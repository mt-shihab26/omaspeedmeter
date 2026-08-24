# File-based config sync (`~/.config/omaspeedmeter/config.json`)

## Context

Right now every setting is persisted only through Omarchy's own mechanism:
the popup calls `omarchy bar set <module> <key> <value>`, which round-trips
through Quickshell IPC into the shell's `shellConfig` and gets written to
`~/.config/omarchy/shell.json`. There's no way for a user to hand-edit a
plain config file for this plugin, and no file a user could version-control
or template across machines.

The ask: add `~/.config/omaspeedmeter/config.json`, hand-editable, that
stays in sync **both ways** with the popup — popup changes write to it, and
editing it externally is picked up live and reflected in the widget/popup,
while `omarchy bar set` keeps working exactly as it does today (confirmed via
research that no other part of Omarchy reads `manifest.json`'s `schema` for
a generic settings UI — `schema` is documentation-only — so there's no third
system to keep in sync with).

## Design

**One writer path, one reader path — both driven off existing reactive state,
not scattered across every popup handler.**

- `root.resolved` (already a live QML binding derived from `root.settings`,
  which Omarchy keeps current via IPC) and `root.currentSection` are the
  single in-memory source of "current settings." Any time either changes —
  whether from a popup click *or* from us relaying an external file edit
  through `omarchy bar set` — a debounced write serializes them to
  `config.json`. This means **zero changes** are needed to `toggleMetric`,
  `moveMetric`, `setSetting`, `resetSettings`, or `setSection` — they already
  mutate `root.settings`/`root.currentSection` indirectly via `omarchy bar
  set`/`omarchy bar move`, and the file-write just listens for that.
- A `FileView` watches `config.json`. On external change, it diffs the
  parsed JSON against `root.resolved`/`root.currentSection` and calls the
  existing `root.setSetting()`/`root.setSection()` for every differing key —
  so an external edit flows through the exact same path a popup click would,
  keeping Omarchy's own `shell.json` in sync too.
- A `lastSyncedConfigText` guard skips reconciling text we just wrote
  ourselves (self-echo from our own `setText()` triggering `onFileChanged`),
  the same idempotent-reload pattern already used in `shell.qml`.

## Changes

### `Model.js`

- Add `parseConfigFile(text)` — same shape as the existing `parseStats`
  (`JSON.parse` + trim + try/catch → `null` on failure) but named for this
  use, so config-parsing isn't semantically borrowing the stats-parsing
  helper. Export it alongside the others.

### `BarWidget.qml`

Add near the top, alongside the existing `pluginDir`/`resolved` properties:

```qml
readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omaspeedmeter"
readonly property string configPath: root.configDir + "/config.json"
property string lastSyncedConfigText: ""
```

New functions:

- `writeConfigFile()` — builds `{ ...Model.defaultSettings() keys from root.resolved, section: root.currentSection }`, `JSON.stringify(..., null, 4) + "\n"`; no-ops if it matches `lastSyncedConfigText`; else updates the guard and calls `configFile.setText(...)`.
- `applyConfigFromFile(parsed)` — for each key in `Model.defaultSettings()` present in `parsed` and differing from `root.resolved[key]`, calls `root.setSetting(key, value, isJson)` (reusing the existing queue — no new Process plumbing); `order` is validated via `Model.sanitizeOrder` and compared/set as the comma-joined string `setSetting` already expects; `section` (if a valid `left`/`center`/`right`) calls `root.setSection(value)` when it differs from `root.currentSection`.
- `reconcileConfigFile(text)` — skip if `text === lastSyncedConfigText`; else `Model.parseConfigFile(text)`, call `applyConfigFromFile`, update the guard.

New `Process` (mirrors the `mkdir -p` pattern in Omarchy's own
`notifications/Service.qml`) to ensure the directory exists, since `FileView`
doesn't create parent directories itself:

```qml
Process {
    id: ensureConfigDirProc
    command: ["mkdir", "-p", root.configDir]
    onExited: configFile.reload()
}
```

New `FileView`:

```qml
FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.reconcileConfigFile(text())
    onLoadFailed: function (error) { root.writeConfigFile() }
    onFileChanged: reload()
}
```

Debounced writer, reacting to the same state the popup already mutates:

```qml
Timer {
    id: configWriteDebounce
    interval: 200
    onTriggered: root.writeConfigFile()
}

onResolvedChanged: configWriteDebounce.restart()
onCurrentSectionChanged: configWriteDebounce.restart()
```

`Component.onCompleted` currently only calls `refresh()` (stats polling).
Add `refreshSection()` there too, so `root.currentSection` (currently only
populated when the popup is first opened) is known at startup and the
initial `config.json` seed includes the real bar position instead of `""`.
Also kick off `ensureConfigDirProc.running = true` there.

### `manifest.json` / `README.md`

- README: new subsection under **Settings** documenting
  `~/.config/omaspeedmeter/config.json` — the exact JSON shape (mirrors
  `defaultSettings()` plus `section`), that it's hand-editable and changes
  apply live, and that it stays in sync with the popup / `omarchy bar set`
  either direction.
- No manifest.json changes needed — `schema`/`defaults` there stay as the
  existing Omarchy-facing contract; the config file is an additional layer
  on top, not a replacement.

## Verification

- `qmllint -I /home/shihab/projects/omarchy/shell BarWidget.qml` — must stay clean, as it did for every prior change in this repo.
- Manual `node -e` sanity check of `Model.parseConfigFile` (mirrors how `parseStats`/`buildSegments` were exercised earlier in this session) for valid JSON, invalid JSON, and missing-file-text (`""`) cases.
- Since there's no running Quickshell/Omarchy environment available here to actually launch the widget, note explicitly in the final report that the FileView/Process wiring is verified by lint + code review + the same patterns already proven elsewhere in the Omarchy shell source, not by an end-to-end manual test — flag this limitation rather than claiming it was clicked through.
