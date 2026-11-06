#!/usr/bin/env python3
"""Ajustes de los perfiles Wi-Fi de NetworkManager para ALBA.

Uso:
    wifi-profile.py profile <ssid> <ruta-qr>
    wifi-profile.py autoconnect <ssid> <yes|no>
    wifi-profile.py forget <ssid>

`profile` imprime un JSON con el nombre del perfil, la reconexión automática y
si se pudo generar el QR para compartir la red.
"""

import json
import os
import subprocess
import sys


def run(args):
    return subprocess.run(args, capture_output=True, text=True)


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

    autoconnect = run([
        "nmcli", "-g", "connection.autoconnect",
        "connection", "show", name,
    ]).stdout.strip() == "yes"
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
        "autoconnect": autoconnect,
        "secure": secure,
        "hasPsk": bool(psk),
        "qr": qr_ready,
    }))
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


def forget(ssid):
    name = profile_for(ssid)
    if not name:
        print(json.dumps({"ok": False}))
        return 1
    result = run(["nmcli", "connection", "delete", name])
    print(json.dumps({"ok": result.returncode == 0, "name": name}))
    return result.returncode


def main():
    if len(sys.argv) < 3:
        return 2
    action = sys.argv[1]
    if action == "profile" and len(sys.argv) >= 4:
        return profile(sys.argv[2], sys.argv[3])
    if action == "autoconnect" and len(sys.argv) >= 4:
        return autoconnect(sys.argv[2], sys.argv[3])
    if action == "forget":
        return forget(sys.argv[2])
    return 2


if __name__ == "__main__":
    sys.exit(main())
