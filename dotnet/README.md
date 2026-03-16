# VolvoxGrid for .NET WinForms

`VolvoxGrid.DotNet` is a WinForms `UserControl` for displaying and editing tabular data.
From a .NET developer's point of view, you work with:

- one managed assembly: `VolvoxGrid.DotNet.dll`
- one control: `VolvoxGridControl`
- one native runtime dependency: `volvoxgrid_plugin.dll`

It is intended for WinForms apps that want a grid control with selection, editing, sorting, merged cells, clipboard support, import/export, and large-data scenarios.

## Supported Targets

| Target framework | Status | Notes |
|---|---|---|
| `net8.0-windows` | Recommended | Best choice for new WinForms applications |
| `net40` | Supported | For legacy WinForms applications |

Runtime notes:

- WinForms only
- `volvoxgrid_plugin.dll` is required at runtime
- The plugin architecture must match your process architecture (`x64` or `x86`)
- Linux/Wine sample runs use the built-in `cosmic-text` engine by default. Set `VOLVOXGRID_DOTNET_USE_HOST_TEXT_RENDERER=1` to opt into the host GDI text bridge.

## Main Types

- Namespace: `VolvoxGrid.DotNet`
- Main control: `VolvoxGridControl`
- Column model: `VolvoxGridColumn`
- Cell batch model: `VolvoxGridCellText`
- Selection model: `VolvoxGridSelectionState`
- Merge range model: `VolvoxGridCellRange`

Useful enums include:

- `VolvoxGridRendererMode`
- `VolvoxGridSelectionMode`
- `VolvoxGridHeaderFeatures`
- `VolvoxGridResizePolicy`
- `VolvoxGridColumnDataType`
- `VolvoxGridSortDirection`

## Installation

### Option A: Reference the project directly

```xml
<ItemGroup>
  <ProjectReference Include="..\volvoxgrid\dotnet\src\VolvoxGrid.DotNet.csproj" />
</ItemGroup>
```

### Option B: Pack a local NuGet package

```bash
dotnet pack dotnet/src/VolvoxGrid.DotNet.csproj -c Release
```

Package output:

- `target/dotnet/msbuild/packages/`

Package ID:

- `VolvoxGrid.DotNet`

No matter how you reference the managed wrapper, you still need to deploy `volvoxgrid_plugin.dll` with your application.

## Deploy the Native Plugin

Recommended deployment:

- copy `volvoxgrid_plugin.dll` beside your application `.exe`

You can also provide the plugin location explicitly:

- set the `VOLVOXGRID_PLUGIN_PATH` environment variable
- set `grid.PluginPath` in code

Example `csproj` copy rule:

```xml
<ItemGroup>
  <None Include="native\volvoxgrid_plugin.dll" CopyToOutputDirectory="PreserveNewest" />
</ItemGroup>
```

Example explicit path:

```csharp
grid.PluginPath = System.IO.Path.Combine(AppContext.BaseDirectory, "volvoxgrid_plugin.dll");
```

If the control cannot create the native grid session, inspect:

- `grid.LastError`

## Quick Start

### Bind a `DataTable`

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
        Width = 1000;
        Height = 700;

        // Optional if volvoxgrid_plugin.dll is already beside the executable.
        // _grid.PluginPath = System.IO.Path.Combine(AppContext.BaseDirectory, "volvoxgrid_plugin.dll");

        _grid.SetColumns(new[]
        {
            new VolvoxGridColumn
            {
                FieldName = "Name",
                Caption = "Product",
                Width = 220,
            },
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

        _grid.SetDataBinding(BuildTable(), null);

        _grid.FocusedCellChanged += (sender, e) =>
        {
            Text = $"VolvoxGrid - Row {e.CurrentRowIndex}, Column {e.CurrentColumnFieldName}";
        };

        _grid.CellValueChanged += (sender, e) =>
        {
            Console.WriteLine($"{e.FieldName} changed to {e.Value}");
        };

        Controls.Add(_grid);
    }

    private static DataTable BuildTable()
    {
        var table = new DataTable();
        table.Columns.Add("Name", typeof(string));
        table.Columns.Add("Price", typeof(decimal));
        table.Columns.Add("Qty", typeof(int));

        table.Rows.Add("Widget A", 29.99m, 150);
        table.Rows.Add("Widget B", 49.99m, 200);
        table.Rows.Add("Widget C", 12.50m, 90);

        return table;
    }
}
```

### Populate the grid without a bound data source

```csharp
var grid = new VolvoxGridControl
{
    Dock = DockStyle.Fill,
    Editable = true,
};

