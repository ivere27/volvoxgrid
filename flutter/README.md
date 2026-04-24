# VolvoxGrid for Flutter

A high-performance, pixel-rendered data grid widget for Flutter. The native Rust engine renders directly to pixel buffers via FFI, supporting touch gestures, cell editing, sorting, merged cells, and more.

## Supported Platforms

| Platform | Native Library | Source |
|---|---|---|
| Android | `libvolvoxgrid_plugin.so` (AAR) | Maven (`volvoxgrid-android`) |
| Linux | `libvolvoxgrid_plugin.so` (JAR) | Maven (`volvoxgrid-desktop`) |
| macOS | `libvolvoxgrid_plugin.dylib` (JAR) | Maven (`volvoxgrid-desktop`) |
| Windows | `volvoxgrid_plugin.dll` (JAR) | Maven (`volvoxgrid-desktop`) |

**Requirements:** Flutter 3.10+, Dart SDK 3.0+, Android API 21+ (for Android)

## Installation

```yaml
dependencies:
  volvoxgrid: ^0.7.1
```

Native binaries are resolved automatically from Maven Central at build time. No manual downloads required.

### Native Library Resolution

By default, `VOLVOXGRID_SOURCE=maven` pulls pre-built binaries from Maven Central. For local development builds, set `VOLVOXGRID_SOURCE=local` and ensure the native library is available in `target/release/`.

| Variable | Default | Description |
|---|---|---|
| `VOLVOXGRID_SOURCE` | `maven` | `maven` or `local` |
| `VOLVOXGRID_VERSION` | `0.7.1` | Maven artifact version |

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:volvoxgrid/volvoxgrid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initVolvoxGrid();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final controller = VolvoxGridController();

  @override
  void initState() {
    super.initState();
    _initGrid();
  }

  Future<void> _initGrid() async {
    await controller.create(rows: 100, cols: 5);

    // Set column headers in the top indicator band.
    await controller.setColumnCaption(0, 'Name');
    await controller.setColumnCaption(1, 'Price');
    await controller.setColumnCaption(2, 'Qty');

    // Set data
    await controller.setCellText(0, 0, 'Widget A');
    await controller.setCellText(0, 1, '29.99');
    await controller.setCellText(0, 2, '150');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('VolvoxGrid')),
        body: VolvoxGridWidget(controller: controller),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

## API Reference

### VolvoxGridWidget

The main Flutter widget. Renders the native grid surface and handles all input forwarding (touch, mouse, keyboard).

```dart
VolvoxGridWidget(
  controller: controller,
  onSelectionChanged: (sel) {
    print('Row: ${sel.activeRow}, Col: ${sel.activeCol}');
  },
  onGridEvent: (event) {
    if (event.hasAfterSort()) { /* sort completed */ }
    if (event.hasAfterEdit()) { /* cell edited */ }
  },
  onBeforeEdit: (details) {
    if (details.col == 0) {
      details.cancel = true;
    }
  },
  onCellEditValidating: (details) {
    if (details.col == 2 && int.tryParse(details.editText) == null) {
      details.cancel = true;
    }
  },
  onBeforeSort: (details) {
    if (details.col == 4) {
      details.cancel = true;
    }
  },
)
```

Cancelable Flutter hooks currently cover `onBeforeEdit`, `onCellEditValidating`, and `onBeforeSort`. The legacy raw `onCancelableEvent` callback is still available, but the event-specific `details.cancel = true` API is clearer for app code.

### VolvoxGridController

High-level async API for grid operations. All calls cross an FFI boundary and return `Future`.

#### Lifecycle

```dart
final controller = VolvoxGridController();

// Create a grid
await controller.create(
  rows: 100,       // total rows
  cols: 10,        // total columns
);

// Dispose when done
controller.dispose();
```

#### Grid Dimensions

```dart
await controller.setRowCount(1000);
await controller.setColCount(20);
await controller.setFrozenRowCount(3);
await controller.setFrozenColCount(1);

int rows = await controller.rowCount();
int cols = await controller.colCount();
```

#### Cell Data

