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
    property string error: ""

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
        running: root.visible

        onExited: {
            if (root.visible)
                root.visible = false;
        }
    }
}
