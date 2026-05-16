package io.github.ivere27.volvoxgrid.example

import io.github.ivere27.volvoxgrid.Align
import io.github.ivere27.volvoxgrid.CellInteraction
import io.github.ivere27.volvoxgrid.CellStyle
import io.github.ivere27.volvoxgrid.ColIndicatorCellMode
import io.github.ivere27.volvoxgrid.ColIndicatorCellModes
import io.github.ivere27.volvoxgrid.ColIndicatorConfig
import io.github.ivere27.volvoxgrid.ColumnDataType
import io.github.ivere27.volvoxgrid.ColumnDef
import io.github.ivere27.volvoxgrid.CornerIndicatorConfig
import io.github.ivere27.volvoxgrid.CornerIndicatorSlot
import io.github.ivere27.volvoxgrid.CornerIndicatorSlotKind
import io.github.ivere27.volvoxgrid.DefineColumnsRequest
import io.github.ivere27.volvoxgrid.EditActivation
import io.github.ivere27.volvoxgrid.EditConfig
import io.github.ivere27.volvoxgrid.EditTrigger
import io.github.ivere27.volvoxgrid.Font
import io.github.ivere27.volvoxgrid.GridConfig
import io.github.ivere27.volvoxgrid.HeaderFeatures
import io.github.ivere27.volvoxgrid.IndicatorsConfig
import io.github.ivere27.volvoxgrid.IndicatorAppearance
import io.github.ivere27.volvoxgrid.InteractionConfig
import io.github.ivere27.volvoxgrid.LayoutConfig
import io.github.ivere27.volvoxgrid.LoadDataOptions
import io.github.ivere27.volvoxgrid.LoadDataStatus
import io.github.ivere27.volvoxgrid.OutlineConfig
import io.github.ivere27.volvoxgrid.ResizePolicy
import io.github.ivere27.volvoxgrid.RowIndicatorConfig
import io.github.ivere27.volvoxgrid.RowIndicatorSlot
import io.github.ivere27.volvoxgrid.RowIndicatorSlotKind
import io.github.ivere27.volvoxgrid.SelectionConfig
import io.github.ivere27.volvoxgrid.SelectionMode
import io.github.ivere27.volvoxgrid.ThemePreset
import io.github.ivere27.volvoxgrid.TreeIndicatorStyle
import io.github.ivere27.volvoxgrid.VolvoxGridController
import org.json.JSONArray
import org.json.JSONObject

object HierarchyJsonDemo {
    private const val NAME_COLUMN_INDEX = 0
    private const val SIZE_COLUMN_INDEX = 2
    private const val MODIFIED_COLUMN_INDEX = 3
    private const val PERMISSIONS_COLUMN_INDEX = 4
    const val ACTION_COLUMN_INDEX = 5

    private const val SHORT_DATE_FORMAT = "short date"

    private val captions = arrayOf("Name", "Type", "Size", "Modified", "Permissions", "Action")
    private val keys = arrayOf("Name", "Type", "Size", "Modified", "Permissions", "Action")
    private const val TREE_COLOR = 0xFFA8A29E.toInt()
    private const val FOLDER_TEXT_COLOR = 0xFF92400E.toInt()
    private const val ACTION_TEXT_COLOR = 0xFF2563EB.toInt()
    private const val OUTLINE_INDENT = 20
    private const val MIN_OUTLINE_INDICATOR_WIDTH = 56
    private const val NAME_EXPANDER_WIDTH = 280
    private const val HEADER_BAND_ROWS = 1
    private const val HEADER_ROW_HEIGHT = 44

    fun load(controller: VolvoxGridController) {
        val rawJson = controller.getDemoData("hierarchy").toString(Charsets.UTF_8)
        val rows = JSONArray(rawJson)
        val levels = hierarchyLevels(rows)
        val types = List(rows.length()) { row -> rows.getJSONObject(row).optString("Type") }
        val sanitizedJson = visibleRowsJson(rows).toString()
        controller.setColCount(keys.size)
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
            .setForeground(ACTION_TEXT_COLOR)
            .build()
        val folderStyle = CellStyle.newBuilder()
            .setForeground(FOLDER_TEXT_COLOR)
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
                controller.setCellStyleRange(row, NAME_COLUMN_INDEX, row, NAME_COLUMN_INDEX, folderStyle)
            }
        }
        controller.autoSize(0, keys.lastIndex)
    }

    private fun hierarchyColumnRequest(): DefineColumnsRequest {
        val builder = DefineColumnsRequest.newBuilder()
        for (col in keys.indices) {
            val def = ColumnDef.newBuilder()
                .setIndex(col)
                .setCaption(captions[col])
                .setKey(keys[col])
            when (col) {
                SIZE_COLUMN_INDEX -> def.align = Align.ALIGN_RIGHT_CENTER
                MODIFIED_COLUMN_INDEX -> {
                    def.dataType = ColumnDataType.COLUMN_DATA_DATE
                    def.format = SHORT_DATE_FORMAT
                }
                PERMISSIONS_COLUMN_INDEX, ACTION_COLUMN_INDEX -> def.align = Align.ALIGN_CENTER_CENTER
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
        return outlineIndicatorWidth(maxOutlineDepth) + NAME_EXPANDER_WIDTH
    }

    private fun hierarchyThemeConfig(maxOutlineDepth: Int, maxOutlineLevel: Int): GridConfig {
        val outlineWidth = outlineIndicatorWidth(maxOutlineDepth)
        val expanderWidth = expanderIndicatorWidth(maxOutlineDepth)
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
                        .setTrigger(EditTrigger.EDIT_TRIGGER_NONE)
                        .build())
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
            .build()
    }
}
