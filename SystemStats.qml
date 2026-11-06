pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Estadísticas reales del sistema para los widgets de CPU, GPU y red.
// `stats.py` imprime una línea JSON por segundo; aquí solo se acumulan los
// totales, los picos y el historial que dibujan las vistas avanzadas.
Singleton {
    id: root

    readonly property string statsPath: (Quickshell.shellDir || "")
        + "/stats.py"

    property real cpuLoad: 0
    property real cpuTemp: -1
    property real cpuFreq: 0
    property real cpuMaxFreq: 0
    property var cpuCores: []
    property var cpuHistory: []
    property real cpuPeakLoad: 0
    property real cpuPeakTemp: 0

    property real gpuLoad: 0
    property real gpuTemp: -1
    property real gpuFreq: 0
    property real gpuMaxFreq: 0
    property real gpuPower: -1
    property real vramUsed: 0
    property real vramTotal: 0
    property var gpuHistory: []
    property real gpuPeakLoad: 0
    property real gpuPeakTemp: 0

    property real netDown: 0
    property real netUp: 0
    property real netSessionDown: 0
    property real netSessionUp: 0
    property real netPeakDown: 0
    property real netPeakUp: 0
    property int netLatency: -1
    property string netInterface: ""
    property string netIp: ""
    property string netKind: "none"
    property var netHistoryDown: []
    property var netHistoryUp: []

    property bool hasSample: false
    property int sampleCount: 0

    readonly property int historyLength: 32
    readonly property bool cpuAvailable: root.cpuTemp >= 0
    readonly property bool gpuAvailable: root.gpuTemp >= 0
        || root.gpuFreq > 0
    readonly property bool networkAvailable: root.netInterface.length > 0

    readonly property real cpuAverage: {
        if (root.cpuHistory.length === 0)
            return 0;
        let sum = 0;
        for (let i = 0; i < root.cpuHistory.length; i++)
            sum += root.cpuHistory[i];
        return sum / root.cpuHistory.length;
    }

    readonly property real gpuAverage: {
        if (root.gpuHistory.length === 0)
            return 0;
        let sum = 0;
        for (let i = 0; i < root.gpuHistory.length; i++)
            sum += root.gpuHistory[i];
        return sum / root.gpuHistory.length;
    }

    function pushHistory(list, value): var {
        const out = list.slice();
        out.push(value);
        while (out.length > root.historyLength)
            out.shift();
        return out;
    }

    function applySample(data): void {
        const dt = Number(data.dt) > 0 ? Number(data.dt) : 1;
        const cpu = Number(data.cpu) || 0;
        const gpu = Number(data.gpu) || 0;
        const down = Number(data.down) || 0;
        const up = Number(data.up) || 0;

        root.cpuLoad = cpu;
        root.cpuTemp = data.temp === null ? -1 : Number(data.temp);
        root.cpuFreq = Number(data.freq) || 0;
        root.cpuMaxFreq = Number(data.maxfreq) || 0;
        root.cpuCores = data.cores || [];
        root.cpuHistory = root.pushHistory(root.cpuHistory, cpu);
        root.cpuPeakLoad = Math.max(root.cpuPeakLoad, cpu);
        if (root.cpuTemp >= 0)
            root.cpuPeakTemp = Math.max(root.cpuPeakTemp, root.cpuTemp);

        root.gpuLoad = gpu;
        root.gpuTemp = data.gtemp === null ? -1 : Number(data.gtemp);
        root.gpuFreq = Number(data.gfreq) || 0;
        root.gpuMaxFreq = Number(data.gmaxfreq) || 0;
        root.gpuPower = data.gpower === null ? -1 : Number(data.gpower);
        root.vramUsed = Number(data.vram) || 0;
        root.vramTotal = Number(data.vramtotal) || 0;
        root.gpuHistory = root.pushHistory(root.gpuHistory, gpu);
        root.gpuPeakLoad = Math.max(root.gpuPeakLoad, gpu);
        if (root.gpuTemp >= 0)
            root.gpuPeakTemp = Math.max(root.gpuPeakTemp, root.gpuTemp);

        root.netDown = down;
        root.netUp = up;
        root.netSessionDown += down * dt;
        root.netSessionUp += up * dt;
        root.netPeakDown = Math.max(root.netPeakDown, down);
        root.netPeakUp = Math.max(root.netPeakUp, up);
        root.netHistoryDown = root.pushHistory(root.netHistoryDown, down);
        root.netHistoryUp = root.pushHistory(root.netHistoryUp, up);
        root.netLatency = Number(data.lat);
        root.netInterface = data.iface || "";
        root.netIp = data.ip || "";
        root.netKind = data.kind || "none";

        root.hasSample = true;
        root.sampleCount += 1;
    }

    function resetPerf(kind: string): void {
        if (kind === "gpu") {
            root.gpuPeakLoad = root.gpuLoad;
            root.gpuPeakTemp = Math.max(0, root.gpuTemp);
            root.gpuHistory = [];
        } else {
            root.cpuPeakLoad = root.cpuLoad;
            root.cpuPeakTemp = Math.max(0, root.cpuTemp);
            root.cpuHistory = [];
        }
    }

    function resetNet(): void {
        root.netSessionDown = 0;
        root.netSessionUp = 0;
        root.netPeakDown = root.netDown;
        root.netPeakUp = root.netUp;
        root.netHistoryDown = [];
        root.netHistoryUp = [];
    }

    function thermalLevel(temp: real): string {
        if (temp < 0)
            return "none";
        if (temp >= 85)
            return "critical";
        if (temp >= 75)
            return "hot";
        if (temp >= 60)
            return "warm";
        return "normal";
    }

    function thermalColor(temp: real): color {
        const level = root.thermalLevel(temp);
        if (level === "critical")
            return Theme.danger;
        if (level === "hot")
            return Theme.warm;
        if (level === "warm")
            return Theme.warning;
        return Theme.accent;
    }

    function thermalLabel(temp: real): string {
        const level = root.thermalLevel(temp);
        if (level === "critical")
            return "crítica";
        if (level === "hot")
            return "caliente";
        if (level === "warm")
            return "templada";
        return "normal";
    }

    function formatBytes(value: real): string {
        if (value >= 1073741824)
            return (value / 1073741824).toFixed(1).replace(".", ",") + " GB";
        if (value >= 1048576)
            return (value / 1048576).toFixed(1).replace(".", ",") + " MB";
        if (value >= 1024)
            return Math.round(value / 1024) + " KB";
        return Math.round(value) + " B";
    }

    function formatRate(value: real): string {
        return root.formatBytes(value) + "/s";
    }

    function formatRateShort(value: real): string {
        if (value >= 1048576)
            return (value / 1048576).toFixed(1).replace(".", ",") + "M";
        if (value >= 1024)
            return Math.round(value / 1024) + "K";
        return Math.round(value) + "B";
    }

    function formatFrequency(mhz: real): string {
        if (mhz <= 0)
            return "—";
        if (mhz >= 1000)
            return (mhz / 1000).toFixed(1).replace(".", ",") + " GHz";
        return Math.round(mhz) + " MHz";
    }

    function formatVram(): string {
        if (root.vramTotal <= 0)
            return "—";
        return (root.vramUsed / 1073741824).toFixed(1).replace(".", ",")
            + " / " + (root.vramTotal / 1073741824).toFixed(0) + " GB";
    }

    function networkKindLabel(): string {
        if (root.netKind === "wifi")
            return "Wi-Fi";
        if (root.netKind === "wired")
            return "Cable";
        if (root.netKind === "vpn")
            return "VPN";
        return "Sin conexión";
    }

    Process {
        id: statsProc

        command: ["python3", "-u", root.statsPath,
            "" + Quickshell.processId]
        running: true

        stdout: SplitParser {
            onRead: (line) => {
                if (!line || line.length === 0)
                    return;
                try {
                    root.applySample(JSON.parse(line));
                } catch (error) {
                    // Una línea incompleta no debe romper el muestreo.
                }
            }
        }

        onExited: restartTimer.restart()
    }

    Timer {
        id: restartTimer

        interval: 1500
        repeat: false
        onTriggered: {
            if (!statsProc.running)
                statsProc.running = true;
        }
    }
}