```dart
// Single cell
await controller.setCellText(row, col, 'text');
String text = await controller.getCellText(row, col);

// Batch update
await controller.setCells([
  CellTextEntry(row: 0, col: 0, text: 'A'),
  CellTextEntry(row: 0, col: 1, text: 'B'),
  CellTextEntry(row: 1, col: 0, text: 'C'),
]);

// Load a matrix-shaped JSON payload
await controller.loadData(
  utf8.encode(jsonEncode([
    ['Name', 'Price', 'Qty'],
    ['Widget A', '29.99', '150'],
    ['Widget B', '49.99', '200'],
  ])),
  LoadDataOptions()
    ..json = (JsonOptions())
    ..headerPolicy = HeaderPolicy.HEADER_NONE
    ..mode = LoadMode.LOAD_REPLACE,
);

// Clear all data
await controller.clear();

// Clear only data (keep formatting)
await controller.clear(scope: ClearScope.CLEAR_DATA);
// Scopes: CLEAR_EVERYTHING, CLEAR_FORMATTING, CLEAR_DATA, CLEAR_SELECTION
// Regions: CLEAR_SCROLLABLE, CLEAR_FIXED_ROWS, CLEAR_FIXED_COLS, CLEAR_ALL_REGIONS
```

#### LoadTable

`loadTable` bulk-loads a row-major flat array of typed `CellValue` entries. It replaces the grid contents in a single RPC call, making it efficient for large datasets.

```dart
await controller.loadTable(3, 2, [
  CellValue()..text = 'a',
  CellValue()..text = 'b',
  CellValue()..number = 1.0,
  CellValue()..number = 2.0,
  CellValue()..flag = true,
  CellValue()..flag = false,
]);
```

`CellValue` supports `text`, `number`, `flag` (boolean), `raw` (bytes), and `timestamp` (epoch-ms). For the full `LoadTableRequest` schema, see [`proto/volvoxgrid.proto`](../proto/volvoxgrid.proto) and the generated FFI client in `volvoxgrid_ffi.dart`.

#### Row & Column Sizing

```dart
await controller.setRowHeight(0, 40);
await controller.setColWidth(0, 200);

// Auto-fit column widths to content
await controller.autoSize(colFrom: 0, colTo: 4, equal: false, maxWidth: 500);
```

#### Row & Column Operations

```dart
await controller.insertRows(5, count: 3);   // insert 3 rows at index 5
await controller.removeRows(5, count: 3);    // remove 3 rows at index 5
await controller.moveColumn(2, 0);           // move column 2 to position 0
await controller.moveRow(10, 0);             // move row 10 to position 0
```

#### Sorting

```dart
// Single-column sort
await controller.sort(SortOrder.SORT_ASCENDING, col: 0);

// Multi-column sort
await controller.sortMulti([
  (0, SortOrder.SORT_ASCENDING),
  (1, SortOrder.SORT_DESCENDING),
]);

// Show sort indicator on header
await controller.setHeaderFeatures(HeaderFeatures()..sort = true);
```

**SortOrder values:** `SORT_NONE`, `SORT_ASCENDING`, `SORT_DESCENDING`

**SortType values:** `SORT_TYPE_AUTO`, `SORT_TYPE_NUMERIC`, `SORT_TYPE_STRING`, `SORT_TYPE_STRING_NO_CASE`, `SORT_TYPE_CUSTOM`

#### Selection

```dart
// Set active cell
await controller.setCursorRow(5);
await controller.setCursorCol(2);

// Select a range
await controller.selectRange(1, 0, 5, 3);  // rowStart, colStart, rowEnd, colEnd

// Select multiple ranges
await controller.selectRanges([
  (CellRange()
    ..row1 = 1
    ..col1 = 0
    ..row2 = 2
    ..col2 = 1),
  (CellRange()
    ..row1 = 4
    ..col1 = 3
    ..row2 = 6
    ..col2 = 4),
]);

// Get current selection
SelectionState sel = await controller.getSelection();
int row = sel.activeRow;
int col = sel.activeCol;
List<CellRange> ranges = sel.ranges;

// Selection mode
await controller.setSelectionMode(SelectionMode.SELECTION_BY_ROW);
// Modes: SELECTION_FREE, SELECTION_BY_ROW, SELECTION_BY_COLUMN, SELECTION_LISTBOX, SELECTION_MULTI_RANGE

// Scroll to make a cell visible
await controller.showCell(10, 3);
```

