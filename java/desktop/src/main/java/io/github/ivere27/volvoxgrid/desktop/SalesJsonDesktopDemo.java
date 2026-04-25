package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.AggregateType;
import io.github.ivere27.volvoxgrid.Align;
import io.github.ivere27.volvoxgrid.Border;
import io.github.ivere27.volvoxgrid.BorderStyle;
import io.github.ivere27.volvoxgrid.Borders;
import io.github.ivere27.volvoxgrid.CellSpanMode;
import io.github.ivere27.volvoxgrid.CellStyle;
import io.github.ivere27.volvoxgrid.CellUpdate;
import io.github.ivere27.volvoxgrid.CellValue;
import io.github.ivere27.volvoxgrid.CheckedState;
import io.github.ivere27.volvoxgrid.ColIndicatorCellMode;
import io.github.ivere27.volvoxgrid.ColIndicatorConfig;
import io.github.ivere27.volvoxgrid.ColumnDataType;
import io.github.ivere27.volvoxgrid.ColumnDef;
import io.github.ivere27.volvoxgrid.DefineColumnsRequest;
import io.github.ivere27.volvoxgrid.Dropdown;
import io.github.ivere27.volvoxgrid.DropdownItem;
import io.github.ivere27.volvoxgrid.DropdownTrigger;
import io.github.ivere27.volvoxgrid.EditConfig;
import io.github.ivere27.volvoxgrid.EditTrigger;
import io.github.ivere27.volvoxgrid.FillHandlePosition;
import io.github.ivere27.volvoxgrid.FreezePolicy;
import io.github.ivere27.volvoxgrid.GridConfig;
import io.github.ivere27.volvoxgrid.GridLineStyle;
import io.github.ivere27.volvoxgrid.GridLines;
import io.github.ivere27.volvoxgrid.GroupTotalPosition;
import io.github.ivere27.volvoxgrid.HeaderFeatures;
import io.github.ivere27.volvoxgrid.HeaderResizeHandle;
import io.github.ivere27.volvoxgrid.HeaderSeparator;
import io.github.ivere27.volvoxgrid.HeaderStyle;
import io.github.ivere27.volvoxgrid.HighlightStyle;
import io.github.ivere27.volvoxgrid.HoverConfig;
import io.github.ivere27.volvoxgrid.IndicatorsConfig;
import io.github.ivere27.volvoxgrid.InteractionConfig;
import io.github.ivere27.volvoxgrid.LayoutConfig;
import io.github.ivere27.volvoxgrid.LoadDataResult;
import io.github.ivere27.volvoxgrid.LoadDataStatus;
import io.github.ivere27.volvoxgrid.LoadDataOptions;
import io.github.ivere27.volvoxgrid.LoadMode;
import io.github.ivere27.volvoxgrid.NodeInfo;
import io.github.ivere27.volvoxgrid.OutlineConfig;
import io.github.ivere27.volvoxgrid.RegionStyle;
import io.github.ivere27.volvoxgrid.ResizePolicy;
import io.github.ivere27.volvoxgrid.RowIndicatorConfig;
import io.github.ivere27.volvoxgrid.RowIndicatorMode;
import io.github.ivere27.volvoxgrid.ScrollBarsMode;
import io.github.ivere27.volvoxgrid.ScrollConfig;
import io.github.ivere27.volvoxgrid.SelectionConfig;
import io.github.ivere27.volvoxgrid.SelectionMode;
import io.github.ivere27.volvoxgrid.SpanConfig;
import io.github.ivere27.volvoxgrid.SpanCompareMode;
import io.github.ivere27.volvoxgrid.StyleConfig;
import io.github.ivere27.volvoxgrid.TreeIndicatorStyle;
import io.github.ivere27.volvoxgrid.UpdateCellsRequest;

