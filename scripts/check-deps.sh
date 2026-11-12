#!/usr/bin/env bash
# Dependencias que usan las vistas de red, el audio Bluetooth y el
# portapapeles del shell.
#
# Salida: una línea por dependencia que falte, con el formato
#   clave|nombre|paquete|comando de solución
# Si no falta nada, no imprime nada. Lo consume DependencyState.qml.
# Mantén esta lista sincronizada con los paquetes de scripts/network.sh.

set -u

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
REPO_Q=$(printf '%q' "$REPO_DIR")
NET_FIX="cd $REPO_Q && sudo ./scripts/network.sh"
GREETER_FIX="cd $REPO_Q && ./scripts/install-greeter.sh"

check_package() {
    local key="$1" label="$2" package="$3" fix="$4"
    if ! dpkg -s "$package" >/dev/null 2>&1; then
        printf '%s|%s|%s|%s\n' "$key" "$label" "$package" "$fix"
    fi
}

# Algunas dependencias pueden estar fuera de dpkg (por ejemplo, en
# ~/.local/bin). Basta con que el comando exista.
check_command() {
    local key="$1" label="$2" package="$3" command="$4" fix="$5"
    if ! command -v "$command" >/dev/null 2>&1; then
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

# Iniciador de sesión y bloqueo de pantalla.
check_package greetd "Iniciador de sesión (greetd)" \
    greetd "$GREETER_FIX"
check_package noctalia-greeter "Iniciador Noctalia" \
    noctalia-greeter "$GREETER_FIX"
check_package hyprlock "Bloqueo de pantalla (hyprlock)" \
    hyprlock "sudo apt install -t trixie-backports hyprlock"
check_package swayidle "Bloqueo automático (swayidle)" \
    swayidle "sudo apt install swayidle"

# cliphist guarda el historial; wl-clipboard aporta wl-paste y wl-copy.
check_package wl-clipboard "Portapapeles (wl-clipboard)" \
    wl-clipboard "sudo apt install wl-clipboard"
check_package cliphist "Historial del portapapeles (cliphist)" \
    cliphist "sudo apt install cliphist"
check_package udiskie "Montaje automático de USB (udiskie)" \
    udiskie "sudo apt install udiskie"
check_package udisks2 "Montaje de discos (udisks2)" \
    udisks2 "sudo apt install udisks2"
check_package ntfs-3g "Discos NTFS (ntfs-3g)" \
    ntfs-3g "sudo apt install ntfs-3g"
check_package exfatprogs "Discos exFAT (exfatprogs)" \
    exfatprogs "sudo apt install exfatprogs"

# python3 ejecuta los ayudantes de DNS y proxy; no lo instala network.sh.
if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3|DNS y proxy (python3)|python3|sudo apt install python3\n'
fi

# Extras que usan funciones concretas del shell. Sin ellos la función falla o
# degrada sin explicar por qué.
check_command grim "Capturas (grim)" grim grim \
    "sudo apt install grim slurp"
check_command slurp "Capturas por región (slurp)" slurp slurp \
    "sudo apt install grim slurp"
check_command brightnessctl "Brillo interno (brightnessctl)" brightnessctl \
    brightnessctl "sudo apt install brightnessctl"
check_command kdialog "Diálogos del sistema (kdialog)" kdialog kdialog \
    "sudo apt install kdialog"

# El paquete fonts-noto-cjk puede faltar aunque haya una fuente copiada a
# ~/.local/share/fonts. Se comprueba el resultado real de fontconfig.
if ! fc-list :lang=ja 2>/dev/null | grep -q .; then
    printf 'fonts-cjk|Letras japonesas/chinas/coreanas|fonts-noto-cjk|sudo apt install fonts-noto-cjk\n'
fi
