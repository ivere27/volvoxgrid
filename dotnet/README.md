# VolvoxGrid for .NET

VolvoxGrid is a pixel-rendered datagrid for .NET. A native Rust engine draws every cell, header, and edit overlay into a shared pixel buffer, which `VolvoxGridControl` blits inside a WinForms control or `VolvoxGridClient` exposes headlessly on `.NET 8`. You get one managed assembly (`VolvoxGrid.DotNet.dll`), one native dependency (`volvoxgrid.dll`, `libvolvoxgrid.so`, or `libvolvoxgrid.dylib`), and a familiar managed surface for binding, editing, sorting, selection, merged cells, clipboard, search, and large datasets.

## Quick start

Add the package and run the snippet below. If you're on Windows targeting WinForms, this is the shortest path from zero to a live grid.

```bash
dotnet add package VolvoxGrid.DotNet --version 0.8.9
```

```csharp
using System;
using System.Data;
using System.Windows.Forms;
using VolvoxGrid.DotNet;

public sealed class MainForm : Form
{
    private readonly VolvoxGridControl _grid = new VolvoxGridControl
    {
        Dock = DockStyle.Fill,
        Editable = true,
        MultiSelect = true,
        RendererMode = VolvoxGridRendererMode.Auto,
        HeaderFeatures = new VolvoxGridHeaderFeatures { Sort = true, Reorder = true },
    };

    public MainForm()
    {
        Text = "VolvoxGrid";
        Width = 1000; Height = 700;

        var table = new DataTable();
        table.Columns.Add("Name", typeof(string));
        table.Columns.Add("Price", typeof(decimal));
        table.Columns.Add("Qty", typeof(int));
        table.Rows.Add("Widget A", 29.99m, 150);
        table.Rows.Add("Widget B", 49.99m, 200);
        table.Rows.Add("Widget C", 12.50m, 90);

        _grid.SetDataBinding(table, null);
        _grid.CellValueChanged += (s, e) => Console.WriteLine($"{e.FieldName} -> {e.Value}");

        Controls.Add(_grid);
    }

    [STAThread]
    public static void Main() => Application.Run(new MainForm());
}
```

## What you just built

You created a top-level `Form` whose only child is a `VolvoxGridControl` docked to fill it. The control discovered three columns from your `DataTable` (no `SetColumns` call required), loaded the three rows, and wired itself up so any in-place edit fires `CellValueChanged`. The Rust engine handles painting, hit testing, scrolling, header sort, and clipboard. You write managed code; the engine paints pixels.

If the form launched but the grid stayed empty, the most likely cause is that the native library can't be found. Jump to "Native library deployment" before debugging your binding.

## Two paths

You'll pick one of these depending on what you're shipping.

- **`VolvoxGridControl`** for desktop UI. A WinForms `Control` that hosts the engine, handles input, and blits the rendered buffer. Targets `net8.0-windows` (recommended) or `net40` (legacy WinForms apps).
- **`VolvoxGridClient`** for cross-platform headless use. A managed wrapper around the same engine without any WinForms dependency. Use it from `net8.0` services, test harnesses, code generators, or any host that owns its own surface (including the TUI session described later).

Both speak to the same Rust engine and share most of the API surface. Differences are noted inline.

## Targets and packages

| Target framework | Status | Notes |
|---|---|---|
| `net8.0` | Supported | Cross-platform `VolvoxGridClient` |
| `net8.0-windows` | Recommended | WinForms via `VolvoxGridControl` |
| `net40` | Supported | Legacy WinForms |

Two NuGet packages ship from the same source:

- `VolvoxGrid.DotNet` — full native runtime: built-in `cosmic-text` rendering, GPU backends via `wgpu`, regex search, rayon parallelism.
- `VolvoxGrid.DotNet.Lite` — slim runtime: no `cosmic-text`, no `wgpu` GPU, no regex, no rayon. Text routes through GDI/GDI+. The Rust-owned external text mask cache shows up as `C:<used>/<cap>` in the debug overlay.

