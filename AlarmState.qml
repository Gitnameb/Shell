pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Sonido y aviso de alarmas y temporizador.
//
// El sonido se repite en bucle hasta que se cierra la notificación o se pulsa
// el reloj de la barra. `CalendarPanel` llama a `fire()` al vencer una alarma
// y a `fireTimer()` al terminar la cuenta atrás; la barra y el panel llaman a
// `stop()`.
Singleton {
    id: root

    // Id de la notificación que dejó `notify-send -p`.
    property string notificationId: ""
    // Con «No molestar» la notificación no se registra; en ese caso el sonido
    // solo se detiene al abrir el calendario.
    property bool dndAtFire: false

    // El reproductor es el proceso directo: al pararlo se corta el audio al
    // instante, sin esperar a que termine la secuencia que estuviera sonando.
    property bool active: false
    property string player: "paplay"
    property string currentSound:
        "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    readonly property bool sounding: root.active
    readonly property string alarmSound:
        "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    readonly property string timerSound:
        "/usr/share/sounds/freedesktop/stereo/complete.oga"

    function fire(alarms): void {
        if (!alarms || alarms.length === 0)
            return;
        const body = alarms.map((alarm) =>
            String(alarm.label || "Alarma") + " · " + alarm.time).join("\n");
        root.start("Alarma", body, root.alarmSound);
    }

    function fireTimer(): void {
        root.start("Temporizador", "Tiempo cumplido", root.timerSound);
    }

    function start(title, body, sound): void {
        root.dismissNotification();
        root.dndAtFire = NotificationState.dnd;
        root.currentSound = sound;

        if (!root.active) {
            root.active = true;
            root.playOnce();
        }

        notifyProc.command = ["sh", "-c",
            "notify-send -p -a Shell -u critical -t 0 "
                + "-i alarm-clock-elapsed \"$1\" \"$2\"",
            "shell", title, body];
        notifyProc.running = true;
        watchdog.restart();
    }

    function playOnce(): void {
        if (!root.active || root.player.length === 0)
            return;
        soundProc.command = [root.player, root.currentSound];
        soundProc.running = true;
    }

    function stopSound(): void {
        root.active = false;
        restartTimer.stop();
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

        onExited: {
            if (root.active)
                restartTimer.restart();
        }
    }

    // Repite la reproducción sin un bucle de shell: así el proceso que suena
    // es paplay/pw-play y se puede matar directamente al detener la alarma.
    Timer {
        id: restartTimer
        interval: 260
        repeat: false
        onTriggered: root.playOnce()
    }

    // Elige el reproductor disponible una sola vez.
    Process {
        id: playerCheck
        command: ["sh", "-c", "command -v paplay || command -v pw-play"]

        stdout: StdioCollector {
            id: playerOut
        }

        onExited: {
            const found = String(playerOut.text || "").trim();
            if (found.length > 0)
                root.player = found;
        }
    }

    Component.onCompleted: playerCheck.running = true

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
