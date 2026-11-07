pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQml.Models

// Estado y servidor de notificaciones. El servidor se registra en D-Bus
// (org.freedesktop.Notifications) mientras el shell está corriendo.
Singleton {
    id: root

    property bool panelOpen: false
    property bool dnd: false
    // Sección visible del panel: "both" (notificaciones y centro de control),
    // "notifications" o "control". El panel rápido de la barra no usa esto.
    property string panelSection: "both"
    // Vista avanzada activa del centro de control ("wifi", "volume", ...).
    property string panelView: ""

    // Hora de llegada de cada aviso (id -> milisegundos). Las notificaciones de
    // D-Bus no traen marca de tiempo, así que la guardamos al recibirlas.
    property var receivedTimes: ({})
    property int clockTick: 0

    // Avisos emergentes que aparecen unos segundos al llegar. Es un ListModel
    // para que insertar uno nuevo no reconstruya los anteriores: así las
    // tarjetas viejas no parpadean con cada aviso.
    ListModel {
        id: bannerList
    }
    // Expuesto para las tarjetas y el diagnóstico; el id interno no sale del
    // singleton.
    readonly property alias bannerModel: bannerList
    property int bannerSerial: 0

    readonly property var items: server.trackedNotifications.values
    readonly property int count: items ? items.length : 0
    readonly property var latest: count > 0 ? items[count - 1] : null

    // Lista normalizada y ordenada de la más reciente a la más antigua.
    readonly property var entries: {
        const list = items ? items.slice() : [];
        const times = receivedTimes;
        list.sort((a, b) => {
            const ta = times[a.id] || a.id;
            const tb = times[b.id] || b.id;
            return tb - ta;
        });
        return list.map((n) => ({
            id: n.id,
            appName: n.appName || n.desktopEntry || "Sistema",
            appKey: (n.desktopEntry || n.appName || "sistema").toLowerCase(),
            desktopEntry: n.desktopEntry || "",
            icon: n.appIcon || n.desktopEntry || "",
            summary: n.summary || "",
            body: n.body || "",
            stamp: times[n.id] || 0,
            notification: n
        }));
    }

    // Avisos agrupados por app. El grupo conserva el aviso más reciente como
    // titular y el resto se despliega dentro.
    readonly property var groups: {
        const list = entries;
        const byKey = ({});
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const entry = list[i];
            let group = byKey[entry.appKey];
            if (!group) {
                group = {
                    appKey: entry.appKey,
                    appName: entry.appName,
                    icon: entry.icon,
                    latest: entry,
                    items: []
                };
                byKey[entry.appKey] = group;
                out.push(group);
            }
            group.items.push(entry);
            if (!group.icon && entry.icon)
                group.icon = entry.icon;
        }
        return out;
    }

    function timeLabel(stamp): string {
        if (!stamp)
            return "";
        const date = new Date(stamp);
        const now = new Date();
        const hm = String(date.getHours()).padStart(2, "0")
            + ":" + String(date.getMinutes()).padStart(2, "0");
        if (date.toDateString() === now.toDateString())
            return hm;
        const yesterday = new Date(now);
        yesterday.setDate(now.getDate() - 1);
        if (date.toDateString() === yesterday.toDateString())
            return "Ayer " + hm;
        return String(date.getDate()).padStart(2, "0")
            + "/" + String(date.getMonth() + 1).padStart(2, "0") + " " + hm;
    }

    function countLabel(value): string {
        return value === 1 ? "1 notificación" : value + " notificaciones";
    }

    function dismissGroup(group): void {
        if (!group || !group.items)
            return;
        const list = group.items.slice();
        for (let i = list.length - 1; i >= 0; i--)
            list[i].notification.dismiss();
    }

    // Abre el panel con la sección indicada. Sin argumento usa la preferencia
    // del usuario: ambos juntos o solo las notificaciones.
    function showSection(section: string): void {
        const value = section === "notifications" || section === "control"
            ? section : "both";
        TrayState.hide();
        BatteryState.hide();
        CalendarState.hide();
        LauncherState.hide();
        PowerState.hide();
        panelView = "";
        panelSection = value;
        panelOpen = true;
        QuickPanelState.hide();
    }

    function toggleSection(section: string): void {
        const value = section === "notifications" || section === "control"
            ? section : "both";
        if (panelOpen && panelSection === value) {
            hidePanel();
            return;
        }
        showSection(value);
    }

    function togglePanel(): void {
        toggleSection(SettingsState.unifiedPanels ? "both" : "notifications");
    }

    function showPanel(): void {
        showSection(SettingsState.unifiedPanels ? "both" : "notifications");
    }

    function hidePanel(): void {
        panelOpen = false;
        panelView = "";
        panelSection = "both";
    }

    function openPanelView(view: string): void {
        // Las vistas avanzadas viven en el centro de control. Con los paneles
        // separados se abre esa sección; con el panel unificado, ambas.
        showSection(SettingsState.unifiedPanels ? "both" : "control");
        panelView = view;
    }

    function dismiss(notification): void {
        if (notification)
            notification.dismiss();
    }

    function clearAll(): void {
        const list = items;
        if (!list)
            return;
        for (let i = list.length - 1; i >= 0; i--)
            list[i].dismiss();
    }

    // ------------------------------------------------- avisos emergentes
    // Índice de una tarjeta por su clave o por el id del aviso.
    function bannerIndex(key): int {
        for (let i = 0; i < bannerList.count; i++) {
            if (Number(bannerList.get(i).key) === Number(key))
                return i;
        }
        return -1;
    }

    function bannerIndexForId(id): int {
        for (let i = 0; i < bannerList.count; i++) {
            if (Number(bannerList.get(i).notifId) === Number(id))
                return i;
        }
        return -1;
    }

    // Añade una tarjeta al principio. Si la app reemplaza el aviso con el
    // mismo id, la anterior se sustituye en lugar de duplicarse.
    function showBanner(notification): void {
        if (!notification || root.panelOpen || root.dnd)
            return;
        const id = Number(notification.id);
        const existing = root.bannerIndexForId(id);
        if (existing >= 0)
            bannerList.remove(existing, 1);
        bannerList.insert(0, {
            key: ++root.bannerSerial,
            notifId: id,
            appName: notification.appName
                || notification.desktopEntry || "Sistema",
            appKey: String(notification.desktopEntry
                || notification.appName || "sistema").toLowerCase(),
            desktopEntry: notification.desktopEntry || "",
            icon: notification.appIcon || notification.desktopEntry || "",
            summary: notification.summary || "",
            body: notification.body || "",
            // 0 significa «no caduca»; -1 deja que el servidor decida y usa
            // el tiempo normal de la tarjeta.
            persistent: Number(notification.expireTimeout) === 0,
            timeout: Number(notification.expireTimeout) > 0
                ? Number(notification.expireTimeout) : 5000,
            urgency: Number(notification.urgency) || 0,
            stamp: Date.now()
        });
        while (bannerList.count > 3)
            bannerList.remove(bannerList.count - 1, 1);
    }

    function removeBanner(key): void {
        const index = root.bannerIndex(key);
        if (index >= 0)
            bannerList.remove(index, 1);
    }

    // Cerrar la tarjeta descarta también el aviso del historial, igual que
    // el botón de cerrar de otras distros; así una alarma deja de sonar.
    function dismissBanner(key): void {
        const index = root.bannerIndex(key);
        if (index < 0)
            return;
        const id = Number(bannerList.get(index).notifId);
        bannerList.remove(index, 1);
        const list = items || [];
        for (let i = 0; i < list.length; i++) {
            if (Number(list[i].id) === id) {
                list[i].dismiss();
                break;
            }
        }
    }

    function clearBanners(): void {
        if (bannerList.count > 0)
            bannerList.clear();
    }

    // Si el aviso desaparece por otra vía (panel, app o reemplazo), su
    // tarjeta tampoco debe quedarse colgada.
    function pruneBanners(): void {
        if (bannerList.count === 0)
            return;
        const live = items || [];
        const present = ({});
        for (let i = 0; i < live.length; i++)
            present[String(live[i].id)] = true;
        for (let i = bannerList.count - 1; i >= 0; i--) {
            if (present[String(bannerList.get(i).notifId)] !== true)
                bannerList.remove(i, 1);
        }
    }

    onDndChanged: {
        if (root.dnd)
            root.clearBanners();
    }

    onPanelOpenChanged: {
        if (root.panelOpen)
            root.clearBanners();
    }

    onItemsChanged: root.pruneBanners()

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.clockTick++
    }

    NotificationServer {
        id: server

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true

        onNotification: (notification) => {
            if (root.dnd) {
                notification.tracked = false;
                return;
            }
            const times = Object.assign({}, root.receivedTimes);
            times[notification.id] = Date.now();
            root.receivedTimes = times;
            notification.tracked = true;
            // Tras recargar el shell, keepOnReload vuelve a emitir el historial:
            // esos avisos no deben aparecer como si acabaran de llegar.
            if (notification.lastGeneration === true)
                return;
            root.showBanner(notification);
        }
    }
}
