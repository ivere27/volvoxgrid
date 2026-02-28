/**
 * Find & Replace bar: Ctrl+F find, Ctrl+H find+replace.
 */

import type { DataStore } from "../core/data-store.js";
import type { CellRef } from "../types.js";
import { iconEl } from "./icons.js";

export class FindReplaceBar {
  readonly element: HTMLDivElement;
  private findInput: HTMLInputElement;
  private replaceInput: HTMLInputElement;
  private replaceRow: HTMLDivElement;
  private countLabel: HTMLSpanElement;
  private store: DataStore;

  private results: CellRef[] = [];
  private currentIndex = -1;
  private replaceMode = false;

  /** Navigate to a found cell. */
  onNavigate: ((row: number, col: number) => void) | null = null;
  /** Replace cell value. */
  onReplace: ((row: number, col: number, oldText: string, newText: string) => void) | null = null;
  /** Replace all (batch). */
  onReplaceAll: ((replacements: Array<{ row: number; col: number; oldText: string; newText: string }>) => void) | null = null;

  constructor(store: DataStore) {
    this.store = store;

    this.element = document.createElement("div");
    this.element.className = "vx-find-bar";
    this.element.style.display = "none";

    // Find row
    const findRow = document.createElement("div");
    findRow.className = "vx-find-row";

    this.findInput = document.createElement("input");
    this.findInput.className = "vx-find-input";
    this.findInput.type = "text";
    this.findInput.placeholder = "Find";

    const prevBtn = document.createElement("button");
    prevBtn.className = "vx-find-btn";
    prevBtn.appendChild(iconEl("keyboard_arrow_up", 16));
    prevBtn.title = "Previous";
    prevBtn.addEventListener("click", () => this.findPrev());

    const nextBtn = document.createElement("button");
    nextBtn.className = "vx-find-btn";
    nextBtn.appendChild(iconEl("keyboard_arrow_down", 16));
    nextBtn.title = "Next";
    nextBtn.addEventListener("click", () => this.findNext());

    this.countLabel = document.createElement("span");
    this.countLabel.className = "vx-find-count";

    const closeBtn = document.createElement("button");
    closeBtn.className = "vx-find-btn vx-find-close";
    closeBtn.appendChild(iconEl("close", 16));
    closeBtn.title = "Close";
    closeBtn.addEventListener("click", () => this.hide());

    findRow.appendChild(this.findInput);
    findRow.appendChild(prevBtn);
    findRow.appendChild(nextBtn);
    findRow.appendChild(this.countLabel);
    findRow.appendChild(closeBtn);

    // Replace row
    this.replaceRow = document.createElement("div");
    this.replaceRow.className = "vx-find-row";
    this.replaceRow.style.display = "none";

    this.replaceInput = document.createElement("input");
    this.replaceInput.className = "vx-find-input";
    this.replaceInput.type = "text";
    this.replaceInput.placeholder = "Replace";

    const replaceBtn = document.createElement("button");
    replaceBtn.className = "vx-find-btn";
    replaceBtn.textContent = "Replace";
    replaceBtn.addEventListener("click", () => this.replaceCurrent());

    const replaceAllBtn = document.createElement("button");
    replaceAllBtn.className = "vx-find-btn";
    replaceAllBtn.textContent = "Replace All";
    replaceAllBtn.addEventListener("click", () => this.replaceAll());

    this.replaceRow.appendChild(this.replaceInput);
    this.replaceRow.appendChild(replaceBtn);
    this.replaceRow.appendChild(replaceAllBtn);

    this.element.appendChild(findRow);
    this.element.appendChild(this.replaceRow);

    // Events
    this.findInput.addEventListener("input", () => this.doSearch());
    this.findInput.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        if (e.shiftKey) this.findPrev(); else this.findNext();
      }
      if (e.key === "Escape") {
        e.preventDefault();
        this.hide();
      }
    });
    this.replaceInput.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        e.preventDefault();
        this.hide();
      }
    });
  }

  show(withReplace: boolean = false): void {
    this.replaceMode = withReplace;
    this.element.style.display = "block";
    this.replaceRow.style.display = withReplace ? "flex" : "none";
    this.findInput.focus();
    this.findInput.select();
    this.doSearch();
  }

  hide(): void {
    this.element.style.display = "none";
    this.results = [];
    this.currentIndex = -1;
    this.countLabel.textContent = "";
  }

  get isVisible(): boolean {
    return this.element.style.display !== "none";
  }

  private doSearch(): void {
    const query = this.findInput.value;
    if (!query) {
      this.results = [];
      this.currentIndex = -1;
      this.countLabel.textContent = "";
      return;
    }

    this.results = this.findAll(query, false);
    this.currentIndex = this.results.length > 0 ? 0 : -1;
    this.updateCount();
    if (this.currentIndex >= 0) {
      this.navigateToCurrent();
    }
  }

  private findAll(query: string, caseSensitive: boolean): CellRef[] {
    const results: CellRef[] = [];
    const data = this.store.getDisplayData();
    const q = caseSensitive ? query : query.toLowerCase();
    for (let r = 0; r < data.length; r++) {
      for (let c = 0; c < data[r].length; c++) {
        const cell = caseSensitive ? data[r][c] : data[r][c].toLowerCase();
        if (cell.includes(q)) {
          results.push({ row: r, col: c });
        }
      }
    }
    return results;
  }

  findNext(): void {
    if (this.results.length === 0) return;
    this.currentIndex = (this.currentIndex + 1) % this.results.length;
    this.updateCount();
    this.navigateToCurrent();
  }

  findPrev(): void {
    if (this.results.length === 0) return;
    this.currentIndex = (this.currentIndex - 1 + this.results.length) % this.results.length;
    this.updateCount();
    this.navigateToCurrent();
  }

  private navigateToCurrent(): void {
    if (this.currentIndex < 0 || this.currentIndex >= this.results.length) return;
    const ref = this.results[this.currentIndex];
    if (this.onNavigate) this.onNavigate(ref.row, ref.col);
  }

  private updateCount(): void {
    if (this.results.length === 0) {
      this.countLabel.textContent = "0 results";
    } else {
      this.countLabel.textContent = `${this.currentIndex + 1} of ${this.results.length}`;
    }
  }

  private replaceCurrent(): void {
    if (this.currentIndex < 0 || !this.onReplace) return;
    const ref = this.results[this.currentIndex];
    const oldText = this.store.getCellValue(ref.row, ref.col);
    const newText = oldText.replace(this.findInput.value, this.replaceInput.value);
    this.onReplace(ref.row, ref.col, oldText, newText);
    this.doSearch(); // re-search after replacement
  }

  private replaceAll(): void {
    if (this.results.length === 0 || !this.onReplaceAll) return;
    const query = this.findInput.value;
    const replacement = this.replaceInput.value;
    const replacements = this.results.map(ref => {
      const oldText = this.store.getCellValue(ref.row, ref.col);
      const newText = oldText.split(query).join(replacement);
      return { row: ref.row, col: ref.col, oldText, newText };
    });
    this.onReplaceAll(replacements);
    this.doSearch();
  }

  destroy(): void {
    this.element.remove();
  }
}
