/**
 * Decode GridEvent stream into typed objects.
 *
 * GridEvent is a oneof — we identify the event by its field number
 * and decode the inner payload accordingly.
 */

import { readVarint, skipField, asInt32, readString, readLengthDelimited } from "./proto-utils.js";

// GridEvent oneof field numbers (from volvoxgrid.proto)
export const EVENT_CELL_FOCUS_CHANGED = 3;
export const EVENT_SELECTION_CHANGED = 5;
export const EVENT_ENTER_CELL = 6;
export const EVENT_START_EDIT = 9;
export const EVENT_AFTER_EDIT = 10;
export const EVENT_CELL_EDIT_CHANGE = 12;
export const EVENT_KEY_DOWN_EDIT = 14;
export const EVENT_KEY_DOWN = 44;
export const EVENT_KEY_PRESS = 45;

export interface GridEventEnvelope {
  eventField: number;
  payload: Uint8Array;
}

export function decodeGridEventEnvelope(data: Uint8Array): GridEventEnvelope | null {
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);

    if (wire === 2 && field >= 2 && field <= 60) {
      const length = readVarint(data, offset);
      const n = Number(length.value);
      if (!Number.isFinite(n) || n < 0) return null;
      const start = length.next;
      const end = Math.min(data.length, start + n);
      return { eventField: field, payload: data.slice(start, end) };
    }

    offset = skipField(data, offset, wire);
  }
  return null;
}

// ── Payload decoders ───────────────────────────────────────

export interface CellFocusPayload {
  row: number;
  col: number;
}

export function decodeCellFocusPayload(data: Uint8Array): CellFocusPayload {
  // Shared by EnterCellEvent (row=1, col=2),
  //           StartEditEvent (row=1, col=2),
  //           CellFocusChangedEvent (old_row=1, old_col=2, new_row=3, new_col=4).
  // For CellFocusChanged we want new_row/new_col (fields 3/4).
  // For the others, only fields 1/2 are present.
  let f1 = 0, f2 = 0, f3: number | null = null, f4: number | null = null;
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const v = readVarint(data, offset);
      offset = v.next;
      const n = asInt32(v.value);
      if (field === 1) f1 = n;
      if (field === 2) f2 = n;
      if (field === 3) f3 = n;
      if (field === 4) f4 = n;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  // Prefer new_row/new_col (fields 3/4) when present; fall back to fields 1/2
  const row = f3 != null ? f3 : f1;
  const col = f4 != null ? f4 : f2;
  return { row, col };
}

export interface AfterEditPayload {
  row: number;
  col: number;
  oldText: string;
  newText: string;
}

export function decodeAfterEditPayload(data: Uint8Array): AfterEditPayload {
  let row = -1, col = -1, oldText = "", newText = "";
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const v = readVarint(data, offset);
      offset = v.next;
      const n = asInt32(v.value);
      if (field === 1) row = n;
      if (field === 2) col = n;
      continue;
    }
    if (wire === 2) {
      const s = readString(data, offset);
      if (field === 3) oldText = s.value;
      if (field === 4) newText = s.value;
      offset = s.next;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return { row, col, oldText, newText };
}

export interface CellEditChangePayload {
  text: string;
}

export function decodeCellEditChangePayload(data: Uint8Array): CellEditChangePayload {
  let text = "";
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === 1 && wire === 2) {
      const s = readString(data, offset);
      text = s.value;
      offset = s.next;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return { text };
}

export interface SelectionChangedPayload {
  /** New selection range end (grid-space). */
  rowEnd: number;
  colEnd: number;
}

interface CellRangePayload {
  row1: number;
  col1: number;
  row2: number;
  col2: number;
}

function decodeCellRangePayload(data: Uint8Array): CellRangePayload {
  let row1 = -1;
  let col1 = -1;
  let row2 = -1;
  let col2 = -1;
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const v = readVarint(data, offset);
      offset = v.next;
      const n = asInt32(v.value);
      if (field === 1) row1 = n;
      if (field === 2) col1 = n;
      if (field === 3) row2 = n;
      if (field === 4) col2 = n;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return { row1, col1, row2, col2 };
}

export function decodeSelectionChangedPayload(data: Uint8Array): SelectionChangedPayload {
  // New schema:
  // - old_ranges=1 (repeated CellRange)
  // - new_ranges=2 (repeated CellRange)
  // - active_row=3
  // - active_col=4
  // Legacy schema fallback:
  // - new_row_end=3
  // - new_col_end=4
  let rowEnd = -1;
  let colEnd = -1;
  let activeRow = -1;
  let activeCol = -1;
  let lastNewRange: CellRangePayload | null = null;
  let hasNewRanges = false;
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === 2 && wire === 2) {
      const ld = readLengthDelimited(data, offset);
      offset = ld.next;
      lastNewRange = decodeCellRangePayload(ld.data);
      hasNewRanges = true;
      continue;
    }
    if (wire === 0) {
      const v = readVarint(data, offset);
      offset = v.next;
      const n = asInt32(v.value);
      if (field === 3) {
        activeRow = n;
        if (!hasNewRanges) rowEnd = n;
      }
      if (field === 4) {
        activeCol = n;
        if (!hasNewRanges) colEnd = n;
      }
      continue;
    }
    offset = skipField(data, offset, wire);
  }

  if (lastNewRange != null) {
    if (activeRow === lastNewRange.row1 && activeCol === lastNewRange.col1) {
      rowEnd = lastNewRange.row2;
      colEnd = lastNewRange.col2;
    } else if (activeRow === lastNewRange.row2 && activeCol === lastNewRange.col2) {
      rowEnd = lastNewRange.row1;
      colEnd = lastNewRange.col1;
    } else {
      rowEnd = lastNewRange.row2;
      colEnd = lastNewRange.col2;
    }
  }

  return { rowEnd, colEnd };
}

export interface KeyEventPayload {
  keyCode: number;
  modifier: number;
}

export function decodeKeyEventPayload(data: Uint8Array): KeyEventPayload {
  let keyCode = 0, modifier = 0;
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const v = readVarint(data, offset);
      offset = v.next;
      const n = asInt32(v.value);
      if (field === 1) keyCode = n;
      if (field === 2) modifier = n;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return { keyCode, modifier };
}

export interface KeyPressPayload {
  keyAscii: number;
}

export function decodeKeyPressPayload(data: Uint8Array): KeyPressPayload {
  let keyAscii = 0;
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === 1 && wire === 0) {
      const v = readVarint(data, offset);
      keyAscii = asInt32(v.value);
      offset = v.next;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return { keyAscii };
}
