import Quickshell
import QtQuick

// Icono de nivel para volumen y micrófono. Usa los mismos iconos del tema
// (Breeze) que el aviso flotante, de modo que la barra, el centro de control y
// el OSD muestran exactamente el mismo dibujo. El tema ya trae una variante
// para cada tramo: bajo, medio y alto, además de la silenciada.
Item {
    id: root

    property string kind: "volume"
    property real level: 0
    property bool muted: false
    property color color: Theme.accent
    property real size: 16
    property string fallback: ""

    readonly property string state: root.muted
        ? "muted"
        : (root.level < 0.333
            ? "low"
            : (root.level < 0.666 ? "medium" : "high"))
    readonly property string iconName: (root.kind === "mic"
        ? "microphone-sensitivity-" : "audio-volume-") + root.state

    implicitWidth: root.size
    implicitHeight: root.size

    AlbaIcon {
        anchors.fill: parent
        name: root.iconName
        fallbackName: root.kind === "mic"
            ? "microphone-sensitivity-high" : "audio-volume-high"
        color: root.color
        size: root.size
        fallback: root.fallback
    }
}
