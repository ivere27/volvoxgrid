package io.github.ivere27.volvoxgrid.example

import io.github.ivere27.volvoxgrid.Align
import io.github.ivere27.volvoxgrid.Border
import io.github.ivere27.volvoxgrid.BorderStyle
import io.github.ivere27.volvoxgrid.Borders
import io.github.ivere27.volvoxgrid.CellInteraction
import io.github.ivere27.volvoxgrid.CellStyle
import io.github.ivere27.volvoxgrid.ColIndicatorCellMode
import io.github.ivere27.volvoxgrid.ColIndicatorConfig
import io.github.ivere27.volvoxgrid.ColumnDataType
import io.github.ivere27.volvoxgrid.ColumnDef
import io.github.ivere27.volvoxgrid.CornerIndicatorConfig
import io.github.ivere27.volvoxgrid.CornerIndicatorSlot
import io.github.ivere27.volvoxgrid.CornerIndicatorSlotKind
import io.github.ivere27.volvoxgrid.DefineColumnsRequest
import io.github.ivere27.volvoxgrid.DropdownTrigger
import io.github.ivere27.volvoxgrid.EditConfig
import io.github.ivere27.volvoxgrid.EditTrigger
import io.github.ivere27.volvoxgrid.FillHandlePosition
import io.github.ivere27.volvoxgrid.Font
import io.github.ivere27.volvoxgrid.GridConfig
import io.github.ivere27.volvoxgrid.GridLineStyle
import io.github.ivere27.volvoxgrid.GridLines
import io.github.ivere27.volvoxgrid.HeaderResizeHandle
import io.github.ivere27.volvoxgrid.HeaderSeparator
import io.github.ivere27.volvoxgrid.HeaderStyle
import io.github.ivere27.volvoxgrid.HeaderFeatures
import io.github.ivere27.volvoxgrid.HighlightStyle
import io.github.ivere27.volvoxgrid.HoverConfig
import io.github.ivere27.volvoxgrid.IndicatorsConfig
import io.github.ivere27.volvoxgrid.IndicatorAppearance
import io.github.ivere27.volvoxgrid.InteractionConfig
import io.github.ivere27.volvoxgrid.LayoutConfig
import io.github.ivere27.volvoxgrid.LoadDataOptions
import io.github.ivere27.volvoxgrid.LoadDataStatus
import io.github.ivere27.volvoxgrid.OutlineConfig
import io.github.ivere27.volvoxgrid.RegionStyle
import io.github.ivere27.volvoxgrid.ResizePolicy
import io.github.ivere27.volvoxgrid.RowIndicatorConfig
import io.github.ivere27.volvoxgrid.RowIndicatorSlot
import io.github.ivere27.volvoxgrid.RowIndicatorSlotKind
import io.github.ivere27.volvoxgrid.ScrollBarsMode
import io.github.ivere27.volvoxgrid.ScrollConfig
import io.github.ivere27.volvoxgrid.SelectionConfig
import io.github.ivere27.volvoxgrid.SelectionMode
import io.github.ivere27.volvoxgrid.StyleConfig
import io.github.ivere27.volvoxgrid.TreeIndicatorStyle
import io.github.ivere27.volvoxgrid.VolvoxGridController
import org.json.JSONArray
import org.json.JSONObject

object HierarchyJsonDemo {
    private const val NAME_COLUMN_INDEX = 0
    const val ACTION_COLUMN_INDEX = 5

    private val widths = intArrayOf(260, 80, 80, 120, 100, 92)
    private val captions = arrayOf("Name", "Type", "Size", "Modified", "Permissions", "Action")
    private val keys = arrayOf("Name", "Type", "Size", "Modified", "Permissions", "Action")
    private const val BODY_BG = 0xFFFFFFFF.toInt()
    private const val BODY_FG = 0xFF1C1917.toInt()
    private const val CANVAS_BG = 0xFFFAFAF9.toInt()
    private const val ALT_ROW_BG = 0xFFF5F5F4.toInt()
    private const val FIXED_BG = 0xFFF5F5F4.toInt()
    private const val FIXED_FG = 0xFF44403C.toInt()
    private const val GRID_COLOR = 0xFFE7E5E4.toInt()
    private const val FIXED_GRID_COLOR = 0xFFD6D3D1.toInt()
    private const val HEADER_BG = 0xFFFAFAF9.toInt()
    private const val HEADER_FG = 0xFF1C1917.toInt()
    private const val ACCENT = 0xFFF59E0B.toInt()
    private const val TREE_COLOR = 0xFFA8A29E.toInt()
    private const val SELECTION_BG = 0xFFD97706.toInt()
    private const val SELECTION_FG = 0xFFFFFFFF.toInt()
    private const val HOVER_CELL_BG = 0x1AD97706
    private const val OUTLINE_INDENT = 20
    private const val MIN_OUTLINE_INDICATOR_WIDTH = 56
    private const val HEADER_ROW_HEIGHT = 44