The namespace is `VolvoxGrid.DotNet` in both packages. The main types you'll touch are `VolvoxGridControl`, `VolvoxGridClient`, `VolvoxGridTerminalSession`, `VolvoxGridTerminalFrame`, `VolvoxGridTerminalCapabilities`, `VolvoxGridColumn`, `VolvoxGridCellText`, `VolvoxGridSelectionState`, and `VolvoxGridCellRange`. The enums you'll reach for most are `VolvoxGridRendererMode`, `VolvoxGridSelectionMode`, `VolvoxGridHeaderFeatures`, `VolvoxGridResizePolicy`, `VolvoxGridColumnDataType`, and `VolvoxGridSortDirection`.

## WinForms: `VolvoxGridControl` in depth

You use `VolvoxGridControl` when you want a real WinForms control you can drop into a `Form`, dock, anchor, and bind. It accepts the binding shapes WinForms developers already expect, so most of the time you don't have to think about columns at all.

### Binding sources

`SetDataBinding(source, member)` (or the `DataSource` / `DataMember` properties) accepts:

- `DataTable`
- `DataView`
- `BindingSource`
- `DataSet` together with a `DataMember` string
- any `IList` or `IEnumerable` of POCOs
- any `IList` or `IEnumerable` of dictionaries
- any `IList` or `IEnumerable` of simple values
- two-dimensional arrays

```csharp
var bindingSource = new BindingSource { DataSource = ordersTable };
grid.SetDataBinding(bindingSource, null);

grid.SetDataBinding(dataSet, "Orders");
grid.SetDataBinding(myPocoList, null);
```

### Column inference vs manual columns

If you don't call `SetColumns`, the control infers columns from the source: column names from `DataTable`, property names from POCOs, keys from dictionaries. That's usually what you want.

You override it when you need explicit captions, widths, alignment, formatting, or data types:

```csharp
grid.SetColumns(new[]
{
    new VolvoxGridColumn { FieldName = "Name", Caption = "Product", Width = 220 },
    new VolvoxGridColumn
    {
        FieldName = "Price",
        Caption = "Price",
        Width = 100,
        DataType = VolvoxGridColumnDataType.Currency,
        Alignment = VolvoxGridAlign.RightCenter,
        Format = "C2",
    },
    new VolvoxGridColumn
    {
        FieldName = "Qty",
        Caption = "Qty",
        Width = 90,
        DataType = VolvoxGridColumnDataType.Number,
        Alignment = VolvoxGridAlign.RightCenter,
    },
});
```

When you do call `SetColumns`, make sure each `FieldName` matches the source column name, property name, or dictionary key — otherwise the column shows as empty.

### Common properties

You don't need to set any of these — they all have sensible defaults — but most apps customize a few. Set them once after construction.

```csharp
grid.Editable = true;
grid.SelectionMode = VolvoxGridSelectionMode.ByRow;
grid.MultiSelect = true;
grid.ScrollBars = VolvoxGridScrollBarsMode.Both;
grid.RendererMode = VolvoxGridRendererMode.Auto;
grid.HeaderFeatures = new VolvoxGridHeaderFeatures { Sort = true, Reorder = true };
grid.ResizePolicy = new VolvoxGridResizePolicy { Columns = true, Rows = true };
grid.DebugOverlay = false;

grid.ShowColumnHeaders = true;
grid.FrozenRowCount = 1;
grid.FrozenColCount = 1;
grid.TopRow = 0;
grid.LeftCol = 0;
```

Other layout knobs you may reach for: `ShowRowIndicator`, `ColumnIndicatorTopConfig`, `RowIndicatorStartConfig`, `RowCount`, `ColCount`. For scrolling and animation: `FastScrollEnabled`, `FlingEnabled`, `FlingImpulseGain`, `FlingFriction`, `TextLayoutCacheCap`, `AnimationEnabled`, `AnimationDurationMs`.

## Cross-platform: `VolvoxGridClient`

Use `VolvoxGridClient` when you want the engine without a UI — for example, a `.NET 8` service that builds and exports a grid, a test that drives the engine programmatically, or a TUI host. There's no WinForms reference, so the same code runs on Linux and macOS.

```csharp
using System;
using VolvoxGrid.DotNet;
using Volvoxgrid.V1;

using var grid = new VolvoxGridClient();

grid.DefineColumns(new[]
{
    new ColumnDef { Index = 0, Key = "id",   Caption = "ID",   Width = 90,
        DataType = ColumnDataType.COLUMN_DATA_NUMBER, Align = Align.ALIGN_RIGHT_CENTER },
    new ColumnDef { Index = 1, Key = "name", Caption = "Name", Width = 180 },
});

grid.LoadTable(2, 2, new object[]
{
    1, "Alpha",
    2, "Beta",
}, atomic: true);

Console.WriteLine(grid.FindByText("Beta", 1, 0, false, true));
```