final class SalesJsonDesktopDemo {
    private static final String SALES_STATUS_ITEMS = "Active|Pending|Shipped|Returned|Cancelled";
    private static final int[] COL_WIDTHS = {40, 80, 100, 120, 90, 90, 70, 56, 80, 140};
    private static final String[] CAPTIONS = {
        "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin%", "Flag", "Status", "Notes",
    };
    private static final String[] KEYS = {
        "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin", "Flag", "Status", "Notes",
    };
    private static final int BODY_BG = (int) 0xFFFFFFFFL;
    private static final int BODY_FG = (int) 0xFF111827L;
    private static final int CANVAS_BG = (int) 0xFFFAFAFBL;
    private static final int ALT_ROW_BG = (int) 0xFFF9FAFBL;
    private static final int FIXED_BG = (int) 0xFFF3F4F6L;
    private static final int FIXED_FG = (int) 0xFF374151L;
    private static final int GRID_COLOR = (int) 0xFFE5E7EBL;
    private static final int FIXED_GRID_COLOR = (int) 0xFFD1D5DBL;
    private static final int HEADER_BG = (int) 0xFFF9FAFBL;
    private static final int HEADER_FG = (int) 0xFF111827L;
    private static final int INDICATOR_BG = (int) 0xFFF9FAFBL;
    private static final int INDICATOR_FG = (int) 0xFF6B7280L;
    private static final int SELECTION_BG = (int) 0xFF6366F1L;
    private static final int SELECTION_FG = (int) 0xFFFFFFFFL;
    private static final int ACCENT = (int) 0xFF818CF8L;
    private static final int TREE_COLOR = (int) 0xFF9CA3AFL;
    private static final int HOVER_BAND_BG = 0x106366F1;
    private static final int HOVER_CELL_BG = 0x1E818CF8;

    private SalesJsonDesktopDemo() {}

    static void load(VolvoxGridDesktopController ctrl)
        throws SynurangDesktopBridge.SynurangBridgeException {
        ctrl.setColCount(COL_WIDTHS.length);
        DefineColumnsRequest columns =
            DefineColumnsRequest.newBuilder()
                .addColumns(column(0, Align.ALIGN_CENTER_CENTER).build())
                .addColumns(currencyColumn(4, "Sales"))
                .addColumns(currencyColumn(5, "Cost"))
                .addColumns(column(6, Align.ALIGN_CENTER_CENTER)
                    .setDataType(ColumnDataType.COLUMN_DATA_NUMBER)
                    .setCaption("Margin%")
                    .setKey("Margin")
                    .setWidth(COL_WIDTHS[6])
                    .build())
                .addColumns(column(7, Align.ALIGN_CENTER_CENTER)
                    .setDataType(ColumnDataType.COLUMN_DATA_BOOLEAN)
                    .setCaption("Flag")
                    .setKey("Flag")
                    .setWidth(COL_WIDTHS[7])
                    .build())
                .addColumns(column(8, null)
                    .setCaption("Status")
                    .setKey("Status")
                    .setWidth(COL_WIDTHS[8])
                    .setDropdown(dropdownFromLabels(SALES_STATUS_ITEMS))
                    .build())
                .addColumns(column(1, null).build())
                .addColumns(column(2, null).build())
                .addColumns(column(3, null).build())
                .addColumns(column(9, null).build())
                .build();
        ctrl.defineColumns(columns);
        LoadDataResult result = ctrl.loadData(
            ctrl.getDemoData("sales"),
            LoadDataOptions.newBuilder()
                .setAutoCreateColumns(false)
                .setMode(LoadMode.LOAD_REPLACE)
                .build()
        );
        if (result.getStatus() == LoadDataStatus.LOAD_FAILED) {
            throw new IllegalStateException("LoadData failed for embedded sales demo");
        }
        ctrl.defineColumns(columns);

        ctrl.configure(salesThemeConfig());

        ctrl.subtotal(AggregateType.AGG_CLEAR, 0, 0, "", 0, 0, false);
        ctrl.subtotal(AggregateType.AGG_SUM, -1, 4, "Grand Total", 0xFFEEF2FFL, 0xFF111827L, true);
        ctrl.subtotal(AggregateType.AGG_SUM, 0, 4, "", 0xFFF5F3FFL, 0xFF111827L, true);
        ctrl.subtotal(AggregateType.AGG_SUM, 1, 4, "", 0xFFF8F7FFL, 0xFF111827L, true);
        ctrl.subtotal(AggregateType.AGG_SUM, -1, 5, "Grand Total", 0xFFEEF2FFL, 0xFF111827L, true);
        ctrl.subtotal(AggregateType.AGG_SUM, 0, 5, "", 0xFFF5F3FFL, 0xFF111827L, true);
        ctrl.subtotal(AggregateType.AGG_SUM, 1, 5, "", 0xFFF8F7FFL, 0xFF111827L, true);
        applySalesSubtotalDecorations(ctrl);
    }

