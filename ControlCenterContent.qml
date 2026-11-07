import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Centro de control compacto: una cuadrícula de 4 controles y una vista de
// opciones avanzadas que sustituye a la cuadrícula al pulsar el nombre.
ColumnLayout {
    id: root

    property bool active: false
    // Vista forzada para el panel rápido de la barra. Vacío usa la vista del
    // panel de notificaciones; con valor, este componente se muestra solo.
    property string viewOverride: ""
    // En modo independiente no hay cuadrícula ni panel de notificaciones: la
    // vista se pinta sola y el botón de volver la cierra.
    property bool standalone: false
    readonly property string view: root.viewOverride.length > 0
        ? root.viewOverride : NotificationState.panelView

    function setView(value): void {
        if (root.standalone) {
            // La vista la fija el panel rápido; se cambia en su estado para
            // que el binding de SidePanel siga mandando.
            QuickPanelState.key = String(value || "");
            return;
        }
        NotificationState.panelView = value;
    }

    function closeView(): void {
        root.pendingNetworkName = "";
        root.wifiListFrozen = false;
        root.syncWifiNetworks();
        if (root.standalone) {
            QuickPanelState.hide();
            return;
        }
        NotificationState.panelView = "";
    }
    // Nombre de la red cuya contraseña se está escribiendo. Se guarda el
    // nombre, no el objeto de NetworkManager, porque los puntos de acceso se
    // destruyen y recrean en cada búsqueda.
    property string pendingNetworkName: ""
    // Formulario para conectarse a una red oculta escribiendo su SSID.
    property bool hiddenNetworkOpen: false
    // Red oculta seleccionada en la lista; su formulario se abre en la fila.
    property string hiddenInlineBssid: ""
    readonly property string hiddenWifiPrefix: "__hidden__:"
    // Red cuya conexión está en curso. Se conserva para poder mostrar el
    // motivo si NetworkManager la rechaza.
    property var connectingNetwork: null
    property string wifiNotice: ""
    // Mientras se escribe una contraseña no se reconstruye la lista, para no
    // borrar el texto de la fila.
    property bool wifiListFrozen: false
    // Bluetooth: vista normal de dispositivos vinculados, modo de vinculación
    // y opciones avanzadas del adaptador detrás del engranaje.
    property bool btAdvanced: false
    property bool btAdding: false
    // Punto de acceso y Wi-Fi: opciones avanzadas detrás de sus engranajes.
    property bool hotspotAdvanced: false
    property bool wifiAdvanced: false
    // Seguridad de la red cuyos ajustes se están editando. Se guarda el valor
    // y no el objeto AccessPoint, que puede desaparecer al escanear.
    property int wifiNetworkSecurity: -1
    property bool wifiNetworkOptions: false
    property string wifiNetworkSsid: ""
    property bool wifiForgetArmed: false
    // Vinculación Bluetooth en curso y error legible para la vista.
    property bool btBusy: false
    property string btBusyAddress: ""
    property string btError: ""
    // Captura de teclas para el atajo del micrófono.
    property bool micShortcutCapture: false

    Component.onCompleted: {
        root.syncWifiNetworks();
        DnsState.refresh();
        if (root.active && root.view === "wifi")
            root.refreshWired();
    }

    Timer {
        id: wifiNetworksTimer
        interval: 400
        repeat: false
        onTriggered: root.syncWifiNetworks()
    }

    Connections {
        target: root.wifiDevice ? root.wifiDevice.networks : null

        function onValuesChanged(): void {
            wifiNetworksTimer.restart();
        }
    }

    spacing: 8

    Process {
        id: pairProc

        stdout: StdioCollector {
            id: pairOut
        }

        stderr: StdioCollector {
            id: pairErr
        }

        onExited: (code) => {
            const text = (pairOut.text || "") + "\n" + (pairErr.text || "");
            root.btBusy = false;
            root.btBusyAddress = "";
            if (text.indexOf("SHELL_PAIR_OK") !== -1) {
                root.btError = "";
                root.btAdding = false;
                if (root.btAdapter)
                    root.btAdapter.discovering = false;
            } else if (text.indexOf("SHELL_PAIR_FAILED") !== -1) {
                root.btError = "No se pudo vincular. Mantén los auriculares "
                    + "en modo vinculación y vuelve a intentarlo.";
            } else if (code !== 0) {
                root.btError = "La vinculación terminó con un error. "
                    + "Comprueba que el dispositivo siga visible.";
            }
        }
    }

    // --------------------------------------------------------------- Wi-Fi
    property var wifiDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }

    // El modelo del Repeater guarda solo nombres SSID. Los objetos
    // AccessPoint de NetworkManager se destruyen al desaparecer una red y un
    // modelo con referencias viejas puede provocar un fallo de Qt al
    // reconstruir las filas. Los objetos se buscan de nuevo por nombre.
    property var wifiNetworks: []

    function networkByName(name) {
        if (!root.wifiDevice || !name)
            return null;
        const list = root.wifiDevice.networks.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === name)
                return list[i];
        }
        return null;
    }

    function isHiddenWifiKey(key): bool {
        return String(key || "").startsWith(root.hiddenWifiPrefix);
    }

    function hiddenBssidFor(key): string {
        const value = String(key || "");
        return root.isHiddenWifiKey(value)
            ? value.slice(root.hiddenWifiPrefix.length) : "";
    }

    function hiddenInfoFor(bssid): var {
        const wanted = String(bssid || "");
        if (wanted.length === 0)
            return null;
        const list = WifiState.hiddenAccessPoints;
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].bssid || "") === wanted)
                return list[i];
        }
        return null;
    }

    // Se actualiza con retardo para agrupar las ráfagas de altas y bajas de
    // puntos de acceso que NetworkManager envía al escanear. Las redes
    // ocultas se mezclan con las visibles y se ordenan por conexión y señal.
    function syncWifiNetworks(): void {
        if (root.wifiListFrozen)
            return;
        const dev = root.wifiDevice;
        if (!dev || !Networking.wifiEnabled) {
            if (root.wifiNetworks.length > 0)
                root.wifiNetworks = [];
            return;
        }
        const entries = [];
        const visible = {};
        const values = dev.networks.values;
        for (let i = 0; i < values.length; i++) {
            if (!values[i].name || values[i].name.length === 0)
                continue;
            visible[values[i].name] = true;
            entries.push({
                key: values[i].name,
                connected: values[i].connected,
                signal: values[i].signalStrength
            });
        }
        if (SettingsState.showHiddenWifi) {
            const hidden = WifiState.hiddenAccessPoints;
            for (let i = 0; i < hidden.length; i++) {
                const point = hidden[i];
                // Una red oculta conectada ya aparece en la lista normal con
                // su SSID real. Se evita duplicarla como «BSSID + SSID».
                const activeName = point.active === true
                    ? String(point.ssid || WifiState.activeConnectionName || "")
                    : "";
                if (activeName.length > 0 && visible[activeName] === true)
                    continue;
                entries.push({
                    key: root.hiddenWifiPrefix + String(point.bssid || ""),
                    connected: point.active === true,
                    signal: Number(point.strength || 0)
                });
            }
        }
        entries.sort((a, b) => (b.connected - a.connected)
            || (b.signal - a.signal)
            || a.key.localeCompare(b.key));
        const names = [];
        for (let i = 0; i < entries.length; i++)
            names.push(entries[i].key);
        if (names.length === root.wifiNetworks.length) {
            let same = true;
            for (let i = 0; i < names.length; i++) {
                if (names[i] !== root.wifiNetworks[i]) {
                    same = false;
                    break;
                }
            }
            if (same)
                return;
        }
        root.wifiNetworks = names;
    }

    property var activeWifi: {
        for (let i = 0; i < root.wifiNetworks.length; i++) {
            const net = root.networkByName(root.wifiNetworks[i]);
            if (net && net.connected)
                return net;
        }
        return null;
    }
    // `wifiDevice.connected` no depende de que el escáner esté activo. Es la
    // fuente fiable para saber si hay Wi-Fi conectada cuando la cuadrícula del
    // centro de control está visible y la lista de redes aún no se ha cargado.
    readonly property bool wifiConnected: root.wifiDevice !== null
        && root.wifiDevice.connected

    // El equipo puede tener varias interfaces cableadas a la vez: la Ethernet
    // del equipo y, por ejemplo, un móvil compartiendo Internet por USB.
    // Primero las conectadas y luego por nombre.
    readonly property var wiredDevices: {
        const list = [];
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wired)
                list.push(devices[i]);
        }
        list.sort((a, b) => (b.connected - a.connected)
            || String(a.name).localeCompare(String(b.name)));
        return list;
    }
    // Interfaz cableada principal para la barra y el resumen.
    readonly property var wiredDevice: root.wiredDevices.length > 0
        ? root.wiredDevices[0] : null
    readonly property bool wiredConnected: {
        for (let i = 0; i < root.wiredDevices.length; i++) {
            if (root.wiredDevices[i].connected)
                return true;
        }
        return false;
    }
    // Hay red cuando hay cable o una Wi-Fi conectada. Si no hay ninguna, la
    // ficha de Red muestra el globo tachado en rojo.
    readonly property bool networkConnected: root.wiredConnected
        || root.wifiConnected
    readonly property string networkIcon: root.networkConnected
        ? ShellIcons.src("globe") : ShellIcons.src("globe-off")
    // `nmManaged` permite distinguir una interfaz que NetworkManager no
    // controla (por ejemplo, porque ifupdown la configuró al instalar Debian)
    // de una que simplemente está desconectada.
    readonly property bool wiredManaged: root.wiredDevice !== null
        && root.wiredDevice.nmManaged

    readonly property bool wifiUnavailable: root.wifiDevice !== null
        && WifiState.deviceState === "unavailable"

    function wiredStatusFor(dev): string {
        if (!dev)
            return "Sin adaptador Ethernet";
        if (!dev.nmManaged)
            return "Ethernet no gestionado";
        return dev.connected
            ? "Ethernet conectado" : "Ethernet desconectado";
    }

    function wiredActionLabelFor(dev): string {
        if (!dev)
            return "";
        if (!dev.nmManaged)
            return "Gestionar";
        return dev.connected ? "Desconectar" : "Conectar";
    }

    function wiredControlFor(dev): string {
        if (!dev)
            return "";
        const label = EthernetState.labelFor(dev.name);
        if (label.length > 0)
            return label;
        return dev.nmManaged ? "NetworkManager" : "sin gestionar";
    }

    // Los nombres usb0/enx…/rndis… corresponden a un móvil compartiendo por
    // USB. No es una identificación perfecta, pero cubre los casos habituales
    // y, si no coincide, se sigue usando el icono de Ethernet.
    function wiredIsUsb(dev): bool {
        const name = String(dev && dev.name || "").toLowerCase();
        return name.indexOf("usb") === 0
            || name.indexOf("enx") === 0
            || name.indexOf("rndis") === 0;
    }

    function wiredActionFor(dev): void {
        if (!dev)
            return;
        root.wifiNotice = "";
        if (!dev.nmManaged) {
            // NetworkManager adopta la interfaz en caliente. El instalador
            // deja el cambio persistente en /etc/network/interfaces.
            dev.nmManaged = true;
            root.refreshWired();
            return;
        }
        if (dev.connected)
            root.disconnectWiredDevice(dev);
        else
            root.connectWiredDevice(dev);
    }

    function refreshWired(): void {
        for (let i = 0; i < root.wiredDevices.length; i++)
            EthernetState.refresh(root.wiredDevices[i].name);
    }

    // ------------------------------------------------------------ Bluetooth
    property var btAdapter: Bluetooth.defaultAdapter
    // Vinculados alguna vez; primero los que están conectados ahora.
    property var btPairedDevices: {
        const list = Bluetooth.devices.values.filter((dev) => dev.paired);
        list.sort((a, b) => (b.connected - a.connected)
            || (a.name || a.address).localeCompare(b.name || b.address));
        return list;
    }
    // Detectados pero todavía sin vincular. Solo se muestran al pulsar «+».
    property var btNewDevices: {
        const list = Bluetooth.devices.values.filter((dev) => !dev.paired
            && ((dev.name && dev.name.length > 0) || dev.address.length > 0));
        list.sort((a, b) => (b.pairing - a.pairing)
            || (a.name || a.address).localeCompare(b.name || b.address));
        return list;
    }
    property var btConnectedDevice: {
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                return list[i];
        }
        return null;
    }
    property string btName: root.btAdapter ? root.btAdapter.name : HostInfo.displayName

    function btVisibleName(dev): string {
        if (!dev)
            return "";
        return dev.name || dev.deviceName || dev.address;
    }

    function btStatus(dev): string {
        if (!dev)
            return "";
        if (dev.connected)
            return "Conectado";
        if (dev.pairing)
            return "Emparejando…";
        if (dev.paired)
            return "Vinculado";
        return "Disponible";
    }

    function btIcon(dev): string {
        return dev && dev.connected
            ? "network-bluetooth-activated"
            : "network-bluetooth";
    }

    // Colores de estado para los iconos del centro de control.
    function wifiStateColor(): color {
        if (root.wiredDevice !== null && !root.wiredManaged)
            return Theme.warning;
        if (root.wiredConnected)
            return Theme.accent;
        if (!root.wifiDevice)
            return Theme.faint;
        if (!Networking.wifiEnabled)
            return Theme.faint;
        if (!root.wifiConnected)
            return Theme.muted;
        if (!root.activeWifi)
            return Theme.accent;
        return root.activeWifi.signalStrength >= 0.5
            ? Theme.accent : Theme.warning;
    }

    function btStateColor(): color {
        if (!root.btAdapter || !root.btAdapter.enabled)
            return Theme.faint;
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++) {
            const dev = list[i];
            if (!dev.connected || !dev.batteryAvailable)
                continue;
            const level = dev.battery * 100;
            if (level <= 10)
                return Theme.danger;
            if (level <= 20)
                return Theme.warning;
            return Theme.text;
        }
        return Theme.text;
    }

    function btActivate(dev): void {
        if (!dev)
            return;
        if (dev.connected)
            dev.disconnect();
        else if (dev.paired)
            dev.connect();
        else
            root.btPair(dev);
    }

    // Quickshell no registra un agente de BlueZ propio, así que `pair()` puede
    // quedarse sin nadie que confirme el emparejamiento. `bluetoothctl` sí
    // registra su agente y funciona con auriculares «Just Works».
    function btPair(dev): void {
        if (!dev || root.btBusy)
            return;
        root.btBusy = true;
        root.btBusyAddress = dev.address;
        root.btError = "";
        pairProc.command = [
            "sh", "-c",
            "if bluetoothctl info \"$1\" 2>/dev/null | grep -q 'Paired: yes'; then "
            + "echo 'SHELL_ALREADY_PAIRED'; "
            + "else out=$(timeout 30 bluetoothctl pair \"$1\" 2>&1); echo \"$out\"; fi; "
            + "if bluetoothctl info \"$1\" 2>/dev/null | grep -q 'Paired: yes'; then "
            + "bluetoothctl trust \"$1\" >/dev/null 2>&1; "
            + "echo SHELL_PAIR_OK; "
            + "timeout 12 bluetoothctl connect \"$1\" 2>&1; "
            + "else echo 'SHELL_PAIR_FAILED'; fi",
            "shell", dev.address
        ];
        pairProc.running = true;
    }

    function btStartAdding(): void {
        root.btAdvanced = false;
        root.btAdding = true;
        root.btError = "";
        if (root.btAdapter) {
            root.btAdapter.pairable = true;
            root.btAdapter.discovering = true;
        }
    }

    function disconnectWiredDevice(dev): void {
        if (!dev)
            return;
        root.wifiNotice = "";
        // `nmcli device disconnect` marca la desconexión como manual y evita
        // que NetworkManager vuelva a activar el perfil automáticamente.
        Quickshell.execDetached(["nmcli", "device", "disconnect", dev.name]);
    }

    function connectWiredDevice(dev): void {
        if (!dev)
            return;
        root.wifiNotice = "";
        Quickshell.execDetached(["nmcli", "device", "connect", dev.name]);
    }

    function btStopAdding(): void {
        root.btAdding = false;
        if (root.btAdapter)
            root.btAdapter.discovering = false;
    }

    function setBluetoothName(value): void {
        const name = String(value).trim();
        if (name.length === 0)
            return;
        aliasProc.command = ["bluetoothctl", "system-alias", name];
        aliasProc.running = true;
    }

    // Al cambiar de vista se corta el escaneo para no dejar la radio ocupada.
    onViewChanged: {
        WifiState.watching = root.active && root.view === "wifi";
        CompositorState.watching = root.active && root.view === "compositor";
        if (root.view !== "mic")
            root.micShortcutCapture = false;
        if (root.view === "wifi" && root.active) {
            root.startWifiScan();
            root.refreshWired();
        } else {
            root.stopNetworkScan();
            root.refreshScan();
        }
        if (root.view !== "wifi") {
            root.wifiNotice = "";
            root.wifiAdvanced = false;
            root.pendingNetworkName = "";
            root.wifiListFrozen = false;
            root.closeHiddenInline();
            root.closeHiddenNetwork();
            root.syncWifiNetworks();
            root.wifiNetworkOptions = false;
            root.wifiNetworkSecurity = -1;
            root.wifiNetworkSsid = "";
            root.wifiForgetArmed = false;
            WifiState.clearProfile();
        }
        if (root.view !== "hotspot")
            root.hotspotAdvanced = false;
        if (root.view !== "bluetooth") {
            root.btAdvanced = false;
            root.btAdding = false;
            if (root.btAdapter)
                root.btAdapter.discovering = false;
        }
    }
    onActiveChanged: {
        WifiState.watching = root.active && root.view === "wifi";
        CompositorState.watching = root.active && root.view === "compositor";
        if (root.active && root.view === "wifi") {
            root.startWifiScan();
            root.refreshWired();
        } else {
            root.stopNetworkScan();
            root.refreshScan();
        }
        if (!root.active && root.btAdapter) {
            root.btAdding = false;
            root.btAdapter.discovering = false;
        }
    }

    readonly property bool airplaneActive: AirplaneState.active

    function setAirplane(enabled): void {
        AirplaneState.setActive(enabled);
    }

    function hotspotClientLabel(state): string {
        if (state === "REACHABLE")
            return "Conectado";
        if (state === "STALE")
            return "Inactivo";
        if (state === "DELAY" || state === "PROBE")
            return "Comprobando";
        return String(state);
    }

    // Nombre de tecla que entiende Hyprland para los atajos.
    function hyprKeyName(key): string {
        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode(key).toUpperCase();
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode(key);
        if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
            return "F" + (key - Qt.Key_F1 + 1);
        if (key === Qt.Key_Space)
            return "SPACE";
        if (key === Qt.Key_Tab)
            return "TAB";
        if (key === Qt.Key_Return || key === Qt.Key_Enter)
            return "RETURN";
        if (key === Qt.Key_Backspace)
            return "BACKSPACE";
        if (key === Qt.Key_Delete)
            return "DELETE";
        if (key === Qt.Key_Insert)
            return "INSERT";
        if (key === Qt.Key_Home)
            return "HOME";
        if (key === Qt.Key_End)
            return "END";
        if (key === Qt.Key_PageUp)
            return "PRIOR";
        if (key === Qt.Key_PageDown)
            return "NEXT";
        if (key === Qt.Key_Left)
            return "LEFT";
        if (key === Qt.Key_Right)
            return "RIGHT";
        if (key === Qt.Key_Up)
            return "UP";
        if (key === Qt.Key_Down)
            return "DOWN";
        if (key === Qt.Key_Print)
            return "PRINT";
        if (key === Qt.Key_Menu)
            return "MENU";
        if (key === Qt.Key_Minus)
            return "MINUS";
        if (key === Qt.Key_Equal)
            return "EQUAL";
        if (key === Qt.Key_BracketLeft)
            return "BRACKETLEFT";
        if (key === Qt.Key_BracketRight)
            return "BRACKETRIGHT";
        if (key === Qt.Key_Backslash)
            return "BACKSLASH";
        if (key === Qt.Key_Semicolon)
            return "SEMICOLON";
        if (key === Qt.Key_Apostrophe)
            return "APOSTROPHE";
        if (key === Qt.Key_Comma)
            return "COMMA";
        if (key === Qt.Key_Period)
            return "PERIOD";
        if (key === Qt.Key_Slash)
            return "SLASH";
        if (key === Qt.Key_QuoteLeft)
            return "GRAVE";
        return "";
    }

    function beginMicShortcut(): void {
        root.micShortcutCapture = true;
        Qt.callLater(() => shortcutCapture.forceActiveFocus());
    }

    function handleMicShortcutKey(event): void {
        if (!root.micShortcutCapture)
            return;
        if (event.isAutoRepeat)
            return;
        // Escape sin modificadores cancela; Retroceso borra el atajo.
        if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
            root.micShortcutCapture = false;
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Backspace
                && event.modifiers === Qt.NoModifier) {
            SettingsState.setMicShortcut("");
            root.micShortcutCapture = false;
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Shift || event.key === Qt.Key_Control
                || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta
                || event.key === Qt.Key_Super_L
                || event.key === Qt.Key_Super_R)
            return;

        const key = root.hyprKeyName(event.key);
        if (key.length === 0)
            return;

        const mods = [];
        if (event.modifiers & Qt.ControlModifier)
            mods.push("CTRL");
        if (event.modifiers & Qt.AltModifier)
            mods.push("ALT");
        if (event.modifiers & Qt.ShiftModifier)
            mods.push("SHIFT");
        if (event.modifiers & Qt.MetaModifier)
            mods.push("SUPER");

        SettingsState.setMicShortcut(
            (mods.length > 0 ? mods.join(" ") + ", " : ", ") + key);
        root.micShortcutCapture = false;
        event.accepted = true;
    }

    function viewTitle(): string {
        if (view === "wifi")
            return root.wifiNetworkOptions && root.wifiNetworkSsid.length > 0
                ? root.wifiNetworkSsid : "Red";
        if (view === "bluetooth")
            return "Bluetooth";
        if (view === "volume")
            return "Volumen";
        if (view === "mic")
            return "Micrófono";
        if (view === "night")
            return "Luz nocturna";
        if (view === "brightness")
            return "Brillo";
        if (view === "extraDim")
            return "Atenuación extra";
        if (view === "hotspot")
            return "Punto de acceso";
        if (view === "music")
            return "Música";
        if (view === "cpu")
            return "Procesador";
        if (view === "gpu")
            return "Gráficos";
        if (view === "net")
            return "Red";
        if (view === "dns")
            return "DNS";
        if (view === "vpn")
            return "VPN";
        if (view === "keyboard")
            return "Teclado";
        if (view === "clipboard")
            return "Portapapeles";
        if (view === "settings")
            return "Ajustes del shell";
        if (view === "windows")
            return "Modo de ventanas";
        if (view === "compositor")
            return "Compositor";
        return "";
    }

    // Resumen legible del estado de una ventana para el diagnóstico.
    function windowStateLabel(win): string {
        if (!win)
            return "";
        const parts = [win.floating ? "flotante" : "mosaico"];
        if (win.minimized)
            parts.push("minimizada");
        if (win.fullscreen)
            parts.push("pantalla completa");
        else if (win.maximized)
            parts.push("maximizada");
        if (win.pinned)
            parts.push("fijada");
        return parts.join(" · ");
    }

    // Detiene por completo el escaneo de Wi-Fi: el del backend de Quickshell
    // y el de nmcli. Se llama al cerrar el panel o salir de la vista Red.
    function stopNetworkScan(): void {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = false;
        WifiState.stop();
    }

    function refreshScan(): void {
        const should = root.active && root.view === "wifi"
            && Networking.wifiEnabled && !root.wifiAdvanced
            && !root.wifiNetworkOptions;
        if (wifiDevice)
            wifiDevice.scannerEnabled = should;
    }

    function startWifiScan(): void {
        if (!root.active || root.view !== "wifi" || !Networking.wifiEnabled
                || root.wifiAdvanced || root.wifiNetworkOptions) {
            root.refreshScan();
            return;
        }
        root.refreshScan();
        WifiState.hasScanned = false;
        WifiState.requestScan();
    }

    function openWifiNetwork(name): void {
        if (!name)
            return;
        root.pendingNetworkName = "";
        root.wifiListFrozen = false;
        root.syncWifiNetworks();
        const net = root.networkByName(name);
        root.wifiNetworkSecurity = net ? net.security : -1;
        root.wifiNetworkSsid = name;
        root.wifiNetworkOptions = true;
        root.wifiAdvanced = false;
        root.wifiForgetArmed = false;
        root.refreshScan();
        WifiState.loadProfile(name);
    }

    function closeWifiNetwork(): void {
        root.wifiNetworkOptions = false;
        root.wifiNetworkSecurity = -1;
        root.wifiNetworkSsid = "";
        root.wifiForgetArmed = false;
        WifiState.clearProfile();
        root.startWifiScan();
    }

    function forgetWifiNetwork(): void {
        if (!root.wifiNetworkOptions
                || root.wifiNetworkSsid.length === 0)
            return;
        if (!root.wifiForgetArmed) {
            root.wifiForgetArmed = true;
            return;
        }
        WifiState.forget(root.wifiNetworkSsid);
        root.closeWifiNetwork();
    }

    onWifiDeviceChanged: {
        wifiNetworksTimer.restart();
        root.syncWifiNetworks();
        refreshScan();
    }

    onWiredDevicesChanged: {
        if (root.active && root.view === "wifi")
            root.refreshWired();
    }

    Connections {
        target: Networking

        function onWifiEnabledChanged(): void {
            wifiNetworksTimer.restart();
            if (!Networking.wifiEnabled) {
                root.closeHiddenInline();
                root.closeHiddenNetwork();
            }
            if (Networking.wifiEnabled && root.active
                    && root.view === "wifi") {
                root.startWifiScan();
            } else {
                root.refreshScan();
            }
        }
    }

    Connections {
        target: WifiState

        function onHiddenConnected(): void {
            root.closeHiddenInline();
            root.closeHiddenNetwork();
            root.syncWifiNetworks();
            root.startWifiScan();
        }

        function onHiddenAccessPointsChanged(): void {
            if (!root.wifiListFrozen)
                wifiNetworksTimer.restart();
        }
    }

    Connections {
        target: SettingsState

        function onShowHiddenWifiChanged(): void {
            if (!SettingsState.showHiddenWifi)
                root.closeHiddenInline();
            wifiNetworksTimer.restart();
        }
    }

    // Al activar el punto de acceso se vuelve a la vista principal con el QR
    // y los dispositivos conectados.
    Connections {
        target: HotspotState

        function onActiveChanged(): void {
            if (HotspotState.active)
                root.hotspotAdvanced = false;
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.active && root.view === "wifi"
        onTriggered: root.refreshWired()
    }

    Process {
        id: aliasProc
    }

    function selectNetwork(name): void {
        const net = root.networkByName(name);
        if (!net)
            return;
        root.wifiNotice = "";
        if (net.connected) {
            net.disconnect();
            return;
        }
        if (net.known || net.security === WifiSecurityType.Open) {
            root.connectingNetwork = net;
            net.connect();
            return;
        }
        // La contraseña se escribe en la propia fila. Se congela la lista
        // para que el escaneo no reconstruya la fila mientras se escribe.
        root.pendingNetworkName = name;
        root.wifiListFrozen = true;
    }

    function connectionErrorText(reason): string {
        if (reason === ConnectionFailReason.NoSecrets)
            return "La red necesita una contraseña válida.";
        if (reason === ConnectionFailReason.WifiAuthTimeout)
            return "La autenticación tardó demasiado; revisa la contraseña.";
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "La red desapareció; acerca el equipo al router.";
        if (reason === ConnectionFailReason.WifiClientDisconnected)
            return "La conexión se cortó antes de completarse.";
        if (reason === ConnectionFailReason.WifiClientFailed)
            return "El adaptador rechazó la conexión.";
        return "No se pudo conectar a la red.";
    }

    function connectWithPassword(name, psk): void {
        const net = root.networkByName(name);
        if (!net) {
            root.wifiNotice = "La red ya no está disponible.";
            root.cancelPassword();
            return;
        }
        if (net.security !== WifiSecurityType.Open
                && psk.length === 0) {
            root.wifiNotice = "Escribe la contraseña.";
            return;
        }
        root.connectingNetwork = net;
        if (net.security === WifiSecurityType.Open)
            net.connect();
        else
            net.connectWithPsk(psk);
        root.pendingNetworkName = "";
        root.wifiListFrozen = false;
        root.syncWifiNetworks();
        root.startWifiScan();
    }

    function cancelPassword(): void {
        root.pendingNetworkName = "";
        root.wifiListFrozen = false;
        root.syncWifiNetworks();
        root.startWifiScan();
    }

    function openHiddenNetwork(): void {
        root.closeHiddenInline();
        root.hiddenNetworkOpen = true;
        WifiState.hiddenError = "";
        hiddenSsidField.text = "";
        hiddenPasswordRow.reset();
        Qt.callLater(function() {
            hiddenSsidField.forceActiveFocus();
        });
    }

    function connectHiddenNetwork(): void {
        if (WifiState.hiddenBusy)
            return;
        root.wifiNotice = "";
        WifiState.connectHidden(hiddenSsidField.text,
            hiddenPasswordRow.text);
    }

    function closeHiddenNetwork(): void {
        root.hiddenNetworkOpen = false;
        hiddenSsidField.text = "";
        hiddenPasswordRow.reset();
        WifiState.hiddenError = "";
    }

    // Formulario de una red oculta concreta, dentro de su propia fila.
    function openHiddenInline(bssid): void {
        root.closeHiddenNetwork();
        root.hiddenInlineBssid = String(bssid || "");
        WifiState.hiddenError = "";
        root.wifiListFrozen = true;
    }

    function closeHiddenInline(): void {
        if (root.hiddenInlineBssid.length === 0)
            return;
        root.hiddenInlineBssid = "";
        root.wifiListFrozen = false;
        WifiState.hiddenError = "";
        root.syncWifiNetworks();
        root.startWifiScan();
    }

    function connectHiddenInline(ssid, psk): void {
        if (WifiState.hiddenBusy)
            return;
        root.wifiNotice = "";
        WifiState.connectHidden(ssid, psk);
    }

    // Si NetworkManager rechaza la conexión, se muestra el motivo en la vista
    // Red en vez de dejar la red como si no hubiera pasado nada.
    Connections {
        target: root.connectingNetwork

        function onConnectionFailed(reason): void {
            if (root.connectingNetwork)
                root.wifiNotice = root.connectionErrorText(reason);
            root.connectingNetwork = null;
        }

        function onConnectedChanged(): void {
            if (root.connectingNetwork && root.connectingNetwork.connected) {
                root.wifiNotice = "";
                root.connectingNetwork = null;
            }
        }
    }

    // Devuelve la ficha visible de un control del centro. Se usa para calcular
    // la posición de inserción al arrastrar dentro de la cuadrícula.
    function centerItem(key): var {
        for (let i = 0; i < grid.children.length; i++) {
            const item = grid.children[i];
            if (item && item.dragKey === key)
                return item;
        }
        return null;
    }

    // Traduce la posición global del puntero a una celda de la cuadrícula fija
    // de dos columnas. Se usan las dos direcciones (arriba/abajo e
    // izquierda/derecha): la fila y la columna salen de la posición real dentro
    // de la cuadrícula, no de comparar con la ficha que se arrastra.
    function updateCenterTarget(): void {
        if (!ControlDrag.active || ControlDrag.origin !== "center"
                || !ControlDrag.overPanel || ControlDrag.key.length === 0) {
            ControlDrag.centerTargetIndex = -1;
            ControlDrag.centerTargetKey = "";
            return;
        }

        const list = BarState.centerControls;
        const from = list.indexOf(ControlDrag.key);
        const bounds = ControlDrag.panelBounds;
        if (from === -1 || bounds.width <= 0 || bounds.height <= 0
                || grid.width <= 0 || grid.height <= 0) {
            ControlDrag.centerTargetIndex = -1;
            ControlDrag.centerTargetKey = "";
            return;
        }

        // Coordenadas del puntero dentro de la cuadrícula, teniendo en cuenta
        // el desplazamiento vertical del panel.
        const point = grid.mapFromItem(null,
            ControlDrag.cursorX - bounds.x,
            ControlDrag.cursorY - bounds.y);

        let cell = null;
        for (let i = 0; i < grid.children.length; i++) {
            const item = grid.children[i];
            if (item && item.dragKey && item.visible) {
                cell = item;
                break;
            }
        }
        const rowHeight = cell
            ? cell.height + grid.rowSpacing
            : 43;
        const halfWidth = grid.width / 2;

        const without = list.filter((key) => key !== ControlDrag.key);
        const row = Math.max(0, Math.floor(point.y / rowHeight));
        const column = point.x > halfWidth ? 1 : 0;
        const target = Math.max(0, Math.min(without.length,
            row * 2 + column));

        if (target !== ControlDrag.centerTargetIndex) {
            ControlDrag.centerTargetIndex = target;
            // Se reordena en vivo: la ficha arrastrada ocupa el hueco y las
            // demás se desplazan igual que quedarán al soltar.
            BarState.moveCenter(ControlDrag.key, target);
        }
        ControlDrag.centerTargetKey = "";
    }

    Connections {
        target: ControlDrag

        function onCursorXChanged(): void {
            root.updateCenterTarget();
        }
        function onCursorYChanged(): void {
            root.updateCenterTarget();
        }
        function onOverPanelChanged(): void {
            root.updateCenterTarget();
        }
        function onOriginChanged(): void {
            root.updateCenterTarget();
        }
        function onActiveChanged(): void {
            root.updateCenterTarget();
        }
    }

    // ------------------------------------------------------------ cuadrícula
    GridLayout {
        id: grid

        Layout.fillWidth: true
        visible: root.view === ""
        columns: 2
        rowSpacing: 5
        columnSpacing: 5

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("wifi") && centerIndex >= 0
            icon: "◌"
            // La ficha representa toda la red (Ethernet y Wi-Fi), no solo una
            // de las dos interfaces. Por eso usa un globo y no el icono de
            // cable o de señal Wi-Fi.
            iconName: "network-workgroup"
            iconSource: root.networkIcon
            iconColor: root.networkConnected
                ? root.wifiStateColor() : Theme.danger
            label: "Red"
            dragKey: "wifi"
            meta: root.wiredConnected
                ? (root.activeWifi ? "Cable + " + root.activeWifi.name : "Cable")
                : (!root.wifiDevice
                    ? "No disponible"
                    : (!Networking.wifiEnabled
                        ? "Desactivada"
                        : (root.activeWifi
                            ? root.activeWifi.name
                            : (root.wifiConnected
                                ? "Wi-Fi conectada"
                                : (root.wifiUnavailable
                                    ? "No disponible" : "Sin conexión")))))
            active: (root.wifiDevice !== null && Networking.wifiEnabled)
                || root.wiredConnected
            // El globo abre la vista de Red; el encendido de Wi-Fi se controla
            // dentro, junto al estado de Ethernet.
            toggleEnabled: false
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            onOpened: root.setView("wifi")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("bluetooth") && centerIndex >= 0
            icon: "ᛒ"
            iconName: root.btAdapter && root.btAdapter.enabled
                ? "network-bluetooth-activated"
                : "network-bluetooth"
            iconSource: ShellIcons.src("bluetooth")
            iconColor: root.btStateColor()
            label: "Bluetooth"
            dragKey: "bluetooth"
            meta: !root.btAdapter
                ? "No disponible"
                : (!root.btAdapter.enabled
                    ? "Desactivado"
                    : (root.btConnectedDevice
                        ? root.btVisibleName(root.btConnectedDevice)
                            + (root.btConnectedDevice.batteryAvailable
                                && SettingsState.showBluetoothPercent
                                ? " · " + Math.round(
                                    root.btConnectedDevice.battery * 100) + "%"
                                : "")
                        : "Activado"))
            active: root.btAdapter !== null && root.btAdapter.enabled
            onToggled: {
                if (root.btAdapter)
                    root.btAdapter.enabled = !root.btAdapter.enabled;
            }
            onOpened: root.setView("bluetooth")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("volume") && centerIndex >= 0
            icon: "◖"
            iconName: Audio.muted
                ? "audio-volume-muted"
                : (Audio.volume > 0.55
                    ? "audio-volume-high"
                    : (Audio.volume > 0.2
                        ? "audio-volume-medium" : "audio-volume-low"))
            iconColor: Audio.muted ? Theme.danger : Theme.accent
            levelIcon: true
            levelKind: "volume"
            level: Audio.volume
            levelMuted: Audio.muted
            label: "Volumen"
            dragKey: "volume"
            meta: Audio.available
                ? (Audio.muted
                    ? "Mudo"
                    : (SettingsState.showVolumePercent
                        ? Math.round(Audio.volume * 100) + "%"
                        : "Activo"))
                : "No disponible"
            active: Audio.available && !Audio.muted
            onToggled: Audio.toggleMute()
            onOpened: root.setView("volume")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("mic") && centerIndex >= 0
            icon: "◉"
            iconName: Audio.micMuted
                ? "microphone-sensitivity-muted"
                : "microphone-sensitivity-high"
            iconColor: Audio.micMuted ? Theme.danger : Theme.accent
            levelIcon: true
            levelKind: "mic"
            level: Audio.micVolume
            levelMuted: Audio.micMuted
            label: "Micrófono"
            dragKey: "mic"
            meta: !Audio.micAvailable
                ? "No disponible"
                : (Audio.micMuted ? "Silenciado" : "Activo")
            active: Audio.micAvailable && !Audio.micMuted
            onToggled: Audio.toggleMicMute()
            onOpened: root.setView("mic")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("night") && centerIndex >= 0
            icon: "☾"
            iconName: "redshift-status-on"
            iconSource: ShellIcons.src("moon")
            iconColor: DisplayState.nightLight ? Theme.warm : Theme.muted
            label: "Luz nocturna"
            dragKey: "night"
            meta: DisplayState.nightLight ? "Activada" : "Desactivada"
            active: DisplayState.nightLight
            onToggled: DisplayState.toggleNight()
            onOpened: root.setView("night")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("airplane") && centerIndex >= 0
            icon: "✈"
            iconName: "flightmode-on"
            iconSource: ShellIcons.src("plane")
            iconColor: root.airplaneActive ? Theme.accent : Theme.muted
            label: "Modo avión"
            dragKey: "airplane"
            meta: root.airplaneActive ? "Activado" : "Desactivado"
            active: root.airplaneActive
            wholeToggle: true
            onToggled: root.setAirplane(!root.airplaneActive)
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("brightness") && centerIndex >= 0
            icon: "☀"
            iconName: "video-display-brightness"
            iconSource: ShellIcons.src("sun")
            iconColor: DisplayState.brightness < 0.99
                ? Theme.accent : Theme.muted
            label: "Brillo"
            dragKey: "brightness"
            toggleEnabled: false
            meta: SettingsState.showBrightnessPercent
                ? Math.round(DisplayState.brightness * 100) + "%"
                : (DisplayState.brightness < 0.99 ? "Ajustado" : "Normal")
            active: DisplayState.brightness < 0.99
            onOpened: root.setView("brightness")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("extraDim") && centerIndex >= 0
            icon: "◐"
            iconName: "brightness-low"
            iconSource: ShellIcons.src("dim")
            iconColor: DisplayState.extraDim > 0.01
                ? Theme.accent : Theme.muted
            label: "Atenuación extra"
            dragKey: "extraDim"
            meta: DisplayState.extraDim > 0.01
                ? (SettingsState.showExtraDimPercent
                    ? Math.round(DisplayState.extraDim * 100) + "%"
                    : "Activada")
                : "Desactivada"
            active: DisplayState.extraDim > 0.01
            onToggled: DisplayState.toggleExtraDim()
            onOpened: root.setView("extraDim")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("hotspot") && centerIndex >= 0
            icon: "◌"
            iconName: "network-wireless-hotspot"
            iconSource: ShellIcons.src("hotspot")
            iconColor: HotspotState.busy
                ? Theme.warning
                : (HotspotState.active ? Theme.accent : Theme.muted)
            label: "Punto de acceso"
            dragKey: "hotspot"
            meta: HotspotState.busy
                ? "Activando…"
                : (HotspotState.active ? HotspotState.ssid : "Desactivado")
            active: HotspotState.active
            onToggled: HotspotState.toggle()
            onOpened: root.setView("hotspot")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("music") && centerIndex >= 0
            icon: "♪"
            iconSource: ShellIcons.src("music")
            iconColor: MusicState.playing ? Theme.accent : Theme.muted
            label: "Música"
            dragKey: "music"
            toggleEnabled: MusicState.available
            meta: MusicState.available
                ? MusicState.title : "Sin reproducción"
            active: MusicState.playing
            onToggled: MusicState.toggle()
            onOpened: root.setView("music")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("keyboard") && centerIndex >= 0
            icon: "⌨"
            iconName: "input-keyboard-symbolic"
            iconSource: ShellIcons.src("keyboard")
            iconColor: KeyboardState.visible
                ? Theme.accent
                : (KeyboardState.available ? Theme.muted : Theme.faint)
            label: "Teclado"
            dragKey: "keyboard"
            meta: SettingsState.keyboardLayout.toUpperCase()
                + (KeyboardState.visible ? " · Visible" : "")
            active: KeyboardState.visible
            onToggled: KeyboardState.toggle()
            onOpened: root.setView("keyboard")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("clipboard") && centerIndex >= 0
            icon: "▤"
            iconSource: ShellIcons.src("clipboard")
            iconColor: ClipboardState.count > 0
                ? Theme.accent : Theme.muted
            label: "Portapapeles"
            dragKey: "clipboard"
            toggleEnabled: false
            meta: ClipboardState.count === 0
                ? "Vacío"
                : (ClipboardState.count === 1
                    ? "1 texto" : ClipboardState.count + " textos")
            active: ClipboardState.count > 0
            onOpened: root.setView("clipboard")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("vpn") && centerIndex >= 0
            icon: "⛨"
            iconName: "network-vpn"
            iconSource: ShellIcons.src("shield")
            iconColor: VpnState.active
                ? Theme.accent
                : (VpnState.configured ? Theme.muted : Theme.faint)
            label: "VPN"
            dragKey: "vpn"
            toggleEnabled: VpnState.configured
            meta: VpnState.active
                ? VpnState.activeLabel
                : (VpnState.configured ? "Desactivada" : "Sin configurar")
            active: VpnState.active
            onToggled: VpnState.toggleActive()
            onOpened: root.setView("vpn")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("cpu") && centerIndex >= 0
            icon: "▣"
            iconName: "cpu"
            iconSource: ShellIcons.src("cpu")
            iconColor: SystemStats.cpuTemp >= 0
                ? SystemStats.thermalColor(SystemStats.cpuTemp) : Theme.muted
            label: "Procesador"
            dragKey: "cpu"
            toggleEnabled: false
            meta: SystemStats.cpuAvailable
                ? Math.round(SystemStats.cpuLoad) + "% · "
                    + Math.round(SystemStats.cpuTemp) + "°"
                : "Sin datos"
            onOpened: root.setView("cpu")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("gpu") && centerIndex >= 0
            icon: "▤"
            iconName: "video-card-inactive-symbolic"
            iconSource: (Quickshell.shellDir || "") + "/icons/gpu.svg"
            iconColor: SystemStats.gpuTemp >= 0
                ? SystemStats.thermalColor(SystemStats.gpuTemp) : Theme.muted
            label: "Gráficos"
            dragKey: "gpu"
            toggleEnabled: false
            meta: SystemStats.gpuAvailable
                ? Math.round(SystemStats.gpuLoad) + "% · "
                    + Math.round(SystemStats.gpuTemp) + "°"
                : "Sin datos"
            onOpened: root.setView("gpu")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("net") && centerIndex >= 0
            icon: "⇅"
            iconSource: ShellIcons.src("net")
            iconColor: (SystemStats.netDown + SystemStats.netUp) > 1024
                ? Theme.accent : Theme.muted
            label: "Red"
            dragKey: "net"
            toggleEnabled: false
            meta: SystemStats.networkAvailable
                ? "↓ " + SystemStats.formatRateShort(SystemStats.netDown)
                    + "  ↑ " + SystemStats.formatRateShort(SystemStats.netUp)
                : "Sin conexión"
            active: (SystemStats.netDown + SystemStats.netUp) > 1024
            onOpened: root.setView("net")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("dns") && centerIndex >= 0
            icon: "D"
            iconSource: ShellIcons.src("dns")
            iconColor: DnsState.allAuto ? Theme.muted : Theme.accent
            label: "DNS"
            dragKey: "dns"
            toggleEnabled: false
            active: !DnsState.allAuto
            meta: DnsState.summary
            onOpened: root.setView("dns")
        }

        CcItem {
            Layout.fillWidth: true
            visible: !BarState.has("settings") && centerIndex >= 0
            icon: "⚙"
            iconName: "applications-system-symbolic"
            iconSource: ShellIcons.src("settings")
            iconColor: Theme.muted
            label: "Ajustes"
            dragKey: "settings"
            toggleEnabled: false
            meta: "Del shell"
            onOpened: root.setView("settings")
        }

    }


    // -------------------------------------------------------- opciones avanzadas
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.view !== ""
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 7
                color: backMouse.containsMouse ? Theme.hover : "transparent"

                Text {
                    anchors.centerIn: parent
                    // En el panel rápido no hay cuadrícula a la que volver: el
                    // mismo botón cierra la ventana.
                    text: root.standalone ? "×" : "‹"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: root.standalone ? 15 : 18
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.wifiNetworkOptions) {
                            root.closeWifiNetwork();
                            return;
                        }
                        root.closeView();
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.viewTitle()
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            // Añadir red oculta: abre el formulario manual con SSID y clave.
            Rectangle {
                visible: root.view === "wifi" && !root.wifiAdvanced
                    && !root.wifiNetworkOptions && Networking.wifiEnabled
                implicitWidth: 26
                implicitHeight: 26
                radius: 7
                color: addWifiMouse.containsMouse ? Theme.hover : "transparent"

                ShellIcon {
                    anchors.centerIn: parent
                    source: ShellIcons.src("plus")
                    color: root.hiddenNetworkOpen
                        ? Theme.accent : Theme.muted
                    size: 14
                    fallback: "+"
                }

                MouseArea {
                    id: addWifiMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.hiddenNetworkOpen)
                            root.closeHiddenNetwork();
                        else
                            root.openHiddenNetwork();
                    }

                    ToolTip.visible: addWifiMouse.containsMouse
                    ToolTip.text: "Añadir red oculta"
                    ToolTip.delay: 400
                }
            }

            // Recargar: pide otra búsqueda de redes Wi-Fi.
            Rectangle {
                visible: root.view === "wifi" && !root.wifiAdvanced
                    && !root.wifiNetworkOptions

                implicitWidth: 26
                implicitHeight: 26
                radius: 7
                color: refreshMouse.containsMouse
                    ? Theme.hover : "transparent"

                Item {
                    id: refreshSpin

                    anchors.centerIn: parent
                    width: 15
                    height: 15

                    ShellIcon {
                        anchors.fill: parent
                        name: "view-refresh-symbolic"
                        fallbackName: "view-refresh"
                        color: (WifiState.scanning || !WifiState.hasScanned)
                            ? Theme.accent : Theme.muted
                        size: 15
                        fallback: "⟳"
                    }

                    RotationAnimator {
                        target: refreshSpin
                        from: 0
                        to: 360
                        duration: 1100
                        loops: Animation.Infinite
                        running: WifiState.scanning || !WifiState.hasScanned
                    }
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startWifiScan()

                    ToolTip.visible: refreshMouse.containsMouse
                    ToolTip.text: "Buscar redes ahora"
                    ToolTip.delay: 400
                }
            }

            // Borra todo el historial del portapapeles.
            Rectangle {
                visible: root.view === "clipboard" && ClipboardState.count > 0
                implicitWidth: 26
                implicitHeight: 26
                radius: 7
                color: clipClearMouse.containsMouse ? Theme.hover : "transparent"

                ShellIcon {
                    anchors.centerIn: parent
                    name: "edit-clear-all"
                    color: clipClearMouse.containsMouse
                        ? Theme.danger : Theme.muted
                    size: 15
                    fallback: "⌫"
                }

                MouseArea {
                    id: clipClearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ClipboardState.clear()
                }
            }

            // Engranaje de opciones: Bluetooth (nombre/visibilidad), punto de
            // acceso (red/clave/banda/ocultación) y Wi-Fi (apagado automático).
            Rectangle {
                id: optionsGear

                readonly property bool open: root.view === "bluetooth"
                    ? root.btAdvanced
                    : (root.view === "hotspot"
                        ? root.hotspotAdvanced
                        : root.wifiAdvanced)

                visible: (root.view === "bluetooth"
                    || root.view === "hotspot"
                    || root.view === "wifi")
                    && !root.wifiNetworkOptions
                implicitWidth: 26
                implicitHeight: 26
                radius: 7
                color: optionsGear.open
                    ? Theme.accentSoft
                    : (gearMouse.containsMouse ? Theme.hover : "transparent")
                border.width: optionsGear.open ? 1 : 0
                border.color: Theme.accentLine

                ShellIcon {
                    anchors.centerIn: parent
                    name: "applications-system-symbolic"
                    fallbackName: "preferences-system-symbolic"
                    color: optionsGear.open ? Theme.accent : Theme.muted
                    size: 14
                    fallback: "⚙"
                }

                MouseArea {
                    id: gearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.view === "bluetooth") {
                            root.btAdding = false;
                            if (root.btAdapter)
                                root.btAdapter.discovering = false;
                            root.btAdvanced = !root.btAdvanced;
                        } else if (root.view === "hotspot") {
                            root.hotspotAdvanced = !root.hotspotAdvanced;
                        } else if (root.view === "wifi") {
                            root.wifiAdvanced = !root.wifiAdvanced;
                        }
                    }
                }
            }

            ShellSwitch {
                visible: (root.view === "wifi"
                    || root.view === "bluetooth"
                    || root.view === "night"
                    || root.view === "extraDim"
                    || root.view === "hotspot"
                    || root.view === "vpn")
                    && !(root.view === "wifi" && root.wifiNetworkOptions)
                enabled: !(root.view === "hotspot" && HotspotState.busy)
                    && !(root.view === "vpn" && !VpnState.configured)
                checked: root.view === "wifi"
                    ? Networking.wifiEnabled
                    : (root.view === "bluetooth"
                        ? (root.btAdapter !== null && root.btAdapter.enabled)
                        : (root.view === "night"
                            ? DisplayState.nightLight
                            : (root.view === "extraDim"
                                ? DisplayState.extraDim > 0.01
                                : (root.view === "hotspot"
                                    ? HotspotState.active
                                    : VpnState.active))))
                onToggled: {
                    if (root.view === "wifi")
                        Networking.wifiEnabled = !Networking.wifiEnabled;
                    else if (root.view === "bluetooth" && root.btAdapter)
                        root.btAdapter.enabled = !root.btAdapter.enabled;
                    else if (root.view === "night")
                        DisplayState.toggleNight();
                    else if (root.view === "extraDim")
                        DisplayState.toggleExtraDim();
                    else if (root.view === "hotspot")
                        HotspotState.toggle();
                    else if (root.view === "vpn")
                        VpnState.toggleActive();
                }
            }
        }

        // ---------------------------------------------------------- Wi-Fi
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "wifi"
            spacing: 5

            // Cables: se muestran todas las interfaces cableadas, no solo una.
            // Así también aparece el móvil compartiendo Internet por USB.
            ListView {
                id: wiredList

                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(0,
                    root.wiredDevices.length * 44 - 2)
                visible: !root.wifiAdvanced && !root.wifiNetworkOptions
                    && root.wiredDevices.length > 0
                interactive: false
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.wiredDevices

                delegate: Rectangle {
                    id: wiredRow

                    required property var modelData
                    readonly property var dev: modelData

                    width: wiredList.width
                    height: 42
                    radius: 8
                    color: wiredRow.dev.connected
                        ? Theme.accentSoft
                        : (wiredRow.dev.nmManaged
                            ? Theme.surfaceAlt : Theme.warningSoft)
                    border.width: 1
                    border.color: wiredRow.dev.connected
                        ? Theme.accentLine
                        : (wiredRow.dev.nmManaged
                            ? Theme.border : Theme.warningLine)

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 7

                        ShellIcon {
                            // Icono propio de puerto Ethernet o USB según el
                            // nombre de la interfaz.
                            source: ShellIcons.src(root.wiredIsUsb(wiredRow.dev)
                                ? "usb" : "wired")
                            color: wiredRow.dev.connected
                                ? Theme.accent
                                : (wiredRow.dev.nmManaged
                                    ? Theme.muted : Theme.warning)
                            size: 17
                            fallback: "◌"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: root.wiredStatusFor(wiredRow.dev)
                                color: wiredRow.dev.connected
                                    ? Theme.accent
                                    : (wiredRow.dev.nmManaged
                                        ? Theme.text : Theme.warning)
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: wiredRow.dev.name + " · "
                                    + root.wiredControlFor(wiredRow.dev)
                                color: wiredRow.dev.nmManaged
                                    ? Theme.faint : Theme.warning
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            implicitWidth: 78
                            implicitHeight: 24
                            radius: 7
                            color: wiredRow.dev.connected
                                && wiredRow.dev.nmManaged
                                ? Theme.surface : Theme.accentSoft
                            border.width: 1
                            border.color: wiredRow.dev.connected
                                && wiredRow.dev.nmManaged
                                ? Theme.border : Theme.accentLine

                            Text {
                                anchors.centerIn: parent
                                text: root.wiredActionLabelFor(wiredRow.dev)
                                color: wiredRow.dev.connected
                                    && wiredRow.dev.nmManaged
                                    ? Theme.muted : Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.wiredActionFor(wiredRow.dev)
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !root.wifiAdvanced && !root.wifiNetworkOptions
                    && !Networking.wifiEnabled
                text: "Wi-Fi desactivado"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !root.wifiAdvanced && !root.wifiNetworkOptions
                    && Networking.wifiEnabled
                    && root.activeWifi === null
                spacing: 6

                Item {
                    id: wifiSpin

                    readonly property bool busy: WifiState.scanning
                        || !WifiState.hasScanned

                    visible: busy
                    Layout.preferredWidth: 15
                    Layout.preferredHeight: 15

                    ShellIcon {
                        anchors.fill: parent
                        visible: wifiSpin.busy
                        name: "view-refresh-symbolic"
                        fallbackName: "view-refresh"
                        color: Theme.accent
                        size: 15
                        fallback: "⟳"
                    }

                    RotationAnimator {
                        target: wifiSpin
                        from: 0
                        to: 360
                        duration: 1400
                        loops: Animation.Infinite
                        running: wifiSpin.busy
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (root.wifiNetworks.length > 0)
                            return "Buscando otras redes…";
                        if (wifiSpin.busy)
                            return "Buscando redes…";
                        if (!root.wifiDevice)
                            return "No hay adaptador Wi-Fi";
                        if (root.wifiUnavailable)
                            return "El adaptador Wi-Fi no está disponible";
                        if (WifiState.lastError.length > 0)
                            return WifiState.lastError;
                        return "No se encontraron redes Wi-Fi";
                    }
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    wrapMode: Text.Wrap
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.wifiNotice.length > 0
                text: root.wifiNotice
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: 8
                wrapMode: Text.Wrap
            }

            // ------------------------------------ añadir red oculta
            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.wifiAdvanced && !root.wifiNetworkOptions
                    && Networking.wifiEnabled && root.hiddenNetworkOpen
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: "AÑADIR RED OCULTA"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                TextField {
                    id: hiddenSsidField

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    placeholderText: "Nombre de la red"
                    color: Theme.text
                    placeholderTextColor: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    leftPadding: 8
                    rightPadding: 8
                    selectByMouse: true
                    background: Rectangle {
                        radius: 7
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.border
                    }
                    onAccepted: hiddenPasswordRow.forcePasswordFocus()
                    Keys.onEscapePressed: root.closeHiddenNetwork()
                }

                WifiPasswordRow {
                    id: hiddenPasswordRow

                    Layout.fillWidth: true
                    busy: WifiState.hiddenBusy
                    placeholderText: "Contraseña (vacía si es abierta)"
                    onSubmitted: root.connectHiddenNetwork()
                    onCancelled: root.closeHiddenNetwork()
                }

                Text {
                    Layout.fillWidth: true
                    visible: WifiState.hiddenError.length > 0
                    text: WifiState.hiddenError
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    wrapMode: Text.Wrap
                }
            }

            Column {
                id: wifiList

                Layout.fillWidth: true
                spacing: 2
                visible: !root.wifiAdvanced && !root.wifiNetworkOptions
                    && root.wifiNetworks.length > 0

                Repeater {
                    model: root.wifiNetworks

                    delegate: Rectangle {
                        id: wifiRow

                        required property string modelData

                        readonly property bool hidden: root.isHiddenWifiKey(
                            wifiRow.modelData)
                        readonly property string hiddenBssid:
                            root.hiddenBssidFor(wifiRow.modelData)
                        readonly property var hiddenInfo:
                            root.hiddenInfoFor(wifiRow.hiddenBssid)
                        // Nombre visible: una red oculta sin conectar se
                        // identifica por su MAC. Si ya está conectada, su
                        // perfil tiene un nombre real (el SSID escrito).
                        readonly property string hiddenTitle: {
                            if (!wifiRow.hidden)
                                return wifiRow.modelData;
                            if (!wifiRow.connected)
                                return wifiRow.hiddenBssid;
                            return String(wifiRow.hiddenInfo
                                    && wifiRow.hiddenInfo.ssid || "")
                                || WifiState.activeConnectionName
                                || wifiRow.hiddenBssid;
                        }
                        readonly property bool hiddenFormOpen: wifiRow.hidden
                            && root.hiddenInlineBssid.length > 0
                            && root.hiddenInlineBssid === wifiRow.hiddenBssid
                        readonly property var net: root.networkByName(wifiRow.modelData)
                        readonly property var point: WifiState.pointFor(wifiRow.modelData)
                        readonly property var bands: wifiRow.hidden
                            ? [] : (wifiRow.point ? wifiRow.point.bands : [])
                        readonly property string securityText: {
                            if (wifiRow.hidden) {
                                const sec = wifiRow.hiddenInfo
                                    ? String(wifiRow.hiddenInfo.security || "")
                                    : "";
                                return sec.length > 0 ? sec : "abierta";
                            }
                            if (wifiRow.point
                                    && wifiRow.point.security.length > 0)
                                return wifiRow.point.security;
                            if (wifiRow.net
                                    && wifiRow.net.security === WifiSecurityType.Open)
                                return "abierta";
                            return wifiRow.net ? "protegida" : "no disponible";
                        }
                        readonly property bool connected: wifiRow.hidden
                            ? (wifiRow.hiddenInfo
                                && wifiRow.hiddenInfo.active === true)
                            : (wifiRow.net !== null && wifiRow.net.connected)
                        readonly property real signalStrength: wifiRow.hidden
                            ? (wifiRow.hiddenInfo
                                ? Number(wifiRow.hiddenInfo.strength || 0) : 0)
                            : (wifiRow.net ? wifiRow.net.signalStrength : 0)
                        // La contraseña se pide en la propia fila, como en
                        // Windows, en vez de en un cuadro aparte al final.
                        readonly property bool passwordOpen: !wifiRow.hidden
                            && root.pendingNetworkName.length > 0
                            && root.pendingNetworkName === wifiRow.modelData

                        width: wifiList.width
                        height: wifiRow.passwordOpen
                            ? 80
                            : (wifiRow.hiddenFormOpen
                                ? (WifiState.hiddenError.length > 0
                                    ? 136 : 118)
                                : 40)
                        radius: 8
                        color: (wifiRow.passwordOpen || wifiRow.hiddenFormOpen)
                            ? Theme.surfaceAlt
                            : (wifiRow.connected
                                ? Theme.accentSoft
                                : (wifiMouse.containsMouse
                                    ? Theme.hover : "transparent"))

                        onHiddenFormOpenChanged: {
                            if (wifiRow.hiddenFormOpen) {
                                inlineHiddenSsid.text = "";
                                inlineHiddenPassword.reset();
                                inlineHiddenSsid.forceActiveFocus();
                            }
                        }

                        MouseArea {
                            id: wifiMouse
                            anchors.fill: parent
                            z: 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (wifiRow.passwordOpen
                                        || wifiRow.hiddenFormOpen)
                                    return;
                                if (wifiRow.hidden) {
                                    root.openHiddenInline(wifiRow.hiddenBssid);
                                    return;
                                }
                                root.selectNetwork(wifiRow.modelData);
                            }
                            onWheel: (wheel) => wheel.accepted = false
                        }

                        RowLayout {
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: 8
                                rightMargin: 8
                            }
                            height: 40
                            z: 1
                            spacing: 6

                            ShellIcon {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                source: WifiState.signalSource(
                                    wifiRow.signalStrength)
                                color: wifiRow.connected
                                    ? (wifiRow.signalStrength >= 0.5
                                        ? Theme.accent : Theme.warning)
                                    : Theme.muted
                                size: 16
                                fallback: "◌"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: wifiRow.hiddenTitle
                                    color: wifiRow.connected
                                        ? Theme.accent
                                        : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: wifiRow.connected
                                        ? Font.DemiBold
                                        : Font.Normal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: wifiRow.securityText
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                            }

                            // Bandas de la red como antes: 2.4G / 5G / 6G.
                            // Se pueden apagar o encender aquí y la misma
                            // preferencia queda editable en el engranaje.
                            Row {
                                spacing: 3
                                visible: !wifiRow.hidden
                                    && wifiRow.bands.length > 0

                                Repeater {
                                    model: wifiRow.bands

                                    delegate: Rectangle {
                                        required property string modelData

                                        readonly property bool on: WifiState.bandOn(
                                            wifiRow.modelData, modelData)

                                        implicitWidth: 22
                                        implicitHeight: 17
                                        radius: 5
                                        color: on
                                            ? Theme.accentSoft
                                            : Theme.surfaceAlt
                                        border.width: 1
                                        border.color: on
                                            ? Theme.accentLine
                                            : Theme.border
                                        opacity: on ? 1 : 0.45

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData + "G"
                                            color: on ? Theme.accent : Theme.faint
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 7
                                            font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.wifiNotice = WifiState.toggleBand(
                                                    wifiRow.modelData,
                                                    modelData);
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: netGear

                                // Las opciones avanzadas solo tienen sentido
                                // en la red a la que ya está conectado.
                                visible: !wifiRow.hidden && wifiRow.connected
                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 6
                                color: netGearMouse.containsMouse
                                    ? Theme.hover : "transparent"

                                ShellIcon {
                                    anchors.centerIn: parent
                                    name: "applications-system-symbolic"
                                    fallbackName: "preferences-system-symbolic"
                                    color: Theme.muted
                                    size: 13
                                    fallback: "⚙"
                                }

                                MouseArea {
                                    id: netGearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openWifiNetwork(
                                        wifiRow.modelData)
                                }
                            }
                        }

                        // Contraseña dentro de la propia fila, con el mismo
                        // aspecto que el formulario de red oculta.
                        WifiPasswordRow {
                            id: inlineAuth

                            visible: wifiRow.passwordOpen
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                topMargin: 42
                                leftMargin: 8
                                rightMargin: 8
                            }
                            z: 2

                            onSubmitted: root.connectWithPassword(
                                wifiRow.modelData, inlineAuth.text)
                            onCancelled: root.cancelPassword()

                            onVisibleChanged: {
                                if (visible) {
                                    inlineAuth.reset();
                                    inlineAuth.forcePasswordFocus();
                                }
                            }
                        }

                        // Formulario de una red oculta dentro de su propia
                        // fila: SSID y contraseña, igual que una red normal.
                        ColumnLayout {
                            visible: wifiRow.hiddenFormOpen
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                topMargin: 42
                                leftMargin: 8
                                rightMargin: 8
                            }
                            spacing: 4
                            z: 2

                            TextField {
                                id: inlineHiddenSsid

                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                placeholderText: "Nombre de la red"
                                color: Theme.text
                                placeholderTextColor: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                leftPadding: 8
                                rightPadding: 8
                                selectByMouse: true
                                background: Rectangle {
                                    radius: 7
                                    color: Theme.surface
                                    border.width: 1
                                    border.color: Theme.border
                                }
                                onAccepted: inlineHiddenPassword.forcePasswordFocus()
                                Keys.onEscapePressed: root.closeHiddenInline()
                            }

                            WifiPasswordRow {
                                id: inlineHiddenPassword

                                Layout.fillWidth: true
                                busy: WifiState.hiddenBusy
                                placeholderText: "Contraseña (vacía si es abierta)"
                                onSubmitted: root.connectHiddenInline(
                                    inlineHiddenSsid.text,
                                    inlineHiddenPassword.text)
                                onCancelled: root.closeHiddenInline()
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: WifiState.hiddenError.length > 0
                                text: WifiState.hiddenError
                                color: Theme.danger
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }

            // ------------------------------------------ ajustes de una red
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.wifiNetworkOptions
                spacing: 7

                Rectangle {
                    Layout.fillWidth: true
                    visible: WifiState.profileQrReady
                    implicitHeight: 106
                    radius: 10
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    RowLayout {
                        anchors {
                            fill: parent
                            margins: 8
                        }
                        spacing: 10

                        Rectangle {
                            implicitWidth: 90
                            implicitHeight: 90
                            radius: 7
                            color: "#f7f7f4"

                            Image {
                                anchors {
                                    fill: parent
                                    margins: 5
                                }
                                source: WifiState.profileQrVersion.length > 0
                                    ? "file://" + WifiState.profileQrPath
                                        + "#" + WifiState.profileQrVersion
                                    : ""
                                cache: false
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                                visible: status === Image.Ready
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                text: root.wifiNetworkSsid
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.wifiNetworkSecurity >= 0
                                    ? (root.wifiNetworkSecurity
                                        === WifiSecurityType.Open
                                        ? "Abierta" : "WPA2")
                                    : ""
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: WifiState.profileFound

                    Text {
                        Layout.fillWidth: true
                        text: "Reconexión automática"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    ShellSwitch {
                        checked: WifiState.profileAutoconnect
                        onToggled: WifiState.setAutoconnect(
                            root.wifiNetworkSsid,
                            !WifiState.profileAutoconnect)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.wifiNetworkSecurity >= 0
                        && WifiState.availableBands(
                            root.wifiNetworkSsid).length > 0

                    Text {
                        text: "Banda"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        width: 54
                    }

                    Row {
                        spacing: 4

                        Repeater {
                            model: WifiState.availableBands(root.wifiNetworkSsid)

                            delegate: Rectangle {
                                required property string modelData

                                readonly property bool on: WifiState.bandOn(
                                    root.wifiNetworkSsid, modelData)

                                implicitWidth: 38
                                implicitHeight: 24
                                radius: 7
                                color: on
                                    ? Theme.accentSoft
                                    : (netBandMouse.containsMouse
                                        ? Theme.hover : Theme.surfaceAlt)
                                border.width: 1
                                border.color: on
                                    ? Theme.accentLine
                                    : Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "G"
                                    color: on ? Theme.accent : Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: on
                                        ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    id: netBandMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const message = WifiState.toggleBand(
                                            root.wifiNetworkSsid, modelData);
                                        root.wifiNotice = message;
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: WifiState.profileError.length > 0
                    text: WifiState.profileError
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: WifiState.profileFound
                    implicitHeight: 30
                    radius: 8
                    color: root.wifiForgetArmed
                        ? Qt.rgba(255 / 255, 122 / 255, 122 / 255, 0.16)
                        : Theme.surfaceAlt
                    border.width: 1
                    border.color: root.wifiForgetArmed
                        ? Theme.danger : Theme.border

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        ShellIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "edit-delete"
                            fallbackName: "user-trash"
                            color: root.wifiForgetArmed
                                ? Theme.danger : Theme.muted
                            size: 14
                            fallback: "⌫"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.wifiForgetArmed
                                ? "Confirmar" : "Olvidar red"
                            color: root.wifiForgetArmed
                                ? Theme.danger : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.forgetWifiNetwork()
                    }
                }
            }

            // ------------------------------------- opciones de Wi-Fi (engranaje)
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.wifiAdvanced && !root.wifiNetworkOptions
                spacing: 7

                Text {
                    Layout.fillWidth: true
                    text: "APAGADO POR INACTIVIDAD"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }


                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Apagar si no hay conexión"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    ShellSwitch {
                        checked: SettingsState.wifiAutoOff
                        onToggled: SettingsState.setWifiAutoOff(
                            !SettingsState.wifiAutoOff)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    opacity: SettingsState.wifiAutoOff ? 1 : 0.45

                    Text {
                        text: "Espera"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        width: 54
                    }

                    Row {
                        spacing: 4

                        Repeater {
                            model: [5, 10, 15, 30]

                            delegate: Rectangle {
                                required property int modelData

                                readonly property bool selected:
                                    SettingsState.wifiMinutes === modelData

                                implicitWidth: 34
                                implicitHeight: 22
                                radius: 6
                                color: selected
                                    ? Theme.accentSoft
                                    : (waitMouse.containsMouse
                                        ? Theme.hover : Theme.surfaceAlt)
                                border.width: 1
                                border.color: selected
                                    ? Theme.accentLine
                                    : Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "m"
                                    color: selected ? Theme.accent : Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: selected
                                        ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    id: waitMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: SettingsState.wifiAutoOff
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: SettingsState.setWifiMinutes(
                                        modelData)
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 2
                    color: Theme.border
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Mostrar redes ocultas"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    ShellSwitch {
                        checked: SettingsState.showHiddenWifi
                        onToggled: SettingsState.showHiddenWifi
                            = !SettingsState.showHiddenWifi
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: SettingsState.showHiddenWifi
                    text: "Añade una entrada para escribir el nombre y la "
                        + "contraseña de una red que no emite su SSID."
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 2
                    color: Theme.border
                }

                ProxySettings {
                    Layout.fillWidth: true
                    active: root.wifiAdvanced
                }
            }
        }

        // ------------------------------------------------------------- DNS
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "dns"
            spacing: 6

            DnsSettings {
                Layout.fillWidth: true
                active: root.view === "dns"
            }
        }

        // ------------------------------------------------------- Bluetooth
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "bluetooth"
            spacing: 6

            Text {
                Layout.fillWidth: true
                visible: root.btAdapter === null || !root.btAdapter.enabled
                text: "Bluetooth desactivado"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            // ------------------------------------------------ opciones (engranaje)
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.btAdvanced && root.btAdapter !== null
                    && root.btAdapter.enabled
                spacing: 7

                Text {
                    Layout.fillWidth: true
                    text: "Opciones del adaptador"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        text: "Nombre visible"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        width: 78
                    }

                    TextField {
                        id: btNameField

                        Layout.fillWidth: true
                        text: root.btName
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        selectByMouse: true
                        onEditingFinished: root.setBluetoothName(text)
                        background: Rectangle {
                            radius: 7
                            color: Theme.surface
                            border.width: 1
                            border.color: Theme.border
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Visible para otros"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    ShellSwitch {
                        checked: root.btAdapter !== null && root.btAdapter.discoverable
                        onToggled: {
                            if (root.btAdapter)
                                root.btAdapter.discoverable = !root.btAdapter.discoverable;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Emparejable"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    ShellSwitch {
                        checked: root.btAdapter !== null && root.btAdapter.pairable
                        onToggled: {
                            if (root.btAdapter)
                                root.btAdapter.pairable = !root.btAdapter.pairable;
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 2
                    color: Theme.border
                }

                Text {
                    Layout.fillWidth: true
                    text: "APAGADO POR INACTIVIDAD"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }


                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Apagar si no hay conexión"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    ShellSwitch {
                        checked: SettingsState.btAutoOff
                        onToggled: SettingsState.setBtAutoOff(
                            !SettingsState.btAutoOff)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    opacity: SettingsState.btAutoOff ? 1 : 0.45

                    Text {
                        text: "Espera"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        width: 54
                    }

                    Row {
                        spacing: 4

                        Repeater {
                            model: [5, 10, 15, 30]

                            delegate: Rectangle {
                                required property int modelData

                                readonly property bool selected:
                                    SettingsState.btMinutes === modelData

                                implicitWidth: 34
                                implicitHeight: 22
                                radius: 6
                                color: selected
                                    ? Theme.accentSoft
                                    : (btWaitMouse.containsMouse
                                        ? Theme.hover : Theme.surfaceAlt)
                                border.width: 1
                                border.color: selected
                                    ? Theme.accentLine
                                    : Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "m"
                                    color: selected ? Theme.accent : Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: selected
                                        ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    id: btWaitMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: SettingsState.btAutoOff
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: SettingsState.setBtMinutes(
                                        modelData)
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Layout.preferredHeight: 1
                    color: Theme.border
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Mostrar porcentaje de batería"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    ShellSwitch {
                        checked: SettingsState.showBluetoothPercent
                        onToggled: SettingsState.showBluetoothPercent =
                            !SettingsState.showBluetoothPercent
                    }
                }

            }

            // ---------------------------------------------- dispositivos vinculados
            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.btAdvanced && !root.btAdding
                    && root.btAdapter !== null && root.btAdapter.enabled
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: "VINCULADOS"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                    }

                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 24
                        radius: 7
                        color: addMouse.containsMouse ? Theme.hover : Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: addMouse.containsMouse ? Theme.accent : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.btStartAdding()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.btPairedDevices.length === 0
                    text: "Sin dispositivos vinculados"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: btPairedList

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(6, root.btPairedDevices.length) * 36
                    visible: root.btPairedDevices.length > 0
                    clip: true
                    spacing: 2
                    model: root.btPairedDevices
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: btRow

                        required property var modelData

                        width: btPairedList.width
                        height: 36
                        radius: 8
                        color: btMouse.containsMouse ? Theme.hover : "transparent"

                        MouseArea {
                            id: btMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.btActivate(btRow.modelData)
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 8
                                rightMargin: 26
                            }
                            spacing: 7

                            ShellIcon {
                                Layout.preferredWidth: 15
                                Layout.preferredHeight: 15
                                name: root.btIcon(btRow.modelData)
                                color: {
                                    const dev = btRow.modelData;
                                    if (dev.connected && dev.batteryAvailable) {
                                        const level = dev.battery * 100;
                                        if (level <= 10)
                                            return Theme.danger;
                                        if (level <= 20)
                                            return Theme.warning;
                                        return Theme.text;
                                    }
                                    return dev.connected
                                        ? Theme.accent : Theme.muted;
                                }
                                size: 15
                                fallback: "ᛒ"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: root.btVisibleName(btRow.modelData)
                                    color: btRow.modelData.connected
                                        ? Theme.accent
                                        : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: btRow.modelData.connected
                                        ? Font.DemiBold
                                        : Font.Normal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.btStatus(btRow.modelData)
                                        + (btRow.modelData.batteryAvailable
                                            && SettingsState.showBluetoothPercent
                                            ? " · " + Math.round(
                                                btRow.modelData.battery * 100) + "%"
                                            : "")
                                    color: btRow.modelData.connected
                                        ? Theme.accent
                                        : Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // Olvidar un dispositivo vinculado.
                        Text {
                            anchors {
                                right: parent.right
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            z: 2
                            text: "×"
                            color: forgetMouse.containsMouse ? Theme.danger : Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 14

                            MouseArea {
                                id: forgetMouse
                                anchors.fill: parent
                                anchors.margins: -5
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: btRow.modelData.forget()
                            }
                        }
                    }
                }

            }

            // -------------------------------------------------- vincular uno nuevo
            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.btAdvanced && root.btAdding
                    && root.btAdapter !== null && root.btAdapter.enabled
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: "VINCULAR DISPOSITIVO"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                    }

                    Text {
                        text: "Cancelar"
                        color: cancelMouse.containsMouse ? Theme.accent : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.btStopAdding()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Buscando dispositivos…"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.btNewDevices.length === 0
                    text: root.btAdapter !== null && root.btAdapter.discovering
                        ? "Buscando… acerca el dispositivo."
                        : "No hay dispositivos nuevos."
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.btError.length > 0
                    text: root.btError
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: btNewList

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(6, root.btNewDevices.length) * 36
                    visible: root.btNewDevices.length > 0
                    clip: true
                    spacing: 2
                    model: root.btNewDevices
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: btNewRow

                        required property var modelData

                        width: btNewList.width
                        height: 36
                        radius: 8
                        color: btNewHover.hovered ? Theme.hover : "transparent"

                        HoverHandler {
                            id: btNewHover
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 8
                                rightMargin: 8
                            }
                            spacing: 7

                            Image {
                                Layout.preferredWidth: 15
                                Layout.preferredHeight: 15
                                source: Quickshell.hasThemeIcon("network-bluetooth")
                                    ? Quickshell.iconPath("network-bluetooth") : ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                visible: status === Image.Ready
                                opacity: 0.6
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: root.btVisibleName(btNewRow.modelData)
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: btNewRow.modelData.address
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                implicitWidth: 58
                                implicitHeight: 24
                                radius: 7
                                color: root.btBusy
                                        && root.btBusyAddress === btNewRow.modelData.address
                                    ? Theme.accentSoft : Theme.surfaceAlt
                                border.width: 1
                                border.color: Theme.accentLine
                                opacity: root.btBusy ? 0.65 : 1

                                Text {
                                    anchors.centerIn: parent
                                    text: root.btBusy
                                            && root.btBusyAddress === btNewRow.modelData.address
                                        ? "…" : "Vincular"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !root.btBusy
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.btPair(btNewRow.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------- Volumen
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "volume"
            spacing: 7

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: Audio.available
                        ? (Audio.muted ? "Silenciado" : Math.round(Audio.volume * 100) + "%")
                        : "No disponible"
                    color: Audio.muted ? Theme.danger : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                Text {
                    text: Audio.muted ? "Activar" : "Silenciar"
                    visible: Audio.available
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMute()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 3
                Layout.preferredHeight: 1
                color: Theme.border
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 1
                text: "APLICACIONES CON AUDIO"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Text {
                Layout.fillWidth: true
                visible: Audio.streams.length === 0
                text: "Ninguna aplicación está reproduciendo audio."
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 9
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: Audio.streams

                delegate: Rectangle {
                    id: streamRow

                    required property var modelData

                    readonly property var stream: modelData
                    readonly property bool muted: stream.audio
                        ? stream.audio.muted : false

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: streamMouse.containsMouse ? Theme.hover : "transparent"

                    MouseArea {
                        id: streamMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 7
                            rightMargin: 7
                        }
                        spacing: 7

                        Item {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16

                            ShellIcon {
                                anchors.fill: parent
                                source: ShellIcons.src(streamRow.muted
                                    ? "volume-off" : "volume-3")
                                color: streamRow.muted ? Theme.danger : Theme.accent
                                size: 15
                                fallback: "◖"
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Audio.toggleNodeMute(streamRow.stream)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: Audio.streamName(streamRow.stream)
                                color: streamRow.muted ? Theme.muted : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: Audio.streamDetail(streamRow.stream)
                                visible: text.length > 0
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }

                        ShellSlider {
                            Layout.preferredWidth: 86
                            Layout.alignment: Qt.AlignVCenter
                            from: 0
                            to: 1
                            value: streamRow.stream.audio
                                ? streamRow.stream.audio.volume : 0
                            enabled: streamRow.stream.audio !== null
                            onMoved: Audio.setNodeVolume(streamRow.stream, value)
                        }

                        Text {
                            Layout.preferredWidth: 30
                            horizontalAlignment: Text.AlignRight
                            text: streamRow.stream.audio
                                ? Math.round(streamRow.stream.audio.volume * 100) + "%"
                                : "—"
                            color: streamRow.muted ? Theme.faint : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: "SALIDAS DE AUDIO"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Text {
                Layout.fillWidth: true
                visible: Audio.sinks.length === 0
                text: "No hay salidas de audio disponibles."
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }

            ListView {
                id: sinkList

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(5, Audio.sinks.length) * 36
                visible: Audio.sinks.length > 0
                clip: true
                spacing: 2
                model: Audio.sinks
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: sinkRow

                    required property var modelData

                    readonly property bool selected: Audio.sink === sinkRow.modelData

                    width: sinkList.width
                    height: 36
                    radius: 8
                    color: sinkRow.selected
                        ? Theme.accentSoft
                        : (sinkMouse.containsMouse ? Theme.hover : "transparent")
                    border.width: sinkRow.selected ? 1 : 0
                    border.color: Theme.accentLine

                    MouseArea {
                        id: sinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.setDefaultSink(sinkRow.modelData)
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 8

                        ShellIcon {
                            Layout.preferredWidth: 15
                            Layout.preferredHeight: 15
                            name: "audio-card"
                            color: sinkRow.selected
                                ? Theme.accent : Theme.muted
                            size: 15
                            fallback: "◖"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: Audio.nodeName(sinkRow.modelData)
                                color: sinkRow.selected ? Theme.accent : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: sinkRow.selected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: sinkRow.selected ? "Salida predeterminada" : "Cambiar a esta salida"
                                color: sinkRow.selected ? Theme.accent : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            visible: sinkRow.selected
                            text: "✓"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            // ShellSlider tiene una altura táctil real; el Slider anterior tenía
            // altura implícita cero y por eso el arrastre no recibía eventos.
            ShellSlider {
                id: volumeSlider

                Layout.fillWidth: true
                from: 0
                to: 1
                stepSize: 0.02
                value: Audio.volume
                enabled: Audio.available
                onMoved: Audio.setVolume(value)
                onPressedChanged: if (!pressed) Audio.setVolume(value)
            }

            Text {
                Layout.fillWidth: true
                visible: Audio.sink !== null
                text: "Nivel de " + Audio.nodeName(Audio.sink)
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Mostrar porcentaje"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                ShellSwitch {
                    checked: SettingsState.showVolumePercent
                    onToggled: SettingsState.showVolumePercent =
                        !SettingsState.showVolumePercent
                }
            }

        }

        // ------------------------------------------------------ Micrófono
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "mic"
            spacing: 7

            Text {
                Layout.fillWidth: true
                text: !Audio.micAvailable
                    ? "No hay micrófono disponible"
                    : (Audio.micMuted ? "Micrófono silenciado" : "Micrófono activo")
                color: Audio.micMuted ? Theme.danger : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: "ENTRADAS DE AUDIO"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Text {
                Layout.fillWidth: true
                visible: Audio.sources.length === 0
                text: "No hay entradas de audio disponibles."
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }

            ListView {
                id: sourceList

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(5, Audio.sources.length) * 36
                visible: Audio.sources.length > 0
                clip: true
                spacing: 2
                model: Audio.sources
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: sourceRow

                    required property var modelData

                    readonly property bool selected: Audio.source === sourceRow.modelData

                    width: sourceList.width
                    height: 36
                    radius: 8
                    color: sourceRow.selected
                        ? Theme.accentSoft
                        : (sourceMouse.containsMouse ? Theme.hover : "transparent")
                    border.width: sourceRow.selected ? 1 : 0
                    border.color: Theme.accentLine

                    MouseArea {
                        id: sourceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.setDefaultSource(sourceRow.modelData)
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 8

                        ShellIcon {
                            Layout.preferredWidth: 15
                            Layout.preferredHeight: 15
                            source: ShellIcons.src("mic")
                            color: sourceRow.selected
                                ? Theme.accent : Theme.muted
                            size: 15
                            fallback: "◉"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: Audio.nodeName(sourceRow.modelData)
                                color: sourceRow.selected ? Theme.accent : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: sourceRow.selected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: sourceRow.selected ? "Entrada predeterminada" : "Usar esta entrada"
                                color: sourceRow.selected ? Theme.accent : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            visible: sourceRow.selected
                            text: "✓"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2

                Text {
                    Layout.fillWidth: true
                    text: "Silenciar micrófono"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                ShellSwitch {
                    checked: Audio.micMuted
                    onToggled: Audio.toggleMicMute()
                }
            }

            // Atajo global para silenciar o reactivar el micrófono.
            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    Layout.fillWidth: true
                    text: "Atajo"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    id: micShortcutChip

                    implicitHeight: 24
                    implicitWidth: Math.max(80,
                        shortcutLabel.implicitWidth + 32)
                    radius: 7
                    color: root.micShortcutCapture
                        ? Theme.accentSoft
                        : (shortcutMouse.containsMouse
                            ? Theme.hover : Theme.surfaceAlt)
                    border.width: 1
                    border.color: root.micShortcutCapture
                        ? Theme.accent : Theme.border

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        ShellIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: ShellIcons.src("keyboard")
                            color: root.micShortcutCapture
                                ? Theme.accent : Theme.muted
                            size: 14
                            fallback: "⌨"
                        }

                        Text {
                            id: shortcutLabel

                            anchors.verticalCenter: parent.verticalCenter
                            text: root.micShortcutCapture
                                ? "Pulsa…"
                                : (SettingsState.micShortcut.length > 0
                                    ? SettingsState.micShortcut : "Sin atajo")
                            color: root.micShortcutCapture
                                ? Theme.accent
                                : (SettingsState.micShortcut.length > 0
                                    ? Theme.text : Theme.faint)
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: shortcutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.beginMicShortcut()
                    }
                }

                Rectangle {
                    visible: SettingsState.micShortcut.length > 0
                        && !root.micShortcutCapture
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: clearShortcutMouse.containsMouse
                        ? Theme.hover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: clearShortcutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setMicShortcut("")
                    }
                }
            }

            Item {
                id: shortcutCapture

                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                visible: root.micShortcutCapture
                focus: root.micShortcutCapture

                Keys.onPressed: (event) => root.handleMicShortcutKey(event)
                onVisibleChanged: {
                    if (visible)
                        forceActiveFocus();
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Nivel del micrófono"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    text: Math.round(Audio.micVolume * 100) + "%"
                    color: Audio.micMuted ? Theme.danger : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            ShellSlider {
                Layout.fillWidth: true
                from: 0
                to: 1
                value: Audio.micVolume
                enabled: Audio.micAvailable
                onMoved: Audio.setMicVolume(value)
            }

            Text {
                Layout.fillWidth: true
                visible: Audio.source !== null
                text: "Entrada: " + Audio.nodeName(Audio.source)
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                elide: Text.ElideRight
            }
        }

        // --------------------------------------------------- Luz nocturna
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "night"
            spacing: 8


            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Intensidad"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    text: Math.round(DisplayState.nightStrength * 100) + "%"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            ShellSlider {
                Layout.fillWidth: true
                from: 0
                to: 1
                stepSize: 0.05
                value: DisplayState.nightStrength
                enabled: DisplayState.nightLight
                onMoved: DisplayState.setNightStrength(value)
            }
        }

        // ---------------------------------------------------------- Brillo
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "brightness"
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Brillo"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    text: Math.round(DisplayState.brightness * 100) + "%"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            ShellSlider {
                Layout.fillWidth: true
                from: 0
                to: 1
                stepSize: 0.05
                value: DisplayState.brightness
                onMoved: DisplayState.setBrightness(value)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Mostrar porcentaje"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                ShellSwitch {
                    checked: SettingsState.showBrightnessPercent
                    onToggled: SettingsState.showBrightnessPercent =
                        !SettingsState.showBrightnessPercent
                }
            }
        }

        // ------------------------------------------------- Atenuación extra
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "extraDim"
            spacing: 8


            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Atenuación"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    text: DisplayState.extraDim > 0.01
                        ? Math.round(DisplayState.extraDim * 100) + "%"
                        : "Desactivada"
                    color: DisplayState.extraDim > 0.01
                        ? Theme.accent
                        : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            ShellSlider {
                Layout.fillWidth: true
                from: 0
                to: 0.8
                stepSize: 0.05
                value: DisplayState.extraDim
                onMoved: DisplayState.setExtraDim(value)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Mostrar porcentaje"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                ShellSwitch {
                    checked: SettingsState.showExtraDimPercent
                    onToggled: SettingsState.showExtraDimPercent =
                        !SettingsState.showExtraDimPercent
                }
            }
        }

        // ------------------------------------------------- Punto de acceso
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "hotspot"
            spacing: 7

            // -------------------------------------------- vista principal
            // Solo el QR y los dispositivos conectados; el resto vive en el
            // engranaje para que la vista no se sature.
            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.hotspotAdvanced
                spacing: 7

                Text {
                    Layout.fillWidth: true
                    text: HotspotState.busy
                        ? "Activando el punto de acceso…"
                        : (HotspotState.active
                            ? "Compartiendo la conexión · "
                                + HotspotState.clients.length
                                + (HotspotState.clients.length === 1
                                    ? " dispositivo" : " dispositivos")
                            : "Apagado")
                    color: HotspotState.active ? Theme.accent : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }

                // QR con los datos actuales: se regenera al editar nombre,
                // clave u ocultación.
                Rectangle {
                    Layout.fillWidth: true
                    visible: HotspotState.password.length >= 8
                    implicitHeight: 106
                    radius: 10
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border
                    opacity: HotspotState.active ? 1 : 0.62

                    RowLayout {
                        anchors {
                            fill: parent
                            margins: 8
                        }
                        spacing: 10

                        Rectangle {
                            implicitWidth: 90
                            implicitHeight: 90
                            radius: 7
                            color: "#f7f7f4"

                            Image {
                                anchors {
                                    fill: parent
                                    margins: 5
                                }
                                source: HotspotState.qrVersion.length > 0
                                    ? "file://" + HotspotState.qrPath
                                        + "#" + HotspotState.qrVersion
                                    : ""
                                cache: false
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                                visible: status === Image.Ready
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: HotspotState.ssid.length > 0
                                    ? HotspotState.ssid : "Sin nombre"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "WPA2 · " + HotspotState.bandLabel(HotspotState.band)
                                    + (HotspotState.hidden ? " · red oculta" : "")
                                    + (HotspotState.active ? " · activo" : " · apagado")
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }
                    }
                }


                // ------------------------------------------ dispositivos
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: "DISPOSITIVOS CONECTADOS"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                    }

                    Rectangle {
                        visible: HotspotState.clients.length > 0
                        implicitWidth: 20
                        implicitHeight: 16
                        radius: 8
                        color: Theme.accentSoft
                        border.width: 1
                        border.color: Theme.accentLine

                        Text {
                            anchors.centerIn: parent
                            text: HotspotState.clients.length
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                        }
                    }
                }


                Text {
                    Layout.fillWidth: true
                    visible: HotspotState.active && HotspotState.clients.length === 0
                    text: "Esperando dispositivos…"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }

                ListView {
                    id: hotspotClientList

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(4, HotspotState.clients.length) * 34
                    visible: HotspotState.clients.length > 0
                    clip: true
                    spacing: 2
                    model: HotspotState.clients
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: hotspotClientRow

                        required property var modelData

                        width: hotspotClientList.width
                        height: 34
                        radius: 8
                        color: clientHover.hovered ? Theme.hover : "transparent"

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 8
                                rightMargin: 8
                            }
                            spacing: 8

                            ShellIcon {
                                Layout.preferredWidth: 15
                                Layout.preferredHeight: 15
                                name: "computer"
                                color: hotspotClientRow.modelData.state
                                    === "REACHABLE"
                                    ? Theme.accent : Theme.muted
                                size: 15
                                fallback: "▭"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: hotspotClientRow.modelData.ip
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: hotspotClientRow.modelData.mac
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                text: root.hotspotClientLabel(
                                    hotspotClientRow.modelData.state)
                                color: hotspotClientRow.modelData.state === "REACHABLE"
                                    ? Theme.accent : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }
                        }

                        HoverHandler {
                            id: clientHover
                        }
                    }
                }

            }

            // ------------------------------------------------ opciones
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.hotspotAdvanced
                spacing: 7

                Text {
                    Layout.fillWidth: true
                    text: "OPCIONES DEL PUNTO DE ACCESO"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Red"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        width: 54
                    }

                    TextField {
                        Layout.fillWidth: true
                        text: HotspotState.ssid
                        enabled: !HotspotState.active && !HotspotState.busy
                        opacity: enabled ? 1 : 0.55
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        selectByMouse: true
                        onTextEdited: HotspotState.ssid = text
                        background: Rectangle {
                            radius: 7
                            color: Theme.surface
                            border.width: 1
                            border.color: Theme.border
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Clave"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        width: 54
                    }

                    TextField {
                        Layout.fillWidth: true
                        text: HotspotState.password
                        enabled: !HotspotState.active && !HotspotState.busy
                        opacity: enabled ? 1 : 0.55
                        echoMode: TextInput.Password
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        selectByMouse: true
                        onTextEdited: HotspotState.password = text
                        background: Rectangle {
                            radius: 7
                            color: Theme.surface
                            border.width: 1
                            border.color: Theme.border
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Banda"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        width: 54
                    }

                    Row {
                        spacing: 4

                        Repeater {
                            model: ["2.4", "5"]

                            delegate: Rectangle {
                                required property string modelData

                                readonly property bool selected:
                                    HotspotState.band === modelData

                                implicitWidth: 58
                                implicitHeight: 24
                                radius: 7
                                color: selected
                                    ? Theme.accentSoft
                                    : (bandMouse.containsMouse
                                        ? Theme.hover : Theme.surfaceAlt)
                                border.width: 1
                                border.color: selected
                                    ? Theme.accentLine
                                    : Theme.border
                                opacity: (HotspotState.active || HotspotState.busy)
                                    ? 0.55 : 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + " GHz"
                                    color: selected ? Theme.accent : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: selected
                                        ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    id: bandMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !HotspotState.active && !HotspotState.busy
                                    onClicked: HotspotState.band = modelData
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Ocultar red"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    ShellSwitch {
                        checked: HotspotState.hidden
                        enabled: !HotspotState.active && !HotspotState.busy
                        onToggled: HotspotState.hidden = !HotspotState.hidden
                    }
                }


                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 2
                    color: Theme.border
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Apagar si nadie se conecta"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    ShellSwitch {
                        checked: SettingsState.hotspotAutoOff
                        onToggled: SettingsState.setHotspotAutoOff(
                            !SettingsState.hotspotAutoOff)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    opacity: SettingsState.hotspotAutoOff ? 1 : 0.45

                    Text {
                        text: "Espera"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        width: 54
                    }

                    Row {
                        spacing: 4

                        Repeater {
                            model: [5, 10, 15, 30]

                            delegate: Rectangle {
                                required property int modelData

                                readonly property bool selected:
                                    SettingsState.hotspotMinutes === modelData

                                implicitWidth: 34
                                implicitHeight: 22
                                radius: 6
                                color: selected
                                    ? Theme.accentSoft
                                    : (hotspotWaitMouse.containsMouse
                                        ? Theme.hover : Theme.surfaceAlt)
                                border.width: 1
                                border.color: selected
                                    ? Theme.accentLine
                                    : Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "m"
                                    color: selected ? Theme.accent : Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: selected
                                        ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    id: hotspotWaitMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: SettingsState.hotspotAutoOff
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: SettingsState.setHotspotMinutes(
                                        modelData)
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

            }

            Text {
                Layout.fillWidth: true
                visible: HotspotState.lastError !== ""
                text: HotspotState.lastError
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: 9
                wrapMode: Text.Wrap
            }
        }

        // ------------------------------------------------------- Música
        MusicView {
            Layout.fillWidth: true
            visible: root.view === "music"
        }

        // --------------------------------------------------- Rendimiento
        PerfView {
            Layout.fillWidth: true
            visible: root.view === "cpu"
            kind: "cpu"
        }

        PerfView {
            Layout.fillWidth: true
            visible: root.view === "gpu"
            kind: "gpu"
        }

        // ----------------------------------------------------------- Red
        NetView {
            Layout.fillWidth: true
            visible: root.view === "net"
        }

        // ----------------------------------------------------------- VPN
        VpnView {
            Layout.fillWidth: true
            visible: root.view === "vpn"
        }

        // ------------------------------------------------------- Teclado
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "keyboard"
            spacing: 8

            Flow {
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: SettingsState.keyboardLayouts

                    delegate: Rectangle {
                        id: layoutChip

                        required property var modelData

                        readonly property bool selected:
                            SettingsState.keyboardLayout === layoutChip.modelData.key

                        implicitWidth: layoutChipLabel.implicitWidth + 18
                        implicitHeight: 24
                        radius: 7
                        color: layoutChip.selected
                            ? Theme.accent : Theme.surfaceAlt
                        border.width: 1
                        border.color: layoutChip.selected
                            ? Theme.accent : Theme.border

                        Text {
                            id: layoutChipLabel

                            anchors.centerIn: parent
                            text: layoutChip.modelData.label
                            color: layoutChip.selected
                                ? Theme.accentInk : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SettingsState.setKeyboardLayout(
                                layoutChip.modelData.key)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Teclado en pantalla"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    visible: !KeyboardState.available
                    text: "No instalado"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }

                ShellSwitch {
                    checked: KeyboardState.visible
                    enabled: KeyboardState.available
                    onToggled: KeyboardState.toggle()
                }
            }
        }

        // --------------------------------------------------- Portapapeles
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "clipboard"
            spacing: 5

            Repeater {
                model: ClipboardState.entries

                delegate: Rectangle {
                    id: clipRow

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: 8
                    color: ClipboardState.copiedIndex === clipRow.index
                        ? Theme.accentSoft
                        : (clipHover.hovered ? Theme.hover : Theme.surfaceAlt)
                    border.width: ClipboardState.copiedIndex === clipRow.index
                        ? 1 : 0
                    border.color: Theme.accentLine

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: ClipboardState.copy(clipRow.index)
                    }

                    HoverHandler {
                        id: clipHover
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 9
                            rightMargin: 8
                        }
                        spacing: 8

                        ShellIcon {
                            Layout.alignment: Qt.AlignVCenter
                            name: "edit-paste"
                            fallbackName: "edit-copy"
                            color: ClipboardState.copiedIndex === clipRow.index
                                ? Theme.accent : Theme.muted
                            size: 14
                            fallback: "▤"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: String(clipRow.modelData.text)
                                    .replace(/\n/g, " ")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: clipRow.modelData.time > 0
                                text: clipRow.modelData.time > 0
                                    ? Qt.formatTime(
                                        new Date(clipRow.modelData.time), "HH:mm")
                                    : ""
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }
                        }
                    }

                    Rectangle {
                        visible: clipHover.hovered
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 5
                        }
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 6
                        color: clipDeleteMouse.containsMouse
                            ? Theme.hover : "transparent"
                        z: 3

                        ShellIcon {
                            anchors.centerIn: parent
                            name: "edit-delete"
                            color: clipDeleteMouse.containsMouse
                                ? Theme.danger : Theme.faint
                            size: 12
                            fallback: "×"
                        }

                        MouseArea {
                            id: clipDeleteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ClipboardState.remove(clipRow.index)
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: ClipboardState.count === 0
                spacing: 4

                Item {
                    Layout.preferredHeight: 18
                }

                ShellIcon {
                    Layout.alignment: Qt.AlignHCenter
                    source: ShellIcons.src("clipboard")
                    color: Theme.faint
                    size: 22
                }

                Text {
                    Layout.fillWidth: true
                    text: "Sin textos copiados"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // ------------------------------------------------------- Ajustes
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "settings"
            spacing: 8

            // --------------------------------------------------- apariencia
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Tema"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    implicitWidth: 118
                    implicitHeight: 24
                    radius: 7
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 2
                        spacing: 2

                        Repeater {
                            model: [
                                { key: "dark", label: "Oscuro", icon: "moon" },
                                { key: "light", label: "Claro", icon: "sun" }
                            ]

                            delegate: Rectangle {
                                id: modeChip

                                required property var modelData

                                readonly property bool selected:
                                    SettingsState.themeMode === modeChip.modelData.key

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 5
                                color: modeChip.selected
                                    ? Theme.accent : "transparent"

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    ShellIcon {
                                        source: ShellIcons.src(modeChip.modelData.icon)
                                        color: modeChip.selected
                                            ? Theme.accentInk : Theme.muted
                                        size: 11
                                    }

                                    Text {
                                        text: modeChip.modelData.label
                                        color: modeChip.selected
                                            ? Theme.accentInk : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: SettingsState.setThemeMode(
                                        modeChip.modelData.key)
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Acento"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Row {
                    spacing: 4

                    Repeater {
                        model: [
                            "#b8bec7", "#c9b8f5", "#a9e8cf",
                            "#f4e6a6", "#8ab4f8", "#e8a9d6"
                        ]

                        delegate: Rectangle {
                            id: accentDot

                            required property string modelData

                            readonly property bool selected:
                                SettingsState.accentColor === accentDot.modelData

                            width: 18
                            height: 18
                            radius: 9
                            color: accentDot.modelData
                            border.width: 2
                            border.color: accentDot.selected
                                ? Theme.text : Theme.border

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsState.setAccentColor(
                                    accentDot.modelData)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Color propio"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                TextField {
                    id: accentHex

                    implicitWidth: 82
                    implicitHeight: 24
                    padding: 0
                    leftPadding: 7
                    rightPadding: 7
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: "#RRGGBB"
                    placeholderTextColor: Theme.faint
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    selectByMouse: true
                    maximumLength: 7
                    background: Rectangle {
                        radius: 6
                        color: Theme.surfaceAlt
                        border.width: 1
                        border.color: accentHex.activeFocus
                            ? Theme.accent : Theme.border
                    }
                    onAccepted: applyAccent()
                    onEditingFinished: applyAccent()

                    function applyAccent(): void {
                        if (SettingsState.setAccentColor(text)) {
                            text = "";
                            focus = false;
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // ------------------------------------------------------- cristal
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Cristal"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Restablecer"
                    color: glassResetMouse.containsMouse
                        ? Theme.accent : Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8

                    MouseArea {
                        id: glassResetMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SettingsState.setGlassTransparency(22);
                            SettingsState.setGlassBlur(12);
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Transparencia"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }

                Text {
                    text: SettingsState.glassTransparency + " %"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            ShellSlider {
                id: glassTransparencySlider

                Layout.fillWidth: true
                from: 0
                to: 90
                stepSize: 2
                value: SettingsState.glassTransparency
                onMoved: SettingsState.setGlassTransparency(value)
            }

            Binding {
                target: glassTransparencySlider
                property: "value"
                value: SettingsState.glassTransparency
                when: !glassTransparencySlider.pressed
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Desenfoque"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }

                Text {
                    text: SettingsState.glassBlur + " px"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            ShellSlider {
                id: glassBlurSlider

                Layout.fillWidth: true
                from: 0
                to: 40
                stepSize: 2
                value: SettingsState.glassBlur
                onMoved: SettingsState.setGlassBlur(value)
            }

            Binding {
                target: glassBlurSlider
                property: "value"
                value: SettingsState.glassBlur
                when: !glassBlurSlider.pressed
            }

            Text {
                Layout.fillWidth: true
                text: "El desenfoque es global: también afecta a las ventanas. "
                    + "El cristal muestra solo el fondo de pantalla."
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Tema en las apps"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                ShellSwitch {
                    checked: SettingsState.systemTheme
                    onToggled: SettingsState.setSystemTheme(
                        !SettingsState.systemTheme)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Fondo de pantalla"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    width: 46
                    height: 28
                    radius: 6
                    color: SettingsState.wallpaperColor.length > 0
                        ? SettingsState.wallpaperColor : Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: SettingsState.wallpaperPath.length > 0
                            ? Qt.resolvedUrl("file://"
                                + SettingsState.wallpaperPath) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: source != ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: SettingsState.wallpaperPath.length === 0
                            && SettingsState.wallpaperColor.length === 0
                        text: "—"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 24
                    radius: 7
                    color: wallpaperChoose.containsMouse
                        ? Theme.hover : Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "Elegir"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: wallpaperChoose
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.chooseWallpaper()
                    }
                }

                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 24
                    radius: 7
                    visible: SettingsState.wallpaperPath.length > 0
                    color: wallpaperClear.containsMouse
                        ? Theme.hover : Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "Quitar"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: wallpaperClear
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.clearWallpaper()
                    }
                }
            }

            // Color de fondo: una alternativa ligera a la imagen. Al elegir
            // uno se quita la imagen para que el cambio se vea al momento.
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Color de fondo"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Row {
                    spacing: 4

                    Repeater {
                        model: [
                            "#0b0d10", "#141821", "#1b1520",
                            "#101a16", "#231a14", "#f2f1ee"
                        ]

                        delegate: Rectangle {
                            id: wallpaperDot

                            required property string modelData

                            readonly property bool selected:
                                SettingsState.wallpaperColor
                                    === wallpaperDot.modelData

                            width: 18
                            height: 18
                            radius: 9
                            color: wallpaperDot.modelData
                            border.width: 2
                            border.color: wallpaperDot.selected
                                ? Theme.text : Theme.border

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsState.setWallpaperColor(
                                    wallpaperDot.modelData)
                            }
                        }
                    }

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        color: Theme.surfaceAlt
                        border.width: 1
                        border.color: SettingsState.wallpaperColor.length
                            === 0 ? Theme.text : Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "—"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SettingsState.clearWallpaperColor()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Color propio"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                TextField {
                    id: wallpaperHex

                    implicitWidth: 82
                    implicitHeight: 24
                    padding: 0
                    leftPadding: 7
                    rightPadding: 7
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: "#RRGGBB"
                    placeholderTextColor: Theme.faint
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    selectByMouse: true
                    maximumLength: 7
                    background: Rectangle {
                        radius: 6
                        color: Theme.surfaceAlt
                        border.width: 1
                        border.color: wallpaperHex.activeFocus
                            ? Theme.accent : Theme.border
                    }
                    onAccepted: applyWallpaperColor()
                    onEditingFinished: applyWallpaperColor()

                    function applyWallpaperColor(): void {
                        if (SettingsState.setWallpaperColor(text)) {
                            text = "";
                            focus = false;
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Distribución del teclado"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    text: SettingsState.keyboardLayout.toUpperCase()
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }

                Rectangle {
                    implicitWidth: 68
                    implicitHeight: 24
                    radius: 7
                    color: layoutButtonMouse.containsMouse
                        ? Theme.hover : Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "Cambiar"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: layoutButtonMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setView("keyboard")
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: "Bloqueo automático"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Row {
                    spacing: 2

                    Repeater {
                        model: [0, 1, 5, 10, 15, 30]

                        delegate: Rectangle {
                            id: lockChip

                            required property var modelData

                            readonly property bool selected:
                                SettingsState.lockMinutes === lockChip.modelData

                            implicitWidth: lockLabel.implicitWidth + 10
                            implicitHeight: 22
                            radius: 5
                            color: lockChip.selected
                                ? Theme.accent
                                : (lockChipHover.containsMouse
                                    ? Theme.hover : Theme.surfaceAlt)
                            border.width: lockChip.selected ? 0 : 1
                            border.color: Theme.border

                            Text {
                                id: lockLabel

                                anchors.centerIn: parent
                                text: lockChip.modelData === 0
                                    ? "Nunca" : lockChip.modelData + "m"
                                color: lockChip.selected
                                    ? Theme.accentInk : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: lockChipHover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsState.setLockMinutes(
                                    lockChip.modelData)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Posición de la barra"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Row {
                    spacing: 2

                    Repeater {
                        model: [
                            { key: "abajo", label: "Abajo" },
                            { key: "arriba", label: "Arriba" },
                            { key: "izquierda", label: "Izquierda" },
                            { key: "derecha", label: "Derecha" }
                        ]

                        delegate: Rectangle {
                            id: barPositionChip

                            required property var modelData

                            readonly property bool selected:
                                SettingsState.barPosition
                                    === barPositionChip.modelData.key

                            width: barPositionChipLabel.implicitWidth + 14
                            height: 24
                            radius: 6
                            color: barPositionChip.selected
                                ? Theme.accent : "transparent"
                            border.width: barPositionChip.selected ? 0 : 1
                            border.color: Theme.border

                            Text {
                                id: barPositionChipLabel
                                anchors.centerIn: parent
                                text: barPositionChip.modelData.label
                                color: barPositionChip.selected
                                    ? Theme.accentInk : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsState.setBarPosition(
                                    barPositionChip.modelData.key)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Orden de los controles"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    implicitWidth: 78
                    implicitHeight: 24
                    radius: 7
                    color: layoutResetMouse.containsMouse
                        ? Theme.hover : Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "Restablecer"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: layoutResetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BarState.resetLayout()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Retardo al mantener Super"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: holdLess.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: holdLess
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setSuperHoldMs(
                            SettingsState.superHoldMs - 50)
                    }
                }

                Text {
                    text: SettingsState.superHoldMs + " ms"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    width: 46
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: holdMore.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: holdMore
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setSuperHoldMs(
                            SettingsState.superHoldMs + 50)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Ocultar barra automáticamente"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                ShellSwitch {
                    checked: SettingsState.autoHideBar
                    onToggled: SettingsState.setAutoHideBar(
                        !SettingsState.autoHideBar)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Notificaciones y control juntos"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                ShellSwitch {
                    checked: SettingsState.unifiedPanels
                    onToggled: SettingsState.setUnifiedPanels(
                        !SettingsState.unifiedPanels)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Filas visibles"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: rowsLess.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: rowsLess
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setCenterRows(
                            SettingsState.centerRows - 1)
                    }
                }

                Text {
                    text: SettingsState.centerRows
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    width: 20
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: rowsMore.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: rowsMore
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setCenterRows(
                            SettingsState.centerRows + 1)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Iconos del centro"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: iconsLess.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: iconsLess
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setCenterIconSize(
                            SettingsState.centerIconSize - 1)
                    }
                }

                Text {
                    text: SettingsState.centerIconSize
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    width: 20
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: iconsMore.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: iconsMore
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setCenterIconSize(
                            SettingsState.centerIconSize + 1)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Iconos de la barra"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: barIconsLess.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: barIconsLess
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setBarIconSize(
                            SettingsState.barIconSize - 1)
                    }
                }

                Text {
                    text: SettingsState.barIconSize
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    width: 20
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: barIconsMore.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: barIconsMore
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setBarIconSize(
                            SettingsState.barIconSize + 1)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Escritorios"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: settingsLess.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: settingsLess
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setMaxWorkspaces(
                            SettingsState.maxWorkspaces - 1)
                    }
                }

                Text {
                    text: SettingsState.maxWorkspaces
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    width: 20
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: settingsMore.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: settingsMore
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setMaxWorkspaces(
                            SettingsState.maxWorkspaces + 1)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Tamaño de ventanas flotantes"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: floatSizeLess.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: floatSizeLess
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setFloatingSizePercent(
                            SettingsState.floatingSizePercent - 5)
                    }
                }

                Text {
                    text: SettingsState.floatingSizePercent + " %"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    width: 46
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: floatSizeMore.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: floatSizeMore
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setFloatingSizePercent(
                            SettingsState.floatingSizePercent + 5)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Separación en cascada"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: floatStepLess.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: floatStepLess
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setFloatingCascade(
                            SettingsState.floatingCascade - 8)
                    }
                }

                Text {
                    text: SettingsState.floatingCascade === 0
                        ? "Auto" : SettingsState.floatingCascade + " px"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    width: 46
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: floatStepMore.containsMouse ? Theme.hover : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: floatStepMore
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsState.setFloatingCascade(
                            SettingsState.floatingCascade + 8)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Modo de ventanas"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    text: WorkspaceModeState.labelFor(
                        SettingsState.workspaceMode(
                            WorkspaceModeState.focusedWorkspaceId))
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }

                Rectangle {
                    implicitWidth: 68
                    implicitHeight: 24
                    radius: 7
                    color: windowModeButton.containsMouse
                        ? Theme.hover : Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "Configurar"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: windowModeButton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setView("windows")
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Barra de ventanas"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Row {
                    spacing: 2

                    Repeater {
                        model: [
                            { key: "floating", label: "Flotante" },
                            { key: "integrated", label: "Integrado" }
                        ]

                        delegate: Rectangle {
                            id: titlebarChip

                            required property var modelData

                            readonly property bool selected:
                                SettingsState.windowChrome
                                    === titlebarChip.modelData.key

                            width: titlebarChipLabel.implicitWidth + 14
                            height: 24
                            radius: 6
                            color: titlebarChip.selected
                                ? Theme.accent : "transparent"
                            border.width: titlebarChip.selected ? 0 : 1
                            border.color: Theme.border

                            Text {
                                id: titlebarChipLabel
                                anchors.centerIn: parent
                                text: titlebarChip.modelData.label
                                color: titlebarChip.selected
                                    ? Theme.accentInk : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsState.setWindowChrome(
                                    titlebarChip.modelData.key)
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Controles de ventana"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    implicitWidth: 78
                    implicitHeight: 24
                    radius: 7
                    color: overlayButton.containsMouse
                        ? Theme.accentSoft : Theme.surfaceAlt
                    border.width: 1
                    border.color: SuperState.pinned
                        ? Theme.accentLine : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: SuperState.pinned ? "Ocultar" : "Mostrar"
                        color: SuperState.pinned
                            ? Theme.accent : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: overlayButton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SuperState.togglePinned()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Compositor"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    text: CompositorState.name
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }

                Rectangle {
                    implicitWidth: 58
                    implicitHeight: 24
                    radius: 7
                    color: compositorButton.containsMouse
                        ? Theme.hover : Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "Ver"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: compositorButton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setView("compositor")
                    }
                }
            }

        }

        // ------------------------------------------------- Modo de ventanas
        // Selector visible de «Flotante / Como Windows» y «Mosaico» para cada
        // escritorio. El overlay de Super enseña el mismo par, pero esta vista
        // es la alternativa permanente y descubrible.
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "windows"
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Las ventanas se abren flotantes, como en Windows, o se "
                    + "reparten en mosaico. El modo se aplica a las ventanas "
                    + "que ya están en el escritorio y a las nuevas."
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 9
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "Para todos los escritorios"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        text: "Borra las excepciones por escritorio"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                    }
                }

                Row {
                    spacing: 2

                    Repeater {
                        model: [
                            { key: "floating", label: "Flotante" },
                            { key: "mosaic", label: "Mosaico" }
                        ]

                        delegate: Rectangle {
                            id: allModeChip

                            required property var modelData

                            readonly property bool selected:
                                SettingsState.workspaceModeDefault
                                    === allModeChip.modelData.key
                                && SettingsState.workspaceModes.length === 0

                            width: allModeLabel.implicitWidth + 16
                            height: 24
                            radius: 6
                            color: allModeChip.selected
                                ? Theme.accent : (allModeHover.containsMouse
                                    ? Theme.hover : "transparent")
                            border.width: allModeChip.selected ? 0 : 1
                            border.color: Theme.border

                            Text {
                                id: allModeLabel
                                anchors.centerIn: parent
                                text: allModeChip.modelData.label
                                color: allModeChip.selected
                                    ? Theme.accentInk : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: allModeHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WorkspaceModeState.choose(
                                    allModeChip.modelData.key)
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            Text {
                text: "Escritorio por escritorio"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Repeater {
                model: SettingsState.workspaceIds

                delegate: Rectangle {
                    id: wsModeRow

                    required property int modelData

                    readonly property string mode:
                        SettingsState.workspaceMode(wsModeRow.modelData)
                    readonly property bool active:
                        Number(WorkspaceModeState.focusedWorkspaceId)
                            === wsModeRow.modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 7
                    color: wsModeRow.active
                        ? Theme.accentGhost : Theme.surfaceAlt
                    border.width: wsModeRow.active ? 1 : 0
                    border.color: Theme.accentLine

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 9
                            rightMargin: 4
                        }
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: "Escritorio " + wsModeRow.modelData
                                + (wsModeRow.active ? " · activo" : "")
                            color: wsModeRow.active
                                ? Theme.text : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: wsModeRow.active
                                ? Font.DemiBold : Font.Normal
                        }

                        Row {
                            spacing: 1

                            Repeater {
                                model: [
                                    { key: "floating", label: "Flotante" },
                                    { key: "mosaic", label: "Mosaico" }
                                ]

                                delegate: Rectangle {
                                    id: rowChip

                                    required property var modelData

                                    readonly property bool selected:
                                        wsModeRow.mode === rowChip.modelData.key

                                    width: rowChipLabel.implicitWidth + 14
                                    height: 22
                                    radius: 5
                                    color: rowChip.selected
                                        ? Theme.accent
                                        : (rowChipHover.containsMouse
                                            ? Theme.hover : "transparent")
                                    border.width: rowChip.selected ? 0 : 1
                                    border.color: Theme.border

                                    Text {
                                        id: rowChipLabel
                                        anchors.centerIn: parent
                                        text: rowChip.modelData.label
                                        color: rowChip.selected
                                            ? Theme.accentInk : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        id: rowChipHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: WorkspaceModeState.setMode(
                                            wsModeRow.modelData,
                                            rowChip.modelData.key)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: "Barra de ventanas"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Flotante aparece con Super · Integrado queda siempre visible"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }
                }

                Row {
                    spacing: 2

                    Repeater {
                        model: [
                            { key: "floating", label: "Flotante" },
                            { key: "integrated", label: "Integrado" }
                        ]

                        delegate: Rectangle {
                            id: titlebarViewChip

                            required property var modelData

                            readonly property bool selected:
                                SettingsState.windowChrome
                                    === titlebarViewChip.modelData.key

                            width: titlebarViewLabel.implicitWidth + 14
                            height: 24
                            radius: 6
                            color: titlebarViewChip.selected
                                ? Theme.accent : "transparent"
                            border.width: titlebarViewChip.selected ? 0 : 1
                            border.color: Theme.border

                            Text {
                                id: titlebarViewLabel
                                anchors.centerIn: parent
                                text: titlebarViewChip.modelData.label
                                color: titlebarViewChip.selected
                                    ? Theme.accentInk : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsState.setWindowChrome(
                                    titlebarViewChip.modelData.key)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Controles de ventana ahora"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Rectangle {
                    implicitWidth: 96
                    implicitHeight: 24
                    radius: 7
                    color: showChromeHover.containsMouse
                        ? Theme.accentSoft : Theme.surfaceAlt
                    border.width: 1
                    border.color: SuperState.active
                        ? Theme.accentLine : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: SuperState.pinned ? "Ocultar"
                            : (CompositorState.supports("superHold")
                                ? "Mostrar con Super"
                                : "Mostrar con Super+Tab")
                        color: SuperState.pinned
                            ? Theme.accent : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: showChromeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SuperState.togglePinned()
                    }
                }
            }
        }

        // ---------------------------------------------------- Compositor
        // Página de diagnóstico del contrato CompositorState: enseña qué
        // compositor se detectó, sus ventanas y escritorios reales, y qué
        // capacidades declara. En esta fase no ejecuta acciones.
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === "compositor"
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: statusColumn.implicitHeight + 20
                radius: 10
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: statusColumn

                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        ShellIcon {
                            name: "preferences-system-windows"
                            fallbackName: "applications-system"
                            color: Theme.accent
                            size: 16
                            fallback: "▣"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: CompositorState.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: CompositorState.available
                                    ? "Conectado" : "Sin conexión"
                                color: CompositorState.available
                                    ? Theme.green : Theme.danger
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }
                        }

                        Rectangle {
                            implicitWidth: 74
                            implicitHeight: 20
                            radius: 6
                            color: Theme.accentSoft
                            border.width: 1
                            border.color: Theme.accentLine

                            Text {
                                anchors.centerIn: parent
                                text: CompositorState.readOnly
                                    ? "SOLO LECTURA" : "CONTROL TOTAL"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 7
                                font.weight: Font.Bold
                                font.letterSpacing: 0.4
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Ventanas " + CompositorState.windowCount
                            + "   ·   Escritorios " + CompositorState.workspaceCount
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                    }

                    Text {
                        Layout.fillWidth: true
                        text: CompositorState.sessionDesktop.length > 0
                            ? "Sesión: " + CompositorState.sessionDesktop
                            : "Sin XDG_CURRENT_DESKTOP"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: CompositorState.lastAction.length > 0
                        text: "Última acción: " + CompositorState.lastAction
                            + (CompositorState.lastActionOk ? " · ok" : " · falló")
                        color: CompositorState.lastActionOk
                            ? Theme.green : Theme.danger
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: CompositorState.lastError.length > 0
                        text: CompositorState.lastError
                        color: Theme.danger
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Enfoque actual
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: focusColumn.implicitHeight + 16
                radius: 9
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: focusColumn

                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: "ENFOQUE"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 7
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.7
                    }

                    Text {
                        Layout.fillWidth: true
                        text: CompositorState.focusedWindow
                            ? CompositorState.focusedTitle : "Ninguna ventana"
                        color: CompositorState.focusedWindow
                            ? Theme.text : Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: CompositorState.focusedApp.length > 0
                        text: CompositorState.focusedApp
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Estado en vivo"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                }

                Rectangle {
                    implicitWidth: 74
                    implicitHeight: 22
                    radius: 6
                    color: refreshCompositor.containsMouse
                        ? Theme.hover : Theme.surface
                    border.width: 1
                    border.color: Theme.border

                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        ShellIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "view-refresh-symbolic"
                            fallbackName: "view-refresh"
                            color: Theme.muted
                            size: 10
                            fallback: "⟳"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Actualizar"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: refreshCompositor
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: CompositorState.refresh()
                    }
                }
            }

            // Escritorios reales
            Text {
                Layout.fillWidth: true
                text: "ESCRITORIOS"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 7
                font.weight: Font.DemiBold
                font.letterSpacing: 0.7
            }

            Column {
                id: workspaceList

                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: CompositorState.workspaces

                    delegate: Rectangle {
                        required property var modelData

                        width: workspaceList.width
                        height: 27
                        radius: 6
                        color: modelData.focused
                            ? Theme.accentSoft : Theme.surfaceAlt
                        border.width: modelData.focused ? 1 : 0
                        border.color: Theme.accentLine

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                text: modelData.id
                                color: modelData.focused
                                    ? Theme.accent : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                horizontalAlignment: Text.AlignHCenter
                                width: 14
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.windowCount + " vent."
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }

                            Row {
                                spacing: 3

                                CompositorChip {
                                    label: "Dwindle"
                                    active: modelData.layout === "dwindle"
                                    onClicked: CompositorState.setWorkspaceLayout(
                                        modelData.id, "dwindle")
                                }

                                CompositorChip {
                                    label: "Master"
                                    active: modelData.layout === "master"
                                    onClicked: CompositorState.setWorkspaceLayout(
                                        modelData.id, "master")
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: CompositorState.workspaceCount === 0
                    text: "Sin escritorios"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                }
            }

            // Ventanas reales
            Text {
                Layout.fillWidth: true
                text: "VENTANAS"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 7
                font.weight: Font.DemiBold
                font.letterSpacing: 0.7
            }

            Column {
                id: windowList

                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: CompositorState.windows

                    delegate: Rectangle {
                        required property var modelData

                        width: windowList.width
                        height: windowColumn.implicitHeight + 12
                        radius: 6
                        color: modelData.focused
                            ? Theme.accentSoft : Theme.surfaceAlt
                        border.width: modelData.focused ? 1 : 0
                        border.color: Theme.accentLine

                        ColumnLayout {
                            id: windowColumn

                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    implicitWidth: 6
                                    implicitHeight: 6
                                    radius: 3
                                    color: modelData.focused
                                        ? Theme.accent
                                        : (modelData.minimized
                                            ? Theme.warning
                                            : (modelData.floating
                                                ? Theme.info : Theme.faint))
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title.length > 0
                                            ? modelData.title : modelData.appId
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.appId + "  ·  escritorio "
                                            + (modelData.workspaceName.length > 0
                                                ? modelData.workspaceName
                                                : modelData.workspaceId)
                                            + "  ·  "
                                            + root.windowStateLabel(modelData)
                                        color: Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 7
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Flow {
                                id: windowActions

                                Layout.fillWidth: true
                                spacing: 3

                                CompositorChip {
                                    label: "Enfocar"
                                    active: modelData.focused
                                    onClicked: CompositorState.focusWindow(
                                        modelData.address)
                                }

                                CompositorChip {
                                    label: modelData.floating
                                        ? "Mosaico" : "Flotar"
                                    active: modelData.floating
                                    onClicked: CompositorState.toggleFloating(
                                        modelData.address)
                                }

                                CompositorChip {
                                    label: modelData.pinned
                                        ? "Soltar" : "Fijar"
                                    active: modelData.pinned
                                    onClicked: CompositorState.togglePinned(
                                        modelData.address)
                                }

                                CompositorChip {
                                    label: modelData.minimized
                                        ? "Restaurar" : "Minimizar"
                                    active: modelData.minimized
                                    onClicked: {
                                        if (modelData.minimized)
                                            CompositorState.restoreWindow(
                                                modelData.address);
                                        else
                                            CompositorState.minimizeWindow(
                                                modelData.address);
                                    }
                                }

                                CompositorChip {
                                    label: modelData.maximized
                                        ? "Restaurar" : "Maximizar"
                                    active: modelData.maximized
                                    onClicked: CompositorState.toggleMaximized(
                                        modelData.address)
                                }

                                CompositorChip {
                                    label: modelData.fullscreen
                                        ? "Salir" : "Pantalla"
                                    active: modelData.fullscreen
                                    onClicked: CompositorState.toggleFullscreen(
                                        modelData.address)
                                }

                                CompositorChip {
                                    label: "Cerrar"
                                    danger: true
                                    onClicked: CompositorState.closeWindow(
                                        modelData.address)
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: CompositorState.windowCount === 0
                    text: "Sin ventanas"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                }
            }

            // Capacidades que declara el backend
            Text {
                Layout.fillWidth: true
                text: "CAPACIDADES"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 7
                font.weight: Font.DemiBold
                font.letterSpacing: 0.7
            }

            Flow {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        { key: "nativeTitlebar", label: "Título nativo" },
                        { key: "superHold", label: "Super mantenido" },
                        { key: "nativeMinimize", label: "Minimizar nativo" },
                        { key: "snapZones", label: "Zonas Windows" },
                        { key: "windowSnap", label: "Snap de ventanas" },
                        { key: "perWorkspaceLayout", label: "Layout por escritorio" },
                        { key: "windowGeometry", label: "Geometría" },
                        { key: "blur", label: "Desenfoque" },
                        { key: "moveToWorkspace", label: "Mover a escritorio" },
                        { key: "floatingToggle", label: "Flotante / mosaico" },
                        { key: "pin", label: "Fijar" },
                        { key: "fullscreen", label: "Pantalla completa" },
                        { key: "maximize", label: "Maximizar" },
                        { key: "minimize", label: "Minimizar" },
                        { key: "focus", label: "Enfocar" },
                        { key: "close", label: "Cerrar" },
                        { key: "focusWorkspace", label: "Cambiar escritorio" },
                        { key: "setLayout", label: "Cambiar layout" }
                    ]

                    delegate: Rectangle {
                        id: capabilityChip

                        required property var modelData

                        readonly property bool on:
                            CompositorState.supports(capabilityChip.modelData.key)

                        implicitWidth: capabilityText.implicitWidth + 18
                        implicitHeight: 21
                        radius: 6
                        color: capabilityChip.on
                            ? Theme.accentSoft : Theme.surfaceAlt
                        border.width: 1
                        border.color: capabilityChip.on
                            ? Theme.accentLine : Theme.border

                        Row {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: capabilityChip.on ? "✓" : "—"
                                color: capabilityChip.on
                                    ? Theme.accent : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                            }

                            Text {
                                id: capabilityText

                                anchors.verticalCenter: parent.verticalCenter
                                text: capabilityChip.modelData.label
                                color: capabilityChip.on
                                    ? Theme.text : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 7
                            }
                        }
                    }
                }
            }
        }
    }
}
