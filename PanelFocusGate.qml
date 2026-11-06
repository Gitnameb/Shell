import QtQuick

// Retrasa un instante el foco de teclado de un panel.
//
// En Hyprland, cuando un panel nuevo se mapea con `WlrKeyboardFocus.OnDemand`,
// la barra pierde el foco del puntero y el primer clic sobre ella se ignora
// hasta que el ratón se mueve. Eso hacía que el panel no se pudiera cerrar al
// instante pulsando otra vez su botón. Manteniéndolo sin foco de teclado
// durante el primer fotograma y activándolo después, el clic llega enseguida y
// los campos de texto siguen recibiendo el teclado cuando se pulsa dentro.
Item {
    id: root

    property bool active: false
    property bool ready: false
    property int delay: 150

    visible: false
    width: 0
    height: 0

    onActiveChanged: {
        if (root.active) {
            root.ready = false;
            gateTimer.restart();
        } else {
            gateTimer.stop();
            root.ready = false;
        }
    }

    Component.onCompleted: {
        if (root.active)
            gateTimer.restart();
    }

    Timer {
        id: gateTimer
        interval: root.delay
        repeat: false
        onTriggered: root.ready = true
    }
}