#### Cell Merging

```dart
await controller.mergeCells(0, 0, 0, 3);     // merge row 0, cols 0-3
await controller.unmergeCells(0, 0, 0, 3);
CellRange range = await controller.getMergedRange(0, 0);
MergedRegionsResponse regions = await controller.getMergedRegions();
```

#### Cell Spanning

```dart
await controller.setCellSpanMode(CellSpanMode.CELL_SPAN_BY_ROW);
// Modes: CELL_SPAN_NONE, CELL_SPAN_FREE, CELL_SPAN_BY_ROW, CELL_SPAN_BY_COLUMN,
//        CELL_SPAN_ADJACENT, CELL_SPAN_HEADER_ONLY, CELL_SPAN_SPILL, CELL_SPAN_GROUP

// Enable spanning for specific columns/rows
await controller.setSpanCol(0, true);
await controller.setSpanRow(0, true);
```

#### Editing

```dart
await controller.setEditTrigger(EditTrigger.EDIT_TRIGGER_KEY_CLICK);
// Modes: EDIT_TRIGGER_NONE, EDIT_TRIGGER_KEY, EDIT_TRIGGER_KEY_CLICK

// Programmatic edit control
await controller.commitEdit('new value');
await controller.cancelEdit();

// Column dropdown lists (pipe-delimited)
await controller.setColDropdownItems(2, 'Option A|Option B|Option C');

// Per-cell dropdown
await controller.setCellDropdownItems(1, 2, 'Yes|No');
```

#### Styling

```dart
// Column alignment
await controller.setColAlignment(1, Align.ALIGN_RIGHT_CENTER);
// Values: ALIGN_LEFT_TOP, ALIGN_LEFT_CENTER, ALIGN_LEFT_BOTTOM,
//         ALIGN_CENTER_TOP, ALIGN_CENTER_CENTER, ALIGN_CENTER_BOTTOM,
//         ALIGN_RIGHT_TOP, ALIGN_RIGHT_CENTER, ALIGN_RIGHT_BOTTOM, ALIGN_GENERAL

// Column data type and format
await controller.setColDataType(1, ColumnDataType.COLUMN_DATA_NUMBER);
await controller.setColFormat(1, '#,##0.00');

// Apply style to a range
await controller.setCellStyleRange(row1, col1, row2, col2, cellStyleOverride);

// Global grid style
StyleConfig style = await controller.getGridStyle();
style
  ..foreColor = 0xFF000000
  ..fontSize = 14.0;
await controller.setGridStyle(style);
```

#### Subtotals & Outlining

```dart
// Add subtotal rows grouped by column 0, aggregating column 2
await controller.subtotal(
  AggregateType.AGG_SUM,
  groupOnCol: 0,
  aggregateCol: 2,
);
// Aggregate types: AGG_SUM, AGG_COUNT, AGG_AVERAGE, AGG_MAX, AGG_MIN,
//                  AGG_STD_DEV, AGG_VAR, AGG_PERCENT, AGG_CLEAR

// Outline levels for tree-style grouping
await controller.setRowOutlineLevel(5, 1);
await controller.outline(2);                 // collapse to level 2
await controller.setTreeIndicator(TreeIndicatorStyle.CONNECTORS);
// Styles: TREE_INDICATOR_NONE, ARROWS, ARROWS_LEAF, CONNECTORS, CONNECTORS_LEAF
```

#### Clipboard

```dart
ClipboardResponse copied = await controller.copy();
ClipboardResponse cut = await controller.cut();
await controller.paste('tab\tseparated\nrows');
await controller.deleteSelection();
```

#### Scrolling & Scrollbars

```dart
await controller.setTopRow(50);
int top = await controller.topRow();
await controller.setScrollBars(ScrollBarsMode.SCROLLBAR_BOTH);
await controller.setFlingEnabled(true);      // momentum scrolling
await controller.setFlingImpulseGain(80.0);
await controller.setFlingFriction(0.9);
await controller.setFastScrollEnabled(true); // fast scroll thumb
```

#### Pin & Sticky

