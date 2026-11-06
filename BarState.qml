pragma Singleton

import Quickshell

// Controles que el usuario ha colocado en la barra. Un control solo puede
// estar en un sitio: si está aquí, desaparece de la cuadrícula del centro de
// control, y al devolverlo al panel vuelve a aparecer allí.
Singleton {
    id: root

    readonly property var defaultControls:
        ["music", "wifi", "bluetooth", "volume", "cpu", "gpu", "net"]
    readonly property var defaultCenterOrder: [
        "wifi", "bluetooth", "volume", "mic", "night",
        "airplane", "brightness", "extraDim", "clipboard", "music",
        "keyboard", "hotspot", "vpn", "cpu", "gpu", "net", "settings"
    ]

    property var controls: root.defaultControls.slice()

    // Orden propio de la cuadrícula del centro de control. Se conserva aunque
    // un control se mueva a la barra y vuelva después.
    property var centerOrder: root.defaultCenterOrder.slice()

    // Todos los controles disponibles, en el orden en que se muestran.
    readonly property var allKeys: [
        "music", "wifi", "bluetooth", "volume", "mic", "night",
        "airplane", "brightness", "extraDim", "hotspot", "vpn",
        "keyboard", "clipboard", "cpu", "gpu", "net", "settings"
    ]

    // Valida una lista separada por comas leída de settings.conf. Ignora
    // claves desconocidas y duplicadas. `complete` añade al final los controles
    // que falten, como exige la cuadrícula del centro.
    function sanitize(text, fallback, complete): var {
        const raw = String(text === undefined || text === null ? "" : text)
            .split(",");
        const seen = ({});
        const out = [];
        for (let i = 0; i < raw.length; i++) {
            const key = raw[i].trim();
            if (key.length === 0 || root.allKeys.indexOf(key) === -1
                    || seen[key] === true)
                continue;
            seen[key] = true;
            out.push(key);
        }
        if (out.length === 0)
            return fallback.slice();
        if (complete) {
            for (let i = 0; i < root.allKeys.length; i++) {
                const key = root.allKeys[i];
                if (seen[key] === true)
                    continue;
                seen[key] = true;
                out.push(key);
            }
        }
        return out;
    }

    // Restaura el orden guardado. Los textos vacíos conservan los valores
    // actuales, de modo que un settings.conf antiguo siga usando los defaults.
    function restore(controlsText, centerText): void {
        if (String(controlsText === undefined || controlsText === null
                ? "" : controlsText).trim().length > 0)
            root.controls = root.sanitize(controlsText, root.defaultControls, false);
        if (String(centerText === undefined || centerText === null
                ? "" : centerText).trim().length > 0)
            root.centerOrder = root.sanitize(centerText, root.defaultCenterOrder, true);
    }

    function resetLayout(): void {
        root.controls = root.defaultControls.slice();
        root.centerOrder = root.defaultCenterOrder.slice();
    }

    // Controles que ahora mismo están en el centro de control, en el orden
    // elegido por el usuario.
    readonly property var centerControls: {
        const present = root.allKeys.filter(
            (key) => root.controls.indexOf(key) === -1);
        const ordered = root.centerOrder.filter(
            (key) => present.indexOf(key) !== -1);
        for (let i = 0; i < present.length; i++) {
            if (ordered.indexOf(present[i]) === -1)
                ordered.push(present[i]);
        }
        return ordered;
    }

    function has(key): bool {
        return root.controls.indexOf(key) !== -1;
    }

    function add(key): void {
        if (!key || root.has(key) || root.allKeys.indexOf(key) === -1)
            return;
        root.controls = root.controls.concat([key]);
    }

    function remove(key): void {
        if (!root.has(key))
            return;
        root.controls = root.controls.filter((item) => item !== key);
    }

    // Reordena un control dentro de la barra. `target` es la posición final
    // una vez quitado el control que se arrastra (0 = primero).
    function move(key, target): void {
        const index = root.controls.indexOf(key);
        if (index === -1)
            return;
        const list = root.controls.slice();
        list.splice(index, 1);
        const position = Math.max(0, Math.min(list.length, target));
        list.splice(position, 0, key);
        if (list.join(",") === root.controls.join(","))
            return;
        root.controls = list;
    }

    // Reordena un control dentro de la cuadrícula del centro de control.
    // `target` se cuenta sobre las fichas visibles, no sobre `centerOrder`
    // (que también guarda el orden de los controles que están en la barra).
    // Se reconstruyen solo las posiciones de las fichas visibles para que un
    // arrastre hacia arriba o hacia la izquierda funcione igual que hacia el
    // otro lado, sin que los controles de la barra ocupen huecos intermedios.
    function moveCenter(key, target): void {
        const visible = root.centerControls;
        if (visible.indexOf(key) === -1)
            return;
        const ordered = visible.filter((item) => item !== key);
        const position = Math.max(0, Math.min(ordered.length, target));
        ordered.splice(position, 0, key);

        let nextIndex = 0;
        const next = root.centerOrder.map((item) => {
            if (visible.indexOf(item) === -1)
                return item;
            return ordered[nextIndex++];
        });
        while (nextIndex < ordered.length)
            next.push(ordered[nextIndex++]);

        if (next.join(",") === root.centerOrder.join(","))
            return;
        root.centerOrder = next;
    }

    function label(key): string {
        if (key === "music")
            return "Música";
        if (key === "wifi")
            return "Wi-Fi";
        if (key === "bluetooth")
            return "Bluetooth";
        if (key === "volume")
            return "Volumen";
        if (key === "mic")
            return "Micrófono";
        if (key === "night")
            return "Luz nocturna";
        if (key === "airplane")
            return "Modo avión";
        if (key === "brightness")
            return "Brillo";
        if (key === "extraDim")
            return "Atenuación extra";
        if (key === "hotspot")
            return "Punto de acceso";
        if (key === "vpn")
            return "VPN";
        if (key === "keyboard")
            return "Teclado en pantalla";
        if (key === "clipboard")
            return "Portapapeles";
        if (key === "cpu")
            return "Procesador";
        if (key === "gpu")
            return "Gráficos";
        if (key === "net")
            return "Red";
        if (key === "settings")
            return "Ajustes del shell";
        return key;
    }
}
