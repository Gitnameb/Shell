pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Paquetes que necesita la vista Red. El chequeo solo se ejecuta cuando el
// usuario pulsa el icono de advertencia del panel de notificaciones; no se
// lanza al arrancar ni cada vez que se abre un panel.
Singleton {
    id: root

    property var missing: []
    property bool checking: false
    property bool checked: false
    property bool revealed: false
    property bool expanded: false
    property string error: ""
    property string copiedText: ""

    readonly property string checkScript: (Quickshell.shellDir || "")
        + "/scripts/check-deps.sh"
    readonly property int count: missing.length
    readonly property bool hasMissing: checked && count > 0
    readonly property bool hasResult: checked || error.length > 0
    readonly property string title: count === 1
        ? "Falta 1 dependencia" : "Faltan " + count + " dependencias"

    // Comandos únicos que resuelven las dependencias pendientes.
    readonly property var fixes: {
        const out = [];
        for (let i = 0; i < missing.length; i++) {
            const fix = String(missing[i].fix || "");
            if (fix.length > 0 && out.indexOf(fix) === -1)
                out.push(fix);
        }
        return out;
    }

    function refresh(): void {
        if (root.checking)
            return;
        root.revealed = true;
        root.checking = true;
        checkProc.running = true;
    }

    // El icono del panel siempre lanza una comprobación nueva.
    function checkNow(): void {
        root.revealed = true;
        root.refresh();
    }

    function toggle(): void {
        if (root.hasMissing)
            root.expanded = !root.expanded;
    }

    function copy(text): void {
        const value = String(text || "");
        if (value.length === 0)
            return;
        Quickshell.execDetached([
            "sh", "-c", "printf '%s' \"$1\" | wl-copy", "alba", value
        ]);
        root.copiedText = value;
        copyTimer.restart();
    }

    onMissingChanged: {
        if (root.missing.length === 0)
            root.expanded = false;
    }

    Timer {
        id: copyTimer

        interval: 1400
        repeat: false
        onTriggered: root.copiedText = ""
    }

    // Si todo está bien, el aviso se retira solo a los pocos segundos.
    Timer {
        id: cleanTimer

        interval: 4500
        repeat: false
        onTriggered: root.revealed = false
    }

    Process {
        id: checkProc

        command: ["bash", root.checkScript]

        stdout: StdioCollector {
            id: checkOut
        }

        stderr: StdioCollector {
            id: checkErr
        }

        onExited: (code) => {
            root.checking = false;
            root.checked = false;
            root.missing = [];
            if (code !== 0) {
                root.error = String(checkErr.text || "").trim()
                    || "No se pudo comprobar las dependencias.";
                cleanTimer.stop();
                return;
            }
            root.error = "";
            root.checked = true;
            const raw = String(checkOut.text || "").trim();
            const list = [];
            if (raw.length > 0) {
                const lines = raw.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("|");
                    if (parts.length < 3)
                        continue;
                    list.push({
                        key: parts[0],
                        label: parts[1],
                        package: parts[2],
                        fix: parts.length > 3
                            ? parts.slice(3).join("|") : ""
                    });
                }
            }
            root.missing = list;
            if (list.length === 0)
                cleanTimer.restart();
            else
                cleanTimer.stop();
        }

        onRunningChanged: root.checking = running
    }
}
