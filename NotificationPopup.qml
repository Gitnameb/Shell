import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Tarjetas emergentes de notificación. Aparecen en la esquina superior derecha
// unos segundos y se apilan, como en el resto de escritorios. Un clic abre el
// panel de notificaciones; la «×» descarta el aviso (y con las alarmas, corta
// el sonido).
//
// El modelo es un ListModel y no un array: al llegar un aviso se inserta una
// tarjeta nueva sin reconstruir las anteriores, así que solo la nueva hace la
// animación de entrada.
PanelWindow {
    id: root

    readonly property var entries: NotificationState.bannerModel
    // La tarjeta aparece en el monitor de la ventana enfocada; si no hay
    // ninguna, en el primero.
    readonly property var targetScreen: {
        const win = CompositorState.focusedWindow;
        const screen = win ? WindowLook.screenFor(win.monitor) : null;
        return screen || (Quickshell.screens.length > 0
            ? Quickshell.screens[0] : null);
    }
    // Mismo ancho que el panel lateral y mismo margen que la barra, para que
    // los avisos queden alineados con el resto del shell.
    readonly property int cardWidth: {
        const available = root.targetScreen
            ? Number(root.targetScreen.width) : 1280;
        return Math.max(260, Math.min(360, available - Theme.edge * 2));
    }

    visible: root.entries.count > 0
        && !NotificationState.panelOpen
        && !NotificationState.dnd
        && !CompositorState.overviewOpen
    screen: root.targetScreen
    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.edge
            + (SettingsState.barAtTop ? Theme.barHeight + 10 : 0)
        right: Theme.edge
            + (SettingsState.barAtRight ? Theme.barHeight + 10 : 0)
    }
    implicitWidth: root.cardWidth
    implicitHeight: Math.max(1, cards.implicitHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-notification-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Column {
        id: cards

        width: parent.width
        spacing: 8

        Repeater {
            model: root.entries

            delegate: Rectangle {
                id: card

                required property int key
                required property int notifId
                required property string appName
                required property string appKey
                required property string desktopEntry
                required property string icon
                required property string summary
                required property string body
                required property bool persistent
                required property int timeout
                required property int urgency
                required property double stamp

                readonly property bool critical: Number(card.urgency) === 2

                width: cards.width
                height: Math.max(66, content.implicitHeight + 20)
                radius: 12
                color: Theme.glassRaised
                border.width: 1
                border.color: cardMouse.containsMouse
                    ? Theme.borderStrong : Theme.border
                opacity: 0

                Component.onCompleted: appear.start()

                NumberAnimation {
                    id: appear

                    target: card
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 170
                    easing.type: Easing.OutQuad
                }

                // Una franja fina marca los avisos críticos sin teñir la
                // tarjeta entera.
                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        margins: 1
                    }
                    width: 3
                    radius: 2
                    color: card.critical ? Theme.danger : Theme.accent
                    opacity: card.critical ? 0.9 : 0.35
                }

                MouseArea {
                    id: cardMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationState.showPanel()
                }

                Timer {
                    id: hideTimer

                    interval: card.timeout || 5000
                    running: !card.persistent && !cardMouse.containsMouse
                    onTriggered: NotificationState.removeBanner(card.key)
                }

                RowLayout {
                    id: content

                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 8
                        topMargin: 10
                        bottomMargin: 10
                    }
                    spacing: 9

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignTop
                        radius: 8
                        color: WindowLook.tintFor(
                            WindowLook.colorFor(card.appKey))

                        Image {
                            id: appIcon

                            anchors {
                                fill: parent
                                margins: 4
                            }
                            source: NotificationLook.iconSource(card)
                            visible: status === Image.Ready
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !appIcon.visible
                            text: WindowLook.letterFor(card.appKey)
                            color: WindowLook.colorFor(card.appKey)
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: card.appName
                                color: Theme.faint
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }

                            Rectangle {
                                id: closeButton

                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                radius: 5
                                color: closeMouse.containsMouse
                                    ? Theme.hover : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: closeMouse.containsMouse
                                        ? Theme.text : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    id: closeMouse

                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationState.dismissBanner(
                                        card.key)
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.summary
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: card.body
                            color: Theme.muted
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                        }
                    }
                }
            }
        }
    }
}
