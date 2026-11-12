import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Menú contextual de una app abierta, al estilo de KDE/Windows. Es una capa
// independiente colocada encima de la ficha: se abre sobre la barra y se cierra
// al pulsar fuera (la capa de cierre del shell), con Escape o al elegir una
// acción. Al ser una tarjeta y no una capa a pantalla completa, un clic en otra
// ficha de la barra llega a la barra y abre el menú de esa otra app sin tener
// que cerrar este primero.
PanelWindow {
    id: root

    property var app: null
    property var targetScreen: null
    property real anchorX: 0
    property real anchorY: 0
    signal dismissed()

    // Tamaño real de la tarjeta.
    readonly property real cardWidth: 244
    readonly property real cardHeight: menuColumn.implicitHeight + 16
    // Acciones propias del .desktop de la app («Nueva ventana», «Incógnito»…).
    // Se recalculan a mano en vez de con un binding: DesktopActions.actionsFor
    // lee `revision` y el modelo del Repeater, y Qt detectaba un bucle entre
    // esa lectura y la altura de la tarjeta.
    readonly property string appId: root.app
        ? String(root.app.cls || root.app.appId || "") : ""
    property var appActions: []

    function reloadAppActions(): void {
        root.appActions = root.appId.length > 0
            ? DesktopActions.actionsFor(root.appId) : [];
    }

    onAppIdChanged: root.reloadAppActions()

    Connections {
        target: DesktopActions

        function onRevisionChanged(): void {
            root.reloadAppActions();
        }
    }

    Component.onCompleted: root.reloadAppActions()
    // Misma lista que dibuja la barra de título: orden, iconos, etiquetas y
    // atajos salen de WindowActions para que no puedan desincronizarse.
    readonly property var windowActions: WindowActions.itemsFor(root.app)
    // Flujo de audio de la app/window. El PID del toplevel es la pista más
    // fiable; si la app no lo publica se compara su id.
    readonly property var audioStream: Audio.primaryStreamForWindow(root.app)
    property bool showWorkspaces: false

    // La tarjeta se centra sobre el icono y se abre hacia dentro de la
    // pantalla (hacia arriba con la barra abajo y hacia abajo con la barra
    // arriba). Se limita a los márgenes de la pantalla.
    readonly property real menuLeft: {
        const screen = root.targetScreen;
        const screenX = screen ? screen.x : 0;
        const screenWidth = screen ? screen.width : 1920;
        let desired;
        if (SettingsState.barVertical) {
            // Al lado de la barra, nunca encima de ella.
            desired = SettingsState.barAtLeft
                ? screenX + Theme.edge + Theme.barHeight + 8
                : screenX + screenWidth - Theme.edge - Theme.barHeight - 8
                    - root.cardWidth;
        } else {
            desired = root.anchorX - root.cardWidth / 2;
        }
        return Math.max(screenX + 8,
            Math.min(screenX + screenWidth - root.cardWidth - 8, desired));
    }
    readonly property real menuTop: {
        const screen = root.targetScreen;
        const screenY = screen ? screen.y : 0;
        const screenHeight = screen ? screen.height : 1080;
        let desired;
        if (SettingsState.barVertical) {
            desired = root.anchorY - root.cardHeight / 2;
        } else {
            desired = SettingsState.barAtTop
                ? root.anchorY + 8
                : root.anchorY - root.cardHeight - 8;
        }
        return Math.max(screenY + 8,
            Math.min(screenY + screenHeight - root.cardHeight - 8, desired));
    }

    visible: false
    screen: root.targetScreen

    anchors {
        top: true
        left: true
    }
    margins {
        left: Math.round(root.menuLeft
            - (root.targetScreen ? root.targetScreen.x : 0))
        top: Math.round(root.menuTop
            - (root.targetScreen ? root.targetScreen.y : 0))
    }
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-app-menu"
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (!root.visible)
            root.dismissed();
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.dismiss()
    }

    function dismiss() {
        root.visible = false;
        // El selector de escritorios vuelve a estar plegado la próxima vez.
        root.showWorkspaces = false;
    }

    // Las acciones de ventana pasan por el contrato común. Así el menú de la
    // barra y el overlay usarán el mismo backend que el resto del shell.
    function targetAddress() {
        return String(root.app ? root.app.address || "" : "");
    }

    function runWindowAction(key) {
        root.dismiss();
        WindowActions.run(key, root.app);
    }

    function moveToWorkspace(workspace) {
        root.dismiss();
        CompositorState.moveToWorkspace(root.targetAddress(), workspace);
    }

    function runAppAction(action) {
        root.dismiss();
        DesktopActions.run(action);
    }

    Item {
        id: menuCard

        width: root.cardWidth
        height: root.cardHeight
        x: 0
        y: 0

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.glassMenu
            border.width: 1
            border.color: Theme.borderStrong

        ColumnLayout {
            id: menuColumn

            anchors {
                fill: parent
                margins: 8
            }
            spacing: 2

            // ------------------------------------------------------ cabecera
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 8
                    color: root.app ? root.app.tile : Theme.surfaceAlt

                    Image {
                        id: headerIcon

                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: root.app ? root.app.icon : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !headerIcon.visible
                        text: root.app ? root.app.letter : ""
                        color: root.app ? root.app.color : Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.app ? root.app.name : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: root.app ? root.app.title : ""
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: Theme.border
            }

            // Acciones del archivo .desktop de la aplicación. Es lo que
            // convierte «click derecho en Brave» en «Nueva ventana» y «Nueva
            // ventana de incógnito», igual que en la barra de tareas de
            // Windows o en Plasma.
            Text {
                Layout.fillWidth: true
                visible: root.appActions.length > 0
                text: "ACCIONES DE LA APP"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Repeater {
                model: root.appActions

                delegate: AppMenuItem {
                    required property var modelData

                    readonly property string actionIcon:
                        DesktopActions.iconFor(modelData)

                    Layout.fillWidth: true
                    label: String(modelData.name || "")
                    iconSource: actionIcon.startsWith("/")
                        || actionIcon.startsWith("file:")
                        ? actionIcon : ""
                    iconName: iconSource.length === 0 ? actionIcon : ""
                    iconTint: iconSource.length === 0
                    glyph: "▸"
                    onClicked: root.runAppAction(modelData)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.appActions.length > 0
                Layout.preferredHeight: 1
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: Theme.border
            }

            Repeater {
                model: root.windowActions

                delegate: ColumnLayout {
                    id: actionBlock

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 2

                    AppMenuItem {
                        Layout.fillWidth: true
                        label: actionBlock.modelData.key === "move"
                            ? actionBlock.modelData.label
                                + (root.showWorkspaces ? "  ▴" : "  ▾")
                            : actionBlock.modelData.label
                        iconName: actionBlock.modelData.source
                            && String(actionBlock.modelData.source).length > 0
                            ? "" : actionBlock.modelData.icon
                        iconSource: actionBlock.modelData.source || ""
                        glyph: actionBlock.modelData.glyph
                        shortcut: actionBlock.modelData.shortcut
                        active: actionBlock.modelData.active === true
                            || (actionBlock.modelData.key === "move"
                                && root.showWorkspaces)
                        danger: actionBlock.modelData.danger === true
                        onClicked: {
                            if (actionBlock.modelData.key === "move") {
                                root.showWorkspaces = !root.showWorkspaces;
                                return;
                            }
                            root.runWindowAction(actionBlock.modelData.key);
                        }
                    }

                    // Selector de escritorio de «Mover a escritorio». La barra
                    // de título abre el mismo selector bajo su botón «#».
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                        spacing: 3
                        visible: actionBlock.modelData.key === "move"
                            && root.showWorkspaces

                        Repeater {
                            model: SettingsState.workspaceIds

                            delegate: Rectangle {
                                required property int modelData

                                readonly property bool current: root.app
                                    && root.app.workspace === modelData

                                width: 20
                                height: 20
                                radius: 6
                                color: current
                                    ? Theme.accentSoft
                                    : (workspaceMouse.containsMouse
                                        ? Theme.hover : Theme.surfaceAlt)
                                border.width: current ? 1 : 0
                                border.color: current
                                    ? Theme.accentLine
                                    : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: current
                                        ? Theme.accent : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: current
                                        ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    id: workspaceMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !current
                                    cursorShape: current
                                        ? Qt.ArrowCursor
                                        : Qt.PointingHandCursor
                                    onClicked: root.moveToWorkspace(modelData)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: Theme.border
            }

            // Volumen de la aplicación, como el altavoz de las ventanas del
            // mockup. Se controla el flujo de PipeWire de esa app; si no hay
            // flujo activo, la fila queda visible pero desactivada.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18

                        ShellIcon {
                            anchors.fill: parent
                            source: ShellIcons.src(
                                root.audioStream && root.audioStream.audio
                                    && root.audioStream.audio.muted
                                    ? "volume-off" : "volume-3")
                            color: root.audioStream && root.audioStream.audio
                                && root.audioStream.audio.muted
                                ? Theme.danger : Theme.muted
                            size: 16
                            fallback: "◖"
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            enabled: root.audioStream !== null
                            cursorShape: root.audioStream !== null
                                ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Audio.toggleNodeMute(root.audioStream)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Volumen"
                        color: root.audioStream !== null
                            ? Theme.text : Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        text: root.audioStream
                            && root.audioStream.audio
                            ? (root.audioStream.audio.muted
                                ? "Mudo"
                                : Math.round(root.audioStream.audio.volume
                                    * 100) + "%")
                            : "—"
                        color: root.audioStream && root.audioStream.audio
                            && root.audioStream.audio.muted
                            ? Theme.danger : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }

                ShellSlider {
                    id: windowVolume

                    Layout.fillWidth: true
                    enabled: root.audioStream !== null
                    from: 0
                    to: 1
                    stepSize: 0.02
                    value: root.audioStream && root.audioStream.audio
                        ? root.audioStream.audio.volume : 0
                    onMoved: Audio.setNodeVolume(root.audioStream, value)
                }

                Binding {
                    target: windowVolume
                    property: "value"
                    value: root.audioStream && root.audioStream.audio
                        ? root.audioStream.audio.volume : 0
                    when: !windowVolume.pressed
                }
            }
        }
    }
    }
}
