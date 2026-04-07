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

## How It Works

The Go TUI host follows the thin-host architecture described in [TUI.md](../TUI.md):

1. The host switches the terminal into raw mode and detects capabilities
2. Raw stdin bytes are forwarded to the plugin via `TerminalInputBytes`
3. The plugin parses escape sequences, drives the grid engine, and encodes ANSI output
4. The host writes the returned bytes to stdout

The Go host is responsible for terminal setup, resize detection, and application chrome (headers, footers, prompts). The plugin owns escape parsing, grid rendering, and frame diffing.

## License

[Apache License 2.0](../LICENSE)
