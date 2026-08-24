#!/usr/bin/env bash

set -Eeuo pipefail

readonly INTERFACE="wlp1s0"
readonly MAIN_INTERFACES_FILE="/etc/network/interfaces"
readonly NM_CONFIG_FILE="/etc/NetworkManager/NetworkManager.conf"
readonly RESOLV_CONF="/etc/resolv.conf"
readonly VPN_NAME="Domatica"

BACKUP_DIR=""
CURRENT_SSID=""
ORIGINAL_IFUP_STATE="inactive"
ORIGINAL_NM_DEVICE_STATE="unknown"
CREATED_CONNECTION_UUID=""
CREATED_CONNECTION_NAME=""
MIGRATION_STARTED=0
MIGRATION_FINISHED=0
ROLLBACK_RUNNING=0

declare -a INTERFACES_FILES=()
declare -a TARGET_FILES=()
declare -a DOMATICA_SNAPSHOTS=()

log() {
    printf '%s\n' "$*"
}

warn() {
    printf 'AVISO: %s\n' "$*" >&2
}

die() {
    printf 'ERRO: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Uso:
  sudo ./scripts/system/migrate-wlp1s0-to-networkmanager.sh
  sudo ./scripts/system/migrate-wlp1s0-to-networkmanager.sh --inspect
  sudo ./scripts/system/migrate-wlp1s0-to-networkmanager.sh --rollback DIRETORIO_BACKUP

Sem opções, inspeciona o sistema, cria backups, pede confirmação imediatamente
antes de interromper o Wi-Fi e migra wlp1s0 para o NetworkManager.

O perfil VPN Domatica nunca é modificado. É apenas identificado e comparado
por checksum antes e depois da operação.
EOF
}

require_root() {
    if [[ ${EUID} -ne 0 ]]; then
        exec sudo -- "$0" "$@"
    fi
}

require_commands() {
    local command_name
    for command_name in awk cp date find getent grep ip nmcli ping pgrep readlink sed sha256sum stat systemctl; do
        command -v "$command_name" >/dev/null 2>&1 || die "Comando obrigatório em falta: ${command_name}"
    done
    [[ -x /usr/sbin/NetworkManager ]] || die "/usr/sbin/NetworkManager não está disponível"
    [[ -x /usr/sbin/iw ]] || die "/usr/sbin/iw não está disponível"
}

add_interfaces_file() {
    local candidate=$1
    local known

    [[ -f $candidate ]] || return 0
    candidate=$(readlink -f -- "$candidate")
    for known in "${INTERFACES_FILES[@]:-}"; do
        [[ $known == "$candidate" ]] && return 0
    done
    INTERFACES_FILES+=("$candidate")
}