`VolvoxGridClient` implements `IDisposable`; always wrap it in `using` so the native session shuts down cleanly.

## Loading data

You have four ways to push data into a grid, listed shortest to most flexible.

`LoadData` accepts a byte buffer of CSV or JSON. CSV uses sensible defaults; JSON needs an options object so the engine knows the shape.

```csharp
grid.LoadData(System.Text.Encoding.UTF8.GetBytes("Name,Price,Qty\nWidget A,29.99,150\nWidget B,49.99,200"));

using Volvoxgrid.V1;
grid.LoadData(
    System.Text.Encoding.UTF8.GetBytes("[[\"Name\",\"Price\"],[\"Alpha\",\"10\"]]"),
    new LoadDataOptions { Json = new JsonOptions(), HeaderPolicy = HeaderPolicy.HEADER_NONE });
```

`LoadTable` bulk-loads a row-major flat array of typed values in a single RPC. `CellValue` supports `text`, `number`, `flag` (boolean), `raw` (bytes), and `timestamp` (epoch-ms). This is the fastest path for "I already have the data in memory."

```csharp
grid.SetColumns(new[]
{
    new VolvoxGridColumn { FieldName = "c0", Caption = "Name",  Width = 220 },
    new VolvoxGridColumn { FieldName = "c1", Caption = "Price", Width = 100,
        DataType = VolvoxGridColumnDataType.Number,
        Alignment = VolvoxGridAlign.RightCenter, Format = "N2" },
});

grid.LoadTable(3, 2, new object[]
{
    "Widget A", 29.99,
    "Widget B", 49.99,
    "Widget C", 12.50,
}, atomic: true);
```

`SetCells` updates an arbitrary batch of cells. Use it after the initial load for hot-cell writes:

```csharp
grid.SetCells(new[]
{
    new VolvoxGridCellText(2, 0, "Widget Z"),
    new VolvoxGridCellText(2, 1, "199.00"),
});
```

`SetCellText` and `SetCellValue` poke a single cell. `SetCellValue` accepts a typed value and a field name, which is convenient for bound grids.

```csharp
grid.SetCellText(0, 0, "Updated name");
grid.SetCellValue(1, "c1", 99.95);
```

## Reading data

`GetCellText` and `GetCellValue` give you a single cell.

```csharp
string text = grid.GetCellText(0, 0);
object value = grid.GetCellValue(0, "Price");
```

For ranges, use `VolvoxGridClient.GetCells`. The `includeStyle`, `includeChecked`, and `includeTyped` flags control how much payload the engine returns — keep them off for a cheap text read, turn them on when you also need formatting or typed values.

```csharp
using var client = new VolvoxGridClient();
// ... define columns and load data ...

var cells = client.GetCells(0, 0, 1, 2,
    includeStyle: false, includeChecked: false, includeTyped: false);

foreach (var cell in cells)
{
    Console.WriteLine($"{cell.Row},{cell.Col} = {cell.Value.Text}");
}
```

## Selection

Selection is rectangular by default and supports multi-rect when you need it. `SelectRange` selects one rectangle; `SelectRanges` selects several at once, and the first two arguments are the explicit active cell (row, column) that will receive focus after the call.

```csharp
grid.SelectRange(1, 0, 2, 1);

grid.SelectRanges(
    6, 4,                                       // active cell
    new VolvoxGridCellRange(1, 0, 2, 1),
    new VolvoxGridCellRange(4, 3, 6, 4));

var state = grid.GetSelection();
grid.ShowCell(state.ActiveRow, state.ActiveCol);
grid.ClearSelection();
```

`ShowCell` scrolls the viewport until the given cell is visible. It's handy after programmatic selection or search.

## Editing and cancelable events

WinForms callers can interrupt three engine actions before they happen: entering edit mode, committing an edit, and starting a header-click sort. `.NET` exposes only `e.Cancel` on these events — the internal decision channel that the engine uses is hidden from app code.

