import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window
    required property var controller
    readonly property var player: controller.player
    visible: controller.panelOpen
    screen: controller.targetScreen
    anchors { top: true; right: true }
    margins { top: 42; right: 12 }
    implicitWidth: 400
    implicitHeight: Math.min(content.implicitHeight + 36, screen ? screen.height - 70 : 700)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "dotfiles-control-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.background
        border.color: Theme.border

        ScrollView {
            anchors.fill: parent
            anchors.margins: 18
            contentWidth: availableWidth
            clip: true
            focus: true
            Keys.onEscapePressed: window.controller.panelOpen = false
            palette.window: Theme.background
            palette.windowText: Theme.foreground
            palette.text: Theme.foreground
            palette.button: Theme.border
            palette.buttonText: Theme.foreground
            palette.base: Theme.background
            palette.highlight: Theme.accent
            palette.accent: Theme.accent
            palette.highlightedText: Theme.selected

            ColumnLayout {
                id: content
                width: parent.width
                spacing: 14
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Control Center"; font.pixelSize: 20; font.bold: true; Layout.fillWidth: true }
                    Button { text: "Close"; onClicked: window.controller.panelOpen = false }
                }
                Label {
                    text: "Sound & media"
                    font.pixelSize: 15
                    font.bold: true
                    color: Theme.accent
                }
                LevelControl {
                    Layout.fillWidth: true
                    title: "Output"
                    available: !!window.controller.sink && !!window.controller.sink.audio
                    detail: available ? window.controller.sink.description : "No audio output connected"
                    level: available ? window.controller.sink.audio.volume : 0
                    muted: available && window.controller.sink.audio.muted
                    onAdjusted: value => window.controller.sink.audio.volume = value
                    onMuteRequested: window.controller.sink.audio.muted = !muted
                }
                LevelControl {
                    Layout.fillWidth: true
                    title: "Microphone"
                    available: !!window.controller.source && !!window.controller.source.audio
                    detail: available ? window.controller.source.description : "No microphone connected"
                    level: available ? window.controller.source.audio.volume : 0
                    muted: available && window.controller.source.audio.muted
                    onAdjusted: value => window.controller.source.audio.volume = value
                    onMuteRequested: window.controller.source.audio.muted = !muted
                }
                LevelControl {
                    Layout.fillWidth: true
                    title: "Brightness"
                    available: window.controller.brightnessAvailable
                    detail: window.controller.brightnessError || (available ? window.controller.brightnessDevice : "No supported backlight")
                    level: window.controller.brightness
                    minimum: 0.01
                    canMute: false
                    onAdjusted: value => window.controller.setBrightness(value)
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
                ComboBox {
                    Layout.fillWidth: true
                    visible: window.controller.players.length > 1
                    model: window.controller.players.map(p => p.identity)
                    currentIndex: window.controller.players.indexOf(window.player)
                    onActivated: index => window.controller.selectedPlayer = window.controller.players[index].dbusName
                    Accessible.name: "Media player"
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle {
                        implicitWidth: 64
                        implicitHeight: 64
                        radius: 8
                        color: Theme.border
                        clip: true
                        Label { anchors.centerIn: parent; text: "♪"; font.pixelSize: 30; visible: artwork.status !== Image.Ready }
                        Image {
                            id: artwork
                            anchors.fill: parent
                            source: window.player ? window.player.trackArtUrl : ""
                            asynchronous: true
                            sourceSize { width: 128; height: 128 }
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: window.player ? (window.player.trackTitle || "Unknown title") : "Nothing playing"
                            textFormat: Text.PlainText
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: window.player ? (window.player.trackArtist || window.player.identity) : "Open a music or video player"
                            textFormat: Text.PlainText
                            color: Theme.secondary
                            elide: Text.ElideRight
                        }
                    }
                }
                MediaSlider {
                    Layout.fillWidth: true
                    visible: !!window.player && window.player.lengthSupported && window.player.positionSupported
                    enabled: !!window.player && window.player.canSeek
                    from: 0
                    to: window.player ? Math.max(1, window.player.length) : 1
                    value: window.player ? window.player.position : 0
                    onMoved: window.player.position = value
                    Accessible.name: "Playback position"
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Button {
                        text: "Previous"
                        enabled: !!window.player && window.player.canGoPrevious
                        onClicked: window.controller.transport("previous")
                    }
                    Button {
                        text: window.player && window.player.isPlaying ? "Pause" : "Play"
                        enabled: !!window.player && window.player.canTogglePlaying
                        onClicked: window.controller.transport("play-pause")
                    }
                    Button {
                        text: "Next"
                        enabled: !!window.player && window.player.canGoNext
                        onClicked: window.controller.transport("next")
                    }
                }
                Button {
                    Layout.fillWidth: true
                    text: "Audio devices & mixer…"
                    onClicked: {
                        Quickshell.execDetached(["pavucontrol"]);
                        window.controller.panelOpen = false;
                    }
                }
            }
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: window.visible && !!window.player && window.player.isPlaying && window.player.positionSupported
        onTriggered: window.player.positionChanged()
    }
}
