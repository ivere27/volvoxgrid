# GUI

VolvoxGrid GUI is the pixel-rendered host path for VolvoxGrid. It uses a retained grid model in Rust, renders that model into either an RGBA pixel buffer or a GPU surface, and lets platform hosts handle windowing, input plumbing, and native overlays.

This document is for developers who want to:

- understand the pixel-grid engine architecture
- build a new GUI host
- extend the existing Android, Java, Flutter, Web, or `.NET` hosts
- change the renderer or host contract safely

## Design Goals

The GUI stack follows a few core rules.

### One retained grid model

There is one `VolvoxGrid` state object per grid. It owns rows, columns, cells, layout, styling, selection, scrolling, editing state, sorting, spans, outline data, animations, and pending events.

The renderer does not own application state. It paints the current grid state.

### Host-neutral rendering

The engine is not tied to Swing, Flutter, Android views, HTML tables, or WinForms controls. Hosts interact with it through protobuf messages and render sessions.

### Pixel-first output

The GUI path renders actual pixels, not host-native table widgets. That keeps rendering behavior, layout, and interactions consistent across platforms.

### Two rendering backends, one contract

GUI hosts use one of two rendering targets:

- CPU rendering into a host-owned RGBA buffer
- GPU rendering into a host-provided native surface

Both backends are driven through the same render session and the same grid state.

### Thin platform shells

Hosts should own platform concerns:

- windows, views, canvases, and surfaces
- input capture
- OS text input / IME
- native edit and dropdown overlays when needed
- frame scheduling

The engine and plugin own:

- grid state
- layout
- rendering
- grid semantics
- protocol translation

## High-Level Architecture

The GUI stack is layered like this:

1. Retained grid state
2. Backend-agnostic canvas pipeline
3. CPU and GPU renderers
4. Plugin render/event streams
5. Platform hosts

## 1. Retained Grid State

Primary file:

- `engine/src/grid.rs`

`VolvoxGrid` is the central state container. It owns:

- sparse cell storage
- column and row properties
- grid-wide style state
- per-cell style overrides
- selection state
- scroll state
- edit state
- span and merge state
- outline state
- sort state
- drag state
- animation state
- layout cache
- event queue

This is a retained-mode engine. Hosts mutate grid state through API calls and input events, then ask for frames when the grid is dirty.

Important retained-mode behavior:

- `mark_dirty()` invalidates render-visible state and text-derived caches
- `mark_dirty_visual()` keeps caches but schedules another frame
- `ensure_layout()` rebuilds layout lazily and updates scroll bounds
- `clear_dirty()` keeps the grid dirty while animations, scrollbar fade, background work, or pull-to-refresh still need frames

That means hosts do not need to recompute layout or paint logic themselves. They only need to keep rendering while the engine says more frames are needed.

## 2. Canvas Pipeline

Primary file:

- `engine/src/canvas.rs`

The engine renders through a backend-agnostic `Canvas` trait. That trait exposes core drawing primitives such as:

- fill and blend rects
- lines and pixels
- text measurement and text drawing
- image blits
- checker fills

All grid painting is composed on top of that shared interface. The same render orchestration is reused by both CPU and GPU paths.

This is the key separation:

- `canvas.rs` defines what gets painted
- backend implementations define how pixels or instances are emitted

## 3. Rendering Backends

### CPU renderer

Primary files:

- `engine/src/render.rs`
- `engine/src/canvas_cpu.rs`

The CPU path renders into a host-owned RGBA buffer. The host sends a `BufferReady` message containing:

- native buffer handle
- stride
- width
- height

The plugin maps that buffer and calls the CPU renderer, which paints the grid into the shared memory region.

Important CPU-path behavior:

- shared `canvas.rs` pipeline
- optional scroll-blit reuse through `ScrollCache`
- shared text pipeline
- dirty rect reporting through `FrameDone`

This is the most portable GUI path and the easiest path for new hosts.

### GPU renderer

Primary files:

- `engine/src/gpu_render.rs`
- `engine/src/canvas_gpu.rs`

The GPU path uses `wgpu` and renders directly to a host-provided native surface. The host sends `GpuSurfaceReady` with:

- native surface handle
- width
- height

The GPU renderer configures or reconfigures a `wgpu::Surface`, then renders the current grid into that surface.

Important GPU-path behavior:

- uses the same shared grid/layout logic
- emits GPU-backed rectangles and textured quads
- uses `GlyphAtlas` for text/image texture data
- supports surface recreation on resize or surface loss
- falls back to CPU mode if GPU initialization or surface configuration fails

