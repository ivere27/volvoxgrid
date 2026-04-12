# Keyboard & Mouse Events in VolvoxGrid

This document covers VolvoxGrid keyboard and mouse event handling across:

- shared Rust engine and proto contract
- grid modes and action dispatch
- mouse hit-testing and pointer interactions
- configuration options
- adapter key forwarding

For IME composition input, see `IME.md`.

## Design Summary

VolvoxGrid has two input paths for non-IME events:

1. **Keyboard**: adapters translate platform key events into a common `KeyEvent` protobuf carrying a virtual key code, modifier bitmask, and optional character.
2. **Mouse/Pointer**: adapters translate platform pointer events into `PointerEvent` (down/up/move with coordinates, button, modifier) and `ScrollEvent` (delta).

All adapters use web/Windows virtual key codes as the common key code space. The engine dispatches actions based on key code + modifier + current mode (non-editing, ENTER mode, EDIT mode).

Three configuration knobs control editing behavior: `EditTrigger`, `TabBehavior`, and `host_key_dispatch`.

## Key Code Convention

Key codes use web/Windows virtual key values. The common codes used by the engine:

| Key code | Key |
|----------|-----|
| 8 | Backspace |
| 9 | Tab |
| 13 | Enter |
| 27 | Escape |
| 32 | Space |
| 33 | PageUp |
| 34 | PageDown |
| 35 | End |
| 36 | Home |
| 37 | Arrow Left |
| 38 | Arrow Up |
| 39 | Arrow Right |
| 40 | Arrow Down |
| 46 | Delete |
| 65 | A |
| 67 | C |
| 86 | V |
| 88 | X |
| 113 | F2 |

### Modifier Bitmask

| Bit | Value | Modifier |
|-----|-------|----------|
| 0 | `0x01` | Shift |
| 1 | `0x02` | Ctrl |
| 2 | `0x04` | Alt |
| 3 | `0x08` | Meta |

### Proto Messages

`proto/volvoxgrid.proto` defines:

```protobuf
message KeyEvent {
  enum Type { KEY_DOWN = 0; KEY_UP = 1; KEY_PRESS = 2; }
  Type   type      = 1;
  int32  key_code  = 2;
  int32  modifier  = 3;   // bitmask: 0x01=Shift, 0x02=Ctrl, 0x04=Alt, 0x08=Meta
  string character = 4;   // for KEY_PRESS: the typed character
}
```

`KEY_DOWN` and `KEY_UP` carry `key_code` for action dispatch. `KEY_PRESS` carries the typed character for text input.

## Grid Modes

The engine has three input modes that determine how keys are dispatched.

### Non-editing mode

The grid is focused but no cell editor is active. Arrow keys navigate, Enter/F2 start editing, Ctrl+C copies.

### ENTER mode (`EditUiMode::EnterMode`)

Spreadsheet-style editing. Activated by pressing Enter or typing a printable character on a cell. Character keys replace the cell content. Arrows commit the edit and move to the adjacent cell. Enter commits and moves down.

### EDIT mode (`EditUiMode::EditMode`)

F2-style editing. Activated by pressing F2 or double-clicking a cell. The caret is placed at the end of the existing text. Arrows move the caret within the text. Up moves caret to start, Down moves caret to end. Enter commits without moving.

Defined in `engine/src/edit.rs`:

```rust
pub enum EditUiMode {
    EnterMode,  // default — spreadsheet Enter-style
    EditMode,   // F2-style
}
```

## Keyboard Action Tables

All key dispatch logic lives in `engine/src/input.rs`, functions `handle_key_down_with_behavior` and `handle_key_press_with_behavior`.

### Non-editing mode

| Action | Key | Modifier | Notes |
|--------|-----|----------|-------|
| Move left | Left Arrow | | |
| Move right | Right Arrow | | |
| Move up | Up Arrow | | |
| Move down | Down Arrow | | |
| Extend selection left | Left Arrow | Shift | |
| Extend selection right | Right Arrow | Shift | |
| Extend selection up | Up Arrow | Shift | |
| Extend selection down | Down Arrow | Shift | |
| Page up | PageUp | | jumps by visible rows |
| Page down | PageDown | | jumps by visible rows |
| Home (first column) | Home | | moves to first data column |
| End (last column) | End | | moves to last column |
| Grid origin | Home | Ctrl | moves to top-left data cell |
| Grid end | End | Ctrl | moves to bottom-right cell |
| Tab next cell | Tab | | requires `TabBehavior::TabCells` |
| Tab previous cell | Tab | Shift | requires `TabBehavior::TabCells` |
| Select all | A | Ctrl | selects all data cells |
| Copy | C | Ctrl | emits `Copy` event to host |
| Cut | X | Ctrl | emits `Cut` event to host |
| Paste | V | Ctrl | emits `Paste` event to host |
| Toggle checkbox | Space | | only on boolean checkbox cells |
| Begin edit (Enter) | Enter | | requires `EditTrigger >= KEY`; toggles checkbox if boolean cell |
| Begin edit (F2) | F2 | | requires `EditTrigger >= KEY`; caret at end of existing text; skips checkbox cells |
| Auto-start edit | any printable char | | requires `EditTrigger >= KEY`; clears cell, types character |
| Cancel header drag | Escape | | only during column drag/reorder |

