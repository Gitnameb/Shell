pragma Singleton

import Quickshell
import QtQuick

// Modo de ventanas por escritorio.
//
// «floating» imita a Windows: las ventanas existentes se sueltan y las nuevas
// se abren flotantes. «mosaic» vuelve a colocarlas en el mosaico del
// compositor. El estado se guarda en SettingsState para sobrevivir reinicios y
// se aplica a través de CompositorState, nunca con llamadas directas a
// Hyprland.
Singleton {
    id: root

    readonly property bool backendReady: CompositorState.available
    readonly property bool firstRun: SettingsState.ready
        && !SettingsState.workspaceModeChosen

    readonly property int focusedWorkspaceId: CompositorState.focusedWorkspace
        ? Number(CompositorState.focusedWorkspace.id) || 1 : 1
    readonly property string focusedMode:
        SettingsState.workspaceMode(root.focusedWorkspaceId)
    readonly property bool focusedFloating: root.focusedMode === "floating"

    // Evita repetir la aplicación inicial en cada recarga de QML.
    property bool applied: false
    property var knownWindows: ({})
    property bool applying: false
    // Último escritorio y modo aplicados, para no repetir la acción en cada
    // tic del temporizador.
    property int lastFocusedWorkspace: 0
    property string lastWorkspaceMode: ""
    // Escritorio al que se aplicará el modo cuando deje de cambiar. Umbriel
    // solo cambia el layout del escritorio activo, así que esperar a que el
    // usuario se detenga evita aplicar un modo a un escritorio intermedio.
    property int pendingWorkspace: 0
    property string pendingMode: ""

    function labelFor(mode): string {
        return mode === "mosaic" ? "Mosaico" : "Ventana";
    }

    function modeFor(workspaceId): string {
        return SettingsState.workspaceMode(workspaceId);
    }

    // En Umbriel el modo vive en la configuración nativa (`[[workspace]]`) y
    // el compositor lo aplica al recargar. El shell no envía además una orden
    // en caliente: dos caminos para el mismo cambio producían dos
    // transiciones. En Hyprland, que no tiene esa configuración, sí se
    // traduce a flotar/mosaicar cada ventana.
    function applyWorkspace(workspaceId): void {
        if (CompositorState.supports("nativeWorkspaceModes"))
            return;
        const id = Number(workspaceId);
        if (!isFinite(id) || id <= 0 || !root.backendReady
                || !CompositorState.windowDataReady)
            return;
        const mode = root.modeFor(id);
        const list = CompositorState.windowsForWorkspace(id);
        for (let i = 0; i < list.length; i++) {
            const win = list[i];
            if (win.minimized === true || win.fullscreen === true)
                continue;
            // Una ventana fijada vive por encima del mosaico por decisión del
            // usuario; no se fuerza a ningún lado.
            if (win.pinned === true)
                continue;
            if (mode === "floating" && win.floating !== true)
                CompositorState.toggleFloating(win.address);
            else if (mode === "mosaic" && win.floating === true)
                CompositorState.toggleFloating(win.address);
        }
    }

    function applyAll(): void {
        if (!root.backendReady || !CompositorState.windowDataReady
                || !SettingsState.workspaceModeChosen)
            return;
        if (CompositorState.supports("nativeWorkspaceModes"))
            return;
        root.applying = true;
        for (let id = 1; id <= SettingsState.maxWorkspaces; id++)
            root.applyWorkspace(id);
        root.applying = false;
        root.lastFocusedWorkspace = root.focusedWorkspaceId;
        root.lastWorkspaceMode = root.modeFor(root.focusedWorkspaceId);
    }

    function setMode(workspaceId, mode): void {
        const id = Number(workspaceId);
        if (!isFinite(id) || id <= 0)
            return;
        const value = SettingsState.normalizeWorkspaceMode(mode);
        if (root.modeFor(id) === value)
            return;
        // Solo se guarda la preferencia. La escritura de la regla nativa y su
        // recarga son el único camino que aplica el modo en Umbriel.
        SettingsState.setWorkspaceMode(id, value);
    }

    function toggleFocused(): void {
        root.setMode(root.focusedWorkspaceId,
            root.focusedMode === "floating" ? "mosaic" : "floating");
    }

    function choose(mode): void {
        SettingsState.chooseWorkspaceMode(mode);
        root.applied = false;
        Qt.callLater(() => root.initialize());
    }

    // Marca las ventanas actuales como ya vistas sin volver a aplicarles el
    // modo. Se usa después de applyAll para que scanNewWindows no repita el
    // toggle con datos que todavía no se han refrescado.
    function markKnownWindows(): void {
        const list = CompositorState.windows || [];
        const now = ({});
        for (let i = 0; i < list.length; i++) {
            const address = String(list[i].address || "");
            if (address.length > 0)
                now[address] = true;
        }
        root.knownWindows = now;
    }

    // Las ventanas nuevas de un escritorio flotante se sueltan solas. Solo se
    // hace una vez por dirección: si el usuario vuelve a mosaicar una ventana
    // a mano, no se le discute. En Umbriel el propio layout stacking abre las
    // ventanas flotantes, así que este camino solo existe para otros backends.
    function scanNewWindows(): void {
        if (CompositorState.supports("nativeWorkspaceModes"))
            return;
        if (!CompositorState.supports("autoFloatNewWindows"))
            return;
        if (!SettingsState.ready || !SettingsState.workspaceModeChosen
                || !root.backendReady || !CompositorState.windowDataReady
                || root.applying)
            return;
        const list = CompositorState.windows;
        const now = ({});
        for (let i = 0; i < list.length; i++) {
            const win = list[i];
            const address = String(win.address || "");
            if (address.length === 0)
                continue;
            const isNew = root.knownWindows[address] !== true;
            now[address] = true;
            if (!isNew)
                continue;
            if (win.minimized === true || win.fullscreen === true
                    || win.pinned === true)
                continue;
            const id = Number(win.workspaceId);
            if (!isFinite(id) || id <= 0)
                continue;
            if (root.modeFor(id) === "floating" && win.floating !== true)
                CompositorState.toggleFloating(address);
        }
        root.knownWindows = now;
    }

    // Umbriel aplica el layout al entrar en un escritorio. Hyprland ya tiene
    // el suyo en caliente y no necesita este seguimiento.
    //
    // No se aplica en cuanto llega el cambio: si el usuario encadena varios
    // escritorios, el layout se escribiría sobre el que esté activo en ese
    // instante. Se espera a que el destino se mantenga estable y entonces se
    // comprueba de nuevo que sigue siendo el mismo.
    function watchFocused(): void {
        if (!root.applied
                || !CompositorState.supports("nativeWorkspaceModes"))
            return;
        const id = root.focusedWorkspaceId;
        const mode = root.modeFor(id);
        if (id === root.lastFocusedWorkspace
                && mode === root.lastWorkspaceMode) {
            root.pendingWorkspace = 0;
            return;
        }
        root.pendingWorkspace = id;
        root.pendingMode = mode;
        settleTimer.restart();
    }

    onFocusedWorkspaceIdChanged: root.watchFocused()

    Timer {
        id: settleTimer

        interval: 320
        repeat: false
        onTriggered: {
            const id = root.focusedWorkspaceId;
            if (!root.applied || id <= 0 || id !== root.pendingWorkspace
                    || root.modeFor(id) !== root.pendingMode)
                return;
            root.pendingWorkspace = 0;
            root.lastFocusedWorkspace = id;
            root.lastWorkspaceMode = root.modeFor(id);
            root.applyWorkspace(id);
        }
    }

    // La primera pasada sí aplica el modo a las ventanas que ya existían.
    function initialize(): void {
        // Umbriel ya aplicó los modos al cargar su configuración. No hay nada
        // que sincronizar en caliente ni que vigilar cada medio segundo.
        if (CompositorState.supports("nativeWorkspaceModes"))
            return;
        if (root.applied || !SettingsState.ready
                || !root.backendReady
                || !CompositorState.windowDataReady
                || !SettingsState.workspaceModeChosen)
            return;
        root.applied = true;
        root.applyAll();
        root.markKnownWindows();
    }

    Connections {
        target: SettingsState

        function onWorkspaceModeChosenChanged(): void {
            if (SettingsState.workspaceModeChosen)
                Qt.callLater(() => root.initialize());
        }

        function onReadyChanged(): void {
            if (SettingsState.ready)
                Qt.callLater(() => root.initialize());
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: !CompositorState.supports("nativeWorkspaceModes")
        onTriggered: {
            if (!root.applied)
                root.initialize();
            else {
                root.scanNewWindows();
                root.watchFocused();
            }
        }
    }
}
