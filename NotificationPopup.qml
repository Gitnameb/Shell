import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Tarjetas emergentes de notificación. Aparecen en la esquina superior derecha
// unos segundos y se apilan, como en el resto de escritorios. Un clic abre el
// panel de notificaciones; la «×» descarta el aviso (y con las alarmas, corta
// el sonido).
PanelWindow {
    id: root

    readonly property var entries: NotificationState.banners || []
    // La tarjeta aparece en el monitor de la ventana enfocada; si no hay
    // ninguna, en el primero.
    readonly property var targetScreen: {
        const win = CompositorState.focusedWindow;
        const screen = win ? WindowLook.screenFor(win.monitor) : null;
        return screen || (Quickshell.screens.length > 0
            ? Quickshell.screens[0] : null);
    }
    readonly property int cardWidth: {
        const available = root.targetScreen
            ? Number(root.targetScreen.width) - 48 : 340;
        return Math.max(240, Math.min(340, available));
    }

    visible: root.entries.length > 0
        && !NotificationState.panelOpen
        && !NotificationState.dnd
        && !CompositorState.overviewOpen
    screen: root.targetScreen
    anchors {
        top: true
        right: true
    }
    margins {
        top: SettingsState.barAtTop
            ? Theme.edge + Theme.barHeight + 12 : Theme.edge + 12
        right: SettingsState.barAtRight
            ? Theme.edge + Theme.barHeight + 12 : Theme.edge + 12
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

                required property var modelData

                readonly property bool persistent: modelData.persistent === true
                readonly property bool critical: Number(modelData.urgency) === 2

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

                    interval: card.modelData.timeout || 5000
                    running: !card.persistent && !cardMouse.containsMouse
                    onTriggered: NotificationState.removeBanner(
                        card.modelData.key)
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
                            WindowLook.colorFor(card.modelData.appKey))

                        Image {
                            id: appIcon

                            anchors {
                                fill: parent
                                margins: 4
                            }
                            source: NotificationLook.iconSource(card.modelData)
                            visible: status === Image.Ready
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !appIcon.visible
                            text: WindowLook.letterFor(card.modelData.appKey)
                            color: WindowLook.colorFor(card.modelData.appKey)
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
                                text: card.modelData.appName
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
                                        card.modelData.key)
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.summary
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: card.modelData.body
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
