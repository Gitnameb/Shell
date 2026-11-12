pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Brillo, atenuación extra y luz nocturna. El brillo intenta controlar el
// monitor de verdad con DDC/CI (`ddcutil`); si no hay monitor compatible o
// faltan permisos, cae al filtro nativo del compositor. Umbriel aplica la
// atenuación extra y la luz nocturna en su propia escena, por encima de la
// barra y de las ventanas.
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
    readonly property string statePath: Quickshell.env("HOME")
        + "/.config/shell/display.conf"

    // Brillo real del monitor por DDC/CI. `hardwareAvailable` solo se pone a
    // true cuando `ddcutil` responde; el resto del archivo funciona igual sin
    // él, usando el filtro como respaldo.
    property bool hardwareAvailable: false
    property bool hardwareChecked: false
    property int hardwareMax: 100
    property int hardwareValue: 100
    property bool writingHardware: false
    property bool writePending: false
    // Valor que se envió al monitor en la escritura en curso. No se usa el
    // brillo actual al terminar porque puede haber cambiado mientras ddcutil
    // trabajaba: entonces la escritura pendiente se saltaría por creer que ya
    // estaba aplicada y el monitor se quedaría en el valor anterior.
    property int writtenHardwareValue: -1
    // Mientras se lee el valor del monitor no se escribe de vuelta.
    property bool applyingRead: false
    property int detectAttempts: 0

    // Brillo del panel interno (portátiles). Se lee de /sys/class/backlight;
    // se escribe con brightnessctl cuando haga falta permiso. Si falla, el
    // filtro nativo sigue funcionando como respaldo.
    property bool backlightAvailable: false
    property bool backlightChecked: false
    property string backlightDevice: ""
    property int backlightMax: 100
    property int backlightValue: 100
    property bool writingBacklight: false
    property bool backlightWritePending: false

    readonly property bool filterActive: root.extraDim > 0.005
        || root.nightLight
        || (!root.hardwareAvailable && !root.backlightAvailable
            && root.brightness < 0.995)

    // Filtro nativo de Umbriel: cubre toda la salida, incluida la barra, y
    // multiplica el color en vez de superponer un velo.
    readonly property bool nativeDisplayFilter:
        CompositorState.supports("displayFilter")
    readonly property string displayFilterScript: (Quickshell.shellDir || "")
        + "/scripts/shell-display-filter"
    readonly property string brightnessScript: (Quickshell.shellDir || "")
        + "/scripts/shell-brightness"

    onBrightnessChanged: {
        // Al leer el valor real del monitor no se devuelve la escritura.
        if (root.applyingRead)
            return;
        if (root.hardwareAvailable) {
            // Escritura adelantada: el primer cambio empieza a contar ya y los
            // cambios que lleguen mientras ddcutil trabaja se agrupan en una
            // sola escritura final. Antes se reiniciaba el temporizador con
            // cada pulsación y el monitor se quedaba atrás.
            if (!writeTimer.running)
                writeTimer.start();
        } else if (root.backlightAvailable) {
            backlightWriteTimer.restart();
        } else {
            root.schedule();
        }
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
    onBacklightAvailableChanged: root.schedule()

    // En los singletons de Quickshell no se usa Component.onCompleted: un
    // temporizador corto arranca la detección y limpia filtros viejos.
    Timer {
        interval: 80
        running: true
        repeat: false
        onTriggered: {
            root.detectHardware();
            root.detectBacklight();
        }
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
            "shell", root.statePath,
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
            "shell", root.statePath]

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
        root.backlightAvailable = false;
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
        root.writtenHardwareValue = value;
        writeProc.command = ["sudo", "-n", "ddcutil", "setvcp", "10",
            String(value), "--sleep-multiplier", "1.5"];
        writeProc.running = true;
    }

    Timer {
        id: writeTimer
        interval: 90
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
                root.detectBacklight();
                root.schedule();
                return;
            }
            // Ya manda el monitor: el filtro nativo solo queda para la
            // atenuación extra y la luz nocturna.
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
            // Se anota el valor que de verdad se escribió, no el brillo actual:
            // si el usuario cambió mientras ddcutil trabajaba, la escritura
            // pendiente debe seguir viendo el monitor desfasado y aplicarse.
            if (code === 0 && root.writtenHardwareValue >= 0)
                root.hardwareValue = root.writtenHardwareValue;
            if (root.writePending) {
                root.writePending = false;
                Qt.callLater(root.writeHardware);
            }
        }
    }

    // ddcutil no avisa cuando el brillo se cambia con los botones del monitor,
    // así que se relee de vez en cuando. Cada lectura cuesta ~200 ms y bloquea
    // el bus I2C del monitor, que en pleno juego se nota como microtirones: se
    // relee cada 30 s y se salta mientras hay una ventana a pantalla completa.
    // La lectura también se salta mientras el shell escribe o detecta, para no
    // pisar el deslizador.
    Timer {
        id: hardwareReadTimer
        interval: 30000
        repeat: true
        running: root.hardwareAvailable
        onTriggered: {
            if (root.writingHardware || writeTimer.running
                    || root.applyingRead || queryProc.running
                    || readProc.running
                    || CompositorState.hasFullscreenWindow)
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

    // ------------------------------------------------------- panel interno
    function detectBacklight(): void {
        if (root.hardwareAvailable || root.backlightAvailable
                || backlightProc.running)
            return;
        backlightProc.command = ["sh", root.brightnessScript, "status"];
        backlightProc.running = true;
    }

    function parseBacklight(line: string): void {
        if (root.hardwareAvailable)
            return;
        const parts = String(line).trim().split(/\s+/);
        if (parts.length < 3)
            return;
        const value = parseInt(parts[1], 10);
        const max = parseInt(parts[2], 10);
        if (isNaN(value) || isNaN(max) || max <= 0)
            return;
        root.backlightDevice = String(parts[0]);
        root.backlightMax = max;
        root.backlightValue = value;
        root.backlightAvailable = true;
        root.backlightChecked = true;
        root.applyingRead = true;
        root.brightness = Math.max(0.0, Math.min(1.0, value / max));
        root.applyingRead = false;
        root.applyNow();
    }

    function writeBacklight(): void {
        if (!root.backlightAvailable)
            return;
        if (backlightWriteProc.running) {
            root.backlightWritePending = true;
            return;
        }
        root.writingBacklight = true;
        backlightWriteProc.command = ["sh", root.brightnessScript, "set",
            String(Math.round(root.brightness * 100))];
        backlightWriteProc.running = true;
    }

    Timer {
        id: backlightWriteTimer
        interval: 160
        repeat: false
        onTriggered: root.writeBacklight()
    }

    Process {
        id: backlightProc

        stdout: SplitParser {
            onRead: (line) => root.parseBacklight(line)
        }

        onExited: (code) => {
            root.backlightChecked = true;
            if (code !== 0) {
                root.backlightAvailable = false;
                root.schedule();
            }
        }
    }

    Process {
        id: backlightWriteProc

        onExited: (code) => {
            root.writingBacklight = false;
            if (code === 0) {
                root.backlightValue = Math.round(
                    root.brightness * root.backlightMax);
            } else {
                // brightnessctl no está o falta el permiso: el filtro nativo
                // recupera el control sin dejar el brillo bloqueado.
                root.backlightAvailable = false;
                root.schedule();
            }
            if (root.backlightWritePending) {
                root.backlightWritePending = false;
                Qt.callLater(root.writeBacklight);
            }
        }
    }

    // El brillo puede cambiar con las teclas del portátil; se relee igual que
    // el monitor externo, sin pisar el deslizador mientras se escribe.
    Timer {
        id: backlightReadTimer
        interval: 3000
        repeat: true
        running: root.backlightAvailable
        onTriggered: {
            if (root.writingBacklight || backlightWriteTimer.running
                    || root.applyingRead || backlightProc.running)
                return;
            backlightReadProc.running = true;
        }
    }

    Process {
        id: backlightReadProc

        command: ["sh", root.brightnessScript, "status"]

        stdout: SplitParser {
            onRead: (line) => {
                const parts = String(line).trim().split(/\s+/);
                if (parts.length < 3)
                    return;
                const value = parseInt(parts[1], 10);
                const max = parseInt(parts[2], 10);
                if (isNaN(value) || isNaN(max) || max <= 0)
                    return;
                if (Math.abs(value - root.backlightValue) < 1)
                    return;
                root.backlightMax = max;
                root.backlightValue = value;
                root.applyingRead = true;
                root.brightness = Math.max(0.0,
                    Math.min(1.0, value / max));
                root.applyingRead = false;
            }
        }
    }

    function applyNow(): void {
        if (root.nativeDisplayFilter)
            root.applyNativeFilter();
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
        const brightness = root.hardwareAvailable || root.backlightAvailable
            ? "1.000" : root.brightness.toFixed(3);
        const dim = root.extraDim.toFixed(3);
        const warm = root.nightLight
            ? root.nightStrength.toFixed(3) : "0.000";
        nativeProc.command = [root.displayFilterScript,
            brightness, dim, warm];
        nativeProc.running = true;
    }

    property bool nativePending: false

    Timer {
        id: applyTimer
        interval: 90
        repeat: false
        onTriggered: root.applyNow()
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