```dart
await controller.pinRow(0, PinPosition.PIN_TOP);
// Positions: PIN_NONE, PIN_TOP, PIN_BOTTOM

await controller.setRowSticky(5, StickyEdge.STICKY_TOP);
await controller.setColSticky(0, StickyEdge.STICKY_LEFT);
// Edges: STICKY_NONE, STICKY_TOP, STICKY_BOTTOM, STICKY_LEFT, STICKY_RIGHT, STICKY_BOTH
```

#### Search

```dart
int row = await controller.findRowByText(
  'Widget A',
  col: 0,
  startRow: 0,
  caseSensitive: false,
);

int row2 = await controller.findRowByRegex(
  r'^Widget.*',
  col: 0,
  startRow: 0,
);
```

#### Aggregates

```dart
double sum = await controller.aggregate(
  AggregateType.AGG_SUM, 1, 1, 100, 1,  // type, row1, col1, row2, col2
);
```

#### Export & LoadData

```dart
final exported = await controller.saveGrid(
  format: ExportFormat.EXPORT_BINARY,
);
final loaded = await controller.loadData(
  utf8.encode(name,qty
apple,3
banana,5),
);
// loadData parses CSV or JSON bytes; saveGrid remains export-only.
```

#### Rendering

```dart
// Renderer backend (Android GPU support)
await controller.setRendererBackend(RendererBackend.cpu);
// Backends: auto, cpu, gpu, vulkan, gles

await controller.setDebugOverlay(true);
await controller.setAnimationEnabled(true, durationMs: 250);
await controller.setTextLayoutCacheCap(4096);

// Batch updates: suspend redraw for performance
await controller.withRedrawSuspended(() async {
  // ... make many changes ...
});

await controller.refresh();   // force full repaint
```

**CPU mode (default):** The native engine renders into a shared RGBA pixel buffer. The Flutter widget copies this buffer and decodes it with `decodeImageFromPixels`, displaying the result via `RawImage`. This works on all platforms with no platform-specific setup.

**GPU mode (Android only):** The engine renders directly into a Flutter platform texture, eliminating the pixel-copy step. `VolvoxGridController.setRendererBackend()` manages the texture lifecycle automatically.

| Backend | Flutter Texture API | How it works |
|---|---|---|
| `RendererBackend.vulkan` | `createSurfaceProducer()` | SurfaceProducer is backed by `ImageReader` + `HardwareBuffer` under Flutter Impeller. wgpu's Vulkan backend renders into the `ANativeWindow`, and Impeller composites the `HardwareBuffer` via Vulkan -- both sides speak Vulkan natively. |
| `RendererBackend.gles` | `createSurfaceTexture()` | `SurfaceTexture` is EGL-native. wgpu's GLES backend renders via an EGL window surface bound to the `SurfaceTexture`, and Flutter composites via the GL texture ID. |

**GLES renders black screen on Impeller (Vulkan):** When Flutter's Impeller renderer uses Vulkan internally, `createSurfaceProducer()` is backed by `ImageReader`. wgpu's GLES backend renders via EGL to this surface, but the GLES-to-ImageReader-to-Vulkan cross-API composite fails silently, producing a black screen. This is why the plugin uses `createSurfaceTexture()` (the legacy API) for GLES -- `SurfaceTexture` is EGL-native and avoids the cross-API path. Vulkan mode works because both wgpu and Impeller speak Vulkan + `HardwareBuffer` natively.

**Desktop (Linux/macOS/Windows):** GPU rendering is not yet available through Flutter's texture registry. CPU mode is used on all desktop platforms.

#### Built-in Demos

```dart
await controller.loadDemo('stress');      // 1,000,000 rows for performance testing

final salesJson = await controller.getDemoData('sales');           // pair with loadData + explicit setup
final hierarchyJson = await controller.getDemoData('hierarchy');   // pair with loadData + explicit setup
```

## Full Proto API Access

`VolvoxGridController` wraps common operations. For the complete proto API surface, use the generated FFI client directly:

```dart
import 'package:volvoxgrid/volvoxgrid_ffi.dart';

// All generated protobuf messages and VolvoxGridServiceFfi are available.
final resp = await VolvoxGridServiceFfi.GetConfig(handle);
```

## License

[Apache License 2.0](../LICENSE)
