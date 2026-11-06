pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Brillo, atenuación extra y luz nocturna. El brillo intenta controlar el
// monitor de verdad con DDC/CI (`ddcutil`); si no hay monitor compatible o
// faltan permisos, cae al filtro del compositor de siempre. En Hyprland la
// atenuación extra y la luz nocturna usan `decoration:screen_shader`; en los
// demás compositores (Umbriel) se dibuja una capa click-through
// (`DisplayFilter.qml`).
Singleton {
    id: root

    // Brillo general (1.0 = sin filtro).
    property real brightness: 1.0
    // Atenuación adicional sobre el brillo (0.0 = desactivada).
    property real extraDim: 0.0
    // Valor que se recupera al volver a activar la atenuación extra.
    property real extraDimLevel: 0.5
    property bool nightLight: false
    property real nightStrength: 0.5

    // Preferencias propias del filtro. Se guardan aparte para que al reiniciar
    // el shell no vuelvan a 0 % ni a los valores iniciales.
    property bool displayReady: false
    readonly property string statePath: (Quickshell.env("HOME") || "/home/username")
        + "/.config/alba/display.conf"

    // Brillo real del monitor por DDC/CI. `hardwareAvailable` solo se pone a
    // true cuando `ddcutil` responde; el resto del archivo funciona igual sin
    // él, usando el filtro como respaldo.
    property bool hardwareAvailable: false
    property bool hardwareChecked: false
    property int hardwareMax: 100
    property int hardwareValue: 100
    property bool writingHardware: false
    property bool writePending: false
    // Mientras se lee el valor del monitor no se escribe de vuelta.
    property bool applyingRead: false
    property int detectAttempts: 0

    readonly property bool filterActive: root.extraDim > 0.005
        || root.nightLight
        || (!root.hardwareAvailable && root.brightness < 0.995)

    // Filtro para compositores sin shader global (Umbriel).
    readonly property bool overlayFilter:
        !CompositorState.supports("screenShader")
            && !CompositorState.supports("displayFilter")
    // Filtro nativo de Umbriel: cubre toda la salida, incluida la barra, y
    // multiplica el color en vez de superponer un velo.
    readonly property bool nativeDisplayFilter:
        CompositorState.supports("displayFilter")
    // Opacidad del velo negro. Con brillo por hardware solo cuenta la
    // atenuación extra; sin él, el brillo también se aplica aquí.
    readonly property real overlayDark: Math.min(1, Math.max(0, 1
        - (root.hardwareAvailable ? 1 : root.brightness)
            * (1 - root.extraDim)))
    readonly property real overlayWarm: root.nightLight
        ? Math.max(0, Math.min(1, root.nightStrength)) * 0.3 : 0

    readonly property string shaderPath: (Quickshell.env("HOME") || "/home/username")
        + "/.config/alba/display.frag"
    readonly property string displayFilterScript: (Quickshell.shellDir || "")
        + "/scripts/alba-display-filter"

    onBrightnessChanged: {
        // Al leer el valor real del monitor no se devuelve la escritura.
        if (root.applyingRead)
            return;
        if (root.hardwareAvailable)
            writeTimer.restart();
        else
            root.schedule();
    }
    onExtraDimChanged: {
        root.schedule();
        stateSaveTimer.restart();
    }
    onExtraDimLevelChanged: stateSaveTimer.restart()
    onNightLightChanged: {
        root.schedule();
        stateSaveTimer.restart();
    }
    onNightStrengthChanged: {
        root.schedule();
        stateSaveTimer.restart();
    }
    onHardwareAvailableChanged: root.schedule()

    // En los singletons de Quickshell no se usa Component.onCompleted: un
    // temporizador corto arranca la detección y limpia filtros viejos.
    Timer {
        interval: 80
        running: true
        repeat: false
        onTriggered: root.detectHardware()
    }

    function setBrightness(value: real): void {
        root.brightness = Math.max(0.0, Math.min(1.0, value));
        OsdState.showBrightness(root.brightness);
    }

    function setExtraDim(value: real): void {
        root.extraDim = Math.max(0.0, Math.min(0.8, value));
        if (root.extraDim > 0.01)
            root.extraDimLevel = root.extraDim;
        OsdState.showExtraDim(root.extraDim);
    }

    function setNightStrength(value: real): void {
        root.nightStrength = Math.max(0.0, Math.min(1.0, value));
        OsdState.showNight(root.nightLight ? root.nightStrength : 0);
    }

    function toggleNight(): void {
        root.nightLight = !root.nightLight;
        OsdState.showNight(root.nightLight ? root.nightStrength : 0);
    }

    function toggleExtraDim(): void {
        root.extraDim = root.extraDim > 0.01 ? 0 : root.extraDimLevel;
        OsdState.showExtraDim(root.extraDim);
    }

    // --------------------------------------------------- preferencias
    function writeState(): void {
        if (!root.displayReady)
            return;
        stateSaveProc.command = [
            "sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf 'extraDim=%s\\nextraDimLevel=%s\\nnightLight=%s\\nnightStrength=%s\\n' "
                + "\"$2\" \"$3\" \"$4\" \"$5\" > \"$1\"",
            "alba", root.statePath,
            root.extraDim.toFixed(3),
            root.extraDimLevel.toFixed(3),
            root.nightLight ? "1" : "0",
            root.nightStrength.toFixed(3)
        ];
        stateSaveProc.running = true;
    }

    Timer {
        id: stateSaveTimer
        interval: 160
        repeat: false
        onTriggered: root.writeState()
    }

    // Se lee un poco después de la detección del monitor para no pisar el
    // brillo real con los valores guardados.
    Timer {
        interval: 130
        running: true
        repeat: false
        onTriggered: stateLoadProc.running = true
    }

    Process {
        id: stateLoadProc

        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true",
            "alba", root.statePath]

        stdout: StdioCollector {
            id: stateLoadOut
        }

        onExited: {
            const lines = stateLoadOut.text.split("\n");
            let extra = root.extraDim;
            let level = root.extraDimLevel;
            let night = root.nightLight;
            let strength = root.nightStrength;
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                const eq = line.indexOf("=");
                if (eq <= 0)
                    continue;
                const key = line.slice(0, eq);
                const value = line.slice(eq + 1);
                if (key === "extraDim") {
                    const parsed = parseFloat(value);
                    if (!isNaN(parsed))
                        extra = Math.max(0.0, Math.min(0.8, parsed));
                } else if (key === "extraDimLevel") {
                    const parsed = parseFloat(value);
                    if (!isNaN(parsed))
                        level = Math.max(0.05, Math.min(0.8, parsed));
                } else if (key === "nightLight") {
                    night = value === "1" || value === "true";
                } else if (key === "nightStrength") {
                    const parsed = parseFloat(value);
                    if (!isNaN(parsed))
                        strength = Math.max(0.0, Math.min(1.0, parsed));
                }
            }
            root.extraDimLevel = level;
            root.extraDim = extra;
            root.nightStrength = strength;
            root.nightLight = night;
            root.displayReady = true;
            root.schedule();
        }
    }

    Process {
        id: stateSaveProc
    }

    function schedule(): void {
        // Throttle, not debounce: the first change starts the timer and later
        // changes during a drag reuse it, so the filter follows the slider
        // without a config write per pixel.
        if (applyTimer.running)
            return;
        applyTimer.start();
    }

    // ------------------------------------------------------------- DDC/CI
    function detectHardware(): void {
        if (queryProc.running)
            return;
        queryProc.running = true;
    }

    function parseVcp(line: string): void {
        const parts = String(line).trim().split(/\s+/);
        if (parts.length < 5 || parts[0] !== "VCP" || parts[1] !== "10")
            return;
        const current = parseInt(parts[3], 10);
        const max = parseInt(parts[4], 10);
        if (isNaN(current) || isNaN(max) || max <= 0)
            return;
        root.hardwareAvailable = true;
        root.hardwareMax = max;
        root.hardwareValue = current;
        root.applyingRead = true;
        root.brightness = Math.max(0.0, Math.min(1.0, current / max));
        root.applyingRead = false;
    }

    function writeHardware(): void {
        if (!root.hardwareAvailable)
            return;
        if (writeProc.running) {
            root.writePending = true;
            return;
        }
        const value = Math.round(root.brightness * root.hardwareMax);
        if (value === root.hardwareValue)
            return;
        root.writingHardware = true;
        writeProc.command = ["sudo", "-n", "ddcutil", "setvcp", "10",
            String(value), "--sleep-multiplier", "1.5"];
        writeProc.running = true;
    }

    Timer {
        id: writeTimer
        interval: 160
        repeat: false
        onTriggered: root.writeHardware()
    }

    Process {
        id: queryProc

        command: ["sudo", "-n", "ddcutil", "getvcp", "10", "--terse"]

        stdout: SplitParser {
            onRead: (line) => root.parseVcp(line)
        }

        onExited: (code) => {
            root.hardwareChecked = true;
            // La primera lectura de algunos monitores devuelve 0 aunque estén
            // a pleno brillo. Se confirma una vez antes de creerla.
            if (root.detectAttempts === 0) {
                root.detectAttempts = 1;
                verifyTimer.restart();
                return;
            }
            if (!root.hardwareAvailable) {
                root.hardwareAvailable = false;
                root.schedule();
                return;
            }
            // Ya manda el monitor: el shader solo queda para atenuación y
            // luz nocturna.
            root.applyNow();
        }
    }

    Timer {
        id: verifyTimer
        interval: 450
        repeat: false
        onTriggered: root.detectHardware()
    }

    Process {
        id: writeProc

        onExited: (code) => {
            root.writingHardware = false;
            if (code === 0)
                root.hardwareValue = Math.round(
                    root.brightness * root.hardwareMax);
            if (root.writePending) {
                root.writePending = false;
                Qt.callLater(root.writeHardware);
            }
        }
    }

    // ddcutil no avisa cuando el brillo se cambia con los botones del monitor,
    // así que se relee cada pocos segundos. La lectura se salta mientras el
    // shell escribe o está detectando, para no pisar el deslizador.
    Timer {
        id: hardwareReadTimer
        interval: 3000
        repeat: true
        running: root.hardwareAvailable
        onTriggered: {
            if (root.writingHardware || writeTimer.running
                    || root.applyingRead || queryProc.running
                    || readProc.running)
                return;
            readProc.running = true;
        }
    }

    Process {
        id: readProc

        command: ["sh", "-c",
            "exec sudo -n ddcutil getvcp 10 --terse 2>/dev/null"]

        stdout: SplitParser {
            onRead: (line) => {
                const parts = String(line).trim().split(/\s+/);
                if (parts.length < 5 || parts[0] !== "VCP"
                        || parts[1] !== "10")
                    return;
                const current = parseInt(parts[3], 10);
                const max = parseInt(parts[4], 10);
                if (isNaN(current) || isNaN(max) || max <= 0)
                    return;
                root.hardwareMax = max;
                // Un cambio de una unidad puede ser ruido del monitor; se
                // aplica en cuanto se nota una diferencia real.
                if (Math.abs(current - root.hardwareValue) < 1)
                    return;
                root.hardwareValue = current;
                root.applyingRead = true;
                root.brightness = Math.max(0.0,
                    Math.min(1.0, current / max));
                root.applyingRead = false;
            }
        }
    }

    // -------------------------------------------------------------- shader
    function shaderSource(): string {
        // Con brillo real el shader no oscurece: solo aplica atenuación y
        // temperatura. Sin DDC/CI el brillo vuelve a multiplicar la imagen.
        const b = root.hardwareAvailable ? "1.000" : root.brightness.toFixed(3);
        const d = root.extraDim.toFixed(3);
        const n = root.nightLight ? root.nightStrength.toFixed(3) : "0.000";
        return "#version 300 es\n"
            + "precision highp float;\n"
            + "in vec2 v_texcoord;\n"
            + "layout(location = 0) out vec4 fragColor;\n"
            + "uniform sampler2D tex;\n"
            + "\n"
            + "void main() {\n"
            + "    vec4 pixColor = texture(tex, v_texcoord);\n"
            + "    vec3 rgb = pixColor.rgb;\n"
            + "    vec3 warm = vec3(1.0, 0.78, 0.58);\n"
            + "    rgb = mix(rgb, rgb * warm, " + n + ");\n"
            + "    rgb *= " + b + " * (1.0 - " + d + ");\n"
            + "    fragColor = vec4(rgb, pixColor.a);\n"
            + "}\n";
    }

    function applyNow(): void {
        // Sin filtro de compositor, DisplayFilter.qml se actualiza solo.
        if (root.overlayFilter)
            return;
        if (root.nativeDisplayFilter) {
            root.applyNativeFilter();
            return;
        }
        if (applyProc.running) {
            root.pending = true;
            return;
        }

        let script = "";
        if (root.filterActive) {
            script = "mkdir -p \""
                + root.shaderPath.substring(0, root.shaderPath.lastIndexOf("/"))
                + "\"; cat > \"" + root.shaderPath + "\" <<'ALBA'\n"
                + root.shaderSource()
                + "ALBA\n"
                + "hyprctl keyword decoration:screen_shader \""
                + root.shaderPath + "\" >/dev/null 2>&1";
        } else {
            script = "hyprctl keyword decoration:screen_shader \"\" >/dev/null 2>&1;"
                + " rm -f \"" + root.shaderPath + "\"";
        }

        applyProc.command = ["sh", "-c", script];
        applyProc.running = true;
    }

    // Umbriel aplica el filtro en el compositor: cubre barra, paneles y
    // ventanas por igual. El script solo escribe [display] y recarga.
    function applyNativeFilter(): void {
        if (!root.displayReady)
            return;
        if (nativeProc.running) {
            root.nativePending = true;
            return;
        }
        const brightness = root.hardwareAvailable
            ? "1.000" : root.brightness.toFixed(3);
        const dim = root.extraDim.toFixed(3);
        const warm = root.nightLight
            ? root.nightStrength.toFixed(3) : "0.000";
        nativeProc.command = [root.displayFilterScript,
            brightness, dim, warm];
        nativeProc.running = true;
    }

    property bool pending: false
    property bool nativePending: false

    Timer {
        id: applyTimer
        interval: 90
        repeat: false
        onTriggered: root.applyNow()
    }

    Process {
        id: applyProc

        onExited: {
            if (!root.pending)
                return;
            root.pending = false;
            Qt.callLater(root.applyNow);
        }
    }

    Process {
        id: nativeProc

        onExited: {
            if (!root.nativePending)
                return;
            root.nativePending = false;
            Qt.callLater(root.applyNativeFilter);
        }
    }
}