    fun load(controller: VolvoxGridController) {
        val rawJson = controller.getDemoData("hierarchy").toString(Charsets.UTF_8)
        val rows = JSONArray(rawJson)
        val levels = hierarchyLevels(rows)
        val types = List(rows.length()) { row -> rows.getJSONObject(row).optString("Type") }
        val sanitizedJson = visibleRowsJson(rows).toString()
        controller.setColCount(widths.size)
        controller.defineColumns(hierarchyColumnRequest())
        val result = controller.loadData(
            sanitizedJson.toByteArray(Charsets.UTF_8),
            LoadDataOptions.newBuilder()
                .setAutoCreateColumns(false)
                .build()
        )
        check(result.status != LoadDataStatus.LOAD_FAILED) { "LoadData failed for embedded hierarchy demo" }
        controller.configure(hierarchyThemeConfig(maxOutlineDepth(levels), maxOutlineLevel(levels)))

        val actionStyle = CellStyle.newBuilder()
            .setForeground(0xFF2563EB.toInt())
            .build()
        val folderStyle = CellStyle.newBuilder()
            .setForeground(0xFF92400E.toInt())
            .setFont(Font.newBuilder().setBold(true).build())
            .build()

        for (row in levels.indices) {
            val isFolder = row < types.size && types[row] == "Folder"
            controller.setRowOutlineLevel(row, levels[row])
            controller.setCellStyleRange(
                row,
                ACTION_COLUMN_INDEX,
                row,
                ACTION_COLUMN_INDEX,
                actionStyle
            )
            if (isFolder) {
                controller.setCellStyleRange(row, 0, row, 0, folderStyle)
            }
        }
    }

    private fun hierarchyColumnRequest(): DefineColumnsRequest {
        val builder = DefineColumnsRequest.newBuilder()
        for (col in widths.indices) {
            val def = ColumnDef.newBuilder()
                .setIndex(col)
                .setCaption(captions[col])
                .setKey(keys[col])
                .setWidth(widths[col])
            when (col) {
                2 -> def.align = Align.ALIGN_RIGHT_CENTER
                3 -> {
                    def.dataType = ColumnDataType.COLUMN_DATA_DATE
                    def.format = "short date"
                }
                4, ACTION_COLUMN_INDEX -> def.align = Align.ALIGN_CENTER_CENTER
            }
            if (col == ACTION_COLUMN_INDEX) {
                def.interaction = CellInteraction.CELL_INTERACTION_TEXT_LINK
            }
            if (col == NAME_COLUMN_INDEX) {
                def.hidden = true
            }
            builder.addColumns(def.build())
        }
        return builder.build()
    }

    private fun visibleRowsJson(rows: JSONArray): JSONArray {
        val visibleRows = JSONArray()
        for (row in 0 until rows.length()) {
            val source = rows.getJSONObject(row)
            val target = JSONObject()
            for (key in keys) {
                target.put(key, source.opt(key) ?: "")
            }
            visibleRows.put(target)
        }
        return visibleRows
    }

    private fun hierarchyLevels(rows: JSONArray): List<Int> {
        val rowsById = mutableMapOf<String, JSONObject>()
        for (row in 0 until rows.length()) {
            val source = rows.getJSONObject(row)
            val id = source.optString("Id")
            check(id.isNotBlank()) { "Hierarchy demo row is missing Id" }
            rowsById[id] = source
        }

        val cache = mutableMapOf<String, Int>()
        fun depthOf(row: JSONObject, visiting: MutableSet<String>): Int {
            val id = row.optString("Id")
            cache[id]?.let { return it }
            check(visiting.add(id)) { "Hierarchy demo data contains a parent cycle at $id" }
            val parentValue = row.opt("ParentId")
            val parentId = if (parentValue == null || parentValue == JSONObject.NULL) "" else parentValue.toString()
            val depth = if (parentId.isBlank()) {
                0
            } else {
                val parent = rowsById[parentId]
                    ?: error("Hierarchy demo data references missing parent $parentId")
                depthOf(parent, visiting) + 1
            }
            visiting.remove(id)
            cache[id] = depth
            return depth
        }

        return List(rows.length()) { row -> depthOf(rows.getJSONObject(row), mutableSetOf()) }
    }

    private fun maxOutlineDepth(levels: List<Int>): Int {
        val nonNegativeLevels = levels.filter { it >= 0 }
        val minLevel = nonNegativeLevels.minOrNull() ?: 0
        val maxLevel = levels.maxOrNull() ?: 0
        return (maxLevel - minLevel).coerceAtLeast(0)
    }

    private fun maxOutlineLevel(levels: List<Int>): Int {
        return levels.filter { it >= 0 }.maxOrNull() ?: 0
    }

    private fun outlineIndicatorWidth(maxOutlineDepth: Int): Int {
        return maxOf(MIN_OUTLINE_INDICATOR_WIDTH, (maxOutlineDepth.coerceAtLeast(0) + 1) * OUTLINE_INDENT)
    }

    private fun expanderIndicatorWidth(maxOutlineDepth: Int): Int {
        return outlineIndicatorWidth(maxOutlineDepth) + 280
    }

    private fun hierarchyThemeConfig(maxOutlineDepth: Int, maxOutlineLevel: Int): GridConfig {
        val outlineWidth = outlineIndicatorWidth(maxOutlineDepth)
        val expanderWidth = expanderIndicatorWidth(maxOutlineDepth)
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
                    .setFlingImpulseGain(220f)
                    .setFlingFriction(0.9f)
                    .build()
            )
            .setOutline(
                OutlineConfig.newBuilder()
                    .setTreeIndicator(TreeIndicatorStyle.TREE_INDICATOR_ARROWS_LEAF)
                    .setIndicatorIndent(OUTLINE_INDENT)
                    .setMaxLevels(maxOutlineLevel.coerceAtLeast(0))
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
                            .setBackground(HEADER_BG)
                            .setForeground(FIXED_FG)
                            .setGridColor(FIXED_GRID_COLOR)
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
                            .setBackground(HEADER_BG)
                            .setForeground(FIXED_FG)
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
                            .setBandRows(1)
                            .setModeBits(ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT.number)
                            .setBackground(HEADER_BG)
                            .setForeground(HEADER_FG)
                            .setGridColor(FIXED_GRID_COLOR)
                            .setAllowResize(true)
                            .build()
                    )
                    .setAppearance(IndicatorAppearance.INDICATOR_APPEARANCE_MODERN)
                    .build()
            )
            .build()
    }
}
