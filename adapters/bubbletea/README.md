# VolvoxGrid — Bubble Tea adapter

A [Bubble Tea](https://github.com/charmbracelet/bubbletea) `Model` that
renders a VolvoxGrid `TerminalSession` behind a typed-row, typed-column API.
Pass typed `Column[T]` definitions and a row slice; the model drives the
underlying engine and surfaces ANSI frames via `View()`.

This is a separate Go module so the core
`github.com/ivere27/volvoxgrid/go` wrapper does not pull in charm
dependencies.

## Install

```sh
go get github.com/ivere27/volvoxgrid/adapters/bubbletea
```

You also need the platform-specific shared library
(`libvolvoxgrid.{so,dylib,dll}`) on disk and reachable from your binary —
distribute it alongside your app (see VolvoxGrid release artifacts).

## Quick start

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
    products := []Product{
        {"Coffee", 3.50},
        {"Tea", 2.75},
    }

    cols := []bubbletea.Column[Product]{
        {Field: "name", Header: "Name", Value: func(p Product) string { return p.Name }},
        {
            Field:    "price",
            Header:   "Price",
            Value:    func(p Product) string { return fmt.Sprintf("%.2f", p.Price) },
            Editable: true,
        },
    }

    libPath := os.Getenv("VOLVOXGRID_LIB") // e.g. ./libvolvoxgrid.so

    m, err := bubbletea.NewWithOptions(libPath, cols, products, bubbletea.Options[Product]{
        OnCellEdit: func(e bubbletea.CellEdit[Product]) {
            log.Printf("row %d %s: %q -> %q", e.RowIndex, e.Field, e.OldText, e.NewText)
        },
    })
    if err != nil {
        log.Fatal(err)
    }
    defer m.Close()

    if _, err := tea.NewProgram(m, tea.WithAltScreen(), tea.WithMouseCellMotion()).Run(); err != nil {
        log.Fatal(err)
    }
}
```

Use `tea.WithMouseCellMotion()` on the containing program. The adapter also
requests mouse tracking from `Init`, but Bubble Tea applies that command after
startup; the program option is the reliable path for double-click editing and
drag selection.

## Example

This module includes a runnable typed-row TUI example:

```sh
cd adapters/bubbletea
make tui-run

# Non-interactive check.
make tui-smoke
```

The source is in [`examples/tui`](examples/tui). It mirrors the Go TUI sample
data modes and also keeps the original simple typed-row example: `--demo simple`,
`--demo sales`, `--demo hierarchy`, and `--demo stress`. The running TUI
switches demos with `F5` Simple, `F6` Sales, `F7` Hierarchy, and `F8` Stress.
`F12` toggles a debug panel like the Go TUI sample. Demo switches reuse the
same adapter model and native terminal session. Simple, Sales, and Hierarchy
are loaded as typed Go rows; Stress uses the native million-row loader while
still running through the Bubble Tea adapter.

## Native grid features

The Bubble Tea adapter does not reimplement tree rows, dropdown lists,
checkboxes, subtotals, merging, or formatting. Those are native VolvoxGrid
features. Pass the same proto metadata you would use with the Go TUI host via
`Options.GridConfig`, `Options.ColumnDefs`, `Options.RowDefs`, and
`Options.ConfigureGrid`. For native loaders that own the row data, such as the
stress demo, set `Options.GridRows`/`GridCols` so the adapter sizes the grid
without creating typed rows or synthetic row metadata.

## API

| Type | Purpose |
|---|---|
| `Column[T]` | Column definition: `{Field, Header, Value, Editable}` |
| `CellEdit[T]` | Committed-edit details: `{RowIndex, Row, ColumnIndex, Field, OldText, NewText}` |
| `Options[T]` | `FrameInterval`, `OnCellEdit`, `Width`, `Height`, native `GridRows`, `GridCols`, `GridConfig`, `ColumnDefs`, `RowDefs`, `ConfigureGrid` |
| `Model[T]` | Bubble Tea `Model` — implements `Init`, `Update`, `View` |

| Function | Purpose |
|---|---|
| `New(libPath, cols, rows)` | Create with default options |
| `NewWithOptions(libPath, cols, rows, opts)` | Create with custom `Options[T]` |
| `(*Model[T]).SetRows(rows)` | Replace the row dataset (call from your own `Update`) |
| `(*Model[T]).Reset(cols, rows, opts)` | Replace columns/data/config while keeping the same terminal session |
| `(*Model[T]).LoadData`, `LoadDemo`, `DefineColumns`, etc. | Native grid-operation wrappers for adapter-hosted apps |
| `(*Model[T]).Close()` | Release native resources (idempotent) |

`Model[T]` owns the VolvoxGrid `Client`, `Grid`, and `TerminalSession`.
Always `defer m.Close()` so native resources are freed even if the program
exits early.

`Column.Editable` controls whether committed edits for that typed column are
reported through `OnCellEdit`. It does not block the native TUI editor; edit
activation, selection, sorting, mouse handling, and keyboard handling remain in
the shared VolvoxGrid runtime.

## Versioning & local development

This module pins `github.com/ivere27/volvoxgrid/go` as a dependency. During
local development, the published `go.mod` uses a `replace` directive
pointing at the sibling `../../go` checkout, so you can edit both modules
together. Released tags drop the `replace` and pin a real version — see
[`../../go/PUBLISHING.md`](../../go/PUBLISHING.md) for the tag conventions
(`adapters/bubbletea/vX.Y.Z`).
