# TUI

## Who this is for

You're an engineer building or modifying a terminal host for VolvoxGrid in Go, .NET, Java, or somewhere new. This doc walks through how the TUI stack works on top of the same engine that drives the pixel-rendered hosts.

After reading, you'll be able to:

- pick between the ANSI byte-stream path and the raw cell path
- wire a thin terminal host that forwards input bytes and writes frame bytes back out
- understand the navigation/edit policy that's currently baked into the runtime
- read the existing Go, .NET, and Java hosts and know what's shared vs sample-level

Next: the design rules that shape the whole stack.

## Design rules

Three rules guide everything below.

**One grid engine.** There's no terminal-only grid model. TUI uses the same `VolvoxGrid` state and the same runtime service as the desktop, web, and mobile hosts. Selection, editing, sorting, layout, scrolling, and data loading stay in the shared engine path.

**Thin hosts.** A terminal host handles terminal setup and application chrome. Terminal parsing, grid event translation, rendering, and output encoding belong to the runtime. Keep the host narrow.

**Viewport-based embedding.** The grid renders into a rectangle inside the terminal, not necessarily the whole screen. You can reserve rows for headers, footers, prompts, or debug panels while the grid stays unaware of that chrome.

The TUI path uses the same render-session protocol used elsewhere. Hosts send terminal capabilities, viewport changes, input bytes, and render buffers through `RenderInput`. The terminal byte-stream path keeps previous frame state and emits only changed spans, so output stays practical for large grids.

Next: two output styles, depending on how much the host wants to own.

## Two output styles

VolvoxGrid offers two TUI-facing output styles. Pick by how much terminal drawing you want to own.

### ANSI byte stream

This is the main cross-language thin-host path. The host:

- sends raw input bytes with `TerminalInputBytes`
- sends `TerminalCapabilities`
- sends `TerminalViewport`
- provides a byte buffer through `BufferReady`
- writes the returned bytes to stdout

The runtime parses the input stream, renders the grid, diffs against the previous frame, and encodes ANSI sequences into the host buffer. This is the path used by the Go terminal host, .NET `VolvoxGridTerminalSession`, and the Java desktop terminal session.

### Raw `TuiCell` surface

This path renders directly into a host-owned array of terminal cells. The engine-side cell shape is:

- `codepoint`
- `fg`
- `bg`
- `attr`

Use this when you want to own terminal drawing instead of consuming ANSI bytes. The clearest public wrapper in the repo is .NET `VolvoxGridTuiSession`.

Next: how those styles map to actual layers.

## Architecture

Here's the layering and where each concern lives:

```text
host wrapper (Go / .NET / Java)
    -> runtime session (terminal_tui.rs + lib.rs)
    -> engine TUI renderer (canvas_tui.rs)
```

The ownership split is intentional.

Host responsibilities:

- switch stdin/stdout into a usable terminal mode
- detect terminal size
- read raw input bytes
- write bytes to stdout
- decide where the grid viewport lives
- draw app-level chrome outside the grid viewport

Runtime responsibilities:

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

### Engine renderer

File: `engine/src/canvas_tui.rs`.

This layer defines `TuiCell`, renders a `VolvoxGrid` into a terminal cell surface, computes row-indicator width, collects visible rows and columns for the viewport, uses Unicode display width when placing text, and draws the header band, data rows, active dropdowns, and the vertical scrollbar.

It knows how to paint a terminal-shaped surface. It does not know how stdin bytes are read or how ANSI mouse escape sequences are parsed.

### Runtime session layer

Files: `runtime/src/terminal_tui.rs`, `runtime/src/lib.rs`.

This layer connects terminal behavior to the shared render session. It handles `TerminalCapabilities`, `TerminalViewport`, `TerminalInputBytes`, `TerminalCommand`, and `BufferReady`. It also handles raw terminal input parsing; key, mouse, focus, and bracketed-paste decoding; TUI-specific navigation/edit policy; ANSI frame preparation and diff encoding; and session start/end terminal sequences.

### Host wrappers

Existing wrappers in the repo:

- Go: `go/pkg/volvoxgrid/tui/terminal.go`, `go/pkg/volvoxgrid/tui/app.go`, examples under `go/examples/tui`.
- .NET: `dotnet/src/common/VolvoxGridTerminal.cs`, `dotnet/src/common/VolvoxGridTerminalHost.cs`, `dotnet/src/common/VolvoxGridTui.cs`, examples under `dotnet/examples/tui`.
- Java: `VolvoxGridDesktopTerminalHost.java`, `VolvoxGridDesktopTerminalSession.java`, `VolvoxGridDesktopTuiRunner.java`, `VolvoxGridDesktopTuiExample.java` under `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/`.

.NET is the clearest reference if you want to compare the byte-stream path against the direct-cell path. Java mirrors the Go and .NET split: one terminal host, one terminal session wrapper, one runner loop, one example controller.

Next: how a frame moves through.

## Render lifecycle

The normal thin-host lifecycle:

1. Create or configure a grid with `RenderConfig.renderer_mode = RENDERER_TUI`.
2. Open a render-backed terminal session for that grid.
3. Detect terminal capabilities and send them.
4. Set the terminal viewport.
5. Forward raw input bytes to the session.
6. Provide a host buffer and request a frame.
7. Write returned bytes to stdout.
8. On resize, update the viewport and render again.
9. On shutdown, send the exit command or close the session cleanly.

