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

The engine and runtime own:

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
4. Runtime render/event streams
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

The runtime maps that buffer and calls the CPU renderer, which paints the grid into the shared memory region.

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
- reports an unrendered GPU frame if GPU initialization or surface configuration fails

In practice, the GPU path is best when the platform can provide a stable native surface or platform texture.

## 4. Runtime Session Layer

Primary file:

- `runtime/src/lib.rs`

The runtime is the bridge between platform hosts and the engine.

It exposes two important streaming interfaces:

- `RenderSession(stream RenderInput) returns (stream RenderOutput)`
- `EventStream(EventStreamRequest) returns (stream GridEvent)`

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
- `EditorSessionStarted`
- `EditorSessionUpdated`
- `EditorSessionEnded`
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

Cancelable events use `EventDecision` on the render session rather than embedding a cancel field directly in the event payload. By default, the engine waits until the host sends that decision. Hosts should only enable this path for events they intend to handle; if a decision channel is already enabled and an unhandled cancelable event arrives, send `cancel=false` so the action proceeds. Finite `decision_timeout_ms` values are watchdogs: on timeout the engine emits `ErrorEvent` and auto-allows.

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

The Swing panel is a CPU shared-buffer and native-surface GPU host. It owns:

- panel lifecycle
- buffer allocation
- repaint scheduling
- input forwarding
- event-stream consumption
- Java2D text fallback for lite builds

It is a good reference for a desktop host with native widget integration.

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

The web host wraps the WASM build and renders into an HTML canvas. It is useful as a reference for a browser shell that still uses the same grid engine ideas, even though the integration mechanics differ from native hosts.

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
6. Runtime renders into that buffer.
7. Runtime returns `FrameDone` with dirty rect and optional metrics.
8. Host blits or presents the resulting pixels.

Flow:

```text
host buffer
    -> BufferReady(handle, stride, width, height)
    -> runtime render_session
    -> engine Renderer / Canvas
    -> RGBA pixels written in place
    -> FrameDone(dirty rect, metrics)
```

### GPU render lifecycle

The usual GPU path looks like this:

1. Host selects a GPU renderer mode.
2. Host creates or exposes a native surface handle.
3. Host sends `GpuSurfaceReady`.
4. Runtime lazily creates `GpuRenderer` if needed.
5. Runtime configures or reconfigures the `wgpu` surface.
6. Engine renders directly to the surface.
7. Runtime returns `GpuFrameDone`.

Flow:

```text
native surface handle
    -> GpuSurfaceReady(handle, width, height)
    -> runtime render_session
    -> GpuRenderer + wgpu surface
    -> present to native surface
    -> GpuFrameDone
```

If surface setup fails, the runtime returns an unrendered `GpuFrameDone`; the host must keep a valid native surface or switch to CPU mode explicitly.

## Input Lifecycle

Hosts forward user input as render-session messages:

- `PointerEvent`
- `KeyEvent`
- `ScrollEvent`
- `ZoomEvent`

The runtime translates those into shared engine input handlers. That keeps interaction behavior aligned across hosts.

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

- `EditorSessionStarted`
- `EditorSessionUpdated`
- `EditorSessionEnded`
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
- `BeforeNodeToggle`
- `BeforeScroll`
- `BeforeUserResize`
- `BeforeMoveColumn`
- `BeforeMoveRow`
- `BeforeMouseDown`

`cancel=true` means veto. `cancel=false` means allow, and is the correct default for an unhandled cancelable event when a decision channel is active.

## Editor Session Lifecycle

GUI editing is expressed as an editor session. The canonical wire shape is in `proto/volvoxgrid.proto`, but GUI hosts should follow the lifecycle below rather than treating each message independently.

### Starting

An edit can start from engine input handling or from the host calling `EditCommand.start`.

`EditCommand.start` names the cell and the reason:

- `EDIT_START_F2`, `EDIT_START_DOUBLE_CLICK`, and `EDIT_START_CLICK_CARET` create edit-mode sessions with a caret.
- `EDIT_START_ENTER_KEY`, `EDIT_START_PRINTABLE_KEY`, `EDIT_START_IME_COMPOSITION`, and `EDIT_START_PROGRAMMATIC` create enter-mode sessions unless the engine has a more specific rule.
- `seed_value` carries the printable key or IME text that opened the session.
- `caret_position` is meaningful for click-caret starts.

The render session then emits `EditorSessionStarted` with a full `EditorSession` snapshot. Hosts should cache this snapshot by `session_id`.

### Edit UI Modes

`EditorSession.ui_mode` is the authoritative mode for keyboard and overlay behavior.

`EDIT_UI_MODE_ENTER` is spreadsheet-style entry:

- the current cell text is selected when the session starts
- the first printable key replaces the selected text
- Enter commits without moving the grid cursor
- Up/Down and similar navigation keys commit and move the grid cursor
- Escape cancels and restores the original value

`EDIT_UI_MODE_EDIT` is text-editor-style entry:

- the caret is placed in the text, usually at the end or at `caret_position`
- printable keys insert at the caret instead of replacing the whole cell
- arrow keys move the caret or selection inside the editor
- Enter commits unless the editor is multiline or the host/editor handles it specially
- Escape cancels and restores the original value

Hosts should use `ui_mode` from the session rather than re-deriving it from the key or pointer event. The engine derives it from `EditStartReason`; for example, F2, double-click, and click-caret starts normally produce edit mode, while Enter, printable-key, IME, and programmatic starts normally produce enter mode.

### Presentation

`EditorSession.editor.presentation` decides whether the host shows a native widget:

