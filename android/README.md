# VolvoxGrid for Android

VolvoxGrid is a pixel-rendered datagrid for Android. The native Rust engine draws cells, headers, gridlines, and text directly into a pixel buffer that an Android `View` composites — so a million rows scrolls the same way a hundred do, and your UI thread stays free.

This doc walks you through your first grid, then the deeper APIs. If you read it top to bottom you'll have a working app by section three and full control by section nine.

## Quick start

Add the dependency to `build.gradle.kts`:

```kotlin
dependencies {
    implementation("io.github.ivere27:volvoxgrid-android:0.8.9")
}
```

Drop a `VolvoxGridView` into your layout:

```xml
<io.github.ivere27.volvoxgrid.VolvoxGridView
    android:id="@+id/gridView"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

Then wire it up with `VolvoxGridAdapter<T>` — the typed, data-first wrapper:

```kotlin
import io.github.ivere27.volvoxgrid.*
import io.github.ivere27.volvoxgrid.common.*

data class Product(val name: String, val price: Double, val qty: Int)

class MainActivity : AppCompatActivity() {
    private lateinit var adapter: VolvoxGridAdapter<Product>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        val gridView: VolvoxGridView = findViewById(R.id.gridView)

        adapter = VolvoxGridAdapter(
            view = gridView,
            columns = listOf(
                VolvoxColumn(field = "name",  header = "Name",  value = { it.name }),
                VolvoxColumn(field = "price", header = "Price",
                             value = { "%.2f".format(it.price) }, editable = true),
                VolvoxColumn(field = "qty",   header = "Qty",   value = { "${it.qty}" }),
            ),
        )
        adapter.onCellEdit = { edit -> /* edit.row is the typed Product */ }
        adapter.submitList(listOf(
            Product("Widget A", 29.99, 150),
            Product("Widget B", 19.50, 80),
        ))
    }

    override fun onDestroy() {
        adapter.detach()
        super.onDestroy()
    }
}
```

## What you just built

- A scrollable, pixel-rendered grid backed by your own `Product` type — no protobuf, no controller code in sight.
- One editable column (`price`) with a real text editor and commit/cancel handling.
- A typed `onCellEdit` callback that hands you the original row, not raw strings.
- Resource cleanup on `onDestroy()` so the native grid releases cleanly.

If you only need that, you're done. Skim the rest when you want more.

## Two paths: high-level vs low-level

VolvoxGrid gives you two ways to talk to the engine, and you can mix them in the same app.

**High-level** — `VolvoxGridAdapter<T>` (View) or `VolvoxGrid<T>` (Compose). You hand it a list of domain rows and column accessors; it manages the controller, schedules reloads, and surfaces edits as typed callbacks. Pick this when your data is already a `List<MyType>` and you want columns to feel like view models.

**Low-level** — `VolvoxGridView` plus `VolvoxGridController`. You drive the engine directly: set cells, fire `loadTable`, hook every event, manage merged ranges and pinned rows yourself. Pick this when you need partial cell updates, custom dropdown sources, or fine-grained event control. It's also what `VolvoxGridAdapter` uses under the hood.

The rest of this doc covers both. Start high-level, drop down when you need to.

## Compose

When your app is Compose-native, use the `volvoxgrid-android-compose` module. The Compose compiler dependency is isolated there, so pure-View consumers don't pay for it:

```kotlin
dependencies {
    implementation("io.github.ivere27:volvoxgrid-android-compose:0.8.9")
}
```

For the lite native runtime, swap in `volvoxgrid-android-compose-lite`:

```kotlin
dependencies {
    implementation("io.github.ivere27:volvoxgrid-android-compose-lite:0.8.9")
}
```

The composable mirrors the adapter's API:

```kotlin
import io.github.ivere27.volvoxgrid.*
import io.github.ivere27.volvoxgrid.common.*
import io.github.ivere27.volvoxgrid.compose.VolvoxGrid

