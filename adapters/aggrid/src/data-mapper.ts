import type { NormalizedColDef } from "./col-def-mapper.js";
import type { CellStyle, ColDef, RowData, ValueFormatterParams, ValueGetterParams } from "./types.js";

export type RowKind = "pinnedTop" | "body" | "pinnedBottom";

export interface DataMatrix<TData extends RowData = RowData> {
  rows: number;
  cols: number;
  values: string[];
  shadowRows: TData[];
  rowKinds: RowKind[];
}

export interface CellStyleMatrixCell {
  rowIndex: number;
  colIndex: number;
  style: CellStyle;
}

export interface CellStyleMatrix {
  cells: CellStyleMatrixCell[];
}

function stringifyValue(value: unknown): string {
  if (value == null) {
    return "";
  }
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "number" || typeof value === "boolean" || typeof value === "bigint") {
    return String(value);
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

function evaluateRawValue<TData extends RowData>(
  row: TData,
  column: NormalizedColDef<TData>,
  rowIndex: number,
): unknown {
  const def = column.def;
  const getterParams: ValueGetterParams<TData> = {
    data: row,
    field: def.field,
    colDef: def,
    rowIndex,
  };

  const rawValue =
    typeof def.valueGetter === "function"
      ? def.valueGetter(getterParams)
      : row[column.field as keyof TData];

  return rawValue;
}

function evaluateValue<TData extends RowData>(
  row: TData,
  column: NormalizedColDef<TData>,
  rowIndex: number,
): unknown {
  const def = column.def;
  const rawValue = evaluateRawValue(row, column, rowIndex);

  if (typeof def.valueFormatter === "function") {
    const fmtParams: ValueFormatterParams<TData> = {
      value: rawValue,
      data: row,
      field: def.field,
      colDef: def,
      rowIndex,
    };
    return def.valueFormatter(fmtParams);
  }

  return rawValue;
}

function evaluateCellStyle<TData extends RowData>(
  row: TData,
  colDef: ColDef<TData>,
  rawValue: unknown,
  rowIndex: number,
): CellStyle | undefined {
  if (colDef.cellStyle == null) {
    return undefined;
  }
  if (typeof colDef.cellStyle === "function") {
    return colDef.cellStyle({
      value: rawValue,
      data: row,
      field: colDef.field,
      colDef,
      rowIndex,
    });
  }
  return colDef.cellStyle;
}

export function mapRowDataToMatrix<TData extends RowData>(args: {
  columns: NormalizedColDef<TData>[];
  rowData: TData[];
  pinnedTopRowData: TData[];
  pinnedBottomRowData: TData[];
}): DataMatrix<TData> {
  const sourceRows: Array<{ row: TData; kind: RowKind }> = [];

  for (const row of args.pinnedTopRowData) {
    sourceRows.push({ row, kind: "pinnedTop" });
  }
  for (const row of args.rowData) {
    sourceRows.push({ row, kind: "body" });
  }
  for (const row of args.pinnedBottomRowData) {
    sourceRows.push({ row, kind: "pinnedBottom" });
  }

  const rows = sourceRows.length;
  const cols = args.columns.length;
  const values = new Array<string>(rows * cols);
  const shadowRows = new Array<TData>(rows);
  const rowKinds = new Array<RowKind>(rows);

  for (let rowIndex = 0; rowIndex < rows; rowIndex += 1) {
    const rowSpec = sourceRows[rowIndex];
    shadowRows[rowIndex] = rowSpec.row;
    rowKinds[rowIndex] = rowSpec.kind;

    for (let colIndex = 0; colIndex < cols; colIndex += 1) {
      const column = args.columns[colIndex];
      const value = evaluateValue(rowSpec.row, column, rowIndex);
      values[rowIndex * cols + colIndex] = stringifyValue(value);
    }
  }

  return {
    rows,
    cols,
    values,
    shadowRows,
    rowKinds,
  };
}

export function mapCellStyles<TData extends RowData>(args: {
  columns: NormalizedColDef<TData>[];
  rowData: TData[];
}): CellStyleMatrix {
  const cells: CellStyleMatrixCell[] = [];
  for (let rowIndex = 0; rowIndex < args.rowData.length; rowIndex += 1) {
    const row = args.rowData[rowIndex];
    for (let colIndex = 0; colIndex < args.columns.length; colIndex += 1) {
      const col = args.columns[colIndex];
      const rawValue = evaluateRawValue(row, col, rowIndex);
      const style = evaluateCellStyle(row, col.def, rawValue, rowIndex);
      if (style != null) {
        cells.push({
          rowIndex,
          colIndex,
          style,
        });
      }
    }
  }
  return { cells };
}
