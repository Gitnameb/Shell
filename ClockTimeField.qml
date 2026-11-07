import QtQuick

// Editor de hora HH:MM sin escribir los dos puntos.
//
// La hora y los minutos son dos campos de dos dígitos: al pulsar uno se
// selecciona entero y se puede reemplazar; al escribir el segundo dígito el
// foco salta al siguiente tramo. Los dos puntos son decorativos y nunca se
// editan. Al perder el foco o pulsar Intro se valida y se emite `edited`.
Item {
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
    readonly property int hourWidth: Math.ceil(root.pixelSize * 1.3)

    function pad(number): string {
        return number < 10 ? "0" + number : "" + number;
    }

    function sync(): void {
        if (!hourInput.activeFocus)
            hourInput.text = root.pad(root.hourValue);
        if (!minuteInput.activeFocus)
            minuteInput.text = root.pad(root.minuteValue);
    }

    function commit(): void {
        const hour = Math.max(0, Math.min(23,
            parseInt(hourInput.text, 10) || 0));
        const minute = Math.max(0, Math.min(59,
            parseInt(minuteInput.text, 10) || 0));
        hourInput.text = root.pad(hour);
        minuteInput.text = root.pad(minute);
        const next = root.pad(hour) + ":" + root.pad(minute);
        if (next !== root.value)
            root.edited(next);
    }

    Component.onCompleted: root.sync()
    onValueChanged: root.sync()

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 0

        TextInput {
            id: hourInput

            width: root.hourWidth
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
                top: 23
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    selectAll();
            }
            onTextEdited: {
                if (text.length >= 2)
                    minuteInput.forceActiveFocus();
            }
            onAccepted: minuteInput.forceActiveFocus()
            onEditingFinished: root.commit()
            Keys.onEscapePressed: (event) => {
                hourInput.text = root.pad(root.hourValue);
                hourInput.focus = false;
                event.accepted = true;
            }
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

            width: root.hourWidth
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
            onEditingFinished: root.commit()
            Keys.onEscapePressed: (event) => {
                minuteInput.text = root.pad(root.minuteValue);
                minuteInput.focus = false;
                event.accepted = true;
            }
        }
    }
}
