pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property var values: {
        const source = palette.text();
        if (!source) return ({});
        try {
            return JSON.parse(source);
        } catch (error) {
            console.warn("Could not parse the desktop palette:", error);
            return ({});
        }
    }
    function value(name, fallbackValue) {
        return typeof values[name] === "string" ? values[name] : fallbackValue;
    }
    readonly property string themeId: value("id", "tokyonight-dark")
    readonly property string label: value("label", "Tokyo Night — Dark")
    readonly property string mode: value("mode", "dark")
    readonly property color barBackground: value("barBackground", "#f51a1b26")
    readonly property color background: value("background", "#16161e")
    readonly property color surface: value("surface", "#1a1b26")
    readonly property color foreground: value("foreground", "#c0caf5")
    readonly property color secondary: value("secondary", "#a9b1d6")
    readonly property color selected: value("selected", "#1a1b26")
    readonly property color muted: value("muted", "#565f89")
    readonly property color border: value("border", "#3b4261")
    readonly property color accent: value("accent", "#7aa2f7")
    readonly property color success: value("success", "#9ece6a")
    readonly property color warning: value("warning", "#e0af68")
    readonly property color orange: value("orange", "#ff9e64")
    readonly property color danger: value("danger", "#f7768e")
    readonly property color purple: value("purple", "#bb9af7")
    property FileView palette: FileView {
        path: root.configHome + "/debian-sway-dev/theme/current.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }
}