At the protocol level, the important request types are `TerminalCapabilities`, `TerminalViewport`, `TerminalInputBytes`, `TerminalCommand`, and `BufferReady`. The important frame output fields are `bytes_written`, `required_capacity`, `frame_kind`, and optional frame metrics.

If `required_capacity` is larger than the buffer you supplied, grow it and render again.

### Thin-host flow

Here's the flow from start to finish:

```text
stdin bytes / resize / capability detection
    -> host wrapper
    -> RenderInput:
         terminal_capabilities
         terminal_viewport
         terminal_input
         buffer
    -> runtime render_session
    -> terminal parser + TUI session
    -> engine TuiRenderer
    -> ANSI diff encoder
    -> RenderOutput.FrameDone
    -> host writes bytes to stdout
```

### Raw-cell flow

Here's the flow from start to finish:

```text
host-owned TuiCell buffer
    -> BufferReady(handle, stride, width, height)
    -> runtime render_session
    -> engine TuiRenderer
    -> FrameDone(dirty rect)
```

Next: how input gets in.

## Input model

The host forwards raw terminal bytes. The runtime parser turns those bytes into the same grid input events used elsewhere.

Decoded categories include:

- CSI and SS3 key sequences
- function keys
- UTF-8 text input
- SGR mouse down, move, up, and scroll
- focus notifications
- bracketed paste

After decoding, the runtime maps these events into the same grid input handlers used by non-terminal hosts.

Next: a few terminal-specific keyboard rules.

## Navigation and edit policy

The terminal session applies a shared navigation-first policy when the grid is not already editing.

Built-in behavior:

- `Enter`, `F2`, and `i` start editing
- `Insert` toggles sticky auto-start edit
- `h`, `j`, `k`, `l` map to arrow navigation
- printable characters aren't blindly forwarded when auto-start edit is off

This policy lives in the runtime TUI session layer. It's intentionally shared across hosts, but it isn't yet exposed as a clean standalone public configuration surface.

Next: how the grid coexists with host chrome.

## Layout model

The TUI renderer is a real layouted grid surface, not a line dump. The pieces are:

- row-indicator band
- one-row column-header band
- visible data columns
- vertical scrollbar
- optional dropdown popup

The renderer is viewport-aware via `origin_x`, `origin_y`, `width`, and `height`. You can keep status lines or prompts outside the grid while the grid renders in local coordinates inside its rectangle.

For the ANSI thin-host path, the runtime uses a transparent background mode so the terminal theme remains visible where the grid doesn't need to paint an explicit background.

Next: working hosts you can run and read.

## Existing host examples

The Go host handles terminal mode, resize detection, capability detection, input/output, and the run loop. The example controller layers on demo switching, search prompts, and a debug panel.

The .NET code exposes both the thin-host terminal session API and the lower-level raw-cell API. Comparing the two side by side is the fastest way to see the difference.

The Java implementation mirrors the Go and .NET split with one terminal host, one session wrapper, one runner loop, and one example controller.

Next: ways to actually run them.

## Try it yourself

Interactive examples:

- `make go-tui-run`
- `cd adapters/bubbletea && make tui-run`
- `make dotnet-tui-run`
- `make java-tui-run`

Non-interactive smoke checks:

- `make go-tui-smoke`
- `cd adapters/bubbletea && make tui-smoke`
- `make dotnet-tui-smoke`
- `make java-tui-smoke`

Pick a demo:

```bash
--demo sales
--demo hierarchy
--demo stress
```

The examples are useful references but they aren't the API boundary. Some behavior in the examples is intentionally host-specific.

Next: where to draw the line between sample code and shared infrastructure.

## Shared TUI vs sample-level

Shared TUI behavior (lives in the engine and runtime):

- terminal parsing
- terminal session lifecycle
- frame diffing
- TUI rendering
- built-in navigation/edit policy

Sample-level behavior (lives in example controllers):

- search prompt and search status UI
- demo switching
- debug panel content
- footer and header wording
- app-level quit shortcuts

If you're designing a new host, treat the sample controller behavior as optional application code, not as required engine behavior.

Next: what's true today.

## Current constraints

- Interactive Go and Java hosts are Unix-oriented.
- The reusable .NET thin host also assumes Unix-like terminal handling.
- Search is sample-level behavior, not yet a first-class shared TUI API.
- The renderer has a vertical scrollbar but not a horizontal scrollbar yet.
- Themes are still color-field driven rather than named semantic terminal themes.

Next: where to start reading.

## Reading order through the code

If you're modifying the TUI stack, start here:

1. `engine/src/canvas_tui.rs`
2. `runtime/src/terminal_tui.rs`
3. `runtime/src/lib.rs`
4. The host wrapper for your language:
   - `go/pkg/volvoxgrid/tui`
   - `dotnet/src/common/VolvoxGridTerminal.cs`
   - `dotnet/src/common/VolvoxGridTerminalHost.cs`
   - `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopTuiRunner.java`

That order matches the actual layering: rendering first, session integration second, host orchestration last.
