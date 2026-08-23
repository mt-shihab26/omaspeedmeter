# Changelog

All notable changes to this project are documented in this file.

## [1.1.0] - 2026-08-23

### Added

- Swap usage metric (`swap`), reading `/proc/meminfo`
- Right-click the widget to open a system monitor (`btop` by default, or
  `htop`), configurable via the new `systemMonitor` setting

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
