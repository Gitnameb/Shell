import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Barra de título y controles del shell para cada ventana.
//
// Cada ventana recibe una superficie pequeña encima de su franja superior. La
// máscara de entrada solo cubre la barra y el menú de escritorios, así que el
// resto de la ventana sigue siendo clicable. No depende de hyprbars: arrastra
// con movewindowpixel exact a través de CompositorState.
Variants {
    id: root

    // Con un compositor que dibuja barras nativas (Umbriel) no se crea
    // ninguna superficie del shell: la decoración ya forma parte de la ventana.
    model: CompositorState.supports("shellTitlebar")
        ? CompositorState.windows : []

    delegate: PanelWindow {
        id: chrome

        required property var modelData
        readonly property var win: chrome.modelData
        readonly property var scr: WindowLook.screenFor(
            chrome.win ? chrome.win.monitor : "")
        readonly property string appId: chrome.win
            ? String(chrome.win.appId || chrome.win.class || "") : ""
        readonly property color appColor:
            WindowLook.colorFor(chrome.appId)
        readonly property bool superChrome: SuperState.active
            && chrome.win && chrome.win.fullscreen !== true
        // «Siempre» solo afecta a ventanas flotantes; el mosaico se queda sin
        // barra permanente para no robar espacio al contenido.
        readonly property bool persistentTitlebar:
            SettingsState.nativeTitlebar === "always"
                && chrome.win && chrome.win.floating === true
                && chrome.win.fullscreen !== true
        readonly property int activeWorkspaceId:
            CompositorState.focusedWorkspace
                ? Number(CompositorState.focusedWorkspace.id) || 0 : 0
        // Las ventanas de otros escritorios no deben dibujar barra ni
        // controles encima del escritorio activo. Las fijadas sí, porque se
        // muestran en todos.
        readonly property bool onActiveWorkspace: chrome.win
            && (Number(chrome.win.workspaceId) === chrome.activeWorkspaceId
                || chrome.win.pinned === true)
        readonly property bool titlebarVisible: chrome.win
            && chrome.win.minimized !== true
            && chrome.win.visible !== false
            && chrome.onActiveWorkspace
            && chrome.win.fullscreen !== true
            && (chrome.persistentTitlebar || chrome.superChrome)
        readonly property bool canDrag: chrome.win
            && chrome.win.floating === true
        readonly property int chromeWidth: Math.max(1,
            Math.round(Number(chrome.win ? chrome.win.width : 0)))
        readonly property int chromeHeight: Math.max(1,
            Math.round(Number(chrome.win ? chrome.win.height : 0)))
        readonly property int localX: chrome.scr && chrome.win
            ? Math.round(Number(chrome.win.x) - chrome.scr.x) : 0
        readonly property int localY: chrome.scr && chrome.win
            ? Math.round(Number(chrome.win.y) - chrome.scr.y) : 0

        property bool moveMenu: false
        property real pendingX: 0
        property real pendingY: 0
        property bool movePending: false

        onModelDataChanged: {
            chrome.moveMenu = false;
            chrome.movePending = false;
            moveTimer.stop();
        }

        screen: chrome.scr
        visible: chrome.titlebarVisible && chrome.chromeWidth > 40
            && chrome.chromeHeight > 20
        anchors {
            top: true
            left: true
        }
        margins {
            top: Math.max(0, chrome.localY)
            left: Math.max(0, chrome.localX)
        }
        implicitWidth: chrome.chromeWidth
        implicitHeight: chrome.chromeHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "shell-window-chrome"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // El borde solo aparece en el modo ventanas de Super; con «Siempre»
        // la barra de título basta y no se altera el aspecto normal.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: 14
            border.width: chrome.superChrome ? 1 : 0
            border.color: chrome.win && chrome.win.focused
                ? Theme.accent : Theme.accentLine
        }

        // La máscara deja pasar los clics al contenido salvo en la barra y el
        // menú de escritorios.
        mask: Region {
            Region {
                x: 6
                y: 5
                width: Math.max(1, chrome.chromeWidth - 12)
                height: 34
            }

            Region {
                x: 6
                y: 43
                width: chrome.moveMenu ? Math.min(
                    chrome.chromeWidth - 12,
                    SettingsState.maxWorkspaces * 24 + 8) : 0
                height: chrome.moveMenu ? 28 : 0
            }
        }

        // ------------------------------------------------------ barra
        Rectangle {
            id: titlebar

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 6
            }
            height: 32
            radius: 9
            color: Theme.glass
            border.width: 1
            border.color: chrome.win && chrome.win.focused
                ? Theme.accentLine : Theme.borderStrong
            clip: true

            // Zona de arrastre. Va debajo del contenido para que los botones
            // sigan recibiendo sus clics.
            MouseArea {
                id: dragArea

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: chrome.canDrag
                    ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                    : Qt.ArrowCursor
                preventStealing: true

                property real startGlobalX: 0
                property real startGlobalY: 0
                property real startWindowX: 0
                property real startWindowY: 0

                function globalPoint(mx, my): var {
                    const p = mapToItem(null, mx, my);
                    return Qt.point((chrome.scr ? chrome.scr.x : 0) + p.x,
                        (chrome.scr ? chrome.scr.y : 0) + p.y);
                }

                onPressed: (mouse) => {
                    if (!chrome.win || !chrome.canDrag)
                        return;
                    if (!chrome.win.focused)
                        CompositorState.focusWindow(chrome.win.address);
                    const p = globalPoint(mouse.x, mouse.y);
                    startGlobalX = p.x;
                    startGlobalY = p.y;
                    startWindowX = Number(chrome.win.x);
                    startWindowY = Number(chrome.win.y);
                }

                onPositionChanged: (mouse) => {
                    if (!pressed || !chrome.canDrag)
                        return;
                    const p = globalPoint(mouse.x, mouse.y);
                    chrome.pendingX = startWindowX + (p.x - startGlobalX);
                    chrome.pendingY = startWindowY + (p.y - startGlobalY);
                    if (!chrome.movePending) {
                        chrome.movePending = true;
                        moveTimer.start();
                    }
                }

                onReleased: {
                    if (chrome.movePending) {
                        chrome.movePending = false;
                        moveTimer.stop();
                        CompositorState.moveWindowTo(chrome.win.address,
                            chrome.pendingX, chrome.pendingY);
                    }
                }

                onDoubleClicked: {
                    if (chrome.win)
                        CompositorState.toggleMaximized(chrome.win.address);
                }
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 6
                    rightMargin: 4
                }
                spacing: 6
                z: 2

                // Icono y color de la aplicación.
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 6
                    color: WindowLook.tintFor(chrome.appColor)

                    Image {
                        id: appIcon

                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: WindowLook.iconFor(chrome.appId)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        text: WindowLook.letterFor(chrome.appId)
                        color: chrome.appColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -1

                    Text {
                        Layout.fillWidth: true
                        text: chrome.win
                            ? (String(chrome.win.title || "").length > 0
                                ? String(chrome.win.title)
                                : WindowLook.nameFor(chrome.appId))
                            : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: WindowLook.nameFor(chrome.appId) + " · "
                            + WindowLook.workspaceLabel(chrome.win)
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    spacing: 1

                    ChromeButton {
                        iconName: "pin"
                        glyph: "◆"
                        tint: chrome.win && chrome.win.pinned
                            ? Theme.accent : Theme.muted
                        active: chrome.win && chrome.win.pinned
                        tip: "Siempre encima"
                        onClicked: {
                            if (chrome.win)
                                CompositorState.togglePinned(chrome.win.address);
                        }
                    }

                    ChromeButton {
                        iconName: "window-duplicate-symbolic"
                        glyph: "❐"
                        tint: chrome.win && chrome.win.floating
                            ? Theme.accent : Theme.muted
                        active: chrome.win && chrome.win.floating
                        tip: "Flotante / mosaico"
                        onClicked: {
                            if (chrome.win)
                                CompositorState.toggleFloating(chrome.win.address);
                        }
                    }

                    ChromeButton {
                        glyph: "#"
                        tint: Theme.muted
                        active: chrome.moveMenu
                        tip: "Mover a otro escritorio"
                        onClicked: chrome.moveMenu = !chrome.moveMenu
                    }

                    ChromeButton {
                        iconName: chrome.win && chrome.win.maximized
                            ? "view-restore" : "view-fullscreen"
                        glyph: chrome.win && chrome.win.maximized ? "❐" : "▣"
                        tint: chrome.win && chrome.win.maximized
                            ? Theme.accent : Theme.muted
                        active: chrome.win && chrome.win.maximized
                        tip: "Maximizar / restaurar"
                        onClicked: {
                            if (chrome.win)
                                CompositorState.toggleMaximized(chrome.win.address);
                        }
                    }

                    ChromeButton {
                        iconName: "go-down"
                        glyph: "—"
                        tint: Theme.muted
                        tip: "Minimizar"
                        onClicked: {
                            chrome.moveMenu = false;
                            if (chrome.win)
                                CompositorState.minimizeWindow(chrome.win.address);
                        }
                    }

                    ChromeButton {
                        iconName: "window-close"
                        glyph: "×"
                        tint: Theme.muted
                        danger: true
                        tip: "Cerrar"
                        onClicked: {
                            if (chrome.win)
                                CompositorState.closeWindow(chrome.win.address);
                        }
                    }
                }
            }
        }

        // ------------------------------------------- selector de escritorio
        Rectangle {
            id: moveRow

            visible: chrome.moveMenu
            anchors {
                top: titlebar.bottom
                left: parent.left
                topMargin: 6
                leftMargin: 6
            }
            width: Math.min(chrome.chromeWidth - 12,
                SettingsState.maxWorkspaces * 24 + 8)
            height: 28
            radius: 8
            color: Theme.glass
            border.width: 1
            border.color: Theme.borderStrong
            clip: true

            Row {
                anchors.centerIn: parent
                spacing: 1

                Repeater {
                    model: SettingsState.workspaceIds

                    delegate: Rectangle {
                        id: wsChip

                        required property int modelData

                        readonly property bool current:
                            chrome.win
                            && Number(chrome.win.workspaceId) === wsChip.modelData

                        width: 22
                        height: 22
                        radius: 5
                        color: wsChip.current
                            ? Theme.accent : (wsHover.containsMouse
                                ? Theme.hover : "transparent")

                        Text {
                            anchors.centerIn: parent
                            text: wsChip.modelData
                            color: wsChip.current
                                ? Theme.accentInk : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: wsHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (chrome.win) {
                                    CompositorState.moveToWorkspace(
                                        chrome.win.address, wsChip.modelData);
                                    chrome.moveMenu = false;
                                }
                            }
                        }
                    }
                }
            }
        }

        Timer {
            id: moveTimer
            interval: 18
            repeat: false
            onTriggered: {
                if (chrome.movePending && chrome.win)
                    CompositorState.moveWindowTo(chrome.win.address,
                        chrome.pendingX, chrome.pendingY);
                chrome.movePending = false;
            }
        }
    }
}
