#!/usr/bin/env bash
# Instalador de ALBA sobre Debian 13 + Umbriel.
#
# Ejecuta este script como tu usuario normal (no con sudo). Él pedirá sudo
# cuando necesite instalar paquetes o escribir en el sistema.
#
# Uso:
#   ./install.sh [opciones]
#
# Opciones:
#   --dry-run         Muestra los comandos sin ejecutar nada
#   --yes             No pide confirmación al empezar
#   --skip-packages   No instala paquetes (solo configura y compila)
#   --skip-fork       No compila ni instala el fork de Umbriel
#   --skip-config     No copia la configuración de usuario
#   --force-config    Reemplaza configuraciones existentes (hace copia .bak)
#   --with-firmware   Instala firmware y drivers de este equipo
#   -h, --help        Muestra esta ayuda

set -Eeuo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

DRY_RUN=0
ASSUME_YES=0
SKIP_PACKAGES=0
SKIP_FORK=0
SKIP_CONFIG=0
FORCE_CONFIG=0
WITH_FIRMWARE=0

log() {
    printf '\n\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33maviso:\033[0m %s\n' "$*" >&2
}

die() {
    printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
    exit 1
}

run() {
    printf '\033[2m$\033[0m'
    printf ' %q' "$@"
    printf '\n'
    if (( ! DRY_RUN )); then
        "$@"
    fi
}

run_sudo() {
    run sudo "$@"
}

usage() {
    cat <<'EOF'
Instalador de ALBA sobre Debian 13 + Umbriel.

Uso:
  ./install.sh [opciones]

Opciones:
  --dry-run         Muestra los comandos sin ejecutar nada
  --yes             No pide confirmación al empezar
  --skip-packages   No instala paquetes (solo configura y compila)
  --skip-fork       No compila ni instala el fork de Umbriel
  --skip-config     No copia la configuración de usuario
  --force-config    Reemplaza configuraciones existentes (hace copia .bak)
  --with-firmware   Instala firmware y drivers de este equipo
  -h, --help        Muestra esta ayuda
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --yes) ASSUME_YES=1; shift ;;
        --skip-packages) SKIP_PACKAGES=1; shift ;;
        --skip-fork) SKIP_FORK=1; shift ;;
        --skip-config) SKIP_CONFIG=1; shift ;;
        --force-config) FORCE_CONFIG=1; shift ;;
        --with-firmware) WITH_FIRMWARE=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
done

if (( EUID == 0 )); then
    die "Ejecuta ./install.sh como tu usuario normal, no con sudo."
fi

command -v sudo >/dev/null 2>&1 || die "Falta sudo."

