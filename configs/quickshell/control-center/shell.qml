import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

ShellRoot {
    id: root
    property bool panelOpen: false
    property string osdKind: ""
    property var targetScreen: null
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var players: Mpris.players.values
    property string selectedPlayer: ""
    readonly property var player: players.find(p => p.dbusName === selectedPlayer)
        || players.find(p => p.isPlaying) || players[0] || null
    property real brightness: 0
    property bool brightnessAvailable: false
    property string brightnessDevice: ""
    property string brightnessError: ""
    property int pendingBrightness: -1

    PwObjectTracker { objects: [root.sink, root.source].filter(n => n !== null) }

    function chooseScreen() {
        const name = I3.focusedMonitor ? I3.focusedMonitor.name : "";
        targetScreen = Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0] || null;
    }
    function refreshBrightness() {
        if (!brightnessRead.running && !brightnessWrite.running)
            brightnessRead.running = true;
    }
    function show(kind) {
        if (["volume", "microphone", "brightness"].indexOf(kind) < 0) return;
        chooseScreen();
        if (kind === "brightness") refreshBrightness();
        osdKind = kind;
        osdTimer.restart();
    }
    function setBrightness(value) {
        pendingBrightness = Math.max(1, Math.min(100, Math.round(value * 100)));
        brightnessDebounce.restart();
    }
    function writeBrightness() {
        if (brightnessWrite.running || pendingBrightness < 0) return;
        const value = pendingBrightness;
        pendingBrightness = -1;
        brightnessError = "";
        brightnessWrite.command = ["brightnessctl", "--class=backlight", "--min-value=1", "set", value + "%"];
        brightnessWrite.running = true;
    }
    function transport(action) {
        if (!player) return false;
        // Keep controlling the same player after pausing it, even when another
        // player remains active or is first in the MPRIS list.
        const active = player;
        selectedPlayer = active.dbusName;
        if (action === "play-pause" && active.canTogglePlaying) active.togglePlaying();
        else if (action === "next" && active.canGoNext) active.next();
        else if (action === "previous" && active.canGoPrevious) active.previous();
        else return false;
        return true;
    }

    IpcHandler {
        target: "media"
        function toggle(): void {
            root.chooseScreen();
            root.panelOpen = !root.panelOpen;
            if (root.panelOpen) root.refreshBrightness();
        }
        function close(): void { root.panelOpen = false; }
        function show(kind: string): void { root.show(kind); }
        function transport(action: string): bool { return root.transport(action); }
        function status(): string {
            return JSON.stringify({panelOpen: root.panelOpen, osd: root.osdKind,
                output: root.sink ? root.sink.description : "", brightness: root.brightness,
                brightnessAvailable: root.brightnessAvailable,
                player: root.player ? root.player.identity : ""});
        }
    }

    Process {
        id: brightnessRead
        command: ["brightnessctl", "--class=backlight", "--machine-readable", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split("\n")[0].split(",");
                const current = Number(fields[2]);
                const max = Number(fields[4]);
                root.brightnessAvailable = fields.length >= 5 && max > 0 && Number.isFinite(current);
                if (root.brightnessAvailable) {
                    root.brightness = current / max;
                    root.brightnessDevice = fields[0];
                }
            }
        }
        onExited: (code, status) => { if (code !== 0) root.brightnessAvailable = false; }
    }
    Process {
        id: brightnessWrite
        onExited: (code, status) => {
            if (code !== 0) root.brightnessError = "Could not change brightness. Check backlight permissions.";
            if (root.pendingBrightness >= 0) root.writeBrightness();
            else root.refreshBrightness();
        }
    }
    Timer { id: brightnessDebounce; interval: 80; onTriggered: root.writeBrightness() }
    Timer { interval: 2000; repeat: true; running: root.panelOpen; onTriggered: root.refreshBrightness() }
    Timer { id: osdTimer; interval: 1800; onTriggered: root.osdKind = "" }

    ControlCenter { controller: root }
    MediaOsd { controller: root }
}
