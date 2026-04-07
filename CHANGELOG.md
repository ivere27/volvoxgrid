# Changelog

All notable changes to VolvoxGrid are documented here. Per-package changelogs may have additional detail (e.g. [flutter/CHANGELOG.md](flutter/CHANGELOG.md)).

## 0.5.0

- Added Go, `.NET`, and Java TUI terminal hosts with interactive and smoke-test examples.
- Added pull-to-refresh support and moved context menu handling to the app side.
- Expanded subtotal support with `Font`, multi-total fixes, and dropdown/icon behavior fixes.
- Improved auto-resize behavior for row numbers, last-column extension, and default sizing.
- Fixed web stream-dispose behavior and moved demo data out of the core crate.
- Updated Synurang to v0.5.10. Added `.NET` lite codegen support.

## 0.4.0

- Improved rendering performance with GTK/Linux GPU surface work and CPU/GPU scroll blitting.
- Fixed selection, active-cell, IME, checkbox, scrollbar, and progress-bar editing issues.
- Added layering work and expanded ActiveX test coverage.

## 0.3.0

- Redesigned APIs.
- Improved Android GPU support and frame pacing.
- Fixed CPU-mode span and header separator rendering issues.

## 0.2.0

- Canonical APIs.

## 0.1.4

- Added Flutter plugin platform declarations for macOS and Windows.
- Added desktop native resolution from Maven for Linux, macOS, and Windows.
- Added support for `VOLVOXGRID_SOURCE` and `VOLVOXGRID_VERSION` across desktop plugin builds.

## 0.1.3

- Support `VOLVOXGRID_SOURCE`, `VOLVOXGRID_VERSION`, and `VOLVOXGRID_VARIANT` environment variables.
- Support resolving native dependencies from Maven (Local or Central) for Android and Linux.

## 0.1.0

- Initial public release.
- Core engine: retained grid state, layout, selection, editing, sorting, merged cells, rendering.
- Native plugin with Synurang FFI and protobuf-driven API.
- Platform wrappers: Flutter, Android, Java desktop, web/WASM.
- CPU and GPU rendering backends.