USER_NAME=$(id -un)
TARGET_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
[[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || die "No se pudo determinar el HOME de $USER_NAME."

if [[ ! -f /etc/debian_version ]] || ! grep -q '^ID=debian' /etc/os-release 2>/dev/null; then
    die "Este instalador está pensado para Debian 13 (trixie)."
fi

if (( ! DRY_RUN )); then
    sudo -v || die "No se pudo obtener permiso de sudo."
fi

if (( ! ASSUME_YES && ! DRY_RUN )); then
    cat <<EOF

Se va a preparar ALBA en este equipo:

  Usuario:   $USER_NAME
  HOME:      $TARGET_HOME
  Proyecto:  $REPO_DIR

Se instalarán paquetes con apt, se copiará configuración (sin sobrescribir la
existente salvo --force-config) y se compilará el fork de Umbriel. La sesión
actual no se reinicia sola.

EOF
    read -r -p "¿Continuar? [s/N] " answer || answer=""
    [[ "$answer" =~ ^[sS]$ ]] || die "Cancelado."
fi

# ---------------------------------------------------------------------------
# Paquetes
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

KDE_PKGS=(
    sddm plasma-workspace plasma-integration kde-cli-tools libkf6config-bin
    kdialog breeze breeze-icon-theme breeze-gtk-theme breeze-cursor-theme
    qt6-wayland qt6-qpa-plugins qt6-svg-plugins
    pipewire pipewire-pulse wireplumber
    network-manager upower polkitd bluez bluez-obexd
    libglib2.0-bin librsvg2-common
)

RUNTIME_PKGS=(
    ddcutil qrencode libnotify-bin fonts-inter wvkbd swayidle kitty
    network-manager-openvpn power-profiles-daemon pulseaudio-utils
    iputils-ping wl-clipboard python3 curl
    qml6-module-qtquick-effects qml6-module-qt5compat-graphicaleffects
    qml6-module-qt-labs-folderlistmodel
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-kde
    xwayland
)

BUILD_PKGS=(
    build-essential git meson ninja-build pkg-config
    wayland-protocols libcairo2-dev libpango1.0-dev libgdk-pixbuf-2.0-dev
    libtomlplusplus-dev libjemalloc-dev libliftoff-dev liblcms2-dev
    libsystemd-dev libudev-dev libxcb1-dev libxcb-icccm4-dev
    libxcb-ewmh-dev libxcb-randr0-dev libxcb-shape0-dev libxcb-render0-dev
    libeis-dev libseat-dev nlohmann-json3-dev
)

BUILD_BACKPORTS_PKGS=(
    libwlroots-0.20-dev libdrm-dev libinput-dev libxkbcommon-dev
    libpixman-1-dev libwayland-dev libdisplay-info-dev
    libegl-dev libgles-dev libgbm-dev
)

FIRMWARE_PKGS=(
    intel-microcode firmware-amd-graphics firmware-iwlwifi firmware-realtek
    firmware-sof-signed mesa-utils mesa-vulkan-drivers mesa-va-drivers
    intel-media-va-driver
)

if (( ! SKIP_PACKAGES )); then
    ensure_repos

    log "Actualizando los índices de apt."
    run_sudo apt-get update

    log "Instalando Quickshell, Umbriel y su portal (backports/Noctalia)."
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        -t trixie-backports quickshell hyprlock umbriel xdg-desktop-portal-umbriel

    log "Instalando la base de KDE, Qt, audio y servicios."
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${KDE_PKGS[@]}"

    log "Instalando las dependencias de ALBA."
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${RUNTIME_PKGS[@]}"

    log "Instalando las dependencias de compilación."
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${BUILD_PKGS[@]}"
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        -t trixie-backports "${BUILD_BACKPORTS_PKGS[@]}"

    if (( WITH_FIRMWARE )); then
        log "Instalando firmware y drivers de este equipo."
        run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${FIRMWARE_PKGS[@]}"
    fi

    log "Habilitando los servicios del sistema."
    run_sudo systemctl enable sddm || warn "No se pudo habilitar SDDM."
    run_sudo systemctl enable --now bluetooth NetworkManager power-profiles-daemon \
        || warn "Algún servicio no se pudo iniciar; revisa systemctl status."
else
    log "Se omiten los paquetes (--skip-packages)."
fi

# ---------------------------------------------------------------------------
# Configuración de usuario
# ---------------------------------------------------------------------------
HOME_SED=$(printf '%s' "$TARGET_HOME" | sed 's/[&|\\]/\\&/g')

render_template() {
    sed "s|/home/USUARIO|$HOME_SED|g" "$1"
}

backup_file() {
    local file=$1
    [[ -e "$file" ]] || return 0
    run cp -a "$file" "$file.bak.$(date +%Y%m%d-%H%M%S)"
}

copy_template() {
    local src=$1 dest=$2

    if [[ -e "$dest" && $FORCE_CONFIG -eq 0 ]]; then
        warn "$dest ya existe; se conserva. Usa --force-config para reemplazarlo."
        return 0
    fi

    backup_file "$dest"
    run mkdir -p "$(dirname "$dest")"

    if (( DRY_RUN )); then
        printf '\033[2m[dry-run]\033[0m render %s -> %s\n' "$src" "$dest"
        return 0
    fi

    render_template "$src" >"$dest"
    chmod 644 "$dest"
}

copy_static() {
    local src=$1 dest=$2

    if [[ -e "$dest" && $FORCE_CONFIG -eq 0 ]]; then
        warn "$dest ya existe; se conserva. Usa --force-config para reemplazarlo."
        return 0
    fi

    backup_file "$dest"
    run mkdir -p "$(dirname "$dest")"
    run install -m644 "$src" "$dest"
}

configure_user() {
    log "Enlazando el shell en ~/.config/quickshell/alba."
    local shell_link="$TARGET_HOME/.config/quickshell/alba"
    run mkdir -p "$(dirname "$shell_link")"
    if [[ -e "$shell_link" && ! -L "$shell_link" ]]; then
        warn "$shell_link existe y no es un enlace; no se toca."
    elif [[ -L "$shell_link" ]]; then
        run ln -sfn "$REPO_DIR" "$shell_link"
    else
        run ln -s "$REPO_DIR" "$shell_link"
    fi

    log "Copiando los scripts auxiliares a ~/.local/bin."
    run mkdir -p "$TARGET_HOME/.local/bin"
    run install -m755 "$REPO_DIR"/install/bin/alba-* "$TARGET_HOME/.local/bin/"

    log "Copiando la configuración de ALBA."
    copy_template "$REPO_DIR/install/config/alba-settings.conf" \
        "$TARGET_HOME/.config/alba/settings.conf"
    copy_template "$REPO_DIR/install/config/alba-display.conf" \
        "$TARGET_HOME/.config/alba/display.conf"

    log "Copiando la configuración de Umbriel."
    copy_template "$REPO_DIR/install/config/umbriel-config.toml" \
        "$TARGET_HOME/.config/umbriel/config.toml"

    log "Configurando los portales."
    copy_static "$REPO_DIR/install/config/portals.conf" \
        "$TARGET_HOME/.config/xdg-desktop-portal/portals.conf"

    log "Copiando el autostart del puente X11."
    copy_static "$REPO_DIR/install/config/xwaylandvideobridge.desktop" \
        "$TARGET_HOME/.config/autostart/org.kde.xwaylandvideobridge.desktop"

    log "Instalando la unidad de alarmas."
    local unit="$TARGET_HOME/.config/systemd/user/alba-alarms.service"
    if [[ -e "$unit" && $FORCE_CONFIG -eq 0 ]]; then
        warn "$unit ya existe; se conserva. Usa --force-config para reemplazarlo."
    else
        backup_file "$unit"
        run mkdir -p "$(dirname "$unit")"
        if (( ! DRY_RUN )); then
            cat >"$unit" <<EOF
[Unit]
Description=Alarmas de ALBA
After=graphical-session.target

[Service]
Type=simple
ExecStart=$REPO_DIR/scripts/alba-alarms
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
            chmod 644 "$unit"
        fi
    fi

    run mkdir -p "$TARGET_HOME/.config/systemd/user/default.target.wants"
    run ln -sfn ../alba-alarms.service \
        "$TARGET_HOME/.config/systemd/user/default.target.wants/alba-alarms.service"

    if command -v systemctl >/dev/null 2>&1 \
        && systemctl --user show-environment >/dev/null 2>&1; then
        run systemctl --user daemon-reload
        run systemctl --user enable --now alba-alarms.service
    else
        warn "No hay una sesión systemd de usuario activa; las alarmas arrancarán al entrar."
    fi

    log "Autorizando ddcutil sin contraseña (solo ese comando)."
    if (( DRY_RUN )); then
        printf '\033[2m[dry-run]\033[0m instalar /etc/sudoers.d/alba-ddcutil para %s\n' "$USER_NAME"
    else
        local tmp
        tmp=$(mktemp)
        printf '%s ALL=(ALL) NOPASSWD: /usr/bin/ddcutil\n' "$USER_NAME" >"$tmp"
        run_sudo visudo -cf "$tmp"
        run_sudo install -m440 -o root -g root "$tmp" /etc/sudoers.d/alba-ddcutil
        rm -f "$tmp"
    fi
}

if (( ! SKIP_CONFIG )); then
    configure_user
else
    log "Se omite la configuración de usuario (--skip-config)."
fi

# ---------------------------------------------------------------------------
# Fork de Umbriel
# ---------------------------------------------------------------------------
if (( ! SKIP_FORK )); then
    log "Compilando e instalando el fork de Umbriel."
    if (( DRY_RUN )); then
        "$REPO_DIR/scripts/install-umbriel-fork.sh" --dry-run
    else
        "$REPO_DIR/scripts/install-umbriel-fork.sh" --yes
    fi
else
    log "Se omite el fork de Umbriel (--skip-fork)."
fi

# La validación va después del fork: la plantilla usa los seis botones del
# binario parcheado, que el Umbriel estándar no conoce.
if [[ -f "$TARGET_HOME/.config/umbriel/config.toml" ]] \
    && command -v umbriel >/dev/null 2>&1; then
    log "Validando la configuración de Umbriel."
    run umbriel config validate -c "$TARGET_HOME/.config/umbriel/config.toml" \
        || warn "Umbriel no aceptó la configuración; revisa $TARGET_HOME/.config/umbriel/config.toml."
fi

# ---------------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------------
log "Comprobaciones rápidas."
for cmd in qs umbriel ddcutil nmcli; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '  ok  %s\n' "$cmd"
    else
        warn "No encuentro '$cmd' en PATH."
    fi
done

cat <<EOF

Instalación terminada.

Siguientes pasos:
  1. Cierra sesión y elige «Umbriel» en SDDM.
  2. Comprueba la barra, los escritorios, el brillo y las alarmas.
  3. Si algo falla, revisa INSTALACION.md y PENDIENTES.md.

El fork de Umbriel requiere cerrar sesión para cargarse. Si un 'apt upgrade'
reemplaza /usr/bin/umbriel, vuelve a ejecutar:

  ./scripts/install-umbriel-fork.sh
EOF
