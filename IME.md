# IME in VolvoxGrid

You're trying to get input method composition working in a VolvoxGrid host. Here's how VolvoxGrid handles it on your platform.

## Who this is for

You're either wiring IME into a new host adapter, or you're debugging why composition (Korean Hangul, Japanese Kana, Chinese Pinyin, French accents) misbehaves on an existing one. Either way, you need to know which side owns what.

This doc covers the shared engine and proto contract, the language bindings and native hosts, the compatibility adapters, and how far the engine's own compose layer reaches across natural languages.

Next: skim the mental model below before you go hunting in `engine/src/`.

## The mental model

VolvoxGrid splits IME into two distinct input paths:

1. GUI hosts use the platform IME.
2. TUI hosts use engine-side compose.

That's it. The rest of this document is just the consequences of that one rule.

For GUI hosts, VolvoxGrid follows the same broad model used by mature grids:

| Reference grid | Editing surface | IME owner |
|---|---|---|
| Excel | custom TSF text store | Windows IME |
| VSFlexGrid / C1FlexGrid | real `EDIT` / `TextBox` control | Windows IME |
| DevExpress XtraGrid | real WinForms in-place editor | Windows IME |
| AG Grid | DOM `<input>` / `<textarea>` | browser + OS IME |

VolvoxGrid does the same on GUI platforms: the host owns focus surfaces, composition capture, and native editor widgets; the engine owns edit state, selection state, layout, and rendering of preedit text.

TUI is the exception. A terminal has no OS IME, so the engine can optionally run a lightweight compose layer itself.

Next: the shared contract is what every host has to satisfy.

## The shared engine contract

