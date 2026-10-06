import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

BarPopover {
    id: root
    popupName: "keybindings"
    title: "Keybindings"
    popupWidth: 980
    popupHeight: 680
    centered: true

    property string requestedScope: "all"
    property var entries: []
    property string errorMessage: ""
    readonly property string query: searchField.text.trim().toLowerCase()
    readonly property string selectedScope: ["sway", "tmux", "neovim"].indexOf(requestedScope) >= 0
        ? requestedScope : "all"
    readonly property var filteredEntries: entries.filter(entry =>
        (root.selectedScope === "all" || entry.scope === root.selectedScope)
        && (root.query.length === 0 || entry.searchText.indexOf(root.query) >= 0))

    function parseEntries(output) {
        return output.split("\n").filter(line => line.length > 0).map((line, index) => {
            const fields = line.split("\t");
            return {
                id: index + ":" + fields.join(":"),
                scope: fields[0] || "",
                category: fields[1] || "",
                keys: fields[2] || "",
                action: fields[3] || "",
                searchText: fields.join(" ").toLowerCase()
            };
        }).filter(entry => entry.scope.length > 0 && entry.action.length > 0);
    }

    function resetSelection() {
        results.currentIndex = root.filteredEntries.length > 0 ? 0 : -1;
        results.positionViewAtBeginning();
    }

    function moveSelection(delta) {
        if (results.count === 0) return;
        results.currentIndex = Math.max(0, Math.min(results.count - 1,
            results.currentIndex + delta));
        results.positionViewAtIndex(results.currentIndex, ListView.Contain);
    }

    onVisibleChanged: {
        if (visible) {
            searchField.text = "";
            root.errorMessage = "";
            root.resetSelection();
            if (!catalogProcess.running) catalogProcess.running = true;
            Qt.callLater(() => searchField.forceActiveFocus());
        }
    }
    onRequestedScopeChanged: {
        if (visible) root.resetSelection();
    }

    ScriptModel {
        id: entryModel
        values: root.filteredEntries
        objectProp: "id"
    }

    Process {
        id: catalogProcess
        command: ["keybindings", "--machine"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = root.parseEntries(text);
                root.resetSelection();
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.errorMessage = "Could not load the keybinding catalog.";
        }
    }

    ThemeField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: "Search keys, actions, categories, or applications…"
        selectByMouse: true
        Accessible.name: "Keybinding search"
        Keys.priority: Keys.BeforeItem
        onTextChanged: root.resetSelection()
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

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Label { Layout.preferredWidth: 80; text: "Scope"; color: Theme.muted; font.bold: true }
        Label { Layout.preferredWidth: 160; text: "Category"; color: Theme.muted; font.bold: true }
        Label { Layout.preferredWidth: 230; text: "Keys"; color: Theme.muted; font.bold: true }
        Label { Layout.fillWidth: true; text: "Action"; color: Theme.muted; font.bold: true }
    }

    ListView {
        id: results
        Layout.fillWidth: true
        Layout.fillHeight: true
        model: entryModel
        currentIndex: 0
        clip: true
        spacing: 3
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ThemeScrollBar { }

        delegate: Rectangle {
            id: bindingRow
            required property var modelData
            required property int index
            width: ListView.view.width
            height: 42
            radius: 7
            color: ListView.isCurrentItem || rowMouse.containsMouse
                ? Theme.surface : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 12

                Label {
                    Layout.preferredWidth: 72
                    text: bindingRow.modelData.scope.charAt(0).toUpperCase()
                        + bindingRow.modelData.scope.slice(1)
                    color: Theme.accent
                    elide: Text.ElideRight
                }
                Label {
                    Layout.preferredWidth: 160
                    text: bindingRow.modelData.category
                    textFormat: Text.PlainText
                    color: Theme.secondary
                    elide: Text.ElideRight
                }
                Label {
                    Layout.preferredWidth: 230
                    text: bindingRow.modelData.keys
                    textFormat: Text.PlainText
                    color: Theme.foreground
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: true
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: bindingRow.modelData.action
                    textFormat: Text.PlainText
                    color: Theme.foreground
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: results.currentIndex = bindingRow.index
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: !catalogProcess.running && root.filteredEntries.length === 0
        text: "No matching keybindings"
        color: Theme.secondary
        horizontalAlignment: Text.AlignHCenter
    }

    Label {
        Layout.fillWidth: true
        text: root.filteredEntries.length + " keybindings  ·  ↑/↓ select  ·  Esc close"
        color: Theme.muted
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }
}
