import QtQuick

// Editor de tiempo con dígitos agrupados desde la derecha.
//
// Al pulsar los números se entra en edición. Mientras escribes se ven los
// dígitos tal cual, con los dos puntos puestos automáticamente. No se
// convierte a tiempo hasta que pulsas Intro o sales del campo. Retroceso
// borra el último dígito; Escape cancela.
//
// Con showSeconds (temporizador): 123 → 1:23 y 12345 → 1:23:45.
// Sin showSeconds (alarma): 930 → 9:30 y 1230 → 12:30.
Item {
    id: root

    property int seconds: 0
    property bool showSeconds: true
    property color textColor: Theme.text
    property color editColor: Theme.accent
    property int pixelSize: 44
    property bool bold: true
    property bool editing: false
    property bool fresh: false
    property string digits: ""

    signal changed(int seconds)
    signal editingStarted()

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight + 2

    function pad(number): string {
        return number < 10 ? "0" + number : "" + number;
    }

    // Formato en reposo. Temporizador: «25:00» o «1:05:09». Alarma: «09:30».
    function compact(total): string {
        const value = Math.max(0, Math.floor(total));
        const hours = Math.floor(value / 3600);
        const minutes = Math.floor((value % 3600) / 60);
        const secs = value % 60;
        if (!root.showSeconds)
            return root.pad(hours) + ":" + root.pad(minutes);
        if (hours > 0)
            return hours + ":" + root.pad(minutes) + ":" + root.pad(secs);
        return minutes + ":" + root.pad(secs);
    }

    // Los dígitos escritos, agrupados de derecha a izquierda.
    function digitsText(): string {
        let value = root.digits;
        if (!root.showSeconds) {
            if (value.length === 0)
                value = "0";
            if (value.length <= 2)
                return value;
            if (value.length === 3)
                return value.charAt(0) + ":" + value.slice(1);
            return value.slice(0, 2) + ":" + value.slice(2, 4);
        }
        value = value.replace(/^0+/, "");
        if (value.length === 0)
            value = "0";
        if (value.length <= 2)
            return value;
        const secs = value.slice(-2);
        const rest = value.slice(0, -2);
        if (rest.length <= 2)
            return rest + ":" + secs;
        const minutes = rest.slice(-2);
        const hours = rest.slice(0, -2);
        return hours + ":" + minutes + ":" + secs;
    }

    function maxDigits(): int {
        return root.showSeconds ? 6 : 4;
    }

    function valueFromDigits(): int {
        const raw = root.digits.length === 0 ? 0 : parseInt(root.digits, 10);
        if (root.showSeconds)
            return Math.min(359999, raw);
        const hours = Math.max(0, Math.min(23, Math.floor(raw / 100)));
        const minutes = Math.max(0, Math.min(59, raw % 100));
        return hours * 3600 + minutes * 60;
    }

    readonly property string previewText: root.digits.length === 0
        ? root.compact(root.seconds) : root.digitsText()

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
        if (save && !root.fresh && root.digits.length > 0) {
            const value = root.valueFromDigits();
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
            } else if (root.digits.length < root.maxDigits()) {
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
        text: root.editing ? root.previewText : root.compact(root.seconds)
        color: root.editing ? root.editColor : root.textColor
        font.family: Theme.fontFamily
        font.pixelSize: root.pixelSize
        font.weight: root.bold ? Font.DemiBold : Font.Normal
    }

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
