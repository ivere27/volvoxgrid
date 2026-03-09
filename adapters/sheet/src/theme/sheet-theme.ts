/**
 * Spreadsheet-like visual configuration for VolvoxGrid.
 */

import type { SheetGridConfig } from "../proto/config-encoder.js";

// ── Proto enum values ──────────────────────────────────────
// From volvoxgrid.proto

const GRIDLINE_SOLID = 1;
const FOCUS_BORDER_THICK = 2;
const SELECTION_MULTI_RANGE = 4;
const FILL_HANDLE_BOTTOM_RIGHT = 1;
const EDIT_TRIGGER_KEY_CLICK = 2; // Engine allows editing; host_key_dispatch controls keyboard triggers
const TAB_CELLS = 1;
const BORDER_NONE = 0;
const BORDER_THICK = 2;
const ALIGN_CENTER_CENTER = 4;
const ALIGN_LEFT_CENTER = 1;

// ── Colors (ARGB uint32) ──────────────────────────────────

export const SHEET_COLORS = {
  white:          0xffffffff,
  black:          0xff000000,
  headerBg:       0xfff3f2f1,  // Fluent neutral gray (Excel 365 ribbon bg)
  headerCornerBg: 0xffe8e6e4,  // Slightly darker corner
  headerFg:       0xff3b3a39,  // Fluent neutral-primary text
  headerBorder:   0xffd2d0ce,  // Fluent neutral-quaternary-alt
  gridLine:       0xffe1dfdd,  // Fluent neutral-lighter gridlines
  gridLineFixed:  0xffc8c6c4,  // Fluent neutral-tertiary-alt
  accent:         0xff217346,  // Excel 365 green
  selectionBg:    0x15217346,  // Very light green fill (Excel 365)
  selectionFg:    0xff000000,  // Black text on selection
  sheetBorder:    0xffd2d0ce,
} as const;

/** Build the GridConfig for a spreadsheet-like appearance. */
export function buildSheetConfig(opts?: {
  rows?: number;
  cols?: number;
  fontName?: string;
  fontSize?: number;
  defaultRowHeight?: number;
  defaultColWidth?: number;
}): SheetGridConfig {
  const resolvedFontSize =
    typeof opts?.fontSize === "number" && Number.isFinite(opts.fontSize) && opts.fontSize > 0
      ? opts.fontSize
      : 11;
  return {
    // Layout
    rows: opts?.rows ?? 100,
    cols: opts?.cols ?? 26,
    defaultRowHeight: opts?.defaultRowHeight ?? 21,
    defaultColWidth: opts?.defaultColWidth ?? 64,
    textOverflow: true,

    // Style — new nested structure
    background: SHEET_COLORS.white,
    foreground: SHEET_COLORS.black,
    font: {
      family: opts?.fontName ?? "Calibri",
      size: resolvedFontSize,
      bold: false,
    },
    gridLines: {
      style: GRIDLINE_SOLID,
      color: SHEET_COLORS.gridLine,
      width: 1,
    },
    fixed: {
      background: SHEET_COLORS.headerBg,
      foreground: SHEET_COLORS.headerFg,
      gridLines: {
        style: GRIDLINE_SOLID,
        color: SHEET_COLORS.gridLineFixed,
      },
    },

    indicators: {
      rowStart: {
        visible: true,
        background: SHEET_COLORS.headerBg,
        foreground: SHEET_COLORS.headerFg,
        gridLines: GRIDLINE_SOLID,
        gridColor: SHEET_COLORS.headerBorder,
        allowResize: true,
      },
      colTop: {
        visible: true,
        bandRows: 1,
        defaultRowHeight: Math.max(24, opts?.defaultRowHeight ?? 21),
        background: SHEET_COLORS.headerBg,
        foreground: SHEET_COLORS.headerFg,
        gridLines: GRIDLINE_SOLID,
        gridColor: SHEET_COLORS.headerBorder,
        allowResize: true,
      },
      cornerTopStart: {
        visible: true,
        background: SHEET_COLORS.headerCornerBg,
        foreground: SHEET_COLORS.headerFg,
      },
    },

    // Selection — Excel 365 green
    selectionMode: SELECTION_MULTI_RANGE,
    focusBorder: FOCUS_BORDER_THICK,
    selectionStyle: {
      background: SHEET_COLORS.selectionBg,
      foreground: SHEET_COLORS.selectionFg,
      fillHandle: FILL_HANDLE_BOTTOM_RIGHT,
      fillHandleColor: SHEET_COLORS.accent,
    },

    // Indicator active state — Excel 365 style:
    // Transparent bg, keep header text color, only edge border green.
    indicatorRowStyle: {
      foreground: SHEET_COLORS.headerFg,
      borders: {
        all:   { style: BORDER_NONE },
        right: { style: BORDER_THICK, color: SHEET_COLORS.accent },
      },
    },
    indicatorColStyle: {
      foreground: SHEET_COLORS.headerFg,
      borders: {
        all:    { style: BORDER_NONE },
        bottom: { style: BORDER_THICK, color: SHEET_COLORS.accent },
      },
    },

    // Editing: host_key_dispatch = true so we control key→edit mapping
    editTrigger: EDIT_TRIGGER_KEY_CLICK,
    tabBehavior: TAB_CELLS,
    hostKeyDispatch: true,

    // Interaction — ResizePolicy message
    resize: { columns: true, rows: true },
    autoResize: false,

    // Span
    // Disable auto-span — spreadsheets do not auto-span adjacent identical cells
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
