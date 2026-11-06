#!/usr/bin/env bash
# Configuración de red del shell sobre Debian 13.
#
# Debian puede instalar el equipo con ifupdown: /etc/network/interfaces trae
# la interfaz principal y NetworkManager la marca como «unmanaged». Además,
# network-manager solo recomienda wpasupplicant; sin él, el adaptador Wi-Fi
# aparece como «unavailable» y el shell no puede listar ni conectar redes.
#
# Este script:
#   1. Instala los paquetes de red: NetworkManager, wpasupplicant, rfkill,
#      dnsmasq-base, bluez, bluez-obexd, el plugin de audio Bluetooth de
#      PipeWire (libspa-0.2-bluetooth), network-manager-openvpn y qrencode.
#      Si el plugin viene de backports, instala también el resto del stack de
#      PipeWire para que las versiones coincidan.
#   2. Guarda una copia de /etc/network/interfaces y deja solo loopback,
#      para que NetworkManager gestione el resto de interfaces.
#   3. Reinicia NetworkManager cuando hace falta.
#   4. Pide a NetworkManager que adopte y conecte el Ethernet si seguía
#      sin gestionar.
#   5. Detiene ifup@ y dhcpcd heredados. Volver a ejecutarlo repara el caso
#      en que la Ethernet se reconecte sola tras desconectarla.
#
# Lo llama install.sh, pero también se puede ejecutar solo:
#
#   sudo ./scripts/network.sh
#   sudo ./scripts/network.sh --dry-run
#   sudo ./scripts/network.sh --yes
#
# --dry-run se puede ejecutar como usuario normal y no cambia nada.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN=0
ASSUME_YES=0
SKIP_PACKAGES=0
RESTART_SHELL=1
INTERFACES=/etc/network/interfaces

usage() {
    cat <<'EOF'
Prepara NetworkManager para Ethernet, Wi-Fi, punto de acceso, VPN y Bluetooth.

Uso:
  sudo ./scripts/network.sh [opciones]

Opciones:
  --dry-run           Muestra lo que haría sin cambiar nada
  --yes               No pide confirmación
  --skip-packages     No instala los paquetes de red, VPN ni Bluetooth
  --no-restart-shell  No reinicia Quickshell al terminar
  -h, --help          Muestra esta ayuda

También detiene los servicios heredados ifup@/dhcpcd que pueden volver a
activar la Ethernet. Vuelve a ejecutarlo para corregir ese control.
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --yes) ASSUME_YES=1; shift ;;
        --skip-packages) SKIP_PACKAGES=1; shift ;;
        --no-restart-shell) RESTART_SHELL=0; shift ;;
        -h | --help) usage; exit 0 ;;
        *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
done

if (( ! DRY_RUN && EUID != 0 )); then
    die "Ejecuta este script con sudo: sudo $0"
fi

[[ -f /etc/debian_version ]] || die "Este script está pensado para Debian."

if (( ! DRY_RUN && ! ASSUME_YES )); then
    cat <<EOF

Se va a preparar la red de este equipo:

  - Instalar NetworkManager, Wi-Fi, punto de acceso, VPN y Bluetooth.
  - Dejar /etc/network/interfaces solo con loopback (con copia .bak).
  - Reiniciar NetworkManager y adoptar la Ethernet si hace falta.

La conexión puede parpadear unos segundos.

EOF
    read -r -p "¿Continuar? [s/N] " answer || answer=""
    [[ "$answer" =~ ^[sS]$ ]] || die "Cancelado."
fi

# ¿Hay alguna interfaz que no sea loopback configurada por ifupdown?
has_ifupdown_interfaces() {
    [[ -f "$INTERFACES" ]] || return 1
    awk '
        /^[[:space:]]*(auto|allow-hotplug)[[:space:]]/ {
            for (i = 2; i <= NF; i++)
                if ($i != "lo")
                    found = 1
        }
        /^[[:space:]]*iface[[:space:]]/ {
            if ($2 != "lo")
                found = 1
        }
        END { exit found ? 0 : 1 }
    ' "$INTERFACES"
}

