# VolvoxGrid for Go

The Go package provides a client API for the VolvoxGrid native plugin and a reusable terminal host for building TUI applications.

## Prerequisites

- Go 1.22+
- The native `volvoxgrid_plugin` shared library (built from the repo root with `make build` or `make release`)

## Package Structure

```
go/
├── pkg/volvoxgrid/         # Client API for the native plugin
│   ├── client.go           # Plugin loading and grid lifecycle
│   └── tui/                # Reusable terminal host
│       ├── terminal.go     # Terminal mode, input reading, capability detection
│       └── app.go          # Run loop and render session management
└── examples/tui/           # Interactive TUI example app
    ├── main.go
    ├── demo.go
    └── terminal.go
```

## Quick Start

```go
package main

import (
    "log"

    "github.com/ivere27/volvoxgrid/pkg/volvoxgrid"
    "github.com/ivere27/volvoxgrid/pkg/volvoxgrid/tui"
)

func main() {
    client, err := volvoxgrid.NewClient("path/to/libvolvoxgrid_plugin.so")
    if err != nil {
        log.Fatal(err)
    }
    defer client.Close()

    grid, err := client.NewGrid(80, 24)
    if err != nil {
        log.Fatal(err)
    }

    // Use the tui package to run an interactive terminal session
    app := tui.NewApp(grid)
    if err := app.Run(); err != nil {
        log.Fatal(err)
    }
}
```

## Running the Example

From the repo root:

```bash
# Build the native plugin first
make build

# Interactive TUI example
make go-tui-run

# Non-interactive smoke check
make go-tui-smoke
```

The example includes demo data selection (`--demo sales`, `--demo hierarchy`, `--demo stress`), search prompts, and a debug panel.

## Data Operations

The `Grid` struct provides convenience wrappers for common data operations. For RPCs without a wrapper, use the proto client directly via `grid.Client().Client()`.

#### LoadData

Parse CSV or JSON bytes into the grid:

```go
import pb "github.com/ivere27/volvoxgrid/pkg/volvoxgrid/proto"

// CSV
result, err := grid.LoadData(
    []byte("Name,Price,Qty\nWidget A,29.99,150\nWidget B,49.99,200"),
    nil, // default options (auto-detect CSV)
)

// JSON matrix
result, err := grid.LoadData(
    []byte(`[["Name","Price"],["Alpha","10"]]`),
    &pb.LoadDataOptions{
        Json:         &pb.JsonOptions{},
        HeaderPolicy: pb.HeaderPolicy_HEADER_NONE,
    },
)
```

#### UpdateCells

Batch update cells:

```go
err := grid.UpdateCells([]*pb.CellUpdate{
    {Row: 0, Col: 0, Value: &pb.CellValue{Value: &pb.CellValue_Text{Text: "Alpha"}}},
    {Row: 0, Col: 1, Value: &pb.CellValue{Value: &pb.CellValue_Number{Number: 29.99}}},
    {Row: 1, Col: 0, Value: &pb.CellValue{Value: &pb.CellValue_Text{Text: "Beta"}}},
}, true /* atomic */)
```

#### GetCells

Read cell values (uses proto client directly):

```go
resp, err := grid.Client().Client().GetCells(context.Background(), &pb.GetCellsRequest{
    GridId: grid.ID,
    Row1: 0, Col1: 0, Row2: 1, Col2: 2,
})
for _, cell := range resp.Cells {
    fmt.Printf("%d,%d = %s\n", cell.Row, cell.Col, cell.Value.GetText())
}
```

#### Clear

Clear grid content (uses proto client directly):

```go
_, err := grid.Client().Client().Clear(context.Background(), &pb.ClearRequest{
    GridId: grid.ID,
    Scope:  pb.ClearScope_CLEAR_EVERYTHING,
    Region: pb.ClearRegion_CLEAR_SCROLLABLE,
})
// Scopes: CLEAR_EVERYTHING, CLEAR_FORMATTING, CLEAR_DATA, CLEAR_SELECTION
```

#### LoadTable

`LoadTable` bulk-loads a row-major flat array of typed `CellValue` entries. It is available via the proto client:

```go
_, err := grid.Client().Client().LoadTable(context.Background(), &pb.LoadTableRequest{
    GridId: grid.ID,
    Rows: 2, Cols: 2,
    Values: []*pb.CellValue{
        {Value: &pb.CellValue_Text{Text: "a"}},
        {Value: &pb.CellValue_Number{Number: 1.0}},
        {Value: &pb.CellValue_Text{Text: "b"}},
        {Value: &pb.CellValue_Number{Number: 2.0}},
    },
    Atomic: true,
})
```

`CellValue` supports `Text`, `Number`, `Flag` (bool), `Raw` (bytes), and `Timestamp` (epoch-ms). For the full schema, see [`proto/volvoxgrid.proto`](../proto/volvoxgrid.proto).

## How It Works

The Go TUI host follows the thin-host architecture described in [TUI.md](../TUI.md):

1. The host switches the terminal into raw mode and detects capabilities
2. Raw stdin bytes are forwarded to the plugin via `TerminalInputBytes`
3. The plugin parses escape sequences, drives the grid engine, and encodes ANSI output
4. The host writes the returned bytes to stdout

The Go host is responsible for terminal setup, resize detection, and application chrome (headers, footers, prompts). The plugin owns escape parsing, grid rendering, and frame diffing.

## License

[Apache License 2.0](../LICENSE)