@Composable
fun ProductGrid() {
    var products by remember { mutableStateOf(listOf(
        Product("Widget A", 29.99, 150),
        Product("Widget B", 19.50, 80),
    )) }

    VolvoxGrid(
        rows = products,
        columns = listOf(
            VolvoxColumn(field = "name",  header = "Name",  value = { it.name }),
            VolvoxColumn(field = "price", header = "Price",
                         value = { "%.2f".format(it.price) }, editable = true),
            VolvoxColumn(field = "qty",   header = "Qty",   value = { "${it.qty}" }),
        ),
        onCellEdit = { edit ->
            products = products.toMutableList().also { rows ->
                val p = rows[edit.rowIndex]
                rows[edit.rowIndex] = p.copy(
                    price = edit.newText.toDoubleOrNull() ?: p.price,
                )
            }
        },
        modifier = Modifier.fillMaxSize(),
    )
}
```

One thing to remember: pass a **new** list reference to refresh. Mutating in place won't trigger a reload — the composable diffs by identity.

## Low-level: VolvoxGridView and VolvoxGridController

When you need finer control — say, updating one cell out of a million, or hooking a custom validator on a specific column — drop to the controller. This is also the right path if you're not on Kotlin yet:

```java
import io.github.ivere27.volvoxgrid.*;
import io.github.ivere27.volvoxgrid.common.*;

public class MainActivity extends AppCompatActivity {
    private VolvoxGridView gridView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        gridView = findViewById(R.id.gridView);
        gridView.initialize(100, 5);

