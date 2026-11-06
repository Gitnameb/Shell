pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Perfiles de energía de power-profiles-daemon. Si el demonio no está
// instalado o no responde, `available` queda en falso y el panel de la batería
// lo explica. No se inventan perfiles: se usan los que anuncia el sistema.
Singleton {
    id: root

    property bool available: false
    // Verdadero tras el primer intento de lectura, haya perfiles o no. Sirve
    // para que el panel de la batería muestre los controles desde el principio
    // en vez de esconderlos hasta que el demonio responda.
    property bool loaded: false
    property string current: ""
    property var profiles: []
    property bool busy: false
    property string error: ""

    readonly property bool ready: root.available && root.profiles.length > 0

    // Acepta tanto el nombre de power-profiles-daemon como la etiqueta que ve
    // el usuario, para que el IPC y los atajos sean cómodos.
    function key(value: string): string {
        const name = String(value).toLowerCase();
        if (name === "rendimiento" || name === "performance")
            return "performance";
        if (name === "equilibrado" || name === "balanced")
            return "balanced";
        if (name === "ahorro" || name === "ahorro de energía"
                || name === "power-saver")
            return "power-saver";
        return name;
    }

    function label(name: string): string {
        if (name === "performance")
            return "Rendimiento";
        if (name === "balanced")
            return "Equilibrado";
        if (name === "power-saver")
            return "Ahorro";
        return name;
    }

    function description(name: string): string {
        if (name === "performance")
            return "Máxima potencia";
        if (name === "balanced")
            return "Uso normal";
        if (name === "power-saver")
            return "Más autonomía";
        return "";
    }

    function iconName(name: string): string {
        if (name === "performance")
            return "gauge";
        if (name === "balanced")
            return "battery";
        if (name === "power-saver")
            return "leaf";
        return "battery";
    }

    // Orden del menú de la batería, de más eficiente a más potente. Si el
    // demonio anuncia un perfil nuevo, se añade al final sin esconderlo.
    readonly property var menuProfiles: {
        const order = ["power-saver", "balanced", "performance"];
        const out = [];
        for (let i = 0; i < order.length; i++) {
            if (root.profiles.indexOf(order[i]) !== -1)
                out.push(order[i]);
        }
        for (let i = 0; i < root.profiles.length; i++) {
            if (out.indexOf(root.profiles[i]) === -1)
                out.push(root.profiles[i]);
        }
        return out;
    }

    function refresh(): void {
        if (readProc.running)
            return;
        readProc.running = true;
    }

    function setProfile(value: string): void {
        const name = root.key(value);
        if (root.busy || name.length === 0 || name === root.current)
            return;
        root.busy = true;
        root.error = "";
        writeProc.command = ["powerprofilesctl", "set", name];
        writeProc.running = true;
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 300
        running: true
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: readProc

        command: ["sh", "-c",
            "command -v powerprofilesctl >/dev/null 2>&1 || exit 3; "
            + "printf 'CURRENT\\n'; powerprofilesctl get 2>/dev/null; "
            + "printf 'LIST\\n'; powerprofilesctl list 2>/dev/null"]

        stdout: StdioCollector {
            id: readOut
        }

        stderr: StdioCollector {
            id: readErr
        }

        onExited: (code) => {
            root.loaded = true;
            if (code === 3) {
                root.available = false;
                root.profiles = [];
                root.error = "";
                return;
            }
            if (code !== 0) {
                root.available = false;
                root.profiles = [];
                root.error = readErr.text.trim();
                return;
            }

            const lines = readOut.text.split("\n");
            const list = [];
            let section = "";
            let current = "";
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                if (line === "CURRENT") {
                    section = "current";
                    continue;
                }
                if (line === "LIST") {
                    section = "list";
                    continue;
                }
                if (section === "current") {
                    if (line.length > 0)
                        current = line;
                    continue;
                }
                if (section !== "list" || line.length === 0)
                    continue;
                const match = line.match(/^\*?\s*([a-z][a-z-]*):$/);
                if (match && list.indexOf(match[1]) === -1)
                    list.push(match[1]);
            }
            root.current = current;
            root.profiles = list;
            root.available = list.length > 0;
            root.error = "";
        }
    }

    Process {
        id: writeProc

        stderr: StdioCollector {
            id: writeErr
        }

        onExited: (code) => {
            root.busy = false;
            if (code !== 0)
                root.error = writeErr.text.trim()
                    || "No se pudo cambiar el perfil de energía.";
            root.refresh();
        }
    }
}
