import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Panel lateral único, pegado a la barra: notificaciones arriba y centro de
// control compacto abajo. Las opciones avanzadas se abren dentro del panel y
// comparten el mismo desplazamiento.
PanelWindow {
    id: root

    // Referenciar el singleton hace que se cree y arranque su temporizador de
    // apagado por inactividad (Quickshell crea los singleton bajo demanda).
    readonly property var autoOff: AutoOffState

    visible: NotificationState.panelOpen
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    anchors {
        top: SettingsState.barAtTop
        bottom: !SettingsState.barAtTop
        right: true
    }
    margins {
        top: SettingsState.barAtTop ? Theme.edge + Theme.barHeight + 10 : 0
        bottom: SettingsState.barAtTop ? 0 : Theme.edge + Theme.barHeight + 10
        right: Theme.edge
    }
    implicitWidth: 360
    implicitHeight: Math.min(900, panelColumn.implicitHeight + 28)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "alba-side-panel"
    WlrLayershell.keyboardFocus: NotificationState.panelOpen && focusGate.ready
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    PanelFocusGate {
        id: focusGate
        active: NotificationState.panelOpen
    }

    // Al cambiar de vista, el centro de control vuelve al principio.
    Connections {
        target: NotificationState

        function onPanelViewChanged(): void {
            if (typeof ccFlick !== "undefined")
                ccFlick.contentY = 0;
        }
    }

    onVisibleChanged: {
        updateDragBounds();
        if (visible) {
            // Al abrir el panel, la cuadrícula vuelve arriba. Las
            // dependencias solo se comprueban si se pulsa su icono.
            if (typeof ccFlick !== "undefined")
                ccFlick.contentY = 0;
            return;
        }
        DependencyState.revealed = false;
        DependencyState.expanded = false;
        NotificationState.panelView = "";
        if (typeof ccContent !== "undefined") {
            // Al cerrar el panel se corta también el escaneo de Wi-Fi, para
            // que la radio no siga buscando redes en segundo plano.
            ccContent.stopNetworkScan();
            ccContent.pendingNetworkName = "";
            ccContent.wifiListFrozen = false;
            ccContent.syncWifiNetworks();
        }
        if (typeof notifList !== "undefined") {
            notifList.openGroup = "";
            notifList.expandedChildId = -1;
        }
    }

    onWidthChanged: updateDragBounds()
    onHeightChanged: updateDragBounds()
    onScreenChanged: updateDragBounds()
    Component.onCompleted: updateDragBounds()

    // El panel y la barra son ventanas distintas: el arrastre necesita saber
    // dónde está el panel para aceptar controles que vuelven desde la barra.
    function updateDragBounds(): void {
        const screen = root.screen;
        if (!screen || !root.visible) {
            ControlDrag.panelBounds = Qt.rect(0, 0, 0, 0);
            return;
        }
        ControlDrag.panelBounds = Qt.rect(
            screen.x + screen.width - Theme.edge - root.width,
            SettingsState.barAtTop
                ? screen.y + Theme.edge + Theme.barHeight + 10
                : screen.y + screen.height
                    - (Theme.edge + Theme.barHeight + 10) - root.height,
            root.width,
            root.height);
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            NotificationState.togglePanel();
        }

        function open(): void {
            NotificationState.showPanel();
        }

        function close(): void {
            NotificationState.hidePanel();
        }

        function clear(): void {
            NotificationState.clearAll();
        }

        function dnd(): void {
            NotificationState.dnd = !NotificationState.dnd;
        }

        function wifi(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("wifi");
        }

        function bluetooth(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("bluetooth");
        }

        function volume(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("volume");
        }

        function mic(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("mic");
        }

        function lockTimeout(minutes: int): void {
            SettingsState.setLockMinutes(minutes);
        }

        // Atajo global: alterna el silencio sin abrir el panel.
        function micToggle(): void {
            Audio.toggleMicMute();
        }

        function night(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("night");
        }

        function brightness(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("brightness");
        }

        // Atajos que solo ajustan sin abrir el panel; el OSD indica el valor.
        function brightnessUp(): void {
            DisplayState.setBrightness(DisplayState.brightness + 0.05);
        }

        function brightnessDown(): void {
            DisplayState.setBrightness(DisplayState.brightness - 0.05);
        }

        function nightToggle(): void {
            DisplayState.toggleNight();
        }

        function extraDimToggle(): void {
            DisplayState.toggleExtraDim();
        }

        function extraDim(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("extraDim");
        }

        function hotspot(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("hotspot");
        }

        function airplane(): void {
            AirplaneState.toggle();
        }

        function music(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("music");
        }

        function cpu(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("cpu");
        }

        function gpu(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("gpu");
        }

        function net(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("net");
        }

        function vpn(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("vpn");
        }

        function keyboard(): void {
            KeyboardState.toggle();
        }

        function keyboardSettings(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("keyboard");
        }

        function keyboardLayout(value: string): void {
            SettingsState.setKeyboardLayout(value);
        }

        function clipboard(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("clipboard");
        }

        function clipboardCopy(index: int): void {
            ClipboardState.copy(index);
        }

        function clipboardRemove(index: int): void {
            ClipboardState.remove(index);
        }

        function clipboardClear(): void {
            ClipboardState.clear();
        }

        function systemTheme(value: bool): void {
            SettingsState.setSystemTheme(value);
        }

        function back(): void {
            NotificationState.panelView = "";
        }

        function settings(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("settings");
        }

        // Desplaza el contenido del panel; útil para scripts y pruebas.
        function scroll(delta: real): void {
            PanelScrollState.request(delta);
        }

        function windowModes(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("windows");
        }

        function compositor(): void {
            NotificationState.showPanel();
            NotificationState.openPanelView("compositor");
        }

        // Ejecuta una acción del contrato desde scripts o atajos.
        // Ejemplos:
        //   qs ipc -c alba call notifications compositorAction focus 0x...
        //   qs ipc -c alba call notifications compositorAction layout 2 master
        function compositorAction(action: string, target: string,
                value: string): void {
            CompositorState.runAction(action, target, value);
        }

        function setTemps(value: bool): void {
            SettingsState.setShowTemps(value);
        }

        function setWorkspaces(value: int): void {
            SettingsState.setMaxWorkspaces(value);
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: ControlDrag.active && ControlDrag.origin === "bar"
            && ControlDrag.overPanel
            ? Theme.accentGhost
            : Theme.surface
        border.width: ControlDrag.active && ControlDrag.origin === "bar"
            && ControlDrag.overPanel ? 2 : 1
        border.color: ControlDrag.active && ControlDrag.origin === "bar"
            && ControlDrag.overPanel
            ? Theme.accent
            : Theme.borderStrong

        // Aviso al devolver un control de la barra al centro de control.
        Rectangle {
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: 8
            }
            z: 30
            visible: ControlDrag.active && ControlDrag.origin === "bar"
                && ControlDrag.overPanel
            implicitWidth: dropPanelLabel.implicitWidth + 20
            implicitHeight: 24
            radius: 12
            color: Theme.accent

            Text {
                id: dropPanelLabel
                anchors.centerIn: parent
                text: "Suelta para devolver al centro de control"
                color: Theme.accentInk
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
            }
        }

        ColumnLayout {
            id: panelColumn

            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ------------------------------------------------------- cabecera
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "Notificaciones"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: NotificationState.count === 0
                            ? (DependencyState.hasMissing
                                || DependencyState.error.length > 0
                                ? "Revisa las dependencias"
                                : "Todo al día")
                            : NotificationState.countLabel(
                                NotificationState.count)
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                    }
                }

                // No molestar (solo icono).
                Rectangle {
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 8
                    color: NotificationState.dnd ? Theme.accentSoft : Theme.hover
                    border.width: NotificationState.dnd ? 1 : 0
                    border.color: Theme.accentLine

                    AlbaIcon {
                        anchors.centerIn: parent
                        name: NotificationState.dnd
                            ? "notifications-disabled" : "notifications"
                        fallbackName: "preferences-desktop-notification"
                        color: NotificationState.dnd
                            ? Theme.danger : Theme.muted
                        size: 15
                        fallback: "!"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationState.dnd = !NotificationState.dnd
                    }
                }

                // Comprobar dependencias (solo al pulsar).
                Rectangle {
                    id: depButton

                    readonly property bool problem: DependencyState.hasMissing
                        || DependencyState.error.length > 0

                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 8
                    color: depMouse.containsMouse
                        ? Theme.hover
                        : (depButton.problem ? Theme.warningSoft : "transparent")
                    border.width: depButton.problem ? 1 : 0
                    border.color: Theme.warningLine

                    AlbaIcon {
                        anchors.centerIn: parent
                        name: DependencyState.checking
                            ? "view-refresh"
                            : (depButton.problem
                                ? "dialog-warning"
                                : (DependencyState.checked
                                    ? "emblem-ok-symbolic" : "dialog-information"))
                        fallback: DependencyState.checking
                            ? "↻"
                            : (depButton.problem
                                ? "⚠"
                                : (DependencyState.checked ? "✓" : "i"))
                        color: DependencyState.checking
                            ? Theme.accent
                            : (depButton.problem
                                ? Theme.warning
                                : (DependencyState.checked
                                    ? Theme.accent : Theme.muted))
                        size: 15
                    }

                    MouseArea {
                        id: depMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DependencyState.checkNow()
                    }

                    ToolTip.visible: depMouse.containsMouse
                    ToolTip.text: DependencyState.checking
                        ? "Comprobando dependencias…"
                        : "Comprobar dependencias"
                    ToolTip.delay: 350
                }

                // Limpiar (solo icono).
                Rectangle {
                    visible: NotificationState.count > 0
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 8
                    color: clearMouse.containsMouse ? Theme.hover : "transparent"

                    AlbaIcon {
                        anchors.centerIn: parent
                        name: "edit-clear-all"
                        color: clearMouse.containsMouse
                            ? Theme.danger : Theme.muted
                        size: 15
                        fallback: "⌫"
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationState.clearAll()
                    }
                }
            }

            // ------------------------------------------ dependencias del sistema
            Rectangle {
                id: depWarning

                readonly property bool problem: DependencyState.hasMissing
                    || DependencyState.error.length > 0

                Layout.fillWidth: true
                visible: DependencyState.revealed
                    && (DependencyState.checking || DependencyState.hasResult)
                implicitHeight: depColumn.implicitHeight + 16
                radius: 10
                color: depWarning.problem
                    ? Theme.warningSoft : Theme.accentSoft
                border.width: 1
                border.color: depWarning.problem
                    ? Theme.warningLine : Theme.accentLine

                ColumnLayout {
                    id: depColumn

                    anchors {
                        fill: parent
                        margins: 8
                    }
                    spacing: 5

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: depHead.implicitHeight

                        RowLayout {
                            id: depHead

                            anchors.fill: parent
                            spacing: 7

                            AlbaIcon {
                                name: DependencyState.checking
                                    ? "view-refresh"
                                    : (depWarning.problem
                                        ? "dialog-warning" : "emblem-ok-symbolic")
                                fallback: DependencyState.checking
                                    ? "↻"
                                    : (depWarning.problem ? "⚠" : "✓")
                                color: depWarning.problem
                                    ? Theme.warning : Theme.accent
                                size: 17
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: DependencyState.checking
                                        ? "Comprobando dependencias…"
                                        : (DependencyState.error.length > 0
                                            ? "No se pudo comprobar"
                                            : (DependencyState.hasMissing
                                                ? DependencyState.title
                                                : "Todo en orden"))
                                    color: depWarning.problem
                                        ? Theme.warning : Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: DependencyState.checking
                                        ? "Revisando los paquetes de red…"
                                        : (DependencyState.error.length > 0
                                            ? DependencyState.error
                                            : (DependencyState.hasMissing
                                                ? (DependencyState.expanded
                                                    ? "Paquetes que faltan:"
                                                    : "Toca para ver qué instalar")
                                                : "No falta ningún paquete de red."))
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    wrapMode: Text.Wrap
                                }
                            }

                            Text {
                                visible: DependencyState.hasMissing
                                    && !DependencyState.checking
                                text: DependencyState.expanded ? "⌃" : "⌄"
                                color: Theme.warning
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: DependencyState.hasMissing
                                && !DependencyState.checking
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DependencyState.toggle()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: DependencyState.expanded
                            && DependencyState.hasMissing
                            && !DependencyState.checking
                        spacing: 3

                        Repeater {
                            model: DependencyState.missing

                            delegate: RowLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: "•"
                                    color: Theme.warning
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.package
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.topMargin: 2
                            color: Theme.warningLine
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "SOLUCIÓN"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                        }

                        Repeater {
                            model: DependencyState.fixes

                            delegate: Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                implicitHeight: Math.max(26,
                                    depFix.implicitHeight + 10)
                                radius: 6
                                color: Theme.surface

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 7
                                        rightMargin: 4
                                    }
                                    spacing: 4

                                    Text {
                                        id: depFix

                                        Layout.fillWidth: true
                                        text: String(modelData)
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        wrapMode: Text.Wrap
                                    }

                                    Rectangle {
                                        implicitWidth: 22
                                        implicitHeight: 22
                                        radius: 6
                                        color: depCopyMouse.containsMouse
                                            ? Theme.hover : "transparent"

                                        AlbaIcon {
                                            anchors.centerIn: parent
                                            name: DependencyState.copiedText
                                                === String(modelData)
                                                ? "emblem-ok-symbolic" : "edit-copy"
                                            fallback: DependencyState.copiedText
                                                === String(modelData) ? "✓" : "⧉"
                                            color: DependencyState.copiedText
                                                === String(modelData)
                                                ? Theme.accent : Theme.muted
                                            size: 13
                                        }

                                        MouseArea {
                                            id: depCopyMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: DependencyState.copy(
                                                String(modelData))
                                        }

                                        ToolTip.visible: depCopyMouse.containsMouse
                                        ToolTip.text: DependencyState.copiedText
                                            === String(modelData)
                                            ? "Copiado" : "Copiar solución"
                                        ToolTip.delay: 300
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --------------------------------------------------- notificaciones
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: NotificationState.count === 0
                    ? 78
                    : Math.min(360, Math.max(80, notifList.contentHeight))

                NotificationList {
                    id: notifList

                    anchors.fill: parent
                    visible: NotificationState.count > 0
                }

                Column {
                    anchors.centerIn: parent
                    visible: NotificationState.count === 0
                    spacing: 3

                    AlbaIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: NotificationState.dnd
                            ? "notifications-disabled" : "notifications"
                        color: NotificationState.dnd
                            ? Theme.danger : Theme.faint
                        size: 22
                        fallback: "!"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: NotificationState.dnd
                            ? "No molestar activado"
                            : "Sin notificaciones"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // ------------------------------------------------- centro de control
            Text {
                Layout.fillWidth: true
                text: "Centro de control"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            // Área fija de 2 columnas; las filas que no caben se desplazan.
            Item {
                id: ccViewport

                Layout.fillWidth: true
                Layout.preferredHeight: 26 + 8
                    + SettingsState.centerRows * 38
                    + (SettingsState.centerRows - 1) * 5
                clip: true

                function scrollBy(delta): void {
                    const max = Math.max(0,
                        ccFlick.contentHeight - ccFlick.height);
                    ccFlick.contentY = Math.max(0, Math.min(max,
                        ccFlick.contentY - delta * 0.7));
                }

                Flickable {
                    id: ccFlick

                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: ccContent.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: false

                    ControlCenterContent {
                        id: ccContent

                        width: ccFlick.width
                        active: NotificationState.panelOpen
                    }
                }

                Connections {
                    target: PanelScrollState
                    function onScrolled(delta): void {
                        ccViewport.scrollBy(delta);
                    }
                }


                MouseArea {
                    anchors.fill: parent
                    z: 20
                    acceptedButtons: Qt.MiddleButton
                    visible: NotificationState.panelView !== ""
                    onWheel: (wheel) => {
                        PanelScrollState.request(wheel.angleDelta.y);
                        wheel.accepted = true;
                    }
                }

                Rectangle {
                    visible: ccFlick.contentHeight > ccFlick.height
                    width: 2
                    height: Math.max(20, ccFlick.height * ccFlick.height
                        / Math.max(1, ccFlick.contentHeight))
                    radius: 1
                    color: Theme.borderStrong
                    x: ccViewport.width - 3
                    y: Math.max(0, (ccFlick.height - height)
                        * (ccFlick.contentY / Math.max(1,
                            ccFlick.contentHeight - ccFlick.height)))
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: NotificationState.panelOpen
        onActivated: NotificationState.hidePanel()
    }
}
