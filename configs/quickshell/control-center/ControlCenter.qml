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
    anchors { top: true; right: true; bottom: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    aboveWindows: true
    focusable: true
    WlrLayershell.namespace: "dotfiles-control-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onVisibleChanged: if (visible) focusScope.forceActiveFocus()

    MouseArea {
        anchors.fill: parent
        onClicked: window.controller.closePopups()
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: window.controller.closePopups()

        Rectangle {
            id: card
            width: 400
            height: Math.min(content.implicitHeight + 28,
                window.screen ? window.screen.height - 90 : 700)
            anchors { top: parent.top; right: parent.right; topMargin: 42; rightMargin: 12 }
            radius: 12
            color: Theme.background
            border.color: Theme.border

            MouseArea {
                anchors.fill: parent
                onClicked: event => event.accepted = true
            }

            ScrollView {
                anchors.fill: parent
                anchors.margins: 14
            contentWidth: availableWidth
            clip: true
            focus: true
            Keys.onEscapePressed: window.controller.closePopups()
            ScrollBar.vertical: ThemeScrollBar { }

            ColumnLayout {
                id: content
                width: parent.width
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Control Center"
                        color: Theme.foreground
                        font.pixelSize: 20
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        text: "✕"
                        onClicked: window.controller.closePopups()
                    }
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
                ThemeComboBox {
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
                        Label {
                            anchors.centerIn: parent
                            text: "♪"
                            color: Theme.secondary
                            font.pixelSize: 30
                            visible: artwork.status !== Image.Ready
                        }
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
                            color: Theme.foreground
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
                    spacing: 16
                    IconButton {
                        glyphSize: 18
                        text: "󰒮"
                        enabled: !!window.player && window.player.canGoPrevious
                        Accessible.name: "Previous"
                        onClicked: window.controller.transport("previous")
                    }
                    IconButton {
                        glyphSize: 20
                        text: window.player && window.player.isPlaying ? "󰏤" : "󰐊"
                        enabled: !!window.player && window.player.canTogglePlaying
                        Accessible.name: window.player && window.player.isPlaying ? "Pause" : "Play"
                        onClicked: window.controller.transport("play-pause")
                    }
                    IconButton {
                        glyphSize: 18
                        text: "󰒭"
                        enabled: !!window.player && window.player.canGoNext
                        Accessible.name: "Next"
                        onClicked: window.controller.transport("next")
                    }
                }
                PopoverButton {
                    Layout.fillWidth: true
                    text: "Audio devices & mixer…"
                    onClicked: {
                        Quickshell.execDetached(["pavucontrol"]);
                        window.controller.closePopups();
                    }
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
