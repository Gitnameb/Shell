import QtQuick

// Editor de duración HH:MM:SS.
//
// Al pulsar los números grandes se entra en edición. Los dos puntos están
// siempre visibles y los dígitos se agrupan solos desde la derecha: escribir
// 130 deja 00:01:30 y escribir 3000 deja 00:30:00. Retroceso borra el último
// dígito; Intro o perder el foco confirman; Escape cancela.
Item {
    id: root

    property int seconds: 0
    property color textColor: Theme.text
    property color editColor: Theme.accent
    property int pixelSize: 44
    property bool bold: true
    // Edición en curso. La expone el panel para pausar la cuenta atrás.
    property bool editing: false
    property bool fresh: false
    property string digits: ""

    signal changed(int seconds)
    signal editingStarted()

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    readonly property int previewSeconds: root.fresh
        ? Math.max(0, root.seconds) : root.digitSeconds()

    function pad(number): string {
        return number < 10 ? "0" + number : "" + number;
    }

    function textFor(total): string {
        const value = Math.max(0, Math.min(359999, Math.floor(total)));
        return root.pad(Math.floor(value / 3600)) + ":"
            + root.pad(Math.floor((value % 3600) / 60)) + ":"
            + root.pad(value % 60);
    }

    function digitSeconds(): int {
        return root.digits.length === 0 ? 0 : parseInt(root.digits, 10);
    }

    function begin(): void {
        if (root.editing)
            return;
        root.digits = "";
        root.fresh = true;
        root.editing = true;
        root.editingStarted();
        keyCatcher.forceActiveFocus();
    }

    function finish(save): void {
        if (!root.editing)
            return;
        root.editing = false;
        if (save) {
            const value = root.fresh ? Math.max(0, root.seconds)
                : root.digitSeconds();
            if (value !== root.seconds)
                root.changed(value);
        }
        root.digits = "";
    }

    function handleKey(event): void {
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            const digit = event.key - Qt.Key_0;
            if (root.fresh) {
                root.digits = "" + digit;
                root.fresh = false;
            } else if (root.digits.length < 6) {
                root.digits = root.digits + digit;
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Backspace) {
            if (root.fresh) {
                root.fresh = false;
                root.digits = "";
            } else {
                root.digits = root.digits.slice(0, -1);
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.finish(true);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape) {
            root.finish(false);
            event.accepted = true;
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.textFor(root.editing ? root.previewSeconds : root.seconds)
        color: root.editing ? root.editColor : root.textColor
        font.family: Theme.fontFamily
        font.pixelSize: root.pixelSize
        font.weight: root.bold ? Font.DemiBold : Font.Normal
    }

    // Un subrayado tenue avisa de que los números se pueden editar.
    Rectangle {
        anchors {
            left: label.left
            right: label.right
            top: label.bottom
            topMargin: 1
        }
        height: 1
        color: root.editing ? Theme.accent : Theme.border
        opacity: root.editing ? 0.9 : 0.5
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: root.begin()
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: root.editing
        Keys.onPressed: (event) => root.handleKey(event)
        onActiveFocusChanged: {
            if (!activeFocus && root.editing)
                root.finish(true);
        }
    }
}
