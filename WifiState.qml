pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Información de las redes Wi-Fi que Quickshell no expone directamente:
// frecuencia (para saber si la red emite en 2,4, 5 o 6 GHz), seguridad y la
// intensidad con la que llega cada banda. Se consulta con nmcli mientras la
// vista de Wi-Fi está abierta.
Singleton {
    id: root

    property bool watching: false
    property bool scanning: false
    property bool hasScanned: false
    property string lastError: ""
    property string deviceState: ""
    property var accessPoints: []
    // Puntos de acceso que no anuncian su SSID. Se muestran con su BSSID como
    // nombre cuando el usuario activa el interruptor correspondiente.
    property var hiddenAccessPoints: []
    // Nombre del perfil Wi-Fi activo. Una red oculta conectada ya tiene un
    // nombre real (el SSID que se escribió al crearla), así que se usa para
    // mostrarlo en lugar de su BSSID.
    property string activeConnectionName: ""
    // Preferencias de banda por SSID. Se aplican al perfil guardado de
    // NetworkManager para que la conexión no vuelva a la banda apagada.
    property var bandPrefs: ({})
    property string lastApplied: ""

    // Perfil de la red que se está editando y QR para compartirla.
    property string profileSsid: ""
    property string profileUuid: ""
    property bool profileFound: false
    property bool profileAutoconnect: true
    property bool profileQrReady: false
    property string profileQrVersion: ""
    property string profileError: ""
    // Conexión manual a una red oculta. NetworkManager no puede revelar el
    // SSID de una red oculta, así que se escribe a mano.
    property bool hiddenBusy: false
    property string hiddenError: ""
    signal hiddenConnected()
    readonly property string profileQrPath: Quickshell.cacheDir
        + "/shell-wifi-qr.png"
    readonly property string helperPath: (Quickshell.shellDir || "")
        + "/scripts/wifi-profile.py"

    readonly property var activePoint: {
        for (let i = 0; i < accessPoints.length; i++) {
            if (accessPoints[i].active)
                return accessPoints[i];
        }
        return null;
    }

    function refresh(): void {
        if (!root.watching || scanProc.running)
            return;
        scanProc.running = true;
    }

    // Pide a NetworkManager una pasada de búsqueda nueva. Se usa al abrir el
    // panel y al pulsar el icono de recargar. Solo se permite mientras la
    // vista de Red está visible: al cerrar el panel no debe quedar la radio
    // escaneando en segundo plano.
    function requestScan(): void {
        if (!root.watching)
            return;
        if (!rescanProc.running)
            rescanProc.running = true;
    }

    // Corta la consulta periódica y cualquier búsqueda en curso. Lo llama la
    // vista de Red al cerrarse o al cambiar de sección.
    function stop(): void {
        root.watching = false;
        root.scanning = false;
        if (scanProc.running)
            scanProc.running = false;
        if (rescanProc.running)
            rescanProc.running = false;
    }

    // Carga los datos del perfil guardado de una red y genera su QR.
    function loadProfile(ssid): void {
        root.profileSsid = ssid;
        root.profileUuid = "";
        root.profileFound = false;
        root.profileAutoconnect = true;
        root.profileQrReady = false;
        root.profileError = "";
        if (!ssid || ssid.length === 0)
            return;
        profileProc.command = ["python3", root.helperPath, "profile",
            ssid, root.profileQrPath];
        profileProc.running = true;
    }

    function clearProfile(): void {
        root.profileSsid = "";
        root.profileUuid = "";
        root.profileFound = false;
        root.profileQrReady = false;
        root.profileError = "";
    }

    function setAutoconnect(ssid, value): void {
        if (!ssid || ssid.length === 0)
            return;
        autoconnectProc.command = ["python3", root.helperPath,
            "autoconnect", ssid, value ? "yes" : "no"];
        autoconnectProc.running = true;
    }

    function forget(ssid): void {
        if (!ssid || ssid.length === 0)
            return;
        forgetProc.command = ["python3", root.helperPath, "forget", ssid];
        forgetProc.running = true;
    }

    function connectHidden(ssid, psk): void {
        const name = String(ssid || "").trim();
        if (name.length === 0) {
            root.hiddenError = "Escribe el nombre de la red.";
            return;
        }
        if (root.hiddenBusy)
            return;
        root.hiddenBusy = true;
        root.hiddenError = "";
        const args = ["nmcli", "--wait", "30", "device", "wifi", "connect",
            name];
        if (String(psk || "").length > 0)
            args.push("password", String(psk));
        args.push("hidden", "yes");
        hiddenProc.command = args;
        hiddenProc.running = true;
    }

    function pointFor(ssid): var {
        for (let i = 0; i < accessPoints.length; i++) {
            if (accessPoints[i].ssid === ssid)
                return accessPoints[i];
        }
        return null;
    }

    function availableBands(ssid): var {
        const point = pointFor(ssid);
        return point ? point.bands : [];
    }

    function bandsFor(ssid): var {
        const available = availableBands(ssid);
        const pref = bandPrefs[ssid];
        if (!pref || pref.length === 0)
            return available;
        const filtered = available.filter((band) => pref.indexOf(band) !== -1);
        return filtered.length > 0 ? filtered : available;
    }

    function bandOn(ssid, band): bool {
        return bandsFor(ssid).indexOf(band) !== -1;
    }

    // Devuelve el SVG propio de señal Wi-Fi. Así la lista de redes usa el
    // mismo dibujo que la barra y no cambia según el tema de iconos.
    function signalSource(strength): string {
        if (strength >= 0.75)
            return ShellIcons.src("wifi-3");
        if (strength >= 0.5)
            return ShellIcons.src("wifi-2");
        if (strength > 0)
            return ShellIcons.src("wifi-1");
        return ShellIcons.src("wifi-none");
    }

    // Devuelve "" si se aplicó o un mensaje si no se puede apagar la última
    // banda disponible de esa red.
    function toggleBand(ssid, band): string {
        const available = availableBands(ssid);
        if (available.indexOf(band) === -1)
            return "";
        const current = bandsFor(ssid);
        const on = current.indexOf(band) !== -1;
        if (on && current.length <= 1)
            return "Deja al menos una banda activa en " + ssid + ".";
        const next = on
            ? current.filter((value) => value !== band)
            : available.filter((value) => current.indexOf(value) !== -1 || value === band);
        const copy = Object.assign({}, root.bandPrefs);
        copy[ssid] = next;
        root.bandPrefs = copy;
        root.applyProfile(ssid, next);
        return "";
    }

    function applyProfile(ssid, bands): void {
        if (!ssid || !bands || bands.length === 0)
            return;
        bandProc.command = ["python3", "-c", root.profileScript, ssid,
            bands.join(",")];
        bandProc.running = true;
    }

    // Aplica la preferencia cuando una red concreta acaba de conectarse, para
    // que valga también la primera vez que se escribe la contraseña.
    function syncActive(): void {
        const point = root.activePoint;
        if (!point)
            return;
        const pref = root.bandPrefs[point.ssid];
        if (!pref || pref.length === 0)
            return;
        const key = point.ssid + "|" + pref.join(",");
        if (key === root.lastApplied)
            return;
        root.lastApplied = key;
        root.applyProfile(point.ssid, pref);
    }

    readonly property string profileScript:
        "import subprocess, sys\n" +
        "ssid = sys.argv[1]\n" +
        "bands = sys.argv[2].split(',')\n" +
        "out = subprocess.run(['nmcli','-t','-f','NAME,TYPE','connection','show'],\n" +
        "                     capture_output=True, text=True).stdout\n" +
        "for line in out.splitlines():\n" +
        "    name, sep, kind = line.rpartition(':')\n" +
        "    if not sep or kind != '802-11-wireless':\n" +
        "        continue\n" +
        "    current = subprocess.run(['nmcli','-g','802-11-wireless.ssid',\n" +
        "                              'connection','show',name],\n" +
        "                             capture_output=True, text=True).stdout.strip()\n" +
        "    if current != ssid:\n" +
        "        continue\n" +
        "    if len(bands) == 1:\n" +
        "        value = 'bg' if bands[0] == '2.4' else 'a'\n" +
        "        subprocess.run(['nmcli','connection','modify',name,\n" +
        "                        '802-11-wireless.band',value],\n" +
        "                       capture_output=True, text=True)\n" +
        "    else:\n" +
        "        subprocess.run(['nmcli','connection','modify',name,\n" +
        "                        '802-11-wireless.band',''],\n" +
        "                       capture_output=True, text=True)\n"

    readonly property string scanScript:
        "import subprocess, json\n" +
        "raw = subprocess.run(['nmcli','-t','-f',\n" +
        "    'IN-USE,SSID,BSSID,CHAN,FREQ,SIGNAL,SECURITY',\n" +
        "    'device','wifi','list','--rescan','no'],\n" +
        "    capture_output=True, text=True, timeout=8).stdout\n" +
        "status = subprocess.run(['nmcli','--wait','8','-t','-f','DEVICE,TYPE,STATE',\n" +
        "    'device','status'], capture_output=True, text=True).stdout\n" +
        "wifi_state = ''\n" +
        "wifi_dev = ''\n" +
        "for line in status.splitlines():\n" +
        "    parts = line.split(':', 2)\n" +
        "    if len(parts) == 3 and parts[1] == 'wifi':\n" +
        "        wifi_dev = parts[0]\n" +
        "        wifi_state = parts[2]\n" +
        "        break\n" +
        "active_connection = ''\n" +
        "if wifi_dev:\n" +
        "    active_connection = subprocess.run(['nmcli','--wait','8','-g',\n" +
        "        'GENERAL.CONNECTION','device','show', wifi_dev],\n" +
        "        capture_output=True, text=True).stdout.strip()\n" +
        "    if active_connection == '--':\n" +
        "        active_connection = ''\n" +
        "def fields(line):\n" +
        "    out = []\n" +
        "    cur = ''\n" +
        "    esc = False\n" +
        "    for ch in line:\n" +
        "        if esc:\n" +
        "            cur += ch\n" +
        "            esc = False\n" +
        "        elif ch == '\\\\':\n" +
        "            esc = True\n" +
        "        elif ch == ':':\n" +
        "            out.append(cur)\n" +
        "            cur = ''\n" +
        "        else:\n" +
        "            cur += ch\n" +
        "    out.append(cur)\n" +
        "    return out\n" +
        "aps = {}\n" +
        "hidden = {}\n" +
        "for line in raw.splitlines():\n" +
        "    if not line.strip():\n" +
        "        continue\n" +
        "    f = fields(line)\n" +
        "    if len(f) < 7:\n" +
        "        continue\n" +
        "    inuse, ssid, bssid, chan, freq, signal, security = f[:7]\n" +
        "    try:\n" +
        "        freq = float(freq.replace(' MHz', '').strip())\n" +
        "    except Exception:\n" +
        "        freq = 0.0\n" +
        "    band = '2.4' if 0 < freq < 3000 else ('5' if freq < 5925 else ('6' if freq else ''))\n" +
        "    try:\n" +
        "        level = int(signal)\n" +
        "    except Exception:\n" +
        "        level = 0\n" +
        "    if not ssid.strip() or ssid.strip() == '--':\n" +
        "        item = hidden.setdefault(bssid, {'ssid': '', 'bssid': bssid,\n" +
        "                                    'bands': [], 'signal': 0,\n" +
        "                                    'security': security, 'active': False})\n" +
        "        if band and band not in item['bands']:\n" +
        "            item['bands'].append(band)\n" +
        "        if level > item['signal']:\n" +
        "            item['signal'] = level\n" +
        "        if inuse.strip() == '*':\n" +
        "            item['active'] = True\n" +
        "        if security:\n" +
        "            item['security'] = security\n" +
        "        continue\n" +
        "    item = aps.setdefault(ssid, {'ssid': ssid, 'bands': [], 'signal': 0,\n" +
        "                                'security': security, 'active': False})\n" +
        "    if band and band not in item['bands']:\n" +
        "        item['bands'].append(band)\n" +
        "    if level > item['signal']:\n" +
        "        item['signal'] = level\n" +
        "    if inuse.strip() == '*':\n" +
        "        item['active'] = True\n" +
        "    if security:\n" +
        "        item['security'] = security\n" +
        "for item in aps.values():\n" +
        "    item['bands'].sort(key=float)\n" +
        "for item in hidden.values():\n" +
        "    item['bands'].sort(key=float)\n" +
        "    item['strength'] = max(0.0, min(1.0, (item['signal'] + 100) / 70.0))\n" +
        "print(json.dumps({\n" +
        "    'aps': sorted(aps.values(),\n" +
        "        key=lambda x: (not x['active'], -x['signal'], x['ssid'].lower())),\n" +
        "    'hidden': sorted(hidden.values(),\n" +
        "        key=lambda x: (not x['active'], -x['signal'], x['bssid'])),\n" +
        "    'state': wifi_state,\n" +
        "    'activeConnection': active_connection}))\n"

    Timer {
        interval: 5000
        repeat: true
        running: root.watching
        onTriggered: root.refresh()
        onRunningChanged: if (running) root.refresh()
    }

    Timer {
        interval: 2500
        repeat: true
        running: true
        onTriggered: root.syncActive()
    }

    // Si nmcli o Python se atascan, la consulta se corta y el indicador deja
    // de girar. Sin esto, `scanning` se quedaba en true para siempre.
    Timer {
        interval: 12000
        running: root.scanning
        repeat: false
        onTriggered: {
            if (scanProc.running)
                scanProc.running = false;
            root.scanning = false;
            root.hasScanned = true;
            root.lastError = "La búsqueda de redes tardó demasiado.";
        }
    }

    Process {
        id: scanProc

        command: ["python3", "-c", root.scanScript]

        stdout: StdioCollector {
            id: scanOut
        }

        stderr: StdioCollector {
            id: scanErr
        }

        onExited: (code) => {
            root.scanning = false;
            if (!root.watching)
                return;
            root.hasScanned = true;
            if (code !== 0) {
                root.lastError = scanErr.text.trim() || "No se pudo consultar las redes.";
                return;
            }
            const raw = scanOut.text.trim();
            if (raw.length === 0) {
                root.accessPoints = [];
                root.hiddenAccessPoints = [];
                root.deviceState = "";
                root.activeConnectionName = "";
                root.lastError = "";
                return;
            }
            try {
                const data = JSON.parse(raw);
                if (Array.isArray(data)) {
                    root.accessPoints = data;
                    root.hiddenAccessPoints = [];
                    root.deviceState = "";
                    root.activeConnectionName = "";
                } else {
                    root.accessPoints = data.aps || [];
                    root.hiddenAccessPoints = data.hidden || [];
                    root.deviceState = data.state || "";
                    root.activeConnectionName =
                        String(data.activeConnection || "");
                }
                root.lastError = "";
            } catch (e) {
                root.lastError = "No se pudo leer la lista de redes.";
            }
        }

        onRunningChanged: root.scanning = running
    }

    Process {
        id: profileProc

        command: ["python3", root.helperPath, "profile", "",
            root.profileQrPath]

        stdout: StdioCollector {
            id: profileOut
        }

        onExited: (code) => {
            if (code !== 0) {
                root.profileError = "No se pudo leer el perfil.";
                return;
            }
            try {
                const info = JSON.parse(profileOut.text.trim() || "{}");
                root.profileFound = info.found === true;
                root.profileUuid = info.found === true
                    ? String(info.uuid || "") : "";
                root.profileAutoconnect = info.autoconnect === true;
                root.profileQrReady = info.qr === true;
                root.profileError = root.profileFound
                    ? "" : "Sin perfil guardado.";
                if (root.profileQrReady)
                    root.profileQrVersion = "" + Date.now();
            } catch (e) {
                root.profileError = "No se pudo leer el perfil.";
            }
        }
    }

    Process {
        id: autoconnectProc

        stdout: StdioCollector {
            id: autoconnectOut
        }

        onExited: (code) => {
            try {
                const info = JSON.parse(autoconnectOut.text.trim() || "{}");
                if (info.ok === true)
                    root.profileAutoconnect = info.autoconnect !== false;
            } catch (e) {
                root.lastError = "No se pudo cambiar la reconexión.";
            }
            if (code !== 0)
                root.lastError = "No se pudo cambiar la reconexión.";
        }
    }

    Process {
        id: forgetProc

        stdout: StdioCollector {
            id: forgetOut
        }

        onExited: (code) => {
            try {
                const info = JSON.parse(forgetOut.text.trim() || "{}");
                if (info.ok === true) {
                    root.clearProfile();
                    root.lastError = "";
                    root.refresh();
                } else {
                    root.lastError = "No se pudo olvidar la red.";
                }
            } catch (e) {
                root.lastError = "No se pudo olvidar la red.";
            }
        }
    }

    Process {
        id: rescanProc

        command: ["nmcli", "--wait", "10", "device", "wifi", "rescan"]

        onExited: root.refresh()
    }

    Process {
        id: hiddenProc

        stderr: StdioCollector {
            id: hiddenErr
        }

        onExited: (code) => {
            root.hiddenBusy = false;
            if (code !== 0) {
                const text = String(hiddenErr.text || "").trim();
                root.hiddenError = text.length > 0
                    ? text : "No se pudo conectar a la red oculta.";
                return;
            }
            root.hiddenError = "";
            root.hiddenConnected();
            root.refresh();
            root.requestScan();
        }
    }

    Process {
        id: bandProc
    }
}
