import QtQuick
import QtQuick.Layouts

// Ítem compacto del centro de control: el icono izquierdo alterna el estado y
// el nombre con el chevron abre las opciones avanzadas. Arrastrarlo fuera del
// panel y soltarlo sobre la barra lo mueve a la barra. Si el control ya está
// en la barra, este ítem no se muestra.
Rectangle {
    id: root

    property string icon: ""
    property string iconName: ""
    property string iconSource: ""
    property color iconColor: Theme.muted
    // Icono de nivel para volumen y micrófono.
    property bool levelIcon: false
    property string levelKind: "volume"
    property real level: 0
    property bool levelMuted: false
    // Segundo icono en la misma ficha (por ejemplo, cable + Wi-Fi).
    property string secondaryIconName: ""
    property string secondaryIconSource: ""
    property color secondaryIconColor: Theme.accent
    readonly property bool hasSecondary: root.secondaryIconName.length > 0
        || root.secondaryIconSource.length > 0
    property string label: ""
    property string meta: ""
    property string dragKey: ""
    property bool active: false
    // Brillo y otros controles sin encendido/apagado abren su vista al pulsar.
    property bool toggleEnabled: true
    // Controles que solo son un interruptor: toda la ficha alterna el estado
    // y no abre ninguna vista (por ejemplo, el modo avión).
    property bool wholeToggle: false
    // Celda resaltada como destino al reordenar dentro de la cuadrícula.
    property bool dropTarget: false
    signal toggled()
    signal opened()

    // Posición dentro de la cuadrícula del centro de control. Mientras se
    // arrastra una ficha, las demás se desplazan para dejar libre la celda de
    // destino; la ficha arrastrada se oculta y la marca el hueco.
    readonly property bool centerDragging: ControlDrag.active
        && ControlDrag.origin === "center"
        && ControlDrag.overPanel
        && ControlDrag.centerTargetIndex >= 0
    readonly property bool centerDragSelf: root.centerDragging
        && root.dragKey === ControlDrag.key
    readonly property int centerIndex: BarState.centerControls.indexOf(
        root.dragKey)
    readonly property int centerRow: root.centerIndex < 0
        ? 0 : Math.floor(root.centerIndex / 2)
    readonly property int centerColumn: root.centerIndex < 0
        ? 0 : root.centerIndex % 2

    Layout.fillWidth: true
    Layout.row: root.centerRow
    Layout.column: root.centerColumn

    function adjustByWheel(direction): bool {
        const step = direction > 0 ? 1 : -1;
        if (root.dragKey === "volume") {
            Audio.adjust(step * 0.02);
            return true;
        }
        if (root.dragKey === "mic") {
            Audio.adjustMic(step * 0.02);
            return true;
        }
        if (root.dragKey === "brightness") {
            DisplayState.setBrightness(DisplayState.brightness + step * 0.05);
            return true;
        }
        if (root.dragKey === "extraDim") {
            DisplayState.setExtraDim(DisplayState.extraDim + step * 0.05);
            return true;
        }
        if (root.dragKey === "night" && DisplayState.nightLight) {
            DisplayState.setNightStrength(
                DisplayState.nightStrength + step * 0.05);
            return true;
        }
        return false;
    }

    // Caja e iconos del centro. El tamaño se ajusta desde Ajustes y nunca
    // supera el lado de la caja para que el dibujo no se salga.
    readonly property real iconBox: 32
    readonly property real iconSize: Math.max(10,
        Math.min(root.iconBox, SettingsState.centerIconSize))
    readonly property real primaryIconSize: root.hasSecondary
        ? Math.min(root.iconSize, 18) : root.iconSize
    readonly property real secondaryIconSize: Math.min(root.iconSize, 14)

    implicitHeight: 38
    radius: 9
    color: root.centerDragSelf
        ? Theme.accentGhost
        : (active ? Theme.accentSoft : Theme.glassInset)
    border.width: root.centerDragSelf ? 2 : 1
    border.color: root.centerDragSelf
        ? Theme.accent
        : (active
            ? Theme.accentLine
            : Theme.border)
    opacity: 1

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 4
            rightMargin: 7
        }
        spacing: 5
        opacity: root.centerDragSelf ? 0 : 1

        Rectangle {
            Layout.preferredWidth: root.iconBox
            Layout.preferredHeight: root.iconBox
            radius: 8
            color: root.active ? Theme.accentSoft : Theme.glassInsetStrong

            Row {
                anchors.centerIn: parent
                spacing: 0

                ShellIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.levelIcon
                    name: root.iconName
                    source: root.iconSource
                    color: root.iconColor
                    size: root.primaryIconSize
                    fallback: root.icon
                }

                LevelIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.levelIcon
                    kind: root.levelKind
                    level: root.level
                    muted: root.levelMuted
                    color: root.iconColor
                    size: root.primaryIconSize
                    fallback: root.icon
                }

                ShellIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasSecondary
                    name: root.secondaryIconName
                    source: root.secondaryIconSource
                    color: root.secondaryIconColor
                    size: root.secondaryIconSize
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 0

                Text {
                    width: parent.width
                    text: root.label
                    color: root.active ? Theme.text : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.meta
                    color: root.active ? Theme.accent : Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            text: "›"
            visible: !root.wholeToggle
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }
    }

    // Un único MouseArea distingue clic corto (icono o nombre) de arrastre.
    MouseArea {
        id: mouse

        anchors.fill: parent
        z: 1
        hoverEnabled: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        property real pressX: 0
        property real pressY: 0
        property bool dragging: false

        onPressed: (event) => {
            pressX = event.x;
            pressY = event.y;
            dragging = false;
        }

        onPositionChanged: (event) => {
            if (!pressed)
                return;
            if (!dragging) {
                const dx = event.x - pressX;
                const dy = event.y - pressY;
                if (Math.sqrt(dx * dx + dy * dy) <= 7)
                    return;
                dragging = true;
                if (root.dragKey.length > 0)
                    ControlDrag.begin(root.dragKey, root.label, "center");
            }
            const point = root.mapToItem(null, event.x, event.y);
            const bounds = ControlDrag.panelBounds;
            if (bounds.width > 0)
                ControlDrag.setPointer(bounds.x + point.x,
                    bounds.y + point.y);
        }

        onReleased: (event) => {
            if (dragging) {
                const point = root.mapToItem(null, event.x, event.y);
                const bounds = ControlDrag.panelBounds;
                if (bounds.width > 0)
                    ControlDrag.setPointer(bounds.x + point.x,
                        bounds.y + point.y);
                ControlDrag.end();
                dragging = false;
                return;
            }
            if ((event.x < 36 || root.wholeToggle) && root.toggleEnabled)
                root.toggled();
            else
                root.opened();
        }

        onCanceled: {
            if (dragging)
                ControlDrag.cancel();
            dragging = false;
        }

        onWheel: (wheel) => {
            if (wheel.angleDelta.y === 0)
                return;
            if (root.adjustByWheel(wheel.angleDelta.y > 0 ? 1 : -1)) {
                wheel.accepted = true;
            } else {
                PanelScrollState.request(wheel.angleDelta.y);
                wheel.accepted = true;
            }
        }
    }
}
