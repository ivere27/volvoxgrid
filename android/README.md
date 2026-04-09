# VolvoxGrid for Android

A high-performance datagrid view for Android that renders directly to pixel buffers. Supports CPU and GPU rendering, touch gestures, cell editing, sorting, merged cells, and more.

## Installation

Add the Maven dependency to your `build.gradle.kts`:

```kotlin
dependencies {
    implementation("io.github.ivere27:volvoxgrid-android:0.6.0")
    // or lite variant:
    // implementation("io.github.ivere27:volvoxgrid-android-lite:0.6.0")
}
```

Or `build.gradle`:

```groovy
dependencies {
    implementation 'io.github.ivere27:volvoxgrid-android:0.6.0'
    // or lite variant:
    // implementation 'io.github.ivere27:volvoxgrid-android-lite:0.6.0'
}
```

### Lite variant differences (`volvoxgrid-android-lite`)

`volvoxgrid-android-lite` is built with `--no-default-features` for the Rust plugin.
Compared to `volvoxgrid-android`, it excludes:

- Built-in text engine (`cosmic-text`)
- Regex-based search (`regex`)
- Parallel sort processing (`rayon`)

Practical impact:
- Smaller binary size
- Text shaping/rasterization is host-driven (in `VolvoxGridView`, Android callback rendering via JNI is auto-registered)
- C-side JNI bridge text cache can be tuned at runtime via `VolvoxGridView.setAndroidTextCacheSize(...)` to minimize JNI overhead
- Regex search APIs are unavailable
- Sorting/work generation is single-threaded
- Demo APIs remain available (`loadDemo`)
- Lite native filename is `libvolvoxgrid_plugin_lite.so` (normal is `libvolvoxgrid_plugin.so`)

The AAR bundles native libraries for `arm64-v8a` and `armeabi-v7a`.

**Requirements:** Android API 21+ (Android 5.0)

### Example App Variant Selection

For the Android example app (`make android-run`), use:

- Normal (default): `make android-run`
- Lite (local build): `make android-run VOLVOXGRID_VARIANT=lite`
- Lite (Maven): `make android-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VARIANT=lite VOLVOXGRID_VERSION=0.6.0`

`VOLVOXGRID_VARIANT` only treats `lite` as special. Any other value falls back to normal.

### Runtime Cache Control (Example App)

The Android example has a `Cache` dropdown (`8192`, `4096`, `1024`, `256`, `0`).

- Changes apply immediately at runtime.
- It updates engine cache via `ctrl.setTextLayoutCacheCap(cap)`.
- It also updates the C-side JNI bridge text cache via `gridView.setAndroidTextCacheSize(cap)` (used by lite mode).
- `0` disables and clears both text caches.

## Quick Start

### 1. Add the view to your layout

```xml
<io.github.ivere27.volvoxgrid.VolvoxGridView
    android:id="@+id/gridView"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

### 2. Initialize and populate

```java
import io.github.ivere27.volvoxgrid.*;

public class MainActivity extends AppCompatActivity {
    private VolvoxGridView gridView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        gridView = findViewById(R.id.gridView);

        // Initialize: auto-detects bundled native plugin (standard or lite)
        gridView.initialize(100, 5);
        //                  rows cols

        // Get a controller for grid operations
        VolvoxGridController ctrl = gridView.createController();

        // Set column headers in the top indicator band
        ctrl.setColumnCaption(0, "Name");
        ctrl.setColumnCaption(1, "Price");
        ctrl.setColumnCaption(2, "Qty");

        // Set data
        ctrl.setCellText(0, 0, "Widget A");
        ctrl.setCellText(0, 1, "29.99");
        ctrl.setCellText(0, 2, "150");
    }

    @Override
    protected void onDestroy() {
        gridView.release();
        super.onDestroy();
    }
}
```

## API Reference

### VolvoxGridView

The main Android `View` (extends `FrameLayout`). Handles rendering, touch input, and the native plugin lifecycle.

#### Initialization

```java
// Option A (recommended): Auto-detect bundled plugin and create a new grid
gridView.initialize(rows, cols);

