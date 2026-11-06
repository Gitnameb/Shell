pragma Singleton

import Quickshell

// Nombres en español, independientes del locale del sistema.
Singleton {
    readonly property var months: [
        "enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
    ]

    readonly property var monthsShort: [
        "ene", "feb", "mar", "abr", "may", "jun",
        "jul", "ago", "sep", "oct", "nov", "dic"
    ]

    readonly property var weekdays: [
        "domingo", "lunes", "martes", "miércoles",
        "jueves", "viernes", "sábado"
    ]

    readonly property var weekdaysShort: [
        "dom", "lun", "mar", "mié", "jue", "vie", "sáb"
    ]

    readonly property var weekdaysInitial: ["L", "M", "X", "J", "V", "S", "D"]

    function monthName(date): string {
        return months[date.getMonth()];
    }

    function monthNameShort(date): string {
        return monthsShort[date.getMonth()];
    }

    function weekdayName(date): string {
        return weekdays[date.getDay()];
    }

    function weekdayNameShort(date): string {
        return weekdaysShort[date.getDay()];
    }

    function longDate(date): string {
        return weekdayName(date) + ", " + date.getDate()
            + " de " + monthName(date) + " de " + date.getFullYear();
    }

    function shortDate(date): string {
        return weekdayNameShort(date) + " " + date.getDate()
            + " " + monthNameShort(date);
    }
}
