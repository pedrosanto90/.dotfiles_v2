import QtQuick
import QtQuick.Controls.Basic

ProgressBar {
    id: root

    property color color: Theme.accent
    implicitHeight: 6

    background: Rectangle {
        implicitHeight: 6
        radius: 3
        color: Theme.border
    }

    contentItem: Item {
        implicitHeight: 6
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: 3
            color: root.enabled ? root.color : Theme.muted
            Behavior on width { NumberAnimation { duration: 100 } }
        }
    }
}
