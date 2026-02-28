/**
 * Edit lifecycle state machine.
 *
 * Tracks whether a cell is being edited and dispatches Edit RPC
 * commands to VolvoxGrid via protobuf.
 */

import {
  encodeEditStart,
  encodeEditCommit,
  encodeEditCancel,
} from "../proto/proto-utils.js";

export type EditPhase = "idle" | "editing";
/** "enter" = started by typing a key (arrow exits); "edit" = F2/dblclick (arrow moves caret). */
export type EditMode = "enter" | "edit";

export class EditStateMachine {
  private _phase: EditPhase = "idle";
  private _mode: EditMode = "enter";
  private _formulaMode = false;
  private _row: number = -1;
  private _col: number = -1;
  private _originalText: string = "";
  private _currentText: string = "";

  private wasm: any;
  private gridId: number;

  constructor(wasm: any, gridId: number) {
    this.wasm = wasm;
    this.gridId = gridId;
  }

  get phase(): EditPhase { return this._phase; }
  get isEditing(): boolean { return this._phase === "editing"; }
  get mode(): EditMode { return this._mode; }
  /** True when arrow keys should move the caret instead of committing. */
  get isEditMode(): boolean { return this._mode === "edit"; }
  get isFormulaMode(): boolean { return this._formulaMode; }
  /** Override the edit mode (e.g. dblclick forces "edit" mode). */
  set editMode(m: EditMode) { this._mode = m; }
  get row(): number { return this._row; }
  get col(): number { return this._col; }
  get originalText(): string { return this._originalText; }
  get currentText(): string { return this._currentText; }

  /** Start editing a cell. */
  startEdit(row: number, col: number, opts?: {
    selectAll?: boolean;
    caretEnd?: boolean;
    seedText?: string;
    currentText?: string;
    mode?: EditMode;
    formulaMode?: boolean;
  }): void {
    if (this._phase === "editing") {
      this.commitEdit();
    }

    this._row = row;
    this._col = col;
    this._originalText = opts?.currentText ?? "";
    this._currentText = opts?.seedText ?? this._originalText;
    this._phase = "editing";
    this._mode = opts?.mode ?? "enter";
    this._formulaMode =
      opts?.formulaMode
      ?? this._currentText.trimStart().startsWith("=");

    if (typeof this.wasm.volvox_grid_edit_pb === "function") {
      const req = encodeEditStart({
        gridId: this.gridId,
        row,
        col,
        selectAll: opts?.selectAll,
        caretEnd: opts?.caretEnd,
        seedText: opts?.seedText,
        formulaMode: this._formulaMode,
      });
      this.wasm.volvox_grid_edit_pb(req);
    }
  }

  /** Commit the current edit. Returns { oldText, newText } or null if not editing. */
  commitEdit(text?: string): { oldText: string; newText: string } | null {
    if (this._phase !== "editing") return null;

    const oldText = this._originalText;
    const newText = text ?? this._currentText;

    if (typeof this.wasm.volvox_grid_edit_pb === "function") {
      const req = encodeEditCommit({ gridId: this.gridId, text });
      this.wasm.volvox_grid_edit_pb(req);
    }

    this._phase = "idle";
    return { oldText, newText };
  }

  /** Cancel the current edit. */
  cancelEdit(): void {
    if (this._phase !== "editing") return;

    if (typeof this.wasm.volvox_grid_edit_pb === "function") {
      const req = encodeEditCancel(this.gridId);
      this.wasm.volvox_grid_edit_pb(req);
    }

    this._phase = "idle";
  }

  /** Update current text from engine's cell_edit_change event. */
  onEditTextChanged(text: string): void {
    if (this._phase === "editing") {
      this._currentText = text;
      this._formulaMode = text.trimStart().startsWith("=");
    }
  }

  /** Called when engine reports edit started (StartEditEvent). */
  onEngineStartEdit(row: number, col: number): void {
    this._phase = "editing";
    this._row = row;
    this._col = col;
    this._formulaMode = this._currentText.trimStart().startsWith("=");
  }

  /** Called when engine reports edit ended (AfterEditEvent). */
  onEngineAfterEdit(row: number, col: number, oldText: string, newText: string): void {
    this._phase = "idle";
    this._originalText = oldText;
    this._currentText = newText;
    this._formulaMode = false;
  }

  /** Reset state on destroy. */
  reset(): void {
    this._phase = "idle";
    this._mode = "enter";
    this._row = -1;
    this._col = -1;
    this._originalText = "";
    this._currentText = "";
    this._formulaMode = false;
  }
}
