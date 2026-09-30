#!/usr/bin/env python3
import json
import math
import os
import re
import subprocess
import time
from pathlib import Path

HOME = Path.home()
CACHE_DIR = HOME / ".cache" / "omarchy-system-widget"
STATIC_CACHE = CACHE_DIR / "static-v4.json"
NETWORK_CACHE = CACHE_DIR / "network.json"
STATIC_TTL = 86400
NETWORK_TTL = 15


def run_text(command, timeout=2.5):
    try:
        out = subprocess.run(command, capture_output=True, text=True, timeout=timeout, check=False)
    except Exception:
        return ""
    return out.stdout if out.returncode == 0 else ""


def run_json(command, timeout=2.5):
    text = run_text(command, timeout=timeout)
    if not text:
        return None
    try:
        return json.loads(text)
    except Exception:
        return None


def read_text(path):
    try:
        return Path(path).read_text().strip()
    except Exception:
        return ""


def read_json_cache(path, ttl):
    try:
        data = json.loads(Path(path).read_text())
    except Exception:
        return None
    if time.time() - float(data.get("ts", 0)) > ttl:
        return None
    return data.get("value")


def write_json_cache(path, value):
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        Path(path).write_text(json.dumps({"ts": time.time(), "value": value}))
    except Exception:
        pass


def sanitize_temp(value):
    try:
        value = float(value)
    except Exception:
        return None
    if math.isnan(value) or value < 1 or value > 125:
        return None
    return value


def iter_sensor_readings(tree):
    for chip_name, chip in (tree or {}).items():
        if not isinstance(chip, dict):
            continue
        for label, reading in chip.items():
            if label == "Adapter" or not isinstance(reading, dict):
                continue
            temp = None
            temp_max = None
            temp_crit = None
            for key, value in reading.items():
                if key.endswith("_input"):
                    temp = sanitize_temp(value)
                elif key.endswith("_max"):
                    temp_max = sanitize_temp(value)
                elif key.endswith("_crit"):
                    temp_crit = sanitize_temp(value)
            if temp is None:
                continue
            yield {
                "chip": str(chip_name),
                "label": str(label),
                "temp": temp,
                "max": temp_max,
                "crit": temp_crit,
            }


def pick_temperature(sensor_data):
    readings = list(iter_sensor_readings(sensor_data))
    cpu_candidates = []
    gpu_candidates = []
    disk_candidates = []
    fallback = []

    for entry in readings:
        chip = entry["chip"].lower()
        label = entry["label"].lower()
        combined = f"{chip} {label}"

        if any(token in chip for token in ["amdgpu", "nouveau", "nvidia"]) or any(token in label for token in ["gpu", "edge", "junction"]):
            gpu_candidates.append(entry)
            continue
        if "nvme" in chip:
            disk_candidates.append(entry)
            continue
        if any(token in combined for token in ["package id", "tdie", "tctl", "coretemp", "cpu"]):
            cpu_candidates.append(entry)
            continue
        fallback.append(entry)

    def sort_key(item):
        preferred = 0 if "package id" in item["label"].lower() else 1
        return (preferred, -item["temp"])

    cpu = sorted(cpu_candidates, key=sort_key)[0] if cpu_candidates else (max(fallback, key=lambda x: x["temp"]) if fallback else None)
    gpu = max(gpu_candidates, key=lambda x: x["temp"]) if gpu_candidates else None
    disk = max(disk_candidates, key=lambda x: x["temp"]) if disk_candidates else None
    return cpu, gpu, disk


def fmt_bytes(value):
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    value = float(value or 0)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.1f} {unit}"
        value /= 1024.0


def fmt_uptime(seconds):
    seconds = int(seconds or 0)
    days, seconds = divmod(seconds, 86400)
    hours, seconds = divmod(seconds, 3600)
    minutes, _ = divmod(seconds, 60)
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours:
        parts.append(f"{hours}h")
    if minutes or not parts:
        parts.append(f"{minutes}m")
    return " ".join(parts[:2])


