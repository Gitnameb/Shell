pragma Singleton

import Quickshell
import QtQuick

// Acciones propias de una aplicación (.desktop), como «Nueva ventana» o
// «Nueva ventana de incógnito». Quickshell expone las entradas y sus
// `Actions=` en DesktopEntries/DesktopEntry.
//
// El escaneo de entradas es asíncrono: la primera lectura del modelo solo lo
// arranca. Por eso se lee al crear el singleton y se incrementa `revision`
// cuando termina, para que los menús que dependen de él se recalculen.
Singleton {
    id: root

    property int revision: 0
    property bool kicked: false
    readonly property int entryCount:
        DesktopEntries.applications.values.length

    // Los singletons no tienen Component.onCompleted fiable. Un temporizador
    // corto arranca el escaneo al crear el singleton.
    Timer {
        interval: 80
        running: true
        repeat: false
        onTriggered: root.kick()
    }

    function kick(): void {
        if (root.kicked)
            return;
        root.kicked = true;
        DesktopEntries.applications.values.length;
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged(): void {
            root.revision++;
        }
    }

    function entryFor(appId): var {
        root.kick();
        root.revision;
        const clean = String(appId === undefined || appId === null
            ? "" : appId).trim();
        if (clean.length === 0)
            return null;
        const entry = DesktopEntries.heuristicLookup(clean);
        if (entry)
            return entry;
        return DesktopEntries.byId(clean + ".desktop");
    }

    function actionsFor(appId): var {
        root.revision;
        const entry = root.entryFor(appId);
        return entry && entry.actions ? entry.actions : [];
    }

    function run(action): void {
        if (!action)
            return;
        // execute() resuelve los marcadores de campo (%f, %u, etc.).
        if (typeof action.execute === "function") {
            action.execute();
            return;
        }
        const command = action.command;
        if (command && command.length > 0)
            Quickshell.execDetached(command);
    }
}
