import QtQuick
import QtQuick.Controls

// Pestaña del panel del reloj: calendario, clima, alarmas o temporizador.
Rectangle {
    id: root

    property string tabKey: ""
    property string label: ""
    property string iconName: ""
    property string iconSource: ""
    property string fallback: ""
    property bool selected: false
    signal activated()

    implicitHeight: 30
    radius: 7
    color: root.selected
        ? Theme.accentSoft
        : (mouse.containsMouse ? Theme.hover : "transparent")
    border.width: root.selected ? 1 : 0
    border.color: Theme.accentLine

    ShellIcon {
        anchors.centerIn: parent
        name: root.iconName
        source: root.iconSource
        color: root.selected ? Theme.accent : Theme.muted
        size: 15
        fallback: root.fallback
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    ToolTip.visible: mouse.containsMouse
    ToolTip.text: root.label
    ToolTip.delay: 350
}
