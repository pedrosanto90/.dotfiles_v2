import QtQuick
import QtQuick.Controls.Basic

Slider {
    id: control
    implicitHeight: 30
    opacity: enabled ? 1 : 0.4
    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 5
        radius: 3
        color: Theme.border
        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 3
            color: Theme.accent
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 16
        height: 16
        radius: 8
        color: control.pressed ? Theme.foreground : Theme.accent
        border.width: control.visualFocus ? 2 : 0
        border.color: Theme.foreground
    }
}
