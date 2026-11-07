pragma Singleton

import Quickshell
import QtQuick

// Arrastre de controles entre el centro de control y la barra. La posición
// global llega desde el MouseArea que está arrastrando (`setPointer`), así no
// hay que sondear `hyprctl` ni depender de un proceso que arranca tarde.
Singleton {
    id: root

    property bool active: false
    // "center" si sale del centro de control, "bar" si sale de la barra.
    property string origin: ""
    property string key: ""
    property string label: ""
    property bool overBar: false
    property bool overPanel: false
    // Geometría del panel abierto, actualizada por SidePanel.qml.
    property rect panelBounds: Qt.rect(0, 0, 0, 0)
    property real cursorX: 0
    property real cursorY: 0
    // Posición final dentro de la barra cuando se reordena un control.
    // -1 significa que no hay destino calculado. Lo actualiza Bar.qml.
    property int targetIndex: -1
    // Destino dentro de la cuadrícula del centro de control. Lo actualiza
    // ControlCenterContent.qml.
    property int centerTargetIndex: -1
    property string centerTargetKey: ""
    property string pendingKey: ""
    property string pendingAction: ""
    property int pendingTarget: -1
    // Orden original del centro para poder deshacer la vista previa si el
    // arrastre termina fuera del panel.
    property var centerBackup: []

    readonly property var screen: Quickshell.screens.length > 0
        ? Quickshell.screens[0]
        : null
    readonly property bool vertical: SettingsState.barVertical
    readonly property bool autoHide: SettingsState.autoHideBar
    readonly property real barLeft: !root.screen
        ? 0
        : (root.vertical
            ? (SettingsState.barAtLeft
                ? root.screen.x + (root.autoHide ? 0 : Theme.edge)
                : root.screen.x + root.screen.width
                    - Theme.edge - Theme.barHeight)
            : root.screen.x + Theme.edge)
    readonly property real barTop: !root.screen
        ? 0
        : (root.vertical
            ? root.screen.y + Theme.edge
            : (SettingsState.barAtTop
                ? root.screen.y + (root.autoHide ? 0 : Theme.edge)
                : root.screen.y + root.screen.height
                    - Theme.edge - Theme.barHeight))
    readonly property real barRight: !root.screen
        ? 0
        : (root.vertical
            ? root.barLeft + Theme.barHeight
            : root.screen.x + root.screen.width - Theme.edge)
    readonly property real barBottom: !root.screen
        ? 0
        : (root.vertical
            ? root.screen.y + root.screen.height - Theme.edge
            : root.barTop + Theme.barHeight)

    function begin(key: string, label: string, origin: string): void {
        root.key = key;
        root.label = label;
        root.origin = origin;
        root.targetIndex = -1;
        root.centerTargetIndex = -1;
        root.centerTargetKey = "";
        root.centerBackup = origin === "center"
            ? BarState.centerOrder.slice() : [];
        root.active = true;
    }

    // Coordenadas globales de la pantalla. Cada MouseArea que arrastra las
    // calcula a partir de su propia ventana.
    function setPointer(x: real, y: real): void {
        root.cursorX = x;
        root.cursorY = y;

        const s = root.screen;
        if (!s)
            return;

        root.overBar = x >= root.barLeft
            && x <= root.barRight
            && y >= root.barTop
            && y <= root.barBottom;

        const bounds = root.panelBounds;
        root.overPanel = bounds.width > 0
            && bounds.height > 0
            && x >= bounds.x
            && x <= bounds.x + bounds.width
            && y >= bounds.y
            && y <= bounds.y + bounds.height;

        // Al salir de la cuadrícula se deshace la vista previa; si se vuelve
        // a entrar, se calcula de nuevo la celda de destino.
        if (root.active && root.origin === "center" && !root.overPanel) {
            root.restoreCenter();
            root.centerTargetIndex = -1;
            root.centerTargetKey = "";
        }
    }

    function restoreCenter(): void {
        if (root.centerBackup.length === 0)
            return;
        if (BarState.centerOrder.join(",") === root.centerBackup.join(","))
            return;
        BarState.centerOrder = root.centerBackup.slice();
    }

    function clearState(): void {
        root.active = false;
        root.overBar = false;
        root.overPanel = false;
        root.origin = "";
        root.key = "";
        root.label = "";
        root.targetIndex = -1;
        root.centerTargetIndex = -1;
        root.centerTargetKey = "";
        root.centerBackup = [];
    }

    function end(): void {
        if (!root.active)
            return;

        const key = root.key;
        const origin = root.origin;
        const overBar = root.overBar;
        const overPanel = root.overPanel;
        const target = root.targetIndex;
        const centerTarget = root.centerTargetIndex;

        if (origin === "center" && overBar && key.length > 0) {
            root.restoreCenter();
            root.clearState();
            root.pendingKey = key;
            root.pendingAction = "add";
            deferTimer.restart();
            return;
        }
        if (origin === "center") {
            // Dentro del panel el orden ya se movió en vivo; fuera se revierte.
            if (!overPanel || centerTarget < 0)
                root.restoreCenter();
            root.clearState();
            return;
        }
        if (origin === "bar" && overBar && target >= 0 && key.length > 0) {
            root.clearState();
            root.pendingKey = key;
            root.pendingAction = "move";
            root.pendingTarget = target;
            deferTimer.restart();
            return;
        }
        if (origin === "bar" && overPanel && key.length > 0) {
            root.clearState();
            root.pendingKey = key;
            root.pendingAction = "remove";
            deferTimer.restart();
            return;
        }
        root.clearState();
    }

    function cancel(): void {
        if (root.origin === "center")
            root.restoreCenter();
        root.clearState();
    }

    // Aplica el cambio de sitio un instante después de soltar.
    Timer {
        id: deferTimer
        interval: 0
        repeat: false

        onTriggered: {
            if (root.pendingAction === "add")
                BarState.add(root.pendingKey);
            else if (root.pendingAction === "remove")
                BarState.remove(root.pendingKey);
            else if (root.pendingAction === "move")
                BarState.move(root.pendingKey, root.pendingTarget);
            root.pendingAction = "";
            root.pendingKey = "";
            root.pendingTarget = -1;
        }
    }

    // Red de seguridad: si la ventana pierde el evento de soltar, el arrastre
    // no se queda activo indefinidamente.
    Timer {
        interval: 10000
        running: root.active
        repeat: false
        onTriggered: root.cancel()
    }
}
