/**
 * Decode GridEvent stream into typed objects.
 *
 * GridEvent is a oneof. We identify the event by its field number
 * and decode the inner payload accordingly.
 */

import {
  AfterEditEventFields,
  CellEditChangeEventFields,
  CellFocusChangedEventFields,
  CellRangeFields,
  EnterCellEventFields,
  GridEventFields,
  KeyDownEventFields,
  KeyPressEventFields,
  SelectionChangedEventFields,
} from "volvoxgrid/generated/volvoxgrid_ffi.js";
import { readVarint, skipField, asInt32, readString, readLengthDelimited } from "./proto-utils.js";

export const EVENT_CELL_FOCUS_CHANGED = GridEventFields.cell_focus_changed;
export const EVENT_SELECTION_CHANGED = GridEventFields.selection_changed;
export const EVENT_ENTER_CELL = GridEventFields.enter_cell;
export const EVENT_START_EDIT = GridEventFields.start_edit;
export const EVENT_AFTER_EDIT = GridEventFields.after_edit;
export const EVENT_CELL_EDIT_CHANGE = GridEventFields.cell_edit_change;
export const EVENT_KEY_DOWN_EDIT = GridEventFields.key_down_edit;
export const EVENT_KEY_DOWN = GridEventFields.key_down;
export const EVENT_KEY_PRESS = GridEventFields.key_press;

const GRID_EVENT_PAYLOAD_FIELDS: ReadonlySet<number> = new Set<number>(
  (Object.values(GridEventFields) as number[]).filter(
    (field) => field !== GridEventFields.grid_id && field !== GridEventFields.event_id,
  ),
);

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

    if (wire === 2 && GRID_EVENT_PAYLOAD_FIELDS.has(field)) {
      const length = readVarint(data, offset);
      const n = Number(length.value);
      if (!Number.isFinite(n) || n < 0) {
        return null;
      }
      const start = length.next;
      const end = Math.min(data.length, start + n);
      return { eventField: field, payload: data.slice(start, end) };
    }

    offset = skipField(data, offset, wire);
  }
  return null;
}

export interface CellFocusPayload {
  row: number;
  col: number;
}

export function decodeCellFocusPayload(data: Uint8Array): CellFocusPayload {
  let row = 0;
  let col = 0;
  let newRow: number | null = null;
  let newCol: number | null = null;
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
      if (field === EnterCellEventFields.row) row = n;
      if (field === EnterCellEventFields.col) col = n;
      if (field === CellFocusChangedEventFields.new_row) newRow = n;
      if (field === CellFocusChangedEventFields.new_col) newCol = n;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return {
    row: newRow ?? row,
    col: newCol ?? col,
  };
}

export interface AfterEditPayload {
  row: number;
  col: number;
  oldText: string;
  newText: string;
}

export function decodeAfterEditPayload(data: Uint8Array): AfterEditPayload {
  let row = -1;
  let col = -1;
  let oldText = "";
  let newText = "";
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
      if (field === AfterEditEventFields.row) row = n;
      if (field === AfterEditEventFields.col) col = n;
      continue;
    }
    if (wire === 2) {
      const s = readString(data, offset);
      if (field === AfterEditEventFields.old_text) oldText = s.value;
      if (field === AfterEditEventFields.new_text) newText = s.value;
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
    if (field === CellEditChangeEventFields.text && wire === 2) {
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
      if (field === CellRangeFields.row1) row1 = n;
      if (field === CellRangeFields.col1) col1 = n;
      if (field === CellRangeFields.row2) row2 = n;
      if (field === CellRangeFields.col2) col2 = n;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return { row1, col1, row2, col2 };
}

export function decodeSelectionChangedPayload(data: Uint8Array): SelectionChangedPayload {
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
    if (field === SelectionChangedEventFields.new_ranges && wire === 2) {
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
      if (field === SelectionChangedEventFields.active_row) {
        activeRow = n;
        if (!hasNewRanges) rowEnd = n;
      }
      if (field === SelectionChangedEventFields.active_col) {
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
  let keyCode = 0;
  let modifier = 0;
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
      if (field === KeyDownEventFields.key_code) keyCode = n;
      if (field === KeyDownEventFields.modifier) modifier = n;
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
    if (field === KeyPressEventFields.key_ascii && wire === 0) {
      const v = readVarint(data, offset);
      keyAscii = asInt32(v.value);
      offset = v.next;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return { keyAscii };
}