```csharp
grid.BeforeEdit += (s, e) =>
{
    if (e.FieldName == "Status") e.Cancel = true;
};

grid.CellEditValidating += (s, e) =>
{
    if (e.FieldName == "Qty" && !int.TryParse(e.ProposedText, out _))
        e.Cancel = true;
};

grid.BeforeSort += (s, e) =>
{
    if (e.FieldName == "Notes") e.Cancel = true;
};
```

Two rules worth knowing:

- If no cancelable event handler is registered for a given action, the control does not pause the engine for a decision — the action just proceeds.
- If the decision channel is active and an unhandled cancelable event arrives, the control allows it with `cancel = false`.

The non-cancelable events you'll wire up most often are `FocusedCellChanged`, `CellValueChanged`, and `SelectionChanged`.

```csharp
grid.FocusedCellChanged += (s, e) => Console.WriteLine($"focus row={e.CurrentRowIndex} field={e.CurrentColumnFieldName}");
grid.CellValueChanged   += (s, e) => Console.WriteLine($"row={e.RowIndex} field={e.FieldName} value={e.Value}");
grid.SelectionChanged   += (s, e) => Console.WriteLine(string.Join(", ", e.SelectedRows));
```

## Sorting, merge, subtotal, search, clipboard

You won't use all of these in every app, but here's the menu in one place:

| You want to | API |
|---|---|
| Configure columns | `SetColumns`, `GetColumns`, `ClearColumns` |
| Bind data | `SetDataBinding`, `DataSource`, `DataMember`, `RefreshData` |
| Manual data load | `LoadTable`, `SetTableData`, `SetCellText`, `GetCellText`, `SetCells` |
| Access by field name | `GetCellValue`, `SetCellValue` |
| Selection | `SelectRange`, `SelectRanges`, `ClearSelection`, `GetSelection`, `ShowCell` |
| Sorting | `Sort` |
| Resizing | `SetRowHeight`, `SetColWidth`, `AutoSize` |
| Row/column structure | `InsertRows`, `RemoveRows`, `MoveRow`, `MoveColumn`, `DefineRows`, `DefineColumns` |
| Merged cells | `MergeCells`, `UnmergeCells`, `GetMergedRange`, `GetMergedRegions` |
| Outline & subtotals | `Outline`, `Subtotal`, `GetNode` |
| Search | `FindRowByText`, `FindRowByRegex` |
| Clipboard | `Copy`, `Cut`, `Paste`, `DeleteSelection` |
| Editing | `BeginEdit`, `CommitEdit`, `CancelEdit` |
| Export / archive | `SaveGrid`, `LoadData`, `PrintGrid`, `Archive` |
| Repaint control | `SetRedraw`, `WithRedrawSuspended`, `Refresh`, `ResizeViewport` |

### Batch updates

When you have several writes in a row, wrap them so the control only repaints once at the end.

```csharp
grid.WithRedrawSuspended(() =>
{
    grid.SetCellText(0, 0, "A");
    grid.SetCellText(0, 1, "B");
    grid.SetCellText(1, 0, "C");
    grid.SetCellText(1, 1, "D");
});
```

### Clearing

`Clear` defaults to clearing everything. You can scope it.

```csharp
grid.Clear();
grid.Clear(VolvoxGridClearScope.Data, VolvoxGridClearRegion.Scrollable);
```

Scopes are `Everything`, `Formatting`, `Data`, `Selection`. Regions are `Scrollable`, `FixedRows`, `FixedCols`, `AllRegions`.

## Terminal session

If you're building a TUI on top of the engine — a console app, a remote shell, an editor — call `OpenTerminalSession()` on a `VolvoxGridClient`. The engine renders into terminal escape sequences instead of pixels, and you blit the resulting byte buffer to stdout.

