pragma Singleton

import Quickshell

// Canal para que las fichas del centro de control pidan desplazar el panel
// cuando la rueda no está ajustando un valor.
Singleton {
    id: root

    signal scrolled(real delta)

    function request(delta): void {
        root.scrolled(delta);
    }
}
