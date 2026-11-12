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
    // Último reproductor que estaba sonando. Cuando todos se pausan, evita
    // que el widget salte a otro reproductor solo porque aparece antes en la
    // lista de MPRIS (por ejemplo, una pestaña del navegador en pausa).
    property var lastPlayingPlayer: null

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
        // Nadie suena: conservar el reproductor que sonaba antes de pausar.
        if (playing.length === 0 && root.lastPlayingPlayer
                && list.indexOf(root.lastPlayingPlayer) !== -1)
            return root.lastPlayingPlayer;
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
    // Ruta del archivo que suena, cuando el reproductor la publica. MPRIS no
    // transporta letras, pero sí la URL del archivo; con ella LyricsState lee
    // el tag incrustado. Los servicios en streaming no la exponen.
    readonly property string trackUrl: {
        if (!root.player)
            return "";
        const metadata = root.player.metadata;
        if (!metadata)
            return "";
        const value = metadata["xesam:url"];
        return value ? String(value) : "";
    }
    readonly property real length: root.player
        && root.player.length > 0 ? root.player.length : 0
    // Position de MPRIS tal como la notifica el reproductor. Solo cambia en
    // saltos no lineales (buscar, cambiar de pista); no sirve para avanzar la
    // barra segundo a segundo.
    readonly property real reportedPosition: root.player
        && root.player.position > 0 ? root.player.position : 0

    // La barra avanza con un reloj local y se resincroniza con la posición
    // real del reproductor: al buscar (MPRIS emite positionChanged), al
    // cambiar de pista y cada pocos segundos para corregir la deriva. Leer
    // `position` devuelve siempre el valor actual aunque Quickshell no emita
    // cambios cada segundo.
    property real displayPosition: 0
    property double lastTickMs: 0
    // Última lectura del reproductor y si su Position avanza de verdad.
    // Algunos reproductores (Firefox) la dejan congelada mientras suena; en
    // ese caso manda el reloj local y no se corrige hacia atrás.
    property real lastPolledPosition: -1
    property bool playerPositionLive: false
    property int positionPollTick: 0

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

    // Posición actual del reproductor, o -1 si no la expone.
    function currentPlayerPosition(): real {
        if (!root.player)
            return -1;
        const value = root.player.position;
        return (isFinite(value) && value >= 0) ? value : -1;
    }

    function adoptPosition(seconds: real): void {
        if (!isFinite(seconds) || seconds < 0)
            return;
        root.displayPosition = root.length > 0
            ? Math.min(root.length, seconds) : seconds;
        root.lastTickMs = Date.now();
    }

    function resetPosition(): void {
        const actual = root.currentPlayerPosition();
        root.displayPosition = actual > 0 ? actual : 0;
        if (root.length > 0)
            root.displayPosition = Math.min(root.length, root.displayPosition);
        root.lastTickMs = Date.now();
        root.lastPolledPosition = actual;
        root.playerPositionLive = false;
        root.positionPollTick = 0;
    }

    // Contrasta el reloj local con la posición real. Solo corrige cuando el
    // reproductor demuestra que actualiza Position y la diferencia ya se nota,
    // para no dar saltos atrás con los que la dejan congelada.
    function pollPlayerPosition(): void {
        const actual = root.currentPlayerPosition();
        if (actual < 0)
            return;
        if (root.lastPolledPosition >= 0
                && Math.abs(actual - root.lastPolledPosition) > 0.05)
            root.playerPositionLive = true;
        root.lastPolledPosition = actual;
        if (root.playerPositionLive
                && Math.abs(actual - root.displayPosition) > 1.5)
            root.adoptPosition(actual);
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

    onPlayerChanged: {
        root.resetPosition();
        if (root.player && root.player.isPlaying)
            root.lastPlayingPlayer = root.player;
    }
    onTitleChanged: root.resetPosition()
    onPlayingChanged: {
        if (root.playing) {
            root.lastPlayingPlayer = root.player;
            root.lastTickMs = Date.now();
            root.positionPollTick = 0;
        }
    }

    // Un salto no lineal en MPRIS (buscar en la app de origen, cambiar de
    // pista) sí emite positionChanged: se adopta en el acto.
    onReportedPositionChanged: {
        const actual = root.currentPlayerPosition();
        if (actual >= 0 && Math.abs(actual - root.displayPosition) > 0.75)
            root.adoptPosition(actual);
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
            const rate = root.player.rate > 0 ? root.player.rate : 1;
            if (root.length > 0)
                root.displayPosition = Math.min(root.length,
                    root.displayPosition + elapsed * rate);
            else
                root.displayPosition += elapsed * rate;

            // Cada 2 s, contrasta con la posición real del reproductor.
            root.positionPollTick++;
            if (root.positionPollTick >= 4) {
                root.positionPollTick = 0;
                root.pollPlayerPosition();
            }
        }
    }
}
