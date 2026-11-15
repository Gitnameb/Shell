pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Salida virtual para jugar por Steam Link desde el móvil. Steam Link es un
// preset de ~/.local/bin/virtual-output: crea o destruye la pantalla headless,
// la marca como primaria de X11, activa las reglas temporales que mandan los
// juegos a esa pantalla y hace que el portal capture solo esa salida mientras
// está activa. Este singleton expone el estado y lanza el preset.
Singleton {
    id: root

    readonly property string script: (Quickshell.env("HOME") || "")
        + "/.local/bin/steamlink-mode"

    property bool active: false
    property bool busy: false
    property bool available: true
    property string error: ""
    // Resolución actual de la salida virtual, por ejemplo "1920x864@60".
    property string mode: "1920x864@60"
    // Preset activo: «steamlink» o «none» si es la salida genérica.
    property string preset: ""

    readonly property string modeLabel: String(root.mode).split("@")[0]

    readonly property string summary: {
        if (root.busy)
            return root.active ? "Retirando…" : "Creando salida…";
        if (!root.available)
            return "No instalado";
        if (!root.active)
            return "Desactivada";
        if (root.preset !== "steamlink")
            return "Salida genérica · " + root.modeLabel;
        return root.modeLabel + " · " + root.aspectLabel(root.mode);
    }

    // Reduce 1920x864 a 20:9 para la ficha del centro de control.
    function aspectLabel(value): string {
        const size = String(value || "").split("@")[0].split("x");
        const width = parseInt(size[0], 10);
        const height = parseInt(size[1], 10);
        if (!width || !height)
            return String(value || "");
        const gcd = (a, b) => b ? gcd(b, a % b) : a;
        const divisor = gcd(width, height);
        return (width / divisor) + ":" + (height / divisor);
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

        command: [root.script, "info"]

        stdout: StdioCollector {
            id: statusOut
        }

        stderr: StdioCollector {
            id: statusErr
        }

        onExited: (code) => {
            root.available = code === 0;
            if (code !== 0) {
                root.active = false;
                root.error = String(statusErr.text || "").trim();
                return;
            }
            let values = {};
            const lines = String(statusOut.text || "").split("\n");
            for (let index = 0; index < lines.length; index++) {
                const separator = lines[index].indexOf("=");
                if (separator > 0)
                    values[lines[index].slice(0, separator)] = lines[index].slice(separator + 1);
            }
            root.active = values.active === "1";
            if (values.mode)
                root.mode = values.mode;
            root.preset = values.preset || "";
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
