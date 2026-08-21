// Pure helpers for the omaspeedmeter bar widget. Kept dependency-free so they can
// be reasoned about (and unit tested) without a QML/Quickshell runtime.

// Icons come from the Font Awesome + Octicons subsets, which every Nerd
// Font variant bundles (Omarchy ships one as the bar's monospace family),
// so they render the same way the built-in bar icons do.
var METRICS = [  
  { key: "net", label: "NET", icon: "", description: "Download/upload speed" },     // fa-exchange (up/down)
  { key: "cpu", label: "CPU", icon: "", description: "CPU usage percentage" },     // oct-cpu
  { key: "temp", label: "TEMP", icon: "", description: "CPU temperature" },   // fa-thermometer-half
  { key: "mem", label: "MEM", icon: "", description: "Memory usage percentage" },     // fa-memory
  { key: "gpu", label: "GPU", icon: "󰢮", description: "GPU usage percentage" },     // md-expansion_card
  { key: "procs", label: "PROC", icon: "", description: "Running process count" }   // fa-tasks
];


var NET_DOWN_ICON = "" // fa-download
var NET_UP_ICON = ""   // fa-upload

function defaultSettings() {
  return {
    interval: 2,
    gap: 8,
    cpu: true,
    mem: true,
    net: true,
    temp: false,
    gpu: false,
    procs: false,
    labels: false,
    netSplit: false,
    gpuVendor: "auto",
    tempZone: "auto",
    netIface: "auto"
  }
}

function boolSetting(settings, key, fallback) {
  if (!settings || !(key in settings)) return fallback
  var v = settings[key]
  if (typeof v === "boolean") return v
  if (v === "true") return true
  if (v === "false") return false
  return fallback
}

function numberSetting(settings, key, fallback) {
  if (!settings || !(key in settings)) return fallback
  var n = Number(settings[key])
  return isFinite(n) && n >= 0 ? n : fallback
}

function stringSetting(settings, key, fallback) {
  if (!settings || !(key in settings)) return fallback
  var v = settings[key]
  return (typeof v === "string" && v.length > 0) ? v : fallback
}

// `dynamicDefaults` lets the QML layer override a static default with a
// live value it alone has access to — e.g. "gap" falling back to
// Style.spacing.controlGap so the widget tracks the user's Omarchy theme
// instead of a pixel value baked into this file.
function resolvedSettings(settings, dynamicDefaults) {
  var d = defaultSettings()
  for (var dk in (dynamicDefaults || {})) d[dk] = dynamicDefaults[dk]
  var out = {}
  for (var k in d) {
    if (typeof d[k] === "boolean") out[k] = boolSetting(settings, k, d[k])
    else if (typeof d[k] === "number") out[k] = numberSetting(settings, k, d[k])
    else out[k] = stringSetting(settings, k, d[k])
  }
  return out
}

function parseStats(text) {
  try {
    var obj = JSON.parse(String(text || "").trim())
    if (obj && typeof obj === "object") return obj
  } catch (e) {
    // fall through
  }
  return null
}

function formatPct(value) {
  if (value === null || value === undefined) return "N/A"
  var n = Number(value)
  if (!isFinite(n)) return "N/A"
  return Math.round(n) + "%"
}

function formatTemp(value) {
  if (value === null || value === undefined) return "N/A"
  var n = Number(value)
  if (!isFinite(n)) return "N/A"
  return Math.round(n) + "°"
}

// Bytes/sec -> short human string, e.g. 850B/s, 12.3K/s, 4.1M/s
function formatRate(bytesPerSec) {
  var n = Number(bytesPerSec)
  if (!isFinite(n) || n < 0) n = 0
  if (n < 1024) return Math.round(n) + "B/s"
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + "K/s"
  return (n / (1024 * 1024)).toFixed(1) + "M/s"
}

