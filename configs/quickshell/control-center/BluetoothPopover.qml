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
        ToggleSwitch {
            visible: !!root.adapter
            checked: !!root.adapter && root.adapter.enabled
            onToggled: root.setEnabled(checked)
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
        ScrollBar.vertical: ThemeScrollBar { }

        Column {
            width: deviceScroll.availableWidth
            spacing: 4

            Repeater {
                model: root.adapter ? root.adapter.devices : 0

                Rectangle {
                    id: deviceRow
                    required property var modelData
                    width: parent.width
                    height: 50
                    radius: 8
                    color: rowMouse.containsMouse ? Theme.border : Theme.surface
                    border.width: deviceRow.modelData.connected ? 1 : 0
                    border.color: Theme.accent
                    opacity: deviceRow.modelData.pairing
                        || deviceRow.modelData.state === BluetoothDeviceState.Connecting
                        || deviceRow.modelData.state === BluetoothDeviceState.Disconnecting ? 0.6 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                Layout.fillWidth: true
                                text: deviceRow.modelData.name
                                textFormat: Text.PlainText
                                color: Theme.foreground
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Label {
                                text: deviceRow.modelData.pairing ? "Pairing…"
                                    : deviceRow.modelData.connected ? "Connected"
                                    : deviceRow.modelData.paired ? "Paired" : "Available"
                                textFormat: Text.PlainText
                                color: Theme.secondary
                                font.pixelSize: 11
                            }
                        }
                        Label {
                            visible: deviceRow.modelData.batteryAvailable
                            text: Math.round(deviceRow.modelData.battery * 100) + "%"
                            textFormat: Text.PlainText
                            color: Theme.secondary
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !deviceRow.modelData.pairing
                            && deviceRow.modelData.state !== BluetoothDeviceState.Connecting
                            && deviceRow.modelData.state !== BluetoothDeviceState.Disconnecting
                        onClicked: {
                            if (deviceRow.modelData.connected) deviceRow.modelData.disconnect();
                            else if (deviceRow.modelData.paired) deviceRow.modelData.connect();
                            else deviceRow.modelData.pair();
                        }
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
