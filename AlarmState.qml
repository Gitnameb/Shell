pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Sonido y aviso de las alarmas.
//
// El sonido se repite en bucle hasta que se cierra la notificación de alarma
// o se pulsa el reloj de la barra. `CalendarPanel` llama a `fire()` cuando
// vence una alarma; la barra y el propio panel llaman a `stop()`.
Singleton {
    id: root

    // Id de la notificación que dejó `notify-send -p`.
    property string notificationId: ""
    // Con «No molestar» la notificación no se registra; en ese caso el sonido
    // solo se detiene al abrir el calendario.
    property bool dndAtFire: false

    readonly property bool sounding: soundProc.running
    readonly property string soundFile:
        "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

    function fire(alarms): void {
        if (!alarms || alarms.length === 0)
            return;
        const body = alarms.map((alarm) =>
            String(alarm.label || "Alarma") + " · " + alarm.time).join("\n");
        root.dismissNotification();
        root.dndAtFire = NotificationState.dnd;

        if (!soundProc.running) {
            soundProc.command = ["sh", "-c",
                "while :; do paplay \"$1\" 2>/dev/null "
                    + "|| pw-play \"$1\" 2>/dev/null "
                    + "|| canberra-gtk-play -f alarm-clock-elapsed 2>/dev/null "
                    + "|| sleep 1; done",
                "shell", root.soundFile];
            soundProc.running = true;
        }

        notifyProc.command = ["sh", "-c",
            "notify-send -p -a Shell -u critical -t 0 "
                + "-i alarm-clock-elapsed \"$1\" \"$2\"",
            "shell", "Alarma", body];
        notifyProc.running = true;
        watchdog.restart();
    }

    function stopSound(): void {
        soundProc.running = false;
        watchdog.stop();
    }

    function dismissNotification(): void {
        if (root.notificationId.length > 0) {
            const list = NotificationState.items || [];
            for (let i = 0; i < list.length; i++) {
                if (String(list[i].id) === root.notificationId) {
                    list[i].dismiss();
                    break;
                }
            }
        }
        root.notificationId = "";
    }

    // Silencia y retira el aviso: al pulsar el reloj o al abrir el calendario.
    function stop(): void {
        root.stopSound();
        root.dismissNotification();
    }

    function checkDismissed(): void {
        if (!soundProc.running || root.notificationId.length === 0
                || root.dndAtFire)
            return;
        const list = NotificationState.items || [];
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].id) === root.notificationId)
                return;
        }
        root.stopSound();
    }

    Process {
        id: soundProc
    }

    Process {
        id: notifyProc

        stdout: StdioCollector {
            id: notifyOut
        }

        onExited: {
            const value = String(notifyOut.text || "").trim().split("\n")[0];
            if (value.length > 0) {
                root.notificationId = value;
                root.checkDismissed();
            }
        }
    }

    // Red de seguridad: un aviso perdido no debe sonar para siempre.
    Timer {
        id: watchdog

        interval: 10 * 60 * 1000
        repeat: false
        onTriggered: root.stopSound()
    }

    Connections {
        target: NotificationState

        function onItemsChanged(): void {
            root.checkDismissed();
        }
    }
}
