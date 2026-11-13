#!/usr/bin/env python3
"""DNS y proxy de los perfiles de NetworkManager para el shell.

Uso:
    network-settings.py list
    network-settings.py dns-on <proveedor> <hostname> <ipv4> <ipv6>
    network-settings.py dns-off
    network-settings.py dns-suspend <proveedor> <hostname> <ipv4> <ipv6>
    network-settings.py dns-ensure
    network-settings.py dns-settings <proveedor> <hostname> <ipv4> <ipv6>
    network-settings.py dns-vpn <yes|no>
    network-settings.py set-proxy <uuid> none
    network-settings.py set-proxy <uuid> auto <pac>
    network-settings.py set-proxy <uuid> manual <http> <https> <socks> <no-proxy>

El DNS privado usa DNS over TLS con systemd-resolved y se aplica a las
conexiones Wi-Fi y Ethernet activas. `dns-on` activa el proveedor elegido,
`dns-off` vuelve al DNS automático y `dns-settings` guarda la selección sin
tocarla. `dns-vpn` recuerda si el DNS debe desactivarse mientras hay una VPN.
El proxy manual de la conexión activa también se escribe en
`~/.config/environment.d/90-shell-proxy.conf` para la próxima sesión. La salida
siempre es JSON.
"""

import ipaddress
import json
import os
import shutil
import socket
import subprocess
import sys
import urllib.parse

WIFI = "802-11-wireless"
WIRED = "802-3-ethernet"

ROOT_HELPER = "/usr/local/lib/shell/shell-private-dns"
RESOLVED_CONF = "/etc/systemd/resolved.conf.d/90-shell-dns.conf"

DNS_DEFAULT = {
    "enabled": False,
    "provider": "cloudflare",
    "hostname": "",
    "ipv4": "",
    "ipv6": "",
    "disabledForVpn": False,
}

# Proveedores con DoT estricto. Las IP se validaron contra el certificado de
# cada servidor; el nombre es el que se comprueba en el TLS.
DNS_PRESETS = {
    "cloudflare": {
        "host": "one.one.one.one",
        "servers": [
            "1.1.1.1", "1.0.0.1",
            "2606:4700:4700::1111", "2606:4700:4700::1001",
        ],
    },
    "adguard": {
        "host": "dns.adguard-dns.com",
        "servers": [
            "94.140.14.14", "94.140.15.15",
            "2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff",
        ],
    },
    "opendns": {
        "host": "doh.opendns.com",
        "servers": [
            "208.67.222.222", "208.67.220.220",
            "2620:119:35::35", "2620:119:53::53",
        ],
    },
    "cleanbrowsing": {
        "host": "security-filter-dns.cleanbrowsing.org",
        "servers": [
            "185.228.168.9", "185.228.169.9",
            "2a0d:2a00:1::2", "2a0d:2a00:2::2",
        ],
    },
    "quad9": {
        "host": "dns.quad9.net",
        "servers": [
            "9.9.9.9", "149.112.112.112",
            "2620:fe::fe", "2620:fe::9",
        ],
    },
}


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
        # El perfil del punto de acceso que emite el shell también es
        # 802-11-wireless, pero no es una red a la que se conecte el equipo.
        # Sin este filtro aparecía en DNS como una red más (su SSID es el
        # nombre del equipo, p. ej. «Desktop»).
        if kind == WIFI and nm_get(uuid, "802-11-wireless.mode") == "ap":
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


def set_link_dns(connection, private):
    """Deja el enlace sin DNS propio para que use el global de resolved.

    En modo privado se ignoran los DNS del router y el enlace queda sin
    servidores; systemd-resolved usa el proveedor DoT global. En modo
    automático se vuelve a aceptar el DNS del router.
    """
    args = [
        "nmcli", "connection", "modify", connection["uuid"],
        "ipv4.ignore-auto-dns", "yes" if private else "no",
        "ipv4.dns", "",
        "ipv6.ignore-auto-dns", "yes" if private else "no",
        "ipv6.dns", "",
        "connection.dns-over-tls", "default",
    ]
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


