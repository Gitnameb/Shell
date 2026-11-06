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
            // `connected` no depende de que la lista de redes esté cargada.
            // Con el escáner apagado, `networks` puede estar vacío aunque el
            // equipo siga conectado, y el autoapagado lo interpretaría mal.
            if (devices[i].type === DeviceType.Wifi
                    && devices[i].connected)
                return true;
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
        // Mientras se está viendo la lista de redes, el apagado automático no
        // debe empezar a contar: el usuario puede tardar en elegir una red.
        const viewingWifi = NotificationState.panelOpen
            && NotificationState.panelView === "wifi";

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
                || !SettingsState.wifiAutoOff || root.wifiConnected()
                || viewingWifi) {
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
