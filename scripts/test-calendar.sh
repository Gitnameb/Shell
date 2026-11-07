#!/bin/bash
# Pruebas del calendario del shell (notas y calendarios iCalendar).
#
# Trabaja con XDG_CONFIG_HOME y XDG_STATE_HOME temporales, así que no toca la
# agenda real. Uso: ./scripts/test-calendar.sh

set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
HELPER="$REPO_DIR/scripts/shell-calendar"
BASE=$(mktemp -d "${TMPDIR:-/tmp}/calendar-test.XXXXXX")
trap 'rm -rf "$BASE"' EXIT

export XDG_CONFIG_HOME="$BASE/config"
export XDG_STATE_HOME="$BASE/state"
export TZ=Europe/Madrid

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

# Evalúa una aserción de Python sobre la salida JSON que recibe en JSON.
assert_json() {
    local name=$1 expression=$2 payload=$3
    JSON="$payload" python3 -c \
        "import json, os; d = json.loads(os.environ['JSON']); assert $expression" \
        >/dev/null 2>&1
    check "$name" $?
}

ics="$BASE/agenda.ics"
cat >"$ics" <<'EOF'
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:cumple
DTSTART;VALUE=DATE:20261106
DTEND;VALUE=DATE:20261107
SUMMARY:Cumpleaños de Ana
END:VEVENT
BEGIN:VEVENT
UID:reunion
DTSTART;TZID=Europe/Madrid:20261107T093000
DTEND;TZID=Europe/Madrid:20261107T103000
SUMMARY:Reunión\, equipo
RRULE:FREQ=WEEKLY;BYDAY=SA;COUNT=4
END:VEVENT
BEGIN:VEVENT
UID:viaje
DTSTART;VALUE=DATE:20261120
DTEND;VALUE=DATE:20261123
SUMMARY:Viaje
END:VEVENT
BEGIN:VEVENT
UID:mensual
DTSTART;TZID=Europe/Madrid:20260115T180000
DTEND;TZID=Europe/Madrid:20260115T190000
SUMMARY:Pago
RRULE:FREQ=MONTHLY;BYMONTHDAY=15;COUNT=11
END:VEVENT
BEGIN:VEVENT
UID:fin
DTSTART;TZID=Europe/Madrid:20260131T120000
SUMMARY:Fin de mes
RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;COUNT=12
END:VEVENT
BEGIN:VEVENT
UID:dst
DTSTART;TZID=Europe/Madrid:20260322T093000
DTEND;TZID=Europe/Madrid:20260322T100000
SUMMARY:Horario estable
RRULE:FREQ=WEEKLY;BYDAY=SU;COUNT=4
END:VEVENT
BEGIN:VEVENT
UID:clase
DTSTART;TZID=Europe/Madrid:20261201T180000
DTEND;TZID=Europe/Madrid:20261201T190000
SUMMARY:Clase
RRULE:FREQ=WEEKLY;BYDAY=TU;COUNT=3
END:VEVENT
BEGIN:VEVENT
UID:clase
RECURRENCE-ID;TZID=Europe/Madrid:20261208T180000
DTSTART;TZID=Europe/Madrid:20261208T200000
DTEND;TZID=Europe/Madrid:20261208T210000
SUMMARY:Clase cambiada
END:VEVENT
BEGIN:VEVENT
UID:clase
RECURRENCE-ID;TZID=Europe/Madrid:20261215T180000
DTSTART;TZID=Europe/Madrid:20261215T180000
STATUS:CANCELLED
SUMMARY:Clase
END:VEVENT
END:VCALENDAR
EOF

echo "==> 1. Sin fuentes solo hay notas (ninguna al empezar)"
list_month() {
    "$HELPER" list --from 2026-11-01 --to 2026-11-30
}
empty=$(list_month)
assert_json "lista vacía con ok" "d['ok'] is True" "$empty"
assert_json "sin eventos" "len(d['events']) == 0" "$empty"
assert_json "sin fuentes" "len(d['sources']) == 0" "$empty"

echo "==> 2. Alta de calendario local"
added=$("$HELPER" source add --name Local --url "$ics")
assert_json "fuente añadida" "d['ok'] is True and len(d['id']) == 6" "$added"
sources=$("$HELPER" sources)
assert_json "aparece en sources" \
    "len(d['sources']) == 1 and d['sources'][0]['name'] == 'Local' and d['sources'][0]['enabled'] is True" \
    "$sources"

echo "==> 3. Lectura de iCalendar"
month=$(list_month)
assert_json "no hay errores" "d['errors'] == []" "$month"
assert_json "10 eventos en noviembre" "len(d['events']) == 10" "$month"
assert_json "todo el día el 6" \
    "any(e['date'] == '2026-11-06' and e['all_day'] and e['title'] == 'Cumpleaños de Ana' for e in d['events'])" \
    "$month"
