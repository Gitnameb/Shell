pragma Singleton

import Quickshell

// Formato compartido por el calendario, las alarmas y el temporizador.
Singleton {
    id: root

    // Dos dígitos para horas, minutos y segundos.
    function pad(value): string {
        return value < 10 ? "0" + value : "" + value;
    }
}
