#!/bin/bash
# Pruebas de las reglas de cristal y del radio de desenfoque.
#
# No toca la configuración real: trabaja sobre una copia de la plantilla.
# Uso: ./scripts/test-glass-rules.sh

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
GLASS="$REPO_DIR/scripts/shell-glass"
WRITER="$REPO_DIR/install/bin/shell-config-set"
BASE=$(mktemp -d "${TMPDIR:-/tmp}/glass-rules-test.XXXXXX")
trap 'rm -rf "$BASE"' EXIT

export XDG_STATE_HOME="$BASE/state"
export SHELL_CONFIG_SET="$WRITER"
mkdir -p "$XDG_STATE_HOME"
# El tono se prueba con valores conocidos, sin depender del archivo del usuario.
export SHELL_GLASS_BLUR_CONF="$BASE/glass-blur.conf"
cat >"$SHELL_GLASS_BLUR_CONF" <<'EOF'
DARK_BRIGHTNESS=0.700
DARK_CONTRAST=0.900
DARK_SATURATION=1.050
LIGHT_BRIGHTNESS=1.100
LIGHT_CONTRAST=0.960
LIGHT_SATURATION=1.030
BLUR_PASSES=4
EOF

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
validate() {
    umbriel config validate -c "$UMBRIEL_CONFIG" >/dev/null 2>&1
}
drop_rules() {
    python3 - "$UMBRIEL_CONFIG" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = re.sub(r"\n# shell-glass: inicio.*?# shell-glass: fin\n?", "\n", text,
              flags=re.S)
path.write_text(text, encoding="utf-8")
PY
}

echo "== 1. la plantilla ya trae las reglas =="
fresh
check "marcador presente" $(grep -q '^# shell-glass: inicio$' "$UMBRIEL_CONFIG"; echo $?)
check "regla del bar" $(grep -qF 'bar|side-panel' "$UMBRIEL_CONFIG"; echo $?)
check "excluye el filtro" $(grep -q 'wallpaper|desktop-icons' "$UMBRIEL_CONFIG"; echo $?)
check "recorta esquinas" $(grep -q '^blur_ignore_alpha = 0.04$' "$UMBRIEL_CONFIG"; echo $?)
check "modo fondo por defecto" $(grep -q '^blur_optimized = true$' "$UMBRIEL_CONFIG"; echo $?)
check "valida" $(validate; echo $?)
status=$("$GLASS" ensure)
check "ensure no cambia" $([ "$status" = unchanged ]; echo $?)

echo "== 2. añade las reglas a una configuración antigua =="
fresh
drop_rules
check "sin reglas" $(! grep -q 'shell-glass' "$UMBRIEL_CONFIG"; echo $?)
status=$("$GLASS" ensure)
check "dice changed" $([ "$status" = changed ]; echo $?)
check "marcador" $(grep -q '^# shell-glass: inicio$' "$UMBRIEL_CONFIG"; echo $?)
check "dos reglas" $([ "$(grep -c '^\[\[layer_rule\]\]$' "$UMBRIEL_CONFIG")" = 2 ]; echo $?)
check "valida" $(validate; echo $?)
check "autostart intacto" $(grep -q '^autostart = \[' "$UMBRIEL_CONFIG"; echo $?)
check "modo 600" $([ "$(stat -c '%a' "$UMBRIEL_CONFIG")" = 600 ]; echo $?)

echo "== 3. idempotente =="
before=$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)
status=$("$GLASS" ensure)
check "unchanged" $([ "$status" = unchanged ]; echo $?)
check "mismo contenido" $([ "$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)" = "$before" ]; echo $?)
check "solo dos reglas" $([ "$(grep -c '^\[\[layer_rule\]\]$' "$UMBRIEL_CONFIG")" = 2 ]; echo $?)

echo "== 4. sin configuración no falla =="
export UMBRIEL_CONFIG="$BASE/inexistente.toml"
"$GLASS" ensure
check "sale 0" $?

echo "== 5. estado =="
fresh
out=$("$GLASS" status)
check "reglas presentes" $(printf '%s\n' "$out" | grep -q 'reglas: presentes'; echo $?)
check "radio visible" $(printf '%s\n' "$out" | grep -q 'radius=16'; echo $?)
check "modo fondo" $(printf '%s\n' "$out" | grep -q 'desenfoque: fondo de pantalla'; echo $?)
check "esquinas recortadas" $(printf '%s\n' "$out" | grep -q 'esquinas: recortadas'; echo $?)

echo "== 6. radio fuera de rango =="
fresh
before=$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)
"$GLASS" blur 101 >/dev/null 2>&1
rc=$?
check "rechaza 101" $([ "$rc" != 0 ]; echo $?)
"$GLASS" blur texto >/dev/null 2>&1
rc=$?
check "rechaza texto" $([ "$rc" != 0 ]; echo $?)
check "archivo intacto" $([ "$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)" = "$before" ]; echo $?)

