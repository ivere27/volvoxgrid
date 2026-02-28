/**
 * Sheet tabs — Office 365 style.
 *
 * Nav arrows | scrollable tab container | + button
 * Inline rename via contentEditable (no prompt()).
 *
 * VolvoxGrid engine has no native multi-sheet, so the adapter
 * saves/restores data snapshots per sheet.
 */

import { iconEl } from "./icons.js";

export interface SheetSnapshot {
  name: string;
  data: string[][];
  selection: { row: number; col: number };
}

export class SheetTabs {
  readonly element: HTMLDivElement;
  private sheets: SheetSnapshot[] = [];
  private activeIndex = 0;
  private navLeft: HTMLButtonElement;
  private navRight: HTMLButtonElement;
  private tabContainer: HTMLDivElement;
  private addBtn: HTMLButtonElement;
  private renaming = false;

  /** Called when user switches to a different sheet. */
  onSwitch: ((fromIndex: number, toIndex: number) => void) | null = null;
  /** Called to get the current sheet's data for snapshotting. */
  onSave: (() => SheetSnapshot) | null = null;
  /** Called to load a sheet's data after switch. */
  onLoad: ((snapshot: SheetSnapshot) => void) | null = null;

  constructor() {
    this.element = document.createElement("div");
    this.element.className = "vx-sheet-tabs";

    // Nav arrows
    const nav = document.createElement("div");
    nav.className = "vx-tab-nav";

    this.navLeft = document.createElement("button");
    this.navLeft.type = "button";
    this.navLeft.className = "vx-tab-nav-btn";
    this.navLeft.title = "Scroll tabs left";
    this.navLeft.appendChild(iconEl("chevron_left", 16));
    this.navLeft.addEventListener("click", () => this.scrollTabs(-100));

    this.navRight = document.createElement("button");
    this.navRight.type = "button";
    this.navRight.className = "vx-tab-nav-btn";
    this.navRight.title = "Scroll tabs right";
    this.navRight.appendChild(iconEl("chevron_right", 16));
    this.navRight.addEventListener("click", () => this.scrollTabs(100));

    nav.appendChild(this.navLeft);
    nav.appendChild(this.navRight);

    // Tab container (scrollable)
    this.tabContainer = document.createElement("div");
    this.tabContainer.className = "vx-tab-container";

    // Add sheet button
    this.addBtn = document.createElement("button");
    this.addBtn.type = "button";
    this.addBtn.className = "vx-tab-add";
    this.addBtn.title = "Add Sheet";
    this.addBtn.appendChild(iconEl("add", 16));
    this.addBtn.addEventListener("click", () => this.addSheet());

    // Assemble
    this.element.appendChild(nav);
    this.element.appendChild(this.tabContainer);
    this.element.appendChild(this.addBtn);

    this.sheets.push({ name: "Sheet1", data: [], selection: { row: 0, col: 0 } });
    this.renderTabs();
  }

  get activeSheet(): SheetSnapshot { return this.sheets[this.activeIndex]; }
  get sheetCount(): number { return this.sheets.length; }

  private scrollTabs(delta: number): void {
    this.tabContainer.scrollBy({ left: delta, behavior: "smooth" });
  }

  private renderTabs(): void {
    if (this.renaming) return;
    this.tabContainer.innerHTML = "";

    for (let i = 0; i < this.sheets.length; i++) {
      const tab = document.createElement("div");
      tab.className = "vx-tab" + (i === this.activeIndex ? " vx-tab-active" : "");
      tab.textContent = this.sheets[i].name;
      tab.addEventListener("click", () => this.switchTo(i));
      tab.addEventListener("dblclick", (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.startRename(i, tab);
      });
      tab.addEventListener("contextmenu", (e) => {
        e.preventDefault();
        this.showTabMenu(e.clientX, e.clientY, i);
      });
      this.tabContainer.appendChild(tab);
    }
  }

  switchTo(index: number): void {
    if (index === this.activeIndex || index < 0 || index >= this.sheets.length) return;
    if (this.renaming) return;

    // Save current sheet
    if (this.onSave) {
      this.sheets[this.activeIndex] = this.onSave();
    }

    const from = this.activeIndex;
    this.activeIndex = index;
    this.renderTabs();

    // Load new sheet
    if (this.onLoad) {
      this.onLoad(this.sheets[index]);
    }

    if (this.onSwitch) this.onSwitch(from, index);
  }

