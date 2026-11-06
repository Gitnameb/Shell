pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Distribución detectada a partir de /etc/os-release. Se usa para el botón
// del lanzador: muestra el logotipo de la distro si existe en el tema y, si
// no, una cuadrícula de cuatro cuadros.
Singleton {
    id: root

    property string distroId: ""
    property string distroName: ""
    property bool loaded: false

    // Nombres habituales de los logotipos en los temas de iconos. Si un
    // nombre no existe, se usa la cuadrícula de respaldo.
    readonly property var iconNames: ({
        "arch": "archlinux-logo",
        "artix": "artix-logo",
        "cachyos": "cachyos-logo",
        "debian": "emblem-debian-symbolic",
        "endeavouros": "endeavouros-logo",
        "elementary": "elementary-logo",
        "fedora": "fedora-logo",
        "gentoo": "gentoo-logo",
        "kali": "kali-linux-logo",
        "linuxmint": "linuxmint-logo",
        "manjaro": "manjaro-logo",
        "nixos": "nixos-logo",
        "opensuse": "opensuse-logo",
        "opensuse-tumbleweed": "opensuse-logo",
        "pop": "pop-os-logo",
        "ubuntu": "ubuntu-logo",
        "zorin": "zorin-os-logo"
    })

    readonly property string iconSource: {
        const id = root.distroId.toLowerCase();
        // Debian no siempre trae el emblema en el tema activo. Probamos los
        // nombres habituales y, si ninguno existe, usamos la cuadrícula.
        // Nunca devolvemos una ruta fija que pueda no existir.
        if (id === "debian" || id === "devuan") {
            const candidates = ["emblem-debian-symbolic",
                "distributor-logo-debian", "debian-logo"];
            for (let i = 0; i < candidates.length; i++) {
                if (Quickshell.hasThemeIcon(candidates[i]))
                    return Quickshell.iconPath(candidates[i]);
            }
            return AlbaIcons.src("grid");
        }
        const name = root.iconNames[id];
        if (name && Quickshell.hasThemeIcon(name))
            return Quickshell.iconPath(name);
        return AlbaIcons.src("grid");
    }

    Process {
        id: osReleaseProc

        command: ["sh", "-c", "cat /etc/os-release 2>/dev/null || true"]

        stdout: StdioCollector {
            id: osReleaseOut
        }

        onExited: {
            const lines = osReleaseOut.text.split("\n");
            let id = "";
            let name = "";
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                if (line.startsWith("ID=") && id.length === 0)
                    id = line.slice(3).replace(/^["']|["']$/g, "");
                else if (line.startsWith("NAME=") && name.length === 0)
                    name = line.slice(5).replace(/^["']|["']$/g, "");
            }
            root.distroId = id;
            root.distroName = name;
            root.loaded = true;
        }
    }

    Timer {
        interval: 40
        running: true
        repeat: false
        onTriggered: osReleaseProc.running = true
    }
}
