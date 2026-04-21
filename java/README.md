# VolvoxGrid for Java Desktop

A high-performance datagrid panel for Java Swing applications. Renders directly to pixel buffers with CPU rendering. Supports cell editing, sorting, merged cells, scrolling, and more.

The repo also includes a Unix-oriented terminal sample that uses the thin TUI byte-stream path:

```bash
make java-tui-run
make java-tui-smoke
```

## Installation

Add the Maven dependency to your `build.gradle.kts`:

```kotlin
repositories {
    mavenCentral()
}

dependencies {
    implementation("io.github.ivere27:volvoxgrid-desktop:0.7.1")
}
```

The JAR bundles native libraries for Linux (x86, x86_64, armv7, aarch64), macOS (x86_64, aarch64), and Windows (x86, x86_64).

**Requirements:** Java 8+

## Quick Start

```java
import io.github.ivere27.volvoxgrid.desktop.*;
import javax.swing.*;
import java.awt.*;

public class MyApp {
    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            JFrame frame = new JFrame("VolvoxGrid");
            frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
            frame.setSize(800, 600);

            VolvoxGridDesktopPanel gridPanel = new VolvoxGridDesktopPanel();
            frame.add(gridPanel, BorderLayout.CENTER);
            frame.setVisible(true);

            // Initialize: loads the native plugin and creates a grid
            gridPanel.initialize(
                null,  // auto-detect plugin path from JAR
                100,   // rows
                5      // cols
            );

            // Get a controller for grid operations
            VolvoxGridDesktopController ctrl = gridPanel.createController();

            // Set column headers in the top indicator band
            ctrl.setColumnCaption(0, "Name");
            ctrl.setColumnCaption(1, "Price");
            ctrl.setColumnCaption(2, "Qty");

            // Set data
            ctrl.setCellText(0, 0, "Widget A");
            ctrl.setCellText(0, 1, "29.99");
            ctrl.setCellText(0, 2, "150");

            // Clean up on close
            frame.addWindowListener(new java.awt.event.WindowAdapter() {
                @Override
                public void windowClosing(java.awt.event.WindowEvent e) {
                    gridPanel.release();
                }
            });
        });
    }
}
```

### Plugin Path Resolution

When using the Maven JAR, the native plugin is bundled and extracted automatically. If you need manual control, the plugin path is resolved in this order:

1. First command-line argument
2. `VOLVOXGRID_PLUGIN_PATH` environment variable
3. Bundled native library from classpath (Maven JAR)
4. Auto-detect in `target/debug/` or `target/release/`

## API Reference

### VolvoxGridDesktopPanel

A Swing `JPanel` that hosts the grid. Handles rendering, mouse/keyboard input, and the native plugin lifecycle.

#### Initialization

```java
// Option A: Auto-detect or specify plugin path
gridPanel.initialize(pluginPath, rows, cols);

// Option B: Reuse an existing bridge and grid (for multi-grid apps)
gridPanel.initialize(bridge, existingGridId);
```

#### Panel Methods

| Method | Description |
|---|---|
| `createController()` | Create a `VolvoxGridDesktopController` for this grid |
| `getGridId()` | Get the native grid handle ID |
| `getServiceClient()` | Get the underlying RPC client |
| `detachGrid()` | Stop render/event session but keep the grid alive |
| `release()` | Clean up all resources |
| `requestFrame()` | Request a render on next repaint |
| `requestFrameImmediate()` | Request a render immediately |
| `setRendererBackend(backend)` | `CPU`, `GPU`, or `AUTO` |
| `isGpuSupported()` | Check if GPU rendering is available |
| `setHostFlingEnabled(enabled)` | Enable/disable momentum scrolling |

#### Event Listeners

```java
// Grid events (selection change, sort, edit, etc.)
gridPanel.setGridEventListener(event -> {
    if (event.hasCellFocusChanged()) {
        var e = event.getCellFocusChanged();
        System.out.println("Moved to row=" + e.getNewRow() + " col=" + e.getNewCol());
    }
    if (event.hasAfterSort()) { /* sort completed */ }
    if (event.hasAfterEdit()) { /* cell edited */ }
});

// Cancelable "before" events. Supported here: BeforeEdit, CellEditValidate, BeforeSort.
gridPanel.setBeforeEditListener(details -> {
    if (details.getRow() == 0) {
        details.setCancel(true);
    }
});

gridPanel.setCellEditValidatingListener(details -> {
    if (details.getEditText().isEmpty()) {
        details.setCancel(true);
    }
});

gridPanel.setBeforeSortListener(details -> {
    if (details.getCol() == 0) {
        details.setCancel(true);
    }
});

// Edit request callback
gridPanel.setEditRequestListener(request -> {
    // handle inline edit requests
});
```

### VolvoxGridDesktopController

High-level API for grid operations. Obtained via `gridPanel.createController()`.

#### Grid Dimensions

```java
ctrl.setRowCount(1000);
ctrl.setColCount(10);
```

#### Cell Data

