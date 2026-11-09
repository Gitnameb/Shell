#!/bin/bash
# Pruebas de la copia estable del fondo de pantalla.
#
# No toca el HOME real: usa un XDG_DATA_HOME temporal.
# Uso: ./scripts/test-wallpaper.sh

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
IMPORT="$REPO_DIR/scripts/shell-wallpaper-import"
BASE=$(mktemp -d "${TMPDIR:-/tmp}/wallpaper-test.XXXXXX")
trap 'rm -rf "$BASE"' EXIT

export XDG_DATA_HOME="$BASE/data"
export HOME="$BASE/home"
mkdir -p "$HOME" "$XDG_DATA_HOME"

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

source="$BASE/original.png"
printf 'fondo de prueba\n' >"$source"

echo "== 1. copia la imagen y devuelve la copia =="
out=$("$IMPORT" "$source")
check "sale 0" $?
check "devuelve current.png" $([ "$out" = "$XDG_DATA_HOME/shell/wallpapers/current.png" ]; echo $?)
check "la copia existe" $([ -f "$out" ]; echo $?)
check "mismo contenido" $(cmp -s "$source" "$out"; echo $?)
check "modo 644" $([ "$(stat -c '%a' "$out")" = 644 ]; echo $?)

echo "== 2. el original se puede borrar =="
rm -f "$source"
check "la copia sigue" $([ -s "$out" ]; echo $?)

echo "== 3. una ruta ya estable no se vuelve a copiar =="
out2=$("$IMPORT" "$out")
check "sale 0" $?
check "misma ruta" $([ "$out2" = "$out" ]; echo $?)

echo "== 4. cambia la extensión y retira la anterior =="
jpg="$BASE/original.jpg"
printf 'otro fondo\n' >"$jpg"
out3=$("$IMPORT" "$jpg")
check "sale 0" $?
check "devuelve current.jpg" $([ "$out3" = "$XDG_DATA_HOME/shell/wallpapers/current.jpg" ]; echo $?)
check "current.png ya no está" $([ ! -e "$out" ]; echo $?)
check "solo queda una copia" $([ "$(find "$XDG_DATA_HOME/shell/wallpapers" -maxdepth 1 -name 'current.*' | wc -l)" = 1 ]; echo $?)

echo "== 5. rechaza una ruta que no existe =="
"$IMPORT" "$BASE/no-existe.png" >/dev/null 2>&1
check "devuelve error" $([ $? != 0 ]; echo $?)

echo
printf 'resultado: %d OK, %d fallos\n' "$pass" "$fail"
[ "$fail" = 0 ]
