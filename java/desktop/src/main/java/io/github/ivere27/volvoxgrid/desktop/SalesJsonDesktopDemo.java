package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.AggregateType;
import io.github.ivere27.volvoxgrid.Align;
import io.github.ivere27.volvoxgrid.CellUpdate;
import io.github.ivere27.volvoxgrid.CellValue;
import io.github.ivere27.volvoxgrid.CheckedState;
import io.github.ivere27.volvoxgrid.ColumnDataType;
import io.github.ivere27.volvoxgrid.ColumnDef;
import io.github.ivere27.volvoxgrid.DefineColumnsRequest;
import io.github.ivere27.volvoxgrid.EditorKind;
import io.github.ivere27.volvoxgrid.EditorOwner;
import io.github.ivere27.volvoxgrid.EditorPresentation;
import io.github.ivere27.volvoxgrid.EditorSpec;
import io.github.ivere27.volvoxgrid.GridConfig;
import io.github.ivere27.volvoxgrid.GroupTotalPosition;
import io.github.ivere27.volvoxgrid.ListEditorParams;
import io.github.ivere27.volvoxgrid.ListItem;
import io.github.ivere27.volvoxgrid.LoadDataOptions;
import io.github.ivere27.volvoxgrid.LoadDataResult;
import io.github.ivere27.volvoxgrid.LoadDataStatus;
import io.github.ivere27.volvoxgrid.OutlineConfig;
import io.github.ivere27.volvoxgrid.ThemePreset;
import io.github.ivere27.volvoxgrid.TreeIndicatorStyle;
import io.github.ivere27.volvoxgrid.UpdateCellsRequest;

import java.util.Arrays;
import java.util.Locale;

final class SalesJsonDesktopDemo {
    private static final int QUARTER_COL = 0;
    private static final int REGION_COL = 1;
    private static final int PRODUCT_COL = 3;
    private static final int SALES_COL = 4;
    private static final int COST_COL = 5;
    private static final int MARGIN_COL = 6;
    private static final int FLAG_COL = 7;
    private static final int STATUS_COL = 8;
    private static final long GRAND_TOTAL_BACK_COLOR = 0xFFEEF2FFL;
    private static final long QUARTER_SUBTOTAL_BACK_COLOR = 0xFFF5F3FFL;
    private static final long REGION_SUBTOTAL_BACK_COLOR = 0xFFF8F7FFL;
    private static final int MARGIN_PROGRESS_COLOR = (int) 0xFF818CF8L;
    private static final int AUTO_SIZE_NO_MAX_WIDTH = 0;

    private static final String SALES_STATUS_ITEMS = "Active|Pending|Shipped|Returned|Cancelled";
    private static final int[] COL_WIDTHS = {40, 80, 100, 120, 90, 90, 70, 56, 80, 140};
    private static final String[] CAPTIONS = {
        "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin%", "Flag", "Status", "Notes",
    };
    private static final String[] KEYS = {
        "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin", "Flag", "Status", "Notes",
    };

    private SalesJsonDesktopDemo() {}

    static void load(VolvoxGridDesktopController ctrl)
        throws SynurangDesktopBridge.SynurangBridgeException {
        ctrl.setThemePreset(ThemePreset.THEME_LIGHT);
        ctrl.setShowRowIndicator(true);
        ctrl.configure(
            GridConfig.newBuilder()
                .setOutline(
                    OutlineConfig.newBuilder()
                        .setTreeIndicator(TreeIndicatorStyle.TREE_INDICATOR_NONE)
                        .setGroupTotalPosition(GroupTotalPosition.GROUP_TOTAL_BELOW)
                        .setMultiTotals(true)
                        .build()
                )
                .build()
        );

        ctrl.setColCount(COL_WIDTHS.length);
        ctrl.defineColumns(salesColumns());
        LoadDataResult result = ctrl.loadData(
            ctrl.getDemoData("sales"),
            LoadDataOptions.newBuilder()
                .setAutoCreateColumns(false)
                .build()
        );
        if (result.getStatus() == LoadDataStatus.LOAD_FAILED) {
            throw new IllegalStateException("LoadData failed for embedded sales demo");
        }

        ctrl.addSubtotals(
            Arrays.asList(SALES_COL, COST_COL),
            Arrays.asList(
                new VolvoxGridSubtotalLevel(null, "Grand Total", GRAND_TOTAL_BACK_COLOR),
                new VolvoxGridSubtotalLevel(QUARTER_COL, "", QUARTER_SUBTOTAL_BACK_COLOR),
                new VolvoxGridSubtotalLevel(REGION_COL, "", REGION_SUBTOTAL_BACK_COLOR)
            ),
            AggregateType.AGG_SUM,
            true,
            QUARTER_COL,
            REGION_COL
        );
        applySubtotalDerivedCells(ctrl);
        ctrl.autoSize(SALES_COL, COST_COL, false, AUTO_SIZE_NO_MAX_WIDTH);
    }

