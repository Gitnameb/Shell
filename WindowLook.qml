pragma Singleton

import Quickshell
import QtQuick

// Apariencia compartida de las ventanas: icono real, nombre legible, color
// estable y pantalla a la que pertenece. Evita duplicar la heurística de
// WorkspacePill en el overlay de Super y en la barra de título.
Singleton {
    id: root

    function iconFor(appId): string {
        const cls = String(appId || "");
        if (cls.length === 0)
            return "";
        if (cls.startsWith("/") || cls.startsWith("file:"))
            return cls;

        const candidates = [cls, cls.toLowerCase()];
        for (let i = 0; i < candidates.length; i++) {
            if (Quickshell.hasThemeIcon(candidates[i]))
                return Quickshell.iconPath(candidates[i]);
        }

        const entry = DesktopEntries.heuristicLookup(cls);
        if (entry && entry.icon) {
            if (entry.icon.startsWith("/") || entry.icon.startsWith("file:"))
                return entry.icon;
            if (Quickshell.hasThemeIcon(entry.icon))
                return Quickshell.iconPath(entry.icon);
        }
        return "";
    }

    function nameFor(appId): string {
        const entry = DesktopEntries.heuristicLookup(String(appId || ""));
        if (entry && entry.name)
            return entry.name;
        let name = String(appId || "");
        const dot = name.lastIndexOf(".");
        if (dot !== -1)
            name = name.slice(dot + 1);
        name = name.replace(/[-_]/g, " ");
        return name.length > 0
            ? name.charAt(0).toUpperCase() + name.slice(1) : "Aplicación";
    }

    function letterFor(appId): string {
        let name = String(appId || "");
        const slash = name.lastIndexOf("/");
        if (slash !== -1)
            name = name.slice(slash + 1);
        const dot = name.indexOf(".");
        if (dot > 0)
            name = name.slice(dot + 1);
        return name.length > 0 ? name.charAt(0).toUpperCase() : "?";
    }

    function colorFor(appId): string {
        const key = String(appId || "").toLowerCase();
        const known = [
            [["firefox", "chrom", "brave", "zen", "epiphany"], "#8ab4f8"],
            [["konsole", "terminal", "kitty", "alacritty", "foot", "wezterm",
                "terminator", "xterm"], "#7fd1b9"],
            [["dolphin", "nautilus", "thunar", "files", "pcmanfm"], "#f4c97a"],
            [["spotify", "music", "mpv", "vlc", "elisa", "audacious"], "#c9b8f5"],
            [["code", "codium", "zed", "neovim", "nvim", "editor"], "#9ad9b0"],
            [["settings", "systemsettings", "control-center"], "#b8c4d4"],
            [["calc"], "#f4a6a6"],
            [["spectacle", "screenshot", "grim", "flameshot"], "#a6d8f4"],
            [["gimp", "krita", "inkscape", "draw"], "#e8a9d6"]
        ];
        for (let i = 0; i < known.length; i++) {
            const aliases = known[i][0];
            for (let j = 0; j < aliases.length; j++) {
                if (key.indexOf(aliases[j]) !== -1)
                    return known[i][1];
            }
        }
        const palette = [
            "#8ab4f8", "#7fd1b9", "#f4c97a", "#c9b8f5", "#9ad9b0",
            "#f4a6a6", "#a6d8f4", "#8fd3e8", "#e8a9d6", "#f5c28b"
        ];
        let hash = 0;
        for (let i = 0; i < key.length; i++)
            hash = (hash * 31 + key.charCodeAt(i)) >>> 0;
        return palette[hash % palette.length];
    }

    function tintFor(hex): color {
        const value = String(hex).replace("#", "");
        if (value.length !== 6)
            return Theme.hover;
        return Qt.rgba(parseInt(value.substr(0, 2), 16) / 255,
            parseInt(value.substr(2, 2), 16) / 255,
            parseInt(value.substr(4, 2), 16) / 255, 0.20);
    }

    // Pantalla del monitor que declara la ventana. Con un solo monitor
    // devuelve la primera; con varios empareja por nombre.
    function screenFor(monitorName): var {
        const screens = Quickshell.screens || [];
        const name = String(monitorName || "");
        for (let i = 0; i < screens.length; i++) {
            if (String(screens[i].name || "") === name)
                return screens[i];
        }
        return screens.length > 0 ? screens[0] : null;
    }

    function workspaceLabel(win): string {
        if (!win)
            return "";
        if (win.minimized === true && Number(win.originWorkspaceId) > 0)
            return "minimizada · " + Number(win.originWorkspaceId);
        return "escritorio " + Number(win.workspaceId || 0);
    }
}
