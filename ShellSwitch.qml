import QtQuick

// Interruptor simple, sin depender del estilo de QtQuick Controls.
Rectangle {
    id: root

    property bool checked: false
    property bool enabled: true
    signal toggled()

    implicitWidth: 38
    implicitHeight: 22
    radius: 11
    color: checked ? Theme.accent : Theme.surfaceAlt
    border.width: 1
    border.color: checked ? Theme.accent : Theme.borderStrong
    opacity: enabled ? 1 : 0.45

    Rectangle {
        width: 16
        height: 16
        radius: 8
        y: 2
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.accentInk : Theme.muted
        Behavior on x {
            NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggled()
    }
}
