#!/usr/bin/env bash
# Dependencias que usan las vistas de red y el audio Bluetooth del shell.
#
# Salida: una línea por dependencia que falte, con el formato
#   clave|nombre|paquete|comando de solución
# Si no falta nada, no imprime nada. Lo consume DependencyState.qml.
# Mantén esta lista sincronizada con los paquetes de scripts/network.sh.

set -u

NET_FIX="cd ~/Shell && sudo ./scripts/network.sh"

check_package() {
    local key="$1" label="$2" package="$3" fix="$4"
    if ! dpkg -s "$package" >/dev/null 2>&1; then
        printf '%s|%s|%s|%s\n' "$key" "$label" "$package" "$fix"
    fi
}

check_package network-manager "NetworkManager" \
    network-manager "$NET_FIX"
check_package wpasupplicant "Wi-Fi (wpasupplicant)" \
    wpasupplicant "$NET_FIX"
check_package rfkill "Radio Wi-Fi (rfkill)" \
    rfkill "$NET_FIX"
check_package dnsmasq-base "Punto de acceso (dnsmasq)" \
    dnsmasq-base "$NET_FIX"
check_package bluez "Bluetooth (bluez)" \
    bluez "$NET_FIX"
check_package bluez-obexd "Transferencia Bluetooth" \
    bluez-obexd "$NET_FIX"

# Además de existir, el plugin Bluetooth debe coincidir con la versión de
# libspa-0.2-modules; si no, WirePlumber no carga el audio Bluetooth.
if ! dpkg -s libspa-0.2-bluetooth >/dev/null 2>&1; then
    printf 'libspa-0.2-bluetooth|Audio Bluetooth (PipeWire)|libspa-0.2-bluetooth|%s\n' \
        "$NET_FIX"
else
    spa_bt_version=$(dpkg-query -W -f='${Version}' libspa-0.2-bluetooth 2>/dev/null || true)
    spa_modules_version=$(dpkg-query -W -f='${Version}' libspa-0.2-modules 2>/dev/null || true)
    if [[ -n "$spa_bt_version" && -n "$spa_modules_version" \
            && "$spa_bt_version" != "$spa_modules_version" ]]; then
        printf 'libspa-0.2-bluetooth|Audio Bluetooth (versión distinta a PipeWire)|libspa-0.2-bluetooth|%s\n' \
            "$NET_FIX"
    fi
fi

check_package network-manager-openvpn "VPN OpenVPN" \
    network-manager-openvpn "$NET_FIX"
check_package qrencode "QR del punto de acceso" \
    qrencode "$NET_FIX"

# python3 ejecuta los ayudantes de DNS y proxy; no lo instala network.sh.
if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3|DNS y proxy (python3)|python3|sudo apt install python3\n'
fi
