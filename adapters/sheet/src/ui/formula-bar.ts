/**
 * Formula bar — Office 365 style.
 *
 * Name box (A1 ref) | fx button | [check | cancel] | formula input | expand toggle
 *
 * Syncs bidirectionally with the edit state machine:
 * - Selection change → update name box + show cell value
 * - Type in formula input → push text to engine via EditSetText
 * - Engine cell_edit_change → update formula input
 * - Enter → commit; Escape → cancel
 */

import type { EditStateMachine } from "../core/edit-state-machine.js";
import type { SelectionModel } from "../core/selection-model.js";
import type { DataStore } from "../core/data-store.js";
import { fromA1 } from "../core/cell-reference.js";
import { iconEl } from "./icons.js";

export class FormulaBar {
  readonly element: HTMLDivElement;
  private nameBox: HTMLInputElement;
  private fxBtn: HTMLButtonElement;
  private editBtns: HTMLDivElement;
  private checkBtn: HTMLButtonElement;
  private cancelBtn: HTMLButtonElement;
  private formulaInput: HTMLInputElement;
  private expandBtn: HTMLButtonElement;
  private editState: EditStateMachine;
  private selection: SelectionModel;
  private store: DataStore;
  private expanded = false;

  /** Callback when user commits from formula bar. */
  onCommit: ((text: string) => void) | null = null;
  /** Callback when user cancels from formula bar. */
  onCancel: (() => void) | null = null;
  /** Callback when user navigates to a cell via name box. */
  onNavigate: ((dataRow: number, dataCol: number) => void) | null = null;
  /** Callback when formula bar starts editing. */
  onStartEdit: ((text: string) => void) | null = null;

  constructor(
    editState: EditStateMachine,
    selection: SelectionModel,
    store: DataStore,
  ) {
    this.editState = editState;
    this.selection = selection;
    this.store = store;

    this.element = document.createElement("div");
    this.element.className = "vx-formula-bar";

    // Name box
    this.nameBox = document.createElement("input");
    this.nameBox.className = "vx-name-box";
    this.nameBox.type = "text";
    this.nameBox.setAttribute("aria-label", "Cell reference");

    // fx button
    this.fxBtn = document.createElement("button");
    this.fxBtn.type = "button";
    this.fxBtn.className = "vx-fx-btn";
    this.fxBtn.textContent = "fx";
    this.fxBtn.title = "Insert Function";
    this.fxBtn.tabIndex = -1;

    // Edit commit/cancel buttons (hidden by default)
    this.editBtns = document.createElement("div");
    this.editBtns.className = "vx-fx-edit-btns";

    this.cancelBtn = document.createElement("button");
    this.cancelBtn.type = "button";
    this.cancelBtn.className = "vx-fx-cancel";
    this.cancelBtn.title = "Cancel (Escape)";
    this.cancelBtn.tabIndex = -1;
    this.cancelBtn.appendChild(iconEl("close", 16));

    this.checkBtn = document.createElement("button");
    this.checkBtn.type = "button";
    this.checkBtn.className = "vx-fx-check";
    this.checkBtn.title = "Confirm (Enter)";
    this.checkBtn.tabIndex = -1;
    this.checkBtn.appendChild(iconEl("check", 16));

    this.editBtns.appendChild(this.cancelBtn);
    this.editBtns.appendChild(this.checkBtn);

    // Formula input
    this.formulaInput = document.createElement("input");
    this.formulaInput.className = "vx-formula-input";
    this.formulaInput.type = "text";
    this.formulaInput.setAttribute("aria-label", "Formula input");

    // Expand toggle
    this.expandBtn = document.createElement("button");
    this.expandBtn.type = "button";
    this.expandBtn.className = "vx-fx-expand";
    this.expandBtn.title = "Expand Formula Bar";
    this.expandBtn.tabIndex = -1;
    this.expandBtn.appendChild(iconEl("expand_more", 14));

    // Assemble
    this.element.appendChild(this.nameBox);
    this.element.appendChild(this.fxBtn);
    this.element.appendChild(this.editBtns);
    this.element.appendChild(this.formulaInput);
    this.element.appendChild(this.expandBtn);

    this.bindEvents();
  }

  private bindEvents(): void {
    // Name box: Enter navigates to typed cell
    this.nameBox.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        const ref = fromA1(this.nameBox.value.trim());
        if (ref && this.onNavigate) {
          this.onNavigate(ref.dataRow, ref.dataCol);
        }
        this.nameBox.blur();
      }
      if (e.key === "Escape") {
        e.preventDefault();
        this.updateNameBox();
        this.nameBox.blur();
      }
    });

    // Formula input: typing starts edit if not already editing
    this.formulaInput.addEventListener("input", () => {
      if (!this.editState.isEditing && this.onStartEdit) {
        this.onStartEdit(this.formulaInput.value);
      }
    });

    this.formulaInput.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        if (this.onCommit) {
          this.onCommit(this.formulaInput.value);
        }
        this.formulaInput.blur();
      }
      if (e.key === "Escape") {
        e.preventDefault();
        if (this.onCancel) {
          this.onCancel();
        }
        this.formulaInput.blur();
      }
    });

    // Commit button
    this.checkBtn.addEventListener("click", (e) => {
      e.preventDefault();
      if (this.onCommit) {
        this.onCommit(this.formulaInput.value);
      }
    });

    // Cancel button
    this.cancelBtn.addEventListener("click", (e) => {
      e.preventDefault();
      if (this.onCancel) {
        this.onCancel();
      }
    });

    // Expand toggle
    this.expandBtn.addEventListener("click", (e) => {
      e.preventDefault();
      this.toggleExpanded();
    });
  }

  /** Show or hide the commit/cancel buttons based on editing state. */
  setEditing(isEditing: boolean): void {
    if (isEditing) {
      this.editBtns.classList.add("vx-visible");
    } else {
      this.editBtns.classList.remove("vx-visible");
    }
  }

  private toggleExpanded(): void {
    this.expanded = !this.expanded;
    if (this.expanded) {
      this.element.classList.add("vx-expanded");
      this.expandBtn.title = "Collapse Formula Bar";
      this.expandBtn.innerHTML = "";
      this.expandBtn.appendChild(iconEl("expand_less", 14));
    } else {
      this.element.classList.remove("vx-expanded");
      this.expandBtn.title = "Expand Formula Bar";
      this.expandBtn.innerHTML = "";
      this.expandBtn.appendChild(iconEl("expand_more", 14));
    }
  }

  /** Update the name box with current A1 reference. */
  updateNameBox(): void {
    this.nameBox.value = this.selection.a1Ref;
  }

  /** Update formula input with current cell value. */
  updateFormulaInput(): void {
    if (this.editState.isEditing) {
      this.formulaInput.value = this.editState.currentText;
    } else {
      const value = this.store.getCellRawValue(this.selection.dataRow, this.selection.dataCol);
      this.formulaInput.value = value;
    }
  }

  /** Called on selection change. */
  onSelectionChanged(): void {
    this.updateNameBox();
    this.updateFormulaInput();
  }

  /** Called when edit text changes from engine. */
  onEditTextChanged(text: string): void {
    this.formulaInput.value = text;
  }

  destroy(): void {
    this.element.remove();
  }
}
