# VolvoxGrid Flutter example

A runnable Flutter app that exercises the `volvoxgrid` package across three representative grids — pivot-style sales, file-tree hierarchy, and a million-row stress test — with live renderer-backend, debug-overlay, and edit toggles.

## What's in it

The example is a single-screen app with a demo switcher. Each demo lives in its own file under `lib/`:

- **`lib/sales_json_demo.dart`** — pivot-style sales table loaded from `getDemoData('sales')`. Demonstrates `defineColumns`, typed column data types, dropdown editors, multi-level subtotals via `addSubtotals`, and outline grouping. The most representative starting point if you're integrating a real business dataset.
- **`lib/hierarchy_json_demo.dart`** — directory-tree style grid loaded from `getDemoData('hierarchy')`. Shows tree-indicator slots, outline levels derived from parent IDs, text-link interactions, and platform-aware header heights for touch vs desktop. Read this one for tree/group rendering.
- **`lib/main.dart`** — the host app: demo switcher, status bar, debug-overlay toggle, renderer-backend selector (CPU / Vulkan / GLES on Android), text cache cap selector, render-layer mask, context menu, and a `stress` mode that calls `controller.loadDemo('stress')` for a one-million-row performance baseline.

All three demos share the same `VolvoxGridController` per mode and the same `VolvoxGridWidget` in `main.dart`, so you can see how a single widget hosts very different grids.

## Run it

From this directory:

```bash
flutter run                  # any connected device
flutter run -d linux         # desktop targets need full variant
flutter run -d macos
flutter run -d windows
flutter run -d <android-id>  # Android: GPU renderer toggles live in the UI
```

The first build pulls the native runtime from Maven Central. To use a local build instead, set the environment before `flutter run`:

```bash
export VOLVOXGRID_SOURCE=local
flutter run
```

On Android, the toolbar in the running app lets you switch between `RendererBackend.cpu`, `vulkan`, and `gles` at runtime — useful for comparing frame pacing and memory.

## What to read in the source

If you're learning the API, read the source files in this order:

1. **`lib/main.dart`** — see how `VolvoxGridController` is created, initialized, and bound to `VolvoxGridWidget`, including `onSelectionChanged`, `onGridEvent`, and context-menu handling.
2. **`lib/sales_json_demo.dart`** — the canonical pattern for `defineColumns`, `loadData` (JSON bytes), `setColDropdown`, and `addSubtotals` with multiple grouping levels.
3. **`lib/hierarchy_json_demo.dart`** — outline levels, tree indicator slots, text-link cells, and how to hide a source column while keeping it available to the engine.

Each demo is self-contained and uses only public APIs from `package:volvoxgrid/volvoxgrid.dart`.

## Customize

Add your own demo in three steps:

1. Drop a new file in `lib/`, exporting a single `Future<void> loadMyDemo(VolvoxGridController controller)` function. Use the existing demos as templates.
2. Extend the `DemoMode` enum in `lib/main.dart` and add a branch in `_initializeController` that calls your loader.
3. Add a button or menu entry to the demo switcher so it's reachable from the running app.

For the simplest possible integration, you don't need any of this — the `VolvoxDataGrid<T>` widget shown in the package README handles the controller for you.

## Next

See [../README.md](../README.md) for the package overview, API layers, native-binary resolution, and platform-support matrix.
