import Quickshell
import QtQuick

// Batería dibujada como en el ejemplo web: contorno redondeado, pista interior,
// relleno que crece con transición, rayo amarillo al cargar y barrido del
// contorno de izquierda a derecha. No usa emoji ni el icono genérico del tema.
Item {
    id: root

    property real iconSize: 22
    property int percentage: -1
    property bool present: false
    property bool charging: false
    property bool mains: false
    property color tone: Theme.text

    readonly property real bodyWidth: Math.max(17,
        Math.round(root.iconSize * 25 / 24))
    readonly property real bodyHeight: Math.max(9,
        Math.round(root.iconSize * 13 / 24))
    readonly property real tipWidth: Math.max(2,
        Math.round(root.iconSize * 2 / 24))
    readonly property real borderWidth: Math.max(1,
        root.iconSize / 19.2)
    readonly property real radius: Math.max(2.5,
        root.iconSize * 0.145)
    readonly property real level: root.present
        ? Math.max(0, Math.min(1, root.percentage / 100)) : 0
    readonly property color borderTone: Qt.rgba(root.tone.r,
        root.tone.g, root.tone.b, 0.58)
    readonly property color trackColor: Theme.light
        ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.09)
    readonly property bool showBolt: root.charging || root.mains
    // En un equipo de sobremesa no hay batería, pero el barrido del contorno
    // sigue indicando que hay corriente, igual que el cargador del mockup.
    readonly property bool chargeLook: root.charging || root.mains

    implicitWidth: root.bodyWidth + root.tipWidth
    implicitHeight: root.bodyHeight

    Rectangle {
        id: shell

        width: root.bodyWidth
        height: root.bodyHeight
        radius: root.radius
        color: "transparent"
        border.width: root.borderWidth
        border.color: root.borderTone

        Behavior on border.color {
            ColorAnimation { duration: 250; easing.type: Easing.OutQuad }
        }

        Rectangle {
            id: track

            anchors.fill: parent
            anchors.margins: Math.max(2, Math.round(root.iconSize * 0.085))
            radius: 1
            color: root.trackColor
            clip: true

            Rectangle {
                id: fill

                height: parent.height
                width: parent.width * root.level
                radius: 1
                color: root.tone

                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.Linear }
                }
                Behavior on color {
                    ColorAnimation { duration: 250; easing.type: Easing.OutQuad }
                }
            }
        }

        // El contorno se ilumina de izquierda a derecha mientras hay
        // corriente. El recorte deja ver solo la parte izquierda del borde,
        // igual que el clip-path del CSS.
        Item {
            id: chargeClip

            x: 0
            y: 0
            width: 0
            height: shell.height
            clip: true
            visible: root.chargeLook

            Rectangle {
                id: chargeBorder

                width: shell.width
                height: shell.height
                radius: shell.radius
                color: "transparent"
                border.width: shell.border.width
                border.color: "#ffffff"
                opacity: 1
            }
        }

        // Rayo amarillo con contorno oscuro, como en el mockup.
        Image {
            anchors.centerIn: parent
            width: Math.round(root.bodyHeight * 1.05)
            height: Math.round(root.bodyHeight * 1.28)
            source: AlbaIcons.src("battery-bolt")
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: root.showBolt
        }
    }

    // Punta de la batería. También se ilumina al final del barrido.
    Rectangle {
        id: tip

        x: shell.width
        y: Math.round((root.bodyHeight - tip.height) / 2)
        width: root.tipWidth
        height: Math.max(3, Math.round(root.bodyHeight * 0.27))
        radius: Math.min(1.5, width / 2)
        color: root.chargeLook && chargeTip ? "#ffffff" : root.borderTone

        Behavior on color {
            ColorAnimation { duration: 80 }
        }
    }

    property bool chargeTip: false

    SequentialAnimation {
        running: root.chargeLook
        loops: Animation.Infinite

        PropertyAction { target: chargeClip; property: "width"; value: 0 }
        PropertyAction { target: chargeBorder; property: "opacity"; value: 0 }
        PropertyAction { target: root; property: "chargeTip"; value: false }

        NumberAnimation {
            target: chargeBorder
            property: "opacity"
            from: 0
            to: 1
            duration: 40
        }
        NumberAnimation {
            target: chargeClip
            property: "width"
            from: 0
            to: shell.width
            duration: 220
            easing.type: Easing.Linear
        }
        PropertyAction { target: root; property: "chargeTip"; value: true }
        NumberAnimation {
            target: chargeBorder
            property: "opacity"
            from: 1
            to: 0
            duration: 100
        }
        PauseAnimation { duration: 70 }
        PropertyAction { target: root; property: "chargeTip"; value: false }
        PauseAnimation { duration: 570 }
    }
}