```java
// Single cell
ctrl.setCellText(row, col, "text");
String text = ctrl.getCellText(row, col);

// Batch update
ctrl.setCells(List.of(
    new GridCellText(0, 0, "A"),
    new GridCellText(0, 1, "B"),
    new GridCellText(1, 0, "C")
));

// Read a range of cells via proto
CellsResponse resp = ctrl.getCells(GetCellsRequest.newBuilder()
    .setRow1(0).setCol1(0).setRow2(1).setCol2(2)
    .build());
for (CellData cell : resp.getCellsList()) {
    System.out.println(cell.getRow() + "," + cell.getCol() + " = " + cell.getValue().getText());
}

// Clear all data
ctrl.clear(ClearScope.CLEAR_EVERYTHING, ClearRegion.CLEAR_SCROLLABLE);

// Clear only data (keep formatting)
ctrl.clear(ClearScope.CLEAR_DATA, ClearRegion.CLEAR_SCROLLABLE);
// Scopes: CLEAR_EVERYTHING, CLEAR_FORMATTING, CLEAR_DATA, CLEAR_SELECTION
```

#### LoadTable

`loadTable` bulk-loads a row-major flat array of typed `CellValue` entries in a single RPC call.

```java
ctrl.loadTable(2, 3, List.of(
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
```

#### Sorting

```java
// Simple sort
ctrl.sort(1, true);  // col 1, ascending

// With sort order enum
ctrl.sort(SortOrder.SORT_ASCENDING, 1);

// Configure header features with the generated proto message
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

**SortOrder values:** `SORT_NONE`, `SORT_ASCENDING`, `SORT_DESCENDING`

**SortType values:** `SORT_TYPE_AUTO`, `SORT_TYPE_NUMERIC`, `SORT_TYPE_STRING`, `SORT_TYPE_STRING_NO_CASE`, `SORT_TYPE_CUSTOM`

#### Selection

```java
// Select a range
ctrl.selectRange(1, 0, 5, 3);  // row1, col1, row2, col2

// Select multiple ranges
ctrl.selectRanges(List.of(
    new GridCellRange(1, 0, 2, 1),
    new GridCellRange(4, 3, 6, 4)
));

// Select multiple ranges with an explicit active cell
ctrl.selectRanges(
    List.of(
        new GridCellRange(1, 0, 2, 1),
        new GridCellRange(4, 3, 6, 4)
    ),
    6,
    4
);

// Get current selection
GridSelection sel = ctrl.getSelection();
// sel.getRow(), sel.getCol(), sel.getRowEnd(), sel.getColEnd(), sel.getTopRow(), sel.getLeftCol(), sel.getRanges()
```

#### Cell Merging

```java
ctrl.mergeCells(0, 0, 0, 3);     // merge row 0, cols 0-3
ctrl.unmergeCells(0, 0, 0, 3);
CellRange range = ctrl.getMergedRange(0, 0);
MergedRegionsResponse regions = ctrl.getMergedRegions();
```

#### Editing

```java
ctrl.setEditable(true);
```

#### Subtotals & Outlining

```java
// Add subtotal rows
ctrl.subtotal(SubtotalRequest.newBuilder()
    .setGridId(ctrl.getGridId())
    .setAggregateType(AggregateType.AGG_SUM)
    .setGroupOnCol(0)
    .setAggregateCol(2)
    .build());

// Outline levels
ctrl.outline(OutlineRequest.newBuilder()
    .setGridId(ctrl.getGridId())
    .setLevel(2)
    .build());
```

#### Clipboard

```java
ClipboardResponse copied = ctrl.copy();
ClipboardResponse cut = ctrl.cut();
ctrl.paste("tab\tseparated\nrows");
ctrl.deleteSelection();
```

#### Search

```java
int row = ctrl.findRow("Widget A", 0, 0, false);  // text, col, startRow, caseSensitive
int row2 = ctrl.findRowByRegex("^Widget.*", 0, 0);
```

#### Aggregates

```java
double sum = ctrl.aggregate(AggregateType.AGG_SUM, 1, 1, 100, 1);
// AGG_SUM, AGG_COUNT, AGG_AVERAGE, AGG_MAX, AGG_MIN, AGG_STD_DEV, AGG_VAR
```

#### Export & LoadData

```java
ExportResponse exported = ctrl.saveGrid(ExportFormat.EXPORT_BINARY, ExportScope.EXPORT_ALL);
LoadDataResult loaded = ctrl.loadData("name,qty\napple,3\nbanana,5".getBytes(java.nio.charset.StandardCharsets.UTF_8));
// loadData parses CSV or JSON bytes; saveGrid remains export-only.
```

#### Rendering

```java
ctrl.setDebugOverlay(true);       // show debug grid overlay
ctrl.setScrollBars(ScrollBarsMode.SCROLL_BARS_BOTH);
ctrl.setFlingEnabled(true);       // momentum scrolling
ctrl.setRedraw(false);            // batch: disable rendering
// ... make many changes ...
ctrl.setRedraw(true);             // re-enable and repaint
ctrl.refresh();                   // force full repaint
```

#### Viewport

```java
ctrl.resizeViewport(800, 600);
```

#### Built-in Demos

```java
ctrl.loadDemo("stress");      // 1,000,000 rows for performance testing

byte[] salesJson = ctrl.getDemoData("sales");           // pair with loadData + explicit setup
byte[] hierarchyJson = ctrl.getDemoData("hierarchy");   // pair with loadData + explicit setup
```

## Multi-Grid Apps

Share a single bridge across multiple grids:

```java
SynurangDesktopBridge bridge = SynurangDesktopBridge.load(pluginPath);

gridPanel1.initialize(bridge, gridId1);
gridPanel2.initialize(bridge, gridId2);
```

## License

[Apache License 2.0](../LICENSE)
