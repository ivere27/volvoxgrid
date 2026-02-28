/**
 * Formatting toolbar — Office 365 style.
 *
 * Uses Material Icons Outlined for icons, styled text for B/I/U/S.
 */

import { iconEl } from "./icons.js";

export type ToolbarAction =
  | "undo"
  | "redo"
  | "fontSizeIncrease"
  | "fontSizeDecrease"
  | "bold"
  | "italic"
  | "underline"
  | "strikethrough"
  | "alignLeft"
  | "alignCenter"
  | "alignRight"
  | "mergeCells"
  | "unmergeCells"
  | "insertRow"
  | "deleteRow"
  | "insertColumn"
  | "deleteColumn"
  | "borderAll"
  | "borderNone"
  | "borderOutside"
  | "borderBottom"
  | "borderThick"
  | "formatGeneral"
  | "formatNumber"
  | "formatCurrency"
  | "formatPercent"
  | "formatDate"
  | "freezeRow"
  | "freezeCol"
  | "alignTop"
  | "alignMiddle"
  | "alignBottom"
  | "freezeBoth"
  | "unfreeze";

interface ButtonDef {
  action: ToolbarAction;
  icon?: string;       // Material Icons ligature name
  label?: string;      // text label (for B/I/U/S)
  title: string;
  className?: string;
}

interface DropdownItemDef {
  action: ToolbarAction;
  label: string;
  icon?: string;
}

export class Toolbar {
  readonly element: HTMLDivElement;
  onAction: ((action: ToolbarAction) => void) | null = null;

  private undoBtn: HTMLButtonElement | null = null;
  private redoBtn: HTMLButtonElement | null = null;

  constructor() {
    this.element = document.createElement("div");
    this.element.className = "vx-toolbar";

    // Undo / Redo
    const undoRedoGroup = this.createGroup([
      { action: "undo", icon: "undo", title: "Undo (Ctrl+Z)" },
      { action: "redo", icon: "redo", title: "Redo (Ctrl+Y)" },
    ]);
    this.undoBtn = undoRedoGroup.querySelector('[data-action="undo"]');
    this.redoBtn = undoRedoGroup.querySelector('[data-action="redo"]');
    // Start disabled
    if (this.undoBtn) this.undoBtn.disabled = true;
    if (this.redoBtn) this.redoBtn.disabled = true;
    this.element.appendChild(undoRedoGroup);

    this.addSeparator();

    // Font size up/down
    this.element.appendChild(this.createGroup([
      {
        action: "fontSizeIncrease",
        label: "A+",
        title: "Increase Font Size",
        className: "vx-tb-font-size-up",
      },
      {
        action: "fontSizeDecrease",
        label: "A-",
        title: "Decrease Font Size",
        className: "vx-tb-font-size-down",
      },
    ]));

    this.addSeparator();

    // Font style: B / I / U / S (styled text, not icons — matches Office 365)
    this.element.appendChild(this.createGroup([
      { action: "bold", label: "B", title: "Bold (Ctrl+B)", className: "vx-tb-bold" },
      { action: "italic", label: "I", title: "Italic (Ctrl+I)", className: "vx-tb-italic" },
      { action: "underline", label: "U", title: "Underline (Ctrl+U)", className: "vx-tb-underline" },
      { action: "strikethrough", label: "S", title: "Strikethrough", className: "vx-tb-strike" },
    ]));

    this.addSeparator();

    // Alignment
    this.element.appendChild(this.createGroup([
      { action: "alignLeft", icon: "format_align_left", title: "Align Left" },
      { action: "alignCenter", icon: "format_align_center", title: "Align Center" },
      { action: "alignRight", icon: "format_align_right", title: "Align Right" },
    ]));

    // Vertical alignment
    this.element.appendChild(this.createGroup([
      { action: "alignTop", icon: "vertical_align_top", title: "Align Top" },
      { action: "alignMiddle", icon: "vertical_align_center", title: "Align Middle" },
      { action: "alignBottom", icon: "vertical_align_bottom", title: "Align Bottom" },
    ]));

    this.addSeparator();

    // Merge
    this.element.appendChild(this.createGroup([
      { action: "mergeCells", icon: "merge_type", title: "Merge Cells" },
      { action: "unmergeCells", icon: "call_split", title: "Unmerge Cells" },
    ]));

    this.addSeparator();

    // Borders dropdown
    this.addDropdown("border_all", "Borders", [
      { action: "borderAll", label: "All Borders", icon: "border_all" },
      { action: "borderOutside", label: "Outside Borders", icon: "border_outer" },
      { action: "borderBottom", label: "Bottom Border", icon: "border_bottom" },
      { action: "borderThick", label: "Thick Outside", icon: "border_style" },
      { action: "borderNone", label: "No Border", icon: "border_clear" },
    ]);

    // Number format dropdown
    this.addDropdown("tag", "Number Format", [
      { action: "formatGeneral", label: "General" },
      { action: "formatNumber", label: "Number (1,000.00)" },
      { action: "formatCurrency", label: "Currency ($1,000.00)" },
      { action: "formatPercent", label: "Percent (10.00%)" },
      { action: "formatDate", label: "Date (MM/DD/YYYY)" },
    ]);

    this.addSeparator();

    // Freeze panes dropdown
    this.addDropdown("ac_unit", "Freeze Panes", [
      { action: "freezeRow", label: "Freeze Top Row" },
      { action: "freezeCol", label: "Freeze First Column" },
      { action: "freezeBoth", label: "Freeze Both" },
      { action: "unfreeze", label: "Unfreeze All" },
    ]);
  }

