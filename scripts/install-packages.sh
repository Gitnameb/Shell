#!/usr/bin/env bash
# Módulo de paquetes del instalador del shell.
#
# Añade los repositorios necesarios y instala todo lo que necesita el shell,
# el compositor y el edit de Umbriel. Lo llama install.sh; también se puede
# ejecutar solo:
#
#   ./scripts/install-packages.sh --dry-run
#   ./scripts/install-packages.sh

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN=0
WITH_FIRMWARE=0
WITH_FIRMWARE_AUTHOR=0
SKIP_GREETER=0

usage() {
    cat <<'EOF'
Instala los paquetes del shell sobre Debian 13.

Uso:
  ./scripts/install-packages.sh [opciones]

Opciones:
  --dry-run         Muestra los comandos sin ejecutar nada
  --with-firmware   Detecta CPU, GPU, red y audio e instala su firmware
  --with-firmware-author
                    Instala la lista exacta del equipo del autor (Intel/AMD),
                    útil para reproducir esa máquina
  --skip-greeter    No instala greetd ni Noctalia Greeter
  -h, --help        Muestra esta ayuda
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --with-firmware) WITH_FIRMWARE=1; shift ;;
        --with-firmware-author)
            WITH_FIRMWARE_AUTHOR=1
            shift
            ;;
        --skip-greeter) SKIP_GREETER=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
done

require_normal_user

if [[ ! -f /etc/debian_version ]] || ! grep -q '^ID=debian' /etc/os-release 2>/dev/null; then
    die "Este instalador está pensado para Debian 13 (trixie)."
fi

if (( ! DRY_RUN )); then
    sudo -v || die "No se pudo obtener permiso de sudo."
fi

# ---------------------------------------------------------------------------
# Repositorios
# ---------------------------------------------------------------------------
ensure_repos() {
    if grep -Rqs 'trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        log "trixie-backports ya está configurado."
    else
        log "Añadiendo trixie-backports."
        printf 'deb http://deb.debian.org/debian trixie-backports main\n' \
            | run_sudo tee /etc/apt/sources.list.d/trixie-backports.list >/dev/null
    fi

    local keyring=/usr/share/keyrings/nickh-archive-keyring.gpg
    local sources=/etc/apt/sources.list.d/noctalia-trixie.sources

    if [[ ! -f "$keyring" ]]; then
        log "Instalando la clave del repositorio de Noctalia."
        if [[ -f "$REPO_DIR/install/apt/nickh-archive-keyring.gpg" ]]; then
            run_sudo install -m644 "$REPO_DIR/install/apt/nickh-archive-keyring.gpg" "$keyring"
        else
            local deb
            deb=$(mktemp)
            run curl -fsSL -o "$deb" https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb
            run_sudo dpkg -i "$deb"
            rm -f "$deb"
        fi
    else
        log "La clave de Noctalia ya está instalada."
    fi

    if [[ ! -f "$sources" ]]; then
        log "Añadiendo el repositorio de Noctalia."
        run_sudo install -m644 "$REPO_DIR/install/apt/noctalia-trixie.sources" "$sources"
    else
        log "El repositorio de Noctalia ya está configurado."
    fi
}

# ---------------------------------------------------------------------------
# Listas de paquetes
# ---------------------------------------------------------------------------
# Los paquetes de red, Wi-Fi, punto de acceso, Bluetooth y VPN viven en
# scripts/network.sh. Así la instalación limpia no los instala dos veces.
KDE_PKGS=(
    sddm libpam-systemd plasma-integration libkf6config-bin
    kdialog breeze breeze-icon-theme breeze-gtk-theme breeze-cursor-theme
    qt6-wayland qt6-qpa-plugins qt6-svg-plugins
    upower polkitd
    libglib2.0-bin librsvg2-common
)

