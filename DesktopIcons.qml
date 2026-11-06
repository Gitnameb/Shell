import Quickshell
import Quickshell.Wayland
import QtQuick

// Iconos del escritorio real, en una capa por debajo de las ventanas.
// Fase 1: cuadricula, seleccion con un clic y apertura con doble clic.
Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        id: desktop

        required property var modelData

        screen: modelData
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "alba-desktop-icons"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: DesktopState.selectedIndex = -1
            onPressed: DesktopState.selectedIndex = -1
        }

        // Acepta archivos arrastrados desde Dolphin u otro gestor. Se colocan
        // en ~/Desktop; el script decide mover o copiar y evita pisar nombres.
        DropArea {
            anchors.fill: parent

            onDropped: (drop) => {
                if (!drop.hasUrls) {
                    drop.ignore();
                    return;
                }
                DesktopState.dropUrls(drop.urls);
                drop.acceptProposedAction();
            }
        }

        GridView {
            id: grid

            anchors {
                top: parent.top
                left: parent.left
                margins: 26
            }
            width: parent.width - 52
            height: parent.height - 52
            cellWidth: 96
            cellHeight: 102
            flow: GridView.TopToBottom
            interactive: false
            clip: true
            model: DesktopState.model

            delegate: Item {
                id: cell

                required property int index
                required property string fileName
                required property string filePath
                required property var fileURL
                required property bool fileIsDir

                readonly property bool selected: DesktopState.selectedIndex === index
                readonly property bool isDesktop: DesktopState.isDesktopFile(fileName)
                readonly property string preview:
                    DesktopState.previewSource(fileName, fileURL, fileIsDir)
                readonly property var entry: isDesktop
                    ? DesktopState.entryFor(fileName) : null

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: 10
                    color: cell.selected
                        ? Theme.accentSoft
                        : (hover.hovered ? Theme.hover : "transparent")
                    border.width: cell.selected ? 1 : 0
                    border.color: Theme.accentLine
                }

                Rectangle {
                    id: iconBox

                    anchors {
                        top: parent.top
                        topMargin: 8
                        horizontalCenter: parent.horizontalCenter
                    }
                    width: 48
                    height: 48
                    radius: 9
                    color: Qt.rgba(0, 0, 0, 0.16)
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: cell.preview.length > 0 ? 0 : 7
                        source: cell.preview.length > 0
                            ? cell.preview
                            : DesktopState.iconSource(cell.fileName, cell.fileIsDir)
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: cell.preview.length > 0
                            ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                    }
                }

                Text {
                    anchors {
                        top: iconBox.bottom
                        topMargin: 4
                        left: parent.left
                        right: parent.right
                        leftMargin: 2
                        rightMargin: 2
                    }
                    text: DesktopState.displayName(cell.fileName)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: cell.selected ? Font.DemiBold : Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideMiddle
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.72)
                }

                MouseArea {
                    id: hover

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            DesktopState.selectedIndex = -1;
                            return;
                        }
                        DesktopState.selectedIndex = cell.index;
                    }
                    onDoubleClicked: DesktopState.openIndex(cell.index)
                }
            }
        }
    }
}
