import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string title
    property string detail
    property real level: 0
    property real minimum: 0
    property bool available: true
    property bool muted: false
    property bool canMute: true
    signal adjusted(real value)
    signal muteRequested()
    spacing: 3

    RowLayout {
        Layout.fillWidth: true
        Label { text: root.title; color: Theme.foreground; font.bold: true; Layout.fillWidth: true }
        Label { text: root.available ? Math.round(root.level * 100) + "%" : "Unavailable"; color: Theme.secondary }
        PopoverButton {
            visible: root.canMute
            enabled: root.available
            text: root.muted ? "Unmute" : "Mute"
            onClicked: root.muteRequested()
        }
    }
    Label {
        Layout.fillWidth: true
        visible: text.length > 0
        text: root.detail
        textFormat: Text.PlainText
        color: Theme.secondary
        font.pixelSize: 12
        elide: Text.ElideRight
    }
    MediaSlider {
        Layout.fillWidth: true
        enabled: root.available
        from: root.minimum
        to: 1
        stepSize: 0.01
        value: root.level
        onMoved: root.adjusted(value)
        Accessible.name: root.title
    }
}