# PipeWire de backports. Todas las piezas deben tener la misma versión: si se
# mezclan con las de trixie, apt falla por dependencias exactas (por ejemplo,
# libspa-0.2-bluetooth exige libspa-0.2-modules de su misma versión).
PIPEWIRE_BACKPORTS_PKGS=(
    pipewire pipewire-bin pipewire-pulse wireplumber
    libpipewire-0.3-0t64 libpipewire-0.3-modules libspa-0.2-modules
)

# Mesa de backports. libgbm-dev (dependencia de libwlroots-0.20-dev) arrastra
# libgbm1 y mesa-libgallium de backports; los drivers VA/Vulkan y las librerías
# DRI deben ser de la misma versión o apt no puede resolver la transacción.
MESA_BACKPORTS_PKGS=(
    libgbm1 mesa-libgallium
    libgl1-mesa-dri libglx-mesa0 libegl-mesa0
    mesa-va-drivers mesa-vulkan-drivers
)

# Quickshell y Umbriel arrastran at-spi2-core, libatk1.0-0t64 y
# libatspi2.0-0t64 desde backports. Sus paquetes GIR deben ser del mismo
# origen: los de trixie exigen la versión exacta de trixie y cualquier app
# GTK3 (por ejemplo un .deb como LocalSend) falla al instalarse con
# «held broken packages».
GTK_GIR_BACKPORTS_PKGS=(
    gir1.2-atk-1.0 gir1.2-atspi-2.0
)

RUNTIME_PKGS=(
    ddcutil brightnessctl libnotify-bin fonts-inter-variable wvkbd swayidle foot
    # Print y Shift+Print llaman a grim (y slurp para la región). No son solo
    # herramientas de prueba: el atajo falla si no están instalados.
    grim slurp
    # Inter no incluye glifos CJK. Sin esta fuente las letras japonesas,
    # chinas y coreanas del widget de música se dibujan como cuadros.
    fonts-noto-cjk
    power-profiles-daemon
    # systemd-resolved es el único backend que permite DNS over TLS con
    # verificación de certificado. La vista DNS del centro de control lo usa.
    systemd-resolved
    # nftables aplica el NAT y el enrutado de los clientes del punto de acceso
    # por la VPN. NetworkManager ya lo usa, pero el ayudante necesita «nft».
    nftables
    iputils-ping wl-clipboard cliphist udiskie udisks2 ntfs-3g exfatprogs usbutils python3 curl
    qml6-module-qtquick-effects
    qml6-module-qt-labs-folderlistmodel
    xdg-utils desktop-file-utils
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-kde
    xwayland
)

BUILD_PKGS=(
    build-essential cmake git meson ninja-build pkg-config
    libcairo2-dev libpango1.0-dev libgdk-pixbuf-2.0-dev
    libtomlplusplus-dev libjemalloc-dev libliftoff-dev liblcms2-dev
    libsystemd-dev libudev-dev libxcb1-dev libxcb-icccm4-dev
    libxcb-ewmh-dev libxcb-randr0-dev libxcb-shape0-dev libxcb-render0-dev
    libeis-dev libseat-dev nlohmann-json3-dev
)

BUILD_BACKPORTS_PKGS=(
    libwlroots-0.20-dev libdrm-dev libinput-dev libxkbcommon-dev
    libpixman-1-dev libpixman-1-0
    libwayland-dev wayland-protocols libdisplay-info-dev
    libegl-dev libgles-dev libgbm-dev
)

# Firmware exacto del equipo del autor. Solo se usa con
# --with-firmware-author; para otros equipos está la detección automática.
AUTHOR_FIRMWARE_PKGS=(
    intel-microcode firmware-amd-graphics firmware-iwlwifi firmware-realtek
    firmware-sof-signed mesa-utils intel-media-va-driver
)

# Lista que rellena detect_firmware_pkgs().
FIRMWARE_PKGS_DETECTED=()

add_firmware_pkg() {
    local pkg=$1 existing
    for existing in "${FIRMWARE_PKGS_DETECTED[@]}"; do
        [[ "$existing" == "$pkg" ]] && return 0
    done
    FIRMWARE_PKGS_DETECTED+=("$pkg")
}

