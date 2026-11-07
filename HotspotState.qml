pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// Punto de acceso Wi-Fi gestionado con NetworkManager. Activa un perfil
// dedicado y lo apaga sin tocar la conexión normal del equipo.
Singleton {
    id: root

    readonly property string connectionName: "shell-hotspot"
    // Por defecto, el nombre que verán otros equipos es el de esta máquina.
    property string ssid: HostInfo.displayName
    property string password: "shell12345"
    // Banda en la que emite el punto de acceso: "2.4" o "5".
    property string band: "2.4"
    // Red oculta: no aparece en la lista de redes de los demás equipos.
    property bool hidden: false
    property bool active: false
    property bool busy: false
    property string lastError: ""
    // Clientes conectados, leídos de la tabla de vecinos del kernel.
    property var clients: []
    // Para el apagado automático solo cuentan los clientes que siguen activos;
    // las entradas STALE pueden quedar un rato después de desconectarse.
    readonly property int activeClientCount: {
        let count = 0;
        for (let i = 0; i < root.clients.length; i++) {
            if (root.clients[i].state !== "STALE")
                count++;
        }
        return count;
    }

    readonly property string qrPath: Quickshell.cacheDir + "/shell-hotspot-qr.png"
    property string qrVersion: ""

    readonly property var wifiDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }
    readonly property string ifname: root.wifiDevice ? root.wifiDevice.name : ""

    function bandLabel(value): string {
        return value === "5" ? "5 GHz" : "2.4 GHz";
    }

    function nmBand(value): string {
        return value === "5" ? "a" : "bg";
    }

    // El QR usa el mismo formato que los móviles esperan para conectarse a una
    // red WPA sin escribir nada. Se regenera al cambiar nombre, clave u
    // ocultación. El campo H indica que la red está oculta.
    function escapeQr(value): string {
        return String(value).replace(/([\\;,":])/g, "\\$1");
    }

    function qrPayload(): string {
        return "WIFI:T:WPA;S:" + root.escapeQr(root.ssid)
            + ";P:" + root.escapeQr(root.password)
            + ";H:" + (root.hidden ? "true" : "false") + ";;";
    }

    function refreshQr(): void {
        if (root.ssid.length === 0 || root.password.length < 8)
            return;
        qrDirProc.running = true;
    }

    Timer {
        interval: 60
        running: true
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 600
        running: true
        repeat: false
        onTriggered: root.refreshQr()
    }

    onSsidChanged: root.refreshQr()
    onPasswordChanged: root.refreshQr()
    onHiddenChanged: root.refreshQr()
    onActiveChanged: {
        if (root.active)
            root.refreshClients();
        else
            root.clients = [];
    }

    function refresh(): void {
        if (statusProc.running || root.busy)
            return;
        statusProc.running = true;
    }

    function toggle(): void {
        if (root.busy)
            return;
        if (root.active)
            root.stop();
        else
            root.start();
    }

    function start(): void {
        if (root.busy)
            return;
        if (root.ifname.length === 0) {
            root.lastError = "No hay adaptador Wi-Fi disponible.";
            return;
        }
        if (root.ssid.length === 0) {
            root.lastError = "El nombre de la red no puede estar vacío.";
            return;
        }
        if (root.password.length < 8) {
            root.lastError = "La contraseña debe tener al menos 8 caracteres.";
            return;
        }

        root.busy = true;
        root.lastError = "";
        // El perfil se recrea para aplicar SSID, contraseña, banda y
        // ocultación actuales.
        deleteProc.running = true;
    }

    function stop(): void {
        if (root.busy)
            return;
        root.busy = true;
        root.lastError = "";
        stopProc.running = true;
    }

    function finishStart(code, errText): void {
        root.busy = false;
        if (code !== 0)
            root.lastError = String(errText).trim() || "No se pudo activar el punto de acceso.";
        root.refresh();
        root.refreshClients();
    }

    // Clientes del punto de acceso. `ip neigh` es la fuente más fiable sin
    // depender de iw: muestra la IP y la MAC de los equipos que han pedido
    // dirección al DHCP compartido.
    function refreshClients(): void {
        if (!root.active || root.ifname.length === 0) {
            root.clients = [];
            return;
        }
        if (clientsProc.running)
            return;
        clientsProc.running = true;
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.active
        onTriggered: root.refreshClients()
        onRunningChanged: if (running) root.refreshClients()
    }

    Process {
        id: statusProc

        command: ["nmcli", "-t", "-f", "NAME", "connection", "show", "--active"]

        stdout: StdioCollector {
            id: statusOut
        }

        onExited: {
            const names = statusOut.text.split("\n").map((line) => line.trim());
            root.active = names.indexOf(root.connectionName) !== -1;
        }
    }

    Process {
        id: qrDirProc

        command: ["mkdir", "-p", Quickshell.cacheDir]
        onExited: qrProc.running = true
    }

    Process {
        id: qrProc

        command: ["qrencode", "-o", root.qrPath, "-s", "5", "-m", "2",
            "-l", "M", root.qrPayload()]

        onExited: (code) => {
            if (code === 0)
                root.qrVersion = "" + Date.now();
        }
    }

    Process {
        id: deleteProc

        command: ["nmcli", "connection", "delete", root.connectionName]
        // Si el perfil no existía, nmcli devuelve error; se ignora.
        onExited: addProc.running = true
    }

    Process {
        id: addProc

        command: ["nmcli", "connection", "add",
            "type", "wifi",
            "ifname", root.ifname,
            "con-name", root.connectionName,
            "ssid", root.ssid]

        stderr: StdioCollector {
            id: addErr
        }

        onExited: (code) => {
            if (code !== 0)
                root.finishStart(code, addErr.text);
            else
                modifyProc.running = true;
        }
    }

    Process {
        id: modifyProc

        // Perfil de punto de acceso completo: modo AP, banda, ocultación,
        // compartición IPv4 y WPA2. Se crea a mano (en lugar de usar
        // `nmcli device wifi hotspot`) para poder fijar `hidden` antes de
        // activarlo.
        command: ["nmcli", "connection", "modify", root.connectionName,
            "connection.autoconnect", "no",
            "802-11-wireless.mode", "ap",
            "802-11-wireless.band", root.nmBand(root.band),
            "802-11-wireless.hidden", root.hidden ? "yes" : "no",
            "ipv4.method", "shared",
            "ipv6.method", "ignore",
            "802-11-wireless-security.key-mgmt", "wpa-psk",
            "802-11-wireless-security.psk", root.password]

        stderr: StdioCollector {
            id: modifyErr
        }

        onExited: (code) => {
            if (code !== 0)
                root.finishStart(code, modifyErr.text);
            else
                upProc.running = true;
        }
    }

    Process {
        id: upProc

        command: ["nmcli", "connection", "up", root.connectionName]

        stderr: StdioCollector {
            id: upErr
        }

        onExited: (code) => root.finishStart(code, upErr.text)
    }

    Process {
        id: stopProc

        command: ["nmcli", "connection", "down", root.connectionName]

        stderr: StdioCollector {
            id: stopErr
        }

        onExited: (code) => {
            root.busy = false;
            if (code !== 0)
                root.lastError = stopErr.text.trim() || "No se pudo desactivar el punto de acceso.";
            root.refresh();
        }
    }

    Process {
        id: clientsProc

        command: ["sh", "-c", "ip neigh show dev \"$1\" 2>/dev/null || true",
            "shell", root.ifname]

        stdout: StdioCollector {
            id: clientsOut
        }

        onExited: {
            const list = [];
            const lines = clientsOut.text.split("\n");
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                if (line.length === 0)
                    continue;
                const parts = line.split(/\s+/);
                if (parts.length < 4)
                    continue;
                const ip = parts[0];
                // Solo IPv4 y solo entradas con MAC resuelta.
                if (!/^\d+\.\d+\.\d+\.\d+$/.test(ip))
                    continue;
                const macIndex = parts.indexOf("lladdr");
                if (macIndex === -1 || macIndex + 1 >= parts.length)
                    continue;
                const state = parts[parts.length - 1];
                if (state === "FAILED" || state === "INCOMPLETE")
                    continue;
                list.push({
                    ip: ip,
                    mac: parts[macIndex + 1].toUpperCase(),
                    state: state
                });
            }
            list.sort((a, b) => a.ip.localeCompare(b.ip));
            root.clients = list;
        }
    }
}