wifi_unavailable() {
    nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
        | awk -F: '$2 == "wifi" && $3 == "unavailable" { found = 1 }
                   END { exit found ? 0 : 1 }'
}

wifi_radio_enabled() {
    [[ "$(nmcli radio wifi 2>/dev/null || true)" == "enabled" ]]
}

wpa_present() {
    command -v wpa_supplicant >/dev/null 2>&1 \
        || [[ -x /usr/sbin/wpa_supplicant ]]
}

rfkill_present() {
    command -v rfkill >/dev/null 2>&1 \
        || [[ -x /usr/sbin/rfkill ]] \
        || [[ -x /sbin/rfkill ]]
}

dnsmasq_present() {
    command -v dnsmasq >/dev/null 2>&1 \
        || [[ -x /usr/sbin/dnsmasq ]]
}

bluez_present() {
    command -v bluetoothctl >/dev/null 2>&1 \
        || [[ -x /usr/sbin/bluetoothd ]] \
        || dpkg -s bluez >/dev/null 2>&1
}

libspa_bt_present() {
    dpkg -s libspa-0.2-bluetooth >/dev/null 2>&1
}

# El plugin Bluetooth debe tener la misma versión que libspa-0.2-modules. Si no
# coincide, hay que reinstalarlo con el resto de PipeWire.
libspa_bt_matches_pipewire() {
    local bt spa
    bt=$(dpkg-query -W -f='${Version}' libspa-0.2-bluetooth 2>/dev/null) || return 1
    spa=$(dpkg-query -W -f='${Version}' libspa-0.2-modules 2>/dev/null) || return 1
    [[ -n "$bt" && "$bt" == "$spa" ]]
}

nm_present() {
    command -v nmcli >/dev/null 2>&1 \
        || dpkg -s network-manager >/dev/null 2>&1
}

openvpn_plugin_present() {
    dpkg -s network-manager-openvpn >/dev/null 2>&1
}

qrencode_present() {
    command -v qrencode >/dev/null 2>&1
}

write_loopback_only() {
    local backup="$INTERFACES.bak.$(date +%Y%m%d-%H%M%S)"

    log "Guardando $INTERFACES en $backup."
    run cp -a "$INTERFACES" "$backup"

    log "Dejando solo loopback en $INTERFACES para que lo gestione NetworkManager."
    if (( DRY_RUN )); then
        printf '\033[2m[dry-run]\033[0m escribir %s con solo loopback\n' "$INTERFACES"
        return 0
    fi

    cat >"$INTERFACES" <<'EOF'
# Gestionado por NetworkManager (shell).
# La configuración anterior de ifupdown está en interfaces.bak.*;
# restáurala solo si vas a dejar de usar NetworkManager.
auto lo
iface lo inet loopback
EOF
    chmod 644 "$INTERFACES"
}

adopt_wired() {
    local dev type state

    while IFS=: read -r dev type state; do
        [[ "$type" == "ethernet" ]] || continue
        if [[ "$state" == "unmanaged" ]]; then
            log "Pidiendo a NetworkManager que gestione $dev."
            run nmcli device set "$dev" managed yes \
                || warn "No se pudo adoptar $dev."
        fi
    done < <(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null || true)
}

# Perfil persistente que NetworkManager usaría para conectar este cable.
# Preferimos activarlo por nombre antes que `nmcli device connect`, que puede
# crear un perfil efímero con el nombre de la interfaz.
wired_profile() {
    local dev="$1" name type autoconnect ifname

    while IFS=: read -r name type autoconnect; do
        [[ "$type" == "802-3-ethernet" && "$autoconnect" == "yes" ]] || continue
        ifname=$(nmcli -g connection.interface-name connection show "$name" 2>/dev/null || true)
        if [[ -z "$ifname" || "$ifname" == "$dev" ]]; then
            printf '%s\n' "$name"
            return 0
        fi
    done < <(nmcli -t -f NAME,TYPE,AUTOCONNECT connection show 2>/dev/null || true)

    return 1
}

