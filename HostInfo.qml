pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Nombre visible de esta máquina. Lo usan el punto de acceso Wi-Fi y el
// adaptador Bluetooth para que otras personas vean el nombre del equipo en
// lugar de un nombre genérico del shell.
Singleton {
    id: root

    property string name: ""
    readonly property string displayName: root.name.length > 0 ? root.name : "ALBA"

    // Se consulta una sola vez al arrancar; no hay Component.onCompleted en
    // los singletons de Quickshell, así que se usa un temporizador corto.
    Timer {
        interval: 40
        running: true
        repeat: false
        onTriggered: hostProc.running = true
    }

    Process {
        id: hostProc

        command: ["hostname"]

        stdout: StdioCollector {
            id: hostOut
        }

        onExited: {
            const value = hostOut.text.trim();
            if (value.length > 0)
                root.name = value;
        }
    }
}
