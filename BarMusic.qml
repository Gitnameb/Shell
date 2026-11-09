import QtQuick
import QtQuick.Effects

// Reproductor compacto de la barra. Muestra portada, título y artista; al
// pasar el ratón los sustituye por los controles, como en el ejemplo web.
Pill {
    id: root

    property string key: "music"

    active: MusicState.playing
    draggable: true
    // La portada y el bloque de texto comparten la misma caja que el resto de
    // widgets de la barra. La píldora completa mide Theme.itemHeight igual que
    // los demás controles, pero el contenido no sobresale por arriba ni por
    // abajo.
    horizontalPadding: 3
    // Mientras se mantiene Super, el borde derecho estira la píldora para
    // leer títulos largos, como el modo de configuración rápida del mockup.
    // En la barra vertical solo se muestra la portada: el título y el
    // artista no caben en 44 px.
    readonly property bool compact: SettingsState.barVertical
    preferredWidth: root.compact ? 0 : SettingsState.musicWidth
    // Ancho del bloque de texto. Se calcula desde el ancho elegido, nunca
    // desde root.width: si dependiera del ancho real, la píldora y su
    // contenido se darían tamaño mutuamente y la barra temblaría al
    // mantener Super. La suma fija es portada (barIconSize) + espacio (4) +
    // relleno horizontal (3 + 3).
    readonly property real textWidth: root.compact ? 0
        : (SettingsState.musicWidth <= 0
            ? 90
            : Math.max(90, SettingsState.musicWidth
                - (SettingsState.barIconSize + 10)))

    onClicked: {
        const point = root.mapToItem(null, root.width / 2, root.height / 2);
        QuickPanelState.toggle("music", point.x, point.y);
    }
    onDragStarted: ControlDrag.begin("music", "Música", "bar")
    onDragFinished: ControlDrag.end()
    onDragCanceled: ControlDrag.cancel()

    Row {
        spacing: 4

        Rectangle {
            id: cover

            anchors.verticalCenter: parent.verticalCenter
            // Portada del mismo alto que el resto de iconos de la barra.
            width: SettingsState.barIconSize
            height: SettingsState.barIconSize
            radius: 6
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

            ShellIcon {
                anchors.centerIn: parent
                visible: !coverImage.visible
                source: ShellIcons.src("music")
                color: Theme.accent
                size: Math.min(18, SettingsState.barIconSize)
                fallback: "♪"
            }

            // Máscara de la portada: rectángulo blanco con el radio del
            // widget. Vive oculta porque solo se usa como textura.
            Rectangle {
                id: coverMask

                anchors.fill: parent
                radius: 6
                color: "white"
                visible: false
                layer.enabled: true
            }
        }

        Item {
            width: root.textWidth
            height: SettingsState.barIconSize
            visible: !root.compact

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
                    width: 22
                    height: 20
                    radius: 6
                    color: prevMouse.containsMouse ? Theme.hover : "transparent"

                    ShellIcon {
                        anchors.centerIn: parent
                        source: ShellIcons.src("prev")
                        color: MusicState.canGoPrevious
                            ? Theme.muted : Theme.faint
                        size: Math.min(14, SettingsState.barIconSize)
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
                    width: 24
                    height: 20
                    radius: 6
                    color: playMouse.containsMouse ? Theme.accentSoft : "transparent"

                    ShellIcon {
                        anchors.centerIn: parent
                        source: ShellIcons.src(MusicState.playing
                            ? "pause" : "play")
                        color: Theme.accent
                        size: Math.min(14, SettingsState.barIconSize)
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
                    width: 22
                    height: 20
                    radius: 6
                    color: nextMouse.containsMouse ? Theme.hover : "transparent"

                    ShellIcon {
                        anchors.centerIn: parent
                        source: ShellIcons.src("next")
                        color: MusicState.canGoNext
                            ? Theme.muted : Theme.faint
                        size: Math.min(14, SettingsState.barIconSize)
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
    }

    // Asa de estirado. Solo aparece en el modo ventanas (Super mantenido o
    // fijado) para no robar clics al reproductor en reposo.
    Rectangle {
        id: resizeHandle

        // Pill.qml manda por defecto todos los hijos a su fila de contenido.
        // El asa no debe formar parte de esa fila: sin este parent explícito
        // su ancho y sus anclas desplazan el título al aparecer con Super.
        parent: root
        visible: SuperState.active && !root.compact
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
