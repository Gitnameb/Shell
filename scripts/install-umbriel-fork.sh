#!/usr/bin/env bash
# Compila el fork de Umbriel y sustituye /usr/bin/umbriel de forma atómica.
#
# Uso:
#   ./scripts/install-umbriel-fork.sh [opciones]
#
# Opciones:
#   --source DIR      Árbol de Umbriel (por defecto ~/umbriel-fork)
#   --patch FILE      Parche para reconstruir el fork (por defecto el del repo)
#   --build-dir DIR   Directorio de compilación (por defecto DIR/build)
#   --build-only      Compila y valida, pero no instala
#   --no-backup       No guarda copia del binario actual
#   --dry-run         Muestra los comandos sin ejecutarlos
#   --yes             No pide confirmación antes de instalar
#   -h, --help        Muestra esta ayuda
#
# El script se ejecuta como usuario normal. Solo usa sudo para escribir en
# /usr/bin y para guardar la copia del binario original.

set -Eeuo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PATCH="${REPO_DIR}/umbriel-fork.patch"
UPSTREAM="${UMBRIEL_UPSTREAM:-https://github.com/noctalia-dev/umbriel.git}"
BASE_COMMIT="${UMBRIEL_BASE_COMMIT:-b6c4b7d}"
SOURCE_DIR="${UMBRIEL_FORK_DIR:-$HOME/umbriel-fork}"
# Por defecto se instala el fork propio, sin depender del Umbriel original.
# UMBRIEL_FORK_REPO= (vacío) fuerza el modo antiguo: upstream + parche.
FORK_REPO="${UMBRIEL_FORK_REPO-https://github.com/Gitnameb/umbriel-shell.git}"
FORK_BRANCH="${UMBRIEL_FORK_BRANCH:-main}"
BUILD_DIR=""
INSTALLED_BIN="/usr/bin/umbriel"

DRY_RUN=0
ASSUME_YES=0
BUILD_ONLY=0
BACKUP=1
DIVERT=1

usage() {
    cat <<'EOF'
Compila el fork de Umbriel y sustituye /usr/bin/umbriel de forma atómica.

Uso:
  ./scripts/install-umbriel-fork.sh [opciones]

Opciones:
  --source DIR      Árbol de Umbriel (por defecto ~/umbriel-fork)
  --fork-repo URL   Clonar un fork propio en vez de aplicar el parche
  --fork-branch B   Rama del fork (por defecto shell-fork)
  --patch FILE      Parche para reconstruir el fork (por defecto el del repo)
  --build-dir DIR   Directorio de compilación (por defecto DIR/build)
  --build-only      Compila y valida, pero no instala
  --no-backup       No guarda copia del binario actual
  --no-divert       No aparta /usr/bin/umbriel con dpkg-divert
  --dry-run         Muestra los comandos sin ejecutarlos
  --yes             No pide confirmación antes de instalar
  -h, --help        Muestra esta ayuda
EOF
}

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

sha() {
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
}

