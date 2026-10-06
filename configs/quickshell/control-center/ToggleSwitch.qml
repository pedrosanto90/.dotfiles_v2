import QtQuick
import QtQuick.Controls.Basic

Switch {
    id: root

    implicitWidth: 32
    implicitHeight: 18
    spacing: 0
    padding: 0

    indicator: Rectangle {
        implicitWidth: 32
        implicitHeight: 18
        x: 0
        y: Math.round((root.height - height) / 2)
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.border
        opacity: root.enabled ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            y: 2
            x: root.checked ? parent.width - width - 2 : 2
            color: root.checked ? Theme.selected : Theme.muted
            Behavior on x {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }
    }

    contentItem: Item { }
}
