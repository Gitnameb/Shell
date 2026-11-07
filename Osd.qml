import Quickshell
import Quickshell.Wayland
import QtQuick

// Aviso flotante sobre la barra. Muestra el volumen, el micrófono, el brillo,
// la atenuación extra o la luz nocturna y se oculta solo.
PanelWindow {
    id: root

    visible: OsdState.visible
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    anchors {
        top: SettingsState.barAtTop
        bottom: !SettingsState.barAtTop
        left: true
        right: true
    }
    margins.top: SettingsState.barAtTop ? Theme.edge + Theme.barHeight + 14 : 0
    margins.bottom: SettingsState.barAtTop ? 0 : Theme.edge + Theme.barHeight + 14
    implicitHeight: 46
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool mutedKind: (OsdState.kind === "volume"
        && OsdState.muted) || (OsdState.kind === "mic" && OsdState.muted)
    readonly property real shownValue: root.mutedKind ? 0 : OsdState.value

    readonly property string iconName: {
        if (OsdState.kind === "volume")
            return OsdState.muted ? "audio-volume-muted" : "audio-volume-high";
        if (OsdState.kind === "mic")
            return OsdState.muted
                ? "microphone-sensitivity-muted"
                : "microphone-sensitivity-high";
        return "";
    }
    readonly property string iconSource: {
        if (OsdState.kind === "brightness")
            return ShellIcons.src("sun");
        if (OsdState.kind === "extraDim")
            return ShellIcons.src("dim");
        if (OsdState.kind === "night")
            return ShellIcons.src("moon");
        return "";
    }
    readonly property color iconColor: {
        if (root.mutedKind)
            return Theme.danger;
        if (OsdState.kind === "night")
            return OsdState.value > 0.01 ? Theme.warm : Theme.muted;
        if (OsdState.kind === "brightness")
            return Theme.accent;
        if (OsdState.kind === "extraDim")
            return OsdState.value > 0.01 ? Theme.accent : Theme.muted;
        return Theme.accent;
    }

    Connections {
        target: Audio.audio

        function onVolumesChanged(): void {
            OsdState.showVolume(Audio.volume, Audio.muted);
        }

        function onMutedChanged(): void {
            OsdState.showVolume(Audio.volume, Audio.muted);
        }
    }

    Connections {
        target: Audio

        function onMicVolumeChanged(): void {
            OsdState.showMic(Audio.micVolume, Audio.micMuted);
        }

        function onMicMutedChanged(): void {
            OsdState.showMic(Audio.micVolume, Audio.micMuted);
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 300
        height: 46
        radius: 13
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderStrong

        Row {
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 12

            Item {
                width: 30
                height: parent.height

                // Mismo icono de nivel que la barra y el centro.
                LevelIcon {
                    anchors.centerIn: parent
                    visible: OsdState.kind === "volume" || OsdState.kind === "mic"
                    kind: OsdState.kind === "mic" ? "mic" : "volume"
                    level: root.shownValue
                    muted: root.mutedKind
                    color: root.iconColor
                    size: 18
                    fallback: OsdState.kind === "mic" ? "◉" : "◖"
                }

                ShellIcon {
                    anchors.centerIn: parent
                    visible: root.iconSource.length > 0
                    source: root.iconSource
                    color: root.iconColor
                    size: 18
                    fallback: "☀"
                }
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30 - 44 - 24
                height: 8

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Theme.surfaceAlt
                }

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.shownValue))
                    height: parent.height
                    radius: 4
                    color: root.mutedKind ? Theme.danger : root.iconColor
                    Behavior on width {
                        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.shownValue * 100) + "%"
                color: root.mutedKind ? Theme.danger : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }
}
