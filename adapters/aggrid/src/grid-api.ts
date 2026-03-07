import type { VolvoxGrid } from "volvoxgrid";
import type { NormalizedColDef } from "./col-def-mapper.js";
import { decodeExportCsv, decodeSelectionState, encodeSelectRequest } from "./proto-utils.js";
import type { ColDef, GridApiLike, RowData } from "./types.js";

interface GridApiDelegate<TData extends RowData> {
  getGrid(): VolvoxGrid;
  getWasm(): any;
  getHeaderRows(): number;
  getColumns(): NormalizedColDef<TData>[];
  getShadowRows(): TData[];
  setRowData(rows: TData[]): void;
  setColumnDefs(columnDefs: ColDef<TData>[]): void;
  reloadData(): void;
  onColumnMoved(fromIndex: number, toIndex: number): void;
  destroy(): void;
}

function escapeCsvCell(value: string): string {
  if (value.includes(",") || value.includes("\n") || value.includes("\"")) {
    return `"${value.replace(/\"/g, "\"\"")}"`;
  }
  return value;
}

function fallbackCsv<TData extends RowData>(
  columns: NormalizedColDef<TData>[],
  rows: TData[],
): string {
  const lines: string[] = [];
  lines.push(columns.map((c) => escapeCsvCell(c.def.headerName ?? c.field)).join(","));
  for (const row of rows) {
    const line: string[] = [];
    for (const col of columns) {
      const raw = row[col.field as keyof TData];
      line.push(escapeCsvCell(raw == null ? "" : String(raw)));
    }
    lines.push(line.join(","));
  }
  return lines.join("\n");
}

function readSelectionState(grid: VolvoxGrid, wasm: any) {
  if (typeof wasm.volvox_grid_get_selection === "function") {
    const payload = wasm.volvox_grid_get_selection(BigInt(grid.id)) as Uint8Array;
    if (payload instanceof Uint8Array && payload.length > 0) {
      return decodeSelectionState(payload);
    }
  }
  return null;
}

function exportCsv(grid: VolvoxGrid, wasm: any): string | null {
  if (typeof wasm.volvox_grid_export === "function") {
    const formatCsv = 2;
    const scopeAll = 0;
    const payload = wasm.volvox_grid_export(BigInt(grid.id), formatCsv, scopeAll) as Uint8Array;
    if (payload instanceof Uint8Array && payload.length > 0) {
      return decodeExportCsv(payload);
    }
  }
  return null;
}

function applySelection(
  grid: VolvoxGrid,
  wasm: any,
  row: number,
  col: number,
  rowEnd?: number,
  colEnd?: number,
): void {
  if (typeof wasm.volvox_grid_select_pb !== "function") {
    return;
  }
  const req = encodeSelectRequest({
    gridId: grid.id,
    row,
    col,
    rowEnd,
    colEnd,
  });
  wasm.volvox_grid_select_pb(req);
}

export class VolvoxGridApi<TData extends RowData> implements GridApiLike<TData> {
  constructor(private readonly delegate: GridApiDelegate<TData>) {}

  getSelectedRows(): TData[] {
    const grid = this.delegate.getGrid();
    const wasm = this.delegate.getWasm();
    const selection = readSelectionState(grid, wasm);
    const rows = this.delegate.getShadowRows();

    let start = grid.cursorRow;
    let end = grid.cursorRow;

    if (selection != null) {
      start = Math.min(selection.row, selection.rowEnd);
      end = Math.max(selection.row, selection.rowEnd);
    }

    const startBody = Math.max(0, start);
    const endBody = Math.min(rows.length - 1, end);
    if (rows.length === 0 || endBody < startBody) {
      return [];
    }

    const out: TData[] = [];
    for (let i = startBody; i <= endBody; i += 1) {
      const row = rows[i];
      if (row != null) {
        out.push(row);
      }
    }
    return out;
  }

  selectAll(): void {
    const grid = this.delegate.getGrid();
    const wasm = this.delegate.getWasm();
    const rowCount = this.delegate.getShadowRows().length;
    const colCount = this.delegate.getColumns().length;
    if (rowCount <= 0 || colCount <= 0) {
      return;
    }

    const rowStart = 0;
    const rowEnd = rowCount - 1;
    const colStart = 0;
    const colEnd = colCount - 1;
    applySelection(grid, wasm, rowStart, colStart, rowEnd, colEnd);
  }

  deselectAll(): void {
    const grid = this.delegate.getGrid();
    const wasm = this.delegate.getWasm();
    const row = 0;
    applySelection(grid, wasm, row, 0, row, 0);
  }

  sizeColumnsToFit(): void {
    this.delegate.getGrid().autoSize(0, -1, false, 0);
  }

  exportDataAsCsv(_fileName?: string): string {
    const grid = this.delegate.getGrid();
    const wasm = this.delegate.getWasm();
    const exported = exportCsv(grid, wasm);
    if (exported != null && exported.length > 0) {
      return exported;
    }
    return fallbackCsv(this.delegate.getColumns(), this.delegate.getShadowRows());
  }

  moveColumn(fromIndex: number, toIndex: number): void {
    this.delegate.getGrid().moveColumn(fromIndex, toIndex);
    this.delegate.onColumnMoved(fromIndex, toIndex);
  }

  setColumnWidth(index: number, width: number): void {
    this.delegate.getGrid().setColWidth(index, width);
  }

  setRowData(rowData: TData[]): void {
    this.delegate.setRowData(rowData);
  }

  setColumnDefs(columnDefs: ColDef<TData>[]): void {
    this.delegate.setColumnDefs(columnDefs);
  }

  refreshData(): void {
    this.delegate.reloadData();
  }

  destroy(): void {
    this.delegate.destroy();
  }
}
