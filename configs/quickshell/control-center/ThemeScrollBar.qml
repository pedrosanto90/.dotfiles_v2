import QtQuick
import QtQuick.Controls.Basic

ScrollBar {
    id: root

    policy: ScrollBar.AsNeeded
    implicitWidth: 6
    implicitHeight: 6
    minimumSize: 0.15

    contentItem: Rectangle {
        implicitWidth: 6
        implicitHeight: 6
        radius: 3
        color: root.pressed || root.hovered ? Theme.accent : Theme.border
    }

    background: Rectangle {
        implicitWidth: 6
        implicitHeight: 6
        color: "transparent"
    }
}
