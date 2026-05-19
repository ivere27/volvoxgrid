# Changelog

All notable changes to VolvoxGrid are documented here. Per-package changelogs may have additional detail (e.g. [flutter/CHANGELOG.md](flutter/CHANGELOG.md)).

## 0.8.10

- Added a Swift package surface with the `VolvoxGrid` client, SwiftUI/UIKit/AppKit render views, Apple binary-target products, Linux support, and a Swift terminal TUI sample.
- Added Flutter iOS/macOS example projects and direct iOS FFI loading for statically linked XCFramework symbols.
- Fixed .NET native library discovery for NuGet `runtimes/<rid>/native` payloads and added cell text/value helper APIs to `VolvoxGridClient`.
- Fixed Java desktop initialization so a null library path can resolve the packaged native library automatically.
- Fixed Go module release metadata by pinning the Bubble Tea adapter to the matching core Go module version.
- Refreshed platform documentation for Swift, Flutter, Java, Android, .NET, Go, Web, and build/release flows.

## 0.8.9

- Added editor-session lifecycle and validation-on-cell-edit support across the engine, protocol, generated bindings, native hosts, Web/WASM, TUI, Flutter, Go, .NET, and ActiveX adapters.
- Added wrapper-facing row and column indicator configuration APIs, including row-indicator slot helpers and refreshed hierarchy/sales demos.
- Added configurable font fallback support across native CPU/GPU rendering, Web Canvas2D, Android, Java desktop, .NET, Flutter, and generated bindings.
- Added built-in visual theme presets via `GridConfig.theme_preset`, with resolved style, selection, scrollbar, and indicator palettes exposed across generated bindings and wrapper controllers.
- Expanded the Web/WASM package with protobuf RPC calls, typed data operations, named event listeners, cancelable-event handling, event pumping, and refreshed split demo modules.
- Added `ROW_INDICATOR_SLOT_NUMBERS_DATA_ONLY` row indicators that number only real data rows while leaving subtotal and outline group rows unnumbered.
- Fixed Flutter desktop IME editing by keeping the focused IME proxy synchronized with edit sessions, commit/cancel navigation, and validation-blocked edits.
- Fixed Web IME composition by using the host text editor as the idle IME proxy, starting edit sessions on composition start, and forwarding non-IME keys back to the canvas.
- Fixed outline toggle hit-box sizing and tree outline interaction handling.
- Fixed GitHub release publishing so internal prerelease artifacts are excluded from release uploads, and refreshed NuGet/package publishing documentation.

## 0.8.8

- Added full/lite artifact flows across Android, Android Compose, Java desktop, iOS, Web/WASM, and .NET, with OS/browser text-rendering fallback and engine-owned text-cache documentation.
- Added rich-text cell runs, baselines, link metadata, and richer text rendering across native, Web/WASM, TUI, Flutter, Go, and ActiveX bindings.
- Tightened GPU renderer mode selection and native-surface handling for platform hosts.
- Fixed Docker desktop/all macOS dylib packaging by adding `llvm-strip` support for Zig-built dylibs.
- Fixed mixed numeric/text and date/text auto sorting so barcode-like column values sort transitively and header toggles remain stable.

## 0.8.7

- Added a Bubble Tea terminal adapter with examples, tests, and TUI demo documentation.
- Added Android Compose artifact support and Java desktop table-model adapter documentation.
- Added higher-level Flutter data-grid helpers and expanded semantic cursor support across native wrappers.
- Fixed row/column resize hit testing and double-click checkbox handling across engine, Web/WASM, sheet, native, and ActiveX paths.

## 0.8.6

- Expanded the ActiveX/VSFlexGrid compatibility layer with container-contract probing, additional OLE/ADO/owner-draw hooks, persisted-state helpers, image/wallpaper compatibility properties, and MSAA accessibility properties.
- Added a protocol-level `CursorType` enum and semantic cursor hints across generated bindings, Web/WASM, GTK, and ActiveX while keeping the legacy cursor-style alias available.
- Fixed Web pointer hover delivery by treating empty grid space as background, suppressing background enter/leave events, and coalescing transient enter/leave pairs before event drain.
- Fixed checkbox rendering and hit testing in narrow or tall cells by sizing the checkbox from the smaller cell dimension.
- Fixed checkbox toggles to emit the `BeforeEdit`/`AfterEdit` edit-event sequence, including cancelable before-edit handling, across native, Web/WASM, and ActiveX/VSFlexGrid paths.
- Fixed duplicate `MouseMove`/`EnterCell` events after checkbox interactions by comparing stable hover target identity while still refreshing target state.
- Added minified Web, sheet, and AG Grid adapter bundles plus CDN import-map support for release demos.

## 0.8.5

- Replaced the plugin crate with the shared `volvoxgrid-runtime` library for native and Web builds.
- Fixed Web pinch-to-zoom handling, canvas clipping, and sticky row/column behavior.

## 0.8.4

- Fixed tree auto-resize behavior and updated the Web DOOM demo CDN/proxy integration.

## 0.8.3

- Added the native `VolvoxTreeService` protocol, engine tree model, and plugin/Web tree APIs for loading, mutating, expanding, selecting, checking, sorting, filtering, finding, and resolving tree nodes.
- Added slot-based row and corner indicators, outline level buttons, indicator appearance/color controls, indicator keyboard focus, and `GridEventTarget` metadata on pointer and cell-enter/leave events.
- Updated hierarchy demos across Flutter, Android, Java, .NET, Go, GTK, Web, TUI, and ActiveX to use the tree/indicator UI, with refreshed hierarchy data and golden screenshots.
- Changed cancelable events and custom sort comparisons to wait indefinitely by default, with `decision_timeout_ms` and `compare_response_timeout_ms` watchdogs available when finite timeouts are desired.
- Improved TUI row-indicator rendering and outline keyboard/pointer handling, and fixed row-indicator level indexing.

## 0.8.2

- Added append-data APIs across the protocol, generated bindings, and platform clients.
- Removed the engine build-time `tonic-build` dependency.
- Refreshed the web screenshot asset for the current demo state.

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

- Fixed Web font loading and hierarchy auto-resize behavior after fonts load.
- Added early XtraGrid adapter work and updated Android builds for SDK 36.
- Improved in-cell editing across Java desktop, .NET host text widgets, ActiveX IME, text selection, clipboard handling, and tab-based selection movement.
- Improved TUI edit-mode behavior and wide-text rendering, and added ActiveX `FontStyle` compatibility.

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
