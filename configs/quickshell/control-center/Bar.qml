import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland

Scope {
    id: root
    required property var controller
    property bool shown: false
    property bool showDate: false
    readonly property var battery: UPower.displayDevice
    readonly property real batteryPercent: battery.ready ? battery.percentage * 100 : 0

    StatusCommand { id: pomodoroStatus; command: ["pomodoro", "status"]; interval: 1000 }
    StatusCommand { id: layoutStatus; command: ["sway-layout", "status"]; interval: 2000 }
    StatusCommand { id: themeStatus; command: ["theme-toggle", "status"]; interval: 5000 }
    StatusCommand { id: caffeineStatus; command: ["caffeine-toggle", "status"]; interval: 5000 }

    Timer {
        id: refreshStatuses
        interval: 500
        onTriggered: {
            pomodoroStatus.refresh();
            layoutStatus.refresh();
            themeStatus.refresh();
            caffeineStatus.refresh();
        }
    }

    function run(command) {
        Quickshell.execDetached(command);
        refreshStatuses.restart();
    }

    function volumeIcon() {
        if (!controller.sink || !controller.sink.audio || controller.sink.audio.muted) return "󰖁";
        const volume = controller.sink.audio.volume;
        if (volume < 0.34) return "";
        if (volume < 0.67) return "";
        return "";
    }

    function batteryIcon() {
        if (!battery.ready) return "";
        if (!UPower.onBattery) return "󰂄";
        const level = batteryPercent;
        if (level <= 10) return "󰁺";
        if (level <= 30) return "󰁼";
        if (level <= 50) return "󰁾";
        if (level <= 70) return "󰂀";
        if (level <= 90) return "󰂂";
        return "󰁹";
    }

    function batteryTooltip() {
        if (!battery.ready) return "Battery unavailable";
        const seconds = UPower.onBattery ? battery.timeToEmpty : battery.timeToFull;
        let detail = UPower.onBattery ? "Discharging" : "Charging or connected to power";
        if (seconds > 0) {
            const hours = Math.floor(seconds / 3600);
            const minutes = Math.floor((seconds % 3600) / 60);
            detail += " · " + hours + "h " + minutes + "m";
        }
        return detail;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            visible: root.shown
            anchors { left: true; right: true; top: true }
            implicitHeight: 30
            exclusiveZone: 30
            color: Theme.barBackground
            aboveWindows: true
            focusable: false
            WlrLayershell.namespace: "dotfiles-bar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                anchors.fill: parent

                Row {
                    id: workspaces
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }

                    Repeater {
                        model: I3.workspaces

                        Rectangle {
                            id: workspaceButton
                            required property var modelData
                            width: Math.max(32, workspaceLabel.implicitWidth + 16)
                            height: workspaces.height
                            color: modelData.urgent ? Theme.danger
                                : modelData.active ? Theme.accent : "transparent"

                            Text {
                                id: workspaceLabel
                                anchors.centerIn: parent
                                text: workspaceButton.modelData.name
                                color: workspaceButton.modelData.active || workspaceButton.modelData.urgent
                                    ? Theme.selected : Theme.muted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: workspaceButton.modelData.activate()
                            }
                        }
                    }
                }

                Rectangle {
                    id: clockButton
                    anchors.centerIn: parent
                    implicitWidth: clockText.implicitWidth + 18
                    height: parent.height
                    color: "transparent"

                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        text: root.showDate
                            ? "  " + Qt.formatDateTime(clock.date, "dddd, dd MMMM yyyy")
                            : "  " + Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.accent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showDate = !root.showDate
                    }
                }

                Row {
                    id: statusArea
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    spacing: 2

                    Rectangle {
                        id: audioButton
                        width: audioText.implicitWidth + 18
                        height: statusArea.height
                        color: "transparent"

                        Text {
                            id: audioText
                            anchors.centerIn: parent
                            text: root.controller.sink && root.controller.sink.audio
                                ? root.volumeIcon() + " " + Math.round(root.controller.sink.audio.volume * 100) + "%"
                                : "󰖁 --"
                            color: Theme.warning
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }

                    }

                    Rectangle {
                        id: batteryButton
                        visible: root.battery.ready && root.battery.isLaptopBattery && root.battery.isPresent
                        width: visible ? batteryText.implicitWidth + 18 : 0
                        height: statusArea.height
                        color: "transparent"

                        Text {
                            id: batteryText
                            anchors.centerIn: parent
                            text: root.batteryIcon() + " " + Math.round(root.batteryPercent) + "%"
                            color: root.batteryPercent <= 15 ? Theme.danger
                                : root.batteryPercent <= 30 ? Theme.orange : Theme.foreground
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                        }
                    }

                    Repeater {
                        model: SystemTray.items

                        Rectangle {
                            id: trayButton
                            required property var modelData
                            width: 30
                            height: statusArea.height
                            color: "transparent"

                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: trayButton.modelData.icon
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            function showMenu() {
                                const point = mapToItem(window.contentItem, 0, 0);
                                trayButton.modelData.display(window, point.x, point.y);
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) trayButton.modelData.secondaryActivate();
                                    else if (trayButton.modelData.hasMenu)
                                        trayButton.showMenu();
                                    else trayButton.modelData.activate();
                                }
                                onWheel: wheel => trayButton.modelData.scroll(wheel.angleDelta.y, false)
                            }
                        }
                    }

                    StatusButton {
                        height: statusArea.height
                        text: pomodoroStatus.data.text
                        tooltip: pomodoroStatus.data.tooltip
                        foregroundColor: pomodoroStatus.data.class === "running" ? Theme.success
                            : pomodoroStatus.data.class === "break" ? Theme.accent
                            : pomodoroStatus.data.class === "paused" ? Theme.orange : Theme.muted
                        onPrimaryClicked: root.run(["pomodoro", "toggle"])
                        onSecondaryClicked: root.run(["pomodoro", "menu"])
                    }

                    StatusButton {
                        height: statusArea.height
                        text: layoutStatus.data.text
                        tooltip: layoutStatus.data.tooltip
                        foregroundColor: Theme.accent
                        onPrimaryClicked: root.run(["sway-layout", "menu"])
                        onSecondaryClicked: root.run(["sway-layout", "menu"])
                    }

                    StatusButton {
                        height: statusArea.height
                        text: ""
                        tooltip: "Clipboard history"
                        foregroundColor: Theme.accent
                        onPrimaryClicked: root.run(["clipboard-history"])
                        onSecondaryClicked: root.run(["clipboard-history"])
                    }

                    StatusButton {
                        height: statusArea.height
                        text: themeStatus.data.text
                        tooltip: themeStatus.data.tooltip
                        foregroundColor: Theme.purple
                        onPrimaryClicked: root.run(["theme-toggle", "menu"])
                        onSecondaryClicked: root.run(["theme-toggle", "toggle"])
                    }

                    StatusButton {
                        height: statusArea.height
                        text: caffeineStatus.data.text
                        tooltip: caffeineStatus.data.tooltip
                        foregroundColor: caffeineStatus.data.class === "active" ? Theme.warning : Theme.muted
                        onPrimaryClicked: root.run(["caffeine-toggle", "toggle"])
                        onSecondaryClicked: root.run(["caffeine-toggle", "toggle"])
                    }

                    StatusButton {
                        height: statusArea.height
                        text: "󰒓"
                        tooltip: "Control Center"
                        foregroundColor: Theme.accent
                        onPrimaryClicked: root.controller.togglePopup("control-center")
                        onSecondaryClicked: root.controller.togglePopup("control-center")
                    }

                    StatusButton {
                        height: statusArea.height
                        text: ""
                        tooltip: "Power menu"
                        foregroundColor: Theme.danger
                        onPrimaryClicked: root.run(["power-menu"])
                        onSecondaryClicked: root.run(["power-menu"])
                    }
                }
            }
        }
    }
}
