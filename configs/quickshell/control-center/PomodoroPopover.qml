import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

BarPopover {
    id: root
    popupName: "pomodoro"
    title: "Pomodoro"
    popupWidth: 440
    popupHeight: 520

    property string pomodoroState: "idle"
    property string phase: "idle"
    property int remaining: 0
    property int duration: 0
    property int sessions: 0
    property string errorMessage: ""
    property string statusMessage: ""
    property bool durationsInitialized: false
    readonly property bool busy: actionProcess.running || detailsProcess.running

    function formatTime(seconds) {
        const safe = Math.max(0, Number(seconds || 0));
        const hours = Math.floor(safe / 3600);
        const minutes = Math.floor((safe % 3600) / 60);
        const remainder = safe % 60;
        return hours > 0
            ? hours + ":" + String(minutes).padStart(2, "0")
                + ":" + String(remainder).padStart(2, "0")
            : String(minutes).padStart(2, "0") + ":"
                + String(remainder).padStart(2, "0");
    }

    function phaseLabel() {
        if (root.phase === "focus") return "Focus";
        if (root.phase === "short") return "Short break";
        if (root.phase === "long") return "Long break";
        return "Stopped";
    }

    function refresh() {
        if (!detailsProcess.running && !actionProcess.running)
            detailsProcess.running = true;
    }

    function runAction(action) {
        if (root.busy) return;
        root.errorMessage = "";
        root.statusMessage = "";
        actionProcess.command = ["pomodoro", action];
        actionProcess.running = true;
    }

    function saveDurations() {
        if (root.busy) return;
        root.errorMessage = "";
        root.statusMessage = "";
        actionProcess.command = ["pomodoro", "set-durations",
            String(focusDuration.value), String(shortDuration.value),
            String(longDuration.value)];
        actionProcess.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            root.durationsInitialized = false;
            root.refresh();
        }
    }

    Process {
        id: detailsProcess
        command: ["pomodoro", "details"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.pomodoroState = String(data.state || "idle");
                    root.phase = String(data.phase || "idle");
                    root.remaining = Number(data.remaining || 0);
                    root.duration = Number(data.duration || 0);
                    root.sessions = Number(data.sessions || 0);
                    if (!root.durationsInitialized) {
                        focusDuration.value = Number(data.focusDuration || 50);
                        shortDuration.value = Number(data.shortDuration || 10);
                        longDuration.value = Number(data.longDuration || 15);
                        root.durationsInitialized = true;
                    }
                } catch (error) {
                    root.errorMessage = "Could not parse the Pomodoro state.";
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.errorMessage = "Could not load the Pomodoro state.";
        }
    }

    Process {
        id: actionProcess
        onExited: (code, status) => {
            if (code === 0) {
                root.statusMessage = actionProcess.command[1] === "set-durations"
                    ? "Durations saved." : "";
                root.refresh();
            } else {
                root.errorMessage = "Could not update the Pomodoro timer.";
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }

    Label {
        Layout.fillWidth: true
        text: root.phaseLabel()
        color: root.pomodoroState === "running" ? Theme.success
            : root.pomodoroState === "break" ? Theme.accent
            : root.pomodoroState === "paused" ? Theme.orange : Theme.secondary
        font.pixelSize: 18
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
    }

    Label {
        Layout.fillWidth: true
        text: root.formatTime(root.remaining)
        color: Theme.foreground
        font.pixelSize: 44
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
    }

    ThemeProgressBar {
        Layout.fillWidth: true
        from: 0
        to: 1
        value: root.duration > 0
            ? Math.max(0, Math.min(1, 1 - root.remaining / root.duration)) : 0
    }

    Label {
        Layout.fillWidth: true
        text: root.sessions + " focus session" + (root.sessions === 1 ? "" : "s") + " completed"
        color: Theme.secondary
        horizontalAlignment: Text.AlignHCenter
    }

    RowLayout {
        Layout.fillWidth: true
        PopoverButton {
            Layout.fillWidth: true
            visible: root.pomodoroState === "idle"
            text: "Start focus"
            enabled: !root.busy
            onClicked: root.runAction("start")
        }
        PopoverButton {
            Layout.fillWidth: true
            visible: root.pomodoroState === "paused"
            text: "Resume"
            enabled: !root.busy
            onClicked: root.runAction("resume")
        }
        PopoverButton {
            Layout.fillWidth: true
            visible: root.pomodoroState === "running" || root.pomodoroState === "break"
            text: "Pause"
            enabled: !root.busy
            onClicked: root.runAction("pause")
        }
        PopoverButton {
            Layout.fillWidth: true
            visible: root.pomodoroState !== "idle"
            text: "Skip"
            enabled: !root.busy
            onClicked: root.runAction("skip")
        }
        PopoverButton {
            Layout.fillWidth: true
            visible: root.pomodoroState !== "idle"
            text: "Stop"
            enabled: !root.busy
            onClicked: root.runAction("stop")
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

    Label {
        Layout.fillWidth: true
        text: "Durations (minutes)"
        color: Theme.foreground
        font.bold: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Label { text: "Focus"; color: Theme.secondary }
            ThemeSpinBox {
                id: focusDuration
                Layout.fillWidth: true
                from: 1
                to: 180
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Label { text: "Short break"; color: Theme.secondary }
            ThemeSpinBox {
                id: shortDuration
                Layout.fillWidth: true
                from: 1
                to: 180
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Label { text: "Long break"; color: Theme.secondary }
            ThemeSpinBox {
                id: longDuration
                Layout.fillWidth: true
                from: 1
                to: 180
            }
        }
    }

    PopoverButton {
        Layout.fillWidth: true
        text: "Save durations"
        enabled: !root.busy
        onClicked: root.saveDurations()
    }

    Label {
        Layout.fillWidth: true
        visible: root.errorMessage.length > 0 || root.statusMessage.length > 0
        text: root.errorMessage.length > 0 ? root.errorMessage : root.statusMessage
        color: root.errorMessage.length > 0 ? Theme.danger : Theme.success
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}
