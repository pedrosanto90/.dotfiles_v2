import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

BarPopover {
    id: root
    popupName: "bluetooth"
    title: "Bluetooth"
    popupHeight: 410
    readonly property var adapter: Bluetooth.defaultAdapter

    function setEnabled(enabled) {
        Quickshell.execDetached(["bluetooth-toggle", enabled ? "on" : "off"]);
    }

    RowLayout {
        Layout.fillWidth: true
        Label {
            Layout.fillWidth: true
            text: root.adapter ? root.adapter.name : "No Bluetooth adapter"
            color: Theme.foreground
            font.bold: true
            elide: Text.ElideRight
        }
        PopoverButton {
            visible: !!root.adapter
            text: root.adapter && root.adapter.enabled ? "Turn off" : "Turn on"
            onClicked: root.setEnabled(!root.adapter.enabled)
            Accessible.name: "Bluetooth"
        }
        PopoverButton {
            visible: !!root.adapter && root.adapter.enabled
            text: root.adapter && root.adapter.discovering ? "Stop scan" : "Scan"
            onClicked: root.adapter.discovering = !root.adapter.discovering
        }
    }

    Label {
        Layout.fillWidth: true
        visible: !!root.adapter && root.adapter.state === BluetoothAdapterState.Blocked
        text: "The Bluetooth radio is blocked. Turn it on to unblock it."
        color: Theme.warning
        wrapMode: Text.WordWrap
    }

    Label {
        Layout.fillWidth: true
        visible: !!root.adapter && root.adapter.enabled && root.adapter.devices.count === 0
        text: "Searching for devices…"
        color: Theme.secondary
    }

    ScrollView {
        id: deviceScroll
        Layout.fillWidth: true
        implicitHeight: 230
        visible: !!root.adapter && root.adapter.enabled && root.adapter.devices.count > 0
        clip: true
        contentWidth: availableWidth

        Column {
            width: deviceScroll.availableWidth
            spacing: 4

            Repeater {
                model: root.adapter ? root.adapter.devices : 0

                PopoverButton {
                    required property var modelData
                    width: parent.width
                    text: (modelData.connected ? "● " : "") + modelData.name
                        + (modelData.batteryAvailable
                            ? "   " + Math.round(modelData.battery * 100) + "%" : "")
                    enabled: !modelData.pairing
                        && modelData.state !== BluetoothDeviceState.Connecting
                        && modelData.state !== BluetoothDeviceState.Disconnecting
                    onClicked: {
                        if (modelData.connected) modelData.disconnect();
                        else if (modelData.paired) modelData.connect();
                        else modelData.pair();
                    }
                }
            }
        }
    }

    PopoverButton {
        Layout.fillWidth: true
        text: "Advanced Bluetooth settings…"
        onClicked: {
            Quickshell.execDetached(["blueman-manager"]);
            root.controller.closePopups();
        }
    }
}