```csharp
using VolvoxGrid.DotNet;
using Volvoxgrid.V1;

using var grid = new VolvoxGridClient(viewportWidth: 80, viewportHeight: 24);

grid.Configure(new GridConfig
{
    Indicators = new IndicatorsConfig
    {
        RowStart = new RowIndicatorConfig { Visible = false },
        ColTop   = new ColIndicatorConfig { Visible = true, BandRows = 1 },
    },
});

grid.DefineColumns(new[]
{
    new ColumnDef { Index = 0, Key = "id",   Caption = "ID",   Width = 4,
        DataType = ColumnDataType.COLUMN_DATA_NUMBER, Align = Align.ALIGN_RIGHT_CENTER },
    new ColumnDef { Index = 1, Key = "name", Caption = "Name", Width = 6 },
});

grid.LoadTable(2, 2, new object[]
{
    10, "Alpha",
    20, "Beta",
}, atomic: true);

using var terminal = grid.OpenTerminalSession();
terminal.SetCapabilities(new VolvoxGridTerminalCapabilities
{
    ColorLevel = VolvoxGridTerminalColorLevel.Truecolor,
});
terminal.SetViewport(0, 0, 20, 6, fullscreen: false);

VolvoxGridTerminalFrame frame = terminal.Render();
Console.OpenStandardOutput().Write(frame.Buffer, 0, frame.BytesWritten);

byte[] arrowDown = new byte[] { 0x1b, (byte)'[', (byte)'B' };
terminal.SendInputBytes(arrowDown, arrowDown.Length);
```

A few rules to keep the contract clean:

- `OpenTerminalSession()` forces the grid into the TUI renderer mode before opening the streams.
- `Render()` writes terminal bytes into a host-owned buffer and returns `BytesWritten`.
- The host forwards raw stdin bytes; the runtime owns terminal escape parsing and ANSI encoding.
- Viewport coordinates stay local to the reserved grid rectangle.

Run the bundled example with `make dotnet-tui-run` (interactive) or `make dotnet-tui-smoke` (non-interactive).

## Renderer modes

`RendererMode` selects how the engine produces pixels. `Auto` is the safe choice; the others let you pin a backend when you know what the host supports.

| Mode | Meaning |
|---|---|
| `VolvoxGridRendererMode.Auto` | Engine picks the best available backend |
| `VolvoxGridRendererMode.Cpu` | CPU RGBA buffer rendering |
| `VolvoxGridRendererMode.Gpu` | GPU auto backend |
| `VolvoxGridRendererMode.GpuVulkan` | Vulkan |
| `VolvoxGridRendererMode.GpuOpenGl` | OpenGL |
| `VolvoxGridRendererMode.GpuGles` | OpenGL ES |
| `VolvoxGridRendererMode.GpuDx12` | DirectX 12 |
| `VolvoxGridRendererMode.GpuMetal` | Metal |

GPU rendering requires the full native package and a compatible native surface. The Lite package is CPU-only. In the WinForms sample running under Wine, `Gpu` is normalized to `GpuOpenGl` because that's the practical path; real Windows can use DX12 or any other `wgpu` backend the driver supports.

## Full vs Lite

You pick `VolvoxGrid.DotNet.Lite` when binary size matters or when you don't want to ship GPU code at all (locked-down enterprise installs, server-side rendering on minimal Linux images, etc.). The trade-offs:

| | Full | Lite |
|---|---|---|
| Built-in text engine | `cosmic-text` | none (GDI/GDI+ bridge) |
| Native GPU backends | `wgpu` (Vulkan, DX12, Metal, GL, GLES) | CPU only |
| Regex search | yes | no |
| Parallelism | rayon | single-threaded |
| Font fallback | built-in | host OS via GDI/GDI+ |
| Text mask cache | engine-owned | Rust-owned external (`C:<used>/<cap>` in debug overlay) |

Full builds default to the `cosmic-text` engine. Lite registers the GDI/GDI+ text bridge automatically when the native library has no built-in text engine. Linux or Wine WinForms hosts running the full package can opt into the GDI bridge by setting `VOLVOXGRID_DOTNET_USE_HOST_TEXT_RENDERER=1`. The `fixme:gdiplus:*` lines you may see under Wine come from Wine's GDI+, not from VolvoxGrid.

See [../TEXT_RENDERING.md](../TEXT_RENDERING.md) for the deeper story on text rendering and cache ownership.

## Native library deployment

The managed assembly is useless without the matching native library. You have three ways to ship it.

**1. Let NuGet do it.** When you reference `VolvoxGrid.DotNet` (or Lite) and target a supported RID, NuGet drops the native library into `runtimes/<rid>/native/` at restore time. Nothing else to do. Currently shipped RIDs: `win-x64`, `win-x86`, `linux-x64`, `linux-arm64`, `osx-x64`, `osx-arm64`.

