package io.github.ivere27.volvoxgrid.example

import io.github.ivere27.volvoxgrid.AggregateType
import io.github.ivere27.volvoxgrid.Align
import io.github.ivere27.volvoxgrid.Border
import io.github.ivere27.volvoxgrid.BorderStyle
import io.github.ivere27.volvoxgrid.Borders
import io.github.ivere27.volvoxgrid.CellSpanMode
import io.github.ivere27.volvoxgrid.CellStyle
import io.github.ivere27.volvoxgrid.CellUpdate
import io.github.ivere27.volvoxgrid.CellValue
import io.github.ivere27.volvoxgrid.CheckedState
import io.github.ivere27.volvoxgrid.ColIndicatorCellMode
import io.github.ivere27.volvoxgrid.ColumnDataType
import io.github.ivere27.volvoxgrid.ColumnDef
import io.github.ivere27.volvoxgrid.ColIndicatorConfig
import io.github.ivere27.volvoxgrid.DefineColumnsRequest
import io.github.ivere27.volvoxgrid.DropdownTrigger
import io.github.ivere27.volvoxgrid.EditConfig
import io.github.ivere27.volvoxgrid.EditTrigger
import io.github.ivere27.volvoxgrid.FillHandlePosition
import io.github.ivere27.volvoxgrid.GridConfig
import io.github.ivere27.volvoxgrid.GridLineStyle
import io.github.ivere27.volvoxgrid.GridLines
import io.github.ivere27.volvoxgrid.GroupTotalPosition
import io.github.ivere27.volvoxgrid.HeaderResizeHandle
import io.github.ivere27.volvoxgrid.HeaderSeparator
import io.github.ivere27.volvoxgrid.HeaderStyle
import io.github.ivere27.volvoxgrid.HeaderFeatures
import io.github.ivere27.volvoxgrid.HighlightStyle
import io.github.ivere27.volvoxgrid.HoverConfig
import io.github.ivere27.volvoxgrid.IndicatorsConfig
import io.github.ivere27.volvoxgrid.InteractionConfig
import io.github.ivere27.volvoxgrid.LayoutConfig
import io.github.ivere27.volvoxgrid.LoadDataStatus
import io.github.ivere27.volvoxgrid.LoadDataOptions
import io.github.ivere27.volvoxgrid.OutlineConfig
import io.github.ivere27.volvoxgrid.RegionStyle
import io.github.ivere27.volvoxgrid.ResizePolicy
import io.github.ivere27.volvoxgrid.RowIndicatorConfig
import io.github.ivere27.volvoxgrid.RowIndicatorMode
import io.github.ivere27.volvoxgrid.ScrollBarsMode
import io.github.ivere27.volvoxgrid.ScrollConfig
import io.github.ivere27.volvoxgrid.SelectionConfig
import io.github.ivere27.volvoxgrid.SelectionMode
import io.github.ivere27.volvoxgrid.SpanConfig
import io.github.ivere27.volvoxgrid.StyleConfig
import io.github.ivere27.volvoxgrid.TabBehavior
import io.github.ivere27.volvoxgrid.TreeIndicatorStyle
import io.github.ivere27.volvoxgrid.UpdateCellsRequest
import io.github.ivere27.volvoxgrid.VolvoxGridController
import java.util.Locale

