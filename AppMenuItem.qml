import QtQuick
import QtQuick.Layouts

// Fila del menú contextual de una app. Usa el icono del tema si existe y, si
// no, un glifo sencillo para no depender de un tema concreto.
Rectangle {
    id: root

    property string label: ""
    property string iconName: ""
    property string iconSource: ""
    property bool iconTint: true
    property string glyph: ""
    property string shortcut: ""
    property bool active: false
    property bool danger: false
    signal clicked()

    implicitHeight: 30
    radius: 7
    color: mouse.containsMouse && root.enabled
        ? Theme.hover
        : (root.active ? Theme.accentSoft : "transparent")
    opacity: root.enabled ? 1 : 0.45

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 8
        }
        spacing: 8

        ShellIcon {
            Layout.preferredWidth: 15
            Layout.preferredHeight: 15
            name: root.iconName
            source: root.iconSource
            tint: root.iconTint
            color: root.danger ? Theme.danger
                : (root.active ? Theme.accent : Theme.muted)
            size: 15
            fallback: root.glyph
        }

        Text {
            Layout.fillWidth: true
            text: root.label
            color: root.danger ? Theme.danger : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
        }

        ShortcutKey {
            Layout.preferredHeight: 16
            label: root.shortcut
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled
            ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
