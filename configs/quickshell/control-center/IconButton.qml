import QtQuick
import QtQuick.Controls.Basic

Button {
    id: root
    property color glyphColor: Theme.muted
    property color activeColor: Theme.foreground
    property bool dangerous: false
    property int glyphSize: 15

    implicitWidth: 30
    implicitHeight: 30
    padding: 0

    contentItem: Label {
        text: root.text
        color: !root.enabled ? Theme.muted
            : root.dangerous ? Theme.danger
            : root.hovered || root.visualFocus ? root.activeColor : root.glyphColor
        font.pixelSize: root.glyphSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: 6
        color: root.pressed ? Theme.border
            : root.hovered ? Theme.surface : "transparent"
    }
}
