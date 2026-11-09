#!/usr/bin/env bash
# Configura Noctalia Greeter como iniciador de sesión.
#
# Instala greetd y noctalia-greeter, escribe la configuración del greeter y
# cambia el gestor de sesión de SDDM a greetd. No detiene SDDM durante la
# sesión actual: el cambio se aplica al reiniciar.
#
# Uso:
#   ./scripts/install-greeter.sh [opciones]
#
# Opciones:
#   --dry-run        Muestra los comandos sin ejecutar nada
#   --yes            No pide confirmación
#   --skip-packages  No instala paquetes; solo configura lo que ya exista
#   --sddm           Mantiene SDDM en vez de usar Noctalia Greeter
#   --force-config   Reemplaza /var/lib/noctalia-greeter/greeter.toml
#   -h, --help       Muestra esta ayuda

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN=0
ASSUME_YES=0
SKIP_PACKAGES=0
USE_SDDM=0
FORCE_CONFIG=0

usage() {
    cat <<'EOF'
Configura el iniciador de sesión sobre Debian 13.

Uso:
  ./scripts/install-greeter.sh [opciones]

Opciones:
  --dry-run        Muestra los comandos sin ejecutar nada
  --yes            No pide confirmación
  --skip-packages  No instala paquetes; solo configura lo que ya exista
  --sddm           Mantiene SDDM en vez de usar Noctalia Greeter
  --force-config   Reemplaza /var/lib/noctalia-greeter/greeter.toml
  -h, --help       Muestra esta ayuda
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --yes) ASSUME_YES=1; shift ;;
        --skip-packages) SKIP_PACKAGES=1; shift ;;
        --sddm) USE_SDDM=1; shift ;;
        --force-config) FORCE_CONFIG=1; shift ;;
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

