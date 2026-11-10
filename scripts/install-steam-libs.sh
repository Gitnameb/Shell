#!/usr/bin/env bash
# Librerías de 32 bits que necesita Steam en Debian 13 amd64.
#
# Steam es un cliente de 32 bits: sin libc6:i386 y el stack gráfico i386 no
# arranca (error «you are missing the following 32-bit libraries: libc.so.6»).
#
# El stack de 64 bits de este equipo viene de trixie-backports (Mesa 26.x,
# libdrm, Wayland). Los paquetes multiarch exigen la misma versión en amd64 e
# i386, así que las librerías de 32 bits también se instalan desde backports.
# Sin `-t trixie-backports`, apt elige las versiones de trixie y falla con
# «held broken packages». Si el repositorio no está configurado, el módulo
# usa el repositorio por defecto para poder ejecutarse por separado.
#
# Uso:
#   ./scripts/install-steam-libs.sh --dry-run
#   ./scripts/install-steam-libs.sh
#
# Lo llama install.sh; también se puede ejecutar solo.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN=0

usage() {
    cat <<'EOF'
Instala las librerías de 32 bits que necesita Steam.

Uso:
  ./scripts/install-steam-libs.sh [opciones]

Opciones:
  --dry-run         Muestra los comandos sin ejecutar nada
  -h, --help        Muestra esta ayuda
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
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

# Núcleo de 32 bits que enlazan el cliente de Steam y su runtime.
STEAM_I386_PKGS=(
    libc6:i386
    libegl1:i386
    libgbm1:i386
    libgl1:i386
    libgl1-mesa-dri:i386
)

need_update=0
if ! dpkg --print-foreign-architectures | grep -qx i386; then
    log "Habilitando la arquitectura i386 para Steam."
    run_sudo dpkg --add-architecture i386
    need_update=1
fi

# Si i386 acaba de habilitarse, o si aún no hay índices i386, hay que
# actualizar apt antes de pedir paquetes de esa arquitectura.
if (( need_update )) || ! apt-cache show libc6:i386 >/dev/null 2>&1; then
    log "Actualizando los índices de apt (incluye i386)."
    run_sudo apt-get update
fi

# Steam publica sus propios metapaquetes en repo.steampowered.com. Debian
# trae los mismos con otro nombre (steam-libs). Se usan los de Steam si están
# disponibles para que la comprobación del lanzador los vea; si no, se usan
# los de Debian para que una instalación limpia funcione sin ese repositorio.
# Se comprueba después de actualizar apt para que, si i386 acaba de
# habilitarse, la lista i386 ya esté cargada.
if apt-cache show steam-libs-amd64 >/dev/null 2>&1 \
    && apt-cache show steam-libs-i386 >/dev/null 2>&1; then
    STEAM_I386_PKGS+=(steam-libs-amd64:amd64 steam-libs-i386:i386)
else
    STEAM_I386_PKGS+=(steam-libs:amd64 steam-libs:i386)
fi

# Si backports está configurado, se instala desde ahí para que las versiones
# amd64 e i386 coincidan con el Mesa/Wayland de 64 bits. Si no lo está (por
# ejemplo, al ejecutar este módulo solo en un Debian recién instalado), se usa
# el repositorio por defecto para no fallar por un release inexistente.
APT_TARGET=()
if grep -Rqs 'trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
    APT_TARGET=(-t trixie-backports)
else
    warn "trixie-backports no está configurado; se usan los repositorios por defecto."
fi

log "Instalando las librerías de 32 bits de Steam."
run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    "${APT_TARGET[@]}" "${STEAM_I386_PKGS[@]}"

if (( ! DRY_RUN )); then
    missing=0
    for pkg in "${STEAM_I386_PKGS[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            warn "No quedó instalado $pkg."
            missing=1
        fi
    done
    if (( missing )); then
        die "Faltan librerías de 32 bits; revisa la salida de apt."
    fi
    if [[ ! -e /lib/i386-linux-gnu/libc.so.6 ]]; then
        die "No aparece /lib/i386-linux-gnu/libc.so.6."
    fi
    log "Librerías de 32 bits de Steam listas."
fi
