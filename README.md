# omarchy-sysmon

Omarchy bar widget: CPU, memory, network speed, temperature, GPU usage, and
process count, each individually toggleable from a click popup, plus a few
other settings (refresh interval, GPU vendor, network interface, temperature
source, combined vs. split up/down network display, word labels).

## Installation

```bash
omarchy plugin add https://github.com/mt-shihab26/omaspeedmeter.git --enable
```

Lands in the right section of the bar by default; move it with:

```bash
omarchy bar move mt-shihab26.omaspeedmeter --section left   # or center/right
```

To remove it:

```bash
omarchy plugin remove mt-shihab26.omaspeedmeter
```

## Development

This directory lives directly under `~/.config/omarchy/plugins/` and is
picked up in place — no separate install/copy step. Edit files here, then
reload:

```bash
omarchy restart shell
```

A plain `omarchy-shell shell rescanPlugins` can leave a stale compiled copy
of an already-loaded widget in memory, so a full shell restart is the
reliable way to pick up changes here.

First time only:

```bash
omarchy plugin enable mt-shihab26.omaspeedmeter
```

## Settings

All settings live inline on the widget's `shell.json` bar-layout entry and
can be changed either from the popup (click the widget) or via:

```bash
omarchy bar set mt-shihab26.omaspeedmeter <key> <value> --json
```

| Key | Type | Default | Meaning |
|---|---|---|---|
| `cpu`, `mem`, `net`, `temp`, `gpu`, `procs` | boolean | `true`/`true`/`true`/`false`/`false`/`false` | show/hide each metric |
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
