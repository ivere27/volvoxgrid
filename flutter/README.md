# VolvoxGrid for Flutter

VolvoxGrid is a pixel-rendered datagrid for Flutter. A native Rust engine draws every cell, header, scrollbar, and edit overlay into a shared RGBA buffer, which Flutter composites via `RawImage` (CPU) or a platform texture (Android GPU). You get the same grid on iOS, Android, macOS, Windows, and Linux, with input, IME, and scrolling handled by the engine — not by Flutter widgets.

## Quick start

Add the package and run the snippet below. In about 20 lines you'll have a typed grid with editable cells, sorting, and selection.

```yaml
dependencies:
  volvoxgrid: ^0.8.9
```

```dart
import 'package:flutter/material.dart';
import 'package:volvoxgrid/volvoxgrid.dart';

class Product {
  Product(this.name, this.price, this.qty);
  String name;
  double price;
  int qty;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initVolvoxGrid();
  runApp(const MaterialApp(home: HelloGrid()));
}

class HelloGrid extends StatefulWidget {
  const HelloGrid({super.key});
  @override
  State<HelloGrid> createState() => _HelloGridState();
}

class _HelloGridState extends State<HelloGrid> {
  List<Product> rows = [
    Product('Widget A', 29.99, 150),
    Product('Widget B', 19.50, 80),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('VolvoxGrid')),
        body: VolvoxDataGrid<Product>(
          rows: rows,
          columns: [
            VolvoxColumn(field: 'name', header: 'Name', value: (p) => p.name),
            VolvoxColumn(
              field: 'price',
              header: 'Price',
              value: (p) => p.price.toStringAsFixed(2),
              editable: true,
            ),
            VolvoxColumn(field: 'qty', header: 'Qty', value: (p) => '${p.qty}'),
          ],
          onCellEdit: (edit) => setState(() {
            rows[edit.rowIndex].price =
                double.tryParse(edit.newText) ?? rows[edit.rowIndex].price;
            rows = List.of(rows); // new list reference triggers a reload
          }),
        ),
      );
}
```

## What you just built

The engine resolved your three columns, inferred their types, picked a default editor for the editable `price` column, and started a render session that paints frames into Flutter. Tap a `price` cell and you're in IME-aware edit mode; commit, and `onCellEdit` fires with the typed row, the field name, and the new text.

Pass a **new** list reference (via `setState` or a copy) to refresh — mutating the same list in place won't trigger a reload. This matches the convention of other Flutter data widgets.

## Two layers of API

You'll mostly stay in the high-level path. Drop down to the controller when you need engine-level control.

### VolvoxDataGrid — the easy path

`VolvoxDataGrid<T>` is the 95% case. You pass typed `rows` and `VolvoxColumn` definitions; it owns the controller, infers column data types, wires the default editors, and exposes a single `onCellEdit` callback with typed details. No protobuf, no FFI plumbing.

```dart
VolvoxDataGrid<Product>(
  rows: products,
  columns: [
    VolvoxColumn(field: 'name',  header: 'Name',  value: (p) => p.name),
    VolvoxColumn(field: 'price', header: 'Price', value: (p) => '${p.price}', editable: true),
  ],
  onCellEdit: (edit) {/* edit.rowIndex, edit.row, edit.field, edit.newText */},
)
```

Use this when your screen is "render this list as a grid; let the user edit a few columns."

### VolvoxGridController + VolvoxGridWidget — the full path

When you need partial cell updates, custom dropdown data sources, programmatic multi-column sort, merged cells, subtotals, frozen rows, sticky columns, or any of the engine-level features documented in [../GUI.md](../GUI.md), drop down to the controller form. `VolvoxDataGrid` is built on top of these.

