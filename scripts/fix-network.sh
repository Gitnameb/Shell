#!/usr/bin/env bash
# Compatibilidad: el antiguo fix-network.sh ahora es scripts/network.sh.
#
# Se conserva este envoltorio para que las instrucciones antiguas y los
# alias existentes sigan funcionando. Ambos aceptan las mismas opciones.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

printf '\033[1;33maviso:\033[0m fix-network.sh pasa a llamarse network.sh; usando el nuevo script.\n' >&2
exec "$SCRIPT_DIR/network.sh" "$@"
