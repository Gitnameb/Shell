import Quickshell
import Quickshell.Wayland
import QtQuick

// Selector 1–9 del botón «Mover» de la barra de título nativa, copiado del
// mockup: una tarjeta estrecha junto al botón con el escritorio actual
// resaltado. Elegir otro escritorio mueve la ventana; elegir el actual solo
// cierra el selector.
PanelWindow {
    id: root

    readonly property int cardWidth: 46
    readonly property int rowHeight: 32
    readonly property int padding: 5
    readonly property int gap: 2
    readonly property real cardHeight: root.padding * 2
        + root.rowHeight * Math.max(1, SettingsState.workspaceIds.length)
        + root.gap * Math.max(0, SettingsState.workspaceIds.length - 1)

    readonly property var targetScreen: {
        const screens = Quickshell.screens || [];
        for (let i = 0; i < screens.length; i++) {
            const screen = screens[i];
            if (MoveMenuState.anchorX >= screen.x
                    && MoveMenuState.anchorX < screen.x + screen.width
                    && MoveMenuState.anchorY >= screen.y
                    && MoveMenuState.anchorY < screen.y + screen.height)
                return screen;
        }
        return screens.length > 0 ? screens[0] : null;
    }

    // La tarjeta cuelga del botón, como en el mockup.
    readonly property real cardLeft: {
        const screen = root.targetScreen;
        const left = screen ? screen.x : 0;
        const width = screen ? screen.width : 1920;
        const desired = MoveMenuState.anchorX - root.cardWidth / 2;
        return Math.max(left + 8,
            Math.min(left + width - root.cardWidth - 8, desired));
    }
    readonly property real cardTop: {
        const screen = root.targetScreen;
        const top = screen ? screen.y : 0;
        const height = screen ? screen.height : 1080;
        const desired = MoveMenuState.anchorY + 26;
        return Math.max(top + 8,
            Math.min(top + height - root.cardHeight - 8, desired));
    }

    // Ventana que pidió el menú. Si ya no existe, el selector se cierra.
    readonly property var moveWindow: {
        const list = CompositorState.windows || [];
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].address) === MoveMenuState.windowId
                    || String(list[i].id) === MoveMenuState.windowId)
                return list[i];
        }
        return null;
    }
    readonly property int currentWorkspace: root.moveWindow
        ? Number(root.moveWindow.workspaceId) || 0 : 0

    visible: MoveMenuState.open && root.moveWindow !== null
    screen: root.targetScreen

    anchors {
        top: true
        left: true
    }
    margins {
        left: Math.round(root.cardLeft
            - (root.targetScreen ? root.targetScreen.x : 0))
        top: Math.round(root.cardTop
            - (root.targetScreen ? root.targetScreen.y : 0))
    }
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-move-menu"
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (!root.visible)
            MoveMenuState.hide();
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: MoveMenuState.hide()
    }

    function choose(workspace): void {
        const target = Number(workspace) || 0;
        if (target <= 0 || root.moveWindow === null) {
            MoveMenuState.hide();
            return;
        }
        // Igual que el mockup: pulsar el escritorio actual solo cierra.
        if (target === root.currentWorkspace) {
            MoveMenuState.hide();
            return;
        }
        const address = String(root.moveWindow.address
            || root.moveWindow.id || "");
        MoveMenuState.hide();
        if (address.length > 0)
            CompositorState.moveToWorkspace(address, target);
    }

    Rectangle {
        anchors.fill: parent
        radius: 13
        color: Theme.glassMenu
        border.width: 1
        border.color: Theme.borderStrong

        Column {
            anchors {
                fill: parent
                margins: root.padding
            }
            spacing: root.gap

            Repeater {
                model: SettingsState.workspaceIds

                delegate: Rectangle {
                    required property int modelData

                    readonly property bool current:
                        root.currentWorkspace === modelData
                    readonly property var workspaceInfo: {
                        const list = CompositorState.workspaces || [];
                        for (let i = 0; i < list.length; i++) {
                            if (Number(list[i].id) === modelData)
                                return list[i];
                        }
                        return null;
                    }

                    width: root.cardWidth - root.padding * 2
                    height: root.rowHeight
                    radius: 8
                    color: current
                        ? Theme.accentSoft
                        : (rowMouse.containsMouse
                            ? Theme.hover : "transparent")
                    border.width: current ? 1 : 0
                    border.color: current
                        ? Theme.accentLine : "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 7
                        color: current
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g,
                                Theme.accent.b, 0.20)
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: current ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.choose(modelData)
                    }
                }
            }
        }
    }
}