// Option B: Explicit plugin path (advanced/manual host loading flows)
gridView.initialize(pluginPath, rows, cols);

// Option C: Reuse an existing plugin host and grid (for multi-grid apps)
gridView.initialize(pluginHost, existingGridId);
```

#### View Methods

| Method | Description |
|---|---|
| `createController()` | Create a `VolvoxGridController` for this grid |
| `getGridId()` | Get the native grid handle ID |
| `getService()` | Get the underlying FFI service client |
| `detachGrid()` | Stop render/event session but keep the grid alive |
| `release()` | Clean up all resources |
| `requestFrame()` | Request a render on next VSync |
| `requestFrameImmediate()` | Request a render immediately |
| `setRendererMode(mode)` | `0` = CPU, `1` = GPU (Auto), `3` = GPU (Vulkan), `4` = GPU (GLES) |
| `setAndroidTextCacheSize(size)` | Set Android host text-render cache size (`0` disables cache) |
| `setFlingFriction(friction)` | Tune scroll deceleration (0.001 -- 0.15) |
| `resolveBundledPluginPath(context)` | Resolve the bundled plugin `.so` path for `PluginHost.load(...)` |

#### Event Listeners

```java
// Grid events (selection change, sort, edit, etc.)
gridView.setEventListener(new VolvoxGridView.GridEventListener() {
    @Override
    public void onGridEvent(GridEvent event) {
        if (event.hasCellFocusChanged()) {
            GridEvent.CellFocusChanged e = event.getCellFocusChanged();
            Log.d("Grid", "Moved to row=" + e.getNewRow() + ", col=" + e.getNewCol());
        }
        if (event.hasAfterSort()) { /* sort completed */ }
        if (event.hasAfterEdit()) { /* cell edited */ }
    }
});

// Cancelable "before" events. Supported here: BeforeEdit, CellEditValidate, BeforeSort.
gridView.setBeforeEditListener(details -> {
    if (details.getRow() == 0) {
        details.setCancel(true);
    }
});

gridView.setCellEditValidatingListener(details -> {
    if (details.getEditText().isEmpty()) {
        details.setCancel(true);
    }
});

gridView.setBeforeSortListener(details -> {
    if (details.getCol() == 0) {
        details.setCancel(true);
    }
});

// Edit commit/cancel callbacks
gridView.setEditListener(new VolvoxGridView.EditCommitListener() {
    @Override
    public void onEditCommit(int row, int col, String text) {
        // user confirmed an edit
    }
    @Override
    public void onEditCancel(int row, int col) {
        // user cancelled an edit
    }
});
```

### VolvoxGridController

High-level API for grid operations. Obtained via `gridView.createController()`.

#### Grid Dimensions

```java
ctrl.setRowCount(1000);       // set row count
ctrl.setColCount(10);         // set column count

int rows = ctrl.rowCount();
int cols = ctrl.colCount();
```

#### Cell Data

```java
// Single cell
ctrl.setCellText(row, col, "text");
String text = ctrl.getCellText(row, col);

// Batch update
ctrl.setCells(Arrays.asList(
    new GridCellText(0, 0, "A"),
    new GridCellText(0, 1, "B"),
    new GridCellText(1, 0, "C")
));

// Load a matrix-shaped JSON payload
LoadDataOptions matrixJson = LoadDataOptions.newBuilder()
    .setJson(JsonOptions.newBuilder().build())
    .setHeaderPolicy(HeaderPolicy.HEADER_NONE)
    .build();
ctrl.loadData(
    """
    [["Name","Price","Qty"],
     ["Widget A","29.99","150"],
     ["Widget B","49.99","200"]]
    """.getBytes(java.nio.charset.StandardCharsets.UTF_8),
    matrixJson
);

// Clear all data
ctrl.clear();