echo "== 7. desenfoca el contenido de detrás =="
fresh
status=$("$GLASS" mode behind)
check "dice changed" $([ "$status" = changed ]; echo $?)
check "optimized false" $(grep -q '^blur_optimized = false$' "$UMBRIEL_CONFIG"; echo $?)
check "conserva el recorte" $(grep -q '^blur_ignore_alpha = 0.04$' "$UMBRIEL_CONFIG"; echo $?)
check "solo un bloque" $([ "$(grep -c '^# shell-glass: inicio$' "$UMBRIEL_CONFIG")" = 1 ]; echo $?)
check "valida" $(validate; echo $?)
out=$("$GLASS" status)
check "estado contenido" $(printf '%s\n' "$out" | grep -q 'desenfoque: contenido detrás'; echo $?)
before=$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)
status=$("$GLASS" mode behind)
check "repetir unchanged" $([ "$status" = unchanged ]; echo $?)
check "mismo contenido" $([ "$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)" = "$before" ]; echo $?)

echo "== 8. vuelve al fondo de pantalla =="
status=$("$GLASS" mode wallpaper)
check "dice changed" $([ "$status" = changed ]; echo $?)
check "optimized true" $(grep -q '^blur_optimized = true$' "$UMBRIEL_CONFIG"; echo $?)
check "valida" $(validate; echo $?)

echo "== 9. modo inválido no toca el archivo =="
before=$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)
"$GLASS" mode cualquiera >/dev/null 2>&1
rc=$?
check "rechaza el modo" $([ "$rc" != 0 ]; echo $?)
check "archivo intacto" $([ "$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)" = "$before" ]; echo $?)

echo "== 10. actualiza un bloque antiguo sin máscara =="
fresh
drop_rules
cat >>"$UMBRIEL_CONFIG" <<'EOF'

# shell-glass: inicio
[[layer_rule]]
match.namespace = "^shell-(bar|side-panel)$"
blur = true
blur_popups = true

[[layer_rule]]
match.namespace = "^shell-(wallpaper|desktop-icons)$"
blur = false
# shell-glass: fin
EOF
status=$("$GLASS" ensure)
check "dice changed" $([ "$status" = changed ]; echo $?)
check "añade la máscara" $(grep -q '^blur_ignore_alpha = 0.04$' "$UMBRIEL_CONFIG"; echo $?)
check "añade el modo" $(grep -q '^blur_optimized = true$' "$UMBRIEL_CONFIG"; echo $?)
check "solo un bloque" $([ "$(grep -c '^# shell-glass: inicio$' "$UMBRIEL_CONFIG")" = 1 ]; echo $?)
check "valida" $(validate; echo $?)

echo "== 11. la actualización conserva el modo de detrás =="
fresh
drop_rules
cat >>"$UMBRIEL_CONFIG" <<'EOF'

# shell-glass: inicio
[[layer_rule]]
match.namespace = "^shell-(bar|side-panel)$"
blur = true
blur_optimized = false
# shell-glass: fin
EOF
status=$("$GLASS" ensure)
check "dice changed" $([ "$status" = changed ]; echo $?)
check "sigue en detrás" $(grep -q '^blur_optimized = false$' "$UMBRIEL_CONFIG"; echo $?)
check "añade la máscara" $(grep -q '^blur_ignore_alpha = 0.04$' "$UMBRIEL_CONFIG"; echo $?)
check "valida" $(validate; echo $?)

echo "== 12. ventanas transparentes =="
fresh
status=$("$GLASS" windows 20 1)
check "dice changed" $([ "$status" = changed ]; echo $?)
check "opacidad" $(grep -q '^opacity = 0.800$' "$UMBRIEL_CONFIG"; echo $?)
check "desenfoque" $(grep -q '^blur = true$' "$UMBRIEL_CONFIG"; echo $?)
check "detrás" $(grep -q '^blur_optimized = false$' "$UMBRIEL_CONFIG"; echo $?)
check "valida" $(validate; echo $?)
out=$("$GLASS" status)
check "estado transparente" $(printf '%s\n' "$out" | grep -q 'ventanas: transparentes'; echo $?)
before=$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)
status=$("$GLASS" windows 20 1)
check "repetir unchanged" $([ "$status" = unchanged ]; echo $?)
check "mismo contenido" $([ "$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)" = "$before" ]; echo $?)
status=$("$GLASS" windows 0 1)
check "quitar dice changed" $([ "$status" = changed ]; echo $?)
check "sin bloque" $(! grep -q 'shell-windows' "$UMBRIEL_CONFIG"; echo $?)
check "valida tras quitar" $(validate; echo $?)
before=$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)
"$GLASS" windows 91 1 >/dev/null 2>&1
check "rechaza 91" $([ $? != 0 ]; echo $?)
"$GLASS" windows 20 2 >/dev/null 2>&1
check "rechaza blur 2" $([ $? != 0 ]; echo $?)
check "archivo intacto" $([ "$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)" = "$before" ]; echo $?)