        VolvoxGridController ctrl = gridView.createController();
        ctrl.setColumnCaption(0, "Name");
        ctrl.setColumnCaption(1, "Price");
        ctrl.setColumnCaption(2, "Qty");
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

`VolvoxGridView` extends `FrameLayout` and handles rendering, touch, and the native library lifecycle. You can initialize it three ways:

```java
// Option A (recommended): auto-detect the bundled .so and create a new grid
gridView.initialize(rows, cols);

// Option B: explicit library path (advanced/manual host loading)
gridView.initialize(libraryPath, rows, cols);

// Option C: reuse an existing PluginHost and grid (multi-grid apps)
gridView.initialize(pluginHost, existingGridId);
```

The view exposes these methods once initialized:

| Method | Description |
|---|---|
| `createController()` | Create a `VolvoxGridController` for this grid |
| `getGridId()` | Get the native grid ID |
| `getService()` | Get the underlying FFI service client |
| `detachGrid()` | Stop render/event session but keep the grid alive |
| `release()` | Clean up all resources |
| `requestFrame()` | Request a render on next VSync |
| `requestFrameImmediate()` | Request a render immediately |
| `setRendererMode(mode)` | `0` Auto, `1` CPU, `2` GPU (Auto), `3` GPU (Vulkan), `4` GPU (GLES) |
| `setAndroidTextCacheSize(size)` | Compatibility hook for lite host text cache sizing |
| `setFlingFriction(friction)` | Tune scroll deceleration (0.001 – 0.15) |
| `resolveBundledLibraryPath(context)` | Resolve the bundled library `.so` path for `PluginHost.load(...)` |

From there, the controller covers grid mechanics. Here are the moves you'll reach for first.

### Grid dimensions

```java
ctrl.setRowCount(1000);
ctrl.setColCount(10);
int rows = ctrl.rowCount();
int cols = ctrl.colCount();
```

### Cell data

For a single cell, just set the text. For more than a handful, batch — the engine does one round-trip instead of many:

```java
ctrl.setCellText(row, col, "text");
String text = ctrl.getCellText(row, col);

ctrl.setCells(Arrays.asList(
    new GridCellText(0, 0, "A"),
    new GridCellText(0, 1, "B"),
    new GridCellText(1, 0, "C")
));
```

Want to wipe state? `clear()` takes a scope and a region:

```java
ctrl.clear();
ctrl.clear(ClearScope.CLEAR_DATA, ClearRegion.CLEAR_SCROLLABLE);
```

ClearScope: `CLEAR_EVERYTHING`, `CLEAR_FORMATTING`, `CLEAR_DATA`, `CLEAR_SELECTION`. ClearRegion: `CLEAR_SCROLLABLE`.

## Loading data

If you're pulling rows from a CSV file, a JSON API, or a typed `List<T>`, you have two paths into the engine. Both beat looping `setCellText`, because each one is a single RPC.

### loadData — CSV/JSON bytes

`loadData` takes raw bytes and figures out the rest. Use this when your data already lives on disk or comes off the wire:

```java
LoadDataResult loaded = ctrl.loadData(
    "name,qty\napple,3\nbanana,5".getBytes(java.nio.charset.StandardCharsets.UTF_8)
);
```

For matrix-shaped JSON (no header row), pass options:

```java
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
```

### loadTable — typed values

When you already have typed data in memory, `loadTable` skips the parsing step and ships numbers as numbers, booleans as booleans:

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

`CellValue` accepts `text`, `number`, `flag` (boolean), `raw` (bytes), and `timestamp` (epoch-ms). The schema lives in [`proto/volvoxgrid.proto`](../proto/volvoxgrid.proto).

### Built-in demos

When you just want something to look at, the engine ships test fixtures:

```java
ctrl.loadDemo("stress");                                  // 1,000,000 rows
byte[] salesJson = ctrl.getDemoData("sales");             // pair with loadData
byte[] hierarchyJson = ctrl.getDemoData("hierarchy");
```

## Editing

The grid's edit pipeline has two halves: *cancelable* events that let you veto a change before it happens, and *informational* events that fire after the fact. Set them up on `VolvoxGridView`:

```java
// Cancelable "before" events. Supported here: BeforeEdit, CellEditValidate, BeforeSort.
// Unhandled cancelable events are allowed with cancel=false when the decision channel is active.
gridView.setBeforeEditListener(details -> {
    if (details.getRow() == 0) details.setCancel(true);   // veto editing the header row
});

gridView.setCellEditValidatingListener(details -> {
    if (details.getEditText().isEmpty()) details.setCancel(true);
});

gridView.setBeforeSortListener(details -> {
    if (details.getCol() == 0) details.setCancel(true);
});

// Commit/cancel callbacks
gridView.setEditListener(new VolvoxGridView.EditCommitListener() {
    @Override public void onEditCommit(int row, int col, String text) { }
    @Override public void onEditCancel(int row, int col) { }
});

// Everything else flows through the general event stream
gridView.setEventListener(event -> {
    if (event.hasCellFocusChanged()) { /* … */ }
    if (event.hasAfterSort())        { /* … */ }
    if (event.hasAfterEdit())        { /* … */ }
});
```

The cancelable channel is a *decision* channel: when it's active the engine waits for your verdict before proceeding. If you don't set a listener, defaults take over and editing continues.

Control how editing kicks off:

```java
ctrl.setEditTrigger(EditTrigger.EDIT_TRIGGER_KEY_CLICK);
// EDIT_TRIGGER_NONE, EDIT_TRIGGER_KEY, EDIT_TRIGGER_KEY_CLICK
ctrl.beginEdit(1, 0);
ctrl.commitEdit();
```

## Renderer modes

The engine can draw with the CPU or one of two GPU backends. The default (mode 0) does the right thing on most devices, but the knob is there when you need it:

```java
ctrl.setRendererMode(2);
// 0=Auto, 1=CPU, 2=GPU(Auto), 3=GPU(Vulkan), 4=GPU(GLES)
```

A note on Android GPU support: on devices with Adreno chips, Vulkan can fail during internal capability probing (a 4×4 allocation error). If you see crashes or hangs in GPU mode, pin the renderer to **GLES** (mode `4`). Mode `2` (GPU auto) deliberately defaults to GLES on Android for that reason.

## VSync and FPS

All renderer modes are vsync-locked, so there's no manual frame cap to set:

- **CPU mode** submits frames through `ANativeWindow_unlockAndPost`, which passes through SurfaceFlinger and syncs to the display's refresh rate (typically 60 Hz).
- **GL / Vulkan modes** use wgpu with `PresentMode::Fifo` (equivalent to `VK_PRESENT_MODE_FIFO_KHR` / `eglSwapInterval(1)`). The Android host also enforces single-frame-in-flight backpressure via the `pendingFrame` semaphore.
- On 60 Hz panels both CPU and GPU target 60fps; on 120 Hz panels they target 120fps.

If you turn on the debug overlay:

```java
ctrl.setDebugOverlay(true);
```

the FPS number is an **Exponential Moving Average (EMA)** of the time to render *and* present a frame. The measurement wraps the GPU's `present()` step, which may or may not block depending on the driver and swapchain state.

- If the driver allows immediate queuing, the FPS reflects the engine's **potential performance** (often 200–300+ fps on GPU) — what it *could* do, not what's reaching the display.
- If the driver blocks during presentation, the FPS matches the display's refresh rate.
- CPU mode usually reports around 60fps because pixel fill is sequential. GPU modes usually report much higher because work is parallelized and offloaded.

The takeaway: GPU FPS in the overlay tells you about driver behavior as much as engine speed. The pixels still hit the screen at vsync either way.

## Multi-grid apps

Each `VolvoxGridView.initialize(rows, cols)` loads the native library afresh. In an app with several grids on screen at once, share a single `PluginHost`:

```java
import io.github.ivere27.synurang.PluginHost;

PluginHost pluginHost = PluginHost.load(VolvoxGridView.resolveBundledLibraryPath(this));

gridView1.initialize(pluginHost, gridId1);
gridView2.initialize(pluginHost, gridId2);
```

One process, one native runtime, many grids.

## Full vs lite

The default `volvoxgrid-android` artifact bundles everything. `volvoxgrid-android-lite` is built with `--no-default-features` on the Rust side and drops the parts you might not need:

- Built-in text engine (`cosmic-text`)
- Native GPU renderer (`wgpu`)
- Regex-based search (`regex`)
- Parallel sort processing (`rayon`)

What that means in practice:

- Smaller binary.
- CPU rendering only.
- Text shaping and rasterization happens on the host — in `VolvoxGridView`, Android callback rendering through JNI is auto-registered for you.
- The Rust runtime owns the external text mask cache used by lite mode.
- `findRowByRegex` is unavailable.
- Sorting and work generation run single-threaded.
- Demo APIs still work.
- The native filename is `libvolvoxgrid_lite.so` (the full variant is `libvolvoxgrid.so`).

Both variants bundle `arm64-v8a` and `armeabi-v7a` native libraries and require **API 21+ (Android 5.0)**.

## Runtime cache control

The engine keeps a text-layout cache to avoid re-shaping the same strings on every scroll tick. The example app exposes a `Cache` dropdown with values `8192`, `4096`, `1024`, `256`, `0`, and you can drive the same knob from your own code:

```java
ctrl.setTextLayoutCacheCap(4096);          // engine-level cap (full + lite)
gridView.setAndroidTextCacheSize(4096);    // compatibility hook for lite hosts
```

- Changes apply immediately at runtime.
- The dropdown wires straight to `ctrl.setTextLayoutCacheCap(cap)`.
- `setAndroidTextCacheSize` is kept as a compatibility hook for lite hosts; today's lite caching is owned by the Rust runtime.
- `0` disables and clears the engine text cache.

For the deeper picture on cache ownership across variants, see [../TEXT_RENDERING.md](../TEXT_RENDERING.md).

## Example app variant selection

The example app in this repo supports both variants via Make targets:

- Normal (default): `make android-run`
- Lite (local build): `make android-run VOLVOXGRID_VARIANT=lite`
- Lite (Maven): `make android-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VARIANT=lite VOLVOXGRID_VERSION=0.8.9`

`VOLVOXGRID_VARIANT` only treats `lite` as special — any other value falls back to normal.

## Reference: deeper controller APIs

When you need them, the controller covers the rest of the spreadsheet world.

### Row & column sizing

```java
ctrl.setRowHeight(0, 40);
ctrl.setColWidth(0, 200);
ctrl.autoSize(0, 4, false, 500);
//         colFrom colTo equal maxWidth
```

### Row & column operations

```java
ctrl.insertRows(5, 3);
ctrl.removeRows(5, 3);
ctrl.moveColumn(2, 0);
ctrl.moveRow(10, 0);
```

### Sorting

```java
ctrl.sort(1, true);
ctrl.sort(SortOrder.SORT_ASCENDING, 1);

ctrl.sortMulti(Arrays.asList(
    new Pair<>(0, SortOrder.SORT_ASCENDING),
    new Pair<>(1, SortOrder.SORT_DESCENDING)
));

ctrl.setHeaderFeatures(HeaderFeatures.newBuilder().setSort(true).build());
```

SortOrder: `SORT_NONE`, `SORT_ASCENDING`, `SORT_DESCENDING`.
SortType: `SORT_TYPE_AUTO`, `SORT_TYPE_NUMERIC`, `SORT_TYPE_STRING`, `SORT_TYPE_STRING_NO_CASE`, `SORT_TYPE_CUSTOM`.

### Selection

```java
ctrl.setCursorRow(5);
ctrl.setCursorCol(2);

ctrl.selectRange(1, 0, 5, 3);

ctrl.selectRanges(Arrays.asList(
    new GridCellRange(1, 0, 2, 1),
    new GridCellRange(4, 3, 6, 4)
));

ctrl.selectRanges(
    Arrays.asList(
        new GridCellRange(1, 0, 2, 1),
        new GridCellRange(4, 3, 6, 4)
    ),
    6, 4
);

GridSelection sel = ctrl.getSelection();
ctrl.setSelectionMode(SelectionMode.SELECTION_BY_ROW);
```

Selection modes: `SELECTION_FREE`, `SELECTION_BY_ROW`, `SELECTION_BY_COLUMN`, `SELECTION_LISTBOX`, `SELECTION_MULTI_RANGE`.

### Cell merging & spanning

```java
ctrl.mergeCells(0, 0, 0, 3);
ctrl.unmergeCells(0, 0, 0, 3);
CellRange range = ctrl.getMergedRange(0, 0);
MergedRegionsResponse regions = ctrl.getMergedRegions();

ctrl.setCellSpanMode(CellSpanMode.CELL_SPAN_BY_ROW);
```

CellSpanMode: `CELL_SPAN_NONE`, `CELL_SPAN_FREE`, `CELL_SPAN_BY_ROW`, `CELL_SPAN_BY_COLUMN`, `CELL_SPAN_ADJACENT`, `CELL_SPAN_HEADER_ONLY`, `CELL_SPAN_SPILL`, `CELL_SPAN_GROUP`.

### Styling

```java
ctrl.setColAlignment(1, Align.ALIGN_RIGHT_CENTER);
ctrl.setColDataType(1, ColumnDataType.COLUMN_DATA_NUMBER);
ctrl.setColFormat(1, "#,##0.00");
ctrl.setWordWrap(true);
ctrl.setEllipsis(true);
ctrl.setCellStyleRange(row1, col1, row2, col2, cellStyleOverride);
ctrl.setGridStyle(styleConfig);
```

Align: `ALIGN_LEFT_TOP`, `ALIGN_LEFT_CENTER`, `ALIGN_LEFT_BOTTOM`, `ALIGN_CENTER_TOP`, `ALIGN_CENTER_CENTER`, `ALIGN_CENTER_BOTTOM`, `ALIGN_RIGHT_TOP`, `ALIGN_RIGHT_CENTER`, `ALIGN_RIGHT_BOTTOM`, `ALIGN_GENERAL`.

ColumnDataType: `COLUMN_DATA_STRING`, `COLUMN_DATA_NUMBER`, `COLUMN_DATA_DATE`, `COLUMN_DATA_BOOLEAN`, `COLUMN_DATA_CURRENCY`.

### Subtotals & outlining

```java
ctrl.subtotal(AggregateType.AGG_SUM, 0, 2);
ctrl.setRowOutlineLevel(5, 1);
ctrl.outline(2);
ctrl.setTreeIndicator(TreeIndicatorStyle.CONNECTORS);
```

AggregateType: `AGG_SUM`, `AGG_COUNT`, `AGG_AVERAGE`, `AGG_MAX`, `AGG_MIN`, `AGG_STD_DEV`, `AGG_VAR`, `AGG_RANGE`, `AGG_COUNT_ALL`, `AGG_MEDIAN`, `AGG_COUNT_DISTINCT`, `AGG_PERCENT`, `AGG_CLEAR`.

TreeIndicatorStyle: `TREE_INDICATOR_NONE`, `ARROWS`, `ARROWS_LEAF`, `CONNECTORS`, `CONNECTORS_LEAF`.

### Clipboard

```java
ClipboardResponse copied = ctrl.copy();
ClipboardResponse cut = ctrl.cut();
ctrl.paste("tab\tseparated\nrows");
ctrl.delete();
```

### Scrolling

```java
ctrl.setTopRow(50);
int top = ctrl.topRow();
ctrl.setScrollBars(ScrollBarsMode.SCROLL_BARS_BOTH);
ctrl.setFlingEnabled(true);
ctrl.setFlingImpulseGain(80f);
ctrl.setFlingFriction(0.9f);
```

### Pin & sticky

```java
ctrl.pinRow(0, PinPosition.PIN_TOP);
ctrl.setRowSticky(5, StickyEdge.STICKY_TOP);
ctrl.setColSticky(0, StickyEdge.STICKY_LEFT);
```

PinPosition: `PIN_NONE`, `PIN_TOP`, `PIN_BOTTOM`.
StickyEdge: `STICKY_NONE`, `STICKY_TOP`, `STICKY_BOTTOM`, `STICKY_LEFT`, `STICKY_RIGHT`, `STICKY_BOTH`.

### Search

```java
int row = ctrl.findRow("Widget A", 0, 0, false);
//                      text       col startRow caseSensitive
int row2 = ctrl.findRowByRegex("^Widget.*", 0, 0);
```

`findRowByRegex` is unavailable in the lite variant.

### Aggregates

```java
double sum = ctrl.aggregate(AggregateType.AGG_SUM, 1, 1, 100, 1);
//                           type                  row1 col1 row2 col2
```

### Export & rendering knobs

```java
ExportResponse exported = ctrl.saveGrid(ExportFormat.EXPORT_BINARY);

ctrl.setAnimationEnabled(true, 250);
ctrl.setTextLayoutCacheCap(4096);

ctrl.setRedraw(false);
// ... make many changes ...
ctrl.setRedraw(true);
ctrl.refresh();

// Or the lambda form:
ctrl.withRedrawSuspended(() -> {
    ctrl.setCellText(0, 0, "A");
    ctrl.setCellText(0, 1, "B");
    ctrl.setCellText(1, 0, "C");
});
```

## Kotlin equivalents

Everything above works identically from Kotlin — method names match. A condensed tour:

```kotlin
val gridView: VolvoxGridView = findViewById(R.id.gridView)
gridView.initialize(rows = 100, cols = 5)

val ctrl = gridView.createController()

ctrl.setRowCount(1000)
ctrl.setColCount(10)
ctrl.setCursorRow(5)
ctrl.setCursorCol(2)

ctrl.setCellText(0, 0, "Name")
ctrl.setCells(listOf(
    GridCellText(0, 0, "A"),
    GridCellText(0, 1, "B"),
))

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

ctrl.loadTable(2, 3, listOf(
    CellValue.newBuilder().setText("Widget A").build(),
    CellValue.newBuilder().setNumber(29.99).build(),
    CellValue.newBuilder().setNumber(150.0).build(),
    CellValue.newBuilder().setText("Widget B").build(),
    CellValue.newBuilder().setNumber(49.99).build(),
    CellValue.newBuilder().setNumber(200.0).build(),
))

ctrl.withRedrawSuspended {
    ctrl.setCellText(0, 0, "A")
    ctrl.setCellText(0, 1, "B")
    ctrl.setCellText(1, 0, "C")
}

ctrl.sort(col = 1, ascending = true)
ctrl.sortMulti(listOf(
    Pair(0, SortOrder.SORT_ASCENDING),
    Pair(1, SortOrder.SORT_DESCENDING),
))

ctrl.selectRange(row1 = 1, col1 = 0, row2 = 5, col2 = 3)
ctrl.selectRanges(
    ranges = listOf(
        GridCellRange(1, 0, 2, 1),
        GridCellRange(4, 3, 6, 4),
    ),
    activeRow = 6,
    activeCol = 4,
)

gridView.eventListener = object : VolvoxGridView.GridEventListener {
    override fun onGridEvent(event: GridEvent) {
        when {
            event.hasCellFocusChanged() -> { /* ... */ }
            event.hasAfterSort() -> { /* ... */ }
            event.hasAfterEdit() -> { /* ... */ }
        }
    }
}

gridView.beforeEditListener = VolvoxGridView.BeforeEditListener { details ->
    if (details.row == 0) details.cancel = true
}
gridView.cellEditValidatingListener = VolvoxGridView.CellEditValidatingListener { details ->
    if (details.editText.isBlank()) details.cancel = true
}
gridView.beforeSortListener = VolvoxGridView.BeforeSortListener { details ->
    if (details.col == 0) details.cancel = true
}
gridView.editListener = object : VolvoxGridView.EditCommitListener {
    override fun onEditCommit(row: Int, col: Int, text: String) { }
    override fun onEditCancel(row: Int, col: Int) { }
}

gridView.release()
```

## Troubleshooting

A few things you'll likely hit early:

- **"Library not found" / `UnsatisfiedLinkError`.** The AAR bundles `arm64-v8a` and `armeabi-v7a`. If your app filters ABIs (via `ndk { abiFilters }` or split APKs), make sure those two are included. For non-bundled flows, pass an explicit path to `gridView.initialize(libraryPath, rows, cols)` or load through `PluginHost.load(VolvoxGridView.resolveBundledLibraryPath(context))`.
- **Crashes or freezes in GPU mode on Adreno devices.** Pin the renderer to GLES with `ctrl.setRendererMode(4)` or `gridView.setRendererMode(4)`. Vulkan capability probing fails on some Adreno drivers.
- **Lite text looks different from full.** Lite uses host-driven text shaping through an Android JNI callback, while full uses the bundled `cosmic-text` engine. Glyph metrics and emoji rendering can differ — see [../TEXT_RENDERING.md](../TEXT_RENDERING.md) for the details and cache implications.
- **Compose grid doesn't refresh after mutating my list.** Pass a *new* list reference. The composable compares by identity, so `rows.add(x)` won't trigger a reload but `rows = rows + x` will.

## What's next

- [../TEXT_RENDERING.md](../TEXT_RENDERING.md) — how full and lite render text, who owns the caches, and what differs in practice.
- [../ARCHITECTURE.md](../ARCHITECTURE.md) — the engine architecture: pixel buffers, FFI surface, render loop.

## License

[Apache License 2.0](../LICENSE)
