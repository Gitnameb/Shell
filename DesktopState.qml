pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel

// Contenido del escritorio real (~/Desktop). Fase 1: ver y abrir. No guarda
// posiciones ni permite arrastrar todavía; el orden es el del sistema de
// archivos, con carpetas primero.
Singleton {
    id: root

    readonly property string desktopDir:
        (Quickshell.env("HOME") || "/home/username") + "/Desktop"
    property int selectedIndex: -1

    readonly property FolderListModel model: folderModel

    function isDesktopFile(name): bool {
        return String(name).toLowerCase().endsWith(".desktop");
    }

    function itemCount(): int {
        return folderModel.count;
    }

    function propertyAt(index, name): var {
        if (index < 0 || index >= folderModel.count)
            return undefined;
        return folderModel.get(index, name);
    }

    function entryFor(fileName): var {
        const name = String(fileName);
        let entry = DesktopEntries.byId(name);
        if (!entry && name.toLowerCase().endsWith(".desktop"))
            entry = DesktopEntries.byId(name.slice(0, -8));
        if (entry)
            return entry;
        const list = DesktopEntries.applications.values;
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].id) === name)
                return list[i];
        }
        return null;
    }

    function displayName(fileName): string {
        const entry = isDesktopFile(fileName) ? entryFor(fileName) : null;
        return entry && entry.name ? String(entry.name) : String(fileName);
    }

    function extensionOf(name): string {
        const clean = String(name);
        const dot = clean.lastIndexOf(".");
        return dot > 0 ? clean.slice(dot + 1).toLowerCase() : "";
    }

    function previewSource(fileName, fileURL, isDir): string {
        if (isDir || isDesktopFile(fileName))
            return "";
        const ext = extensionOf(fileName);
        if (["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif"].indexOf(ext) >= 0)
            return String(fileURL);
        return "";
    }

    function iconNameFor(fileName, isDir): string {
        if (isDir)
            return "folder";
        if (isDesktopFile(fileName)) {
            const entry = entryFor(fileName);
            if (entry && entry.icon)
                return String(entry.icon);
            return "application-x-executable";
        }
        const ext = extensionOf(fileName);
        if (["mp4", "mkv", "webm", "avi", "mov", "m4v"].indexOf(ext) >= 0)
            return "video-x-generic";
        if (["mp3", "flac", "ogg", "wav", "m4a", "opus", "aac"].indexOf(ext) >= 0)
            return "audio-x-generic";
        if (ext === "pdf")
            return "application-pdf";
        if (["zip", "tar", "gz", "xz", "7z", "rar", "zst"].indexOf(ext) >= 0)
            return "package-x-generic";
        if (["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif"].indexOf(ext) >= 0)
            return "image-x-generic";
        return "text-x-generic";
    }

    function iconSource(fileName, isDir): string {
        return Quickshell.iconPath(iconNameFor(fileName, isDir), "text-x-generic");
    }

    function launchEntry(entry): void {
        if (!entry)
            return;
        const command = entry.command || [];
        if (command.length > 0) {
            let line = ["env", "-u", "HL_INITIAL_WORKSPACE_TOKEN"];
            if (entry.runInTerminal)
                line = line.concat(["kitty", "-e"]);
            Quickshell.execDetached(line.concat(command));
        } else {
            entry.execute();
        }
    }

    function openIndex(index): void {
        const fileName = propertyAt(index, "fileName");
        if (fileName === undefined)
            return;
        const filePath = propertyAt(index, "filePath");
        const isDir = propertyAt(index, "fileIsDir") === true;

        if (isDesktopFile(fileName)) {
            const entry = entryFor(fileName);
            if (entry) {
                launchEntry(entry);
                return;
            }
        }
        Quickshell.execDetached(["xdg-open", String(filePath)]);
    }

    // Archivos soltados sobre el escritorio: se mueven desde la misma unidad y
    // se copian desde otra, como en Windows. Los nombres repetidos no se pisan.
    readonly property string dropScript: (Quickshell.shellDir || "")
        + "/scripts/alba-desktop-drop"

    function dropUrls(urls): void {
        if (!urls || urls.length === 0)
            return;
        const paths = [];
        for (let i = 0; i < urls.length; i++) {
            let value = String(urls[i]);
            if (!value.startsWith("file://"))
                continue;
            value = value.slice(7);
            if (value.startsWith("localhost/"))
                value = value.slice(9);
            try {
                value = decodeURIComponent(value);
            } catch (error) {
                // Un nombre mal codificado se deja tal cual.
            }
            if (value.length > 0)
                paths.push(value);
        }
        if (paths.length === 0)
            return;
        dropProc.command = [root.dropScript].concat(paths);
        dropProc.running = true;
    }

    Process {
        id: dropProc
    }

    FolderListModel {
        id: folderModel

        folder: "file://" + root.desktopDir
        showDirs: true
        showFiles: true
        showHidden: false
        showDirsFirst: true
        sortField: FolderListModel.Name
        sortCaseSensitive: false
    }
}
