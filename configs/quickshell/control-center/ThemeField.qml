import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: root

    implicitHeight: 38
    leftPadding: 12
    rightPadding: 12
    color: Theme.foreground
    placeholderTextColor: Theme.muted
    selectionColor: Theme.accent
    selectedTextColor: Theme.selected

    background: Rectangle {
        radius: 7
        color: Theme.surface
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : Theme.border
    }
}
