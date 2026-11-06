#!/usr/bin/env bash
# Módulo de configuración de usuario del instalador del shell.
#
# Enlaza el shell, copia los scripts auxiliares y las plantillas de
# configuración, e instala la unidad de usuario de las alarmas. Lo llama
# install.sh; también se puede ejecutar solo:
#
#   ./scripts/install-user-config.sh --dry-run
#   ./scripts/install-user-config.sh --force-config

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN=0
FORCE_CONFIG=0

usage() {
    cat <<'EOF'
Copia la configuración del shell al HOME del usuario actual.

Uso:
  ./scripts/install-user-config.sh [opciones]

Opciones:
  --dry-run       Muestra los comandos sin ejecutar nada
  --force-config  Reemplaza configuraciones existentes (hace copia .bak)
  -h, --help      Muestra esta ayuda
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --force-config) FORCE_CONFIG=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
done

require_normal_user

USER_NAME=$(id -un)
TARGET_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
[[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] \
    || die "No se pudo determinar el HOME de $USER_NAME."

if (( ! DRY_RUN )); then
    sudo -v || die "No se pudo obtener permiso de sudo."
fi

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

# ---------------------------------------------------------------------------
# Enlaces y archivos del usuario
# ---------------------------------------------------------------------------
log "Enlazando el shell en ~/.config/quickshell/alba."
shell_link="$TARGET_HOME/.config/quickshell/alba"
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

log "Copiando la configuración del shell."
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

# ---------------------------------------------------------------------------
# Alarmas
# ---------------------------------------------------------------------------
log "Instalando la unidad de alarmas."
unit="$TARGET_HOME/.config/systemd/user/alba-alarms.service"
if [[ -e "$unit" && $FORCE_CONFIG -eq 0 ]]; then
    warn "$unit ya existe; se conserva. Usa --force-config para reemplazarlo."
else
    backup_file "$unit"
    run mkdir -p "$(dirname "$unit")"
    if (( ! DRY_RUN )); then
        cat >"$unit" <<EOF
[Unit]
Description=Alarmas del shell
After=graphical-session.target

[Service]
Type=simple
ExecStart="$REPO_DIR/scripts/alba-alarms"
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
    run systemctl --user daemon-reload \
        || warn "No se pudo recargar systemd de usuario."
    run systemctl --user enable --now alba-alarms.service \
        || warn "No se pudo activar alba-alarms ahora; se activará al entrar."
else
    warn "No hay una sesión systemd de usuario activa; las alarmas arrancarán al entrar."
fi

log "Autorizando ddcutil sin contraseña (solo ese comando)."
if (( DRY_RUN )); then
    printf '\033[2m[dry-run]\033[0m instalar /etc/sudoers.d/alba-ddcutil para %s\n' "$USER_NAME"
else
    tmp=$(mktemp)
    printf '%s ALL=(ALL) NOPASSWD: /usr/bin/ddcutil\n' "$USER_NAME" >"$tmp"
    run_sudo visudo -cf "$tmp"
    run_sudo install -m440 -o root -g root "$tmp" /etc/sudoers.d/alba-ddcutil
    rm -f "$tmp"
fi

log "Configuración de usuario instalada."
