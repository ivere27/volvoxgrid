/**
 * <volvox-excel> custom element.
 *
 * Attributes:
 *   rows      - number of data rows (default 100)
 *   cols      - number of data columns (default 26)
 *   wasm-url  - URL of the WASM module (default "./wasm/volvoxgrid_wasm.js")
 */

import { VolvoxExcel } from "./volvox-excel.js";
import type { VolvoxExcelApi } from "./types.js";

class VolvoxExcelElement extends HTMLElement {
  private _excel?: VolvoxExcel;
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
    if (this._excel) {
      this._excel.destroy();
      this._excel = undefined;
    }
  }

  get excel(): VolvoxExcelApi | undefined {
    return this._excel;
  }

  private async initWasm(host: HTMLElement): Promise<void> {
    const wasmUrl = this.getAttribute("wasm-url") || "./wasm/volvoxgrid_wasm.js";
    const rows = parseInt(this.getAttribute("rows") || "100", 10);
    const cols = parseInt(this.getAttribute("cols") || "26", 10);

    try {
      const wasmModule = await import(/* @vite-ignore */ wasmUrl);
      await wasmModule.default();

      this._excel = new VolvoxExcel({
        container: host,
        wasm: wasmModule,
        rows,
        cols,
      });

      this.dispatchEvent(
        new CustomEvent("volvox-excel-ready", {
          detail: { excel: this._excel },
          bubbles: true,
        }),
      );
    } catch (err) {
      console.error("Failed to initialise VolvoxExcel WASM module:", err);
    }
  }
}

customElements.define("volvox-excel", VolvoxExcelElement);

export { VolvoxExcelElement };
