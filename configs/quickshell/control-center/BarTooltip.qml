import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var barScreen
    property string text: ""
    property int rightOffset: 8

    visible: text.length > 0
    screen: barScreen
    anchors { top: true; right: true }
    margins { top: 5; right: root.rightOffset }
    implicitWidth: tipText.implicitWidth + 16
    implicitHeight: 26
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}
    aboveWindows: true
    focusable: false
    WlrLayershell.namespace: "dotfiles-bar-tooltip"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Theme.background
        border.color: Theme.border

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.text
            color: Theme.foreground
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
        }
    }
}