object SalesJsonDemo {
    private const val SALES_STATUS_ITEMS = "Active|Pending|Shipped|Returned|Cancelled"
    private val widths = intArrayOf(40, 80, 100, 120, 90, 90, 70, 56, 80, 140)
    private val captions = arrayOf(
        "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin%", "Flag", "Status", "Notes"
    )
    private val keys = arrayOf(
        "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin", "Flag", "Status", "Notes"
    )
    private const val BODY_BG = 0xFFFFFFFF.toInt()
    private const val BODY_FG = 0xFF111827.toInt()
    private const val CANVAS_BG = 0xFFFAFAFB.toInt()
    private const val ALT_ROW_BG = 0xFFF9FAFB.toInt()
    private const val FIXED_BG = 0xFFF3F4F6.toInt()
    private const val FIXED_FG = 0xFF374151.toInt()
    private const val GRID_COLOR = 0xFFE5E7EB.toInt()
    private const val FIXED_GRID_COLOR = 0xFFD1D5DB.toInt()
    private const val HEADER_BG = 0xFFF9FAFB.toInt()
    private const val HEADER_FG = 0xFF111827.toInt()
    private const val INDICATOR_BG = 0xFFF9FAFB.toInt()
    private const val INDICATOR_FG = 0xFF6B7280.toInt()
    private const val SELECTION_BG = 0xFF6366F1.toInt()
    private const val SELECTION_FG = 0xFFFFFFFF.toInt()
    private const val ACCENT = 0xFF818CF8.toInt()
    private const val TREE_COLOR = 0xFF9CA3AF.toInt()
    private const val HOVER_ROW_BG = 0x106366F1
    private const val HOVER_CELL_BG = 0x1E818CF8

    fun load(controller: VolvoxGridController) {
        controller.setColCount(widths.size)
        val columns = salesColumnRequest()
        controller.defineColumns(columns)
        val result = controller.loadData(
            controller.getDemoData("sales"),
            LoadDataOptions.newBuilder()
                .setAutoCreateColumns(false)
                .build()
        )
        check(result.status != LoadDataStatus.LOAD_FAILED) { "LoadData failed for embedded sales demo" }
        controller.defineColumns(columns)
        controller.setColDropdownItems(8, SALES_STATUS_ITEMS)

        controller.configure(salesThemeConfig())

        controller.subtotal(AggregateType.AGG_CLEAR, 0, 0, "", 0, 0, false)
        controller.subtotal(AggregateType.AGG_SUM, -1, 4, "Grand Total", 0xFFEEF2FF, 0xFF111827, true)
        controller.subtotal(AggregateType.AGG_SUM, 0, 4, "", 0xFFF5F3FF, 0xFF111827, true)
        controller.subtotal(AggregateType.AGG_SUM, 1, 4, "", 0xFFF8F7FF, 0xFF111827, true)
        controller.subtotal(AggregateType.AGG_SUM, -1, 5, "Grand Total", 0xFFEEF2FF, 0xFF111827, true)
        controller.subtotal(AggregateType.AGG_SUM, 0, 5, "", 0xFFF5F3FF, 0xFF111827, true)
        controller.subtotal(AggregateType.AGG_SUM, 1, 5, "", 0xFFF8F7FF, 0xFF111827, true)
        applySalesSubtotalDecorations(controller)
    }

    private fun salesColumnRequest(): DefineColumnsRequest {
        val builder = DefineColumnsRequest.newBuilder()
        for (col in widths.indices) {
            val def = ColumnDef.newBuilder()
                .setIndex(col)
                .setCaption(captions[col])
                .setKey(keys[col])
                .setWidth(widths[col])
            when (col) {
                0 -> def.align = Align.ALIGN_CENTER_CENTER
                4, 5 -> {
                    def.align = Align.ALIGN_RIGHT_CENTER
                    def.dataType = ColumnDataType.COLUMN_DATA_CURRENCY
                    def.format = "$#,##0"
                }
                6 -> {
                    def.align = Align.ALIGN_CENTER_CENTER
                    def.dataType = ColumnDataType.COLUMN_DATA_NUMBER
                }
                7 -> {
                    def.align = Align.ALIGN_CENTER_CENTER
                    def.dataType = ColumnDataType.COLUMN_DATA_BOOLEAN
                }
                8 -> def.dropdownItems = SALES_STATUS_ITEMS
            }
            if (col == 0 || col == 1) {
                def.span = true
            }
            builder.addColumns(def.build())
        }
        return builder.build()
    }

