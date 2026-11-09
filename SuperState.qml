pragma Singleton

import Quickshell
import QtQuick

// Estado de la tecla Super. Hyprland envía «superPress» al pulsar y
// «superRelease» al soltar. Un toque corto abre el lanzador; mantenerla
// muestra los controles de las ventanas. El modo también se puede fijar desde
// el centro de control para quien no quiera mantener la tecla.
Singleton {
    id: root

    // Debe coincidir con mod_hold_delay_ms de Umbriel: un toque corto abre el
    // lanzador y no debe encender el modo ventanas ni atenuar el contenido.
    // Se ajusta en Ajustes del shell y se escribe en la configuración del
    // compositor.
    readonly property int holdDelay: SettingsState.superHoldMs

    property bool held: false
    property bool heldOverlay: false
    property bool pinned: false
    // Si el gesto terminó siendo un toque limpio. Un atajo como Super+Return
    // no debe abrir el lanzador al soltar Super.
    property bool tapAllowed: true
    readonly property bool active: root.pinned || root.heldOverlay
    // Mientras se elige el modo inicial, Super no debe abrir el lanzador ni
    // los controles por encima del modal de bienvenida.
    readonly property bool blocked: SettingsState.ready
        && !SettingsState.workspaceModeChosen

    function press(openLauncherOnTap): void {
        if (root.blocked)
            return;
        root.held = true;
        root.heldOverlay = false;
        root.tapAllowed = openLauncherOnTap !== false;
        holdTimer.restart();
    }

    // `tapped` lo decide quien conoce el estado real de la tecla: Hyprland usa
    // el valor guardado y Umbriel manda el suyo en el evento de soltar.
    function release(tapped): void {
        if (root.blocked || !root.held)
            return;
        root.held = false;
        holdTimer.stop();
        if (root.heldOverlay) {
            root.heldOverlay = false;
            // Si está fijado, el overlay sigue abierto hasta que se cierre.
            return;
        }
        const opensLauncher = tapped === undefined
            ? root.tapAllowed : tapped === true;
        if (!root.pinned && opensLauncher) {
            // Un toque limpio de Super siempre alterna el cajón: si ya está
            // abierto, el segundo toque lo cierra.
            if (LauncherState.open)
                LauncherState.hide();
            else
                LauncherState.show();
        }
    }

    // Algunos atajos de Hyprland cancelan el gesto para que el overlay no
    // aparezca de fondo mientras se usa Super+T, Super+1, etc.
    function cancel(): void {
        root.held = false;
        root.heldOverlay = false;
        holdTimer.stop();
    }

    // La presentación nativa (puntos, divisores y barras de título) la pinta
    // Umbriel. El pin solo se lo pide al compositor; el estado visual de este
    // lado sigue mandando sobre qué paneles del shell se muestran.
    function syncOverlayPin(): void {
        if (CompositorState.supports("overlayPin"))
            CompositorState.setOverlayPinned(root.pinned);
    }

    function togglePinned(): void {
        if (root.blocked)
            return;
        root.pinned = !root.pinned;
        if (!root.pinned)
            root.heldOverlay = false;
        root.syncOverlayPin();
    }

    function showPinned(): void {
        if (root.blocked)
            return;
        root.pinned = true;
        root.syncOverlayPin();
    }

    function hide(): void {
        root.pinned = false;
        root.heldOverlay = false;
        root.held = false;
        holdTimer.stop();
        root.syncOverlayPin();
    }

    // Una recarga de QML no debe dejar el compositor con el overlay fijado.
    Component.onCompleted: root.syncOverlayPin()

    Timer {
        id: holdTimer
        interval: root.holdDelay
        repeat: false
        onTriggered: {
            if (root.held)
                root.heldOverlay = true;
        }
    }
}
