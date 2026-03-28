import type { VolvoxGrid } from "volvoxgrid";
import type { NormalizedColDef } from "./col-def-mapper.js";
import {
  decodeAfterSortPayload,
  decodeAfterUserResizePayload,
  decodeGridEventEnvelope,
} from "./proto-utils.js";
import { GridEventFields } from "volvoxgrid/generated/volvoxgrid_ffi.js";
import type { GridApiLike, GridOptions, RowData } from "./types.js";

interface EventMapperContext<TData extends RowData> {
  grid: VolvoxGrid;
  getOptions(): GridOptions<TData>;
  api: GridApiLike<TData>;
  getColumns(): NormalizedColDef<TData>[];
  getShadowRows(): TData[];
  getHeaderRows(): number;
}

export class VolvoxGridEventMapper<TData extends RowData> {
  private intervalId: number | null = null;

  constructor(private readonly context: EventMapperContext<TData>) {}

  start(): void {
    if (this.intervalId != null || typeof window === "undefined") {
      return;
    }
    this.intervalId = window.setInterval(() => {
      this.pollEvents();
    }, 48);
  }

  stop(): void {
    if (this.intervalId != null && typeof window !== "undefined") {
      window.clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  pollEvents(): void {
    const rawEvents = this.context.grid.drainEventStreamRaw(256);
    if (rawEvents.length === 0) {
      return;
    }

    for (const raw of rawEvents) {
      const event = decodeGridEventEnvelope(raw);
      if (event == null) {
        continue;
      }

      if (event.eventField === GridEventFields.selection_changed) {
        this.context.getOptions().onSelectionChanged?.({
          api: this.context.api,
          selectedRows: this.context.api.getSelectedRows(),
        });
        continue;
      }

      if (event.eventField === GridEventFields.after_sort) {
        const payload = decodeAfterSortPayload(event.payload);
        this.context.getOptions().onSortChanged?.({
          api: this.context.api,
          colIndex: payload.col,
          colId: this.context.getColumns()[payload.col]?.field,
        });
        continue;
      }

      if (event.eventField === GridEventFields.after_user_resize) {
        const payload = decodeAfterUserResizePayload(event.payload);
        this.context.getOptions().onColumnResized?.({
          api: this.context.api,
          row: payload.row,
          col: payload.col,
        });
        continue;
      }

      if (event.eventField === GridEventFields.click) {
        this.emitClickEvents();
      }
    }
  }

  private emitClickEvents(): void {
    const rowIndex = this.context.grid.cursorRow;
    const colIndex = this.context.grid.cursorCol;

    const row = rowIndex >= 0 ? this.context.getShadowRows()[rowIndex] : undefined;
    const colDef = this.context.getColumns()[colIndex];
    const value =
      row != null && colDef != null ? row[colDef.field as keyof TData] : undefined;

    if (rowIndex >= 0) {
      this.context.getOptions().onRowClicked?.({
        api: this.context.api,
        rowIndex,
        data: row,
      });
    }

    if (rowIndex >= 0 && colDef != null) {
      this.context.getOptions().onCellClicked?.({
        api: this.context.api,
        rowIndex,
        colIndex,
        colDef: colDef.def,
        data: row,
        value,
      });
    }
  }
}
