import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Desplegable de la bandeja del sistema. Agrupa los iconos de las apps que
// publican StatusNotifierItem para no llenar la barra. Se abre con el botón de
// chevron y se coloca justo encima (o debajo) de ese botón.
PanelWindow {
    id: root

    readonly property var items: SystemTray.items
        ? SystemTray.items.values : []
    readonly property int count: root.items ? root.items.length : 0
    readonly property int cell: 40
    readonly property int gap: 6
    // Cuatro columnas como máximo; con pocos iconos el panel se estrecha.
    readonly property int columns: Math.max(1, Math.min(4, root.count))
    readonly property int rows: root.columns > 0
        ? Math.ceil(root.count / root.columns) : 0
    readonly property int gridWidth: root.columns * root.cell
        + Math.max(0, root.columns - 1) * root.gap
    readonly property int gridHeight: root.rows * root.cell
        + Math.max(0, root.rows - 1) * root.gap

    property string hoveredTitle: ""

    visible: TrayState.open && root.count > 0
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // Altura del panel cuando la barra está en un lateral: se centra con el
    // botón de la bandeja.
    readonly property real verticalTop: {
        const screenHeight = root.screen ? root.screen.height : 800;
        const anchor = TrayState.anchorY;
        const desired = anchor > 0
            ? anchor + Theme.edge - root.implicitHeight / 2
            : (screenHeight - root.implicitHeight) / 2;
        return Math.max(Theme.edge + 8, Math.min(
            screenHeight - root.implicitHeight - Theme.edge - 8, desired));
    }

    anchors {
        top: SettingsState.barVertical || SettingsState.barAtTop
        bottom: !SettingsState.barVertical && !SettingsState.barAtTop
        left: !SettingsState.barVertical || SettingsState.barAtLeft
        right: SettingsState.barVertical && SettingsState.barAtRight
    }
    margins {
        top: SettingsState.barVertical ? root.verticalTop
            : (SettingsState.barAtTop ? Theme.edge + Theme.barHeight + 8 : 0)
        bottom: !SettingsState.barVertical && !SettingsState.barAtTop
            ? Theme.edge + Theme.barHeight + 8 : 0
        // En horizontal se centra sobre el botón; en vertical se pega al lado
        // de la barra.
        left: SettingsState.barVertical
            ? (SettingsState.barAtLeft
                ? Theme.edge + Theme.barHeight + 8 : 0)
            : Math.max(Theme.edge, Math.min(
                (screen ? screen.width : 1280) - root.implicitWidth - Theme.edge,
                (TrayState.anchorX > 0
                    ? TrayState.anchorX
                    : (screen ? screen.width - 180 : 1000))
                    - root.implicitWidth / 2))
        right: SettingsState.barVertical && SettingsState.barAtRight
            ? Theme.edge + Theme.barHeight + 8 : 0
    }
    implicitWidth: Math.max(176, root.gridWidth + 20)
    implicitHeight: content.implicitHeight + 20
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-tray"
    WlrLayershell.keyboardFocus: TrayState.open && focusGate.ready
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    PanelFocusGate {
        id: focusGate
        active: TrayState.open
    }

    onCountChanged: {
        if (root.count === 0)
            TrayState.hide();
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.glassCard
        border.width: 1
        border.color: Theme.borderStrong

        ColumnLayout {
            id: content

            anchors {
                fill: parent
                margins: 10
            }
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Bandeja del sistema"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }

            Flow {
                Layout.alignment: Qt.AlignHCenter
                width: root.gridWidth
                height: root.gridHeight
                spacing: root.gap

                Repeater {
                    model: root.items

                    delegate: Rectangle {
                        id: trayCell

                        required property var modelData

                        readonly property string title: String(
                            trayCell.modelData.tooltipTitle
                                || trayCell.modelData.title
                                || trayCell.modelData.id || "")
                        // Igual que en la barra: Quickshell entrega el icono
                        // como fuente de imagen, no como nombre del tema.
                        readonly property string iconSource: {
                            const raw = String(
                                trayCell.modelData.icon || "");
                            if (raw.length === 0)
                                return "";
                            if (raw.startsWith("image://")
                                    || raw.startsWith("file://"))
                                return raw;
                            if (raw.startsWith("/"))
                                return "file://" + raw;
                            return Quickshell.iconPath(raw) || "";
                        }

                        width: root.cell
                        height: root.cell
                        radius: 9
                        color: cellMouse.containsMouse
                            ? Theme.hover : "transparent"

                        Image {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: trayCell.iconSource
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: source != ""
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: trayCell.iconSource.length === 0
                            text: trayCell.title.length > 0
                                ? trayCell.title.charAt(0).toUpperCase() : "?"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        // El menú de plataforma se ancla a esta celda dentro
                        // de la ventana del panel.
                        function openMenu(): void {
                            const point = trayCell.mapToItem(
                                root.contentItem, 0, 0);
                            trayCell.modelData.display(root,
                                Math.round(point.x + trayCell.width / 2),
                                Math.round(point.y + trayCell.height));
                        }

                        MouseArea {
                            id: cellMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                                | Qt.RightButton | Qt.MiddleButton

                            onEntered: root.hoveredTitle = trayCell.title
                            onExited: {
                                if (root.hoveredTitle === trayCell.title)
                                    root.hoveredTitle = "";
                            }

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.MiddleButton) {
                                    trayCell.modelData.secondaryActivate();
                                    return;
                                }
                                if (mouse.button === Qt.RightButton) {
                                    if (trayCell.modelData.hasMenu)
                                        trayCell.openMenu();
                                    else
                                        trayCell.modelData.secondaryActivate();
                                    return;
                                }
                                // Si la app solo tiene menú, se abre y el
                                // panel sigue visible para elegir una opción.
                                if (trayCell.modelData.onlyMenu
                                        && trayCell.modelData.hasMenu) {
                                    trayCell.openMenu();
                                    return;
                                }
                                trayCell.modelData.activate();
                                TrayState.hide();
                            }

                            onWheel: (wheel) => {
                                const vertical = wheel.angleDelta.y;
                                const horizontal = wheel.angleDelta.x;
                                if (vertical === 0 && horizontal === 0)
                                    return;
                                const useHorizontal = Math.abs(horizontal)
                                    > Math.abs(vertical);
                                const delta = useHorizontal
                                    ? horizontal : vertical;
                                if (delta !== 0)
                                    trayCell.modelData.scroll(
                                        delta > 0 ? 1 : -1, useHorizontal);
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.hoveredTitle.length > 0
                    ? root.hoveredTitle : "Clic derecho para el menú"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: TrayState.open
        onActivated: TrayState.hide()
    }
}
