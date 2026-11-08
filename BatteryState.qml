pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick

// Estado de la batería y del panel de energía que cuelga de ella.
//
// En un equipo de sobremesa no hay batería. Aun así el icono sigue en la
// barra, con el rayo de corriente y sin porcentaje, porque desde ahí se
// cambian los perfiles de energía. En un portátil muestra el nivel real.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: root.device !== null
        && root.device.isPresent && root.device.isLaptopBattery
    readonly property real percentage: root.present
        ? root.device.percentage : -1
    readonly property int level: root.present
        ? Math.max(0, Math.min(100, Math.round(root.percentage))) : -1
    readonly property int deviceState: root.present
        ? root.device.state : UPowerDeviceState.Unknown
    readonly property bool charging: root.present
        && (root.deviceState === UPowerDeviceState.Charging
            || root.deviceState === UPowerDeviceState.PendingCharge)
    readonly property bool full: root.present
        && root.deviceState === UPowerDeviceState.FullyCharged
    // Sin batería y con corriente: el equipo está enchufado.
    readonly property bool mains: !root.present && !UPower.onBattery

    // Mismos colores que el ejemplo web: texto normal, naranja desde el 20 %
    // y rojo desde el 10 %. El ahorro tiñe de celeste si no hay aviso.
    readonly property color tone: {
        if (root.present) {
            if (root.level <= 10)
                return Theme.danger;
            if (root.level <= 20)
                return Theme.warm;
        }
        if (PowerProfilesState.current === "power-saver")
            return "#8fd8f2";
        return Theme.text;
    }

    readonly property string statusText: {
        if (!root.present) {
            return UPower.onBattery
                ? "Sin batería" : "Sin batería · conectado a la corriente";
        }
        if (root.charging)
            return "Batería al " + root.level + "% · cargando";
        if (root.full || root.level >= 100)
            return "Batería al " + root.level + "% · carga completa";
        if (root.deviceState === UPowerDeviceState.Empty)
            return "Batería agotada";
        return "Batería al " + root.level + "% · descargando";
    }

    readonly property string tooltip: root.statusText
        + " · modo " + PowerProfilesState.label(PowerProfilesState.current)
        + " · clic para opciones de energía"

    // ------------------------------------------------------------ panel
    property bool open: false
    property real anchorX: -1
    property real anchorY: -1

    signal opened()

    function show(): void {
        if (root.open)
            return;
        LauncherState.hide();
        NotificationState.hidePanel();
        CalendarState.hide();
        PowerState.hide();
        TrayState.hide();
        SuperState.hide();
        root.open = true;
        root.opened();
    }

    function toggle(): void {
        if (root.open)
            root.hide();
        else
            root.show();
    }

    function hide(): void {
        root.open = false;
    }
}
