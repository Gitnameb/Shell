#!/usr/bin/env bash
# Módulo de paquetes del instalador del shell.
#
# Añade los repositorios necesarios y instala todo lo que necesita el shell,
# el compositor y el fork de Umbriel. Lo llama install.sh; también se puede
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

usage() {
    cat <<'EOF'
Instala los paquetes del shell sobre Debian 13.

Uso:
  ./scripts/install-packages.sh [opciones]

Opciones:
  --dry-run         Muestra los comandos sin ejecutar nada
  --with-firmware   Instala firmware y drivers de este equipo
  -h, --help        Muestra esta ayuda
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --with-firmware) WITH_FIRMWARE=1; shift ;;
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

RUNTIME_PKGS=(
    ddcutil brightnessctl libnotify-bin fonts-inter-variable wvkbd swayidle foot
    power-profiles-daemon
    iputils-ping wl-clipboard cliphist udiskie python3 curl
    qml6-module-qtquick-effects
    qml6-module-qt-labs-folderlistmodel
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

FIRMWARE_PKGS=(
    intel-microcode firmware-amd-graphics firmware-iwlwifi firmware-realtek
    firmware-sof-signed mesa-utils intel-media-va-driver
)

# ---------------------------------------------------------------------------
# Instalación
# ---------------------------------------------------------------------------
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

if (( WITH_FIRMWARE )); then
    log "Instalando firmware y drivers de este equipo."
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${FIRMWARE_PKGS[@]}"
fi

log "Habilitando los servicios del sistema."
run_sudo systemctl enable sddm || warn "No se pudo habilitar SDDM."
run_sudo systemctl enable --now power-profiles-daemon \
    || warn "Algún servicio no se pudo iniciar; revisa systemctl status."
# NetworkManager y bluetooth los activa scripts/network.sh después de
# instalar sus paquetes.

log "Paquetes instalados."
