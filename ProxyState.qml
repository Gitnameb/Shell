pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Proxy por conexión. NetworkManager solo admite proxy desactivado o PAC, así
// que el modo manual se traduce a un PAC generado en el perfil. El proxy de la
// conexión activa también se escribe en environment.d para la próxima sesión.
Singleton {
    id: root

    property var connections: []
    property bool loading: false
    property bool busy: false
    property string error: ""
    property string notice: ""
    property string expandedUuid: ""
    property string envFile: ""

    readonly property string helperPath: (Quickshell.shellDir || "")
        + "/scripts/network-settings.py"

    function refresh(): void {
        if (root.loading || root.busy)
            return;
        listProc.running = true;
    }

    function toggle(uuid): void {
        const value = String(uuid || "");
        root.expandedUuid = root.expandedUuid === value ? "" : value;
        root.error = "";
        root.notice = "";
        root.envFile = "";
    }

    function save(uuid, method, pac, http, https, socks, noProxy): void {
        if (root.busy)
            return;
        const args = [root.helperPath, "set-proxy", String(uuid || ""),
            String(method || "none")];
        if (method === "auto")
            args.push(String(pac || ""));
        else if (method === "manual")
            args.push(String(http || ""), String(https || ""),
                String(socks || ""), String(noProxy || ""));
        root.busy = true;
        root.error = "";
        root.notice = "";
        root.envFile = "";
        setProc.command = ["python3"].concat(args);
        setProc.running = true;
    }

    function readResponse(text, code): void {
        const raw = String(text || "").trim();
        if (code !== 0 && raw.length === 0) {
            root.error = "No se pudo guardar el proxy.";
            return;
        }
        try {
            const data = JSON.parse(raw);
            if (Array.isArray(data.connections))
                root.connections = data.connections;
            if (!data.ok) {
                root.error = String(data.error || "No se pudo guardar el proxy.");
                return;
            }
            root.error = "";
            root.envFile = String(data.envFile || "");
            const warning = String(data.warning || "");
            if (warning.length > 0)
                root.notice = warning;
            else if (root.envFile.length > 0)
                root.notice = "Proxy guardado. Se aplicará al iniciar sesión.";
            else
                root.notice = "Proxy guardado.";
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
                    || "No se pudo guardar el proxy.";
                return;
            }
            root.readResponse(raw, code);
        }

        onRunningChanged: root.busy = running
    }
}
