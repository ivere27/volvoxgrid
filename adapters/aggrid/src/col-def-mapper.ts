import type { ColDef, RowData } from "./types.js";

export interface NormalizedColDef<TData extends RowData = RowData> {
  index: number;
  field: string;
  def: ColDef<TData>;
  parentHeader?: string;
}

export interface ColumnLayout<TData extends RowData = RowData> {
  columns: NormalizedColDef<TData>[];
  fieldToIndex: Map<string, number>;
  headerRows: number;
  topHeaderTexts: string[];
  leafHeaderTexts: string[];
  hasColumnGroups: boolean;
}

function defaultHeaderName(field: string, fallbackIndex: number): string {
  if (field.length > 0) {
    return field;
  }
  return `Column ${fallbackIndex + 1}`;
}

function fallbackField<TData extends RowData>(def: ColDef<TData>, index: number): string {
  if (typeof def.field === "string" && def.field.length > 0) {
    return def.field;
  }
  return `col_${index}`;
}

export function normalizeColumnDefs<TData extends RowData>(
  columnDefs: ColDef<TData>[],
): ColumnLayout<TData> {
  const columns: NormalizedColDef<TData>[] = [];

  const visit = (defs: ColDef<TData>[], parentHeader?: string): void => {
    for (const def of defs) {
      if (def.children != null && def.children.length > 0) {
        const groupName =
          def.headerName ??
          (typeof def.field === "string" && def.field.length > 0 ? def.field : "");
        visit(def.children, groupName);
        continue;
      }

      const index = columns.length;
      const field = fallbackField(def, index);
      columns.push({
        index,
        field,
        def,
        parentHeader,
      });
    }
  };

  visit(columnDefs);

  const fieldToIndex = new Map<string, number>();
  const topHeaderTexts: string[] = [];
  const leafHeaderTexts: string[] = [];

  for (const col of columns) {
    fieldToIndex.set(col.field, col.index);
    const leafHeader =
      col.def.headerName ?? defaultHeaderName(col.field, col.index);
    // In mixed-depth grouped headers, AG Grid renders top-level leaf columns
    // as row-spanning header cells. Duplicating the leaf text into the top row
    // lets Volvox fixed-header merging create the same vertical span.
    topHeaderTexts[col.index] = col.parentHeader ?? leafHeader;
    leafHeaderTexts[col.index] = leafHeader;
  }

  const hasColumnGroups = columns.some((c) => c.parentHeader != null && c.parentHeader.length > 0);

  return {
    columns,
    fieldToIndex,
    headerRows: hasColumnGroups ? 2 : 1,
    topHeaderTexts,
    leafHeaderTexts,
    hasColumnGroups,
  };
}