// Clear only data (keep formatting)
ctrl.clear(ClearScope.CLEAR_DATA, ClearRegion.CLEAR_SCROLLABLE);
// Scopes: CLEAR_EVERYTHING, CLEAR_FORMATTING, CLEAR_DATA, CLEAR_SELECTION
```

#### LoadTable

`loadTable` bulk-loads a row-major flat array of typed `CellValue` entries in a single RPC call.

```java
ctrl.loadTable(2, 3, Arrays.asList(
    CellValue.newBuilder().setText("Widget A").build(),
    CellValue.newBuilder().setNumber(29.99).build(),
    CellValue.newBuilder().setNumber(150).build(),
    CellValue.newBuilder().setText("Widget B").build(),
    CellValue.newBuilder().setNumber(49.99).build(),
    CellValue.newBuilder().setNumber(200).build()
), true /* atomic */);
```

`CellValue` supports `text`, `number`, `flag` (boolean), `raw` (bytes), and `timestamp` (epoch-ms). For the full `LoadTableRequest` schema, see [`proto/volvoxgrid.proto`](../proto/volvoxgrid.proto) and the generated protobuf classes.

#### Row & Column Sizing

```java
ctrl.setRowHeight(0, 40);
ctrl.setColWidth(0, 200);

// Auto-fit column widths to content
ctrl.autoSize(0, 4, false, 500);
//          colFrom colTo equal maxWidth
```

#### Row & Column Operations

```java
ctrl.insertRows(5, 3);           // insert 3 rows at index 5
ctrl.removeRows(5, 3);           // remove 3 rows at index 5
ctrl.moveColumn(2, 0);           // move column 2 to position 0
ctrl.moveRow(10, 0);             // move row 10 to position 0
```

#### Sorting

```java
// Simple sort
ctrl.sort(1, true);              // col 1, ascending

// With sort order enum
ctrl.sort(SortOrder.SORT_ASCENDING, 1);

// Multi-column sort
ctrl.sortMulti(Arrays.asList(
    new Pair<>(0, SortOrder.SORT_ASCENDING),
    new Pair<>(1, SortOrder.SORT_DESCENDING)
));

// Show sort indicator on header
ctrl.setHeaderFeatures(HeaderFeatures.newBuilder().setSort(true).build());
```

**SortOrder values:** `SORT_NONE`, `SORT_ASCENDING`, `SORT_DESCENDING`

**SortType values:** `SORT_TYPE_AUTO`, `SORT_TYPE_NUMERIC`, `SORT_TYPE_STRING`, `SORT_TYPE_STRING_NO_CASE`, `SORT_TYPE_CUSTOM`

#### Selection

```java
// Set active cell
ctrl.setCursorRow(5);
ctrl.setCursorCol(2);

// Select a range
ctrl.selectRange(1, 0, 5, 3);    // row1, col1, row2, col2

// Select multiple ranges
ctrl.selectRanges(Arrays.asList(
    new GridCellRange(1, 0, 2, 1),
    new GridCellRange(4, 3, 6, 4)
));

// Select multiple ranges with an explicit active cell
ctrl.selectRanges(
    Arrays.asList(
        new GridCellRange(1, 0, 2, 1),
        new GridCellRange(4, 3, 6, 4)
    ),
    6,
    4
);

// Get current selection
GridSelection sel = ctrl.getSelection();
int row = sel.getRow();
int col = sel.getCol();
int rowEnd = sel.getRowEnd();
int colEnd = sel.getColEnd();
GridCellRange[] ranges = sel.getRanges();

// Selection mode
ctrl.setSelectionMode(SelectionMode.SELECTION_BY_ROW);
// Modes: SELECTION_FREE, SELECTION_BY_ROW, SELECTION_BY_COLUMN, SELECTION_LISTBOX, SELECTION_MULTI_RANGE
```

#### Cell Merging

```java
ctrl.mergeCells(0, 0, 0, 3);     // merge row 0, cols 0-3
ctrl.unmergeCells(0, 0, 0, 3);
CellRange range = ctrl.getMergedRange(0, 0);
MergedRegionsResponse regions = ctrl.getMergedRegions();
```

#### Cell Spanning

```java
ctrl.setCellSpanMode(CellSpanMode.CELL_SPAN_BY_ROW);
// Modes: CELL_SPAN_NONE, CELL_SPAN_FREE, CELL_SPAN_BY_ROW, CELL_SPAN_BY_COLUMN,
//        CELL_SPAN_ADJACENT, CELL_SPAN_HEADER_ONLY, CELL_SPAN_SPILL, CELL_SPAN_GROUP
```

#### Editing

```java
ctrl.setEditTrigger(EditTrigger.EDIT_TRIGGER_KEY_CLICK);
// Modes: EDIT_TRIGGER_NONE, EDIT_TRIGGER_KEY, EDIT_TRIGGER_KEY_CLICK