TARGET_USER=$(id -un)
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
[[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] \
    || die "No se pudo determinar el HOME de $TARGET_USER."

if (( USE_SDDM )); then
    log "Se mantiene SDDM como iniciador de sesión."
    if (( DRY_RUN )) || systemctl list-unit-files greetd.service >/dev/null 2>&1; then
        run_sudo systemctl disable greetd || true
    fi
    if (( DRY_RUN )) || systemctl list-unit-files sddm.service >/dev/null 2>&1; then
        run_sudo systemctl enable sddm || warn "No se pudo habilitar SDDM."
    else
        warn "SDDM no está instalado; no hay iniciador de respaldo."
    fi
    if (( DRY_RUN )); then
        printf '\033[2m[dry-run]\033[0m printf %s > /etc/X11/default-display-manager\n' \
            '/usr/bin/sddm'
    else
        printf '/usr/bin/sddm\n' \
            | run_sudo tee /etc/X11/default-display-manager >/dev/null
    fi
    exit 0
fi

if (( ASSUME_YES == 0 && DRY_RUN == 0 )); then
    cat <<EOF

Se va a cambiar el iniciador de sesión:

  Iniciador actual:  SDDM
  Iniciador nuevo:   Noctalia Greeter (greetd)
  Sesión por defecto: Umbriel
  Usuario:           $TARGET_USER

SDDM se queda instalado como respaldo. El cambio no cierra la sesión actual:
se aplica al reiniciar. Si el greeter no arranca, se puede recuperar SDDM
desde una TTY con:

  sudo systemctl disable greetd && sudo systemctl enable sddm

EOF
    read -r -p "¿Continuar? [s/N] " answer || answer=""
    [[ "$answer" =~ ^[sS]$ ]] || die "Cancelado."
fi

# ---------------------------------------------------------------------------
# Paquetes
# ---------------------------------------------------------------------------
if (( ! SKIP_PACKAGES )); then
    log "Instalando greetd y Noctalia Greeter."
    # --no-install-recommends evita que fonts-noctalia-tabler arrastre el
    # paquete `noctalia` completo. El escritorio usa Umbriel.
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends -t trixie-backports greetd noctalia-greeter
else
    log "Se omiten los paquetes (--skip-packages)."
fi

if (( ! DRY_RUN )) && ! command -v noctalia-greeter-session >/dev/null 2>&1; then
    die "No encuentro noctalia-greeter-session. Instala noctalia-greeter y vuelve a intentarlo."
fi

# El compositor del greeter necesita acceso a las tarjetas DRM. En Debian,
# /dev/dri/* pertenece al grupo video. Es idempotente y solo afecta a _greetd.
if id _greetd >/dev/null 2>&1 || (( DRY_RUN )); then
    log "Añadiendo _greetd al grupo video."
    run_sudo usermod -aG video _greetd
fi

# El paquete de Debian trae este archivo. Se crea solo si falta para que una
# instalación parcial no deje greetd apuntando a agreety.
greetd_conf=/etc/greetd/noctalia-greeter.toml
if [[ ! -f "$greetd_conf" ]]; then
    log "Creando $greetd_conf."
    run_sudo install -d /etc/greetd
    printf '[terminal]\nvt = 7\n\n[default_session]\ncommand = "/usr/bin/noctalia-greeter-session"\nuser = "_greetd"\n' \
        | run_sudo tee "$greetd_conf" >/dev/null
fi

# ---------------------------------------------------------------------------
# Configuración del greeter
# ---------------------------------------------------------------------------
greeter_state=/var/lib/noctalia-greeter
greeter_config="$greeter_state/greeter.toml"
greeter_template="$REPO_DIR/install/config/noctalia-greeter.toml"
wallpaper_dir="$TARGET_HOME/.local/share/shell/wallpapers"

sed_escape() {
    printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

# El fondo del greeter debe poder leerlo _greetd. Por eso se copia al
# directorio de estado y no se referencia una ruta dentro del HOME privado.
wallpaper=""
line=$(grep -m1 '^wallpaperPath=' \
    "$TARGET_HOME/.config/shell/settings.conf" 2>/dev/null || true)
path=${line#wallpaperPath=}
if [[ -n "$path" && -f "$path" ]]; then
    wallpaper=$path
fi
if [[ -z "$wallpaper" ]]; then
    for candidate in "$wallpaper_dir"/current.*; do
        if [[ -f "$candidate" ]]; then
            wallpaper=$candidate
            break
        fi
    done
fi
if [[ -z "$wallpaper" && -f "$wallpaper_dir/default.png" ]]; then
    wallpaper="$wallpaper_dir/default.png"
fi
if [[ -z "$wallpaper" && -f "$REPO_DIR/install/wallpapers/default.png" ]]; then
    wallpaper="$REPO_DIR/install/wallpapers/default.png"
fi

greeter_wallpaper="color:#0b0d10"
if [[ -n "$wallpaper" ]]; then
    ext=${wallpaper##*.}
    ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    greeter_wallpaper="$greeter_state/wallpaper.$ext"
fi

write_greeter=1
if [[ -f "$greeter_config" && $FORCE_CONFIG -eq 0 ]]; then
    warn "$greeter_config ya existe; se conserva. Usa --force-config para reemplazarlo."
    write_greeter=0
fi

if (( write_greeter )); then
    # Crea el estado inicial (greeter.toml y sync.toml) con el dueño correcto.
    # Se hace antes de escribir nuestra plantilla para que el paquete no deje
    # un archivo a medias; después se sustituye greeter.toml por el del repo.
    if (( DRY_RUN )); then
        printf '\033[2m[dry-run]\033[0m sudo install -d -o _greetd -g _greetd -m750 %s\n' \
            "$greeter_state"
        printf '\033[2m[dry-run]\033[0m sudo noctalia-greeter-apply-appearance --setup-system\n'
    else
        run_sudo install -d -o _greetd -g _greetd -m750 "$greeter_state"
        if command -v noctalia-greeter-apply-appearance >/dev/null 2>&1; then
            run_sudo noctalia-greeter-apply-appearance --setup-system \
                || warn "No se pudo inicializar el estado del greeter; se continúa."
        fi
    fi

    if [[ -n "$wallpaper" ]]; then
        log "Copiando el fondo del greeter desde $wallpaper."
        if (( DRY_RUN )); then
            printf '\033[2m[dry-run]\033[0m instalar %s como %s\n' \
                "$wallpaper" "$greeter_wallpaper"
        else
            run_sudo install -d -o _greetd -g _greetd -m750 "$greeter_state"
            run_sudo install -o _greetd -g _greetd -m644 \
                "$wallpaper" "$greeter_wallpaper"
            run_sudo find "$greeter_state" -maxdepth 1 -type f \
                -name 'wallpaper.*' ! -name "wallpaper.${greeter_wallpaper##*.}" \
                -delete
        fi
    fi

    log "Escribiendo la configuración de Noctalia Greeter."
    user_escaped=$(sed_escape "$TARGET_USER")
    wallpaper_escaped=$(sed_escape "$greeter_wallpaper")
    if (( DRY_RUN )); then
        printf '\033[2m[dry-run]\033[0m render %s -> %s\n' \
            "$greeter_template" "$greeter_config"
        sed -e "s|@USER@|$user_escaped|g" \
            -e "s|/var/lib/noctalia-greeter/wallpaper.png|$wallpaper_escaped|g" \
            "$greeter_template" | sed 's/^/  /'
    else
        tmp=$(mktemp)
        sed -e "s|@USER@|$user_escaped|g" \
            -e "s|/var/lib/noctalia-greeter/wallpaper.png|$wallpaper_escaped|g" \
            "$greeter_template" >"$tmp"
        run_sudo install -d -o _greetd -g _greetd -m750 "$greeter_state"
        run_sudo install -o _greetd -g _greetd -m600 "$tmp" "$greeter_config"
        rm -f "$tmp"
    fi
fi

# ---------------------------------------------------------------------------
# Cambio de gestor de sesión
# ---------------------------------------------------------------------------
log "Activando greetd y desactivando SDDM."
run_sudo systemctl enable greetd \
    || die "No se pudo habilitar greetd; SDDM sigue habilitado."
run_sudo systemctl disable sddm \
    || warn "SDDM no estaba habilitado."

if (( DRY_RUN )); then
    printf '\033[2m[dry-run]\033[0m printf %s > /etc/X11/default-display-manager\n' \
        '/usr/sbin/greetd'
else
    printf '/usr/sbin/greetd\n' \
        | run_sudo tee /etc/X11/default-display-manager >/dev/null
    if systemctl is-active --quiet sddm 2>/dev/null; then
        log "SDDM sigue abierto en esta sesión. El cambio se verá al reiniciar."
    fi
fi

log "Iniciador de sesión configurado."
cat <<EOF

  Iniciador:  Noctalia Greeter (greetd)
  Sesión:     Umbriel
  Usuario:    $TARGET_USER
  Fondo:      $greeter_wallpaper

Reinicia para entrar por Noctalia Greeter. Si no arranca, recupera SDDM desde
una TTY con:

  sudo systemctl disable greetd
  sudo systemctl enable sddm

EOF
