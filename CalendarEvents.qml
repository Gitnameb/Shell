pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Notas del calendario del panel del reloj.
//
// Las notas las administra scripts/shell-calendar en
// ~/.config/shell/calendar-notes.conf. Aquí solo se pide el mes visible y se
// indexa por día para que el calendario pinte puntos y la lista del día.
Singleton {
    id: root

    property var events: []
    property bool loading: false
    property bool ready: false
    property int revision: 0
    property string rangeFrom: ""
    property string rangeTo: ""

    // Último mes mostrado: las mutaciones lo reutilizan para recargar el
    // mismo rango aunque el usuario haya navegado a otro mes.
    property var anchor: new Date()
    property bool queued: false

    readonly property string scriptPath:
        (Quickshell.shellDir || "") + "/scripts/shell-calendar"

    function key(date): string {
        return date.getFullYear() + "-" + Format.pad(date.getMonth() + 1)
            + "-" + Format.pad(date.getDate());
    }

    function firstOfMonth(date): var {
        return new Date(date.getFullYear(), date.getMonth(), 1);
    }

    function lastOfMonth(date): var {
        return new Date(date.getFullYear(), date.getMonth() + 1, 0);
    }

    function refresh(date): void {
        const month = date ? date : root.anchor;
        root.anchor = month;
        if (listProc.running) {
            root.queued = true;
            return;
        }
        root.rangeFrom = root.key(root.firstOfMonth(month));
        root.rangeTo = root.key(root.lastOfMonth(month));
        root.loading = true;
        listProc.command = [root.scriptPath, "list",
            "--from", root.rangeFrom, "--to", root.rangeTo];
        listProc.running = true;
    }

    function apply(raw): void {
        let data = null;
        try {
            data = JSON.parse(String(raw || "").trim());
        } catch (error) {
            data = null;
        }
        if (!data || !data.ok) {
            root.events = [];
            root.loading = false;
            return;
        }
        root.events = Array.isArray(data.events) ? data.events : [];
        root.loading = false;
        root.ready = true;
        root.revision++;
    }

    function reload(): void {
        root.refresh(root.anchor);
    }

    function eventsFor(date): var {
        const day = typeof date === "string" ? date : root.key(date);
        return root.events.filter((entry) => entry.date === day);
    }

    // -------------------------------------------------------------- acciones
    function addNote(date, text): void {
        const value = String(text || "").trim();
        if (value.length === 0)
            return;
        const day = typeof date === "string" ? date : root.key(date);
        noteProc.command = [root.scriptPath, "note", "add",
            "--date", day, "--text", value];
        noteProc.running = true;
    }

    function removeNote(entryId): void {
        const id = String(entryId || "").replace(/^note:/, "");
        if (id.length === 0)
            return;
        noteProc.command = [root.scriptPath, "note", "remove", "--id", id];
        noteProc.running = true;
    }

    Process {
        id: listProc

        stdout: StdioCollector {
            id: listOut
        }

        onExited: {
            root.apply(listOut.text);
            if (root.queued) {
                root.queued = false;
                root.refresh(root.anchor);
            }
        }
    }

    Process {
        id: noteProc

        stdout: StdioCollector {
            id: noteOut
        }

        onExited: root.reload()
    }

    // Si el archivo se edita por fuera, el panel abierto lo recoge sin tener
    // que cerrarse. Las notas son locales, así que no hay red de por medio.
    Timer {
        interval: 60 * 1000
        repeat: true
        running: CalendarState.open
        onTriggered: root.refresh(root.anchor)
    }
}