connect_wired() {
    local dev type state profile

    while IFS=: read -r dev type state; do
        [[ "$type" == "ethernet" ]] || continue
        if [[ "$state" != connected* && "$state" != "unmanaged" ]]; then
            profile=$(wired_profile "$dev" || true)
            if [[ -n "$profile" ]]; then
                log "Conectando $dev con el perfil «$profile»."
                run nmcli connection up "$profile" \
                    || warn "No se pudo conectar $dev todavía."
            else
                log "Conectando $dev."
                run nmcli device connect "$dev" \
                    || warn "No se pudo conectar $dev todavía."
            fi
        fi
    done < <(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null || true)
}

# ifupdown deja servicios ifup@<interfaz> activos cuando Debian instala con
# `allow-hotplug`. Aunque /etc/network/interfaces ya solo tenga loopback, el
# servicio y su dhcpcd siguen vivos hasta que se detienen, y pueden volver a
# configurar la interfaz justo después de desconectarla desde NetworkManager.
legacy_ifup_units() {
    command -v systemctl >/dev/null 2>&1 || return 0
    systemctl list-units --type=service --all --no-legend 2>/dev/null \
        | awk '$1 ~ /^ifup@.*\.service$/ && $1 != "ifup@lo.service" && $3 == "active" { print $1 }'
}

has_legacy_ifup() {
    [[ -n "$(legacy_ifup_units)" ]]
}

