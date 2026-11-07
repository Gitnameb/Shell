pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Teclado en pantalla real mediante wvkbd (protocolo de teclado virtual de
// Wayland). Se muestra como capa inferior y escribe en la ventana con foco.
Singleton {
    id: root

    property bool visible: false
    property bool available: false
    property bool checked: false
    property bool restarting: false
    property string error: ""

    // wvkbd no tiene capas nativas para todos los idiomas. El ruso usa la
    // capa cirílica; el resto, la QWERTY internacional con acentos.
    readonly property string layerList:
        SettingsState.keyboardLayout === "ru"
            ? "cyrillic,special,simple,nav,emoji"
            : "full,special,simple,nav,emoji"

    function toggle(): void {
        if (!root.available) {
            root.error = "wvkbd no está instalado.";
            return;
        }
        root.visible = !root.visible;
        root.error = "";
    }

    function show(): void {
        if (root.available)
            root.visible = true;
    }

    function hide(): void {
        root.visible = false;
    }

    Timer {
        interval: 250
        running: true
        repeat: false
        onTriggered: checkProc.running = true
    }

    Process {
        id: checkProc

        command: ["sh", "-c", "command -v wvkbd-mobintl >/dev/null 2>&1"]

        onExited: (code) => {
            root.available = code === 0;
            root.checked = true;
            if (code !== 0)
                root.error = "Instala wvkbd para usar el teclado en pantalla.";
        }
    }

    Process {
        id: keyboardProc

        command: [
            "wvkbd-mobintl",
            "-l", root.layerList,
            "-L", "290",
            "-H", "250",
            "--bg", "14171c",
            "--fg", "1a1e25",
            "--fg-sp", "24242f",
            "--text", "e9e7df",
            "--text-sp", "c9b8f5",
            "--press", "2f2e3c",
            "--press-sp", "3a3550"
        ]
        running: root.visible && !root.restarting

        onExited: {
            if (root.visible && !root.restarting)
                root.visible = false;
        }
    }

    // Al cambiar la distribución física se reinicia el teclado flotante para
    // que cargue la capa correspondiente.
    Connections {
        target: SettingsState

        function onKeyboardLayoutChanged(): void {
            if (!root.visible)
                return;
            root.restarting = true;
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 350
        repeat: false
        onTriggered: root.restarting = false
    }
}
