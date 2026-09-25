# Quick System Info

Quick System Info is an Omarchy bar widget that adds a compact temperature pill to the bar and a clean popup panel for hardware and system status.

![Quick System Info screenshot](screenshots/quick-system-info.png)

## Features

- Bar pill with current CPU package temperature
- Popup panel with:
  - CPU model and current/max frequency
  - memory usage
  - disk usage
  - GPU name and temperature when available
  - uptime
  - network label
  - IP address
  - host, kernel, and filesystem
- Left click opens the panel
- Middle click refreshes data
- Right click opens `btop`
- Performance-focused collector with cached static and network data

## Install

Install from a git repository with:

```bash
omarchy plugin add https://github.com/sisocobacho/jca.quick-system-info --enable --yes
```

Or install by hand:

```bash
git clone https://github.com/sisocobacho/jca.quick-system-info ~/.config/omarchy/plugins/jca.quick-system-info
omarchy-shell shell rescanPlugins
omarchy plugin enable jca.quick-system-info
```

## Update

```bash
omarchy plugin update jca.quick-system-info --yes
```

## Remove

```bash
omarchy plugin remove jca.quick-system-info
```

## Controls

- Left click: open panel
- Middle click: refresh
- Right click: open `btop`

## Requirements

The plugin expects these tools to be available:

- `python3`
- `lm_sensors` (`sensors`)
- `iproute2` (`ip`)
- `NetworkManager` (`nmcli`) for Wi-Fi SSID detection
- `pciutils` (`lspci`) for GPU name detection
- `btop` for right-click launch

The widget degrades gracefully if some data sources are missing.

## Notes

- Static hardware information is cached for 24 hours.
- Network information is cached for 15 seconds.
- GPU and disk temperatures depend on available sensors on the host machine.
- The plugin uses only local system commands and local files. It does not make network requests.
- Review the code before enabling, as Omarchy plugins run as local unsandboxed code inside `omarchy-shell`.

## Development

Test locally from the plugin directory:

```bash
python3 -m py_compile collect.py
python3 collect.py
omarchy-shell shell rescanPlugins
```

## License

MIT
