# GUI

## Who this is for

You're an engineer building or modifying a pixel-rendered host for VolvoxGrid, on Android, Java desktop, Flutter, Web, .NET, or somewhere new. This doc walks through how the GUI stack actually works.

After reading, you'll be able to:

- pick the right rendering backend (CPU or GPU) for your platform
- wire the render session and event stream to a new host
- handle editor sessions and immediate UI requests correctly
- swap in a custom text renderer for a lite build

Next: the mental model below sets the scene.

## The mental model

There's one retained `VolvoxGrid` state object per grid. It owns everything that defines the grid: rows, columns, cells, layout, styling, selection, scrolling, editing, sorting, spans, outline data, animations, pending events.

The engine paints that state into either a CPU RGBA buffer or a GPU surface. Hosts stay thin: they handle windows, input plumbing, and any native overlays. They don't reimplement grid logic.

That separation is the entire design. The engine is host-neutral. The hosts are pixel-pipe shells.

Next: how those layers stack up.

## Architecture layers

Here's how the GUI stack is layered:

1. Retained grid state (`engine/src/grid.rs`)
2. Backend-agnostic canvas pipeline (`engine/src/canvas.rs`)
3. CPU and GPU renderers (`engine/src/render.rs`, `engine/src/gpu_render.rs`)
4. Runtime render and event streams (`runtime/src/lib.rs`)
5. Platform hosts (Android, Java, Flutter, Web, .NET)

### Retained grid state

`VolvoxGrid` is the central state container. It owns sparse cell storage, column/row properties, grid-wide and per-cell style, selection, scroll, edit state, span/merge state, outline state, sort state, drag state, animation state, the layout cache, and the event queue.

This is a retained-mode engine. You mutate grid state through API calls and input events, then ask for frames when something is dirty.

A few retained-mode rules worth knowing:

- `mark_dirty()` invalidates render-visible state and text-derived caches.
- `mark_dirty_visual()` keeps caches but schedules another frame.
- `ensure_layout()` rebuilds layout lazily and updates scroll bounds.
- `clear_dirty()` keeps the grid dirty while animations, scrollbar fade, background work, or pull-to-refresh still need frames.

You don't recompute layout or paint logic in the host. You just keep rendering while the engine says more frames are needed.

### Canvas pipeline

The engine renders through a backend-agnostic `Canvas` trait in `engine/src/canvas.rs`. It exposes the drawing primitives: fill and blend rects, lines, pixels, text measurement and drawing, image blits, checker fills.

All grid painting composes on that shared interface, and the same orchestration is reused by both CPU and GPU paths. `canvas.rs` defines what gets painted; backend implementations define how pixels or instances are emitted.

### CPU renderer

Files: `engine/src/render.rs`, `engine/src/canvas_cpu.rs`.

The CPU path renders into a host-owned RGBA buffer. The host sends `BufferReady` with a native buffer handle, stride, width, and height. The runtime maps the buffer and calls the CPU renderer, which paints the grid into that shared memory.

Behaviors to know: the shared `canvas.rs` pipeline, optional scroll-blit reuse via `ScrollCache`, the shared text pipeline, and dirty-rect reporting through `FrameDone`. This is the most portable path and the easiest one for a new host.

### GPU renderer

Files: `engine/src/gpu_render.rs`, `engine/src/canvas_gpu.rs`.

The GPU path uses `wgpu` and renders directly to a host-provided native surface. The host sends `GpuSurfaceReady` with a native surface handle, width, and height. The GPU renderer configures or reconfigures a `wgpu::Surface` and renders into it.

The GPU path shares all the grid and layout logic, emits GPU-backed rectangles and textured quads, uses `GlyphAtlas` for text and image texture data, supports surface recreation on resize or loss, and reports an unrendered GPU frame if surface configuration fails.

Next: when do you actually want GPU?

## CPU vs GPU: when do you need each?

Both backends drive through the same render session and the same grid state. The choice is mostly about what your platform can give the engine.

