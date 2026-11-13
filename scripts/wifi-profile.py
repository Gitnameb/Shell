#!/usr/bin/env python3
"""Ajustes de los perfiles Wi-Fi de NetworkManager para el shell.

Uso:
    wifi-profile.py profile <ssid> <ruta-qr>
    wifi-profile.py saved
    wifi-profile.py autoconnect <ssid> <yes|no>
    wifi-profile.py hostname <ssid> <yes|no>
    wifi-profile.py mac <ssid> <permanent|stable|random>
    wifi-profile.py forget <ssid>

`profile` imprime un JSON con el nombre del perfil, la reconexión automática,
la privacidad (nombre por DHCP y modo de MAC) y si se pudo generar el QR para
compartir la red. `saved` imprime el historial de redes guardadas, ordenado por
la última vez que se usaron.
"""

import json
import os
import subprocess
import sys


def run(args):
    return subprocess.run(args, capture_output=True, text=True)


def nm_get(name, field):
    result = run(["nmcli", "-g", field, "connection", "show", name])
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def ternary(value, default=True):
    """Interpreta los valores -1/0/1 de NetworkManager."""
    text = str(value or "").strip().lower()
    if text in ("1", "yes", "true", "on"):
        return True
    if text in ("0", "no", "false", "off"):
        return False
    return default


def mac_mode(value):
    """Traduce 802-11-wireless.cloned-mac-address a un modo de la interfaz."""
    text = str(value or "").strip().lower()
    if text == "random":
        return "random"
    if text in ("stable", "stable-ssid"):
        return "stable"
    if not text or text in ("preserve", "permanent"):
        return "permanent"
    return "custom"


def profile_for(ssid):
    out = run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]).stdout
    for line in out.splitlines():
        name, sep, kind = line.rpartition(":")
        if not sep or kind != "802-11-wireless":
            continue
        current = run([
            "nmcli", "-g", "802-11-wireless.ssid",
            "connection", "show", name,
        ]).stdout.strip()
        if current == ssid:
            return name
    return ""


def escape_qr(value):
    return "".join(("\\" + ch) if ch in "\\;,\":" else ch for ch in value)


def profile(ssid, qr_path):
    name = profile_for(ssid)
    if not name:
        print(json.dumps({"found": False}))
        return 0

    uuid = run([
        "nmcli", "-g", "connection.uuid",
        "connection", "show", name,
    ]).stdout.strip()
    autoconnect = run([
        "nmcli", "-g", "connection.autoconnect",
        "connection", "show", name,
    ]).stdout.strip() == "yes"
    dhcp_hostname = (ternary(nm_get(name, "ipv4.dhcp-send-hostname"))
        and ternary(nm_get(name, "ipv6.dhcp-send-hostname")))
    cloned_mac = nm_get(name, "802-11-wireless.cloned-mac-address")
    key_mgmt = run([
        "nmcli", "-g", "802-11-wireless-security.key-mgmt",
        "connection", "show", name,
    ]).stdout.strip()
    psk = run([
        "nmcli", "-s", "-g", "802-11-wireless-security.psk",
        "connection", "show", name,
    ]).stdout.strip()

    secure = bool(key_mgmt)
    payload = ""
    if secure and psk:
        payload = "WIFI:T:WPA;S:%s;P:%s;;" % (
            escape_qr(ssid), escape_qr(psk))
    elif not secure:
        payload = "WIFI:T:nopass;S:%s;;" % escape_qr(ssid)

    qr_ready = False
    if payload:
        try:
            os.makedirs(os.path.dirname(qr_path), exist_ok=True)
            qr_ready = run([
                "qrencode", "-o", qr_path, "-s", "5", "-m", "2", "-l", "M",
                payload,
            ]).returncode == 0
        except OSError:
            qr_ready = False

    print(json.dumps({
        "found": True,
        "name": name,
        "uuid": uuid,
        "autoconnect": autoconnect,
        "dhcpHostname": dhcp_hostname,
        "macMode": mac_mode(cloned_mac),
        "clonedMac": cloned_mac,
        "secure": secure,
        "hasPsk": bool(psk),
        "qr": qr_ready,
    }))
    return 0


