pragma Singleton

import Quickshell
import QtQuick

// Resolución de iconos de notificaciones, compartida por el historial y por
// las tarjetas emergentes. Algunas apps envían un nombre que no coincide con
// el icono instalado; estas alias cubren los casos habituales.
Singleton {
    id: root

    readonly property var iconAliases: ({
        "firefox": "firefox-esr",
        "thunderbird": "thunderbird-esr",
        "org.mozilla.firefox": "firefox-esr",
        "code": "vscode",
        "com.visualstudio.code": "vscode",
        "telegram-desktop": "telegram",
        "org.telegram.desktop": "telegram"
    })

    function tryIcon(name): string {
        if (!name)
            return "";
        if (name.startsWith("/") || name.startsWith("file:"))
            return name;
        let clean = String(name);
        if (clean.endsWith(".desktop"))
            clean = clean.slice(0, -8);
        if (Quickshell.hasThemeIcon(clean))
            return Quickshell.iconPath(clean, "application-x-executable");
        const alias = root.iconAliases[clean.toLowerCase()];
        if (alias && Quickshell.hasThemeIcon(alias))
            return Quickshell.iconPath(alias, "application-x-executable");
        return "";
    }

    function iconSource(entry): string {
        if (!entry)
            return "";
        return root.tryIcon(entry.icon) || root.tryIcon(entry.desktopEntry);
    }
}
