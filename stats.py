#!/usr/bin/env python3
"""Muestreo de CPU, GPU y red para el shell.

Imprime una línea JSON por segundo. No necesita privilegios: usa /proc,
/sys/class/hwmon y /sys/class/drm, y `ping` al gateway para la latencia.
"""

import glob
import json
import os
import re
import subprocess
import sys
import time


def read(path, default=None):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as handle:
            return handle.read().strip()
    except OSError:
        return default


def hwmon_dir(name):
    for folder in glob.glob("/sys/class/hwmon/hwmon*"):
        if read(folder + "/name") == name:
            return folder
    return None


def hwmon_value(name, filename, divisor=1000.0):
    folder = hwmon_dir(name)
    if not folder:
        return None
    raw = read(folder + "/" + filename)
    if raw is None:
        return None
    try:
        return float(raw) / divisor
    except ValueError:
        return None


def cpu_snapshot():
    total = idle = 0
    cores = []
    for line in (read("/proc/stat", "") or "").splitlines():
        if not line.startswith("cpu"):
            continue
        fields = line.split()
        try:
            values = [int(value) for value in fields[1:]]
        except ValueError:
            continue
        if not values:
            continue
        idle_all = values[3] + (values[4] if len(values) > 4 else 0)
        whole = sum(values)
        if fields[0] == "cpu":
            total, idle = whole, idle_all
        else:
            cores.append((whole, idle_all))
    return total, idle, cores


def cpu_frequency():
    values = []
    for line in (read("/proc/cpuinfo", "") or "").splitlines():
        if line.startswith("cpu MHz"):
            try:
                values.append(float(line.split(":", 1)[1]))
            except (ValueError, IndexError):
                pass
    return sum(values) / len(values) if values else 0.0


def gpu_power():
    return hwmon_value("amdgpu", "power1_input", 1000000.0)


def gpu_frequency():
    text = read("/sys/class/drm/card0/device/pp_dpm_sclk", "") or ""
    current = None
    maximum = None
    for line in text.splitlines():
        match = re.search(r"(\d+)\s*Mhz", line, re.IGNORECASE)
        if not match:
            continue
        value = float(match.group(1))
        maximum = value if maximum is None else max(maximum, value)
        if "*" in line:
            current = value
    return current, maximum


def default_route():
    best = None
    lines = (read("/proc/net/route", "") or "").splitlines()
    for line in lines[1:]:
        fields = line.split()
        if len(fields) < 8:
            continue
        interface, destination, gateway, flags, _ref, _use, metric, _mask = fields[:8]
        if destination != "00000000":
            continue
        try:
            if not (int(flags, 16) & 0x2):
                continue
            priority = int(metric)
        except ValueError:
            continue
        if best is None or priority < best[0]:
            best = (priority, interface, gateway)
    return best


def hex_address(value):
    try:
        octets = [str(int(value[index:index + 2], 16)) for index in (6, 4, 2, 0)]
        return ".".join(octets)
    except (ValueError, IndexError):
        return ""


def interface_ip(interface):
    try:
        output = subprocess.check_output(
            ["ip", "-4", "-brief", "addr", "show", "dev", interface],
            text=True, timeout=1.5)
    except (OSError, subprocess.SubprocessError):
        return ""
    for part in output.split():
        if "/" in part and part[0].isdigit():
            return part.split("/", 1)[0]
    return ""


def latency(gateway):
    if not gateway:
        return -1
    try:
        output = subprocess.check_output(
            ["ping", "-c", "1", "-W", "1", "-n", hex_address(gateway)],
            text=True, timeout=2.5)
    except (OSError, subprocess.SubprocessError):
        return -1
    match = re.search(r"time=([\d.]+)", output)
    return int(round(float(match.group(1)))) if match else -1


def net_bytes(interface):
    lines = (read("/proc/net/dev", "") or "").splitlines()
    for line in lines:
        if ":" not in line:
            continue
        name, values = line.split(":", 1)
        if name.strip() != interface:
            continue
        fields = values.split()
        try:
            return int(fields[0]), int(fields[8])
        except (ValueError, IndexError):
            return None
    return None


def clamp(value, low, high):
    return max(low, min(high, value))


def parent_alive(pid):
    if pid is None:
        return True
    try:
        with open("/proc/%d/stat" % pid, "r", encoding="utf-8", errors="ignore") as handle:
            fields = handle.read().split()
        return len(fields) > 2 and fields[2] != "Z"
    except OSError:
        return False


