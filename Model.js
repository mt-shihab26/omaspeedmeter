// Pure helpers for the sysmon bar widget. Kept dependency-free so they can
// be reasoned about (and unit tested) without a QML/Quickshell runtime.

// Icons come from the Font Awesome + Octicons subsets, which every Nerd
// Font variant bundles (Omarchy ships one as the bar's monospace family),
// so they render the same way the built-in bar icons do.
var METRICS = [  
  { key: "cpu", label: "CPU", icon: "" },     // oct-cpu
  { key: "mem", label: "MEM", icon: "" },     // fa-memory
  { key: "net", label: "NET", icon: "" },     // fa-exchange (up/down)
  { key: "temp", label: "TEMP", icon: "" },   // fa-thermometer-half
  { key: "gpu", label: "GPU", icon: "" },     // fa-microchip
  { key: "procs", label: "PROC", icon: "" }   // fa-tasks
];


var NET_DOWN_ICON = "" // fa-download
var NET_UP_ICON = ""   // fa-upload

function defaultSettings() {
  return {
    interval: 2,
    cpu: true,
    mem: true,
    net: true,
    temp: true,
    gpu: true,
    procs: false,
    labels: false,
    netSplit: true,
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
  return isFinite(n) && n > 0 ? n : fallback
}

function stringSetting(settings, key, fallback) {
  if (!settings || !(key in settings)) return fallback
  var v = settings[key]
  return (typeof v === "string" && v.length > 0) ? v : fallback
}

function resolvedSettings(settings) {
  var d = defaultSettings()
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
    var prefix = m.icon + " " + (labels ? m.label + " " : "")
    segments.push({ key: key, text: prefix + valueText })
  }

  if (s.cpu) push("cpu", stats ? formatPct(stats.cpu) : "…")
  if (s.mem) push("mem", stats ? formatPct(stats.mem) : "…")
  if (s.net) {
    var down = stats ? formatRate(stats.rx) : "…"
    var up = stats ? formatRate(stats.tx) : "…"
    var netLabel = labels ? "NET " : ""
    if (s.netSplit) {
      segments.push({ key: "net-down", text: (labels ? "DOWN " : "") + NET_DOWN_ICON + " " + down })
      segments.push({ key: "net-up", text: (labels ? "UP " : "") + NET_UP_ICON + " " + up })
    } else {
      segments.push({ key: "net", text: netLabel + NET_DOWN_ICON + " " + down + "  " + NET_UP_ICON + " " + up })
    }
  }
  if (s.temp) push("temp", stats ? formatTemp(stats.temp) : "…")
  if (s.gpu) push("gpu", stats ? formatPct(stats.gpu) : "…")
  if (s.procs) push("procs", stats ? String(stats.procs) : "…")

  return segments
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
    buildSegments: buildSegments
  }
}
