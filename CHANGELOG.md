# Changelog

All notable changes to this project are documented in this file.

## [1.2.0] - 2026-08-24

### Added

- Two-way config file sync at `~/.config/omaspeedmeter/config.json`:
  editing settings in the popup writes the file, and hand-editing the file
  applies live and stays in sync with the popup and `omarchy bar set`

**Full Changelog**: [v1.1.0...v1.2.0](https://github.com/mt-shihab26/omaspeedmeter/compare/v1.1.0...v1.2.0)

## [1.1.0] - 2026-08-23

### Added

- Swap usage metric (`swap`), reading `/proc/meminfo`
- Right-click the widget to open a system monitor (`btop` by default, or
  `htop`), configurable via the new `systemMonitor` setting

**Full Changelog**: [v1.0.0...v1.1.0](https://github.com/mt-shihab26/omaspeedmeter/compare/v1.0.0...v1.1.0)

## [1.0.0] - 2026-08-21

### Added

- CPU, memory, network, temperature, GPU, and process-count bar segments
- Settings popup to toggle metrics, reorder segments, split network into
  download/upload, switch icons for word labels, move the widget between bar
  sections, and change refresh interval, GPU vendor, temperature source, and
  network interface
- Reset button to restore all settings to their defaults
- Per-metric polling scripts in `bin/`, with `Model.js` holding the pure
  settings/formatting/segment-building logic

**Full Changelog**: [v1.0.0](https://github.com/mt-shihab26/omaspeedmeter/commits/v1.0.0)