  /** Update undo/redo button disabled state. */
  updateUndoRedoState(canUndo: boolean, canRedo: boolean): void {
    if (this.undoBtn) this.undoBtn.disabled = !canUndo;
    if (this.redoBtn) this.redoBtn.disabled = !canRedo;
  }

  private createGroup(buttons: ButtonDef[]): HTMLDivElement {
    const group = document.createElement("div");
    group.className = "vx-tb-group";

    for (const btn of buttons) {
      const el = document.createElement("button");
      el.type = "button";
      el.className = "vx-tb-btn" + (btn.className ? ` ${btn.className}` : "");
      el.title = btn.title;
      el.dataset.action = btn.action;

      if (btn.icon) {
        el.appendChild(iconEl(btn.icon, 18));
      } else if (btn.label) {
        el.textContent = btn.label;
      }

      el.addEventListener("click", (e) => {
        e.preventDefault();
        if (this.onAction) this.onAction(btn.action);
      });
      group.appendChild(el);
    }

    return group;
  }

  private addDropdown(
    iconName: string,
    title: string,
    items: DropdownItemDef[],
  ): void {
    const wrapper = document.createElement("div");
    wrapper.className = "vx-tb-dropdown";

    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "vx-tb-btn vx-tb-dropdown-btn";
    btn.title = title;
    btn.appendChild(iconEl(iconName, 18));

    // Dropdown arrow
    const arrow = document.createElement("span");
    arrow.className = "vx-tb-dropdown-arrow";
    arrow.textContent = "\u25BC";
    btn.appendChild(arrow);

    const menu = document.createElement("div");
    menu.className = "vx-tb-dropdown-menu";
    menu.style.display = "none";

    for (const item of items) {
      const el = document.createElement("div");
      el.className = "vx-tb-dropdown-item";

      if (item.icon) {
        el.appendChild(iconEl(item.icon, 16));
      }

      const label = document.createElement("span");
      label.textContent = item.label;
      el.appendChild(label);

      el.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        menu.style.display = "none";
        if (this.onAction) this.onAction(item.action);
      });
      menu.appendChild(el);
    }

    btn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      const isOpen = menu.style.display !== "none";
      menu.style.display = isOpen ? "none" : "block";
      if (!isOpen) {
        const dismiss = (ev: Event) => {
          if (!wrapper.contains(ev.target as Node)) {
            menu.style.display = "none";
            document.removeEventListener("pointerdown", dismiss);
          }
        };
        setTimeout(() => document.addEventListener("pointerdown", dismiss), 0);
      }
    });

    wrapper.appendChild(btn);
    wrapper.appendChild(menu);
    this.element.appendChild(wrapper);
  }

  private addSeparator(): void {
    const sep = document.createElement("div");
    sep.className = "vx-tb-sep";
    this.element.appendChild(sep);
  }

  destroy(): void {
    this.element.remove();
  }
}