Pick CPU when:

- you want the simplest possible integration
- portability matters more than peak rendering throughput
- your platform doesn't expose a clean native surface handle (most widget toolkits)
- you're embedding inside a traditional widget tree

Pick GPU when:

- you can hand the engine a stable native surface or platform texture
- pixel-copy overhead from the CPU buffer to the screen is measurable
- you've already got a compatible surface story (Android `SurfaceView`, a platform texture, a windowed native surface)

A reasonable rollout is to start on CPU, get correctness right, then add GPU as an optional host optimization. The Android host is a good reference for a host that supports both modes over the same contract.

Next: how a frame actually moves through the system.

## The render lifecycle

### CPU flow

Here's the flow from start to finish:

```text
host buffer
    -> BufferReady(handle, stride, width, height)
    -> runtime render_session
    -> engine Renderer / Canvas
    -> RGBA pixels written in place
    -> FrameDone(dirty rect, metrics)
```

Step by step:

1. Host creates a grid with an initial viewport and scale.
2. Host configures layout, indicators, editing, selection, rendering, and data.
3. Host opens a render session.
4. Host sends `ViewportState` whenever the size changes.
5. Host allocates a direct RGBA buffer and sends `BufferReady`.
6. The runtime renders into that buffer.
7. The runtime returns `FrameDone` with the dirty rect and optional metrics.
8. Host blits or presents the resulting pixels.

### GPU flow

Here's the flow from start to finish:

```text
native surface handle
    -> GpuSurfaceReady(handle, width, height)
    -> runtime render_session
    -> GpuRenderer + wgpu surface
    -> present to native surface
    -> GpuFrameDone
```

Step by step:

1. Host selects a GPU renderer mode.
2. Host creates or exposes a native surface handle.
3. Host sends `GpuSurfaceReady`.
4. The runtime lazily creates `GpuRenderer` if needed.
5. The runtime configures or reconfigures the `wgpu` surface.
6. The engine renders directly to the surface.
7. The runtime returns `GpuFrameDone`.

If surface setup fails, the runtime returns an unrendered `GpuFrameDone`. Your host must keep a valid native surface or fall back to CPU explicitly.

Next: how user input gets in.

## The input lifecycle

You forward user input as render-session messages:

- `PointerEvent`
- `KeyEvent`
- `ScrollEvent`
- `ZoomEvent`

The runtime turns these into shared engine input handlers, so interaction behavior stays aligned across hosts. Touch and mouse presses become pointer down/up/move. Wheel and gesture deltas become scroll events. Keyboard navigation and editing become key down/press/up. Pinch gestures become zoom begin/update/end.

Translate platform coordinates into viewport-local grid coordinates before sending them.

Next: there are two kinds of things coming back out, and you need to handle each differently.

## Immediate UI vs semantic events

GUI hosts need both render-coupled UI outputs and application-level events. The runtime exposes them on two separate streams:

- `RenderSession(stream RenderInput) returns (stream RenderOutput)`
- `EventStream(EventStreamRequest) returns (stream GridEvent)`

### Immediate UI requests on `RenderOutput`

These arrive on the render session because they're render-coupled:

- `EditorSessionStarted`
- `EditorSessionUpdated`
- `EditorSessionEnded`
- `TooltipRequest`
- `CursorChange`
- `SelectionUpdate`

You react immediately: show an edit overlay at the requested pixel rect, open a dropdown popup, show or hide a tooltip, update the cursor, sync mirrored selection state.

### Semantic events on `GridEvent`

These arrive on `EventStream` and feed application logic: focus changes, selection changes, before/after edit, validation, before/after sort, scroll, mouse and keyboard, refresh, errors.

Cancelable events use `EventDecision` on the render session instead of embedding a cancel field directly. By default the engine waits for that decision. Only enable the decision path for events you intend to handle. If the channel is enabled and an unhandled cancelable event arrives, send `cancel=false` so the action proceeds. Finite `decision_timeout_ms` is a watchdog: on timeout the engine emits `ErrorEvent` and auto-allows.

