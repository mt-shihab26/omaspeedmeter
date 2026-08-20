# omarchy-sysmon

Omarchy bar widget: CPU, memory, network speed, temperature, GPU usage, and
process count, each individually toggleable from a click popup, plus a few
other settings (refresh interval, GPU vendor, network interface, temperature
source, combined vs. split up/down network display, word labels).

## Layout

- `manifest.json` — plugin manifest (`kinds: ["bar-widget"]`)
- `BarWidget.qml` — the bar row + click popup (settings UI)
- `Model.js` — pure formatting/settings helpers (no Quickshell runtime needed)
- `bin/omarchy-sysmon-stats` — bash script that samples `/proc`, `/sys`, and
  optionally `nvidia-smi` / `intel_gpu_top`, printing one JSON line per call
- `install.sh` — syncs this directory into
  `~/.config/omarchy/plugins/shihab.sysmon/` and reloads the shell

## Development

Edit files here, then run:

```bash
./install.sh
```

This copies the project into Omarchy's plugin directory and reloads it.
**A real copy, not a symlink** — the Omarchy shell's plugin file-watcher (and
`omarchy plugin validate`) doesn't reliably follow a symlinked plugin
directory, so editing the symlink target in place does not reload cleanly.

First time only:

```bash
./install.sh
omarchy plugin enable shihab.sysmon
omarchy bar move shihab.sysmon --section right   # or left/center
```

## Settings

All settings live inline on the widget's `shell.json` bar-layout entry and
can be changed either from the popup (click the widget) or via:

```bash
omarchy bar set shihab.sysmon <key> <value> --json
```

| Key | Type | Default | Meaning |
|---|---|---|---|
| `cpu`, `mem`, `net`, `temp`, `gpu`, `procs` | boolean | `true`/`true`/`true`/`true`/`true`/`false` | show/hide each metric |
| `labels` | boolean | `false` | prefix each segment with a word label |
| `netSplit` | boolean | `false` | show download/upload as two segments instead of one combined one |
| `interval` | number | `2` | poll interval in seconds |
| `gpuVendor` | string | `auto` | `auto`, `nvidia`, `amd`, `intel`, or `none` |
| `tempZone` | string | `auto` | `auto` or a `/sys/class/thermal/thermal_zoneN/temp` path |
| `netIface` | string | `auto` | `auto` or an interface name (e.g. `wlan0`) |

## GPU support

- **NVIDIA**: `nvidia-smi` (if installed)
- **AMD**: `/sys/class/drm/card*/device/gpu_busy_percent` (amdgpu)
- **Intel**: `intel_gpu_top -J` (needs perf access; falls back to N/A if it
  can't run)
