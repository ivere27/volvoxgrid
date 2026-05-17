# VolvoxGrid for Go

VolvoxGrid for Go is a client to the native Rust engine plus a reusable terminal host. You get TUI-grade rendering, escape parsing, and frame diffing without writing any of it yourself. Point it at the shared library, hand it some rows, and let the engine do the drawing.

This README walks you through the two ways you'll typically use the library: the low-level core wrapper when you're building your own terminal host, and the Bubble Tea adapter when you want a typed, data-first model in the Elm style.

## Prerequisites

Before you start, you'll need:

- Go 1.24 or newer. The core module is pinned at `go 1.24` because transitive dependencies (`golang.org/x/sys v0.36.0` and `bubbletea v1.3.10`) require it.
- The native `volvoxgrid` shared library. Build it from the repo root with `make build` for a debug build or `make release` for an optimized one.

Point your code at the resulting `libvolvoxgrid.{so,dylib,dll}` — pass the path to `volvoxgrid.NewClient(...)` directly, or read it from an environment variable. The Bubble Tea example below reads `VOLVOXGRID_LIB`; pick whichever convention fits your project.

## Quick start

The fastest way to confirm the library is wired up is to create a client, spin up a grid, and ask it to load a built-in demo. No terminal, no rendering loop — just the engine handshake:

```go
package main

import (
    "log"

    "github.com/ivere27/volvoxgrid/go/pkg/volvoxgrid"
)

func main() {
    client, err := volvoxgrid.NewClient("path/to/libvolvoxgrid.so")
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

If that runs cleanly, your native library is loadable and the client can talk to it. From here you have two paths.

## Two paths

You can use VolvoxGrid in Go at two levels of abstraction. Pick the one that matches your project.

- **Low-level core** — `github.com/ivere27/volvoxgrid/go/pkg/volvoxgrid`. Direct client/grid handles, raw cell updates, your own terminal host. Use this when you're embedding the engine into a non-standard host or building something other than a Bubble Tea app.
- **Bubble Tea adapter** — `github.com/ivere27/volvoxgrid/adapters/bubbletea`. A typed, data-first wrapper that plugs into the Elm architecture. Use this when you already have row structs and want a grid that updates as your model changes.

The adapter ships in a sibling module so the core wrapper stays free of charm dependencies. If you only need the core, you won't pull in Bubble Tea.

## Bubble Tea adapter

When your app already has row structs and follows the Elm architecture, the Bubble Tea adapter saves you from writing column descriptors and edit plumbing by hand. You declare typed columns, hand it a slice of rows, and the model takes care of refreshes.

Install it alongside Bubble Tea itself:

```sh
go get github.com/ivere27/volvoxgrid/adapters/bubbletea
```

Then declare your row type, describe the columns, and start a Bubble Tea program:

```go
package main

import (
    "fmt"
    "log"
    "os"

    tea "github.com/charmbracelet/bubbletea"
    "github.com/ivere27/volvoxgrid/adapters/bubbletea"
)

type Product struct {
    Name  string
    Price float64
}

func main() {
    products := []Product{{"Coffee", 3.50}, {"Tea", 2.75}}
    cols := []bubbletea.Column[Product]{
        {Field: "name", Header: "Name", Value: func(p Product) string { return p.Name }},
        {Field: "price", Header: "Price",
            Value:    func(p Product) string { return fmt.Sprintf("%.2f", p.Price) },
            Editable: true},
    }

    m, err := bubbletea.New(os.Getenv("VOLVOXGRID_LIB"), cols, products)
    if err != nil {
        log.Fatal(err)
    }
    defer m.Close()

    if _, err := tea.NewProgram(m, tea.WithAltScreen()).Run(); err != nil {
        log.Fatal(err)
    }
}
```

The adapter exposes `Column[T]`, `CellEdit[T]`, `Options[T]`, and `Model[T].SetRows` for the common cases. Reach for `SetRows` whenever your model changes upstream and you want the grid to reflect the new slice.

## Module structure

The Go side of VolvoxGrid is split into two modules so you only pay for what you import.

| Module | Purpose |
|---|---|
| `github.com/ivere27/volvoxgrid/go` | Core wrapper. Deps: `synurang`, `grpc`, `protobuf` only. |
| `github.com/ivere27/volvoxgrid/adapters/bubbletea` | Bubble Tea typed-row adapter. |

If you're embedding the engine into your own runtime, depend only on the core. If you want the typed model, add the adapter — it depends on the core module transitively.

## Building a custom TUI host

When Bubble Tea isn't a fit (you have your own input loop, your own chrome, or you're embedding into an existing TUI), you can drive the engine directly through the `tui` subpackage. The pieces you'll touch:

- `tui.Terminal` — switches the terminal into raw mode, detects size and capabilities, and exposes the input byte stream.
- `tui.Controller` — the interface you implement to react to runtime events and inject app-level chrome (headers, footers, prompts).
- `tui.Run(...)` — the run loop that wires terminal input into the runtime and writes the runtime's ANSI output back to stdout.

For a working sample controller, look at `go/examples/tui`. It loads a demo, handles `--demo` flags, and shows the minimum a custom host needs to do.

## Data operations

Once you have a `Grid`, the wrapper exposes a small set of convenience methods for the operations you'll reach for most often.

### LoadData

Use `LoadData` when you have CSV or JSON bytes from a file, network response, or test fixture and want the engine to parse them for you. Passing `nil` options auto-detects CSV.

```go
import pb "github.com/ivere27/volvoxgrid/go/api/v1"

