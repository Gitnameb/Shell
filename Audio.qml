pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire

// Estado compartido del audio. Mantiene vivos todos los nodos de salida y
// entrada para que el panel pueda listarlos y cambiar el dispositivo
// predeterminado sin perder las notificaciones de volumen y silencio.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var audio: sink && sink.ready ? sink.audio : null
    readonly property var mic: source && source.ready ? source.audio : null
    readonly property bool available: audio !== null
    readonly property bool micAvailable: mic !== null
    readonly property bool muted: audio ? audio.muted : false
    readonly property bool micMuted: mic ? mic.muted : false
    readonly property real volume: audio ? audio.volume : 0
    readonly property real micVolume: mic ? mic.volume : 0

    // Nodos físicos, sin flujos de aplicaciones ni monitores de salida.
    readonly property var sinks: {
        const list = Pipewire.nodes.values.filter(
            (node) => node.isSink && !node.isStream && node.audio !== null);
        list.sort((a, b) => a.description.localeCompare(b.description));
        return list;
    }

    readonly property var sources: {
        const list = Pipewire.nodes.values.filter(
            (node) => !node.isSink && !node.isStream && node.audio !== null
                && String(node.name).indexOf(".monitor") === -1);
        list.sort((a, b) => a.description.localeCompare(b.description));
        return list;
    }

    // Flujos de aplicaciones (no dispositivos): una entrada por reproducción.
    readonly property var streams: {
        const list = Pipewire.nodes.values.filter(
            (node) => node.isStream && node.audio !== null);
        list.sort((a, b) => streamName(a).localeCompare(streamName(b)));
        return list;
    }

    function streamName(node): string {
        if (!node)
            return "";
        const props = node.properties || ({});
        return String(props["application.name"] || props["media.name"]
            || node.description || node.nickname || node.name || "Aplicación");
    }

    function streamDetail(node): string {
        if (!node)
            return "";
        const props = node.properties || ({});
        return String(props["media.name"] || props["application.process.binary"] || "");
    }

    function setNodeVolume(node, value): void {
        if (node && node.audio)
            node.audio.volume = Math.max(0, Math.min(1, value));
    }

    function setNodeMuted(node, muted): void {
        if (node && node.audio)
            node.audio.muted = muted;
    }

    function toggleNodeMute(node): void {
        if (node && node.audio)
            node.audio.muted = !node.audio.muted;
    }

    function nodeName(node): string {
        if (!node)
            return "";
        return node.description || node.nickname || node.name;
    }

    function setVolume(value): void {
        if (audio)
            audio.volume = Math.max(0, Math.min(1, value));
    }

    function adjust(delta): void {
        if (audio)
            setVolume(audio.volume + delta);
    }

    function toggleMute(): void {
        if (audio)
            audio.muted = !audio.muted;
    }

    function setMicVolume(value): void {
        if (mic)
            mic.volume = Math.max(0, Math.min(1, value));
    }

    function adjustMic(delta): void {
        if (mic)
            setMicVolume(mic.volume + delta);
    }

    function toggleMicMute(): void {
        if (mic)
            mic.muted = !mic.muted;
    }

    function setDefaultSink(node): void {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node): void {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    PwObjectTracker {
        objects: root.sinks.concat(root.sources).concat(root.streams)
    }
}
