# TUI

VolvoxGrid TUI is the terminal-host path for VolvoxGrid. It uses the same grid engine, grid state, and plugin service as the pixel-rendered hosts, but targets terminal cells or ANSI byte streams instead of RGBA buffers.

This document is for developers who want to:

- understand the TUI architecture
- build a new terminal host
- extend the existing Go, `.NET`, or Java hosts
- change the renderer or input behavior safely

## Design Goals

The TUI stack follows a small set of design rules.

### One grid engine

There is no separate terminal-only grid model. TUI uses the same `VolvoxGrid` state and the same plugin service as the desktop, web, and mobile-style hosts. Selection, editing, sorting, layout, scrolling, and data loading stay in the shared engine path.

### Thin hosts

Terminal hosts should stay narrow. A host is responsible for terminal setup and application chrome. The plugin is responsible for terminal parsing, grid event translation, rendering, and output encoding.

### Viewport-based embedding

The grid renders into a rectangle inside the terminal, not necessarily the whole screen. That lets a host reserve rows for headers, footers, prompts, or debug panels while the grid stays unaware of that extra chrome.

### Protocol-driven integration

The TUI path is exposed through the same render-session protocol used elsewhere. Hosts send terminal capabilities, viewport changes, input bytes, and render buffers through `RenderInput`.

### Incremental output

The terminal byte-stream path keeps previous frame state and emits only changed spans. That avoids full-screen repaint behavior on every frame and keeps output practical for large grids.

## High-Level Model

At a high level, the stack is split into three layers:

1. Engine TUI renderer
2. Plugin session and terminal protocol logic
3. Language-specific terminal hosts and sample apps

The ownership split is intentional.

Host responsibilities:

- switch stdin/stdout into a usable terminal mode
- detect terminal size
- read raw input bytes
- write bytes to stdout
- decide where the grid viewport lives
- draw app-level chrome outside the grid viewport

Plugin responsibilities:

- parse terminal escape sequences
- translate decoded input into grid events
- apply terminal-specific navigation/edit policy
- render the grid into terminal cells
- diff frames
- encode ANSI output for thin hosts

Engine responsibilities:

- maintain grid state
- perform layout
- render the visible grid surface
- support terminal-specific geometry such as indicator bands and scrollbar layout

## Output Modes

VolvoxGrid supports two TUI-facing output styles.

### ANSI thin-host session

This is the main cross-language terminal-host path.

The host:

- sends raw input bytes with `TerminalInputBytes`
- sends `TerminalCapabilities`
- sends `TerminalViewport`
- provides a byte buffer through `BufferReady`
- writes the returned bytes to stdout

The plugin:

- parses the input stream
- renders the grid
- diffs against the previous frame
- encodes ANSI sequences into the host buffer

This is the path used by:

- Go terminal host
- `.NET` `VolvoxGridTerminalSession`
- Java desktop terminal session

### Raw `TuiCell` surface

This path renders directly into a host-owned array of terminal cells.

The engine-side cell shape is:

- `codepoint`
- `fg`
- `bg`
- `attr`

This mode is useful when the host wants to own terminal drawing itself instead of consuming ANSI bytes. In this repo, the clearest public wrapper for that path is `.NET` `VolvoxGridTuiSession`.

## Architecture

### 1. Engine renderer

Primary file:

- `engine/src/canvas_tui.rs`

Core responsibilities:

- defines `TuiCell`
- renders a `VolvoxGrid` into a terminal cell surface
- computes row-indicator width
- collects visible rows and columns for the viewport
- uses Unicode display width when placing text
- draws the header band, data rows, active dropdowns, and vertical scrollbar

This layer knows how to paint a terminal-shaped surface. It does not know how stdin bytes are read or how ANSI mouse escape sequences are parsed.

### 2. Plugin session layer

Primary files:

- `plugin/src/terminal_tui.rs`
- `plugin/src/lib.rs`

This layer connects terminal behavior to the shared render session.

It handles:

- `TerminalCapabilities`
- `TerminalViewport`
- `TerminalInputBytes`
- `TerminalCommand`
- `BufferReady`

Important behavior in this layer:

- raw terminal input parsing
- key, mouse, focus, and bracketed-paste decoding
- TUI-specific navigation/edit policy
- ANSI frame preparation and diff encoding
- session start and session end terminal sequences

### 3. Host wrappers

#### Go

Main files:

- `go/pkg/volvoxgrid/tui/terminal.go`
- `go/pkg/volvoxgrid/tui/app.go`
- `go/examples/tui`

The Go host handles terminal mode, resize detection, capability detection, input/output, and the run loop. The example controller adds app-level behavior such as demo switching, search prompts, and a debug panel.

#### .NET

Main files:

- `dotnet/src/common/VolvoxGridTerminal.cs`
- `dotnet/src/common/VolvoxGridTerminalHost.cs`
- `dotnet/examples/tui`
- `dotnet/src/common/VolvoxGridTui.cs`

The `.NET` code exposes both:

- a reusable thin-host terminal session API
- a lower-level raw-cell API

That makes `.NET` the clearest reference if you want to compare the byte-stream path against the direct-cell path.

#### Java

Main files:

- `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopTerminalHost.java`
- `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopTerminalSession.java`
- `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopTuiRunner.java`
- `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopTuiExample.java`

The Java implementation mirrors the Go and `.NET` split: one terminal host, one terminal session wrapper, one runner loop, and one example controller.

