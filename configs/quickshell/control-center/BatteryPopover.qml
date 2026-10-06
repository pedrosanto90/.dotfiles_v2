import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Services.UPower

BarPopover {
    id: root
    popupName: "battery"
    title: "Battery"
    popupHeight: 350
    readonly property var battery: UPower.displayDevice
    readonly property real percentage: battery.ready ? battery.percentage * 100 : 0

    function duration(seconds) {
        if (seconds <= 0) return "Calculating…";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return hours > 0 ? hours + " h " + minutes + " min" : minutes + " min";
    }

    function degradationText(reason) {
        if (reason === PerformanceDegradationReason.HighTemperature)
            return "Performance is limited due to high temperature.";
        if (reason === PerformanceDegradationReason.LapDetected)
            return "Performance is limited because the laptop is on your lap.";
        return "";
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

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.border
    }

    Label {
        Layout.fillWidth: true
        text: "Power profile"
        color: Theme.foreground
        font.bold: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        PopoverButton {
            Layout.fillWidth: true
            text: "Power saver"
            highlighted: PowerProfiles.profile === PowerProfile.PowerSaver
            onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
        }
        PopoverButton {
            Layout.fillWidth: true
            text: "Balanced"
            highlighted: PowerProfiles.profile === PowerProfile.Balanced
            onClicked: PowerProfiles.profile = PowerProfile.Balanced
        }
        PopoverButton {
            Layout.fillWidth: true
            text: "Performance"
            highlighted: PowerProfiles.profile === PowerProfile.Performance
            enabled: PowerProfiles.hasPerformanceProfile
            onClicked: PowerProfiles.profile = PowerProfile.Performance
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.degradationText(PowerProfiles.degradationReason).length > 0
        text: root.degradationText(PowerProfiles.degradationReason)
        color: Theme.warning
        wrapMode: Text.WordWrap
    }
}
