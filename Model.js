// Pure helpers for the omaspeedmeter bar widget. Kept dependency-free so they can
// be reasoned about (and unit tested) without a QML/Quickshell runtime.

// Icons come from the Font Awesome + Octicons subsets, which every Nerd
// Font variant bundles (Omarchy ships one as the bar's monospace family),
// so they render the same way the built-in bar icons do.
var METRICS = [
    {
        key: "net",
        label: "NET",
        icon: "", // fa-exchange (up/down)
        description: "Download/upload speed",
    },
    {
        key: "cpu",
        label: "CPU",
        icon: "", // oct-cpu
        description: "CPU usage percentage",
    },
    {
        key: "temp",
        label: "TEMP",
        icon: "", // fa-thermometer-half
        description: "CPU temperature",
    },
    {
        key: "mem",
        label: "MEM",
        icon: "", // fa-memory
        description: "Memory usage percentage",
    },
    {
        key: "swap",
        label: "SWAP",
        icon: "", // fa-hdd-o
        description: "Swap usage percentage",
    },
    {
        key: "gpu",
        label: "GPU",
        icon: "󰢮", // md-expansion_card
        description: "GPU usage percentage",
    },
    {
        key: "procs",
        label: "PROC",
        icon: "", // fa-tasks
        description: "Running process count",
    },
];

var NET_DOWN_ICON = ""; // fa-download
var NET_UP_ICON = ""; // fa-upload
var PLACEHOLDER = "…"; // shown while a metric's value hasn't arrived yet

function defaultSettings() {
    return {
        interval: 2,
        gap: 17,
        cpu: true,
        mem: true,
        swap: false,
        net: true,
        temp: false,
        gpu: false,
        procs: false,
        labels: false,
        netSplit: false,
        gpuVendor: "auto",
        tempZone: "auto",
        netIface: "auto",
        systemMonitor: "btop",
        order: METRICS.map(function (m) {
            return m.key;
        }),
    };
}

function boolSetting(settings, key, fallback) {
    if (!settings || !(key in settings)) return fallback;
    var v = settings[key];
    if (typeof v === "boolean") return v;
    if (v === "true") return true;
    if (v === "false") return false;
    return fallback;
}

function numberSetting(settings, key, fallback) {
    if (!settings || !(key in settings)) return fallback;
    var n = Number(settings[key]);
    return isFinite(n) && n >= 0 ? n : fallback;
}

function stringSetting(settings, key, fallback) {
    if (!settings || !(key in settings)) return fallback;
    var v = settings[key];
    return typeof v === "string" && v.length > 0 ? v : fallback;
}

// Stored as a plain comma-joined string (e.g. "net,cpu,mem"), not JSON —
// `omarchy bar set --json` passes the raw value through Quickshell's `qs ipc
// call`, which mis-splits a bracketed array literal into extra arguments
// instead of treating it as one string.
function arraySetting(settings, key, fallback) {
    if (!settings || !(key in settings)) return fallback;
    var v = settings[key];
    if (Array.isArray(v)) return v;
    if (typeof v === "string" && v.length > 0) return v.split(",");
    return fallback;
}

// Keeps every valid key exactly once, in the order given, then appends any
// valid key missing from `order` (e.g. a metric added after the user's
// stored order was last saved) so nothing drops out of the segment list.
function sanitizeOrder(order, validKeys) {
    var seen = {};
    var result = [];
    for (var i = 0; i < order.length; i++) {
        var k = order[i];
        if (validKeys.indexOf(k) !== -1 && !seen[k]) {
            seen[k] = true;
            result.push(k);
        }
    }
    for (var j = 0; j < validKeys.length; j++) {
        if (!seen[validKeys[j]]) result.push(validKeys[j]);
    }
    return result;
}

// `dynamicDefaults` lets the QML layer override a static default with a
// live value it alone has access to — e.g. "gap" falling back to
// Style.spacing.controlGap so the widget tracks the user's Omarchy theme
// instead of a pixel value baked into this file.
function resolvedSettings(settings, dynamicDefaults) {
    var d = defaultSettings();
    for (var dk in dynamicDefaults || {}) d[dk] = dynamicDefaults[dk];
    var out = {};
    for (var k in d) {
        if (k === "order")
            out[k] = sanitizeOrder(
                arraySetting(settings, k, d[k]),
                METRICS.map(function (m) {
                    return m.key;
                }),
            );
        else if (typeof d[k] === "boolean")
            out[k] = boolSetting(settings, k, d[k]);
        else if (typeof d[k] === "number")
            out[k] = numberSetting(settings, k, d[k]);
        else out[k] = stringSetting(settings, k, d[k]);
    }
    return out;
}

function parseStats(text) {
    try {
        var obj = JSON.parse(String(text || "").trim());
        if (obj && typeof obj === "object") return obj;
    } catch (e) {
        // fall through
    }
    return null;
}

// Same shape as parseStats (JSON.parse + trim + try/catch -> null on
// failure), named separately since it parses ~/.config/omaspeedmeter's
// config file rather than a polling script's stats output.
function parseConfigFile(text) {
    try {
        var obj = JSON.parse(String(text || "").trim());
        if (obj && typeof obj === "object") return obj;
    } catch (e) {
        // fall through
    }
    return null;
}

function formatPct(value) {
    if (value === null || value === undefined) return PLACEHOLDER;
    var n = Number(value);
    if (!isFinite(n)) return PLACEHOLDER;
    return Math.round(n) + "%";
}

function formatTemp(value) {
    if (value === null || value === undefined) return PLACEHOLDER;
    var n = Number(value);
    if (!isFinite(n)) return PLACEHOLDER;
    return Math.round(n) + "°";
}

