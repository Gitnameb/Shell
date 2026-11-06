import Quickshell
import Quickshell.Wayland
import QtQuick

// Fondo de pantalla del escritorio, en la capa más baja del compositor.
// Una ventana por pantalla; si no hay imagen elegida no dibuja nada y se ve
// el fondo propio de Umbriel.
Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        id: wallpaper

        required property var modelData

        screen: modelData
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "alba-wallpaper"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Si la imagen elegida ya no existe, se vuelve al color de fondo.
        property bool imageBroken: false

        Connections {
            target: SettingsState

            function onWallpaperPathChanged(): void {
                wallpaper.imageBroken = false;
            }
        }

        // Color de fondo cuando no hay imagen. También sirve de respaldo si
        // la imagen elegida desaparece del disco.
        Rectangle {
            anchors.fill: parent
            visible: (SettingsState.wallpaperPath.length === 0
                || wallpaper.imageBroken)
                && SettingsState.wallpaperColor.length > 0
            color: SettingsState.wallpaperColor.length > 0
                ? SettingsState.wallpaperColor : "transparent"
        }

        Image {
            anchors.fill: parent
            source: SettingsState.wallpaperPath.length > 0
                ? Qt.resolvedUrl("file://" + SettingsState.wallpaperPath)
                : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            visible: source != ""
            onStatusChanged: {
                if (status === Image.Error)
                    wallpaper.imageBroken = true;
            }
        }
    }
}
