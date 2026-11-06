#!/usr/bin/env python3
"""DNS y proxy de los perfiles de NetworkManager para ALBA.

Uso:
    network-settings.py list
    network-settings.py set <uuid> auto
    network-settings.py set <uuid> manual <ipv4> <ipv6>
    network-settings.py set-all auto
    network-settings.py set-all manual <ipv4> <ipv6>
    network-settings.py set-proxy <uuid> none
    network-settings.py set-proxy <uuid> auto <pac>
    network-settings.py set-proxy <uuid> manual <http> <https> <socks> <no-proxy>

Las direcciones DNS se aceptan separadas por espacios o comas. `set` cambia un
perfil y `set-all` aplica lo mismo a todas las conexiones Wi-Fi y Ethernet.
Si la conexión está activa, el DNS se aplica con `nmcli device reapply` sin
cortar el enlace. El proxy manual de la conexión activa también se escribe en
`~/.config/environment.d/90-alba-proxy.conf` para la próxima sesión. La salida
siempre es JSON.
"""

import ipaddress
import json
import os
import subprocess
import sys
import urllib.parse

WIFI = "802-11-wireless"
WIRED = "802-3-ethernet"


def run(args):
    return subprocess.run(args, capture_output=True, text=True)


def fields(line):
    """Separa los campos de `nmcli -t`, respetando los ':' escapados."""
    out = []
    current = ""
    escaped = False
    for char in line:
        if escaped:
            current += char
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            out.append(current)
            current = ""
        else:
            current += char
    out.append(current)
    return out


def unescape(value):
    """Deshace el escapado de ':' que usa `nmcli -t/-g`."""
    return str(value or "").replace("\\:", ":").replace("\\\\", "\\")


def nm_get(uuid, field):
    result = run(["nmcli", "-g", field, "connection", "show", uuid])
    if result.returncode != 0:
        return ""
    return unescape(result.stdout.strip())


def split_dns(value):
    return [token for token in unescape(value).replace(",", " ").split()
            if token]


def active_devices():
    result = run(["nmcli", "-t", "-f", "UUID,DEVICE",
                  "connection", "show", "--active"])
    devices = {}
    for line in result.stdout.splitlines():
        parts = fields(line)
        if len(parts) >= 2 and parts[0] and parts[1] != "--":
            devices[parts[0]] = parts[1]
    return devices


def snapshot():
    result = run(["nmcli", "-t", "-f", "NAME,UUID,TYPE",
                  "connection", "show"])
    active = active_devices()
    proxy_config = load_proxy_config()
    connections = []
    for line in result.stdout.splitlines():
        parts = fields(line)
        if len(parts) < 3:
            continue
        name, uuid, kind = parts[0], parts[1], parts[2]
        if kind not in (WIFI, WIRED):
            continue
        label = nm_get(uuid, "802-11-wireless.ssid") if kind == WIFI else name
        device = nm_get(uuid, "connection.interface-name")
        if uuid in active:
            device = active[uuid]
        values = run([
            "nmcli", "-g",
            "ipv4.dns,ipv4.ignore-auto-dns,ipv6.dns,ipv6.ignore-auto-dns",
            "connection", "show", uuid,
        ]).stdout.splitlines()
        while len(values) < 4:
            values.append("")
        dns4, ignore4, dns6, ignore6 = [value.strip() for value in values[:4]]
        manual = ignore4 == "yes" or ignore6 == "yes"
        proxy_values = run([
            "nmcli", "-g",
            "proxy.method,proxy.pac-url,proxy.pac-script",
            "connection", "show", uuid,
        ]).stdout.splitlines()
        while len(proxy_values) < 3:
            proxy_values.append("")
        nm_method, nm_pac_url, nm_pac_script = [
            unescape(value.strip()) for value in proxy_values[:3]
        ]
        saved = proxy_config.get(uuid, {})
        if saved:
            proxy_method = saved.get("method", "none")
            proxy_pac = saved.get("pac", "")
            proxy_http = saved.get("http", "")
            proxy_https = saved.get("https", "")
            proxy_socks = saved.get("socks", "")
            proxy_no = saved.get("no", "")
        elif nm_method == "auto" and nm_pac_url:
            proxy_method = "auto"
            proxy_pac = nm_pac_url
            proxy_http = ""
            proxy_https = ""
            proxy_socks = ""
            proxy_no = ""
        else:
            proxy_method = "none"
            proxy_pac = ""
            proxy_http = ""
            proxy_https = ""
            proxy_socks = ""
            proxy_no = ""
        connections.append({
            "uuid": uuid,
            "name": name,
            "kind": "wifi" if kind == WIFI else "wired",
            "label": label or name,
            "device": device,
            "active": uuid in active,
            "dns4": split_dns(dns4),
            "dns6": split_dns(dns6),
            "auto": not manual,
            "proxyMethod": proxy_method,
            "proxyPac": proxy_pac,
            "proxyHttp": proxy_http,
            "proxyHttps": proxy_https,
            "proxySocks": proxy_socks,
            "proxyNo": proxy_no,
        })
    connections.sort(key=lambda item: (
        not item["active"], item["kind"] != "wifi",
        item["label"].lower()))
    return connections