Cancelable events include:

- `BeforeEdit`
- `CellEditValidate`
- `BeforeSort`
- `BeforeNodeToggle`
- `BeforeScroll`
- `BeforeUserResize`
- `BeforeMoveColumn`
- `BeforeMoveRow`
- `BeforeMouseDown`

`cancel=true` vetoes. `cancel=false` allows, and it's the right default for an unhandled cancelable event when the channel is active.

Rule of thumb: use `RenderOutput` for render-coupled UI behavior, use `GridEvent` for semantic host callbacks.

Next: the biggest lifecycle in the system.

## Editor session lifecycle

GUI editing is expressed as an editor session. The canonical wire shape lives in `proto/volvoxgrid.proto`, but you should follow the lifecycle as a whole, not message-by-message.

### Starting

An edit can start from engine input handling or from the host calling `EditCommand.start`. `EditCommand.start` names the cell and the reason:

- `EDIT_START_F2`, `EDIT_START_DOUBLE_CLICK`, and `EDIT_START_CLICK_CARET` create edit-mode sessions with a caret.
- `EDIT_START_ENTER_KEY`, `EDIT_START_PRINTABLE_KEY`, `EDIT_START_IME_COMPOSITION`, and `EDIT_START_PROGRAMMATIC` create enter-mode sessions unless the engine has a more specific rule.
- `seed_value` carries the printable key or IME text that opened the session.
- `caret_position` is meaningful for click-caret starts.

The render session emits `EditorSessionStarted` with a full `EditorSession` snapshot. Cache it by `session_id`.

### Edit UI modes

`EditorSession.ui_mode` is the authoritative mode for keyboard and overlay behavior. Use it directly. Don't re-derive it from the key or pointer event.

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
- Enter commits unless the editor is multiline or handled specially
- Escape cancels and restores the original value

The engine derives `ui_mode` from `EditStartReason`. F2, double-click, and click-caret starts normally produce edit mode. Enter, printable-key, IME, and programmatic starts normally produce enter mode.

### Presentation

`EditorSession.editor.presentation` decides whether the host shows a native widget:

- `EDITOR_CANVAS`: the engine draws the editor on the canvas. Don't mount an overlay, but do still track the session for focus, clipboard, keyboard, and command routing.
- `EDITOR_INLINE`, `EDITOR_POPUP_OVER`, `EDITOR_POPUP_UNDER`, `EDITOR_MODAL`: mount a native editor surface using the session's geometry and editor spec.

The engine default is `EDITOR_CANVAS`. If your host wants native overlays, set a non-canvas presentation explicitly in `EditorSpec`.

`EditorSession.editor.owner` decides who owns the editor implementation:

- `EDITOR_OWNER_ENGINE`: engine semantics and value model.
- `EDITOR_OWNER_HOST_NATIVE`: host-provided native editor for a built-in editor kind.
- `EDITOR_OWNER_CUSTOM`: application/custom editor identified by `custom_editor_id`.

Presentation and owner are related but not interchangeable. Key overlay creation from `presentation`, then use `owner` and `kind` to choose the widget implementation.

### List editors

List editor semantics come from `EditorSpec.kind` and `ListEditorParams.allow_custom_value`. Presentation only decides who draws the surface.

- `EDITOR_SELECT` with `allow_custom_value=false` is a read-only select/list editor. It may have list navigation and type-ahead search, but it must not expose caret movement, text selection, or mutating paste/cut. Committed values must match a list item.
- `EDITOR_COMBO` with `allow_custom_value=true` is an editable dropdown/combobox. It accepts custom typed text in addition to choosing a list item.

If your host uses native text editors for normal cell editing, keep select/dropdown lists engine-owned and canvas-presented unless you're going to implement the same select-only restrictions yourself.

### Commit validation

Commit-time validation is layered:

