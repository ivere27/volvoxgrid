# VolvoxGrid for Java desktop

Welcome. VolvoxGrid is a datagrid for Java Swing that draws every pixel itself. A Rust engine renders rows, columns, headers, selection, and editors into a shared pixel buffer, and the Swing host composites that buffer into a `JComponent`. You get native-feeling performance on a million rows, identical look across Linux, macOS, and Windows, and a small, predictable API that fits naturally next to `JTable`.

This page is the full guide. If you just want to skim the in-source samples, see [desktop/README.md](desktop/README.md).

## Quick start

Add the dependency, drop a panel into a frame, hand it a typed row list, and you have an editable grid. Here is the whole thing.

`build.gradle.kts`:

```kotlin
repositories {
    mavenCentral()
}

dependencies {
    implementation("io.github.ivere27:volvoxgrid-desktop:0.8.9")
    // or: implementation("io.github.ivere27:volvoxgrid-desktop-lite:0.8.9")
}
```

`App.java`:

```java
import io.github.ivere27.volvoxgrid.desktop.*;
import javax.swing.*;
import java.util.*;

public class App {
    static final class Product {
        final String name; final double price; final int qty;
        Product(String name, double price, int qty) {
            this.name = name; this.price = price; this.qty = qty;
        }
        String getName()  { return name; }
        double getPrice() { return price; }
        int    getQty()   { return qty; }
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            JFrame frame = new JFrame("VolvoxGrid");
            VolvoxGridDesktopPanel panel = new VolvoxGridDesktopPanel();
            panel.initialize(null, 100, 3); // null = auto-detect native library

            List<Product> products = new ArrayList<>(Arrays.asList(
                new Product("Widget A", 29.99, 150),
                new Product("Widget B", 19.50,  80)
            ));

            VolvoxGridTableModelAdapter<Product> adapter =
                new VolvoxGridTableModelAdapter<>(panel, Arrays.asList(
                    VolvoxGridTableModelAdapter.column  ("name",  "Name",  Product::getName),
                    VolvoxGridTableModelAdapter.editable("price", "Price",
                        p -> String.format("%.2f", p.getPrice())),
                    VolvoxGridTableModelAdapter.column  ("qty",   "Qty",
                        p -> Integer.toString(p.getQty()))
                ));
            adapter.setOnCellEdit(edit -> {
                Product p = edit.getRow();
                try {
                    products.set(edit.getRowIndex(), new Product(
                        p.getName(),
                        Double.parseDouble(edit.getNewText()),
                        p.getQty()
                    ));
                } catch (NumberFormatException ignore) { }
            });
            adapter.setRows(products);

            frame.setContentPane(panel);
            frame.setSize(800, 600);
            frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
            frame.setVisible(true);
        });
    }
}
```

Run it. You'll see three columns, two rows, and the "Price" column accepting edits. Try typing a new number into a Price cell — the change flows through `setOnCellEdit` so your `products` list stays the source of truth.

## What you just built

The fast path uses two pieces. `VolvoxGridDesktopPanel` is the `JPanel` you add to your frame; it owns the native library, the render loop, and the input pipeline. `VolvoxGridTableModelAdapter<T>` is a small typed wrapper modeled after Swing's `TableModel` idiom — you describe columns once, pass a row list, and edits surface through one callback.

Passing `null` as the first argument to `panel.initialize(...)` is intentional. The panel runs the library-resolution chain for you (env var, classpath, workspace fallback) and loads the right native binary for your OS and architecture. There is no `LD_LIBRARY_PATH` to set.

**Requirements:** Java 8 or newer. The Maven JAR bundles native libraries for Linux (x86, x86_64, armv7, aarch64), macOS (x86_64, aarch64), and Windows (x86, x86_64), named `libvolvoxgrid.so`, `libvolvoxgrid.dylib`, and `volvoxgrid.dll`.

## Two paths: adapter or controller

You have two ways to drive the grid, and you can mix them freely on the same panel.

- **`VolvoxGridTableModelAdapter<T>`** — data-first. You hand it typed rows and column descriptors. Best when your data already lives in `List<T>` and you want edits to flow back to that list.
- **`VolvoxGridDesktopPanel` + `VolvoxGridDesktopController`** — engine-first. You write cells, captions, sizes, and selections directly. Best when you need partial updates, programmatic sorts, merged regions, subtotals, or custom dropdown sources.

