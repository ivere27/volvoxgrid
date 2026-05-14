package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.Align;
import io.github.ivere27.volvoxgrid.CellStyle;
import io.github.ivere27.volvoxgrid.CellUpdate;
import io.github.ivere27.volvoxgrid.CellValue;
import io.github.ivere27.volvoxgrid.ColIndicatorCellMode;
import io.github.ivere27.volvoxgrid.ColIndicatorCellModes;
import io.github.ivere27.volvoxgrid.ColIndicatorConfig;
import io.github.ivere27.volvoxgrid.ColumnDataType;
import io.github.ivere27.volvoxgrid.ColumnDef;
import io.github.ivere27.volvoxgrid.CornerIndicatorConfig;
import io.github.ivere27.volvoxgrid.CornerIndicatorSlot;
import io.github.ivere27.volvoxgrid.CornerIndicatorSlotKind;
import io.github.ivere27.volvoxgrid.DefineColumnsRequest;
import io.github.ivere27.volvoxgrid.DefineRowsRequest;
import io.github.ivere27.volvoxgrid.EditActivation;
import io.github.ivere27.volvoxgrid.EditConfig;
import io.github.ivere27.volvoxgrid.EditTrigger;
import io.github.ivere27.volvoxgrid.Font;
import io.github.ivere27.volvoxgrid.FreezePolicy;
import io.github.ivere27.volvoxgrid.GridConfig;
import io.github.ivere27.volvoxgrid.HeaderFeatures;
import io.github.ivere27.volvoxgrid.IndicatorsConfig;
import io.github.ivere27.volvoxgrid.IndicatorAppearance;
import io.github.ivere27.volvoxgrid.InteractionConfig;
import io.github.ivere27.volvoxgrid.LayoutConfig;
import io.github.ivere27.volvoxgrid.LoadDataResult;
import io.github.ivere27.volvoxgrid.LoadDataStatus;
import io.github.ivere27.volvoxgrid.LoadDataOptions;
import io.github.ivere27.volvoxgrid.OutlineConfig;
import io.github.ivere27.volvoxgrid.ResizePolicy;
import io.github.ivere27.volvoxgrid.RowIndicatorConfig;
import io.github.ivere27.volvoxgrid.RowIndicatorSlot;
import io.github.ivere27.volvoxgrid.RowIndicatorSlotKind;
import io.github.ivere27.volvoxgrid.RowDef;
import io.github.ivere27.volvoxgrid.SelectionConfig;
import io.github.ivere27.volvoxgrid.SelectionMode;
import io.github.ivere27.volvoxgrid.ThemePreset;
import io.github.ivere27.volvoxgrid.TreeIndicatorStyle;
import io.github.ivere27.volvoxgrid.UpdateCellsRequest;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class HierarchyJsonDesktopDemo {
    static final int NAME_COLUMN_INDEX = 0;
    private static final int TYPE_COLUMN_INDEX = 1;
    private static final int SIZE_COLUMN_INDEX = 2;
    private static final int MODIFIED_COLUMN_INDEX = 3;
    private static final int PERMISSIONS_COLUMN_INDEX = 4;
    static final int ACTION_COLUMN_INDEX = 5;

    private static final int NAME_COLUMN_WIDTH = 260;
    private static final int TYPE_COLUMN_WIDTH = 80;
    private static final int SIZE_COLUMN_WIDTH = 80;
    private static final int MODIFIED_COLUMN_WIDTH = 120;
    private static final int PERMISSIONS_COLUMN_WIDTH = 100;
    private static final int ACTION_COLUMN_WIDTH = 92;
    private static final String SHORT_DATE_FORMAT = "short date";

    private static final int[] COL_WIDTHS = {
        NAME_COLUMN_WIDTH,
        TYPE_COLUMN_WIDTH,
        SIZE_COLUMN_WIDTH,
        MODIFIED_COLUMN_WIDTH,
        PERMISSIONS_COLUMN_WIDTH,
        ACTION_COLUMN_WIDTH,
    };
    private static final String[] CAPTIONS = {
        "Name", "Type", "Size", "Modified", "Permissions", "Action",
    };
    private static final String[] KEYS = {
        "Name", "Type", "Size", "Modified", "Permissions", "Action",
    };
    private static final Pattern ID_PATTERN = Pattern.compile("\"Id\"\\s*:\\s*\"([^\"]+)\"");
    private static final Pattern PARENT_ID_PATTERN = Pattern.compile("\"ParentId\"\\s*:\\s*(?:null|\"([^\"]*)\")");
    private static final Pattern TYPE_PATTERN = Pattern.compile("\"Type\"\\s*:\\s*\"([^\"]+)\"");
    private static final Pattern HELPER_FIELD_PATTERN = Pattern.compile(",\\s*\"(?:Id|ParentId)\"\\s*:\\s*(?:null|\"[^\"]*\")");
    private static final int TREE_COLOR = (int) 0xFFA8A29EL;
    private static final int FOLDER_TEXT_COLOR = (int) 0xFF92400EL;
    private static final int ACTION_TEXT_COLOR = (int) 0xFF2563EBL;
    private static final int OUTLINE_INDENT = 20;
    private static final int MIN_OUTLINE_INDICATOR_WIDTH = 56;
    private static final int NAME_EXPANDER_WIDTH = 280;
    private static final int HEADER_BAND_ROWS = 1;
    private static final int HEADER_ROW_HEIGHT = 28;

    private HierarchyJsonDesktopDemo() {}

    static void load(VolvoxGridDesktopController ctrl)
        throws SynurangDesktopBridge.SynurangBridgeException {
        String rawJson = new String(ctrl.getDemoData("hierarchy"), StandardCharsets.UTF_8);
        List<Integer> levels = deriveLevels(extractIds(rawJson), extractParentIds(rawJson));
        List<String> types = extractTypes(rawJson);
        ctrl.setColCount(COL_WIDTHS.length);
        ctrl.defineColumns(
            DefineColumnsRequest.newBuilder()
                .addColumns(column(NAME_COLUMN_INDEX, null).build())
                .addColumns(column(TYPE_COLUMN_INDEX, null).build())
                .addColumns(column(SIZE_COLUMN_INDEX, Align.ALIGN_RIGHT_CENTER).build())
                .addColumns(column(MODIFIED_COLUMN_INDEX, null).build())
                .addColumns(column(PERMISSIONS_COLUMN_INDEX, Align.ALIGN_CENTER_CENTER).build())
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

        ctrl.configure(hierarchyThemeConfig(maxOutlineDepth(levels), maxOutlineLevel(levels)));

        DefineRowsRequest.Builder rows = DefineRowsRequest.newBuilder();
        UpdateCellsRequest.Builder styles = UpdateCellsRequest.newBuilder();
        for (int row = 0; row < levels.size(); row++) {
            boolean isFolder = row < types.size() && "Folder".equals(types.get(row));
            rows.addRows(
                RowDef.newBuilder()
                    .setIndex(row)
                    .setOutlineLevel(levels.get(row))
                    .build()
            );
            styles.addCells(
                CellUpdate.newBuilder()
                    .setRow(row)
                    .setCol(ACTION_COLUMN_INDEX)
                    .setValue(CellValue.newBuilder().setText(isFolder ? "Browse" : "Open").build())
                    .setStyle(
                        CellStyle.newBuilder()
                            .setForeground(ACTION_TEXT_COLOR)
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
                                .setForeground(FOLDER_TEXT_COLOR)
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

    private static int maxOutlineDepth(List<Integer> levels) {
        if (levels.isEmpty()) {
            return 0;
        }
        int min = Integer.MAX_VALUE;
        int max = Integer.MIN_VALUE;
        for (int level : levels) {
            if (level >= 0) {
                min = Math.min(min, level);
            }
            max = Math.max(max, level);
        }
        return Math.max(0, max - (min == Integer.MAX_VALUE ? 0 : min));
    }

    private static int maxOutlineLevel(List<Integer> levels) {
        int max = 0;
        boolean hasMax = false;
        for (int level : levels) {
            if (level >= 0 && (!hasMax || level > max)) {
                hasMax = true;
                max = level;
            }
        }
        return max;
    }

    private static int outlineIndicatorWidth(int maxOutlineDepth) {
        return Math.max(MIN_OUTLINE_INDICATOR_WIDTH, (Math.max(0, maxOutlineDepth) + 1) * OUTLINE_INDENT);
    }

    private static int expanderIndicatorWidth(int maxOutlineDepth) {
        return outlineIndicatorWidth(maxOutlineDepth) + NAME_EXPANDER_WIDTH;
    }

    private static GridConfig hierarchyThemeConfig(int maxOutlineDepth, int maxOutlineLevel) {
        int outlineWidth = outlineIndicatorWidth(maxOutlineDepth);
        int expanderWidth = expanderIndicatorWidth(maxOutlineDepth);
        return GridConfig.newBuilder()
            .setThemePreset(ThemePreset.THEME_AMBER)
            .setLayout(
                LayoutConfig.newBuilder()
                    .setFixedRows(0)
                    .build()
            )
            .setSelection(
                SelectionConfig.newBuilder()
                    .setMode(SelectionMode.SELECTION_FREE)
                    .build()
            )
            .setEditing(
                EditConfig.newBuilder()
                    .setActivation(EditActivation.newBuilder()
                        .setTrigger(EditTrigger.EDIT_TRIGGER_NONE))
                    .build()
            )
            .setOutline(
                OutlineConfig.newBuilder()
                    .setTreeIndicator(TreeIndicatorStyle.TREE_INDICATOR_ARROWS_LEAF)
                    .setIndicatorIndent(OUTLINE_INDENT)
                    .setMaxLevels(Math.max(0, maxOutlineLevel))
                    .setShowLevelButtons(true)
                    .setLabelColumn(NAME_COLUMN_INDEX)
                    .setTreeColor(TREE_COLOR)
                    .build()
            )
            .setInteraction(
                InteractionConfig.newBuilder()
                    .setResize(
                        ResizePolicy.newBuilder()
                            .setColumns(true)
                            .setRows(false)
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
                            .setVisible(true)
                            .setWidth(expanderWidth)
                            .setAutoSize(false)
                            .setAllowResize(true)
                            .addSlots(
                                RowIndicatorSlot.newBuilder()
                                    .setKind(RowIndicatorSlotKind.ROW_INDICATOR_SLOT_EXPANDER)
                                    .setWidth(expanderWidth)
                                    .setVisible(true)
                                    .build()
                            )
                            .build()
                    )
                    .setCornerTopStart(
                        CornerIndicatorConfig.newBuilder()
                            .setVisible(true)
                            .addSlots(
                                CornerIndicatorSlot.newBuilder()
                                    .setKind(CornerIndicatorSlotKind.CORNER_SLOT_OUTLINE_LEVELS)
                                    .setWidth(outlineWidth)
                                    .setVisible(true)
                                    .build()
                            )
                            .build()
                    )
                    .setColTop(
                        ColIndicatorConfig.newBuilder()
                            .setVisible(true)
                            .setDefaultRowHeight(HEADER_ROW_HEIGHT)
                            .setBandRows(HEADER_BAND_ROWS)
                            .setCellModes(
                                ColIndicatorCellModes.newBuilder()
                                    .addModes(ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT)
                                    .build()
                            )
                            .setAllowResize(true)
                            .build()
                    )
                    .setAppearance(IndicatorAppearance.INDICATOR_APPEARANCE_MODERN)
                    .build()
            )
            .build();
    }

    private static List<String> extractIds(String rawJson) {
        ArrayList<String> ids = new ArrayList<>();
        Matcher matcher = ID_PATTERN.matcher(rawJson);
        while (matcher.find()) {
            ids.add(matcher.group(1));
        }
        return ids;
    }

    private static List<String> extractParentIds(String rawJson) {
        ArrayList<String> parentIds = new ArrayList<>();
        Matcher matcher = PARENT_ID_PATTERN.matcher(rawJson);
        while (matcher.find()) {
            parentIds.add(matcher.group(1));
        }
        return parentIds;
    }

    private static List<Integer> deriveLevels(List<String> ids, List<String> parentIds) {
        if (ids.size() != parentIds.size()) {
            throw new IllegalStateException("Hierarchy demo Id/ParentId counts do not match");
        }
        Map<String, String> parentById = new HashMap<>();
        for (int index = 0; index < ids.size(); index += 1) {
            String id = ids.get(index);
            if (id == null || id.trim().isEmpty()) {
                throw new IllegalStateException("Hierarchy demo row is missing Id");
            }
            parentById.put(id, parentIds.get(index));
        }

        Map<String, Integer> cache = new HashMap<>();
        ArrayList<Integer> levels = new ArrayList<>();
        for (String id : ids) {
            levels.add(depthOf(id, parentById, cache, new HashSet<>()));
        }
        return levels;
    }

    private static int depthOf(
        String id,
        Map<String, String> parentById,
        Map<String, Integer> cache,
        Set<String> visiting
    ) {
        Integer cached = cache.get(id);
        if (cached != null) {
            return cached;
        }
        if (!parentById.containsKey(id)) {
            throw new IllegalStateException("Hierarchy demo data references missing parent " + id);
        }
        if (!visiting.add(id)) {
            throw new IllegalStateException("Hierarchy demo data contains a parent cycle at " + id);
        }
        String parentId = parentById.get(id);
        int depth = parentId == null || parentId.trim().isEmpty()
            ? 0
            : depthOf(parentId, parentById, cache, visiting) + 1;
        visiting.remove(id);
        cache.put(id, depth);
        return depth;
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
        if (index == MODIFIED_COLUMN_INDEX) {
            builder
                .setDataType(ColumnDataType.COLUMN_DATA_DATE)
                .setFormat(SHORT_DATE_FORMAT);
        }
        if (align != null) {
            builder.setAlign(align);
        }
        if (index == NAME_COLUMN_INDEX) {
            builder.setHidden(true);
        }
        return builder;
    }
}
