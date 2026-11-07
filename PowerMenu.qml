import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Menú de energía. Vive en su propia capa porque la barra solo mide 44 px y
// cualquier cosa anclada encima quedaría recortada.
PanelWindow {
    id: root

    visible: PowerState.open
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    anchors {
        top: !SettingsState.barVertical && SettingsState.barAtTop
        bottom: SettingsState.barVertical || !SettingsState.barAtTop
        left: SettingsState.barVertical && SettingsState.barAtLeft
        right: !SettingsState.barVertical || SettingsState.barAtRight
    }
    margins {
        top: SettingsState.barVertical ? 0
            : (SettingsState.barAtTop ? Theme.edge + Theme.barHeight + 8 : 0)
        bottom: SettingsState.barVertical ? Theme.edge
            : (SettingsState.barAtTop ? 0 : Theme.edge + Theme.barHeight + 8)
        left: SettingsState.barVertical && SettingsState.barAtLeft
            ? Theme.edge + Theme.barHeight + 8 : 0
        right: SettingsState.barVertical
            ? (SettingsState.barAtRight
                ? Theme.edge + Theme.barHeight + 8 : 0)
            : Theme.edge
    }
    implicitWidth: 184
    implicitHeight: menuColumn.implicitHeight + 16
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-power"
    WlrLayershell.keyboardFocus: PowerState.open && focusGate.ready
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    PanelFocusGate {
        id: focusGate
        active: PowerState.open
    }

    // El cierre de sesión lo resuelve cada backend: Hyprland con `hyprctl` y
    // Umbriel con su IPC. Antes se ejecutaba `hyprctl dispatch exit` siempre,
    // así que en Umbriel el botón no hacía nada.
    function run(action): void {
        PowerState.hide();
        if (action === "lock") {
            CompositorState.lockScreen();
            return;
        }
        if (action === "logout") {
            CompositorState.sessionQuit();
            return;
        }
        if (action === "reboot") {
            Quickshell.execDetached(["systemctl", "reboot"]);
            return;
        }
        if (action === "shutdown")
            Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            PowerState.toggle();
        }

        // Perfil de energía desde la terminal o un atajo:
        //   qs ipc -c shell call power profile rendimiento
        //   qs ipc -c shell call power profile ahorro
        function profile(value: string): void {
            PowerProfilesState.setProfile(value);
        }

        function status(): string {
            return PowerProfilesState.available
                ? PowerProfilesState.current : "";
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.glassPopover
        border.width: 1
        border.color: Theme.borderStrong

        Column {
            id: menuColumn
            anchors {
                fill: parent
                margins: 8
            }
            spacing: 2

            Repeater {
                model: [
                    { label: "Bloquear", action: "lock",
                        icon: "system-lock-screen", iconSource: ShellIcons.src("lock"),
                        color: Theme.accent },
                    { label: "Cerrar sesión", action: "logout",
                        icon: "system-log-out", iconSource: ShellIcons.src("logout"),
                        color: Theme.warning },
                    { label: "Reiniciar", action: "reboot",
                        icon: "system-reboot", iconSource: ShellIcons.src("restart"),
                        color: Theme.warning },
                    { label: "Apagar", action: "shutdown",
                        icon: "system-shutdown", iconSource: ShellIcons.src("power"),
                        color: Theme.danger }
                ]

                Rectangle {
                    id: item

                    required property var modelData

                    width: menuColumn.width
                    height: 32
                    radius: 8
                    color: itemMouse.containsMouse ? Theme.hover : "transparent"

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 8

                        ShellIcon {
                            name: item.modelData.icon
                            source: item.modelData.iconSource || ""
                            color: item.modelData.color
                            size: 15
                            fallback: "•"
                        }

                        Text {
                            Layout.fillWidth: true
                            text: item.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.run(item.modelData.action)
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: PowerState.open
        onActivated: PowerState.hide()
    }
}
