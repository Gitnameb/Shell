#!/bin/bash
# Pruebas del guardián de configuración de Umbriel.
#
# No toca la configuración real: trabaja con copias en un directorio temporal.
# Uso: ./scripts/test-config-guard.sh

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
GUARD="$REPO_DIR/install/bin/umbriel-config-guard"
TEMPLATE="$REPO_DIR/install/config/umbriel-config.toml"
BASE=$(mktemp -d "${TMPDIR:-/tmp}/config-guard-test.XXXXXX")
trap 'rm -rf "$BASE"' EXIT

export XDG_STATE_HOME="$BASE/state"
mkdir -p "$XDG_STATE_HOME"

good="$BASE/good.toml"
sed "s|/home/USUARIO|$HOME|g" "$TEMPLATE" >"$good"
unrendered="$BASE/unrendered.toml"
cp "$TEMPLATE" "$unrendered"

cat >"$BASE/broken.toml" <<'EOF'
[display]
brightness = 1.000
extra_dim = 0.000
warm = 0.000

[appearance.title_bar]
overlay = true

[input.keyboard]
layout = "es"

[layout.stacking]
default_width_fraction = 0.60
default_height_fraction = 0.60
cascade_step = 0

[input]
mod_hold_delay_ms = 320
EOF

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
no_broken() {
    ! ls "$1"/config.toml.broken-* >/dev/null 2>&1
}

echo "== 1. configuración válida =="
d="$BASE/1"
mkdir -p "$d"
export UMBRIEL_CONFIG="$d/config.toml"
cp "$good" "$d/config.toml"
"$GUARD" ensure >/dev/null 2>&1
check "ensure sale 0" $?
check "crea copia buena" $([ -s "$d/config.toml.good" ]; echo $?)
check "no crea copia rota" $(no_broken "$d"; echo $?)

echo "== 2. archivo truncado con copia buena =="
d="$BASE/2"
mkdir -p "$d"
export UMBRIEL_CONFIG="$d/config.toml"
cp "$BASE/broken.toml" "$d/config.toml"
cp "$good" "$d/config.toml.good"
"$GUARD" ensure >/dev/null 2>&1
check "ensure sale 0" $?
check "restaura la plantilla completa" $([ "$(wc -l <"$d/config.toml")" = "$(wc -l <"$good")" ]; echo $?)
check "recupera autostart" $(grep -q '^autostart' "$d/config.toml"; echo $?)
check "guarda copia rota" $(ls "$d"/config.toml.broken-* >/dev/null 2>&1; echo $?)

echo "== 3. configuración ausente con copia buena =="
d="$BASE/3"
mkdir -p "$d"
export UMBRIEL_CONFIG="$d/config.toml"
cp "$good" "$d/config.toml.good"
"$GUARD" ensure >/dev/null 2>&1
check "ensure sale 0" $?
check "recrea config" $([ -s "$d/config.toml" ]; echo $?)
check "con autostart" $(grep -q '^autostart' "$d/config.toml"; echo $?)

echo "== 4. autostart = [] intencional no se toca =="
d="$BASE/4"
mkdir -p "$d"
export UMBRIEL_CONFIG="$d/config.toml"
cp "$good" "$d/config.toml.good"
sed 's#^autostart = .*#autostart = []#' "$good" >"$d/config.toml"
"$GUARD" ensure >/dev/null 2>&1
check "ensure sale 0" $?
check "conserva autostart = []" $(grep -q '^autostart = \[\]' "$d/config.toml"; echo $?)
check "no sobrescribe copia buena" \
    $(grep -q '^autostart = \[' "$d/config.toml.good" \
        && ! grep -q '^autostart = \[\]' "$d/config.toml.good"; echo $?)

echo "== 5. TOML inválido con copia buena =="
d="$BASE/5"
mkdir -p "$d"
export UMBRIEL_CONFIG="$d/config.toml"
cp "$good" "$d/config.toml.good"
printf 'esto no es toml\n[[[\n' >"$d/config.toml"
"$GUARD" ensure >/dev/null 2>&1
check "ensure sale 0" $?
check "restaura la plantilla completa" $([ "$(wc -l <"$d/config.toml")" = "$(wc -l <"$good")" ]; echo $?)

echo "== 6. sin copia buena usa la plantilla renderizada =="
d="$BASE/6"
mkdir -p "$d"
export UMBRIEL_CONFIG="$d/config.toml"
cp "$good" "$d/config.toml.template"
cp "$BASE/broken.toml" "$d/config.toml"
"$GUARD" ensure >/dev/null 2>&1
check "ensure sale 0" $?
check "restaura desde plantilla" $([ "$(wc -l <"$d/config.toml")" = "$(wc -l <"$good")" ]; echo $?)

echo "== 7. sin copias no rompe y avisa =="
d="$BASE/7"
mkdir -p "$d"
export UMBRIEL_CONFIG="$d/config.toml"
cp "$BASE/broken.toml" "$d/config.toml"
"$GUARD" ensure >/dev/null 2>&1
rc=$?
check "ensure devuelve 1" $([ "$rc" = 1 ]; echo $?)
check "deja el archivo como estaba" $([ "$(wc -l <"$d/config.toml")" = "$(wc -l <"$BASE/broken.toml")" ]; echo $?)
check "deja copia de la versión rota" $(ls "$d"/config.toml.broken-* >/dev/null 2>&1; echo $?)

echo "== 8. plantilla sin renderizar se rechaza =="
d="$BASE/8"
mkdir -p "$d"
export UMBRIEL_CONFIG="$d/config.toml"
cp "$unrendered" "$d/config.toml.template"
cp "$BASE/broken.toml" "$d/config.toml"
"$GUARD" ensure >/dev/null 2>&1
rc=$?
check "ensure devuelve 1" $([ "$rc" = 1 ]; echo $?)
check "no restaura /home/USUARIO" $(! grep -q '/home/USUARIO' "$d/config.toml"; echo $?)
check "deja el archivo como estaba" $([ "$(wc -l <"$d/config.toml")" = "$(wc -l <"$BASE/broken.toml")" ]; echo $?)

echo
printf 'resultado: %d OK, %d fallos\n' "$pass" "$fail"
[ "$fail" = 0 ]