// CSV with auto-detection
if _, err := grid.LoadData(
    []byte("Name,Price,Qty\nWidget A,29.99,150\nWidget B,49.99,200"),
    nil,
); err != nil {
    return err
}

// JSON matrix with explicit header policy
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

### UpdateCells

Use `UpdateCells` when you want to write a batch of cells in one round trip. The `atomic` flag makes the runtime apply the whole batch in a single frame, so you won't see a half-updated grid mid-render.

```go
if err := grid.UpdateCells([]*pb.CellUpdate{
    {Row: 0, Col: 0, Value: &pb.CellValue{Value: &pb.CellValue_Text{Text: "Alpha"}}},
    {Row: 0, Col: 1, Value: &pb.CellValue{Value: &pb.CellValue_Number{Number: 29.99}}},
    {Row: 1, Col: 0, Value: &pb.CellValue{Value: &pb.CellValue_Text{Text: "Beta"}}},
}, true /* atomic */); err != nil {
    return err
}
```

### GetCells

Use `GetCells` when you need to read a range back out — for tests, exports, or pushing values into another widget. The trailing booleans (`includeStyle`, `includeChecked`, `includeTyped`) let you opt in to the heavier payload only when you need it.

```go
resp, err := grid.GetCells(0, 0, 1, 2, false, false, false)
if err != nil {
    return err
}
for _, cell := range resp.Cells {
    fmt.Printf("%d,%d = %s\n", cell.Row, cell.Col, cell.Value.GetText())
}
```

### Clear

Use `Clear` when you want to wipe state without destroying the grid. The scope picks what gets cleared; the region picks where.

```go
if err := grid.Clear(
    pb.ClearScope_CLEAR_EVERYTHING,
    pb.ClearRegion_CLEAR_SCROLLABLE,
); err != nil {
    return err
}
```

Scopes you can pass: `CLEAR_EVERYTHING`, `CLEAR_FORMATTING`, `CLEAR_DATA`, `CLEAR_SELECTION`. Region `CLEAR_SCROLLABLE` is the most common — it leaves frozen headers and footers alone.

### LoadTable

Use `LoadTable` when you have a typed flat array and want to skip parsing entirely. It's the fastest path for bulk loads from in-memory data because each value is already typed.

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

## Running the example

The repo ships an interactive TUI example under `go/examples/tui`. To try it:

```bash
# Build the native library first
make build

# Interactive TUI example
make go-tui-run

# Non-interactive smoke check (useful in CI)
make go-tui-smoke
```

The example accepts demo selection flags so you can flip between datasets without recompiling:

```bash
make go-tui-run ARGS="--demo sales"
make go-tui-run ARGS="--demo hierarchy"
make go-tui-run ARGS="--demo stress"
```

`sales` is a small tabular demo, `hierarchy` exercises tree rendering, and `stress` loads enough rows to make frame diffing earn its keep.

## How it works

VolvoxGrid follows a thin-host architecture (the full write-up is in [TUI.md](../TUI.md)). The split keeps the host code in Go small and the rendering predictable across platforms.

1. The host switches the terminal into raw mode and detects capabilities.
2. Raw stdin bytes are forwarded to the runtime via `TerminalInputBytes`.
3. The runtime parses escape sequences, drives the grid engine, and encodes ANSI output.
4. The host writes the returned bytes to stdout.

That gives you a clean ownership boundary:

- **Host owns** terminal setup, resize detection, and app chrome (headers, footers, prompts).
- **Runtime owns** escape parsing, grid rendering, and frame diffing.

So whether you're using Bubble Tea or driving `tui.Run` yourself, the runtime's job is the same and the host stays small.

## What's next

- [../TUI.md](../TUI.md) — the full architecture write-up for the terminal host, including how escape parsing and frame diffing fit together.
- [../ARCHITECTURE.md](../ARCHITECTURE.md) — the cross-platform engine architecture.
- [./PUBLISHING.md](./PUBLISHING.md) — how to cut releases for the core and adapter modules.

## License

[Apache License 2.0](../LICENSE)