ctrl.beginEdit(1, 0);            // programmatically start editing
ctrl.commitEdit();
```

#### Styling

```java
// Column alignment
ctrl.setColAlignment(1, Align.ALIGN_RIGHT_CENTER);
// Values: ALIGN_LEFT_TOP, ALIGN_LEFT_CENTER, ALIGN_LEFT_BOTTOM,
//         ALIGN_CENTER_TOP, ALIGN_CENTER_CENTER, ALIGN_CENTER_BOTTOM,
//         ALIGN_RIGHT_TOP, ALIGN_RIGHT_CENTER, ALIGN_RIGHT_BOTTOM, ALIGN_GENERAL

// Column data type and format
ctrl.setColDataType(1, ColumnDataType.COLUMN_DATA_NUMBER);
ctrl.setColFormat(1, "#,##0.00");
// Data types: COLUMN_DATA_STRING, COLUMN_DATA_NUMBER, COLUMN_DATA_DATE, COLUMN_DATA_BOOLEAN, COLUMN_DATA_CURRENCY

// Word wrap and ellipsis
ctrl.setWordWrap(true);
ctrl.setEllipsis(true);

// Apply style to a range of cells
ctrl.setCellStyleRange(row1, col1, row2, col2, cellStyleOverride);

// Global grid style
ctrl.setGridStyle(styleConfig);
```

#### Subtotals & Outlining

```java
// Add subtotal rows grouped by column 0, aggregating column 2
ctrl.subtotal(AggregateType.AGG_SUM, 0, 2);
// Aggregate types: AGG_SUM, AGG_COUNT, AGG_AVERAGE, AGG_MAX, AGG_MIN,
//                  AGG_STD_DEV, AGG_VAR, AGG_PERCENT, AGG_CLEAR

// Outline levels for tree-style grouping
ctrl.setRowOutlineLevel(5, 1);
ctrl.outline(2);                 // collapse to level 2
ctrl.setTreeIndicator(TreeIndicatorStyle.CONNECTORS);
// Styles: TREE_INDICATOR_NONE, ARROWS, ARROWS_LEAF, CONNECTORS, CONNECTORS_LEAF
```

#### Clipboard

```java
ClipboardResponse copied = ctrl.copy();
ClipboardResponse cut = ctrl.cut();
ctrl.paste("tab\tseparated\nrows");
ctrl.delete();                   // delete selection content
```

#### Scrolling & Scrollbars

```java
ctrl.setTopRow(50);              // scroll to row 50
int top = ctrl.topRow();
ctrl.setScrollBars(ScrollBarsMode.SCROLL_BARS_BOTH);
ctrl.setFlingEnabled(true);      // momentum scrolling
ctrl.setFlingImpulseGain(80f);
ctrl.setFlingFriction(0.9f);
```

#### Pin & Sticky

```java
ctrl.pinRow(0, PinPosition.PIN_TOP);
// Positions: PIN_NONE, PIN_TOP, PIN_BOTTOM

ctrl.setRowSticky(5, StickyEdge.STICKY_TOP);
ctrl.setColSticky(0, StickyEdge.STICKY_LEFT);
// Edges: STICKY_NONE, STICKY_TOP, STICKY_BOTTOM, STICKY_LEFT, STICKY_RIGHT, STICKY_BOTH
```

#### Search

```java
int row = ctrl.findRow("Widget A", 0, 0, false);
//                      text       col startRow caseSensitive

