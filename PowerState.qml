pragma Singleton

import Quickshell

Singleton {
    property bool open: false

    function toggle(): void {
        TrayState.hide();
        BatteryState.hide();
        if (!open) {
            CalendarState.hide();
            LauncherState.hide();
            NotificationState.hidePanel();
        }
        open = !open;
    }

    function hide(): void {
        open = false;
    }
}
