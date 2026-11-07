import Quickshell
import QtQuick

// Contenedor base de los widgets de la barra. La apariencia es provisional.
Rectangle {
    id: root

    default property alias contentData: row.data

    property bool active: false
    // Fondo azul de aviso: suena una alarma o el temporizador.
    property bool alert: false
    property bool draggable: false
    // Relleno horizontal a cada lado del contenido. El tráfico de red usa
    // menos para que la píldora no quede más ancha que sus cifras.
    property real horizontalPadding: 8
    // Ancho mínimo solicitado por el widget. La música lo usa para poder
    // alargarse manteniendo Super sin dejar de encogerse con su contenido.
    property real preferredWidth: 0
    // Ancho fijo opcional. El tráfico de red lo usa para que pasar de «9» a
    // «1,2» no empuje a los controles que tiene al lado.
    property real fixedWidth: 0
    readonly property bool hovered: mouse.containsMouse
    signal clicked()
    signal dragStarted()
    signal dragFinished()
    signal dragCanceled()
    signal wheeled(int delta)

    implicitWidth: root.fixedWidth > 0
        ? root.fixedWidth
        : Math.max(row.implicitWidth + root.horizontalPadding * 2,
            root.preferredWidth)
    implicitHeight: Theme.itemHeight
    radius: Theme.itemRadius
    // Los widgets no se dibujan como botones: comparten el fondo de la barra
    // y solo se tiñen al pasar el ratón. El estado activo lo comunica el
    // icono, igual que el botón de energía del mockup.
    color: root.alert
        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
        : (root.hovered ? Theme.hover : "transparent")
    border.width: root.alert ? 1 : 0
    border.color: Theme.accentLine

    Behavior on color {
        ColorAnimation { duration: 160 }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }

    // Traduce un punto del widget a coordenadas globales de la pantalla. La
    // barra puede estar en cualquiera de los cuatro bordes.
    function reportPointer(x, y): void {
        const point = root.mapToItem(null, x, y);
        const s = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        if (!s)
            return;
        const vertical = SettingsState.barVertical;
        const auto = SettingsState.autoHideBar;
        ControlDrag.setPointer(
            s.x + (vertical
                ? (SettingsState.barAtLeft
                    ? (auto ? 0 : Theme.edge)
                    : s.width - Theme.edge - Theme.barHeight)
                : Theme.edge) + point.x,
            s.y + (vertical
                ? Theme.edge
                : (SettingsState.barAtTop
                    ? (auto ? 0 : Theme.edge)
                    : s.height - Theme.edge - Theme.barHeight)) + point.y);
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        property real pressX: 0
        property real pressY: 0
        property bool dragging: false

        onPressed: (event) => {
            pressX = event.x;
            pressY = event.y;
            dragging = false;
        }

        onPositionChanged: (event) => {
            if (!root.draggable || !pressed)
                return;
            if (!dragging) {
                const dx = event.x - pressX;
                const dy = event.y - pressY;
                if (Math.sqrt(dx * dx + dy * dy) <= 7)
                    return;
                dragging = true;
                root.dragStarted();
            }
            root.reportPointer(event.x, event.y);
        }

        onReleased: (event) => {
            if (dragging) {
                root.reportPointer(event.x, event.y);
                root.dragFinished();
                dragging = false;
                return;
            }
            root.clicked();
        }

        onCanceled: {
            if (dragging)
                root.dragCanceled();
            dragging = false;
        }

        onWheel: (wheel) => root.wheeled(wheel.angleDelta.y)
    }
}