int row2 = ctrl.findRowByRegex("^Widget.*", 0, 0);
//                               pattern    col startRow
```

#### Aggregates

```java
double sum = ctrl.aggregate(AggregateType.AGG_SUM, 1, 1, 100, 1);
//                           type                  row1 col1 row2 col2
```

#### Export & LoadData

```java
ExportResponse exported = ctrl.saveGrid(ExportFormat.EXPORT_BINARY);
LoadDataResult loaded = ctrl.loadData("name,qty\napple,3\nbanana,5".getBytes(java.nio.charset.StandardCharsets.UTF_8));
// loadData parses CSV or JSON bytes; saveGrid remains export-only.
```

#### Rendering

```java
ctrl.setRendererMode(1);          // 0=CPU, 1=GPU (Auto), 3=GPU (Vulkan), 4=GPU (GLES)
ctrl.setDebugOverlay(true);       // show debug grid overlay
```

**GPU Backend Note:** On some Android devices (especially those with Adreno GPUs), Vulkan may fail during internal capability probing (4x4 allocation error). If you experience crashes or hangs in GPU mode, try pinning to **GLES** (mode `4`). Mode `1` (Auto) defaults to GLES on Android for better stability.

**Rendering Performance & VSync:** All rendering modes are vsync-locked on Android — there is no need to manually cap the frame rate.

- **CPU mode** submits frames through `ANativeWindow_unlockAndPost`, which passes through SurfaceFlinger and is always synchronized to the display's refresh rate (typically 60 Hz).
- **GL / Vulkan modes** use wgpu with `PresentMode::Fifo` (equivalent to `VK_PRESENT_MODE_FIFO_KHR` / `eglSwapInterval(1)`), which synchronizes frame presentation to the display refresh rate. Additionally, the Android host enforces single-frame-in-flight backpressure via the `pendingFrame` semaphore.
- The engine does not expose a manual frame rate cap setting because vsync pacing handles this automatically. On 60 Hz panels both CPU and GPU modes target 60fps; on 120 Hz panels they target 120fps.
- **Debug overlay FPS** (`setDebugOverlay(true)`) shows an **Exponential Moving Average (EMA)** of the time taken to render and present a frame.
- The measurement wraps the entire render-to-surface/buffer call, including the GPU's `present()` step. Depending on the graphics driver and swapchain state, `present()` may block to synchronize with VSync. 
- If the driver allows immediate queuing, the reported FPS reflects the engine's **potential performance** (how fast it *could* render, often 200–300+ fps on GPU). If the driver blocks during presentation, the reported FPS will match the display's refresh rate (e.g., 60 or 120 fps).
- CPU mode typically reports lower FPS (e.g. ~60fps) because software rendering fills pixels sequentially on the CPU, while GPU modes often report much higher numbers because the work is parallelized and offloaded.

```java
ctrl.setAnimationEnabled(true, 250);  // enable with 250ms duration
ctrl.setTextLayoutCacheCap(4096); // engine text layout cache size
gridView.setAndroidTextCacheSize(4096); // lite host text cache size (0 disables)

ctrl.setRedraw(false);            // batch: disable rendering
// ... make many changes ...
ctrl.setRedraw(true);             // re-enable and repaint
ctrl.refresh();                   // force full repaint

// Or use withRedrawSuspended for automatic suspend/resume:
ctrl.withRedrawSuspended(() -> {
    ctrl.setCellText(0, 0, "A");
    ctrl.setCellText(0, 1, "B");
    ctrl.setCellText(1, 0, "C");
});
```

#### Built-in Demos

```java
ctrl.loadDemo("stress");          // 1,000,000 rows for performance testing

byte[] salesJson = ctrl.getDemoData("sales");           // pair with loadData + explicit setup
byte[] hierarchyJson = ctrl.getDemoData("hierarchy");   // pair with loadData + explicit setup
```

## Multi-Grid Apps

Share a single plugin host across multiple grids to avoid reloading the native library:

```java
import io.github.ivere27.synurang.PluginHost;

