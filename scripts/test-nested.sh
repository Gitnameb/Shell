#!/usr/bin/env bash
# Prueba en un Hyprland anidado, sin cerrar la sesión actual.
#
#   bash ~/Shell/scripts/test-nested.sh
#
# Deja capturas en /tmp/shell-shot-*.png y los logs en /tmp/hypr-shell.log y
# /tmp/shell-qs.log.
#
# Variables útiles:
#   KEEP=1   deja Hyprland y Quickshell corriendo al terminar (para mirar a mano)
#   CONFIG   config de Hyprland a usar (por defecto la real del usuario)

set -u

HYPR_CONF="${CONFIG:-$HOME/.config/hypr/hyprland.conf}"
RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
PIDFILE="/tmp/shell-nested.pid"
SHOT_PREFIX="/tmp/shell-shot"
QS_LOG="/tmp/shell-qs.log"
HYPR_LOG="/tmp/hypr-shell.log"

say() { printf '\n\033[1;35m[shell]\033[0m %s\n' "$*"; }

# Seguridad: si ya estamos dentro de Hyprland, el script cerraría la barra real
# (pkill -x qs). Sirve solo desde otra sesión, como KDE o una TTY.
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    say "Ya estás dentro de Hyprland. Este script es para probar desde otra sesión."
    say "Abortando para no cerrar tu shell actual."
    exit 1
fi

kill_pids() {
    [ "$#" -eq 0 ] && return
    kill "$@" 2>/dev/null || true
    sleep 1
    kill -9 "$@" 2>/dev/null || true
}

stop_previous() {
    # Salida ordenada del compositor anidado. Guardamos todos los PIDs nuevos de
    # Hyprland porque el proceso inicial se re-ejecuta y deja un hijo vivo.
    if [ -f "$PIDFILE" ]; then
        read -r OLD_SIG OLD_PIDS < "$PIDFILE" || true
        if [ -n "${OLD_SIG:-}" ]; then
            HYPRLAND_INSTANCE_SIGNATURE="$OLD_SIG" hyprctl dispatch exit > /dev/null 2>&1 || true
            sleep 1
        fi
        # shellcheck disable=SC2086
        kill_pids ${OLD_PIDS:-}
        rm -f "$PIDFILE"
    fi
    pkill -x qs 2>/dev/null || true
}

cleanup() {
    if [ "${KEEP:-0}" = "1" ]; then
        say "KEEP=1: dejo Hyprland (PIDs ${NESTED_PIDS:-$HYPR_PID}) y Quickshell corriendo."
        return
    fi
    say "Cerrando Quickshell y Hyprland anidado…"
    pkill -x qs 2>/dev/null || true
    if [ -n "${SIG:-}" ]; then
        HYPRLAND_INSTANCE_SIGNATURE="$SIG" hyprctl dispatch exit > /dev/null 2>&1 || true
        sleep 2
    fi
    # shellcheck disable=SC2086
    kill_pids ${NESTED_PIDS:-$HYPR_PID}
    rm -f "$PIDFILE"
}
trap cleanup EXIT

say "Limpiando la prueba anterior (solo la instancia anidada)…"
stop_previous
sleep 1

# No borramos nada de $RUNTIME ni matamos Hyprland por nombre: podría
# pertenecer a una sesión Hyprland real del usuario.
BEFORE="$(ls -1 "$RUNTIME" 2>/dev/null | sort)"
BEFORE_HYPR="$(pgrep -x Hyprland 2>/dev/null | sort || true)"

say "Arrancando Hyprland anidado con $HYPR_CONF…"
rm -f "$HYPR_LOG"
setsid Hyprland -c "$HYPR_CONF" > "$HYPR_LOG" 2>&1 < /dev/null &
HYPR_PID=$!

# La firma cambia en cada arranque: buscamos el directorio nuevo.
SIG=""
for _ in $(seq 1 50); do
    sleep 0.2
    AFTER="$(ls -1 "$RUNTIME" 2>/dev/null | sort)"
    SIG="$(comm -13 <(printf '%s\n' "$BEFORE") <(printf '%s\n' "$AFTER") | head -1)"
    [ -n "$SIG" ] && [ -S "$RUNTIME/$SIG/.socket.sock" ] && break
    SIG=""
done
if [ -z "$SIG" ]; then
    say "Hyprland no creó el socket. Últimas líneas del log:"
    tail -30 "$HYPR_LOG"
    exit 1
fi
export HYPRLAND_INSTANCE_SIGNATURE="$SIG"

sleep 0.5
NESTED_PIDS=""
for pid in $(pgrep -x Hyprland 2>/dev/null); do
    printf '%s\n' "$BEFORE_HYPR" | grep -qx "$pid" || NESTED_PIDS="$NESTED_PIDS $pid"
done
NESTED_PIDS="${NESTED_PIDS# }"
echo "$SIG $NESTED_PIDS" > "$PIDFILE"
say "Hyprland listo (firma ${SIG:0:12}…, PIDs: ${NESTED_PIDS:-$HYPR_PID})."

hyprctl monitors > /dev/null 2>&1 || {
    say "hyprctl no responde. Log:"
    tail -30 "$HYPR_LOG"
    exit 1
}

say "Esperando a Quickshell (lo arranca el exec-once de la config)…"
rm -f "$QS_LOG"
for _ in $(seq 1 25); do
    pgrep -x qs > /dev/null && break
    sleep 0.2
done

if ! pgrep -x qs > /dev/null; then
    say "El exec-once no lo arrancó; lanzo Quickshell a mano…"
    hyprctl dispatch exec "sh -c 'QT_QPA_PLATFORMTHEME=gtk3 qs -c shell > \"$QS_LOG\" 2>&1'" > /dev/null
    sleep 4
fi

if ! pgrep -x qs > /dev/null; then
    say "Quickshell no arrancó. Log:"
    cat "$QS_LOG" 2>/dev/null
    exit 1
fi
say "Quickshell corriendo."

say "Capturando la barra…"
sleep 2
hyprctl dispatch exec "grim ${SHOT_PREFIX}-bar.png" > /dev/null
sleep 2

say "Abriendo el lanzador…"
qs ipc -c shell --any-display call launcher toggle > /dev/null 2>&1
sleep 2
hyprctl dispatch exec "grim ${SHOT_PREFIX}-launcher.png" > /dev/null
sleep 2
qs ipc -c shell --any-display call launcher toggle > /dev/null 2>&1

say "Capturando el panel de notificaciones…"
qs ipc -c shell --any-display call notifications toggle > /dev/null 2>&1
sleep 2
hyprctl dispatch exec "grim ${SHOT_PREFIX}-notifications.png" > /dev/null
sleep 2
qs ipc -c shell --any-display call notifications toggle > /dev/null 2>&1

say "Capturando el calendario…"
qs ipc -c shell --any-display call calendar toggle > /dev/null 2>&1
sleep 2
hyprctl dispatch exec "grim ${SHOT_PREFIX}-calendar.png" > /dev/null
sleep 2

say "Capturas:"
ls -la "${SHOT_PREFIX}"-*.png 2>/dev/null

say "Últimas líneas de Quickshell:"
tail -20 "$QS_LOG"

say "Listo."
