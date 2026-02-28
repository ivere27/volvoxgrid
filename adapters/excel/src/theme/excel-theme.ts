/**
 * Excel/Sheets-like visual configuration for VolvoxGrid.
 */

import type { ExcelGridConfig } from "../proto/config-encoder.js";

// ── Proto enum values ──────────────────────────────────────
// From volvoxgrid.proto

const GRIDLINE_SOLID = 1;
const FOCUS_BORDER_THICK = 2;
const SELECTION_FREE = 0;
const EDIT_TRIGGER_KEY_CLICK = 2; // Engine allows editing; host_key_dispatch controls keyboard triggers
const TAB_CELLS = 1;
const RESIZE_BOTH = 3;
const CELL_SPAN_FREE = 1;
const ALIGN_CENTER_CENTER = 4;
const ALIGN_LEFT_CENTER = 1;

// ── Colors (ARGB uint32) ──────────────────────────────────

export const EXCEL_COLORS = {
  white:          0xffffffff,
  black:          0xff000000,
  headerBg:       0xfff5f5f5,  // Light gray for headers (Office 365)
  headerFg:       0xff323130,  // Fluent UI primary text
  gridLine:       0xffe0e0e0,  // Lighter gridlines
  gridLineFixed:  0xffc8c8c8,  // Slightly darker for header grid lines
  selectionBg:    0x15217346,  // Very light green fill (Office 365)
  selectionFg:    0xff000000,  // Black text on selection
  sheetBorder:    0xffd6d6d6,
} as const;

/** Build the GridConfig for a spreadsheet-like appearance. */
export function buildExcelConfig(opts?: {
  rows?: number;
  cols?: number;
  fontName?: string;
  fontSize?: number;
  defaultRowHeight?: number;
  defaultColWidth?: number;
}): ExcelGridConfig {
  const resolvedFontSize =
    typeof opts?.fontSize === "number" && Number.isFinite(opts.fontSize) && opts.fontSize > 0
      ? opts.fontSize
      : 11;
  return {
    // Layout
    rows: opts?.rows ?? 101,         // 1 header + 100 data rows
    cols: opts?.cols ?? 27,          // 1 row-number col + 26 data cols
    fixedRows: 1,
    fixedCols: 1,
    defaultRowHeight: opts?.defaultRowHeight ?? 21,
    defaultColWidth: opts?.defaultColWidth ?? 64,
    textOverflow: true,

    // Style
    backColor: EXCEL_COLORS.white,
    foreColor: EXCEL_COLORS.black,
    backColorFixed: EXCEL_COLORS.headerBg,
    foreColorFixed: EXCEL_COLORS.headerFg,
    gridLines: GRIDLINE_SOLID,
    gridLinesFixed: GRIDLINE_SOLID,
    gridColor: EXCEL_COLORS.gridLine,
    gridColorFixed: EXCEL_COLORS.gridLineFixed,
    gridLineWidth: 1,
    fontName: opts?.fontName ?? "Calibri",
    fontSize: resolvedFontSize,
    fontBold: false,
    backColorSel: EXCEL_COLORS.selectionBg,
    foreColorSel: EXCEL_COLORS.selectionFg,

    // Selection
    selectionMode: SELECTION_FREE,
    focusBorder: FOCUS_BORDER_THICK,
    showFillHandle: true,

    // Editing: host_key_dispatch = true so we control key→edit mapping
    editTrigger: EDIT_TRIGGER_KEY_CLICK,
    tabBehavior: TAB_CELLS,
    hostKeyDispatch: true,

    // Interaction
    allowUserResizing: RESIZE_BOTH,
    autoResize: false,

    // Span
    // Disable auto-span — Excel does not auto-span adjacent identical cells
    cellSpan: 0,
    cellSpanFixed: 0,
  };
}

/** Alignment constants for the public API. */
export const ALIGN = {
  LEFT_TOP: 0,
  LEFT_CENTER: ALIGN_LEFT_CENTER,
  LEFT_BOTTOM: 2,
  CENTER_TOP: 3,
  CENTER_CENTER: ALIGN_CENTER_CENTER,
  CENTER_BOTTOM: 5,
  RIGHT_TOP: 6,
  RIGHT_CENTER: 7,
  RIGHT_BOTTOM: 8,
} as const;
