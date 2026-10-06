import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

BarPopover {
    id: root
    popupName: "clipboard"
    title: "Clipboard history"
    popupHeight: 540

    property var entries: []
    property string errorMessage: ""
    property string pendingEntryId: ""
    readonly property string query: searchField.text.trim().toLowerCase()
    readonly property var filteredEntries: entries.filter(entry =>
        root.query.length === 0 || entry.searchText.indexOf(root.query) >= 0).slice(0, 100)

    function parseEntries(output) {
        return output.split("\n").filter(line => line.length > 0).map(line => {
            const separator = line.indexOf("\t");
            const id = separator >= 0 ? line.slice(0, separator) : line;
            const preview = separator >= 0 ? line.slice(separator + 1) : line;
            return {
                id: id,
                preview: preview,
                searchText: preview.toLowerCase()
            };
        });
    }

    function refresh() {
        root.errorMessage = "";
        if (!listProcess.running) listProcess.running = true;
    }

    function moveSelection(delta) {
        if (results.count === 0) return;
        results.currentIndex = Math.max(0, Math.min(results.count - 1,
            results.currentIndex + delta));
        results.positionViewAtIndex(results.currentIndex, ListView.Contain);
    }

    function restore(index) {
        if (restoreProcess.running || index < 0 || index >= root.filteredEntries.length) return;
        root.errorMessage = "";
        root.pendingEntryId = root.filteredEntries[index].id;
        restoreProcess.command = ["clipboard-history", "--restore", root.pendingEntryId];
        restoreProcess.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            searchField.text = "";
            results.currentIndex = 0;
            root.refresh();
            Qt.callLater(() => searchField.forceActiveFocus());
        }
    }

    ScriptModel {
        id: clipboardModel
        values: root.filteredEntries
        objectProp: "id"
    }

    Process {
        id: listProcess
        command: ["clipboard-history", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = root.parseEntries(text);
                results.currentIndex = root.entries.length > 0 ? 0 : -1;
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.errorMessage = "Could not load clipboard history.";
        }
    }

    Process {
        id: restoreProcess
        onExited: (code, status) => {
            if (code === 0) root.controller.closePopups();
            else root.errorMessage = "Could not restore the clipboard entry.";
            root.pendingEntryId = "";
        }
    }

    ThemeField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: "Search clipboard…"
        selectByMouse: true
        Accessible.name: "Clipboard search"
        Keys.priority: Keys.BeforeItem
        onTextChanged: {
            results.currentIndex = root.filteredEntries.length > 0 ? 0 : -1;
            results.positionViewAtBeginning();
        }
        onAccepted: root.restore(results.currentIndex)
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
    }

    Label {
        Layout.fillWidth: true
        visible: root.errorMessage.length > 0
        text: root.errorMessage
        color: Theme.danger
        wrapMode: Text.WordWrap
    }

    Label {
        Layout.fillWidth: true
        visible: listProcess.running
        text: "Loading clipboard history…"
        color: Theme.secondary
        horizontalAlignment: Text.AlignHCenter
    }

    ListView {
        id: results
        Layout.fillWidth: true
        Layout.fillHeight: true
        model: clipboardModel
        currentIndex: 0
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ThemeScrollBar { }

        delegate: Rectangle {
            id: clipboardRow
            required property var modelData
            required property int index
            width: ListView.view.width
            height: 52
            radius: 8
            color: ListView.isCurrentItem || rowMouse.containsMouse
                ? Theme.surface : "transparent"

            Label {
                anchors.fill: parent
                anchors.margins: 10
                text: clipboardRow.modelData.preview
                textFormat: Text.PlainText
                color: Theme.foreground
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !restoreProcess.running
                onClicked: {
                    results.currentIndex = clipboardRow.index;
                    root.restore(clipboardRow.index);
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: !listProcess.running && root.filteredEntries.length === 0
        text: root.entries.length === 0 ? "Clipboard history is empty" : "No matching entries"
        color: Theme.secondary
        horizontalAlignment: Text.AlignHCenter
    }

    Label {
        Layout.fillWidth: true
        text: "↑/↓ select  ·  Enter copy  ·  Esc close"
        color: Theme.muted
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }
}
