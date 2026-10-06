import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: root

    implicitHeight: 38

    contentItem: Label {
        leftPadding: 12
        rightPadding: root.indicator.width + 12
        text: root.displayText
        textFormat: Text.PlainText
        color: root.enabled ? Theme.foreground : Theme.muted
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Label {
        x: root.width - width - 12
        y: (root.height - height) / 2
        text: "\u25be"
        color: Theme.muted
        font.pixelSize: 12
    }

    background: Rectangle {
        radius: 7
        color: Theme.surface
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : Theme.border
    }

    delegate: ItemDelegate {
        id: item
        required property var modelData
        required property int index
        width: root.width
        height: 36
        highlighted: root.highlightedIndex === item.index
        contentItem: Label {
            leftPadding: 12
            text: String(item.modelData)
            textFormat: Text.PlainText
            color: Theme.foreground
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            color: item.highlighted
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                : item.hovered ? Theme.surface : Theme.background
        }
    }

    popup: Popup {
        y: root.height + 2
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 240)
        padding: 4

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollBar.vertical: ThemeScrollBar { }
        }

        background: Rectangle {
            radius: 7
            color: Theme.background
            border.color: Theme.border
        }
    }
}
