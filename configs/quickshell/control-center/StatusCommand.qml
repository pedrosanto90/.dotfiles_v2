import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var command: []
    property int interval: 5000
    property bool enabled: true
    property var data: ({text: "", class: "", tooltip: ""})

    function refresh() {
        if (enabled && command.length > 0 && !process.running) process.running = true;
    }

    Process {
        id: process
        command: root.command
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output.length === 0) return;
                try {
                    const parsed = JSON.parse(output);
                    parsed.text = String(parsed.text || "");
                    parsed.class = String(parsed.class || "");
                    parsed.tooltip = String(parsed.tooltip || "");
                    root.data = parsed;
                } catch (error) {
                    console.warn("Could not parse status from", root.command[0], error);
                }
            }
        }
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.enabled
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
