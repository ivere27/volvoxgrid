package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.Align;
import io.github.ivere27.volvoxgrid.Border;
import io.github.ivere27.volvoxgrid.BorderStyle;
import io.github.ivere27.volvoxgrid.Borders;
import io.github.ivere27.volvoxgrid.CellStyle;
import io.github.ivere27.volvoxgrid.CellUpdate;
import io.github.ivere27.volvoxgrid.CellValue;
import io.github.ivere27.volvoxgrid.ColIndicatorCellMode;
import io.github.ivere27.volvoxgrid.ColIndicatorConfig;
import io.github.ivere27.volvoxgrid.ColumnDataType;
import io.github.ivere27.volvoxgrid.ColumnDef;
import io.github.ivere27.volvoxgrid.DefineColumnsRequest;
import io.github.ivere27.volvoxgrid.DefineRowsRequest;
import io.github.ivere27.volvoxgrid.DropdownTrigger;
import io.github.ivere27.volvoxgrid.EditConfig;
import io.github.ivere27.volvoxgrid.EditTrigger;
import io.github.ivere27.volvoxgrid.FillHandlePosition;
import io.github.ivere27.volvoxgrid.Font;
import io.github.ivere27.volvoxgrid.FreezePolicy;
import io.github.ivere27.volvoxgrid.GridConfig;
import io.github.ivere27.volvoxgrid.GridLineStyle;
import io.github.ivere27.volvoxgrid.GridLines;
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
import io.github.ivere27.volvoxgrid.OutlineConfig;
import io.github.ivere27.volvoxgrid.RegionStyle;
import io.github.ivere27.volvoxgrid.ResizePolicy;
import io.github.ivere27.volvoxgrid.RowIndicatorConfig;
import io.github.ivere27.volvoxgrid.RowDef;
import io.github.ivere27.volvoxgrid.ScrollBarsMode;
import io.github.ivere27.volvoxgrid.ScrollConfig;
import io.github.ivere27.volvoxgrid.SelectionConfig;
import io.github.ivere27.volvoxgrid.SelectionMode;
import io.github.ivere27.volvoxgrid.StyleConfig;
import io.github.ivere27.volvoxgrid.TreeIndicatorStyle;
import io.github.ivere27.volvoxgrid.UpdateCellsRequest;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class HierarchyJsonDesktopDemo {
    static final int ACTION_COLUMN_INDEX = 5;

    private static final int[] COL_WIDTHS = {260, 80, 80, 120, 100, 92};
    private static final String[] CAPTIONS = {
        "Name", "Type", "Size", "Modified", "Permissions", "Action",
    };
    private static final String[] KEYS = {
        "Name", "Type", "Size", "Modified", "Permissions", "Action",
    };
    private static final Pattern LEVEL_PATTERN = Pattern.compile("\"_level\"\\s*:\\s*(-?\\d+)");
    private static final Pattern TYPE_PATTERN = Pattern.compile("\"Type\"\\s*:\\s*\"([^\"]+)\"");
    private static final Pattern HELPER_FIELD_PATTERN = Pattern.compile(",\\s*\"_level\"\\s*:\\s*-?\\d+");
    private static final int BODY_BG = (int) 0xFFFFFFFFL;
    private static final int BODY_FG = (int) 0xFF1C1917L;
    private static final int CANVAS_BG = (int) 0xFFFAFAF9L;
    private static final int ALT_ROW_BG = (int) 0xFFF5F5F4L;
    private static final int FIXED_BG = (int) 0xFFF5F5F4L;
    private static final int FIXED_FG = (int) 0xFF44403CL;
    private static final int GRID_COLOR = (int) 0xFFE7E5E4L;
    private static final int FIXED_GRID_COLOR = (int) 0xFFD6D3D1L;
    private static final int HEADER_BG = (int) 0xFFFAFAF9L;
    private static final int HEADER_FG = (int) 0xFF1C1917L;
    private static final int SELECTION_BG = (int) 0xFFD97706L;
    private static final int SELECTION_FG = (int) 0xFFFFFFFFL;
    private static final int ACCENT = (int) 0xFFF59E0BL;
    private static final int TREE_COLOR = (int) 0xFFA8A29EL;
    private static final int HOVER_CELL_BG = 0x1AD97706;

    private HierarchyJsonDesktopDemo() {}

    static void load(VolvoxGridDesktopController ctrl)
        throws SynurangDesktopBridge.SynurangBridgeException {
        String rawJson = new String(ctrl.getDemoData("hierarchy"), StandardCharsets.UTF_8);
        List<Integer> levels = extractLevels(rawJson);
        List<String> types = extractTypes(rawJson);
        ctrl.setColCount(COL_WIDTHS.length);
        ctrl.defineColumns(
            DefineColumnsRequest.newBuilder()
                .addColumns(column(0, null).build())
                .addColumns(column(1, null).build())
                .addColumns(column(2, Align.ALIGN_RIGHT_CENTER).build())
                .addColumns(column(3, null).build())
                .addColumns(column(4, Align.ALIGN_CENTER_CENTER).build())
                .addColumns(column(ACTION_COLUMN_INDEX, Align.ALIGN_CENTER_CENTER)
                    .setInteraction(io.github.ivere27.volvoxgrid.CellInteraction.CELL_INTERACTION_TEXT_LINK)
                    .build())
                .build()
        );
        LoadDataResult result = ctrl.loadData(
            HELPER_FIELD_PATTERN.matcher(rawJson).replaceAll("").getBytes(StandardCharsets.UTF_8),
            LoadDataOptions.newBuilder()
                .setAutoCreateColumns(false)
                .build()
        );
        if (result.getStatus() == LoadDataStatus.LOAD_FAILED) {
            throw new IllegalStateException("LoadData failed for embedded hierarchy demo");
        }

        ctrl.configure(hierarchyThemeConfig());

        DefineRowsRequest.Builder rows = DefineRowsRequest.newBuilder();
        UpdateCellsRequest.Builder styles = UpdateCellsRequest.newBuilder();
        for (int row = 0; row < levels.size(); row++) {
            boolean isFolder = row < types.size() && "Folder".equals(types.get(row));
            rows.addRows(
                RowDef.newBuilder()
                    .setIndex(row)
                    .setOutlineLevel(levels.get(row))
                    .setIsSubtotal(isFolder)
                    .build()
            );
            styles.addCells(
                CellUpdate.newBuilder()
                    .setRow(row)
                    .setCol(ACTION_COLUMN_INDEX)
                    .setValue(CellValue.newBuilder().setText(isFolder ? "Browse" : "Open").build())
                    .setStyle(
                        CellStyle.newBuilder()
                            .setForeground((int) 0xFF2563EBL)
                            .build()
                    )
                    .build()
            );
            if (isFolder) {
                styles.addCells(
                    CellUpdate.newBuilder()
                        .setRow(row)
                        .setCol(0)
                        .setStyle(
                            CellStyle.newBuilder()
                                .setForeground((int) 0xFF92400EL)
                                .setFont(Font.newBuilder().setBold(true).build())
                                .build()
                        )
                        .build()
                );
            }
        }
        ctrl.defineRows(rows.build());
        ctrl.updateCells(styles.build());
    }

    private static GridConfig hierarchyThemeConfig() {
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
                            .setCell(true)
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
                    .setDropdownTrigger(DropdownTrigger.DROPDOWN_NEVER)
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
                    .setTreeIndicator(TreeIndicatorStyle.TREE_INDICATOR_ARROWS_LEAF)
                    .setTreeColumn(0)
                    .setTreeColor(TREE_COLOR)
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
                            .setSort(false)
                            .setReorder(false)
                            .setChooser(false)
                            .build()
                    )
                    .build()
            )
            .setIndicators(
                IndicatorsConfig.newBuilder()
                    .setRowStart(
                        RowIndicatorConfig.newBuilder()
                            .setVisible(false)
                            .build()
                    )
                    .setColTop(
                        ColIndicatorConfig.newBuilder()
                            .setVisible(true)
                            .setDefaultRowHeight(28)
                            .setBandRows(1)
                            .setModeBits(ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT_VALUE)
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

    private static List<Integer> extractLevels(String rawJson) {
        ArrayList<Integer> levels = new ArrayList<>();
        Matcher matcher = LEVEL_PATTERN.matcher(rawJson);
        while (matcher.find()) {
            levels.add(Integer.parseInt(matcher.group(1)));
        }
        return levels;
    }

    private static List<String> extractTypes(String rawJson) {
        ArrayList<String> types = new ArrayList<>();
        Matcher matcher = TYPE_PATTERN.matcher(rawJson);
        while (matcher.find()) {
            types.add(matcher.group(1));
        }
        return types;
    }

    private static ColumnDef.Builder column(int index, Align align) {
        ColumnDef.Builder builder = ColumnDef.newBuilder()
            .setIndex(index)
            .setWidth(COL_WIDTHS[index])
            .setCaption(CAPTIONS[index])
            .setKey(KEYS[index]);
        if (index == 3) {
            builder
                .setDataType(ColumnDataType.COLUMN_DATA_DATE)
                .setFormat("short date");
        }
        if (align != null) {
            builder.setAlign(align);
        }
        return builder;
    }
}
