pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import QtQuick

// Modo avión al estilo de Android: apaga las radios inalámbricas (Wi-Fi,
// Bluetooth y punto de acceso), pero deja que el usuario las vuelva a
// encender a mano sin salir del modo. El indicador sigue activo mientras el
// modo esté activado, aunque una radio se haya encendido después.
Singleton {
    id: root

    readonly property bool active: SettingsState.airplaneMode
    readonly property var btAdapter: Bluetooth.defaultAdapter

    function setActive(enabled: bool): void {
        if (enabled === root.active)
            return;
        if (enabled) {
            // Recordar qué radios estaban encendidas para restaurarlas al
            // salir del modo avión. No se toca un punto de acceso ya activo:
            // primero se apaga y no se vuelve a levantar solo.
            SettingsState.airplaneRestoreWifi = Networking.wifiEnabled;
            SettingsState.airplaneRestoreBt = root.btAdapter !== null
                && root.btAdapter.enabled;
            SettingsState.airplaneMode = true;
            root.suspendRadios();
        } else {
            SettingsState.airplaneMode = false;
            root.restoreRadios();
        }
    }

    function toggle(): void {
        root.setActive(!root.active);
    }

    // Apaga las radios. Se puede llamar más de una vez sin efectos raros.
    function suspendRadios(): void {
        if (HotspotState.active)
            HotspotState.stop();

        // Cortar la búsqueda de redes antes de apagar la radio.
        WifiState.stop();
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi) {
                devices[i].scannerEnabled = false;
                break;
            }
        }

        if (Networking.wifiEnabled)
            Networking.wifiEnabled = false;
        if (root.btAdapter) {
            root.btAdapter.discovering = false;
            if (root.btAdapter.enabled)
                root.btAdapter.enabled = false;
        }
    }

    function restoreRadios(): void {
        if (SettingsState.airplaneRestoreWifi && !Networking.wifiEnabled)
            Networking.wifiEnabled = true;
        if (SettingsState.airplaneRestoreBt && root.btAdapter
                && !root.btAdapter.enabled)
            root.btAdapter.enabled = true;
    }

    // Si el shell se recarga o arranca con el modo avión guardado, las radios
    // deben quedar apagadas otra vez.
    Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: {
            if (SettingsState.ready && root.active)
                root.suspendRadios();
        }
    }

    Connections {
        target: SettingsState

        function onReadyChanged(): void {
            if (SettingsState.ready && root.active)
                root.suspendRadios();
        }

        function onAirplaneModeChanged(): void {
            if (SettingsState.ready && root.active)
                root.suspendRadios();
        }
    }

    // El adaptador Bluetooth puede aparecer después de cargar el singleton.
    Connections {
        target: Bluetooth

        function onDefaultAdapterChanged(): void {
            if (root.active)
                root.suspendRadios();
        }
    }
}
