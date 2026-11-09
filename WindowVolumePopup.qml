import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Volumen de una ventana concreta. Lo abre el botón de altavoz de la barra de
// título nativa. Es una capa modal transparente: un clic fuera cierra, y la
// tarjeta controla el flujo de PipeWire de esa aplicación.
PanelWindow {
    id: root

    property bool open: false
    property string windowId: ""
    property real anchorX: 0
    property real anchorY: 0

    readonly property var win: root.open
        ? CompositorState.windowById(root.windowId) : null
    readonly property var stream: Audio.primaryStreamForWindow(root.win)
    readonly property var targetScreen: {
        const x = root.anchorX;
        const y = root.anchorY;
        const list = Quickshell.screens || [];
        for (let i = 0; i < list.length; i++) {
            const screen = list[i];
            if (x >= screen.x && x < screen.x + screen.width
                    && y >= screen.y && y < screen.y + screen.height)
                return screen;
        }
        return list.length > 0 ? list[0] : null;
    }
    readonly property int cardWidth: 282
    readonly property int cardHeight: 122
    readonly property real cardX: {
        const screen = root.targetScreen;
        const left = screen ? screen.x : 0;
        const width = screen ? screen.width : 1920;
        const desired = root.anchorX - root.cardWidth / 2;
        return Math.max(left + 8,
            Math.min(left + width - root.cardWidth - 8, desired));
    }
    readonly property real cardY: {
        const screen = root.targetScreen;
        const top = screen ? screen.y : 0;
        const height = screen ? screen.height : 1080;
        const desired = root.anchorY + 14;
        return Math.max(top + 8,
            Math.min(top + height - root.cardHeight - 8, desired));
    }

    visible: root.open
    screen: root.targetScreen
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
    WlrLayershell.namespace: "shell-window-volume"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function show(id, x, y): void {
        const value = String(id || "");
        if (value.length === 0)
            return;
        LauncherState.hide();
        NotificationState.hidePanel();
        QuickPanelState.hide();
        CalendarState.hide();
        PowerState.hide();
        BatteryState.hide();
        TrayState.hide();
        root.windowId = value;
        root.anchorX = Number(x) || 0;
        root.anchorY = Number(y) || 0;
        root.open = true;
    }

    function hide(): void {
        root.open = false;
        root.windowId = "";
    }

    onWinChanged: {
        if (root.open && root.win === null)
            root.hide();
    }

    Connections {
        target: QuickPanelState

        function onOpened(): void {
            if (root.open)
                root.hide();
        }
    }

    Connections {
        target: NotificationState

        function onPanelOpenChanged(): void {
            if (NotificationState.panelOpen && root.open)
                root.hide();
        }
    }

    Connections {
        target: CalendarState

        function onOpenChanged(): void {
            if (CalendarState.open && root.open)
                root.hide();
        }
    }

    Connections {
        target: LauncherState

        function onOpenChanged(): void {
            if (LauncherState.open && root.open)
                root.hide();
        }
    }

    Connections {
        target: PowerState

        function onOpenChanged(): void {
            if (PowerState.open && root.open)
                root.hide();
        }
    }

    Connections {
        target: BatteryState

        function onOpenChanged(): void {
            if (BatteryState.open && root.open)
                root.hide();
        }
    }

    Connections {
        target: TrayState

        function onOpened(): void {
            if (root.open)
                root.hide();
        }
    }

    // Fuera de la tarjeta, cualquier pulsación solo cierra.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.hide()
    }

    Rectangle {
        id: card

        x: root.cardX - (root.targetScreen ? root.targetScreen.x : 0)
        y: root.cardY - (root.targetScreen ? root.targetScreen.y : 0)
        width: root.cardWidth
        height: root.cardHeight
        radius: 13
        color: Theme.glassMenu
        border.width: 1
        border.color: Theme.borderStrong

        // La tarjeta consume los clics; los controles de dentro van por encima.
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.AllButtons
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 8
                    color: root.win
                        ? WindowLook.tintFor(WindowLook.colorFor(
                            root.win.appId || root.win.class))
                        : Theme.surfaceAlt

                    Image {
                        id: appIcon

                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: root.win
                            ? WindowLook.iconFor(root.win.appId
                                || root.win.class) : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        text: root.win
                            ? WindowLook.letterFor(root.win.appId
                                || root.win.class) : "?"
                        color: root.win
                            ? WindowLook.colorFor(root.win.appId
                                || root.win.class) : Theme.faint
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
                        text: root.win
                            ? WindowLook.nameFor(root.win.appId
                                || root.win.class) : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.win ? String(root.win.title || "") : ""
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18

                    ShellIcon {
                        anchors.fill: parent
                        source: ShellIcons.src(root.stream
                            && root.stream.audio
                            && root.stream.audio.muted
                            ? "volume-off" : "volume-3")
                        color: root.stream && root.stream.audio
                            && root.stream.audio.muted
                            ? Theme.danger : Theme.muted
                        size: 16
                        fallback: "◖"
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        enabled: root.stream !== null
                        cursorShape: root.stream !== null
                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: Audio.toggleNodeMute(root.stream)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Volumen"
                    color: root.stream !== null ? Theme.text : Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    text: root.stream && root.stream.audio
                        ? (root.stream.audio.muted ? "Mudo"
                            : Math.round(root.stream.audio.volume * 100) + "%")
                        : "—"
                    color: root.stream && root.stream.audio
                        && root.stream.audio.muted
                        ? Theme.danger : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            ShellSlider {
                id: volumeSlider

                Layout.fillWidth: true
                enabled: root.stream !== null
                from: 0
                to: 1
                stepSize: 0.02
                value: root.stream && root.stream.audio
                    ? root.stream.audio.volume : 0
                onMoved: Audio.setNodeVolume(root.stream, value)
            }

            Binding {
                target: volumeSlider
                property: "value"
                value: root.stream && root.stream.audio
                    ? root.stream.audio.volume : 0
                when: !volumeSlider.pressed
            }
        }
    }
}