grid.SetColumns(new[]
{
    new VolvoxGridColumn { FieldName = "c0", Caption = "Name", Width = 220 },
    new VolvoxGridColumn
    {
        FieldName = "c1",
        Caption = "Price",
        Width = 100,
        DataType = VolvoxGridColumnDataType.Number,
        Alignment = VolvoxGridAlign.RightCenter,
        Format = "N2",
    },
});

grid.LoadTable(3, 2, new object[]
{
    "Widget A", 29.99,
    "Widget B", 49.99,
    "Widget C", 12.50,
}, atomic: true);
```

You can also update individual cells or batches later:

```csharp
grid.SetCellText(0, 0, "Updated name");
grid.SetCellValue(1, "c1", 99.95);
grid.SetCells(new[]
{
    new VolvoxGridCellText(2, 0, "Widget Z"),
    new VolvoxGridCellText(2, 1, "199.00"),
});
```

## Data Binding

The wrapper accepts the following source styles:

- `DataTable`
- `DataView`
- `BindingSource`
- `DataSet` with `DataMember`
- any `IList` or `IEnumerable` of POCOs
- `IList` or `IEnumerable` of dictionaries
- `IList` or `IEnumerable` of simple values
- two-dimensional arrays

Useful rules:

- If you do not call `SetColumns`, columns are inferred from the source.
- If you do call `SetColumns`, `FieldName` should match the source column name, property name, or dictionary key.
- `SetDataBinding(source, member)` is the direct API for binding.
- `DataSource` and `DataMember` properties are also available if you prefer property-style setup.

Example with `BindingSource`:

```csharp
var bindingSource = new BindingSource();
bindingSource.DataSource = ordersTable;

grid.SetDataBinding(bindingSource, null);
```

## Common Configuration

```csharp
grid.Editable = true;
grid.SelectionMode = VolvoxGridSelectionMode.ByRow;
grid.MultiSelect = true;
grid.SelectionVisibility = VolvoxGridSelectionVisibility.Always;
grid.RendererMode = VolvoxGridRendererMode.Auto;
grid.ScrollBars = VolvoxGridScrollBarsMode.Both;
grid.ResizePolicy = new VolvoxGridResizePolicy { Columns = true, Rows = true };
grid.HeaderFeatures = new VolvoxGridHeaderFeatures { Sort = true, Reorder = true };
grid.DebugOverlay = false;
```

Layout-related properties:

- `ShowColumnHeaders`
- `ShowRowIndicator`
- `FrozenRowCount`
- `FrozenColCount`
- `RowCount`
- `ColCount`

Scrolling and rendering properties:

- `TopRow`
- `LeftCol`
- `RendererMode`
- `ScrollBars`
- `FastScrollEnabled`
- `FlingEnabled`
- `FlingImpulseGain`
- `FlingFriction`
- `TextLayoutCacheCap`
- `AnimationEnabled`
- `AnimationDurationMs`

## Common Operations

| Scenario | Main API |
|---|---|
| Configure columns | `SetColumns`, `GetColumns`, `ClearColumns` |
| Bind data | `SetDataBinding`, `DataSource`, `DataMember`, `RefreshData` |
| Manual data load | `LoadTable`, `SetTableData`, `SetCellText`, `GetCellText`, `SetCells` |
| Access by field name | `GetCellValue`, `SetCellValue` |
| Selection | `SelectRange`, `SelectRanges`, `ClearSelection`, `GetSelection`, `ShowCell` |
| Sorting | `Sort` |
| Resizing | `SetRowHeight`, `SetColWidth`, `AutoSize` |
| Row and column structure | `InsertRows`, `RemoveRows`, `MoveRow`, `MoveColumn`, `DefineRows`, `DefineColumns` |
| Merged cells | `MergeCells`, `UnmergeCells`, `GetMergedRange`, `GetMergedRegions` |
| Outline and subtotals | `Outline`, `Subtotal`, `GetNode` |
| Search | `FindRowByText`, `FindRowByRegex` |
| Clipboard | `Copy`, `Cut`, `Paste`, `DeleteSelection` |
| Editing | `BeginEdit`, `CommitEdit`, `CancelEdit` |
| Import and export | `SaveGrid`, `LoadGrid`, `PrintGrid`, `Archive` |
| Repaint control | `SetRedraw`, `WithRedrawSuspended`, `Refresh`, `ResizeViewport` |

Batch update tip:

```csharp
grid.WithRedrawSuspended(() =>
{
    grid.SetCellText(0, 0, "A");
    grid.SetCellText(0, 1, "B");
    grid.SetCellText(1, 0, "C");
    grid.SetCellText(1, 1, "D");
});
```

Selection tip:

```csharp
grid.SelectRanges(
    6,
    4,
    new VolvoxGridCellRange(1, 0, 2, 1),
    new VolvoxGridCellRange(4, 3, 6, 4)
);
```

## Events

| Event | Purpose |
|---|---|
| `FocusedCellChanged` | Track active-cell movement |
| `CellValueChanged` | React to edits or programmatic cell changes reported back from the engine |
| `SelectionChanged` | Track row selection changes |
| `BeforeEdit` | Cancel entry into edit mode for a cell |
| `CellEditValidating` | Cancel a pending text commit before it is applied |
| `BeforeSort` | Cancel a header-click sort before it runs |

Example:

```csharp
grid.FocusedCellChanged += (sender, e) =>
{
    Console.WriteLine($"Focused row={e.CurrentRowIndex}, field={e.CurrentColumnFieldName}");
};