def clean_addresses(value, version):
    addresses = []
    for token in split_dns(value):
        try:
            address = ipaddress.ip_address(token)
        except ValueError:
            raise ValueError("Dirección IPv%d no válida: %s"
                             % (version, token))
        if address.version != version:
            raise ValueError("Se esperaba una dirección IPv%d: %s"
                             % (version, token))
        addresses.append(str(address))
    return addresses


def apply_dns(uuid, automatic, dns4, dns6):
    args = ["nmcli", "connection", "modify", uuid]
    if automatic:
        args += [
            "ipv4.ignore-auto-dns", "no", "ipv4.dns", "",
            "ipv6.ignore-auto-dns", "no", "ipv6.dns", "",
        ]
    else:
        if dns4:
            args += ["ipv4.ignore-auto-dns", "yes",
                     "ipv4.dns", " ".join(dns4)]
        else:
            args += ["ipv4.ignore-auto-dns", "no", "ipv4.dns", ""]
        if dns6:
            args += ["ipv6.ignore-auto-dns", "yes",
                     "ipv6.dns", " ".join(dns6)]
        else:
            args += ["ipv6.ignore-auto-dns", "no", "ipv6.dns", ""]
    result = run(args)
    if result.returncode != 0:
        return result.stderr.strip() or "No se pudo guardar el DNS."
    return ""


def reapply(connection):
    if not connection["active"] or not connection["device"]:
        return ""
    result = run(["nmcli", "device", "reapply", connection["device"]])
    if result.returncode != 0:
        return (result.stderr.strip()
                or "El DNS se guardó, pero no se pudo aplicar en %s."
                % connection["device"])
    return ""


def proxy_config_path():
    return os.path.expanduser("~/.config/alba/proxy.json")