    private static void applySalesSubtotalDecorations(VolvoxGridDesktopController ctrl)
        throws SynurangDesktopBridge.SynurangBridgeException {
        UpdateCellsRequest.Builder updates = UpdateCellsRequest.newBuilder();
        for (int row = 0; row < ctrl.rowCount(); row += 1) {
            String product = ctrl.getCellText(row, 3);
            String sales = ctrl.getCellText(row, 4);
            String cost = ctrl.getCellText(row, 5);
            boolean isSubtotal = product.isEmpty() && (!sales.isEmpty() || !cost.isEmpty());
            if (!isSubtotal) {
                double margin = parseMarginPercent(ctrl.getCellText(row, 6));
                updates.addCells(
                    CellUpdate.newBuilder()
                        .setRow(row)
                        .setCol(6)
                        .setStyle(salesProgressStyle(margin))
                        .build()
                );
                boolean flagged = parseSalesFlag(ctrl.getCellText(row, 7));
                updates.addCells(
                    CellUpdate.newBuilder()
                        .setRow(row)
                        .setCol(7)
                        .setValue(CellValue.newBuilder().setFlag(flagged).build())
                        .setChecked(flagged ? CheckedState.CHECKED_CHECKED : CheckedState.CHECKED_UNCHECKED)
                        .build()
                );
                updates.addCells(
                    CellUpdate.newBuilder()
                        .setRow(row)
                        .setCol(8)
                        .setDropdown(dropdownFromLabels(SALES_STATUS_ITEMS))
                        .build()
                );
                continue;
            }
            if (sales.isEmpty() && cost.isEmpty()) {
                continue;
            }

            updates.addCells(
                CellUpdate.newBuilder()
                    .setRow(row)
                    .setCol(7)
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
                    .setCol(6)
                    .setValue(
                        CellValue.newBuilder()
                            .setText(String.format(java.util.Locale.US, "%.1f", margin))
                            .build()
                    )
                    .setStyle(salesProgressStyle(margin))
                    .build()
            );

            NodeInfo node = ctrl.getNode(row, null);
            if (node.getLevel() <= 0) {
                ctrl.mergeCells(row, 0, row, 1);
            }
        }
        if (updates.getCellsCount() > 0) {
            ctrl.updateCells(updates.build());
        }
    }

    private static Dropdown dropdownFromLabels(String items) {
        Dropdown.Builder dropdown = Dropdown.newBuilder();
        for (String label : items.split("\\|")) {
            if (!label.isEmpty()) {
                dropdown.addItems(DropdownItem.newBuilder().setLabel(label));
            }
        }
        return dropdown.build();
    }

    private static boolean parseSalesFlag(String text) {
        String normalized = text == null ? "" : text.trim().toLowerCase(java.util.Locale.US);
        return normalized.equals("1")
            || normalized.equals("true")
            || normalized.equals("yes")
            || normalized.equals("y")
            || normalized.equals("on")
            || normalized.equals("checked");
    }

    private static long parseLong(String text) {
        try {
            return Long.parseLong(text == null ? "" : text.trim());
        } catch (NumberFormatException ex) {
            return 0L;
        }
    }

    private static double parseMarginPercent(String text) {
        try {
            return Double.parseDouble((text == null ? "" : text.trim()).replace(",", ""));
        } catch (NumberFormatException ex) {
            return 0.0;
        }
    }

