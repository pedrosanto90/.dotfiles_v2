import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell

BarPopover {
    id: root
    popupName: "audio"
    title: "Sound"
    popupHeight: 310

    LevelControl {
        Layout.fillWidth: true
        title: "Output"
        available: !!root.controller.sink && !!root.controller.sink.audio
        detail: available ? root.controller.sink.description : "No audio output connected"
        level: available ? root.controller.sink.audio.volume : 0
        muted: available && root.controller.sink.audio.muted
        onAdjusted: value => root.controller.sink.audio.volume = value
        onMuteRequested: root.controller.sink.audio.muted = !muted
    }

    LevelControl {
        Layout.fillWidth: true
        title: "Microphone"
        available: !!root.controller.source && !!root.controller.source.audio
        detail: available ? root.controller.source.description : "No microphone connected"
        level: available ? root.controller.source.audio.volume : 0
        muted: available && root.controller.source.audio.muted
        onAdjusted: value => root.controller.source.audio.volume = value
        onMuteRequested: root.controller.source.audio.muted = !muted
    }

    Button {
        Layout.fillWidth: true
        text: "Audio devices & mixer…"
        onClicked: {
            Quickshell.execDetached(["pavucontrol"]);
            root.controller.closePopups();
        }
    }
}
