import QtQuick
import QtQuick.Controls

// Deslizador compacto reutilizable para las vistas del centro de control.
Slider {
    id: root

    property color fillColor: Theme.accent

    implicitWidth: 140
    implicitHeight: 24

    // Los controles de volumen, brillo y micrófono suben/bajan de 2 en 2.
    stepSize: 0.02

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 6
        radius: 3
        color: Theme.surface

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: 3
            color: root.enabled ? root.fillColor : Theme.faint
        }
    }

    handle: Rectangle {
        x: root.leftPadding
            + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 13
        height: 13
        radius: 7
        color: root.enabled ? Theme.accent : Theme.faint
    }
}
