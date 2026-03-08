/**
 * <volvox-sheet> custom element.
 *
 * Attributes:
 *   rows      - number of data rows (default 100)
 *   cols      - number of data columns (default 26)
 *   wasm-url  - URL of the WASM module (default "./wasm/volvoxgrid_wasm.js")
 */

import { VolvoxSheet } from "./volvox-sheet.js";
import type { VolvoxSheetApi } from "./types.js";

class VolvoxSheetElement extends HTMLElement {
  private _sheet?: VolvoxSheet;
  private shadow: ShadowRoot;

  static get observedAttributes(): string[] {
    return ["rows", "cols"];
  }

  constructor() {
    super();
    this.shadow = this.attachShadow({ mode: "open" });
  }

  connectedCallback(): void {
    const style = document.createElement("style");
    style.textContent = `
      :host {
        display: block;
        width: 100%;
        height: 400px;
        overflow: hidden;
      }
      .vx-host {
        width: 100%;
        height: 100%;
      }
    `;

    const host = document.createElement("div");
    host.className = "vx-host";

    this.shadow.appendChild(style);
    this.shadow.appendChild(host);

    this.initWasm(host);
  }

  disconnectedCallback(): void {
    if (this._sheet) {
      this._sheet.destroy();
      this._sheet = undefined;
    }
  }

  get sheet(): VolvoxSheetApi | undefined {
    return this._sheet;
  }

  private async initWasm(host: HTMLElement): Promise<void> {
    const wasmUrl = this.getAttribute("wasm-url") || "./wasm/volvoxgrid_wasm.js";
    const rows = parseInt(this.getAttribute("rows") || "100", 10);
    const cols = parseInt(this.getAttribute("cols") || "26", 10);

    try {
      const wasmModule = await import(/* @vite-ignore */ wasmUrl);
      await wasmModule.default();

      this._sheet = new VolvoxSheet({
        container: host,
        wasm: wasmModule,
        rows,
        cols,
      });

      this.dispatchEvent(
        new CustomEvent("volvox-sheet-ready", {
          detail: { sheet: this._sheet },
          bubbles: true,
        }),
      );
    } catch (err) {
      console.error("Failed to initialise VolvoxSheet WASM module:", err);
    }
  }
}

customElements.define("volvox-sheet", VolvoxSheetElement);

export { VolvoxSheetElement };
