import QtQuick

// Tecla de atajo compacta, como un botón pequeño. Se usa a la derecha de las
// opciones de ventana para recordar el atajo sin ocupar toda la fila.
Rectangle {
    id: root

    property string label: ""

    implicitWidth: shortcut.implicitWidth + 10
    implicitHeight: 16
    visible: root.label.length > 0
    radius: 4
    color: Theme.surfaceAlt
    border.width: 1
    border.color: Theme.border

    Text {
        id: shortcut

        anchors.centerIn: parent
        text: root.label
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        font.weight: Font.DemiBold
    }
}
