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
REPO_SED=$(printf '%s' "$REPO_DIR" | sed 's/[&|\\]/\\&/g')

# Conector de la salida principal. En un portátil se prefiere el panel eDP;
# en un sobremesa, el primer monitor conectado. Así la plantilla no fija
# HDMI-A-1 y funciona en otros equipos.
detect_primary_output() {
    local status name fallback=""
    while IFS= read -r status; do
        [[ -f "$status" ]] || continue
        [[ "$(cat "$status" 2>/dev/null)" == "connected" ]] || continue
        name=${status%/status}
        name=${name##*/}
        name=${name#card*-}
        case "$name" in
            eDP* | LVDS*) printf '%s\n' "$name"; return 0 ;;
        esac
        [[ -n "$fallback" ]] || fallback=$name
    done < <(printf '%s\n' /sys/class/drm/card*-*/status)
    printf '%s\n' "$fallback"
}

PRIMARY_OUTPUT=$(detect_primary_output)
[[ -n "$PRIMARY_OUTPUT" ]] || PRIMARY_OUTPUT="HDMI-A-1"
OUTPUT_SED=$(printf '%s' "$PRIMARY_OUTPUT" | sed 's/[&|\\]/\\&/g')
log "Conector de salida para los nueve escritorios: $PRIMARY_OUTPUT."

render_template() {
    # /home/USUARIO es el HOME de destino, @REPO@ la ruta real del clon y
    # @OUTPUT@ el conector detectado. Los atajos que llaman a scripts del
    # repositorio usan @REPO@ para no depender de que esté en ~/Shell.
    sed -e "s|/home/USUARIO|$HOME_SED|g" \
        -e "s|@REPO@|$REPO_SED|g" \
        -e "s|@OUTPUT@|$OUTPUT_SED|g" "$1"
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

# Thunar abre la terminal con exo-open. Para eso necesita un descriptor en
# ~/.local/share/xfce4/helpers y la categoría TerminalEmulator en
# ~/.config/xfce4/helpers.rc. foot no trae descriptor propio y, sin él,
# «Abrir terminal aquí» falla con:
#   Failed to launch preferred application for category "TerminalEmulator"
ensure_exo_terminal() {
    local rc="$TARGET_HOME/.config/xfce4/helpers.rc"
    local desktop="$TARGET_HOME/.local/share/xfce4/helpers/foot.desktop"
    local src="$REPO_DIR/install/config/xfce4-helpers-foot.desktop"
    local line
    line=$(cat "$REPO_DIR/install/config/xfce4-helpers.rc")

    run mkdir -p "$(dirname "$rc")" "$(dirname "$desktop")"

    # helpers.rc puede tener más categorías (navegador, correo, etc.). Solo se
    # añade TerminalEmulator si falta, para no pisar la configuración del usuario.
    if [[ -f "$rc" ]] && grep -qxF "$line" "$rc"; then
        log "El terminal de Thunar ya está configurado (foot)."
    elif [[ -f "$rc" ]] && grep -q '^TerminalEmulator=' "$rc" \
        && (( ! FORCE_CONFIG )); then
        warn "$rc ya define otro terminal; se conserva. Usa --force-config para cambiarlo."
    else
        backup_file "$rc"
        if (( DRY_RUN )); then
            printf '\033[2m[dry-run]\033[0m escribir %s en %s\n' "$line" "$rc"
        elif [[ -f "$rc" ]] && grep -q '^TerminalEmulator=' "$rc"; then
            local tmp
            tmp=$(mktemp)
            awk -v line="$line" '
                /^TerminalEmulator=/ { print line; next }
                { print }
            ' "$rc" >"$tmp"
            mv "$tmp" "$rc"
            chmod 644 "$rc"
        elif [[ -s "$rc" ]] && [[ -n "$(tail -c 1 "$rc")" ]]; then
            printf '\n%s\n' "$line" >>"$rc"
        else
            printf '%s\n' "$line" >>"$rc"
        fi
    fi

    if [[ -f "$desktop" ]] && cmp -s "$src" "$desktop"; then
        log "El descriptor de foot para exo-open ya está instalado."
    elif [[ -e "$desktop" && $FORCE_CONFIG -eq 0 ]]; then
        warn "$desktop ya existe con otro contenido; se conserva. Usa --force-config para reemplazarlo."
    else
        backup_file "$desktop"
        run install -m644 "$src" "$desktop"
    fi
}

# ---------------------------------------------------------------------------
# Enlaces y archivos del usuario
# ---------------------------------------------------------------------------
log "Enlazando el shell en ~/.config/quickshell/shell."
shell_link="$TARGET_HOME/.config/quickshell/shell"
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
run install -m755 "$REPO_DIR"/install/bin/shell-* "$TARGET_HOME/.local/bin/"
run install -m755 "$REPO_DIR/install/bin/umbriel-config-guard" \
    "$TARGET_HOME/.local/bin/umbriel-config-guard"

log "Copiando la configuración del shell."
copy_template "$REPO_DIR/install/config/shell-settings.conf" \
    "$TARGET_HOME/.config/shell/settings.conf"
copy_template "$REPO_DIR/install/config/shell-display.conf" \
    "$TARGET_HOME/.config/shell/display.conf"
copy_template "$REPO_DIR/install/config/glass-blur.conf" \
    "$TARGET_HOME/.config/shell/glass-blur.conf"

# ---------------------------------------------------------------------------
# Terminal de Thunar
# ---------------------------------------------------------------------------
log "Registrando foot como terminal de exo-open (Thunar)."
if ! command -v foot >/dev/null 2>&1; then
    warn "foot no está instalado; «Abrir terminal aquí» fallará hasta instalarlo."
fi
ensure_exo_terminal

# ---------------------------------------------------------------------------
# Fondo de pantalla
# ---------------------------------------------------------------------------
# La plantilla apunta a ~/.local/share/shell/wallpapers/default.png. Esa copia
# es la que se usa en una instalación nueva: así el fondo no depende de que el
# archivo original siga en Descargas. Si ya hay una configuración con un fondo
# fuera de ese directorio, se copia aquí y se actualiza settings.conf.
wallpaper_dir="$TARGET_HOME/.local/share/shell/wallpapers"
log "Preparando el fondo de pantalla del shell."
run mkdir -p "$wallpaper_dir"
default_wallpaper="$REPO_DIR/install/wallpapers/default.png"
if [[ -f "$default_wallpaper" ]]; then
    if [[ ! -e "$wallpaper_dir/default.png" ]]; then
        run install -m644 "$default_wallpaper" "$wallpaper_dir/default.png"
    else
        log "El fondo por defecto ya está en $wallpaper_dir/default.png."
    fi
else
    warn "Falta $default_wallpaper; la instalación nueva se quedará sin imagen."
fi

migrate_wallpaper() {
    local settings="$TARGET_HOME/.config/shell/settings.conf"
    [[ -f "$settings" ]] || return 0

    local line path name ext dest old
    line=$(grep -m1 '^wallpaperPath=' "$settings" 2>/dev/null || true)
    [[ -n "$line" ]] || return 0
    path=${line#wallpaperPath=}
    [[ -n "$path" && -f "$path" ]] || return 0

    case "$path" in
        "$wallpaper_dir"/*) return 0 ;;
    esac

    name=$(basename -- "$path")
    ext=${name##*.}
    if [[ "$ext" = "$name" || -z "$ext" ]]; then
        ext=png
    fi
    ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    dest="$wallpaper_dir/current.$ext"

    if (( DRY_RUN )); then
        printf '\033[2m[dry-run]\033[0m copiar %s -> %s\n' "$path" "$dest"
        printf '\033[2m[dry-run]\033[0m actualizar wallpaperPath en %s\n' "$settings"
        return 0
    fi

    if ! cp -f -- "$path" "$dest"; then
        warn "No se pudo copiar el fondo actual; se conserva la ruta original."
        return 0
    fi
    chmod 644 "$dest"

    for old in "$wallpaper_dir"/current.*; do
        [[ "$old" = "$dest" ]] && continue
        [[ -e "$old" ]] || continue
        rm -f -- "$old"
    done

    if ! command -v python3 >/dev/null 2>&1; then
        warn "Falta python3; no se pudo actualizar wallpaperPath."
        return 0
    fi

    backup_file "$settings"
    if ! python3 - "$settings" "$dest" <<'PY'
import sys
from pathlib import Path

settings = Path(sys.argv[1])
path = sys.argv[2]
lines = settings.read_text(encoding="utf-8").splitlines()
for index, line in enumerate(lines):
    if line.startswith("wallpaperPath="):
        lines[index] = "wallpaperPath=" + path
        break
settings.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
    then
        warn "No se pudo actualizar wallpaperPath en $settings."
        return 0
    fi

    # Si el shell está abierto, se actualiza también su estado en memoria para
    # que un cambio de ajustes no vuelva a guardar la ruta antigua.
    if command -v qs >/dev/null 2>&1 \
        && timeout 5 qs ipc -c shell call appearance wallpaper "$dest" \
            >/dev/null 2>&1; then
        log "Fondo actualizado en la sesión abierta."
    fi
    log "Fondo actual copiado a $dest."
}

migrate_wallpaper

log "Copiando la configuración de la pantalla de bloqueo."
copy_template "$REPO_DIR/install/config/hyprlock.conf" \
    "$TARGET_HOME/.config/hypr/hyprlock.conf"

log "Copiando la configuración de Umbriel."
copy_template "$REPO_DIR/install/config/umbriel-config.toml" \
    "$TARGET_HOME/.config/umbriel/config.toml"

log "Preparando la red de seguridad de la configuración de Umbriel."
config_dir="$TARGET_HOME/.config/umbriel"
config_file="$config_dir/config.toml"
template_file="$config_dir/config.toml.template"
good_file="$config_dir/config.toml.good"
run mkdir -p "$config_dir"

if (( DRY_RUN )); then
    printf '\033[2m[dry-run]\033[0m render %s -> %s\n' \
        "$REPO_DIR/install/config/umbriel-config.toml" "$template_file"
    printf '\033[2m[dry-run]\033[0m preparar %s desde %s\n' \
        "$good_file" "$template_file"
else
    render_template "$REPO_DIR/install/config/umbriel-config.toml" \
        >"$template_file"
    chmod 644 "$template_file"

    # Copia de referencia con la que reparar un archivo que pierda
    # [general] autostart. Si la configuración actual parece completa y tiene
    # autostart, se conserva tal cual, con los ajustes del usuario. La
    # validación semántica completa se hace después de instalar el edit.
    if [[ ! -s "$good_file" ]]; then
        if [[ -s "$config_file" ]] \
            && awk '
                /^[[:space:]]*\[/ { secciones++ }
                /^[[:space:]]*autostart[[:space:]]*=/ { auto = 1 }
                END { exit !(auto && secciones >= 5) }
            ' "$config_file"; then
            cp "$config_file" "$good_file"
        else
            cp "$template_file" "$good_file"
        fi
    fi
    chmod 644 "$good_file"
fi

# Las reglas de capa del cristal se añaden también a configuraciones que ya
# existían: el cristal no funciona sin ellas, y la plantilla sola no basta.
log "Añadiendo las reglas de cristal del shell a Umbriel."
if (( DRY_RUN )); then
    printf '\033[2m[dry-run]\033[0m %s ensure\n' \
        "$REPO_DIR/scripts/shell-glass"
else
    SHELL_CONFIG_SET="$TARGET_HOME/.local/bin/shell-config-set" \
        UMBRIEL_CONFIG="$config_file" \
        "$REPO_DIR/scripts/shell-glass" ensure \
        || warn "No se pudieron añadir las reglas de cristal; revisa config.toml."
fi

log "Instalando el guardián de configuración de Umbriel."
guard_dropin="$TARGET_HOME/.config/systemd/user/umbriel.service.d/50-config-guard.conf"
run mkdir -p "$(dirname "$guard_dropin")"
if [[ -e "$guard_dropin" ]] \
    && ! cmp -s "$REPO_DIR/install/systemd/umbriel-config-guard.conf" "$guard_dropin"; then
    backup_file "$guard_dropin"
fi
run install -m644 "$REPO_DIR/install/systemd/umbriel-config-guard.conf" \
    "$guard_dropin"

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
unit="$TARGET_HOME/.config/systemd/user/shell-alarms.service"
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
ExecStart="$REPO_DIR/scripts/shell-alarms"
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
        chmod 644 "$unit"
    fi
fi

run mkdir -p "$TARGET_HOME/.config/systemd/user/default.target.wants"
run ln -sfn ../shell-alarms.service \
    "$TARGET_HOME/.config/systemd/user/default.target.wants/shell-alarms.service"

if command -v systemctl >/dev/null 2>&1 \
    && systemctl --user show-environment >/dev/null 2>&1; then
    run systemctl --user daemon-reload \
        || warn "No se pudo recargar systemd de usuario."
    run systemctl --user enable --now shell-alarms.service \
        || warn "No se pudo activar shell-alarms ahora; se activará al entrar."
else
    warn "No hay una sesión systemd de usuario activa; las alarmas arrancarán al entrar."
fi

# ---------------------------------------------------------------------------
# Recarga de unidades de XDG Autostart
# ---------------------------------------------------------------------------
# systemd-xdg-autostart-generator solo se ejecuta al arrancar el gestor de
# usuario o con `daemon-reload`. Si una app activa su arranque automático a
# mitad de sesión (por ejemplo, el portal Background de un Flatpak), su unidad
# no existe hasta el próximo reinicio. Este path unit vigila
# ~/.config/autostart y recarga systemd en cuanto cambia una entrada.
log "Instalando el vigilante de XDG Autostart."
reload_service="$TARGET_HOME/.config/systemd/user/shell-autostart-reload.service"
reload_path="$TARGET_HOME/.config/systemd/user/shell-autostart-reload.path"
if [[ -e "$reload_service" && $FORCE_CONFIG -eq 0 ]]; then
    warn "$reload_service ya existe; se conserva. Usa --force-config para reemplazarlo."
else
    backup_file "$reload_service"
    run mkdir -p "$(dirname "$reload_service")"
    if (( ! DRY_RUN )); then
        cat >"$reload_service" <<EOF
[Unit]
Description=Regenerar las unidades de XDG Autostart

[Service]
Type=oneshot
ExecStart=$REPO_DIR/scripts/shell-autostart-refresh
EOF
        chmod 644 "$reload_service"
    fi
fi
if [[ -e "$reload_path" && $FORCE_CONFIG -eq 0 ]]; then
    warn "$reload_path ya existe; se conserva. Usa --force-config para reemplazarlo."
else
    backup_file "$reload_path"
    run mkdir -p "$(dirname "$reload_path")"
    if (( ! DRY_RUN )); then
        cat >"$reload_path" <<'EOF'
[Unit]
Description=Vigilar ~/.config/autostart y regenerar sus unidades

[Path]
PathChanged=%h/.config/autostart
Unit=shell-autostart-reload.service

[Install]
WantedBy=default.target
EOF
        chmod 644 "$reload_path"
    fi
fi

run mkdir -p "$TARGET_HOME/.config/systemd/user/default.target.wants"
run ln -sfn ../shell-autostart-reload.path \
    "$TARGET_HOME/.config/systemd/user/default.target.wants/shell-autostart-reload.path"

if command -v systemctl >/dev/null 2>&1 \
    && systemctl --user show-environment >/dev/null 2>&1; then
    run systemctl --user daemon-reload \
        || warn "No se pudo recargar systemd de usuario."
    run systemctl --user enable --now shell-autostart-reload.path \
        || warn "No se pudo activar el vigilante ahora; se activará al entrar."
    run "$REPO_DIR/scripts/shell-autostart-refresh" \
        || warn "No se pudieron preparar los drop-ins de autostart."
else
    warn "No hay una sesión systemd de usuario activa; el vigilante arrancará al entrar."
fi

# ---------------------------------------------------------------------------
# Montaje automático de unidades extraíbles
# ---------------------------------------------------------------------------
if command -v udiskie >/dev/null 2>&1; then
    log "Instalando el montaje automático de unidades extraíbles."
    unit="$TARGET_HOME/.config/systemd/user/udiskie.service"
    if [[ -e "$unit" && $FORCE_CONFIG -eq 0 ]]; then
        warn "$unit ya existe; se conserva. Usa --force-config para reemplazarlo."
    else
        backup_file "$unit"
        run mkdir -p "$(dirname "$unit")"
        if (( ! DRY_RUN )); then
            cat >"$unit" <<'EOF'
[Unit]
Description=Montaje automático de unidades extraíbles
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/udiskie --automount --notify
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
            chmod 644 "$unit"
        fi
    fi

    run mkdir -p "$TARGET_HOME/.config/systemd/user/default.target.wants"
    run ln -sfn ../udiskie.service \
        "$TARGET_HOME/.config/systemd/user/default.target.wants/udiskie.service"

    if command -v systemctl >/dev/null 2>&1 \
        && systemctl --user show-environment >/dev/null 2>&1; then
        run systemctl --user daemon-reload \
            || warn "No se pudo recargar systemd de usuario."
        run systemctl --user enable --now udiskie.service \
            || warn "No se pudo activar udiskie ahora; se activará al entrar."
    else
        warn "No hay una sesión systemd de usuario activa; udiskie arrancará al entrar."
    fi
else
    warn "udiskie no está instalado; las unidades USB no se montarán solas."
fi

log "Autorizando ddcutil sin contraseña (solo ese comando)."
if (( DRY_RUN )); then
    printf '\033[2m[dry-run]\033[0m instalar /etc/sudoers.d/shell-ddcutil para %s\n' "$USER_NAME"
else
    tmp=$(mktemp)
    printf '%s ALL=(ALL) NOPASSWD: /usr/bin/ddcutil, /usr/bin/brightnessctl\n' \
        "$USER_NAME" >"$tmp"
    run_sudo visudo -cf "$tmp"
    run_sudo install -m440 -o root -g root "$tmp" /etc/sudoers.d/shell-ddcutil
    rm -f "$tmp"
fi

log "Configuración de usuario instalada."
