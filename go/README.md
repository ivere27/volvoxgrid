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
    defer grid.Destroy()

    if err := grid.LoadDemo("sales"); err != nil {
        log.Fatal(err)
    }
}
```

For an interactive terminal app, create a `tui.Terminal`, implement `tui.Controller`, and call `tui.Run(...)`. See `go/examples/tui` for a complete sample controller and host setup.

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

The `Grid` struct provides convenience wrappers for common data operations.

#### LoadData

Parse CSV or JSON bytes into the grid:

```go
import pb "github.com/ivere27/volvoxgrid/api/v1"

// CSV
if _, err := grid.LoadData(
    []byte("Name,Price,Qty\nWidget A,29.99,150\nWidget B,49.99,200"),
    nil, // default options (auto-detect CSV)
); err != nil {
    return err
}

// JSON matrix
headerPolicy := pb.HeaderPolicy_HEADER_NONE
if _, err := grid.LoadData(
    []byte(`[["Name","Price"],["Alpha","10"]]`),
    &pb.LoadDataOptions{
        Format:       &pb.LoadDataOptions_Json{Json: &pb.JsonOptions{}},
        HeaderPolicy: &headerPolicy,
    },
); err != nil {
    return err
}
```

#### UpdateCells

Batch update cells:

```go
if err := grid.UpdateCells([]*pb.CellUpdate{
    {Row: 0, Col: 0, Value: &pb.CellValue{Value: &pb.CellValue_Text{Text: "Alpha"}}},
    {Row: 0, Col: 1, Value: &pb.CellValue{Value: &pb.CellValue_Number{Number: 29.99}}},
    {Row: 1, Col: 0, Value: &pb.CellValue{Value: &pb.CellValue_Text{Text: "Beta"}}},
}, true /* atomic */); err != nil {
    return err
}
```

#### GetCells

Read cell values:

```go
resp, err := grid.GetCells(0, 0, 1, 2, false, false, false)
if err != nil {
    return err
}
for _, cell := range resp.Cells {
    fmt.Printf("%d,%d = %s\n", cell.Row, cell.Col, cell.Value.GetText())
}
```

#### Clear

Clear grid content:

```go
if err := grid.Clear(
    pb.ClearScope_CLEAR_EVERYTHING,
    pb.ClearRegion_CLEAR_SCROLLABLE,
); err != nil {
    return err
}
// Scopes: CLEAR_EVERYTHING, CLEAR_FORMATTING, CLEAR_DATA, CLEAR_SELECTION
```

#### LoadTable

`LoadTable` bulk-loads a row-major flat array of typed `CellValue` entries:

```go
if _, err := grid.LoadTable(
    2,
    2,
    []*pb.CellValue{
        {Value: &pb.CellValue_Text{Text: "a"}},
        {Value: &pb.CellValue_Number{Number: 1.0}},
        {Value: &pb.CellValue_Text{Text: "b"}},
        {Value: &pb.CellValue_Number{Number: 2.0}},
    },
    true,
); err != nil {
    return err
}
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
