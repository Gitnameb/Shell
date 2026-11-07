import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Campo de contraseña de una red Wi-Fi. Se usa tanto en la fila de una red
// normal como en el formulario de red oculta para que ambos se vean igual:
// campo redondeado, ojo para mostrar la clave, check para conectar y aspa
// para cancelar.
RowLayout {
    id: root

    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property bool passwordVisible: false
    property bool busy: false
    signal submitted()
    signal cancelled()

    spacing: 4

    function forcePasswordFocus(): void {
        field.forceActiveFocus();
    }

    function reset(): void {
        field.text = "";
        root.passwordVisible = false;
    }

    TextField {
        id: field

        Layout.fillWidth: true
        Layout.preferredHeight: 30
        placeholderText: "Contraseña"
        echoMode: root.passwordVisible
            ? TextInput.Normal : TextInput.Password
        color: Theme.text
        placeholderTextColor: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 10
        leftPadding: 8
        rightPadding: 8
        selectByMouse: true
        background: Rectangle {
            radius: 7
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
        }
        onAccepted: root.submitted()
        Keys.onEscapePressed: root.cancelled()
    }

    Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: 6
        color: eyeMouse.containsMouse ? Theme.hover : "transparent"

        ShellIcon {
            anchors.centerIn: parent
            source: ShellIcons.src(root.passwordVisible ? "eye-off" : "eye")
            color: root.passwordVisible ? Theme.accent : Theme.muted
            size: 14
            fallback: "◉"
        }

        MouseArea {
            id: eyeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.passwordVisible = !root.passwordVisible;
                field.forceActiveFocus();
            }
        }
    }

    Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: 6
        color: Theme.accent
        opacity: root.busy ? 0.5 : 1

        ShellIcon {
            anchors.centerIn: parent
            source: ShellIcons.src("check")
            color: Theme.accentInk
            size: 14
            fallback: "✓"
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: root.submitted()
        }
    }

    Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: 6
        color: Theme.hover

        Text {
            anchors.centerIn: parent
            text: "×"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.cancelled()
        }
    }
}