In practice, the GPU path is best when the platform can provide a stable native surface or platform texture.

## 4. Plugin Session Layer

Primary file:

- `plugin/src/lib.rs`

The plugin is the bridge between platform hosts and the engine.

It exposes two important streaming interfaces:

- `RenderSession(stream RenderInput) returns (stream RenderOutput)`
- `EventStream(GridHandle) returns (stream GridEvent)`

### Render session responsibilities

The render session receives:

- `ViewportState`
- `PointerEvent`
- `KeyEvent`
- `ScrollEvent`
- `ZoomEvent`
- `BufferReady`
- `GpuSurfaceReady`
- `EventDecision`

For CPU rendering, the session:

1. applies input
2. updates layout and animation state
3. renders into the supplied RGBA buffer
4. returns `FrameDone`

For GPU rendering, the session:

1. applies input
2. configures the native surface if needed
3. renders to the surface
4. returns `GpuFrameDone`

The render session also emits immediate UI-facing outputs:

- `SelectionUpdate`
- `CursorChange`
- `EditRequest`
- `DropdownRequest`
- `TooltipRequest`

These are not the same as the long-lived semantic event stream. They exist so the host can react immediately to render-time UI needs.

### Event stream responsibilities

The event stream exposes semantic grid events such as:

- focus changes
- selection changes
- before/after edit
- validation
- before/after sort
- scroll events
- mouse and keyboard events
- refresh and error events

Cancelable events use `EventDecision` on the render session rather than embedding a cancel field directly in the event payload.

This split is important:

- use `RenderOutput` for immediate render-coupled UI behavior
- use `GridEvent` for semantic host callbacks and application logic

## 5. Platform Hosts

The repo already contains several GUI host styles.

### Android

Primary file:

- `android/volvoxgrid-android/src/main/java/io/github/ivere27/volvoxgrid/VolvoxGridView.kt`

The Android host is a `SurfaceView`-based shell. It supports:

- CPU shared-buffer rendering
- GPU surface rendering
- touch, wheel, key, and pinch-zoom forwarding
- IME integration
- native `EditText` overlay for editing
- event stream listeners

It is the clearest reference for a host that supports both CPU and GPU modes over the same contract.

### Java desktop

Primary file:

- `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopPanel.java`

The Swing panel is a CPU shared-buffer host. It owns:

- panel lifecycle
- buffer allocation
- repaint scheduling
- input forwarding
- event-stream consumption

It is a good reference for a desktop CPU host with native widget integration.

### Flutter

Primary pieces:

- `flutter/lib/volvoxgrid_controller.dart`
- `flutter/README.md`

Flutter uses the same native engine through FFI:

- CPU mode renders into a shared RGBA buffer and displays it via Flutter image plumbing
- Android GPU mode renders into a Flutter platform texture

Flutter is a good reference for a cross-platform host where the Dart controller is high-level but the rendering contract remains the same underneath.

### Web

Primary pieces:

- `web/js/src/volvoxgrid.ts`
- `web/js/src/volvoxgrid-element.ts`

The web host wraps the WASM build and renders into an HTML canvas. It is useful as a reference for a browser shell that still uses the same grid engine ideas, even though the integration mechanics differ from native plugin hosts.

### `.NET`

Relevant pieces:

- `dotnet/src/common`

The `.NET` side exposes controller and WinForms-oriented integration over the same native engine. It is also useful because it includes host text-rendering integration points.

## Render Lifecycle

### CPU render lifecycle

The usual CPU path looks like this:

1. Host creates a grid with an initial viewport and scale.
2. Host configures layout, indicators, editing, selection, rendering, and data.
3. Host opens a render session.
4. Host sends `ViewportState` whenever size changes.
5. Host allocates a direct RGBA buffer and sends `BufferReady`.
6. Plugin renders into that buffer.
7. Plugin returns `FrameDone` with dirty rect and optional metrics.
8. Host blits or presents the resulting pixels.

Flow:

```text
host buffer
    -> BufferReady(handle, stride, width, height)
    -> plugin render_session
    -> engine Renderer / Canvas
    -> RGBA pixels written in place
    -> FrameDone(dirty rect, metrics)
```

### GPU render lifecycle

The usual GPU path looks like this:

1. Host selects a GPU renderer mode.
2. Host creates or exposes a native surface handle.
3. Host sends `GpuSurfaceReady`.
4. Plugin lazily creates `GpuRenderer` if needed.
5. Plugin configures or reconfigures the `wgpu` surface.
6. Engine renders directly to the surface.
7. Plugin returns `GpuFrameDone`.

