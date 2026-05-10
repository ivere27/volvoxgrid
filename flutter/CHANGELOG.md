# Changelog

## 0.8.8

- Added `VOLVOXGRID_VARIANT=lite` documentation and iOS podspec support for `VolvoxGridLite.xcframework`.
- Regenerated protocol bindings for rich-text cells, text baselines, and explicit GPU renderer modes.
- Added `includeRichText` to `VolvoxGridController.getCells`.

## 0.8.7

- Added the `VolvoxDataGrid` helper API and refreshed package docs for Maven-backed native binary resolution.
- Synced wrapper cursor handling and checkbox interaction fixes with the runtime changes.

## 0.8.6

- Regenerated Flutter protocol bindings for the new semantic `CursorType` enum.

## 0.8.5

- Switched desktop and mobile native loading from the old plugin library name to the shared `volvoxgrid` runtime library.
- Synced Flutter documentation, generated comments, and package defaults with the runtime/library layout.

## 0.8.3

- Regenerated Flutter protocol bindings for tree events, slot-based row/corner indicators, indicator appearance controls, event target metadata, and configurable decision/compare timeouts.
- Updated `VolvoxGridController` row-indicator helpers to emit indicator slots instead of the removed row-indicator mode bit field.
- Refreshed the hierarchy example to derive tree levels from parent IDs, hide the label source column, and render outline expanders plus corner level buttons through indicators.
- Added `onBeforeDropdownOpen` to the documented cancelable hook set and made unhandled cancelable events resolve with `cancel=false`.
- Removed the unused Flutter fallback table and added analyzer/lint configuration for the package example.

## 0.8.2

- Added Flutter controller support for appending data and refreshed generated protocol bindings.

## 0.8.1

- Synced barcode fixture/docs updates and GTK demo build fixes with the release.

## 0.8.0

- Synced Flutter bindings and docs for barcode support, aggregate APIs, custom sort responses, dropdown lifecycle events, and event-decision handling.

## 0.7.1

- Regenerated Flutter bindings for explicit mutating RPC responses and operation-summary fields.

## 0.7.0

- Synced Flutter package metadata and generated bindings for the in-cell editing and IME-focused release.

## 0.6.0

- Refreshed package docs and metadata alongside the GUI/TUI documentation split.

## 0.5.0

- Added pull-to-refresh support and moved context menu handling to the app side.
- Expanded subtotal support with `Font`, multi-total fixes, and dropdown/icon behavior fixes.
- Improved auto-resize behavior for row numbers, last-column extension, and default sizing.
- Fixed web and stream-dispose behavior and moved demo examples out of the core crate.

## 0.4.0

- Improved rendering performance with GTK/Linux GPU surface work and CPU/GPU scroll blitting.
- Fixed selection, active-cell, IME, checkbox, scrollbar, and progress-bar editing issues.
- Added layering work and expanded ActiveX test coverage.

## 0.3.0

- Redesigned APIs.
- Improved Android GPU support and frame pacing.
- Fixed CPU-mode span and header separator rendering issues.

## 0.2.0

- canonical APIs 

## 0.1.4

- Added Flutter platform declarations for `macos` and `windows`.
- Added desktop native resolution from Maven for Linux, macOS, and Windows.
- Added support for `VOLVOXGRID_SOURCE` and `VOLVOXGRID_VERSION` across desktop native library builds.
- Added `-SNAPSHOT` refresh handling for desktop native resolution.

## 0.1.3

- Support `VOLVOXGRID_SOURCE`, `VOLVOXGRID_VERSION`, and `VOLVOXGRID_VARIANT` environment variables.
- Support resolving native dependencies from Maven (Local or Central) for Android and Linux.

## 0.1.0

- Initial public release of `volvoxgrid` Flutter package.
- Added `VolvoxGridWidget` for native pixel-rendered grid display.
- Added `VolvoxGridController` high-level async API.
- Added generated protobuf and Synurang FFI bindings.
- Added Android and Linux platform support.
