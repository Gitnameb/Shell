pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

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

    // Avisos emergentes que aparecen unos segundos al llegar. Es una lista
    // corta: los tres más recientes. Cada entrada guarda lo necesario para
    // pintar la tarjeta sin volver a consultar el servidor.
    property var banners: []
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
    // Añade una tarjeta al principio. Si la app reemplaza el aviso con el
    // mismo id, la anterior se sustituye en lugar de duplicarse.
    function showBanner(notification): void {
        if (!notification || root.panelOpen || root.dnd)
            return;
        const id = notification.id;
        const entry = {
            key: ++root.bannerSerial,
            id: id,
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
            stamp: Date.now(),
            notification: notification
        };
        const list = root.banners.slice();
        for (let i = list.length - 1; i >= 0; i--) {
            if (list[i].id === id)
                list.splice(i, 1);
        }
        list.unshift(entry);
        while (list.length > 3)
            list.pop();
        root.banners = list;
    }

    function removeBanner(key): void {
        const list = root.banners || [];
        const out = [];
        let changed = false;
        for (let i = 0; i < list.length; i++) {
            if (list[i].key === key)
                changed = true;
            else
                out.push(list[i]);
        }
        if (changed)
            root.banners = out;
    }

    // Cerrar la tarjeta descarta también el aviso del historial, igual que
    // el botón de cerrar de otras distros; así una alarma deja de sonar.
    function dismissBanner(key): void {
        const list = root.banners || [];
        let notification = null;
        for (let i = 0; i < list.length; i++) {
            if (list[i].key === key) {
                notification = list[i].notification;
                break;
            }
        }
        root.removeBanner(key);
        if (notification)
            notification.dismiss();
    }

    function clearBanners(): void {
        if (root.banners.length > 0)
            root.banners = [];
    }

    // Si el aviso desaparece por otra vía (panel, app o reemplazo), su
    // tarjeta tampoco debe quedarse colgada.
    function pruneBanners(): void {
        const list = root.banners || [];
        if (list.length === 0)
            return;
        const live = items || [];
        const present = ({});
        for (let i = 0; i < live.length; i++)
            present[String(live[i].id)] = true;
        const out = [];
        let changed = false;
        for (let i = 0; i < list.length; i++) {
            if (present[String(list[i].id)] === true)
                out.push(list[i]);
            else
                changed = true;
        }
        if (changed)
            root.banners = out;
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