def main():
    watchdog_pid = None
    if len(sys.argv) > 1:
        try:
            watchdog_pid = int(sys.argv[1])
        except ValueError:
            watchdog_pid = None

    total, idle, cores = cpu_snapshot()
    route = default_route()
    interface = route[1] if route else ""
    gateway = route[2] if route else ""
    ip = interface_ip(interface) if interface else ""
    net_previous = net_bytes(interface) if interface else None
    session_down = session_up = 0.0
    peak_down = peak_up = 0.0
    last_time = time.monotonic()
    last_latency = -1
    tick = 0
    smooth_cpu = 0.0
    smooth_gpu = 0.0

    while True:
        # Si Quickshell se reinicia o muere, este proceso no debe quedarse
        # huérfano consumiendo CPU.
        if not parent_alive(watchdog_pid):
            return
        time.sleep(1)
        try:
            now = time.monotonic()
            elapsed = max(0.2, now - last_time)
            last_time = now
            tick += 1

            new_total, new_idle, new_cores = cpu_snapshot()
            delta_total = new_total - total
            delta_idle = new_idle - idle
            raw_cpu = 100.0 * (1.0 - delta_idle / delta_total) if delta_total > 0 else 0.0
            raw_cpu = clamp(raw_cpu, 0.0, 100.0)
            smooth_cpu = smooth_cpu * 0.55 + raw_cpu * 0.45

            core_load = []
            for (old_total, old_idle), (cur_total, cur_idle) in zip(cores, new_cores):
                span = cur_total - old_total
                idle_span = cur_idle - old_idle
                value = 100.0 * (1.0 - idle_span / span) if span > 0 else 0.0
                core_load.append(round(clamp(value, 0.0, 100.0), 1))
            total, idle, cores = new_total, new_idle, new_cores

            cpu_temp = hwmon_value("coretemp", "temp1_input")
            if cpu_temp is None:
                for zone in glob.glob("/sys/class/thermal/thermal_zone*"):
                    if read(zone + "/type") == "x86_pkg_temp":
                        raw = read(zone + "/temp")
                        try:
                            cpu_temp = float(raw) / 1000.0
                        except (TypeError, ValueError):
                            cpu_temp = None
                        break
            cpu_max_raw = read("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")
            try:
                cpu_max = float(cpu_max_raw) / 1000.0
            except (TypeError, ValueError):
                cpu_max = 0.0

            gpu_raw = read("/sys/class/drm/card0/device/gpu_busy_percent")
            try:
                raw_gpu = clamp(float(gpu_raw), 0.0, 100.0)
            except (TypeError, ValueError):
                raw_gpu = 0.0
            smooth_gpu = smooth_gpu * 0.55 + raw_gpu * 0.45
            gpu_temp = hwmon_value("amdgpu", "temp1_input")
            gpu_clock, gpu_clock_max = gpu_frequency()
            gpu_watts = gpu_power()
            vram_used = read("/sys/class/drm/card0/device/mem_info_vram_used")
            vram_total = read("/sys/class/drm/card0/device/mem_info_vram_total")

            if tick % 10 == 1:
                route = default_route()
                new_interface = route[1] if route else ""
                if new_interface and new_interface != interface:
                    interface = new_interface
                    gateway = route[2]
                    ip = interface_ip(interface)
                    net_previous = net_bytes(interface)
                elif interface:
                    ip = interface_ip(interface)
                last_latency = latency(gateway)

            current = net_bytes(interface) if interface else None
            down_rate = up_rate = 0.0
            if current and net_previous:
                down_rate = max(0.0, (current[0] - net_previous[0]) / elapsed)
                up_rate = max(0.0, (current[1] - net_previous[1]) / elapsed)
            net_previous = current
            session_down += down_rate * elapsed
            session_up += up_rate * elapsed
            peak_down = max(peak_down, down_rate)
            peak_up = max(peak_up, up_rate)

            payload = {
                "dt": round(elapsed, 3),
                "cpu": round(smooth_cpu, 1),
                "temp": round(cpu_temp, 1) if cpu_temp is not None else None,
                "freq": int(round(cpu_frequency())),
                "maxfreq": int(round(cpu_max)),
                "cores": core_load,
                "gpu": round(smooth_gpu, 1),
                "gtemp": round(gpu_temp, 1) if gpu_temp is not None else None,
                "gfreq": int(round(gpu_clock)) if gpu_clock else None,
                "gmaxfreq": int(round(gpu_clock_max)) if gpu_clock_max else None,
                "gpower": round(gpu_watts, 1) if gpu_watts is not None else None,
                "vram": int(vram_used) if vram_used else None,
                "vramtotal": int(vram_total) if vram_total else None,
                "down": round(down_rate),
                "up": round(up_rate),
                "sdown": round(session_down),
                "sup": round(session_up),
                "pdown": round(peak_down),
                "pup": round(peak_up),
                "lat": last_latency,
                "iface": interface,
                "ip": ip,
                "kind": (
                    "wifi" if interface.startswith("wl")
                    else ("vpn" if interface.startswith(("tun", "tap", "wg", "ppp"))
                        else ("wired" if interface else "none"))),
            }
            print(json.dumps(payload), flush=True)
        except Exception:
            # Un fallo puntual no debe matar el muestreo.
            continue


if __name__ == "__main__":
    main()
