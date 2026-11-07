import Quickshell
import QtQuick
import QtQuick.Layouts

// Selector segmentado del tipo de desenfoque, con el mismo estilo que el
// selector de tema: dos píldoras dentro de un fondo oscuro. «Simple» muestra
// el contenido real que hay detrás; «Fondo» usa solo el fondo de pantalla.
Rectangle {
    id: root

    property bool behind: false
    property bool interactive: true

    signal selected(bool behind)

    implicitWidth: 150
    implicitHeight: 24
    radius: 7
    color: Theme.surfaceAlt
    border.width: 1
    border.color: Theme.border
    opacity: root.interactive ? 1 : 0.55

    RowLayout {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 2

        Repeater {
            model: [
                { key: true, label: "Simple", icon: "eye" },
                { key: false, label: "Fondo", icon: "wallpaper" }
            ]

            delegate: Rectangle {
                id: modeChip

                required property var modelData

                readonly property bool selected:
                    root.behind === modeChip.modelData.key

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 5
                color: modeChip.selected ? Theme.accent : "transparent"

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 3

                    ShellIcon {
                        source: ShellIcons.src(modeChip.modelData.icon)
                        color: modeChip.selected
                            ? Theme.accentInk : Theme.muted
                        size: 11
                    }

                    Text {
                        text: modeChip.modelData.label
                        color: modeChip.selected
                            ? Theme.accentInk : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.interactive
                    hoverEnabled: root.interactive
                    cursorShape: root.interactive
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.selected(modeChip.modelData.key)
                }
            }
        }
    }
}
