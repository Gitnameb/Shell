#!/bin/bash
# Pruebas del escritor único de config.toml.
#
# No toca la configuración real: parte de la plantilla renderizada en un
# directorio temporal.
# Uso: ./scripts/test-config-set.sh

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
WRITER="$REPO_DIR/install/bin/shell-config-set"
BASE=$(mktemp -d "${TMPDIR:-/tmp}/config-set-test.XXXXXX")
trap 'rm -rf "$BASE"' EXIT

export XDG_STATE_HOME="$BASE/state"
mkdir -p "$XDG_STATE_HOME"

template="$BASE/template.toml"
sed "s|/home/USUARIO|$HOME|g" "$REPO_DIR/install/config/umbriel-config.toml" \
    >"$template"

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
fresh() {
    rm -rf "$BASE/case"
    mkdir -p "$BASE/case"
    cp "$template" "$BASE/case/config.toml"
    chmod 600 "$BASE/case/config.toml"
    export UMBRIEL_CONFIG="$BASE/case/config.toml"
}
head_sum() {
    sha256sum "$1" | cut -d' ' -f1
}
remove_key() {
    python3 - "$1" "$2" "$3" <<'PY'
import re
import sys

path, section, key = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8").read()
block_re = re.compile(r"(?ms)^\[%s\][^\[]*" % re.escape(section))


def repl(match):
    block = match.group(0)
    return re.sub(r"(?m)^%s\s*=.*\n?" % re.escape(key), "", block, count=1)


open(path, "w", encoding="utf-8").write(
    block_re.sub(repl, text, count=1))
PY
}
remove_section() {
    python3 - "$1" "$2" <<'PY'
import re
import sys

path, section = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
pattern = re.compile(r"(?ms)^\[%s\][^\[]*" % re.escape(section))
open(path, "w", encoding="utf-8").write(pattern.sub("", text, count=1))
PY
}

echo "== 1. actualiza una clave existente =="
fresh
status=$("$WRITER" --section display brightness=0.123)
check "sale 0" $?
check "dice changed" $([ "$status" = changed ]; echo $?)
check "escribe el valor" $(grep -q '^brightness = 0.123$' "$UMBRIEL_CONFIG"; echo $?)
check "conserva comentarios" $(grep -q '# Superpuesta: no reserva espacio' "$UMBRIEL_CONFIG"; echo $?)
check "conserva autostart" $(grep -q '^autostart = \[' "$UMBRIEL_CONFIG"; echo $?)

echo "== 2. idempotente =="
before=$(head_sum "$UMBRIEL_CONFIG")
status=$("$WRITER" --section display brightness=0.123)
check "sale 0" $?
check "dice unchanged" $([ "$status" = unchanged ]; echo $?)
check "mismo contenido" $([ "$(head_sum "$UMBRIEL_CONFIG")" = "$before" ]; echo $?)

echo "== 3. varias secciones en una llamada =="
fresh
status=$("$WRITER" \
    --section display brightness=0.900 extra_dim=0.100 warm=0.200 \
    --section input mod_hold_delay_ms=480 \
    --section layout.stacking default_width_fraction=0.65 \
    default_height_fraction=0.65 cascade_step=12 \
    --section appearance.title_bar overlay=false \
    --section input.keyboard 'layout="us"')
check "sale 0" $?
check "dice changed" $([ "$status" = changed ]; echo $?)
check "display" $(grep -q '^brightness = 0.900$' "$UMBRIEL_CONFIG"; echo $?)
check "input" $(grep -q '^mod_hold_delay_ms = 480$' "$UMBRIEL_CONFIG"; echo $?)
check "stacking" $(grep -q '^cascade_step = 12$' "$UMBRIEL_CONFIG"; echo $?)
check "overlay" $(grep -q '^overlay = false$' "$UMBRIEL_CONFIG"; echo $?)
check "layout" $(grep -q '^layout = "us"$' "$UMBRIEL_CONFIG"; echo $?)
check "valida" $(umbriel config validate -c "$UMBRIEL_CONFIG" >/dev/null 2>&1; echo $?)

