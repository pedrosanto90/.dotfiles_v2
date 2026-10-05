import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

BarPopover {
    id: root
    popupName: "network"
    title: "Network"
    popupHeight: 470
    readonly property var wifiDevice: Networking.devices.values.find(
        device => device.type === DeviceType.Wifi) || null
    property var selectedNetwork: null

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

    onVisibleChanged: {
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = visible && Networking.wifiEnabled;
        if (!visible) root.selectedNetwork = null;
    }

    RowLayout {
        Layout.fillWidth: true
        Label {
            Layout.fillWidth: true
            text: root.wifiDevice ? "Wi-Fi" : "No Wi-Fi adapter"
            color: Theme.foreground
            font.bold: true
        }
        Switch {
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
        implicitHeight: 250
        visible: !!root.wifiDevice && Networking.wifiEnabled
        clip: true
        contentWidth: availableWidth

        Column {
            width: networkScroll.availableWidth
            spacing: 4

            Repeater {
                model: root.wifiDevice ? root.wifiDevice.networks : 0

                Button {
                    required property var modelData
                    width: parent.width
                    text: (modelData.connected ? "● " : "") + modelData.name
                        + "   " + Math.round(modelData.signalStrength * 100) + "%"
                    enabled: !modelData.stateChanging
                    onClicked: root.activate(modelData)
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
            TextField {
                id: passwordField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Wi-Fi password"
                onAccepted: connectButton.clicked()
            }
            Button {
                id: connectButton
                text: "Connect"
                enabled: passwordField.text.length >= 8
                onClicked: {
                    if (root.selectedNetwork) root.selectedNetwork.connectWithPsk(passwordField.text);
                    passwordField.text = "";
                    root.selectedNetwork = null;
                }
            }
        }
    }

    Button {
        Layout.fillWidth: true
        text: "Advanced network settings…"
        onClicked: {
            Quickshell.execDetached(["nm-connection-editor"]);
            root.controller.closePopups();
        }
    }
}
