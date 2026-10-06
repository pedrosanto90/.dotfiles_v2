import QtQuick
import QtQuick.Controls.Basic

Button {
    id: root
    property bool dangerous: false

    implicitHeight: 38
    implicitWidth: Math.max(78, contentItem.implicitWidth + 24)

    contentItem: Label {
        text: root.text
        textFormat: Text.PlainText
        color: !root.enabled ? Theme.muted
            : root.dangerous ? Theme.danger : Theme.foreground
        font: root.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 7
        color: root.pressed ? Theme.border
            : root.highlighted
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                : root.hovered ? Theme.border : Theme.surface
        border.color: root.highlighted ? Theme.accent : Theme.border
        opacity: root.enabled ? 1 : 0.65
    }
}
