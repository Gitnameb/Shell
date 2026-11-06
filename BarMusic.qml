import QtQuick
import QtQuick.Effects

// Reproductor compacto de la barra. Muestra portada, título y artista; al
// pasar el ratón los sustituye por los controles, como en el ejemplo web.
Pill {
    id: root

    property string key: "music"

    active: MusicState.playing
    draggable: true
    // La portada llega hasta los bordes laterales de la píldora: sin relleno
    // izquierdo y con el ancho del texto compensado a la derecha.
    horizontalPadding: 0
    // Mientras se mantiene Super, el borde derecho estira la píldora para
    // leer títulos largos, como el modo de configuración rápida del mockup.
    preferredWidth: SettingsState.musicWidth
    // Ancho del bloque de texto. Se calcula desde el ancho elegido, nunca
    // desde root.width: si dependiera del ancho real, la píldora y su
    // contenido se darían tamaño mutuamente y la barra temblaría al
    // mantener Super. La suma fija es portada (34) + dos espacios (4 + 4)
    // + margen derecho (8).
    readonly property real textWidth: SettingsState.musicWidth <= 0
        ? 90
        : Math.max(90, SettingsState.musicWidth - 50)

    onClicked: {
        if (NotificationState.panelOpen
                && NotificationState.panelView === "music")
            NotificationState.hidePanel();
        else
            NotificationState.openPanelView("music");
    }
    onDragStarted: ControlDrag.begin("music", "Música", "bar")
    onDragFinished: ControlDrag.end()
    onDragCanceled: ControlDrag.cancel()

    Row {
        spacing: 4

        Rectangle {
            id: cover

            anchors.verticalCenter: parent.verticalCenter
            // Portada a todo el alto de la píldora, pegada al borde
            // izquierdo. La imagen se recorta con la misma curva que el
            // widget para que no asome ningún pico cuadrado.
            width: Theme.itemHeight
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: Theme.surfaceAlt
            clip: true

            Image {
                id: coverImage

                anchors.fill: parent
                source: MusicState.artUrl
                sourceSize.width: 128
                sourceSize.height: 128
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                visible: status === Image.Ready
                // `clip` solo recorta en rectángulo; la máscara redondea la
                // propia imagen igual que la píldora.
                layer.enabled: visible
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: coverMask
                }
            }

            AlbaIcon {
                anchors.centerIn: parent
                visible: !coverImage.visible
                source: AlbaIcons.src("music")
                color: Theme.accent
                size: Math.min(22, SettingsState.barIconSize)
                fallback: "♪"
            }

            // Máscara de la portada: rectángulo blanco con el radio del
            // widget. Vive oculta porque solo se usa como textura.
            Rectangle {
                id: coverMask

                anchors.fill: parent
                radius: Theme.itemRadius
                color: "white"
                visible: false
                layer.enabled: true
            }
        }

        Item {
            width: root.textWidth
            height: Theme.itemHeight

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 0
                visible: !root.hovered || !MusicState.available

                Text {
                    width: parent.width
                    text: MusicState.available ? MusicState.title : "Música"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: MusicState.available ? MusicState.artist : "Sin reproducción"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 0
                visible: root.hovered && MusicState.available

                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: prevMouse.containsMouse ? Theme.hover : "transparent"

                    AlbaIcon {
                        anchors.centerIn: parent
                        source: AlbaIcons.src("prev")
                        color: MusicState.canGoPrevious
                            ? Theme.muted : Theme.faint
                        size: Math.min(16, SettingsState.barIconSize)
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: MusicState.canGoPrevious
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicState.previous()
                    }
                }

                Rectangle {
                    width: 26
                    height: 24
                    radius: 6
                    color: playMouse.containsMouse ? Theme.accentSoft : "transparent"

                    AlbaIcon {
                        anchors.centerIn: parent
                        source: AlbaIcons.src(MusicState.playing
                            ? "pause" : "play")
                        color: Theme.accent
                        size: Math.min(16, SettingsState.barIconSize)
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicState.toggle()
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: nextMouse.containsMouse ? Theme.hover : "transparent"

                    AlbaIcon {
                        anchors.centerIn: parent
                        source: AlbaIcons.src("next")
                        color: MusicState.canGoNext
                            ? Theme.muted : Theme.faint
                        size: Math.min(16, SettingsState.barIconSize)
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: MusicState.canGoNext
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicState.next()
                    }
                }
            }
        }

        // Margen derecho para que el texto no toque el borde de la píldora
        // ahora que la portada ocupa todo el lado izquierdo.
        Item {
            width: 8
            height: 1
        }
    }

    // Asa de estirado. Solo aparece en el modo ventanas (Super mantenido o
    // fijado) para no robar clics al reproductor en reposo.
    Rectangle {
        id: resizeHandle

        // Pill.qml manda por defecto todos los hijos a su fila de contenido.
        // El asa no debe formar parte de esa fila: sin este parent explícito
        // su ancho y sus anclas desplazan el título al aparecer con Super.
        parent: root
        visible: SuperState.active
        z: 5
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            rightMargin: 2
            topMargin: 7
            bottomMargin: 7
        }
        width: 5
        radius: 3
        color: resizeMouse.containsMouse || resizeMouse.pressed
            ? Theme.accent : Theme.borderStrong

        MouseArea {
            id: resizeMouse

            anchors {
                fill: parent
                leftMargin: -4
                rightMargin: -2
            }
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            acceptedButtons: Qt.LeftButton
            preventStealing: true

            property real startX: 0
            property real startWidth: 0

            onPressed: (event) => {
                startX = mapToItem(null, event.x, 0).x;
                startWidth = root.width;
            }

            onPositionChanged: (event) => {
                if (!pressed)
                    return;
                const dx = mapToItem(null, event.x, 0).x - startX;
                SettingsState.setMusicWidth(startWidth + dx);
            }

            onDoubleClicked: SettingsState.setMusicWidth(0)
        }
    }
}
