#!/usr/bin/env bash
# Funciones comunes de los scripts de instalación del shell.
#
# Se carga con `source` desde install.sh y desde scripts/install-*.sh.
# Cada script define DRY_RUN antes de llamar a run().

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
    if (( ! ${DRY_RUN:-0} )); then
        "$@"
    fi
}

run_sudo() {
    run sudo "$@"
}

# Los módulos se ejecutan como el usuario normal y piden sudo cuando hace
# falta. Así el instalador no deja archivos con dueño root en el HOME.
require_normal_user() {
    if (( EUID == 0 )); then
        die "Ejecuta este script como tu usuario normal, no con sudo."
    fi
    command -v sudo >/dev/null 2>&1 || die "Falta sudo."
}