def unescape(value):
    """Quita el escapado de los campos en modo terse de nmcli."""
    result = []
    i = 0
    while i < len(value):
        if value[i] == "\\" and i + 1 < len(value):
            result.append(value[i + 1])
            i += 2
        else:
            result.append(value[i])
            i += 1
    return "".join(result)


def saved():
    """Lista los perfiles Wi-Fi guardados, del más reciente al más antiguo."""
    active = {
        unescape(line)
        for line in run([
            "nmcli", "-t", "-f", "NAME", "connection", "show", "--active",
        ]).stdout.splitlines()
        if line
    }
    out = run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]).stdout
    networks = []
    for line in out.splitlines():
        name, sep, kind = line.rpartition(":")
        if not sep or kind != "802-11-wireless":
            continue
        name = unescape(name)
        ssid = nm_get(name, "802-11-wireless.ssid") or name
        try:
            timestamp = int(float(nm_get(name, "connection.timestamp") or 0))
        except ValueError:
            timestamp = 0
        networks.append({
            "ssid": ssid,
            "name": name,
            "uuid": nm_get(name, "connection.uuid"),
            "timestamp": timestamp,
            "autoconnect": nm_get(name, "connection.autoconnect") == "yes",
            "active": name in active,
        })
    networks.sort(key=lambda item: item["timestamp"], reverse=True)
    print(json.dumps({"networks": networks}))
    return 0


def autoconnect(ssid, value):
    name = profile_for(ssid)
    if not name:
        print(json.dumps({"ok": False}))
        return 1
    result = run([
        "nmcli", "connection", "modify", name,
        "connection.autoconnect", "yes" if value == "yes" else "no",
    ])
    print(json.dumps({
        "ok": result.returncode == 0,
        "name": name,
        "autoconnect": value == "yes",
    }))
    return result.returncode


def set_hostname(ssid, value):
    name = profile_for(ssid)
    if not name:
        print(json.dumps({"ok": False}))
        return 1
    enabled = "yes" if value == "yes" else "no"
    result = run([
        "nmcli", "connection", "modify", name,
        "ipv4.dhcp-send-hostname", enabled,
        "ipv6.dhcp-send-hostname", enabled,
    ])
    print(json.dumps({
        "ok": result.returncode == 0,
        "name": name,
        "dhcpHostname": enabled == "yes",
    }))
    return result.returncode


def set_mac(ssid, mode):
    name = profile_for(ssid)
    if not name:
        print(json.dumps({"ok": False}))
        return 1
    values = {
        "permanent": "permanent",
        # stable-ssid deriva la MAC del SSID, como la MAC aleatoria por red
        # de Android, en vez de depender del UUID del perfil.
        "stable": "stable-ssid",
        "random": "random",
    }
    if mode not in values:
        print(json.dumps({"ok": False, "error": "modo desconocido"}))
        return 2
    result = run([
        "nmcli", "connection", "modify", name,
        "802-11-wireless.cloned-mac-address", values[mode],
    ])
    print(json.dumps({
        "ok": result.returncode == 0,
        "name": name,
        "macMode": mode,
    }))
    return result.returncode


def forget(ssid):
    name = profile_for(ssid)
    if not name:
        print(json.dumps({"ok": False}))
        return 1
    result = run(["nmcli", "connection", "delete", name])
    print(json.dumps({"ok": result.returncode == 0, "name": name}))
    return result.returncode


def main():
    if len(sys.argv) < 2:
        return 2
    action = sys.argv[1]
    if action == "saved":
        return saved()
    if len(sys.argv) < 3:
        return 2
    if action == "profile" and len(sys.argv) >= 4:
        return profile(sys.argv[2], sys.argv[3])
    if action == "autoconnect" and len(sys.argv) >= 4:
        return autoconnect(sys.argv[2], sys.argv[3])
    if action == "hostname" and len(sys.argv) >= 4:
        return set_hostname(sys.argv[2], sys.argv[3])
    if action == "mac" and len(sys.argv) >= 4:
        return set_mac(sys.argv[2], sys.argv[3])
    if action == "forget":
        return forget(sys.argv[2])
    return 2


if __name__ == "__main__":
    sys.exit(main())
