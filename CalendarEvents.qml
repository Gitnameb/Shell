pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Agenda del panel del reloj: notas locales y calendarios en formato iCalendar.
//
// Los datos los administra scripts/shell-calendar, que también descarga y
// cachea los calendarios remotos (por ejemplo la dirección iCal privada de
// Google Calendar). Aquí solo se pide el rango visible y se indexa por día
// para que el calendario pinte puntos y la agenda muestre los próximos días.
Singleton {
    id: root

    property var events: []
    property var sources: []
    property var errors: []
    // date (YYYY-MM-DD) → { count, notes }
    property var byDate: ({})
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

    function pad(value): string {
        return value < 10 ? "0" + value : "" + value;
    }

    function key(date): string {
        return date.getFullYear() + "-" + pad(date.getMonth() + 1)
            + "-" + pad(date.getDate());
    }

    function firstOfMonth(date): var {
        return new Date(date.getFullYear(), date.getMonth(), 1);
    }

    // Rango que cubre el mes visible y, como mínimo, los próximos 62 días.
    // Así la pestaña Agenda puede listar lo que viene sin otra consulta.
    function rangeFor(date): var {
        const monthStart = firstOfMonth(date);
        const monthEnd = new Date(date.getFullYear(), date.getMonth() + 1, 0);
        const today = new Date();
        const todayStart = new Date(today.getFullYear(), today.getMonth(),
            today.getDate());
        const start = monthStart.getTime() < todayStart.getTime()
            ? monthStart : todayStart;
        const horizon = new Date(todayStart.getFullYear(),
            todayStart.getMonth(), todayStart.getDate() + 62);
        const end = monthEnd.getTime() > horizon.getTime() ? monthEnd : horizon;
        return { from: key(start), to: key(end) };
    }

    function refresh(date): void {
        const month = date ? date : root.anchor;
        root.anchor = month;
        const span = root.rangeFor(month);
        if (listProc.running) {
            root.queued = true;
            return;
        }
        root.rangeFrom = span.from;
        root.rangeTo = span.to;
        root.loading = true;
        listProc.command = [root.scriptPath, "list",
            "--from", span.from, "--to", span.to];
        listProc.running = true;
    }

    function refreshNow(date): void {
        const month = date ? date : root.anchor;
        root.anchor = month;
        const span = root.rangeFor(month);
        root.rangeFrom = span.from;
        root.rangeTo = span.to;
        root.loading = true;
        forceProc.command = [root.scriptPath, "list", "--force",
            "--from", span.from, "--to", span.to];
        forceProc.running = true;
    }

    function apply(raw): void {
        let data = null;
        try {
            data = JSON.parse(String(raw || "").trim());
        } catch (error) {
            data = null;
        }
        if (!data || !data.ok) {
            root.errors = ["No se pudo leer el calendario."];
            root.loading = false;
            return;
        }
        const list = Array.isArray(data.events) ? data.events : [];
        const index = {};
        for (let i = 0; i < list.length; i++) {
            const entry = list[i];
            let bucket = index[entry.date];
            if (!bucket) {
                bucket = { count: 0, notes: 0 };
                index[entry.date] = bucket;
            }
            bucket.count += 1;
            if (entry.note)
                bucket.notes += 1;
        }
        root.events = list;
        root.sources = Array.isArray(data.sources) ? data.sources : [];
        root.errors = Array.isArray(data.errors) ? data.errors : [];
        root.byDate = index;
        root.loading = false;
        root.ready = true;
        root.revision++;
    }

    function reload(): void {
        root.refresh(root.anchor);
    }

    function dayInfo(date): var {
        return root.byDate[root.key(date)] || { count: 0, notes: 0 };
    }

    function eventsFor(date): var {
        const day = typeof date === "string" ? date : root.key(date);
        return root.events.filter((entry) => entry.date === day);
    }

    function upcoming(days): var {
        const today = new Date();
        const start = root.key(new Date(today.getFullYear(),
            today.getMonth(), today.getDate()));
        const end = root.key(new Date(today.getFullYear(),
            today.getMonth(), today.getDate() + (days || 30)));
        return root.events.filter((entry) => entry.date >= start
            && entry.date <= end);
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

    function addSource(name, url): void {
        const label = String(name || "").trim();
        const address = String(url || "").trim();
        if (label.length === 0 || address.length === 0)
            return;
        sourceProc.command = [root.scriptPath, "source", "add",
            "--name", label, "--url", address];
        sourceProc.running = true;
    }

    function removeSource(sourceId): void {
        if (!sourceId)
            return;
        sourceProc.command = [root.scriptPath, "source", "remove",
            "--id", String(sourceId)];
        sourceProc.running = true;
    }

    function toggleSource(sourceId): void {
        if (!sourceId)
            return;
        sourceProc.command = [root.scriptPath, "source", "toggle",
            "--id", String(sourceId)];
        sourceProc.running = true;
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
        id: forceProc

        stdout: StdioCollector {
            id: forceOut
        }

        onExited: root.apply(forceOut.text)
    }

    Process {
        id: noteProc

        stdout: StdioCollector {
            id: noteOut
        }

        onExited: {
            try {
                const reply = JSON.parse(String(noteOut.text || "").trim());
                if (reply && reply.ok === false)
                    root.errors = [String(reply.error || "No se pudo guardar.")];
            } catch (error) {
            }
            root.reload();
        }
    }

    Process {
        id: sourceProc

        stdout: StdioCollector {
            id: sourceOut
        }

        onExited: {
            try {
                const reply = JSON.parse(String(sourceOut.text || "").trim());
                if (reply && reply.ok === false)
                    root.errors = [String(reply.error || "No se pudo guardar.")];
            } catch (error) {
            }
            root.reload();
        }
    }

    // Con el panel abierto se refresca solo: los calendarios remotos se
    // recargan como mucho cada 20 minutos (lo decide el script).
    Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: CalendarState.open
        onTriggered: root.refresh(root.anchor)
    }
}
