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

    if _, err := tea.NewProgram(m, tea.WithAltScreen()).Run(); err != nil {
        log.Fatal(err)
    }
}
```

## API

| Type | Purpose |
|---|---|
| `Column[T]` | Column definition: `{Field, Header, Value, Editable}` |
| `CellEdit[T]` | Committed-edit details: `{RowIndex, Row, ColumnIndex, Field, OldText, NewText}` |
| `Options[T]` | `FrameInterval`, `OnCellEdit`, `Width`, `Height` |
| `Model[T]` | Bubble Tea `Model` — implements `Init`, `Update`, `View` |

| Function | Purpose |
|---|---|
| `New(libPath, cols, rows)` | Create with default options |
| `NewWithOptions(libPath, cols, rows, opts)` | Create with custom `Options[T]` |
| `(*Model[T]).SetRows(rows)` | Replace the row dataset (call from your own `Update`) |
| `(*Model[T]).Close()` | Release native resources (idempotent) |

`Model[T]` owns the VolvoxGrid `Client`, `Grid`, and `TerminalSession`.
Always `defer m.Close()` so native resources are freed even if the program
exits early.

## Versioning & local development

This module pins `github.com/ivere27/volvoxgrid/go` as a dependency. During
local development, the published `go.mod` uses a `replace` directive
pointing at the sibling `../../go` checkout, so you can edit both modules
together. Released tags drop the `replace` and pin a real version — see
[`../../go/PUBLISHING.md`](../../go/PUBLISHING.md) for the tag conventions
(`adapters/bubbletea/vX.Y.Z`).
