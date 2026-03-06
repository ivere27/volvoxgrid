import { VolvoxGrid } from "./volvoxgrid.js";

/**
 * <volvox-grid> custom element.
 *
 * Attributes:
 *   rows        - total row count (default 10)
 *   cols        - total column count (default 5)
 *   frozen-rows - number of frozen data rows (default 0)
 *   frozen-cols - number of frozen data columns (default 0)
 *   show-column-headers - whether the top column indicator is visible (default true)
 *   show-indicator - whether the start row indicator is visible (default false)
 *   wasm-url    - URL of the WASM module (default "./wasm/volvoxgrid_wasm.js")
 *
 * The element creates a full-size <canvas> in its shadow DOM and initialises
 * a VolvoxGrid instance once the WASM module has loaded.
 */
class VolvoxGridElement extends HTMLElement {
  private volvoxgrid?: VolvoxGrid;
  private canvas?: HTMLCanvasElement;
  private shadow: ShadowRoot;

  static get observedAttributes(): string[] {
    return ["rows", "cols", "frozen-rows", "frozen-cols", "show-column-headers", "show-indicator"];
  }

  constructor() {
    super();
    this.shadow = this.attachShadow({ mode: "open" });
  }

  connectedCallback(): void {
    // Build shadow DOM
    const style = document.createElement("style");
    style.textContent = `
      :host {
        display: block;
        width: 100%;
        height: 300px;
        overflow: hidden;
      }
      canvas {
        display: block;
        width: 100%;
        height: 100%;
        outline: none;
      }
    `;

    this.canvas = document.createElement("canvas");
    this.shadow.appendChild(style);
    this.shadow.appendChild(this.canvas);

    // Load WASM and create the grid
    this.initWasm();
  }

  disconnectedCallback(): void {
    if (this.volvoxgrid) {
      this.volvoxgrid.destroy();
      this.volvoxgrid = undefined;
    }
  }

  attributeChangedCallback(
    name: string,
    _old: string | null,
    value: string | null,
  ): void {
    if (!this.volvoxgrid || value === null) return;

    switch (name) {
      case "rows": {
        const n = parseInt(value, 10);
        if (isNaN(n)) return;
        this.volvoxgrid.rows = n;
        break;
      }
      case "cols": {
        const n = parseInt(value, 10);
        if (isNaN(n)) return;
        this.volvoxgrid.cols = n;
        break;
      }
      case "frozen-rows": {
        const n = parseInt(value, 10);
        if (isNaN(n)) return;
        this.volvoxgrid.frozenRows = n;
        break;
      }
      case "frozen-cols": {
        const n = parseInt(value, 10);
        if (isNaN(n)) return;
        this.volvoxgrid.frozenCols = n;
        break;
      }
      case "show-column-headers":
        this.volvoxgrid.showColumnHeaders = value !== "false" && value !== "0";
        break;
      case "show-indicator":
        this.volvoxgrid.showIndicator = value !== "false" && value !== "0";
        break;
    }
  }

  /** The underlying VolvoxGrid instance (available after WASM loads). */
  get grid(): VolvoxGrid | undefined {
    return this.volvoxgrid;
  }

  private async initWasm(): Promise<void> {
    const wasmUrl =
      this.getAttribute("wasm-url") || "./wasm/volvoxgrid_wasm.js";
    console.log("VolvoxGridElement: initWasm from:", wasmUrl);

    try {
      const wasmModule = await import(/* @vite-ignore */ wasmUrl);
      console.log("VolvoxGridElement: WASM module imported");
      await wasmModule.default();
      console.log("VolvoxGridElement: WASM default function called");

      if (!this.canvas) {
        console.warn("VolvoxGridElement: No canvas element found");
        return;
      }

      const rows = parseInt(this.getAttribute("rows") || "10", 10);
      const cols = parseInt(this.getAttribute("cols") || "5", 10);
      const frozenRows = parseInt(this.getAttribute("frozen-rows") || "0", 10);
      const frozenCols = parseInt(this.getAttribute("frozen-cols") || "0", 10);
      const showColumnHeaders =
        (this.getAttribute("show-column-headers") || "true") !== "false"
        && this.getAttribute("show-column-headers") !== "0";
      const showIndicator =
        (this.getAttribute("show-indicator") || "false") !== "false"
        && this.getAttribute("show-indicator") !== "0";

      this.volvoxgrid = new VolvoxGrid(this.canvas, wasmModule, rows, cols);
      this.volvoxgrid.frozenRows = frozenRows;
      this.volvoxgrid.frozenCols = frozenCols;
      this.volvoxgrid.showColumnHeaders = showColumnHeaders;
      this.volvoxgrid.showIndicator = showIndicator;

      console.log("VolvoxGridElement: Grid instance created, dispatching ready event");
      // Dispatch a ready event so consumers know the grid is usable
      this.dispatchEvent(
        new CustomEvent("volvoxgrid-ready", {
          detail: { grid: this.volvoxgrid },
          bubbles: true,
        }),
      );
    } catch (err) {
      console.error("Failed to initialise VolvoxGrid WASM module:", err);
    }
  }
}

customElements.define("volvox-grid", VolvoxGridElement);

export { VolvoxGridElement };