The adapter uses the controller under the hood, so anything you can do with one, you can do alongside the other.

## Low-level: panel and controller

Use the controller when you want direct command of the engine. You create a panel the same way, then ask it for a controller.

```java
VolvoxGridDesktopPanel panel = new VolvoxGridDesktopPanel();
panel.initialize(null, 100, 5);

VolvoxGridDesktopController ctrl = panel.createController();
ctrl.setColumnCaption(0, "Name");
ctrl.setColumnCaption(1, "Price");
ctrl.setColumnCaption(2, "Qty");

ctrl.setCellText(0, 0, "Widget A");
ctrl.setCellText(0, 1, "29.99");
ctrl.setCellText(0, 2, "150");
```

The panel itself has a handful of methods you'll reach for often.

| Method | When you'd use it |
|---|---|
| `createController()` | Get a `VolvoxGridDesktopController` for this grid |
| `getGridId()` | Get the native grid ID (for multi-grid wiring) |
| `getServiceClient()` | Get the underlying RPC client |
| `detachGrid()` | Stop the render/event session while keeping the grid alive |
| `release()` | Clean up everything on close |
| `requestFrame()` | Queue a render on the next repaint |
| `requestFrameImmediate()` | Render right now |
| `setRendererBackend(backend)` | `CPU`, `GPU`, or `AUTO` |
| `setRendererMode(mode)` | Pick a specific renderer (see below) |
| `isGpuSupported()` | Check whether the loaded native library exposes GPU rendering |
| `setHostFlingEnabled(enabled)` | Toggle momentum scrolling at the host |

## Loading data

You typically load a grid in one of two ways.

`loadData(bytes)` parses CSV or JSON and figures out the shape for you. Use it when you have a file or an HTTP response and don't want to type each value.

```java
LoadDataResult loaded = ctrl.loadData(
    "name,qty\napple,3\nbanana,5".getBytes(java.nio.charset.StandardCharsets.UTF_8));
```

`loadTable(rows, cols, values, atomic)` is the typed, bulk path. Use it when you already know the shape and want the engine to apply the whole table in one round trip.

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

`CellValue` carries one of `text`, `number`, `flag` (boolean), `raw` (bytes), or `timestamp` (epoch-ms). For the full schema, look at [`proto/volvoxgrid.proto`](../proto/volvoxgrid.proto) and the generated protobuf classes.

Cells, ranges, and clearing are direct:

```java
ctrl.setCellText(row, col, "text");
String text = ctrl.getCellText(row, col);

ctrl.setCells(Arrays.asList(
    new GridCellText(0, 0, "A"),
    new GridCellText(0, 1, "B"),
    new GridCellText(1, 0, "C")
));

CellsResponse resp = ctrl.getCells(GetCellsRequest.newBuilder()
    .setRow1(0).setCol1(0).setRow2(1).setCol2(2)
    .build());

ctrl.clear(ClearScope.CLEAR_EVERYTHING, ClearRegion.CLEAR_SCROLLABLE);
```

`ClearScope` is one of `CLEAR_EVERYTHING`, `CLEAR_FORMATTING`, `CLEAR_DATA`, `CLEAR_SELECTION`. `ClearRegion` selects which band of the grid the clear applies to.

## Editing and events

Listening for what the user did is one listener; vetoing what they're about to do is another. You'll use both in any non-trivial app.

```java
gridPanel.setGridEventListener(event -> {
    if (event.hasCellFocusChanged()) {
        CellFocusChanged e = event.getCellFocusChanged();
        System.out.println("Moved to row=" + e.getNewRow() + " col=" + e.getNewCol());
    }
    if (event.hasAfterSort()) { /* sort completed */ }
    if (event.hasAfterEdit()) { /* cell edited */ }
});
```

`BeforeEdit`, `CellEditValidate`, and `BeforeSort` are cancelable. If you don't handle a cancelable event, it proceeds as if you set `cancel=false`, as long as the decision channel is active.

```java
gridPanel.setBeforeEditListener(details -> {
    if (details.getRow() == 0) details.setCancel(true);
});

gridPanel.setCellEditValidatingListener(details -> {
    if (details.getEditText().isEmpty()) details.setCancel(true);
});

gridPanel.setBeforeSortListener(details -> {
    if (details.getCol() == 0) details.setCancel(true);
});

gridPanel.setEditorSessionStartedListener(session -> {
    // wire up an inline editor session
});
```

