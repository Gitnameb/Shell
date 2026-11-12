//@ pragma UseQApplication

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import QtQml

ShellRoot {
    id: shellRoot

    // Cierra todo lo que el usuario haya desplegado desde la barra. Se usa al
    // enfocar una ventana o al mantener Super: ambas cosas son interacción con
    // algo distinto del propio panel.
    //
    // Al pulsar Super no se cierra el lanzador, porque ese mismo gesto puede
    // ser un toque que lo abre o lo cierra. Se cierra cuando Super se mantiene
    // de verdad, en la conexión con SuperState.active.
    function closeShellPanels(includeLauncher): void {
        // Mientras se captura un atajo, Super forma parte de la combinación y
        // no debe cerrar el panel que está escuchando.
        if (QuickPanelState.micCapturing)
            return;
        if (includeLauncher !== false)
            LauncherState.hide();
        NotificationState.hidePanel();
        QuickPanelState.hide();
        CalendarState.hide();
        PowerState.hide();
        BatteryState.hide();
        TrayState.hide();
        windowVolumePopup.hide();
    }

    // BlueZ enciende el adaptador al arrancar (AutoEnable=true) y no recuerda
    // que el usuario lo apagó. Se reaplica la intención guardada; el modo
    // avión manda y no se toca mientras esté activo.
    function applyBluetoothPreference(): void {
        if (!SettingsState.ready || AirplaneState.active)
            return;
        const adapter = Bluetooth.defaultAdapter;
        if (adapter !== null && adapter.enabled !== SettingsState.btEnabled)
            adapter.enabled = SettingsState.btEnabled;
    }

    // Va antes que la barra para quedar debajo de ella dentro de la misma capa.
    Wallpaper {}
    DesktopIcons {}
    Bar {}
    Launcher {}
    SidePanel {}
    CalendarPanel {}
    PowerMenu {}
    BatteryPanel {}
    TrayPanel {}
    Osd {}
    NotificationPopup {}
    WindowVolumePopup {
        id: windowVolumePopup
    }

    // Fase 3: controles de ventana al mantener Super y barra de título por
    // ventana. El cambio de modo vive en el icono del escritorio activo, no en
    // una barra aparte.
    //
    // El botón de volumen de la barra de título nativa abre su tarjeta.
    Connections {
        target: CompositorState

        function onWindowVolumeSerialChanged(): void {
            if (CompositorState.windowVolumeSerial <= 0)
                return;
            windowVolumePopup.show(CompositorState.windowVolumeId,
                CompositorState.windowVolumeX, CompositorState.windowVolumeY);
        }

        // Respaldo del captador de clics: si una ventana recibe el foco
        // mientras hay un panel abierto, el panel se retira. Cubre también los
        // clics que llegan por una capa nativa en vez de por la barra.
        function onFocusedWindowChanged(): void {
            if (!CompositorState.focusedWindow)
                return;
            shellRoot.closeShellPanels();
        }

        // Mantener Super para señalar una ventana es interactuar con otra cosa:
        // el panel se cierra antes de que llegue el enfoque por hover. Así el
        // foco no queda retenido por el teclado del panel.
        function onModHeldChanged(): void {
            if (CompositorState.modHeld)
                shellRoot.closeShellPanels(false);
        }

        // La vista general de Umbriel ocupa toda la pantalla. Al abrirse se
        // retiran los paneles del shell para no dejarlos flotando encima.
        function onOverviewOpenChanged(): void {
            if (!CompositorState.overviewOpen)
                return;
            NotificationState.clearBanners();
            SuperState.hide();
            shellRoot.closeShellPanels();
        }
    }

    // Mantener Super sí retira el lanzador: ya no es un toque para abrirlo,
    // sino el gesto de gestión de ventanas.
    Connections {
        target: SuperState

        function onActiveChanged(): void {
            if (SuperState.active)
                LauncherState.hide();
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

    // Letras del widget de música:
    //   qs ipc -c shell call lyrics toggle
    //   qs ipc -c shell call lyrics enable true
    //   qs ipc -c shell call lyrics refresh
    IpcHandler {
        target: "lyrics"

        function toggle(): void {
            SettingsState.lyricsEnabled = !SettingsState.lyricsEnabled;
        }

        function enable(value: string): void {
            SettingsState.lyricsEnabled =
                value === "1" || value === "true";
        }

        function refresh(): void {
            LyricsState.checked = false;
            LyricsState.request(MusicState.trackUrl);
        }
    }

    // Alarmas y temporizador:
    //   qs ipc -c shell call alarm stop
    IpcHandler {
        target: "alarm"

        function stop(): void {
            AlarmState.stop();
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

        // Cristal del shell desde la terminal:
        //   qs ipc -c shell call appearance glass 22 16
        // El primer valor es la transparencia (0-90) y el segundo el radio de
        // desenfoque del shell (0-40; 0 lo apaga).
        function glass(transparency: string, blurRadius: string): void {
            if (transparency !== "")
                SettingsState.setGlassTransparency(Number(transparency));
            if (blurRadius !== "")
                SettingsState.setGlassBlur(Number(blurRadius));
        }

        // Qué desenfoca el cristal:
        //   qs ipc -c shell call appearance glassMode simple|fondo
        // «fondo» usa la caché del fondo de pantalla; «simple» desenfoca el
        // contenido real que hay detrás.
        function glassMode(mode: string): void {
            if (mode === "simple" || mode === "behind"
                    || mode === "contenido")
                SettingsState.setGlassBlurBehind(true);
            else if (mode === "wallpaper" || mode === "fondo")
                SettingsState.setGlassBlurBehind(false);
        }

        // Transparencia y desenfoque de las ventanas:
        //   qs ipc -c shell call appearance windows 15 12 simple
        // El primer valor es la transparencia (0-90; 0 las deja opacas), el
        // segundo el radio (0-40) y el tercero el tipo (simple|fondo).
        function windows(transparency: string, blurRadius: string,
                mode: string): void {
            if (transparency !== "")
                SettingsState.setWindowTransparency(Number(transparency));
            if (blurRadius !== "")
                SettingsState.setWindowBlur(Number(blurRadius));
            if (mode === "simple" || mode === "behind"
                    || mode === "contenido")
                SettingsState.setWindowBlurBehind(true);
            else if (mode === "fondo" || mode === "wallpaper")
                SettingsState.setWindowBlurBehind(false);
        }

        // Sincronizar las ventanas con los valores del shell:
        //   qs ipc -c shell call appearance windowsSync 1
        function windowsSync(value: string): void {
            SettingsState.setWindowSync(
                value === "1" || value === "true");
        }

        // Diagnóstico del cristal y de las ventanas.
        function glassStatus(): string {
            return "ready=" + (SettingsState.ready ? "1" : "0")
                + " script=" + SettingsState.glassScript
                + " transparency=" + SettingsState.glassTransparency
                + " blur=" + SettingsState.glassBlur
                + " blurMode=" + (SettingsState.glassBlurBehind
                    ? "simple" : "fondo")
                + " windowTransparency="
                + SettingsState.effectiveWindowTransparency
                + " windowBlur=" + SettingsState.effectiveWindowBlur
                + " windowBlurMode="
                + (SettingsState.effectiveWindowBlurBehind
                    ? "simple" : "fondo")
                + " windowSync=" + (SettingsState.windowSync ? "1" : "0");
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

    // Los ajustes pueden terminar de cargar antes o después de que aparezca
    // el adaptador Bluetooth; se intenta en ambos casos.
    Connections {
        target: SettingsState

        function onReadyChanged(): void {
            shellRoot.applyBluetoothPreference();
        }
    }

    Connections {
        target: Bluetooth

        function onDefaultAdapterChanged(): void {
            shellRoot.applyBluetoothPreference();
        }
    }
}

