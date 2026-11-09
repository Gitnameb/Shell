import Quickshell
import QtQuick

// Indicador de un escritorio. El activo muestra hasta cinco iconos de las
// ventanas abiertas, como el ejemplo web: cada ventana va en una ficha con su
// color y al pulsarla se enfoca (o se restaura). Los demás escritorios solo
// muestran el número para no ensuciar la barra.
Rectangle {
    id: root

    property int workspaceId: 1
    // En la barra vertical no caben las fichas de las apps: se muestra solo
    // el número del escritorio para que la franja no se ensanche.
    property bool compact: false

    // El menú contextual vive en Bar.qml; la ficha solo le pasa el icono y la app.
    signal appMenuRequested(var anchorItem, var app)
    // Cualquier clic en la ficha (app, número o modo) avisa a la barra para
    // cerrar el panel que hubiera abierto.
    signal interacted()

    readonly property var ws: {
        const list = CompositorState.workspaces || [];
        for (let i = 0; i < list.length; i++) {
            if (Number(list[i].id) === root.workspaceId)
                return list[i];
        }
        return null;
    }
    readonly property bool exists: root.ws !== null || root.windows.length > 0
    readonly property bool focused: root.ws ? root.ws.focused : false
    // Cualquier ventana cuenta, también las minimizadas o en el scratchpad:
    // el número se ilumina para saber qué escritorios están en uso.
    readonly property bool occupied: root.windows.length > 0
    // Con Super pulsada, el escritorio activo cambia sus fichas por un botón
    // que alterna entre mosaico y flotante, como en el mockup. Las apps siguen
    // ahí, atenuadas, para no perder el contexto del escritorio.
    readonly property bool modeSwitch: root.focused && SuperState.active
        && !root.compact
    readonly property string workspaceMode:
        SettingsState.workspaceMode(root.workspaceId)
    readonly property bool floatingMode: root.workspaceMode === "floating"
    // Ventanas del contrato común, incluidas las minimizadas que volverán a
    // este escritorio. Antes se leían solo los toplevels del escritorio y al
    // minimizar el icono desaparecía de la barra.
    readonly property var windows:
        CompositorState.windowsForWorkspace(root.workspaceId)
    readonly property var clients: root.windows
    // El ejemplo web enseña como máximo cinco fichas y resume el resto con +N.
    readonly property int maxIcons: 5

    // Una entrada por ventana, no por aplicación: dos terminales muestran dos
    // fichas y cada una abre su propio menú y ejecuta acciones sobre su ventana.
    readonly property var apps: {
        const list = root.windows;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const win = list[i];
            let cls = String(win.appId || win.class || "");
            if (cls.length === 0)
                continue;
            const key = cls.toLowerCase();
            // Las ventanas propias de Quickshell (diálogos de crash, etc.) no
            // son apps del escritorio y no deben aparecer en la barra.
            if (key.indexOf("quickshell") !== -1)
                continue;

            const color = root.colorFor(cls);
            out.push({
                cls: cls,
                name: root.nameFor(cls),
                address: win.address,
                title: String(win.title || ""),
                workspace: root.workspaceId,
                icon: root.iconFor(cls),
                letter: root.letterFor(cls),
                color: color,
                tile: root.tintFor(color),
                minimized: win.minimized === true,
                maximized: win.maximized === true,
                fullscreen: win.fullscreen === true,
                floating: win.floating === true,
                pinned: win.pinned === true,
                activated: win.focused === true
            });
        }
        return out;
    }
    readonly property var visibleApps: root.focused && !root.compact
        ? root.apps.slice(0, root.maxIcons) : []
    readonly property int hiddenApps: root.focused && !root.compact
        ? Math.max(0, root.apps.length - root.visibleApps.length) : 0

    // Progreso de tareas: las apps lo muestran en su propia ficha. Los
    // escritorios inactivos resumen el de sus apps y, si hay una tarea
    // genérica para ese escritorio (`ws:N`), el anillo rodea la píldora.
    readonly property real workspaceProgress:
        ProgressState.forWorkspace(root.workspaceId)
    readonly property real appProgress: {
        let best = -1;
        for (let i = 0; i < root.apps.length; i++)
            best = Math.max(best, ProgressState.forApp(root.apps[i].cls));
        return best;
    }
    readonly property real pillProgress: root.focused
        ? root.workspaceProgress
        : Math.max(root.workspaceProgress, root.appProgress)

    function iconFor(cls) {
        if (!cls)
            return "";
        if (cls.startsWith("/") || cls.startsWith("file:"))
            return cls;

        const candidates = [cls, cls.toLowerCase()];
        for (let i = 0; i < candidates.length; i++) {
            if (Quickshell.hasThemeIcon(candidates[i]))
                return Quickshell.iconPath(candidates[i]);
        }

        const entry = DesktopEntries.heuristicLookup(cls);
        if (entry && entry.icon) {
            if (entry.icon.startsWith("/") || entry.icon.startsWith("file:"))
                return entry.icon;
            if (Quickshell.hasThemeIcon(entry.icon))
                return Quickshell.iconPath(entry.icon);
        }
        return "";
    }

    // Nombre de la app para el menú contextual; primero busca su .desktop.
    function nameFor(cls) {
        const entry = DesktopEntries.heuristicLookup(cls);
        if (entry && entry.name)
            return entry.name;
        let name = String(cls);
        const dot = name.lastIndexOf(".");
        if (dot !== -1)
            name = name.slice(dot + 1);
        name = name.replace(/[-_]/g, " ");
        return name.length > 0
            ? name.charAt(0).toUpperCase() + name.slice(1) : "Aplicación";
    }

    // Nombre legible para el respaldo cuando no hay icono en el tema.
    function letterFor(cls) {
        let name = String(cls);
        const slash = name.lastIndexOf("/");
        if (slash !== -1)
            name = name.slice(slash + 1);
        const dot = name.indexOf(".");
        if (dot > 0)
            name = name.slice(dot + 1);
        return name.length > 0 ? name.charAt(0).toUpperCase() : "?";
    }

    // Color por aplicación, siguiendo la paleta del ejemplo web. Las apps
    // conocidas conservan su color y el resto recibe uno estable por nombre.
    function colorFor(cls) {
        const key = String(cls).toLowerCase();
        const known = [
            [["firefox", "chrom", "brave", "zen", "epiphany"], "#8ab4f8"],
            [["konsole", "terminal", "kitty", "alacritty", "foot", "wezterm",
                "terminator", "xterm"], "#7fd1b9"],
            [["dolphin", "nautilus", "thunar", "files", "pcmanfm"], "#f4c97a"],
            [["spotify", "music", "mpv", "vlc", "elisa", "audacious"], "#c9b8f5"],
            [["code", "codium", "zed", "neovim", "nvim", "editor"], "#9ad9b0"],
            [["settings", "systemsettings", "control-center"], "#b8c4d4"],
            [["calc"], "#f4a6a6"],
            [["spectacle", "screenshot", "grim", "flameshot"], "#a6d8f4"],
            [["gimp", "krita", "inkscape", "draw"], "#e8a9d6"]
        ];
        for (let i = 0; i < known.length; i++) {
            const aliases = known[i][0];
            for (let j = 0; j < aliases.length; j++) {
                if (key.indexOf(aliases[j]) !== -1)
                    return known[i][1];
            }
        }
        const palette = [
            "#8ab4f8", "#7fd1b9", "#f4c97a", "#c9b8f5", "#9ad9b0",
            "#f4a6a6", "#a6d8f4", "#8fd3e8", "#e8a9d6", "#f5c28b"
        ];
        let hash = 0;
        for (let i = 0; i < key.length; i++)
            hash = (hash * 31 + key.charCodeAt(i)) >>> 0;
        return palette[hash % palette.length];
    }

    // Fondo de la ficha: el color de la app al 18 % sobre el cristal de la barra.
    function tintFor(hex) {
        const value = String(hex).replace("#", "");
        if (value.length !== 6)
            return Theme.hover;
        return Qt.rgba(parseInt(value.substr(0, 2), 16) / 255,
            parseInt(value.substr(2, 2), 16) / 255,
            parseInt(value.substr(4, 2), 16) / 255, 0.18);
    }

    function normalizeApp(value) {
        return String(value).toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    // El backend normaliza la dirección: Hyprland añade «0x» si falta y
    // Umbriel usa su id hexadecimal tal cual.
    function focusAddress(address) {
        return String(address || "").trim();
    }

    function toggleMode(): void {
        WorkspaceModeState.setMode(root.workspaceId,
            root.floatingMode ? "mosaic" : "floating");
    }

    // Punto de aviso, como en el ejemplo web. Se compara el nombre de la app
    // del aviso con la clase de la ventana (p. ej. Konsole u org.kde.konsole).
    function notified(cls) {
        const target = root.normalizeApp(cls);
        if (target.length === 0)
            return false;
        const list = NotificationState.entries;
        for (let i = 0; i < list.length; i++) {
            const key = root.normalizeApp(list[i].appKey);
            if (key.length === 0)
                continue;
            if (key === target || key.indexOf(target) !== -1
                    || target.indexOf(key) !== -1)
                return true;
        }
        return false;
    }

    implicitWidth: Math.max(root.compact ? 26 : 0,
        content.implicitWidth + 14,
        root.modeSwitch ? 38 : 0)
    implicitHeight: root.compact ? 28 : 34
    radius: 8
    // El escritorio actual lleva el mismo fondo que al pasar el ratón, así se
    // sabe dónde estamos aunque no haya ninguna app abierta. Los demás siguen
    // limpios para que el activo destaque.
    color: root.focused || mouse.containsMouse
        ? Theme.hover : "transparent"
    border.width: 0
    border.color: Theme.accentLine

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.visibleApps

            delegate: Rectangle {
                id: miniApp

                required property var modelData

                width: 26
                height: 26
                radius: 7
                color: modelData.tile
                opacity: root.modeSwitch
                    ? 0.24
                    : (modelData.minimized
                        ? (miniMouse.containsMouse ? 0.85 : 0.4)
                        : 1)
                scale: miniMouse.containsMouse && !root.modeSwitch ? 1.1 : 1

                Behavior on scale {
                    NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                Image {
                    id: miniIcon

                    anchors.centerIn: parent
                    width: Math.min(24, SettingsState.barIconSize)
                    height: Math.min(24, SettingsState.barIconSize)
                    source: modelData.icon
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !miniIcon.visible
                    text: modelData.letter
                    color: modelData.color
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }

                // Aviso pendiente de esta app: punto en la esquina superior.
                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: -2
                    anchors.rightMargin: -2
                    color: Theme.accent
                    border.width: 1
                    border.color: Theme.glass
                    visible: root.notified(modelData.cls)
                    z: 6
                }

                // Anillo de progreso de la tarea de esta app.
                ProgressRing {
                    anchors.fill: parent
                    anchors.margins: -2
                    cornerRadius: 9
                    progress: ProgressState.forApp(modelData.cls)
                    color: modelData.color
                    z: 5
                }

                MouseArea {
                    id: miniMouse

                    anchors.fill: parent
                    hoverEnabled: !root.modeSwitch
                    enabled: !root.modeSwitch
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        root.interacted();
                        if (mouse.button === Qt.RightButton) {
                            root.appMenuRequested(miniApp, miniApp.modelData);
                            return;
                        }
                        const address = root.focusAddress(
                            miniApp.modelData.address);
                        // Una ventana minimizada vuelve al pulsar su ficha,
                        // igual que en el mockup. El foco solo no la restaura.
                        if (miniApp.modelData.minimized) {
                            if (address.length > 0)
                                CompositorState.restoreWindow(address);
                            return;
                        }
                        if (address.length > 0)
                            CompositorState.focusWindow(address);
                        else
                            CompositorState.focusWorkspace(root.workspaceId);
                    }
                }
            }
        }

        Text {
            height: 16
            verticalAlignment: Text.AlignVCenter
            // En el escritorio activo manda el contexto: sus iconos. Si no
            // tiene ninguna app, se muestra el número para que el hueco no
            // parezca un fallo.
            visible: !root.focused || root.visibleApps.length === 0
            text: root.workspaceId
            // El activo y los que tienen cualquier ventana (aunque esté
            // minimizada) usan el acento a plena intensidad; los vacíos quedan
            // atenuados. Así se ve de un vistazo qué escritorios están en uso.
            color: root.focused || root.occupied
                ? Theme.accent : Theme.accentFaded
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        Text {
            height: 16
            verticalAlignment: Text.AlignVCenter
            visible: root.hiddenApps > 0
            text: "+" + root.hiddenApps
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.weight: Font.DemiBold
        }
    }

    // Botón de modo sobre las fichas atenuadas del escritorio activo. El
    // icono enseña el modo al que se cambia al pulsarlo.
    Rectangle {
        id: modeButton

        anchors.centerIn: parent
        z: 20
        width: 26
        height: 26
        radius: 7
        visible: root.modeSwitch
        color: modeMouse.containsMouse ? Theme.accent : Theme.accentSoft
        border.width: 1
        border.color: Theme.accentLine

        ShellIcon {
            anchors.centerIn: parent
            size: 14
            color: modeMouse.containsMouse ? Theme.accentInk : Theme.accent
            // El icono enseña el modo al que se va a cambiar, no el actual.
            source: ShellIcons.src(root.floatingMode
                ? "mode-tile" : "mode-float")
        }

        MouseArea {
            id: modeMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.interacted();
                root.toggleMode();
            }
        }
    }

    // Anillo de progreso de una tarea sin app concreta (por ejemplo una copia
    // de archivos o una descarga que no informa su clase de ventana).
    ProgressRing {
        anchors.fill: parent
        anchors.margins: -1
        cornerRadius: 9
        progress: root.exists ? root.pillProgress : -1
        color: Theme.accent
        z: 4
    }

    // Va por debajo de los iconos (z negativo) para que pulsar una app enfoque
    // su ventana en vez de cambiar de escritorio.
    MouseArea {
        id: mouse

        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.interacted();
            // El cambio de modo lo hace solo el botón dedicado (z: 20).
            // Tenerlo también aquí hacía que un mismo clic pudiera disparar
            // dos cambios cuando el pulsador del botón y el de la píldora se
            // solapaban.
            CompositorState.focusWorkspace(root.workspaceId);
        }
    }
}