def dns_config_path():
    return os.path.expanduser("~/.config/shell/dns.json")


def load_dns_config():
    config = dict(DNS_DEFAULT)
    try:
        with open(dns_config_path(), "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        return config
    if not isinstance(data, dict):
        return config
    if isinstance(data.get("enabled"), bool):
        config["enabled"] = data["enabled"]
    if isinstance(data.get("disabledForVpn"), bool):
        config["disabledForVpn"] = data["disabledForVpn"]
    provider = str(data.get("provider") or "")
    if provider in DNS_PRESETS or provider in ("hostname", "manual"):
        config["provider"] = provider
    for key in ("hostname", "ipv4", "ipv6"):
        config[key] = str(data.get(key) or "")[:253]
    return config


def save_dns_config(config):
    path = dns_config_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    temporary = path + ".tmp"
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC,
                         0o600)
    with os.fdopen(descriptor, "w") as handle:
        json.dump(config, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    os.replace(temporary, path)
    os.chmod(path, 0o600)


def private_dns_available():
    return bool(shutil.which("resolvectl")) and os.path.isfile(ROOT_HELPER)


def resolved_conf_exists():
    return os.path.isfile(RESOLVED_CONF)


def run_root_dns(args):
    if not os.path.isfile(ROOT_HELPER):
        return ("Falta el ayudante de DNS privado; ejecuta el instalador.")
    result = run(["sudo", "-n", ROOT_HELPER] + args)
    if result.returncode == 0:
        return ""
    text = (result.stderr.strip() or result.stdout.strip())
    lowered = text.lower()
    if "password" in lowered or "contraseña" in lowered \
            or "no tty present" in lowered:
        return ("El DNS privado necesita el permiso del instalador "
                "(sudo sin contraseña para shell-private-dns).")
    return text or "No se pudo aplicar el DNS privado."


def resolve_host(hostname):
    try:
        infos = socket.getaddrinfo(hostname, 853,
                                   type=socket.SOCK_STREAM)
    except socket.gaierror as error:
        return [], str(error)
    addresses = []
    for info in infos:
        address = info[4][0]
        try:
            parsed = ipaddress.ip_address(address)
        except ValueError:
            continue
        if parsed.is_link_local:
            continue
        value = str(parsed)
        if value not in addresses:
            addresses.append(value)
    return addresses, ""


def apply_active_links(private):
    connections = [item for item in snapshot() if item["active"]]
    warnings = []
    applied = 0
    for connection in connections:
        error = set_link_dns(connection, private)
        if error:
            warnings.append("%s: %s" % (connection["label"], error))
            continue
        applied += 1
        warning = reapply(connection)
        if warning:
            warnings.append(warning)
    if connections and applied == 0:
        return 0, warnings[0]
    return applied, ". ".join(warnings)


def dns_on(provider, hostname, ipv4, ipv6):
    provider = str(provider or "").strip()
    hostname = str(hostname or "").strip()
    ipv4 = str(ipv4 or "").strip()
    ipv6 = str(ipv6 or "").strip()
    if provider not in DNS_PRESETS and provider not in (
            "hostname", "manual"):
        return payload(False, "Proveedor DNS no válido.")

    entries = []
    tls = "yes"
    if provider in DNS_PRESETS:
        preset = DNS_PRESETS[provider]
        entries = ["%s#%s" % (server, preset["host"])
                   for server in preset["servers"]]
    elif provider == "hostname":
        if not hostname:
            return payload(False, "Escribe el nombre del proveedor DNS.")
        if len(hostname) > 253 or hostname.startswith(".") \
                or hostname.endswith(".") or ".." in hostname \
                or not all(ch.isalnum() or ch in ".-" for ch in hostname):
            return payload(False, "El nombre del proveedor no es válido.")
        addresses, error = resolve_host(hostname)
        if not addresses:
            return payload(False, "No se pudo resolver %s: %s"
                           % (hostname, error or "sin direcciones"))
        entries = ["%s#%s" % (address, hostname) for address in addresses]
    elif provider == "manual":
        dns4 = clean_addresses(ipv4, 4)
        dns6 = clean_addresses(ipv6, 6)
        entries = dns4 + dns6
        if not entries:
            return payload(False, "Escribe al menos un servidor DNS.")
        tls = "opportunistic"

    error = run_root_dns(["apply", tls] + entries)
    if error:
        return payload(False, error)

    count, warning = apply_active_links(True)
    run(["resolvectl", "flush-caches"])

    config = load_dns_config()
    config.update({
        "enabled": True,
        "provider": provider,
        "hostname": hostname,
        "ipv4": ipv4,
        "ipv6": ipv6,
    })
    try:
        save_dns_config(config)
    except OSError as error:
        warning = (warning + ". " if warning else "") \
            + "No se pudo guardar la configuración: %s" % error
    return payload(True, warning=warning, count=count)


def dns_off():
    if os.path.isfile(ROOT_HELPER):
        error = run_root_dns(["off"])
        if error:
            return payload(False, error)
    elif os.path.isfile(RESOLVED_CONF):
        return payload(False, "Falta el ayudante de DNS privado; "
                       "ejecuta el instalador para poder desactivarlo.")
    count, warning = apply_active_links(False)
    run(["resolvectl", "flush-caches"])
    config = load_dns_config()
    config["enabled"] = False
    try:
        save_dns_config(config)
    except OSError as error:
        warning = (warning + ". " if warning else "") \
            + "No se pudo guardar la configuración: %s" % error
    return payload(True, warning=warning, count=count)


def dns_suspend(provider, hostname, ipv4, ipv6):
    """Desactiva el DNS privado sin apagar el interruptor principal.

    Se usa mientras hay una VPN y el usuario activó «Desactivado para VPN».
    La selección se conserva para restaurarla al desconectar.
    """
    provider = str(provider or "").strip()
    if provider not in DNS_PRESETS and provider not in (
            "hostname", "manual"):
        return payload(False, "Proveedor DNS no válido.")
    if os.path.isfile(ROOT_HELPER):
        error = run_root_dns(["off"])
        if error:
            return payload(False, error)
    elif os.path.isfile(RESOLVED_CONF):
        return payload(False, "Falta el ayudante de DNS privado; "
                       "ejecuta el instalador para poder suspenderlo.")
    count, warning = apply_active_links(False)
    run(["resolvectl", "flush-caches"])
    config = load_dns_config()
    config.update({
        "enabled": True,
        "provider": provider,
        "hostname": str(hostname or "").strip()[:253],
        "ipv4": str(ipv4 or "").strip()[:253],
        "ipv6": str(ipv6 or "").strip()[:253],
    })
    try:
        save_dns_config(config)
    except OSError as error:
        warning = (warning + ". " if warning else "") \
            + "No se pudo guardar la configuración: %s" % error
    return payload(True, warning=warning, count=count)


def active_links():
    """Devuelve (uuid, dispositivo) de las conexiones Wi-Fi y Ethernet activas."""
    result = run(["nmcli", "-t", "-f", "UUID,TYPE,DEVICE",
                  "connection", "show", "--active"])
    links = []
    for line in result.stdout.splitlines():
        parts = fields(line)
        if len(parts) < 3:
            continue
        uuid, kind, device = parts[0], parts[1], parts[2]
        if kind in (WIFI, WIRED) and device and device != "--":
            links.append((uuid, device))
    return links


def dns_ensure():
    """Quita el DNS del router a las conexiones activas nuevas.

    Se llama cuando NetworkManager cambia su lista de dispositivos y con un
    sondeo lento mientras el DNS privado está activo. Solo consulta las
    conexiones activas y no reinicia resolved.
    """
    config = load_dns_config()
    if not config["enabled"] or not private_dns_available() \
            or not resolved_conf_exists():
        return payload(True, with_connections=False)
    warnings = []
    changed = 0
    for uuid, device in active_links():
        values = run([
            "nmcli", "-g", "ipv4.ignore-auto-dns,ipv6.ignore-auto-dns",
            "connection", "show", uuid,
        ]).stdout.splitlines()
        while len(values) < 2:
            values.append("")
        if values[0].strip() == "yes" and values[1].strip() == "yes":
            continue
        result = run([
            "nmcli", "connection", "modify", uuid,
            "ipv4.ignore-auto-dns", "yes", "ipv4.dns", "",
            "ipv6.ignore-auto-dns", "yes", "ipv6.dns", "",
        ])
        if result.returncode != 0:
            warnings.append("%s: %s" % (
                device, result.stderr.strip() or "no se pudo aplicar"))
            continue
        changed += 1
        result = run(["nmcli", "device", "reapply", device])
        if result.returncode != 0:
            warnings.append(result.stderr.strip()
                            or "no se pudo aplicar en %s" % device)
    if changed:
        run(["resolvectl", "flush-caches"])
    return payload(True, warning=". ".join(warnings), count=changed,
                   with_connections=False)


def dns_settings(provider, hostname, ipv4, ipv6):
    provider = str(provider or "").strip()
    if provider not in DNS_PRESETS and provider not in (
            "hostname", "manual"):
        return payload(False, "Proveedor DNS no válido.")
    config = load_dns_config()
    config["provider"] = provider
    config["hostname"] = str(hostname or "").strip()[:253]
    config["ipv4"] = str(ipv4 or "").strip()[:253]
    config["ipv6"] = str(ipv6 or "").strip()[:253]
    try:
        save_dns_config(config)
    except OSError as error:
        return payload(False, "No se pudo guardar el DNS: %s" % error)
    return payload(True)


def dns_vpn(value):
    config = load_dns_config()
    config["disabledForVpn"] = str(value or "") == "yes"
    try:
        save_dns_config(config)
    except OSError as error:
        return payload(False, "No se pudo guardar el DNS: %s" % error)
    return payload(True)


def proxy_config_path():
    return os.path.expanduser("~/.config/shell/proxy.json")


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
        "~/.config/environment.d/90-shell-proxy.conf")


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


