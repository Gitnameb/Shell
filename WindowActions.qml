pragma Singleton

import Quickshell
import QtQuick

// Acciones de ventana compartidas por la barra de título y el menú del clic
// derecho. Una sola lista evita que ambos sitios se desincronicen: mismo
// orden, mismas etiquetas, mismos iconos y mismos atajos.
//
// El orden y los iconos imitan los botones de la barra de título nativa de
// Umbriel. Fijar y volumen conservan los iconos del menú del clic derecho,
// que es lo que pidió el usuario.
Singleton {
    id: root

    // Escritorio al que pertenece la ventana. En las minimizadas el backend
    // deja workspaceId en 0 y conserva el original en originWorkspaceId.
    function workspaceIdFor(win): int {
        if (!win)
            return 0;
        const direct = Number(win.workspace || win.workspaceId);
        if (isFinite(direct) && direct > 0)
            return direct;
        const origin = Number(win.originWorkspaceId);
        return isFinite(origin) ? origin : 0;
    }

    // Umbriel rechaza `window-toggle-floating` en un escritorio que ya está en
    // modo flotante. En ese caso la opción no se muestra: no haría nada.
    function floatingToggleUseful(win): bool {
        if (!win)
            return false;
        if (CompositorState.supports("nativeWorkspaceModes")) {
            return SettingsState.workspaceMode(root.workspaceIdFor(win))
                !== "floating";
        }
        return true;
    }

    function itemsFor(win): var {
        if (!win)
            return [];

        const out = [];
        const fullscreen = win.fullscreen === true;

        if (CompositorState.supports("floatingToggle")
                && !fullscreen && root.floatingToggleUseful(win)) {
            const floating = win.floating === true;
            out.push({
                key: "float",
                label: floating ? "Volver al mosaico" : "Hacer flotante",
                icon: "",
                source: ShellIcons.src("window-float"),
                glyph: "❐",
                shortcut: "Super+T",
                active: floating,
                danger: false
            });
        }

        if (CompositorState.supports("pin")) {
            const pinned = win.pinned === true;
            out.push({
                key: "pin",
                label: pinned ? "Dejar de fijar" : "Fijar siempre encima",
                icon: pinned ? "window-unpin" : "window-pin",
                glyph: "◆",
                shortcut: "Super+P",
                active: pinned,
                danger: false
            });
        }

        if (CompositorState.supports("fullscreen")) {
            out.push({
                key: "fullscreen",
                label: fullscreen
                    ? "Salir de pantalla completa" : "Pantalla completa",
                icon: "",
                source: ShellIcons.src("window-fullscreen"),
                glyph: "⛶",
                shortcut: "Super+F",
                active: fullscreen,
                danger: false
            });
        }

        if (CompositorState.supports("moveToWorkspace")) {
            out.push({
                key: "move",
                label: "Mover a escritorio",
                icon: "",
                source: ShellIcons.src("window-move"),
                glyph: "#",
                shortcut: "Super+Shift+1…9",
                active: false,
                danger: false
            });
        }

        if (CompositorState.supports("minimize")) {
            const minimized = win.minimized === true;
            out.push({
                key: "minimize",
                label: minimized ? "Restaurar ventana" : "Minimizar",
                icon: "",
                source: ShellIcons.src("window-minimize"),
                glyph: "—",
                shortcut: "Super+Shift+H",
                active: minimized,
                danger: false
            });
        }

        if (CompositorState.supports("maximize") && !fullscreen) {
            const maximized = win.maximized === true;
            out.push({
                key: "maximize",
                label: maximized ? "Restaurar tamaño" : "Maximizar",
                icon: "",
                source: ShellIcons.src("window-maximize"),
                glyph: "▣",
                shortcut: "Super+M",
                active: maximized,
                danger: false
            });
        }

        if (CompositorState.supports("close")) {
            out.push({
                key: "close",
                label: "Cerrar ventana",
                icon: "",
                source: ShellIcons.src("window-close"),
                glyph: "×",
                shortcut: "Super+Q",
                active: false,
                danger: true
            });
        }

        return out;
    }

    // Ejecuta una acción de la lista. «move» la resuelve cada interfaz porque
    // la barra de título y el menú tienen selectores distintos.
    function run(key, win): bool {
        if (!win)
            return false;
        const address = String(win.address || win.id || "");
        if (address.length === 0)
            return false;
        if (key === "float")
            return CompositorState.toggleFloating(address);
        if (key === "pin")
            return CompositorState.togglePinned(address);
        if (key === "minimize") {
            return win.minimized === true
                ? CompositorState.restoreWindow(address)
                : CompositorState.minimizeWindow(address);
        }
        if (key === "maximize")
            return CompositorState.toggleMaximized(address);
        if (key === "fullscreen")
            return CompositorState.toggleFullscreen(address);
        if (key === "close")
            return CompositorState.closeWindow(address);
        return false;
    }
}
