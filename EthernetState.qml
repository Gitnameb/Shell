pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Diagnóstico de solo lectura: muestra quién controla cada Ethernet
// (NetworkManager, ifupdown o dhcpcd). La reparación del control heredado se
// hace ejecutando `sudo ./scripts/network.sh`, no desde el shell.
Singleton {
    id: root

    property string interfaceName: ""
    property string controlLabel: ""
    // Control por interfaz para poder enseñar varias Ethernet a la vez
    // (por ejemplo, la del equipo y la de un móvil compartiendo por USB).
    property var labels: ({})
    property string pendingInterface: ""
    property var queue: []

    readonly property string statusScript: (Quickshell.shellDir || "")
        + "/scripts/ethernet-control.sh"

    function parseControl(text): string {
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const sep = line.indexOf("=");
            if (sep <= 0)
                continue;
            if (line.slice(0, sep) === "control")
                return line.slice(sep + 1);
        }
        return "";
    }

    function labelFor(iface): string {
        return root.labels[String(iface || "")] || "";
    }

    function refresh(iface): void {
        const name = String(iface || "");
        if (name.length === 0)
            return;
        if (root.queue.indexOf(name) === -1
                && name !== root.pendingInterface)
            root.queue.push(name);
        root.runNext();
    }

    function runNext(): void {
        if (statusProc.running || root.queue.length === 0)
            return;
        const name = root.queue.shift();
        root.pendingInterface = name;
        root.interfaceName = name;
        statusProc.command = [root.statusScript, "status", name];
        statusProc.running = true;
    }

    function storeLabel(iface, label): void {
        const copy = Object.assign({}, root.labels);
        copy[String(iface)] = String(label);
        root.labels = copy;
    }

    Process {
        id: statusProc

        command: [root.statusScript, "status", root.interfaceName]

        stdout: StdioCollector {
            id: statusOut
        }

        onExited: (code) => {
            const iface = root.pendingInterface;
            if (code !== 0) {
                root.storeLabel(iface, "");
                if (root.interfaceName === iface)
                    root.controlLabel = "";
            } else {
                const control = root.parseControl(statusOut.text);
                root.storeLabel(iface, control);
                if (root.interfaceName === iface)
                    root.controlLabel = control;
            }
            root.pendingInterface = "";
            root.runNext();
        }
    }
}
