export type RowData = Record<string, unknown>;

export type RowSelectionMode = "single" | "multiple";
export type SortDirection = "asc" | "desc";
export type PinnedDirection = "left" | "right";

export interface ValueGetterParams<TData extends RowData = RowData> {
  data: TData;
  field?: string;
  colDef: ColDef<TData>;
  rowIndex: number;
}

export interface ValueFormatterParams<TData extends RowData = RowData> {
  value: unknown;
  data: TData;
  field?: string;
  colDef: ColDef<TData>;
  rowIndex: number;
}

export type CellStyle = Record<string, string | number | undefined>;
export type AgIconValue =
  | string
  | ((...args: unknown[]) => string | HTMLElement | undefined);

export interface CellStyleParams<TData extends RowData = RowData> {
  value: unknown;
  data: TData;
  field?: string;
  colDef: ColDef<TData>;
  rowIndex: number;
}

export interface ColDef<TData extends RowData = RowData> {
  field?: string;
  headerName?: string;
  width?: number;
  minWidth?: number;
  maxWidth?: number;
  flex?: number;
  sortable?: boolean;
  sort?: SortDirection;
  resizable?: boolean;
  pinned?: PinnedDirection;
  valueGetter?: (params: ValueGetterParams<TData>) => unknown;
  valueFormatter?: (params: ValueFormatterParams<TData>) => unknown;
  cellStyle?: CellStyle | ((params: CellStyleParams<TData>) => CellStyle | undefined);
  hide?: boolean;
  children?: ColDef<TData>[];
}

export interface CellClickedEvent<TData extends RowData = RowData> {
  api: GridApiLike<TData>;
  rowIndex: number;
  colIndex: number;
  colDef: ColDef<TData>;
  data?: TData;
  value: unknown;
}

export interface RowClickedEvent<TData extends RowData = RowData> {
  api: GridApiLike<TData>;
  rowIndex: number;
  data?: TData;
}

export interface SelectionChangedEvent<TData extends RowData = RowData> {
  api: GridApiLike<TData>;
  selectedRows: TData[];
}

export interface SortChangedEvent<TData extends RowData = RowData> {
  api: GridApiLike<TData>;
  colIndex: number;
  colId?: string;
}

export interface BeforeEditEvent<TData extends RowData = RowData> {
  api: GridApiLike<TData>;
  rowIndex: number;
  colIndex: number;
  colId?: string;
  colDef: ColDef<TData>;
  data?: TData;
  value: unknown;
  cancel: boolean;
}

export interface CellEditValidatingEvent<TData extends RowData = RowData> {
  api: GridApiLike<TData>;
  rowIndex: number;
  colIndex: number;
  colId?: string;
  colDef: ColDef<TData>;
  data?: TData;
  value: unknown;
  editText: string;
  cancel: boolean;
}

export interface BeforeSortEvent<TData extends RowData = RowData> {
  api: GridApiLike<TData>;
  colIndex: number;
  colId?: string;
  colDef: ColDef<TData>;
  cancel: boolean;
}

export interface ColumnResizedEvent<TData extends RowData = RowData> {
  api: GridApiLike<TData>;
  row: number;
  col: number;
}

export interface GridReadyEvent<TData extends RowData = RowData> {
  api: GridApiLike<TData>;
}

export type AgThemeName =
  | "ag-theme-alpine"
  | "ag-theme-balham"
  | "ag-theme-material";

export interface GridOptions<TData extends RowData = RowData> {
  columnDefs?: ColDef<TData>[];
  defaultColDef?: Partial<ColDef<TData>>;
  rowData?: TData[];
  rowSelection?: RowSelectionMode;
  fontSize?: number;
  rowHeight?: number;
  headerHeight?: number;
  icons?: Record<string, AgIconValue>;
  pinnedTopRowData?: TData[];
  pinnedBottomRowData?: TData[];
  animateRows?: boolean;
  theme?: AgThemeName;
  onGridReady?: (event: GridReadyEvent<TData>) => void;
  onBeforeEdit?: (event: BeforeEditEvent<TData>) => void;
  onCellEditValidating?: (event: CellEditValidatingEvent<TData>) => void;
  onBeforeSort?: (event: BeforeSortEvent<TData>) => void;
  onSelectionChanged?: (event: SelectionChangedEvent<TData>) => void;
  onSortChanged?: (event: SortChangedEvent<TData>) => void;
  onColumnResized?: (event: ColumnResizedEvent<TData>) => void;
  onRowClicked?: (event: RowClickedEvent<TData>) => void;
  onCellClicked?: (event: CellClickedEvent<TData>) => void;
}

export interface AgGridVolvoxParams<TData extends RowData = RowData> {
  container: HTMLElement;
  wasm: unknown;
  gridOptions?: GridOptions<TData>;
}

export interface GridApiLike<TData extends RowData = RowData> {
  getSelectedRows(): TData[];
  selectAll(): void;
  deselectAll(): void;
  sizeColumnsToFit(): void;
  exportDataAsCsv(fileName?: string): string;
  moveColumn(fromIndex: number, toIndex: number): void;
  setColumnWidth(index: number, width: number): void;
  setRowData(rowData: TData[]): void;
  setColumnDefs(columnDefs: ColDef<TData>[]): void;
  refreshData(): void;
  destroy(): void;
}