// Builds the ordered list of enabled, renderable segments for the bar row.
// `stats` is the parsed JSON from the polling script (or null before first poll).
// `labels` prefixes each segment with its word label (CPU/MEM/...); off by
// default since the icon already identifies the metric, matching how the
// built-in audio/network/battery widgets work.
function buildSegments(settings, stats) {
  var s = resolvedSettings(settings)
  var labels = s.labels
  var segments = []

  function metric(key) {
    for (var i = 0; i < METRICS.length; i++) if (METRICS[i].key === key) return METRICS[i]
    return null
  }

  function push(key, valueText) {
    var m = metric(key)
    var prefix = labels ? (m.label + " ") : (m.icon + " ")
    segments.push({ key: key, text: prefix + valueText })
  }

  if (s.net) {
    if (s.netSplit) {
      var down = stats ? formatRate(stats.rx) : "…"
      var up = stats ? formatRate(stats.tx) : "…"
      segments.push({ key: "net-down", text: (labels ? "DOWN " : (NET_DOWN_ICON + " ")) + down })
      segments.push({ key: "net-up", text: (labels ? "UP " : (NET_UP_ICON + " ")) + up })
    } else {
      var total = stats ? formatRate((Number(stats.rx) || 0) + (Number(stats.tx) || 0)) : "…"
      push("net", total)
    }
  }
  if (s.cpu) push("cpu", stats ? formatPct(stats.cpu) : "…")
  if (s.temp) push("temp", stats ? formatTemp(stats.temp) : "…")
  if (s.mem) push("mem", stats ? formatPct(stats.mem) : "…")
  if (s.gpu) push("gpu", stats ? formatPct(stats.gpu) : "…")
  if (s.procs) push("procs", stats ? String(stats.procs) : "…")

  return segments
}

// Finds which bar section (left/center/right) a widget currently lives in,
// given the raw JSON text from `omarchy-shell shell listShellConfig`.
// Returns null if the widget isn't placed or the config can't be parsed.
function findSection(configText, moduleName) {
  try {
    var cfg = JSON.parse(String(configText || "").trim())
    var layout = cfg && cfg.bar && cfg.bar.layout
    if (!layout) return null
    var sections = ["left", "center", "right"]
    for (var i = 0; i < sections.length; i++) {
      var arr = layout[sections[i]]
      if (!Array.isArray(arr)) continue
      for (var j = 0; j < arr.length; j++) {
        var entry = arr[j]
        var id = (entry && typeof entry === "object") ? entry.id : entry
        if (id === moduleName) return sections[i]
      }
    }
  } catch (e) {
    // fall through
  }
  return null
}

// Turns `ls /sys/class/net` output into Dropdown options, always leading
// with "auto" (loopback is skipped — never a useful network-speed source).
function parseNetIfaces(text) {
  var out = [{ value: "auto", label: "auto" }]
  var lines = String(text || "").trim().split("\n")
  for (var i = 0; i < lines.length; i++) {
    var name = lines[i].trim()
    if (!name || name === "lo") continue
    out.push({ value: name, label: name })
  }
  return out
}

// Turns "<temp-path>|<zone-type>" lines (one per thermal zone) into Dropdown
// options, always leading with "auto".
function parseTempZones(text) {
  var out = [{ value: "auto", label: "auto" }]
  var lines = String(text || "").trim().split("\n")
  for (var i = 0; i < lines.length; i++) {
    var sep = lines[i].indexOf("|")
    if (sep < 0) continue
    var path = lines[i].slice(0, sep).trim()
    var type = lines[i].slice(sep + 1).trim()
    if (!path) continue
    var zoneName = path.replace("/sys/class/thermal/", "").replace("/temp", "")
    out.push({ value: path, label: (type || zoneName) + " (" + zoneName + ")" })
  }
  return out
}

if (typeof module !== "undefined") {
  module.exports = {
    METRICS: METRICS,
    NET_DOWN_ICON: NET_DOWN_ICON,
    NET_UP_ICON: NET_UP_ICON,
    defaultSettings: defaultSettings,
    boolSetting: boolSetting,
    numberSetting: numberSetting,
    stringSetting: stringSetting,
    resolvedSettings: resolvedSettings,
    parseStats: parseStats,
    formatPct: formatPct,
    formatTemp: formatTemp,
    formatRate: formatRate,
    buildSegments: buildSegments,
    findSection: findSection,
    parseNetIfaces: parseNetIfaces,
    parseTempZones: parseTempZones
  }
}
