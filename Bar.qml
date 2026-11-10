import Quickshell
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar

        required property var modelData
        screen: modelData

        // Mientras hay música o vídeo, o un juego a pantalla completa, la
        // pantalla no se considera inactiva: swayidle no llega a bloquear. El
        // inhibidor vive en la superficie de la barra, que siempre está mapeada
        // aunque esté oculta. Los juegos no cuentan como actividad con mando.
        IdleInhibitor {
            window: bar
            enabled: MusicState.playing
                || CompositorState.hasFullscreenWindow
        }

        // Menú contextual de las apps del escritorio activo.
        property var appMenuApp: null
        property real appMenuX: 0
        property real appMenuY: 0
        // Posición del marcador de inserción al reordenar controles.
        property real reorderX: -1

        function updateReorderTarget() {
            if (!ControlDrag.active || ControlDrag.origin !== "bar"
                    || !ControlDrag.overBar || ControlDrag.key.length === 0) {
                ControlDrag.targetIndex = -1;
                bar.reorderX = -1;
                return;
            }

            const list = BarState.controls;
            const from = list.indexOf(ControlDrag.key);
            if (from === -1) {
                ControlDrag.targetIndex = -1;
                bar.reorderX = -1;
                return;
            }

            // En horizontal se compara la coordenada X; en vertical, la Y.
            // Ese número es la posición final dentro de la lista sin el
            // control que se arrastra.
            const vertical = SettingsState.barVertical;
            let target = 0;
            let marker = -1;
            for (let i = 0; i < list.length; i++) {
                if (i === from)
                    continue;
                const loader = controlRepeater.itemAt(i);
                if (!loader)
                    continue;
                const point = loader.mapToItem(null, 0, 0);
                const center = vertical
                    ? bar.screen.y + Theme.edge
                        + point.y + loader.height / 2
                    : bar.screen.x + Theme.edge
                        + point.x + loader.width / 2;
                const cursor = vertical
                    ? ControlDrag.cursorY : ControlDrag.cursorX;
                if (cursor > center) {
                    target++;
                    marker = vertical
                        ? point.y + loader.height + 2
                        : point.x + loader.width + 2;
                } else if (marker < 0) {
                    marker = vertical ? point.y - 2 : point.x - 2;
                }
            }
            // Si el cursor está antes del primer control, el marcador va
            // delante; si está después del último, detrás.
            if (marker < 0)
                marker = 2;
            ControlDrag.targetIndex = target;
            bar.reorderX = marker;
        }

        function openAppMenu(anchorItem, app) {
            const currentScreen = bar.screen;
            if (!anchorItem || !currentScreen)
                return;
            // Un segundo clic derecho en la misma ficha cierra el menú. En otra
            // ficha se reemplaza sin tener que cerrar el anterior primero.
            if (appMenu.visible && bar.appMenuApp
                    && String(bar.appMenuApp.address)
                        === String(app.address)) {
                bar.closeAppMenu();
                return;
            }
            // El menú de la app y los paneles de la barra no se solapan.
            NotificationState.hidePanel();
            CalendarState.hide();
            PowerState.hide();
            BatteryState.hide();
            // mapToItem(null) devuelve coordenadas de la ventana de la barra;
            // se suman el margen y el origen de la pantalla para obtenerlas
            // globales.
            const point = anchorItem.mapToItem(null,
                anchorItem.width / 2, anchorItem.height / 2);
            clearMenuTimer.stop();
            bar.appMenuApp = app;
            if (SettingsState.barVertical) {
                // En vertical el menú se abre al lado de la barra y a la
                // altura del icono. AppContextMenu decide el lado.
                bar.appMenuX = currentScreen.x + Theme.edge + point.x;
                bar.appMenuY = currentScreen.y + Theme.edge + point.y;
            } else {
                bar.appMenuX = currentScreen.x + Theme.edge + point.x;
                bar.appMenuY = SettingsState.barAtTop
                    ? currentScreen.y + Theme.edge + Theme.barHeight
                    : currentScreen.y + currentScreen.height
                        - Theme.edge - Theme.barHeight;
            }
            appMenu.visible = true;
        }

        function closeAppMenu(): void {
            if (!appMenu.visible && bar.appMenuApp === null)
                return;
            appMenu.visible = false;
            bar.appMenuApp = null;
            clearMenuTimer.stop();
        }

        // Cierra todo lo que se despliega desde la barra. Se usa al pulsar el
        // fondo de la propia barra y en la capa que captura clics fuera.
        function closePanels(): void {
            closeAppMenu();
            LauncherState.hide();
            NotificationState.hidePanel();
            QuickPanelState.hide();
            CalendarState.hide();
            PowerState.hide();
            BatteryState.hide();
            TrayState.hide();
        }

        Timer {
            id: clearMenuTimer
            interval: 250
            repeat: false
            onTriggered: bar.appMenuApp = null
        }

        // Al abrir otro panel, el menú de la app se cierra para no quedar
        // debajo de él ni interceptar clics.
        Connections {
            target: NotificationState

            function onPanelOpenChanged(): void {
                if (NotificationState.panelOpen)
                    bar.closeAppMenu();
            }
        }

        Connections {
            target: QuickPanelState

            function onOpened(): void {
                bar.closeAppMenu();
            }
        }

        Connections {
            target: CalendarState

            function onOpenChanged(): void {
                if (CalendarState.open)
                    bar.closeAppMenu();
            }
        }

        Connections {
            target: PowerState

            function onOpenChanged(): void {
                if (PowerState.open)
                    bar.closeAppMenu();
            }
        }

        Connections {
            target: BatteryState

            function onOpenChanged(): void {
                if (BatteryState.open)
                    bar.closeAppMenu();
            }
        }

        // Orientación de la barra. En los lados ocupa una franja vertical y
        // los widgets se apilan; arriba y abajo se mantiene horizontal.
        readonly property bool vertical: SettingsState.barVertical

        anchors {
            top: bar.vertical || SettingsState.barAtTop
            bottom: bar.vertical || SettingsState.barAtBottom
            left: !bar.vertical || SettingsState.barAtLeft
            right: !bar.vertical || SettingsState.barAtRight
        }
        margins {
            // En horizontal se separa del borde superior o inferior; en
            // vertical, del lateral. El resto de lados conserva el margen del
            // tema para que la franja no toque los extremos de la pantalla.
            top: bar.vertical ? Theme.edge
                : (SettingsState.barAtTop && !bar.autoHide ? Theme.edge : 0)
            bottom: bar.vertical ? Theme.edge
                : (SettingsState.barAtBottom && !bar.autoHide
                    ? Theme.edge : 0)
            left: bar.vertical
                ? (SettingsState.barAtLeft && !bar.autoHide
                    ? Theme.edge : 0)
                : Theme.edge
            right: bar.vertical
                ? (SettingsState.barAtRight && !bar.autoHide
                    ? Theme.edge : 0)
                : Theme.edge
        }
        // Con la barra automática la ventana llega hasta el borde de la
        // pantalla para que la franja que revela la barra quede al alcance del
        // puntero. El margen visual se aplica dentro, al contenido.
        implicitWidth: bar.vertical
            ? (bar.autoHide ? Theme.barHeight + Theme.edge : Theme.barHeight)
            : 0
        implicitHeight: bar.vertical
            ? (bar.screen ? bar.screen.height - Theme.edge * 2 : 800)
            : (bar.autoHide ? Theme.barHeight + Theme.edge : Theme.barHeight)
        color: "transparent"
        // Reserva solo la altura de la barra. El compositor ya suma el margen
        // superior de la superficie (Theme.edge), así que añadirlo aquí dejaba
        // 17 px entre la barra y la ventana en vez de los 8-9 del resto.
        exclusiveZone: bar.autoHide ? 0 : Theme.barHeight

        // ------------------------------------------------- barra automática
        // La barra vive en la capa Overlay para poder quedar por encima de una
        // ventana a pantalla completa. Fuera de ese caso se comporta igual:
        // reserva su espacio y no se oculta salvo que el usuario lo pida.
        // Con un juego a pantalla completa se auto-oculta y se revela al
        // pulsar Super o al llevar el puntero al borde, como en Windows.
        property bool autoHide: SettingsState.autoHideBar
            || CompositorState.hasFullscreenWindow
        property bool barHidden: false
        property real barOpacity: bar.barHidden ? 0 : 1
        readonly property int revealHeight: 4
        // Mientras haya un panel, un menú o un arrastre abierto, la barra no
        // se oculta: los paneles se apoyan encima de ella.
        readonly property bool keepVisible: NotificationState.panelOpen
            || QuickPanelState.open
            || CalendarState.open || LauncherState.open || PowerState.open
            || BatteryState.open || TrayState.open
            || ControlDrag.active || bar.appMenuApp !== null
            || SuperState.active

        Behavior on barOpacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        function showBar(): void {
            bar.barHidden = false;
            hideTimer.stop();
            revealTimer.stop();
        }

        function scheduleHide(): void {
            if (!bar.autoHide || bar.keepVisible || bar.barHidden
                    || revealArea.containsMouse)
                return;
            hideTimer.restart();
        }

        onAutoHideChanged: {
            if (!bar.autoHide) {
                bar.barHidden = false;
                hideTimer.stop();
                revealTimer.stop();
            } else {
                bar.scheduleHide();
            }
        }

        onKeepVisibleChanged: {
            if (bar.keepVisible)
                bar.showBar();
            else
                bar.scheduleHide();
        }

        onBarHiddenChanged: {
            if (bar.barHidden) {
                hideTimer.stop();
                revealTimer.stop();
                TrayState.hide();
                BatteryState.hide();
            } else if (bar.autoHide && !barHover.hovered
                    && !revealArea.containsMouse) {
                // Si se acaba de revelar, da tiempo a llegar a la barra.
                revealTimer.restart();
            }
        }

        Component.onCompleted: bar.scheduleHide()

        Timer {
            id: hideTimer
            interval: 1000
            repeat: false
            onTriggered: {
                if (bar.autoHide && !bar.keepVisible && !barHover.hovered
                        && !revealArea.containsMouse)
                    bar.barHidden = true;
            }
        }

        Timer {
            id: revealTimer
            interval: 900
            repeat: false
            onTriggered: {
                if (bar.autoHide && !bar.keepVisible && !barHover.hovered
                        && !revealArea.containsMouse)
                    bar.barHidden = true;
            }
        }

        // Cuando está oculta, la ventana solo acepta eventos en la franja del
        // borde; el resto deja pasar los clics a las ventanas de debajo.
        mask: Region {
            x: bar.vertical
                ? (bar.autoHide && bar.barHidden && !SettingsState.barAtLeft
                    ? bar.width - bar.revealHeight : 0)
                : 0
            y: bar.vertical ? 0
                : (bar.autoHide && bar.barHidden
                    && !SettingsState.barAtTop
                    ? bar.height - bar.revealHeight : 0)
            width: bar.vertical && bar.autoHide && bar.barHidden
                ? bar.revealHeight : bar.width
            height: !bar.vertical && bar.autoHide && bar.barHidden
                ? bar.revealHeight : bar.height
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "shell-bar"

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        // Contenido visual de la barra. Se desvanece al ocultarse y su
        // HoverHandler permite saber si el puntero sigue sobre ella.
        Item {
            id: barSurface

            anchors.fill: parent
            anchors.topMargin: bar.autoHide && !bar.vertical
                && SettingsState.barAtTop ? Theme.edge : 0
            anchors.bottomMargin: bar.autoHide && !bar.vertical
                && SettingsState.barAtBottom ? Theme.edge : 0
            anchors.leftMargin: bar.autoHide && bar.vertical
                && SettingsState.barAtLeft ? Theme.edge : 0
            anchors.rightMargin: bar.autoHide && bar.vertical
                && SettingsState.barAtRight ? Theme.edge : 0
            opacity: bar.barOpacity

            HoverHandler {
                id: barHover

                onHoveredChanged: {
                    if (hovered) {
                        hideTimer.stop();
                        revealTimer.stop();
                        if (bar.autoHide)
                            bar.barHidden = false;
                    } else {
                        bar.scheduleHide();
                    }
                }
            }

            // Un clic en el fondo de la barra (fuera de sus controles) cierra
            // cualquier panel abierto. Los controles quedan por encima y
            // siguen abriendo o cambiando su propio panel.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                z: -1
                onClicked: bar.closePanels()
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.barRadius
                color: ControlDrag.active && ControlDrag.origin === "center"
                    && ControlDrag.overBar
                    ? Theme.accentSoft
                    : Theme.glass
                border.width: ControlDrag.active && ControlDrag.origin === "center"
                    && ControlDrag.overBar ? 2 : 1
                border.color: ControlDrag.active && ControlDrag.origin === "center"
                    && ControlDrag.overBar
                    ? Theme.accent
                    : Theme.border
            }

            // Contenido de la barra. El mismo árbol se usa en horizontal
            // (tres columnas: inicio, reloj y estado) y en vertical (tres
            // filas: inicio, reloj y estado).
            GridLayout {
                id: barContent

                anchors.fill: parent
                anchors.leftMargin: bar.vertical ? 0 : 4
                anchors.rightMargin: bar.vertical ? 0 : 4
                anchors.topMargin: bar.vertical ? 4 : 0
                anchors.bottomMargin: bar.vertical ? 4 : 0
                columns: bar.vertical ? 1 : 3
                columnSpacing: 0
                rowSpacing: bar.vertical ? 2 : 0

                // Inicio: logo y escritorios.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridLayout {
                            x: bar.vertical ? (parent.width - width) / 2 : 0
                        y: bar.vertical ? 0 : (parent.height - height) / 2
                        columns: bar.vertical ? 1 : 99
                        columnSpacing: bar.vertical ? 0 : 2
                        rowSpacing: bar.vertical ? 2 : 0
                        width: implicitWidth
                        height: implicitHeight

                    // Logo / lanzador. Mide lo mismo que una ficha de
                    // escritorio (34 px, 28 en la barra vertical) para que el
                    // logotipo no quede más pequeño que sus botones vecinos.
                    Rectangle {
                        Layout.preferredWidth: SettingsState.barVertical ? 28 : 34
                        Layout.preferredHeight: SettingsState.barVertical ? 28 : 34
                        radius: 8
                        color: Theme.accent
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                        ShellIcon {
                            anchors.centerIn: parent
                            source: Distro.iconSource
                            color: Theme.accentInk
                            // El PNG del logotipo ya trae su propio margen.
                            size: parent.width
                            fallback: "▦"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                CalendarState.hide();
                                NotificationState.hidePanel();
                                LauncherState.toggle();
                            }
                        }
                    }

                    // Escritorios configurables (1..N, por defecto 9). Cada
                    // indicador resume las apps abiertas en ese escritorio.
                    Repeater {
                        model: SettingsState.workspaceIds

                        delegate: WorkspacePill {
                            required property int modelData

                            workspaceId: modelData
                            compact: SettingsState.barVertical
                            Layout.alignment: Qt.AlignHCenter
                            onAppMenuRequested: (anchorItem, app) => {
                                bar.openAppMenu(anchorItem, app);
                            }
                            onInteracted: bar.closePanels()
                        }
                    }
                    }
                }

                // ------------------------------------------------------------- centro
                Pill {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: SettingsState.barVertical
                    horizontalPadding: SettingsState.barVertical ? 2 : 6
                    active: CalendarState.open
                    alert: AlarmState.sounding
                    onClicked: {
                        NotificationState.hidePanel();
                        LauncherState.hide();
                        AlarmState.stop();
                        CalendarState.toggle();
                    }

                    Row {
                        id: clockContent

                        visible: !SettingsState.barVertical

                        // Altura de la línea superior (hora y número del día)
                        // y de la inferior (día de la semana).
                        readonly property int topLine: 20
                        readonly property int bottomLine: 9
                        readonly property int contentHeight: topLine + bottomLine
                        // El lado derecho lleva tres filas: día, mes y año.
                        // Suman el mismo alto que el lado izquierdo para que
                        // ambos bloques queden centrados en la píldora.
                        readonly property int dayLine: 13
                        readonly property int smallLine: 8

                        spacing: 6

                        // Hora arriba y día de la semana debajo. La línea de
                        // abajo empieza a la misma altura que el mes.
                        Item {
                            id: clockLeft

                            width: Math.max(clockTime.implicitWidth,
                                clockWeekday.implicitWidth)
                            height: clockContent.contentHeight

                            Text {
                                id: clockTime

                                width: parent.width
                                height: clockContent.topLine
                                text: Qt.formatDateTime(clock.date, "HH:mm")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                font.weight: Font.DemiBold
                                font.letterSpacing: -0.4
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                id: clockWeekday

                                y: clockContent.topLine
                                width: parent.width
                                height: clockContent.bottomLine
                                text: Fechas.weekdayName(clock.date).toUpperCase()
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.05
                                horizontalAlignment: Text.AlignRight
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            width: 1
                            height: clockContent.contentHeight
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.borderStrong
                        }

                        // Tres filas: día arriba, mes en medio y año abajo,
                        // como la pila original pero sin aire de más.
                        Item {
                            id: clockDate

                            readonly property real yearWidth:
                                clockYear.implicitWidth
                            readonly property real monthWidth:
                                clockMonth.implicitWidth

                            width: Math.max(clockDay.implicitWidth,
                                Math.max(monthWidth, yearWidth))
                            height: clockContent.contentHeight

                            Text {
                                id: clockDay

                                width: parent.width
                                height: clockContent.dayLine
                                text: clock.date.getDate()
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                id: clockMonth

                                y: clockContent.dayLine
                                width: parent.width
                                height: clockContent.smallLine
                                text: Fechas.monthNameShort(clock.date).toUpperCase()
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.9
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                id: clockYear

                                y: clockContent.dayLine + clockContent.smallLine
                                width: parent.width
                                height: clockContent.smallLine
                                text: String(clock.date.getFullYear())
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.9
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    // Reloj compacto: en una barra de 44 px solo caben la
                    // hora y el día abreviado.
                    Column {
                        visible: SettingsState.barVertical
                        spacing: 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clock.date, "HH:mm")
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            font.letterSpacing: -0.3
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Fechas.weekdayName(clock.date)
                                .substr(0, 3).toUpperCase()
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 7
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.4
                        }
                    }
                }


                // Estado: controles, batería, bandeja y accesos.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridLayout {
                            x: bar.vertical
                            ? (parent.width - width) / 2
                            : parent.width - width
                        y: bar.vertical
                            ? parent.height - height
                            : (parent.height - height) / 2
                        columns: bar.vertical ? 1 : 99
                        columnSpacing: 0
                        rowSpacing: bar.vertical ? 2 : 0
                        width: implicitWidth
                        height: implicitHeight

                        // Controles añadidos desde el centro de control.
                        Repeater {
                            id: controlRepeater

                            model: BarState.controls

                            delegate: Loader {
                                required property int index

                                readonly property string controlKey: BarState.controls[index] || ""

                                // El ancho de la música cambia en caliente
                                // (asa de estirado). Sin estas preferencias el
                                // RowLayout conserva el tamaño del primer
                                // montaje y la píldora no se ensancha hasta
                                // recargar el archivo.
                                Layout.preferredWidth: item
                                    ? item.implicitWidth : 0
                                Layout.preferredHeight: item
                                    ? item.implicitHeight : 0
                                Layout.alignment: SettingsState.barVertical
                                    ? Qt.AlignHCenter : Qt.AlignVCenter

                                sourceComponent: controlKey === "music"
                                    ? musicWidget : controlWidget

                                onLoaded: {
                                    if (item && controlKey !== "music")
                                        item.key = controlKey;
                                    }
                                }
                            }

                            Component {
                                id: controlWidget

                                BarControl {}
                            }

                            Component {
                                id: musicWidget

                                BarMusic {}
                            }

                            // Batería / energía. En un equipo sin batería sigue
                            // visible con el rayo de corriente; en un portátil
                            // muestra el nivel real. Al pulsarla se abren los
                            // perfiles de energía.
                            Pill {
                                id: batteryButton
                                Layout.alignment: SettingsState.barVertical
                                    ? Qt.AlignHCenter : Qt.AlignVCenter

                                active: BatteryState.open
                                horizontalPadding: 3
                                onClicked: {
                                    const point = batteryButton.mapToItem(
                                        bar.contentItem, 0, 0);
                                    BatteryState.anchorX = point.x
                                        + batteryButton.width / 2;
                                    BatteryState.anchorY = point.y
                                        + batteryButton.height / 2;
                                    bar.closeAppMenu();
                                    BatteryState.toggle();
                                }

                                Row {
                                    spacing: 4

                                    BatteryGlyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        iconSize: SettingsState.barIconSize
                                        percentage: BatteryState.level
                                        present: BatteryState.present
                                        charging: BatteryState.charging
                                        mains: BatteryState.mains
                                        tone: BatteryState.tone
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: BatteryState.present
                                            && SettingsState.showBatteryPercent
                                            && !SettingsState.barVertical
                                        text: BatteryState.level + "%"
                                        color: BatteryState.tone
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 250
                                                easing.type: Easing.OutQuad
                                            }
                                        }
                                    }
                                }
                            }

                            // Bandeja del sistema: los iconos de las apps se
                            // agrupan en TrayPanel para no llenar la barra.
                            Pill {
                                id: trayButton
                                Layout.alignment: SettingsState.barVertical
                                    ? Qt.AlignHCenter : Qt.AlignVCenter

                                visible: SystemTray.items
                                    && SystemTray.items.values.length > 0
                                active: TrayState.open
                                horizontalPadding: 3

                                onClicked: {
                                    const point = trayButton.mapToItem(
                                        bar.contentItem, 0, 0);
                                    TrayState.anchorX = point.x
                                        + trayButton.width / 2;
                                    TrayState.anchorY = point.y
                                        + trayButton.height / 2;
                                    if (!TrayState.open)
                                        bar.closeAppMenu();
                                    TrayState.toggle();
                                }

                                Item {
                                    width: SettingsState.barIconSize
                                    height: SettingsState.barIconSize

                                    ShellIcon {
                                        anchors.centerIn: parent
                                        source: ShellIcons.src("chevron-up")
                                        color: TrayState.open
                                            ? Theme.accent : Theme.accentFaded
                                        size: Math.min(18, SettingsState.barIconSize)
                                        normalize: true
                                        // La flecha apunta hacia dentro de la
                                        // pantalla según el lado de la barra.
                                        rotation: SettingsState.barVertical
                                            ? (SettingsState.barAtLeft ? 90 : -90)
                                            : (SettingsState.barAtTop ? 180 : 0)
                                        fallback: "^"
                                    }
                                }
                            }

                            // Centro de control con icono propio. Solo aparece
                            // cuando los paneles están separados en los ajustes.
                            Pill {
                                id: controlButton
                                Layout.alignment: SettingsState.barVertical
                                    ? Qt.AlignHCenter : Qt.AlignVCenter

                                visible: !SettingsState.unifiedPanels
                                active: NotificationState.panelOpen
                                    && NotificationState.panelSection === "control"
                                horizontalPadding: 3

                                onClicked: {
                                    CalendarState.hide();
                                    LauncherState.hide();
                                    PowerState.hide();
                                    NotificationState.toggleSection("control");
                                }

                                Item {
                                    width: SettingsState.barIconSize
                                    height: SettingsState.barIconSize

                                    ShellIcon {
                                        anchors.centerIn: parent
                                        source: ShellIcons.src("grid")
                                        color: controlButton.active
                                            ? Theme.accent : Theme.accentFaded
                                        size: SettingsState.barIconSize
                                        normalize: true
                                        fallback: "▦"
                                    }
                                }
                            }

                            // Campana / notificaciones
                            Pill {
                                Layout.alignment: SettingsState.barVertical
                                    ? Qt.AlignHCenter : Qt.AlignVCenter
                                active: (NotificationState.panelOpen
                                        && NotificationState.panelSection !== "control")
                                    || NotificationState.count > 0
                                horizontalPadding: 3
                                onClicked: {
                                    CalendarState.hide();
                                    LauncherState.hide();
                                    PowerState.hide();
                                    NotificationState.togglePanel();
                                }

                                Row {
                                    spacing: 0

                                    // El icono ocupa una caja cuadrada y el punto de
                                    // aviso va en su esquina, como en las apps.
                                    Item {
                                        width: SettingsState.barIconSize
                                        height: SettingsState.barIconSize

                                        ShellIcon {
                                            anchors.centerIn: parent
                                            source: ShellIcons.src(NotificationState.dnd
                                                ? "bell-off" : "bell")
                                            color: NotificationState.dnd
                                                ? Theme.danger
                                                : (((NotificationState.panelOpen
                                                    && NotificationState.panelSection
                                                        !== "control")
                                                    || NotificationState.count > 0)
                                                    ? Theme.accent : Theme.accentFaded)
                                            size: SettingsState.barIconSize
                                            normalize: true
                                            fallback: "!"
                                        }

                                        Rectangle {
                                            width: 7
                                            height: 7
                                            radius: 4
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.topMargin: -1
                                            anchors.rightMargin: -1
                                            color: NotificationState.dnd
                                                ? Theme.danger
                                                : (DependencyState.hasMissing
                                                    ? Theme.warning : Theme.accent)
                                            border.width: 1
                                            border.color: Theme.glass
                                            visible: NotificationState.count > 0
                                                || DependencyState.hasMissing
                                        }
                                    }
                                }
                            }

                            // Menú de energía
                            Pill {
                                Layout.alignment: SettingsState.barVertical
                                    ? Qt.AlignHCenter : Qt.AlignVCenter
                                active: PowerState.open
                                onClicked: {
                                    CalendarState.hide();
                                    LauncherState.hide();
                                    NotificationState.hidePanel();
                                    PowerState.toggle();
                                }

                                Item {
                                    width: SettingsState.barIconSize
                                    height: SettingsState.barIconSize

                                    ShellIcon {
                                        anchors.centerIn: parent
                                        source: ShellIcons.src("power")
                                        color: Theme.accent
                                        size: SettingsState.barIconSize
                                        fallback: "⏻"
                                    }
                                }
                            }
                    }
                }
            }

            // Marca de inserción mientras se reordena un control de la barra.
            Rectangle {
                x: bar.vertical ? 7 : bar.reorderX - 1
                y: bar.vertical ? bar.reorderX - 1 : 7
                width: bar.vertical ? parent.width - 14 : 3
                height: bar.vertical ? 3 : parent.height - 14
                radius: 1
                color: Theme.accent
                z: 19
                visible: ControlDrag.active && ControlDrag.origin === "bar"
                    && ControlDrag.overBar && bar.reorderX >= 0
            }

            // La posición del cursor llega por sondeo; se traduce a una posición
            // de inserción dentro de la fila de controles.
            Connections {
                target: ControlDrag

                function onCursorXChanged() {
                    bar.updateReorderTarget();
                }
                function onOverBarChanged() {
                    bar.updateReorderTarget();
                }
                function onOriginChanged() {
                    bar.updateReorderTarget();
                }
                function onActiveChanged() {
                    if (!ControlDrag.active) {
                        ControlDrag.targetIndex = -1;
                        bar.reorderX = -1;
                    } else {
                        bar.updateReorderTarget();
                    }
                }
            }

            // Aviso de destino mientras se arrastra un control desde el panel.
            Rectangle {
                anchors.centerIn: parent
                z: 20
                visible: ControlDrag.active && ControlDrag.origin === "center"
                    && ControlDrag.overBar
                implicitWidth: dropLabel.implicitWidth + 20
                implicitHeight: 26
                radius: 13
                color: Theme.accent

                Text {
                    id: dropLabel
                    anchors.centerIn: parent
                    text: "Suelta para añadir a la barra"
                    color: Theme.accentInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }

            // Menú contextual de un icono de app. Vive en la ventana de la barra
            // para poder anclarse a la ficha y abrirse por encima de ella.
            AppContextMenu {
                id: appMenu

                app: bar.appMenuApp
                targetScreen: bar.screen
                anchorX: bar.appMenuX
                anchorY: bar.appMenuY

                onDismissed: {
                    // No se limpia la app de inmediato: el menú aún se está
                    // ocultando y sus bindings se están actualizando.
                    clearMenuTimer.restart();
                }
            }
        } // barSurface

        // Franja invisible en el borde donde vive la barra que la revela
        // cuando está oculta. Solo está activa en ese estado.
        MouseArea {
            id: revealArea

            anchors {
                left: bar.vertical
                    ? (SettingsState.barAtLeft ? parent.left : undefined)
                    : parent.left
                right: bar.vertical
                    ? (SettingsState.barAtRight ? parent.right : undefined)
                    : parent.right
                top: bar.vertical || SettingsState.barAtTop
                    ? parent.top : undefined
                bottom: bar.vertical || !SettingsState.barAtTop
                    ? parent.bottom : undefined
            }
            width: bar.vertical ? bar.revealHeight : undefined
            height: bar.vertical ? undefined : bar.revealHeight
            z: 100
            hoverEnabled: true
            enabled: bar.autoHide
            cursorShape: Qt.PointingHandCursor
            onEntered: bar.showBar()
            onExited: bar.scheduleHide()
            onClicked: bar.showBar()
        }

        // Capa transparente que cierra los paneles y el menú de apps al pulsar
        // fuera del shell. Deja libre la franja de la barra para que un clic en
        // otro widget abra su panel directamente, sin cerrar el anterior.
        PanelWindow {
            id: outsideCatcher

            screen: bar.screen
            visible: appMenu.visible || NotificationState.panelOpen
                || QuickPanelState.open
                || CalendarState.open || PowerState.open
                || BatteryState.open || TrayState.open
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            focusable: false

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "shell-outside-close"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Solo recibe clics fuera de la barra; su franja de revelado sigue
            // siendo de la barra.
            mask: Region {
                x: bar.vertical
                    ? (SettingsState.barAtLeft
                        ? Theme.edge + Theme.barHeight + 6 : 0)
                    : 0
                y: bar.vertical ? 0
                    : (SettingsState.barAtTop
                        ? Theme.edge + Theme.barHeight + 6 : 0)
                width: bar.vertical
                    ? Math.max(0, outsideCatcher.width
                        - (Theme.edge + Theme.barHeight + 6))
                    : outsideCatcher.width
                height: bar.vertical
                    ? outsideCatcher.height
                    : Math.max(0, outsideCatcher.height
                        - (Theme.edge + Theme.barHeight + 6))
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: bar.closePanels()
            }
        }

    }
}