**2. Copy it beside the executable.** If you're using a `ProjectReference` or packing locally without embedded natives, add a copy rule to your `csproj`:

```xml
<ItemGroup>
  <None Include="native\volvoxgrid.dll" CopyToOutputDirectory="PreserveNewest" />
</ItemGroup>
```

Library names by platform: `volvoxgrid.dll` (Windows), `libvolvoxgrid.so` (Linux), `libvolvoxgrid.dylib` (macOS). Architecture must match your process.

**3. Tell the control where to look.** Either set the environment variable `VOLVOXGRID_LIBRARY_PATH` before launch, or set the path in code before any other call:

```csharp
grid.LibraryPath = System.IO.Path.Combine(AppContext.BaseDirectory, "volvoxgrid.dll");
```

## Demos and smoke helpers

While you're getting set up, the engine ships demo data so you can verify the rendering path before your real data flows through.

```csharp
grid.LoadDemo("stress");

byte[] salesJson     = grid.GetDemoData("sales");
byte[] hierarchyJson = grid.GetDemoData("hierarchy");
// Pair GetDemoData with LoadData and your own SetColumns call.
```

The diagnostic properties you'll want during bring-up: `LastError` (last native failure message) and `CurrentGridId` (engine-side session id, useful when correlating logs).

## Troubleshooting

**The control stays blank.** Almost always a native-library problem. Confirm `volvoxgrid.dll` sits next to your executable, or that `LibraryPath` is set, and check that the library architecture matches the process architecture (a x86 process can't load a x64 native). Read `grid.LastError` for the engine's own complaint.

**Bound columns don't line up with the data source.** When you call `SetColumns`, every `FieldName` must match the source column name, property name, or dictionary key. Easiest fix: stop calling `SetColumns` and let the control infer columns. Customize widths and formatting after binding if you need to.

**You need local sample binaries from this repo.** The helper scripts handle the build:

```bash
./dotnet/build_dotnet.sh
./dotnet/run_sample.sh
```

Staged sample output lives in `target/dotnet/winforms_debug/` and `target/dotnet/winforms_release/`. Managed build artifacts are written under `target/dotnet/msbuild/`.

## Local development and packaging

The solution file is `dotnet/VolvoxGrid.DotNet.sln`. The example projects sit under `dotnet/examples/console`, `dotnet/examples/tui`, and `dotnet/examples/winforms/`.

For day-to-day development, the Makefile wraps the common flows:

```bash
make dotnet-run-release
make dotnet-run-release VOLVOXGRID_VARIANT=lite
make dotnet-smoke-release VOLVOXGRID_VARIANT=lite
make dotnet-tui-run
make dotnet-tui-smoke
```

`VOLVOXGRID_VARIANT=lite` builds the native runtime with `--no-default-features --features demo` and runs the same managed sample against the Lite native library.

On a real Windows host with the .NET 8 Windows Desktop SDK, you can also build the library and sample directly:

```bash
dotnet build dotnet/src/VolvoxGrid.DotNet.csproj -f net8.0-windows
dotnet build dotnet/examples/winforms/VolvoxGrid.WinFormsSample.csproj -c Debug -f net8.0-windows
```

The legacy `net40` build is gated behind a flag so it doesn't slow down normal builds:

```bash
dotnet build dotnet/src/VolvoxGrid.DotNet.csproj -f net40 -p:VolvoxGridLegacyOnly=true
```

Pack local NuGets — one command per package ID:

```bash
dotnet pack dotnet/src/VolvoxGrid.DotNet.csproj -c Release
dotnet pack dotnet/src/VolvoxGrid.DotNet.csproj -c Release -p:VolvoxGridPackageId=VolvoxGrid.DotNet.Lite
```

Publish the release set:

```bash
make publish_nuget
```

`publish_nuget` publishes both `VolvoxGrid.DotNet` and `VolvoxGrid.DotNet.Lite`. Full RID coverage is staged from `make docker_all` outputs and desktop JAR backfill where available.

## What's next

- [../TEXT_RENDERING.md](../TEXT_RENDERING.md) — how the full and Lite text pipelines differ, who owns the glyph mask cache, and what the debug overlay numbers mean.
- [../TUI.md](../TUI.md) — protocol details for `VolvoxGridTerminalSession`, capability negotiation, and input forwarding.

## License

See the repository root for license terms.
