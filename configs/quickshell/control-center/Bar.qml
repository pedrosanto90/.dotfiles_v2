import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Bluetooth
import Quickshell.Networking
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
    readonly property var wifiDevice: Networking.devices.values.find(
        device => device.type === DeviceType.Wifi) || null
    readonly property var activeWifi: wifiDevice
        ? wifiDevice.networks.values.find(network => network.connected) || null : null
    readonly property var wiredDevice: Networking.devices.values.find(
        device => device.type === DeviceType.Wired && device.connected) || null
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter

    StatusCommand { id: pomodoroStatus; command: ["pomodoro", "status"]; interval: 1000 }
    StatusCommand { id: layoutStatus; command: ["sway-layout", "status"]; interval: 2000 }
    StatusCommand { id: themeStatus; command: ["theme-toggle", "status"]; interval: 5000 }
    StatusCommand { id: caffeineStatus; command: ["caffeine-toggle", "status"]; interval: 5000 }
    StatusCommand { id: systemStatsStatus; command: ["system-stats"]; interval: 2000 }

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

    function networkIcon() {
        if (wiredDevice) return "󰈀";
        if (!wifiDevice || !Networking.wifiEnabled) return "󰤮";
        if (!activeWifi) return "󰤯";
        const signal = activeWifi.signalStrength;
        if (signal < 0.25) return "󰤟";
        if (signal < 0.5) return "󰤢";
        if (signal < 0.75) return "󰤥";
        return "󰤨";
    }

    function isManagedTrayItem(item) {
        const identity = (item.id + " " + item.title).toLowerCase();
        return identity.indexOf("nm-applet") >= 0
            || identity.indexOf("networkmanager") >= 0
            || identity.indexOf("blueman") >= 0;
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
            property bool systemStatsShown: false
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

            function showSystemStats() {
                systemStatsClose.stop();
                systemStatsOpen.restart();
            }

            function scheduleSystemStatsClose() {
                systemStatsOpen.stop();
                systemStatsClose.restart();
            }

            Timer {
                id: systemStatsOpen
                interval: 120
                onTriggered: window.systemStatsShown = true
            }

            Timer {
                id: systemStatsClose
                interval: 280
                onTriggered: {
                    const panelHovered = systemStatsLoader.item && systemStatsLoader.item.hovered;
                    if (!systemStatsButton.hovered && !panelHovered)
                        window.systemStatsShown = false;
                }
            }

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

                    StatusButton {
                        id: systemStatsButton
                        height: statusArea.height
                        text: systemStatsStatus.data.text
                        tooltip: systemStatsStatus.data.tooltip
                        foregroundColor: {
                            const peak = Math.max(Number(systemStatsStatus.data.cpu || 0),
                                Number(systemStatsStatus.data.memory || 0),
                                Number(systemStatsStatus.data.disk || 0));
                            return peak >= 90 ? Theme.danger : peak >= 75 ? Theme.warning : Theme.accent;
                        }
                        onHoveredChanged: {
                            if (hovered) window.showSystemStats();
                            else window.scheduleSystemStatsClose();
                        }
                        onPrimaryClicked: {
                            window.systemStatsShown = false;
                            root.run(["system-monitor"]);
                        }
                    }

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

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.controller.togglePopupOnScreen("audio", window.screen)
                        }
                    }

                    StatusButton {
                        id: networkButton
                        height: statusArea.height
                        text: root.networkIcon()
                            + (root.activeWifi ? " " + root.activeWifi.name : "")
                        foregroundColor: root.activeWifi || root.wiredDevice ? Theme.success : Theme.muted
                        onPrimaryClicked: root.controller.togglePopupOnScreen("network", window.screen)
                        onSecondaryClicked: root.controller.togglePopupOnScreen("network", window.screen)
                    }

                    StatusButton {
                        id: bluetoothButton
                        height: statusArea.height
                        text: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? "󰂯" : "󰂲"
                        foregroundColor: Bluetooth.devices.count > 0 ? Theme.accent : Theme.muted
                        onPrimaryClicked: root.controller.togglePopupOnScreen("bluetooth", window.screen)
                        onSecondaryClicked: root.controller.togglePopupOnScreen("bluetooth", window.screen)
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
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.controller.togglePopupOnScreen("battery", window.screen)
                        }
                    }

                    Repeater {
                        model: SystemTray.items

                        Rectangle {
                            id: trayButton
                            required property var modelData
                            visible: !root.isManagedTrayItem(modelData)
                            width: visible ? 30 : 0
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
                        onPrimaryClicked: root.controller.togglePopupOnScreen("pomodoro", window.screen)
                        onSecondaryClicked: root.run(["pomodoro", "toggle"])
                    }

                    StatusButton {
                        height: statusArea.height
                        text: layoutStatus.data.text
                        tooltip: layoutStatus.data.tooltip
                        foregroundColor: Theme.accent
                        onPrimaryClicked: root.controller.togglePopupOnScreen("tiling", window.screen)
                        onSecondaryClicked: root.controller.togglePopupOnScreen("tiling", window.screen)
                    }

                    StatusButton {
                        height: statusArea.height
                        text: ""
                        tooltip: "Clipboard history"
                        foregroundColor: Theme.accent
                        onPrimaryClicked: root.controller.togglePopupOnScreen("clipboard", window.screen)
                        onSecondaryClicked: root.controller.togglePopupOnScreen("clipboard", window.screen)
                    }

                    StatusButton {
                        height: statusArea.height
                        text: themeStatus.data.text
                        tooltip: themeStatus.data.tooltip
                        foregroundColor: Theme.purple
                        onPrimaryClicked: root.controller.togglePopupOnScreen("theme", window.screen)
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
                        onPrimaryClicked: root.controller.togglePopupOnScreen("power", window.screen)
                        onSecondaryClicked: root.controller.togglePopupOnScreen("power", window.screen)
                    }
                }

                LazyLoader {
                    id: systemStatsLoader
                    active: window.systemStatsShown
                    SystemStatsPopover {
                        shown: true
                        barScreen: window.screen
                        stats: systemStatsStatus.data
                        rightOffset: Math.max(8,
                            statusArea.width - systemStatsButton.x - systemStatsButton.width)
                    }
                }

                Connections {
                    target: systemStatsLoader.item
                    function onHoveredChanged() {
                        if (target.hovered) systemStatsClose.stop();
                        else if (!systemStatsButton.hovered) systemStatsClose.restart();
                    }
                }

                LazyLoader {
                    active: root.controller.activePopup === "audio"
                        && root.controller.targetScreen === window.screen
                    AudioPopover {
                        controller: root.controller
                        barScreen: window.screen
                    }
                }
                LazyLoader {
                    active: root.controller.activePopup === "network"
                        && root.controller.targetScreen === window.screen
                    NetworkPopover {
                        controller: root.controller
                        barScreen: window.screen
                    }
                }
                LazyLoader {
                    active: root.controller.activePopup === "bluetooth"
                        && root.controller.targetScreen === window.screen
                    BluetoothPopover {
                        controller: root.controller
                        barScreen: window.screen
                    }
                }
                LazyLoader {
                    active: root.controller.activePopup === "battery"
                        && root.controller.targetScreen === window.screen
                    BatteryPopover {
                        controller: root.controller
                        barScreen: window.screen
                    }
                }
                LazyLoader {
                    active: root.controller.activePopup === "clipboard"
                        && root.controller.targetScreen === window.screen
                    ClipboardPopover {
                        controller: root.controller
                        barScreen: window.screen
                    }
                }
                LazyLoader {
                    active: root.controller.activePopup === "theme"
                        && root.controller.targetScreen === window.screen
                    ThemePopover {
                        controller: root.controller
                        barScreen: window.screen
                    }
                }
                LazyLoader {
                    active: root.controller.activePopup === "tiling"
                        && root.controller.targetScreen === window.screen
                    TilingPopover {
                        controller: root.controller
                        barScreen: window.screen
                    }
                }
                LazyLoader {
                    active: root.controller.activePopup === "pomodoro"
                        && root.controller.targetScreen === window.screen
                    PomodoroPopover {
                        controller: root.controller
                        barScreen: window.screen
                    }
                }
                LazyLoader {
                    active: root.controller.activePopup === "power"
                        && root.controller.targetScreen === window.screen
                    PowerPopover {
                        controller: root.controller
                        barScreen: window.screen
                    }
                }
            }
        }
    }
}