echo "== 4. valor TOML inválido no toca el archivo =="
fresh
before=$(head_sum "$UMBRIEL_CONFIG")
"$WRITER" --section display 'roto=sin comillas' >/dev/null 2>&1
rc=$?
check "devuelve error" $([ "$rc" != 0 ]; echo $?)
check "archivo intacto" $([ "$(head_sum "$UMBRIEL_CONFIG")" = "$before" ]; echo $?)

echo "== 5. clave desconocida no toca el archivo =="
fresh
before=$(head_sum "$UMBRIEL_CONFIG")
"$WRITER" --section display desconocida=1 >/dev/null 2>&1
rc=$?
check "devuelve error" $([ "$rc" != 0 ]; echo $?)
check "archivo intacto" $([ "$(head_sum "$UMBRIEL_CONFIG")" = "$before" ]; echo $?)

echo "== 6. añade una clave conocida que faltaba =="
fresh
remove_key "$UMBRIEL_CONFIG" display warm
status=$("$WRITER" --section display warm=0.500)
check "sale 0" $?
check "dice changed" $([ "$status" = changed ]; echo $?)
check "añade warm" $(grep -q '^warm = 0.500$' "$UMBRIEL_CONFIG"; echo $?)
check "valida" $(umbriel config validate -c "$UMBRIEL_CONFIG" >/dev/null 2>&1; echo $?)

echo "== 7. crea una sección conocida que faltaba =="
fresh
remove_section "$UMBRIEL_CONFIG" display
status=$("$WRITER" --section display brightness=0.800 extra_dim=0.050 warm=0.100)
check "sale 0" $?
check "dice changed" $([ "$status" = changed ]; echo $?)
check "crea sección" $(grep -q '^\[display\]$' "$UMBRIEL_CONFIG"; echo $?)
check "valida" $(umbriel config validate -c "$UMBRIEL_CONFIG" >/dev/null 2>&1; echo $?)

echo "== 8. conserva el modo del archivo =="
fresh
chmod 640 "$UMBRIEL_CONFIG"
"$WRITER" --section input mod_hold_delay_ms=360 >/dev/null
check "modo 640" $([ "$(stat -c '%a' "$UMBRIEL_CONFIG")" = 640 ]; echo $?)

echo "== 9. concurrencia =="
fresh
for n in 1 2 3 4 5 6 7 8; do
    (
        for i in 1 2 3 4 5; do
            "$WRITER" --section display "brightness=0.$((n * 10 + i))" \
                >/dev/null 2>&1 || true
        done
    ) &
done
wait
check "valida" $(umbriel config validate -c "$UMBRIEL_CONFIG" >/dev/null 2>&1; echo $?)
check "188 líneas" $([ "$(wc -l <"$UMBRIEL_CONFIG")" = 188 ]; echo $?)
check "autostart intacto" $(grep -q '^autostart = \[' "$UMBRIEL_CONFIG"; echo $?)
check "sin temporales" $(! ls "$UMBRIEL_CONFIG".shell-?????? >/dev/null 2>&1; echo $?)
check "registro con cambios" $([ -s "$XDG_STATE_HOME/shell/config-writer.log" ]; echo $?)

echo "== 10. limpia temporales huérfanos =="
fresh
touch "$UMBRIEL_CONFIG.shell-orphan"
"$WRITER" --section input mod_hold_delay_ms=340 >/dev/null
check "borra el huérfano" $([ ! -e "$UMBRIEL_CONFIG.shell-orphan" ]; echo $?)
check "conserva el cerrojo" $([ -e "$UMBRIEL_CONFIG.shell-lock" ]; echo $?)

echo
printf 'resultado: %d OK, %d fallos\n' "$pass" "$fail"
[ "$fail" = 0 ]
