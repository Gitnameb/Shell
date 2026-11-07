import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Barra flotante del modo ventanas. Aparece al mantener Super o al fijar los
// controles desde el centro de control. Ofrece el modo del escritorio activo,
// las ventanas minimizadas y una salida clara cuando el modo está fijado.
PanelWindow {
    id: root

    readonly property var minimizedWindows: {
        const list = CompositorState.windows || [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].minimized === true)
                out.push(list[i]);
        }
        out.sort((a, b) => Number(a.originWorkspaceId || a.workspaceId)
            - Number(b.originWorkspaceId || b.workspaceId));
        return out;
    }
    readonly property var visibleMinimized: root.minimizedWindows.slice(0, 6)
    readonly property int hiddenMinimized:
        Math.max(0, root.minimizedWindows.length - root.visibleMinimized.length)
    readonly property int workspaceId: WorkspaceModeState.focusedWorkspaceId
    readonly property string mode: SettingsState.workspaceMode(root.workspaceId)

    visible: SuperState.active
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    anchors {
        top: !SettingsState.barVertical && SettingsState.barAtTop
        bottom: SettingsState.barVertical || !SettingsState.barAtTop
        left: true
        right: true
    }
    margins {
        top: SettingsState.barVertical ? 0
            : (SettingsState.barAtTop ? Theme.edge + Theme.barHeight + 12 : 0)
        bottom: SettingsState.barVertical ? Theme.edge + 12
            : (SettingsState.barAtTop ? 0 : Theme.edge + Theme.barHeight + 12)
        left: SettingsState.barVertical
            ? Theme.edge + Theme.barHeight + 12 : 0
        right: SettingsState.barVertical
            ? Theme.edge + Theme.barHeight + 12 : 0
    }
    implicitWidth: Math.min(Quickshell.screens.length > 0
        ? Quickshell.screens[0].width - 32 : 900, bar.implicitWidth + 24)
    implicitHeight: 46
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-window-mode"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: bar

        anchors.centerIn: parent
        implicitWidth: content.implicitWidth + 18
        implicitHeight: 42
        radius: 11
        color: Theme.glass
        border.width: 1
        border.color: Theme.borderStrong

        RowLayout {
            id: content

            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "Escritorio " + root.workspaceId
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: Theme.border
            }

            Row {
                spacing: 2

                Repeater {
                    model: [
                        { key: "floating", label: "Flotante" },
                        { key: "mosaic", label: "Mosaico" }
                    ]

                    delegate: Rectangle {
                        id: modeChip

                        required property var modelData

                        readonly property bool selected:
                            root.mode === modeChip.modelData.key

                        width: modeLabel.implicitWidth + 18
                        height: 26
                        radius: 7
                        color: modeChip.selected
                            ? Theme.accent : (modeHover.containsMouse
                                ? Theme.hover : "transparent")
                        border.width: modeChip.selected ? 0 : 1
                        border.color: Theme.border

                        Text {
                            id: modeLabel
                            anchors.centerIn: parent
                            text: modeChip.modelData.label
                            color: modeChip.selected
                                ? Theme.accentInk : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: modeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: WorkspaceModeState.setMode(
                                root.workspaceId, modeChip.modelData.key)
                        }
                    }
                }
            }

            Rectangle {
                visible: root.minimizedWindows.length > 0
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: Theme.border
            }

            Row {
                spacing: 3

                Repeater {
                    model: root.visibleMinimized

                    delegate: Rectangle {
                        id: minChip

                        required property var modelData

                        readonly property color appColor:
                            WindowLook.colorFor(String(minChip.modelData.appId
                                || minChip.modelData.class || ""))

                        width: Math.min(132, 16 + 4
                            + Math.min(90, minText.implicitWidth) + 12)
                        height: 26
                        radius: 7
                        color: minHover.containsMouse
                            ? Theme.hover : WindowLook.tintFor(minChip.appColor)
                        border.width: 1
                        border.color: minHover.containsMouse
                            ? Theme.accentLine : "transparent"

                        Image {
                            id: minIcon
                            anchors {
                                left: parent.left
                                leftMargin: 5
                                verticalCenter: parent.verticalCenter
                            }
                            width: 16
                            height: 16
                            source: WindowLook.iconFor(String(
                                minChip.modelData.appId
                                || minChip.modelData.class || ""))
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: status === Image.Ready
                        }

                        Text {
                            id: minText

                            anchors {
                                left: minIcon.right
                                leftMargin: 4
                                right: parent.right
                                rightMargin: 6
                                verticalCenter: parent.verticalCenter
                            }
                            text: String(minChip.modelData.title || "").length > 0
                                ? String(minChip.modelData.title)
                                : WindowLook.nameFor(String(minChip.modelData.appId
                                    || minChip.modelData.class || ""))
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            elide: Text.ElideRight
                            width: 74
                        }

                        MouseArea {
                            id: minHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: CompositorState.restoreWindow(
                                minChip.modelData.address)
                        }
                    }
                }

                Text {
                    visible: root.hiddenMinimized > 0
                    text: "+" + root.hiddenMinimized
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                visible: SuperState.pinned
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: Theme.border
            }

            Rectangle {
                visible: SuperState.pinned
                width: exitLabel.implicitWidth + 18
                height: 26
                radius: 7
                color: exitHover.containsMouse ? Theme.hover : "transparent"

                Text {
                    id: exitLabel
                    anchors.centerIn: parent
                    text: "Salir"
                    color: exitHover.containsMouse
                        ? Theme.text : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: exitHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SuperState.hide()
                }
            }
        }
    }
}