def compact_name(value):
    value = (value or "").strip()
    value = re.sub(r"\s+@\s+.*$", "", value)
    value = value.replace("(R)", "")
    value = value.replace("(TM)", "")
    value = re.sub(r"\s+CPU$", "", value)
    value = re.sub(r"\s+\(Integrated\)$", "", value)
    return re.sub(r"\s+", " ", value).strip()


def fmt_ghz(mhz):
    try:
        mhz = float(mhz)
    except Exception:
        return ""
    if mhz <= 0:
        return ""
    ghz = mhz / 1000.0
    text = f"{ghz:.1f}".rstrip("0").rstrip(".")
    return f"{text} GHz"


def current_cpu_mhz():
    values = []
    for path in sorted(Path("/sys/devices/system/cpu").glob("cpu[0-9]*/cpufreq/scaling_cur_freq")):
        try:
            values.append(float(path.read_text().strip()) / 1000.0)
        except Exception:
            pass
    if values:
        return sum(values) / len(values)

    mhz_values = []
    for line in read_text("/proc/cpuinfo").splitlines():
        if line.lower().startswith("cpu mhz"):
            try:
                mhz_values.append(float(line.split(":", 1)[1].strip()))
            except Exception:
                pass
    if mhz_values:
        return sum(mhz_values) / len(mhz_values)
    return None


def max_cpu_mhz():
    values = []
    for path in sorted(Path("/sys/devices/system/cpu").glob("cpu[0-9]*/cpufreq/cpuinfo_max_freq")):
        try:
            values.append(float(path.read_text().strip()) / 1000.0)
        except Exception:
            pass
    if values:
        return max(values)
    return None


def root_filesystem():
    for line in read_text("/proc/mounts").splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[1] == "/":
            return parts[2]
    return ""


def distribution_name():
    values = {}
    for line in read_text("/etc/os-release").splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"')
    return values.get("PRETTY_NAME") or values.get("NAME") or ""


def short_brand(value):
    value = compact_name((value or "").replace("_", " "))
    if not value:
        return ""

    mappings = {
        "ASUSTEK": "ASUS",
        "ASUSTEK COMPUTER": "ASUS",
        "ASUSTEK COMPUTER INC.": "ASUS",
        "HEWLETT-PACKARD": "HP",
        "MICRO-STAR": "MSI",
        "MICRO-STAR INTERNATIONAL": "MSI",
        "LENOVO": "Lenovo",
    }

    mapped = mappings.get(value.upper())
    if mapped:
        return mapped

    first = value.split()[0]
    return mappings.get(first.upper(), first)


def hostnamectl_info():
    data = run_json(["hostnamectl", "--json=short", "status"], timeout=2.0)
    return data if isinstance(data, dict) else {}


def host_name(hostctl=None):
    model = compact_name((hostctl or {}).get("HardwareModel", ""))
    if model:
        return model

    for path in [
        "/sys/devices/virtual/dmi/id/product_name",
        "/sys/class/dmi/id/product_name",
    ]:
        value = compact_name(read_text(path))
        if value:
            return value
    return compact_name(os.uname().nodename)


def device_name(hostctl=None):
    vendor = ""
    for path in [
        "/sys/devices/virtual/dmi/id/sys_vendor",
        "/sys/class/dmi/id/sys_vendor",
    ]:
        vendor = short_brand(read_text(path))
        if vendor:
            break

    if not vendor:
        vendor = short_brand((hostctl or {}).get("HardwareVendor", ""))

    product = host_name(hostctl)
    if vendor and product:
        if product.lower().startswith(vendor.lower()):
            return product
        return f"{vendor} {product}"
    return product or vendor or compact_name(os.uname().nodename)


def clean_output(text):
    text = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", text or "")
    text = re.sub(r"\x03\d{0,2}", "", text)
    return re.sub(r"[\x00-\x09\x0b-\x1f\x7f]", "", text)


