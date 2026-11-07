import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Panel lateral único, pegado a la barra. En modo completo muestra el centro
// de control y las notificaciones como dos tarjetas; el orden depende del
// borde donde viva la barra (con la barra abajo, las notificaciones primero).
// En modo rápido (al pulsar un control de la barra) muestra solo la vista
// avanzada de ese control, sin notificaciones, y se coloca junto al icono
// pulsado: debajo en horizontal o al lado en vertical.
PanelWindow {
    id: root

    // Referenciar el singleton hace que se cree y arranque su temporizador de
    // apagado por inactividad (Quickshell crea los singleton bajo demanda).
    readonly property var autoOff: AutoOffState
    // Modo rápido: una sola vista avanzada, sin notificaciones.
    readonly property bool quickMode: QuickPanelState.open
    // Secciones del panel completo. La campana puede abrir ambas o solo las
    // notificaciones; el icono de cuadrícula abre solo el centro de control.
    readonly property bool showNotifications: !root.quickMode
        && NotificationState.panelOpen
        && (NotificationState.panelSection === "both"
            || NotificationState.panelSection === "notifications")
    readonly property bool showControl: root.quickMode
        || (NotificationState.panelOpen
            && (NotificationState.panelSection === "both"
                || NotificationState.panelSection === "control"))

    visible: NotificationState.panelOpen || root.quickMode
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // En horizontal el panel se abre a la derecha; en vertical se pega al
    // lado de la barra y se centra con el control pulsado.
    readonly property bool barVertical: SettingsState.barVertical

    anchors {
        top: root.barVertical || SettingsState.barAtTop
        bottom: !root.barVertical && SettingsState.barAtBottom
        left: !root.barVertical || SettingsState.barAtLeft
        right: root.barVertical && SettingsState.barAtRight
    }
    margins {
        top: root.barVertical ? root.verticalTopMargin
            : (SettingsState.barAtTop
                ? Theme.edge + Theme.barHeight + 10 : 0)
        bottom: root.barVertical ? 0
            : (SettingsState.barAtTop
                ? 0 : Theme.edge + Theme.barHeight + 10)
        left: root.barVertical
            ? (SettingsState.barAtLeft
                ? Theme.edge + Theme.barHeight + 10 : 0)
            : root.leftMargin
        right: root.barVertical && SettingsState.barAtRight
            ? Theme.edge + Theme.barHeight + 10 : 0
    }
    // En modo rápido el panel aparece a la altura del control; en modo
    // completo se centra en la pantalla.
    readonly property real verticalTopMargin: {
        const screenHeight = root.screen ? root.screen.height : 900;
        const desired = root.quickMode && QuickPanelState.anchorY > 0
            ? QuickPanelState.anchorY + Theme.edge - root.implicitHeight / 2
            : (screenHeight - root.implicitHeight) / 2;
        return Math.max(Theme.edge + 10, Math.min(
            screenHeight - root.implicitHeight - Theme.edge - 10,
            desired));
    }
    // En modo completo se pega a la derecha; en modo rápido se centra sobre
    // el control pulsado, sin salirse de la pantalla.
    readonly property real leftMargin: {
        const width = root.implicitWidth;
        const screenWidth = screen ? screen.width : 1280;
        if (!root.quickMode)
            return Math.max(Theme.edge, screenWidth - width - Theme.edge);
        const anchor = QuickPanelState.anchorX;
        return Math.max(Theme.edge, Math.min(
            screenWidth - width - Theme.edge,
            (anchor > 0 ? anchor + Theme.edge : screenWidth - 220)
                - width / 2));
    }
    // Altura máxima de la vista avanzada en modo rápido: el panel puede
    // crecer, pero nunca más allá de la pantalla.
    readonly property int quickHeightLimit: Math.max(220,
        (screen ? screen.height : 800) - Theme.edge * 2
            - (root.barVertical ? 56 : Theme.barHeight + 56))
    implicitWidth: 360
    implicitHeight: Math.min(root.barVertical
            ? (screen ? screen.height : 900) - Theme.edge * 2 : 900,
        panelColumn.implicitHeight + (root.quickMode ? 28 : 0))
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-side-panel"
    WlrLayershell.keyboardFocus: root.visible && focusGate.ready
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    PanelFocusGate {
        id: focusGate
        active: root.visible
    }

    // Al cambiar de vista, el centro de control vuelve al principio.
    Connections {
        target: NotificationState

        function onPanelViewChanged(): void {
            if (typeof ccFlick !== "undefined")
                ccFlick.contentY = 0;
        }
    }

    Connections {
        target: QuickPanelState

        function onOpened(): void {
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
        if (ccLoader.item) {
            // Al cerrar el panel se corta también el escaneo de Wi-Fi, para
            // que la radio no siga buscando redes en segundo plano.
            ccLoader.item.stopNetworkScan();
            ccLoader.item.pendingNetworkName = "";
            ccLoader.item.wifiListFrozen = false;
            ccLoader.item.syncWifiNetworks();
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
            root.barVertical
                ? (SettingsState.barAtLeft
                    ? screen.x + Theme.edge + Theme.barHeight + 10
                    : screen.x + screen.width
                        - (Theme.edge + Theme.barHeight + 10) - root.width)
                : screen.x + root.leftMargin,
            root.barVertical
                ? screen.y + root.verticalTopMargin
                : (SettingsState.barAtTop
                    ? screen.y + Theme.edge + Theme.barHeight + 10
                    : screen.y + screen.height
                        - (Theme.edge + Theme.barHeight + 10) - root.height),
            root.width,
            root.height);
    }

    IpcHandler {
        target: "quickpanel"

        function open(view: string): void {
            QuickPanelState.show(view, -1);
        }

        function close(): void {
            QuickPanelState.hide();
        }

        function toggle(view: string): void {
            QuickPanelState.toggle(view, -1);
        }

        function status(): string {
            return "open=" + (QuickPanelState.open ? "1" : "0")
                + " key=" + QuickPanelState.key
                + " anchorX=" + QuickPanelState.anchorX;
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            NotificationState.togglePanel();
        }

        function open(): void {
            NotificationState.showPanel();
        }

        function control(): void {
            NotificationState.toggleSection("control");
        }

        function status(): string {
            return "open=" + (NotificationState.panelOpen ? "1" : "0")
                + " section=" + NotificationState.panelSection
                + " view=" + NotificationState.panelView
                + " order=" + (sectionsLayout.controlFirst
                    ? "control-first" : "notifications-first");
        }

        // Diagnóstico de las tarjetas emergentes.
        function popups(): string {
            const list = NotificationState.bannerModel;
            const parts = [];
            for (let i = 0; i < list.count; i++)
                parts.push(list.get(i).summary);
            return "count=" + list.count + " items=" + parts.join("|");
        }

        function unified(value: bool): void {
            SettingsState.setUnifiedPanels(value);
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
            QuickPanelState.show("wifi", -1);
        }

        function bluetooth(): void {
            QuickPanelState.show("bluetooth", -1);
        }

        function volume(): void {
            QuickPanelState.show("volume", -1);
        }

        function mic(): void {
            QuickPanelState.show("mic", -1);
        }

        function lockTimeout(minutes: int): void {
            SettingsState.setLockMinutes(minutes);
        }

        // Atajo global: alterna el silencio sin abrir el panel.
        function micToggle(): void {
            Audio.toggleMicMute();
        }

        function night(): void {
            QuickPanelState.show("night", -1);
        }

        function brightness(): void {
            QuickPanelState.show("brightness", -1);
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
            QuickPanelState.show("extraDim", -1);
        }

        function hotspot(): void {
            QuickPanelState.show("hotspot", -1);
        }

        function airplane(): void {
            AirplaneState.toggle();
        }

        function music(): void {
            QuickPanelState.show("music", -1);
        }

        function cpu(): void {
            QuickPanelState.show("cpu", -1);
        }

        function gpu(): void {
            QuickPanelState.show("gpu", -1);
        }

        function net(): void {
            QuickPanelState.show("net", -1);
        }

        function vpn(): void {
            QuickPanelState.show("vpn", -1);
        }

        function keyboard(): void {
            KeyboardState.toggle();
        }

        function keyboardSettings(): void {
            QuickPanelState.show("keyboard", -1);
        }

        function keyboardLayout(value: string): void {
            SettingsState.setKeyboardLayout(value);
        }

        function clipboard(): void {
            QuickPanelState.show("clipboard", -1);
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
            QuickPanelState.show("settings", -1);
        }

        // Desplaza el contenido del panel; útil para scripts y pruebas.
        function scroll(delta: real): void {
            PanelScrollState.request(delta);
        }

        function windowModes(): void {
            QuickPanelState.show("windows", -1);
        }

        function compositor(): void {
            QuickPanelState.show("compositor", -1);
        }

        // Ejecuta una acción del contrato desde scripts o atajos.
        // Ejemplos:
        //   qs ipc -c shell call notifications compositorAction focus 0x...
        //   qs ipc -c shell call notifications compositorAction layout 2 master
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
        readonly property bool dragOver: ControlDrag.active
            && ControlDrag.origin === "bar" && ControlDrag.overPanel
        // En modo rápido el fondo y el borde pertenecen a la ventana. En modo
        // completo cada sección dibuja su propia tarjeta y aquí no hay nada.
        color: dragOver ? Theme.accentGhost
            : (root.quickMode ? Theme.glassCard : "transparent")
        border.width: dragOver ? 2 : (root.quickMode ? 1 : 0)
        border.color: dragOver ? Theme.accent : Theme.borderStrong

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
            anchors.margins: root.quickMode ? 14 : 0
            spacing: 0

            // Dos tarjetas independientes: el hueco de 8 px es la
            // única unión, igual que en el diseño de referencia.
            GridLayout {
                id: sectionsLayout

                Layout.fillWidth: true
                columns: 1
                rowSpacing: 8

                readonly property bool controlFirst: root.showControl
                    && (!root.showNotifications || SettingsState.barAtTop
                        || root.barVertical)
                readonly property int notificationRow:
                    sectionsLayout.controlFirst ? 1 : 0
                readonly property int controlRow:
                    sectionsLayout.controlFirst ? 0 : 1

                // Tarjeta de notificaciones: cabecera y avisos dentro.
                Rectangle {
                    id: notificationCard

                    Layout.row: sectionsLayout.notificationRow
                    Layout.fillWidth: true
                    visible: root.showNotifications
                    Layout.preferredHeight: notifContent.implicitHeight
                    radius: root.quickMode ? 0 : 16
                    color: root.quickMode ? "transparent" : Theme.glassCard
                    border.width: root.quickMode ? 0 : 1
                    border.color: Theme.borderStrong

                    ColumnLayout {
                        id: notifContent

                        anchors.fill: parent
                        spacing: 0

                        // ------------------------------------------------------- cabecera
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 12
                            Layout.topMargin: 12
                            Layout.bottomMargin: 9
                            visible: root.showNotifications
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

                                ShellIcon {
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

                                ShellIcon {
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

                                ShellIcon {
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

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.border
                        }

                        // ------------------------------------------ dependencias del sistema
                        Rectangle {
                            id: depWarning

                            readonly property bool problem: DependencyState.hasMissing
                                || DependencyState.error.length > 0

                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            Layout.bottomMargin: 6
                            visible: !root.quickMode
                                && DependencyState.revealed
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

                                        ShellIcon {
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

                                                    ShellIcon {
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

                        Item {
                            id: notificationSection

                            Layout.fillWidth: true
                            visible: root.showNotifications
                            // Más alto por defecto: la lista respira y la división con el
                            // centro de control queda clara incluso sin avisos.
                            Layout.preferredHeight: NotificationState.count === 0
                                ? 150
                                : Math.min(440, Math.max(190,
                                    notifList.contentHeight + 10))

                            NotificationList {
                                id: notifList

                                anchors.fill: parent
                                anchors.margins: 5
                                visible: NotificationState.count > 0
                            }

                            Column {
                                anchors.centerIn: parent
                                visible: NotificationState.count === 0
                                spacing: 3

                                ShellIcon {
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

                    } // notifContent
                } // notificationCard

                // Tarjeta del centro de control.
                Rectangle {
                    id: controlSection

                    Layout.row: sectionsLayout.controlRow
                    Layout.fillWidth: true
                    visible: root.showControl
                    Layout.preferredHeight: ccCardContent.implicitHeight
                        + (root.quickMode ? 0 : 24)
                    radius: root.quickMode ? 0 : 16
                    color: root.quickMode ? "transparent" : Theme.glassCard
                    border.width: root.quickMode ? 0 : 1
                    border.color: Theme.borderStrong

                    ColumnLayout {
                        id: ccCardContent

                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: root.quickMode ? 0 : 12
                        }
                        spacing: 8

                        // ------------------------------------------------- centro de control
                        Text {
                            Layout.fillWidth: true
                            visible: root.showControl && !root.quickMode
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
                            visible: root.showControl
                            Layout.preferredHeight: root.quickMode
                                ? Math.min(root.quickHeightLimit,
                                    Math.max(80, ccLoader.item
                                        ? ccLoader.item.implicitHeight : 0))
                                : 26 + 8
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
                                contentHeight: ccLoader.item
                                    ? ccLoader.item.implicitHeight : 0
                                boundsBehavior: Flickable.StopAtBounds
                                interactive: false

                                // El centro de control son más de 7000 líneas
                                // de QML. Se crea la primera vez que se abre y
                                // se conserva: antes se construía al arrancar
                                // aunque el panel estuviera cerrado.
                                Loader {
                                    id: ccLoader

                                    width: ccFlick.width
                                    active: root.showControl
                                        || ccLoader.item !== null
                                    asynchronous: false
                                    sourceComponent: ccComponent
                                }

                                Component {
                                    id: ccComponent

                                    ControlCenterContent {
                                        width: ccFlick.width
                                        active: root.showControl
                                        standalone: root.quickMode
                                        viewOverride: root.quickMode
                                            ? QuickPanelState.key : ""
                                    }
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
                                visible: root.quickMode
                                    ? ccFlick.contentHeight > ccFlick.height
                                    : NotificationState.panelView !== ""
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
                    } // ccCardContent
                } // controlSection
            } // sectionsLayout
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: {
            NotificationState.hidePanel();
            QuickPanelState.hide();
        }
    }
}
