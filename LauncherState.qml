pragma Singleton

import Quickshell

Singleton {
    property bool open: false

    function toggle(): void {
        TrayState.hide();
        BatteryState.hide();
        if (!open) {
            CalendarState.hide();
            NotificationState.hidePanel();
            PowerState.hide();
        }
        open = !open;
    }

    function show(): void {
        TrayState.hide();
        BatteryState.hide();
        CalendarState.hide();
        NotificationState.hidePanel();
        PowerState.hide();
        open = true;
    }

    function hide(): void {
        open = false;
    }
}
