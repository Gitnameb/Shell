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
    // Vista avanzada activa del centro de control ("wifi", "volume", ...).
    property string panelView: ""

    // Hora de llegada de cada aviso (id -> milisegundos). Las notificaciones de
    // D-Bus no traen marca de tiempo, así que la guardamos al recibirlas.
    property var receivedTimes: ({})
    property int clockTick: 0

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

    function togglePanel(): void {
        TrayState.hide();
        BatteryState.hide();
        if (!panelOpen) {
            CalendarState.hide();
            LauncherState.hide();
            PowerState.hide();
        }
        panelOpen = !panelOpen;
    }

    function showPanel(): void {
        TrayState.hide();
        BatteryState.hide();
        CalendarState.hide();
        LauncherState.hide();
        PowerState.hide();
        panelOpen = true;
    }

    function hidePanel(): void {
        panelOpen = false;
    }

    function openPanelView(view: string): void {
        showPanel();
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
        }
    }
}
