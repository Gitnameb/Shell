pragma Singleton

import Quickshell
import QtQuick

// Rutas de los iconos dibujados para el shell, copiados del sprite del diseño.
// Se tiñen con ShellIcon igual que los del tema, pero conservan las formas
// exactas del mockup.
Singleton {
    readonly property string base: (Quickshell.shellDir || "") + "/icons/"

    // Tamaño del dibujo (ancho, alto) dentro del viewBox 24x24, medido del SVG
    // rasterizado. Los iconos no ocupan todo el viewBox: sin normalizar, unos
    // parecen mucho más grandes que otros (por ejemplo, Ethernet frente a
    // Wi-Fi). ShellIcon usa esta tabla para escalar cada dibujo y que su lado
    // mayor mida lo mismo.
    readonly property var visualSizes: ({
        "wifi": [16.40, 13.80],
        "wifi-1": [16.40, 13.70],
        "wifi-2": [16.40, 13.70],
        "wifi-3": [16.40, 13.80],
        "wifi-none": [16.40, 13.70],
        "wifi-off": [17.20, 17.20],
        "globe": [19.80, 19.80],
        "globe-off": [19.80, 19.80],
        "wired": [21.80, 17.80],
        "usb": [10.50, 16.10],
        "bluetooth": [11.80, 17.80],
        "moon": [18.50, 18.50],
        "plane": [21.80, 19.80],
        "sun": [21.80, 21.80],
        "dim": [15.80, 15.80],
        "cpu": [20.80, 20.80],
        "gpu": [20.80, 15.30],
        "shield": [15.80, 19.80],
        "net": [20.20, 15.60],
        "keyboard": [21.80, 13.80],
        "clipboard": [15.80, 20.80],
        "hotspot": [23.80, 20.40],
        "settings": [23.80, 23.80],
        "dns": [18.80, 17.80],
        "mic": [12.80, 19.30],
        "mic-off": [16.80, 19.30],
        "bell": [19.00, 20.20],
        "bell-off": [21.20, 21.20],
        "grid": [18.00, 18.00],
        "chevron-up": [14.00, 8.00],
        "music": [16.80, 18.30],
        "mode-tile": [19.80, 19.80],
        "mode-float": [19.80, 19.80],
        "volume-1": [13.30, 13.80],
        "volume-2": [16.30, 13.80],
        "volume-3": [19.30, 16.00],
        "volume-off": [18.80, 13.80],
        "power": [18.80, 20.20]
    })

    // Fracción del viewBox que ocupa el lado mayor después de normalizar.
    // 0,84 deja un margen uniforme dentro de la caja de 22 px.
    readonly property real normalizedSide: 24 * 0.84

    function normalizeScale(name: string): real {
        const size = visualSizes[name];
        if (!size || size.length < 2)
            return 1.0;
        const largest = Math.max(size[0], size[1]);
        return largest > 0 ? normalizedSide / largest : 1.0;
    }

    function src(name: string): string {
        return base + name + ".svg";
    }
}
