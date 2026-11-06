pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Historial de textos copiados. `wl-paste --watch` (incluido en scripts/bin)
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
    readonly property string path: (Quickshell.env("HOME") || "/home/username")
        + "/.local/state/alba/clipboard.json"

    readonly property string watchScript: (Quickshell.shellDir || "")
        + "/scripts/alba-clipboard-watch"
    readonly property string copyScript: (Quickshell.shellDir || "")
        + "/scripts/alba-clipboard-copy"

    function normalize(list): var {
        const result = [];
        if (!Array.isArray(list))
            return result;
        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            let text = "";
            let time = 0;
            if (typeof item === "string") {
                text = item;
            } else if (item && typeof item.text === "string") {
                text = item.text;
                time = Number(item.time) || 0;
            }
            if (text.length === 0 || text.trim().length === 0)
                continue;
            result.push({ text: text, time: time });
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
            "alba", root.path
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
