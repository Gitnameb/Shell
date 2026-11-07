#!/bin/bash
# Pruebas de integración de los seis scripts que escriben config.toml.
#
# Comprueba que todos pasan por shell-config-set, que las recargas solo se
# piden cuando hay cambios y que el archivo conserva su estructura.
# No toca la configuración real.
# Uso: ./scripts/test-config-writers.sh

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
REAL_UMBRIEL=$(command -v umbriel || true)
BASE=$(mktemp -d "${TMPDIR:-/tmp}/config-writers-test.XXXXXX")
trap 'rm -rf "$BASE"' EXIT

if [ -z "$REAL_UMBRIEL" ]; then
    echo "falta umbriel en PATH" >&2
    exit 1
fi

BIN="$BASE/bin"
mkdir -p "$BIN" "$BASE/state"
LOG="$BASE/reload.log"
CFG="$BASE/config.toml"
sed "s|/home/USUARIO|$HOME|g" "$REPO_DIR/install/config/umbriel-config.toml" \
    >"$CFG"
chmod 600 "$CFG"
BASE_LINES=$(wc -l <"$CFG")

# El compositor falso registra las recargas, pero delega la validación al
# binario real para que las pruebas no dependan de una sesión gráfica.
cat >"$BIN/umbriel" <<EOF
#!/bin/sh
if [ "\$1" = "config" ] && [ "\$2" = "validate" ]; then
    exec "$REAL_UMBRIEL" "\$@"
fi
if [ "\$1" = "msg" ] && [ "\$2" = "config-reload" ]; then
    printf '%s\n' "\$*" >> "$LOG"
    exit 0
fi
exec "$REAL_UMBRIEL" "\$@"
EOF
chmod 755 "$BIN/umbriel"

export UMBRIEL_CONFIG="$CFG"
export XDG_STATE_HOME="$BASE/state"
export SHELL_CONFIG_SET="$REPO_DIR/install/bin/shell-config-set"
export PATH="$BIN:$PATH"

pass=0
fail=0
check() {
    local name=$1 cond=$2
    if [ "$cond" = 0 ]; then
        printf '  OK    %s\n' "$name"
        pass=$((pass + 1))
    else
        printf '  FALLO %s\n' "$name"
        fail=$((fail + 1))
    fi
}
validate() {
    "$REAL_UMBRIEL" config validate -c "$CFG" >/dev/null 2>&1
}
reloads() {
    if [ -f "$LOG" ]; then
        wc -l <"$LOG"
    else
        echo 0
    fi
}

echo "== 1. mod-hold =="
"$REPO_DIR/scripts/shell-mod-hold" 480 >/dev/null 2>&1
check "sale 0" $?
check "escribe 480" $(grep -q '^mod_hold_delay_ms = 480$' "$CFG"; echo $?)
check "recarga una vez" $([ "$(reloads)" = 1 ]; echo $?)
check "valida" $(validate; echo $?)
"$REPO_DIR/scripts/shell-mod-hold" 480 >/dev/null 2>&1
check "segunda vez no recarga" $([ "$(reloads)" = 1 ]; echo $?)

echo "== 2. tamaño flotante =="
"$REPO_DIR/scripts/shell-floating-defaults" 65 12 >/dev/null 2>&1
check "sale 0" $?
check "escribe ancho" $(grep -q '^default_width_fraction = 0.65$' "$CFG"; echo $?)
check "escribe alto" $(grep -q '^default_height_fraction = 0.65$' "$CFG"; echo $?)
check "escribe cascada" $(grep -q '^cascade_step = 12$' "$CFG"; echo $?)
check "recarga" $([ "$(reloads)" = 2 ]; echo $?)
check "valida" $(validate; echo $?)

echo "== 3. barra de ventanas =="
"$REPO_DIR/scripts/shell-window-chrome" integrated >/dev/null 2>&1
check "sale 0" $?
check "overlay false" $(grep -q '^overlay = false$' "$CFG"; echo $?)
check "recarga" $([ "$(reloads)" = 3 ]; echo $?)

