# Changelog

## 0.8.12

- Fixed native version resolution for package-only installs. Explicit overrides take priority over the package version, with a recognized monorepo `VERSION` as a fallback. Source selection consistently honors `VOLVOXGRID_SOURCE=local/maven`.
- Removed the Linux/Windows CMake dependency on a Gradle wrapper; missing downloads, libraries and requested Android ABIs now fail the build with recovery instructions. Shared Ruby configuration applies version/source selection to the iOS/macOS podspecs.
- Added optional `getRowId: int Function(T)` and numeric native row IDs. `VolvoxCellEdit.rowId`, controller ID helpers and `VolvoxRowIdentity` use positive signed 64-bit Dart integers without double conversion; generated protobuf messages use `Int64`. Engine-generated IDs are used when omitted. Business keys remain on source objects. Replaced the unpublished string-ID/Flutter-only hidden-column approaches while retaining source-snapshot indices, separate display coordinates and field-based column mapping.
- Made native row identities an explicit creation-only option: low-level `create(rowIdsEnabled: false)` is the default and allocates no identity arrays; ID APIs fail rather than enabling them implicitly. `VolvoxDataGrid` always creates with IDs enabled and rejects an existing disabled controller before changing its data. Changing the option requires destruction/recreation; disabled low-level edit events use ID zero.
- Use the current native API directly without version-specific capability probes or fallback paths. Reuse supplied IDs without querying them back, and discard obsolete queued requests before allocating snapshot arrays.
- Used compact numeric engine identities and rejected delayed validation for canceled or superseded edit sessions, including supplied-ID reuse.
- Enabled editing automatically for editable columns; added explicit column types, formatting/editor options, synchronous validation and error callbacks. Integer/decimal values retain string precision. Grid-range mutations are disabled while bound to avoid bypassing per-cell validation.
- Serialized asynchronous reloads, guarded controller replacement/disposal and avoided reloads for equivalent column configurations. Added `dataVersion` for intentional same-list updates.
- Added `active`/`TickerMode` suspension, system text/density scaling and finite viewport diagnostics. Protected asynchronous editor/event work across controller changes.
- Added package-only consumer verification, native edit/mapping regressions, lifecycle/scaling/input tests and a runnable business-table example. Documented app-owned server persistence and rollback, layout constraints and remaining mobile accessibility work.

Use the Flutter package with the matching current native engine, including its row-ID API, exact numeric ordering, typed readback and native read-only enforcement. Per-cell Semantics/TalkBack navigation remains unimplemented, and real-device Korean IME/touch acceptance is incomplete.

## 0.8.11

- Bumped iOS, macOS, Linux, and Windows artifact resolution to the v0.8.11 release: podspecs pull the matching `VolvoxGrid.xcframework` / `VolvoxGridLite.xcframework` from the GitHub v0.8.11 release, and the Linux/Windows CMake glue resolves `volvoxgrid-desktop-0.8.11.jar` from Maven Central.
- No Dart-side API changes. The 0.8.11 release focuses on a new header-only C++ binding (`cpp/include/volvoxgrid.hpp`) for non-Flutter hosts and a Rust reimplementation of the codegen plugin — see the [top-level CHANGELOG](../CHANGELOG.md) for full detail.

## 0.8.10

- Added checked-in iOS and macOS example projects for the Flutter package.
- Fixed Flutter iOS native loading through the statically linked XCFramework symbols.
- Added direct iOS FFI transport through `DynamicLibrary.process()` for statically linked XCFramework symbols.
- Added iOS plugin registration files that keep the Synurang/VolvoxGrid native symbols linked.
- Updated Flutter metadata for the iOS plugin class and the Synurang 0.6.0 package.
- Expanded native library probing for framework bundle locations.

## 0.8.9

- Regenerated protocol bindings for editor sessions, edit validation, indicator configuration, and font fallbacks.
- Added controller APIs for row/column indicator configuration and font fallback settings.
- Refreshed Flutter docs and examples for Maven-backed native loading, hierarchy indicators, and edit validation demos.

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
- Added snapshot refresh handling for desktop native resolution.

## 0.1.3

- Support `VOLVOXGRID_SOURCE`, `VOLVOXGRID_VERSION`, and `VOLVOXGRID_VARIANT` environment variables.
- Support resolving native dependencies from Maven (Local or Central) for Android and Linux.

## 0.1.0

- Initial public release of `volvoxgrid` Flutter package.
- Added `VolvoxGridWidget` for native pixel-rendered grid display.
- Added `VolvoxGridController` high-level async API.
- Added generated protobuf and Synurang FFI bindings.
- Added Android and Linux platform support.