The common IME contract is defined once and reused everywhere. IME is layered on top of the editor-session lifecycle described in [GUI.md](GUI.md#editor-session-lifecycle).

### Proto

`proto/volvoxgrid.proto` exposes:

- `EditCommand.session` → `EditorSessionCommand.preedit_changed`
- `EditorPreeditChanged { text, cursor, commit }`
- `EditState.session.composing`
- `EditState.session.preedit_text`
- `EditConfig.compose_method`

What each field means:

- `text` + `cursor` update the current preedit string.
- `commit = true` commits the supplied text into the active editor.
- An empty preedit clears composition state.
- Preedit commands must carry the active editor session's latest `session_id` and `state_version`.
- `compose_method` selects the engine-side compose algorithm when engine compose is active.
- GUI hosts normally use host-driven IME through native editor surfaces.
- TUI mode enables engine compose by default, because terminals don't provide an OS IME surface.

### How the editor session connects

You should treat composition as active editor-session state, not as a side channel:

- If composition starts while no editor is active, start an edit session for the current cell with `EDIT_START_IME_COMPOSITION`.
- When the engine emits `EditorSessionStarted`, cache `session_id`, `state_version`, `value`, `selection`, `composing`, and `preedit_text`.
- Send composition updates as `EditCommand.session.preedit_changed` using the latest cached `session_id` and `state_version`.
- Apply `EditorSessionUpdated` deltas back to the host editor or proxy before sending the next command.
- Ignore stale composition callbacks after `EditorSessionEnded`.

For visible host-native editors, the host widget owns platform composition events and forwards only the normalized edit state to the engine. For `EDITOR_CANVAS` sessions, the engine renders the preedit underline and caret itself, but the host still owns the platform IME focus surface or idle proxy on GUI platforms.

Next: the engine side of that contract.

### Engine flow

The engine-side flow lives in:

- `engine/src/edit.rs`
- `engine/src/input.rs`
- `engine/src/canvas.rs`

Core behavior:

- `set_preedit()` enters composing mode and replaces any active selection.
- `commit_preedit()` inserts committed text into `edit_text`.
- `cancel_preedit()` clears composition without changing `edit_text`.
- `flush_preedit()` finalizes pending preedit before commit/navigation keys.
- The active editor renderer draws preedit inline with underline and caret.
- Host-driven IME composition suppresses normal grid key handling until composition ends.

Next: which host owns the IME on your runtime.

## Runtime matrix

| Runtime | Language | IME owner | Strategy |
|---|---|---|---|
| Android | Kotlin | Android IME | hidden `EditText` proxy when idle, real `EditText` overlay when editing |
| Flutter GUI | Dart | Flutter/platform text input | overlay `TextField`; desktop-only hidden proxy for idle IME capture |
| Java Desktop | Java/Swing | AWT/Swing input method | transparent `JTextField` proxy plus overlay editor |
| .NET WinForms | C# | Win32 IMM32 | host `Control` handles `WM_IME_*`, overlay `TextBox` handles visible editing |
| Web/WASM | TypeScript | browser + OS IME | hidden `<textarea>` proxy plus visible host editor |
| Go / .NET / Java TUI | Go / C# / Java + Rust engine | engine compose | no host IME; compose handled in the shared engine |

Next: per-platform specifics.

## GUI hosts

### Android

Primary file:

- `android/volvoxgrid-android/src/main/java/io/github/ivere27/volvoxgrid/VolvoxGridView.kt`

What the host does:

- Uses a hidden 1x1 `EditText` as `imeProxy` when the grid is focused but not actively editing.
- Keeps `showSoftInputOnFocus = false` on the idle proxy so it doesn't pop the keyboard on every tap.
- Starts engine edit when composition begins on the idle proxy.
- Defers showing the visible editor until composition settles.
- Swaps to a real overlay `EditText` during active edit.
- Reads composing spans from `BaseInputConnection` and forwards them through `EditorSessionCommand.preedit_changed`.
- Commits plain text through `EditorSessionCommand.value_changed` when no composition is active.
- Ignores stale composition callbacks after the active `session_id` changes.

Practical result:

- Touch devices get the native Android keyboard and IME.
- Hardware-keyboard composition can begin before the overlay is visible.
- The engine still renders the preedit state.

### Flutter

Primary files:

- `flutter/lib/volvoxgrid.dart`
- `flutter/lib/volvoxgrid_controller.dart`

What the host does:

- Active editing uses a host `TextField`.
- Desktop uses a hidden `imeProxy` `TextField` so hardware-keyboard IME can start while the grid is idle.
- Mobile intentionally skips idle proxy focus to avoid opening the soft keyboard on every tap.
- Composition updates are forwarded with `VolvoxGridController.setEditPreedit(...)`.
- Plain edits still use the normal edit RPCs: `beginEdit`, `commitEdit`, `cancelEdit`.
- Overlay key handling ignores commit/cancel shortcuts while Flutter reports an active composing range.
- Edit RPCs include the current `session_id` and `state_version` when mutating the active session.

Practical result:

- Android/iOS Flutter builds rely on the normal platform text system.
- Desktop Flutter builds can start IME composition before the visible edit box exists.

### Java Desktop

Primary file:

- `java/desktop/src/main/java/io/github/ivere27/volvoxgrid/desktop/VolvoxGridDesktopPanel.java`

What the host does:

- The panel itself disables input methods.
- A transparent `JTextField` proxy is always present and input-method enabled.
- The proxy captures `InputMethodEvent` traffic even when the visible edit overlay isn't yet shown.
- IME input can trigger `beginHostEditOverlay()` before cell geometry is ready.
- Committed and composed text are separated from the `InputMethodEvent`.
- `InputContext.endComposition()` is called before commit/cancel to flush pending composition.
- A `DocumentFilter` guards against stale post-cancel mutations from the proxy text field.

Why this shape exists:

- On Swing/X11, `InputMethodEvent` is delivered to `JTextComponent`, not to a plain painted panel.
- The transparent proxy gives the pixel-rendered grid a real IME-capable text target.

### .NET WinForms

Primary file:

- `dotnet/src/common/Volvox/RenderHostCpu.cs`

What the host does:

- Visible editing uses a borderless WinForms `TextBox` with `ImeMode.On`.
- When the overlay is hidden, the host `Control` itself intercepts:
  - `WM_IME_STARTCOMPOSITION`
  - `WM_IME_COMPOSITION`
  - `WM_IME_ENDCOMPOSITION`
  - `WM_IME_CHAR`
- `WM_IME_STARTCOMPOSITION` starts a clean engine edit session for the active cell.
- `WM_IME_COMPOSITION` reads:
  - `GCS_RESULTSTR` for committed text
  - `GCS_COMPSTR` for preedit text
- `WM_IME_ENDCOMPOSITION` clears preedit state.
- `WM_IME_CHAR` is suppressed to avoid duplicate insertion after `GCS_RESULTSTR`.

Practical result:

- WinForms doesn't need a second hidden proxy HWND.
- IMM32 can drive composition directly through the focused control.
- The overlay `TextBox` still takes over when visible editing is active.

### Web/WASM

Primary files:

- `web/js/src/volvoxgrid.ts`
- `runtime/src/wasm.rs`

What the host does:

- The visible editor is a real DOM `input` or `select`.
- A hidden `textarea` `imeProxy` stays focused instead of the canvas while idle.
- `compositionstart` on the proxy begins engine editing at the current selection.
- `compositionupdate` forwards preedit through `set_edit_preedit`.
- `compositionend` commits through `commit_edit_preedit`.
- The transition from proxy to visible editor is delayed so Korean-style immediate follow-up composition doesn't lose focus.
- The visible editor also handles `compositionstart/update/end`.
- Non-IME key redispatch uses `event.isComposing` and `keyCode === 229` guards.
- Session updates from the engine remain authoritative for overlay text and selection.

Practical result:

- Browser IME toggle keys and CJK composition work even though the grid is canvas-rendered.
- The engine remains the source of truth for edit state.

Next: TUI is a different shape entirely.

## TUI hosts

Relevant files:

- `TUI.md`
- `go/README.md`
- `engine/src/compose.rs`
- `engine/src/input.rs`
- `engine/src/grid.rs`

TUI behavior is different on purpose:

- Terminal hosts only forward raw bytes and viewport/capability information.
- There's no host IME surface.
- The engine can enable compose internally.

Default behavior:

- TUI mode enables engine compose by default.
- TUI mode defaults `compose_method = DeadKey`.
- GUI mode leaves engine compose disabled unless a host or session explicitly enables it.

Shipped engine compose methods:

- `DeadKey`
- `Hangul`
- `Telex`

What that means in practice:

- Latin dead-key accents can work in TUI without a host IME.
- Korean Hangul can use the engine algorithm.
- Vietnamese Telex can use the engine algorithm.
- TUI still can't replace dictionary-based IMEs such as Chinese Pinyin or Japanese Kana/Kanji conversion.

Next: how the compatibility adapters fit on top.

## Compatibility adapter matrix

These adapters don't all own IME themselves. Most inherit behavior from their host runtime.

| Adapter | Runtime | IME behavior | Status |
|---|---|---|---|
| `adapters/aggrid` | Web / TypeScript | inherits VolvoxGrid web host IME behavior | no adapter-specific IME layer |
| `adapters/sheet` | Web / TypeScript | inherits VolvoxGrid web host IME behavior | adds sheet-state synchronization on composition start |
| `adapters/sfdatagrid` | Flutter / Dart | inherits `VolvoxGridWidget` IME behavior | no separate adapter IME layer |
| `adapters/report` | Web / React | not an edit-centric adapter | no adapter-specific IME handling |
| `adapters/vsflexgrid` | Windows ActiveX / C/C++/Rust | `ImeComposition` dispatch bridge plus demo host `WM_IME_*` forwarding | external containers must forward IME messages |
| `adapters/xtragrid` | WinForms compare harness | Volvox side inherits WinForms host IME; reference side uses DevExpress native editors | not a standalone IME implementation |

### Sheet adapter

Primary file:

- `adapters/sheet/src/volvox-sheet.ts`

Extra behavior:

- Hooks into VolvoxGrid's `onCompositionEditStart`.
- Synchronizes the sheet edit state machine before focus moves to the visible grid editor.
- Keeps formula-bar state and sheet edit state aligned during IME-driven entry.

### SfDataGrid adapter

Primary file:

- `adapters/sfdatagrid/lib/src/sf_data_grid_volvox.dart`

Behavior:

- Wraps `VolvoxGridWidget`.
- Inherits Flutter's IME path directly.
- Doesn't implement a separate composition bridge.

### AG Grid adapter

Primary file:

- `adapters/aggrid/src/ag-grid-volvox.ts`

Behavior:

- Instantiates the normal web `VolvoxGrid`.
- Relies on the browser + VolvoxGrid web host IME path.
- Doesn't add separate composition logic.

### VSFlexGrid ActiveX adapter

Relevant files:

- `adapters/vsflexgrid/crate/src/lib.rs`
- `adapters/vsflexgrid/src/VolvoxGridCtrl.cpp`
- `adapters/vsflexgrid/mingw/volvoxgrid_ocx.c`
- `adapters/vsflexgrid/mingw/activex_demo_host.c`

Current status:

- The Rust adapter core understands `EditorSessionCommand.preedit_changed` and `preedit_text`.
- The windowless OCX exposes `ImeComposition(text, cursor, commit)` and encodes `preedit_changed` through the existing native edit protobuf path.
- The MinGW demo host forwards `WM_IME_STARTCOMPOSITION`, `WM_IME_COMPOSITION`, and `WM_IME_ENDCOMPOSITION`, and suppresses `WM_IME_CHAR` duplicates.
- `WM_IME_COMPOSITION` reads `GCS_RESULTSTR` and `GCS_COMPSTR` through IMM32 and forwards them to the OCX DISPID bridge.

What that means for you:

- Host wrappers can now drive the engine preedit API through the ActiveX dispatch surface instead of falling back to plain `WM_CHAR`.
- The shipped demo host has functional CJK/dead-key composition support, including inline preedit and commit without duplicate `WM_IME_CHAR` insertion.
- Because the OCX is windowless, any other ActiveX container still needs to forward `WM_IME_*` messages from its host window to `ImeComposition`.

### XtraGrid adapter

Relevant files:

- `adapters/xtragrid/README.md`
- `adapters/xtragrid/test/runner/ScriptCompat.cs`

Current status:

- This is a comparison harness, not a production host layer.
- The DevExpress reference side uses DevExpress editors.
- The Volvox side uses the normal `.NET` host path.
- No additional IME implementation lives in the harness.

Next: how far the shipped paths actually carry you across human languages.

## Natural-language coverage

IME requirements differ by human language. VolvoxGrid's runtime split maps cleanly onto those categories.

| Input class | Examples | Host IME path | Engine compose path |
|---|---|---|---|
| direct keyboard | English, Russian, Arabic, Thai, Indonesian | works | works |
| dead-key accents | Spanish, French, Portuguese, German, Italian, Turkish, Polish | host handles natively | `DeadKey` |
| algorithmic composition shipped | Korean, Vietnamese | host handles natively | `Hangul`, `Telex` |
| algorithmic composition not shipped | Hindi, Bengali, Tamil | host handles natively | not currently implemented |
| dictionary-based IME | Chinese, Japanese | required | out of scope |

Two things follow from that table:

- GUI hosts should keep preferring the platform IME if you want full language coverage.
- TUI covers a useful subset, but not full CJK dictionary input.

Next: where the repo actually stands today.

## Current repo position

Today, the repo is strongest on IME in these public hosts:

- Android
- Flutter GUI
- Java Desktop
- .NET WinForms
- Web/WASM
- TUI engine compose

The main remaining ActiveX caveat is container integration: the Rust core and demo host expose the preedit bridge, but third-party windowless OCX containers still need to forward `WM_IME_*` messages into `ImeComposition`.