echo "== 13. tono del desenfoque =="
fresh
status=$("$GLASS" tone light)
check "claro cambia" $([ "$status" = changed ]; echo $?)
check "brillo claro" $(grep -q '^brightness = 1.100$' "$UMBRIEL_CONFIG"; echo $?)
check "contraste claro" $(grep -q '^contrast = 0.960$' "$UMBRIEL_CONFIG"; echo $?)
check "pasadas" $(grep -q '^passes = 4$' "$UMBRIEL_CONFIG"; echo $?)
status=$("$GLASS" tone dark)
check "oscuro cambia" $([ "$status" = changed ]; echo $?)
check "brillo oscuro" $(grep -q '^brightness = 0.700$' "$UMBRIEL_CONFIG"; echo $?)
check "saturación oscura" $(grep -q '^saturation = 1.050$' "$UMBRIEL_CONFIG"; echo $?)
check "conserva el radio" $(grep -q '^radius = 16$' "$UMBRIEL_CONFIG"; echo $?)
check "valida" $(validate; echo $?)

echo "== 14. radios independientes del shell y de las ventanas =="
fresh
status=$("$GLASS" apply 16 simple 20 12 fondo)
check "apply cambia" $([ "$status" = changed ]; echo $?)
check "radio global 16" $(grep -q '^radius = 16$' "$UMBRIEL_CONFIG"; echo $?)
check "shell al máximo" $(grep -q '^blur_strength = 1.0000$' "$UMBRIEL_CONFIG"; echo $?)
check "ventanas al 75 %" $(grep -q '^blur_strength = 0.7500$' "$UMBRIEL_CONFIG"; echo $?)
check "shell simple" $(grep -q '^blur_optimized = false$' "$UMBRIEL_CONFIG"; echo $?)
check "ventanas fondo" $([ "$(grep -c '^blur_optimized = true$' "$UMBRIEL_CONFIG")" = 1 ]; echo $?)
check "valida" $(validate; echo $?)
out=$("$GLASS" status)
check "estado shell 16" $(printf '%s\n' "$out" | grep -q '^shell: 16 px$'; echo $?)
check "estado ventanas 12" $(printf '%s\n' "$out" | grep -q '^ventanas: 12 px$'; echo $?)
status=$("$GLASS" apply 8 fondo 20 12 simple)
check "shell menor cambia" $([ "$status" = changed ]; echo $?)
check "radio global 12" $(grep -q '^radius = 12$' "$UMBRIEL_CONFIG"; echo $?)
check "shell al 66 %" $(grep -q '^blur_strength = 0.6667$' "$UMBRIEL_CONFIG"; echo $?)
check "ventanas al máximo" $(grep -q '^blur_strength = 1.0000$' "$UMBRIEL_CONFIG"; echo $?)
out=$("$GLASS" status)
check "estado shell 8" $(printf '%s\n' "$out" | grep -q '^shell: 8 px$'; echo $?)
check "estado ventanas 12 otra vez" $(printf '%s\n' "$out" | grep -q '^ventanas: 12 px$'; echo $?)
status=$("$GLASS" apply 0 fondo 20 0 fondo)
check "todo apagado" $([ "$status" = changed ]; echo $?)
check "blur desactivado" $(grep -q '^enabled = false$' "$UMBRIEL_CONFIG"; echo $?)
check "radio 0" $(grep -q '^radius = 0$' "$UMBRIEL_CONFIG"; echo $?)
check "ventana opaca" $(grep -q '^opacity = 0.800$' "$UMBRIEL_CONFIG"; echo $?)
check "sin blur de ventana" $(grep -q '^blur = false$' "$UMBRIEL_CONFIG"; echo $?)
check "valida apagado" $(validate; echo $?)
before=$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)
"$GLASS" apply 41 fondo 10 10 fondo >/dev/null 2>&1
check "rechaza radio 41" $([ $? != 0 ]; echo $?)
"$GLASS" apply 10 ruido 10 10 fondo >/dev/null 2>&1
check "rechaza tipo" $([ $? != 0 ]; echo $?)
check "archivo intacto tras errores" $([ "$(sha256sum "$UMBRIEL_CONFIG" | cut -d' ' -f1)" = "$before" ]; echo $?)

echo
printf 'resultado: %d OK, %d fallos\n' "$pass" "$fail"
[ "$fail" = 0 ]
