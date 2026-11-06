pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Reproductor MPRIS activo. Prefiere el que está sonando; si hay varios,
// permite elegir uno desde la vista de Música. Los controles son opcionales:
// cada botón se desactiva si el reproductor no los soporta.
Singleton {
    id: root

    property var preferredPlayer: null

    readonly property var players: Mpris.players.values
    // Prefiere al reproductor que está sonando y, entre varios, al que expone
    // portada y artista. Firefox publica un MPRIS nativo sin carátula mientras
    // plasma-browser-integration publica el mismo tema con metadatos completos.
    readonly property var player: {
        const list = Mpris.players.values;
        if (root.preferredPlayer && list.indexOf(root.preferredPlayer) !== -1)
            return root.preferredPlayer;
        if (list.length === 0)
            return null;
        const playing = list.filter((item) => item.isPlaying);
        const pool = playing.length > 0 ? playing : list;
        for (let i = 0; i < pool.length; i++) {
            if ((pool[i].trackArtUrl || "").length > 0
                    && root.artistFor(pool[i]).length > 0)
                return pool[i];
        }
        for (let i = 0; i < pool.length; i++) {
            if ((pool[i].trackArtUrl || "").length > 0)
                return pool[i];
        }
        for (let i = 0; i < pool.length; i++) {
            if (root.artistFor(pool[i]).length > 0)
                return pool[i];
        }
        return pool[0];
    }

    // `trackArtist` suele ser una cadena y `trackArtists` una lista; se
    // normalizan para que el widget nunca muestre «[object Object]».
    function artistFor(target): string {
        if (!target)
            return "";
        if ((target.trackArtist || "").length > 0)
            return target.trackArtist;
        const list = target.trackArtists;
        if (Array.isArray(list))
            return list.join(", ");
        return list ? String(list) : "";
    }

    readonly property bool available: root.player !== null
    readonly property bool playing: root.player !== null
        && root.player.isPlaying
    readonly property string title: root.player
        && (root.player.trackTitle || "").length > 0
        ? root.player.trackTitle : "Sin reproducción"
    readonly property string artist: root.artistFor(root.player).length > 0
        ? root.artistFor(root.player) : "Artista desconocido"
    readonly property string album: root.player
        && root.player.trackAlbum ? root.player.trackAlbum : ""
    readonly property string identity: root.player
        ? root.player.identity : ""
    readonly property string artUrl: root.player
        && root.player.trackArtUrl ? root.player.trackArtUrl : ""
    readonly property real length: root.player
        && root.player.length > 0 ? root.player.length : 0
    readonly property real reportedPosition: root.player
        && root.player.position > 0 ? root.player.position : 0

    // La posición MPRIS no siempre emite cambios (Firefox, por ejemplo, no
    // actualiza Position). Se avanza localmente mientras suena y se resincroniza
    // al cambiar de pista o al buscar.
    property real displayPosition: 0
    property double lastTickMs: 0
    readonly property real position: root.displayPosition
    readonly property bool canGoNext: root.player !== null
        && root.player.canGoNext
    readonly property bool canGoPrevious: root.player !== null
        && root.player.canGoPrevious
    readonly property bool canSeek: root.player !== null
        && root.player.canSeek && root.length > 0
    readonly property bool canSetVolume: root.player !== null
        && root.player.volumeSupported

    function select(target): void {
        root.preferredPlayer = target;
        root.resetPosition();
    }

    function resetPosition(): void {
        root.displayPosition = root.reportedPosition;
        root.lastTickMs = Date.now();
    }

    function toggle(): void {
        if (!root.player)
            return;
        if (root.player.canTogglePlaying)
            root.player.togglePlaying();
        else if (root.playing)
            root.player.pause();
        else
            root.player.play();
    }

    function next(): void {
        if (root.player && root.player.canGoNext)
            root.player.next();
    }

    function previous(): void {
        if (root.player && root.player.canGoPrevious)
            root.player.previous();
    }

    function seek(seconds: real): void {
        if (!root.player || !root.player.canSeek)
            return;
        const target = Math.max(0, Math.min(root.length, seconds));
        root.displayPosition = target;
        root.lastTickMs = Date.now();
        root.player.position = target;
    }

    function seekFraction(fraction: real): void {
        if (!root.canSeek)
            return;
        root.seek(Math.max(0, Math.min(1, fraction)) * root.length);
    }

    function setVolume(value: real): void {
        if (!root.player || !root.player.volumeSupported)
            return;
        root.player.volume = Math.max(0, Math.min(1, value));
    }

    function timeLabel(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0)
            seconds = 0;
        const total = Math.floor(seconds);
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return minutes + ":" + String(rest).padStart(2, "0");
    }

    onPlayerChanged: root.resetPosition()
    onTitleChanged: root.resetPosition()
    onPlayingChanged: {
        if (root.playing)
            root.lastTickMs = Date.now();
    }

    // Inicializa la posición cuando el singleton arranca con un reproductor ya
    // presente (los singletons no tienen Component.onCompleted fiable).
    Timer {
        interval: 300
        running: true
        repeat: false
        onTriggered: root.resetPosition()
    }

    Timer {
        interval: 500
        repeat: true
        running: root.playing

        onTriggered: {
            if (!root.player)
                return;
            const now = Date.now();
            const elapsed = (now - root.lastTickMs) / 1000;
            root.lastTickMs = now;
            if (root.length > 0)
                root.displayPosition = Math.min(root.length,
                    root.displayPosition + elapsed);
            else
                root.displayPosition += elapsed;
        }
    }
}