while (( $# > 0 )); do
    case "$1" in
        --source)
            [[ $# -ge 2 ]] || die "Falta el valor de --source"
            SOURCE_DIR=$2
            shift 2
            ;;
        --fork-repo)
            [[ $# -ge 2 ]] || die "Falta el valor de --fork-repo"
            FORK_REPO=$2
            shift 2
            ;;
        --fork-branch)
            [[ $# -ge 2 ]] || die "Falta el valor de --fork-branch"
            FORK_BRANCH=$2
            shift 2
            ;;
        --patch)
            [[ $# -ge 2 ]] || die "Falta el valor de --patch"
            PATCH=$2
            shift 2
            ;;
        --build-dir)
            [[ $# -ge 2 ]] || die "Falta el valor de --build-dir"
            BUILD_DIR=$2
            shift 2
            ;;
        --build-only)
            BUILD_ONLY=1
            shift
            ;;
        --no-backup)
            BACKUP=0
            shift
            ;;
        --no-divert)
            DIVERT=0
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --yes)
            ASSUME_YES=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "Opción desconocida: $1 (usa --help)"
            ;;
    esac
done

if (( EUID == 0 )); then
    die "Ejecuta este script como tu usuario normal, no con sudo."
fi

for cmd in git meson ninja cmake sudo; do
    command -v "$cmd" >/dev/null 2>&1 || die "Falta '$cmd'. Ejecuta primero ./install.sh."
done

[[ -f "$PATCH" ]] || die "No encuentro el parche: $PATCH"

BUILD_DIR="${BUILD_DIR:-$SOURCE_DIR/build}"
BINARY="$BUILD_DIR/umbriel"

# Normalizar rutas relativas para que el script funcione desde cualquier sitio.
case "$SOURCE_DIR" in /*) ;; *) SOURCE_DIR="$(pwd)/$SOURCE_DIR" ;; esac
case "$BUILD_DIR" in /*) ;; *) BUILD_DIR="$(pwd)/$BUILD_DIR" ;; esac
case "$PATCH" in /*) ;; *) PATCH="$(pwd)/$PATCH" ;; esac
BINARY="$BUILD_DIR/umbriel"

if (( ! DRY_RUN && ! BUILD_ONLY )); then
    sudo -v || die "No se pudo obtener permiso de sudo."
fi

log "Árbol de Umbriel: $SOURCE_DIR"
log "Parche: $PATCH"
log "Compilación: $BUILD_DIR"

# ---------------------------------------------------------------------------
# 1. Preparar el código
# ---------------------------------------------------------------------------
if [[ -n "$FORK_REPO" ]]; then
    if [[ -d "$SOURCE_DIR/.git" ]]; then
        log "Usando el árbol del fork ya existente en $SOURCE_DIR."
    elif [[ -e "$SOURCE_DIR" ]]; then
        die "$SOURCE_DIR existe y no es un repositorio git."
    elif ! run git clone --branch "$FORK_BRANCH" "$FORK_REPO" "$SOURCE_DIR"; then
        warn "No se pudo clonar el fork; se usará el Umbriel original con el parche."
        FORK_REPO=""
    fi
fi

if [[ -z "$FORK_REPO" ]]; then
    if [[ -d "$SOURCE_DIR/.git" ]]; then
        if [[ -n "$(git -C "$SOURCE_DIR" status --porcelain 2>/dev/null)" ]]; then
            log "El árbol tiene cambios locales; se compila tal cual."
        else
            current=$(git -C "$SOURCE_DIR" rev-parse HEAD 2>/dev/null || true)
            base=$(git -C "$SOURCE_DIR" rev-parse "$BASE_COMMIT" 2>/dev/null || true)
            if [[ "$current" == "$base" ]]; then
                log "Aplicando el parche del fork."
                run git -C "$SOURCE_DIR" apply "$PATCH"
            elif git -C "$SOURCE_DIR" merge-base --is-ancestor "$base" "$current"; then
                log "El árbol ya contiene los commits del fork; se compila tal cual."
            else
                log "Árbol limpio; se cambia a la base $BASE_COMMIT."
                run git -C "$SOURCE_DIR" checkout -B shell-fork "$BASE_COMMIT"
                run git -C "$SOURCE_DIR" apply "$PATCH"
            fi
        fi
    elif [[ -d "$SOURCE_DIR" ]]; then
        warn "El directorio no es un repositorio git; se compila tal cual."
    else
        log "Clonando Umbriel desde $UPSTREAM."
        run git clone "$UPSTREAM" "$SOURCE_DIR"
        run git -C "$SOURCE_DIR" checkout -B shell-fork "$BASE_COMMIT"
        run git -C "$SOURCE_DIR" apply "$PATCH"
    fi
fi

# ---------------------------------------------------------------------------
# 2. Compilar
# ---------------------------------------------------------------------------
if [[ -f "$BUILD_DIR/build.ninja" ]]; then
    log "Reconfigurando el directorio de compilación."
    if ! run meson setup --reconfigure "$BUILD_DIR" --prefix=/usr --buildtype=release; then
        warn "La reconfiguración falló; se recrea $BUILD_DIR."
        run rm -rf "$BUILD_DIR"
        run meson setup "$BUILD_DIR" "$SOURCE_DIR" --prefix=/usr --buildtype=release
    fi
else
    log "Configurando la compilación."
    run meson setup "$BUILD_DIR" "$SOURCE_DIR" --prefix=/usr --buildtype=release
fi

log "Compilando."
run ninja -C "$BUILD_DIR"

if (( ! DRY_RUN )); then
    [[ -x "$BINARY" ]] || die "No se generó el binario: $BINARY"
    missing=$(ldd "$BINARY" 2>/dev/null | grep 'not found' || true)
    [[ -z "$missing" ]] || die "Faltan bibliotecas para ejecutar el binario:
$missing"
fi

log "Binario compilado: $BINARY"

if (( BUILD_ONLY )); then
    log "Modo --build-only: no se instala nada."
    exit 0
fi

# La plantilla ya incluye el botón de volumen, pero una instalación anterior
# conserva su lista de botones. Solo se añade cuando sigue siendo exactamente
# la lista por defecto del shell: una lista personalizada no se toca. Se llama
# también cuando el binario ya está instalado, para completar la migración.
ensure_volume_button() {
    local config_toml="$HOME/.config/umbriel/config.toml"
    local config_setter add_volume
    config_setter=$(command -v shell-config-set 2>/dev/null || true)
    if [[ -z "$config_setter" && -x "$HOME/.local/bin/shell-config-set" ]]; then
        config_setter="$HOME/.local/bin/shell-config-set"
    fi
    [[ -f "$config_toml" && -n "$config_setter" ]] || return 0
    add_volume=$(
        python3 - "$config_toml" <<'PY' 2>/dev/null || echo no
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    config = tomllib.load(handle)
buttons = config.get("appearance", {}).get("title_bar", {}).get("buttons")
legacy = ["float", "pin", "fullscreen", "move", "minimize", "maximize", "close"]
print("yes" if buttons == legacy else "no")
PY
    )
    [[ "$add_volume" == "yes" ]] || return 0
    log "Añadiendo el botón de volumen a la barra de título."
    run "$config_setter" --section appearance.title_bar \
        buttons='["volume", "float", "pin", "fullscreen", "move", "minimize", "maximize", "close"]' \
        || warn "No se pudo añadir el botón de volumen; revisa $config_toml."
    if [[ -x "$HOME/.local/bin/umbriel-config-guard" ]]; then
        run env UMBRIEL_CONFIG="$config_toml" \
            "$HOME/.local/bin/umbriel-config-guard" save \
            || warn "No se pudo actualizar config.toml.good."
    fi
}

# ---------------------------------------------------------------------------
# 3. Instalar
# ---------------------------------------------------------------------------
build_hash=$(sha "$BINARY" 2>/dev/null || true)
current_hash=$(sha "$INSTALLED_BIN" 2>/dev/null || true)

if [[ -n "$build_hash" && "$build_hash" == "$current_hash" ]]; then
    log "El binario instalado ya es este mismo fork. No hay nada que hacer."
    ensure_volume_button
    exit 0
fi

if (( ! ASSUME_YES && ! DRY_RUN )); then
    printf '\nSe va a sustituir %s por el fork compilado.\n' "$INSTALLED_BIN"
    read -r -p "¿Continuar? [s/N] " answer || answer=""
    [[ "$answer" =~ ^[sSyY]$ ]] || die "Cancelado."
fi

# Un `apt upgrade` del paquete oficial escribe /usr/bin/umbriel y borraría el
# fork. La diversión local hace que el paquete escriba en
# /usr/bin/umbriel.distrib y deja intacto el binario compilado.
if (( DIVERT )); then
    if ! dpkg-divert --list /usr/bin/umbriel 2>/dev/null |
            grep -q '^diversion of /usr/bin/umbriel '; then
        log "Apartando el binario oficial con dpkg-divert."
        run_sudo dpkg-divert --local --rename --add /usr/bin/umbriel
    else
        log "El binario oficial ya está apartado con dpkg-divert."
    fi
else
    warn "Sin dpkg-divert, apt o install-packages pueden volver a sustituir el fork."
fi

if (( BACKUP )) && (( ! DIVERT )); then
    if compgen -G "/usr/bin/umbriel.stock-*" >/dev/null 2>&1; then
        log "Ya existe una copia del binario original; no se sobrescribe."
    elif dpkg -V umbriel 2>/dev/null | grep -q '/usr/bin/umbriel$'; then
        warn "El binario actual no coincide con el del paquete; no se guarda como original."
    else
        version=$(dpkg-query -W -f='${Version}' umbriel 2>/dev/null | cut -d'~' -f1 || true)
        [[ -n "$version" ]] || version=$(date +%Y%m%d)
        stock="/usr/bin/umbriel.stock-$version"
        run_sudo cp -a "$INSTALLED_BIN" "$stock"
        log "Copia del binario original: $stock"
    fi
fi

log "Instalando de forma atómica."
tmp="/usr/bin/.umbriel.new.$$"
cleanup() {
    if (( ! DRY_RUN )) && [[ -n "${tmp:-}" ]]; then
        sudo rm -f "$tmp" 2>/dev/null || true
    fi
}
trap cleanup EXIT

run_sudo install -m755 -o root -g root "$BINARY" "$tmp"
run_sudo mv -f "$tmp" "$INSTALLED_BIN"
tmp=""

if (( DRY_RUN )); then
    log "Simulación completada: no se ha instalado nada."
    exit 0
fi

installed_hash=$(sha "$INSTALLED_BIN" 2>/dev/null || true)
[[ "$installed_hash" == "$build_hash" ]] || die "La instalación no coincide con el binario compilado."

log "Fork instalado correctamente."
"$INSTALLED_BIN" --version 2>/dev/null || warn "No se pudo comprobar 'umbriel --version'."

ensure_volume_button

cat <<'EOF'

Cierra sesión y vuelve a entrar para que el compositor use el binario nuevo.
El binario oficial queda en /usr/bin/umbriel.distrib y los futuros
`apt upgrade` no deberían pisar el fork. Si alguna vez quieres volver al
oficial, quita la diversión con:

  sudo dpkg-divert --local --rename --remove /usr/bin/umbriel

EOF
