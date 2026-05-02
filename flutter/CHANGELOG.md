# Changelog

## 0.8.3

- Regenerated Flutter protocol bindings for tree events, slot-based row/corner indicators, indicator appearance controls, event target metadata, and configurable decision/compare timeouts.
- Updated `VolvoxGridController` row-indicator helpers to emit indicator slots instead of the removed row-indicator mode bit field.
- Refreshed the hierarchy example to derive tree levels from parent IDs, hide the label source column, and render outline expanders plus corner level buttons through indicators.
- Added `onBeforeDropdownOpen` to the documented cancelable hook set and made unhandled cancelable events resolve with `cancel=false`.
- Removed the unused Flutter fallback table and added analyzer/lint configuration for the package example.

## 0.8.2

- Version bump for the project-wide 0.8.2 patch release.
- Added Flutter controller support for appending data and refreshed generated protocol bindings.

## 0.8.1

- Version bump for the project-wide 0.8.1 patch release.
- Synced barcode fixture/docs updates and GTK demo build fixes with the release.

## 0.8.0

- Version bump for project-wide 0.8.0 release.

## 0.7.1

- Version bump for project-wide 0.7.1 release.

## 0.7.0

- Version bump for project-wide 0.7.0 release.

## 0.6.0

- Version bump for project-wide 0.6.0 release.

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
