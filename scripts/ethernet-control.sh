#!/usr/bin/env bash
# Diagnóstico de solo lectura del control de la Ethernet.
#
# Uso:
#   scripts/ethernet-control.sh status [interfaz]
#
# `status` se puede ejecutar como usuario normal y devuelve pares clave=valor.
# No repara nada: el control heredado de ifupdown/dhcpcd se corrige ejecutando
# `sudo ./scripts/network.sh`.

set -Eeuo pipefail

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

die() {
    printf 'error=%s\n' "$*" >&2
    exit 1
}

detect_iface() {
    nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
        | awk -F: '$2 == "ethernet" { print $1; exit }'
}

ifup_active() {
    systemctl is-active --quiet "ifup@$1.service" 2>/dev/null
}

dhcpcd_active() {
    local pidfile="/run/dhcpcd/$1.pid" pid
    [[ -r "$pidfile" ]] || return 1
    pid=$(cat "$pidfile" 2>/dev/null || true)
    [[ -n "$pid" && -d "/proc/$pid" ]]
}

nm_managed() {
    [[ "$(nmcli -g GENERAL.NM-MANAGED device show "$1" 2>/dev/null || true)" == "yes" ]]
}

print_status() {
    local iface="$1" managed=0 ifup=0 dhcp=0 control

    if nm_managed "$iface"; then
        managed=1
    fi
    if ifup_active "$iface"; then
        ifup=1
    fi
    if dhcpcd_active "$iface"; then
        dhcp=1
    fi

    if (( ifup && dhcp )); then
        control="ifupdown + dhcpcd"
    elif (( ifup )); then
        control="ifupdown"
    elif (( dhcp )); then
        control="dhcpcd"
    elif (( managed )); then
        control="NetworkManager"
    else
        control="sin gestionar"
    fi

    printf 'interface=%s\n' "$iface"
    printf 'managed=%d\n' "$managed"
    printf 'ifup=%d\n' "$ifup"
    printf 'dhcpcd=%d\n' "$dhcp"
    printf 'control=%s\n' "$control"
}

status() {
    local iface="${1:-}"

    if [[ -z "$iface" ]]; then
        iface=$(detect_iface)
    fi
    if [[ -z "$iface" ]]; then
        printf 'interface=\nmanaged=0\nifup=0\ndhcpcd=0\n'
        printf 'control=sin-ethernet\n'
        return 0
    fi

    print_status "$iface"
}

case "${1:-status}" in
    status)
        status "${2:-}"
        ;;
    *)
        die "uso: $0 status [interfaz]"
        ;;
esac
