pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import QtQuick

// Apagado por inactividad. El punto de acceso se apaga si pasa el tiempo
// configurado sin ningún cliente conectado; el Wi-Fi se apaga si pasa el
// tiempo sin estar conectado a ninguna red y el Bluetooth si no tiene ningún
// dispositivo conectado. Mientras el hotspot está activo no se toca el Wi-Fi,
// porque la radio se está usando como punto de acceso.
Singleton {
    id: root

    property real lastHotspotActivity: 0
    property real lastWifiActivity: 0
    property real lastBluetoothActivity: 0

    function wifiConnected(): bool {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type !== DeviceType.Wifi)
                continue;
            const networks = devices[i].networks.values;
            for (let j = 0; j < networks.length; j++) {
                if (networks[j].connected)
                    return true;
            }
        }
        return false;
    }

    function bluetoothConnected(): bool {
        const devices = Bluetooth.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].connected)
                return true;
        }
        return false;
    }

    function tick(): void {
        const now = Date.now();

        // ------------------------------------------------ punto de acceso
        if (HotspotState.active) {
            if (!SettingsState.hotspotAutoOff
                    || HotspotState.activeClientCount > 0) {
                root.lastHotspotActivity = now;
            } else if (root.lastHotspotActivity <= 0) {
                root.lastHotspotActivity = now;
            } else if (now - root.lastHotspotActivity
                    >= SettingsState.hotspotMinutes * 60000) {
                root.lastHotspotActivity = now;
                HotspotState.stop();
            }
        } else {
            root.lastHotspotActivity = now;
        }

        // ----------------------------------------------------------- Wi-Fi
        // Con hotspot activo la radio está ocupada; no se apaga por "falta de
        // conexión" porque el punto de acceso no es una conexión de estación.
        if (!Networking.wifiEnabled || HotspotState.active || HotspotState.busy
                || !SettingsState.wifiAutoOff || root.wifiConnected()) {
            root.lastWifiActivity = now;
        } else if (root.lastWifiActivity <= 0) {
            root.lastWifiActivity = now;
        } else if (now - root.lastWifiActivity
                >= SettingsState.wifiMinutes * 60000) {
            root.lastWifiActivity = now;
            Networking.wifiEnabled = false;
        }

        // ------------------------------------------------------ Bluetooth
        const adapter = Bluetooth.defaultAdapter;
        if (!adapter || !adapter.enabled || !SettingsState.btAutoOff
                || root.bluetoothConnected() || adapter.discovering) {
            root.lastBluetoothActivity = now;
        } else if (root.lastBluetoothActivity <= 0) {
            root.lastBluetoothActivity = now;
        } else if (now - root.lastBluetoothActivity
                >= SettingsState.btMinutes * 60000) {
            root.lastBluetoothActivity = now;
            adapter.enabled = false;
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.tick()
    }
}