stop_legacy_ifup() {
    local unit iface dhcpcd_bin=""

    dhcpcd_bin=$(command -v dhcpcd 2>/dev/null || true)
    [[ -n "$dhcpcd_bin" ]] || dhcpcd_bin=/usr/sbin/dhcpcd

    while IFS= read -r unit; do
        [[ -n "$unit" ]] || continue
        iface=${unit#ifup@}
        iface=${iface%.service}
        log "Deteniendo $unit: ifupdown ya no debe gestionar $iface."
        run systemctl stop "$unit" || warn "No se pudo detener $unit."
        if [[ -x "$dhcpcd_bin" && -e "/run/dhcpcd/$iface.pid" ]]; then
            log "Liberando la concesión DHCP de $iface (dhcpcd)."
            # Es un respaldo por si systemctl stop no cerró dhcpcd; si ya no
            # está en marcha, el comando falla y no debe detener el script.
            run "$dhcpcd_bin" -k "$iface" || true
        fi
    done < <(legacy_ifup_units)
}

# ---------------------------------------------------------------------------
# WirePlumber carga el plugin BlueZ al arrancar. Si se acaba de instalar,
# hay que reiniciarlo en la sesión del usuario para que aparezcan las salidas
# y micrófonos Bluetooth.
restart_audio_if_needed() {
    (( DRY_RUN )) && return 0
    command -v systemctl >/dev/null 2>&1 || return 0

    local user="${SUDO_USER:-}"
    [[ -n "$user" && "$user" != "root" ]] || return 0

    local uid
    uid=$(id -u "$user" 2>/dev/null) || return 0
    [[ -d "/run/user/$uid" ]] || return 0

    log "Reiniciando PipeWire y WirePlumber para cargar el audio Bluetooth."
    run sudo -u "$user" env XDG_RUNTIME_DIR="/run/user/$uid" \
        systemctl --user restart pipewire pipewire-pulse wireplumber \
        || warn "No se pudo reiniciar el audio; cierra sesión o reinícialo tú."
}

# ---------------------------------------------------------------------------
# Paquetes de red
# ---------------------------------------------------------------------------
# Si añades un paquete obligatorio para estas vistas, actualiza también
# scripts/check-deps.sh para que el aviso de notificaciones lo detecte.
# NetworkManager es la base de Wi-Fi, Ethernet, punto de acceso y VPN. Si no
# está instalado, se instala antes de consultar nmcli.
if nm_present; then
    log "network-manager ya está instalado."
elif (( SKIP_PACKAGES )); then
    warn "network-manager no está instalado (--skip-packages); no se puede"
    warn "configurar la red ni enumerar las interfaces."
else
    log "Instalando network-manager."
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends network-manager
fi

WPA_BEFORE=0
if wpa_present; then
    WPA_BEFORE=1
fi

if (( WPA_BEFORE )); then
    log "wpasupplicant ya está instalado."
elif (( SKIP_PACKAGES )); then
    warn "wpasupplicant no está instalado (--skip-packages); el Wi-Fi seguirá"
    warn "apareciendo como «unavailable» hasta que lo instales."
else
    log "Instalando wpasupplicant (lo necesita NetworkManager para el Wi-Fi)."
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wpasupplicant
fi

if rfkill_present; then
    log "rfkill ya está instalado."
elif (( SKIP_PACKAGES )); then
    warn "rfkill no está instalado (--skip-packages); no se podrá comprobar"
    warn "si la radio Wi-Fi está bloqueada."
else
    log "Instalando rfkill (para comprobar bloqueos de la radio Wi-Fi)."
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends rfkill
fi

# El punto de acceso usa la IPv4 compartida de NetworkManager, que reparte
# direcciones con dnsmasq. Sin este paquete los clientes se conectan pero no
# reciben IP.
if dnsmasq_present; then
    log "dnsmasq ya está instalado (lo necesita el punto de acceso)."
elif (( SKIP_PACKAGES )); then
    warn "dnsmasq-base no está instalado (--skip-packages); el punto de"
    warn "acceso podría no repartir direcciones IP a los clientes."
else
    log "Instalando dnsmasq-base (DHCP del punto de acceso)."
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends dnsmasq-base
fi

# Bluetooth. El adaptador y el emparejamiento necesitan BlueZ; obexd añade la
# transferencia de archivos. El servicio se activa al final, con la red.
if bluez_present; then
    log "bluez ya está instalado."
elif (( SKIP_PACKAGES )); then
    warn "bluez no está instalado (--skip-packages); Bluetooth no aparecerá"
    warn "en el centro de control."
else
    log "Instalando bluez y bluez-obexd (Bluetooth)."
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends bluez bluez-obexd
fi

# Audio Bluetooth. WirePlumber necesita el plugin BlueZ de PipeWire; sin él
# los auriculares se emparejan pero no aparecen como salida ni micrófono y la
# conexión puede fallar con br-connection-profile-unavailable.
LIBSPA_BT_BEFORE=0
if libspa_bt_present && libspa_bt_matches_pipewire; then
    LIBSPA_BT_BEFORE=1
    log "libspa-0.2-bluetooth ya está instalado (audio Bluetooth)."
elif (( SKIP_PACKAGES )); then
    warn "libspa-0.2-bluetooth no está instalado (--skip-packages); los"
    warn "auriculares Bluetooth no aparecerán como salida ni micrófono."
else
    log "Instalando libspa-0.2-bluetooth (audio Bluetooth de PipeWire)."
    SPA_ARGS=()
    SPA_PKGS=(libspa-0.2-bluetooth)
    SPA_POLICY=$(apt-cache policy libspa-0.2-bluetooth 2>/dev/null || true)
    if [[ "$SPA_POLICY" == *trixie-backports* ]]; then
        SPA_ARGS=(-t trixie-backports)
        # El plugin debe coincidir con el resto de PipeWire. Si el equipo tenía
        # PipeWire de trixie, instalar solo el plugin de backports rompe las
        # dependencias exactas de libspa-0.2-modules.
        SPA_PKGS+=(
            pipewire pipewire-bin pipewire-pulse wireplumber
            libpipewire-0.3-0t64 libpipewire-0.3-modules
            libspa-0.2-modules
        )
    fi
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "${SPA_ARGS[@]}" --no-install-recommends "${SPA_PKGS[@]}"
fi
LIBSPA_BT_AFTER=0
if libspa_bt_present && libspa_bt_matches_pipewire; then
    LIBSPA_BT_AFTER=1
fi

# VPN de NetworkManager: el complemento OpenVPN es lo que permite importar
# archivos .ovpn y conectarlos desde la vista VPN del shell.
if openvpn_plugin_present; then
    log "network-manager-openvpn ya está instalado."
elif (( SKIP_PACKAGES )); then
    warn "network-manager-openvpn no está instalado (--skip-packages); la"
    warn "vista VPN no podrá importar ni conectar archivos .ovpn."
else
    log "Instalando network-manager-openvpn (VPN)."
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends network-manager-openvpn
fi

# qrencode genera el QR del punto de acceso. No hace falta para que el
# hotspot funcione, pero sin él la vista no puede mostrar el código.
if qrencode_present; then
    log "qrencode ya está instalado (QR del punto de acceso)."
elif (( SKIP_PACKAGES )); then
    warn "qrencode no está instalado (--skip-packages); el punto de acceso"
    warn "funcionará, pero no se mostrará su QR."
else
    log "Instalando qrencode (QR del punto de acceso)."
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends qrencode
fi

if (( ! LIBSPA_BT_BEFORE && LIBSPA_BT_AFTER )); then
    restart_audio_if_needed
fi

WPA_AFTER=0
if wpa_present; then
    WPA_AFTER=1
fi
if (( ! DRY_RUN && ! SKIP_PACKAGES && ! WPA_AFTER )); then
    die "wpasupplicant no quedó instalado; revisa apt."
fi

# Los servicios se activan aquí, después de instalar sus paquetes. No se
# duplican en install-packages.sh.
run systemctl enable --now NetworkManager \
    || warn "No se pudo activar NetworkManager; revisa systemctl status."
run systemctl enable --now bluetooth \
    || warn "No se pudo activar bluetooth; revisa systemctl status."

# Si no se instaló network-manager, no tiene sentido seguir: nmcli es la vía
# de configuración de NetworkManager.
if ! command -v nmcli >/dev/null 2>&1; then
    if (( DRY_RUN )); then
        warn "nmcli no está instalado; el --dry-run seguirá sin consultar el estado real."
    else
        die "Falta nmcli. Instala network-manager (o ejecuta sin --skip-packages)."
    fi
fi

# ---------------------------------------------------------------------------
# NetworkManager
# ---------------------------------------------------------------------------
NEED_RESTART=0
if (( ! WPA_BEFORE && WPA_AFTER )); then
    NEED_RESTART=1
fi

if has_ifupdown_interfaces; then
    write_loopback_only
    NEED_RESTART=1
else
    log "$INTERFACES ya deja las interfaces a NetworkManager."
fi

# Aunque el archivo ya esté limpio, en el arranque actual puede seguir activo
# un ifup@<interfaz> con su dhcpcd. Sin esto, la Ethernet se reconecta sola.
if has_legacy_ifup; then
    stop_legacy_ifup
    NEED_RESTART=1
fi

if wifi_radio_enabled && wifi_unavailable; then
    NEED_RESTART=1
fi

if (( NEED_RESTART )); then
    log "Reiniciando NetworkManager (la red puede parpadear un momento)."
    run systemctl restart NetworkManager \
        || warn "No se pudo reiniciar NetworkManager; revisa systemctl status."
    if (( ! DRY_RUN )); then
        sleep 2
    fi
else
    log "No hace falta reiniciar NetworkManager."
fi

adopt_wired
if (( ! DRY_RUN )); then
    sleep 2
fi
connect_wired

# Quickshell 0.3 puede quedarse sin dispositivos de red después de reiniciar
# NetworkManager. El sistema sigue teniendo las interfaces, pero el shell
# necesita volver a enumerarlas. Lo reiniciamos si estaba abierto.
restart_shell_if_running() {
    (( RESTART_SHELL )) || return 0

    # En una instalación limpia no hay shell instalado ni en ejecución. Este
    # bloque debe ser opcional y no puede hacer fallar al instalador.
    command -v qs >/dev/null 2>&1 || return 0
    command -v sudo >/dev/null 2>&1 || return 0

    local user="${SUDO_USER:-}"
    [[ -n "$user" && "$user" != "root" ]] || return 0

    local uid
    uid=$(id -u "$user" 2>/dev/null) || return 0

    local pid
    pid=$(pgrep -u "$uid" -x qs | head -n 1 || true)
    if [[ -z "$pid" ]]; then
        pid=$(pgrep -u "$uid" -x quickshell | head -n 1 || true)
    fi
    [[ -n "$pid" ]] || return 0

    local exe
    exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)
    [[ "$exe" == *quickshell* || "${exe##*/}" == "qs" ]] || return 0

    local cfg="default"
    local -a parts=()
    mapfile -d '' -t parts < "/proc/$pid/cmdline" || return 0
    local i
    for ((i = 1; i < ${#parts[@]}; i++)); do
        if [[ "${parts[$i]}" == "-c" || "${parts[$i]}" == "--config" ]]; then
            cfg="${parts[$((i + 1))]:-default}"
            break
        fi
    done

    local -a shell_env=()
    local line
    while IFS= read -r line; do
        case "$line" in
            WAYLAND_DISPLAY=*|XDG_RUNTIME_DIR=*|DBUS_SESSION_BUS_ADDRESS=*|\
            XDG_CURRENT_DESKTOP=*|XDG_SESSION_TYPE=*|XDG_CONFIG_HOME=*|\
            XDG_DATA_HOME=*|XDG_CACHE_HOME=*|HOME=*|USER=*|PATH=*)
                shell_env+=("$line") ;;
        esac
    done < <(tr '\0' '\n' < "/proc/$pid/environ")

    log "Reiniciando Quickshell ($cfg) para que vuelva a enumerar las interfaces."
    run kill "$pid" || warn "No se pudo cerrar Quickshell."
    if (( ! DRY_RUN )); then
        for _ in $(seq 1 25); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.2
        done
    fi
    run sudo -u "$user" env "${shell_env[@]}" qs -c "$cfg" -d \
        || warn "No se pudo reiniciar Quickshell; ejecuta: qs -c $cfg -d"
}

# Solo hace falta reiniciar el shell si NetworkManager se reinició: es cuando
# Quickshell puede quedarse sin la lista de dispositivos. Si el script solo
# comprobó el estado, no se toca la sesión.
if (( NEED_RESTART )); then
    restart_shell_if_running
fi

log "Estado final de las interfaces."
if (( DRY_RUN )); then
    printf '\033[2m[dry-run]\033[0m nmcli -t -f DEVICE,TYPE,STATE device status\n'
else
    nmcli -t -f DEVICE,TYPE,STATE device status || true
    if wifi_radio_enabled && wifi_unavailable; then
        warn "El adaptador Wi-Fi sigue no disponible. Revisa rfkill,"
        warn "el firmware y el estado de NetworkManager."
    fi
    if has_legacy_ifup; then
        warn "Todavía hay servicios ifup@ activos; la Ethernet podría"
        warn "volver a activarse sola. Revisa: systemctl list-units 'ifup@*'"
    fi
    if pgrep -x dhcpcd >/dev/null 2>&1; then
        warn "dhcpcd sigue en ejecución; revisa que no esté configurando"
        warn "la interfaz que debe controlar NetworkManager."
    fi
fi

cat <<'EOF'

Si el Wi-Fi ya aparece disponible, abre el centro de control del shell y
despliega la vista Red: la lista de redes debería cargarse al momento.

Si la Ethernet vuelve a activarse sola, ejecuta otra vez:
  sudo ./scripts/network.sh
EOF