### ENTER mode (editing)

| Action | Key | Modifier | Notes |
|--------|-----|----------|-------|
| Commit + move down | Enter | | skipped when `host_key_dispatch` |
| Cancel edit | Escape | | restores original value; skipped when `host_key_dispatch` |
| Commit + move up | Up Arrow | | commits and moves selection up |
| Commit + move down | Down Arrow | | commits and moves selection down |
| Move caret left | Left Arrow | | |
| Move caret right | Right Arrow | | |
| Move caret to start | Home | | |
| Move caret to end | End | | |
| Select all text | A | Ctrl | |
| Backspace | Backspace | | |
| Delete forward | Delete | | |

Dropdown-specific overrides in ENTER mode:

| Action | Key | Notes |
|--------|-----|-------|
| Move dropdown selection up | Up Arrow | when dropdown list is open |
| Move dropdown selection down | Down Arrow | when dropdown list is open |

### EDIT mode (editing)

| Action | Key | Modifier | Notes |
|--------|-----|----------|-------|
| Commit | Enter | | skipped when `host_key_dispatch` |
| Cancel edit | Escape | | restores original value; skipped when `host_key_dispatch` |
| Move caret left | Left Arrow | | within text |
| Move caret right | Right Arrow | | within text |
| Move caret to start | Up Arrow | | equivalent to Home |
| Move caret to end | Down Arrow | | equivalent to End |
| Move caret to start | Home | | |
| Move caret to end | End | | |
| Select all text | A | Ctrl | |
| Backspace | Backspace | | |
| Delete forward | Delete | | |

## Mouse Event Dispatch

### Proto Messages

```protobuf
message PointerEvent {
  enum Type { DOWN = 0; UP = 1; MOVE = 2; }
  Type  type      = 1;
  float x         = 2;   // viewport-local X coordinate
  float y         = 3;   // viewport-local Y coordinate
  int32 modifier  = 4;   // bitmask: 0x01=Shift, 0x02=Ctrl, 0x04=Alt, 0x08=Meta
  int32 button    = 5;   // bitmask: 0x01=primary (left), 0x02=secondary (right)
  bool  dbl_click = 6;
}

message ScrollEvent {
  float delta_x = 1;
  float delta_y = 2;
}
```

### Hit Areas

The engine hit-tests pointer coordinates against these regions, defined in `engine/src/input.rs`:

| HitArea | Description |
|---------|-------------|
| Cell | regular cell background / padding |
| CellText | text content inside a cell |
| CellPicture | picture content inside a cell |
| CellButtonPicture | button_picture content inside a cell |
| FixedRow | fixed row header |
| FixedCol | fixed column header |
| FixedCorner | top-left fixed corner |
| IndicatorColTop | top column indicator band |
| IndicatorRowStart | start row indicator band |
| IndicatorCornerTopStart | top-start indicator corner |
| ColBorder | between column headers (resize handle) |
| RowBorder | between row headers (resize handle) |
| OutlineButton | outline +/- button (tree expand/collapse) |
| CheckBox | checkbox in cell |
| DropdownButton | dropdown button in cell |
| DropdownList | open dropdown list overlay |
| HScrollBar | horizontal scrollbar (track, thumb, arrows) |
| VScrollBar | vertical scrollbar (track, thumb, arrows) |
| FastScroll | fast scroll touch zone (right edge) |
| Background | empty area beyond grid |

### Click Behavior

**Single click on a data cell** (`Cell`, `CellText`, `CellPicture`, `CellButtonPicture`):

- Moves cell selection (fires `CellFocusChanging` / `CellFocusChanged`)
- Shift+click extends selection range
- Ctrl+click toggles row in ListBox selection mode
- Opens dropdown editor on single-click for dropdown cells (when `EditTrigger >= KEY_CLICK`)
- Click-away from active editor commits plain text edits, cancels dropdown edits

**Double click on a data cell**:

- Begins EDIT mode (F2-style) with caret positioned at click location
- Requires `EditTrigger >= KEY_CLICK`

**Checkbox cell click**:

- Single click toggles the checkbox value
- Skipped when `host_pointer_dispatch`

