pragma Singleton

import Quickshell
import QtQuick

// Contrato común entre el shell y el compositor. La interfaz (barra, centro de
// control, overlay de ventanas) habla solo con este objeto; cada compositor
// aporta un backend intercambiable que traduce ventanas, escritorios,
// capacidades y acciones a este formato.
//
// Los backends exponen las mismas firmas. Si un compositor no puede hacer
// algo, lo declara en `capabilities` y la interfaz lo oculta o lo sustituye.
Singleton {
    id: root

    // ------------------------------------------------------------ detección
    readonly property string sessionDesktop:
        String(Quickshell.env("XDG_CURRENT_DESKTOP") || "")
    readonly property string desktop: root.sessionDesktop.toLowerCase()
    readonly property string hyprlandSignature:
        String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "")
    readonly property string umbrielSocket:
        String(Quickshell.env("UMBRIEL_SOCKET") || "")
    // Permite forzar un backend al probar: SHELL_COMPOSITOR=hyprland.
    readonly property string override:
        String(Quickshell.env("SHELL_COMPOSITOR") || "").toLowerCase()

    // El orden importa. Primero manda el escritorio que declara la sesión
    // actual; después los sockets. Así una sesión anidada (por ejemplo Umbriel
    // dentro de Hyprland) no se confunde con las variables heredadas del padre.
    readonly property string detected: {
        if (root.override.length > 0)
            return root.override;
        if (root.desktop.indexOf("umbriel") !== -1)
            return "umbriel";
        if (root.desktop.indexOf("hyprland") !== -1)
            return "hyprland";
        if (root.umbrielSocket.length > 0)
            return "umbriel";
        if (root.hyprlandSignature.length > 0)
            return "hyprland";
        if (root.desktop.indexOf("sway") !== -1)
            return "sway";
        if (root.desktop.indexOf("kde") !== -1
                || root.desktop.indexOf("plasma") !== -1)
            return "kwin";
        return "unknown";
    }

    // ------------------------------------------------------------- backend
    // Se crea en caliente para que añadir un compositor sea solo añadir un
    // archivo y una línea en backendFile().
    property var backend: null
    property string lastError: ""
    // El diagnóstico pide una lectura periódica; el resto del shell usa las
    // señales nativas de Quickshell.
    property bool watching: false

    readonly property string id: root.backend
        ? String(root.backend.id || "unknown") : root.detected
    readonly property string name: root.backend
        ? String(root.backend.name || root.labelFor(root.detected))
        : root.labelFor(root.detected)
    readonly property bool available: root.backend
        ? root.backend.available === true : false
    // Un backend de solo lectura puede describir pero no ejecutar acciones.
    readonly property bool readOnly: root.backend
        ? root.backend.readOnly !== false : true
    readonly property string lastAction: root.backend
        ? String(root.backend.lastAction || "") : ""
    readonly property bool lastActionOk: root.backend
        ? root.backend.lastActionOk === true : false
    // Verdadero cuando el backend ya leyó la geometría y el estado real de las
    // ventanas. Los modos por escritorio esperan a esto para no confundir una
    // ventana flotante con una mosaicada durante el arranque.
    readonly property bool windowDataReady: root.backend
        ? root.backend.windowDataReady === true : false

    readonly property var capabilities: root.backend
        ? root.backend.capabilities : ({})
    readonly property var windows: root.backend ? root.backend.windows : []
    readonly property var workspaces: root.backend
        ? root.backend.workspaces : []
    readonly property var focusedWindow: root.backend
        ? root.backend.focusedWindow : null
    readonly property var focusedWorkspace: root.backend
        ? root.backend.focusedWorkspace : null

    // El botón «Mover» de la barra de título nativa abrió su selector. El
    // serial cambia en cada petición, aunque se pulse dos veces en el mismo
    // sitio; ventana y coordenadas son globales.
    readonly property int moveMenuSerial: root.backend
        ? Number(root.backend.moveMenuSerial) || 0 : 0
    readonly property string moveMenuWindow: root.backend
        ? String(root.backend.moveMenuWindow || "") : ""
    readonly property real moveMenuX: root.backend
        ? Number(root.backend.moveMenuX) || 0 : 0
    readonly property real moveMenuY: root.backend
        ? Number(root.backend.moveMenuY) || 0 : 0

    // Vista general del compositor abierta. En Umbriel llega por el evento
    // `overview`; el shell la usa para retirar sus paneles.
    readonly property bool overviewOpen: root.backend
        ? root.backend.overviewOpen === true : false

    readonly property int windowCount: root.windows ? root.windows.length : 0
    readonly property int workspaceCount:
        root.workspaces ? root.workspaces.length : 0
    readonly property string focusedTitle: root.focusedWindow
        ? String(root.focusedWindow.title || "") : ""
    readonly property string focusedApp: root.focusedWindow
        ? String(root.focusedWindow.appId || root.focusedWindow.class || "") : ""

    // Orden estable de las fichas de la barra. El backend devuelve las ventanas
    // en orden de apilado, que cambia al enfocar; aquí se conserva el orden en
    // que apareció cada ventana. Se mutan solo las claves del objeto (nunca se
    // reasigna la propiedad) para no invalidar el binding que lo lee.
    property var windowOrder: ({ "__next": 1 })

    // Ventanas que pertenecen a un escritorio, incluidas las minimizadas que
    // el backend sabe devolver a su escritorio de origen. La barra usa esto
    // para conservar el icono aunque la ventana esté en special:minimized.
    function windowsForWorkspace(workspaceId): var {
        const id = Number(workspaceId);
        const list = root.windows || [];
        const order = root.windowOrder;
        const present = {};
        const ordered = [];
        // Asignar el orden sobre la lista completa: todas las píldoras ven el
        // mismo orden global aunque cada una filtre su escritorio.
        for (let i = 0; i < list.length; i++) {
            const win = list[i];
            const key = String(win.address || win.id || "");
            if (key.length === 0)
                continue;
            present[key] = true;
            if (order[key] === undefined)
                order[key] = order.__next++;
            ordered.push({ win: win, seq: order[key] });
        }
        // Olvidar ventanas cerradas para que el mapa no crezca sin límite.
        for (const key in order) {
            if (key !== "__next" && present[key] !== true)
                delete order[key];
        }
        ordered.sort(function (a, b) { return a.seq - b.seq; });

        const out = [];
        for (let i = 0; i < ordered.length; i++) {
            const win = ordered[i].win;
            if (Number(win.workspaceId) === id
                    || (win.minimized === true
                        && Number(win.originWorkspaceId) === id))
                out.push(win);
        }
        return out;
    }

    function labelFor(value): string {
        if (value === "hyprland")
            return "Hyprland";
        if (value === "umbriel")
            return "Umbriel";
        if (value === "sway")
            return "Sway";
        if (value === "kwin")
            return "KWin";
        return "Desconocido";
    }

    function backendFile(): string {
        if (root.detected === "hyprland")
            return "HyprlandBackend.qml";
        if (root.detected === "umbriel")
            return "UmbrielBackend.qml";
        // Los siguientes backends se añaden aquí cuando estén listos:
        return "";
    }

    function loadBackend(): void {
        const file = root.backendFile();
        if (file.length === 0)
            return;

        const component = Qt.createComponent(file);
        if (!component) {
            root.lastError = "No se pudo crear " + file;
            return;
        }

        if (component.status === Component.Ready) {
            root.backend = component.createObject(root);
            if (!root.backend)
                root.lastError = "No se pudo instanciar " + file;
            return;
        }

        if (component.status === Component.Loading) {
            component.statusChanged.connect(function() {
                if (component.status === Component.Ready) {
                    root.backend = component.createObject(root);
                    if (!root.backend)
                        root.lastError = "No se pudo instanciar " + file;
                } else if (component.status === Component.Error) {
                    root.lastError = component.errorString();
                }
            });
            return;
        }

        root.lastError = component.errorString();
    }

    // Fuerza una relectura. En Hyprland además refresca las listas internas de
    // Quickshell; en otros backends puede ser solo un cambio de revisión.
    function refresh(): void {
        if (root.backend && typeof root.backend.refresh === "function")
            root.backend.refresh();
    }

    function supports(capability): bool {
        return root.capabilities
            ? root.capabilities[capability] === true : false;
    }

    // ------------------------------------------------------------- acciones
    // Firmas estables para toda la interfaz. El backend decide cómo se hacen.
    function focusWindow(windowId): bool {
        return root.callBackend("focusWindow", windowId);
    }

    function closeWindow(windowId): bool {
        return root.callBackend("closeWindow", windowId);
    }

    function toggleFloating(windowId): bool {
        return root.callBackend("toggleFloating", windowId);
    }

    function toggleFullscreen(windowId): bool {
        return root.callBackend("toggleFullscreen", windowId);
    }

    function toggleMaximized(windowId): bool {
        return root.callBackend("toggleMaximized", windowId);
    }

    function togglePinned(windowId): bool {
        return root.callBackend("togglePinned", windowId);
    }

    function minimizeWindow(windowId): bool {
        return root.callBackend("minimizeWindow", windowId);
    }

    function restoreWindow(windowId): bool {
        return root.callBackend("restoreWindow", windowId);
    }

    function moveToWorkspace(windowId, workspaceId): bool {
        return root.callBackend("moveToWorkspace", windowId, workspaceId);
    }

    // Mueve una ventana flotante a coordenadas globales. Lo usa la barra de
    // título del shell para arrastrar sin depender de un plugin del compositor.
    function moveWindowTo(windowId, x, y): bool {
        return root.callBackend("moveWindowTo", windowId, x, y);
    }

    function focusWorkspace(workspaceId): bool {
        return root.callBackend("focusWorkspace", workspaceId);
    }

    function setWorkspaceLayout(workspaceId, layout): bool {
        return root.callBackend("setWorkspaceLayout", workspaceId, layout);
    }

    // Aplica el modo del shell al escritorio. Hyprland lo resuelve flotando o
    // mosaicando sus ventanas; Umbriel cambia el layout nativo del escritorio.
    function setWorkspaceMode(workspaceId, mode): bool {
        return root.callBackend("setWorkspaceMode", workspaceId, mode);
    }

    // Cambia el layout del teclado físico sin reiniciar la sesión.
    function setKeyboardLayout(layout): bool {
        return root.callBackend("setKeyboardLayout", layout);
    }

    // Aplica modo claro/oscuro y acento a la decoración nativa.
    function setShellTheme(mode, accent): bool {
        return root.callBackend("setShellTheme", mode, accent);
    }

    // Termina la sesión del compositor. El backend elige el mecanismo: en
    // Hyprland es `exit` y en Umbriel `session-quit`.
    function sessionQuit(): bool {
        return root.callBackend("sessionQuit");
    }

    // Bloquea la pantalla. shell-lock es el único punto de entrada, también
    // para el menú de energía y el bloqueo automático.
    function lockScreen(): bool {
        const repo = Quickshell.shellDir || "";
        Quickshell.execDetached(["sh", "-c",
            'lock="$HOME/.local/bin/shell-lock"; '
            + '[ -x "$lock" ] || lock="' + repo + '/install/bin/shell-lock"; '
            + 'exec "$lock"']);
        return true;
    }

    // Punto de entrada para IPC y menús: recibe el nombre de la acción como
    // texto y la ejecuta. Así los scripts no dependen de la implementación.
    function runAction(action, windowId, value): bool {
        const name = String(action || "").toLowerCase();
        if (name === "focus")
            return root.focusWindow(windowId);
        if (name === "close")
            return root.closeWindow(windowId);
        if (name === "float" || name === "floating")
            return root.toggleFloating(windowId);
        if (name === "fullscreen")
            return root.toggleFullscreen(windowId);
        if (name === "maximize" || name === "maximized")
            return root.toggleMaximized(windowId);
        if (name === "pin" || name === "pinned")
            return root.togglePinned(windowId);
        if (name === "minimize")
            return root.minimizeWindow(windowId);
        if (name === "restore")
            return root.restoreWindow(windowId);
        if (name === "move")
            return root.moveToWorkspace(windowId, value);
        if (name === "workspace")
            return root.focusWorkspace(windowId);
        if (name === "layout")
            return root.setWorkspaceLayout(windowId, value);
        return false;
    }

    function callBackend(method, arg1, arg2, arg3): bool {
        if (!root.backend)
            return false;
        const fn = root.backend[method];
        if (typeof fn !== "function")
            return false;
        return fn.call(root.backend, arg1, arg2, arg3) === true;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.watching
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.loadBackend()
}