// Load once
PluginHost pluginHost = PluginHost.load(VolvoxGridView.resolveBundledPluginPath(this));

// Create multiple grids
gridView1.initialize(pluginHost, gridId1);
gridView2.initialize(pluginHost, gridId2);
```

## Kotlin

The API is identical from Kotlin, using the same method names:

```kotlin
val gridView: VolvoxGridView = findViewById(R.id.gridView)
gridView.initialize(rows = 100, cols = 5)

val ctrl = gridView.createController()

ctrl.setRowCount(1000)
ctrl.setColCount(10)
ctrl.setCursorRow(5)
ctrl.setCursorCol(2)

// Cell data
ctrl.setCellText(0, 0, "Name")
ctrl.setCells(listOf(
    GridCellText(0, 0, "A"),
    GridCellText(0, 1, "B"),
))

// Load a matrix-shaped JSON payload
val matrixJson = """
    [["Name","Price","Qty"],
     ["Widget A","29.99","150"],
     ["Widget B","49.99","200"]]
""".trimIndent().toByteArray(Charsets.UTF_8)
ctrl.loadData(
    matrixJson,
    LoadDataOptions.newBuilder()
        .setJson(JsonOptions.newBuilder().build())
        .setHeaderPolicy(HeaderPolicy.HEADER_NONE)
        .build()
)

// Clear all data
ctrl.clear()

// Clear only data (keep formatting)
ctrl.clear(ClearScope.CLEAR_DATA, ClearRegion.CLEAR_SCROLLABLE)

// Bulk load typed values
ctrl.loadTable(2, 3, listOf(
    CellValue.newBuilder().setText("Widget A").build(),
    CellValue.newBuilder().setNumber(29.99).build(),
    CellValue.newBuilder().setNumber(150.0).build(),
    CellValue.newBuilder().setText("Widget B").build(),
    CellValue.newBuilder().setNumber(49.99).build(),
    CellValue.newBuilder().setNumber(200.0).build(),
))

// Batch updates with suspended redraw
ctrl.withRedrawSuspended {
    ctrl.setCellText(0, 0, "A")
    ctrl.setCellText(0, 1, "B")
    ctrl.setCellText(1, 0, "C")
}

// Sorting
ctrl.sort(col = 1, ascending = true)
ctrl.sort(SortOrder.SORT_ASCENDING, col = 1)
ctrl.sortMulti(listOf(
    Pair(0, SortOrder.SORT_ASCENDING),
    Pair(1, SortOrder.SORT_DESCENDING),
))

// Selection
ctrl.selectRange(row1 = 1, col1 = 0, row2 = 5, col2 = 3)
ctrl.selectRanges(
    ranges = listOf(
        GridCellRange(1, 0, 2, 1),
        GridCellRange(4, 3, 6, 4),
    ),
    activeRow = 6,
    activeCol = 4,
)
val sel = ctrl.getSelection()

// Events
gridView.eventListener = object : VolvoxGridView.GridEventListener {
    override fun onGridEvent(event: GridEvent) {
        when {
            event.hasCellFocusChanged() -> { /* ... */ }
            event.hasAfterSort() -> { /* ... */ }
            event.hasAfterEdit() -> { /* ... */ }
        }
    }
}

// Cancelable "before" events. Supported here: BeforeEdit, CellEditValidate, BeforeSort.
gridView.beforeEditListener = VolvoxGridView.BeforeEditListener { details ->
    if (details.row == 0) {
        details.cancel = true
    }
}

gridView.cellEditValidatingListener = VolvoxGridView.CellEditValidatingListener { details ->
    if (details.editText.isBlank()) {
        details.cancel = true
    }
}

gridView.beforeSortListener = VolvoxGridView.BeforeSortListener { details ->
    if (details.col == 0) {
        details.cancel = true
    }
}

gridView.editListener = object : VolvoxGridView.EditCommitListener {
    override fun onEditCommit(row: Int, col: Int, text: String) { }
    override fun onEditCancel(row: Int, col: Int) { }
}

// Cleanup
gridView.release()
```

## License

[Apache License 2.0](../LICENSE)
