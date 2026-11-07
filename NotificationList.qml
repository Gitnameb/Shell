import Quickshell
import QtQuick
import QtQuick.Layouts

// Lista de notificaciones agrupadas por aplicación. El grupo muestra el aviso
// más reciente y un contador con chevron; al abrirlo se listan todos sus avisos.
// Un clic en un aviso suelto despliega su texto completo.
ListView {
    id: root

    property string openGroup: ""
    property int expandedChildId: -1

    clip: true
    spacing: 4
    model: NotificationState.groups
    boundsBehavior: Flickable.StopAtBounds

    // Nombres que algunas apps envían y que no coinciden con su icono instalado.
    // La resolución vive en NotificationLook para compartirla con las tarjetas
    // emergentes.
    function tryIcon(name) {
        return NotificationLook.tryIcon(name);
    }

    function iconSource(entry) {
        return NotificationLook.iconSource(entry);
    }

    function toggleGroup(key) {
        root.openGroup = root.openGroup === key ? "" : key;
    }

    function toggleText(id) {
        root.expandedChildId = root.expandedChildId === id ? -1 : id;
    }

    delegate: Item {
        id: groupColumn

        required property var modelData

        readonly property var items: modelData.items
        readonly property var latest: modelData.latest
        readonly property bool grouped: items.length > 1
        readonly property bool open: root.openGroup === modelData.appKey
        readonly property bool expanded: !grouped && root.expandedChildId === latest.id

        width: root.width
        height: head.height + (childrenColumn.visible
            ? childrenColumn.height + 3
            : 0)

        // -------------------------------------------------- cabecera del grupo
        Rectangle {
            id: head

            width: groupColumn.width
            height: Math.max(54, headRow.implicitHeight + 14)
            radius: 10
            color: groupColumn.open
                ? Theme.surfaceAlt
                : (headMouse.containsMouse ? Theme.hover : Theme.surfaceAlt)
            border.width: 1
            border.color: groupColumn.open
                ? Theme.borderStrong
                : Theme.border

            MouseArea {
                id: headMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (groupColumn.grouped)
                        root.toggleGroup(groupColumn.modelData.appKey);
                    else
                        root.toggleText(groupColumn.latest.id);
                }
            }

            RowLayout {
                id: headRow

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: 7
                    rightMargin: 6
                    topMargin: 7
                }
                spacing: 7

                // Icono de la app con respaldo de inicial.
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignTop
                    radius: 7
                    color: Theme.surface

                    Image {
                        id: appIcon

                        anchors {
                            fill: parent
                            margins: 4
                        }
                        source: root.iconSource(groupColumn.modelData)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        text: groupColumn.modelData.appName.charAt(0).toUpperCase()
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: groupColumn.modelData.appName
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: NotificationState.timeLabel(
                                groupColumn.latest.stamp,
                                NotificationState.clockTick)
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                        }
                    }

                    Text {
                        id: titleText

                        Layout.fillWidth: true
                        text: groupColumn.latest.summary
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                        maximumLineCount: groupColumn.expanded ? 0 : 1
                        elide: groupColumn.expanded
                            ? Text.ElideNone
                            : Text.ElideRight
                    }

                    Text {
                        id: bodyText

                        Layout.fillWidth: true
                        visible: text !== ""
                        text: groupColumn.latest.body
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        wrapMode: Text.Wrap
                        maximumLineCount: groupColumn.expanded ? 0 : 1
                        elide: groupColumn.expanded
                            ? Text.ElideNone
                            : Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }

                // Contador y despliegue del grupo, al lado derecho.
                Rectangle {
                    visible: groupColumn.grouped
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: pillRow.implicitWidth + 10
                    implicitHeight: 17
                    radius: 8
                    color: groupColumn.open ? Theme.accent : Theme.accentSoft

                    Row {
                        id: pillRow

                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: groupColumn.items.length
                            color: groupColumn.open ? Theme.accentInk : Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "▾"
                            color: groupColumn.open ? Theme.accentInk : Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            rotation: groupColumn.open ? 180 : 0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleGroup(groupColumn.modelData.appKey)
                    }
                }

                // Aviso suelto recortado: el chevron de expandir queda a la derecha.
                Text {
                    Layout.alignment: Qt.AlignTop
                    visible: !groupColumn.grouped
                        && (titleText.truncated
                            || bodyText.truncated
                            || groupColumn.expanded)
                    text: "⌄"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    rotation: groupColumn.expanded ? 180 : 0
                }
            }
        }

        // ------------------------------------------------ avisos del grupo
        Column {
            id: childrenColumn

            visible: groupColumn.open && groupColumn.grouped
            y: head.height + 3
            width: parent.width
            spacing: 3

            Repeater {
                model: groupColumn.items

                Rectangle {
                    id: child

                    required property var modelData

                    readonly property bool expanded: root.expandedChildId === modelData.id

                    width: childrenColumn.width - 12
                    height: Math.max(46, childRow.implicitHeight + 12)
                    x: 12
                    radius: 9
                    color: childMouse.containsMouse ? Theme.hover : Theme.surface
                    border.width: 1
                    border.color: Theme.border

                    MouseArea {
                        id: childMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleText(child.modelData.id)
                    }

                    RowLayout {
                        id: childRow

                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 6
                            rightMargin: 5
                            topMargin: 6
                        }
                        spacing: 6

                        Rectangle {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            Layout.alignment: Qt.AlignTop
                            radius: 6
                            color: Theme.surfaceAlt

                            Image {
                                id: childIcon

                                anchors {
                                    fill: parent
                                    margins: 3
                                }
                                source: root.iconSource(child.modelData)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !childIcon.visible
                                text: child.modelData.appName.charAt(0).toUpperCase()
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    id: childTitle

                                    Layout.fillWidth: true
                                    text: child.modelData.summary
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.Wrap
                                    maximumLineCount: child.expanded ? 0 : 1
                                    elide: child.expanded
                                        ? Text.ElideNone
                                        : Text.ElideRight
                                }

                                Text {
                                    text: NotificationState.timeLabel(
                                        child.modelData.stamp,
                                        NotificationState.clockTick)
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                }

                                Text {
                                    visible: childTitle.truncated
                                        || childBody.truncated
                                        || child.expanded
                                    text: "⌄"
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    rotation: child.expanded ? 180 : 0
                                }
                            }

                            Text {
                                id: childBody

                                Layout.fillWidth: true
                                visible: text !== ""
                                text: child.modelData.body
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                wrapMode: Text.Wrap
                                maximumLineCount: child.expanded ? 0 : 1
                                elide: child.expanded
                                    ? Text.ElideNone
                                    : Text.ElideRight
                                textFormat: Text.PlainText
                            }
                        }
                    }
                }
            }
        }
    }
}
