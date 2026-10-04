import QtQuick

QtObject {
    property string activePopup: ""

    function open(name) {
        activePopup = name;
    }

    function toggle(name) {
        activePopup = activePopup === name ? "" : name;
    }

    function closeAll() {
        activePopup = "";
    }
}
