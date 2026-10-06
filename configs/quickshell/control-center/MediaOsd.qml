import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window
    required property var controller
    readonly property bool brightness: controller.osdKind === "brightness"
    readonly property var node: controller.osdKind === "microphone" ? controller.source : controller.sink
    readonly property bool available: brightness ? controller.brightnessAvailable : !!node && !!node.audio
    readonly property bool muted: !brightness && available && node.audio.muted
    readonly property real level: available ? (brightness ? controller.brightness : node.audio.volume) : 0
    visible: controller.osdKind !== "" && !controller.panelOpen
    screen: controller.targetScreen
    anchors.bottom: true
    margins.bottom: 64
    implicitWidth: 320
    implicitHeight: 84
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "dotfiles-media-osd"
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
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: window.brightness ? "Brightness" : (window.controller.osdKind === "microphone" ? "Microphone" : "Volume")
                    color: Theme.foreground
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: !window.available ? "Unavailable" : window.muted ? "Muted" : Math.round(window.level * 100) + "%"
                    color: window.muted ? Theme.danger : Theme.secondary
                    font.pixelSize: 14
                }
            }
            ThemeProgressBar {
                Layout.fillWidth: true
                value: window.muted ? 0 : Math.min(1, Math.max(0, window.level))
            }
        }
    }
}
