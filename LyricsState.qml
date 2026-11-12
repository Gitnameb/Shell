pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Letras sincronizadas de la pista actual. MPRIS no las transporta, así que
// se leen del propio archivo con lyrics.py. La ruta llega por
// MusicState.trackUrl; los servicios en streaming no la publican y el widget
// se queda con título y artista.
Singleton {
    id: root

    readonly property string helperPath: (Quickshell.shellDir || "")
        + "/lyrics.py"

    // Estado de la pista actual.
    property string sourceUrl: ""
    property string pendingUrl: ""
    property string queuedUrl: ""
    property var lines: []
    property bool synced: false
    property bool loading: false
    property bool checked: false
    property string source: ""
    property string error: ""
    property int activeIndex: -1

    // Caché por URL para no relanzar Python al volver a una pista. Solo se
    // guardan los resultados válidos; las pistas sin letra se recuerdan en
    // `checked` mientras siga siendo la actual.
    property var cache: ({})

    readonly property bool enabled: SettingsState.lyricsEnabled
    readonly property bool available: root.synced && root.lines.length > 0
    readonly property bool active: root.enabled && root.available
    readonly property bool localSource: MusicState.trackUrl.indexOf("file://") === 0
        || MusicState.trackUrl.indexOf("/") === 0

    function textAt(index): string {
        if (index < 0 || index >= root.lines.length)
            return "";
        const line = root.lines[index];
        return line && line.text ? line.text : "";
    }

    readonly property string previousLine: root.textAt(root.activeIndex - 1)
    readonly property string currentLine: root.textAt(root.activeIndex)
    // Antes de la primera marca, la siguiente línea es la primera.
    readonly property string nextLine: root.activeIndex < 0
        ? root.textAt(0) : root.textAt(root.activeIndex + 1)

    function applyResult(url, result): void {
        if (url !== root.sourceUrl)
            return;
        root.loading = false;
        if (!result || result.ok !== true) {
            root.error = result && result.error ? result.error : "sin datos";
            root.synced = false;
            root.lines = [];
            root.activeIndex = -1;
            return;
        }
        root.error = "";
        root.source = result.source || "";
        root.synced = result.synced === true
            && Array.isArray(result.lines) && result.lines.length > 0;
        root.lines = root.synced ? result.lines : [];
        root.activeIndex = -1;
        if (root.synced)
            root.cache[url] = result;
        root.updateIndex();
    }

    // Pide las letras de una URL. Evita repetir la consulta de la pista que ya
    // está cargada y usa la caché cuando existe. Si el modo letras está
    // apagado no se lanza Python: se carga al activarlo.
    function request(url): void {
        if (!root.enabled)
            return;
        if (url === root.sourceUrl && (root.loading || root.checked))
            return;
        root.sourceUrl = url;
        root.pendingUrl = url;
        root.queuedUrl = "";
        root.lines = [];
        root.synced = false;
        root.source = "";
        root.error = "";
        root.activeIndex = -1;
        root.checked = false;
        if (!url) {
            root.loading = false;
            root.checked = true;
            return;
        }
        // Un servicio en streaming publica una URL https que no es un
        // archivo: no hay tag que leer.
        if (url.indexOf("file://") !== 0 && url.indexOf("/") !== 0) {
            root.loading = false;
            root.checked = true;
            return;
        }
        if (root.cache[url]) {
            root.applyResult(url, root.cache[url]);
            root.checked = true;
            return;
        }
        if (readProc.running) {
            // El proceso en curso es de otra pista: se relanza al terminar.
            root.queuedUrl = url;
            root.loading = true;
            return;
        }
        root.loading = true;
        readProc.command = ["python3", root.helperPath, url];
        readProc.running = true;
    }

    function startQueued(): void {
        if (root.queuedUrl.length === 0)
            return;
        const next = root.queuedUrl;
        root.queuedUrl = "";
        if (next !== root.sourceUrl || root.checked) {
            root.loading = false;
            return;
        }
        root.pendingUrl = next;
        root.loading = true;
        readProc.command = ["python3", root.helperPath, next];
        readProc.running = true;
    }

    // La línea activa es la última marca cuyo tiempo ya pasó. Se consulta con
    // un temporizador corto en vez de con cada cambio de Position porque el
    // reloj local de MusicState avanza cada 500 ms.
    function updateIndex(): void {
        if (!root.synced || root.lines.length === 0) {
            if (root.activeIndex !== -1)
                root.activeIndex = -1;
            return;
        }
        const now = MusicState.position + 0.08;
        let low = 0;
        let high = root.lines.length - 1;
        let found = -1;
        while (low <= high) {
            const middle = (low + high) >> 1;
            const time = Number(root.lines[middle].time);
            if (isFinite(time) && time <= now) {
                found = middle;
                low = middle + 1;
            } else {
                high = middle - 1;
            }
        }
        if (found !== root.activeIndex)
            root.activeIndex = found;
    }

    Connections {
        target: MusicState

        function onTrackUrlChanged(): void {
            if (root.enabled)
                root.request(MusicState.trackUrl);
        }
    }

    Connections {
        target: SettingsState

        function onLyricsEnabledChanged(): void {
            if (root.enabled)
                root.request(MusicState.trackUrl);
        }
    }

    // Los singletons arrancan antes de que MPRIS publique la primera pista.
    Timer {
        interval: 600
        running: true
        repeat: false
        onTriggered: {
            if (root.enabled)
                root.request(MusicState.trackUrl);
        }
    }

    Timer {
        interval: 200
        repeat: true
        running: root.active
        onTriggered: root.updateIndex()
    }

    Process {
        id: readProc

        stdout: StdioCollector {
            id: readOut
        }

        onExited: (code) => {
            const url = root.pendingUrl;
            let result = null;
            const raw = readOut.text.trim();
            if (raw.length > 0) {
                try {
                    result = JSON.parse(raw);
                } catch (error) {
                    result = { "ok": false, "error": "respuesta inválida" };
                }
            } else {
                result = { "ok": false, "error": "sin respuesta" };
            }
            if (url === root.sourceUrl) {
                root.applyResult(url, result);
                root.checked = true;
            }
            root.loading = false;
            root.startQueued();
        }
    }
}
