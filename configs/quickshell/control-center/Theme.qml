pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    readonly property string paletteDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/waybar/"
    readonly property string css: palette.text()
    readonly property string imported: {
        const match = css.match(/@import\s+"([a-zA-Z0-9_-]+\.css)"/);
        return match ? match[1] : "";
    }
    readonly property string source: css + "\n" + fallback.text()
    function colorFor(name, fallbackColor) {
        const match = source.match(new RegExp("@define-color\\s+" + name + "\\s+(#[0-9a-fA-F]{6})\\s*;"));
        return match ? match[1] : fallbackColor;
    }
    readonly property color background: colorFor("tooltip_background", "#16161e")
    readonly property color foreground: colorFor("foreground", "#c0caf5")
    readonly property color secondary: colorFor("secondary_foreground", "#a9b1d6")
    readonly property color border: colorFor("border", "#3b4261")
    readonly property color accent: colorFor("blue", "#7aa2f7")
    readonly property color danger: colorFor("red", "#f7768e")
    readonly property color selected: colorFor("selected_foreground", "#1a1b26")
    property FileView palette: FileView {
        path: root.paletteDir + "colors.css"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }
    property FileView fallback: FileView {
        path: root.imported ? root.paletteDir + root.imported : ""
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }
}
