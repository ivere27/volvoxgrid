import { VolvoxGrid } from "./volvoxgrid.js";

/**
 * <volvox-grid> custom element.
 *
 * Attributes:
 *   rows        - total row count (default 10)
 *   cols        - total column count (default 5)
 *   fixed-rows  - number of fixed header rows (default 1)
 *   fixed-cols  - number of fixed header columns (default 0)
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
    return ["rows", "cols", "fixed-rows", "fixed-cols"];
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

    const n = parseInt(value, 10);
    if (isNaN(n)) return;

    switch (name) {
      case "rows":
        this.volvoxgrid.rows = n;
        break;
      case "cols":
        this.volvoxgrid.cols = n;
        break;
      case "fixed-rows":
        this.volvoxgrid.fixedRows = n;
        break;
      case "fixed-cols":
        this.volvoxgrid.fixedCols = n;
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
      const fixedRows = parseInt(this.getAttribute("fixed-rows") || "1", 10);
      const fixedCols = parseInt(this.getAttribute("fixed-cols") || "0", 10);

      this.volvoxgrid = new VolvoxGrid(this.canvas, wasmModule, rows, cols);
      this.volvoxgrid.fixedRows = fixedRows;
      this.volvoxgrid.fixedCols = fixedCols;

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
