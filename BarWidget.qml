import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// System Monitor bar widget: CPU / memory / network / temperature / GPU /
// process-count stats in the bar row, with a click popup to toggle each
// metric and tweak the underlying settings (refresh interval, GPU vendor,
// temperature source, network interface).
Panel {
  id: root
  moduleName: "shihab.sysmon"
  ipcTarget: moduleName

  readonly property var resolved: Model.resolvedSettings(root.settings)
  property var stats: null
  readonly property var segments: Model.buildSegments(root.settings, root.stats)

  // The plugin's own directory, so the polling script can be found no
  // matter where this plugin checkout/symlink lives.
  readonly property string pluginDir: {
    var u = Qt.resolvedUrl(".").toString()
    return u.indexOf("file://") === 0 ? u.substring(7) : u
  }

  implicitWidth: row.implicitWidth + Style.space(16)
  implicitHeight: bar ? bar.barSize : 26

  function refresh() {
    if (!statsProc.running) statsProc.running = true
  }

  function setSetting(key, value, isJson) {
    var args = ["bar", "set", root.moduleName, key, String(value)]
    if (isJson) args.push("--json")
    setSettingProc.command = ["omarchy"].concat(args)
    setSettingProc.running = true
  }

  Process {
    id: setSettingProc
    stdout: StdioCollector { waitForEnd: true }
  }

  function toggleMetric(key) {
    root.setSetting(key, !root.resolved[key], true)
  }

  Component.onCompleted: refresh()

  Timer {
    interval: Math.max(1, root.resolved.interval) * 1000
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.refresh()
  }

  Process {
    id: statsProc
    command: [
      root.pluginDir + "bin/omarchy-sysmon-stats",
      "--gpu-vendor", root.resolved.gpuVendor,
      "--temp-zone", root.resolved.tempZone,
      "--net-iface", root.resolved.netIface
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.stats = Model.parseStats(text)
    }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(10)

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
      text: "sysmon"
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
    contentWidth: panel.fittedContentWidth(Style.space(320))
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

        Text {
          text: "System Monitor"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
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
          model: Model.METRICS

          Toggle {
            required property var modelData
            width: settingsColumn.width
            label: modelData.icon + "  " + modelData.label
            checked: root.resolved[modelData.key] === true
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onClicked: root.toggleMetric(modelData.key)
          }
        }

        Toggle {
          width: settingsColumn.width
          label: "Split network up/down"
          description: "Show download and upload as two separate segments instead of one combined \"↓ ↑\" segment"
          checked: root.resolved.netSplit === true
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: root.toggleMetric("netSplit")
        }

        Toggle {
          width: settingsColumn.width
          label: "Show word labels"
          description: "e.g. \"CPU 12%\" instead of just the icon + value"
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

        NumberField {
          label: "Refresh interval (seconds)"
          value: root.resolved.interval
          from: 1
          to: 60
          stepSize: 1
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onModified: function(v) { root.setSetting("interval", v, true) }
        }

        Dropdown {
          label: "GPU vendor"
          width: settingsColumn.width
          value: root.resolved.gpuVendor
          options: ["auto", "nvidia", "amd", "intel", "none"]
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onChanged: function(v) { root.setSetting("gpuVendor", v, false) }
        }

        Column {
          width: settingsColumn.width
          spacing: Style.space(4)

          Text {
            text: "Network interface"
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }

          TextField {
            id: ifaceField
            width: parent.width
            text: root.resolved.netIface
            placeholderText: "auto"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            onEditingFinished: root.setSetting("netIface", ifaceField.text.trim() || "auto", false)
          }
        }

        Column {
          width: settingsColumn.width
          spacing: Style.space(4)

          Text {
            text: "Temperature source"
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }

          Text {
            text: "auto, or a /sys/class/thermal/thermal_zoneN/temp path"
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            width: parent.width
          }

          TextField {
            id: tempField
            width: parent.width
            text: root.resolved.tempZone
            placeholderText: "auto"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            onEditingFinished: root.setSetting("tempZone", tempField.text.trim() || "auto", false)
          }
        }

        Item { width: 1; height: Style.space(4) }
      }
    }
  }
}
