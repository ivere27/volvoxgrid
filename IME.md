# IME in VolvoxGrid

This document covers VolvoxGrid IME behavior across:

- shared Rust engine and proto contract
- language bindings and runtime hosts
- compatibility adapters
- natural-language composition coverage

## Design Summary

VolvoxGrid has two distinct input paths:

1. GUI hosts use the platform IME.
2. TUI hosts use engine-side compose.

For GUI hosts, VolvoxGrid follows the same broad model used by mature grids:

| Reference grid | Editing surface | IME owner |
|---|---|---|
| Excel | custom TSF text store | Windows IME |
| VSFlexGrid / C1FlexGrid | real `EDIT` / `TextBox` control | Windows IME |
| DevExpress XtraGrid | real WinForms in-place editor | Windows IME |
| AG Grid | DOM `<input>` / `<textarea>` | browser + OS IME |

VolvoxGrid does the same on GUI platforms: the host owns focus surfaces, composition capture, and native editor widgets; the engine owns edit state, selection state, layout, and rendering of preedit text.

TUI is the exception. A terminal has no OS IME, so the engine can optionally run a lightweight compose layer itself.

## Shared Engine Contract

The common IME contract is defined once and reused everywhere.

### Proto

`proto/volvoxgrid.proto` exposes:

- `EditCommand.set_preedit`
- `EditSetPreedit { text, cursor, commit }`
- `EditState.composing`
- `EditState.preedit_text`
- `EditConfig.engine_compose`
- `EditConfig.compose_method`

Meaning:

- `text` + `cursor` updates the current preedit string.
- `commit = true` commits the supplied text into the active editor.
- empty preedit clears composition state.
- `engine_compose` switches composition from host-driven IME to engine-driven compose logic.

### Engine

The engine-side flow lives in:

- `engine/src/edit.rs`
- `engine/src/input.rs`
- `engine/src/canvas.rs`

Core behavior:

- `set_preedit()` enters composing mode and replaces any active selection.
- `commit_preedit()` inserts committed text into `edit_text`.
- `cancel_preedit()` clears composition without changing `edit_text`.
- `flush_preedit()` finalizes pending preedit before commit/navigation keys.
- the active editor renderer draws preedit inline with underline and caret.
- host-driven IME composition suppresses normal grid key handling until composition ends.

## Runtime Matrix

| Runtime | Language | IME owner | Strategy |
|---|---|---|---|
| Android | Kotlin | Android IME | hidden `EditText` proxy when idle, real `EditText` overlay when editing |
| Flutter GUI | Dart | Flutter/platform text input | overlay `TextField`; desktop-only hidden proxy for idle IME capture |
| Java Desktop | Java/Swing | AWT/Swing input method | transparent `JTextField` proxy plus overlay editor |
| .NET WinForms | C# | Win32 IMM32 | host `Control` handles `WM_IME_*`, overlay `TextBox` handles visible editing |
| Web/WASM | TypeScript | browser + OS IME | hidden `<textarea>` proxy plus visible host editor |
| Go / .NET / Java TUI | Go / C# / Java + Rust engine | engine compose | no host IME; compose handled in the shared engine |

## GUI Hosts

### Android

Primary file:

- `android/volvoxgrid-android/src/main/java/io/github/ivere27/volvoxgrid/VolvoxGridView.kt`

Current behavior:

- uses a hidden 1x1 `EditText` as `imeProxy` when the grid is focused but not actively editing
- keeps `showSoftInputOnFocus = false` on the idle proxy so it does not pop the keyboard on every tap
- starts engine edit when composition begins on the idle proxy
- defers showing the visible editor until composition settles
- swaps to a real overlay `EditText` during active edit
- reads composing spans from `BaseInputConnection` and forwards them through `EditSetPreedit`
- commits plain text through `EditSetText` when no composition is active

Practical result:

- touch devices get the native Android keyboard and IME
- hardware-keyboard composition can begin before the overlay is visible
- the engine still renders the preedit state

### Flutter

Primary files:

- `flutter/lib/volvoxgrid.dart`
- `flutter/lib/volvoxgrid_controller.dart`

Current behavior:

- active editing uses a host `TextField`
- desktop uses a hidden `imeProxy` `TextField` so hardware-keyboard IME can start while the grid is idle
- mobile intentionally skips idle proxy focus to avoid opening the soft keyboard on every tap
- composition updates are forwarded with `VolvoxGridController.setEditPreedit(...)`
- plain edits still use normal edit RPCs such as `beginEdit`, `commitEdit`, and `cancelEdit`
- overlay key handling ignores commit/cancel shortcuts while Flutter reports an active composing range

Practical result:

- Android/iOS Flutter builds rely on the normal platform text system
- desktop Flutter builds can start IME composition before the visible edit box exists

### Java Desktop

Primary file:

- `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopPanel.java`

Current behavior:

- the panel itself disables input methods
- a transparent `JTextField` proxy is always present and input-method enabled
- the proxy captures `InputMethodEvent` traffic even when the visible edit overlay is not yet shown
- IME input can trigger `beginHostEditOverlay()` before cell geometry is ready
- committed and composed text are separated from the `InputMethodEvent`
- `InputContext.endComposition()` is called before commit/cancel to flush pending composition
- a `DocumentFilter` guards against stale post-cancel mutations from the proxy text field

Why this shape exists:

- on Swing/X11, `InputMethodEvent` is delivered to `JTextComponent`, not to a plain painted panel
- the transparent proxy gives the pixel-rendered grid a real IME-capable text target

### .NET WinForms

Primary file:

- `dotnet/src/common/Volvox/RenderHostCpu.cs`

Current behavior:

- visible editing uses a borderless WinForms `TextBox` with `ImeMode.On`
- when the overlay is hidden, the host `Control` itself intercepts:
  - `WM_IME_STARTCOMPOSITION`
  - `WM_IME_COMPOSITION`
  - `WM_IME_ENDCOMPOSITION`
  - `WM_IME_CHAR`
- `WM_IME_STARTCOMPOSITION` starts a clean engine edit session for the active cell
- `WM_IME_COMPOSITION` reads:
  - `GCS_RESULTSTR` for committed text
  - `GCS_COMPSTR` for preedit text
- `WM_IME_ENDCOMPOSITION` clears preedit state
- `WM_IME_CHAR` is suppressed to avoid duplicate insertion after `GCS_RESULTSTR`

Practical result:

- WinForms does not need a second hidden proxy HWND
- IMM32 can drive composition directly through the focused control
- the overlay `TextBox` still takes over when visible editing is active

### Web/WASM

Primary files:

- `web/js/src/volvoxgrid.ts`
- `web/crate/src/lib.rs`

Current behavior:

- the visible editor is a real DOM `input` or `select`
- a hidden `textarea` `imeProxy` stays focused instead of the canvas while idle
- `compositionstart` on the proxy begins engine editing at the current selection
- `compositionupdate` forwards preedit through `set_edit_preedit`
- `compositionend` commits through `commit_edit_preedit`
- transition from proxy to visible editor is delayed so Korean-style immediate follow-up composition does not lose focus
- the visible editor also handles `compositionstart/update/end`
- non-IME key redispatch uses `event.isComposing` and `keyCode === 229` guards

Practical result:

- browser IME toggle keys and CJK composition work even though the grid is canvas-rendered
- the engine remains the source of truth for edit state

## TUI Hosts

Relevant files:

- `TUI.md`
- `go/README.md`
- `engine/src/compose.rs`
- `engine/src/input.rs`
- `engine/src/grid.rs`

TUI behavior is different:

- terminal hosts only forward raw bytes and viewport/capability information
- there is no host IME surface
- the engine can enable compose internally

Default behavior:

- TUI mode defaults `engine_compose = true`
- TUI mode defaults `compose_method = DeadKey`

Shipped engine compose methods:

- `DeadKey`
- `Hangul`
- `Telex`

This means:

- Latin dead-key accents can work in TUI without a host IME
- Korean Hangul can use the engine algorithm
- Vietnamese Telex can use the engine algorithm
- TUI still cannot replace dictionary-based IMEs such as Chinese Pinyin or Japanese Kana/Kanji conversion

## Compatibility Adapter Matrix

These adapters do not all own IME themselves. Most inherit behavior from their host runtime.

