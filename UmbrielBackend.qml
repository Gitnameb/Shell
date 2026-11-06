import Quickshell
import Quickshell.Io
import QtQuick

// Backend de Umbriel para CompositorState.
//
// Umbriel no expone enlaces de Quickshell como Hyprland, así que se consulta
// su IPC documentado (`umbriel windows --json` y `umbriel workspaces --json`)
// y se ejecutan acciones con `umbriel msg`. El contrato que ve ALBA es el
// mismo que en Hyprland.
Scope {
    id: root

    readonly property string id: "umbriel"
    readonly property string name: "Umbriel"
    readonly property bool readOnly: false

    property string lastAction: ""
    property bool lastActionOk: false
    property var minimizedWorkspaces: ({})
    // Último escritorio real visto para cada ventana. Cuando Umbriel minimiza
    // una ventana mosaicada la pasa al scratchpad y su `workspace` queda vacío;
    // sin esta memoria la ficha desaparecía de la barra en vez de atenuarse.
    property var knownWorkspaces: ({})
    property int revision: 0

    // El socket lo publica Umbriel; sin él no hay forma de hablar con la
    // sesión, aunque el escritorio se detecte por XDG_CURRENT_DESKTOP.
    readonly property bool available:
        String(Quickshell.env("UMBRIEL_SOCKET") || "").length > 0

    property var windowsJson: []
    property var workspacesJson: []
    property int dataRevision: 0
    property bool windowDataReady: false

    // Estado real de la tecla Mod (Super). Umbriel lo publica por su IPC
    // mientras se mantiene pulsada, así que ALBA puede mostrar los controles
    // durante el gesto en lugar de esperar al bind que llega al soltar.
    property bool modHeld: false
    // Si el gesto actual sigue siendo un toque limpio. Se conserva entre
    // eventos para que un atajo no abra el lanzador al soltar Mod.
    property bool modTapAllowed: true
    // Intentos fallidos del flujo de Mod. Sirve para reintentar si ALBA
    // arranca antes que el socket del compositor, sin repetir para siempre.
    property int modFailures: 0

    // Selector de escritorio que pide el botón «Mover» de la barra de título
    // nativa. Cada petición lleva un serial para que dos aperturas seguidas en
    // la misma posición sigan siendo eventos distintos.
    property int moveMenuSerial: 0
    property string moveMenuWindow: ""
    property real moveMenuX: 0
    property real moveMenuY: 0

    // Vista general de Umbriel. ALBA la usa para cerrar sus paneles cuando
    // aparece, de modo que no queden flotando encima de las miniaturas.
    property bool overviewOpen: false

    readonly property var capabilities: ({
        nativeTitlebar: true,      // barra de título del propio Umbriel
        shellTitlebar: false,      // ALBA no debe dibujar otra encima
        moveWindowTo: true,
        superHold: true,           // Umbriel emite el estado de Mod al instante
        nativeMinimize: false,     // Umbriel solo minimiza ventanas flotantes
        minimize: true,            // en mosaico se emula con scratchpad
        nativeWorkspaceModes: true,
        autoFloatNewWindows: false, // el layout del escritorio ya decide
        snapZones: false,
        windowSnap: false,
        perWorkspaceLayout: true,
        windowGeometry: true,
        blur: true,
        moveToWorkspace: true,
        floatingToggle: true,
        pin: true,
        fullscreen: true,
        maximize: true,
        screenShader: false,       // no hay shader global de Hyprland
        displayFilter: true,       // filtro nativo de brillo/luz nocturna
        hyprlandFocusGrab: false,  // el menú usa un captador de clics
        focus: true,
        close: true,
        focusWorkspace: true,
        setLayout: true,
        setWorkspaceMode: true
    })

    function numberOr(value, fallback): real {
        const parsed = Number(value);
        return isFinite(parsed) ? parsed : fallback;
    }

    // Umbriel identifica los escritorios con cadenas internas («WL-1:3») que
    // no coinciden con el nombre visible: el número del id es un contador y el
    // nombre («2») puede ser distinto. ALBA usa el índice 1..N, así que hay que
    // resolverlo con el campo `index` y guardar la última tabla conocida por si
    // las ventanas llegan en una lectura anterior a la de escritorios.
    property var workspaceCache: ({})

    function rebuildWorkspaceCache(): void {
        const list = root.workspacesJson || [];
        const cache = ({});
        for (let i = 0; i < list.length; i++) {
            const id = String(list[i].id || "");
            if (id.length === 0)
                continue;
            cache[id] = {
                index: Number(list[i].index) || 0,
                name: String(list[i].name || list[i].id || "")
            };
        }
        root.workspaceCache = cache;
    }

    function workspaceIndex(workspaceId): int {
        const id = String(workspaceId === undefined || workspaceId === null
            ? "" : workspaceId);
        const list = root.workspacesJson || [];
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].id) === id)
                return Number(list[i].index) || 0;
        }
        const cached = root.workspaceCache[id];
        return cached ? Number(cached.index) || 0 : 0;
    }

    function workspaceName(workspaceId): string {
        const id = String(workspaceId === undefined || workspaceId === null
            ? "" : workspaceId);
        const list = root.workspacesJson || [];
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].id) === id)
                return String(list[i].name || list[i].id || "");
        }
        const cached = root.workspaceCache[id];
        return cached ? String(cached.name || "") : "";
    }

    // Resuelve el nombre visible de un escritorio («1», «2», o uno con nombre)
    // a su índice 1..N. Se usa como respaldo cuando un binario antiguo de
    // Umbriel publica `scratchpad_return_index` en base 0: el nombre siempre
    // es correcto y evita que la ficha caiga en el escritorio de al lado.
    function workspaceIndexByName(name): int {
        const wanted = String(name === undefined || name === null ? "" : name);
        if (wanted.length === 0)
            return 0;
        const list = root.workspacesJson || [];
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].name) === wanted)
                return Number(list[i].index) || 0;
        }
        for (const id in root.workspaceCache) {
            if (String(root.workspaceCache[id].name) === wanted)
                return Number(root.workspaceCache[id].index) || 0;
        }
        return 0;
    }

    // -------------------------------------------------------------- ventanas
    readonly property var windows: {
        root.revision;
        root.dataRevision;
        const list = root.windowsJson || [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const win = list[i];
            const address = String(win.id || "");
            if (address.length === 0)
                continue;
            const appId = String(win.app_id || "");
            if (appId.toLowerCase().indexOf("quickshell") !== -1)
                continue;
            const scratchpad = String(win.scratchpad || "");
            // Umbriel oculta al scratchpad las ventanas que no caben en su
            // minimizar nativo (las mosaicadas). Para ALBA toda ventana del
            // scratchpad está minimizada, aunque el compositor la muestre
            // temporalmente: así la ficha sigue en la barra y se puede
            // restaurar con `restore-window`.
            const minimized = win.minimized === true || scratchpad.length > 0;
            const wsIndex = root.workspaceIndex(win.workspace);
            const wsName = root.workspaceName(win.workspace);
            // Recordar el último escritorio real. Las ventanas del scratchpad
            // no tienen escritorio, y una minimizada nativa lo conserva.
            if (!minimized && wsIndex > 0) {
                root.knownWorkspaces[address] = { id: wsIndex, name: wsName };
            }
            const remembered = root.minimizedWorkspaces[address]
                || root.knownWorkspaces[address] || null;
            // Umbriel publica el escritorio al que volverá una ventana del
            // scratchpad. Es la fuente exacta y sobrevive a reiniciar ALBA.
            const returnIndex = root.numberOr(win.scratchpad_return_index, 0);
            const returnName = String(win.scratchpad_return_name || "");
            // Preferir el nombre: es correcto tanto con el índice 1..N nuevo
            // como con el 0..N-1 de un binario anterior de Umbriel.
            const returnByName = root.workspaceIndexByName(returnName);
            const returnId = returnByName > 0 ? returnByName : returnIndex;
            const originId = minimized
                ? (wsIndex > 0 ? wsIndex
                    : (returnId > 0 ? returnId
                        : (remembered ? Number(remembered.id) || 0 : 0)))
                : 0;
            const originName = minimized
                ? (wsIndex > 0 ? wsName
                    : (returnName.length > 0 ? returnName
                        : (remembered ? String(remembered.name || "") : "")))
                : "";

            out.push({
                id: address,
                address: address,
                title: String(win.title || ""),
                appId: appId,
                class: appId,
                workspaceId: wsIndex,
                workspaceName: wsName,
                monitor: String(win.output || ""),
                focused: win.active === true,
                urgent: win.urgent === true,
                visible: win.visible === true,
                floating: win.floating === true,
                minimized: minimized,
                minimizable: win.minimizable === true,
                scratchpad: scratchpad,
                titleBar: win.title_bar === true,
                originWorkspaceId: originId,
                originWorkspaceName: originName,
                maximized: win.maximized === true,
                fullscreen: win.fullscreen === true,
                pinned: win.pinned === true,
                x: root.numberOr(win.x, 0),
                y: root.numberOr(win.y, 0),
                width: root.numberOr(win.w, 0),
                height: root.numberOr(win.h, 0),
                pid: root.numberOr(win.pid, 0),
                xwayland: win.xwayland === true
            });
        }
        return out;
    }

    // ----------------------------------------------------------- escritorios
    readonly property var workspaces: {
        root.revision;
        root.dataRevision;
        const list = root.workspacesJson || [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            out.push({
                id: Number(ws.index) || 0,
                name: String(ws.name || ws.id || ""),
                monitor: String(ws.output || ""),
                focused: ws.focused === true,
                active: ws.active === true,
                urgent: ws.urgent === true,
                hasFullscreen: false,
                layout: String(ws.layout || "dwindle"),
                windowCount: root.numberOr(ws.window_count, 0)
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
        const wanted = String(windowId === undefined || windowId === null
            ? "" : windowId).replace(/^0x/, "");
        const list = root.windows;
        for (let i = 0; i < list.length; i++) {
            if (list[i].address === wanted || list[i].id === wanted)
                return list[i];
        }
        return null;
    }

    function noteAction(action, ok): bool {
        root.lastAction = String(action);
        root.lastActionOk = ok === true;
        return root.lastActionOk;
    }

    function quote(value): string {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    // Umbriel se controla por CLI. Las acciones que solo trabajan sobre la
    // ventana enfocada se encadenan con window-focus.
    function run(command, action): bool {
        if (!root.available)
            return root.noteAction(action, false);
        Quickshell.execDetached(["sh", "-c", command]);
        return root.noteAction(action, true);
    }

    function focusWindow(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("focusWindow", false);
        // Enfocar una ventana minimizada es restaurarla. Para las del
        // scratchpad no basta con `window-focus`: eso mostraría el pad
        // entero, no devolvería la ventana a su escritorio.
        if (win.minimized)
            return root.restoreWindow(windowId);
        return root.run("umbriel msg window-focus " + root.quote(win.address),
            "focusWindow");
    }

    function closeWindow(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("closeWindow", false);
        return root.run("umbriel msg window-close " + root.quote(win.address),
            "closeWindow");
    }

    function toggleFloating(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("toggleFloating", false);
        return root.run("umbriel msg window-toggle-floating "
            + root.quote(win.address), "toggleFloating");
    }

    function toggleFullscreen(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("toggleFullscreen", false);
        return root.run("umbriel msg window-focus " + root.quote(win.address)
            + " && umbriel msg window-toggle-fullscreen", "toggleFullscreen");
    }

    function toggleMaximized(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("toggleMaximized", false);
        return root.run("umbriel msg window-focus " + root.quote(win.address)
            + " && umbriel msg window-toggle-maximize", "toggleMaximized");
    }

    function togglePinned(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("togglePinned", false);
        return root.run("umbriel msg window-focus " + root.quote(win.address)
            + " && umbriel msg window-toggle-pinned", "togglePinned");
    }

    function minimizeWindow(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("minimizeWindow", false);
        if (win.minimized)
            return root.noteAction("minimizeWindow", true);

        root.minimizedWorkspaces[win.address] = {
            id: win.workspaceId,
            name: win.workspaceName
        };
        // Umbriel solo minimiza ventanas flotantes. Las mosaicadas se
        // esconden en un scratchpad y se recuperan con window-focus, así que
        // el botón de minimizar funciona en los dos modos.
        if (win.floating === true && win.minimizable !== false) {
            return root.run("umbriel msg window-minimize "
                + root.quote(win.address), "minimizeWindow");
        }
        return root.run("umbriel msg window-focus " + root.quote(win.address)
            + " && umbriel msg window-move-to-scratchpad",
            "minimizeWindow");
    }

    function restoreWindow(windowId): bool {
        const win = root.windowById(windowId);
        if (!win)
            return root.noteAction("restoreWindow", false);
        if (!win.minimized)
            return root.noteAction("restoreWindow", true);
        delete root.minimizedWorkspaces[win.address];
        // Un solo comando devuelve la ventana exacta a su escritorio. Es
        // importante no enfocar primero: enfocar una ventana del scratchpad
        // muestra el scratchpad entero y deja las demás flotando encima sin
        // poder usarse como ventanas normales. El respaldo mantiene la
        // compatibilidad con binarios anteriores del compositor.
        return root.run("umbriel restore-window " + root.quote(win.address)
            + " || (umbriel msg window-focus " + root.quote(win.address)
            + " && umbriel msg window-restore-from-scratchpad)",
            "restoreWindow");
    }

    function moveToWorkspace(windowId, workspaceId): bool {
        const win = root.windowById(windowId);
        const target = String(workspaceId === undefined || workspaceId === null
            ? "" : workspaceId).trim();
        if (!win || target.length === 0)
            return root.noteAction("moveToWorkspace", false);
        // Como el mockup: una ventana fijada se desancla antes de moverse para
        // que el cambio de escritorio se note.
        let command = "umbriel msg window-focus " + root.quote(win.address);
        if (win.pinned === true)
            command += " && umbriel msg window-toggle-pinned";
        command += " && umbriel msg window-move-to-workspace-silent "
            + root.quote(target);
        return root.run(command, "moveToWorkspace");
    }

    function focusWorkspace(workspaceId): bool {
        const target = String(workspaceId === undefined || workspaceId === null
            ? "" : workspaceId).trim();
        if (target.length === 0)
            return root.noteAction("focusWorkspace", false);
        return root.run("umbriel msg workspace-switch " + root.quote(target),
            "focusWorkspace");
    }

    function setWorkspaceLayout(workspaceId, layout): bool {
        const id = Number(workspaceId);
        const mode = String(layout === undefined || layout === null
            ? "" : layout).trim().toLowerCase();
        if (!isFinite(id) || id <= 0
                || ["scrolling", "dwindle", "master", "stacking"]
                    .indexOf(mode) === -1)
            return root.noteAction("setWorkspaceLayout", false);

        // Umbriel cambia el layout del escritorio activo. Si el objetivo no
        // está activo, se va, se cambia y se vuelve.
        const current = root.focusedWorkspace
            ? Number(root.focusedWorkspace.id) || 1 : 1;
        if (current === id) {
            return root.run("umbriel msg workspace-set-layout "
                + root.quote(mode), "setWorkspaceLayout");
        }
        return root.run("umbriel msg workspace-switch " + root.quote(id)
            + " && umbriel msg workspace-set-layout " + root.quote(mode)
            + " && umbriel msg workspace-switch " + root.quote(current),
            "setWorkspaceLayout");
    }

    // Modo de ALBA («floating» / «mosaic») traducido al layout nativo de
    // Umbriel. «Flotante» es el layout stacking: ventanas sueltas y
    // redimensionables. «Mosaico» es dwindle: reparto automático.
    function setWorkspaceMode(workspaceId, mode): bool {
        const value = String(mode === undefined || mode === null ? "" : mode);
        return root.setWorkspaceLayout(workspaceId,
            value === "mosaic" ? "dwindle" : "stacking");
    }

    // Umbriel no tiene una acción para fijar un layout concreto: se escribe en
    // su configuración y se recarga. El ayudante conserva el resto del archivo.
    function setKeyboardLayout(layout): bool {
        const clean = String(layout === undefined || layout === null
            ? "" : layout).trim().toLowerCase();
        if (!/^[a-z0-9_]+$/.test(clean))
            return root.noteAction("setKeyboardLayout", false);
        return root.run((Quickshell.env("HOME") || "")
            + "/.local/bin/alba-keyboard-layout "
            + root.quote(clean), "setKeyboardLayout");
    }

    // Reescribe los colores de la barra nativa y recarga Umbriel.
    function setShellTheme(mode, accent): bool {
        const value = String(mode === undefined || mode === null
            ? "" : mode).toLowerCase() === "light" ? "light" : "dark";
        const color = String(accent === undefined || accent === null
            ? "" : accent);
        const clean = /^#[0-9a-f]{6}$/i.test(color) ? color : "#b8bec7";
        return root.run((Quickshell.env("HOME") || "")
            + "/.local/bin/alba-umbriel-theme "
            + root.quote(value) + " " + root.quote(clean), "setShellTheme");
    }

    function moveWindowTo(windowId, x, y): bool {
        const win = root.windowById(windowId);
        if (!win || win.floating !== true)
            return root.noteAction("moveWindowTo", false);
        const px = Math.round(Number(x));
        const py = Math.round(Number(y));
        if (!isFinite(px) || !isFinite(py))
            return root.noteAction("moveWindowTo", false);
        return root.run("umbriel msg window-move-to top_left "
            + root.quote(px) + " " + root.quote(py)
            + " --window " + root.quote(win.address), "moveWindowTo");
    }

    // ------------------------------------------------------------------ sesión
    // Umbriel no entiende `hyprctl`: el cierre de sesión va por su IPC, sin
    // diálogo de confirmación porque el usuario ya lo pidió en el menú.
    function sessionQuit(): bool {
        return root.run("umbriel msg session-quit skip-confirmation",
            "sessionQuit");
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
        if (!windowsProc.running)
            windowsProc.running = true;
        if (!workspacesProc.running)
            workspacesProc.running = true;
    }

    Process {
        id: windowsProc

        command: ["umbriel", "windows", "--json"]

        stdout: StdioCollector {
            id: windowsOut
        }

        onExited: {
            try {
                const reply = JSON.parse(windowsOut.text || "[]");
                // Umbriel devuelve un array directo; algunas versiones lo
                // envuelven en { "ok": [...] }. Se aceptan las dos formas.
                const list = Array.isArray(reply) ? reply
                    : (reply && Array.isArray(reply.ok) ? reply.ok : []);
                root.windowsJson = list;
                root.dataRevision++;
                root.windowDataReady = true;
            } catch (error) {
            }
        }
    }

    Process {
        id: workspacesProc

        command: ["umbriel", "workspaces", "--json"]

        stdout: StdioCollector {
            id: workspacesOut
        }

        onExited: {
            try {
                const reply = JSON.parse(workspacesOut.text || "[]");
                const list = Array.isArray(reply) ? reply
                    : (reply && Array.isArray(reply.ok) ? reply.ok : []);
                root.workspacesJson = list;
                root.rebuildWorkspaceCache();
                root.dataRevision++;
            } catch (error) {
            }
        }
    }

    Timer {
        interval: 600
        repeat: true
        running: root.available
        onTriggered: root.refresh()
    }

    // ------------------------------------------------------- tecla Mod
    // Umbriel informa del estado real de Mod mientras se mantiene pulsada.
    // Así el overlay de ventanas aparece con el gesto y no al soltar, y el
    // lanzador solo se abre con un toque limpio (sin atajos de por medio).
    Process {
        id: modProc

        command: ["umbriel", "subscribe", "modifiers"]
        running: root.available

        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const message = JSON.parse(line);
                    if (!message || message.event !== "modifiers"
                            || !message.data)
                        return;
                    const held = message.data.mod === true;
                    const tapped = message.data.tap === true;
                    root.modFailures = 0;
                    SuperState.externalHold = true;
                    if (held === root.modHeld) {
                        if (held)
                            root.modTapAllowed = root.modTapAllowed && tapped;
                        return;
                    }
                    root.modHeld = held;
                    if (held) {
                        root.modTapAllowed = tapped;
                        SuperState.press(tapped);
                    } else {
                        SuperState.release(root.modTapAllowed && tapped);
                        root.modTapAllowed = true;
                    }
                } catch (error) {
                }
            }
        }

        onExited: {
            if (root.modHeld)
                SuperState.cancel();
            SuperState.externalHold = false;
            root.modHeld = false;
            if (root.available && root.modFailures < 4) {
                root.modFailures++;
                modRestart.restart();
            }
        }
    }

    Timer {
        id: modRestart

        interval: Math.min(16000, 1000 * Math.pow(2, root.modFailures))
        repeat: false
        onTriggered: {
            if (root.available && !modProc.running)
                modProc.running = true;
        }
    }

    // ------------------------------------------------- selector de escritorio
    // El botón «Mover» de la barra de título nativa pide este menú. Umbriel
    // solo entrega la ventana y la posición; la tarjeta la dibuja ALBA.
    Process {
        id: moveMenuProc

        command: ["umbriel", "subscribe", "move_menu"]
        running: root.available

        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const message = JSON.parse(line);
                    if (!message || message.event !== "move_menu"
                            || !message.data)
                        return;
                    root.moveMenuWindow = String(message.data.window || "");
                    root.moveMenuX = Number(message.data.x) || 0;
                    root.moveMenuY = Number(message.data.y) || 0;
                    root.moveMenuSerial = Number(message.data.serial) || 0;
                } catch (error) {
                }
            }
        }

        onExited: {
            if (root.available)
                moveMenuRestart.restart();
        }
    }

    Timer {
        id: moveMenuRestart

        interval: 1000
        repeat: false
        onTriggered: {
            if (root.available && !moveMenuProc.running)
                moveMenuProc.running = true;
        }
    }

    // La vista general del compositor avisa al abrirse y al empezar a
    // cerrarse. Al abrirse, ALBA cierra sus paneles para no taparla.
    Process {
        id: overviewProc

        command: ["umbriel", "subscribe", "overview"]
        running: root.available

        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const message = JSON.parse(line);
                    if (!message || message.event !== "overview"
                            || !message.data)
                        return;
                    root.overviewOpen = message.data.open === true;
                } catch (error) {
                }
            }
        }

        onExited: {
            if (root.available)
                overviewRestart.restart();
        }
    }

    Timer {
        id: overviewRestart

        interval: 1000
        repeat: false
        onTriggered: {
            if (root.available && !overviewProc.running)
                overviewProc.running = true;
        }
    }
}