    private fun applySalesSubtotalDecorations(controller: VolvoxGridController) {
        controller.setSpanCol(0, true)
        controller.setSpanCol(1, true)

        val updates = UpdateCellsRequest.newBuilder()
        for (row in 0 until controller.rowCount()) {
            val product = controller.getCellText(row, 3)
            val sales = controller.getCellText(row, 4)
            val cost = controller.getCellText(row, 5)
            val isSubtotal = product.isEmpty() && (sales.isNotEmpty() || cost.isNotEmpty())
            if (!isSubtotal) {
                val margin = parseSalesMarginPercent(controller.getCellText(row, 6))
                updates.addCells(
                    CellUpdate.newBuilder()
                        .setRow(row)
                        .setCol(6)
                        .setStyle(salesProgressStyle(margin))
                        .build()
                )
                val flagged = parseSalesFlag(controller.getCellText(row, 7))
                updates.addCells(
                    CellUpdate.newBuilder()
                        .setRow(row)
                        .setCol(7)
                        .setValue(CellValue.newBuilder().setFlag(flagged).build())
                        .setChecked(
                            if (flagged) CheckedState.CHECKED_CHECKED else CheckedState.CHECKED_UNCHECKED
                        )
                        .build()
                )
                updates.addCells(
                    CellUpdate.newBuilder()
                        .setRow(row)
                        .setCol(8)
                        .setDropdownItems(SALES_STATUS_ITEMS)
                        .build()
                )
                continue
            }
            if (sales.isEmpty() && cost.isEmpty()) {
                continue
            }

            updates.addCells(
                CellUpdate.newBuilder()
                    .setRow(row)
                    .setCol(7)
                    .setValue(CellValue.newBuilder().setFlag(false).build())
                    .setChecked(CheckedState.CHECKED_GRAYED)
                    .build()
            )

            val salesValue = sales.trim().toLongOrNull() ?: 0L
            val costValue = cost.trim().toLongOrNull() ?: 0L
            val margin = if (salesValue > 0L) {
                ((salesValue - costValue) * 100.0) / salesValue
            } else {
                0.0
            }
            updates.addCells(
                CellUpdate.newBuilder()
                    .setRow(row)
                    .setCol(6)
                    .setValue(
                        CellValue.newBuilder()
                            .setText(String.format(Locale.US, "%.1f", margin))
                            .build()
                    )
                    .setStyle(salesProgressStyle(margin))
                    .build()
            )

            if (controller.getNode(row).level <= 0) {
                controller.mergeCells(row, 0, row, 1)
            }
        }
        if (updates.cellsCount > 0) {
            controller.updateCells(updates.build())
        }
    }

    private fun parseSalesFlag(text: String): Boolean {
        return when (text.trim().lowercase(Locale.US)) {
            "1", "true", "yes", "y", "on", "checked" -> true
            else -> false
        }
    }

    private fun parseSalesMarginPercent(text: String): Double {
        return text.trim().replace(",", "").toDoubleOrNull() ?: 0.0
    }

    private fun salesProgressStyle(marginPercent: Double): CellStyle {
        return CellStyle.newBuilder()
            .setProgress((marginPercent / 100.0).coerceIn(0.0, 1.0).toFloat())
            .setProgressColor(ACCENT)
            .build()
    }

    private fun salesThemeConfig(): GridConfig {
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
                                    .setBackground(HOVER_ROW_BG)
                                    .build()
                            )
                            .setColumnStyle(
                                HighlightStyle.newBuilder()
                                    .setBackground(HOVER_ROW_BG)
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
                    .setCellSpanCompare(1)
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
                        io.github.ivere27.volvoxgrid.FreezePolicy.newBuilder()
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
                            .setModeBits(RowIndicatorMode.ROW_INDICATOR_NUMBERS.number)
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
                                ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT.number or
                                    ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH.number
                            )
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
