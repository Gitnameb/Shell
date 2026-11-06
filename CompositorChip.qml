import QtQuick

// Chip pequeño y reutilizable para las acciones del compositor. Mantiene el
// mismo lenguaje visual que el resto de ALBA: borde fino, acento cuando la
// acción ya está activa y rojo solo para lo destructivo.
Rectangle {
    id: root

    property string label: ""
    property bool active: false
    property bool danger: false
    signal clicked()

    implicitWidth: chipText.implicitWidth + 16
    implicitHeight: 18
    radius: 5
    color: root.active
        ? Theme.accentSoft
        : (chipMouse.containsMouse ? Theme.hover : Theme.surface)
    border.width: 1
    border.color: root.active ? Theme.accentLine : Theme.border

    Text {
        id: chipText

        anchors.centerIn: parent
        text: root.label
        color: root.danger
            ? Theme.danger
            : (root.active ? Theme.accent : Theme.muted)
        font.family: Theme.fontFamily
        font.pixelSize: 7
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: chipMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
