import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Panel del reloj: calendario, clima, alarmas y temporizador. Se abre desde el
// reloj de la barra y queda pegado a ella, no en la parte alta de la pantalla.
PanelWindow {
    id: root

    visible: CalendarState.open
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    readonly property real verticalTop: Math.max(Theme.edge + 10,
        ((screen ? screen.height : 900) - root.implicitHeight) / 2)

    anchors {
        top: SettingsState.barVertical || SettingsState.barAtTop
        bottom: !SettingsState.barVertical && !SettingsState.barAtTop
        left: !SettingsState.barVertical || SettingsState.barAtLeft
        right: SettingsState.barVertical && SettingsState.barAtRight
    }
    margins {
        top: SettingsState.barVertical ? root.verticalTop
            : (SettingsState.barAtTop ? Theme.edge + Theme.barHeight + 10 : 0)
        bottom: !SettingsState.barVertical && !SettingsState.barAtTop
            ? Theme.edge + Theme.barHeight + 10 : 0
        left: SettingsState.barVertical
            ? (SettingsState.barAtLeft
                ? Theme.edge + Theme.barHeight + 10 : 0)
            : Math.round(((screen ? screen.width : 1280)
                - implicitWidth) / 2)
        right: SettingsState.barVertical && SettingsState.barAtRight
            ? Theme.edge + Theme.barHeight + 10 : 0
    }
    implicitWidth: 344
    implicitHeight: root.tab === "calendar" ? 492
        : (root.tab === "weather" ? (root.editingPlace ? 384 : 350)
            : 330)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-calendar"
    WlrLayershell.keyboardFocus: CalendarState.open && focusGate.ready
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    PanelFocusGate {
        id: focusGate
        active: CalendarState.open
    }

    property string tab: "calendar"
    property date shownMonth: new Date(now.date.getFullYear(), now.date.getMonth(), 1)

    // Ubicación manual del clima. Mientras se edita, el borrador no se aplica
    // hasta pulsar Aplicar o Intro; vacío vuelve a la detección por IP.
    property bool editingPlace: false
    property string placeDraft: ""

    // Borrador del campo de notas del día.
    property string noteDraft: ""
    // El campo de notas ya no está siempre visible: se abre al pulsar por
    // segunda vez el día ya seleccionado.
    property bool noteEditorOpen: false
    property var lastClickedDate: null

    function applyWeatherPlace(): void {
        SettingsState.setWeatherPlace(root.placeDraft);
        root.editingPlace = false;
    }

    // ------------------------------------------------------------- alarmas
    property var alarms: [
        { time: "07:00", label: "Despertar", enabled: false },
        { time: "13:00", label: "Almuerzo", enabled: false }
    ]
    property string alarmMinute: ""
    property var firedAlarms: ({})
    // Día elegido en el calendario. Se puede pulsar cualquier celda, también
    // las de los meses vecinos, y el panel salta a ese mes.
    property date selectedDate: new Date()
    property bool alarmsReady: false

    readonly property string alarmsPath: Quickshell.env("HOME")
        + "/.config/shell/alarms.conf"

    // --------------------------------------------------------- temporizador
    property int timerTotal: 25 * 60
    property int timerLeft: 25 * 60
    property bool timerRunning: false
    // Al editar los números grandes el tiempo pasa a ser manual y ningún
    // preset debe quedar seleccionado aunque coincida con la duración.
    property bool customTimer: false
    // Algún editor de hora de alarma tiene el foco: Escape cancela la edición
    // en vez de cerrar el panel.
    property bool alarmEditing: false
    // Editor de tiempo activo (temporizador o una alarma). Cualquier clic
    // fuera, cambio de pestaña o cierre del panel lo confirma.
    property var activeEditor: null
    property string timerState: "Listo"
    property string timerInput: ""
    // Vencimiento en segundos desde la época. Se guarda en timer.conf para
    // que el demonio de alarmas pueda terminarlo con el shell cerrado.
    property int timerDeadline: 0
    readonly property string timerPath: Quickshell.env("HOME")
        + "/.config/shell/timer.conf"

    function shiftMonth(delta): void {
        root.commitEditors();
        shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + delta, 1);
    }

    function sameDay(a, b): bool {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    function selectDay(cell): void {
        const again = root.lastClickedDate !== null
            && root.sameDay(cell.date, root.lastClickedDate)
            && root.sameDay(cell.date, root.selectedDate);
        if (again) {
            // Segundo clic sobre el día ya elegido: se abre la nota de ese
            // día sin dejar un campo permanente en el calendario.
            root.noteEditorOpen = true;
            Qt.callLater(() => noteField.forceActiveFocus());
            return;
        }
        root.commitEditors();
        root.noteEditorOpen = false;
        root.noteDraft = "";
        root.selectedDate = cell.date;
        root.lastClickedDate = cell.date;
        if (!cell.inMonth) {
            root.shownMonth = new Date(cell.date.getFullYear(),
                cell.date.getMonth(), 1);
        }
    }

    function closeNoteEditor(): void {
        root.noteEditorOpen = false;
        root.noteDraft = "";
    }

    function goToday(): void {
        root.commitEditors();
        root.noteEditorOpen = false;
        root.noteDraft = "";
        root.lastClickedDate = null;
        root.selectedDate = new Date();
        root.shownMonth = new Date(root.selectedDate.getFullYear(),
            root.selectedDate.getMonth(), 1);
    }

    function buildDays(): var {
        const year = shownMonth.getFullYear();
        const month = shownMonth.getMonth();
        const first = new Date(year, month, 1);
        // Lunes = 0
        const offset = (first.getDay() + 6) % 7;
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const today = now.date;
        const chosen = root.selectedDate;
        const cells = [];

        for (let i = 0; i < 42; i++) {
            const number = i - offset + 1;
            const inMonth = number >= 1 && number <= daysInMonth;
            const cellDate = new Date(year, month, number);
            cells.push({
                day: cellDate.getDate(),
                date: cellDate,
                inMonth: inMonth,
                isToday: root.sameDay(cellDate, today),
                isSelected: root.sameDay(cellDate, chosen)
            });
        }
        return cells;
    }

    function dayEvents(): var {
        return CalendarEvents.eventsFor(root.selectedDate);
    }

    function dayDots(date): var {
        const list = CalendarEvents.eventsFor(date);
        const dots = [];
        for (let i = 0; i < list.length && i < 3; i++) {
            const entry = list[i];
            dots.push(entry.note ? Theme.accent : (entry.color || Theme.accent));
        }
        return dots;
    }

    function addNoteFromDraft(): void {
        root.commitEditors();
        const text = root.noteDraft.trim();
        if (text.length === 0)
            return;
        CalendarEvents.addNote(root.selectedDate, text);
        root.noteDraft = "";
        root.noteEditorOpen = false;
    }

    function validTime(value): bool {
        return /^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(value);
    }

    function commitEditors(): void {
        const editor = root.activeEditor;
        root.activeEditor = null;
        if (editor && editor.editing)
            editor.finish(true);
    }

    function alarmSeconds(value): int {
        const parts = String(value || "00:00").split(":");
        const hour = Math.max(0, Math.min(23, parseInt(parts[0], 10) || 0));
        const minute = Math.max(0, Math.min(59, parseInt(parts[1], 10) || 0));
        return hour * 3600 + minute * 60;
    }

    function formatAlarm(value): string {
        const total = Math.max(0, Math.min(23 * 3600 + 59 * 60,
            Math.round(value)));
        return Format.pad(Math.floor(total / 3600)) + ":"
            + Format.pad(Math.floor((total % 3600) / 60));
    }

    function updateAlarm(index, field, value): void {
        if (index < 0 || index >= root.alarms.length)
            return;
        if (field === "time" && !root.validTime(value))
            return;
        if (field === "label" && String(value).length === 0)
            return;
        const list = root.alarms.slice();
        const copy = Object.assign({}, list[index]);
        copy[field] = value;
        list[index] = copy;
        root.alarms = list;
    }

    function addAlarm(): void {
        root.commitEditors();
        const next = new Date();
        next.setHours(next.getHours() + 1, 0, 0, 0);
        const time = Format.pad(next.getHours()) + ":" + Format.pad(next.getMinutes());
        root.alarms = root.alarms.concat([{ time: time, label: "Alarma", enabled: true }]);
    }

    function removeAlarm(index): void {
        root.commitEditors();
        root.alarms = root.alarms.filter((alarm, position) => position !== index);
    }

    function saveAlarms(): void {
        if (!root.alarmsReady)
            return;
        let text = "";
        for (let i = 0; i < root.alarms.length; i++) {
            const alarm = root.alarms[i];
            const label = String(alarm.label || "Alarma")
                .replace(/\|/g, "/").replace(/\n/g, " ");
            text += (alarm.enabled ? "1" : "0") + "|" + alarm.time + "|"
                + label + "\n";
        }
        alarmSave.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
            "shell", root.alarmsPath, text];
        alarmSave.running = true;
    }

    function checkAlarms(): void {
        const stamp = Format.pad(now.date.getHours()) + ":"
            + Format.pad(now.date.getMinutes());
        if (root.alarmMinute !== stamp) {
            root.alarmMinute = stamp;
            root.firedAlarms = ({});
        }
        const due = [];
        for (let i = 0; i < root.alarms.length; i++) {
            const alarm = root.alarms[i];
            if (!alarm.enabled || alarm.time !== stamp)
                continue;
            const key = stamp + "|" + i;
            if (root.firedAlarms[key])
                continue;
            let fired = Object.assign({}, root.firedAlarms);
            fired[key] = true;
            root.firedAlarms = fired;
            due.push(alarm);
        }
        if (due.length > 0)
            AlarmState.fire(due);
    }

    // Aplica una duración exacta (en segundos) editada en los números grandes.
    function setTimerFromSeconds(value): void {
        const total = Math.max(1, Math.min(359999, Math.round(value)));
        root.timerRunning = false;
        root.customTimer = true;
        root.timerTotal = total;
        root.timerLeft = total;
        root.timerState = "Listo";
        root.writeTimer(0);
    }

    // Escribe (o borra) el vencimiento del temporizador. Con 0 se elimina el
    // archivo; así el demonio solo actúa cuando hay una cuenta atrás viva.
    function writeTimer(deadline): void {
        root.timerDeadline = deadline;
        timerSave.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && if [ \"$2\" -gt 0 ]; then "
                + "printf 'deadline=%s\\n' \"$2\" > \"$1\"; else rm -f \"$1\"; fi",
            "shell", root.timerPath, deadline];
        timerSave.running = true;
    }

    function scheduleTimer(): void {
        if (!root.timerRunning || root.timerLeft <= 0) {
            root.writeTimer(0);
            return;
        }
        root.writeTimer(Math.floor(Date.now() / 1000) + root.timerLeft);
    }

    function setTimerPreset(minutes): void {
        root.commitEditors();
        root.timerRunning = false;
        root.customTimer = false;
        root.timerTotal = minutes * 60;
        root.timerLeft = minutes * 60;
        root.timerState = "Listo";
    }

    function toggleTimer(): void {
        root.commitEditors();
        if (root.timerLeft <= 0) {
            root.timerLeft = root.timerTotal;
        }
        root.timerRunning = !root.timerRunning;
        root.timerState = root.timerRunning ? "En marcha" : "Pausado";
    }

    function resetTimer(): void {
        root.commitEditors();
        root.timerRunning = false;
        root.timerLeft = root.timerTotal;
        root.timerState = "Listo";
    }

    SystemClock {
        id: now
        precision: SystemClock.Minutes
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.checkAlarms()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.timerRunning && root.timerLeft > 0
        onTriggered: {
            root.timerLeft -= 1;
            if (root.timerLeft <= 0) {
                root.timerLeft = 0;
                root.timerRunning = false;
                root.timerState = "Terminado";
                AlarmState.fireTimer();
            }
        }
    }

    // Las alarmas se guardan en un archivo propio para que sobrevivan a un
    // reinicio del shell. El temporizador vive en timer.conf mientras haya
    // una cuenta atrás, también si el panel está cerrado.
    Component.onCompleted: {
        alarmLoad.running = true;
        timerLoad.running = true;
    }

    onAlarmsChanged: alarmSaveTimer.restart()

    // Al abrir el panel o cambiar de mes se recargan las notas. Con el panel
    // cerrado no se consulta nada; los calendarios remotos viven en caché.
    onVisibleChanged: {
        if (visible) {
            CalendarEvents.refresh(root.shownMonth);
        } else {
            root.commitEditors();
            root.closeNoteEditor();
            // La próxima apertura vuelve a pedir dos clics para editar.
            root.lastClickedDate = null;
        }
    }

    onShownMonthChanged: {
        if (visible)
            CalendarEvents.refresh(root.shownMonth);
    }

    onTabChanged: root.commitEditors()

    // Pulsar el reloj de la barra abre el calendario: eso da por atendida la
    // alarma y detiene el sonido y el aviso.
    Connections {
        target: CalendarState

        function onOpenChanged(): void {
            if (CalendarState.open) {
                AlarmState.stop();
            } else {
                root.commitEditors();
            }
        }
    }

    // Al empezar, pausar o terminar se reescribe el vencimiento; el aviso de
    // cada segundo no toca el archivo.
    onTimerRunningChanged: root.scheduleTimer()

    Timer {
        id: alarmSaveTimer

        interval: 160
        repeat: false
        onTriggered: root.saveAlarms()
    }

    Process {
        id: alarmLoad

        command: ["sh", "-c",
            "if [ -f \"$1\" ]; then cat \"$1\"; else echo __missing__; fi",
            "shell", root.alarmsPath]

        stdout: StdioCollector {
            id: alarmOut
        }

        onExited: {
            const raw = alarmOut.text;
            if (raw.indexOf("__missing__") === 0) {
                root.alarmsReady = true;
                root.saveAlarms();
                return;
            }
            const list = [];
            const lines = raw.split("\n");
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                if (line.length === 0)
                    continue;
                const parts = line.split("|");
                if (parts.length < 3 || !root.validTime(parts[1]))
                    continue;
                list.push({
                    enabled: parts[0] === "1",
                    time: parts[1],
                    label: parts.slice(2).join("|")
                });
            }
            root.alarms = list;
            root.alarmsReady = true;
        }
    }

    Process {
        id: alarmSave
    }

    Process {
        id: timerSave
    }

    // Restaura la cuenta atrás si el shell se cerró con el temporizador en
    // marcha. Si venció mientras estaba cerrado, avisa una sola vez.
    Process {
        id: timerLoad

        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true",
            "shell", root.timerPath]

        stdout: StdioCollector {
            id: timerOut
        }

        onExited: {
            const match = timerOut.text.match(/^deadline=(\d+)\s*$/m);
            const deadline = match ? parseInt(match[1], 10) : 0;
            if (deadline <= 0) {
                root.timerDeadline = 0;
                return;
            }
            const nowSeconds = Math.floor(Date.now() / 1000);
            root.timerDeadline = deadline;
            if (deadline <= nowSeconds) {
                root.timerLeft = 0;
                root.timerState = "Terminado";
                AlarmState.fireTimer();
                root.writeTimer(0);
                return;
            }
            const left = deadline - nowSeconds;
            root.customTimer = true;
            root.timerTotal = Math.max(root.timerTotal, left);
            root.timerLeft = left;
            root.timerState = "En marcha";
            root.timerRunning = true;
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            CalendarState.toggle();
        }

        function showTab(name: string): void {
            CalendarState.show();
            root.tab = name;
        }

        function calendar(): void {
            showTab("calendar");
        }


        function weather(): void {
            showTab("weather");
        }

        function alarms(): void {
            showTab("alarms");
        }

        function timer(): void {
            showTab("timer");
        }
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: 16
        color: Theme.glassCard
        border.width: 1
        border.color: Theme.borderStrong
        clip: true

        // Los clics en zonas vacías del panel cierran cualquier edición de
        // hora; los controles con su propio MouseArea quedan por encima.
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root.commitEditors()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ---------------------------------------------------------- pestañas
            RowLayout {
                Layout.fillWidth: true
                spacing: 2

                ClockTab {
                    Layout.fillWidth: true
                    tabKey: "calendar"
                    label: "Calendario"
                    iconName: "x-office-calendar"
                    iconSource: ShellIcons.src("calendar")
                    fallback: "▦"
                    selected: root.tab === "calendar"
                    onActivated: root.tab = "calendar"
                }

                ClockTab {
                    Layout.fillWidth: true
                    tabKey: "weather"
                    label: "Clima"
                    iconName: "weather-few-clouds"
                    iconSource: ShellIcons.src("cloud")
                    fallback: "☁"
                    selected: root.tab === "weather"
                    onActivated: root.tab = "weather"
                }

                ClockTab {
                    Layout.fillWidth: true
                    tabKey: "alarms"
                    label: "Alarmas"
                    iconName: "kalarm"
                    iconSource: ShellIcons.src("alarm")
                    fallback: "◷"
                    selected: root.tab === "alarms"
                    onActivated: root.tab = "alarms"
                }

                ClockTab {
                    Layout.fillWidth: true
                    tabKey: "timer"
                    label: "Temporizador"
                    iconName: "chronometer"
                    iconSource: ShellIcons.src("timer")
                    fallback: "⏱"
                    selected: root.tab === "timer"
                    onActivated: root.tab = "timer"
                }
            }

            // -------------------------------------------------------- calendario
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === "calendar"
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: Fechas.monthName(root.shownMonth) + " "
                                + root.shownMonth.getFullYear()
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            font.capitalization: Font.Capitalize
                        }
                    }

                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 24
                        radius: 6
                        color: todayMouse.containsMouse ? Theme.hover : "transparent"
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "Hoy"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: todayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.goToday()
                        }
                    }

                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 7
                        color: prevMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(-1)
                        }
                    }

                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 7
                        color: nextMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "›"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(1)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: ["L", "M", "X", "J", "V", "S", "D"]

                        Text {
                            required property string modelData

                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 2
                    columnSpacing: 0

                    Repeater {
                        model: root.buildDays()

                        Rectangle {
                            id: dayCell

                            required property var modelData

                            readonly property bool chosen: dayCell.modelData.isSelected
                                && !dayCell.modelData.isToday

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 7
                            color: dayCell.modelData.isToday
                                ? Theme.accent
                                : (dayCell.chosen
                                    ? Theme.accentSoft
                                    : (dayMouse.containsMouse
                                        && dayCell.modelData.inMonth
                                        ? Theme.hover : "transparent"))
                            border.width: dayCell.chosen ? 1 : 0
                            border.color: Theme.accentLine

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dayCell.modelData.day
                                    color: dayCell.modelData.isToday
                                        ? Theme.accentInk
                                        : (dayCell.chosen
                                            ? Theme.accent
                                            : (dayCell.modelData.inMonth
                                                ? Theme.text : Theme.faint))
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: dayCell.modelData.isToday
                                        || dayCell.chosen ? Font.Bold : Font.Normal
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 2

                                    Repeater {
                                        model: root.dayDots(dayCell.modelData.date)

                                        Rectangle {
                                            required property color modelData

                                            width: 3
                                            height: 3
                                            radius: 1.5
                                            color: modelData
                                            opacity: dayCell.modelData.inMonth ? 1 : 0.4
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectDay(dayCell.modelData)
                            }
                        }
                    }
                }

                // Eventos y notas del día elegido. La fecha larga que había
                // aquí se sustituyó por las notas reales del día.
                ListView {
                    id: dayList

                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    visible: root.dayEvents().length > 0
                    clip: true
                    spacing: 1
                    model: root.dayEvents()
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: dayRow

                        required property var modelData

                        width: dayList.width
                        height: 26
                        radius: 6
                        color: dayRow.modelData.note
                            ? Theme.accentSoft
                            : (dayHover.hovered ? Theme.hover : "transparent")

                        HoverHandler {
                            id: dayHover
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 6
                                rightMargin: 5
                            }
                            spacing: 5

                            Text {
                                Layout.preferredWidth: 38
                                text: dayRow.modelData.all_day
                                    ? "Día" : dayRow.modelData.time
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: dayRow.modelData.note
                                    ? Theme.accent
                                    : (dayRow.modelData.color || Theme.accent)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: dayRow.modelData.title
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: dayRow.modelData.note
                                text: "×"
                                color: removeNoteMouse.containsMouse
                                    ? Theme.danger : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 12

                                MouseArea {
                                    id: removeNoteMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.commitEditors();
                                        CalendarEvents.removeNote(
                                            dayRow.modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }

            }

            // ------------------------------------------------------------ clima
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === "weather"
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: WeatherState.place.length > 0
                            ? WeatherState.place : "Ubicación desconocida"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.6
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.editingPlace ? "Cancelar" : "Cambiar"
                        color: changePlaceMouse.containsMouse
                            ? Theme.accent : Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.DemiBold

                        MouseArea {
                            id: changePlaceMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.editingPlace) {
                                    root.editingPlace = false;
                                    return;
                                }
                                root.placeDraft = SettingsState.weatherPlace;
                                root.editingPlace = true;
                            }
                        }
                    }

                    Text {
                        text: WeatherState.loading ? "…" : "Actualizar"
                        color: refreshMouse.containsMouse ? Theme.accent : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.DemiBold

                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: WeatherState.refresh()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.editingPlace

                    TextField {
                        id: placeField

                        Layout.fillWidth: true
                        text: root.placeDraft
                        placeholderText: "Automática (por IP)"
                        color: Theme.text
                        placeholderTextColor: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        selectByMouse: true
                        onTextEdited: root.placeDraft = text
                        onAccepted: root.applyWeatherPlace()
                        background: Rectangle {
                            radius: 7
                            color: Theme.surfaceAlt
                            border.width: 1
                            border.color: placeField.activeFocus
                                ? Theme.accent : Theme.border
                        }
                    }

                    Rectangle {
                        implicitWidth: applyLabel.implicitWidth + 16
                        implicitHeight: 26
                        radius: 7
                        color: applyMouse.containsMouse
                            ? Theme.accent : Theme.accentSoft

                        Text {
                            id: applyLabel
                            anchors.centerIn: parent
                            text: "Aplicar"
                            color: applyMouse.containsMouse
                                ? Theme.accentInk : Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: applyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applyWeatherPlace()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ShellIcon {
                        Layout.alignment: Qt.AlignVCenter
                        source: ShellIcons.src(WeatherState.currentIcon)
                        tint: false
                        color: Theme.accent
                        size: 40
                        fallback: "◌"
                    }

                    ColumnLayout {
                        spacing: 0

                        Text {
                            text: WeatherState.temp + "°"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 34
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: WeatherState.description
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        spacing: 2

                        Text {
                            text: "Sensación " + WeatherState.feels + "°"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                        }

                        Text {
                            text: "Humedad " + WeatherState.humidity + "%"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                        }

                        Text {
                            text: "Viento " + WeatherState.wind + " km/h"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: WeatherState.hours

                        Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 52
                            radius: 8
                            color: Theme.surfaceAlt
                            border.width: 1
                            border.color: Theme.border

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                }

                                ShellIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    source: ShellIcons.src(modelData.icon)
                                    tint: false
                                    color: Theme.muted
                                    size: 17
                                    fallback: "◌"
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.temp + "°"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    text: "PRÓXIMOS DÍAS"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                Repeater {
                    model: WeatherState.days

                    RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: modelData.label
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            width: 35
                        }

                        ShellIcon {
                            source: ShellIcons.src(modelData.icon)
                            tint: false
                            color: Theme.faint
                            size: 17
                            fallback: "◌"
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData.max + "° / " + modelData.min + "°"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                Text {
                    Layout.fillWidth: true
                    visible: WeatherState.error.length > 0
                    text: WeatherState.error
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: WeatherState.loading
                    text: "Consultando el clima…"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }
            }

            // ----------------------------------------------------------- alarmas
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === "alarms"
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: "ALARMAS"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.9
                    }

                    Rectangle {
                        implicitWidth: addAlarmLabel.implicitWidth + 16
                        implicitHeight: 24
                        radius: 6
                        color: addAlarmMouse.containsMouse ? Theme.hover : "transparent"
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            id: addAlarmLabel
                            anchors.centerIn: parent
                            text: "+ Añadir"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                        }

                        MouseArea {
                            id: addAlarmMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addAlarm()
                        }
                    }
                }

                ListView {
                    id: alarmList

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: root.alarms
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: alarmRow

                        required property int index
                        required property var modelData

                        width: alarmList.width
                        height: 38
                        radius: 8
                        color: alarmHover.hovered ? Theme.hover : "transparent"

                        HoverHandler {
                            id: alarmHover
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 5
                                rightMargin: 5
                            }
                            spacing: 5

                            DurationField {
                                id: alarmTimeEditor
                                Layout.preferredWidth: 52
                                seconds: root.alarmSeconds(
                                    alarmRow.modelData.time)
                                showSeconds: false
                                textColor: alarmRow.modelData.enabled
                                    ? Theme.text : Theme.faint
                                editColor: Theme.accent
                                pixelSize: 11
                                onEditingStarted:
                                    root.activeEditor = alarmTimeEditor
                                onEditingChanged: {
                                    root.alarmEditing = editing;
                                    if (!editing
                                            && root.activeEditor === alarmTimeEditor)
                                        root.activeEditor = null;
                                }
                                onChanged: (value) => root.updateAlarm(
                                    alarmRow.index, "time",
                                    root.formatAlarm(value))
                                Component.onDestruction: {
                                    if (root.activeEditor === alarmTimeEditor)
                                        root.activeEditor = null;
                                }
                            }

                            TextField {
                                Layout.fillWidth: true
                                text: alarmRow.modelData.label
                                color: alarmRow.modelData.enabled
                                    ? Theme.text
                                    : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                selectByMouse: true
                                onEditingFinished: root.updateAlarm(
                                    alarmRow.index, "label", text)
                                background: Rectangle {
                                    radius: 6
                                    color: "transparent"
                                    border.width: 0
                                }
                            }

                            ShellSwitch {
                                checked: alarmRow.modelData.enabled
                                onToggled: {
                                    root.commitEditors();
                                    root.updateAlarm(alarmRow.index, "enabled",
                                        !alarmRow.modelData.enabled);
                                }
                            }

                            Text {
                                text: "×"
                                color: removeAlarmMouse.containsMouse
                                    ? Theme.danger : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 14

                                MouseArea {
                                    id: removeAlarmMouse
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.removeAlarm(alarmRow.index)
                                }
                            }
                        }
                    }
                }

            }

            // ------------------------------------------------------ temporizador
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === "timer"
                spacing: 8

                Item {
                    Layout.fillHeight: true
                }

                DurationField {
                    id: timerField

                    Layout.alignment: Qt.AlignHCenter
                    seconds: root.timerLeft
                    textColor: root.timerState === "Terminado"
                        ? Theme.danger : Theme.text
                    editColor: Theme.accent
                    pixelSize: 44
                    onEditingStarted: {
                        root.activeEditor = timerField;
                        root.timerRunning = false;
                        root.timerState = "Listo";
                        root.writeTimer(0);
                    }
                    onEditingChanged: {
                        if (!editing && root.activeEditor === timerField)
                            root.activeEditor = null;
                    }
                    onChanged: (value) => root.setTimerFromSeconds(value)
                }

                Text {
                    Layout.fillWidth: true
                    text: root.timerState.toUpperCase()
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    Repeater {
                        model: [5, 10, 25, 45]

                        Rectangle {
                            required property int modelData

                            implicitWidth: 46
                            implicitHeight: 26
                            radius: 7
                            readonly property bool chosen:
                                !root.customTimer
                                && root.timerTotal === modelData * 60
                            color: chosen
                                ? Theme.accentSoft : Theme.surfaceAlt
                            border.width: 1
                            border.color: chosen
                                ? Theme.accentLine
                                : Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: modelData + " min"
                                color: parent.chosen ? Theme.accent : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setTimerPreset(modelData)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    Rectangle {
                        implicitWidth: 86
                        implicitHeight: 30
                        radius: 8
                        color: Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: root.timerRunning ? "Pausar" : "Iniciar"
                            color: Theme.accentInk
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleTimer()
                        }
                    }

                    Rectangle {
                        implicitWidth: 86
                        implicitHeight: 30
                        radius: 8
                        color: resetMouse.containsMouse ? Theme.hover : Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "Reiniciar"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                        }

                        MouseArea {
                            id: resetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetTimer()
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }

        // Opciones avanzadas del día. El calendario solo selecciona días; el
        // editor de notas vive en este apartado aparte, como las opciones
        // avanzadas de los demás controles, y se abre con el segundo clic.
        Item {
            id: noteOverlay

            anchors.fill: parent
            visible: root.noteEditorOpen
            z: 50

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.42)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeNoteEditor()
                }
            }

            Rectangle {
                id: noteCard

                width: Math.min(300, parent.width - 36)
                height: noteCardColumn.implicitHeight + 24
                anchors.centerIn: parent
                radius: 14
                color: Theme.glassCard
                border.width: 1
                border.color: Theme.borderStrong

                // Absorbe los clics del interior para que no cierren el panel.
                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: noteCardColumn

                    anchors {
                        fill: parent
                        margins: 12
                    }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: Fechas.longDate(root.selectedDate)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 6
                            color: noteCloseMouse.containsMouse
                                ? Theme.hover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: noteCloseMouse.containsMouse
                                    ? Theme.danger : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                            }

                            MouseArea {
                                id: noteCloseMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeNoteEditor()
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.dayEvents().length === 0
                            ? "Este día no tiene eventos ni notas."
                            : "Las notas existentes se pueden borrar con la × "
                                + "de la lista del día."
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        TextField {
                            id: noteField

                            Layout.fillWidth: true
                            implicitHeight: 28
                            text: root.noteDraft
                            placeholderText: "Nueva nota para este día…"
                            placeholderTextColor: Theme.faint
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            selectByMouse: true
                            onTextEdited: root.noteDraft = text
                            onAccepted: root.addNoteFromDraft()
                            Keys.onEscapePressed: root.closeNoteEditor()
                            background: Rectangle {
                                radius: 7
                                color: Theme.surfaceAlt
                                border.width: 1
                                border.color: noteField.activeFocus
                                    ? Theme.accent : Theme.border
                            }
                        }

                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 28
                            radius: 7
                            color: addNoteMouse.containsMouse
                                ? Theme.accent : Theme.accentSoft
                            border.width: 1
                            border.color: Theme.accentLine

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                color: addNoteMouse.containsMouse
                                    ? Theme.accentInk : Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: addNoteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addNoteFromDraft()
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Intro guarda · Esc cierra"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: CalendarState.open && !timerField.editing
            && !root.alarmEditing
        onActivated: {
            if (root.noteEditorOpen)
                root.closeNoteEditor();
            else
                CalendarState.hide();
        }
    }
}
