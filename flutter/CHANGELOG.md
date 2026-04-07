# Changelog

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

- Added Flutter plugin platform declarations for `macos` and `windows`.
- Added desktop native resolution from Maven for Linux, macOS, and Windows.
- Added support for `VOLVOXGRID_SOURCE` and `VOLVOXGRID_VERSION` across desktop plugin builds.
- Added `-SNAPSHOT` refresh handling for desktop native resolution.

## 0.1.3

- Support `VOLVOXGRID_SOURCE`, `VOLVOXGRID_VERSION`, and `VOLVOXGRID_VARIANT` environment variables.
- Support resolving native dependencies from Maven (Local or Central) for Android and Linux.

## 0.1.0

- Initial public release of `volvoxgrid` Flutter package.
- Added `VolvoxGridWidget` for native pixel-rendered grid display.
- Added `VolvoxGridController` high-level async API.
- Added generated protobuf and Synurang FFI bindings.
- Added Android and Linux plugin platform support.
