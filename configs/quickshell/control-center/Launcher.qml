import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var controller
    visible: controller.activePopup === "launcher"
    screen: controller.targetScreen
    anchors { top: true; right: true; bottom: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    aboveWindows: true
    focusable: true
    WlrLayershell.namespace: "dotfiles-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property string query: searchField.text.trim().toLowerCase()
    readonly property var filteredEntries: {
        const entries = root.uniqueEntries(DesktopEntries.applications.values);
        const needle = root.query;
        entries.sort((left, right) => {
            const difference = root.score(left, needle) - root.score(right, needle);
            return difference !== 0 ? difference
                : String(left.name).localeCompare(String(right.name));
        });
        return entries.filter(entry => root.score(entry, needle) < 1000).slice(0, 60);
    }

    function uniqueEntries(entries) {
        const seen = {};
        return entries.filter(entry => {
            const name = String(entry.name || "").trim().toLowerCase();
            const key = name.length > 0 ? "name:" + name : "id:" + entry.id;
            if (seen[key]) return false;
            seen[key] = true;
            return true;
        });
    }

    function searchableText(entry) {
        return [entry.name, entry.genericName, entry.comment, entry.id,
            entry.keywords ? entry.keywords.join(" ") : ""].join(" ").toLowerCase();
    }

    function score(entry, needle) {
        if (needle.length === 0) return 10;
        const name = String(entry.name || "").toLowerCase();
        const genericName = String(entry.genericName || "").toLowerCase();
        if (name === needle) return 0;
        if (name.startsWith(needle)) return 1;
        if (name.split(/\s+/).some(word => word.startsWith(needle))) return 2;
        if (name.indexOf(needle) >= 0) return 3;
        if (genericName.startsWith(needle)) return 4;
        return root.searchableText(entry).indexOf(needle) >= 0 ? 5 : 1000;
    }

    function moveSelection(delta) {
        if (results.count === 0) return;
        results.currentIndex = Math.max(0, Math.min(results.count - 1,
            results.currentIndex + delta));
        results.positionViewAtIndex(results.currentIndex, ListView.Contain);
    }

    function launch(index) {
        if (index < 0 || index >= root.filteredEntries.length) return;
        const entry = root.filteredEntries[index];
        root.controller.closePopups();
        entry.execute();
    }

    onVisibleChanged: {
        if (visible) {
            searchField.text = "";
            results.currentIndex = 0;
            Qt.callLater(() => searchField.forceActiveFocus());
        }
    }

    ScriptModel {
        id: applicationModel
        values: root.filteredEntries
        objectProp: "id"
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.38)

        MouseArea {
            anchors.fill: parent
            onClicked: root.controller.closePopups()
        }
    }

    Rectangle {
        id: card
        width: Math.min(760, parent.width - 40)
        height: Math.min(610, parent.height - 100)
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 70 }
        radius: 14
        color: Theme.background
        border.color: Theme.border

        MouseArea {
            anchors.fill: parent
            onClicked: event => event.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Label {
                Layout.fillWidth: true
                text: "Applications"
                color: Theme.foreground
                font.pixelSize: 20
                font.bold: true
            }

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search applications…"
                selectByMouse: true
                Accessible.name: "Application search"
                onTextChanged: {
                    results.currentIndex = 0;
                    results.positionViewAtBeginning();
                }
                onAccepted: root.launch(results.currentIndex)
                Keys.onEscapePressed: root.controller.closePopups()
                Keys.onDownPressed: root.moveSelection(1)
                Keys.onUpPressed: root.moveSelection(-1)
            }

            ListView {
                id: results
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: applicationModel
                currentIndex: 0
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { }

                delegate: Rectangle {
                    id: applicationRow
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 62
                    radius: 8
                    color: ListView.isCurrentItem || rowMouse.containsMouse
                        ? Theme.surface : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Theme.border

                                Label {
                                    anchors.centerIn: parent
                                    text: "▦"
                                    color: Theme.secondary
                                    font.pixelSize: 20
                                }
                            }

                            Image {
                                anchors.fill: parent
                                source: Quickshell.iconPath(
                                    applicationRow.modelData.icon || "", true)
                                sourceSize { width: 40; height: 40 }
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                Layout.fillWidth: true
                                text: applicationRow.modelData.name
                                textFormat: Text.PlainText
                                color: Theme.foreground
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                text: applicationRow.modelData.comment
                                    || applicationRow.modelData.genericName
                                    || applicationRow.modelData.id
                                textFormat: Text.PlainText
                                color: Theme.secondary
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            results.currentIndex = applicationRow.index;
                            root.launch(applicationRow.index);
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                visible: results.count === 0
                text: "No matching applications"
                color: Theme.secondary
                horizontalAlignment: Text.AlignHCenter
            }

            Label {
                Layout.fillWidth: true
                text: "↑/↓ select  ·  Enter launch  ·  Esc close"
                color: Theme.muted
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