    private static DefineColumnsRequest salesColumns() {
        DefineColumnsRequest.Builder builder = DefineColumnsRequest.newBuilder();
        for (int col = 0; col < COL_WIDTHS.length; col += 1) {
            ColumnDef.Builder def = column(col, col == QUARTER_COL ? Align.ALIGN_CENTER_CENTER : null);
            switch (col) {
                case SALES_COL:
                case COST_COL:
                    def.setAlign(Align.ALIGN_RIGHT_CENTER)
                        .setDataType(ColumnDataType.COLUMN_DATA_CURRENCY)
                        .setFormat("$#,##0");
                    break;
                case MARGIN_COL:
                    def.setAlign(Align.ALIGN_CENTER_CENTER)
                        .setDataType(ColumnDataType.COLUMN_DATA_NUMBER)
                        .setProgressColor(MARGIN_PROGRESS_COLOR);
                    break;
                case FLAG_COL:
                    def.setAlign(Align.ALIGN_CENTER_CENTER)
                        .setDataType(ColumnDataType.COLUMN_DATA_BOOLEAN);
                    break;
                case STATUS_COL:
                    def.setEditor(dropdownEditorFromLabels(SALES_STATUS_ITEMS));
                    break;
                default:
                    break;
            }
            builder.addColumns(def.build());
        }
        return builder.build();
    }

    private static void applySubtotalDerivedCells(VolvoxGridDesktopController ctrl)
        throws SynurangDesktopBridge.SynurangBridgeException {
        UpdateCellsRequest.Builder updates = UpdateCellsRequest.newBuilder();
        for (int row = 0; row < ctrl.rowCount(); row += 1) {
            String product = ctrl.getCellText(row, PRODUCT_COL);
            String sales = ctrl.getCellText(row, SALES_COL);
            String cost = ctrl.getCellText(row, COST_COL);
            boolean isSubtotal = product.isEmpty() && (!sales.isEmpty() || !cost.isEmpty());
            if (!isSubtotal) {
                continue;
            }

            updates.addCells(
                CellUpdate.newBuilder()
                    .setRow(row)
                    .setCol(FLAG_COL)
                    .setValue(CellValue.newBuilder().setFlag(false).build())
                    .setChecked(CheckedState.CHECKED_GRAYED)
                    .build()
            );

            long salesValue = parseLong(sales);
            long costValue = parseLong(cost);
            double margin = salesValue > 0
                ? ((salesValue - costValue) * 100.0) / salesValue
                : 0.0;
            updates.addCells(
                CellUpdate.newBuilder()
                    .setRow(row)
                    .setCol(MARGIN_COL)
                    .setValue(CellValue.newBuilder()
                        .setText(String.format(Locale.US, "%.1f", margin))
                        .build())
                    .build()
            );
        }
        if (updates.getCellsCount() > 0) {
            ctrl.updateCells(updates.build());
        }
    }

    private static long parseLong(String text) {
        try {
            return Long.parseLong(text == null ? "" : text.trim());
        } catch (NumberFormatException ex) {
            return 0L;
        }
    }

    private static ColumnDef.Builder column(int index, Align align) {
        ColumnDef.Builder builder = ColumnDef.newBuilder()
            .setIndex(index)
            .setWidth(COL_WIDTHS[index])
            .setCaption(CAPTIONS[index])
            .setKey(KEYS[index]);
        if (index == QUARTER_COL || index == REGION_COL) {
            builder.setSpan(true);
        }
        if (align != null) {
            builder.setAlign(align);
        }
        return builder;
    }

    private static EditorSpec dropdownEditorFromLabels(String items) {
        ListEditorParams.Builder list = ListEditorParams.newBuilder();
        for (String label : items.split("\\|")) {
            if (!label.isEmpty()) {
                list.addStaticItems(ListItem.newBuilder().setLabel(label));
            }
        }
        return EditorSpec.newBuilder()
            .setKind(EditorKind.EDITOR_SELECT)
            .setOwner(EditorOwner.EDITOR_OWNER_ENGINE)
            .setPresentation(EditorPresentation.EDITOR_CANVAS)
            .setList(list)
            .build();
    }
}