assert_json "hora y fin del evento con TZID" \
    "any(e['date'] == '2026-11-07' and e['time'] == '09:30' and e['end_time'] == '10:30' for e in d['events'])" \
    "$month"
assert_json "coma escapada en el título" \
    "any(e['title'] == 'Reunión, equipo' for e in d['events'])" "$month"
assert_json "recurrencia semanal COUNT=4" \
    "[e['date'] for e in d['events'] if e['title'] == 'Reunión, equipo'] == ['2026-11-07', '2026-11-14', '2026-11-21', '2026-11-28']" \
    "$month"
assert_json "evento mensual que empezó en enero" \
    "any(e['date'] == '2026-11-15' and e['time'] == '18:00' and e['title'] == 'Pago' for e in d['events'])" \
    "$month"
assert_json "evento de varios días en cada día" \
    "[e['date'] for e in d['events'] if e['title'] == 'Viaje'] == ['2026-11-20', '2026-11-21', '2026-11-22']" \
    "$month"
assert_json "ordenado por fecha y hora" \
    "d['events'] == sorted(d['events'], key=lambda e: (e['date'], e['time'] or '00:00', e['title'].lower()))" \
    "$month"

echo "==> 4. Notas locales"
note=$("$HELPER" note add --date 2026-11-06 --text "Comprar regalo")
assert_json "nota añadida" "d['ok'] is True and len(d['id']) == 8" "$note"
note_id=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$note")
month=$(list_month)
assert_json "la nota aparece en su día" \
    "any(e['date'] == '2026-11-06' and e['note'] and e['title'] == 'Comprar regalo' for e in d['events'])" \
    "$month"
assert_json "la nota suma un evento" "len(d['events']) == 11" "$month"
assert_json "fecha inválida rechazada" "d['ok'] is False" \
    "$("$HELPER" note add --date 2026-02-30 --text x)"

removed=$("$HELPER" note remove --id "$note_id")
assert_json "nota borrada" "d['ok'] is True" "$removed"
month=$(list_month)
assert_json "la nota ya no está" "len(d['events']) == 10" "$month"

echo "==> 5. Activar y desactivar fuentes"
source_id=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["sources"][0]["id"])' "$sources")
off=$("$HELPER" source toggle --id "$source_id")
assert_json "fuente desactivada" "d['ok'] is True and d['enabled'] is False" "$off"
month=$(list_month)
assert_json "sin eventos al desactivar" "len(d['events']) == 0" "$month"
"$HELPER" source toggle --id "$source_id" >/dev/null
month=$(list_month)
assert_json "vuelven al reactivar" "len(d['events']) == 10" "$month"

echo "==> 6. Validaciones y borrado"
assert_json "URL no compatible rechazada" "d['ok'] is False" \
    "$("$HELPER" source add --name Mala --url ejemplo.com/x.ics)"
assert_json "nombre vacío rechazado" "d['ok'] is False" \
    "$("$HELPER" source add --name '' --url "$ics")"
removed=$("$HELPER" source remove --id "$source_id")
assert_json "fuente borrada" "d['ok'] is True" "$removed"
month=$(list_month)
assert_json "sin fuentes ni eventos" \
    "len(d['events']) == 0 and len(d['sources']) == 0" "$month"
assert_json "borrar fuente inexistente falla" "d['ok'] is False" \
    "$("$HELPER" source remove --id 000000)"

echo "==> 7. Fuerza de actualización con archivo local"
"$HELPER" source add --name Local --url "$ics" >/dev/null
forced=$("$HELPER" list --force --from 2026-11-01 --to 2026-11-30)
assert_json "--force sigue leyendo el archivo local" \
    "d['ok'] is True and len(d['events']) == 10 and d['errors'] == []" "$forced"

echo "==> 8. Fin de mes y cambio de horario"
november=$(list_month)
assert_json "BYMONTHDAY=-1 cae en el último día" \
    "any(e['date'] == '2026-11-30' and e['time'] == '12:00' and e['title'] == 'Fin de mes' for e in d['events'])" \
    "$november"
april=$("$HELPER" list --from 2026-04-01 --to 2026-04-30)
assert_json "el horario de verano mantiene la hora local" \
    "[e['time'] for e in d['events'] if e['title'] == 'Horario estable'] == ['09:30', '09:30']" \
    "$april"

echo "==> 9. Instancias modificadas y canceladas"
december=$("$HELPER" list --from 2026-12-01 --to 2026-12-31)
assert_json "la instancia movida sustituye a la original" \
    "[(e['date'], e['time'], e['title']) for e in d['events'] if e['title'].startswith('Clase')] == [('2026-12-01', '18:00', 'Clase'), ('2026-12-08', '20:00', 'Clase cambiada')]" \
    "$december"

echo
echo "resultado: $pass OK, $fail fallos"
[ "$fail" -eq 0 ]
