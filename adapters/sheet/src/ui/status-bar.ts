/**
 * Status bar — Office 365 style (green background).
 *
 * Left: mode indicator ("Ready" / "Edit" / "Enter")
 * Right: Average / Count / Sum aggregates
 * Far right: zoom slider with +/- buttons
 */

import { iconEl } from "./icons.js";

export interface StatusBarValues {
  sum: number;
  avg: number;
  count: number;
}

export class StatusBar {
  readonly element: HTMLDivElement;
  private modeEl: HTMLSpanElement;
  private sumEl: HTMLSpanElement;
  private avgEl: HTMLSpanElement;
  private countEl: HTMLSpanElement;
  private zoomSlider: HTMLInputElement;
  private zoomLabel: HTMLSpanElement;

  /** Callback when zoom level changes. */
  onZoomChange: ((zoomPercent: number) => void) | null = null;

  constructor() {
    this.element = document.createElement("div");
    this.element.className = "vx-status-bar";

    // Left section: mode indicator
    const left = document.createElement("div");
    left.className = "vx-sb-left";
    this.modeEl = document.createElement("span");
    this.modeEl.className = "vx-sb-mode";
    this.modeEl.textContent = "Ready";
    left.appendChild(this.modeEl);

    // Right section: aggregates
    const right = document.createElement("div");
    right.className = "vx-sb-right";
    this.avgEl = document.createElement("span");
    this.avgEl.className = "vx-sb-item";
    this.countEl = document.createElement("span");
    this.countEl.className = "vx-sb-item";
    this.sumEl = document.createElement("span");
    this.sumEl.className = "vx-sb-item";
    right.appendChild(this.avgEl);
    right.appendChild(this.countEl);
    right.appendChild(this.sumEl);

    // Zoom section
    const zoom = document.createElement("div");
    zoom.className = "vx-sb-zoom";

    const zoomOut = document.createElement("button");
    zoomOut.type = "button";
    zoomOut.className = "vx-sb-zoom-btn";
    zoomOut.title = "Zoom Out";
    zoomOut.appendChild(iconEl("remove", 14));
    zoomOut.addEventListener("click", () => this.adjustZoom(-10));

    this.zoomSlider = document.createElement("input");
    this.zoomSlider.type = "range";
    this.zoomSlider.className = "vx-sb-zoom-slider";
    this.zoomSlider.min = "25";
    this.zoomSlider.max = "400";
    this.zoomSlider.value = "100";
    this.zoomSlider.addEventListener("input", () => {
      const val = parseInt(this.zoomSlider.value, 10);
      this.zoomLabel.textContent = `${val}%`;
      if (this.onZoomChange) this.onZoomChange(val);
    });

    const zoomIn = document.createElement("button");
    zoomIn.type = "button";
    zoomIn.className = "vx-sb-zoom-btn";
    zoomIn.title = "Zoom In";
    zoomIn.appendChild(iconEl("add", 14));
    zoomIn.addEventListener("click", () => this.adjustZoom(10));

    this.zoomLabel = document.createElement("span");
    this.zoomLabel.className = "vx-sb-zoom-label";
    this.zoomLabel.textContent = "100%";

    zoom.appendChild(zoomOut);
    zoom.appendChild(this.zoomSlider);
    zoom.appendChild(zoomIn);
    zoom.appendChild(this.zoomLabel);

    // Assemble
    this.element.appendChild(left);
    this.element.appendChild(right);
    this.element.appendChild(zoom);

    this.clear();
  }

  private adjustZoom(delta: number): void {
    let val = parseInt(this.zoomSlider.value, 10) + delta;
    val = Math.max(25, Math.min(400, val));
    this.zoomSlider.value = String(val);
    this.zoomLabel.textContent = `${val}%`;
    if (this.onZoomChange) this.onZoomChange(val);
  }

  /** Set the mode indicator text. */
  setMode(mode: "Ready" | "Edit" | "Enter" | "Point"): void {
    this.modeEl.textContent = mode;
  }

  /** Set zoom level programmatically. */
  setZoom(percent: number): void {
    const val = Math.max(25, Math.min(400, Math.round(percent)));
    this.zoomSlider.value = String(val);
    this.zoomLabel.textContent = `${val}%`;
  }

  update(values: StatusBarValues): void {
    const fmt = (n: number) =>
      Number.isFinite(n) ? n.toLocaleString(undefined, { maximumFractionDigits: 4 }) : "0";
    this.avgEl.textContent = `Average: ${fmt(values.avg)}`;
    this.countEl.textContent = `Count: ${values.count}`;
    this.sumEl.textContent = `Sum: ${fmt(values.sum)}`;
  }

  clear(): void {
    this.avgEl.textContent = "";
    this.countEl.textContent = "";
    this.sumEl.textContent = "";
  }

  destroy(): void {
    this.element.remove();
  }
}
