import Quickshell
import Quickshell.Wayland
import QtQuick

// Filtro de pantalla para compositores sin shader global (Umbriel).
//
// En Hyprland la atenuación extra y la luz nocturna las aplica
// `decoration:screen_shader`. Umbriel no tiene ese ajuste, así que se dibuja
// una capa por encima de las ventanas con dos rectángulos: uno negro para
// oscurecer y otro cálido para la luz nocturna. La máscara vacía deja pasar
// todos los clics, de modo que el escritorio sigue siendo usable.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: filter

        required property var modelData
        screen: modelData

        readonly property real dark: DisplayState.overlayDark
        readonly property real warm: DisplayState.overlayWarm
        // Con filtro nativo (Umbriel) o shader de Hyprland esta capa no se usa.
        readonly property bool fallback:
            !CompositorState.supports("screenShader")
                && !CompositorState.supports("displayFilter")

        visible: filter.fallback && (dark > 0.002 || warm > 0.002)
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "shell-filter"
        mask: Region {}

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, filter.dark)
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(1.0, 0.78, 0.58, filter.warm)
        }
    }
}
