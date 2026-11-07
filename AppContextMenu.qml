import Quickshell
import Quickshell.Hyprland
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
    readonly property var appActions: {
        if (!root.app)
            return [];
        return DesktopActions.actionsFor(String(root.app.cls
            || root.app.appId || ""));
    }

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

    // En Hyprland se conserva su captador de foco como respaldo; en Umbriel
    // basta la capa de cierre del shell y el teclado sigue en el menú.
    HyprlandFocusGrab {
        id: focusGrab

        windows: [root]
        active: false
        onCleared: root.dismiss()
    }

    onVisibleChanged: {
        if (root.visible) {
            if (CompositorState.supports("hyprlandFocusGrab"))
                Qt.callLater(function() {
                    if (root.visible)
                        focusGrab.active = true;
                });
        } else {
            focusGrab.active = false;
            root.dismissed();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.dismiss()
    }

    function dismiss() {
        root.visible = false;
    }

    // Las acciones de ventana pasan por el contrato común. Así el menú de la
    // barra y el overlay usarán el mismo backend que el resto del shell.
    function targetAddress() {
        return String(root.app ? root.app.address || "" : "");
    }

    function focusWindow() {
        root.dismiss();
        CompositorState.focusWindow(root.targetAddress());
    }

    function toggleMaximized() {
        root.dismiss();
        CompositorState.toggleMaximized(root.targetAddress());
    }

    function toggleFloating() {
        root.dismiss();
        CompositorState.toggleFloating(root.targetAddress());
    }

    function minimizeWindow() {
        const address = root.targetAddress();
        root.dismiss();
        if (root.app && root.app.minimized)
            CompositorState.restoreWindow(address);
        else
            CompositorState.minimizeWindow(address);
    }

    function moveToWorkspace(workspace) {
        root.dismiss();
        CompositorState.moveToWorkspace(root.targetAddress(), workspace);
    }

    function closeWindow() {
        root.dismiss();
        CompositorState.closeWindow(root.targetAddress());
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

            AppMenuItem {
                Layout.fillWidth: true
                label: root.app && root.app.activated
                    ? "Ventana activa" : "Enfocar ventana"
                iconName: "window"
                glyph: "◎"
                hint: root.app && root.app.activated ? "activa" : ""
                enabled: !(root.app && root.app.activated)
                onClicked: root.focusWindow()
            }

            AppMenuItem {
                Layout.fillWidth: true
                label: root.app && root.app.maximized
                    ? "Restaurar tamaño" : "Maximizar"
                iconName: root.app && root.app.maximized
                    ? "view-restore" : "view-fullscreen"
                glyph: "⛶"
                onClicked: root.toggleMaximized()
            }

            AppMenuItem {
                Layout.fillWidth: true
                label: root.app && root.app.minimized
                    ? "Restaurar ventana" : "Minimizar"
                iconName: root.app && root.app.minimized
                    ? "view-restore" : "go-down"
                glyph: "—"
                onClicked: root.minimizeWindow()
            }

            AppMenuItem {
                Layout.fillWidth: true
                label: "Flotante / mosaico"
                iconName: "window-duplicate-symbolic"
                glyph: "❐"
                onClicked: root.toggleFloating()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: Theme.border
            }

            Text {
                Layout.fillWidth: true
                text: "MOVER AL ESCRITORIO"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Flow {
                Layout.fillWidth: true
                spacing: 3

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
                            color: current ? Theme.accent : Theme.muted
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
                                ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: root.moveToWorkspace(modelData)
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

            AppMenuItem {
                Layout.fillWidth: true
                label: "Cerrar ventana"
                iconName: "window-close-symbolic"
                glyph: "✕"
                danger: true
                onClicked: root.closeWindow()
            }
        }
    }
    }
}