  addSheet(): void {
    // Save current sheet
    if (this.onSave) {
      this.sheets[this.activeIndex] = this.onSave();
    }

    const name = `Sheet${this.sheets.length + 1}`;
    const snapshot: SheetSnapshot = { name, data: [], selection: { row: 0, col: 0 } };
    this.sheets.push(snapshot);
    this.activeIndex = this.sheets.length - 1;
    this.renderTabs();

    if (this.onLoad) this.onLoad(snapshot);
  }

  /** Inline rename via contentEditable (no prompt). */
  private startRename(index: number, tabEl: HTMLElement): void {
    this.renaming = true;

    tabEl.contentEditable = "true";
    tabEl.focus();

    // Select all text
    const range = document.createRange();
    range.selectNodeContents(tabEl);
    const sel = window.getSelection();
    if (sel) {
      sel.removeAllRanges();
      sel.addRange(range);
    }

    const commit = () => {
      if (!this.renaming) return;
      this.renaming = false;
      tabEl.contentEditable = "false";
      const newName = tabEl.textContent?.trim();
      if (newName) {
        this.sheets[index].name = newName;
      }
      this.renderTabs();
    };

    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Enter") {
        e.preventDefault();
        tabEl.blur();
      }
      if (e.key === "Escape") {
        e.preventDefault();
        tabEl.textContent = this.sheets[index].name;
        this.renaming = false;
        tabEl.contentEditable = "false";
        tabEl.removeEventListener("keydown", onKeyDown);
        this.renderTabs();
      }
    };

    tabEl.addEventListener("keydown", onKeyDown);
    tabEl.addEventListener("blur", () => {
      tabEl.removeEventListener("keydown", onKeyDown);
      commit();
    }, { once: true });
  }

  private showTabMenu(x: number, y: number, index: number): void {
    const menu = document.createElement("div");
    menu.className = "vx-context-menu";
    menu.style.left = `${x}px`;
    menu.style.top = `${y}px`;

    const items = [
      { label: "Rename", action: () => {
        const tabs = this.tabContainer.querySelectorAll(".vx-tab");
        const tab = tabs[index] as HTMLElement;
        if (tab) this.startRename(index, tab);
      }},
      { label: "Duplicate", action: () => this.duplicateSheet(index) },
      { label: "Insert", action: () => this.addSheet() },
    ];

    if (this.sheets.length > 1) {
      items.push({ label: "Delete", action: () => this.deleteSheet(index) });
    }

    for (const item of items) {
      const el = document.createElement("div");
      el.className = "vx-cm-item";
      el.textContent = item.label;
      el.addEventListener("click", () => {
        menu.remove();
        item.action();
      });
      menu.appendChild(el);
    }

    document.body.appendChild(menu);

    // Clamp to viewport
    const rect = menu.getBoundingClientRect();
    if (rect.right > window.innerWidth) {
      menu.style.left = `${window.innerWidth - rect.width - 4}px`;
    }
    if (rect.bottom > window.innerHeight) {
      menu.style.top = `${window.innerHeight - rect.height - 4}px`;
    }

    const dismiss = (e: Event) => {
      if (!menu.contains(e.target as Node)) {
        menu.remove();
        document.removeEventListener("pointerdown", dismiss);
      }
    };
    setTimeout(() => document.addEventListener("pointerdown", dismiss), 0);
  }

  private duplicateSheet(index: number): void {
    if (this.onSave && index === this.activeIndex) {
      this.sheets[index] = this.onSave();
    }
    const src = this.sheets[index];
    const copy: SheetSnapshot = {
      name: `${src.name} (Copy)`,
      data: src.data.map(r => [...r]),
      selection: { ...src.selection },
    };
    this.sheets.splice(index + 1, 0, copy);
    this.switchTo(index + 1);
  }

  private deleteSheet(index: number): void {
    if (this.sheets.length <= 1) return;
    this.sheets.splice(index, 1);
    if (this.activeIndex >= this.sheets.length) {
      this.activeIndex = this.sheets.length - 1;
    } else if (this.activeIndex > index) {
      this.activeIndex--;
    }
    this.renderTabs();
    if (this.onLoad) this.onLoad(this.sheets[this.activeIndex]);
  }

  destroy(): void {
    this.element.remove();
  }
}
