/**
 * Default keyboard and context menu handlers for VolvoxGrid.
 *
 * VolvoxGrid itself only registers pointer and wheel events (core engine
 * mechanics). Higher-level input — keyboard navigation, edit-on-keypress,
 * and context menus — is left to the consumer.
 *
 * For adapters like VolvoxSheet that implement their own key dispatch and
 * context menus, these helpers are NOT needed.
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
 * - Starts editing on printable key press
 * - Forwards all keys to the engine via handle_key_down
 *
 * Returns a cleanup function to remove the listener.
 */
export function setupDefaultKeyboard(
  grid: DefaultInputGrid,
  wasm: any,
  canvas: HTMLCanvasElement,
): () => void {
  const gridId = grid.id;

  const onKeyDown = (e: KeyboardEvent): void => {
    if (NAV_KEYS.has(e.key)) {
      e.preventDefault();
    }

    // Printable key starts edit mode and seeds the first character.
    // suppressEditorSelect prevents editInput.select() from selecting
    // the seeded character (which would cause "abc" → "bc").
    if (!wasm.is_editing(gridId) && isPrintableEditKey(e)) {
      if (typeof wasm.begin_edit_at_selection === "function") {
        (grid as any).suppressEditorSelect = true;
        wasm.begin_edit_at_selection(gridId);
        if (wasm.is_editing(gridId)) {
          wasm.set_edit_text(gridId, e.key);
          if (typeof wasm.set_edit_selection === "function") {
            wasm.set_edit_selection(gridId, 1, 0);
          }
          grid.invalidate();
          e.preventDefault();
          requestAnimationFrame(() => { (grid as any).suppressEditorSelect = false; });
          return;
        }
        (grid as any).suppressEditorSelect = false;
      }
    }

    const modifier = modifierBits(e);
    wasm.handle_key_down(gridId, e.keyCode, modifier);
    grid.invalidate();
  };

  canvas.addEventListener("keydown", onKeyDown);
  return () => canvas.removeEventListener("keydown", onKeyDown);
}

// ── Context Menu ────────────────────────────────────────────────

/**
 * Attach a default right-click context menu with Copy, Pin, and Sticky options.
 * Returns a cleanup function to remove the listener and any open menu.
 */