Flow:

```text
native surface handle
    -> GpuSurfaceReady(handle, width, height)
    -> plugin render_session
    -> GpuRenderer + wgpu surface
    -> present to native surface
    -> GpuFrameDone
```

If surface setup fails, the plugin can drop back to CPU mode rather than leaving the grid unusable.

## Input Lifecycle

Hosts forward user input as render-session messages:

- `PointerEvent`
- `KeyEvent`
- `ScrollEvent`
- `ZoomEvent`

The plugin translates those into shared engine input handlers. That keeps interaction behavior aligned across hosts.

Examples:

- touch and mouse presses become pointer down/up/move
- wheel and gesture deltas become scroll events
- keyboard navigation and editing become key down/press/up
- pinch gestures become zoom begin/update/end

Hosts should translate platform coordinates into viewport-local grid coordinates before sending them.

## Immediate UI Requests Vs Semantic Events

GUI hosts usually need both render-coupled UI outputs and application-level events.

### Immediate UI requests

These arrive on `RenderOutput`:

- `EditRequest`
- `DropdownRequest`
- `TooltipRequest`
- `CursorChange`
- `SelectionUpdate`

Typical host behavior:

- show an edit overlay at the requested pixel rect
- open a dropdown popup
- show or hide a tooltip
- update the cursor
- sync selection state if the host mirrors it

### Semantic events

These arrive on `EventStream` as `GridEvent`.

Typical host behavior:

- notify application callbacks
- validate or cancel edits
- react to sort, scroll, or selection changes
- listen for lifecycle and error events

Use `EventDecision` when the host needs to cancel a cancelable event such as:

- `BeforeEdit`
- `CellEditValidate`
- `BeforeSort`

## Text Rendering Strategy

Text is part of the GUI engine contract, but it has extension points.

### Default path

The engine normally uses `TextEngine` for measurement and shaping.

### Full replacement: `TextRenderer`

A platform can replace the whole text pipeline with a custom renderer. This is used when the host has a better or more appropriate native text stack.

Examples in the repo:

- Web Canvas2D text renderer
- Android Canvas text renderer for lite builds
- optional GDI-based bridge on `.NET`

Use this when the host should handle both:

- text measurement
- glyph rasterization or text drawing

### Fallback path: `ExternalGlyphRasterizer`

A host can also provide per-glyph fallback rasterization while leaving layout and shaping inside the engine.

Use this when the default shaping path is correct, but some glyph coverage must come from a host-native font stack.

## Host Responsibilities

If you are building a new GUI host, keep these boundaries clear.

The host should own:

- view or widget lifecycle
- viewport sizing
- direct buffer or native surface ownership
- input capture
- IME and composition
- native overlay widgets for edit/dropdown if desired
- frame scheduling

The host should not own:

- grid layout rules
- selection logic
- editing state machine
- rendering rules
- sort behavior
- scroll bounds

That logic already lives in the engine.

## Choosing CPU Vs GPU

Choose CPU when:

- you want the simplest host integration
- portability matters more than peak rendering throughput
- your platform does not expose a clean native surface handle
- you are embedding in a traditional widget toolkit

Choose GPU when:

- the host can provide a stable native surface
- pixel-copy overhead matters
- the platform already has a compatible surface or platform texture story

A common strategy is:

- start with CPU
- add GPU later as an optional host optimization

## Current Constraints

Useful constraints to keep in mind:

- not every host exposes both CPU and GPU paths
- Flutter desktop currently uses CPU mode
- GPU surface handling is platform-specific even though the engine contract is shared
- edit/dropdown overlays are host-driven, so exact UX can vary by platform
- some hosts may redraw full surfaces even when the plugin reports only a dirty rect

## Recommended Reading Order

If you are modifying the GUI stack, read in this order:

1. `engine/src/grid.rs`
2. `engine/src/canvas.rs`
3. `engine/src/render.rs`
4. `engine/src/gpu_render.rs`
5. `plugin/src/lib.rs`
6. the host for your platform:
   - Android: `android/volvoxgrid-android/src/main/java/io/github/ivere27/volvoxgrid/VolvoxGridView.kt`
   - Java desktop: `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopPanel.java`
   - Flutter: `flutter/lib/volvoxgrid_controller.dart`
   - Web: `web/js/src/volvoxgrid.ts`
   - `.NET`: `dotnet/src/common`

That order matches the real layering: retained state first, render pipeline second, plugin bridge third, host shell last.
