import QtQuick
import QtQuick.Controls
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

    // El atajo se muestra al pasar el ratón por el icono de teclado, no en
    // toda la fila.
    readonly property bool shortcutHover: {
        if (root.shortcut.length === 0 || !mouse.containsMouse)
            return false;
        const p = shortcutKey.mapToItem(root, 0, 0);
        return mouse.mouseX >= p.x - 2
            && mouse.mouseX <= p.x + shortcutKey.width + 2;
    }

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
            id: shortcutKey

            Layout.preferredHeight: 18
            label: root.shortcut
            hovered: root.shortcutHover
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

    ToolTip.visible: root.shortcutHover
    ToolTip.text: root.shortcut
    ToolTip.delay: 250
}
