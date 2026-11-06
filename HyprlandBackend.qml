import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Backend de Hyprland para CompositorState. Describe ventanas, escritorios,
// foco y capacidades con el formato común de ALBA, y ejecuta las acciones
// usando los dispatchers de Hyprland.
Item {
    id: root

    readonly property string id: "hyprland"
    readonly property string name: "Hyprland"
    readonly property bool readOnly: false

    // Diagnóstico de la última acción: qué se pidió y si se pudo enviar.
    property string lastAction: ""
    property bool lastActionOk: false
    // Escritorio original de cada ventana minimizada, para poder restaurarla.
    property var minimizedWorkspaces: ({})

    // La sesión está conectada al socket de eventos de Hyprland.
    readonly property bool available:
        String(Hyprland.eventSocketPath || "").length > 0

    // Se incrementa al pedir una relectura y obliga a recalcular las listas.
    property int revision: 0
    // «lastIpcObject» de Quickshell no siempre trae floating, pinned ni la
    // geometría final. Se completa con una lectura periódica de hyprctl.
    property var clientData: ({})
    property int clientRevision: 0
    property bool windowDataReady: false

    readonly property var capabilities: ({
        nativeTitlebar: false,     // necesita hyprbars u otro plugin
        shellTitlebar: true,       // barra de título de ALBA sobre flotantes
        moveWindowTo: true,        // movewindowpixel exact
        superHold: true,           // bind + bindr
        nativeMinimize: false,     // se simula con special:minimized
        nativeWorkspaceModes: false,
        autoFloatNewWindows: true,
        snapZones: false,          // no hay mitades/cuartos nativos
        windowSnap: true,          // general:snap:enabled
        perWorkspaceLayout: true,  // reglas de workspace en 0.55
        windowGeometry: true,
        blur: true,
        moveToWorkspace: true,
        floatingToggle: true,
        pin: true,
        fullscreen: true,
        maximize: true,
        minimize: true,            // simulado con special:minimized
        screenShader: true,        // decoration:screen_shader
        displayFilter: false,
        hyprlandFocusGrab: true,
        focus: true,
        close: true,
        focusWorkspace: true,
        setLayout: true,
        setWorkspaceMode: true
    })

    // Dirección de Hyprland con el prefijo 0x que esperan sus dispatchers.
    function cleanAddress(value): string {
        const address = String(value || "");
        if (address.length === 0)
            return "";
        return address.startsWith("0x") ? address : "0x" + address;
    }

    function numberOr(value, fallback): real {
        const parsed = Number(value);
        return isFinite(parsed) ? parsed : fallback;
    }

    // -------------------------------------------------------------- ventanas
    readonly property var windows: {
        root.revision;
        root.clientRevision;
        const list = Hyprland.toplevels.values;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const top = list[i];
            const wayland = top.wayland || null;
            const ipc = top.lastIpcObject || ({});
            const address = root.cleanAddress(top.address
                || (ipc.address || ""));
            const client = root.clientData[address] || null;
            const data = client || ipc;
            const cws = client && client.workspace ? client.workspace : null;
            const ws = top.workspace || null;
            const at = data.at || [0, 0];
            const size = data.size || [0, 0];
            const fullscreenRaw = client ? Number(client.fullscreen) || 0
                : Number(ipc.fullscreen) || 0;

            let appId = wayland && wayland.appId ? wayland.appId : "";
            if (appId.length === 0)
                appId = data.class || data.initialClass || "";
            // Las superficies de Quickshell no son apps del escritorio.
            if (String(appId).toLowerCase().indexOf("quickshell") !== -1)
                continue;

            const title = wayland && wayland.title
                ? wayland.title : (data.title || top.title || "");
            const workspaceName = cws ? String(cws.name || "")
                : (ws ? String(ws.name || "")
                    : String(ipc.workspace ? ipc.workspace.name || "" : ""));
            const minimized = (wayland && wayland.minimized === true)
                || workspaceName === "special:minimized";
            // Hyprland manda las minimizadas a special:minimized. La píldora
            // las devuelve a su escritorio original para no perder su icono.
            const origin = root.minimizedWorkspaces[address] || null;
            const workspaceId = cws ? Number(cws.id) || 0
                : (ws ? Number(ws.id) || 0
                    : (ipc.workspace ? Number(ipc.workspace.id) || 0 : 0));

            out.push({
                id: address,
                address: address,
                title: String(title),
                appId: String(appId),
                class: String(data.class || data.initialClass || ""),
                workspaceId: workspaceId,
                workspaceName: workspaceName,
                monitor: top.monitor ? String(top.monitor.name || "")
                    : String(data.monitor || ""),
                focused: top.activated === true,
                urgent: top.urgent === true,
                visible: client ? (client.visible === true
                    && client.mapped !== false) : true,
                floating: client ? client.floating === true
                    : ipc.floating === true,
                minimized: minimized,
                originWorkspaceId: minimized && origin
                    ? Number(origin.id) || 0 : 0,
                originWorkspaceName: minimized && origin
                    ? String(origin.name || "") : "",
                // Hyprland usa fullscreen 1 para maximizar y 2 para pantalla
                // completa real. La barra de título solo debe desaparecer en
                // la segunda.
                maximized: client ? fullscreenRaw === 1
                    : (wayland ? wayland.maximized === true
                        : fullscreenRaw === 1),
                fullscreen: client ? fullscreenRaw >= 2
                    : (wayland ? wayland.fullscreen === true
                        : fullscreenRaw >= 2),
                pinned: client ? client.pinned === true : ipc.pinned === true,
                x: root.numberOr(at[0], 0),
                y: root.numberOr(at[1], 0),
                width: root.numberOr(size[0], 0),
                height: root.numberOr(size[1], 0),
                pid: root.numberOr(data.pid, 0),
                xwayland: data.xwayland === true
            });
        }
        return out;
    }

    // ----------------------------------------------------------- escritorios
    readonly property var workspaces: {
        root.revision;
        const list = Hyprland.workspaces.values;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            const data = ws.lastIpcObject || ({});
            out.push({
                id: ws.id,
                name: String(ws.name || ""),
                monitor: ws.monitor ? String(ws.monitor.name || "")
                    : String(data.monitor || ""),
                focused: ws.focused === true,
                active: ws.active === true,
                urgent: ws.urgent === true,
                hasFullscreen: ws.hasFullscreen === true,
                layout: String(data.tiledLayout || "dwindle"),
                windowCount: root.numberOr(data.windows, 0)
            });
        }
        return out;
    }

    readonly property var focusedWindow: {
        const list = root.windows;
        for (let i = 0; i < list.length; i++) {
            if (list[i].focused)
                return list[i];
        }
        return null;
    }

    readonly property var focusedWorkspace: {
        const list = root.workspaces;
        for (let i = 0; i < list.length; i++) {
            if (list[i].focused)
                return list[i];
        }
        return null;
    }

    // ---------------------------------------------------------------- acciones
    function windowById(windowId): var {
        const wanted = root.cleanAddress(windowId);
        if (wanted.length === 0)
            return null;
        const list = root.windows;
        for (let i = 0; i < list.length; i++) {
            if (list[i].address === wanted)
                return list[i];
        }
        return null;
    }

    function noteAction(action, ok): bool {
        root.lastAction = String(action);
        root.lastActionOk = ok === true;
        return root.lastActionOk;
    }

    // Envía una orden a Hyprland. El socket no devuelve resultado síncrono,
    // así que damos por buena la orden si el compositor está conectado.
    function dispatch(request): bool {
        if (!root.available)
            return false;
        Hyprland.dispatch(String(request));
        return true;
    }

    function focusWindow(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("focusWindow", false);

        // Una ventana minimizada debe volver antes de poder enfocarse.
        if (win.minimized)
            root.restoreWindow(windowId);

        const ok = root.dispatch("focuswindow address:" + win.address);
        return root.noteAction("focusWindow", ok);
    }

    function closeWindow(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("closeWindow", false);
        const ok = root.dispatch("killwindow address:" + win.address);
        return root.noteAction("closeWindow", ok);
    }

    function toggleFloating(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("toggleFloating", false);
        const ok = root.dispatch("togglefloating address:" + win.address);
        return root.noteAction("toggleFloating", ok);
    }

    // Hyprland no acepta una ventana en el dispatcher de pantalla completa:
    // hay que enfocarla primero. Para una acción de ventana eso es correcto.
    function toggleFullscreen(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("toggleFullscreen", false);
        if (!win.focused)
            root.dispatch("focuswindow address:" + win.address);
        // fullscreen 0 alterna pantalla completa real; 1 alterna maximizado.
        const ok = root.dispatch("fullscreen 0");
        return root.noteAction("toggleFullscreen", ok);
    }

    function toggleMaximized(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("toggleMaximized", false);
        if (!win.focused)
            root.dispatch("focuswindow address:" + win.address);
        const ok = root.dispatch("fullscreen 1");
        return root.noteAction("toggleMaximized", ok);
    }

    function togglePinned(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("togglePinned", false);
        const ok = root.dispatch("pin address:" + win.address);
        return root.noteAction("togglePinned", ok);
    }

    // Hyprland no trae minimizar nativo. Se mueve la ventana a un escritorio
    // especial oculto y se recuerda de dónde vino para restaurarla.
    function minimizeWindow(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("minimizeWindow", false);
        if (win.minimized)
            return root.noteAction("minimizeWindow", true);

        const origin = {
            id: win.workspaceId,
            name: win.workspaceName
        };
        root.minimizedWorkspaces[win.address] = origin;

        const ok = root.dispatch(
            "movetoworkspacesilent special:minimized,address:" + win.address);
        // La píldora necesita recalcular con el escritorio de origen recién
        // guardado, antes de que llegue el evento de Hyprland.
        root.revision++;
        return root.noteAction("minimizeWindow", ok);
    }

    function restoreWindow(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("restoreWindow", false);
        if (!win.minimized)
            return root.noteAction("restoreWindow", true);

        const origin = root.minimizedWorkspaces[win.address] || null;
        let target = origin ? String(origin.name || origin.id || "") : "";
        if (target.length === 0 || target === "special:minimized")
            target = root.focusedWorkspace
                ? String(root.focusedWorkspace.name
                    || root.focusedWorkspace.id) : "1";

        const moved = root.dispatch(
            "movetoworkspacesilent " + target + ",address:" + win.address);
        if (moved)
            root.dispatch("focuswindow address:" + win.address);
        delete root.minimizedWorkspaces[win.address];
        root.revision++;
        return root.noteAction("restoreWindow", moved);
    }

    function moveToWorkspace(windowId, workspaceId): bool {
        const win = root.windowById(windowId);
        const target = String(workspaceId === undefined || workspaceId === null
            ? "" : workspaceId).trim();
        if (!win || target.length === 0 || target === "special:minimized")
            return root.noteAction("moveToWorkspace", false);

        const ok = root.dispatch(
            "movetoworkspacesilent " + target + ",address:" + win.address);
        if (ok && win.minimized) {
            delete root.minimizedWorkspaces[win.address];
            root.revision++;
        }
        return root.noteAction("moveToWorkspace", ok);
    }

    // Arrastre de la barra de título de ALBA. Hyprland acepta coordenadas
    // absolutas con «movewindowpixel exact».
    function moveWindowTo(windowId, x, y): bool {
        const win = root.windowById(windowId);
        if (!win || win.floating !== true)
            return root.noteAction("moveWindowTo", false);
        const px = Math.round(Number(x));
        const py = Math.round(Number(y));
        if (!isFinite(px) || !isFinite(py))
            return root.noteAction("moveWindowTo", false);
        const ok = root.dispatch("movewindowpixel exact " + px + " " + py
            + ",address:" + win.address);
        return root.noteAction("moveWindowTo", ok);
    }

    function focusWorkspace(workspaceId): bool {
        const target = String(workspaceId === undefined || workspaceId === null
            ? "" : workspaceId).trim();
        if (target.length === 0)
            return root.noteAction("focusWorkspace", false);
        const ok = root.dispatch("workspace " + target);
        return root.noteAction("focusWorkspace", ok);
    }

    function setWorkspaceLayout(workspaceId, layout): bool {
        const id = Number(workspaceId);
        const name = String(layout === undefined || layout === null
            ? "" : layout).trim().toLowerCase();
        if (!root.available || !isFinite(id) || id <= 0
                || !/^[a-z0-9_-]+$/.test(name))
            return root.noteAction("setWorkspaceLayout", false);

        // Hyprland.dispatch() antepone "dispatch ", y una regla de workspace
        // no es un dispatcher: hay que usar la petición "keyword" de hyprctl.
        Quickshell.execDetached(["hyprctl", "keyword", "workspace",
            id + ",layout:" + name]);
        return root.noteAction("setWorkspaceLayout", true);
    }

    // Modo de ALBA: flotante suelta las ventanas del escritorio; mosaico las
    // vuelve a repartir. Las minimizadas, fijadas y a pantalla completa no se
    // tocan.
    function setWorkspaceMode(workspaceId, mode): bool {
        const id = Number(workspaceId);
        const value = String(mode === undefined || mode === null ? "" : mode);
        if (!root.available || !isFinite(id) || id <= 0)
            return root.noteAction("setWorkspaceMode", false);
        const wantFloating = value !== "mosaic";
        const list = root.windows || [];
        for (let i = 0; i < list.length; i++) {
            const win = list[i];
            if (Number(win.workspaceId) !== id)
                continue;
            if (win.minimized === true || win.fullscreen === true
                    || win.pinned === true)
                continue;
            if (wantFloating && win.floating !== true)
                root.toggleFloating(win.address);
            else if (!wantFloating && win.floating === true)
                root.toggleFloating(win.address);
        }
        root.revision++;
        return root.noteAction("setWorkspaceMode", true);
    }

    // Hyprland aplica el layout a los teclados conectados sin reiniciar.
    function setKeyboardLayout(layout): bool {
        const clean = String(layout === undefined || layout === null
            ? "" : layout).trim().toLowerCase();
        if (!root.available || !/^[a-z0-9_]+$/.test(clean))
            return root.noteAction("setKeyboardLayout", false);
        Quickshell.execDetached(["hyprctl", "keyword", "input:kb_layout",
            clean]);
        return root.noteAction("setKeyboardLayout", true);
    }

    // Hyprland no dibuja la barra nativa: no hay colores que sincronizar.
    function setShellTheme(mode, accent): bool {
        return root.noteAction("setShellTheme", true);
    }

    function sessionQuit(): bool {
        return root.noteAction("sessionQuit", root.dispatch("exit"));
    }

    function lockScreen(): bool {
        if (!root.available)
            return root.noteAction("lockScreen", false);
        Quickshell.execDetached(["hyprlock"]);
        return root.noteAction("lockScreen", true);
    }

    // ------------------------------------------------------------- relectura
    function refresh(): void {
        root.revision++;
        if (!root.available)
            return;
        // Vuelve a pedir el estado a Hyprland. Es seguro tras una acción y
        // mantiene el diagnóstico al día aunque se pierda algún evento.
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        if (!clientsProc.running)
            clientsProc.running = true;
    }

    // hyprctl clients completa los campos que el evento de Quickshell no
    // actualiza (floating, pinned, geometría y fullscreen).
    Process {
        id: clientsProc

        command: ["hyprctl", "-j", "clients"]

        stdout: StdioCollector {
            id: clientsOut
        }

        onExited: {
            try {
                const list = JSON.parse(clientsOut.text || "[]");
                const map = ({});
                for (let i = 0; i < list.length; i++) {
                    const client = list[i];
                    const address = root.cleanAddress(
                        client.address || "");
                    if (address.length > 0)
                        map[address] = client;
                }
                root.clientData = map;
                root.clientRevision++;
                root.windowDataReady = true;
            } catch (error) {
                // Si hyprctl devuelve una respuesta incompleta se conserva la
                // última lectura buena.
            }
        }
    }

    Timer {
        interval: 700
        repeat: true
        running: true
        onTriggered: {
            if (!clientsProc.running)
                clientsProc.running = true;
        }
    }
}