# Elige los paquetes de firmware según la CPU y el driver que el kernel ya
# cargó. Así no se instala el firmware de una Wi-Fi Intel en un equipo Realtek
# ni el de una GPU AMD en uno NVIDIA. Si un dispositivo no aparece, no se
# adivina: se deja fuera y el usuario puede instalar su paquete a mano.
detect_firmware_pkgs() {
    FIRMWARE_PKGS_DETECTED=()

    local cpu
    cpu=$(awk -F: '/^vendor_id/ {
        gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit
    }' /proc/cpuinfo 2>/dev/null)
    case "$cpu" in
        GenuineIntel) add_firmware_pkg intel-microcode ;;
        AuthenticAMD) add_firmware_pkg amd64-microcode ;;
    esac

    local uevent driver
    while IFS= read -r uevent; do
        [[ -f "$uevent" ]] || continue
        driver=$(sed -n 's/^DRIVER=//p' "$uevent" 2>/dev/null | head -n1)
        [[ -n "$driver" ]] || continue
        case "$driver" in
            amdgpu | radeon)
                add_firmware_pkg firmware-amd-graphics ;;
            i915 | xe)
                add_firmware_pkg firmware-intel-graphics
                add_firmware_pkg intel-media-va-driver ;;
            nouveau)
                add_firmware_pkg firmware-nvidia-graphics ;;
            nvidia | nvidia-drm)
                add_firmware_pkg firmware-nvidia-gsp ;;
            iwlwifi | iwlmvm)
                add_firmware_pkg firmware-iwlwifi ;;
            r8* | rtsx_pci | rtl* | rtw*)
                add_firmware_pkg firmware-realtek ;;
            ath9k_htc)
                add_firmware_pkg firmware-ath9k-htc ;;
            carl9170)
                add_firmware_pkg firmware-carl9170 ;;
            ath*)
                add_firmware_pkg firmware-atheros ;;
            brcmfmac | brcmsmac)
                add_firmware_pkg firmware-brcm80211 ;;
            bnx2)
                add_firmware_pkg firmware-bnx2 ;;
            bnx2x)
                add_firmware_pkg firmware-bnx2x ;;
            mt76* | mt79* | rt2400* | rt2500* | rt2800* | rt61* | rt73*)
                add_firmware_pkg firmware-mediatek ;;
            mwl8k)
                add_firmware_pkg firmware-misc-nonfree ;;
            wcn36xx)
                add_firmware_pkg firmware-qcom-soc ;;
            libertas*)
                add_firmware_pkg firmware-libertas ;;
            ipw2x00)
                add_firmware_pkg firmware-ipw2x00 ;;
            zd1211rw)
                add_firmware_pkg firmware-zd1211 ;;
            snd_sof*)
                add_firmware_pkg firmware-sof-signed ;;
        esac
    done < <(printf '%s\n' \
        /sys/class/drm/card*/device/uevent \
        /sys/class/net/*/device/uevent \
        /sys/class/sound/card*/device/uevent)

    # Utilidad genérica para comprobar que la GPU funciona.
    add_firmware_pkg mesa-utils
}

# ---------------------------------------------------------------------------
# Registro de lanzadores
# ---------------------------------------------------------------------------
# Muchos .deb publican su .desktop desde el postinst con `xdg-desktop-menu`.
# Ese script exige un directorio de menús (/etc/xdg/menus) y otro de
# directorios de escritorio (/usr/share/desktop-directories) escribibles. Un
# Debian 13 mínimo no trae ninguno de los dos y el postinst falla con
# «No writable system menu directory found»: el binario y los iconos quedan
# instalados, pero la app no aparece en el lanzador. Le pasa a Spotify y a
# cualquier otro paquete que use xdg-desktop-menu. Los directorios se crean
# antes de instalar nada para que los postinst de esta misma ejecución
# funcionen.
ensure_desktop_menu_dirs() {
    local dir
    for dir in /etc/xdg/menus /usr/share/desktop-directories; do
        if [[ -d "$dir" ]]; then
            continue
        fi
        log "Creando $dir para registrar los lanzadores de las apps."
        run_sudo install -d -m755 "$dir"
    done
}

