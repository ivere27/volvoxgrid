import type { VolvoxGrid } from "volvoxgrid";
import type { AgThemeName } from "./types.js";

export interface PaddingPreset {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface ThemePreset {
  themeClass: AgThemeName;
  containerStyle: Partial<CSSStyleDeclaration>;
  canvasStyle: Partial<CSSStyleDeclaration>;
  fontName: string;
  fontSize: number;
  rowHeight: number;
  headerHeight: number;
  gridLines: number;
  cellPadding: PaddingPreset;
  fixedCellPadding: PaddingPreset;
}

const GRIDLINE_SOLID_HORIZONTAL = 4;

const DEFAULT_THEME: ThemePreset = {
  themeClass: "ag-theme-alpine",
  containerStyle: {
    backgroundColor: "#ffffff",
    color: "#181d1f",
    border: "1px solid #babfc7",
  },
  canvasStyle: {
    backgroundColor: "#ffffff",
  },
  fontName: "",
  // AG Alpine rows use --ag-font-size (13px) + 1px for cells.
  fontSize: 14,
  rowHeight: 42,
  headerHeight: 48,
  gridLines: GRIDLINE_SOLID_HORIZONTAL,
  // AG Alpine defaults: header 18px horizontal, body 17px (18px - 1px border).
  cellPadding: { left: 17, top: 0, right: 17, bottom: 0 },
  fixedCellPadding: { left: 18, top: 0, right: 18, bottom: 0 },
};

const THEMES: Record<AgThemeName, ThemePreset> = {
  "ag-theme-alpine": DEFAULT_THEME,
  "ag-theme-balham": {
    themeClass: "ag-theme-balham",
    containerStyle: {
      backgroundColor: "#ffffff",
      color: "#252a2e",
      border: "1px solid #b8bec9",
    },
    canvasStyle: {
      backgroundColor: "#ffffff",
    },
    fontName: "",
    fontSize: 12,
    rowHeight: 28,
    headerHeight: 32,
    gridLines: GRIDLINE_SOLID_HORIZONTAL,
    // Balham: --ag-cell-horizontal-padding = 12px.
    // Body effectively renders at 11px due internal border handling.
    cellPadding: { left: 11, top: 0, right: 11, bottom: 0 },
    fixedCellPadding: { left: 12, top: 0, right: 12, bottom: 0 },
  },
  "ag-theme-material": {
    themeClass: "ag-theme-material",
    containerStyle: {
      backgroundColor: "#fafafa",
      color: "#212121",
      border: "1px solid #d0d0d0",
    },
    canvasStyle: {
      backgroundColor: "#fafafa",
    },
    fontName: "",
    fontSize: 12,
    rowHeight: 48,
    headerHeight: 56,
    gridLines: GRIDLINE_SOLID_HORIZONTAL,
    // Material: --ag-cell-horizontal-padding = 24px.
    // Body effectively renders at 23px due internal border handling.
    cellPadding: { left: 23, top: 0, right: 23, bottom: 0 },
    fixedCellPadding: { left: 24, top: 0, right: 24, bottom: 0 },
  },
};

const THEME_CLASSES: AgThemeName[] = [
  "ag-theme-alpine",
  "ag-theme-balham",
  "ag-theme-material",
];

function applyStyle(target: HTMLElement, style: Partial<CSSStyleDeclaration>): void {
  for (const [key, value] of Object.entries(style)) {
    if (value != null) {
      (target.style as any)[key] = String(value);
    }
  }
}

function parsePx(value: string): number | undefined {
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return undefined;
  }
  const parsed = Number.parseFloat(trimmed);
  if (!Number.isFinite(parsed)) {
    return undefined;
  }
  return parsed;
}

function readCssVarPaddingPx(container: HTMLElement, varName: string): number | undefined {
  const probe = document.createElement("div");
  probe.style.position = "absolute";
  probe.style.visibility = "hidden";
  probe.style.pointerEvents = "none";
  probe.style.paddingLeft = `var(${varName})`;
  probe.style.paddingRight = `var(${varName})`;
  probe.style.border = "0";
  probe.style.margin = "0";
  probe.style.width = "0";
  probe.style.height = "0";
  container.appendChild(probe);
  const computed = getComputedStyle(probe);
  const left = parsePx(computed.paddingLeft);
  container.removeChild(probe);
  return left;
}

function resolveRuntimePadding(container: HTMLElement, fallback: ThemePreset): ThemePreset {
  const cellHorizontal = readCssVarPaddingPx(container, "--ag-cell-horizontal-padding");
  if (typeof cellHorizontal !== "number") {
    return fallback;
  }
  const fixedHorizontal = Math.max(0, Math.round(cellHorizontal));
  const bodyHorizontal = Math.max(0, fixedHorizontal - 1);
  return {
    ...fallback,
    cellPadding: { left: bodyHorizontal, top: 0, right: bodyHorizontal, bottom: 0 },
    fixedCellPadding: { left: fixedHorizontal, top: 0, right: fixedHorizontal, bottom: 0 },
  };
}

export function resolveTheme(theme?: AgThemeName): ThemePreset {
  if (theme != null && theme in THEMES) {
    return THEMES[theme];
  }
  return DEFAULT_THEME;
}

export function applyTheme(
  grid: VolvoxGrid,
  container: HTMLElement,
  canvas: HTMLCanvasElement,
  theme?: AgThemeName,
  fontSizeOverride?: number,
): ThemePreset {
  const preset = resolveTheme(theme);
  for (const cls of THEME_CLASSES) {
    container.classList.remove(cls);
  }
  container.classList.add(preset.themeClass);
  applyStyle(container, preset.containerStyle);
  applyStyle(canvas, preset.canvasStyle);

  const fontSize =
    typeof fontSizeOverride === "number" && fontSizeOverride > 0
      ? Math.round(fontSizeOverride)
      : preset.fontSize;

  if (preset.fontName.trim().length > 0 && typeof grid.setFontName === "function") {
    grid.setFontName(preset.fontName);
  }
  if (typeof grid.setFontSize === "function") {
    grid.setFontSize(fontSize);
  }
  grid.setGridLines(preset.gridLines);

  return resolveRuntimePadding(container, preset);
}
