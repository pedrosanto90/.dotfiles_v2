import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var barScreen
    required property var stats
    property bool shown: false
    property int rightOffset: 8
    readonly property bool hovered: hoverArea.containsMouse
    readonly property var metrics: [
        { icon: "", label: "CPU", value: Number(stats.cpu || 0),
            detail: Math.round(Number(stats.cpu || 0)) + "%", color: Theme.accent },
        { icon: "󰎅", label: "Memory", value: Number(stats.memory || 0),
            detail: root.byteLabel(stats.memoryUsed) + " / " + root.byteLabel(stats.memoryTotal),
            color: Theme.purple },
        { icon: "", label: "Disk", value: Number(stats.disk || 0),
            detail: root.byteLabel(stats.diskUsed) + " / " + root.byteLabel(stats.diskTotal),
            color: Theme.warning }
    ]

    function byteLabel(value) {
        const bytes = Number(value || 0);
        if (bytes <= 0) return "--";
        const gibibytes = bytes / 1073741824;
        return (gibibytes >= 10 ? gibibytes.toFixed(0) : gibibytes.toFixed(1)) + " GiB";
    }

    visible: shown
    screen: barScreen
    anchors { top: true; right: true }
    margins { top: 34; right: root.rightOffset }
    implicitWidth: 310
    implicitHeight: 206
    exclusiveZone: 0
    color: "transparent"
    aboveWindows: true
    focusable: false
    WlrLayershell.namespace: "dotfiles-system-stats"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.background
        border.color: Theme.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Label {
                Layout.fillWidth: true
                text: "System resources"
                color: Theme.foreground
                font.pixelSize: 15
                font.bold: true
            }

            Repeater {
                model: root.metrics

                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            text: modelData.icon
                            color: modelData.color
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: Theme.foreground
                            font.bold: true
                        }
                        Label {
                            text: modelData.label === "CPU"
                                ? modelData.detail : Math.round(modelData.value) + "%  ·  " + modelData.detail
                            color: Theme.secondary
                            font.pixelSize: 12
                        }
                    }

                    ThemeProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: Math.max(0, Math.min(100, modelData.value))
                        color: modelData.color
                    }
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }
}