# Si el postinst de una app ya falló (o se instaló antes de que existieran esos
# directorios), su .desktop sigue en /usr/share/<app>/ y no en
# /usr/share/applications. Se registran los que falten mirando solo los
# paquetes cuyo postinst usa xdg-desktop-menu: así no se cuelan .desktop de
# autostart, sesiones de escritorio ni atajos de KDE, que también declaran
# Type=Application pero no son lanzadores.
register_orphan_desktop_entries() {
    local postinst pkg file base
    local registered=0
    for postinst in /var/lib/dpkg/info/*.postinst; do
        [[ -f "$postinst" ]] || continue
        grep -q 'xdg-desktop-menu' "$postinst" 2>/dev/null || continue
        pkg=${postinst##*/}
        pkg=${pkg%.postinst}
        while IFS= read -r file; do
            if [[ "$file" != *.desktop || "$file" == /usr/share/applications/* ]]; then
                continue
            fi
            if ! grep -q '^Type=Application' "$file" 2>/dev/null; then
                continue
            fi
            base=${file##*/}
            if [[ -e "/usr/share/applications/$base" ]]; then
                continue
            fi
            log "Registrando el lanzador $base (paquete $pkg)."
            # XDG_DATA_DIRS/XDG_CONFIG_DIRS explícitos: sudo puede heredar los
            # del usuario (por ejemplo, los exports de Flatpak) y
            # xdg-desktop-menu elegiría el primer directorio escribible, que
            # como root es cualquiera.
            if ! run_sudo env XDG_DATA_DIRS=/usr/local/share:/usr/share XDG_CONFIG_DIRS=/etc/xdg \
                xdg-desktop-menu install --novendor "$file"; then
                warn "No se pudo registrar $base."
                continue
            fi
            registered=1
        done < <(dpkg-query -L "$pkg" 2>/dev/null)
    done
    if (( registered )); then
        run_sudo env XDG_DATA_DIRS=/usr/local/share:/usr/share \
            update-desktop-database /usr/share/applications \
            || warn "No se pudo actualizar la caché de lanzadores."
    fi
}

# ---------------------------------------------------------------------------
# Instalación
# ---------------------------------------------------------------------------
ensure_desktop_menu_dirs
ensure_repos

log "Actualizando los índices de apt."
run_sudo apt-get update

# PipeWire y Mesa se instalan en bloque y desde backports, antes de Quickshell
# y Umbriel. Si se instalan después, el propio `-t trixie-backports` de
# Quickshell puede arrastrar solo una parte de las librerías y dejar la
# transacción en un estado que apt no puede resolver.
log "Alineando PipeWire y Mesa con trixie-backports."
run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -t trixie-backports \
    "${PIPEWIRE_BACKPORTS_PKGS[@]}" "${MESA_BACKPORTS_PKGS[@]}"

# Las dependencias de compilación de backports se instalan antes de
# libcairo2-dev (que está en BUILD_PKGS y arrastra libpixman-1-dev). Si se
# instalan después, apt puede meter primero la versión de trixie y luego no
# puede combinarla con la de backports.
log "Instalando las dependencias de compilación de backports."
run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -t trixie-backports "${BUILD_BACKPORTS_PKGS[@]}"

log "Instalando Quickshell, Umbriel y su portal (backports/Noctalia)."
run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -t trixie-backports quickshell hyprlock umbriel xdg-desktop-portal-umbriel

# Solo si libatk viene de backports: alinear sus GIR evita que instalar
# después una app GTK3 (un .deb, Steam, etc.) rompa apt por dependencias
# exactas entre trixie y backports.
if dpkg-query -W -f='${Version}' libatk1.0-0t64 2>/dev/null | grep -q 'bpo13'; then
    log "Alineando los GIR de ATK y AT-SPI con libatk de backports."
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        -t trixie-backports "${GTK_GIR_BACKPORTS_PKGS[@]}"
fi

