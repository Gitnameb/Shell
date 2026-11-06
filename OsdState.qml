pragma Singleton

import Quickshell
import QtQuick

// Estado del aviso flotante que aparece encima de la barra al cambiar el
// volumen, el micrófono, el brillo, la atenuación extra o la luz nocturna.
Singleton {
    id: root

    property bool visible: false
    property real value: 0
    property bool muted: false
    // "volume", "mic", "brightness", "extraDim" o "night".
    property string kind: "volume"
    property string label: "Volumen"

    function showVolume(volume, isMuted): void {
        value = volume;
        muted = isMuted;
        kind = "volume";
        label = "Volumen";
        visible = true;
        hideTimer.restart();
    }

    function showMic(volume, isMuted): void {
        value = volume;
        muted = isMuted;
        kind = "mic";
        label = "Micrófono";
        visible = true;
        hideTimer.restart();
    }

    function showBrightness(level): void {
        value = level;
        muted = false;
        kind = "brightness";
        label = "Brillo";
        visible = true;
        hideTimer.restart();
    }

    function showExtraDim(level): void {
        value = level;
        muted = false;
        kind = "extraDim";
        label = "Atenuación extra";
        visible = true;
        hideTimer.restart();
    }

    function showNight(level): void {
        value = level;
        muted = false;
        kind = "night";
        label = "Luz nocturna";
        visible = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.visible = false
    }
}