- `ColumnDef.data_type` controls display, sort, formatting, and aggregation. It does not by itself make editing numeric, date-only, or list-only.
- `EditorSpec.kind` plus editor params controls built-in edit validation.
- `CellEditValidate` is for application rules that the editor params can't express.

Built-in validation runs before `CellEditValidate`. If it fails with `VALIDATION_BLOCK`, the editor stays open and `EditorSession.validation_errors` / `EditorSessionUpdated.validation_errors` carries the error state.

Built-in commit checks:

- `EDITOR_NUMBER`: committed text must parse as a finite number; `NumberEditorParams.nullable=false` rejects empty text; `min` and `max` enforce numeric range.
- `EDITOR_DATE_TIME`: non-empty committed text must parse as a date/time; `min_timestamp` and `max_timestamp` enforce range.
- `EDITOR_SELECT`: committed text must match an enabled list item when static items are available.
- `EDITOR_COMBO`: list items may be chosen, but custom text is allowed.
- `EDITOR_TEXT` / `EDITOR_MULTILINE_TEXT`: `max_length` and `allow_newlines` are enforced at commit.

Use `CellEditValidate` for cross-cell, cross-row, server, permission, duplicate-key, formula, or other business validation. For example, a `Margin` column can use `EDITOR_NUMBER` with `min=0` and `max=100`; a rule such as `Cost <= Sales` belongs in `CellEditValidate`.

### Updating

For an existing session, the engine emits `EditorSessionUpdated`, a sparse delta against the cached `EditorSessionStarted.session`.

Host rules:

- Ignore updates whose `session_id` doesn't match the active session.
- Use `state_version` to reject stale value/selection/preedit work.
- Apply only fields that are present.
- Treat `value` and `selection` as authoritative when present.
- Treat `viewport_rect` as a geometry move for overlay presentations.
- Treat `visible=false` as hide without ending the session; keep the cached session and restore on `visible=true`.
- Treat `validation_errors` as the current validation state when sent.
- Honor `force_refocus=true` on the next host UI tick.

Same-session value, selection, validation, geometry, and visibility changes must be handled as `EditorSessionUpdated`. Don't require another `EditorSessionStarted` unless the `session_id` changes.

### Sending commands

Hosts send editor mutations through `EditCommand.session`, which carries `EditorSessionCommand`. Every command should include the latest cached `session_id` and `state_version`. The engine uses those fields for optimistic concurrency. Stale commands are ignored and the returned `EditState` is the authoritative current snapshot.

Common commands:

- `value_changed`: host overlay text/value changed.
- `selection_changed`: host overlay caret/selection changed.
- `preedit_changed`: IME composition changed or committed.
- `commit`: accept the current or supplied value.
- `cancel`: close the session without committing.
- `custom_action`: custom editor button/action callback.

### Ending

The engine emits `EditorSessionEnded` when the session closes. Unmount any overlay, clear the cached session, and release session-specific focus/proxy state.

`committed_value` is present for committed sessions. For canceled, reverted, focus-lost, removed-cell, or destroyed-grid sessions, use `reason` to decide host cleanup and application callbacks.

### Synchronous state

`EditCommand.get_state` returns `EditState`:

- `active=false`: no session is open; ignore `session`.
- `active=true`: `session` is a full current `EditorSession` snapshot.

This is useful for wrappers, diagnostics, and reconnect paths. Render-session hosts should still treat `EditorSessionStarted/Updated/Ended` as the primary live lifecycle.

Next: text is its own subsystem with its own extension points.

## Text rendering strategy

Text is part of the GUI engine contract, but it has extension points. The full cross-platform design lives in [TEXT_RENDERING.md](TEXT_RENDERING.md).

The engine normally uses `TextEngine` for measurement, shaping, caching, and rendering. That's the default.

