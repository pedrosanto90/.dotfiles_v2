import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

BarPopover {
    id: root
    popupName: "theme"
    title: "Theme"
    popupHeight: 560

    property var themes: []
    property string errorMessage: ""
    readonly property bool canToggleMode: Theme.themeId.indexOf("rose-pine-") !== 0
        && Theme.themeId.indexOf("nightfox-") !== 0
    readonly property string query: searchField.text.trim().toLowerCase()
    readonly property var filteredThemes: themes.filter(theme =>
        root.query.length === 0 || theme.searchText.indexOf(root.query) >= 0)

    function parseThemes(output) {
        return output.split("\n").filter(line => line.length > 0).map(line => {
            const fields = line.split("\t");
            return {
                id: fields[0] || "",
                label: fields[1] || fields[0] || "",
                mode: fields[2] || "",
                searchText: fields.join(" ").toLowerCase()
            };
        }).filter(theme => theme.id.length > 0);
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

    function apply(index) {
        if (applyProcess.running || index < 0 || index >= root.filteredThemes.length) return;
        root.errorMessage = "";
        applyProcess.command = ["theme-toggle", root.filteredThemes[index].id];
        applyProcess.running = true;
    }

    function toggleMode() {
        if (applyProcess.running) return;
        root.errorMessage = "";
        applyProcess.command = ["theme-toggle", "toggle"];
        applyProcess.running = true;
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
        id: themeModel
        values: root.filteredThemes
        objectProp: "id"
    }

    Process {
        id: listProcess
        command: ["theme-toggle", "list-machine"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.themes = root.parseThemes(text);
                const current = root.themes.findIndex(theme => theme.id === Theme.themeId);
                results.currentIndex = current >= 0 ? current : 0;
                if (results.currentIndex >= 0)
                    results.positionViewAtIndex(results.currentIndex, ListView.Center);
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.errorMessage = "Could not load the available themes.";
        }
    }

    Process {
        id: applyProcess
        onExited: (code, status) => {
            if (code === 0) root.controller.closePopups();
            else root.errorMessage = "Could not apply the selected theme.";
        }
    }

    TextField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: "Search themes…"
        selectByMouse: true
        Accessible.name: "Theme search"
        Keys.priority: Keys.BeforeItem
        onTextChanged: {
            results.currentIndex = root.filteredThemes.length > 0 ? 0 : -1;
            results.positionViewAtBeginning();
        }
        onAccepted: root.apply(results.currentIndex)
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

    ListView {
        id: results
        Layout.fillWidth: true
        Layout.fillHeight: true
        model: themeModel
        currentIndex: 0
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { }

        delegate: Rectangle {
            id: themeRow
            required property var modelData
            required property int index
            width: ListView.view.width
            height: 46
            radius: 8
            color: ListView.isCurrentItem || rowMouse.containsMouse
                ? Theme.surface : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    text: themeRow.modelData.label
                    textFormat: Text.PlainText
                    color: Theme.foreground
                    elide: Text.ElideRight
                }
                Label {
                    text: themeRow.modelData.id === Theme.themeId ? "●" : ""
                    color: Theme.accent
                }
                Label {
                    text: themeRow.modelData.mode === "light" ? "󰖨" : "󰖔"
                    color: Theme.secondary
                    font.family: "JetBrainsMono Nerd Font"
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !applyProcess.running
                onClicked: {
                    results.currentIndex = themeRow.index;
                    root.apply(themeRow.index);
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: !listProcess.running && root.filteredThemes.length === 0
        text: "No matching themes"
        color: Theme.secondary
        horizontalAlignment: Text.AlignHCenter
    }

    PopoverButton {
        Layout.fillWidth: true
        text: applyProcess.running ? "Applying…"
            : root.canToggleMode ? "Toggle light / dark" : "Dark-only theme family"
        enabled: !applyProcess.running && root.canToggleMode
        onClicked: root.toggleMode()
    }

    Label {
        Layout.fillWidth: true
        text: "↑/↓ select  ·  Enter apply  ·  Esc close"
        color: Theme.muted
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }
}
