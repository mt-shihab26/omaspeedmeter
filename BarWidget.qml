import "Model.js" as Model
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Omaspeedmeter bar widget: CPU / memory / network / temperature / GPU /
// process-count stats in the bar row, with a click popup to toggle each
// metric and tweak the underlying settings (refresh interval, GPU vendor,
// temperature source, network interface).
Panel {
    id: root

    // Omarchy's own bar widgets (WidgetButton) each carry an 8.5px scaled
    // horizontal margin either side; with zero spacing between modules in
    // the bar row, two adjacent widgets end up 17px apart. Using that same
    // raw value here (then run through Style.space() below, same as a
    // user-entered gap) reproduces that spacing and keeps it theme-scaled.
    readonly property var resolved: Model.resolvedSettings(root.settings, {
        "gap": 17
    })
    property var stats: null
    readonly property var segments: Model.buildSegments(root.settings, root.stats)
    // Model.METRICS re-ordered to match the persisted `order` setting, for
    // the popup's METRICS list — kept in sync with root.resolved.order so
    // the move-up/move-down buttons there always reflect the saved order.
    readonly property var orderedMetrics: root.resolved.order.map(function (key) {
        for (var i = 0; i < Model.METRICS.length; i++)
            if (Model.METRICS[i].key === key)
                return Model.METRICS[i];
        return null;
    }).filter(function (m) {
        return m !== null;
    })
    property string currentSection: ""
    property var netIfaceOptions: [
        {
            "value": "auto",
            "label": "auto"
        }
    ]
    property var tempZoneOptions: [
        {
            "value": "auto",
            "label": "auto"
        }
    ]
    // The plugin's own directory, so the polling script can be found no
    // matter where this plugin checkout/symlink lives.
    readonly property string pluginDir: {
        var u = Qt.resolvedUrl(".").toString();
        return u.indexOf("file://") === 0 ? u.substring(7) : u;
    }

    // Merges a single metric script's JSON output into root.stats, creating
    // the object on first arrival. Reassigns (rather than mutates) so the
    // `segments` binding above picks up the change.
    function mergeStats(patch) {
        var merged = {};
        for (var k in root.stats)
            merged[k] = root.stats[k];
        for (var k2 in patch)
            merged[k2] = patch[k2];
        root.stats = merged;
    }

    function refresh() {
        if (root.resolved.cpu && !cpuProc.running)
            cpuProc.running = true;

        if (root.resolved.mem && !memProc.running)
            memProc.running = true;

        if (root.resolved.net && !netProc.running)
            netProc.running = true;

        if (root.resolved.temp && !tempProc.running)
            tempProc.running = true;

        if (root.resolved.gpu && !gpuProc.running)
            gpuProc.running = true;

        if (root.resolved.procs && !procsProc.running)
            procsProc.running = true;
    }

    // Queued rather than fired directly at setSettingProc: resetSettings()
    // below calls this once per setting in the same tick, and reassigning
    // `command`/`running` on an already-running Process drops everything
    // but the first call, since `running = true` is a no-op when it's
    // already true.
    property var settingQueue: []

    function setSetting(key, value, isJson) {
        var args = ["bar", "set", root.moduleName, key, String(value)];
        if (isJson)
            args.push("--json");

        root.settingQueue.push(["omarchy"].concat(args));
        root.pumpSettingQueue();
    }

    function pumpSettingQueue() {
        if (setSettingProc.running || root.settingQueue.length === 0)
            return;

        setSettingProc.command = root.settingQueue.shift();
        setSettingProc.running = true;
    }

    function toggleMetric(key) {
        root.setSetting(key, !root.resolved[key], true);
    }

    // Swaps `key` with its neighbor one step toward `direction` (-1 = up,
    // +1 = down) in the metric order and persists the result. Operates on
    // the full metric list (root.resolved.order), not just enabled ones, so
    // the popup's METRICS list stays reorderable regardless of what's shown.
    function moveMetric(key, direction) {
        var order = root.resolved.order.slice();
        var from = order.indexOf(key);
        var to = from + direction;
        if (from === -1 || to < 0 || to >= order.length)
            return;

        var tmp = order[to];
        order[to] = order[from];
        order[from] = tmp;

        root.setSetting("order", order.join(","), false);
    }

    // Restores every setting (toggles, netSplit, labels, interval, gap,
    // gpuVendor, netIface, tempZone, segment order) to its manifest default.
    function resetSettings() {
        var defaults = Model.defaultSettings();
        for (var key in defaults) {
            var value = defaults[key];
            if (key === "order")
                root.setSetting(key, value.join(","), false);
            else if (typeof value === "boolean" || typeof value === "number")
                root.setSetting(key, value, true);
            else
                root.setSetting(key, value, false);
        }
    }

    function refreshSection() {
        if (!sectionProc.running)
            sectionProc.running = true;
    }

    function setSection(section) {
        root.currentSection = section;
        moveSectionProc.command = ["omarchy", "bar", "move", root.moduleName, "--section", section];
        moveSectionProc.running = true;
    }

    moduleName: "mt-shihab26.omaspeedmeter"
    ipcTarget: moduleName
    implicitWidth: row.implicitWidth + Style.space(16)
    implicitHeight: bar ? bar.barSize : 26
    onOpenedChanged: {
        if (!opened)
            return;

        root.refreshSection();
        if (!netIfacesProc.running)
            netIfacesProc.running = true;

        if (!tempZonesProc.running)
            tempZonesProc.running = true;
    }
    Component.onCompleted: refresh()

    Process {
        id: setSettingProc

        stdout: StdioCollector {
            waitForEnd: true
        }
        onExited: root.pumpSettingQueue()
    }

    Process {
        id: sectionProc

        command: ["omarchy-shell", "shell", "listShellConfig"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.currentSection = Model.findSection(text, root.moduleName) || root.currentSection
        }
    }

    Process {
        id: moveSectionProc

        stdout: StdioCollector {
            waitForEnd: true
        }
    }

    Process {
        id: netIfacesProc

        command: ["bash", "-c", "ls /sys/class/net 2>/dev/null"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.netIfaceOptions = Model.parseNetIfaces(text)
        }
    }

    Process {
        id: tempZonesProc

        command: ["bash", "-c", "for f in /sys/class/thermal/thermal_zone*/type; do p=\"${f%/type}/temp\"; echo \"$p|$(cat \"$f\" 2>/dev/null)\"; done 2>/dev/null"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.tempZoneOptions = Model.parseTempZones(text)
        }
    }

    Timer {
        interval: Math.max(1, root.resolved.interval) * 1000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    Process {
        id: cpuProc

        command: [root.pluginDir + "bin/omaspeedmeter-cpu"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.mergeStats(Model.parseStats(text) || {})
        }
    }

    Process {
        id: memProc

        command: [root.pluginDir + "bin/omaspeedmeter-mem"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.mergeStats(Model.parseStats(text) || {})
        }
    }

    Process {
        id: netProc

        command: [root.pluginDir + "bin/omaspeedmeter-net", "--iface", root.resolved.netIface]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.mergeStats(Model.parseStats(text) || {})
        }
    }

    Process {
        id: tempProc

        command: [root.pluginDir + "bin/omaspeedmeter-temp", "--zone", root.resolved.tempZone]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.mergeStats(Model.parseStats(text) || {})
        }
    }

    Process {
        id: gpuProc

        command: [root.pluginDir + "bin/omaspeedmeter-gpu", "--vendor", root.resolved.gpuVendor]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.mergeStats(Model.parseStats(text) || {})
        }
    }

    Process {
        id: procsProc

        command: [root.pluginDir + "bin/omaspeedmeter-procs"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.mergeStats(Model.parseStats(text) || {})
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Style.space(root.resolved.gap)

        Repeater {
            model: root.segments

            Text {
                required property var modelData

                text: modelData.text
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
            }
        }

        // Shown when every metric is disabled, so the widget stays clickable
        // instead of collapsing to nothing.
        Text {
            visible: root.segments.length === 0
            text: "omaspeedmeter"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }

    KeyboardPanel {
        id: panel

        anchorItem: root
        owner: root
        bar: root.bar
        open: root.opened
        // Same fittedContentWidth pattern Omarchy's own panels use (e.g. the
        // agents/AI widget's KeyboardPanel) — fixed at 360 in practice, only
        // capped down on a screen too narrow to fit it.
        contentWidth: panel.fittedContentWidth(Style.space(360))
        contentHeight: panel.fittedContentHeight(settingsColumn.implicitHeight, Style.space(480))

        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: settingsColumn

                width: parent.width
                spacing: Style.space(10)

                Item {
                    width: settingsColumn.width
                    height: titleText.implicitHeight

                    Text {
                        id: titleText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Omaspeedmeter"
                        color: root.bar ? root.bar.foreground : Color.foreground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.title
                        font.bold: true
                    }

                    PanelActionButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        iconText: "↺"
                        tooltipText: "Reset all settings to default"
                        foreground: root.bar ? root.bar.foreground : Color.foreground
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        onClicked: root.resetSettings()
                    }
                }

                PanelSeparator {
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                }

                PanelSectionHeader {
                    text: "METRICS"
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                }

                Repeater {
                    model: root.orderedMetrics

                    Row {
                        id: metricRow

                        required property var modelData
                        required property int index

                        width: settingsColumn.width
                        spacing: Style.space(4)

                        Toggle {
                            width: metricRow.width - upBtn.width - downBtn.width - metricRow.spacing * 2
                            label: metricRow.modelData.icon + "  " + metricRow.modelData.label
                            description: metricRow.modelData.description || ""
                            checked: root.resolved[metricRow.modelData.key] === true
                            foreground: root.bar ? root.bar.foreground : Color.foreground
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                            onClicked: root.toggleMetric(metricRow.modelData.key)
                        }

                        PanelActionButton {
                            id: upBtn

                            anchors.verticalCenter: parent.verticalCenter
                            iconText: "▲"
                            tooltipText: "Move up"
                            foreground: root.bar ? root.bar.foreground : Color.foreground
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                            enabled: metricRow.index > 0
                            onClicked: root.moveMetric(metricRow.modelData.key, -1)
                        }

                        PanelActionButton {
                            id: downBtn

                            anchors.verticalCenter: parent.verticalCenter
                            iconText: "▼"
                            tooltipText: "Move down"
                            foreground: root.bar ? root.bar.foreground : Color.foreground
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                            enabled: metricRow.index < root.orderedMetrics.length - 1
                            onClicked: root.moveMetric(metricRow.modelData.key, 1)
                        }
                    }
                }

                Toggle {
                    width: settingsColumn.width
                    label: "Split network up/down"
                    description: "Separate download and upload"
                    checked: root.resolved.netSplit === true
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    onClicked: root.toggleMetric("netSplit")
                }

                Toggle {
                    width: settingsColumn.width
                    label: "Show word labels"
                    description: "Show label instead of icon"
                    checked: root.resolved.labels === true
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    onClicked: root.toggleMetric("labels")
                }

                PanelSeparator {
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                }

                PanelSectionHeader {
                    text: "SETTINGS"
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                }

                Column {
                    width: settingsColumn.width
                    spacing: Style.space(4)

                    Text {
                        text: "Bar position"
                        color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                    }

                    ButtonGroup {
                        options: ["left", "center", "right"]
                        value: root.currentSection
                        foreground: root.bar ? root.bar.foreground : Color.foreground
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        onChanged: function (v) {
                            root.setSection(v);
                        }
                    }
                }

                NumberField {
                    label: "Refresh interval (seconds)"
                    value: root.resolved.interval
                    from: 1
                    to: 60
                    stepSize: 1
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    onModified: function (v) {
                        root.setSetting("interval", v, true);
                    }
                }

                NumberField {
                    label: "Segment spacing (pixels)"
                    value: root.resolved.gap
                    from: 0
                    to: 40
                    stepSize: 1
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    onModified: function (v) {
                        root.setSetting("gap", v, true);
                    }
                }

                Dropdown {
                    label: "GPU vendor"
                    width: settingsColumn.width
                    value: root.resolved.gpuVendor
                    options: ["auto", "nvidia", "amd", "intel", "none"]
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    onChanged: function (v) {
                        root.setSetting("gpuVendor", v, false);
                    }
                }

                Dropdown {
                    label: "Network interface"
                    width: settingsColumn.width
                    value: root.resolved.netIface
                    options: root.netIfaceOptions
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    onChanged: function (v) {
                        root.setSetting("netIface", v, false);
                    }
                }

                Dropdown {
                    label: "Temperature source"
                    width: settingsColumn.width
                    value: root.resolved.tempZone
                    options: root.tempZoneOptions
                    foreground: root.bar ? root.bar.foreground : Color.foreground
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    onChanged: function (v) {
                        root.setSetting("tempZone", v, false);
                    }
                }

                Item {
                    width: 1
                    height: Style.space(4)
                }
            }
        }
    }
}