function formatCount(value) {
    if (value === null || value === undefined) return PLACEHOLDER;
    var n = Number(value);
    if (!isFinite(n)) return PLACEHOLDER;
    return String(Math.round(n));
}

// Bytes/sec -> short human string, e.g. 850B/s, 12.3K/s, 4.1M/s
function formatRate(bytesPerSec) {
    var n = Number(bytesPerSec);
    if (!isFinite(n) || n < 0) n = 0;
    if (n < 1024) return Math.round(n) + "B/s";
    if (n < 1024 * 1024) return (n / 1024).toFixed(1) + "K/s";
    return (n / (1024 * 1024)).toFixed(1) + "M/s";
}

// Builds the ordered list of enabled, renderable segments for the bar row.
// `stats` is the parsed JSON from the polling script (or null before first poll).
// `labels` prefixes each segment with its word label (CPU/MEM/...); off by
// default since the icon already identifies the metric, matching how the
// built-in audio/network/battery widgets work.
function buildSegments(settings, stats) {
    var s = resolvedSettings(settings);
    var labels = s.labels;
    var segments = [];

    function metric(key) {
        for (var i = 0; i < METRICS.length; i++)
            if (METRICS[i].key === key) return METRICS[i];
        return null;
    }

    function push(key, valueText) {
        var m = metric(key);
        var prefix = labels ? m.label + " " : m.icon + " ";
        segments.push({ key: key, text: prefix + valueText });
    }

    var builders = {
        net: function () {
            if (!s.net) return;
            if (s.netSplit) {
                var down = stats ? formatRate(stats.rx) : PLACEHOLDER;
                var up = stats ? formatRate(stats.tx) : PLACEHOLDER;
                segments.push({
                    key: "net-down",
                    text: (labels ? "DOWN " : NET_DOWN_ICON + " ") + down,
                });
                segments.push({
                    key: "net-up",
                    text: (labels ? "UP " : NET_UP_ICON + " ") + up,
                });
            } else {
                var total = stats
                    ? formatRate(
                          (Number(stats.rx) || 0) + (Number(stats.tx) || 0),
                      )
                    : PLACEHOLDER;
                push("net", total);
            }
        },
        cpu: function () {
            if (s.cpu) push("cpu", stats ? formatPct(stats.cpu) : PLACEHOLDER);
        },
        temp: function () {
            if (s.temp)
                push("temp", stats ? formatTemp(stats.temp) : PLACEHOLDER);
        },
        mem: function () {
            if (s.mem) push("mem", stats ? formatPct(stats.mem) : PLACEHOLDER);
        },
        swap: function () {
            if (s.swap)
                push("swap", stats ? formatPct(stats.swap) : PLACEHOLDER);
        },
        gpu: function () {
            if (s.gpu) push("gpu", stats ? formatPct(stats.gpu) : PLACEHOLDER);
        },
        procs: function () {
            if (s.procs)
                push("procs", stats ? formatCount(stats.procs) : PLACEHOLDER);
        },
    };

    for (var i = 0; i < s.order.length; i++) {
        var build = builders[s.order[i]];
        if (build) build();
    }

    return segments;
}

// Finds which bar section (left/center/right) a widget currently lives in,
// given the raw JSON text from `omarchy-shell shell listShellConfig`.
// Returns null if the widget isn't placed or the config can't be parsed.
function findSection(configText, moduleName) {
    try {
        var cfg = JSON.parse(String(configText || "").trim());
        var layout = cfg && cfg.bar && cfg.bar.layout;
        if (!layout) return null;
        var sections = ["left", "center", "right"];
        for (var i = 0; i < sections.length; i++) {
            var arr = layout[sections[i]];
            if (!Array.isArray(arr)) continue;
            for (var j = 0; j < arr.length; j++) {
                var entry = arr[j];
                var id = entry && typeof entry === "object" ? entry.id : entry;
                if (id === moduleName) return sections[i];
            }
        }
    } catch (e) {
        // fall through
    }
    return null;
}

// Turns `ls /sys/class/net` output into Dropdown options, always leading
// with "auto" (loopback is skipped — never a useful network-speed source).
function parseNetIfaces(text) {
    var out = [{ value: "auto", label: "auto" }];
    var lines = String(text || "")
        .trim()
        .split("\n");
    for (var i = 0; i < lines.length; i++) {
        var name = lines[i].trim();
        if (!name || name === "lo") continue;
        out.push({ value: name, label: name });
    }
    return out;
}

// Turns "<temp-path>|<zone-type>" lines (one per thermal zone) into Dropdown
// options, always leading with "auto".
function parseTempZones(text) {
    var out = [{ value: "auto", label: "auto" }];
    var lines = String(text || "")
        .trim()
        .split("\n");
    for (var i = 0; i < lines.length; i++) {
        var sep = lines[i].indexOf("|");
        if (sep < 0) continue;
        var path = lines[i].slice(0, sep).trim();
        var type = lines[i].slice(sep + 1).trim();
        if (!path) continue;
        var zoneName = path
            .replace("/sys/class/thermal/", "")
            .replace("/temp", "");
        out.push({
            value: path,
            label: (type || zoneName) + " (" + zoneName + ")",
        });
    }
    return out;
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
        arraySetting: arraySetting,
        sanitizeOrder: sanitizeOrder,
        resolvedSettings: resolvedSettings,
        parseStats: parseStats,
        parseConfigFile: parseConfigFile,
        formatPct: formatPct,
        formatTemp: formatTemp,
        formatCount: formatCount,
        formatRate: formatRate,
        buildSegments: buildSegments,
        findSection: findSection,
        parseNetIfaces: parseNetIfaces,
        parseTempZones: parseTempZones,
    };
}
