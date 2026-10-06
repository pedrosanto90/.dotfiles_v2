import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Io

BarPopover {
    id: root
    popupName: "calendar"
    title: "Calendar"
    popupWidth: 720
    popupHeight: 570
    centered: true

    property date displayedMonth: new Date()
    property date selectedDate: new Date()
    property var events: []
    property bool editing: false
    property string editingId: ""
    property string errorMessage: ""
    readonly property var reminderValues: [-1, 0, 5, 10, 15, 30, 60, 1440]
    readonly property var selectedEvents: events.filter(event =>
        event.date === root.dateKey(root.selectedDate))

    function dateKey(value) {
        return Qt.formatDate(value, "yyyy-MM-dd");
    }

    function monthKey() {
        return displayedMonth.getFullYear() + "-"
            + String(displayedMonth.getMonth() + 1).padStart(2, "0");
    }

    function selectToday() {
        const today = new Date();
        displayedMonth = new Date(today.getFullYear(), today.getMonth(), 1);
        selectedDate = today;
        refresh();
    }

    function shiftMonth(delta) {
        displayedMonth = new Date(displayedMonth.getFullYear(),
            displayedMonth.getMonth() + delta, 1);
        selectedDate = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth(), 1);
        cancelEdit();
        refresh();
    }

    function refresh() {
        if (!listProcess.running && !actionProcess.running) {
            listProcess.command = ["local-calendar", "list", "--month", monthKey()];
            listProcess.running = true;
        }
    }

    function reminderLabel(minutes) {
        if (minutes < 0) return "No alert";
        if (minutes === 0) return "At event time";
        if (minutes === 1440) return "1 day before";
        if (minutes === 60) return "1 hour before";
        return minutes + " min before";
    }

    function beginAdd() {
        editing = true;
        editingId = "";
        titleField.text = "";
        timeField.text = "09:00";
        reminderBox.currentIndex = 4;
        errorMessage = "";
        titleField.forceActiveFocus();
    }

    function beginEdit(event) {
        editing = true;
        editingId = event.id;
        titleField.text = event.title;
        timeField.text = event.time;
        reminderBox.currentIndex = Math.max(0, reminderValues.indexOf(event.reminder));
        errorMessage = "";
        titleField.forceActiveFocus();
    }

    function cancelEdit() {
        editing = false;
        editingId = "";
        errorMessage = "";
    }

    function saveEvent() {
        const title = titleField.text.trim();
        const time = timeField.text.trim();
        if (!title) {
            errorMessage = "Add a title.";
            return;
        }
        if (!/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(time)) {
            errorMessage = "Use a 24-hour time such as 09:30.";
            return;
        }
        const command = ["local-calendar", editingId ? "update" : "add"];
        if (editingId) command.push(editingId);
        command.push("--title", title, "--date", dateKey(selectedDate),
            "--time", time, "--reminder", String(reminderValues[reminderBox.currentIndex]));
        runAction(command);
    }

    function deleteEvent(id) {
        runAction(["local-calendar", "delete", id]);
    }

    function runAction(command) {
        if (actionProcess.running) return;
        errorMessage = "";
        actionProcess.command = command;
        actionProcess.running = true;
    }

    onVisibleChanged: if (visible) selectToday()

    Process {
        id: listProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim() || "[]");
                    root.events = Array.isArray(parsed) ? parsed : [];
                    root.errorMessage = "";
                } catch (error) {
                    root.errorMessage = "Could not read calendar events.";
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.errorMessage = "Could not read calendar events.";
        }
    }

    Process {
        id: actionProcess
        onExited: (code, status) => {
            if (code === 0) {
                root.cancelEdit();
                root.refresh();
            } else {
                root.errorMessage = "Could not save the calendar change.";
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 14

        ColumnLayout {
            Layout.preferredWidth: 390
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                IconButton { text: "‹"; Accessible.name: "Previous month"; onClicked: root.shiftMonth(-1) }
                Label {
                    Layout.fillWidth: true
                    text: monthGrid.title
                    color: Theme.foreground
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                PopoverButton { text: "Today"; onClicked: root.selectToday() }
                IconButton { text: "›"; Accessible.name: "Next month"; onClicked: root.shiftMonth(1) }
            }

            DayOfWeekRow {
                Layout.fillWidth: true
                locale: monthGrid.locale
                delegate: Label {
                    required property string shortName
                    text: shortName
                    color: Theme.secondary
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Item { }
            }

            MonthGrid {
                id: monthGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                month: root.displayedMonth.getMonth()
                year: root.displayedMonth.getFullYear()
                locale: Qt.locale()
                spacing: 3
                background: Item { }
                onClicked: date => {
                    if (date.getMonth() !== root.displayedMonth.getMonth()) {
                        root.displayedMonth = new Date(date.getFullYear(), date.getMonth(), 1);
                        root.refresh();
                    }
                    root.selectedDate = date;
                    root.cancelEdit();
                }

                delegate: Rectangle {
                    id: dayCell
                    required property var model
                    readonly property string key: root.dateKey(model.date)
                    readonly property int eventCount: root.events.filter(event => event.date === key).length
                    readonly property bool selected: key === root.dateKey(root.selectedDate)
                    radius: 7
                    color: selected ? Theme.accent
                        : cellMouse.containsMouse ? Theme.border : "transparent"
                    opacity: model.month === monthGrid.month ? 1 : 0.35

                    Label {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: dayCell.eventCount > 0 ? -4 : 0
                        text: dayCell.model.day
                        color: dayCell.selected ? Theme.selected
                            : dayCell.model.today ? Theme.accent : Theme.foreground
                        font.bold: dayCell.model.today || dayCell.selected
                    }
                    Row {
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 5 }
                        spacing: 2
                        Repeater {
                            model: Math.min(dayCell.eventCount, 3)
                            Rectangle {
                                width: 4; height: 4; radius: 2
                                color: dayCell.selected ? Theme.selected : Theme.accent
                            }
                        }
                    }
                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: monthGrid.clicked(dayCell.model.date)
                    }
                }
            }
        }

        Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.border }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: Qt.formatDate(root.selectedDate, "dddd, d MMMM")
                    color: Theme.foreground
                    font.bold: true
                    elide: Text.ElideRight
                }
                PopoverButton {
                    text: "+ Event"
                    enabled: !root.editing
                    onClicked: root.beginAdd()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.editing
                spacing: 7
                ThemeField {
                    id: titleField
                    Layout.fillWidth: true
                    placeholderText: "Event title"
                    onAccepted: root.saveEvent()
                }
                ThemeField {
                    id: timeField
                    Layout.fillWidth: true
                    placeholderText: "HH:MM"
                    inputMethodHints: Qt.ImhTime
                    onAccepted: root.saveEvent()
                }
                ThemeComboBox {
                    id: reminderBox
                    Layout.fillWidth: true
                    model: ["No alert", "At event time", "5 minutes before", "10 minutes before",
                        "15 minutes before", "30 minutes before", "1 hour before", "1 day before"]
                    Accessible.name: "Reminder"
                }
                RowLayout {
                    Layout.fillWidth: true
                    PopoverButton { Layout.fillWidth: true; text: "Cancel"; onClicked: root.cancelEdit() }
                    PopoverButton {
                        Layout.fillWidth: true
                        text: actionProcess.running ? "Saving…" : "Save"
                        enabled: !actionProcess.running
                        highlighted: true
                        onClicked: root.saveEvent()
                    }
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
                Layout.fillHeight: true
                visible: !root.editing && root.selectedEvents.length === 0
                text: "No events for this day."
                color: Theme.secondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.editing && root.selectedEvents.length > 0
                clip: true
                contentWidth: availableWidth
                ScrollBar.vertical: ThemeScrollBar { }

                Column {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: root.selectedEvents
                        Rectangle {
                            id: eventRow
                            required property var modelData
                            width: parent.width
                            height: 66
                            radius: 8
                            color: Theme.surface
                            border.color: Theme.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 7
                                Label {
                                    text: eventRow.modelData.time
                                    color: Theme.accent
                                    font.bold: true
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label {
                                        Layout.fillWidth: true
                                        text: eventRow.modelData.title
                                        textFormat: Text.PlainText
                                        color: Theme.foreground
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        text: root.reminderLabel(eventRow.modelData.reminder)
                                        color: Theme.secondary
                                        font.pixelSize: 11
                                    }
                                }
                                IconButton {
                                    text: "󰏫"
                                    Accessible.name: "Edit event"
                                    onClicked: root.beginEdit(eventRow.modelData)
                                }
                                IconButton {
                                    text: "󰆴"
                                    dangerous: true
                                    Accessible.name: "Delete event"
                                    onClicked: root.deleteEvent(eventRow.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
