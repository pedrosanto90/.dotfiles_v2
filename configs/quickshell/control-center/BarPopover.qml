import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var controller
    required property var barScreen
    required property string popupName
    required property string title
    property int popupWidth: 380
    property int popupHeight: 320
    default property alias content: contentColumn.data

    visible: controller.activePopup === popupName && controller.targetScreen === barScreen
    screen: barScreen
    anchors { top: true; right: true; bottom: true; left: true }
    margins.top: 30
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    aboveWindows: true
    focusable: true
    WlrLayershell.namespace: "dotfiles-" + popupName + "-popover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onVisibleChanged: {
        if (visible) focusScope.forceActiveFocus();
        else if (controller.activePopup === popupName) controller.closePopups();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.controller.closePopups()
    }

    Rectangle {
        id: card
        width: root.popupWidth
        height: Math.min(root.popupHeight, root.screen ? root.screen.height - 48 : root.popupHeight)
        anchors { top: parent.top; right: parent.right; topMargin: 6; rightMargin: 8 }
        radius: 12
        color: Theme.background
        border.color: Theme.border

        MouseArea {
            anchors.fill: parent
            onClicked: event => event.accepted = true
        }

        FocusScope {
            id: focusScope
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.controller.closePopups()

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: root.title
                        color: Theme.foreground
                        font.pixelSize: 16
                        font.bold: true
                    }
                    Button {
                        text: "Close"
                        onClicked: root.controller.closePopups()
                    }
                }
            }
        }
    }
}
