import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Button {
    id: root
    property string glyph
    property string subtitle
    property bool active: false
    property bool detailsAvailable: false
    signal detailsRequested()

    implicitHeight: 62
    padding: 9

    contentItem: RowLayout {
        spacing: 9

        Label {
            text: root.glyph
            color: root.active ? Theme.selected : Theme.secondary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Label {
                Layout.fillWidth: true
                text: root.text
                textFormat: Text.PlainText
                color: root.active ? Theme.selected : Theme.foreground
                font.bold: true
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: root.subtitle
                textFormat: Text.PlainText
                color: root.active ? Theme.selected : Theme.secondary
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        IconButton {
            visible: root.detailsAvailable
            text: "›"
            glyphColor: root.active ? Theme.selected : Theme.secondary
            activeColor: root.active ? Theme.selected : Theme.foreground
            Accessible.name: root.text + " details"
            onClicked: root.detailsRequested()
        }
    }

    background: Rectangle {
        radius: 9
        color: root.active
            ? Theme.accent
            : root.pressed ? Theme.border
            : root.hovered ? Theme.border : Theme.surface
        border.color: root.active ? Theme.accent : Theme.border
        opacity: root.enabled ? 1 : 0.55
        Behavior on color { ColorAnimation { duration: 100 } }
    }
}
