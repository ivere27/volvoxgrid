# VolvoxGrid for Android

A high-performance datagrid view for Android that renders directly to pixel buffers. Supports CPU and GPU rendering, touch gestures, cell editing, sorting, merged cells, and more.

## Installation

Add the Maven dependency to your `build.gradle.kts`:

```kotlin
dependencies {
    implementation("io.github.ivere27:volvoxgrid-android:0.1.5")
    // or lite variant:
    // implementation("io.github.ivere27:volvoxgrid-android-lite:0.1.5")
}
```

Or `build.gradle`:

```groovy
dependencies {
    implementation 'io.github.ivere27:volvoxgrid-android:0.1.5'
    // or lite variant:
    // implementation 'io.github.ivere27:volvoxgrid-android-lite:0.1.5'
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
- Lite (Maven): `make android-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VARIANT=lite VOLVOXGRID_VERSION=0.1.5`

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

// Bulk load a 2D array (row-major order)
ctrl.loadArray(3, 2, Arrays.asList("a", "b", "c", "d", "e", "f"), false);

// Fill a 2D matrix (auto-resizes grid if needed)
ctrl.setTableData(Arrays.asList(
    Arrays.asList("Name", "Price", "Qty"),
    Arrays.asList("Widget A", "29.99", "150"),
    Arrays.asList("Widget B", "49.99", "200")
));
```

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
ctrl.sort(SortOrder.SORT_NUMERIC_ASCENDING, 1);

// Multi-column sort
ctrl.sortMulti(Arrays.asList(
    new Pair<>(0, SortOrder.SORT_STRING_ASC),
    new Pair<>(1, SortOrder.SORT_NUMERIC_DESCENDING)
));

// Show sort indicator on header
ctrl.setHeaderFeatures(HeaderFeatures.HEADER_SORT);
```

**SortOrder values:** `SORT_NONE`, `SORT_GENERIC_ASCENDING`, `SORT_GENERIC_DESCENDING`, `SORT_NUMERIC_ASCENDING`, `SORT_NUMERIC_DESCENDING`, `SORT_STRING_ASC`, `SORT_STRING_DESC`, `SORT_STRING_NO_CASE_ASC`, `SORT_STRING_NO_CASE_DESC`, `SORT_CUSTOM`

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
ctrl.setSelectionMode(SelectionMode.BY_ROW);
// Modes: FREE, BY_ROW, BY_COLUMN, LISTBOX, MULTI_RANGE
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
ctrl.setCellSpan(CellSpanMode.CELL_SPAN_BY_ROW);
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
ctrl.setColDataType(1, ColumnDataType.NUMBER);
ctrl.setColFormat(1, "#,##0.00");
// Data types: STRING, NUMBER, DATE, BOOLEAN, CURRENCY

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

#### Save & Load

```java
ExportResponse exported = ctrl.saveGrid(ExportFormat.EXPORT_BINARY);
ctrl.loadGrid(exported.getData().toByteArray(), ExportFormat.EXPORT_BINARY);
// Formats: EXPORT_BINARY, EXPORT_TSV, EXPORT_CSV, EXPORT_SPREADSHEET_ML
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
ctrl.loadDemo("sales");           // ~1000 rows with subtotals, merging, formats
ctrl.loadDemo("hierarchy");       // ~200 rows with tree outline
ctrl.loadDemo("stress");          // 1,000,000 rows for performance testing
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
ctrl.loadArray(rows = 3, cols = 2, values = listOf("a", "b", "c", "d", "e", "f"))

// Fill a 2D matrix (auto-resizes grid)
ctrl.setTableData(listOf(
    listOf("Name", "Price", "Qty"),
    listOf("Widget A", "29.99", "150"),
    listOf("Widget B", "49.99", "200"),
))

// Batch updates with suspended redraw
ctrl.withRedrawSuspended {
    ctrl.setCellText(0, 0, "A")
    ctrl.setCellText(0, 1, "B")
    ctrl.setCellText(1, 0, "C")
}

// Sorting
ctrl.sort(col = 1, ascending = true)
ctrl.sort(SortOrder.SORT_NUMERIC_ASCENDING, col = 1)
ctrl.sortMulti(listOf(
    Pair(0, SortOrder.SORT_STRING_ASC),
    Pair(1, SortOrder.SORT_NUMERIC_DESCENDING),
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

gridView.editListener = object : VolvoxGridView.EditCommitListener {
    override fun onEditCommit(row: Int, col: Int, text: String) { }
    override fun onEditCancel(row: Int, col: Int) { }
}

// Cleanup
gridView.release()
```

## License

[Apache License 2.0](../LICENSE)
