import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Vista de VPN de NetworkManager. No inventa servidores: muestra los perfiles
// reales, permite importar un `.ovpn` y editar nombre y arranque automático.
ColumnLayout {
    id: root

    spacing: 8

    // Nombre del perfil que está abierto en el editor. Cadena vacía = ninguno.
    property string editingName: ""
    property string editingValue: ""
    property bool editingAuto: false
    property bool confirmDelete: false

    function openEditor(profile): void {
        root.editingName = profile.name;
        root.editingValue = profile.name;
        root.editingAuto = profile.autoconnect === true;
        root.confirmDelete = false;
    }

    function closeEditor(): void {
        root.editingName = "";
        root.confirmDelete = false;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: "Perfiles VPN"
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 8
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        Text {
            text: VpnState.busy ? "Espera…" : "Importar .ovpn"
            color: importMouse.containsMouse
                ? Theme.accent : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 8
            font.weight: Font.DemiBold
            opacity: VpnState.busy ? 0.6 : 1

            MouseArea {
                id: importMouse
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                enabled: !VpnState.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: VpnState.pickImport()
            }
        }

        Text {
            text: "Actualizar"
            color: refreshMouse.containsMouse
                ? Theme.accent : Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 8

            MouseArea {
                id: refreshMouse
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: VpnState.refresh()
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: !VpnState.configured

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Rectangle {
                width: 40
                height: 40
                radius: 10
                color: Theme.surfaceAlt

                AlbaIcon {
                    anchors.centerIn: parent
                    source: AlbaIcons.src("shield")
                    color: Theme.faint
                    size: 22
                    fallback: "⛨"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: "Sin perfiles VPN"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: "Importa un archivo .ovpn para empezar."
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: VpnState.configured

        Repeater {
            model: VpnState.profiles

            delegate: ColumnLayout {
                id: profileBlock

                required property var modelData

                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    id: profileRow

                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: modelData.active
                        ? Theme.accentSoft
                        : (rowMouse.containsMouse ? Theme.hover : Theme.surfaceAlt)
                    border.width: modelData.active ? 1 : 0
                    border.color: Theme.accentLine

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 6
                        }
                        spacing: 7

                        AlbaIcon {
                            source: AlbaIcons.src("shield")
                            color: modelData.active ? Theme.accent : Theme.muted
                            size: 16
                            fallback: "⛨"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: modelData.active
                                    ? Theme.accent : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.type + " · "
                                    + (modelData.active
                                        ? "Conectada" : "Desconectada")
                                    + (modelData.autoconnect
                                        ? " · Al iniciar" : "")
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            implicitWidth: actionLabel.implicitWidth + 14
                            implicitHeight: 24
                            radius: 6
                            color: modelData.active
                                ? Theme.surface
                                : (actionMouse.containsMouse
                                    ? Theme.accent : Theme.accentSoft)
                            opacity: VpnState.busy ? 0.6 : 1

                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: VpnState.busy
                                    && VpnState.busyName === modelData.name
                                    ? "…"
                                    : (modelData.active
                                        ? "Desconectar" : "Conectar")
                                color: modelData.active
                                    ? Theme.muted : Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !VpnState.busy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: VpnState.toggle(modelData.name)
                            }
                        }

                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 6
                            color: editMouse.containsMouse
                                ? Theme.hover : "transparent"

                            AlbaIcon {
                                anchors.centerIn: parent
                                source: AlbaIcons.src("settings")
                                color: root.editingName === modelData.name
                                    ? Theme.accent : Theme.muted
                                size: 13
                            }

                            MouseArea {
                                id: editMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !VpnState.busy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.editingName === modelData.name)
                                        root.closeEditor();
                                    else
                                        root.openEditor(modelData);
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        z: -1
                    }
                }

                // Editor del perfil: nombre visible y arranque automático. Se
                // aplica en una sola orden para no dejar estados intermedios.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: editColumn.implicitHeight + 16
                    radius: 8
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.border
                    visible: root.editingName === modelData.name

                    ColumnLayout {
                        id: editColumn

                        x: 8
                        y: 8
                        width: parent.width - 16
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: "Nombre del perfil"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }

                        TextField {
                            id: nameField

                            Layout.fillWidth: true
                            text: root.editingValue
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            selectByMouse: true
                            onTextEdited: root.editingValue = text
                            onAccepted: {
                                VpnState.saveProfile(modelData.name,
                                    root.editingValue, root.editingAuto);
                                root.closeEditor();
                            }
                            background: Rectangle {
                                radius: 7
                                color: Theme.surfaceAlt
                                border.width: 1
                                border.color: nameField.activeFocus
                                    ? Theme.accent : Theme.border
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: "Conectar al iniciar"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                            }

                            AlbaSwitch {
                                checked: root.editingAuto
                                onToggled: root.editingAuto = !root.editingAuto
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                implicitWidth: deleteLabel.implicitWidth + 14
                                implicitHeight: 24
                                radius: 6
                                color: deleteMouse.containsMouse
                                    ? Theme.surfaceAlt : "transparent"
                                border.width: 1
                                border.color: root.confirmDelete
                                    ? Theme.danger : Theme.border

                                Text {
                                    id: deleteLabel
                                    anchors.centerIn: parent
                                    text: root.confirmDelete
                                        ? "¿Eliminar?" : "Eliminar"
                                    color: Theme.danger
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: deleteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !VpnState.busy
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.confirmDelete) {
                                            root.confirmDelete = true;
                                            return;
                                        }
                                        VpnState.deleteProfile(modelData.name);
                                        root.closeEditor();
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                implicitWidth: cancelLabel.implicitWidth + 14
                                implicitHeight: 24
                                radius: 6
                                color: cancelMouse.containsMouse
                                    ? Theme.hover : "transparent"
                                border.width: 1
                                border.color: Theme.border

                                Text {
                                    id: cancelLabel
                                    anchors.centerIn: parent
                                    text: "Cancelar"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                }

                                MouseArea {
                                    id: cancelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeEditor()
                                }
                            }

                            Rectangle {
                                implicitWidth: saveLabel.implicitWidth + 16
                                implicitHeight: 24
                                radius: 6
                                color: Theme.accent
                                opacity: VpnState.busy ? 0.6 : 1

                                Text {
                                    id: saveLabel
                                    anchors.centerIn: parent
                                    text: "Guardar"
                                    color: Theme.accentInk
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: saveMouse
                                    anchors.fill: parent
                                    enabled: !VpnState.busy
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        VpnState.saveProfile(modelData.name,
                                            root.editingValue, root.editingAuto);
                                        root.closeEditor();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: VpnState.error.length > 0
        text: VpnState.error
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }
}