grid.CellValueChanged += (sender, e) =>
{
    Console.WriteLine($"Row={e.RowIndex}, field={e.FieldName}, value={e.Value}");
};

grid.SelectionChanged += (sender, e) =>
{
    Console.WriteLine(string.Join(", ", e.SelectedRows));
};

grid.BeforeEdit += (sender, e) =>
{
    if (e.FieldName == "Status")
    {
        e.Cancel = true;
    }
};

grid.CellEditValidating += (sender, e) =>
{
    if (e.FieldName == "Qty" && !int.TryParse(e.ProposedText, out _))
    {
        e.Cancel = true;
    }
};

grid.BeforeSort += (sender, e) =>
{
    if (e.FieldName == "Notes")
    {
        e.Cancel = true;
    }
};
```

Cancelable `.NET` events currently cover `BeforeEdit`, `CellEditValidating`, and `BeforeSort`. The control hides the internal `EventDecision` transport; app code only uses `e.Cancel`.

## Demo and Smoke-Test Helpers

For quick validation during development:

```csharp
grid.LoadDemo("sales");
// or: "hierarchy"
// or: "stress"
```

Useful diagnostics:

- `LastError`
- `CurrentGridId`

## Troubleshooting

### The control stays blank or fails to initialize

Check the following first:

- `volvoxgrid_plugin.dll` is present next to the executable, or `PluginPath` is set correctly
- the plugin architecture matches the process architecture
- `grid.LastError` contains the latest failure message

### My bound columns do not line up with my data source

Check the following:

- `FieldName` matches the `DataTable` column name, POCO property name, or dictionary key
- or remove `SetColumns` and let the control infer columns automatically

### I need local sample binaries from this repo

Use the helper scripts:

```bash
./dotnet/build_dotnet.sh
./dotnet/run_sample.sh
```

Staged sample output:

- `target/dotnet/winforms_debug/`
- `target/dotnet/winforms_release/`

Managed build artifacts are written under:

- `target/dotnet/msbuild/`

## Local Development From This Repo

Solution file:

- `dotnet/VolvoxGrid.DotNet.sln`

On Windows with the .NET 8 Windows Desktop SDK installed, build the library directly:

```bash
dotnet build dotnet/src/VolvoxGrid.DotNet.csproj -f net8.0-windows
```

Build the sample directly:

```bash
dotnet build dotnet/examples/winforms/VolvoxGrid.WinFormsSample.csproj -c Debug -f net8.0-windows
```

Legacy `net40` build:

```bash
dotnet build dotnet/src/VolvoxGrid.DotNet.csproj -f net40 -p:VolvoxGridLegacyOnly=true
```

Create a local package:

```bash
dotnet pack dotnet/src/VolvoxGrid.DotNet.csproj -c Release
```
