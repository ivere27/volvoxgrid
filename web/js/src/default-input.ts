/**
 * Default keyboard helpers for VolvoxGrid.
 *
 * VolvoxGrid itself owns pointer, wheel, and context-menu request events.
 * Higher-level keyboard input remains opt-in via these helpers.
 *
 * For adapters like VolvoxSheet that implement their own key dispatch, these
 * helpers are NOT needed.
 *
 * For simple demos or thin wrappers, call:
 *   const cleanup = setupDefaultInput(grid, wasm, canvas);
 *   // later: cleanup();
 */

/** Minimal surface used by default-input helpers. */
export interface DefaultInputGrid {
  readonly id: number;
  invalidate(): void;
  pinRow(row: number, mode: number): void;
  setRowSticky(row: number, edge: number): void;
  setColSticky(col: number, edge: number): void;
  /** When true, syncInputEditor skips select() so the first typed char isn't selected. */
  suppressEditorSelect?: boolean;
}

// ── Keyboard ────────────────────────────────────────────────────

const NAV_KEYS = new Set([
  "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight",
  "PageUp", "PageDown", "Home", "End", "Tab",
]);

function modifierBits(e: KeyboardEvent): number {
  let m = 0;
  if (e.shiftKey) m |= 1;
  if (e.ctrlKey || e.metaKey) m |= 2;
  if (e.altKey) m |= 4;
  return m;
}

function isPrintableEditKey(e: KeyboardEvent): boolean {
  if (e.ctrlKey || e.metaKey || e.altKey) return false;
  return e.key.length === 1;
}

/**
 * Attach a default keyboard handler that:
 * - Navigates with arrow/tab/page/home/end keys
 * - Forwards printable characters via handle_key_press so the engine decides
 *   whether to edit, toggle, or ignore them
 * - Forwards all keys to the engine via handle_key_down
 *
 * Returns a cleanup function to remove the listener.
 */
export function setupDefaultKeyboard(
  grid: DefaultInputGrid,
  wasm: any,
  canvas: HTMLCanvasElement,
): () => void {
  const onKeyDown = (e: KeyboardEvent): void => {
    const gridId = grid.id;

    if (NAV_KEYS.has(e.key)) {
      e.preventDefault();
    }

    const printable = isPrintableEditKey(e);
    if (printable) {
      e.preventDefault();
    }

    const modifier = modifierBits(e);
    wasm.handle_key_down(gridId, e.keyCode, modifier);
    if (printable && typeof wasm.handle_key_press === "function") {
      const charCode = e.key.codePointAt(0);
      if (charCode != null) {
        wasm.handle_key_press(gridId, charCode);
      }
    }
    grid.invalidate();
  };

  canvas.addEventListener("keydown", onKeyDown);
  return () => canvas.removeEventListener("keydown", onKeyDown);
}

// ── Context Menu ────────────────────────────────────────────────

/**
 * Legacy no-op. Context menus are host-owned and should be attached via
 * `grid.onContextMenuRequest`.
 */
export function setupDefaultContextMenu(
  grid: DefaultInputGrid,
  wasm: any,
  canvas: HTMLCanvasElement,
): () => void {
  void grid;
  void wasm;
  void canvas;
  return () => {};
}

// ── Combined ────────────────────────────────────────────────────

/**
 * Set up default keyboard handlers.
 * Returns a single cleanup function.
 */
export function setupDefaultInput(
  grid: DefaultInputGrid,
  wasm: any,
  canvas: HTMLCanvasElement,
): () => void {
  const cleanupKb = setupDefaultKeyboard(grid, wasm, canvas);
  const cleanupCtx = setupDefaultContextMenu(grid, wasm, canvas);
  return () => { cleanupKb(); cleanupCtx(); };
}
