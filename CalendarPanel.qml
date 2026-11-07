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

    readonly property string alarmsPath: (Quickshell.env("HOME")
        || "/home/username") + "/.config/shell/alarms.conf"
    readonly property string alarmSound:
        "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    readonly property string doneSound:
        "/usr/share/sounds/freedesktop/stereo/complete.oga"

    // --------------------------------------------------------- temporizador
    property int timerTotal: 25 * 60
    property int timerLeft: 25 * 60
    property bool timerRunning: false
    property string timerState: "Listo"
    property string timerInput: ""
    // Vencimiento en segundos desde la época. Se guarda en timer.conf para
    // que el demonio de alarmas pueda terminarlo con el shell cerrado.
    property int timerDeadline: 0
    readonly property string timerPath: (Quickshell.env("HOME")
        || "/home/username") + "/.config/shell/timer.conf"

    function pad(value): string {
        return value < 10 ? "0" + value : "" + value;
    }

    function shiftMonth(delta): void {
        shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + delta, 1);
    }

    function sameDay(a, b): bool {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    function selectDay(cell): void {
        root.selectedDate = cell.date;
        if (!cell.inMonth) {
            root.shownMonth = new Date(cell.date.getFullYear(),
                cell.date.getMonth(), 1);
        }
    }

    function goToday(): void {
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

    function notify(title, body): void {
        Quickshell.execDetached(["notify-send", "-a", "Shell", title, body]);
    }

    function validTime(value): bool {
        return /^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(value);
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
        const next = new Date();
        next.setHours(next.getHours() + 1, 0, 0, 0);
        const time = root.pad(next.getHours()) + ":" + root.pad(next.getMinutes());
        root.alarms = root.alarms.concat([{ time: time, label: "Alarma", enabled: true }]);
    }

    function removeAlarm(index): void {
        root.alarms = root.alarms.filter((alarm, position) => position !== index);
    }

    function playSound(path): void {
        Quickshell.execDetached(["sh", "-c",
            "paplay \"$1\" 2>/dev/null || pw-play \"$1\" 2>/dev/null || true",
            "shell", path]);
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
        const stamp = root.pad(now.date.getHours()) + ":"
            + root.pad(now.date.getMinutes());
        if (root.alarmMinute !== stamp) {
            root.alarmMinute = stamp;
            root.firedAlarms = ({});
        }
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
            root.playSound(root.alarmSound);
            root.notify("Alarma", alarm.label + " · " + alarm.time);
        }
    }

    function formatSeconds(value): string {
        const minutes = Math.floor(value / 60);
        const seconds = value % 60;
        return root.pad(minutes) + ":" + root.pad(seconds);
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
        root.timerRunning = false;
        root.timerTotal = minutes * 60;
        root.timerLeft = minutes * 60;
        root.timerState = "Listo";
    }

    function toggleTimer(): void {
        if (root.timerLeft <= 0) {
            root.timerLeft = root.timerTotal;
        }
        root.timerRunning = !root.timerRunning;
        root.timerState = root.timerRunning ? "En marcha" : "Pausado";
    }

    function resetTimer(): void {
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
                root.playSound(root.doneSound);
                root.notify("Temporizador", "Tiempo cumplido");
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
                root.playSound(root.doneSound);
                root.notify("Temporizador", "Tiempo cumplido");
                root.writeTimer(0);
                return;
            }
            const left = deadline - nowSeconds;
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
        anchors.fill: parent
        radius: 16
        color: Theme.glassCard
        border.width: 1
        border.color: Theme.borderStrong
        clip: true

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

                        Text {
                            Layout.fillWidth: true
                            text: "Hoy · " + Fechas.longDate(now.date)
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            elide: Text.ElideRight
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

                            Text {
                                anchors.centerIn: parent
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

                // Fecha elegida y vuelta rápida a hoy.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: Fechas.longDate(root.selectedDate)
                        color: root.sameDay(root.selectedDate, now.date)
                            ? Theme.faint : Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: !root.sameDay(root.selectedDate, now.date)
                        implicitWidth: 34
                        implicitHeight: 20
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
                        }

                        MouseArea {
                            id: todayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.goToday()
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
                        name: WeatherState.currentIcon
                        color: Theme.accent
                        size: 38
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
                                    name: modelData.icon
                                    color: Theme.muted
                                    size: 14
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
                            name: modelData.icon
                            color: Theme.faint
                            size: 14
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

                            TextField {
                                id: alarmTime

                                Layout.preferredWidth: 52
                                text: alarmRow.modelData.time
                                color: alarmRow.modelData.enabled
                                    ? Theme.text
                                    : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                horizontalAlignment: TextInput.AlignHCenter
                                selectByMouse: true
                                validator: RegularExpressionValidator {
                                    regularExpression: /^([01][0-9]|2[0-3]):[0-5][0-9]$/
                                }
                                onEditingFinished: root.updateAlarm(
                                    alarmRow.index, "time", text)
                                background: Rectangle {
                                    radius: 6
                                    color: Theme.surfaceAlt
                                    border.width: 1
                                    border.color: Theme.border
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
                                onToggled: root.updateAlarm(
                                    alarmRow.index, "enabled",
                                    !alarmRow.modelData.enabled)
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

                Text {
                    Layout.fillWidth: true
                    text: root.formatSeconds(root.timerLeft)
                    color: root.timerState === "Terminado"
                        ? Theme.danger : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 44
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
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
                            color: root.timerTotal === modelData * 60
                                ? Theme.accentSoft : Theme.surfaceAlt
                            border.width: 1
                            border.color: root.timerTotal === modelData * 60
                                ? Theme.accentLine
                                : Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: modelData + " min"
                                color: root.timerTotal === modelData * 60
                                    ? Theme.accent : Theme.muted
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

                    // Minutos a medida: se aplican al pulsar Enter o al salir
                    // del campo.
                    TextField {
                        id: timerMinutes

                        implicitWidth: 56
                        implicitHeight: 26
                        padding: 0
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        placeholderText: "Otro"
                        placeholderTextColor: Theme.faint
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        selectByMouse: true
                        validator: IntValidator {
                            bottom: 1
                            top: 600
                        }
                        background: Rectangle {
                            radius: 7
                            color: Theme.surfaceAlt
                            border.width: 1
                            border.color: Theme.border
                        }
                        onEditingFinished: {
                            const value = parseInt(text, 10);
                            if (!isNaN(value) && value >= 1 && value <= 600) {
                                root.setTimerPreset(value);
                                text = "";
                            } else {
                                text = "";
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
    }

    Shortcut {
        sequence: "Escape"
        enabled: CalendarState.open
        onActivated: CalendarState.hide()
    }
}
