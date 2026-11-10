import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: root

    visible: LauncherState.open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    // La barra y el cajón comparten la capa Overlay. Si el cajón empezara en el
    // borde taparía la barra, así que se aparta el lado donde vive la barra y
    // ambos quedan visibles, como el menú de inicio y la barra de Windows.
    margins {
        top: SettingsState.barAtTop ? Theme.barHeight + Theme.edge : 0
        bottom: SettingsState.barAtBottom ? Theme.barHeight + Theme.edge : 0
        left: SettingsState.barAtLeft ? Theme.barHeight + Theme.edge : 0
        right: SettingsState.barAtRight ? Theme.barHeight + Theme.edge : 0
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-launcher"
    WlrLayershell.keyboardFocus: LauncherState.open
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    property var filtered: computeFiltered()

    function computeFiltered(): var {
        const query = search.text.trim().toLowerCase();
        const apps = DesktopEntries.applications.values.filter((entry) => {
            return !entry.noDisplay && entry.name;
        });

        apps.sort((a, b) => a.name.localeCompare(b.name));

        if (!query)
            return apps;

        return apps.filter((entry) => {
            const haystack = (entry.name + " "
                + (entry.genericName || "") + " "
                + (entry.comment || "") + " "
                + (entry.keywords || "")).toLowerCase();
            return haystack.includes(query);
        });
    }

    function iconFor(entry): string {
        if (!entry || !entry.icon)
            return Quickshell.iconPath("application-x-executable");
        if (entry.icon.startsWith("/"))
            return entry.icon;
        return Quickshell.iconPath(entry.icon, "application-x-executable");
    }

    function launch(entry): void {
        if (!entry)
            return;
        // Quickshell hereda HL_INITIAL_WORKSPACE_TOKEN de Hyprland. Si se deja
        // en el entorno, algunas apps pueden abrirse en el escritorio inicial
        // en vez de en el que está activo; se limpia solo para esta orden.
        if (entry.command.length > 0) {
            let command = ["env", "-u", "HL_INITIAL_WORKSPACE_TOKEN"];
            if (entry.runInTerminal)
                command = command.concat(["foot"]);
            Quickshell.execDetached(command.concat(entry.command));
        } else {
            entry.execute();
        }
        LauncherState.hide();
    }

    onVisibleChanged: {
        if (visible) {
            search.text = "";
            list.currentIndex = 0;
            search.forceActiveFocus();
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            LauncherState.toggle();
        }

        function open(): void {
            LauncherState.show();
        }

        function close(): void {
            LauncherState.hide();
        }

        // Diagnóstico: permite comprobar que un segundo toque de Super
        // cierra el cajón sin abrirlo otra vez.
        function status(): string {
            return "open=" + (LauncherState.open ? "1" : "0");
        }
    }

    // Sin fondo atenuado: el cajón no oscurece el escritorio ni el juego. La
    // superficie transparente sigue capturando el clic fuera de la tarjeta
    // para cerrarlo.
    MouseArea {
        anchors.fill: parent
        onClicked: LauncherState.hide()
    }

    Rectangle {
        id: card

        width: Math.min(720, root.width - 72)
        height: Math.min(560, root.height - 96)
        anchors.centerIn: parent
        radius: 18
        color: Theme.glassCard
        border.width: 1
        border.color: Theme.borderStrong

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Evita que el clic llegue al fondo y cierre el lanzador.
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 12
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: "Buscar"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    TextField {
                        id: search

                        Layout.fillWidth: true
                        placeholderText: "apps, ajustes…"
                        color: Theme.text
                        placeholderTextColor: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        selectByMouse: true
                        background: Rectangle { color: "transparent" }

                        onTextChanged: list.currentIndex = 0
                        onAccepted: root.launch(root.filtered[list.currentIndex])

                        Keys.onEscapePressed: LauncherState.hide()
                        Keys.onDownPressed: (event) => {
                            list.incrementCurrentIndex();
                            event.accepted = true;
                        }
                        Keys.onUpPressed: (event) => {
                            list.decrementCurrentIndex();
                            event.accepted = true;
                        }
                    }

                    Text {
                        text: "Esc"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.filtered.length + " aplicaciones"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.filtered
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: item

                    required property var modelData
                    required property int index

                    width: list.width
                    height: 46
                    radius: 10
                    color: ListView.isCurrentItem
                        ? Theme.accentSoft
                        : (itemMouse.containsMouse ? Theme.hover : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        Image {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            source: root.iconFor(item.modelData)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: item.modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: item.modelData.comment || item.modelData.genericName || ""
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launch(item.modelData)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.filtered.length === 0
                text: "Sin resultados"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