    private static CellStyle salesProgressStyle(double marginPercent) {
        return CellStyle.newBuilder()
            .setProgress((float) Math.max(0.0, Math.min(1.0, marginPercent / 100.0)))
            .setProgressColor(ACCENT)
            .build();
    }

    private static GridConfig salesThemeConfig() {
        return GridConfig.newBuilder()
            .setLayout(
                LayoutConfig.newBuilder()
                    .setFixedRows(0)
                    .build()
            )
            .setStyle(
                StyleConfig.newBuilder()
                    .setBackground(BODY_BG)
                    .setForeground(BODY_FG)
                    .setAlternateBackground(ALT_ROW_BG)
                    .setProgressColor(ACCENT)
                    .setSheetBackground(CANVAS_BG)
                    .setSheetBorder(FIXED_GRID_COLOR)
                    .setGridLines(
                        GridLines.newBuilder()
                            .setStyle(GridLineStyle.GRIDLINE_SOLID)
                            .setColor(GRID_COLOR)
                            .build()
                    )
                    .setFixed(
                        RegionStyle.newBuilder()
                            .setBackground(FIXED_BG)
                            .setForeground(FIXED_FG)
                            .setGridLines(
                                GridLines.newBuilder()
                                    .setStyle(GridLineStyle.GRIDLINE_SOLID)
                                    .setColor(FIXED_GRID_COLOR)
                                    .build()
                            )
                            .build()
                    )
                    .setFrozen(
                        RegionStyle.newBuilder()
                            .setBackground(BODY_BG)
                            .setForeground(BODY_FG)
                            .setGridLines(
                                GridLines.newBuilder()
                                    .setStyle(GridLineStyle.GRIDLINE_SOLID)
                                    .setColor(FIXED_GRID_COLOR)
                                    .build()
                            )
                            .build()
                    )
                    .setHeader(
                        HeaderStyle.newBuilder()
                            .setSeparator(
                                HeaderSeparator.newBuilder()
                                    .setEnabled(true)
                                    .setColor(FIXED_GRID_COLOR)
                                    .setWidth(1)
                                    .build()
                            )
                            .setResizeHandle(
                                HeaderResizeHandle.newBuilder()
                                    .setEnabled(true)
                                    .setColor(FIXED_GRID_COLOR)
                                    .setWidth(1)
                                    .setHitWidth(6)
                                    .build()
                            )
                            .build()
                    )
                    .build()
            )
            .setSelection(
                SelectionConfig.newBuilder()
                    .setMode(SelectionMode.SELECTION_FREE)
                    .setStyle(
                        HighlightStyle.newBuilder()
                            .setBackground(SELECTION_BG)
                            .setForeground(SELECTION_FG)
                            .setFillHandle(FillHandlePosition.FILL_HANDLE_NONE)
                            .setFillHandleColor(ACCENT)
                            .build()
                    )
                    .setActiveCellStyle(
                        HighlightStyle.newBuilder()
                            .setBackground(0x22000000)
                            .setForeground(SELECTION_FG)
                            .setBorders(
                                Borders.newBuilder()
                                    .setAll(
                                        Border.newBuilder()
                                            .setStyle(BorderStyle.BORDER_THICK)
                                            .setColor(ACCENT)
                                            .build()
                                    )
                                    .build()
                            )
                            .build()
                    )
                    .setHover(
                        HoverConfig.newBuilder()
                            .setRow(true)
                            .setColumn(true)
                            .setCell(true)
                            .setRowStyle(
                                HighlightStyle.newBuilder()
                                    .setBackground(HOVER_BAND_BG)
                                    .build()
                            )
                            .setColumnStyle(
                                HighlightStyle.newBuilder()
                                    .setBackground(HOVER_BAND_BG)
                                    .build()
                            )
                            .setCellStyle(
                                HighlightStyle.newBuilder()
                                    .setBackground(HOVER_CELL_BG)
                                    .setBorders(
                                        Borders.newBuilder()
                                            .setAll(
                                                Border.newBuilder()
                                                    .setStyle(BorderStyle.BORDER_THIN)
                                                    .setColor(ACCENT)
                                                    .build()
                                            )
                                            .build()
                                    )
                                    .build()
                            )
                            .build()
                    )
                    .build()
            )
            .setEditing(
                EditConfig.newBuilder()
                    .setTrigger(EditTrigger.EDIT_TRIGGER_NONE)
                    .setDropdownTrigger(DropdownTrigger.DROPDOWN_ALWAYS)
                    .setDropdownSearch(false)
                    .build()
            )
            .setScrolling(
                ScrollConfig.newBuilder()
                    .setScrollbars(ScrollBarsMode.SCROLLBAR_BOTH)
                    .setFlingEnabled(true)
                    .setFlingImpulseGain(220.0f)
                    .setFlingFriction(0.9f)
                    .build()
            )
            .setOutline(
                OutlineConfig.newBuilder()
                    .setTreeIndicator(TreeIndicatorStyle.TREE_INDICATOR_NONE)
                    .setTreeColor(TREE_COLOR)
                    .setGroupTotalPosition(GroupTotalPosition.GROUP_TOTAL_BELOW)
                    .setMultiTotals(true)
                    .build()
            )
            .setSpan(
                SpanConfig.newBuilder()
                    .setCellSpan(CellSpanMode.CELL_SPAN_ADJACENT)
                    .setCellSpanFixed(CellSpanMode.CELL_SPAN_NONE)
                    .setCellSpanCompare(SpanCompareMode.SPAN_COMPARE_NO_CASE)
                    .build()
            )
            .setInteraction(
                InteractionConfig.newBuilder()
                    .setResize(
                        ResizePolicy.newBuilder()
                            .setColumns(true)
                            .setRows(true)
                            .build()
                    )
                    .setFreeze(
                        FreezePolicy.newBuilder()
                            .setColumns(true)
                            .setRows(true)
                            .build()
                    )
                    .setAutoSizeMouse(true)
                    .setHeaderFeatures(
                        HeaderFeatures.newBuilder()
                            .setSort(true)
                            .setReorder(true)
                            .setChooser(false)
                            .build()
                    )
                    .build()
            )
            .setIndicators(
                IndicatorsConfig.newBuilder()
                    .setRowStart(
                        RowIndicatorConfig.newBuilder()
                            .setVisible(true)
                            .setWidth(40)
                            .setModeBits(RowIndicatorMode.ROW_INDICATOR_NUMBERS_VALUE)
                            .setBackground(INDICATOR_BG)
                            .setForeground(INDICATOR_FG)
                            .setGridColor(FIXED_GRID_COLOR)
                            .setAllowResize(true)
                            .build()
                    )
                    .setColTop(
                        ColIndicatorConfig.newBuilder()
                            .setVisible(true)
                            .setDefaultRowHeight(28)
                            .setBandRows(1)
                            .setModeBits(
                                ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT_VALUE
                                    | ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH_VALUE
                            )
                            .setBackground(HEADER_BG)
                            .setForeground(HEADER_FG)
                            .setGridColor(FIXED_GRID_COLOR)
                            .setAllowResize(true)
                            .build()
                    )
                    .build()
            )
            .build();
    }

    private static ColumnDef.Builder column(int index, Align align) {
        ColumnDef.Builder builder = ColumnDef.newBuilder()
            .setIndex(index)
            .setWidth(COL_WIDTHS[index])
            .setCaption(CAPTIONS[index])
            .setKey(KEYS[index]);
        if (index == 0 || index == 1) {
            builder.setSpan(true);
        }
        if (align != null) {
            builder.setAlign(align);
        }
        return builder;
    }

    private static ColumnDef currencyColumn(int index, String caption) {
        return column(index, Align.ALIGN_RIGHT_CENTER)
            .setCaption(caption)
            .setDataType(ColumnDataType.COLUMN_DATA_CURRENCY)
            .setFormat("$#,##0")
            .build();
    }

}