def ram_type():
    output = clean_output(run_text(["inxi", "-mxx"], timeout=3.0))
    if not output:
        return ""

    types = []
    for line in output.splitlines():
        if "Device-" not in line or "type" not in line:
            continue
        match = re.search(r"\btype\s+(.+?)(?:\s+(?:size|speed|configured|clock|volts|manufacturer|part-no)\b|$)", line)
        if not match:
            continue
        value = compact_name(match.group(1))
        lowered = value.lower()
        if not value or "no module installed" in lowered or lowered in {"unknown", "none"}:
            continue
        if value not in types:
            types.append(value)

    if not types:
        return ""
    return types[0] if len(types) == 1 else " / ".join(types)


def cpu_name():
    for line in read_text("/proc/cpuinfo").splitlines():
        if line.lower().startswith("model name"):
            return compact_name(line.split(":", 1)[1].strip())
    return "Unknown CPU"


def gpu_name():
    output = run_text(["lspci", "-mm"], timeout=2.0)
    for line in output.splitlines():
        if any(kind in line for kind in ["VGA compatible controller", "3D controller", "Display controller"]):
            parts = re.findall(r'"([^"]+)"', line)
            if len(parts) >= 3:
                vendor = compact_name(parts[1])
                model = compact_name(parts[2])

                bracketed = re.findall(r'\[([^\]]+)\]', model)
                if bracketed:
                    model = compact_name(bracketed[-1])

                model = re.sub(r"^Corporation\s+", "", model)
                model = re.sub(r"^Intel\s+", "", model)
                model = re.sub(r"^AMD\s+", "", model)
                model = re.sub(r"^NVIDIA\s+", "", model)
                model = compact_name(model)

                if model:
                    return model
                if vendor:
                    return vendor
            return compact_name(line)
    return "Unknown GPU"


def memory_info():
    values = {}
    for line in read_text("/proc/meminfo").splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        try:
            values[key.strip()] = int(value.strip().split()[0]) * 1024
        except Exception:
            pass
    total = int(values.get("MemTotal", 0))
    available = int(values.get("MemAvailable", values.get("MemFree", 0)))
    used = max(0, total - available)
    return total, used


def disk_info(path="/"):
    stats = os.statvfs(path)
    total = stats.f_frsize * stats.f_blocks
    free = stats.f_frsize * stats.f_bavail
    used = max(0, total - free)
    return total, used


def uptime_seconds():
    text = read_text("/proc/uptime")
    if not text:
        return 0
    try:
        return float(text.split()[0])
    except Exception:
        return 0


def network_info():
    cached = read_json_cache(NETWORK_CACHE, NETWORK_TTL)
    if isinstance(cached, dict):
        return cached

    ip_addr = "—"
    label = "—"

    routes = run_json(["ip", "-json", "route", "show", "default"], timeout=1.5)
    addrs = run_json(["ip", "-json", "addr"], timeout=1.5)

    default_dev = ""
    if isinstance(routes, list):
        for route in routes:
            if isinstance(route, dict) and route.get("dev"):
                default_dev = str(route.get("dev"))
                break

    if isinstance(addrs, list):
        preferred = []
        fallback = []
        for iface in addrs:
            if not isinstance(iface, dict):
                continue
            name = str(iface.get("ifname") or "")
            if name == "lo":
                continue
            for addr in iface.get("addr_info") or []:
                if not isinstance(addr, dict):
                    continue
                if addr.get("family") != "inet" or addr.get("scope") != "global":
                    continue
                local = str(addr.get("local") or "").strip()
                if not local:
                    continue
                entry = (name, local, str(iface.get("operstate") or ""))
                if name == default_dev and entry[2] == "UP":
                    preferred.insert(0, entry)
                elif entry[2] == "UP":
                    preferred.append(entry)
                else:
                    fallback.append(entry)
        chosen = preferred[0] if preferred else (fallback[0] if fallback else None)
        if chosen:
            default_dev = chosen[0]
            ip_addr = chosen[1]

    if default_dev.startswith(("wl", "wlan")):
        wifi = run_text(["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"], timeout=1.5)
        ssid = ""
        for line in wifi.splitlines():
            if line.startswith("yes:"):
                ssid = line.split(":", 1)[1].strip()
                break
        label = f"Wi-Fi · {ssid}" if ssid else "Wi-Fi"
    elif default_dev.startswith(("en", "eth")):
        label = "Ethernet"
    elif default_dev:
        label = default_dev

    result = {"ip_address": ip_addr, "network": label}
    write_json_cache(NETWORK_CACHE, result)
    return result


