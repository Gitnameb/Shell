import Quickshell
import QtQuick

// Icono de nivel para volumen y micrófono en la barra, el centro y el OSD.
// Ambos usan SVG propios con el mismo trazo que el resto de iconos, para no
// depender del tema ni mezclar estilos rellenos y de línea.
Item {
    id: root

    property string kind: "volume"
    property real level: 0
    property bool muted: false
    property color color: Theme.accent
    property real size: 16
    property string fallback: ""

    readonly property string state: root.muted
        ? "off"
        : (root.level < 0.333
            ? "1"
            : (root.level < 0.666 ? "2" : "3"))
    readonly property string iconSource: root.kind === "mic"
        ? ShellIcons.src(root.muted ? "mic-off" : "mic")
        : ShellIcons.src("volume-" + root.state)

    implicitWidth: root.size
    implicitHeight: root.size

    ShellIcon {
        anchors.fill: parent
        source: root.iconSource
        color: root.color
        size: root.size
        fallback: root.fallback
    }
}
