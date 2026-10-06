import QtQuick
import QtQuick.Controls.Basic

SpinBox {
    id: root

    implicitWidth: 112
    implicitHeight: 38
    editable: true

    contentItem: TextInput {
        z: 2
        text: root.displayText
        font: root.font
        color: root.enabled ? Theme.foreground : Theme.muted
        selectionColor: Theme.accent
        selectedTextColor: Theme.selected
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !root.editable
        validator: root.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
    }

    up.indicator: Rectangle {
        x: root.mirrored ? 0 : parent.width - width
        height: parent.height
        implicitWidth: 30
        color: root.up.pressed ? Theme.border
            : root.up.hovered ? Theme.surface : "transparent"
        Text {
            anchors.centerIn: parent
            text: "+"
            color: root.value < root.to ? Theme.foreground : Theme.muted
            font.pixelSize: 15
        }
    }

    down.indicator: Rectangle {
        x: root.mirrored ? parent.width - width : 0
        height: parent.height
        implicitWidth: 30
        color: root.down.pressed ? Theme.border
            : root.down.hovered ? Theme.surface : "transparent"
        Text {
            anchors.centerIn: parent
            text: "\u2212"
            color: root.value > root.from ? Theme.foreground : Theme.muted
            font.pixelSize: 15
        }
    }

    background: Rectangle {
        radius: 7
        color: Theme.surface
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : Theme.border
    }
}
