pragma Singleton

import Quickshell
import QtQuick

// Tokens de apariencia. Los colores se derivan de dos preferencias del usuario:
// el modo (oscuro o claro) y el color de acento. Así todo el shell cambia a la
// vez sin tocar cada componente.
Singleton {
    id: root

    // ------------------------------------------------------------ medidas
    readonly property int edge: 8
    readonly property int barHeight: 44
    readonly property int barRadius: 15
    readonly property int itemHeight: 34
    readonly property int itemRadius: 9
    readonly property int gap: 2

    readonly property string fontFamily: "Inter"

    // ------------------------------------------------------------- modo
    readonly property bool light: SettingsState.themeMode === "light"
    readonly property bool dark: !root.light

    // ------------------------------------------------------------ acento
    // El color elegido se ajusta en cada modo para que siempre tenga contraste:
    // en oscuro se aclara si hace falta y en claro se oscurece, conservando el
    // tono. El gris por defecto funciona en ambos.
    readonly property color accentBase: SettingsState.accentColor
        || "#b8bec7"

    function luminance(value): real {
        return 0.2126 * value.r + 0.7152 * value.g + 0.0722 * value.b;
    }

    function mixColor(from, to, amount): color {
        return Qt.rgba(from.r + (to.r - from.r) * amount,
            from.g + (to.g - from.g) * amount,
            from.b + (to.b - from.b) * amount, 1);
    }

    function adjustedAccent(): color {
        const base = root.accentBase;
        const lum = root.luminance(base);
        if (root.light && lum > 0.38) {
            const amount = Math.min(0.85,
                (lum - 0.38) / Math.max(0.01, lum));
            return root.mixColor(base, Qt.rgba(0, 0, 0, 1), amount);
        }
        if (root.dark && lum < 0.55) {
            const amount = Math.min(0.85,
                (0.55 - lum) / Math.max(0.01, 1 - lum));
            return root.mixColor(base, Qt.rgba(1, 1, 1, 1), amount);
        }
        return base;
    }

    readonly property color accent: root.adjustedAccent()
    // Mismo tono de acento, más tenue, para estados apagados o sin actividad.
    readonly property color accentFaded: Qt.rgba(root.accent.r,
        root.accent.g, root.accent.b, root.light ? 0.68 : 0.58)
    readonly property color accentSoft: Qt.rgba(root.accent.r,
        root.accent.g, root.accent.b, root.light ? 0.14 : 0.16)
    // Relleno muy tenue para zonas que se iluminan al arrastrar.
    readonly property color accentGhost: Qt.rgba(root.accent.r,
        root.accent.g, root.accent.b, root.light ? 0.08 : 0.06)
    // Bordes y anillos alrededor de elementos activos.
    readonly property color accentLine: Qt.rgba(root.accent.r,
        root.accent.g, root.accent.b, root.light ? 0.45 : 0.35)
    readonly property color accentInk: root.luminance(root.accent) > 0.5
        ? "#15171a" : "#f7f8fa"

    // ------------------------------------------------------- superficies
    // En oscuro la barra y los paneles usan un gris muy oscuro, casi negro.
    readonly property color bg: root.light ? "#f2f1ee" : "#0b0d10"
    readonly property color surface: root.light ? "#ffffff" : "#121418"
    readonly property color surfaceAlt: root.light ? "#f0efec" : "#191c21"
    readonly property color text: root.light ? "#1b1d21" : "#ebeae5"
    readonly property color muted: root.light ? "#565d67" : "#9aa1ab"
    readonly property color faint: root.light ? "#7c838d" : "#6b7280"

    readonly property color glass: root.light
        ? Qt.rgba(252 / 255, 252 / 255, 250 / 255, 0.90)
        : Qt.rgba(17 / 255, 19 / 255, 22 / 255, 0.92)

    readonly property color border: root.light
        ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color borderStrong: root.light
        ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.14)
    readonly property color hover: root.light
        ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)

    // --------------------------------------------------------- estados
    readonly property color danger: root.light ? "#c4423e" : "#ff7a7a"
    readonly property color green: root.light ? "#2f8a56" : "#9ad9b0"
    readonly property color warning: root.light ? "#a97a12" : "#f2c96b"
    readonly property color warm: root.light ? "#b5641b" : "#f6a04d"
    readonly property color info: root.light ? "#2b7f96" : "#8fd3e8"
}
