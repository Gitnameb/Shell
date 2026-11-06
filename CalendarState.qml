pragma Singleton

import Quickshell

Singleton {
    property bool open: false

    function toggle(): void {
        TrayState.hide();
        BatteryState.hide();
        if (!open) {
            NotificationState.hidePanel();
            LauncherState.hide();
            PowerState.hide();
        }
        open = !open;
    }

    function show(): void {
        TrayState.hide();
        BatteryState.hide();
        NotificationState.hidePanel();
        LauncherState.hide();
        PowerState.hide();
        open = true;
    }

    function hide(): void {
        open = false;
    }
}