def load_proxy_config():
    try:
        with open(proxy_config_path(), "r", encoding="utf-8") as handle:
            data = json.load(handle)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save_proxy_config(config):
    path = proxy_config_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    temporary = path + ".tmp"
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC,
                         0o600)
    with os.fdopen(descriptor, "w") as handle:
        json.dump(config, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    os.replace(temporary, path)
    os.chmod(path, 0o600)


def env_file_path():
    return os.path.expanduser(
        "~/.config/environment.d/90-alba-proxy.conf")


def remove_env_file():
    try:
        os.remove(env_file_path())
    except FileNotFoundError:
        pass
    return ""


def write_env_file(http, https, socks, no_proxy):
    if not (http or https or socks):
        return remove_env_file()
    path = env_file_path()
    no = str(no_proxy or "").strip() or "localhost,127.0.0.1,::1"
    lines = []
    for key, value in (("http_proxy", http),
                       ("https_proxy", https or http),
                       ("all_proxy", socks)):
        if not value:
            continue
        lines.append("%s=%s" % (key, value))
        lines.append("%s=%s" % (key.upper(), value))
    lines.append("no_proxy=" + no)
    lines.append("NO_PROXY=" + no)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w") as handle:
        handle.write("\n".join(lines) + "\n")
    os.chmod(path, 0o600)
    return path


def normalize_proxy(value, scheme):
    value = str(value or "").strip()
    if not value:
        return ""
    if "://" not in value:
        value = scheme + "://" + value
    return value


def proxy_hostport(value, scheme):
    value = normalize_proxy(value, scheme)
    if not value:
        return ""
    try:
        parsed = urllib.parse.urlsplit(value)
        host = parsed.hostname
        port = parsed.port
    except ValueError:
        return ""
    if not host:
        return ""
    if port is None:
        port = 1080 if scheme == "socks5" else 8080
    if ":" in host and not host.startswith("["):
        host = "[" + host + "]"
    return "%s:%d" % (host, port)


def pac_quote(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"')


def pac_script(http, https, socks, no_proxy):
    http_host = proxy_hostport(http, "http")
    https_host = proxy_hostport(https, "http") or http_host
    socks_host = proxy_hostport(socks, "socks5")
    directives = []
    if http_host:
        directives.append("PROXY " + http_host)
    if https_host and https_host != http_host:
        directives.append("PROXY " + https_host)
    if socks_host:
        directives.append("SOCKS5 " + socks_host)
    if not directives:
        return ""
    conditions = [
        "isPlainHostName(host)",
        'host == "localhost"',
        'host == "127.0.0.1"',
        'host == "::1"',
    ]
    entries = []
    for token in str(no_proxy or "").replace(" ", ",").split(","):
        token = token.strip()
        if token and token not in entries:
            entries.append(token)
    for entry in entries:
        if entry in ("localhost", "127.0.0.1", "::1"):
            continue
        if "*" in entry:
            conditions.append('shExpMatch(host, "%s")' % pac_quote(entry))
        elif entry.startswith("."):
            conditions.append('dnsDomainIs(host, "%s")' % pac_quote(entry))
        else:
            conditions.append('(host == "%s" || dnsDomainIs(host, ".%s"))'
                              % (pac_quote(entry), pac_quote(entry)))
    return ("function FindProxyForURL(url, host) {\n"
            "  if (" + " || ".join(conditions) + ") return \"DIRECT\";\n"
            "  return \"" + "; ".join(directives) + "\";\n"
            "}\n")


def apply_proxy(uuid, method, pac, http, https, socks, no_proxy):
    if method == "none":
        args = ["nmcli", "connection", "modify", uuid,
                "proxy.method", "none", "proxy.pac-url", "",
                "proxy.pac-script", ""]
    elif method == "auto":
        pac = str(pac or "").strip()
        if not pac:
            return "Escribe la URL del archivo PAC."
        args = ["nmcli", "connection", "modify", uuid,
                "proxy.method", "auto", "proxy.pac-url", pac,
                "proxy.pac-script", ""]
    elif method == "manual":
        script = pac_script(http, https, socks, no_proxy)
        if not script:
            return "Escribe al menos un servidor proxy."
        args = ["nmcli", "connection", "modify", uuid,
                "proxy.method", "auto", "proxy.pac-url", "",
                "proxy.pac-script", script]
    else:
        return "Método de proxy no válido."
    result = run(args)
    if result.returncode != 0:
        return result.stderr.strip() or "No se pudo guardar el proxy."
    return ""


def set_proxy(uuid, method, pac, http, https, socks, no_proxy):
    connections = snapshot()
    connection = next((item for item in connections
                       if item["uuid"] == uuid), None)
    if connection is None:
        return payload(False, "No se encontró la conexión.")
    http = normalize_proxy(http, "http")
    https = normalize_proxy(https, "http")
    socks = normalize_proxy(socks, "socks5")
    error = apply_proxy(uuid, method, pac, http, https, socks, no_proxy)
    if error:
        return payload(False, error)
    config = load_proxy_config()
    config[uuid] = {
        "method": method,
        "pac": str(pac or "").strip(),
        "http": http,
        "https": https,
        "socks": socks,
        "no": str(no_proxy or "").strip(),
    }
    try:
        save_proxy_config(config)
    except OSError as error:
        return payload(False, "No se pudo guardar la configuración: %s"
                       % error)
    warning = ""
    env_file = ""
    if connection["active"]:
        if method == "manual":
            try:
                env_file = write_env_file(http, https, socks, no_proxy)
            except OSError as error:
                warning = ("El proxy se guardó, pero no se pudo escribir "
                           "environment.d: %s" % error)
        else:
            env_file = remove_env_file()
    else:
        warning = "Se aplicará cuando uses esta red."
    return payload(True, warning=warning, env_file=env_file)


def payload(ok, error="", warning="", count=0, env_file=""):
    return {
        "ok": ok,
        "error": error,
        "warning": warning,
        "count": count,
        "envFile": env_file,
        "connections": snapshot(),
    }


def emit(data):
    print(json.dumps(data, ensure_ascii=False))
    return 0 if data.get("ok") else 1


def set_one(uuid, automatic, dns4, dns6):
    connections = snapshot()
    connection = next((item for item in connections
                       if item["uuid"] == uuid), None)
    if connection is None:
        return payload(False, "No se encontró la conexión.")
    error = apply_dns(uuid, automatic, dns4, dns6)
    if error:
        return payload(False, error)
    return payload(True, warning=reapply(connection))


def set_all(automatic, dns4, dns6):
    connections = snapshot()
    if not connections:
        return payload(False, "No hay conexiones Wi-Fi o Ethernet guardadas.")
    warnings = []
    for connection in connections:
        error = apply_dns(connection["uuid"], automatic, dns4, dns6)
        if error:
            warnings.append("%s: %s" % (connection["label"], error))
            continue
        warning = reapply(connection)
        if warning:
            warnings.append(warning)
    if len(warnings) == len(connections):
        return payload(False, warnings[0])
    return payload(True, warning=". ".join(warnings),
                   count=len(connections))


def main():
    if len(sys.argv) < 2:
        return emit(payload(False, "Falta la acción."))
    action = sys.argv[1]
    try:
        if action == "list":
            return emit(payload(True))
        if action == "set" and len(sys.argv) >= 4:
            uuid = sys.argv[2]
            mode = sys.argv[3]
            if mode == "auto":
                return emit(set_one(uuid, True, [], []))
            if mode == "manual" and len(sys.argv) >= 6:
                dns4 = clean_addresses(sys.argv[4], 4)
                dns6 = clean_addresses(sys.argv[5], 6)
                return emit(set_one(uuid, False, dns4, dns6))
            return emit(payload(False, "Modo de DNS no válido."))
        if action == "set-all" and len(sys.argv) >= 3:
            mode = sys.argv[2]
            if mode == "auto":
                return emit(set_all(True, [], []))
            if mode == "manual" and len(sys.argv) >= 5:
                dns4 = clean_addresses(sys.argv[3], 4)
                dns6 = clean_addresses(sys.argv[4], 6)
                return emit(set_all(False, dns4, dns6))
            return emit(payload(False, "Modo de DNS no válido."))
        if action == "set-proxy" and len(sys.argv) >= 4:
            uuid = sys.argv[2]
            mode = sys.argv[3]
            if mode == "none":
                return emit(set_proxy(uuid, "none", "", "", "", "", ""))
            if mode == "auto" and len(sys.argv) >= 5:
                return emit(set_proxy(uuid, "auto", sys.argv[4],
                                      "", "", "", ""))
            if mode == "manual" and len(sys.argv) >= 8:
                return emit(set_proxy(uuid, "manual", "", sys.argv[4],
                                      sys.argv[5], sys.argv[6],
                                      sys.argv[7]))
            return emit(payload(False, "Modo de proxy no válido."))
        return emit(payload(False, "Uso no válido."))
    except ValueError as error:
        return emit(payload(False, str(error)))
    except OSError as error:
        return emit(payload(False, "No se pudo ejecutar nmcli: %s" % error))


if __name__ == "__main__":
    sys.exit(main())
