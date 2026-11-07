import Quickshell
import QtQuick

// Icono de teclado que sustituye al texto del atajo en las opciones de
// ventana. Al pasar el ratón por encima, AppMenuItem muestra el atajo en un
// tooltip. No es un botón de configuración: editar atajos desde aquí exigiría
// escribir en la configuración de Umbriel y recargarla, con más riesgo que
// beneficio.
Rectangle {
    id: root

    property string label: ""
    property bool hovered: false

    implicitWidth: 22
    implicitHeight: 18
    visible: root.label.length > 0
    radius: 4
    color: root.hovered ? Theme.hover : Theme.surfaceAlt
    border.width: 1
    border.color: root.hovered ? Theme.borderStrong : Theme.border

    ShellIcon {
        anchors.centerIn: parent
        source: ShellIcons.src("keyboard")
        size: 11
        color: root.hovered ? Theme.text : Theme.faint
    }
}
