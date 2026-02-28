/**
 * Right-click context menu — Office 365 style.
 *
 * Features: Material Icons icons, keyboard shortcut hints, separator lines.
 */

import { iconEl } from "./icons.js";

export type ContextMenuAction =
  | "cut"
  | "copy"
  | "paste"
  | "insertRowAbove"
  | "insertRowBelow"
  | "deleteRow"
  | "insertColumnLeft"
  | "insertColumnRight"
  | "deleteColumn"
  | "clearCell"
  | "mergeCells"
  | "unmergeCells";

export type ContextMenuScope = "cell" | "rowHeader" | "colHeader" | "corner" | "outside";

interface MenuItem {
  label: string;
  action: ContextMenuAction;
  separator?: boolean;
  icon?: string;
  shortcut?: string;
}

const CELL_MENU_ITEMS: MenuItem[] = [
  { label: "Cut", action: "cut", icon: "content_cut", shortcut: "Ctrl+X" },
  { label: "Copy", action: "copy", icon: "content_copy", shortcut: "Ctrl+C" },
  { label: "Paste", action: "paste", icon: "content_paste", shortcut: "Ctrl+V" },
  { label: "Clear Contents", action: "clearCell", icon: "delete", shortcut: "Delete", separator: true },
  { label: "Insert Row Above", action: "insertRowAbove", icon: "table_rows" },
  { label: "Insert Row Below", action: "insertRowBelow", icon: "table_rows" },
  { label: "Delete Row", action: "deleteRow", icon: "remove", separator: true },
  { label: "Insert Column Left", action: "insertColumnLeft", icon: "view_column" },
  { label: "Insert Column Right", action: "insertColumnRight", icon: "view_column" },
  { label: "Delete Column", action: "deleteColumn", icon: "remove", separator: true },
  { label: "Merge Cells", action: "mergeCells", icon: "merge_type" },
  { label: "Unmerge Cells", action: "unmergeCells", icon: "call_split" },
];

const ROW_HEADER_MENU_ITEMS: MenuItem[] = [
  { label: "Insert Row Above", action: "insertRowAbove", icon: "table_rows" },
  { label: "Insert Row Below", action: "insertRowBelow", icon: "table_rows" },
  { label: "Delete Row", action: "deleteRow", icon: "remove", separator: true },
  { label: "Clear Contents", action: "clearCell", icon: "delete" },
];

const COL_HEADER_MENU_ITEMS: MenuItem[] = [
  { label: "Insert Column Left", action: "insertColumnLeft", icon: "view_column" },
  { label: "Insert Column Right", action: "insertColumnRight", icon: "view_column" },
  { label: "Delete Column", action: "deleteColumn", icon: "remove", separator: true },
  { label: "Clear Contents", action: "clearCell", icon: "delete" },
];

const CORNER_MENU_ITEMS: MenuItem[] = [
  { label: "Copy", action: "copy", icon: "content_copy", shortcut: "Ctrl+C" },
  { label: "Paste", action: "paste", icon: "content_paste", shortcut: "Ctrl+V" },
  { label: "Clear Contents", action: "clearCell", icon: "delete" },
];

function menuItemsForScope(scope: ContextMenuScope): MenuItem[] {
  if (scope === "rowHeader") return ROW_HEADER_MENU_ITEMS;
  if (scope === "colHeader") return COL_HEADER_MENU_ITEMS;
  if (scope === "corner") return CORNER_MENU_ITEMS;
  if (scope === "outside") return [];
  return CELL_MENU_ITEMS;
}

export class ContextMenu {
  private menuEl: HTMLDivElement | null = null;
  private dismissHandler: ((e: Event) => void) | null = null;
  onAction: ((action: ContextMenuAction) => void) | null = null;

  /** Show context menu at (x, y) screen position. */
  show(x: number, y: number, scope: ContextMenuScope = "cell"): void {
    this.hide();
    const items = menuItemsForScope(scope);
    if (items.length === 0) return;

    const menu = document.createElement("div");
    menu.className = "vx-context-menu";
    menu.style.left = `${x}px`;
    menu.style.top = `${y}px`;

    for (const item of items) {
      if (item.separator) {
        const sep = document.createElement("div");
        sep.className = "vx-cm-sep";
        menu.appendChild(sep);
      }

      const el = document.createElement("div");
      el.className = "vx-cm-item";

      // Icon
      const iconWrap = document.createElement("span");
      iconWrap.className = "vx-cm-icon";
      if (item.icon) {
        iconWrap.appendChild(iconEl(item.icon, 16));
      }
      el.appendChild(iconWrap);

      // Label
      const labelSpan = document.createElement("span");
      labelSpan.className = "vx-cm-label";
      labelSpan.textContent = item.label;
      el.appendChild(labelSpan);

      // Keyboard shortcut
      if (item.shortcut) {
        const shortcutSpan = document.createElement("span");
        shortcutSpan.className = "vx-cm-shortcut";
        shortcutSpan.textContent = item.shortcut;
        el.appendChild(shortcutSpan);
      }

      el.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.hide();
        if (this.onAction) this.onAction(item.action);
      });
      menu.appendChild(el);
    }

    document.body.appendChild(menu);
    this.menuEl = menu;

    // Clamp to viewport
    const rect = menu.getBoundingClientRect();
    if (rect.right > window.innerWidth) {
      menu.style.left = `${window.innerWidth - rect.width - 4}px`;
    }
    if (rect.bottom > window.innerHeight) {
      menu.style.top = `${window.innerHeight - rect.height - 4}px`;
    }

    // Dismiss on click outside or Escape
    this.dismissHandler = (e: Event) => {
      if (e instanceof KeyboardEvent && e.key === "Escape") {
        this.hide();
        return;
      }
      if (e instanceof MouseEvent && !menu.contains(e.target as Node)) {
        this.hide();
      }
    };
    setTimeout(() => {
      document.addEventListener("mousedown", this.dismissHandler!);
      document.addEventListener("keydown", this.dismissHandler!);
    }, 0);
  }

  /** Hide context menu if visible. */
  hide(): void {
    if (this.menuEl) {
      this.menuEl.remove();
      this.menuEl = null;
    }
    if (this.dismissHandler) {
      document.removeEventListener("mousedown", this.dismissHandler);
      document.removeEventListener("keydown", this.dismissHandler);
      this.dismissHandler = null;
    }
  }

  get isVisible(): boolean {
    return this.menuEl != null;
  }

  destroy(): void {
    this.hide();
  }
}
