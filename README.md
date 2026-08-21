# omaspeedmeter

Omarchy bar widget showing CPU, memory, network, temperature, GPU, and process count stats.

Click the widget in the bar to open a settings popup where you can toggle
metrics, split network into up/down segments, switch icons for word labels,
move the widget between bar sections, and change the refresh interval, GPU
vendor, temperature source, and network interface — all without editing
config files by hand.

![Omaspeedmeter bar widget screenshot](docs/screenshot.png)

## Installation

```bash
omarchy plugin add https://github.com/mt-shihab26/omaspeedmeter.git --enable
```

To remove it:

```bash
omarchy plugin remove mt-shihab26.omaspeedmeter
```

## Metrics

| Metric  | Icon | Source                                       | Notes                                   |
| ------- | :--: | --------------------------------------------- | ---------------------------------------- |
| Network |     | `/sys/class/net/<iface>/statistics/*_bytes` | Combined or split into download/upload  |
| CPU     |     | `/proc/stat`                                | Usage % since the previous poll         |
| Temp    |     | `/sys/class/thermal/thermal_zone*/temp`     | Prefers the CPU package/core sensor     |
| Memory  |     | `/proc/meminfo`                             | `(MemTotal - MemAvailable) / MemTotal` |
| GPU     |  󰢮   | `nvidia-smi`, sysfs, or `intel_gpu_top`   | Vendor auto-detected                    |
| Procs   |     | `/proc/[0-9]*`                              | Count of running process directories    |

Icons come from the Nerd Font glyph set Omarchy already ships for the bar, so
they render consistently with the built-in widgets. Enable **word labels** in
the settings popup to show `CPU`, `MEM`, etc. instead.

CPU and network are rate-based and need two polls to produce a real number,
so they show `…` for the first tick after the widget loads or after the
refresh interval changes.

## Settings

All settings are toggled/edited from the bar widget's click popup, and are
persisted via `omarchy bar set`.

| Setting    | Default | Description                                              |
| ---------- | ------- | ---------------------------------------------------------- |
| `cpu`      | `true`  | Show CPU usage %                                          |
| `mem`      | `true`  | Show memory usage %                                       |
| `net`      | `true`  | Show network speed                                        |
| `temp`     | `false` | Show CPU temperature                                       |
| `gpu`      | `false` | Show GPU usage %                                           |
| `procs`    | `false` | Show running process count                                 |
| `labels`   | `false` | Show word labels (`CPU`, `MEM`, ...) instead of icons     |
| `netSplit` | `false` | Show download/upload as two separate segments              |
| `interval` | `2`     | Refresh interval, in seconds                                |
| `gap`      | `8`     | Spacing between segments, in pixels (matches Omarchy's own control-gap spacing) |
| `gpuVendor`| `auto`  | `auto`, `nvidia`, `amd`, `intel`, or `none`         |
| `tempZone` | `auto`  | `auto`, or a specific `/sys/class/thermal/thermal_zone*/temp` path |
| `netIface` | `auto`  | `auto`, or a specific network interface name              |

`auto` for GPU vendor and temperature zone probes the system on each poll;
pinning a specific value skips detection and avoids picking the wrong sensor
on machines with multiple thermal zones or GPUs. The network interface and
temperature zone dropdowns are populated live from `/sys/class/net` and
`/sys/class/thermal` when the popup opens.

The bar position dropdown (left/center/right) reads and writes the widget's
placement via `omarchy-shell`/`omarchy bar move`, independent of the
`defaultSection` set on first install.

## How it works

Each metric is collected by a small standalone bash script in `bin/`, run on
a timer by `BarWidget.qml` and merged into a single stats object:

- `omaspeedmeter-cpu` — reads `/proc/stat`, diffs against a cached previous
  sample in `$XDG_CACHE_HOME/omaspeedmeter/cpu` to compute usage %.
- `omaspeedmeter-mem` — reads `/proc/meminfo` directly (no state needed).
- `omaspeedmeter-net` — reads interface byte counters from sysfs, diffs
  against `$XDG_CACHE_HOME/omaspeedmeter/net` to compute throughput.
- `omaspeedmeter-temp` — reads a thermal zone from sysfs, auto-preferring a
  zone whose type matches a known CPU sensor (`coretemp`, `k10temp`, etc.).
- `omaspeedmeter-gpu` — detects the GPU vendor and shells out to
  `nvidia-smi`, AMD's `gpu_busy_percent` sysfs file, or `intel_gpu_top`.
- `omaspeedmeter-procs` — counts `/proc/[0-9]*` directories.

Each script only runs when its metric is enabled, and only prints a single
line of JSON (e.g. `{"cpu":42}`), which `Model.js` parses and formats into
the bar segments. `Model.js` holds all the pure logic (settings resolution,
formatting, segment building) separately from the QML so it can be reasoned
about — and unit tested — without a Quickshell runtime.

## Requirements

- Linux with `/proc` and `/sys` available (standard on any distro).
- `awk`, `bash`, `ip` — present on virtually every system.
- GPU stats additionally require, depending on vendor:
  - NVIDIA: `nvidia-smi`
  - AMD: no extra tooling (reads sysfs directly)
  - Intel: `intel_gpu_top` and `jq`

If a required tool is missing, that metric's script emits `null` and the
segment is skipped rather than erroring.
