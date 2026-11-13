pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// DNS de las conexiones activas. NetworkManager no tiene un DNS único para
// todo el sistema, así que se aplica la misma elección a las conexiones Wi-Fi
// y Ethernet conectadas en ese momento. La vista DNS del centro de control usa
// este singleton.
Singleton {
    id: root

    property var connections: []
    property bool loading: false
    property bool busy: false
    property string error: ""
    property string notice: ""

    readonly property string helperPath: (Quickshell.shellDir || "")
        + "/scripts/network-settings.py"

    // Solo las conexiones activas reciben el ajuste de DNS.
    readonly property var activeConnections: {
        if (!Array.isArray(root.connections))
            return [];
        return root.connections.filter(item => item.active === true);
    }

    // Todas las conexiones activas usan el DNS que entrega el router.
    readonly property bool allAuto: {
        if (root.activeConnections.length === 0)
            return true;
        for (let i = 0; i < root.activeConnections.length; i++) {
            if (root.activeConnections[i].auto !== true)
                return false;
        }
        return true;
    }

    // Hay redes conectadas con ajustes distintos: el widget avisa antes de
    // unificarlas.
    readonly property bool mixed: {
        if (root.activeConnections.length === 0)
            return false;
        let signature = "";
        for (let i = 0; i < root.activeConnections.length; i++) {
            const item = root.activeConnections[i];
            const current = item.auto
                ? "auto"
                : "manual:" + (item.dns4 || []).join(",")
                    + "|" + (item.dns6 || []).join(",");
            if (signature.length === 0)
                signature = current;
            else if (signature !== current)
                return true;
        }
        return false;
    }

    // Valores de referencia para rellenar el formulario cuando hay una
    // configuración manual (aunque no sea igual en todas las redes).
    readonly property var manualSample: {
        for (let i = 0; i < root.activeConnections.length; i++) {
            if (root.activeConnections[i].auto !== true)
                return root.activeConnections[i];
        }
        return null;
    }

    readonly property string current4: root.manualSample
        ? (root.manualSample.dns4 || []).join(" ") : ""
    readonly property string current6: root.manualSample
        ? (root.manualSample.dns6 || []).join(" ") : ""

    readonly property string summary: {
        if (root.loading)
            return "Leyendo…";
        if (root.activeConnections.length === 0)
            return "Sin conexión";
        if (root.allAuto)
            return "Automático";
        if (root.mixed)
            return "Mixto";
        const list = [];
        const v4 = root.manualSample ? root.manualSample.dns4 || [] : [];
        const v6 = root.manualSample ? root.manualSample.dns6 || [] : [];
        for (let i = 0; i < v4.length; i++)
            list.push(v4[i]);
        for (let i = 0; i < v6.length; i++)
            list.push(v6[i]);
        return list.length > 0 ? list.join(", ") : "Sin DNS";
    }

    function refresh(): void {
        if (root.loading || root.busy)
            return;
        listProc.running = true;
    }

    // Aplica la misma elección a todas las conexiones activas.
    function saveAll(automatic, dns4, dns6): void {
        if (root.busy)
            return;
        const args = [root.helperPath, "set-all",
            automatic ? "auto" : "manual"];
        if (!automatic) {
            args.push(String(dns4 || ""));
            args.push(String(dns6 || ""));
        }
        root.busy = true;
        root.error = "";
        root.notice = "";
        setProc.command = ["python3"].concat(args);
        setProc.running = true;
    }

    function readResponse(text, code): void {
        const raw = String(text || "").trim();
        if (code !== 0 && raw.length === 0) {
            root.error = "No se pudo guardar el DNS.";
            return;
        }
        try {
            const data = JSON.parse(raw);
            if (Array.isArray(data.connections))
                root.connections = data.connections;
            if (!data.ok) {
                root.error = String(data.error || "No se pudo guardar el DNS.");
                return;
            }
            root.error = "";
            const warning = String(data.warning || "");
            if (warning.length > 0)
                root.notice = warning;
            else if (data.count > 0)
                root.notice = "DNS aplicado a " + data.count
                    + (data.count === 1 ? " conexión." : " conexiones.");
            else
                root.notice = "DNS guardado.";
        } catch (e) {
            root.error = "No se pudo leer la respuesta del ayudante.";
        }
    }

    Process {
        id: listProc

        command: ["python3", root.helperPath, "list"]

        stdout: StdioCollector {
            id: listOut
        }

        stderr: StdioCollector {
            id: listErr
        }

        onExited: (code) => {
            root.loading = false;
            const raw = String(listOut.text || "").trim();
            if (code !== 0 && raw.length === 0) {
                root.error = String(listErr.text || "").trim()
                    || "No se pudieron leer las conexiones.";
                return;
            }
            try {
                const data = JSON.parse(raw);
                root.connections = data.connections || [];
                if (!data.ok)
                    root.error = String(data.error || "")
                        || "No se pudieron leer las conexiones.";
            } catch (e) {
                root.error = "No se pudo leer la lista de conexiones.";
            }
        }

        onRunningChanged: root.loading = running
    }

    Process {
        id: setProc

        stdout: StdioCollector {
            id: setOut
        }

        stderr: StdioCollector {
            id: setErr
        }

        onExited: (code) => {
            root.busy = false;
            const raw = String(setOut.text || "").trim();
            if (raw.length === 0) {
                root.error = String(setErr.text || "").trim()
                    || "No se pudo guardar el DNS.";
                return;
            }
            root.readResponse(raw, code);
        }

        onRunningChanged: root.busy = running
    }
}
