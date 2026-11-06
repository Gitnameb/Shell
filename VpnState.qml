pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// VPN de NetworkManager. Lista los perfiles de tipo `vpn` o `wireguard` y
// permite conectarlos o desconectarlos con nmcli. Si no hay ninguno, la vista
// explica cómo crear uno en lugar de inventar servidores de demostración.
Singleton {
    id: root

    property var profiles: []
    property string activeName: ""
    property bool busy: false
    property string busyName: ""
    property string error: ""

    readonly property bool configured: root.profiles.length > 0
    readonly property bool active: root.activeName.length > 0
    readonly property string activeLabel: {
        for (let i = 0; i < root.profiles.length; i++) {
            if (root.profiles[i].name === root.activeName)
                return root.profiles[i].name;
        }
        return root.activeName;
    }

    function splitFields(line): var {
        const out = [];
        let current = "";
        let escaped = false;
        for (let i = 0; i < line.length; i++) {
            const ch = line.charAt(i);
            if (escaped) {
                current += ch;
                escaped = false;
            } else if (ch === "\\") {
                escaped = true;
            } else if (ch === ":") {
                out.push(current);
                current = "";
            } else {
                current += ch;
            }
        }
        out.push(current);
        return out;
    }

    function refresh(): void {
        if (listProc.running)
            return;
        listProc.running = true;
    }

    function toggle(name: string): void {
        if (root.busy || name.length === 0)
            return;
        const isActive = name === root.activeName;
        root.busy = true;
        root.busyName = name;
        root.error = "";
        actionProc.command = [
            "nmcli", "--wait", "20", "connection",
            isActive ? "down" : "up", "id", name
        ];
        actionProc.running = true;
    }

    function toggleActive(): void {
        if (!root.configured)
            return;
        if (root.active)
            root.toggle(root.activeName);
        else
            root.toggle(root.profiles[0].name);
    }

    // nmcli devuelve mensajes técnicos; los casos conocidos se explican en
    // castellano y el resto se muestra tal cual.
    function humanError(text): string {
        const value = String(text).trim();
        if (value.indexOf("unknown VPN plugin") !== -1)
            return "Falta el complemento OpenVPN de NetworkManager.";
        if (value.indexOf("not a valid OpenVPN configuration") !== -1)
            return "El archivo no es una configuración OpenVPN válida.";
        if (value.indexOf("not authorized") !== -1)
            return "NetworkManager no autorizó el cambio.";
        return value.length > 0
            ? value : "No se pudo completar la operación.";
    }

    // Abre el selector de archivos y, si se elige uno, lo importa. El selector
    // vive en un script para poder usar KDialog o Zenity sin bloquear el shell.
    function pickImport(): void {
        if (root.busy)
            return;
        root.error = "";
        pickProc.running = true;
    }

    function importOpenVpn(path: string): void {
        if (root.busy || path.length === 0)
            return;
        root.busy = true;
        root.busyName = "";
        root.error = "";
        editProc.command = [
            "nmcli", "--wait", "30", "connection", "import",
            "type", "openvpn", "file", path
        ];
        editProc.running = true;
    }

    // Guarda el nombre visible y el arranque automático en una sola orden. Si
    // el nombre no cambia, nmcli acepta el mismo valor sin tocar nada más.
    function saveProfile(oldName, newName, autoconnect): void {
        if (root.busy)
            return;
        const clean = String(newName).trim();
        if (clean.length === 0) {
            root.error = "El nombre no puede quedar vacío.";
            return;
        }
        root.busy = true;
        root.busyName = oldName;
        root.error = "";
        editProc.command = [
            "nmcli", "connection", "modify", "id", oldName,
            "connection.id", clean,
            "connection.autoconnect", autoconnect ? "yes" : "no"
        ];
        editProc.running = true;
    }

    function deleteProfile(name: string): void {
        if (root.busy || name.length === 0)
            return;
        root.busy = true;
        root.busyName = name;
        root.error = "";
        editProc.command = ["nmcli", "connection", "delete", "id", name];
        editProc.running = true;
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
        onRunningChanged: if (running) root.refresh()
    }

    Timer {
        interval: 250
        running: true
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: listProc

        command: ["sh", "-c",
            "printf 'ALL\\n'; nmcli -t -e yes -f NAME,TYPE,AUTOCONNECT connection show 2>/dev/null; "
            + "printf 'ACTIVE\\n'; nmcli -t -e yes -f NAME,TYPE,AUTOCONNECT connection show --active 2>/dev/null"]

        stdout: StdioCollector {
            id: listOut
        }

        stderr: StdioCollector {
            id: listErr
        }

        onExited: (code) => {
            if (code !== 0) {
                root.error = listErr.text.trim() || "No se pudo consultar NetworkManager.";
                return;
            }
            const lines = listOut.text.split("\n");
            const all = [];
            const active = [];
            const types = {};
            const autos = {};
            let section = "";
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                if (line === "ALL") {
                    section = "all";
                    continue;
                }
                if (line === "ACTIVE") {
                    section = "active";
                    continue;
                }
                if (line.length === 0)
                    continue;
                const fields = root.splitFields(line);
                if (fields.length < 3)
                    continue;
                const type = fields[fields.length - 2];
                if (type !== "vpn" && type !== "wireguard")
                    continue;
                const name = fields.slice(0, -2).join(":");
                const autoconnect = fields[fields.length - 1] === "yes";
                if (section === "active") {
                    active.push(name);
                } else if (all.indexOf(name) === -1) {
                    all.push(name);
                    types[name] = type;
                    autos[name] = autoconnect;
                }
            }
            root.profiles = all.map((name) => ({
                name: name,
                active: active.indexOf(name) !== -1,
                autoconnect: autos[name] === true,
                type: types[name] === "wireguard" ? "WireGuard" : "VPN"
            }));
            root.activeName = active.length > 0 ? active[0] : "";
            root.error = "";
        }
    }

    Process {
        id: actionProc

        stderr: StdioCollector {
            id: actionErr
        }

        onExited: (code) => {
            root.busy = false;
            root.busyName = "";
            if (code !== 0)
                root.error = root.humanError(actionErr.text);
            root.refresh();
        }
    }

    Process {
        id: pickProc

        command: [(Quickshell.shellDir || "") + "/scripts/alba-vpn-pick"]

        stdout: StdioCollector {
            id: pickOut
        }

        stderr: StdioCollector {
            id: pickErr
        }

        onExited: (code) => {
            const path = pickOut.text.trim();
            if (code === 127) {
                root.error = "No hay un selector de archivos instalado.";
                return;
            }
            if (code !== 0) {
                if (pickErr.text.trim().length > 0)
                    root.error = root.humanError(pickErr.text);
                return;
            }
            if (path.length > 0)
                root.importOpenVpn(path);
        }
    }

    Process {
        id: editProc

        stderr: StdioCollector {
            id: editErr
        }

        onExited: (code) => {
            root.busy = false;
            root.busyName = "";
            if (code !== 0)
                root.error = root.humanError(editErr.text);
            root.refresh();
        }
    }
}
