pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Progreso de tareas externas (copias, descargas, renderizados...) que se
// muestra como un anillo alrededor del icono de la app o del escritorio.
// Cualquier programa puede alimentarlo escribiendo líneas `clave=porcentaje`
// en ~/.local/state/shell/progress. El script `scripts/shell-progress` ofrece
// una forma cómoda de actualizarlo.
Singleton {
    id: root

    // Claves de app y de escritorio ya normalizadas a 0..1.
    property var appValues: ({})
    property var workspaceValues: ({})
    property string lastText: ""

    readonly property string path: (Quickshell.env("HOME") || "/home/username")
        + "/.local/state/shell/progress"

    function normalize(value) {
        return String(value).toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function apply(text) {
        const apps = ({});
        const spaces = ({});
        const lines = String(text || "").split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length === 0 || line.charAt(0) === "#")
                continue;
            const eq = line.indexOf("=");
            if (eq <= 0)
                continue;

            let key = line.slice(0, eq).trim().toLowerCase();
            if (key.indexOf("app:") === 0)
                key = key.slice(4);
            if (key.length === 0)
                continue;

            const raw = line.slice(eq + 1).trim().replace(",", ".");
            let value = parseFloat(raw);
            if (!isFinite(value))
                continue;
            // Se admite 34 (34 %), 34% (34 %) y 0.34 (34 %). El 1 suelto se
            // interpreta como 100 %; para 1 % hay que escribir 1%.
            if (raw.indexOf("%") !== -1 || value > 1)
                value /= 100;
            value = Math.max(0, Math.min(1, value));

            if (key.indexOf("ws:") === 0) {
                const id = parseInt(key.slice(3), 10);
                if (isNaN(id))
                    continue;
                const current = spaces[id];
                spaces[id] = current === undefined
                    ? value : Math.max(current, value);
            } else {
                const current = apps[key];
                apps[key] = current === undefined
                    ? value : Math.max(current, value);
            }
        }

        root.appValues = apps;
        root.workspaceValues = spaces;
    }

    function refresh() {
        let text = "";
        try {
            text = stateFile.text();
        } catch (error) {
            return;
        }
        if (text === root.lastText)
            return;
        root.lastText = text;
        root.apply(text);
    }

    // Progreso de una app por su clase de ventana. Se compara sin signos para
    // que `firefox` encuentre también `firefox-esr`. Devuelve -1 si no hay
    // ninguna tarea en curso.
    function forApp(cls) {
        const target = root.normalize(cls);
        if (target.length === 0)
            return -1;

        let best = -1;
        const values = root.appValues;
        for (const key in values) {
            const normalized = root.normalize(key);
            if (normalized.length === 0)
                continue;
            if (normalized === target || normalized.indexOf(target) !== -1
                    || target.indexOf(normalized) !== -1)
                best = Math.max(best, values[key]);
        }
        return best;
    }

    function forWorkspace(id) {
        const value = root.workspaceValues[String(id)];
        return value === undefined ? -1 : value;
    }

    FileView {
        id: stateFile

        path: root.path
        watchChanges: true
        printErrors: false

        onFileChanged: stateFile.reload()
        onLoaded: root.refresh()
        onTextChanged: root.refresh()
    }

    // Respaldo por si el archivo no existía al arrancar y el vigilante no
    // llega a engancharse: una lectura por segundo de un archivo diminuto.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: stateFile.reload()
    }
}
