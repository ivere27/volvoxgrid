import {
  Align,
  ColIndicatorCellMode,
  ColumnDataType,
  GroupTotalPosition,
  LoadDataStatus,
  RowIndicatorSlotKind,
  ThemePreset,
  TreeIndicatorStyle,
  dropdownFromLabels,
  type VolvoxGrid,
} from "../js/src/index.js";
import {
  DEFAULT_COL_INDICATOR_BAND_ROWS,
  DEFAULT_ROW_INDICATOR_WIDTH,
  type DemoColumnSetup,
} from "./shared.js";

const SALES_HEADER_ROW_HEIGHT = 28;

const SALES_STATUS_ITEMS = "Active|Pending|Shipped|Returned|Cancelled";
const SALES_GRAND_TOTAL_BACK_COLOR = 0xFFEEF2FF;
const SALES_QUARTER_SUBTOTAL_BACK_COLOR = 0xFFF5F3FF;
const SALES_REGION_SUBTOTAL_BACK_COLOR = 0xFFF8F7FF;
const SALES_MARGIN_PROGRESS_COLOR = 0xFF818CF8;

enum SalesColumn {
  Quarter,
  Region,
  Category,
  Product,
  Sales,
  Cost,
  Margin,
  Flag,
  Status,
  Notes,
}

const SALES_COLUMN_SETUP = [
  { caption: "Q", key: "Q", align: Align.ALIGN_CENTER_CENTER, dataType: undefined, format: undefined, dropdownItems: undefined, span: true },
  { caption: "Region", key: "Region", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: true },
  { caption: "Category", key: "Category", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: false },
  { caption: "Product", key: "Product", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: false },
  { caption: "Sales", key: "Sales", align: Align.ALIGN_RIGHT_CENTER, dataType: ColumnDataType.COLUMN_DATA_CURRENCY, format: "$#,##0", dropdownItems: undefined, span: false },
  { caption: "Cost", key: "Cost", align: Align.ALIGN_RIGHT_CENTER, dataType: ColumnDataType.COLUMN_DATA_CURRENCY, format: "$#,##0", dropdownItems: undefined, span: false },
  { caption: "Margin%", key: "Margin", align: Align.ALIGN_CENTER_CENTER, dataType: ColumnDataType.COLUMN_DATA_NUMBER, format: undefined, dropdownItems: undefined, progressColor: SALES_MARGIN_PROGRESS_COLOR, span: false },
  { caption: "Flag", key: "Flag", align: Align.ALIGN_CENTER_CENTER, dataType: ColumnDataType.COLUMN_DATA_BOOLEAN, format: undefined, dropdownItems: undefined, span: false },
  { caption: "Status", key: "Status", align: undefined, dataType: undefined, format: undefined, dropdownItems: SALES_STATUS_ITEMS, span: false },
  { caption: "Notes", key: "Notes", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: false },
] satisfies readonly DemoColumnSetup[];

export const SALES_COLS = SALES_COLUMN_SETUP.length;

export function setupSalesJsonDemo(grid: VolvoxGrid, id: number): void {
  const prevId = grid.id;
  if (id !== prevId) {
    grid.useGrid(id);
  }

  try {
    const salesData = grid.getDemoData("sales");
    if (salesData.length === 0) {
      throw new Error("embedded sales demo data is empty");
    }
    grid.colCount = SALES_COLS;
    grid.defineColumns(SALES_COLUMN_SETUP);
    const result = grid.loadData(salesData, {
      autoCreateColumns: false,
    });
    if (result.status === LoadDataStatus.LOAD_FAILED) {
      throw new Error("LoadData failed for embedded sales demo");
    }
    grid.themePreset = ThemePreset.THEME_LIGHT;
    grid.showRowIndicator = true;
    grid.setOutlineConfig({
      treeIndicator: TreeIndicatorStyle.TREE_INDICATOR_NONE,
      groupTotalPosition: GroupTotalPosition.GROUP_TOTAL_BELOW,
      multiTotals: true,
    });
    grid.setRowIndicatorStartConfig({
      visible: true,
      width: DEFAULT_ROW_INDICATOR_WIDTH,
      slots: [{ kind: RowIndicatorSlotKind.ROW_INDICATOR_SLOT_NUMBERS }],
    });
    grid.setColumnIndicatorTopConfig({
      visible: true,
      defaultRowHeight: SALES_HEADER_ROW_HEIGHT,
      bandRows: DEFAULT_COL_INDICATOR_BAND_ROWS,
      cellModes: [
        ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT,
        ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH,
      ],
    });
    grid.setColDropdown(SalesColumn.Status, dropdownFromLabels(SALES_STATUS_ITEMS));
    grid.addSubtotals(
      [SalesColumn.Sales, SalesColumn.Cost],
      [
        { caption: "Grand Total", backColor: SALES_GRAND_TOTAL_BACK_COLOR },
        { groupCol: SalesColumn.Quarter, backColor: SALES_QUARTER_SUBTOTAL_BACK_COLOR },
        { groupCol: SalesColumn.Region, backColor: SALES_REGION_SUBTOTAL_BACK_COLOR },
      ],
      { mergeColFrom: SalesColumn.Quarter, mergeColTo: SalesColumn.Region },
    );
    grid.autoSize(SalesColumn.Sales, SalesColumn.Cost);
    grid.invalidate();
  } finally {
    if (id !== prevId) {
      grid.useGrid(prevId);
    }
  }
}
