import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

BarPopover {
    id: root
    popupName: "power"
    title: "Power"
    popupWidth: 400
    popupHeight: 400
    centered: true
    compactCloseButton: true

    readonly property var actions: [
        {id: "lock", icon: "󰌾", label: "Lock", description: "Lock the current session", dangerous: false},
        {id: "suspend", icon: "󰒲", label: "Suspend", description: "Lock and suspend the computer", dangerous: false},
        {id: "reboot", icon: "󰜉", label: "Reboot", description: "Restart the computer", dangerous: true},
        {id: "poweroff", icon: "", label: "Power off", description: "Shut down the computer", dangerous: true}
    ]
    property string pendingAction: ""
    property string errorMessage: ""

    function actionById(actionId) {
        return root.actions.find(action => action.id === actionId) || null;
    }

    function moveSelection(delta) {
        actionList.currentIndex = Math.max(0, Math.min(actionList.count - 1,
            actionList.currentIndex + delta));
        actionList.positionViewAtIndex(actionList.currentIndex, ListView.Contain);
    }

    function request(index) {
        if (actionProcess.running || index < 0 || index >= root.actions.length) return;
        const action = root.actions[index];
        root.errorMessage = "";
        if (action.dangerous) {
            root.pendingAction = action.id;
            Qt.callLater(() => confirmation.forceActiveFocus());
        } else root.execute(action.id);
    }

    function execute(actionId) {
        if (actionProcess.running || !root.actionById(actionId)) return;
        root.errorMessage = "";
        actionProcess.command = ["power-menu", "execute", actionId];
        actionProcess.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            root.pendingAction = "";
            root.errorMessage = "";
            actionList.currentIndex = 0;
            Qt.callLater(() => actionList.forceActiveFocus());
        }
    }

    Process {
        id: actionProcess
        onExited: (code, status) => {
            if (code === 0) root.controller.closePopups();
            else root.errorMessage = "Could not perform the selected power action.";
        }
    }

    ListView {
        id: actionList
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.pendingAction.length === 0
        model: root.actions
        currentIndex: 0
        clip: true
        spacing: 5
        boundsBehavior: Flickable.StopAtBounds
        Keys.priority: Keys.BeforeItem
        Keys.onEscapePressed: event => {
            root.controller.closePopups();
            event.accepted = true;
        }
        Keys.onDownPressed: event => {
            root.moveSelection(1);
            event.accepted = true;
        }
        Keys.onUpPressed: event => {
            root.moveSelection(-1);
            event.accepted = true;
        }
        Keys.onReturnPressed: event => {
            root.request(actionList.currentIndex);
            event.accepted = true;
        }
        Keys.onEnterPressed: event => {
            root.request(actionList.currentIndex);
            event.accepted = true;
        }

        delegate: Rectangle {
            id: actionRow
            required property var modelData
            required property int index
            width: ListView.view.width
            height: 62
            radius: 8
            color: actionRow.index === actionList.currentIndex || rowMouse.containsMouse
                ? Theme.surface : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 14
                Label {
                    text: actionRow.modelData.icon
                    color: actionRow.modelData.dangerous ? Theme.danger : Theme.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        Layout.fillWidth: true
                        text: actionRow.modelData.label
                        color: Theme.foreground
                        font.bold: true
                    }
                    Label {
                        Layout.fillWidth: true
                        text: actionRow.modelData.description
                        color: Theme.secondary
                        font.pixelSize: 11
                    }
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !actionProcess.running
                onClicked: {
                    actionList.currentIndex = actionRow.index;
                    root.request(actionRow.index);
                }
            }
        }
    }

    ColumnLayout {
        id: confirmation
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.pendingAction.length > 0
        focus: visible
        spacing: 14
        Keys.priority: Keys.BeforeItem
        Keys.onEscapePressed: event => {
            root.pendingAction = "";
            Qt.callLater(() => actionList.forceActiveFocus());
            event.accepted = true;
        }
        Keys.onReturnPressed: event => {
            root.execute(root.pendingAction);
            event.accepted = true;
        }
        Keys.onEnterPressed: event => {
            root.execute(root.pendingAction);
            event.accepted = true;
        }

        Item { Layout.fillHeight: true }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: {
                const action = root.actionById(root.pendingAction);
                return action ? action.icon : "";
            }
            color: Theme.danger
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 42
        }
        Label {
            Layout.fillWidth: true
            text: {
                const action = root.actionById(root.pendingAction);
                return action ? action.label + " the computer?" : "";
            }
            color: Theme.foreground
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
        Label {
            Layout.fillWidth: true
            text: "This action will end the current session."
            color: Theme.secondary
            horizontalAlignment: Text.AlignHCenter
        }
        RowLayout {
            Layout.fillWidth: true
            Button {
                Layout.fillWidth: true
                text: "Cancel"
                onClicked: {
                    root.pendingAction = "";
                    Qt.callLater(() => actionList.forceActiveFocus());
                }
            }
            Button {
                Layout.fillWidth: true
                text: "Confirm"
                enabled: !actionProcess.running
                onClicked: root.execute(root.pendingAction)
            }
        }
        Item { Layout.fillHeight: true }
    }

    Label {
        Layout.fillWidth: true
        visible: root.errorMessage.length > 0
        text: root.errorMessage
        color: Theme.danger
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    Label {
        Layout.fillWidth: true
        visible: root.pendingAction.length === 0
        text: "↑/↓ select  ·  Enter continue  ·  Esc close"
        color: Theme.muted
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }
}
