pragma Singleton

import Quickshell
import QtQuick

// Panel rápido de los controles de la barra. Cada control abre su vista
// avanzada en el panel lateral, pero en modo compacto y sin la sección de
// notificaciones. La campana abre el panel completo con notificaciones,
// centro de control y sus opciones avanzadas.
Singleton {
    id: root

    property bool open: false
    // Clave de la vista avanzada activa ("wifi", "volume", "bluetooth"...).
    property string key: ""
    // Centro del control pulsado, en coordenadas de la barra, para colocar el
    // panel justo debajo (o encima) de él. anchorY se usa con la barra
    // vertical, donde el panel se abre al lado y a la altura del control.
    property real anchorX: -1
    property real anchorY: -1

    signal opened()
    // Verdadero mientras el panel del micrófono está capturando un atajo.
    // Super forma parte de la combinación y no debe cerrar el panel.
    property bool micCapturing: false

    function isOpen(value): bool {
        return root.open && root.key === String(value || "");
    }

    function show(value, anchorX, anchorY): void {
        const view = String(value || "");
        if (view.length === 0)
            return;
        root.key = view;
        root.anchorX = (anchorX === undefined || anchorX === null)
            ? -1 : Number(anchorX);
        root.anchorY = (anchorY === undefined || anchorY === null)
            ? -1 : Number(anchorY);
        if (root.open) {
            // Ya estaba abierto: solo cambia de vista y de ancla.
            root.opened();
            return;
        }
        // Se marca abierto antes de retirar los demás paneles: así el panel
        // lateral no se oculta y vuelve a mostrarse entre medias.
        root.open = true;
        LauncherState.hide();
        NotificationState.hidePanel();
        CalendarState.hide();
        PowerState.hide();
        BatteryState.hide();
        TrayState.hide();
        SuperState.hide();
        root.opened();
    }

    function toggle(value, anchorX, anchorY): void {
        if (root.isOpen(value)) {
            root.hide();
            return;
        }
        root.show(value, anchorX, anchorY);
    }

    function hide(): void {
        root.open = false;
    }


    // Cualquier otro panel que se abra retira el rápido para no apilar
    // paneles. La campana sigue abriendo SidePanel con notificaciones y
    // centro de control.
    Connections {
        target: NotificationState

        function onPanelOpenChanged(): void {
            if (NotificationState.panelOpen)
                root.hide();
        }
    }

    Connections {
        target: CalendarState

        function onOpenChanged(): void {
            if (CalendarState.open)
                root.hide();
        }
    }

    Connections {
        target: LauncherState

        function onOpenChanged(): void {
            if (LauncherState.open)
                root.hide();
        }
    }

    Connections {
        target: PowerState

        function onOpenChanged(): void {
            if (PowerState.open)
                root.hide();
        }
    }

    Connections {
        target: BatteryState

        function onOpenChanged(): void {
            if (BatteryState.open)
                root.hide();
        }
    }

    Connections {
        target: TrayState

        function onOpenChanged(): void {
            if (TrayState.open)
                root.hide();
        }
    }

    Connections {
        target: SuperState

        function onActiveChanged(): void {
            if (SuperState.active && !root.micCapturing)
                root.hide();
        }
    }
}
