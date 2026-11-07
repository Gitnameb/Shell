pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Preferencias pequeñas del shell. Se guardan en un archivo de texto para que
// sobrevivan a las recargas de Quickshell y a un reinicio de la sesión.
Singleton {
    id: root

    property int maxWorkspaces: 9
    // Filas visibles del centro de control. El resto se desplaza hacia abajo.
    property int centerRows: 5
    // Tamaño de los iconos del centro. La caja mide 32 px y nunca se supera.
    property int centerIconSize: 20
    // Tamaño de los iconos de la barra. Solo cambia el dibujo, no la píldora
    // que los contiene.
    property int barIconSize: 22
    // Si está activo, la barra se oculta al dejar de usarla y vuelve a
    // aparecer al acercar el puntero al borde donde vive.
    property bool autoHideBar: false
    // Dónde vive la barra: «abajo» (por defecto), «arriba», «izquierda» o
    // «derecha». En los lados, la barra se dibuja en vertical.
    property string barPosition: "abajo"
    readonly property bool barAtTop: root.barPosition === "arriba"
    readonly property bool barAtBottom: root.barPosition === "abajo"
    readonly property bool barAtLeft: root.barPosition === "izquierda"
    readonly property bool barAtRight: root.barPosition === "derecha"
    readonly property bool barVertical: root.barAtLeft || root.barAtRight
    // Ancho del reproductor de música, ajustable manteniendo Super. 0 deja
    // que la píldora mida lo que pida su contenido.
    property int musicWidth: 0
    // Cuántos milisegundos hay que mantener Super para entrar en el modo
    // ventanas. Un toque más corto sigue abriendo el lanzador. El valor se
    // escribe en la configuración de Umbriel para que el compositor y el
    // overlay del shell usen exactamente el mismo retardo.
    property int superHoldMs: 320
    // Tamaño de la primera vez que una ventana pasa de mosaico a flotante,
    // como porcentaje del área útil. Después manda el tamaño que el usuario
    // le haya dado al redimensionarla.
    property int floatingSizePercent: 60
    // Separación diagonal entre ventanas flotantes en cascada. 0 la calcula
    // a partir de la barra de título.
    property int floatingCascade: 0
    // Cada vista decide si su valor se muestra como porcentaje en la barra y
    // en las fichas del centro de control. Por defecto, todos desactivados.
    property bool showVolumePercent: false
    property bool showBrightnessPercent: false
    property bool showExtraDimPercent: false
    property bool showBluetoothPercent: false
    property bool showBatteryPercent: false
    // Muestra la temperatura junto a los iconos de CPU y GPU en la barra.
    property bool showTemps: false
    // Un solo icono abre las notificaciones y el centro de control juntos.
    // Desactivado, la campana abre solo las notificaciones y el icono de
    // cuadrícula abre solo el centro de control.
    property bool unifiedPanels: true

    // ------------------------------------------------------- ventanas
    // Modo por defecto de los escritorios. «floating» imita a Windows: las
    // ventanas se abren sueltas y se mueven libremente. «mosaic» las coloca
    // en mosaico. El valor elegido en el primer arranque manda hasta que el
    // usuario cambie un escritorio concreto.
    property string workspaceModeDefault: "floating"
    // Excepciones por escritorio, codificadas como «1=floating;2=mosaic».
    property string workspaceModes: ""
    // Falso hasta que el usuario elige en la pantalla de bienvenida.
    property bool workspaceModeChosen: false

    // Barra de título del shell para ventanas flotantes en backends sin cromo
    // nativo (Hyprland). El valor público es windowChrome; este se deriva de
    // él para conservar el respaldo anterior.
    //   auto   → aparece con Super
    //   always → siempre visible (útil para quien viene de Windows)
    //   never  → solo los controles del overlay
    property string nativeTitlebar: "auto"
    // Estilo de la barra de ventanas, como en el mockup:
    //   floating   → superpuesta; aparece al mantener Super
    //   integrated → franja integrada; siempre visible
    property string windowChrome: "floating"

    // Fondo de pantalla del escritorio. Ruta absoluta a una imagen; vacío
    // deja el fondo del compositor o el color elegido.
    property string wallpaperPath: ""
    // Color de fondo alternativo a la imagen (#RRGGBB). La imagen manda si
    // existe; al quitarla se vuelve a este color.
    property string wallpaperColor: ""

    // Ciudad del clima. Vacío deja que wttr.in la deduzca por la conexión;
    // con un valor se consulta esa ubicación.
    property string weatherPlace: ""

    // Apariencia. El modo cambia toda la paleta y el acento se comparte entre
    // ambos modos: en claro se oscurece solo para mantener el contraste.
    property string themeMode: "dark"
    property string accentColor: "#b8bec7"
    // Propaga el modo y el acento a GTK y a las apps de KDE.
    property bool systemTheme: true
    // Cristal del shell. «glassTransparency» es el porcentaje que se ve a
    // través de la barra y los paneles: 0 es opaco y 90, casi transparente.
    // «glassBlur» es el radio de desenfoque global de Umbriel, en la misma
    // escala que el mockup (0 lo apaga). Afecta también a las ventanas.
    // «glassBlurBehind» elige qué se desenfoca: false usa la caché del fondo
    // de pantalla (como el mockup) y true, el contenido real que hay detrás.
    property int glassTransparency: 22
    property int glassBlur: 12
    property bool glassBlurBehind: false

    // Distribución física del teclado. Se aplica a Hyprland en caliente y se
    // vuelve a aplicar al arrancar el shell.
    property string keyboardLayout: "es"
    readonly property var keyboardLayouts: [
        { key: "es", label: "Español" },
        { key: "latam", label: "Latinoam." },
        { key: "us", label: "Inglés EE. UU." },
        { key: "gb", label: "Inglés RU" },
        { key: "fr", label: "Francés" },
        { key: "de", label: "Alemán" },
        { key: "it", label: "Italiano" },
        { key: "pt", label: "Portugués" },
        { key: "br", label: "Brasil" },
        { key: "ru", label: "Ruso" },
        { key: "pl", label: "Polaco" },
        { key: "tr", label: "Turco" }
    ]

    // Atajo global que silencia o reactiva el micrófono, en formato de
    // Hyprland (por ejemplo "SUPER SHIFT, M"). Vacío = sin atajo.
    property string micShortcut: ""
    property string appliedMicShortcut: ""

    // Apagado automático: si nadie usa el punto de acceso o el Wi-Fi se queda
    // sin conexión durante estos minutos, se apaga para no gastar radio.
    property bool hotspotAutoOff: true
    property int hotspotMinutes: 15
    property bool wifiAutoOff: true
    property int wifiMinutes: 15
    // Mostrar la entrada para conectarse a una red Wi-Fi oculta.
    property bool showHiddenWifi: false
    property bool btAutoOff: true
    property int btMinutes: 15

    // Modo avión: se guarda para sobrevivir a una recarga del shell. También
    // se recuerdan las radios que estaban encendidas al activarlo.
    property bool airplaneMode: false
    property bool airplaneRestoreWifi: true
    property bool airplaneRestoreBt: true

    // Bloqueo automático de la sesión con hyprlock. 0 = nunca.
    property int lockMinutes: 5

    // Se rellena al leer el archivo; hasta entonces no se guarda nada para no
    // pisar la configuración del usuario con los valores por defecto.
    property bool ready: false
    property bool themeApplyPending: false
    property bool chromeApplyPending: false
    property bool holdApplyPending: false
    property bool floatingApplyPending: false
    property bool glassApplyPending: false
    property bool glassModeApplyPending: false

    readonly property string path: (Quickshell.env("HOME") || "/home/username")
        + "/.config/shell/settings.conf"
    readonly property string systemThemeScript: (Quickshell.shellDir || "")
        + "/scripts/shell-system-theme"
    readonly property string windowChromeScript: (Quickshell.shellDir || "")
        + "/scripts/shell-window-chrome"
    readonly property string superHoldScript: (Quickshell.shellDir || "")
        + "/scripts/shell-mod-hold"
    readonly property string floatingScript: (Quickshell.shellDir || "")
        + "/scripts/shell-floating-defaults"
    readonly property string glassScript: (Quickshell.shellDir || "")
        + "/scripts/shell-glass"
    readonly property string wallpaperPickScript: (Quickshell.shellDir || "")
        + "/scripts/shell-wallpaper-pick"

    readonly property var workspaceIds: {
        const list = [];
        for (let i = 1; i <= root.maxWorkspaces; i++)
            list.push(i);
        return list;
    }

    function setMaxWorkspaces(value: int): void {
        root.maxWorkspaces = Math.max(1, Math.min(20, value));
    }

    function setCenterRows(value: int): void {
        root.centerRows = Math.max(2, Math.min(8, value));
    }

    function setCenterIconSize(value: int): void {
        root.centerIconSize = Math.max(12, Math.min(32, value));
    }

    function setBarIconSize(value: int): void {
        root.barIconSize = Math.max(12, Math.min(26, value));
    }

    function setAutoHideBar(value: bool): void {
        root.autoHideBar = value;
    }

    function setBarPosition(value: string): void {
        root.barPosition = value === "arriba" || value === "izquierda"
            || value === "derecha" ? value : "abajo";
    }

    function setMusicWidth(value: int): void {
        const width = Math.round(value);
        root.musicWidth = width <= 0
            ? 0 : Math.max(140, Math.min(420, width));
    }

    function setSuperHoldMs(value: int): void {
        const ms = Math.round(value);
        root.superHoldMs = Math.max(100, Math.min(1000, ms));
        holdApplyTimer.restart();
    }

    function setFloatingSizePercent(value: int): void {
        const percent = Math.round(value);
        root.floatingSizePercent = Math.max(40, Math.min(80, percent));
        floatingApplyTimer.restart();
    }

    function setFloatingCascade(value: int): void {
        const step = Math.round(value);
        root.floatingCascade = Math.max(0, Math.min(96, step));
        floatingApplyTimer.restart();
    }

    // Escribe el tamaño y la cascada en [layout.stacking] de Umbriel y
    // recarga. El script no toca el archivo si los valores ya coinciden.
    function applyFloatingDefaults(): void {
        if (!root.ready)
            return;
        if (floatingProc.running) {
            root.floatingApplyPending = true;
            return;
        }
        root.floatingApplyPending = false;
        floatingProc.command = [
            "sh", root.floatingScript, String(root.floatingSizePercent),
            String(root.floatingCascade)
        ];
        floatingProc.running = true;
    }

    // Escribe el retardo en [input] de Umbriel y recarga la configuración.
    // El script no toca el archivo si el valor ya coincide.
    function applySuperHoldDelay(): void {
        if (!root.ready)
            return;
        if (superHoldProc.running) {
            root.holdApplyPending = true;
            return;
        }
        root.holdApplyPending = false;
        superHoldProc.command = [
            "sh", root.superHoldScript, String(root.superHoldMs)
        ];
        superHoldProc.running = true;
    }

    function setMicShortcut(value: string): void {
        root.micShortcut = value;
    }

    // Registra el atajo en Hyprland sin tocar el archivo de configuración.
    // Primero retira el anterior y después añade el nuevo.
    function applyMicShortcut(): void {
        if (!root.ready)
            return;
        const previous = root.appliedMicShortcut;
        if (previous === root.micShortcut)
            return;
        let script = "";
        if (previous.length > 0)
            script += "hyprctl keyword unbind '" + previous
                + "' >/dev/null 2>&1\n";
        if (root.micShortcut.length > 0) {
            // Quitar una posible bind anterior del mismo atajo (por ejemplo,
            // tras reiniciar el shell) evita que se ejecute dos veces.
            script += "hyprctl keyword unbind '" + root.micShortcut
                + "' >/dev/null 2>&1\n";
            script += "hyprctl keyword bind '" + root.micShortcut
                + ",exec,qs ipc -c shell call notifications micToggle'"
                + " >/dev/null 2>&1\n";
        }
        root.appliedMicShortcut = root.micShortcut;
        if (script.length > 0) {
            shortcutProc.command = ["sh", "-c", script];
            shortcutProc.running = true;
        }
    }

    function setShowTemps(value: bool): void {
        root.showTemps = value;
    }

    function setUnifiedPanels(value: bool): void {
        root.unifiedPanels = value;
    }

    // ------------------------------------------------------- ventanas
    function normalizeWorkspaceMode(value): string {
        return value === "mosaic" ? "mosaic" : "floating";
    }

    function workspaceMode(workspaceId): string {
        const id = String(Number(workspaceId) || 0);
        const parts = String(root.workspaceModes || "").split(";");
        for (let i = 0; i < parts.length; i++) {
            const pair = parts[i].split("=");
            if (pair.length === 2 && pair[0] === id)
                return root.normalizeWorkspaceMode(pair[1]);
        }
        return root.normalizeWorkspaceMode(root.workspaceModeDefault);
    }

    function setWorkspaceMode(workspaceId, mode): void {
        const id = Number(workspaceId);
        if (!isFinite(id) || id <= 0)
            return;
        const value = root.normalizeWorkspaceMode(mode);
        const pairs = [];
        const parts = String(root.workspaceModes || "").split(";");
        for (let i = 0; i < parts.length; i++) {
            const pair = parts[i].split("=");
            if (pair.length !== 2 || pair[0].length === 0)
                continue;
            if (Number(pair[0]) !== id)
                pairs.push(pair[0] + "=" + pair[1]);
        }
        pairs.push(String(id) + "=" + value);
        root.workspaceModes = pairs.join(";");
    }

    // Primera elección: se aplica a todos los escritorios y se borran las
    // excepciones para que el modo elegido sea el nuevo punto de partida.
    function chooseWorkspaceMode(mode): void {
        root.workspaceModeDefault = root.normalizeWorkspaceMode(mode);
        root.workspaceModes = "";
        root.workspaceModeChosen = true;
    }

    function setWorkspaceModeDefault(mode): void {
        root.workspaceModeDefault = root.normalizeWorkspaceMode(mode);
        root.workspaceModeChosen = true;
    }

    function setNativeTitlebar(value): void {
        const clean = String(value);
        if (clean === "always" || clean === "never" || clean === "auto")
            root.nativeTitlebar = clean;
    }

    // Estilo de barra de ventanas del mockup. Umbriel lo aplica en caliente
    // escribiendo [appearance.title_bar] overlay; los demás backends usan la
    // barra del shell como respaldo.
    function setWindowChrome(value): void {
        const clean = String(value);
        if (clean !== "floating" && clean !== "integrated")
            return;
        root.windowChrome = clean;
        root.applyWindowChrome();
    }

    function applyWindowChrome(): void {
        if (!root.ready)
            return;
        if (CompositorState.supports("nativeTitlebar")) {
            if (chromeProc.running) {
                root.chromeApplyPending = true;
                return;
            }
            root.chromeApplyPending = false;
            chromeProc.command = [
                "sh", root.windowChromeScript, root.windowChrome
            ];
            chromeProc.running = true;
        } else {
            root.nativeTitlebar = root.windowChrome === "integrated"
                ? "always" : "auto";
        }
    }

    function setWallpaperPath(path: string): void {
        const clean = String(path || "").trim();
        root.wallpaperPath = clean;
    }

    // Igual que el acento: solo #RRGGBB. Elegir un color quita la imagen para
    // que el cambio se vea al instante; la imagen puede volver después.
    function setWallpaperColor(value: string): bool {
        const clean = String(value).trim().toLowerCase();
        if (!/^#[0-9a-f]{6}$/.test(clean))
            return false;
        root.wallpaperColor = clean;
        root.wallpaperPath = "";
        return true;
    }

    function clearWallpaperColor(): void {
        root.wallpaperColor = "";
    }

    function clearWallpaper(): void {
        root.wallpaperPath = "";
    }

    // Ciudad del clima. Se recorta, se quitan saltos de línea y se limita la
    // longitud; vacío vuelve a la detección por IP.
    function setWeatherPlace(value: string): void {
        let clean = String(value || "").replace(/[\r\n\t]+/g, " ").trim();
        if (clean.length > 80)
            clean = clean.slice(0, 80);
        root.weatherPlace = clean;
    }

    // Abre el selector del sistema y guarda la imagen elegida. kdialog y
    // zenity se encargan de la ventana; el script solo elige el disponible.
    function chooseWallpaper(): void {
        if (wallpaperProc.running)
            return;
        wallpaperProc.command = ["sh", root.wallpaperPickScript];
        wallpaperProc.running = true;
    }

    function setThemeMode(value: string): void {
        root.themeMode = value === "light" ? "light" : "dark";
        root.requestShellTheme();
    }

    // Acepta solo #RRGGBB para que el color siempre sea válido. Devuelve si se
    // aplicó, de modo que el campo personalizado pueda limpiarse.
    function setAccentColor(value: string): bool {
        const clean = String(value).trim().toLowerCase();
        if (!/^#[0-9a-f]{6}$/.test(clean))
            return false;
        root.accentColor = clean;
        root.requestShellTheme();
        return true;
    }

    function setSystemTheme(value: bool): void {
        root.systemTheme = value;
    }

    // El cristal se limita para que el texto siga siendo legible. Umbriel
    // solo desenfoca donde hay transparencia, así que ambos valores se
    // aplican juntos: el porcentaje en vivo y el radio con un pequeño
    // retardo para no lanzar un proceso por cada paso del deslizador.
    function setGlassTransparency(value: int): void {
        root.glassTransparency = Math.max(0, Math.min(90, Math.round(value)));
    }

    function setGlassBlur(value: int): void {
        root.glassBlur = Math.max(0, Math.min(40, Math.round(value)));
    }

    function setGlassBlurBehind(value: bool): void {
        root.glassBlurBehind = value;
    }

    function applyGlassBlur(): void {
        if (!root.ready)
            return;
        if (glassProc.running) {
            root.glassApplyPending = true;
            return;
        }
        root.glassApplyPending = false;
        glassProc.command = [
            "sh", root.glassScript, "blur", String(root.glassBlur)
        ];
        glassProc.running = true;
    }

    // Umbriel guarda el modo en la misma regla de capa, así que cambiarlo
    // reescribe el bloque administrado por shell-glass.
    function applyGlassMode(): void {
        if (!root.ready)
            return;
        if (glassModeProc.running) {
            root.glassModeApplyPending = true;
            return;
        }
        root.glassModeApplyPending = false;
        glassModeProc.command = [
            "sh", root.glassScript, "mode",
            root.glassBlurBehind ? "behind" : "wallpaper"
        ];
        glassModeProc.running = true;
    }

    function setKeyboardLayout(value: string): void {
        const clean = String(value).trim().toLowerCase();
        if (!/^[a-z0-9_]+$/.test(clean))
            return;
        root.keyboardLayout = clean;
    }

    // El compositor aplica el cambio a los teclados conectados sin reiniciar.
    function applyKeyboardLayout(): void {
        if (!root.ready)
            return;
        CompositorState.setKeyboardLayout(root.keyboardLayout);
    }

    // La barra nativa de Umbriel tiene sus propios colores; se reescriben con
    // un pequeño retardo para no lanzar un proceso por cada clic.
    function applyShellTheme(): void {
        if (!root.ready)
            return;
        CompositorState.setShellTheme(root.themeMode, root.accentColor);
    }

    function requestShellTheme(): void {
        if (!root.ready)
            return;
        shellThemeTimer.restart();
    }

    Timer {
        id: shellThemeTimer

        interval: 220
        repeat: false
        onTriggered: root.applyShellTheme()
    }

    // El tema del sistema se aplica con un pequeño retardo para no lanzar un
    // proceso por cada clic mientras se eligen colores.
    function requestSystemTheme(): void {
        if (!root.ready || !root.systemTheme)
            return;
        themeTimer.restart();
    }

    function applySystemTheme(): void {
        if (!root.ready || !root.systemTheme)
            return;
        if (themeProc.running) {
            root.themeApplyPending = true;
            return;
        }
        themeApplyPending = false;
        themeProc.command = [
            "python3", root.systemThemeScript,
            root.themeMode, root.accentColor
        ];
        themeProc.running = true;
    }

    function setHotspotAutoOff(value: bool): void {
        root.hotspotAutoOff = value;
    }

    function setHotspotMinutes(value: int): void {
        root.hotspotMinutes = Math.max(1, Math.min(120, value));
    }

    function setWifiAutoOff(value: bool): void {
        root.wifiAutoOff = value;
    }

    function setWifiMinutes(value: int): void {
        root.wifiMinutes = Math.max(1, Math.min(120, value));
    }

    function setBtAutoOff(value: bool): void {
        root.btAutoOff = value;
    }

    function setBtMinutes(value: int): void {
        root.btMinutes = Math.max(1, Math.min(120, value));
    }

    function setLockMinutes(value: int): void {
        root.lockMinutes = Math.max(0, Math.min(120, value));
    }

    // Reinicia swayidle con el tiempo elegido. 0 lo detiene.
    function applyIdle(): void {
        if (!root.ready)
            return;
        Quickshell.execDetached(["sh", "-c",
            (Quickshell.env("HOME") || "") + "/.local/bin/shell-idle "
            + root.lockMinutes]);
    }

    function write(): void {
        if (!root.ready)
            return;
        // El script recibe la ruta en $1 y los valores en $2..$N. Se guarda la
        // ruta, se hace shift y printf escribe las claves con los valores.
        const format = "out=\"$1\" && shift && mkdir -p \"$(dirname \"$out\")\""
            + " && printf 'maxWorkspaces=%s\\n"
            + "showVolumePercent=%s\\n"
            + "showBrightnessPercent=%s\\n"
            + "showExtraDimPercent=%s\\n"
            + "showBluetoothPercent=%s\\n"
            + "showBatteryPercent=%s\\n"
            + "showTemps=%s\\n"
            + "unifiedPanels=%s\\n"
            + "hotspotAutoOff=%s\\n"
            + "hotspotMinutes=%s\\n"
            + "wifiAutoOff=%s\\n"
            + "wifiMinutes=%s\\n"
            + "btAutoOff=%s\\n"
            + "btMinutes=%s\\n"
            + "centerRows=%s\\n"
            + "centerIconSize=%s\\n"
            + "micShortcut=%s\\n"
            + "barIconSize=%s\\n"
            + "autoHideBar=%s\\n"
            + "themeMode=%s\\n"
            + "accentColor=%s\\n"
            + "systemTheme=%s\\n"
            + "glassTransparency=%s\\n"
            + "glassBlur=%s\\n"
            + "glassBlurBehind=%s\\n"
            + "keyboardLayout=%s\\n"
            + "workspaceModeDefault=%s\\n"
            + "workspaceModes=%s\\n"
            + "workspaceModeChosen=%s\\n"
            + "nativeTitlebar=%s\\n"
            + "lockMinutes=%s\\n"
            + "windowChrome=%s\\n"
            + "wallpaperPath=%s\\n"
            + "barPosition=%s\\n"
            + "musicWidth=%s\\n"
            + "superHoldMs=%s\\n"
            + "floatingSizePercent=%s\\n"
            + "floatingCascade=%s\\n"
            + "barControls=%s\\n"
            + "centerOrder=%s\\n"
            + "wallpaperColor=%s\\n"
            + "weatherPlace=%s\\n"
            + "airplaneMode=%s\\n"
            + "airplaneRestoreWifi=%s\\n"
            + "airplaneRestoreBt=%s\\n"
            + "showHiddenWifi=%s\\n' \"$@\" > \"$out\"";
        const values = [
            root.maxWorkspaces,
            root.showVolumePercent ? "1" : "0",
            root.showBrightnessPercent ? "1" : "0",
            root.showExtraDimPercent ? "1" : "0",
            root.showBluetoothPercent ? "1" : "0",
            root.showBatteryPercent ? "1" : "0",
            root.showTemps ? "1" : "0",
            root.unifiedPanels ? "1" : "0",
            root.hotspotAutoOff ? "1" : "0",
            root.hotspotMinutes,
            root.wifiAutoOff ? "1" : "0",
            root.wifiMinutes,
            root.btAutoOff ? "1" : "0",
            root.btMinutes,
            root.centerRows,
            root.centerIconSize,
            root.micShortcut,
            root.barIconSize,
            root.autoHideBar ? "1" : "0",
            root.themeMode,
            root.accentColor,
            root.systemTheme ? "1" : "0",
            root.glassTransparency,
            root.glassBlur,
            root.glassBlurBehind ? "1" : "0",
            root.keyboardLayout,
            root.workspaceModeDefault,
            root.workspaceModes,
            root.workspaceModeChosen ? "1" : "0",
            root.nativeTitlebar,
            root.lockMinutes,
            root.windowChrome,
            root.wallpaperPath,
            root.barPosition,
            root.musicWidth,
            root.superHoldMs,
            root.floatingSizePercent,
            root.floatingCascade,
            BarState.controls.join(","),
            BarState.centerOrder.join(","),
            root.wallpaperColor,
            root.weatherPlace,
            root.airplaneMode ? "1" : "0",
            root.airplaneRestoreWifi ? "1" : "0",
            root.airplaneRestoreBt ? "1" : "0",
            root.showHiddenWifi ? "1" : "0"
        ];
        saveProc.command = ["sh", "-c", format, "shell", root.path].concat(values);
        saveProc.running = true;
    }

    // El orden de los controles vive en BarState, no en este singleton. Se
    // guarda cuando cambia, igual que cualquier otro ajuste.
    Connections {
        target: BarState

        function onControlsChanged(): void {
            if (root.ready)
                saveTimer.restart();
        }

        function onCenterOrderChanged(): void {
            if (root.ready)
                saveTimer.restart();
        }
    }

    onMaxWorkspacesChanged: saveTimer.restart()
    onCenterRowsChanged: saveTimer.restart()
    onCenterIconSizeChanged: saveTimer.restart()
    onBarIconSizeChanged: saveTimer.restart()
    onAutoHideBarChanged: saveTimer.restart()
    onBarPositionChanged: saveTimer.restart()
    onMusicWidthChanged: saveTimer.restart()
    onSuperHoldMsChanged: saveTimer.restart()
    onFloatingSizePercentChanged: saveTimer.restart()
    onFloatingCascadeChanged: saveTimer.restart()
    onShowVolumePercentChanged: saveTimer.restart()
    onShowBrightnessPercentChanged: saveTimer.restart()
    onShowExtraDimPercentChanged: saveTimer.restart()
    onShowBluetoothPercentChanged: saveTimer.restart()
    onShowBatteryPercentChanged: saveTimer.restart()
    onShowTempsChanged: saveTimer.restart()
    onUnifiedPanelsChanged: saveTimer.restart()
    onWorkspaceModeDefaultChanged: saveTimer.restart()
    onWorkspaceModesChanged: saveTimer.restart()
    onWorkspaceModeChosenChanged: saveTimer.restart()
    onNativeTitlebarChanged: saveTimer.restart()
    onWindowChromeChanged: saveTimer.restart()
    onWallpaperPathChanged: saveTimer.restart()
    onWeatherPlaceChanged: saveTimer.restart()
    onThemeModeChanged: {
        saveTimer.restart();
        root.requestSystemTheme();
    }
    onAccentColorChanged: {
        saveTimer.restart();
        root.requestSystemTheme();
    }
    onSystemThemeChanged: {
        saveTimer.restart();
        if (root.systemTheme)
            root.requestSystemTheme();
    }
    onGlassTransparencyChanged: saveTimer.restart()
    onGlassBlurChanged: {
        saveTimer.restart();
        if (root.ready)
            glassApplyTimer.restart();
    }
    onGlassBlurBehindChanged: {
        saveTimer.restart();
        if (root.ready)
            glassModeApplyTimer.restart();
    }
    onKeyboardLayoutChanged: {
        saveTimer.restart();
        root.applyKeyboardLayout();
    }
    onMicShortcutChanged: {
        saveTimer.restart();
        root.applyMicShortcut();
    }
    onHotspotAutoOffChanged: saveTimer.restart()
    onHotspotMinutesChanged: saveTimer.restart()
    onWifiAutoOffChanged: saveTimer.restart()
    onWifiMinutesChanged: saveTimer.restart()
    onBtAutoOffChanged: saveTimer.restart()
    onBtMinutesChanged: saveTimer.restart()
    onAirplaneModeChanged: saveTimer.restart()
    onAirplaneRestoreWifiChanged: saveTimer.restart()
    onAirplaneRestoreBtChanged: saveTimer.restart()
    onShowHiddenWifiChanged: saveTimer.restart()
    onLockMinutesChanged: {
        saveTimer.restart();
        root.applyIdle();
    }

    // En los singletons de Quickshell no hay Component.onCompleted fiable.
    Timer {
        interval: 60
        running: true
        repeat: false
        onTriggered: loadProc.running = true
    }

    Timer {
        id: saveTimer
        interval: 140
        repeat: false
        onTriggered: root.write()
    }

    Timer {
        id: glassApplyTimer
        interval: 260
        repeat: false
        onTriggered: root.applyGlassBlur()
    }

    Timer {
        id: glassModeApplyTimer
        interval: 180
        repeat: false
        onTriggered: root.applyGlassMode()
    }

    Timer {
        id: themeTimer
        interval: 220
        repeat: false
        onTriggered: root.applySystemTheme()
    }

    Process {
        id: themeProc

        onExited: {
            if (root.themeApplyPending) {
                root.themeApplyPending = false;
                root.applySystemTheme();
            }
        }
    }

    Process {
        id: glassProc

        onExited: {
            if (root.glassApplyPending) {
                root.glassApplyPending = false;
                root.applyGlassBlur();
            }
        }
    }

    Process {
        id: glassModeProc

        onExited: {
            if (root.glassModeApplyPending) {
                root.glassModeApplyPending = false;
                root.applyGlassMode();
            }
        }
    }

    Process {
        id: loadProc

        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "shell", root.path]

        stdout: StdioCollector {
            id: loadOut
        }

        onExited: {
            const lines = loadOut.text.split("\n");
            let max = root.maxWorkspaces;
            let rows = root.centerRows;
            let iconSize = root.centerIconSize;
            let barIcon = root.barIconSize;
            let autoHide = root.autoHideBar;
            let barPos = root.barPosition;
            let music = root.musicWidth;
            let superHold = root.superHoldMs;
            let floatingSize = root.floatingSizePercent;
            let floatingStep = root.floatingCascade;
            let pctVolume = root.showVolumePercent;
            let pctBrightness = root.showBrightnessPercent;
            let pctExtraDim = root.showExtraDimPercent;
            let pctBluetooth = root.showBluetoothPercent;
            let pctBattery = root.showBatteryPercent;
            let temps = root.showTemps;
            let unified = root.unifiedPanels;
            let mode = root.themeMode;
            let accent = root.accentColor;
            let sysTheme = root.systemTheme;
            let glassPct = root.glassTransparency;
            let glassRadius = root.glassBlur;
            let glassBehind = root.glassBlurBehind;
            let layout = root.keyboardLayout;
            let shortcut = root.micShortcut;
            let hotspotOff = root.hotspotAutoOff;
            let hotspotMin = root.hotspotMinutes;
            let wifiOff = root.wifiAutoOff;
            let wifiMin = root.wifiMinutes;
            let btOff = root.btAutoOff;
            let btMin = root.btMinutes;
            let wsModeDefault = root.workspaceModeDefault;
            let wsModes = root.workspaceModes;
            let wsModeChosen = root.workspaceModeChosen;
            let titlebar = root.nativeTitlebar;
            let lock = root.lockMinutes;
            let chromeStyle = root.windowChrome;
            let wallpaper = root.wallpaperPath;
            let wallpaperColor = root.wallpaperColor;
            let weatherPlace = root.weatherPlace;
            let airplane = root.airplaneMode;
            let airplaneWifi = root.airplaneRestoreWifi;
            let airplaneBt = root.airplaneRestoreBt;
            let hiddenWifi = root.showHiddenWifi;
            let controlsOrder = "";
            let centerOrderText = "";
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                const eq = line.indexOf("=");
                if (eq <= 0)
                    continue;
                const key = line.slice(0, eq);
                const value = line.slice(eq + 1);
                if (key === "maxWorkspaces") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        max = Math.max(1, Math.min(20, parsed));
                } else if (key === "showVolumePercent") {
                    pctVolume = value === "1" || value === "true";
                } else if (key === "showBrightnessPercent") {
                    pctBrightness = value === "1" || value === "true";
                } else if (key === "showExtraDimPercent") {
                    pctExtraDim = value === "1" || value === "true";
                } else if (key === "showBluetoothPercent") {
                    pctBluetooth = value === "1" || value === "true";
                } else if (key === "showBatteryPercent") {
                    pctBattery = value === "1" || value === "true";
                } else if (key === "centerRows") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        rows = Math.max(2, Math.min(8, parsed));
                } else if (key === "centerIconSize") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        iconSize = Math.max(12, Math.min(32, parsed));
                } else if (key === "barIconSize") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        barIcon = Math.max(12, Math.min(26, parsed));
                } else if (key === "autoHideBar") {
                    autoHide = value === "1" || value === "true";
                } else if (key === "barPosition") {
                    barPos = value === "arriba" || value === "izquierda"
                        || value === "derecha" ? value : "abajo";
                } else if (key === "musicWidth") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        music = parsed <= 0
                            ? 0 : Math.max(140, Math.min(420, parsed));
                } else if (key === "superHoldMs") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        superHold = Math.max(100, Math.min(1000, parsed));
                } else if (key === "floatingSizePercent") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        floatingSize = Math.max(40, Math.min(80, parsed));
                } else if (key === "floatingCascade") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        floatingStep = Math.max(0, Math.min(96, parsed));
                } else if (key === "micShortcut") {
                    shortcut = value;
                } else if (key === "showTemps") {
                    temps = value === "1" || value === "true";
                } else if (key === "unifiedPanels") {
                    unified = value === "1" || value === "true";
                } else if (key === "themeMode") {
                    mode = value === "light" ? "light" : "dark";
                } else if (key === "accentColor") {
                    if (/^#[0-9a-fA-F]{6}$/.test(value))
                        accent = value.toLowerCase();
                } else if (key === "systemTheme") {
                    sysTheme = value === "1" || value === "true";
                } else if (key === "glassTransparency") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        glassPct = Math.max(0, Math.min(90, parsed));
                } else if (key === "glassBlur") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        glassRadius = Math.max(0, Math.min(40, parsed));
                } else if (key === "glassBlurBehind") {
                    glassBehind = value === "1" || value === "true";
                } else if (key === "keyboardLayout") {
                    if (/^[a-z0-9_]+$/.test(value))
                        layout = value;
                } else if (key === "hotspotAutoOff") {
                    hotspotOff = value === "1" || value === "true";
                } else if (key === "hotspotMinutes") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        hotspotMin = Math.max(1, Math.min(120, parsed));
                } else if (key === "wifiAutoOff") {
                    wifiOff = value === "1" || value === "true";
                } else if (key === "wifiMinutes") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        wifiMin = Math.max(1, Math.min(120, parsed));
                } else if (key === "btAutoOff") {
                    btOff = value === "1" || value === "true";
                } else if (key === "btMinutes") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        btMin = Math.max(1, Math.min(120, parsed));
                } else if (key === "workspaceModeDefault") {
                    wsModeDefault = value === "mosaic" ? "mosaic" : "floating";
                } else if (key === "workspaceModes") {
                    wsModes = value;
                } else if (key === "workspaceModeChosen") {
                    wsModeChosen = value === "1" || value === "true";
                } else if (key === "nativeTitlebar") {
                    if (value === "always" || value === "never"
                            || value === "auto")
                        titlebar = value;
                } else if (key === "lockMinutes") {
                    const parsed = parseInt(value, 10);
                    if (!isNaN(parsed))
                        lock = Math.max(0, Math.min(120, parsed));
                } else if (key === "windowChrome") {
                    if (value === "floating" || value === "integrated")
                        chromeStyle = value;
                } else if (key === "wallpaperPath") {
                    wallpaper = value;
                } else if (key === "wallpaperColor") {
                    if (/^#[0-9a-fA-F]{6}$/.test(value))
                        wallpaperColor = value.toLowerCase();
                } else if (key === "weatherPlace") {
                    weatherPlace = value.slice(0, 80);
                } else if (key === "airplaneMode") {
                    airplane = value === "1" || value === "true";
                } else if (key === "airplaneRestoreWifi") {
                    airplaneWifi = value === "1" || value === "true";
                } else if (key === "airplaneRestoreBt") {
                    airplaneBt = value === "1" || value === "true";
                } else if (key === "showHiddenWifi") {
                    hiddenWifi = value === "1" || value === "true";
                } else if (key === "barControls") {
                    controlsOrder = value;
                } else if (key === "centerOrder") {
                    centerOrderText = value;
                }
            }
            root.maxWorkspaces = max;
            root.centerRows = rows;
            root.centerIconSize = iconSize;
            root.barIconSize = barIcon;
            root.autoHideBar = autoHide;
            root.barPosition = barPos;
            root.musicWidth = music;
            root.superHoldMs = superHold;
            root.floatingSizePercent = floatingSize;
            root.floatingCascade = floatingStep;
            root.showVolumePercent = pctVolume;
            root.showBrightnessPercent = pctBrightness;
            root.showExtraDimPercent = pctExtraDim;
            root.showBluetoothPercent = pctBluetooth;
            root.showBatteryPercent = pctBattery;
            root.showTemps = temps;
            root.unifiedPanels = unified;
            root.themeMode = mode;
            root.accentColor = accent;
            root.systemTheme = sysTheme;
            root.glassTransparency = glassPct;
            root.glassBlur = glassRadius;
            root.glassBlurBehind = glassBehind;
            root.keyboardLayout = layout;
            root.hotspotAutoOff = hotspotOff;
            root.hotspotMinutes = hotspotMin;
            root.wifiAutoOff = wifiOff;
            root.wifiMinutes = wifiMin;
            root.btAutoOff = btOff;
            root.btMinutes = btMin;
            root.workspaceModeDefault = wsModeDefault;
            root.workspaceModes = wsModes;
            root.workspaceModeChosen = wsModeChosen;
            root.nativeTitlebar = titlebar;
            root.lockMinutes = lock;
            root.micShortcut = shortcut;
            root.windowChrome = chromeStyle;
            root.wallpaperPath = wallpaper;
            root.wallpaperColor = wallpaperColor;
            root.weatherPlace = weatherPlace;
            root.airplaneMode = airplane;
            root.airplaneRestoreWifi = airplaneWifi;
            root.airplaneRestoreBt = airplaneBt;
            root.showHiddenWifi = hiddenWifi;
            BarState.restore(controlsOrder, centerOrderText);
            root.ready = true;
            root.applyWindowChrome();
            root.applySuperHoldDelay();
            root.applyFloatingDefaults();
            root.applyGlassBlur();
            root.applyGlassMode();
            root.applyMicShortcut();
            root.applyKeyboardLayout();
            root.applyIdle();
            root.requestShellTheme();
            root.applySystemTheme();
        }
    }

    // Evita escribir y recargar el compositor en cada clic del ajuste.
    Timer {
        id: holdApplyTimer
        interval: 220
        repeat: false
        onTriggered: root.applySuperHoldDelay()
    }

    Timer {
        id: floatingApplyTimer
        interval: 220
        repeat: false
        onTriggered: root.applyFloatingDefaults()
    }

    Process {
        id: saveProc
    }

    Process {
        id: floatingProc

        onExited: {
            if (root.floatingApplyPending) {
                root.floatingApplyPending = false;
                root.applyFloatingDefaults();
            }
        }
    }

    Process {
        id: superHoldProc

        onExited: {
            if (root.holdApplyPending) {
                root.holdApplyPending = false;
                root.applySuperHoldDelay();
            }
        }
    }

    Process {
        id: shortcutProc
    }

    Process {
        id: chromeProc

        onExited: {
            if (root.chromeApplyPending) {
                root.chromeApplyPending = false;
                root.applyWindowChrome();
            }
        }
    }

    Process {
        id: wallpaperProc

        stdout: StdioCollector {
            id: wallpaperPickOut
        }

        onExited: (code) => {
            if (code !== 0)
                return;
            const path = String(wallpaperPickOut.text || "").trim();
            if (path.length > 0)
                root.setWallpaperPath(path);
        }
    }
}
