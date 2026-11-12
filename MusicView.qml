import QtQuick
import QtQuick.Layouts

// Vista avanzada de Música: portada, progreso, controles y selector de
// reproductor cuando hay más de uno expuesto por MPRIS.
ColumnLayout {
    id: root

    spacing: 8

    // Texto de estado del botón de letras. Se calcula aquí para que las
    // dependencias de LyricsState y MusicState queden claras.
    function lyricsStatus(): string {
        if (LyricsState.loading)
            return "Buscando letras…";
        if (LyricsState.available)
            return "Letras sincronizadas · " + LyricsState.lines.length
                + " líneas";
        if (MusicState.trackUrl.length === 0 || !LyricsState.localSource)
            return "Este reproductor no publica la ruta del archivo";
        if (LyricsState.checked)
            return "Esta pista no tiene letras sincronizadas";
        return "";
    }

    // ------------------------------------------------------- selector
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 3
        visible: MusicState.players.length > 1

        Text {
            Layout.fillWidth: true
            text: "REPRODUCTORES"
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 8
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        Repeater {
            model: MusicState.players

            Rectangle {
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 28
                radius: 7
                color: MusicState.player === modelData
                    ? Theme.accentSoft : "transparent"
                border.width: MusicState.player === modelData ? 1 : 0
                border.color: Theme.accentLine

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 8
                        rightMargin: 8
                    }
                    spacing: 6

                    Rectangle {
                        width: 7
                        height: 7
                        radius: 4
                        color: modelData.isPlaying ? Theme.accent : Theme.faint
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.identity || "Reproductor"
                        color: MusicState.player === modelData
                            ? Theme.accent : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Text {
                        text: modelData.isPlaying ? "Sonando" : "Pausado"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MusicState.select(modelData)
                }
            }
        }
    }

    // ------------------------------------------------------- reproductor
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 72
            Layout.preferredHeight: 72
            radius: 11
            color: Theme.surfaceAlt
            clip: true

            Image {
                id: art

                anchors.fill: parent
                source: MusicState.artUrl
                sourceSize.width: 160
                sourceSize.height: 160
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                visible: status === Image.Ready
            }

            ShellIcon {
                anchors.centerIn: parent
                visible: !art.visible
                source: ShellIcons.src("music")
                color: Theme.accent
                size: 30
                fallback: "♪"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: MusicState.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: MusicState.artist
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: MusicState.album.length > 0
                text: MusicState.album
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 9
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: MusicState.identity
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                elide: Text.ElideRight
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: !MusicState.available
        text: "Sin reproducción"
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 9
        wrapMode: Text.Wrap
    }

    // ------------------------------------------------------- letras
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: MusicState.available

        Rectangle {
            id: lyricsButton

            Layout.fillWidth: true
            implicitHeight: 30
            radius: 8
            color: SettingsState.lyricsEnabled
                ? Theme.accentSoft : Theme.surfaceAlt
            border.width: 1
            border.color: SettingsState.lyricsEnabled
                ? Theme.accentLine : Theme.border

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 9
                    rightMargin: 9
                }
                spacing: 7

                ShellIcon {
                    name: "view-media-lyrics"
                    fallbackName: "amarok_lyrics"
                    color: SettingsState.lyricsEnabled
                        ? Theme.accent : Theme.muted
                    size: 15
                    fallback: "♪"
                }

                Text {
                    text: "Letras"
                    color: SettingsState.lyricsEnabled
                        ? Theme.accent : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: SettingsState.lyricsEnabled
                        ? "Activadas" : "Desactivadas"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsState.lyricsEnabled
                    = !SettingsState.lyricsEnabled
            }
        }

        Text {
            Layout.fillWidth: true
            visible: SettingsState.lyricsEnabled
            text: root.lyricsStatus()
            color: LyricsState.available
                ? Theme.muted : Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 8
            wrapMode: Text.Wrap
        }

        // Vista rápida de las mismas tres líneas que enseña la barra.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            visible: SettingsState.lyricsEnabled && LyricsState.available

            Text {
                Layout.fillWidth: true
                text: LyricsState.previousLine
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 9
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: LyricsState.currentLine
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: LyricsState.nextLine
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }
    }

    // ------------------------------------------------------- progreso
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        visible: MusicState.available

        ShellSlider {
            id: seek

            Layout.fillWidth: true
            // Sin duración conocida (directos) no hay progreso que mostrar:
            // con `to` en 1 s la barra se llenaba entera al poco de empezar.
            visible: MusicState.length > 0
            from: 0
            to: Math.max(1, MusicState.length)
            stepSize: 1
            enabled: MusicState.canSeek
            fillColor: Theme.accent
            onMoved: MusicState.seek(value)

            Binding {
                target: seek
                property: "value"
                value: MusicState.position
                when: !seek.pressed
                restoreMode: Binding.RestoreNone
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: MusicState.timeLabel(seek.value)
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: MusicState.timeLabel(MusicState.length)
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
            }
        }
    }

    // ------------------------------------------------------- controles
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 6
        visible: MusicState.available

        Item {
            Layout.fillWidth: true
        }

        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: prevMouse.containsMouse ? Theme.hover : "transparent"

            ShellIcon {
                anchors.centerIn: parent
                name: "media-skip-backward"
                color: MusicState.canGoPrevious ? Theme.muted : Theme.faint
                size: 18
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
            width: 44
            height: 44
            radius: 22
            color: playMouse.containsMouse ? Theme.accent : Theme.accentSoft
            border.width: 1
            border.color: Theme.accentLine

            ShellIcon {
                anchors.centerIn: parent
                name: MusicState.playing
                    ? "media-playback-pause" : "media-playback-start"
                color: playMouse.containsMouse
                    ? Theme.accentInk : Theme.accent
                size: 21
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
            width: 32
            height: 32
            radius: 16
            color: nextMouse.containsMouse ? Theme.hover : "transparent"

            ShellIcon {
                anchors.centerIn: parent
                name: "media-skip-forward"
                color: MusicState.canGoNext ? Theme.muted : Theme.faint
                size: 18
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

        Item {
            Layout.fillWidth: true
        }
    }

    // ------------------------------------------------------- volumen
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: MusicState.canSetVolume

        ShellIcon {
            source: ShellIcons.src("volume-2")
            color: Theme.muted
            size: 14
            fallback: "◖"
        }

        ShellSlider {
            id: volume

            Layout.fillWidth: true
            from: 0
            to: 1
            stepSize: 0.02
            value: MusicState.player ? MusicState.player.volume : 0
            onMoved: MusicState.setVolume(value)

            Binding {
                target: volume
                property: "value"
                value: MusicState.player ? MusicState.player.volume : 0
                when: !volume.pressed
                restoreMode: Binding.RestoreNone
            }
        }

        Text {
            text: Math.round(volume.value * 100) + "%"
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 8
        }
    }
}
