# Changelog

All notable changes to VolvoxGrid are documented here. Per-package changelogs may have additional detail (e.g. [flutter/CHANGELOG.md](flutter/CHANGELOG.md)).

## 0.8.1

- Refined barcode defaults: QR uses the default text path, while Code 128 plain text stays the default and GS1 inserts FNC1.
- Added QR ECC metadata to the shared barcode fixture and wired the web/GTK demos to use it.
- Fixed the GTK release build by migrating demo dropdown columns to the current `Dropdown` field.

## 0.8.0

- Added 1D and 2D barcode support.
- Added aggregate APIs for range, count-all, median, and count-distinct.
- Added custom sort support, schema responses, row status, and span compare modes.
- Added dropdown lifecycle APIs with `BeforeDropdownOpen`, dropdown messages, and `EventDecision` handling for all before-events.
- Cleaned up protocol compatibility with `*_UNSPECIFIED = 0` enum values and removal of `GridHandle`.
- Refactored plugin event streaming to an event-driven flow and fixed Java `RenderLayerBit` handling.

## 0.7.1

- Removed the shared `Empty` response from the API and added explicit response types for mutating RPCs.
- Added operation summaries to row, selection, scroll, merge, clear, and viewport responses.
- Regenerated Flutter, Go, Java, Web, .NET, plugin, and ActiveX bindings for the updated protocol.

## 0.7.0

- Version bump for project-wide 0.7.0 release.

## 0.6.0

- Added TUI (terminal) rendering: Go, `.NET`, and Java terminal hosts with interactive and smoke-test examples.
- Reorganized README and added GUI.md, TUI.md, and per-language READMEs.

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