# Noctalia Greeter depende de fonts-noctalia-tabler, que recomienda el paquete
# `noctalia` (el shell completo). No se instala: este escritorio usa Umbriel.
if (( ! SKIP_GREETER )); then
    log "Instalando greetd y Noctalia Greeter."
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends -t trixie-backports greetd noctalia-greeter
else
    log "Se omite greetd y Noctalia Greeter (--skip-greeter)."
fi

log "Instalando la base de KDE, Qt, audio y servicios."
# Sin plasma-workspace: solo las librerías y herramientas que usa el shell.
# --no-install-recommends evita que kio6 arrastre systemsettings/Plasma.
if [[ ! -e /usr/share/sddm/themes/breeze/Main.qml \
    && ! -e /usr/share/sddm/themes/debian-breeze/Main.qml ]]; then
    log "Instalando un tema ligero para SDDM (sin Plasma)."
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends sddm-theme-maya
fi
run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --no-install-recommends "${KDE_PKGS[@]}"

# NetworkManager, Wi-Fi, punto de acceso, Bluetooth y VPN los instala
# scripts/network.sh para no duplicar paquetes en la instalación.

if [[ ! -e /usr/share/sddm/themes/breeze/Main.qml \
    && ! -e /usr/share/sddm/themes/debian-breeze/Main.qml \
    && ! -e /etc/sddm.conf.d/20-shell-theme.conf ]]; then
    log "Configurando SDDM con el tema ligero maya."
    run_sudo install -d /etc/sddm.conf.d
    printf '[Theme]\nCurrent=maya\n' \
        | run_sudo tee /etc/sddm.conf.d/20-shell-theme.conf >/dev/null
fi

log "Instalando las dependencias del shell."
run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${RUNTIME_PKGS[@]}"

log "Instalando las dependencias de compilación."
run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${BUILD_PKGS[@]}"

if (( WITH_FIRMWARE_AUTHOR )); then
    log "Instalando la lista de firmware del equipo del autor (Intel/AMD)."
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "${AUTHOR_FIRMWARE_PKGS[@]}"
elif (( WITH_FIRMWARE )); then
    detect_firmware_pkgs
    log "Firmware detectado para este equipo: ${FIRMWARE_PKGS_DETECTED[*]}"
    case " ${FIRMWARE_PKGS_DETECTED[*]} " in
        *" firmware-nvidia-graphics "*)
            warn "GPU NVIDIA con nouveau: este firmware no instala el driver"
            warn "propietario. Para usarlo hace falta nvidia-driver."
            ;;
    esac
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "${FIRMWARE_PKGS_DETECTED[@]}"
fi

# Apps cuyo postinst no pudo registrar su lanzador antes de crear los
# directorios de xdg-desktop-menu.
register_orphan_desktop_entries

log "Habilitando los servicios del sistema."
# SDDM queda instalado y habilitado como respaldo. scripts/install-greeter.sh
# lo desactiva al final si Noctalia Greeter está disponible.
run_sudo systemctl enable sddm || warn "No se pudo habilitar SDDM."
run_sudo systemctl enable --now power-profiles-daemon \
    || warn "Algún servicio no se pudo iniciar; revisa systemctl status."
# NetworkManager y bluetooth los activa scripts/network.sh después de
# instalar sus paquetes.

# El paquete oficial de Umbriel no trae el edit. Ejecutar este módulo solo
# (en vez de install.sh) lo deja instalado y el edit desaparece hasta que se
# vuelva a ejecutar install-umbriel-edit.sh.
if command -v umbriel >/dev/null 2>&1 \
    && ! umbriel config schema --json 2>/dev/null | grep -q '"animation.speed"'; then
    warn "El paquete oficial de Umbriel ha sustituido el edit."
    warn "Ejecuta ./scripts/install-umbriel-edit.sh --yes antes de reiniciar."
fi

log "Paquetes instalados."
