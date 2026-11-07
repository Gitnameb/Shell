import QtQuick

// Editor de hora HH:MM sin escribir los dos puntos.
//
// Al pulsar la hora se selecciona y se escribe de izquierda a derecha como
// texto normal: los dos primeros dígitos son la hora y el foco salta solo a
// los minutos. Si la hora escrita no es válida (por ejemplo 93), se interpreta
// como hora de un dígito y el dígito sobrante pasa a los minutos: 930 → 09:30.
// Los dos puntos son decorativos y nunca se editan. Intro o salir del campo
// confirman; Escape cancela.
FocusScope {
    id: root

    property string value: "00:00"
    property color textColor: Theme.text
    property color editColor: Theme.accent
    property int pixelSize: 11
    property bool bold: true

    signal edited(string value)

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(18, Math.ceil(root.pixelSize * 1.55))

    readonly property var parts: String(root.value).split(":")
    readonly property int hourValue: parts.length > 0
        ? Math.max(0, Math.min(23, parseInt(parts[0], 10) || 0)) : 0
    readonly property int minuteValue: parts.length > 1
        ? Math.max(0, Math.min(59, parseInt(parts[1], 10) || 0)) : 0
    readonly property int partWidth: Math.ceil(root.pixelSize * 1.3)

    function pad(number): string {
        return number < 10 ? "0" + number : "" + number;
    }

    function sync(): void {
        if (root.activeFocus)
            return;
        hourInput.text = root.pad(root.hourValue);
        minuteInput.text = root.pad(root.minuteValue);
    }

    function commit(): void {
        let hour = hourInput.text.length === 0
            ? root.hourValue : parseInt(hourInput.text, 10);
        let minute = minuteInput.text.length === 0
            ? root.minuteValue : parseInt(minuteInput.text, 10);
        if (isNaN(hour))
            hour = root.hourValue;
        if (isNaN(minute))
            minute = root.minuteValue;
        hour = Math.max(0, Math.min(23, hour));
        minute = Math.max(0, Math.min(59, minute));
        hourInput.text = root.pad(hour);
        minuteInput.text = root.pad(minute);
        const next = root.pad(hour) + ":" + root.pad(minute);
        if (next !== root.value)
            root.edited(next);
    }

    // La hora de dos dígitos no puede pasar de 23. Si pasa, el primer dígito
    // es la hora y el segundo empieza los minutos: 93 → 09:3_.
    function advanceHour(): void {
        const text = hourInput.text;
        if (text.length < 2)
            return;
        const value = parseInt(text, 10);
        if (isNaN(value)) {
            hourInput.text = root.pad(root.hourValue);
            minuteInput.forceActiveFocus();
            return;
        }
        if (value <= 23) {
            hourInput.text = root.pad(value);
            minuteInput.forceActiveFocus();
            return;
        }
        const first = parseInt(text.charAt(0), 10);
        const second = text.charAt(1);
        hourInput.text = root.pad(isNaN(first) ? 0 : first);
        minuteInput.text = second;
        minuteInput.forceActiveFocus();
        minuteInput.cursorPosition = minuteInput.text.length;
    }

    function cancel(): void {
        hourInput.text = root.pad(root.hourValue);
        minuteInput.text = root.pad(root.minuteValue);
        root.focus = false;
    }

    Component.onCompleted: root.sync()
    onValueChanged: root.sync()
    onActiveFocusChanged: {
        if (!activeFocus)
            root.commit();
    }
    Keys.onEscapePressed: (event) => {
        root.cancel();
        event.accepted = true;
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: hourInput.forceActiveFocus()
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 0

        TextInput {
            id: hourInput

            width: root.partWidth
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            color: hourInput.activeFocus ? root.editColor : root.textColor
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentInk
            font.family: Theme.fontFamily
            font.pixelSize: root.pixelSize
            font.weight: root.bold ? Font.DemiBold : Font.Normal
            inputMethodHints: Qt.ImhDigitsOnly
            maximumLength: 2
            selectByMouse: true
            validator: IntValidator {
                bottom: 0
                top: 99
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    selectAll();
            }
            onTextEdited: root.advanceHour()
            onAccepted: minuteInput.forceActiveFocus()
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ":"
            color: hourInput.activeFocus || minuteInput.activeFocus
                ? root.editColor : root.textColor
            font.family: Theme.fontFamily
            font.pixelSize: root.pixelSize
            font.weight: root.bold ? Font.DemiBold : Font.Normal
        }

        TextInput {
            id: minuteInput

            width: root.partWidth
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            color: minuteInput.activeFocus ? root.editColor : root.textColor
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentInk
            font.family: Theme.fontFamily
            font.pixelSize: root.pixelSize
            font.weight: root.bold ? Font.DemiBold : Font.Normal
            inputMethodHints: Qt.ImhDigitsOnly
            maximumLength: 2
            selectByMouse: true
            validator: IntValidator {
                bottom: 0
                top: 59
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    selectAll();
            }
            onAccepted: root.commit()
        }
    }
}