| Adapter | Runtime | IME behavior | Status |
|---|---|---|---|
| `adapters/aggrid` | Web / TypeScript | inherits VolvoxGrid web host IME behavior | no adapter-specific IME layer |
| `adapters/sheet` | Web / TypeScript | inherits VolvoxGrid web host IME behavior | adds sheet-state synchronization on composition start |
| `adapters/sfdatagrid` | Flutter / Dart | inherits `VolvoxGridWidget` IME behavior | no separate adapter IME layer |
| `adapters/report` | Web / React | not an edit-centric adapter | no adapter-specific IME handling |
| `adapters/vsflexgrid` | Windows ActiveX / C/C++/Rust | engine-side preedit plumbing exists in Rust | host wrapper IME wiring is incomplete today |
| `adapters/xtragrid` | WinForms compare harness | Volvox side inherits WinForms host IME; reference side uses DevExpress native editors | not a standalone IME implementation |

### Sheet Adapter

Primary file:

- `adapters/sheet/src/volvox-sheet.ts`

Extra behavior:

- hooks into VolvoxGrid's `onCompositionEditStart`
- synchronizes the sheet edit state machine before focus moves to the visible grid editor
- keeps formula-bar state and sheet edit state aligned during IME-driven entry

### SfDataGrid Adapter

Primary file:

- `adapters/sfdatagrid/lib/src/sf_data_grid_volvox.dart`

Behavior:

- wraps `VolvoxGridWidget`
- inherits Flutter's IME path directly
- does not implement a separate composition bridge

### AG Grid Adapter

Primary file:

- `adapters/aggrid/src/ag-grid-volvox.ts`

Behavior:

- instantiates the normal web `VolvoxGrid`
- relies on the browser + VolvoxGrid web host IME path
- does not add separate composition logic

### VSFlexGrid ActiveX Adapter

Relevant files:

- `adapters/vsflexgrid/crate/src/lib.rs`
- `adapters/vsflexgrid/src/VolvoxGridCtrl.cpp`
- `adapters/vsflexgrid/mingw/volvoxgrid_ocx.c`

Current status:

- the Rust adapter core understands `EditSetPreedit` and `preedit_text`
- the public ATL and raw OCX wrappers currently expose keyboard forwarding through `WM_KEYDOWN` and `WM_CHAR`
- there is no explicit `WM_IME_*` handling in the current wrapper layers

Interpretation:

- engine-side preedit support exists below the wrapper
- host-side IME capture is not wired to the same level as WinForms, Swing, Android, or web
- treat IME support in this adapter as incomplete until the wrapper adds real IME message handling or a native editor control

### XtraGrid Adapter

Relevant files:

- `adapters/xtragrid/README.md`
- `adapters/xtragrid/test/runner/ScriptCompat.cs`

Current status:

- this is a comparison harness, not a production host layer
- the DevExpress reference side uses DevExpress editors
- the Volvox side uses the normal `.NET` host path
- no additional IME implementation lives in the harness

## Natural-Language Coverage

IME requirements differ by human language. VolvoxGrid's runtime split maps cleanly onto those categories.

| Input class | Examples | Host IME path | Engine compose path |
|---|---|---|---|
| direct keyboard | English, Russian, Arabic, Thai, Indonesian | works | works |
| dead-key accents | Spanish, French, Portuguese, German, Italian, Turkish, Polish | host handles natively | `DeadKey` |
| algorithmic composition shipped | Korean, Vietnamese | host handles natively | `Hangul`, `Telex` |
| algorithmic composition not shipped | Hindi, Bengali, Tamil | host handles natively | not currently implemented |
| dictionary-based IME | Chinese, Japanese | required | out of scope |

Important consequence:

- GUI hosts should continue to prefer the platform IME for full language coverage.
- TUI can cover a useful subset, but not full CJK dictionary input.

## Current Repo Position

Today, the repo is strongest on IME in these public hosts:

- Android
- Flutter GUI
- Java Desktop
- .NET WinForms
- Web/WASM
- TUI engine compose

The main gap is the Windows ActiveX compatibility adapter, where the lower engine can represent preedit state but the current OCX wrapper does not yet expose a complete host IME bridge.
