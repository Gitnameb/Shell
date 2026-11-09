pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Historial de textos copiados. `wl-paste --watch` (paquete wl-clipboard)
// escucha el portapapeles de Wayland y guarda cada texto en un JSON local.
// La vista se actualiza sola al cambiar el archivo y los elementos se pueden
// copiar o borrar sin depender de que el shell tenga el foco.
Singleton {
    id: root

    property var entries: []
    property int maxEntries: 50
    property bool ready: false
    property bool fileReady: false
    // Último JSON leído, para no reconstruir la lista en cada sondeo.
    property string lastLoadedText: ""
    // Índice que acaba de copiarse, para marcar la fila unos instantes.
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
        if (root.count === 0)
            return "Vacío";
        if (root.count === 1)
            return root.imageCount === 1 ? "1 imagen" : "1 elemento";
        return root.count + " elementos";
    }
    readonly property string path: (Quickshell.env("HOME") || "/home/username")
        + "/.local/state/shell/clipboard.json"

    readonly property string watchScript: (Quickshell.shellDir || "")
        + "/scripts/shell-clipboard-watch"
    readonly property string copyScript: (Quickshell.shellDir || "")
        + "/scripts/shell-clipboard-copy"

    function normalize(list): var {
        const result = [];
        if (!Array.isArray(list))
            return result;
        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            if (typeof item === "string") {
                if (item.trim().length > 0)
                    result.push({ kind: "text", text: item, time: 0 });
            } else if (item && typeof item.text === "string") {
                const kind = String(item.kind || "text");
                const time = Number(item.time) || 0;
                if (kind === "image"
                        && typeof item.image === "string"
                        && item.image.length > 0) {
                    result.push({
                        kind: "image",
                        text: item.text,
                        display: String(item.display || item.text),
                        image: item.image,
                        mime: String(item.mime || "image/png"),
                        time: time
                    });
                } else if (item.text.trim().length > 0) {
                    result.push({
                        kind: kind === "files" ? "files" : "text",
                        text: item.text,
                        display: String(item.display || item.text),
                        time: time
                    });
                }
            }
            if (result.length >= root.maxEntries)
                break;
        }
        return result;
    }

    function reloadEntries(): void {
        const raw = fileView.text() || "";
        if (raw === root.lastLoadedText && root.ready)
            return;
        root.lastLoadedText = raw;
        let parsed = [];
        try {
            parsed = JSON.parse(raw || "[]");
        } catch (error) {
            parsed = [];
        }
        root.entries = root.normalize(parsed);
        root.ready = true;
    }

    function writeEntries(): void {
        if (!root.fileReady)
            return;
        fileView.setText(JSON.stringify(root.entries));
    }

    // El texto se copia con wl-copy desde un proceso aparte: funciona aunque
    // el panel no tenga el foco y no importa si el texto es largo. El propio
    // vigilante mueve la entrada al principio al detectar el nuevo contenido.
    function copy(index: int): void {
        if (index < 0 || index >= root.entries.length)
            return;
        copyProc.command = [
            "python3", root.copyScript, String(index)
        ];
        copyProc.running = true;
        root.copiedIndex = 0;
        copyTimer.restart();
    }

    function remove(index: int): void {
        if (index < 0 || index >= root.entries.length)
            return;
        const list = root.entries.slice();
        list.splice(index, 1);
        root.entries = list;
        root.copiedIndex = -1;
        root.writeEntries();
    }

    function clear(): void {
        root.entries = [];
        root.copiedIndex = -1;
        root.writeEntries();
    }

    Timer {
        interval: 60
        running: true
        repeat: false
        onTriggered: initProc.running = true
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
            if (root.fileReady)
                watchProc.running = true;
        }
    }

    // Crea el archivo antes de que FileView empiece a vigilarlo.
    Process {
        id: initProc

        command: [
            "sh", "-c",
            "umask 077; mkdir -p \"$(dirname \"$1\")\"; "
                + "[ -f \"$1\" ] || printf '[]' > \"$1\"",
            "shell", root.path
        ]

        onExited: {
            root.fileReady = true;
            root.reloadEntries();
        }
    }

    FileView {
        id: fileView

        path: root.fileReady ? root.path : ""
        preload: true
        watchChanges: true
        blockWrites: false
        atomicWrites: false

        onTextChanged: root.reloadEntries()
        onFileChanged: root.reloadEntries()
        onLoaded: root.reloadEntries()
    }

    // Respaldo de lectura: algunos sistemas de archivos no avisan del cambio
    // después de una escritura externa. El JSON es diminuto y se relee cada
    // pocos segundos; así la ficha y la vista nunca se quedan desfasadas.
    Timer {
        interval: 2500
        running: root.fileReady
        repeat: true
        onTriggered: {
            fileView.reload();
            root.reloadEntries();
        }
    }

    Process {
        id: watchProc

        command: ["sh", root.watchScript]
        running: root.fileReady

        onExited: (code) => {
            // Sale con 0 si ya había otro vigilante. Se reintenta más tarde
            // para recuperar el historial si el proceso antiguo desaparece.
            watchRestart.interval = code === 0 ? 15000 : 1200;
            watchRestart.restart();
        }
    }

    Process {
        id: copyProc
    }
}
