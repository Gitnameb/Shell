import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Elección inicial del modo de ventanas. Aparece una sola vez, cuando todavía
// no hay una preferencia guardada. Después se cambia por escritorio desde
// Ajustes → Modo de ventanas o desde la barra de Super.
PanelWindow {
    id: root

    visible: SettingsState.ready && !SettingsState.workspaceModeChosen
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: root.visible

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-welcome-mode"
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.light ? Qt.rgba(0.10, 0.11, 0.13, 0.28)
            : Qt.rgba(0.02, 0.02, 0.03, 0.58)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: Math.min(660, parent.width - 48)
            implicitHeight: cardColumn.implicitHeight + 44
            radius: 18
            color: Theme.surface
            border.width: 1
            border.color: Theme.borderStrong

            ColumnLayout {
                id: cardColumn

                anchors {
                    fill: parent
                    margins: 22
                }
                spacing: 14

                Text {
                    Layout.fillWidth: true
                    text: "Bienvenido"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }

                Text {
                    Layout.fillWidth: true
                    text: "¿Cómo quieres que se abran las ventanas?"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 21
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: "Puedes cambiarlo después para cada escritorio. "
                        + "Esta elección solo define el punto de partida."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Repeater {
                        model: [
                            {
                                key: "floating",
                                title: "Flotante",
                                subtitle: "Como Windows",
                                description: "Las ventanas se abren sueltas, "
                                    + "con barra de título y controles. "
                                    + "Ideal si vienes de Windows.",
                                icon: "window-duplicate-symbolic",
                                glyph: "❐"
                            },
                            {
                                key: "mosaic",
                                title: "Mosaico",
                                subtitle: "Tiling",
                                description: "Las ventanas se reparten solas "
                                    + "por la pantalla. Más orden y menos "
                                    + "movimientos de ratón.",
                                icon: "view-grid-symbolic",
                                glyph: "▦"
                            }
                        ]

                        delegate: Rectangle {
                            id: option

                            required property var modelData

                            readonly property bool recommended:
                                option.modelData.key === "floating"

                            Layout.fillWidth: true
                            Layout.preferredHeight: 226
                            radius: 13
                            color: hover.hovered ? Theme.accentGhost : Theme.surfaceAlt
                            border.width: hover.hovered ? 2 : 1
                            border.color: hover.hovered
                                ? Theme.accent : Theme.border

                            ColumnLayout {
                                anchors {
                                    fill: parent
                                    margins: 14
                                }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 38
                                        Layout.preferredHeight: 38
                                        radius: 10
                                        color: Theme.accentSoft
                                        border.width: 1
                                        border.color: Theme.accentLine

                                        ShellIcon {
                                            anchors.centerIn: parent
                                            name: option.modelData.icon
                                            color: Theme.accent
                                            size: 21
                                            fallback: option.modelData.glyph
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        Text {
                                            text: option.modelData.title
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            text: option.modelData.subtitle
                                            color: Theme.faint
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                        }
                                    }

                                    Rectangle {
                                        visible: option.recommended
                                        implicitWidth: recoLabel.implicitWidth + 12
                                        implicitHeight: 18
                                        radius: 9
                                        color: Theme.accent

                                        Text {
                                            id: recoLabel
                                            anchors.centerIn: parent
                                            text: "Recomendado"
                                            color: Theme.accentInk
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 8
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: option.modelData.description
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 8
                                    color: hover.hovered
                                        ? Theme.accent : Theme.surface
                                    border.width: 1
                                    border.color: hover.hovered
                                        ? Theme.accent : Theme.borderStrong

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Elegir " + option.modelData.title.toLowerCase()
                                        color: hover.hovered
                                            ? Theme.accentInk : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WorkspaceModeState.choose(
                                    option.modelData.key)
                            }
                        }
                    }
                }

                Rectangle {
                    // La barra de título la dibuja el compositor; no hay nada
                    // que configurar aquí.
                    visible: !CompositorState.supports("nativeTitlebar")
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                }

                RowLayout {
                    visible: !CompositorState.supports("nativeTitlebar")
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: "Barra de título"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    Row {
                        spacing: 2

                        Repeater {
                            model: [
                                { key: "auto", label: "Automática" },
                                { key: "always", label: "Siempre" },
                                { key: "never", label: "Nunca" }
                            ]

                            delegate: Rectangle {
                                id: titleChip

                                required property var modelData

                                readonly property bool selected:
                                    SettingsState.nativeTitlebar
                                        === titleChip.modelData.key

                                width: titleLabel.implicitWidth + 16
                                height: 24
                                radius: 6
                                color: titleChip.selected
                                    ? Theme.accent : "transparent"
                                border.width: titleChip.selected ? 0 : 1
                                border.color: Theme.border

                                Text {
                                    id: titleLabel
                                    anchors.centerIn: parent
                                    text: titleChip.modelData.label
                                    color: titleChip.selected
                                        ? Theme.accentInk : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: SettingsState.setNativeTitlebar(
                                        titleChip.modelData.key)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !CompositorState.supports("nativeTitlebar")
                    Layout.fillWidth: true
                    text: "Automática la muestra al mantener Super; Siempre la "
                        + "deja visible en ventanas flotantes; Nunca deja solo "
                        + "los controles de Super."
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