def payload(ok, error="", warning="", count=0, env_file="",
            with_connections=True):
    data = {
        "ok": ok,
        "error": error,
        "warning": warning,
        "count": count,
        "envFile": env_file,
        "settings": load_dns_config(),
        "dnsApplied": resolved_conf_exists(),
        "dnsAvailable": private_dns_available(),
    }
    if with_connections:
        data["connections"] = snapshot()
    return data


def emit(data):
    print(json.dumps(data, ensure_ascii=False))
    return 0 if data.get("ok") else 1


def main():
    if len(sys.argv) < 2:
        return emit(payload(False, "Falta la acción."))
    action = sys.argv[1]
    try:
        if action == "list":
            return emit(payload(True))
        if action == "dns-on" and len(sys.argv) >= 6:
            return emit(dns_on(sys.argv[2], sys.argv[3],
                               sys.argv[4], sys.argv[5]))
        if action == "dns-off":
            return emit(dns_off())
        if action == "dns-suspend" and len(sys.argv) >= 6:
            return emit(dns_suspend(sys.argv[2], sys.argv[3],
                                    sys.argv[4], sys.argv[5]))
        if action == "dns-ensure":
            return emit(dns_ensure())
        if action == "dns-settings" and len(sys.argv) >= 6:
            return emit(dns_settings(sys.argv[2], sys.argv[3],
                                     sys.argv[4], sys.argv[5]))
        if action == "dns-vpn" and len(sys.argv) >= 3:
            return emit(dns_vpn(sys.argv[2]))
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