echo "== 4. filtro de pantalla =="
"$REPO_DIR/scripts/shell-display-filter" 0.9 0.1 0.2 >/dev/null 2>&1
check "sale 0" $?
check "brightness" $(grep -q '^brightness = 0.900$' "$CFG"; echo $?)
check "extra_dim" $(grep -q '^extra_dim = 0.100$' "$CFG"; echo $?)
check "warm" $(grep -q '^warm = 0.200$' "$CFG"; echo $?)
check "recarga" $([ "$(reloads)" = 4 ]; echo $?)
check "valida" $(validate; echo $?)

echo "== 5. layout de teclado =="
"$REPO_DIR/install/bin/shell-keyboard-layout" us >/dev/null 2>&1
check "sale 0" $?
check "layout us" $(grep -q '^layout = "us"$' "$CFG"; echo $?)
check "recarga" $([ "$(reloads)" = 5 ]; echo $?)
check "valida" $(validate; echo $?)

echo "== 6. tema oscuro =="
"$REPO_DIR/install/bin/shell-umbriel-theme" dark "#ff0000" >/dev/null 2>&1
check "sale 0" $?
check "fondo oscuro" $(grep -q '^background = "#141519FF"$' "$CFG"; echo $?)
check "acento actualizado" \
    $(grep -q '^accent_primary = ".*FF"$' "$CFG" \
        && ! grep -q '^accent_primary = "#8ab4f8FF"$' "$CFG"; echo $?)
check "recarga" $([ "$(reloads)" = 6 ]; echo $?)
check "valida" $(validate; echo $?)

echo "== 7. tema claro =="
"$REPO_DIR/install/bin/shell-umbriel-theme" light "#ff0000" >/dev/null 2>&1
check "sale 0" $?
check "fondo claro" $(grep -q '^background = "#f4f3f0FF"$' "$CFG"; echo $?)
check "recarga" $([ "$(reloads)" = 7 ]; echo $?)
check "valida" $(validate; echo $?)

echo "== 8. cristal =="
"$REPO_DIR/scripts/shell-glass" blur 18 >/dev/null 2>&1
check "sale 0" $?
check "radius 18" $(grep -q '^radius = 18$' "$CFG"; echo $?)
check "enabled true" $(grep -q '^enabled = true$' "$CFG"; echo $?)
check "recarga" $([ "$(reloads)" = 8 ]; echo $?)
check "valida" $(validate; echo $?)
"$REPO_DIR/scripts/shell-glass" blur 18 >/dev/null 2>&1
check "segunda vez no recarga" $([ "$(reloads)" = 8 ]; echo $?)
"$REPO_DIR/scripts/shell-glass" blur 0 >/dev/null 2>&1
check "cero apaga" $(grep -q '^enabled = false$' "$CFG"; echo $?)
check "cero deja radio 0" $(grep -q '^radius = 0$' "$CFG"; echo $?)
check "valida tras apagar" $(validate; echo $?)

echo "== 9. integridad =="
check "mismas líneas" $([ "$(wc -l <"$CFG")" = "$BASE_LINES" ]; echo $?)
check "comentario preservado" $(grep -q '# Superpuesta: no reserva espacio' "$CFG"; echo $?)
check "autostart intacto" $(grep -q '^autostart = \[' "$CFG"; echo $?)
check "modo 600" $([ "$(stat -c '%a' "$CFG")" = 600 ]; echo $?)
check "sin temporales" $(! ls "$CFG".shell-?????? >/dev/null 2>&1; echo $?)
check "registro del escritor" \
    $([ -s "$XDG_STATE_HOME/shell/config-writer.log" ]; echo $?)

echo
printf 'resultado: %d OK, %d fallos\n' "$pass" "$fail"
[ "$fail" = 0 ]
