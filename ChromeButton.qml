import Quickshell
import QtQuick

// Botón compacto de la barra de título / controles de ventana.
Rectangle {
    id: root

    property string iconName: ""
    property string fallbackName: ""
    property string source: ""
    property string glyph: ""
    property color tint: Theme.muted
    property color hoverTint: Theme.text
    property bool active: false
    property bool danger: false
    property string tip: ""

    signal clicked()

    implicitWidth: 24
    implicitHeight: 24
    radius: 6
    color: mouse.pressed
        ? (root.danger ? Qt.rgba(1, 0.35, 0.35, 0.20) : Theme.hover)
        : (mouse.containsMouse
            ? (root.danger ? Qt.rgba(1, 0.35, 0.35, 0.16) : Theme.hover)
            : (root.active ? Theme.accentSoft : "transparent"))
    border.width: root.active ? 1 : 0
    border.color: Theme.accentLine

    ShellIcon {
        id: icon

        anchors.centerIn: parent
        visible: root.source.length > 0 || root.iconName.length > 0
        source: root.source
        name: root.iconName
        fallbackName: root.fallbackName
        color: root.danger && mouse.containsMouse
            ? Theme.danger
            : (root.active ? Theme.accent
                : (mouse.containsMouse ? root.hoverTint : root.tint))
        size: 14
        fallback: root.glyph
    }

    Text {
        anchors.centerIn: parent
        visible: !icon.visible && root.glyph.length > 0
        text: root.glyph
        color: root.danger && mouse.containsMouse
            ? Theme.danger : (root.active ? Theme.accent : root.tint)
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
