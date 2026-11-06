pragma Singleton

import Quickshell

// Selector de escritorio del botón «Mover» de la barra de título nativa.
//
// Umbriel no dibuja el menú: solo avisa con la ventana y la posición del
// puntero. Este estado compartido permite que la tarjeta viva en shell.qml y
// que la capa de cierre de la barra sepa cuándo hay algo abierto.
Singleton {
    id: root

    property bool open: false
    property string windowId: ""
    property real anchorX: 0
    property real anchorY: 0

    function show(windowId, x, y): void {
        if (String(windowId || "").length === 0)
            return;
        // El selector no debe quedar debajo de otro panel.
        NotificationState.hidePanel();
        CalendarState.hide();
        PowerState.hide();
        BatteryState.hide();
        LauncherState.hide();
        root.windowId = String(windowId);
        root.anchorX = Number(x) || 0;
        root.anchorY = Number(y) || 0;
        root.open = true;
    }

    function hide(): void {
        if (!root.open && root.windowId.length === 0)
            return;
        root.open = false;
        root.windowId = "";
    }
}
