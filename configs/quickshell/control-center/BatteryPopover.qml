import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Services.UPower

BarPopover {
    id: root
    popupName: "battery"
    title: "Battery"
    popupHeight: 250
    readonly property var battery: UPower.displayDevice
    readonly property real percentage: battery.ready ? battery.percentage * 100 : 0

    function duration(seconds) {
        if (seconds <= 0) return "Calculating…";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return hours > 0 ? hours + " h " + minutes + " min" : minutes + " min";
    }

    Label {
        Layout.fillWidth: true
        text: Math.round(root.percentage) + "%"
        color: root.percentage <= 15 ? Theme.danger : Theme.foreground
        font.pixelSize: 30
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
    }

    ThemeProgressBar {
        Layout.fillWidth: true
        from: 0
        to: 100
        value: root.percentage
        color: root.percentage <= 15 ? Theme.danger
            : root.percentage <= 30 ? Theme.orange : Theme.accent
        Accessible.name: "Battery charge"
    }

    Label {
        Layout.fillWidth: true
        text: UPower.onBattery ? "Discharging" : "Connected to power"
        color: Theme.secondary
        horizontalAlignment: Text.AlignHCenter
    }

    Label {
        Layout.fillWidth: true
        visible: root.battery.ready
        text: UPower.onBattery
            ? "Remaining: " + root.duration(root.battery.timeToEmpty)
            : root.battery.timeToFull > 0
                ? "Until full: " + root.duration(root.battery.timeToFull)
                : "Fully charged or not charging"
        color: Theme.secondary
        horizontalAlignment: Text.AlignHCenter
    }
}
