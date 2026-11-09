import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import QtQuick

// Control fijo de la barra, movido arrastrándolo desde el centro de control.
// El clic abre sus opciones avanzadas, salvo en el modo avión, que solo
// alterna; arrastrarlo de vuelta al panel lo devuelve al centro de control.
Pill {
    id: root

    property string key: ""
    // En la barra vertical solo cabe el icono: se ocultan porcentajes y el
    // tráfico de red se resume con su icono.
    readonly property bool compact: SettingsState.barVertical

    // Todos los controles comparten el mismo relleno y la misma caja de icono.
    // Así el hueco entre dos controles siempre es el mismo y ninguno parece
    // más alto o más separado que el resto. El tráfico de red solo pide un
    // ancho mínimo para sus cifras; crece con el contenido en vez de reservar
    // 50 px fijos aunque esté en «0 B/s».
    horizontalPadding: root.compact ? 2 : 3
    preferredWidth: root.key === "net" && !root.compact ? 34 : 0
    readonly property real glyphSize: SettingsState.barIconSize

    // Elige el SVG del Wi-Fi con la misma escala de bandas que el diseño.
    function wifiSource(strength: real): string {
        if (strength >= 0.75)
            return ShellIcons.src("wifi-3");
        if (strength >= 0.5)
            return ShellIcons.src("wifi-2");
        return ShellIcons.src("wifi-1");
    }

    readonly property var wifiDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }

    readonly property var wiredDevice: {
        const devices = Networking.devices.values;
        let fallback = null;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type !== DeviceType.Wired)
                continue;
            if (devices[i].connected)
                return devices[i];
            if (fallback === null)
                fallback = devices[i];
        }
        return fallback;
    }

    readonly property var activeWifi: {
        if (!root.wifiDevice)
            return null;
        const networks = root.wifiDevice.networks.values;
        for (let i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i];
        }
        return null;
    }

    readonly property bool wiredConnected: root.wiredDevice !== null
        && root.wiredDevice.connected
    readonly property bool wiredUsb: {
        if (!root.wiredDevice)
            return false;
        const name = String(root.wiredDevice.name || "").toLowerCase();
        return name.indexOf("usb") === 0
            || name.indexOf("enx") === 0
            || name.indexOf("rndis") === 0;
    }
    readonly property bool wifiConnected: root.wifiDevice !== null
        && root.wifiDevice.connected
    // La ficha de la barra representa toda la red, no solo el Wi-Fi.
    readonly property bool networkConnected: root.wiredConnected
        || root.wifiConnected
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: root.btAdapter !== null
        && root.btAdapter.enabled
    readonly property var btConnectedDevice: {
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                return list[i];
        }
        return null;
    }
    readonly property real btBatteryLevel: root.btConnectedDevice !== null
        && root.btConnectedDevice.batteryAvailable
        ? root.btConnectedDevice.battery * 100 : -1
    // El icono solo cambia de color cuando la batería está baja: rojo hasta
    // el 10 %, naranja hasta el 20 % y blanco (texto normal) por encima.
    readonly property color btBatteryColor: {
        if (root.btBatteryLevel < 0)
            return Theme.accent;
        if (root.btBatteryLevel <= 10)
            return Theme.danger;
        if (root.btBatteryLevel <= 20)
            return Theme.warning;
        return Theme.accent;
    }
    readonly property bool airplaneActive: AirplaneState.active

    readonly property string iconName: {
        if (root.key === "wifi") {
            // La barra usa siempre iconSource (SVG propios); este nombre queda
            // vacío para no depender del tema.
            return "";
        }
        if (root.key === "bluetooth")
            return root.btEnabled
                ? "network-bluetooth-activated" : "network-bluetooth";
        if (root.key === "volume") {
            if (Audio.muted)
                return "audio-volume-muted";
            if (Audio.volume > 0.55)
                return "audio-volume-high";
            if (Audio.volume > 0.2)
                return "audio-volume-medium";
            return "audio-volume-low";
        }
        if (root.key === "mic")
            return Audio.micMuted
                ? "microphone-sensitivity-muted"
                : "microphone-sensitivity-high";
        if (root.key === "night")
            return "redshift-status-on";
        if (root.key === "airplane")
            return "flightmode-on";
        if (root.key === "brightness")
            return "video-display-brightness";
        if (root.key === "extraDim")
            return "brightness-low";
        if (root.key === "hotspot")
            return "network-wireless-hotspot";
        if (root.key === "cpu")
            return "cpu";
        if (root.key === "gpu")
            return "video-card-inactive-symbolic";
        if (root.key === "net") {
            // Igual que el Wi-Fi: iconSource aporta el SVG propio.
            return "";
        }
        if (root.key === "vpn")
            return "network-vpn";
        if (root.key === "keyboard")
            return "input-keyboard-symbolic";
        if (root.key === "clipboard")
            return "edit-paste";
        if (root.key === "settings")
            return "applications-system-symbolic";
        if (root.key === "dns")
            return "";
        return "";
    }

    // El color del icono comunica el estado, como en el ejemplo web.
    readonly property color iconColor: {
        if (root.key === "wifi") {
            if (root.wiredConnected)
                return Theme.accent;
            if (!root.networkConnected)
                return Theme.danger;
            if (!root.activeWifi)
                return Theme.accent;
            return root.activeWifi.signalStrength >= 0.5
                ? Theme.accent : Theme.warning;
        }
        if (root.key === "bluetooth") {
            if (!root.btEnabled)
                return Theme.accentFaded;
            return root.btBatteryColor;
        }
        if (root.key === "volume")
            return Audio.muted ? Theme.danger : Theme.accent;
        if (root.key === "mic")
            return Audio.micMuted ? Theme.danger : Theme.accent;
        if (root.key === "night")
            return DisplayState.nightLight ? Theme.accent : Theme.accentFaded;
        if (root.key === "airplane")
            return root.airplaneActive ? Theme.accent : Theme.accentFaded;
        if (root.key === "brightness")
            return DisplayState.brightness < 0.99
                ? Theme.accent : Theme.accentFaded;
        if (root.key === "extraDim")
            return DisplayState.extraDim > 0.01
                ? Theme.accent : Theme.accentFaded;
        if (root.key === "hotspot") {
            if (HotspotState.busy)
                return Theme.warning;
            return HotspotState.active ? Theme.accent : Theme.accentFaded;
        }
        if (root.key === "cpu")
            return root.cpuColor;
        if (root.key === "gpu")
            return root.gpuColor;
        if (root.key === "net")
            return (SystemStats.netDown + SystemStats.netUp) > 1024
                ? Theme.accent : Theme.accentFaded;
        if (root.key === "vpn")
            return VpnState.active ? Theme.accent : Theme.accentFaded;
        if (root.key === "keyboard")
            return KeyboardState.visible ? Theme.accent : Theme.accentFaded;
        if (root.key === "clipboard")
            return ClipboardState.count > 0
                || QuickPanelState.isOpen("clipboard")
                ? Theme.accent : Theme.accentFaded;
        if (root.key === "settings")
            return QuickPanelState.isOpen("settings")
                ? Theme.accent : Theme.accentFaded;
        if (root.key === "dns")
            return DnsState.allAuto ? Theme.accentFaded : Theme.accent;
        return Theme.accentFaded;
    }

    readonly property color cpuColor: SystemStats.cpuTemp >= 0
        ? SystemStats.thermalColor(SystemStats.cpuTemp) : Theme.accentFaded
    readonly property color gpuColor: SystemStats.gpuTemp >= 0
        ? SystemStats.thermalColor(SystemStats.gpuTemp) : Theme.accentFaded

    // Iconos exactos del diseño para los widgets que el usuario dibujó. El
    // resto sigue usando el tema Breeze.
    readonly property string iconSource: {
        if (root.key === "wifi") {
            if (root.wiredConnected)
                return ShellIcons.src(root.wiredUsb ? "usb" : "wired");
            if (!root.wifiConnected)
                return ShellIcons.src("globe-off");
            if (!root.activeWifi)
                return ShellIcons.src("wifi-3");
            return root.wifiSource(root.activeWifi.signalStrength);
        }
        if (root.key === "bluetooth")
            return ShellIcons.src("bluetooth");
        if (root.key === "night")
            return ShellIcons.src("moon");
        if (root.key === "airplane")
            return ShellIcons.src("plane");
        if (root.key === "brightness")
            return ShellIcons.src("sun");
        if (root.key === "extraDim")
            return ShellIcons.src("dim");
        if (root.key === "cpu")
            return ShellIcons.src("cpu");
        if (root.key === "vpn")
            return ShellIcons.src("shield");
        if (root.key === "net")
            return ShellIcons.src("net");
        if (root.key === "keyboard")
            return ShellIcons.src("keyboard");
        if (root.key === "clipboard")
            return ShellIcons.src("clipboard");
        if (root.key === "hotspot")
            return ShellIcons.src("hotspot");
        if (root.key === "settings")
            return ShellIcons.src("settings");
        if (root.key === "dns")
            return ShellIcons.src("dns");
        if (root.key === "gpu")
            return ShellIcons.src("gpu");
        return "";
    }

    readonly property string fallbackIcon: {
        if (root.key === "wifi")
            return "◌";
        if (root.key === "bluetooth")
            return "ᛒ";
        if (root.key === "volume")
            return "◖";
        if (root.key === "mic")
            return "◉";
        if (root.key === "night")
            return "☾";
        if (root.key === "airplane")
            return "✈";
        if (root.key === "brightness")
            return "☀";
        if (root.key === "extraDim")
            return "◐";
        if (root.key === "hotspot")
            return "◌";
        if (root.key === "cpu")
            return "▣";
        if (root.key === "gpu")
            return "▤";
        if (root.key === "net")
            return "⇅";
        if (root.key === "vpn")
            return "⛨";
        if (root.key === "keyboard")
            return "⌨";
        if (root.key === "clipboard")
            return "▤";
        if (root.key === "settings")
            return "⚙";
        if (root.key === "dns")
            return "D";
        return "•";
    }

    active: {
        if (root.key === "settings" || root.key === "clipboard")
            return QuickPanelState.isOpen(root.key);
        if (root.key === "wifi")
            return root.wiredConnected || root.wifiConnected;
        if (root.key === "bluetooth")
            return root.btEnabled;
        if (root.key === "volume")
            return Audio.available && !Audio.muted;
        if (root.key === "mic")
            return Audio.micAvailable && !Audio.micMuted;
        if (root.key === "night")
            return DisplayState.nightLight;
        if (root.key === "airplane")
            return root.airplaneActive;
        if (root.key === "brightness")
            return DisplayState.brightness < 0.99;
        if (root.key === "extraDim")
            return DisplayState.extraDim > 0.01;
        if (root.key === "hotspot")
            return HotspotState.active;
        if (root.key === "cpu")
            return false;
        if (root.key === "gpu")
            return false;
        if (root.key === "net")
            return (SystemStats.netDown + SystemStats.netUp) > 1024;
        if (root.key === "vpn")
            return VpnState.active;
        if (root.key === "keyboard")
            return KeyboardState.visible;
        if (root.key === "dns")
            return !DnsState.allAuto;
        return false;
    }

    draggable: true
    onClicked: {
        // El modo avión es solo un interruptor: no tiene vista propia.
        if (root.key === "airplane") {
            AirplaneState.toggle();
            return;
        }
        // Cada control abre su propio panel rápido, sin la sección de
        // notificaciones. El ancla es el centro del control en la barra.
        const point = root.mapToItem(null, root.width / 2, root.height / 2);
        QuickPanelState.toggle(root.key, point.x, point.y);
    }
    onDragStarted: ControlDrag.begin(root.key, BarState.label(root.key), "bar")
    onDragFinished: ControlDrag.end()
    onDragCanceled: ControlDrag.cancel()
    onWheeled: (delta) => {
        if (root.key === "volume")
            Audio.adjust(delta > 0 ? 0.02 : -0.02);
        else if (root.key === "mic")
            Audio.adjustMic(delta > 0 ? 0.02 : -0.02);
        else if (root.key === "brightness")
            DisplayState.setBrightness(DisplayState.brightness
                + (delta > 0 ? 0.05 : -0.05));
        else if (root.key === "extraDim")
            DisplayState.setExtraDim(DisplayState.extraDim
                + (delta > 0 ? 0.05 : -0.05));
        else if (root.key === "night" && DisplayState.nightLight)
            DisplayState.setNightStrength(DisplayState.nightStrength
                + (delta > 0 ? 0.05 : -0.05));
    }

    // Controles normales: icono de estado (y, en Wi-Fi, un segundo icono si
    // hay cable y Wi-Fi conectados a la vez).
    Row {
        visible: root.key !== "net" || root.compact
        spacing: 4

        Item {
            id: mainSlot

            readonly property bool shown: root.key !== "volume"
                && root.key !== "mic"

            visible: shown
            anchors.verticalCenter: parent.verticalCenter
            width: shown ? root.glyphSize : 0
            height: root.glyphSize

            ShellIcon {
                id: mainIcon

                anchors.centerIn: parent
                visible: mainSlot.shown
                name: root.iconName
                source: root.iconSource
                color: root.iconColor
                size: root.glyphSize
                normalize: true
                fallback: root.fallbackIcon
            }
        }

        // Volumen y micrófono comparten el icono de nivel. Ambos usan SVG
        // propios (volume-*.svg y mic.svg) para no depender del tema.
        Item {
            id: levelSlot

            readonly property bool shown: root.key === "volume"
                || root.key === "mic"

            visible: shown
            anchors.verticalCenter: parent.verticalCenter
            width: shown ? root.glyphSize : 0
            height: root.glyphSize

            LevelIcon {
                anchors.centerIn: parent
                visible: levelSlot.shown
                kind: root.key === "mic" ? "mic" : "volume"
                level: root.key === "mic" ? Audio.micVolume : Audio.volume
                muted: root.key === "mic" ? Audio.micMuted : Audio.muted
                color: root.iconColor
                size: root.glyphSize
                normalize: root.key === "mic"
                fallback: root.fallbackIcon
            }
        }

        Item {
            id: wifiSlot

            readonly property bool shown: root.key === "wifi"
                && root.wiredConnected && root.wifiConnected
            readonly property real side: Math.round(root.glyphSize * 0.82)

            visible: shown
            anchors.verticalCenter: parent.verticalCenter
            width: shown ? side : 0
            height: root.glyphSize

            ShellIcon {
                anchors.centerIn: parent
                visible: wifiSlot.shown
                source: root.activeWifi
                    ? root.wifiSource(root.activeWifi.signalStrength)
                    : ShellIcons.src("wifi-3")
                color: root.activeWifi
                    && root.activeWifi.signalStrength < 0.5
                    ? Theme.warning : Theme.accent
                size: wifiSlot.side
                normalize: true
                fallback: "◌"
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.compact
                && ((root.key === "volume" && Audio.available
                    && (SettingsState.showVolumePercent || Audio.muted))
                || (root.key === "brightness"
                    && SettingsState.showBrightnessPercent)
                || (root.key === "extraDim"
                    && SettingsState.showExtraDimPercent
                    && DisplayState.extraDim > 0.01)
                || (root.key === "cpu" && SettingsState.showTemps)
                || (root.key === "gpu" && SettingsState.showTemps)
                || (root.key === "bluetooth"
                    && SettingsState.showBluetoothPercent
                    && root.btBatteryLevel >= 0))
            text: {
                if (root.key === "volume")
                    return Audio.muted ? "Mudo" : Math.round(Audio.volume * 100) + "%";
                if (root.key === "brightness")
                    return Math.round(DisplayState.brightness * 100) + "%";
                if (root.key === "extraDim")
                    return Math.round(DisplayState.extraDim * 100) + "%";
                if (root.key === "cpu")
                    return SystemStats.cpuTemp >= 0
                        ? Math.round(SystemStats.cpuTemp) + "°" : "--";
                if (root.key === "gpu")
                    return SystemStats.gpuTemp >= 0
                        ? Math.round(SystemStats.gpuTemp) + "°" : "--";
                if (root.key === "bluetooth")
                    return Math.round(root.btBatteryLevel) + "%";
                return "";
            }
            color: (root.key === "volume" && Audio.muted)
                ? Theme.danger : root.iconColor
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }

    // Tráfico de red: número y unidad a la izquierda, flechas a la derecha,
    // igual que el widget del diseño (sin icono intermedio).
    Row {
        visible: root.key === "net" && !root.compact
        spacing: 1

        Column {
            anchors.verticalCenter: parent.verticalCenter
            // La unidad sube unos píxeles para quedar pegada a la cifra: con
            // el interlineado normal se veía demasiado separada.
            spacing: -2

            Text {
                anchors.right: parent.right
                text: {
                    const total = SystemStats.netDown + SystemStats.netUp;
                    if (total >= 1048576)
                        return (total / 1048576).toFixed(1).replace(".", ",");
                    if (total >= 1024)
                        return Math.round(total / 1024);
                    return Math.round(total);
                }
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
            }

            Text {
                anchors.right: parent.right
                text: {
                    const total = SystemStats.netDown + SystemStats.netUp;
                    if (total >= 1048576)
                        return "MB/s";
                    if (total >= 1024)
                        return "KB/s";
                    return "B/s";
                }
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 7
                horizontalAlignment: Text.AlignRight
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "↑"
                color: SystemStats.netUp > 64
                    ? Theme.accent : Theme.accentFaded
                opacity: SystemStats.netUp > 64 ? 1 : 0.55
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "↓"
                color: SystemStats.netDown > 64
                    ? Theme.accent : Theme.accentFaded
                opacity: SystemStats.netDown > 64 ? 1 : 0.55
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }
        }
    }
}