export function setupDefaultContextMenu(
  grid: DefaultInputGrid,
  wasm: any,
  canvas: HTMLCanvasElement,
): () => void {
  const gridId = grid.id;
  let menuEl: HTMLDivElement | null = null;
  let dismissHandler: ((e: Event) => void) | null = null;
  let escHandler: ((e: KeyboardEvent) => void) | null = null;

  function dismiss(): void {
    if (menuEl) { menuEl.remove(); menuEl = null; }
    if (dismissHandler) { document.removeEventListener("pointerdown", dismissHandler); dismissHandler = null; }
    if (escHandler) { document.removeEventListener("keydown", escHandler); escHandler = null; }
  }

  function addItem(menu: HTMLDivElement, label: string, action: () => void): void {
    const item = document.createElement("div");
    item.textContent = label;
    Object.assign(item.style, { padding: "6px 16px", cursor: "pointer", whiteSpace: "nowrap" });
    item.addEventListener("pointerenter", () => { item.style.background = "#f0f0f0"; });
    item.addEventListener("pointerleave", () => { item.style.background = "transparent"; });
    item.addEventListener("click", () => { action(); dismiss(); });
    menu.appendChild(item);
  }

  function addSeparator(menu: HTMLDivElement): void {
    const last = menu.lastElementChild;
    if (!last || (last as HTMLElement).dataset.separator === "1") return;
    const sep = document.createElement("div");
    sep.dataset.separator = "1";
    Object.assign(sep.style, { height: "1px", background: "#e0e0e0", margin: "4px 8px" });
    menu.appendChild(sep);
  }

  const onContextMenu = (e: Event): void => {
    e.preventDefault();
    dismiss();

    const me = e as MouseEvent;
    const row = Number(wasm.get_mouse_row(gridId));
    const col = Number(wasm.get_mouse_col(gridId));
    const fixedRows = Number(wasm.get_fixed_rows(gridId));
    const fixedCols = Number(wasm.get_fixed_cols(gridId));
    const isDataRow = row >= fixedRows;
    const isDataCol = col >= fixedCols;

    const menu = document.createElement("div");
    Object.assign(menu.style, {
      position: "fixed", zIndex: "2147483647", background: "#fff",
      border: "1px solid #ccc", borderRadius: "4px",
      boxShadow: "0 4px 12px rgba(0,0,0,0.15)", padding: "4px 0",
      minWidth: "180px", fontFamily: "system-ui, -apple-system, sans-serif",
      fontSize: "13px", color: "#222", userSelect: "none",
    });

    // Copy
    addItem(menu, "Copy", () => {
      const text = String(wasm.copy_selection(gridId));
      if (text && navigator.clipboard) navigator.clipboard.writeText(text);
    });
    addSeparator(menu);

    // Row pin items (only for data rows)
    if (isDataRow && row >= 0) {
      const pinned = typeof wasm.is_row_pinned === "function" ? Number(wasm.is_row_pinned(gridId, row)) : 0;
      if (pinned !== 1) addItem(menu, `Pin Row ${row} to Top`, () => grid.pinRow(row, 1));
      if (pinned !== 2) addItem(menu, `Pin Row ${row} to Bottom`, () => grid.pinRow(row, 2));
      addItem(menu, `Unpin Row ${row}`, () => grid.pinRow(row, 0));

      addSeparator(menu);

      // Row sticky items
      const stickyRow = typeof wasm.get_row_sticky === "function" ? Number(wasm.get_row_sticky(gridId, row)) : 0;
      if (stickyRow !== 1) addItem(menu, `Sticky Row ${row} to Top`, () => grid.setRowSticky(row, 1));
      if (stickyRow !== 2) addItem(menu, `Sticky Row ${row} to Bottom`, () => grid.setRowSticky(row, 2));
      if (stickyRow !== 5) addItem(menu, `Sticky Row ${row} Both`, () => grid.setRowSticky(row, 5));
      addItem(menu, `Unsticky Row ${row}`, () => grid.setRowSticky(row, 0));
    }

    // Column sticky items (for data columns)
    if (isDataCol && col >= 0) {
      if (isDataRow) addSeparator(menu);

      const stickyCol = typeof wasm.get_col_sticky === "function" ? Number(wasm.get_col_sticky(gridId, col)) : 0;
      if (stickyCol !== 3) addItem(menu, `Sticky Col ${col} to Left`, () => grid.setColSticky(col, 3));
      if (stickyCol !== 4) addItem(menu, `Sticky Col ${col} to Right`, () => grid.setColSticky(col, 4));
      if (stickyCol !== 5) addItem(menu, `Sticky Col ${col} Both`, () => grid.setColSticky(col, 5));
      addItem(menu, `Unsticky Col ${col}`, () => grid.setColSticky(col, 0));
    }

    if (menu.childElementCount === 0) return;

    menuEl = menu;
    document.body.appendChild(menu);

    let x = me.clientX, y = me.clientY;
    menu.style.left = `${x}px`;
    menu.style.top = `${y}px`;
    requestAnimationFrame(() => {
      const vw = window.innerWidth, vh = window.innerHeight;
      const mw = menu.offsetWidth, mh = menu.offsetHeight;
      if (x + mw > vw) x = Math.max(0, vw - mw - 4);
      if (y + mh > vh) y = Math.max(0, vh - mh - 4);
      menu.style.left = `${x}px`;
      menu.style.top = `${y}px`;
    });

    setTimeout(() => {
      dismissHandler = (ev: Event) => { if (!menu.contains(ev.target as Node)) dismiss(); };
      escHandler = (ev: KeyboardEvent) => { if (ev.key === "Escape") dismiss(); };
      document.addEventListener("pointerdown", dismissHandler);
      document.addEventListener("keydown", escHandler);
    }, 0);
  };

  canvas.addEventListener("contextmenu", onContextMenu);
  return () => { dismiss(); canvas.removeEventListener("contextmenu", onContextMenu); };
}

// ── Combined ────────────────────────────────────────────────────

/**
 * Set up both default keyboard and context menu handlers.
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
