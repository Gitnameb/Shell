pragma Singleton

import Quickshell

// Estado del desplegable de la bandeja del sistema. Los iconos de las apps
// (StatusNotifierItem) no viven en la barra: se agrupan en un panel aparte que
// se abre con el botón de chevron. `anchorX` guarda el centro del botón en
// coordenadas de pantalla para colocar el panel justo encima de él.
Singleton {
    id: root

    property bool open: false
    // -1 significa «sin botón conocido»: el panel cae a la derecha.
    property real anchorX: -1
    // Altura del botón para colocar el panel en la barra vertical.
    property real anchorY: -1

    signal opened()

    function toggle(): void {
        BatteryState.hide();
        if (!root.open) {
            root.open = true;
            root.opened();
            return;
        }
        root.open = false;
    }

    function show(): void {
        BatteryState.hide();
        if (root.open)
            return;
        root.open = true;
        root.opened();
    }

    function hide(): void {
        root.open = false;
    }
}