## Render Lifecycle

The normal thin-host lifecycle is:

1. Create or configure a grid with `RenderConfig.renderer_mode = RENDERER_TUI`.
2. Open a render-backed terminal session for that grid.
3. Detect terminal capabilities and send them.
4. Set the terminal viewport.
5. Forward raw input bytes to the session.
6. Provide a host buffer and request a frame.
7. Write returned bytes to stdout.
8. On resize, update the viewport and render again.
9. On shutdown, send the exit command or close the session cleanly.

At the protocol level, the important request types are:

- `TerminalCapabilities`
- `TerminalViewport`
- `TerminalInputBytes`
- `TerminalCommand`
- `BufferReady`

The important frame output fields are:

- `bytes_written`
- `required_capacity`
- `frame_kind`
- optional frame metrics

If `required_capacity` is larger than the supplied host buffer, the host should grow the buffer and render again.

## Input Model

The host forwards raw terminal bytes. The plugin parser turns those bytes into regular grid-facing events.

Supported input categories include:

- CSI and SS3 key sequences
- function keys
- UTF-8 text input
- SGR mouse down, move, up, and scroll
- focus notifications
- bracketed paste

After decoding, the plugin maps those events into the same grid input handlers used by non-terminal hosts.

## Terminal Navigation And Edit Policy

The terminal session currently applies a shared navigation-first policy when the grid is not already editing.

Built-in behavior:

- `Enter`, `F2`, and `i` start editing
- `Insert` toggles sticky auto-start edit
- `h`, `j`, `k`, `l` map to arrow navigation
- printable characters are not blindly forwarded when auto-start edit is off

This policy lives in the plugin TUI session layer. It is intentionally shared across hosts, but it is not yet exposed as a clean standalone public configuration surface.

## Layout Model

The TUI renderer is a real layouted grid surface, not a line dump.

Important pieces:

- row-indicator band
- one-row column-header band
- visible data columns
- vertical scrollbar
- optional dropdown popup

The renderer is viewport-aware:

- `origin_x`
- `origin_y`
- `width`
- `height`

That means the host can keep status lines or prompts outside the grid while the grid continues to render in local coordinates inside its rectangle.

For the ANSI thin-host path, the plugin uses a transparent background mode so the host terminal theme can remain visible where the grid does not need to paint an explicit background.

## End-To-End Flow

Thin-host flow:

```text
stdin bytes / resize / capability detection
    -> host wrapper
    -> RenderInput:
         terminal_capabilities
         terminal_viewport
         terminal_input
         buffer
    -> plugin render_session
    -> terminal parser + TUI session
    -> engine TuiRenderer
    -> ANSI diff encoder
    -> RenderOutput.FrameDone
    -> host writes bytes to stdout
```

Raw-cell flow:

```text
host-owned TuiCell buffer
    -> BufferReady(handle, stride, width, height)
    -> plugin render_session
    -> engine TuiRenderer
    -> FrameDone(dirty rect)
```

## Integration Guidance

### If you are building a thin terminal host

Use the ANSI byte-stream path.

Recommended responsibilities:

- keep terminal mode handling in the host
- keep prompts, footers, and debug overlays in the host
- treat the plugin as the owner of escape parsing and grid rendering
- reserve a viewport for the grid instead of teaching the grid about app chrome

### If you are building a custom terminal renderer

Use the raw-cell path if you need:

- custom diffing
- custom palette handling
- a non-ANSI transport
- tight integration with another terminal UI framework

In that model, the host owns presentation and the plugin only fills cell buffers.

## Repo Examples

The repo includes ready-to-run example hosts.

Interactive examples:

- `make go-tui-run`
- `make dotnet-tui-run`
- `make java-tui-run`

Non-interactive smoke checks:

- `make go-tui-smoke`
- `make dotnet-tui-smoke`
- `make java-tui-smoke`

Example demo selection:

```bash
--demo sales
--demo hierarchy
--demo stress
```

The examples are useful references, but they are not the API boundary. Some behavior in the examples is intentionally host-specific.

## What Lives In Samples Vs Shared TUI

Shared TUI behavior:

- terminal parsing
- terminal session lifecycle
- frame diffing
- TUI rendering
- built-in navigation/edit policy

Sample-level behavior:

- search prompt and search status UI
- demo switching
- debug panel content
- footer and header wording
- app-level quit shortcuts

If you are designing a new host, treat the sample controller behavior as optional application code, not as required engine behavior.

## Current Constraints

Useful implementation constraints to keep in mind:

- interactive Go and Java hosts are Unix-oriented
- the reusable `.NET` thin host also assumes Unix-like terminal handling
- search is currently sample-level behavior rather than a first-class shared TUI API
- the renderer has a vertical scrollbar but not a horizontal scrollbar yet
- themes are still color-field driven rather than named semantic terminal themes

## Recommended Reading Order

If you are modifying the TUI stack, start here:

1. `engine/src/canvas_tui.rs`
2. `plugin/src/terminal_tui.rs`
3. `plugin/src/lib.rs`
4. the host wrapper for your language:
   - `go/pkg/volvoxgrid/tui`
   - `dotnet/src/common/VolvoxGridTerminal.cs`
   - `dotnet/src/common/VolvoxGridTerminalHost.cs`
   - `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopTuiRunner.java`

That order matches the actual layering: rendering first, session integration second, host orchestration last.