For lite builds, a platform can replace the whole text pipeline with a custom `TextRenderer`. The host provides OS or browser font fallback and the engine still owns cache policy. Existing replacements in the repo: Web Canvas2D, Android Canvas (lite), CoreText/CoreGraphics (macOS/iOS lite), Java2D (Java desktop lite), GDI (.NET lite and optional Wine experiments).

The debug overlay shows the active text backend as `Text:Engine`, `Text:Android`, `Text:Browser`, `Text:CoreText`, `Text:Java2D`, or `Text:GDI`. The `C:<used>/<cap>` value reports the engine-owned text cache.

If you only need to fill in coverage for some glyphs while keeping engine shaping, use the `ExternalGlyphRasterizer` fallback instead of replacing the whole pipeline.

Next: a clean line on who owns what.

## What the host owns vs what the engine owns

The host owns:

- view or widget lifecycle
- viewport sizing
- direct buffer or native surface ownership
- input capture
- IME and composition
- native overlay widgets for edit and dropdown when desired
- frame scheduling

The host does not own:

- grid layout rules
- selection logic
- editing state machine
- rendering rules
- sort behavior
- scroll bounds

That logic already lives in the engine. If you find yourself reimplementing any of it in a host, that's a smell.

Next: the existing hosts you can crib from.

## Existing hosts

### Android

File: `android/volvoxgrid-android/src/main/java/io/github/ivere27/volvoxgrid/VolvoxGridView.kt`.

A `SurfaceView`-based shell that supports CPU shared-buffer rendering, GPU surface rendering, touch/wheel/key/pinch-zoom forwarding, IME integration, a native `EditText` overlay for editing, and event-stream listeners. The clearest reference for a host that supports both CPU and GPU modes over the same contract.

### Java desktop

File: `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopPanel.java`.

A Swing panel that supports CPU shared-buffer and native-surface GPU paths. Owns panel lifecycle, buffer allocation, repaint scheduling, input forwarding, event-stream consumption, and Java2D text fallback for lite builds. Good reference for desktop with native widget integration.

### Flutter

Files: `flutter/lib/volvoxgrid_controller.dart`, `flutter/README.md`.

Same native engine through FFI. CPU mode renders into a shared RGBA buffer and displays it via Flutter image plumbing. Android GPU mode renders into a Flutter platform texture. Good reference for a cross-platform host where the Dart controller is high-level but the rendering contract underneath is unchanged.

### Web

Files: `web/js/src/volvoxgrid.ts`, `web/js/src/volvoxgrid-element.ts`.

The web host wraps the WASM build and renders into an HTML canvas. Useful as a reference for a browser shell that still uses the same grid engine, even though the integration mechanics differ from native hosts.

### .NET

Files under: `dotnet/src/common`.

Exposes controller and WinForms-oriented integration over the same native engine. Includes host text-rendering integration points.

Next: a few things that are true today but might not stay that way.

## Current constraints

- Not every host exposes both CPU and GPU paths.
- Flutter desktop currently uses CPU mode.
- GPU surface handling is platform-specific even though the engine contract is shared.
- Lite text fallback uses the host font stack, so exact glyph selection can vary by OS.
- Edit and dropdown overlays are host-driven, so exact UX can vary by platform.
- Some hosts may redraw full surfaces even when the runtime reports only a dirty rect.

Next: where to start reading.

## Reading order through the code

If you're modifying the GUI stack, read in this order:

1. `engine/src/grid.rs`
2. `engine/src/canvas.rs`
3. `engine/src/render.rs`
4. `engine/src/gpu_render.rs`
5. `runtime/src/lib.rs`
6. The host for your platform:
   - Android: `android/volvoxgrid-android/src/main/java/io/github/ivere27/volvoxgrid/VolvoxGridView.kt`
   - Java desktop: `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopPanel.java`
   - Flutter: `flutter/lib/volvoxgrid_controller.dart`
   - Web: `web/js/src/volvoxgrid.ts`
   - .NET: `dotnet/src/common`

That order matches the real layering: retained state first, render pipeline second, runtime bridge third, host shell last.
