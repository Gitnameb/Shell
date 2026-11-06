import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Panel que cuelga del icono de batería. Reproduce la tarjeta de opciones del
// ejemplo web: estado de la batería, y los perfiles de energía como filas con
// icono, descripción y estado seleccionado.
PanelWindow {
    id: root

    visible: BatteryState.open
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    anchors {
        top: SettingsState.barAtTop
        bottom: !SettingsState.barAtTop
        left: true
    }
    margins {
        top: SettingsState.barAtTop ? Theme.edge + Theme.barHeight + 8 : 0
        bottom: SettingsState.barAtTop ? 0 : Theme.edge + Theme.barHeight + 8
        left: Math.max(Theme.edge, Math.min(
            (screen ? screen.width : 1280) - root.implicitWidth - Theme.edge,
            (BatteryState.anchorX > 0
                ? BatteryState.anchorX
                : (screen ? screen.width - 260 : 1000)) - root.implicitWidth / 2))
    }
    implicitWidth: 236
    implicitHeight: content.implicitHeight + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "alba-battery"
    WlrLayershell.keyboardFocus: BatteryState.open && focusGate.ready
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    PanelFocusGate {
        id: focusGate
        active: BatteryState.open
    }

    IpcHandler {
        target: "battery"

        function openPanel(): void {
            BatteryState.show();
        }

        function toggle(): void {
            BatteryState.toggle();
        }

        function closePanel(): void {
            BatteryState.hide();
        }

        function profile(value: string): void {
            PowerProfilesState.setProfile(value);
        }

        function status(): string {
            return "present=" + (BatteryState.present ? "1" : "0")
                + " level=" + BatteryState.level
                + " charging=" + (BatteryState.charging ? "1" : "0")
                + " profile=" + PowerProfilesState.current
                + " open=" + (BatteryState.open ? "1" : "0");
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderStrong

        ColumnLayout {
            id: content

            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            // ------------------------------------------------------ cabecera
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: BatteryState.present ? "Batería" : "Energía"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 7
                    color: closeMouse.containsMouse ? Theme.hover : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    AlbaIcon {
                        anchors.centerIn: parent
                        name: "window-close"
                        color: closeMouse.containsMouse
                            ? Theme.text : Theme.muted
                        size: 12
                        fallback: "×"
                    }

                    MouseArea {
                        id: closeMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BatteryState.hide()
                    }
                }
            }

            // -------------------------------------------------------- estado
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                BatteryGlyph {
                    iconSize: 20
                    percentage: BatteryState.level
                    present: BatteryState.present
                    charging: BatteryState.charging
                    mains: BatteryState.mains
                    tone: BatteryState.tone
                }

                Text {
                    Layout.fillWidth: true
                    text: BatteryState.statusText
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // -------------------------------------------------------- perfiles
            Repeater {
                model: PowerProfilesState.menuProfiles

                delegate: Rectangle {
                    id: option

                    required property var modelData

                    readonly property bool selected:
                        PowerProfilesState.current === option.modelData

                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: 9
                    color: option.selected
                        ? Theme.accentSoft
                        : (optionMouse.containsMouse
                            ? Theme.hover
                            : (Theme.light
                                ? Qt.rgba(0, 0, 0, 0.025)
                                : Qt.rgba(1, 1, 1, 0.025)))
                    border.width: 1
                    border.color: option.selected
                        ? Theme.accentLine
                        : (optionMouse.containsMouse
                            ? Theme.borderStrong : Theme.border)
                    opacity: PowerProfilesState.busy ? 0.6 : 1

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: 120 }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 9

                        AlbaIcon {
                            source: AlbaIcons.src(
                                PowerProfilesState.iconName(option.modelData))
                            color: option.selected
                                ? Theme.accent
                                : (optionMouse.containsMouse
                                    ? Theme.text : Theme.muted)
                            size: 15
                            fallback: "•"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: PowerProfilesState.label(option.modelData)
                                color: option.selected
                                    ? Theme.accent
                                    : (optionMouse.containsMouse
                                        ? Theme.text : Theme.muted)
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: PowerProfilesState.description(
                                    option.modelData)
                                color: option.selected
                                    ? Theme.accent : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: optionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !PowerProfilesState.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfilesState.setProfile(option.modelData)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: PowerProfilesState.loaded
                    && !PowerProfilesState.ready
                    && PowerProfilesState.error.length === 0
                text: "Los perfiles de energía no están disponibles en este equipo."
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 9
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: PowerProfilesState.loaded
                    && PowerProfilesState.error.length > 0
                text: PowerProfilesState.error
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: 9
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: !PowerProfilesState.loaded
                text: "Leyendo los perfiles del sistema…"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: BatteryState.open
        onActivated: BatteryState.hide()
    }
}
