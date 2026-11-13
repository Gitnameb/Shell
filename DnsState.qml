pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// DNS privado (DNS over TLS) con systemd-resolved. El interruptor del centro
// de control decide entre automático (apagado) y el proveedor elegido
// (encendido). La configuración vive en ~/.config/shell/dns.json y el trabajo
// con privilegios lo hace /usr/local/lib/shell/shell-private-dns.
Singleton {
    id: root

    property bool loading: false
    property bool busy: false
    property string error: ""
    property string notice: ""

    // Estado persistido en ~/.config/shell/dns.json.
    property bool enabled: false
    property string provider: "cloudflare"
    property string hostname: ""
    property string manual4: ""
    property string manual6: ""
    property bool disabledForVpn: false

    // Estado de la sesión: la VPN puede suspender el DNS sin apagar el
    // interruptor principal.
    property bool vpnSuspended: false
    property bool applied: false
    // Evita reintentar sin fin si el primer intento de restaurar falla.
    property bool restoreChecked: false
    property bool available: false
    property bool settingsLoaded: false
    property string pendingAction: ""
    property bool quietAction: false
    property double lastEnsure: 0

    readonly property string helperPath: (Quickshell.shellDir || "")
        + "/scripts/network-settings.py"

    readonly property string providerLabel: {
        if (root.provider === "cloudflare")
            return "Cloudflare";
        if (root.provider === "adguard")
            return "AdGuard";
        if (root.provider === "opendns")
            return "OpenDNS";
        if (root.provider === "cleanbrowsing")
            return "CleanBrowsing";
        if (root.provider === "quad9")
            return "Quad9";
        if (root.provider === "hostname")
            return "Personalizado";
        if (root.provider === "manual")
            return "Manual";
        return "Cloudflare";
    }

    readonly property string summary: {
        if (root.loading)
            return "Leyendo…";
        if (!root.enabled)
            return "Automático";
        if (!root.available)
            return "Sin soporte";
        if (root.vpnSuspended)
            return "Desactivado por VPN";
        return root.providerLabel;
    }

    function refresh(): void {
        if (root.loading || root.busy)
            return;
        listProc.running = true;
    }

    function applyPayload(data): void {
        if (typeof data.dnsAvailable === "boolean")
            root.available = data.dnsAvailable;
        if (typeof data.dnsApplied === "boolean")
            root.applied = data.dnsApplied;
        const settings = data.settings;
        if (root.pendingAction !== "dns-ensure"
                && settings && typeof settings === "object") {
            root.enabled = settings.enabled === true;
            root.provider = String(settings.provider || "cloudflare");
            root.hostname = String(settings.hostname || "");
            root.manual4 = String(settings.ipv4 || "");
            root.manual6 = String(settings.ipv6 || "");
            root.disabledForVpn = settings.disabledForVpn === true;
        }
        root.settingsLoaded = true;
    }

    function actionArgs(action, extra): var {
        return ["python3", root.helperPath, action].concat(extra || []);
    }

    function runAction(action, extra, quiet): void {
        if (root.busy || root.loading)
            return;
        root.pendingAction = action;
        root.quietAction = quiet === true;
        root.busy = true;
        if (!root.quietAction) {
            root.error = "";
            root.notice = "";
        }
        actionProc.command = root.actionArgs(action, extra);
        actionProc.running = true;
    }

    function currentSettingsArgs(): var {
        return [root.provider, root.hostname, root.manual4, root.manual6];
    }

    function applyCurrent(): void {
        if (root.busy || root.loading)
            return;
        if (!root.available) {
            root.error = "El DNS privado necesita systemd-resolved. "
                + "Ejecuta el instalador.";
            return;
        }
        if (root.disabledForVpn && VpnState.active) {
            root.vpnSuspended = true;
            root.runAction("dns-suspend", root.currentSettingsArgs());
            return;
        }
        root.vpnSuspended = false;
        root.runAction("dns-on", root.currentSettingsArgs());
    }

    function setEnabled(value): void {
        if (root.busy || root.loading)
            return;
        root.error = "";
        root.notice = "";
        if (!value) {
            root.enabled = false;
            root.vpnSuspended = false;
            root.runAction("dns-off", []);
            return;
        }
        if (!root.available) {
            root.error = "El DNS privado necesita systemd-resolved. "
                + "Ejecuta el instalador.";
            return;
        }
        root.enabled = true;
        root.applyCurrent();
    }

    function saveSettings(): void {
        root.runAction("dns-settings", root.currentSettingsArgs());
    }

    function selectProvider(key): void {
        if (root.busy || root.loading || root.provider === key)
            return;
        root.provider = key;
        root.error = "";
        root.notice = "";
        // Con el DNS apagado solo se elige el proveedor; se guarda con el
        // botón. Con el DNS encendido, los proveedores con servidores fijos
        // se aplican al tocar.
        if (!root.enabled)
            return;
        if (key === "hostname" || key === "manual")
            return;
        root.applyCurrent();
    }

    function setHostname(value): void {
        root.hostname = String(value || "").trim();
    }

    // Los campos manuales se guardan juntos; se aplican con el botón.
    function setManualServers(ipv4, ipv6): void {
        root.manual4 = String(ipv4 || "").trim();
        root.manual6 = String(ipv6 || "").trim();
    }

    // Aplica en una sola orden los valores escritos en la vista.
    function applyWith(hostname, ipv4, ipv6): void {
        root.setHostname(hostname);
        root.setManualServers(ipv4, ipv6);
        root.applyCurrent();
    }

    // Con el DNS apagado, el botón guarda la selección sin activarla.
    function saveWith(hostname, ipv4, ipv6): void {
        root.setHostname(hostname);
        root.setManualServers(ipv4, ipv6);
        root.saveSettings();
    }

    function setDisabledForVpn(value): void {
        if (root.busy || root.loading || root.disabledForVpn === value)
            return;
        root.disabledForVpn = value;
        root.runAction("dns-vpn", [value ? "yes" : "no"], true);
    }

    // Cuando aparece una conexión nueva mientras el DNS privado está activo,
    // se le quita el DNS del router para que use el proveedor global. Solo
    // toca conexiones activas y no reinicia resolved.
    function ensureLinks(): void {
        if (!root.enabled || !root.available || root.vpnSuspended
                || root.busy || root.loading)
            return;
        const now = Date.now();
        if (now - root.lastEnsure < 3000)
            return;
        root.lastEnsure = now;
        root.runAction("dns-ensure", [], true);
    }

    // Estado real del DNS cuando hay VPN: suspende o restaura el proveedor.
    function syncVpn(): void {
        if (!root.settingsLoaded || root.loading || root.busy)
            return;
        if (!root.enabled) {
            root.vpnSuspended = false;
            return;
        }
        if (root.disabledForVpn && VpnState.active) {
            if (!root.vpnSuspended) {
                root.vpnSuspended = true;
                root.runAction("dns-suspend", root.currentSettingsArgs());
            }
            return;
        }
        if (root.vpnSuspended) {
            root.vpnSuspended = false;
            root.applyCurrent();
            return;
        }
        // Si el archivo de resolved desapareció (por ejemplo, el shell se
        // cerró durante una suspensión), se vuelve a aplicar una vez.
        if (!root.applied && root.available && !root.restoreChecked) {
            root.restoreChecked = true;
            root.applyCurrent();
        }
    }

    function readResponse(text, code, stderrText): void {
        const raw = String(text || "").trim();
        if (code !== 0 && raw.length === 0) {
            root.error = String(stderrText || "").trim()
                || "No se pudo aplicar el DNS privado.";
            return;
        }
        try {
            const data = JSON.parse(raw);
            root.applyPayload(data);
            if (!data.ok) {
                root.error = String(data.error || "No se pudo aplicar el DNS.");
                return;
            }
            if (root.quietAction)
                return;
            root.error = "";
            const warning = String(data.warning || "");
            if (warning.length > 0) {
                root.notice = warning;
            } else if (root.pendingAction === "dns-off") {
                root.notice = "DNS automático restaurado.";
            } else if (root.pendingAction === "dns-suspend") {
                root.notice = "DNS privado desactivado mientras la VPN "
                    + "está activa.";
            } else if (root.pendingAction === "dns-settings") {
                root.notice = "Proveedor DNS guardado.";
            } else if (data.count > 0) {
                root.notice = "DNS privado aplicado a " + data.count
                    + (data.count === 1 ? " conexión." : " conexiones.");
            } else {
                root.notice = "DNS privado actualizado.";
            }
        } catch (e) {
            root.error = "No se pudo leer la respuesta del ayudante.";
        }
    }

    Connections {
        target: VpnState

        function onActiveChanged(): void {
            root.syncVpn();
        }
    }

    // Una conexión nueva debe heredar el DNS privado mientras esté activo.
    Connections {
        target: Networking.devices

        function onValuesChanged(): void {
            root.ensureLinks();
        }
    }

    // Respaldo lento para cambios de estado que no alteran la lista de
    // dispositivos (por ejemplo, cambiar de SSID en el mismo adaptador).
    Timer {
        interval: 30000
        repeat: true
        running: root.enabled && root.available && !root.vpnSuspended
        onTriggered: root.ensureLinks()
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
                root.applyPayload(data);
                if (!data.ok)
                    root.error = String(data.error || "")
                        || "No se pudieron leer las conexiones.";
            } catch (e) {
                root.error = "No se pudo leer la lista de conexiones.";
            }
            root.syncVpn();
        }

        onRunningChanged: root.loading = running
    }

    Process {
        id: actionProc

        stdout: StdioCollector {
            id: actionOut
        }

        stderr: StdioCollector {
            id: actionErr
        }

        onExited: (code) => {
            root.busy = false;
            root.readResponse(actionOut.text, code, actionErr.text);
            root.quietAction = false;
            root.pendingAction = "";
            root.syncVpn();
        }

        onRunningChanged: root.busy = running
    }
}
