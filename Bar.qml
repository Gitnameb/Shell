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

        // Mientras hay música o vídeo, la pantalla no se considera inactiva:
        // swayidle no llega a bloquear. El inhibidor vive en la superficie de
        // la barra, que siempre está mapeada aunque esté oculta.
        IdleInhibitor {
            window: bar
            enabled: MusicState.playing
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

            // Se cuentan los controles cuyo centro queda a la izquierda del
            // cursor, sin contar el que se arrastra. Ese número es la posición
            // final dentro de la lista sin el control.
            let target = 0;
            let marker = -1;
            for (let i = 0; i < list.length; i++) {
                if (i === from)
                    continue;
                const loader = controlRepeater.itemAt(i);
                if (!loader)
                    continue;
                const point = loader.mapToItem(null, 0, 0);
                const center = bar.screen.x + Theme.edge
                    + point.x + loader.width / 2;
                if (ControlDrag.cursorX > center) {
                    target++;
                    marker = point.x + loader.width + 2;
                } else if (marker < 0) {
                    marker = point.x - 2;
                }
            }
            // Si el cursor está a la izquierda de todo, el marcador va delante
            // del primer control; si está a la derecha, detrás del último.
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
            MoveMenuState.hide();
            // mapToItem(null) devuelve coordenadas de la ventana de la barra;
            // se suman el margen y el origen de la pantalla para obtenerlas
            // globales.
            const point = anchorItem.mapToItem(null,
                anchorItem.width / 2, 0);
            clearMenuTimer.stop();
            bar.appMenuApp = app;
            bar.appMenuX = currentScreen.x + Theme.edge + point.x;
            bar.appMenuY = SettingsState.barAtTop
                ? currentScreen.y + Theme.edge + Theme.barHeight + point.y
                : currentScreen.y + currentScreen.height
                    - Theme.edge - Theme.barHeight + point.y;
            appMenu.visible = true;
        }

        function closeAppMenu(): void {
            if (!appMenu.visible && bar.appMenuApp === null)
                return;
            appMenu.visible = false;
            bar.appMenuApp = null;
            clearMenuTimer.stop();
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

        anchors {
            top: SettingsState.barAtTop
            bottom: !SettingsState.barAtTop
            left: true
            right: true
        }
        margins {
            top: SettingsState.barAtTop && !bar.autoHide ? Theme.edge : 0
            bottom: !SettingsState.barAtTop && !bar.autoHide ? Theme.edge : 0
            left: Theme.edge
            right: Theme.edge
        }
        // Con la barra automática la ventana llega hasta el borde de la
        // pantalla para que la franja que revela la barra quede al alcance del
        // puntero. El margen visual se aplica dentro, al contenido.
        implicitHeight: bar.autoHide
            ? Theme.barHeight + Theme.edge : Theme.barHeight
        color: "transparent"
        // Reserva espacio para que las ventanas no queden bajo la barra. Con
        // ocultación automática no reserva nada: la barra aparece por encima.
        exclusiveZone: bar.autoHide ? 0 : Theme.barHeight + Theme.edge

        // ------------------------------------------------- barra automática
        property bool autoHide: SettingsState.autoHideBar
        property bool barHidden: false
        property real barOpacity: bar.barHidden ? 0 : 1
        readonly property int revealHeight: 4
        // Mientras haya un panel, un menú o un arrastre abierto, la barra no
        // se oculta: los paneles se apoyan encima de ella.
        readonly property bool keepVisible: NotificationState.panelOpen
            || CalendarState.open || LauncherState.open || PowerState.open
            || BatteryState.open || TrayState.open || MoveMenuState.open
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
            x: 0
            y: bar.autoHide && bar.barHidden && !SettingsState.barAtTop
                ? bar.height - bar.revealHeight : 0
            width: bar.width
            height: bar.autoHide && bar.barHidden
                ? bar.revealHeight : bar.height
        }

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "alba-bar"

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        // Contenido visual de la barra. Se desvanece al ocultarse y su
        // HoverHandler permite saber si el puntero sigue sobre ella.
        Item {
            id: barSurface

            anchors.fill: parent
            anchors.topMargin: bar.autoHide && SettingsState.barAtTop
                ? Theme.edge : 0
            anchors.bottomMargin: bar.autoHide && !SettingsState.barAtTop
                ? Theme.edge : 0
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

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 0

                // ------------------------------------------------------------ izquierda
                Item {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        // Logo / lanzador
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 8
                            color: Theme.accent

                            AlbaIcon {
                                anchors.centerIn: parent
                                source: Distro.iconSource
                                color: Theme.accentInk
                                size: Math.min(26, SettingsState.barIconSize)
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
                                onAppMenuRequested: (anchorItem, app) => {
                                    bar.openAppMenu(anchorItem, app);
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------- centro
                Pill {
                    Layout.alignment: Qt.AlignVCenter
                    horizontalPadding: 6
                    active: CalendarState.open
                    onClicked: {
                        NotificationState.hidePanel();
                        LauncherState.hide();
                        CalendarState.toggle();
                    }

                    Row {
                        id: clockContent

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
                }

                // ------------------------------------------------------------- derecha
                Item {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

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
                                Layout.alignment: Qt.AlignVCenter

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

                            active: BatteryState.open
                            horizontalPadding: 1
                            onClicked: {
                                const point = batteryButton.mapToItem(
                                    bar.contentItem, 0, 0);
                                BatteryState.anchorX = point.x
                                    + batteryButton.width / 2;
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
                                        && SettingsState.showPercentages
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

                            visible: SystemTray.items
                                && SystemTray.items.values.length > 0
                            active: TrayState.open

                            onClicked: {
                                const point = trayButton.mapToItem(
                                    bar.contentItem, 0, 0);
                                TrayState.anchorX = point.x
                                    + trayButton.width / 2;
                                if (!TrayState.open)
                                    bar.closeAppMenu();
                                TrayState.toggle();
                            }

                            Item {
                                width: SettingsState.barIconSize
                                height: SettingsState.barIconSize

                                AlbaIcon {
                                    anchors.centerIn: parent
                                    source: AlbaIcons.src("chevron-up")
                                    color: TrayState.open
                                        ? Theme.accent : Theme.accentFaded
                                    size: 14
                                    // Con la barra arriba, la flecha apunta
                                    // hacia abajo para alejarse del borde.
                                    rotation: SettingsState.barAtTop ? 180 : 0
                                    fallback: "^"
                                }
                            }
                        }

                        // Campana / notificaciones
                        Pill {
                            active: NotificationState.panelOpen || NotificationState.count > 0
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

                                    AlbaIcon {
                                        anchors.centerIn: parent
                                        source: AlbaIcons.src(NotificationState.dnd
                                            ? "bell-off" : "bell")
                                        color: NotificationState.dnd
                                            ? Theme.danger
                                            : ((NotificationState.panelOpen
                                                || NotificationState.count > 0)
                                                ? Theme.accent : Theme.accentFaded)
                                        size: SettingsState.barIconSize
                                        fallback: "!"
                                    }

                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        color: NotificationState.dnd
                                            ? Theme.danger : Theme.accent
                                        border.width: 2
                                        border.color: Theme.glass
                                        visible: NotificationState.count > 0
                                    }
                                }
                            }
                        }

                        // Menú de energía
                        Pill {
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

                                AlbaIcon {
                                    anchors.centerIn: parent
                                    source: AlbaIcons.src("power")
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
                x: bar.reorderX - 1
                y: 7
                width: 3
                height: parent.height - 14
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
                left: parent.left
                right: parent.right
                top: SettingsState.barAtTop ? parent.top : undefined
                bottom: SettingsState.barAtTop ? undefined : parent.bottom
            }
            height: bar.revealHeight
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
                || CalendarState.open || PowerState.open
                || BatteryState.open
                || MoveMenuState.open || TrayState.open
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
            WlrLayershell.namespace: "alba-outside-close"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Solo recibe clics fuera de la barra; su franja de revelado sigue
            // siendo de la barra.
            mask: Region {
                x: 0
                y: SettingsState.barAtTop
                    ? Theme.edge + Theme.barHeight + 6 : 0
                width: outsideCatcher.width
                height: Math.max(0, outsideCatcher.height
                    - (Theme.edge + Theme.barHeight + 6))
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: {
                    bar.closeAppMenu();
                    NotificationState.hidePanel();
                    CalendarState.hide();
                    PowerState.hide();
                    BatteryState.hide();
                    MoveMenuState.hide();
                    TrayState.hide();
                }
            }
        }

    }
}
