//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQml

ShellRoot {
    // Va antes que la barra para quedar debajo de ella dentro de la misma capa.
    Wallpaper {}
    DesktopIcons {}
    DisplayFilter {}
    Bar {}
    Launcher {}
    SidePanel {}
    CalendarPanel {}
    PowerMenu {}
    BatteryPanel {}
    TrayPanel {}
    Osd {}

    // Fase 3: controles de ventana al mantener Super, barra de título por
    // ventana y elección inicial del modo de escritorio. El cambio de modo
    // vive en el icono del escritorio activo, no en una barra aparte.
    WindowChrome {}
    WelcomeMode {}
    WorkspacePicker {}

    // El botón «Mover» de la barra de título nativa pide el selector 1–9.
    Connections {
        target: CompositorState

        function onMoveMenuSerialChanged(): void {
            if (CompositorState.moveMenuSerial <= 0)
                return;
            MoveMenuState.show(CompositorState.moveMenuWindow,
                CompositorState.moveMenuX, CompositorState.moveMenuY);
        }

        // La vista general de Umbriel ocupa toda la pantalla. Al abrirse se
        // retiran los paneles del shell para no dejarlos flotando encima.
        function onOverviewOpenChanged(): void {
            if (!CompositorState.overviewOpen)
                return;
            LauncherState.hide();
            NotificationState.hidePanel();
            QuickPanelState.hide();
            CalendarState.hide();
            PowerState.hide();
            BatteryState.hide();
            MoveMenuState.hide();
            TrayState.hide();
            SuperState.hide();
        }
    }

    // La bandeja se abre encima de sus iconos: cualquier otro panel que
    // estuviera abierto se retira para no apilar ventanas.
    Connections {
        target: TrayState

        function onOpened(): void {
            LauncherState.hide();
            NotificationState.hidePanel();
            QuickPanelState.hide();
            CalendarState.hide();
            PowerState.hide();
            BatteryState.hide();
            MoveMenuState.hide();
            SuperState.hide();
        }
    }

    // Iconos del escritorio: apertura por indice para pruebas y atajos.
    //   qs ipc -c shell call desktop open 0
    IpcHandler {
        target: "desktop"

        function open(index: string): void {
            DesktopState.openIndex(Number(index));
        }

        function select(index: string): void {
            DesktopState.selectedIndex = Number(index);
        }
    }

    // Cambios de apariencia desde la terminal o desde un atajo:
    //   qs ipc -c shell call appearance toggle
    //   qs ipc -c shell call appearance mode light
    //   qs ipc -c shell call appearance accent "#c9b8f5"
    IpcHandler {
        target: "appearance"

        function toggle(): void {
            SettingsState.setThemeMode(
                SettingsState.themeMode === "light" ? "dark" : "light");
        }

        function mode(value: string): void {
            SettingsState.setThemeMode(value);
        }

        function accent(value: string): void {
            SettingsState.setAccentColor(value);
        }

        // Fondo de pantalla desde la terminal o un atajo:
        //   qs ipc -c shell call appearance wallpaper /ruta/imagen.png
        //   qs ipc -c shell call appearance wallpaperChoose
        //   qs ipc -c shell call appearance wallpaperClear
        function wallpaper(path: string): void {
            SettingsState.setWallpaperPath(path);
        }

        function wallpaperChoose(): void {
            SettingsState.chooseWallpaper();
        }

        function wallpaperClear(): void {
            SettingsState.clearWallpaper();
        }

        //   qs ipc -c shell call appearance wallpaperColor "#141821"
        function wallpaperColor(value: string): void {
            SettingsState.setWallpaperColor(value);
        }

        function wallpaperColorClear(): void {
            SettingsState.clearWallpaperColor();
        }

        // Estilo de barra de ventanas: flotante o integrada.
        //   qs ipc -c shell call appearance chrome integrated
        function chrome(style: string): void {
            SettingsState.setWindowChrome(style);
        }

        // Ciudad del clima; vacío vuelve a la detección por IP.
        //   qs ipc -c shell call appearance weatherPlace Madrid
        function weatherPlace(value: string): void {
            SettingsState.setWeatherPlace(value);
        }
    }

    // Diagnóstico y control de red desde la terminal:
    //   qs ipc -c shell call network status
    //   qs ipc -c shell call network scan
    IpcHandler {
        target: "network"

        function status(): string {
            const devices = Networking.devices.values;
            const list = [];
            let wifiNetworks = 0;
            let wifiScanner = 0;
            for (let i = 0; i < devices.length; i++) {
                const dev = devices[i];
                if (dev.type === DeviceType.Wifi) {
                    wifiNetworks = dev.networks.values.length;
                    wifiScanner = dev.scannerEnabled ? 1 : 0;
                }
                list.push(dev.name + ":" + dev.type + ":"
                    + (dev.connected ? "connected" : "disconnected")
                    + ":managed=" + (dev.nmManaged ? "1" : "0"));
            }
            return "wifiEnabled=" + (Networking.wifiEnabled ? "1" : "0")
                + " airplane=" + (AirplaneState.active ? "1" : "0")
                + " wifiHardwareEnabled=" + (Networking.wifiHardwareEnabled ? "1" : "0")
                + " backend=" + Networking.backend
                + " connectivity=" + Networking.connectivity
                + " nmWifiNetworks=" + wifiNetworks
                + " scanner=" + wifiScanner
                + " ethernet=" + EthernetState.controlLabel
                + " panelOpen=" + (NotificationState.panelOpen ? "1" : "0")
                + " watching=" + (WifiState.watching ? "1" : "0")
                + " scanning=" + (WifiState.scanning ? "1" : "0")
                + " hasScanned=" + (WifiState.hasScanned ? "1" : "0")
                + " state=" + WifiState.deviceState
                + " aps=" + WifiState.accessPoints.length
                + " hidden=" + WifiState.hiddenAccessPoints.length
                + " error=" + WifiState.lastError
                + " devices=" + list.join(",");
        }

        function scan(): string {
            WifiState.watching = true;
            WifiState.hasScanned = false;
            WifiState.requestScan();
            return "scan";
        }

        function stop(): void {
            WifiState.stop();
        }

        function open(): void {
            QuickPanelState.show("wifi", -1);
        }

        function close(): void {
            NotificationState.hidePanel();
        }
    }

    // VPN de NetworkManager desde la terminal o un atajo:
    //   qs ipc -c shell call vpn list
    //   qs ipc -c shell call vpn importFile /ruta/perfil.ovpn
    IpcHandler {
        target: "vpn"

        function refresh(): void {
            VpnState.refresh();
        }

        function importFile(path: string): void {
            VpnState.importOpenVpn(path);
        }

        function toggle(name: string): void {
            VpnState.toggle(name);
        }

        function save(name: string, newName: string, autoconnect: bool): void {
            VpnState.saveProfile(name, newName, autoconnect);
        }

        function remove(name: string): void {
            VpnState.deleteProfile(name);
        }

        function status(): string {
            return VpnState.activeName;
        }

        // Resumen legible para diagnóstico: nombre, tipo, activa y automática.
        function list(): string {
            const out = [];
            for (let i = 0; i < VpnState.profiles.length; i++) {
                const profile = VpnState.profiles[i];
                out.push(profile.name + "|" + profile.type + "|"
                    + (profile.active ? "1" : "0") + "|"
                    + (profile.autoconnect ? "1" : "0"));
            }
            return out.join("\n");
        }
    }

    // Bandeja del sistema desde la terminal o un atajo:
    //   qs ipc -c shell call tray toggle
    IpcHandler {
        target: "tray"

        function toggle(): void {
            TrayState.toggle();
        }

        function hide(): void {
            TrayState.hide();
        }
    }

    // Control del modo ventanas desde Hyprland y desde scripts:
    //   qs ipc -c shell call windows superPress
    //   qs ipc -c shell call windows superRelease
    //   qs ipc -c shell call windows mode 2 mosaic
    //   qs ipc -c shell call windows titlebar integrated
    IpcHandler {
        target: "windows"

        function superPress(): void {
            SuperState.press();
        }

        function superRelease(): void {
            SuperState.release();
        }

        // Respaldo de Umbriel para sesiones sin el evento `modifiers`.
        function superTap(): void {
            SuperState.externalTap();
        }

        function superCancel(): void {
            SuperState.cancel();
        }

        function overlay(value: bool): void {
            if (value)
                SuperState.showPinned();
            else
                SuperState.hide();
        }

        function pinned(): void {
            SuperState.togglePinned();
            SuperState.cancel();
        }

        function mode(workspace: string, value: string): void {
            WorkspaceModeState.setMode(Number(workspace), value);
        }

        function choose(value: string): void {
            WorkspaceModeState.choose(value);
        }

        function defaultMode(value: string): void {
            SettingsState.setWorkspaceModeDefault(value);
            WorkspaceModeState.applyAll();
        }

        function barPosition(value: string): void {
            SettingsState.setBarPosition(value);
        }

        function musicWidth(value: int): void {
            SettingsState.setMusicWidth(value);
        }

        function modHold(value: int): void {
            SettingsState.setSuperHoldMs(value);
        }

        function floatingSize(value: int): void {
            SettingsState.setFloatingSizePercent(value);
        }

        function floatingCascade(value: int): void {
            SettingsState.setFloatingCascade(value);
        }

        function autoHide(value: bool): void {
            SettingsState.setAutoHideBar(value);
        }

        function titlebar(value: string): void {
            // Compatibilidad con los valores antiguos; ahora el ajuste real
            // es el estilo flotante/integrado.
            if (value === "always")
                SettingsState.setWindowChrome("integrated");
            else if (value === "never" || value === "auto")
                SettingsState.setWindowChrome("floating");
            else
                SettingsState.setWindowChrome(value);
        }

        function toggleFocused(): void {
            SuperState.cancel();
            WorkspaceModeState.toggleFocused();
        }

        function moveWindow(address: string, x: string, y: string): void {
            CompositorState.moveWindowTo(address, Number(x), Number(y));
        }

        // Diagnóstico rápido del contrato y de los modos.
        //   qs ipc -c shell call windows status
        function status(): string {
            let text = "titlebar=" + SettingsState.windowChrome
                + " default=" + SettingsState.workspaceModeDefault
                + " chosen=" + (SettingsState.workspaceModeChosen ? "1" : "0")
                + " overlay=" + (SuperState.active ? "1" : "0")
                + " overview=" + (CompositorState.overviewOpen ? "1" : "0")
                + " backend=" + CompositorState.id
                + " available=" + (CompositorState.available ? "1" : "0")
                + " error=" + CompositorState.lastError + "\n";
            const list = CompositorState.windows || [];
            for (let i = 0; i < list.length; i++) {
                text += list[i].appId + " ws=" + list[i].workspaceId
                    + " origin=" + list[i].originWorkspaceId
                    + " float=" + (list[i].floating ? "1" : "0")
                    + " min=" + (list[i].minimized ? "1" : "0")
                    + " focused=" + (list[i].focused ? "1" : "0")
                    + (String(list[i].scratchpad || "").length > 0
                        ? " scratch=" + list[i].scratchpad : "")
                    + "\n";
            }
            return text;
        }
    }
}