**Dropdown button click**:

- Opens the dropdown list for the cell
- If already editing the same cell, fires `DropdownOpened`

**Outline button click**:

- Toggles tree node expand/collapse
- Fires `BeforeNodeToggle` / `AfterNodeToggle`

**Column header click** (`IndicatorColTop`, `FixedRow`):

- When `header_features & 1` (sort): triggers column sort (`BeforeSort` / `AfterSort`)
- When `header_features & 2` (move): initiates column drag/reorder on long-press
- When `header_click_select` and no header features: selects the entire column

**Row header click** (`IndicatorRowStart`):

- When `header_click_select`: selects the entire row

**Indicator corner click** (`IndicatorCornerTopStart`):

- Selects all cells (equivalent to Ctrl+A)

**Column border double click** (`ColBorder`):

- Auto-fits column width (when `auto_size_mouse` is enabled)

### Drag Behavior

| Gesture | Hit area | Action |
|---------|----------|--------|
| Drag on data cell | Cell/CellText/... | Extends selection to dragged cell |
| Drag on column border | ColBorder | Resizes column width |
| Drag on row border | RowBorder | Resizes row height |
| Drag on column header | IndicatorColTop/FixedRow | Column reorder (after long-press) |
| Drag on scrollbar thumb | HScrollBar/VScrollBar | Scrollbar tracking |
| Drag on frozen pane separator | Cell near frozen line | Adjusts frozen row/column count |
| Drag on fast scroll zone | FastScroll | Fast scroll to proportional position |

### Scroll

`ScrollEvent` with `delta_x` / `delta_y` scrolls the viewport. The engine supports fling/momentum scrolling which decelerates over time.

Scrollbar track clicks scroll by one page. Scrollbar arrow clicks scroll by a small step. Both support auto-repeat on held press.

## Configuration Options

Defined in `proto/volvoxgrid.proto`:

### EditTrigger

```protobuf
enum EditTrigger {
  EDIT_TRIGGER_NONE      = 0;  // no keyboard or click editing
  EDIT_TRIGGER_KEY       = 1;  // Enter, F2, and printable chars start editing
  EDIT_TRIGGER_KEY_CLICK = 2;  // above + double-click starts editing
}
```

- `NONE`: cells are read-only to user input; editing only via API
- `KEY`: Enter key, F2, and printable character keystrokes start editing
- `KEY_CLICK`: adds double-click to start editing

### TabBehavior

```protobuf
enum TabBehavior {
  TAB_CONTROLS = 0;  // Tab moves focus out of the grid
  TAB_CELLS    = 1;  // Tab moves between cells
}
```

### EditConfig flags

```protobuf
message EditConfig {
  optional EditTrigger trigger              = 1;
  optional TabBehavior tab_behavior         = 2;
  optional bool        host_key_dispatch    = 7;
  optional bool        host_pointer_dispatch = 8;
  // ... other fields omitted
}
```

- `host_key_dispatch`: when true, the engine stops handling edit-action keys (Enter to commit, Escape to cancel, arrows to navigate during edit). The host adapter drives editing via RPC (`EditCommand`) instead.
- `host_pointer_dispatch`: when true, the engine stops handling pointer-driven selection changes and edit triggers. The host adapter drives selection and editing via RPC.

## Event Output

All events are defined in `engine/src/event.rs` as variants of `GridEventData`.

### Raw input events (always emitted)

| Event | Payload | When |
|-------|---------|------|
| `KeyDown` | `key_code`, `modifier` | every key down |
| `KeyUp` | `key_code`, `modifier` | every key up |
| `KeyPress` | `key_ascii` | printable character input |
| `KeyDownEdit` | `key_code`, `modifier` | key down while editing |
| `KeyPressEdit` | `key_ascii` | character input while editing |
| `KeyUpEdit` | `key_code`, `modifier` | key up while editing |
| `MouseDown` | `button`, `modifier`, `x`, `y` | pointer down |
| `MouseUp` | `button`, `modifier`, `x`, `y` | pointer up |
| `MouseMove` | `button`, `modifier`, `x`, `y` | pointer move |
| `Click` | `row`, `col`, `hit_area`, `interaction` | click on a cell |
| `DblClick` | `row`, `col` | double click on a cell |

### Action events

