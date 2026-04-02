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
import io.github.ivere27.volvoxgrid.InteractionConfig
import io.github.ivere27.volvoxgrid.LayoutConfig
import io.github.ivere27.volvoxgrid.LoadDataOptions
import io.github.ivere27.volvoxgrid.LoadDataStatus
import io.github.ivere27.volvoxgrid.OutlineConfig
import io.github.ivere27.volvoxgrid.RegionStyle
import io.github.ivere27.volvoxgrid.ResizePolicy
import io.github.ivere27.volvoxgrid.RowIndicatorConfig
import io.github.ivere27.volvoxgrid.ScrollBarsMode
import io.github.ivere27.volvoxgrid.ScrollConfig
import io.github.ivere27.volvoxgrid.SelectionConfig
import io.github.ivere27.volvoxgrid.SelectionMode
import io.github.ivere27.volvoxgrid.StyleConfig
import io.github.ivere27.volvoxgrid.TabBehavior
import io.github.ivere27.volvoxgrid.TreeIndicatorStyle
import io.github.ivere27.volvoxgrid.VolvoxGridController

object HierarchyJsonDemo {
    const val ACTION_COLUMN_INDEX = 5

    private val widths = intArrayOf(260, 80, 80, 120, 100, 92)
    private val captions = arrayOf("Name", "Type", "Size", "Modified", "Permissions", "Action")
    private val keys = arrayOf("Name", "Type", "Size", "Modified", "Permissions", "Action")
    private val levelRegex = Regex("\"_level\"\\s*:\\s*(-?\\d+)")
    private val typeRegex = Regex("\"Type\"\\s*:\\s*\"([^\"]+)\"")
    private val helperFieldRegex = Regex(",\\s*\"_level\"\\s*:\\s*-?\\d+")
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

    fun load(controller: VolvoxGridController) {
        val rawJson = controller.getDemoData("hierarchy").toString(Charsets.UTF_8)
        val levels = levelRegex.findAll(rawJson).map { it.groupValues[1].toInt() }.toList()
        val types = typeRegex.findAll(rawJson).map { it.groupValues[1] }.toList()
        val sanitizedJson = helperFieldRegex.replace(rawJson, "")
        controller.setColCount(widths.size)
        controller.defineColumns(hierarchyColumnRequest())
        val result = controller.loadData(
            sanitizedJson.toByteArray(Charsets.UTF_8),
            LoadDataOptions.newBuilder()
                .setAutoCreateColumns(false)
                .build()
        )
        check(result.status != LoadDataStatus.LOAD_FAILED) { "LoadData failed for embedded hierarchy demo" }
        controller.configure(hierarchyThemeConfig())

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
            controller.setIsSubtotal(row, isFolder)
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
            builder.addColumns(def.build())
        }
        return builder.build()
    }

    private fun hierarchyThemeConfig(): GridConfig {
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
                    .setTabBehavior(TabBehavior.TAB_CELLS)
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
                            .setModeBits(ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT.number)
                            .setBackground(HEADER_BG)
                            .setForeground(HEADER_FG)
                            .setGridColor(FIXED_GRID_COLOR)
                            .setAllowResize(true)
                            .build()
                    )
                    .build()
            )
            .build()
    }
}