def static_info():
    cached = read_json_cache(STATIC_CACHE, STATIC_TTL)
    if isinstance(cached, dict):
        return cached

    hostctl = hostnamectl_info()
    result = {
        "device": device_name(hostctl),
        "host": host_name(hostctl),
        "distribution": distribution_name(),
        "kernel": os.uname().release,
        "cpu_name": cpu_name(),
        "cpu_max": fmt_ghz(max_cpu_mhz()),
        "gpu": gpu_name(),
        "ram_type": ram_type(),
        "filesystem": root_filesystem(),
    }
    write_json_cache(STATIC_CACHE, result)
    return result


def main():
    static = static_info()
    network = network_info()
    sensors = run_json(["sensors", "-j"], timeout=2.0)

    cpu_sensor, gpu_sensor, disk_sensor = pick_temperature(sensors)
    cpu_temp = round(cpu_sensor["temp"]) if cpu_sensor else None
    gpu_temp = round(gpu_sensor["temp"]) if gpu_sensor else None
    disk_temp = round(disk_sensor["temp"]) if disk_sensor else None

    memory_total, memory_used = memory_info()
    disk_total, disk_used = disk_info("/")
    cpu_current = fmt_ghz(current_cpu_mhz())
    cpu_max = static.get("cpu_max") or ""

    result = {
        "ok": True,
        "label": f" {cpu_temp}°" if cpu_temp is not None else " --",
        "temperature_c": cpu_temp,
        "temperature_text": f"{cpu_temp}°C" if cpu_temp is not None else "—",
        "temperature_source": cpu_sensor["label"] if cpu_sensor else "No sensor",
        "device": static.get("device") or static.get("host") or "—",
        "host": static.get("host") or "—",
        "distribution": static.get("distribution") or "—",
        "kernel": static.get("kernel") or os.uname().release,
        "cpu_name": static.get("cpu_name") or "Unknown CPU",
        "cpu": ((cpu_current + " / " + cpu_max) if cpu_current and cpu_max else (cpu_current or cpu_max or "—")),
        "gpu": static.get("gpu") or "Unknown GPU",
        "gpu_temp": gpu_temp,
        "disk_temp": disk_temp,
        "memory_used": fmt_bytes(memory_used),
        "memory_total": fmt_bytes(memory_total),
        "memory_percent": round((memory_used / memory_total) * 100) if memory_total else 0,
        "ram_type": static.get("ram_type") or "—",
        "disk_used": fmt_bytes(disk_used),
        "disk_total": fmt_bytes(disk_total),
        "disk_percent": round((disk_used / disk_total) * 100) if disk_total else 0,
        "filesystem": static.get("filesystem") or "",
        "uptime": fmt_uptime(uptime_seconds()),
        "network": network.get("network") or "—",
        "ip_address": network.get("ip_address") or "—",
    }
    result["summary"] = (
        f"{result['device']} • {result['temperature_text']} • "
        f"CPU {result['cpu']} • "
        f"RAM {result['memory_used']} / {result['memory_total']} • "
        f"Disk {result['disk_used']} / {result['disk_total']} • "
        f"Uptime {result['uptime']}"
    )

    print(json.dumps(result))


if __name__ == "__main__":
    main()