```dart
class _GridState extends State<MyGrid> {
  final controller = VolvoxGridController();

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    await controller.create(rows: 1000, cols: 5);
    await controller.setColumnCaption(0, 'Name');
    await controller.setColumnCaption(1, 'Price');
    await controller.setCellText(0, 0, 'Widget A');
    await controller.setCellText(0, 1, '29.99');
  }

  @override
  Widget build(BuildContext context) => VolvoxGridWidget(
        controller: controller,
        onSelectionChanged: (sel) => print('${sel.activeRow}, ${sel.activeCol}'),
        onBeforeEdit: (d) {
          if (d.col == 0) d.cancel = true; // make column 0 read-only
        },
      );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

Every method on `VolvoxGridController` is async because each call crosses an FFI boundary. For bulk work, prefer `setCells`, `loadTable`, `loadData`, and `withRedrawSuspended` over per-cell calls.

## Loading data

For bulk loading, use `loadData` (CSV or JSON bytes) or `loadTable` (typed `CellValue` array). Both replace the grid contents in a single RPC.

```dart
await controller.loadData(
  utf8.encode(jsonEncode([
    {'name': 'Widget A', 'price': 29.99, 'qty': 150},
    {'name': 'Widget B', 'price': 19.50, 'qty': 80},
  ])),
);
```

`loadData` auto-detects CSV vs JSON, infers column data types, and creates columns when `autoCreateColumns` is left at its default. Pass `LoadDataOptions` to override the header policy, format, or auto-creation behaviour.

For programmatic builds, the typed `loadTable` form is fastest:

```dart
await controller.loadTable(2, 3, [
  CellValue()..text = 'Widget A', CellValue()..number = 29.99, CellValue()..number = 150,
  CellValue()..text = 'Widget B', CellValue()..number = 19.50, CellValue()..number = 80,
]);
```

## Editing & validation

`VolvoxGridWidget` exposes three cancelable hooks for the edit lifecycle. Set `details.cancel = true` to veto.

```dart
VolvoxGridWidget(
  controller: controller,
  onBeforeEdit: (d) {
    if (d.col == 0) d.cancel = true; // protect the Name column
  },
  onCellEditValidating: (d) {
    if (d.col == 1 && double.tryParse(d.editText) == null) {
      d.cancel = true; // refuse non-numeric prices
    }
  },
  onBeforeSort: (d) {
    if (d.col == 4) d.cancel = true; // notes column is unsortable
  },
)
```

`onBeforeEdit` fires before the editor opens. `onCellEditValidating` fires when the user tries to commit. `onBeforeSort` fires before a header click sorts. If you don't register a hook, the engine proceeds without pausing for a decision. See [../KEYS.md](../KEYS.md) for the keyboard model and [../IME.md](../IME.md) for IME composition behaviour on each platform.

## Full vs lite

The native runtime ships in two variants. **Full** uses the built-in Rust text engine and (on Android) GPU rendering. **Lite** falls back to the host's text renderer (Android TextView, iOS CoreText, macOS CoreText). Lite is smaller and useful when you need to match host fonts exactly.

Flip variants by setting `VOLVOXGRID_VARIANT=lite` at build time. Linux and Windows desktop currently require the full variant for text; macOS, iOS, and Android all support lite. See [../TEXT_RENDERING.md](../TEXT_RENDERING.md) for the matrix.

## Native library resolution

The Flutter package resolves natives at build time, so consumers don't ship binaries directly:

- **Android** AAR via Maven Central (`io.github.ivere27:volvoxgrid-android`)
- **Desktop** (Linux, macOS, Windows) JAR via Maven Central (`io.github.ivere27:volvoxgrid-desktop`)
- **iOS** `VolvoxGrid.xcframework` from GitHub releases (Lite uses `VolvoxGridLite.xcframework`)

Override resolution with environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `VOLVOXGRID_SOURCE` | `maven` | `maven` or `local` (reads from `target/release/`) |
| `VOLVOXGRID_VERSION` | matches package | Pin a specific Maven artifact version |
| `VOLVOXGRID_VARIANT` | empty | Set to `lite` on supported platforms |

The shared library is named `libvolvoxgrid.so` (Linux, Android), `libvolvoxgrid.dylib` (macOS), or `volvoxgrid.dll` (Windows). The Dart loader resolves it through Flutter's plugin FFI mechanism — you don't link it manually.

## Platform support

| Platform | Native artifact | CPU render | GPU render |
|---|---|---|---|
| Android | `libvolvoxgrid.so` (AAR) | yes | Vulkan + GLES via Flutter texture |
| iOS | `VolvoxGrid.xcframework` | yes | not yet via Flutter texture |
| macOS | `libvolvoxgrid.dylib` (JAR) | yes | not yet via Flutter texture |
| Windows | `volvoxgrid.dll` (JAR) | yes | not yet via Flutter texture |
| Linux | `libvolvoxgrid.so` (JAR) | yes | not yet via Flutter texture |

CPU mode is the default everywhere and is the only mode currently exposed through Flutter's texture registry on desktop. On Android, `controller.setRendererBackend(RendererBackend.vulkan)` or `gles` switches to direct platform-texture compositing. See [../ARCHITECTURE.md](../ARCHITECTURE.md) for the render pipeline.

**Requirements:** Flutter 3.10+, Dart 3.0+, Android API 21+.

## Troubleshooting

- **IME composition disappears on desktop.** Ensure your app forwards keyboard events to the focused `VolvoxGridWidget` and that no parent widget swallows `TextInputAction.newline`. See [../IME.md](../IME.md).
- **Black grid on Android with `RendererBackend.gles`.** Impeller on Vulkan composites GLES surfaces through `ImageReader`, which fails silently. Switch to `RendererBackend.vulkan` or fall back to `RendererBackend.cpu`.
- **Missing native lib at runtime.** Verify `VOLVOXGRID_SOURCE`. With `maven` (default), check that Gradle can reach Maven Central; with `local`, confirm the binary is in `target/release/` relative to the package root.
- **Lite renders the wrong glyphs.** On Linux/Windows desktop, lite isn't supported — drop `VOLVOXGRID_VARIANT=lite` and rebuild with the full runtime.
- **Maven snapshot resolution stalls.** Force a refresh with `flutter clean` then rebuild; snapshot versions intentionally re-check the remote on each build.

## What's next

- [CHANGELOG.md](CHANGELOG.md) — release notes
- [../GUI.md](../GUI.md) — full engine feature reference
- [../ARCHITECTURE.md](../ARCHITECTURE.md) — render pipeline, FFI, threading
- [../IME.md](../IME.md) — IME and host-editor model
- [../KEYS.md](../KEYS.md) — keyboard map and edit triggers
- [../TEXT_RENDERING.md](../TEXT_RENDERING.md) — full vs lite text matrix
- [example/](example/) — runnable demos (sales, hierarchy, stress)

## License

[Apache License 2.0](../LICENSE)