| Event | Payload | When |
|-------|---------|------|
| `CellFocusChanging` | old/new row/col | before selection moves (cancelable) |
| `CellFocusChanged` | old/new row/col | after selection moves |
| `SelectionChanging` | old/new ranges, active row/col | before selection changes (cancelable) |
| `SelectionChanged` | old/new ranges, active row/col | after selection changes |
| `BeforeEdit` | row, col | before editing starts (cancelable) |
| `StartEdit` | row, col | editing has started |
| `AfterEdit` | row, col, old_text, new_text | after editing commits or cancels |
| `CellEditChange` | text | text changed during editing |
| `CellEditValidate` | row, col, edit_text | validation request during edit |
| `BeforeSort` | col | before column sort (cancelable) |
| `AfterSort` | col | after column sort |
| `BeforeScroll` | old/new top_row, left_col | before scroll (cancelable) |
| `AfterScroll` | old/new top_row, left_col | after scroll |
| `BeforeUserResize` | row, col | before column/row resize |
| `AfterUserResize` | row, col | after column/row resize |
| `BeforeMoveColumn` | col, new_position | before column reorder (cancelable) |
| `AfterMoveColumn` | col, old_position | after column reorder |
| `BeforeNodeToggle` | row, collapse | before outline expand/collapse (cancelable) |
| `AfterNodeToggle` | row, collapse | after outline expand/collapse |

### Clipboard events

| Event | When |
|-------|------|
| `Copy` | Ctrl+C pressed |
| `Cut` | Ctrl+X pressed |
| `Paste` | Ctrl+V pressed |

The engine emits these events but does not access the system clipboard. The host adapter receives the event and implements actual clipboard read/write using platform APIs.

## Adapter Key Forwarding

Each adapter translates platform key events into the common `KeyEvent` proto. The translation strategy varies by platform.

### Flutter

File: `flutter/lib/volvoxgrid.dart`

```dart
void _forwardRawKeyEvent(KeyEvent event) {
  ...
  ..keyCode = (event.logicalKey.keyId & 0x7FFFFFFF).toInt()
  ..character = event.character ?? ''
  ..modifier = _modifiers()
}
```

- `LogicalKeyboardKey.keyId & 0x7FFFFFFF` yields web/Windows virtual key codes
- Modifier bitmask built from `HardwareKeyboard.instance.isShiftPressed` etc.
- Sends `KEY_DOWN` and `KEY_UP`; character input handled separately by the host text field

### Java Desktop

File: `java/desktop/.../VolvoxGridDesktopPanel.java`

```java
sendKeyDirect(type, keyCode, modifier, character);
```

- AWT `KeyEvent.getKeyCode()` returns `VK_*` constants which are the same as web/Windows virtual key codes
- Direct passthrough — no translation needed
- Sends `KEY_DOWN`, `KEY_UP`, and `KEY_PRESS` for printable characters

### .NET WinForms

File: `dotnet/src/common/Volvox/RenderHostCpu.cs`

```csharp
var payload = _client.EncodeRenderInputKey(_gridId, KeyDownEvent, (int)e.KeyCode, GetModifiers(), string.Empty);
```

- `System.Windows.Forms.Keys` enum values are the same as Windows virtual key codes
- Direct cast — no translation needed
- Sends `KEY_DOWN`, `KEY_UP`, and `KEY_PRESS` for printable characters

### Web/WASM

File: `web/js/src/default-input.ts`

```typescript
wasm.handle_key_down(gridId, e.keyCode, modifier);
```

- DOM `KeyboardEvent.keyCode` is already a web virtual key code
- Modifier built from `shiftKey`, `ctrlKey`/`metaKey`, `altKey`
- Meta key is folded into Ctrl bit (`m |= 2`) for Mac Cmd key compatibility
- IME guard: events with `isComposing` or `keyCode === 229` are suppressed

### Android

File: `android/.../VolvoxGridView.kt`

```kotlin
KeyEvent.newBuilder()
    .setType(KeyEvent.Type.KEY_DOWN)
    .setKeyCode(keyCode)
    .setModifier(event.metaState)
    .setCharacter(...)
```

- Android `KEYCODE_*` constants are forwarded directly
- Android key codes overlap with web/Windows virtual key codes for common keys (Enter=66 on Android vs 13 on web — the engine handles both)
- Navigation keys (`DPAD_UP/DOWN/LEFT/RIGHT`, `ENTER`, `ESCAPE`, `TAB`) are intercepted from the idle proxy and forwarded
- Printable characters generate a follow-up `KEY_PRESS` with the unicode character

### Summary Table

| Adapter | Platform key type | Translation method |
|---------|-------------------|--------------------|
| Flutter | `LogicalKeyboardKey.keyId` | `& 0x7FFFFFFF` to virtual key code |
| Java Desktop | `java.awt.event.KeyEvent.VK_*` | direct (same values) |
| .NET WinForms | `System.Windows.Forms.Keys` | direct cast (same values) |
| Web/WASM | DOM `KeyboardEvent.keyCode` | direct (native web key codes) |
| Android | Android `KeyEvent.KEYCODE_*` | direct forward; overlapping codes for common keys |
