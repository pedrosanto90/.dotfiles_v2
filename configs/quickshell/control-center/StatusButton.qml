import QtQuick

Rectangle {
    id: root
    property string text: ""
    property string tooltip: ""
    property color foregroundColor: Theme.foreground
    signal primaryClicked()
    signal secondaryClicked()

    visible: text.length > 0
    width: visible ? label.implicitWidth + 18 : 0
    color: "transparent"

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.foregroundColor
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) root.secondaryClicked();
            else root.primaryClicked();
        }
    }
}
