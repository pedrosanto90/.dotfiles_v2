import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

BarPopover {
    id: root
    popupName: "network"
    title: "Network"
    popupHeight: 690
    readonly property var wifiDevice: Networking.devices.values.find(
        device => device.type === DeviceType.Wifi) || null
    property var selectedNetwork: null
    property var vpns: []
    property string vpnError: ""

    function signalIcon(strength) {
        if (strength < 0.25) return "󰤟";
        if (strength < 0.5) return "󰤢";
        if (strength < 0.75) return "󰤥";
        return "󰤨";
    }

    function needsPsk(network) {
        return network.security === WifiSecurityType.WpaPsk
            || network.security === WifiSecurityType.Wpa2Psk
            || network.security === WifiSecurityType.Sae;
    }

    function activate(network) {
        root.selectedNetwork = null;
        passwordField.text = "";
        if (network.connected) network.disconnect();
        else if (network.known || network.security === WifiSecurityType.Open) network.connect();
        else if (root.needsPsk(network)) {
            root.selectedNetwork = network;
            passwordField.forceActiveFocus();
        } else {
            Quickshell.execDetached(["nm-connection-editor"]);
            root.controller.closePopups();
        }
    }

    function refreshVpns() {
        if (!vpnListProcess.running && !vpnActionProcess.running)
            vpnListProcess.running = true;
    }

    function toggleVpn(vpn) {
        if (vpnActionProcess.running) return;
        root.vpnError = "";
        vpnActionProcess.command = ["network-vpn", vpn.active ? "down" : "up", vpn.uuid];
        vpnActionProcess.running = true;
    }

    function editVpn(uuid) {
        Quickshell.execDetached(["network-vpn", "edit", uuid]);
        root.controller.closePopups();
    }

    onVisibleChanged: {
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = visible && Networking.wifiEnabled;
        if (!visible) root.selectedNetwork = null;
        else root.refreshVpns();
    }

    Process {
        id: vpnListProcess
        command: ["network-vpn", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim() || "[]");
                    root.vpns = Array.isArray(parsed) ? parsed : [];
                    root.vpnError = "";
                } catch (error) {
                    root.vpnError = "Could not read the configured VPNs.";
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.vpnError = "Could not read the configured VPNs.";
        }
    }

    Process {
        id: vpnActionProcess
        onExited: (code, status) => {
            if (code !== 0) root.vpnError = "Could not change the selected VPN connection.";
            vpnRefreshDelay.restart();
        }
    }

    Timer {
        id: vpnRefreshTimer
        interval: 3000
        repeat: true
        running: root.visible
        onTriggered: root.refreshVpns()
    }

    Timer {
        id: vpnRefreshDelay
        interval: 500
        onTriggered: root.refreshVpns()
    }

    RowLayout {
        Layout.fillWidth: true
        Label {
            Layout.fillWidth: true
            text: root.wifiDevice ? "Wi-Fi" : "No Wi-Fi adapter"
            color: Theme.foreground
            font.bold: true
        }
        ToggleSwitch {
            visible: !!root.wifiDevice
            checked: Networking.wifiEnabled
            enabled: Networking.wifiHardwareEnabled
            onToggled: Networking.wifiEnabled = checked
            Accessible.name: "Wi-Fi"
        }
    }

    Label {
        Layout.fillWidth: true
        visible: !!root.wifiDevice && !Networking.wifiHardwareEnabled
        text: "Wi-Fi is disabled by a hardware switch."
        color: Theme.warning
        wrapMode: Text.WordWrap
    }

    ScrollView {
        id: networkScroll
        Layout.fillWidth: true
        implicitHeight: 190
        visible: !!root.wifiDevice && Networking.wifiEnabled
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical: ThemeScrollBar { }

        Column {
            width: networkScroll.availableWidth
            spacing: 4

            Repeater {
                model: root.wifiDevice ? root.wifiDevice.networks : 0

                Rectangle {
                    id: wifiRow
                    required property var modelData
                    width: parent.width
                    height: 50
                    radius: 8
                    color: rowMouse.containsMouse ? Theme.border : Theme.surface
                    border.width: wifiRow.modelData.connected ? 1 : 0
                    border.color: Theme.accent
                    opacity: wifiRow.modelData.stateChanging ? 0.6 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                Layout.fillWidth: true
                                text: wifiRow.modelData.name
                                textFormat: Text.PlainText
                                color: Theme.foreground
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Label {
                                text: Math.round(wifiRow.modelData.signalStrength * 100) + "%"
                                    + (wifiRow.modelData.connected ? " · Connected"
                                        : wifiRow.modelData.known ? " · Saved" : "")
                                textFormat: Text.PlainText
                                color: Theme.secondary
                                font.pixelSize: 11
                            }
                        }
                        Label {
                            text: root.signalIcon(wifiRow.modelData.signalStrength)
                            textFormat: Text.PlainText
                            color: wifiRow.modelData.connected ? Theme.success : Theme.muted
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !wifiRow.modelData.stateChanging
                        onClicked: root.activate(wifiRow.modelData)
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: !!root.selectedNetwork
        spacing: 6

        Label {
            Layout.fillWidth: true
            text: root.selectedNetwork ? "Password for " + root.selectedNetwork.name : ""
            color: Theme.secondary
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            ThemeField {
                id: passwordField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Wi-Fi password"
                onAccepted: connectButton.clicked()
            }
            PopoverButton {
                id: connectButton
                text: "Connect"
                highlighted: true
                enabled: passwordField.text.length >= 8
                onClicked: {
                    if (root.selectedNetwork) root.selectedNetwork.connectWithPsk(passwordField.text);
                    passwordField.text = "";
                    root.selectedNetwork = null;
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.border
    }

    RowLayout {
        Layout.fillWidth: true

        Label {
            Layout.fillWidth: true
            text: "VPN"
            color: Theme.foreground
            font.bold: true
        }
        Label {
            text: root.vpns.filter(vpn => vpn.active).length > 0
                ? root.vpns.filter(vpn => vpn.active).length + " active" : "Disconnected"
            color: root.vpns.some(vpn => vpn.active) ? Theme.success : Theme.muted
            font.pixelSize: 11
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.vpnError.length > 0
        text: root.vpnError
        color: Theme.danger
        wrapMode: Text.WordWrap
    }

    ScrollView {
        id: vpnScroll
        Layout.fillWidth: true
        implicitHeight: Math.min(150, Math.max(48, root.vpns.length * 54))
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical: ThemeScrollBar { }

        Column {
            width: vpnScroll.availableWidth
            spacing: 4

            Repeater {
                model: root.vpns

                Rectangle {
                    id: vpnRow
                    required property var modelData
                    width: parent.width
                    height: 50
                    radius: 8
                    color: Theme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                Layout.fillWidth: true
                                text: vpnRow.modelData.name
                                textFormat: Text.PlainText
                                color: Theme.foreground
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Label {
                                text: vpnRow.modelData.type
                                textFormat: Text.PlainText
                                color: Theme.secondary
                                font.pixelSize: 11
                            }
                        }
                        ToggleSwitch {
                            checked: vpnRow.modelData.active
                            enabled: !vpnActionProcess.running
                            onClicked: root.toggleVpn(vpnRow.modelData)
                            Accessible.name: vpnRow.modelData.name
                        }
                        IconButton {
                            text: "✎"
                            glyphSize: 14
                            enabled: !vpnActionProcess.running
                            Accessible.name: "Edit " + vpnRow.modelData.name
                            onClicked: root.editVpn(vpnRow.modelData.uuid)
                        }
                    }
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: !vpnListProcess.running && root.vpns.length === 0 && root.vpnError.length === 0
        text: "No VPN profiles configured"
        color: Theme.secondary
        horizontalAlignment: Text.AlignHCenter
    }

    RowLayout {
        Layout.fillWidth: true
        PopoverButton {
            Layout.fillWidth: true
            text: "Add VPN…"
            onClicked: {
                Quickshell.execDetached(["network-vpn", "add"]);
                root.controller.closePopups();
            }
        }
        PopoverButton {
            Layout.fillWidth: true
            text: "Import VPN…"
            onClicked: {
                Quickshell.execDetached(["network-vpn", "import"]);
                root.controller.closePopups();
            }
        }
    }

    PopoverButton {
        Layout.fillWidth: true
        text: "Advanced network settings…"
        onClicked: {
            Quickshell.execDetached(["nm-connection-editor"]);
            root.controller.closePopups();
        }
    }
}
