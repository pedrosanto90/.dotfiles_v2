import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

ShellRoot {
    id: root
    readonly property bool panelOpen: popupManager.activePopup === "control-center"
    readonly property string activePopup: popupManager.activePopup
    readonly property var availablePopups: ["control-center", "audio", "network", "bluetooth", "battery", "clipboard", "theme", "tiling", "pomodoro", "power", "keybindings", "launcher"]
    property string osdKind: ""
    property bool barVisible: true
    property var targetScreen: null
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var outputDevices: Pipewire.nodes.values.filter(
        node => !!node.audio && node.isSink && !node.isStream)
    readonly property var players: Mpris.players.values
    property string selectedPlayer: ""
    readonly property var player: players.find(p => p.dbusName === selectedPlayer)
        || players.find(p => p.isPlaying) || players[0] || null
    property real brightness: 0
    property bool brightnessAvailable: false
    property string brightnessDevice: ""
    property string brightnessError: ""
    property int pendingBrightness: -1
    property string keybindingsScope: "all"

    PopupManager { id: popupManager }

    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.outputDevices).filter(n => n !== null)
    }

    function chooseScreen() {
        const name = I3.focusedMonitor ? I3.focusedMonitor.name : "";
        targetScreen = Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0] || null;
    }
    function refreshBrightness() {
        if (!brightnessRead.running && !brightnessWrite.running)
            brightnessRead.running = true;
    }
    function popupAvailable(name) {
        return availablePopups.indexOf(name) >= 0;
    }
    function openPopup(name) {
        if (!popupAvailable(name)) return false;
        chooseScreen();
        popupManager.open(name);
        if (name === "control-center") refreshBrightness();
        return true;
    }
    function togglePopup(name) {
        if (!popupAvailable(name)) return false;
        chooseScreen();
        popupManager.toggle(name);
        if (name === "control-center" && panelOpen) refreshBrightness();
        return true;
    }
    function togglePopupOnScreen(name, screen) {
        if (!popupAvailable(name)) return false;
        targetScreen = screen;
        popupManager.toggle(name);
        return true;
    }
    function closePopups() {
        popupManager.closeAll();
    }
    function openKeybindings(scope) {
        keybindingsScope = ["sway", "tmux", "neovim"].indexOf(scope) >= 0 ? scope : "all";
        return openPopup("keybindings");
    }
    function show(kind) {
        if (["volume", "microphone", "brightness"].indexOf(kind) < 0) return;
        chooseScreen();
        if (kind === "brightness") refreshBrightness();
        osdKind = kind;
        osdTimer.restart();
    }
    function setBrightness(value) {
        pendingBrightness = Math.max(1, Math.min(100, Math.round(value * 100)));
        brightnessDebounce.restart();
    }
    function writeBrightness() {
        if (brightnessWrite.running || pendingBrightness < 0) return;
        const value = pendingBrightness;
        pendingBrightness = -1;
        brightnessError = "";
        brightnessWrite.command = ["brightnessctl", "--class=backlight", "--min-value=1", "set", value + "%"];
        brightnessWrite.running = true;
    }
    function transport(action) {
        if (!player) return false;
        // Keep controlling the same player after pausing it, even when another
        // player remains active or is first in the MPRIS list.
        const active = player;
        selectedPlayer = active.dbusName;
        if (action === "play-pause" && active.canTogglePlaying) active.togglePlaying();
        else if (action === "next" && active.canGoNext) active.next();
        else if (action === "previous" && active.canGoPrevious) active.previous();
        else return false;
        return true;
    }
    function selectOutput(index) {
        if (index < 0 || index >= outputDevices.length) return false;
        Pipewire.preferredDefaultAudioSink = outputDevices[index];
        return true;
    }

    IpcHandler {
        target: "media"
        function toggle(): void { root.togglePopup("control-center"); }
        function close(): void { root.closePopups(); }
        function show(kind: string): void { root.show(kind); }
        function transport(action: string): bool { return root.transport(action); }
        function status(): string {
            return JSON.stringify({panelOpen: root.panelOpen, osd: root.osdKind,
                output: root.sink ? root.sink.description : "", brightness: root.brightness,
                brightnessAvailable: root.brightnessAvailable,
                player: root.player ? root.player.identity : ""});
        }
    }

    IpcHandler {
        target: "shell"
        function open(name: string): bool { return root.openPopup(name); }
        function toggle(name: string): bool { return root.togglePopup(name); }
        function close(): void { root.closePopups(); }
        function showBar(): void { root.barVisible = true; }
        function hideBar(): void { root.barVisible = false; }
        function toggleBar(): bool {
            root.barVisible = !root.barVisible;
            return root.barVisible;
        }
        function status(): string {
            return JSON.stringify({activePopup: root.activePopup,
                screen: root.targetScreen ? root.targetScreen.name : "",
                availablePopups: root.availablePopups,
                barVisible: root.barVisible});
        }
    }

    IpcHandler {
        target: "keybindings"
        function open(scope: string): bool { return root.openKeybindings(scope); }
    }

    Process {
        id: brightnessRead
        command: ["brightnessctl", "--class=backlight", "--machine-readable", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split("\n")[0].split(",");
                const current = Number(fields[2]);
                const max = Number(fields[4]);
                root.brightnessAvailable = fields.length >= 5 && max > 0 && Number.isFinite(current);
                if (root.brightnessAvailable) {
                    root.brightness = current / max;
                    root.brightnessDevice = fields[0];
                }
            }
        }
        onExited: (code, status) => { if (code !== 0) root.brightnessAvailable = false; }
    }
    Process {
        id: brightnessWrite
        onExited: (code, status) => {
            if (code !== 0) root.brightnessError = "Could not change brightness. Check backlight permissions.";
            if (root.pendingBrightness >= 0) root.writeBrightness();
            else root.refreshBrightness();
        }
    }
    Timer { id: brightnessDebounce; interval: 80; onTriggered: root.writeBrightness() }
    Timer { interval: 2000; repeat: true; running: root.panelOpen; onTriggered: root.refreshBrightness() }
    Timer { id: osdTimer; interval: 1800; onTriggered: root.osdKind = "" }

    ControlCenter { controller: root }
    Launcher { controller: root }
    KeybindingsPopover { controller: root; barScreen: root.targetScreen; requestedScope: root.keybindingsScope }
    MediaOsd { controller: root }
    Bar { controller: root; shown: root.barVisible }
}
