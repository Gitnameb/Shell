pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Salida virtual de 1920x864 para jugar por Steam Link desde el móvil en 20:9.
// El trabajo real lo hace ~/.local/bin/steamlink-mode: crea o destruye la
// salida, la marca como primaria de X11 y activa las reglas temporales que
// mandan los juegos a esa pantalla. Este singleton solo expone el estado y
// lanza el script.
Singleton {
    id: root

    readonly property string script: (Quickshell.env("HOME") || "")
        + "/.local/bin/steamlink-mode"

    property bool active: false
    property bool busy: false
    property bool available: true
    property string error: ""

    readonly property string summary: {
        if (root.busy)
            return root.active ? "Retirando…" : "Creando salida…";
        if (!root.available)
            return "No instalado";
        return root.active ? "1920x864 · 20:9" : "Desactivada";
    }

    function refresh(): void {
        if (root.busy || statusProc.running)
            return;
        statusProc.running = true;
    }

    function toggle(): void {
        if (root.busy)
            return;
        root.error = "";
        root.busy = true;
        toggleProc.running = true;
    }

    Component.onCompleted: root.refresh()

    // El atajo Mod+Shift+F11 puede cambiar el estado sin pasar por el shell;
    // una consulta periódica mantiene la ficha y el control de la barra al día.
    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProc

        command: [root.script, "status"]

        stdout: StdioCollector {
            id: statusOut
        }

        stderr: StdioCollector {
            id: statusErr
        }

        onExited: (code) => {
            root.available = code === 0;
            root.active = code === 0
                && String(statusOut.text || "").trim() === "activa";
            if (code !== 0)
                root.error = String(statusErr.text || "").trim();
        }
    }

    Process {
        id: toggleProc

        command: [root.script, "toggle"]

        stdout: StdioCollector {
            id: toggleOut
        }

        stderr: StdioCollector {
            id: toggleErr
        }

        onExited: (code) => {
            root.busy = false;
            if (code !== 0)
                root.error = String(toggleErr.text || "").trim()
                    || "No se pudo cambiar Steam Link.";
            root.refresh();
        }
    }
}