discover_interfaces_files() {
    local index=0
    local file line directive argument directory included
    local -a matches=()

    INTERFACES_FILES=()
    add_interfaces_file "$MAIN_INTERFACES_FILE"

    while (( index < ${#INTERFACES_FILES[@]} )); do
        file=${INTERFACES_FILES[$index]}
        ((index += 1))

        while IFS= read -r line || [[ -n $line ]]; do
            line=${line%%#*}
            [[ $line =~ ^[[:space:]]*(source|source-directory)[[:space:]]+(.+[^[:space:]])[[:space:]]*$ ]] || continue
            directive=${BASH_REMATCH[1]}
            argument=${BASH_REMATCH[2]}

            if [[ $argument != /* ]]; then
                argument="$(dirname -- "$file")/$argument"
            fi

            if [[ $directive == source ]]; then
                mapfile -t matches < <(compgen -G "$argument" || true)
                for included in "${matches[@]:-}"; do
                    add_interfaces_file "$included"
                done
            else
                directory=$argument
                [[ -d $directory ]] || continue
                while IFS= read -r -d '' included; do
                    add_interfaces_file "$included"
                done < <(find "$directory" -maxdepth 1 -type f -regextype posix-extended \
                    -regex '.*/[A-Za-z0-9_-]+' -print0)
            fi
        done < "$file"
    done
}

file_declares_interface() {
    local file=$1
    awk -v iface="$INTERFACE" '
        BEGIN { found = 0 }
        {
            line = $0
            sub(/[[:space:]]*#.*/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            count = split(line, field, /[[:space:]]+/)
            if (field[1] == "iface" && field[2] == iface) found = 1
            if (field[1] == "auto" || field[1] == "allow-auto" || field[1] == "allow-hotplug") {
                for (i = 2; i <= count; i++) if (field[i] == iface) found = 1
            }
        }
        END { exit(found ? 0 : 1) }
    ' "$file"
}

find_target_files() {
    local file
    TARGET_FILES=()
    for file in "${INTERFACES_FILES[@]}"; do
        if file_declares_interface "$file"; then
            TARGET_FILES+=("$file")
        fi
    done
}

show_safe_interfaces_config() {
    local file
    for file in "${INTERFACES_FILES[@]}"; do
        log "--- ${file}"
        awk -v iface="$INTERFACE" '
            BEGIN { in_target = 0 }
            function redact(text) {
                if (text ~ /^[[:space:]]*(wpa-psk|password|passwd|passphrase|private[-_]key|private_key_passwd|secret|wep-key|wireless-key)[[:space:]=]/) {
                    match(text, /^[[:space:]]*[^[:space:]=]+/)
                    text = substr(text, 1, RLENGTH) " <redigido>"
                }
                return text
            }
            {
                raw = $0
                line = raw
                sub(/[[:space:]]*#.*/, "", line)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                count = split(line, field, /[[:space:]]+/)

                if (field[1] == "iface") in_target = (field[2] == iface || field[2] == "lo")
                if ((field[1] == "auto" || field[1] == "allow-auto" || field[1] == "allow-hotplug") && line ~ "(^|[[:space:]])(" iface "|lo)($|[[:space:]])") {
                    print FNR ":" raw
                    next
                }
                if (in_target) print FNR ":" redact(raw)
            }
        ' "$file"
    done
}

get_current_ssid() {
    /usr/sbin/iw dev "$INTERFACE" link 2>/dev/null |
        awk -F': ' '/^[[:space:]]*SSID: / { print $2; exit }'
}

find_nm_profile_file() {
    local wanted_uuid=$1
    local candidate

    for candidate in /etc/NetworkManager/system-connections/*; do
        [[ -f $candidate ]] || continue
        if awk -F= -v wanted_name="$VPN_NAME" -v wanted_uuid="$wanted_uuid" '
            BEGIN { in_connection = 0; id = ""; uuid = "" }
            /^[[:space:]]*\[connection\][[:space:]]*$/ { in_connection = 1; next }
            /^[[:space:]]*\[/ { in_connection = 0 }
            in_connection && $1 == "id" { id = substr($0, index($0, "=") + 1) }
            in_connection && $1 == "uuid" { uuid = substr($0, index($0, "=") + 1) }
            END { exit(id == wanted_name && uuid == wanted_uuid ? 0 : 1) }
        ' "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

snapshot_domatica() {
    local uuid filename checksum metadata
    local -a uuids=()

    DOMATICA_SNAPSHOTS=()
    mapfile -t uuids < <(
        nmcli -t -f NAME,UUID connection show |
            awk -F: -v wanted="$VPN_NAME" '$1 == wanted { print $2 }'
    )

    for uuid in "${uuids[@]:-}"; do
        [[ -n $uuid ]] || continue
        filename=$(nmcli -g GENERAL.FILENAME connection show uuid "$uuid" 2>/dev/null || true)
        if [[ -z $filename ]]; then
            filename=$(find_nm_profile_file "$uuid" || true)
        fi
        if [[ -n $filename && -f $filename ]]; then
            checksum=$(sha256sum -- "$filename" | awk '{print $1}')
            metadata=$(stat -c '%a:%u:%g:%s:%y' -- "$filename")
        else
            filename="<sem-ficheiro-persistente>"
            checksum="<indisponivel>"
            metadata="<indisponivel>"
        fi
        DOMATICA_SNAPSHOTS+=("${uuid}|${filename}|${checksum}|${metadata}")
    done
}

write_domatica_snapshot() {
    local record
    : > "$BACKUP_DIR/domatica.snapshot"
    chmod 0600 "$BACKUP_DIR/domatica.snapshot"
    for record in "${DOMATICA_SNAPSHOTS[@]:-}"; do
        [[ -n $record ]] && printf '%s\n' "$record" >> "$BACKUP_DIR/domatica.snapshot"
    done
}

verify_domatica_snapshot_file() {
    local snapshot_file=$1
    local uuid filename expected_hash expected_metadata current_hash current_metadata
    local found=0

    [[ -f $snapshot_file ]] || {
        warn "Não existe snapshot de ${VPN_NAME} em ${snapshot_file}"
        return 1
    }

    while IFS='|' read -r uuid filename expected_hash expected_metadata; do
        [[ -n $uuid ]] || continue
        found=1
        if [[ $filename == "<sem-ficheiro-persistente>" ]]; then
            warn "Não é possível comparar o perfil ${VPN_NAME} ${uuid}: não tinha ficheiro persistente"
            continue
        fi
        [[ -f $filename ]] || {
            warn "O ficheiro do perfil ${VPN_NAME} desapareceu: ${filename}"
            return 1
        }
        current_hash=$(sha256sum -- "$filename" | awk '{print $1}')
        current_metadata=$(stat -c '%a:%u:%g:%s:%y' -- "$filename")
        [[ $current_hash == "$expected_hash" && $current_metadata == "$expected_metadata" ]] || {
            warn "O checksum ou os metadados do perfil ${VPN_NAME} mudaram"
            return 1
        }
    done < "$snapshot_file"

    if (( found == 0 )); then
        log "Perfil ${VPN_NAME}: não estava presente no início; nenhuma operação o terá como alvo."
    else
        log "Perfil ${VPN_NAME}: checksum e metadados inalterados."
    fi
}

inspect_system() {
    local file effective_nm_config

    log "== Interface física =="
    [[ -d /sys/class/net/$INTERFACE ]] || die "A interface ${INTERFACE} não existe"
    systemctl is-active --quiet NetworkManager.service || die "NetworkManager.service não está ativo; diagnóstico revisto necessário"
    systemctl is-active --quiet wpa_supplicant.service || die "wpa_supplicant.service global não está ativo; diagnóstico revisto necessário"
    if nmcli -t -f NAME connection show --active | grep -Fxq "$VPN_NAME"; then
        die "A VPN ${VPN_NAME} está ativa. Desliga-a manualmente e repete a inspeção; o script não mudará o seu estado"
    fi

    ip -brief link show "$INTERFACE"
    log "Dispositivo: $(readlink -f "/sys/class/net/$INTERFACE/device")"
    /usr/sbin/iw dev "$INTERFACE" link 2>/dev/null |
        sed -n -E '/SSID:|freq:|signal:|[tr]x bitrate:/p' || true

    discover_interfaces_files
    find_target_files
    log
    log "== Ficheiros ifupdown lidos =="
    printf '%s\n' "${INTERFACES_FILES[@]}"
    log
    log "== Configuração relevante, com segredos redigidos =="
    show_safe_interfaces_config

    ((${#TARGET_FILES[@]} > 0)) || die "${INTERFACE} não está declarada nos ficheiros ifupdown lidos; diagnóstico revisto necessário"
    for file in "${TARGET_FILES[@]}"; do
        if grep -Eq "^[[:space:]]*mapping[[:space:]]+${INTERFACE}([[:space:]]|$)" "$file"; then
            die "Foi encontrada uma stanza mapping para ${INTERFACE} em ${file}; o script não a altera automaticamente"
        fi
    done

    log
    log "== Serviços e processos =="
    systemctl show "ifup@${INTERFACE}.service" -p ActiveState -p SubState -p FragmentPath -p ExecStart -p ExecStop
    systemctl show NetworkManager.service wpa_supplicant.service \
        -p Id -p ActiveState -p SubState -p UnitFileState -p ExecStart
    pgrep -a wpa_supplicant || true
    pgrep -a dhcpcd || true

    log
    log "== NetworkManager efetivo =="
    effective_nm_config=$(/usr/sbin/NetworkManager --print-config)
    printf '%s\n' "$effective_nm_config"
    if grep -Eq '^[[:space:]]*dns[[:space:]]*=[[:space:]]*(none|systemd-resolved)([[:space:]]|$)' <<< "$effective_nm_config"; then
        die "O backend DNS efetivo não permite ao NetworkManager gerir /etc/resolv.conf diretamente"
    fi
    if grep -Eq '^[[:space:]]*rc-manager[[:space:]]*=[[:space:]]*unmanaged([[:space:]]|$)' <<< "$effective_nm_config"; then
        die "O rc-manager efetivo está unmanaged; diagnóstico revisto necessário"
    fi
    if [[ -L $RESOLV_CONF ]] && readlink -f "$RESOLV_CONF" | grep -q '/systemd/resolve/'; then
        die "${RESOLV_CONF} aponta para systemd-resolved; diagnóstico revisto necessário"
    fi
    nmcli general status
    nmcli device status
    log "Perfis Wi-Fi existentes (sem segredos):"
    nmcli -f NAME,UUID,TYPE,DEVICE,AUTOCONNECT connection show |
        awk 'NR == 1 || $3 == "wifi" || $3 == "802-11-wireless"'

    log
    log "== Rede e DNS atuais =="
    ip address show "$INTERFACE"
    ip route show
    stat -c '%A %U:%G %y %n -> %N' "$RESOLV_CONF"
    sed -n -E '/^[[:space:]]*(nameserver|search|domain|options)[[:space:]]/p' "$RESOLV_CONF"

    CURRENT_SSID=$(get_current_ssid || true)
    ORIGINAL_IFUP_STATE=$(systemctl is-active "ifup@${INTERFACE}.service" 2>/dev/null || true)
    ORIGINAL_NM_DEVICE_STATE=$(nmcli -g GENERAL.STATE device show "$INTERFACE" 2>/dev/null || true)
    snapshot_domatica
}

show_plan() {
    log
    log "== Plano =="
    log "Ficheiros a alterar:"
    printf '  - %s\n' "${TARGET_FILES[@]}"
    log "Ficheiros apenas salvaguardados: ${NM_CONFIG_FILE}, ${RESOLV_CONF}"
    log "Serviços afetados: ifup@${INTERFACE}.service e NetworkManager.service."
    log "O NetworkManager recebe primeiro um reload; se o plugin ifupdown mantiver o estado unmanaged, é reiniciado."
    log "Serviço preservado: wpa_supplicant.service global."
    log "Interrupção: começa apenas depois da confirmação, ao parar ifup@${INTERFACE}.service."
    log "Rollback: restaurar os backups, devolver ${INTERFACE} a unmanaged e reiniciar apenas a instância ifup anterior."
    log "VPN ${VPN_NAME}: nunca será passada a comandos de modificação; será apenas comparada por checksum."
}

create_backups() {
    local timestamp file
    timestamp=$(date +%Y%m%dT%H%M%S%z)
    BACKUP_DIR="/var/backups/networkmanager-${INTERFACE}-${timestamp}"
    install -d -m 0700 -o root -g root "$BACKUP_DIR"

    for file in "${INTERFACES_FILES[@]}" "$NM_CONFIG_FILE" "$RESOLV_CONF"; do
        [[ -e $file || -L $file ]] || continue
        cp -a --parents -- "$file" "$BACKUP_DIR"
        printf '%s\n' "$file" >> "$BACKUP_DIR/files.manifest"
    done
    chmod 0600 "$BACKUP_DIR/files.manifest"
    printf '%s\n' "$ORIGINAL_IFUP_STATE" > "$BACKUP_DIR/original-ifup-state"
    printf '%s\n' "$ORIGINAL_NM_DEVICE_STATE" > "$BACKUP_DIR/original-nm-device-state"
    : > "$BACKUP_DIR/created-wifi-uuid"
    chmod 0600 "$BACKUP_DIR/original-ifup-state" "$BACKUP_DIR/original-nm-device-state" "$BACKUP_DIR/created-wifi-uuid"
    write_domatica_snapshot

    log
    log "Backups criados em: ${BACKUP_DIR}"
    while IFS= read -r file; do
        stat -c '  %a %U:%G %y %n' "$BACKUP_DIR$file"
    done < "$BACKUP_DIR/files.manifest"
}

confirm_interruption() {
    local answer
    log
    warn "A próxima ação para ifup@${INTERFACE}.service e interrompe temporariamente o Wi-Fi."
    printf 'Escreve MIGRAR para confirmar a interrupção: '
    IFS= read -r answer
    [[ $answer == MIGRAR ]] || die "Operação cancelada antes da interrupção; apenas os backups foram criados"
}

rewrite_interfaces_file() {
    local file=$1
    local temporary
    temporary=$(mktemp --tmpdir="$(dirname -- "$file")" .nm-ifupdown.XXXXXX)
    cp --attributes-only --preserve=all -- "$file" "$temporary"

    awk -v iface="$INTERFACE" '
        function print_interface_list(raw, directive, count, field,    i, output, comment_at, comment) {
            comment_at = index(raw, "#")
            comment = comment_at ? substr(raw, comment_at) : ""
            output = directive
            for (i = 2; i <= count; i++) {
                if (field[i] != iface && field[i] != "") output = output " " field[i]
            }
            if (output == directive) return
            if (comment != "") output = output " " comment
            print output
        }
        {
            raw = $0
            line = raw
            sub(/[[:space:]]*#.*/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            count = split(line, field, /[[:space:]]+/)

            if (skip_stanza) {
                if (raw ~ /^[[:space:]]/ || raw ~ /^[[:space:]]*$/) next
                skip_stanza = 0
            }

            if (field[1] == "iface" && field[2] == iface) {
                skip_stanza = 1
                next
            }

            if (field[1] == "auto" || field[1] == "allow-auto" || field[1] == "allow-hotplug") {
                contains_target = 0
                for (i = 2; i <= count; i++) if (field[i] == iface) contains_target = 1
                if (contains_target) {
                    print_interface_list(raw, field[1], count, field)
                    next
                }
            }
            print raw
        }
    ' "$file" > "$temporary"

    mv -f -- "$temporary" "$file"
}

remove_ifupdown_management() {
    local file
    for file in "${TARGET_FILES[@]}"; do
        rewrite_interfaces_file "$file"
    done

    discover_interfaces_files
    find_target_files
    ((${#TARGET_FILES[@]} == 0)) || die "Ainda existe uma declaração ifupdown para ${INTERFACE}"

    grep -Eq '^[[:space:]]*auto[[:space:]]+lo([[:space:]]|$)' "$MAIN_INTERFACES_FILE" ||
        die "A validação não encontrou 'auto lo'"
    grep -Eq '^[[:space:]]*iface[[:space:]]+lo[[:space:]]+inet[[:space:]]+loopback([[:space:]]|$)' "$MAIN_INTERFACES_FILE" ||
        die "A validação não encontrou 'iface lo inet loopback'"
}

matching_wifi_profiles() {
    local uuid type ssid
    while IFS=: read -r uuid type; do
        [[ $type == 802-11-wireless || $type == wifi ]] || continue
        ssid=$(nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null || true)
        [[ $ssid == "$CURRENT_SSID" ]] && printf '%s\n' "$uuid"
    done < <(nmcli -t -f UUID,TYPE connection show)
}

activate_wifi() {
    local uuid profile_name chosen index
    local -a matches=()

    if [[ -z $CURRENT_SSID ]]; then
        nmcli device wifi rescan ifname "$INTERFACE" || true
        nmcli -f IN-USE,SSID,MODE,CHAN,RATE,SIGNAL,SECURITY device wifi list ifname "$INTERFACE"
        printf 'SSID a ligar: '
        IFS= read -r CURRENT_SSID
        [[ -n $CURRENT_SSID ]] || die "SSID vazio"
    fi

    mapfile -t matches < <(matching_wifi_profiles)
    if ((${#matches[@]} == 1)); then
        chosen=${matches[0]}
        log "A ativar perfil Wi-Fi existente para ${CURRENT_SSID}: ${chosen}"
        nmcli --ask connection up uuid "$chosen" ifname "$INTERFACE"
        return
    fi

    if ((${#matches[@]} > 1)); then
        log "Existem vários perfis para ${CURRENT_SSID}:"
        for index in "${!matches[@]}"; do
            profile_name=$(nmcli -g connection.id connection show uuid "${matches[$index]}")
            printf '  %d) %s (%s)\n' "$((index + 1))" "$profile_name" "${matches[$index]}"
        done
        printf 'Número do perfil a ativar: '
        IFS= read -r index
        [[ $index =~ ^[0-9]+$ ]] || die "Seleção inválida"
        (( index >= 1 && index <= ${#matches[@]} )) || die "Seleção fora do intervalo"
        chosen=${matches[$((index - 1))]}
        nmcli --ask connection up uuid "$chosen" ifname "$INTERFACE"
        return
    fi

    CREATED_CONNECTION_NAME="${CURRENT_SSID} (${INTERFACE} NetworkManager)"
    log "Não existe perfil correspondente. O nmcli pedirá a password de forma interativa."
    nmcli --ask device wifi connect "$CURRENT_SSID" ifname "$INTERFACE" name "$CREATED_CONNECTION_NAME"
    CREATED_CONNECTION_UUID=$(nmcli -g connection.uuid connection show id "$CREATED_CONNECTION_NAME")
    printf '%s\n' "$CREATED_CONNECTION_UUID" > "$BACKUP_DIR/created-wifi-uuid"
}

restore_from_backup() {
    local directory=$1
    local file backup_file original_ifup_state original_nm_state created_uuid

    [[ -d $directory ]] || die "Diretório de backup inexistente: ${directory}"
    [[ -f $directory/files.manifest ]] || die "Manifesto inexistente em ${directory}"

    ROLLBACK_RUNNING=1
    set +e
    nmcli device disconnect "$INTERFACE" >/dev/null 2>&1

    created_uuid=""
    [[ -f $directory/created-wifi-uuid ]] && created_uuid=$(<"$directory/created-wifi-uuid")
    if [[ -n $created_uuid ]]; then
        nmcli connection delete uuid "$created_uuid" >/dev/null 2>&1
    fi

    while IFS= read -r file; do
        backup_file="${directory}${file}"
        if [[ -e $backup_file || -L $backup_file ]]; then
            cp -a -- "$backup_file" "$file"
        else
            warn "Backup em falta: ${backup_file}"
        fi
    done < "$directory/files.manifest"

    nmcli general reload >/dev/null 2>&1
    original_ifup_state="inactive"
    original_nm_state="unknown"
    [[ -f $directory/original-ifup-state ]] && original_ifup_state=$(<"$directory/original-ifup-state")
    [[ -f $directory/original-nm-device-state ]] && original_nm_state=$(<"$directory/original-nm-device-state")
    if [[ $original_nm_state == *unmanaged* ]]; then
        nmcli device set "$INTERFACE" managed no >/dev/null 2>&1
    fi
    if [[ $original_ifup_state == active ]]; then
        systemctl start "ifup@${INTERFACE}.service"
    fi
    verify_domatica_snapshot_file "$directory/domatica.snapshot"
    set -e
    ROLLBACK_RUNNING=0
    log "Rollback concluído a partir de ${directory}"
}

on_exit() {
    local status=$?
    if (( status != 0 && MIGRATION_STARTED == 1 && MIGRATION_FINISHED == 0 && ROLLBACK_RUNNING == 0 )); then
        warn "A migração falhou; a executar rollback automático."
        restore_from_backup "$BACKUP_DIR" || warn "O rollback automático encontrou erros"
    fi
    exit "$status"
}

wait_for_managed_device() {
    local attempts=${1:-20}
    local attempt state
    for ((attempt = 1; attempt <= attempts; attempt++)); do
        state=$(nmcli -g GENERAL.STATE device show "$INTERFACE" 2>/dev/null || true)
        [[ $state != *unmanaged* && -n $state ]] && return 0
        sleep 0.5
    done
    return 1
}

make_device_managed() {
    nmcli general reload
    nmcli device set "$INTERFACE" managed yes

    if wait_for_managed_device 10; then
        return 0
    fi

    warn "O reload não atualizou o estado do plugin ifupdown; a reiniciar apenas NetworkManager.service."
    systemctl restart NetworkManager.service

    if wait_for_managed_device 40; then
        return 0
    fi

    nmcli -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.REASON device show "$INTERFACE" || true
    die "O NetworkManager continua a apresentar ${INTERFACE} como unmanaged depois do restart"
}

validate_core_connection() {
    local state
    state=$(nmcli -g GENERAL.STATE device show "$INTERFACE")
    [[ $state == *connected* ]] || die "${INTERFACE} não ficou connected: ${state}"
    ip -4 address show dev "$INTERFACE" | grep -q 'inet ' || die "Não foi atribuído endereço IPv4"
    ip -4 route show default dev "$INTERFACE" | grep -q '^default ' || die "Não existe rota IPv4 default por ${INTERFACE}"
    nmcli -g IP4.DNS device show "$INTERFACE" | grep -q . || die "O NetworkManager não recebeu DNS IPv4"
}

run_validation() {
    local gateway

    log
    log "== Validação final =="
    log "-- nmcli device status"
    nmcli device status
    log "-- nmcli general status"
    nmcli general status
    log "-- nmcli connection show --active"
    nmcli connection show --active
    log "-- ip address show ${INTERFACE}"
    ip address show "$INTERFACE"
    log "-- ip route"
    ip route
    log "-- /etc/resolv.conf (apenas conteúdo não sensível)"
    stat -c '%A %U:%G %y %n -> %N' "$RESOLV_CONF"
    sed -n -E '/^[[:space:]]*(nameserver|search|domain|options)[[:space:]]/p' "$RESOLV_CONF"

    gateway=$(ip -4 route show default dev "$INTERFACE" | awk 'NR == 1 {print $3}')
    log "-- gateway ${gateway}"
    if [[ -n $gateway ]] && ping -c 3 -W 2 "$gateway"; then
        log "Gateway: OK"
    else
        warn "O gateway não respondeu a ICMP"
    fi

    log "-- conectividade por IP"
    if ping -c 3 -W 2 1.1.1.1 || ping -c 3 -W 2 9.9.9.9; then
        log "Internet por IP: OK"
    else
        warn "Os endereços de teste não responderam a ICMP"
    fi

    log "-- resolução DNS"
    if getent ahostsv4 debian.org; then
        log "DNS: OK"
    else
        warn "A resolução DNS falhou"
    fi

    log "-- redes Wi-Fi visíveis"
    nmcli -f IN-USE,SSID,MODE,CHAN,RATE,SIGNAL,SECURITY device wifi list ifname "$INTERFACE"
    log "-- processos wpa_supplicant"
    pgrep -a wpa_supplicant || true
    log "-- processos dhcpcd"
    if pgrep -a dhcpcd | grep -F "$INTERFACE"; then
        warn "Ainda existe dhcpcd associado a ${INTERFACE}"
    else
        log "Nenhum dhcpcd associado a ${INTERFACE}."
    fi
    log "-- serviço global wpa_supplicant"
    systemctl is-active wpa_supplicant.service
    verify_domatica_snapshot_file "$BACKUP_DIR/domatica.snapshot"
}

migrate() {
    inspect_system
    show_plan
    create_backups
    confirm_interruption

    trap on_exit EXIT
    MIGRATION_STARTED=1

    systemctl stop "ifup@${INTERFACE}.service"
    remove_ifupdown_management

    make_device_managed
    activate_wifi
    validate_core_connection

    MIGRATION_FINISHED=1
    run_validation

    log
    log "Migração concluída. Não é necessário reiniciar nem terminar a sessão."
    log "Backup: ${BACKUP_DIR}"
    log "Rollback exato: sudo $0 --rollback '${BACKUP_DIR}'"
}

main() {
    local mode=${1:-migrate}
    require_root "$@"
    require_commands

    case "$mode" in
        migrate)
            [[ $# -eq 0 ]] || die "Argumentos inesperados"
            migrate
            ;;
        --inspect)
            [[ $# -eq 1 ]] || die "Argumentos inesperados"
            inspect_system
            show_plan
            log
            log "Inspeção concluída; nenhuma alteração foi efetuada."
            ;;
        --rollback)
            [[ $# -eq 2 ]] || die "Indica exatamente um diretório de backup"
            restore_from_backup "$2"
            ;;
        -h|--help)
            usage
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
