pragma Singleton

import Quickshell
import QtQuick

// Rutas de los iconos dibujados para ALBA, copiados del sprite del diseño.
// Se tiñen con AlbaIcon igual que los del tema, pero conservan las formas
// exactas del mockup.
Singleton {
    readonly property string base: (Quickshell.shellDir || "") + "/icons/"

    function src(name: string): string {
        return base + name + ".svg";
    }
}
