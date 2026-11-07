#!/bin/bash
# Pruebas del calendario simple del shell (notas locales).
#
# Trabaja con XDG_CONFIG_HOME temporal, así que no toca la agenda real.
# Uso: ./scripts/test-calendar.sh

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
HELPER="$REPO_DIR/scripts/shell-calendar"
BASE=$(mktemp -d "${TMPDIR:-/tmp}/calendar-test.XXXXXX")
trap 'rm -rf "$BASE"' EXIT

export XDG_CONFIG_HOME="$BASE/config"

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

assert_json() {
    local name=$1 expression=$2 payload=$3
    JSON="$payload" python3 -c \
        "import json, os; d = json.loads(os.environ['JSON']); assert $expression" \
        >/dev/null 2>&1
    check "$name" $?
}

list_range() {
    "$HELPER" list --from "$1" --to "$2"
}

echo "==> 1. Lista vacía"
empty=$(list_range 2026-11-01 2026-11-30)
assert_json "respuesta correcta" "d['ok'] is True" "$empty"
assert_json "sin notas" "d['events'] == []" "$empty"

echo "==> 2. Alta de notas"
first=$("$HELPER" note add --date 2026-11-06 --text "Comprar regalo")
assert_json "nota añadida" "d['ok'] is True and len(d['id']) == 8" "$first"
first_id=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$first")
second=$("$HELPER" note add --date 2026-11-06 --text "Llamar a Ana | cita")
second_id=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$second")
third=$("$HELPER" note add --date 2026-12-24 --text "Nochebuena")
third_id=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$third")

echo "==> 3. Lectura por rango"
november=$(list_range 2026-11-01 2026-11-30)
assert_json "dos notas en noviembre" "len(d['events']) == 2" "$november"
assert_json "todas son notas de día completo" \
    "all(e['note'] and e['all_day'] and e['time'] == '' for e in d['events'])" "$november"
assert_json "la barra vertical se conserva" \
    "any(e['title'] == 'Llamar a Ana | cita' for e in d['events'])" "$november"
assert_json "ordenadas por título dentro del día" \
    "[e['title'] for e in d['events']] == ['Comprar regalo', 'Llamar a Ana | cita']" \
    "$november"
december=$(list_range 2026-12-01 2026-12-31)
assert_json "diciembre solo trae su nota" \
    "len(d['events']) == 1 and d['events'][0]['title'] == 'Nochebuena'" "$december"
assert_json "rango invertido se corrige" \
    "len(d['events']) == 1" "$(list_range 2026-12-31 2026-12-01)"

echo "==> 4. Archivo y borrado"
notes_file="$XDG_CONFIG_HOME/shell/calendar-notes.conf"
check "el archivo existe" "$([ -f "$notes_file" ]; echo $?)"
check "una nota por línea" "$([ "$(wc -l <"$notes_file")" -eq 3 ]; echo $?)"
removed=$("$HELPER" note remove --id "$first_id")
assert_json "nota borrada" "d['ok'] is True" "$removed"
assert_json "queda una" "len(d['events']) == 1" "$(list_range 2026-11-01 2026-11-30)"
assert_json "borrar dos veces falla" "d['ok'] is False" \
    "$("$HELPER" note remove --id "$first_id")"
assert_json "id inexistente falla" "d['ok'] is False" \
    "$("$HELPER" note remove --id 00000000)"

echo "==> 5. Validaciones"
assert_json "fecha imposible rechazada" "d['ok'] is False" \
    "$("$HELPER" note add --date 2026-02-30 --text x)"
assert_json "texto vacío rechazado" "d['ok'] is False" \
    "$("$HELPER" note add --date 2026-11-07 --text '   ')"
assert_json "texto con saltos se aplana" \
    "d['ok'] is True" "$("$HELPER" note add --date 2026-11-08 --text $'uno\ndos')"
november=$(list_range 2026-11-01 2026-11-30)
assert_json "sin saltos de línea" \
    "any(e['title'] == 'uno dos' for e in d['events'])" "$november"

echo "==> 6. Límites del rango"
edge=$(list_range 2026-11-06 2026-11-06)
assert_json "el día inicial y final se incluyen" \
    "all(e['date'] == '2026-11-06' for e in d['events']) and len(d['events']) >= 1" "$edge"

echo
echo "resultado: $pass OK, $fail fallos"
rm -f "$notes_file"
[ "$fail" -eq 0 ]