Enable editing globally with `ctrl.setEditable(true)`.

## Renderer modes

VolvoxGrid renders into a CPU pixel buffer by default. Full desktop builds can also render onto a real native surface using `wgpu`, which is faster on large grids and animated viewports. The lite build is CPU-only, so GPU modes are rejected by capability checks.

Pick a mode on the controller when you want to be explicit:

```java
ctrl.setRendererModeCpu();
ctrl.setRendererModeGpu();          // auto-pick the best GPU backend
ctrl.setRendererModeGpuVulkan();
ctrl.setRendererModeGpuGles();
ctrl.setRendererModeGpuOpenGl();
ctrl.setRendererModeGpuDx12();
ctrl.setRendererModeGpuMetal();
```

Or set it on the panel with `setRendererMode(...)` using the enum: `RENDERER_CPU`, `RENDERER_GPU`, `RENDERER_GPU_VULKAN`, `RENDERER_GPU_GLES`, `RENDERER_GPU_OPENGL`, `RENDERER_GPU_DX12`, `RENDERER_GPU_METAL`.

Use `panel.isGpuSupported()` to test the loaded library at runtime — handy when you ship both variants from one app.

## Sorting

Sort programmatically or let users click headers.

```java
ctrl.sort(1, true);                       // col 1, ascending
ctrl.sort(SortOrder.SORT_ASCENDING, 1);

ctrl.configure(
    GridConfig.newBuilder()
        .setInteraction(
            InteractionConfig.newBuilder()
                .setHeaderFeatures(HeaderFeatures.newBuilder().setSort(true).build())
                .build()
        )
        .build()
);
```

| Enum | Values |
|---|---|
| `SortOrder` | `SORT_NONE`, `SORT_ASCENDING`, `SORT_DESCENDING` |
| `SortType` | `SORT_TYPE_AUTO`, `SORT_TYPE_NUMERIC`, `SORT_TYPE_STRING`, `SORT_TYPE_STRING_NO_CASE`, `SORT_TYPE_CUSTOM` |

## Selection

```java
ctrl.selectRange(1, 0, 5, 3);             // row1, col1, row2, col2

ctrl.selectRanges(Arrays.asList(
    new GridCellRange(1, 0, 2, 1),
    new GridCellRange(4, 3, 6, 4)
));

ctrl.selectRanges(
    Arrays.asList(new GridCellRange(1, 0, 2, 1), new GridCellRange(4, 3, 6, 4)),
    6, 4                                  // explicit active cell
);

GridSelection sel = ctrl.getSelection();
// sel.getRow(), sel.getCol(), sel.getRowEnd(), sel.getColEnd(),
// sel.getTopRow(), sel.getLeftCol(), sel.getRanges()
```

## Merged cells

```java
ctrl.mergeCells(0, 0, 0, 3);
ctrl.unmergeCells(0, 0, 0, 3);
CellRange range = ctrl.getMergedRange(0, 0);
MergedRegionsResponse regions = ctrl.getMergedRegions();
```

## Subtotal and outline

Add aggregate rows under groups, or collapse rows by outline level.

```java
ctrl.subtotal(SubtotalRequest.newBuilder()
    .setGridId(ctrl.getGridId())
    .setAggregateType(AggregateType.AGG_SUM)
    .setGroupOnCol(0)
    .setAggregateCol(2)
    .build());

ctrl.outline(OutlineRequest.newBuilder()
    .setGridId(ctrl.getGridId())
    .setLevel(2)
    .build());
```

## Clipboard

```java
ClipboardResponse copied = ctrl.copy();
ClipboardResponse cut    = ctrl.cut();
ctrl.paste("tab\tseparated\nrows");
ctrl.deleteSelection();
```

## Search

```java
int row  = ctrl.findRow("Widget A", 0, 0, false); // text, col, startRow, caseSensitive
int row2 = ctrl.findRowByRegex("^Widget.*", 0, 0);
```

Regex search is only available in the full variant.

## Aggregates

```java
double sum = ctrl.aggregate(AggregateType.AGG_SUM, 1, 1, 100, 1);
```

Aggregate types: `AGG_SUM`, `AGG_COUNT`, `AGG_AVERAGE`, `AGG_MAX`, `AGG_MIN`, `AGG_STD_DEV`, `AGG_VAR`, `AGG_RANGE`, `AGG_COUNT_ALL`, `AGG_MEDIAN`, `AGG_COUNT_DISTINCT`.

