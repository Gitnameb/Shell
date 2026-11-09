pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Historial del portapapeles delegado en cliphist. Este singleton solo lee
// `cliphist list`, pide `cliphist decode` para pegar y borra con
// `cliphist delete`/`wipe`; el almacenamiento y la deduplicación viven en
// cliphist, no en el shell. `scripts/shell-clipboard-watch` mantiene el
// vigilante `wl-paste --watch cliphist store`.
Singleton {
    id: root

    property var entries: []
    property bool ready: false
    property bool available: false
    property string error: ""
    // Solo se consulta mientras la vista del portapapeles está abierta.
    property bool monitoring: false
    property bool refreshPending: false
    // Índice que acaba de copiarse, para marcarlo unos instantes.
    property int copiedIndex: -1

    readonly property int count: root.entries.length
    readonly property int imageCount: {
        let total = 0;
        for (let i = 0; i < root.entries.length; i++) {
            if (root.entries[i].kind === "image")
                total++;
        }
        return total;
    }
    readonly property int textCount: root.count - root.imageCount
    readonly property string summary: {
        if (!root.available)
            return "Sin cliphist";
        if (root.count === 0)
            return "Vacío";
        if (root.count === 1)
            return root.imageCount === 1 ? "1 imagen" : "1 elemento";
        return root.count + " elementos";
    }

    readonly property string watchScript: (Quickshell.shellDir || "")
        + "/scripts/shell-clipboard-watch"
    readonly property string copyScript: (Quickshell.shellDir || "")
        + "/scripts/shell-clipboard-copy"
    readonly property string removeScript: (Quickshell.shellDir || "")
        + "/scripts/shell-clipboard-remove"

    // Convierte una línea de `cliphist list` («id<TAB>vista previa») en una
    // entrada del modelo. Las imágenes solo muestran su tipo y tamaño; el
    // contenido binario sigue guardado dentro de cliphist.
    function parseLine(line): var {
        const tab = line.indexOf("\t");
        if (tab <= 0)
            return null;
        const id = line.slice(0, tab).trim();
        if (!/^[0-9]+$/.test(id))
            return null;
        const preview = line.slice(tab + 1);
        const image = preview.match(
            /^\[\[ binary data .*? ([A-Za-z0-9]+) (\d+)x(\d+) \]\]$/);
        if (image) {
            const mime = String(image[1]).toUpperCase();
            const width = Number(image[2]) || 0;
            const height = Number(image[3]) || 0;
            return {
                id: id,
                kind: "image",
                mime: mime.toLowerCase(),
                width: width,
                height: height,
                text: "Imagen " + mime
                    + (width > 0 && height > 0
                        ? " · " + width + "×" + height : "")
            };
        }
        const files = preview.indexOf("file://") === 0;
        return {
            id: id,
            kind: files ? "files" : "text",
            text: preview,
            display: preview
        };
    }

    function parseList(raw): void {
        const lines = String(raw || "").split("\n");
        const list = [];
        for (let i = 0; i < lines.length; i++) {
            const entry = root.parseLine(lines[i]);
            if (entry !== null)
                list.push(entry);
        }
        root.entries = list;
        root.ready = true;
        if (root.copiedIndex >= list.length)
            root.copiedIndex = -1;
    }

    function refresh(): void {
        if (listProc.running) {
            root.refreshPending = true;
            return;
        }
        root.refreshPending = false;
        listProc.running = true;
    }

    function copy(index: int): void {
        if (index < 0 || index >= root.entries.length)
            return;
        copyProc.command = ["sh", root.copyScript,
            String(root.entries[index].id)];
        copyProc.running = true;
        root.copiedIndex = 0;
        copyTimer.restart();
    }

    function remove(index: int): void {
        if (index < 0 || index >= root.entries.length)
            return;
        removeProc.command = ["sh", root.removeScript,
            String(root.entries[index].id)];
        removeProc.running = true;
        root.copiedIndex = -1;
    }

    function clear(): void {
        wipeProc.running = true;
        root.copiedIndex = -1;
    }

    Timer {
        interval: 60
        running: true
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1800
        running: root.monitoring
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: copyTimer
        interval: 1300
        repeat: false
        onTriggered: root.copiedIndex = -1
    }

    Timer {
        id: watchRestart
        interval: 1200
        repeat: false
        onTriggered: {
            if (watchProc.running)
                return;
            watchProc.running = true;
        }
    }

    Process {
        id: listProc

        // 127 significa que no hay cliphist; `list` sale con 1 mientras la
        // base está vacía, que no es un error para la interfaz.
        command: ["sh", "-c",
            "if command -v cliphist >/dev/null 2>&1; then "
                + "exec cliphist list; "
                + "elif [ -x \"$HOME/.local/bin/cliphist\" ]; then "
                + "exec \"$HOME/.local/bin/cliphist\" list; "
                + "else exit 127; fi"]

        stdout: StdioCollector {
            id: listOut
        }

        onExited: (code) => {
            if (code === 127) {
                root.available = false;
                root.error = "cliphist no está instalado.";
                root.entries = [];
                root.ready = true;
            } else {
                root.available = true;
                root.error = "";
                root.parseList(listOut.text);
            }
            if (root.refreshPending) {
                root.refreshPending = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    Process {
        id: watchProc

        command: ["sh", root.watchScript]
        running: true

        onExited: (code) => {
            watchRestart.interval = code === 0 ? 15000 : 1200;
            watchRestart.restart();
        }
    }

    Process {
        id: copyProc

        onExited: {
            // cliphist vuelve a guardar lo pegado como entrada nueva; se
            // refresca para que el orden real mande sobre el índice local.
            root.refresh();
        }
    }

    Process {
        id: removeProc

        onExited: root.refresh()
    }

    Process {
        id: wipeProc

        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }
}
