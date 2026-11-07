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

    // Icono de una acción. Muchos .desktop no rellenan `Icon=` dentro de
    // `[Desktop Action ...]` (Brave, por ejemplo), así que se deduce del id o
    // del nombre. Los nombres del tema existen en Breeze y Adwaita; si no,
    // DesktopActions devuelve "" y el menú usa el glifo de siempre.
    function iconFor(action): string {
        if (!action)
            return "";
        const own = String(action.icon || "").trim();
        if (own.length > 0)
            return own;

        const id = String(action.id || "").toLowerCase();
        const name = String(action.name || "").toLowerCase();
        const both = id + " " + name;
        const candidates = [];

        if (both.indexOf("incognito") !== -1
                || both.indexOf("private") !== -1
                || both.indexOf("privad") !== -1
                || both.indexOf("incógnit") !== -1)
            candidates.push("view-private", "view-private-symbolic");
        if (both.indexOf("new-window") !== -1
                || both.indexOf("newwindow") !== -1
                || both.indexOf("nueva ventana") !== -1)
            candidates.push("window-new", "window-new-symbolic");
        if (both.indexOf("new-tab") !== -1
                || both.indexOf("newtab") !== -1
                || both.indexOf("nueva pestaña") !== -1)
            candidates.push("tab-new", "tab-new-symbolic");
        if (both.indexOf("trash") !== -1 || both.indexOf("papelera") !== -1)
            candidates.push("user-trash", "user-trash-symbolic");
        if (both.indexOf("home") !== -1 || both.indexOf("inicio") !== -1)
            candidates.push("go-home", "go-home-symbolic");
        if (both.indexOf("computer") !== -1 || both.indexOf("equipo") !== -1)
            candidates.push("computer", "computer-symbolic");
        if (both.indexOf("settings") !== -1
                || both.indexOf("preferences") !== -1
                || both.indexOf("configur") !== -1)
            candidates.push("settings-configure", "preferences-system");
        if (both.indexOf("new") !== -1)
            candidates.push("window-new", "window-new-symbolic");

        for (let i = 0; i < candidates.length; i++) {
            if (Quickshell.hasThemeIcon(candidates[i]))
                return candidates[i];
        }
        return "";
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
