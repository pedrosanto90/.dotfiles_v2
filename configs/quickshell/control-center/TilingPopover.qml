import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

BarPopover {
    id: root
    popupName: "tiling"
    title: root.workspace.length > 0 ? "Tiling · Workspace " + root.workspace : "Tiling"
    popupWidth: 660
    popupHeight: 650

    property var presets: []
    property string workspace: ""
    property string selectedPreset: ""
    property string errorMessage: ""

    function previewRectangles(preset) {
        const rectangles = [];
        const count = Number(preset.count || 0);
        if (preset.id === "alternate") {
            let x = 0;
            let y = 0;
            let width = 1;
            let height = 1;
            for (let index = 0; index < count - 1; index++) {
                if (index % 2 === 0) {
                    width /= 2;
                    rectangles.push({number: index + 1, x: x, y: y,
                        width: width, height: height});
                    x += width;
                } else {
                    height /= 2;
                    rectangles.push({number: index + 1, x: x, y: y,
                        width: width, height: height});
                    y += height;
                }
            }
            rectangles.push({number: count, x: x, y: y, width: width, height: height});
            return rectangles;
        }

        if (preset.id === "master") {
            rectangles.push({number: 1, x: 0, y: 0, width: 0.5, height: 1});
            for (let index = 1; index < count; index++) {
                rectangles.push({number: index + 1, x: 0.5,
                    y: (index - 1) / (count - 1), width: 0.5, height: 1 / (count - 1)});
            }
            return rectangles;
        }

        const columns = Math.min(Number(preset.columns || 1), count);
        for (let index = 0; index < count; index++) {
            const column = index % columns;
            const row = Math.floor(index / columns);
            const rows = Math.ceil((count - column) / columns);
            rectangles.push({number: index + 1, x: column / columns, y: row / rows,
                width: 1 / columns, height: 1 / rows});
        }
        return rectangles;
    }

    function moveSelection(delta) {
        if (presetGrid.count === 0) return;
        presetGrid.currentIndex = Math.max(0, Math.min(presetGrid.count - 1,
            presetGrid.currentIndex + delta));
        presetGrid.positionViewAtIndex(presetGrid.currentIndex, GridView.Contain);
    }

    function apply(index) {
        if (applyProcess.running || index < 0 || index >= root.presets.length) return;
        root.errorMessage = "";
        applyProcess.command = ["sway-layout", "apply", root.presets[index].id];
        applyProcess.running = true;
    }

    function refresh() {
        root.errorMessage = "";
        if (!listProcess.running) listProcess.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            root.refresh();
            Qt.callLater(() => presetGrid.forceActiveFocus());
        }
    }

    ScriptModel {
        id: presetModel
        values: root.presets
        objectProp: "id"
    }

    Process {
        id: listProcess
        command: ["sway-layout", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.workspace = String(data.workspace || "");
                    root.selectedPreset = String(data.selected || "alternate");
                    root.presets = Array.isArray(data.presets) ? data.presets : [];
                    const current = root.presets.findIndex(
                        preset => preset.id === root.selectedPreset);
                    presetGrid.currentIndex = current >= 0 ? current : 0;
                    if (presetGrid.currentIndex >= 0)
                        presetGrid.positionViewAtIndex(presetGrid.currentIndex, GridView.Contain);
                } catch (error) {
                    root.errorMessage = "Could not parse the available layouts.";
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.errorMessage = "Could not load the available layouts.";
        }
    }

    Process {
        id: applyProcess
        onExited: (code, status) => {
            if (code === 0) root.controller.closePopups();
            else root.errorMessage = "Could not apply the selected layout.";
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.errorMessage.length > 0
        text: root.errorMessage
        color: Theme.danger
        wrapMode: Text.WordWrap
    }

    GridView {
        id: presetGrid
        Layout.fillWidth: true
        Layout.fillHeight: true
        model: presetModel
        currentIndex: 0
        cellWidth: width / 2
        cellHeight: 128
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: false
        Keys.priority: Keys.BeforeItem
        Keys.onEscapePressed: event => {
            root.controller.closePopups();
            event.accepted = true;
        }
        Keys.onLeftPressed: event => {
            root.moveSelection(-1);
            event.accepted = true;
        }
        Keys.onRightPressed: event => {
            root.moveSelection(1);
            event.accepted = true;
        }
        Keys.onUpPressed: event => {
            root.moveSelection(-2);
            event.accepted = true;
        }
        Keys.onDownPressed: event => {
            root.moveSelection(2);
            event.accepted = true;
        }
        Keys.onReturnPressed: event => {
            root.apply(presetGrid.currentIndex);
            event.accepted = true;
        }
        Keys.onEnterPressed: event => {
            root.apply(presetGrid.currentIndex);
            event.accepted = true;
        }

        delegate: Item {
            id: presetCell
            required property var modelData
            required property int index
            width: presetGrid.cellWidth
            height: presetGrid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 10
                color: presetCell.index === presetGrid.currentIndex || cellMouse.containsMouse
                    ? Theme.surface : "transparent"
                border.width: presetCell.modelData.id === root.selectedPreset ? 2 : 1
                border.color: presetCell.modelData.id === root.selectedPreset
                    ? Theme.accent : Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        id: preview
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 94
                        radius: 7
                        color: Theme.background
                        border.color: Theme.border

                        Repeater {
                            model: root.previewRectangles(presetCell.modelData)

                            Rectangle {
                                required property var modelData
                                x: 5 + modelData.x * (preview.width - 10)
                                y: 5 + modelData.y * (preview.height - 10)
                                width: modelData.width * (preview.width - 10) - 3
                                height: modelData.height * (preview.height - 10) - 3
                                radius: 2
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                border.color: Theme.accent

                                Label {
                                    anchors.centerIn: parent
                                    visible: parent.width > 18 && parent.height > 15
                                    text: parent.modelData.number
                                    color: Theme.foreground
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label {
                            Layout.fillWidth: true
                            text: presetCell.modelData.label
                                + (presetCell.modelData.id === root.selectedPreset ? "  ✓" : "")
                            color: Theme.foreground
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: presetCell.modelData.description
                            color: Theme.secondary
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !applyProcess.running
                    onClicked: {
                        presetGrid.currentIndex = presetCell.index;
                        root.apply(presetCell.index);
                    }
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: listProcess.running
        text: "Loading layouts…"
        color: Theme.secondary
        horizontalAlignment: Text.AlignHCenter
    }

    Label {
        Layout.fillWidth: true
        text: applyProcess.running ? "Applying layout…"
            : "←/→/↑/↓ select  ·  Enter apply  ·  Esc close"
        color: Theme.muted
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }
}
