/**
 * Configurable key→action mapping for spreadsheet UX.
 *
 * The adapter intercepts browser keydown events and resolves them to
 * SpreadsheetActions. If no action matches, the event passes through
 * to VolvoxGrid's canvas for engine handling.
 */

import type { SpreadsheetAction, KeyContext } from "../types.js";

interface ResolvedBinding {
  idle?: SpreadsheetAction;
  editing?: SpreadsheetAction;
}

/** Normalize a KeyboardEvent into a canonical key string like "Ctrl+Shift+Enter". */
function normalizeKeyCombo(e: KeyboardEvent): string {
  const parts: string[] = [];
  if (e.ctrlKey || e.metaKey) parts.push("Ctrl");
  if (e.shiftKey) parts.push("Shift");
  if (e.altKey) parts.push("Alt");

  let key = e.key;
  // Normalize special keys
  if (key === " ") key = "Space";
  if (key.length === 1) key = key.toUpperCase();

  parts.push(key);
  return parts.join("+");
}

const DEFAULT_BINDINGS: Array<{ key: string; context: KeyContext; action: SpreadsheetAction }> = [
  // ── Idle context ──
  { key: "Enter", context: "idle", action: "startEdit" },
  { key: "F2", context: "idle", action: "startEditCaretEnd" },
  { key: "Delete", context: "idle", action: "clearCell" },
  { key: "Backspace", context: "idle", action: "startEditClear" },
  { key: "Tab", context: "idle", action: "moveRight" },
  { key: "Shift+Tab", context: "idle", action: "moveLeft" },
  { key: "ArrowDown", context: "idle", action: "moveDown" },
  { key: "ArrowUp", context: "idle", action: "moveUp" },
  { key: "ArrowRight", context: "idle", action: "moveRight" },
  { key: "ArrowLeft", context: "idle", action: "moveLeft" },

  // ── Editing context ──
  { key: "Enter", context: "editing", action: "commitMoveDown" },
  { key: "Shift+Enter", context: "editing", action: "commitMoveUp" },
  { key: "Tab", context: "editing", action: "commitMoveRight" },
  { key: "Shift+Tab", context: "editing", action: "commitMoveLeft" },
  { key: "Escape", context: "editing", action: "cancelEdit" },
  // Arrow keys in editing context are handled conditionally by volvox-sheet
  // ("enter" mode → commit+move, "edit" mode → pass to input for caret movement)

  // ── Common (both contexts) ──
  { key: "Ctrl+Z", context: "idle", action: "undo" },
  { key: "Ctrl+Y", context: "idle", action: "redo" },
  { key: "Ctrl+Shift+Z", context: "idle", action: "redo" },
  { key: "Ctrl+C", context: "idle", action: "copy" },
  { key: "Ctrl+X", context: "idle", action: "cut" },
  { key: "Ctrl+V", context: "idle", action: "paste" },
  { key: "Ctrl+B", context: "idle", action: "toggleBold" },
  { key: "Ctrl+I", context: "idle", action: "toggleItalic" },
  { key: "Ctrl+U", context: "idle", action: "toggleUnderline" },
  { key: "Ctrl+A", context: "idle", action: "selectAll" },
  { key: "Ctrl+F", context: "idle", action: "find" },
  { key: "Ctrl+H", context: "idle", action: "findReplace" },
];

export class KeyDispatch {
  private bindings = new Map<string, ResolvedBinding>();

  constructor(userOverrides?: Record<string, SpreadsheetAction>) {
    // Load defaults
    for (const b of DEFAULT_BINDINGS) {
      this.setBinding(b.key, b.context, b.action);
    }
    // Apply user overrides (override both contexts for the key)
    if (userOverrides) {
      for (const [key, action] of Object.entries(userOverrides)) {
        // User overrides apply to both contexts unless key already has context prefix
        this.setBinding(key, "idle", action);
        this.setBinding(key, "editing", action);
      }
    }
  }

  private setBinding(key: string, context: KeyContext, action: SpreadsheetAction): void {
    const existing = this.bindings.get(key) || {};
    existing[context] = action;
    this.bindings.set(key, existing);
  }

  /**
   * Resolve a keyboard event to a spreadsheet action.
   * Returns the action if matched, or null to let the event pass to the engine.
   */
  resolve(e: KeyboardEvent, context: KeyContext): SpreadsheetAction | null {
    const combo = normalizeKeyCombo(e);
    const binding = this.bindings.get(combo);
    if (binding) {
      const action = binding[context];
      if (action) return action;
    }

    // In idle mode, printable single characters start editing with seed text
    if (context === "idle" && !e.ctrlKey && !e.metaKey && !e.altKey) {
      if (e.key.length === 1 && e.key !== " ") {
        return "startEdit"; // caller uses e.key as seed_text
      }
    }

    return null;
  }
}
