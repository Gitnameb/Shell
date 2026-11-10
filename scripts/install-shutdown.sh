#!/usr/bin/env bash
# Cierre ordenado de la sesión antes de apagar o reiniciar.
#
# systemd ya detiene la sesión del usuario antes de desmontar los discos, pero
# espera hasta 90 s por cada unidad de usuario. Si Steam o un juego de Proton no
# responde, el apagado se alarga y el desmontaje de NTFS puede fallar con
# «Failed unmounting».
#
# Este módulo reduce ese plazo en el gestor de usuario: las aplicaciones reciben
# SIGTERM y, si siguen sin cerrarse, systemd las mata. Es el equivalente al
# «cerrar programas» de Windows, sin pantalla intermedia.
#
# Uso:
#   ./scripts/install-shutdown.sh --dry-run
#   ./scripts/install-shutdown.sh
#   ./scripts/install-shutdown.sh --timeout 15
#   sudo ./scripts/install-shutdown.sh --uninstall
#
# Lo llama install.sh; también se puede ejecutar solo.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

CONF=/etc/systemd/user.conf.d/20-shell-shutdown.conf

DRY_RUN=0
TIMEOUT=20
UNINSTALL=0

usage() {
    cat <<'EOF'
Configura el cierre ordenado de la sesión al apagar o reiniciar.

Opciones:
  --dry-run         Muestra los comandos sin ejecutar nada
  --timeout SEG     Segundos que espera systemd antes de forzar el cierre (20)
  --uninstall       Quita la configuración y vuelve al valor por defecto
  -h, --help        Muestra esta ayuda
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --timeout)
            TIMEOUT="${2:-}"
            shift 2
            ;;
        --uninstall) UNINSTALL=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
done

require_normal_user

if [[ ! "$TIMEOUT" =~ ^[0-9]+$ ]]; then
    die "--timeout espera un número de segundos, no '$TIMEOUT'."
fi
if (( TIMEOUT < 5 )); then
    warn "Con menos de 5 s las aplicaciones no tienen tiempo ni de guardar."
fi

if (( ! DRY_RUN )); then
    sudo -v || die "No se pudo obtener permiso de sudo."
fi

if (( UNINSTALL )); then
    log "Quitando el cierre ordenado de la sesión."
    run_sudo rm -f "$CONF"
    log "Hecho. Se aplicará en el próximo inicio de sesión."
    exit 0
fi

log "Configurando el cierre ordenado de la sesión (${TIMEOUT} s)."
run_sudo install -d -m 755 "$(dirname "$CONF")"
tmp=$(mktemp)
printf '[Manager]\n# Generado por scripts/install-shutdown.sh; no editar a mano.\nDefaultTimeoutStopSec=%ss\n' \
    "$TIMEOUT" >"$tmp"
run_sudo install -m644 "$tmp" "$CONF"
rm -f "$tmp"

log "Listo. Las aplicaciones tendrán ${TIMEOUT} s para cerrarse en el próximo apagado."
log "Se aplica cuando vuelvas a iniciar sesión; no hace falta reiniciar ahora."