## Export and load

```java
ExportResponse exported = ctrl.saveGrid(ExportFormat.EXPORT_BINARY, ExportScope.EXPORT_ALL);
LoadDataResult loaded   = ctrl.loadData(bytes);
```

`saveGrid` exports; `loadData` parses CSV or JSON bytes and populates the grid.

## Viewport, sizing, and rendering control

```java
ctrl.setRowCount(1000);
ctrl.setColCount(10);
ctrl.setRowHeight(0, 40);
ctrl.setColWidth(0, 200);

ctrl.resizeViewport(800, 600);

ctrl.setDebugOverlay(true);
ctrl.setScrollBars(ScrollBarsMode.SCROLL_BARS_BOTH);
ctrl.setFlingEnabled(true);

ctrl.setRedraw(false);          // batch many changes
// ... lots of edits ...
ctrl.setRedraw(true);
ctrl.refresh();                 // force a full repaint
```

## Built-in demos

Handy for benchmarking and for screenshots:

```java
ctrl.loadDemo("stress");                              // 1,000,000 rows
byte[] salesJson     = ctrl.getDemoData("sales");     // pair with loadData + setup
byte[] hierarchyJson = ctrl.getDemoData("hierarchy"); // pair with loadData + setup
```

## Multi-grid apps

When you show several grids side by side, share one bridge so they cooperate over a single RPC channel.

```java
SynurangDesktopBridge bridge = SynurangDesktopBridge.load(libraryPath);

panel1.initialize(bridge, gridId1);
panel2.initialize(bridge, gridId2);
```

`SynurangDesktopBridge.load(...)` accepts the same library-path argument shape as the panel — pass `null` to use auto-detection.

## Full versus lite

There are two artifacts:

| Artifact | When to choose it |
|---|---|
| `io.github.ivere27:volvoxgrid-desktop:0.8.9` | Default. Includes the built-in Rust text engine, GPU renderer, regex search, and rayon parallelism. |
| `io.github.ivere27:volvoxgrid-desktop-lite:0.8.9` | Smaller footprint. CPU-only. Uses Java2D for OS font fallback. No GPU, no regex search. |

In the lite variant, the Swing wrapper auto-registers a Java2D text renderer when the loaded native library has no built-in text engine. The Rust runtime still owns the external text mask cache — Java2D only measures and rasterizes on cache misses, with a small Java-side `Font` object cache to keep allocation under control. See [../TEXT_RENDERING.md](../TEXT_RENDERING.md) for the full ownership and lifecycle story.

## How the native library is found

When you call `panel.initialize(null, rows, cols)`, the panel walks this chain and uses the first hit:

1. The first command-line argument passed to your `main`.
2. The `VOLVOXGRID_LIBRARY_PATH` environment variable.
3. The bundled native library on the classpath (this is what the Maven JAR provides).
4. A development build under the workspace `target/debug/` or `target/release/` directory.

If you already have a path in hand — for example from a packaging step — pass it explicitly: `panel.initialize("/opt/myapp/libvolvoxgrid.so", rows, cols)`.

## Local development

When you've cloned the repo and want to iterate on the samples, the Makefile drives everything.

```bash
# Run the desktop sample against the locally built native library.
make java-desktop-run
make java-desktop-run-release

# Run against the published Maven artifact instead.
make java-desktop-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VERSION=0.8.9

# Lite variant.
make java-desktop-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VARIANT=lite VOLVOXGRID_VERSION=0.8.9
make java-desktop-run-release VOLVOXGRID_VARIANT=lite
```

## TUI sample

The repo also ships a Unix-oriented terminal sample that uses the thin TUI byte-stream path. Useful for SSH sessions, CI smoke tests, and headless servers.

```bash
make java-tui-run
make java-tui-smoke
```

The corresponding `VolvoxGridDesktopTuiExample.java` lives next to the Swing demos.

## What's next

- [../TEXT_RENDERING.md](../TEXT_RENDERING.md) — how the engine and the host divide responsibility for text shaping, the external mask cache, and OS font fallback.
- [../TUI.md](../TUI.md) — the terminal-host integration in depth.
- [../ARCHITECTURE.md](../ARCHITECTURE.md) — the engine, the RPC channel, and how host adapters fit on top.
- [desktop/README.md](desktop/README.md) — the in-source pointer next to the runnable samples.

## License

[Apache License 2.0](../LICENSE)
