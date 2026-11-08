import Quickshell
import Quickshell.Wayland
import QtQuick

// Indicadores de redimensionado del modo ventanas. Mientras Super está
// mantenido (o fijado), dibuja encima de las ventanas:
//
//  · una línea en cada borde compartido entre mosaicos, para arrastrarlo;
//  · cuatro puntos en las esquinas de cada ventana flotante, que marcan dónde
//    empieza el redimensionado.
//
// La superficie no captura entrada: los clics siguen llegando a Umbriel, que
// es quien mueve o redimensiona. Son solo una pista visual, igual que en el
// mockup.
Variants {
    id: root

    model: Quickshell.screens

    delegate: PanelWindow {
        id: handleScreen

        required property var modelData

        readonly property int screenX: Number(handleScreen.modelData.x) || 0
        readonly property int screenY: Number(handleScreen.modelData.y) || 0
        readonly property int activeWorkspaceId:
            CompositorState.focusedWorkspace
                ? Number(CompositorState.focusedWorkspace.id) || 0 : 0

        // Al cambiar de escritorio las ventanas se animan hasta su hueco.
        // Dibujar las líneas mientras tanto las deja quietas sobre contenido
        // en movimiento, así que se ocultan hasta que la transición termina
        // (la animación del compositor dura unos 250 ms).
        property int previousWorkspaceId: 0
        property bool settling: false

        onActiveWorkspaceIdChanged: {
            if (activeWorkspaceId <= 0)
                return;
            if (previousWorkspaceId !== 0
                    && previousWorkspaceId !== activeWorkspaceId) {
                settling = true;
                settleTimer.restart();
            }
            previousWorkspaceId = activeWorkspaceId;
        }

        Component.onCompleted: previousWorkspaceId = activeWorkspaceId

        Timer {
            id: settleTimer
            interval: 320
            repeat: false
            onTriggered: handleScreen.settling = false
        }

        // Ventanas visibles de este monitor en el escritorio activo. Las
        // fijadas se muestran en todos los escritorios.
        readonly property var windows: {
            const list = CompositorState.windows || [];
            const out = [];
            for (let i = 0; i < list.length; i++) {
                const win = list[i];
                if (win.minimized === true || win.visible === false
                        || win.fullscreen === true
                        || Number(win.width) <= 0 || Number(win.height) <= 0
                        || (win.maximized === true
                            && win.floating === true))
                    continue;
                const screen = WindowLook.screenFor(win.monitor);
                if (screen
                        && String(screen.name) !== String(
                            handleScreen.modelData.name))
                    continue;
                if (Number(win.workspaceId) !== handleScreen.activeWorkspaceId
                        && win.pinned !== true)
                    continue;
                out.push(win);
            }
            return out;
        }

        readonly property var floatingWindows: {
            const list = handleScreen.windows;
            const out = [];
            for (let i = 0; i < list.length; i++) {
                if (list[i].floating === true)
                    out.push(list[i]);
            }
            return out;
        }

        // Solo la ventana flotante enfocada muestra los puntos: dibujar los de
        // una ventana tapada los dejaría flotando sobre la de delante.
        readonly property var focusedFloating: {
            const list = handleScreen.floatingWindows;
            for (let i = 0; i < list.length; i++) {
                if (list[i].focused === true)
                    return [list[i]];
            }
            return [];
        }

        readonly property var tiledWindows: {
            const list = handleScreen.windows;
            const out = [];
            for (let i = 0; i < list.length; i++) {
                if (list[i].floating !== true)
                    out.push(list[i]);
            }
            return out;
        }

        // Líneas entre mosaicos vecinos. Se dibuja una línea centrada en el
        // hueco cuando dos ventanas comparten un borde y se solapan lo
        // suficiente; el inset del 7 % imita al del mockup.
        readonly property var dividers: {
            const wins = handleScreen.tiledWindows;
            const out = [];
            const seen = ({});

            // Una ventana flotante por encima del mosaico tapa el divisor:
            // no debe dibujarse sobre su contenido.
            function covered(vertical, position, start, end) {
                const floats = handleScreen.floatingWindows;
                for (let i = 0; i < floats.length; i++) {
                    const win = floats[i];
                    const x = Number(win.x);
                    const y = Number(win.y);
                    const w = Number(win.width);
                    const h = Number(win.height);
                    if (vertical) {
                        if (position >= x - 6 && position <= x + w + 6
                                && end >= y && start <= y + h)
                            return true;
                    } else if (position >= y - 6 && position <= y + h + 6
                            && end >= x && start <= x + w) {
                        return true;
                    }
                }
                return false;
            }

            function add(vertical, position, start, end, key) {
                if (end - start < 48)
                    return;
                const inset = Math.max(6, Math.min(46, (end - start) * 0.07));
                const first = Math.round(start + inset);
                const last = Math.round(end - inset);
                if (last - first < 12 || seen[key] === true
                        || covered(vertical, position, first, last))
                    return;
                seen[key] = true;
                out.push({
                    vertical: vertical,
                    position: Math.round(position),
                    start: first,
                    end: last,
                    key: key
                });
            }

            for (let i = 0; i < wins.length; i++) {
                const a = wins[i];
                for (let j = i + 1; j < wins.length; j++) {
                    const b = wins[j];
                    const left = Number(a.x) <= Number(b.x) ? a : b;
                    const right = left === a ? b : a;
                    const gapX = Number(right.x)
                        - (Number(left.x) + Number(left.width));
                    const top = Math.max(Number(a.y), Number(b.y));
                    const bottom = Math.min(Number(a.y) + Number(a.height),
                        Number(b.y) + Number(b.height));
                    if (gapX >= -6 && gapX <= 32 && bottom - top > 60) {
                        const mid = (Number(left.x) + Number(left.width)
                            + Number(right.x)) / 2;
                        add(true, mid, top, bottom,
                            "v" + Math.round(mid) + ":" + Math.round(top));
                    }

                    const upper = Number(a.y) <= Number(b.y) ? a : b;
                    const lower = upper === a ? b : a;
                    const gapY = Number(lower.y)
                        - (Number(upper.y) + Number(upper.height));
                    const firstX = Math.max(Number(a.x), Number(b.x));
                    const lastX = Math.min(Number(a.x) + Number(a.width),
                        Number(b.x) + Number(b.width));
                    if (gapY >= -6 && gapY <= 32 && lastX - firstX > 60) {
                        const mid = (Number(upper.y) + Number(upper.height)
                            + Number(lower.y)) / 2;
                        add(false, mid, firstX, lastX,
                            "h" + Math.round(mid) + ":" + Math.round(firstX));
                    }
                }
            }
            return out;
        }

        // Cuatro puntos en la ventana flotante enfocada.
        readonly property var handles: {
            const list = handleScreen.focusedFloating;
            const out = [];
            for (let i = 0; i < list.length; i++) {
                const win = list[i];
                const x = Number(win.x) - handleScreen.screenX;
                const y = Number(win.y) - handleScreen.screenY;
                const w = Number(win.width);
                const h = Number(win.height);
                if (x > Number(handleScreen.modelData.width)
                        || y > Number(handleScreen.modelData.height)
                        || x + w < 0 || y + h < 0)
                    continue;
                const focused = win.focused === true;
                // Los puntos van unos píxeles dentro de la esquina para que
                // queden sobre el borde redondeado, como en el mockup.
                const inset = 6;
                const corners = [
                    [x + inset, y + inset],
                    [x + w - inset, y + inset],
                    [x + inset, y + h - inset],
                    [x + w - inset, y + h - inset]
                ];
                for (let c = 0; c < corners.length; c++) {
                    out.push({
                        key: String(win.address || win.id) + ":" + c,
                        x: corners[c][0],
                        y: corners[c][1],
                        focused: focused
                    });
                }
            }
            return out;
        }

        visible: SuperState.active && !CompositorState.overviewOpen
            && !handleScreen.settling
            && CompositorState.supports("windowGeometry")
            && (handleScreen.handles.length > 0
                || handleScreen.dividers.length > 0)
        screen: handleScreen.modelData
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "shell-window-handles"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Sin región de entrada: todo pasa a la ventana que hay debajo.
        mask: Region {}

        // Diagnóstico opcional: SHELL_DEBUG_HANDLES=1 hace que el shell
        // escriba la geometría usada por los indicadores en su registro.
        onDividersChanged: {
            if (Quickshell.env("SHELL_DEBUG_HANDLES") !== "1")
                return;
            const list = handleScreen.windows;
            const geometry = [];
            for (let i = 0; i < list.length; i++) {
                geometry.push({
                    id: list[i].address,
                    floating: list[i].floating === true,
                    x: Number(list[i].x),
                    y: Number(list[i].y),
                    w: Number(list[i].width),
                    h: Number(list[i].height)
                });
            }
            console.log("HANDLES windows=" + JSON.stringify(geometry)
                + " dividers=" + JSON.stringify(handleScreen.dividers)
                + " handles=" + JSON.stringify(handleScreen.handles));
        }

        onHandlesChanged: {
            if (Quickshell.env("SHELL_DEBUG_HANDLES") !== "1")
                return;
            console.log("HANDLES corners=" + JSON.stringify(
                handleScreen.handles));
        }

        // ------------------------------------------------- líneas de mosaico
        // Una banda ancha y suave marca la zona sensible (16 px por lado de
        // cada borde); la línea fina del centro es la guía del mockup.
        Repeater {
            model: handleScreen.dividers

            delegate: Item {
                required property var modelData

                readonly property bool vertical: modelData.vertical === true

                x: vertical ? modelData.position - 7 : modelData.start
                y: vertical ? modelData.start : modelData.position - 7
                width: vertical ? 14 : modelData.end - modelData.start
                height: vertical ? modelData.end - modelData.start : 14

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: Theme.accent
                    opacity: 0.10
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.vertical ? 2 : parent.width
                    height: parent.vertical ? parent.height : 2
                    radius: 1
                    color: Theme.accent
                    opacity: 0.42
                }
            }
        }

        // ------------------------------------------------ esquinas flotantes
        Repeater {
            model: handleScreen.handles

            delegate: Rectangle {
                required property var modelData

                readonly property int size: 8

                x: modelData.x - width / 2
                y: modelData.y - height / 2
                width: size
                height: size
                radius: size / 2
                color: Theme.accent
                opacity: modelData.focused ? 0.9 : 0.55
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.30)
            }
        }
    }
}