- `EDITOR_CANVAS`: the engine draws the editor on the canvas. The host must not mount an overlay, but must still track the session for focus, clipboard, keyboard, and command routing.
- `EDITOR_INLINE`, `EDITOR_POPUP_OVER`, `EDITOR_POPUP_UNDER`, `EDITOR_MODAL`: the host mounts a native editor surface using the session's geometry and editor spec.

The engine default is `EDITOR_CANVAS`. Host wrappers that want native overlays must set a non-canvas presentation explicitly in their `EditorSpec`.

`EditorSession.editor.owner` decides who owns the editor implementation:

- `EDITOR_OWNER_ENGINE`: engine semantics and value model.
- `EDITOR_OWNER_HOST_NATIVE`: host-provided native editor for a built-in editor kind.
- `EDITOR_OWNER_CUSTOM`: application/custom editor identified by `custom_editor_id`.

Presentation and owner are related but not interchangeable. A host should key overlay creation from `presentation`, then use `owner` and `kind` to choose the widget implementation.

### List Editors

List editor semantics come from `EditorSpec.kind` and `ListEditorParams.allow_custom_value`; presentation only decides who draws the editor surface.

- `EDITOR_SELECT` with `allow_custom_value=false` is a read-only select/list editor. It may have list navigation and type-ahead search, but it must not expose caret movement, text selection, or mutating paste/cut behavior. Committed values must match a list item.
- `EDITOR_COMBO` with `allow_custom_value=true` is an editable dropdown/combobox. It accepts custom typed text in addition to choosing a list item.

Host wrappers that use native text editors for normal cell editing should still keep select/dropdown lists engine-owned and canvas-presented unless they implement the same select-only restrictions.

### Updating

For an existing session, the engine emits `EditorSessionUpdated`. This is a sparse delta against the cached `EditorSessionStarted.session`.

Host rules:

- Ignore updates whose `session_id` does not match the active session.
- Use `state_version` to reject stale value/selection/preedit work.
- Apply only fields that are present.
- Treat `value` and `selection` as authoritative when present.
- Treat `viewport_rect` as a geometry move for overlay presentations.
- Treat `visible=false` as hide without ending the session; keep the cached session and restore on `visible=true`.
- Treat `validation_errors` as the current validation state when sent.
- Honor `force_refocus=true` on the next host UI tick.

Same-session value, selection, validation, geometry, and visibility changes must be handled as `EditorSessionUpdated`. A host should not require another `EditorSessionStarted` unless the `session_id` changes.

### Sending Commands

Hosts send editor mutations through `EditCommand.session`, which carries `EditorSessionCommand`.

Every command should include the latest cached:

- `session_id`
- `state_version`

The engine uses those fields for optimistic concurrency. Stale commands are ignored and the returned `EditState` is the authoritative current snapshot.

Common commands:

- `value_changed`: host overlay text/value changed.
- `selection_changed`: host overlay caret/selection changed.
- `preedit_changed`: IME composition changed or committed.
- `commit`: accept the current or supplied value.
- `cancel`: close the session without committing.
- `custom_action`: custom editor button/action callback.

### Ending

The engine emits `EditorSessionEnded` when the session closes. The host should unmount any overlay, clear its cached session, and release session-specific focus/proxy state.

`committed_value` is present for committed sessions. For canceled, reverted, focus-lost, removed-cell, or destroyed-grid sessions, use `reason` to decide host cleanup and application callbacks.

### Synchronous State

`EditCommand.get_state` returns `EditState`.

- `active=false`: no session is open; ignore `session`.
- `active=true`: `session` is a full current `EditorSession` snapshot.

This is useful for wrappers, diagnostics, and reconnect paths. Render-session hosts should still use `EditorSessionStarted/Updated/Ended` as the primary live lifecycle.

## Text Rendering Strategy

Text is part of the GUI engine contract, but it has extension points.

The full cross-platform design is documented in [TEXT_RENDERING.md](TEXT_RENDERING.md).

### Default path

The engine normally uses `TextEngine` for measurement, shaping, caching, and rendering.

### Full replacement: `TextRenderer`

A platform can replace the whole text pipeline with a custom renderer. This is used by lite builds, where the host provides OS/browser font fallback and the engine still owns cache policy.

Examples in the repo:

- Web Canvas2D text renderer
- Android Canvas text renderer for lite builds
- CoreText/CoreGraphics renderer for macOS and iOS lite native runtimes
- Java2D text renderer for Java desktop lite builds
- GDI-based bridge on `.NET` lite builds and optional Wine experiments

Use this when the host should handle both:

- text measurement
- glyph rasterization or text drawing

The debug overlay shows the active text backend as `Text:Engine`, `Text:Android`, `Text:Browser`, `Text:CoreText`, `Text:Java2D`, or `Text:GDI`. The `C:<used>/<cap>` value reports the engine-owned text cache.

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
- lite text fallback uses the host font stack, so exact glyph selection can vary by OS
- edit/dropdown overlays are host-driven, so exact UX can vary by platform
- some hosts may redraw full surfaces even when the runtime reports only a dirty rect

## Recommended Reading Order

If you are modifying the GUI stack, read in this order:

1. `engine/src/grid.rs`
2. `engine/src/canvas.rs`
3. `engine/src/render.rs`
4. `engine/src/gpu_render.rs`
5. `runtime/src/lib.rs`
6. the host for your platform:
   - Android: `android/volvoxgrid-android/src/main/java/io/github/ivere27/volvoxgrid/VolvoxGridView.kt`
   - Java desktop: `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopPanel.java`
   - Flutter: `flutter/lib/volvoxgrid_controller.dart`
   - Web: `web/js/src/volvoxgrid.ts`
   - `.NET`: `dotnet/src/common`

That order matches the real layering: retained state first, render pipeline second, runtime bridge third, host shell last.
