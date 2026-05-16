package io.github.ivere27.volvoxgrid.example

import io.github.ivere27.volvoxgrid.Align
import io.github.ivere27.volvoxgrid.CellSpanMode
import io.github.ivere27.volvoxgrid.ColumnDataType
import io.github.ivere27.volvoxgrid.ColumnDef
import io.github.ivere27.volvoxgrid.DefineColumnsRequest
import io.github.ivere27.volvoxgrid.DropdownItemLayout
import io.github.ivere27.volvoxgrid.GridConfig
import io.github.ivere27.volvoxgrid.GroupTotalPosition
import io.github.ivere27.volvoxgrid.IndicatorsConfig
import io.github.ivere27.volvoxgrid.LayoutConfig
import io.github.ivere27.volvoxgrid.ListEditorParams
import io.github.ivere27.volvoxgrid.ListItem
import io.github.ivere27.volvoxgrid.LoadDataOptions
import io.github.ivere27.volvoxgrid.LoadDataStatus
import io.github.ivere27.volvoxgrid.OutlineConfig
import io.github.ivere27.volvoxgrid.RowIndicatorConfig
import io.github.ivere27.volvoxgrid.RowIndicatorSlot
import io.github.ivere27.volvoxgrid.RowIndicatorSlotKind
import io.github.ivere27.volvoxgrid.SpanConfig
import io.github.ivere27.volvoxgrid.ThemePreset
import io.github.ivere27.volvoxgrid.TreeIndicatorStyle
import io.github.ivere27.volvoxgrid.VolvoxGridController
import io.github.ivere27.volvoxgrid.VolvoxGridSubtotalLevel

object SalesJsonDemo {
    private const val QUARTER_COL = 0
    private const val REGION_COL = 1
    private const val SALES_COL = 4
    private const val COST_COL = 5
    private const val MARGIN_COL = 6
    private const val FLAG_COL = 7
    private const val STATUS_COL = 8
    private const val FROZEN_COLS = REGION_COL + 1
    private const val ROW_INDICATOR_WIDTH = 40
    private const val GRAND_TOTAL_BACK_COLOR = 0xFFEEF2FFL
    private const val QUARTER_SUBTOTAL_BACK_COLOR = 0xFFF5F3FFL
    private const val REGION_SUBTOTAL_BACK_COLOR = 0xFFF8F7FFL
    private const val MARGIN_PROGRESS_COLOR = 0xFF818CF8.toInt()

    private val salesStatusItems = listOf("Active", "Pending", "Shipped", "Returned", "Cancelled")
    private val captions = arrayOf(
        "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin%", "Flag", "Status", "Notes"
    )
    private val keys = arrayOf(
        "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin", "Flag", "Status", "Notes"
    )

    fun load(controller: VolvoxGridController) {
        controller.themePreset = ThemePreset.THEME_LIGHT
        controller.configure(
            GridConfig.newBuilder()
                .setLayout(
                    LayoutConfig.newBuilder()
                        .setFrozenCols(FROZEN_COLS)
                        .build()
                )
                .setOutline(
                    OutlineConfig.newBuilder()
                        .setTreeIndicator(TreeIndicatorStyle.TREE_INDICATOR_NONE)
                        .setGroupTotalPosition(GroupTotalPosition.GROUP_TOTAL_BELOW)
                        .setMultiTotals(true)
                        .build()
                )
                .setSpan(
                    SpanConfig.newBuilder()
                        .setCellSpan(CellSpanMode.CELL_SPAN_ADJACENT)
                        .build()
                )
                .setIndicators(
                    IndicatorsConfig.newBuilder()
                        .setRowStart(
                            RowIndicatorConfig.newBuilder()
                                .setVisible(true)
                                .setWidth(ROW_INDICATOR_WIDTH)
                                .addSlots(
                                    RowIndicatorSlot.newBuilder()
                                        .setKind(RowIndicatorSlotKind.ROW_INDICATOR_SLOT_NUMBERS_DATA_ONLY)
                                        .build()
                                )
                                .build()
                        )
                        .build()
                )
                .build()
        )

        controller.setColCount(keys.size)
        controller.defineColumns(salesColumnRequest())
        val result = controller.loadData(
            controller.getDemoData("sales"),
            LoadDataOptions.newBuilder()
                .setAutoCreateColumns(false)
                .build()
        )
        check(result.status != LoadDataStatus.LOAD_FAILED) { "LoadData failed for embedded sales demo" }
        controller.setColDropdown(STATUS_COL, salesStatusDropdown())

        controller.addSubtotals(
            amountCols = listOf(SALES_COL, COST_COL),
            levels = listOf(
                VolvoxGridSubtotalLevel(caption = "Grand Total", backColor = GRAND_TOTAL_BACK_COLOR),
                VolvoxGridSubtotalLevel(groupCol = QUARTER_COL, backColor = QUARTER_SUBTOTAL_BACK_COLOR),
                VolvoxGridSubtotalLevel(groupCol = REGION_COL, backColor = REGION_SUBTOTAL_BACK_COLOR),
            ),
            mergeColFrom = QUARTER_COL,
            mergeColTo = REGION_COL,
        )
        controller.autoSize(0, keys.lastIndex)
    }

    private fun salesColumnRequest(): DefineColumnsRequest {
        val builder = DefineColumnsRequest.newBuilder()
        for (col in keys.indices) {
            val def = ColumnDef.newBuilder()
                .setIndex(col)
                .setCaption(captions[col])
                .setKey(keys[col])
            when (col) {
                QUARTER_COL -> def.align = Align.ALIGN_CENTER_CENTER
                SALES_COL, COST_COL -> {
                    def.align = Align.ALIGN_RIGHT_CENTER
                    def.dataType = ColumnDataType.COLUMN_DATA_CURRENCY
                    def.format = "$#,##0"
                }
                MARGIN_COL -> {
                    def.align = Align.ALIGN_CENTER_CENTER
                    def.dataType = ColumnDataType.COLUMN_DATA_NUMBER
                    def.progressColor = MARGIN_PROGRESS_COLOR
                }
                FLAG_COL -> {
                    def.align = Align.ALIGN_CENTER_CENTER
                    def.dataType = ColumnDataType.COLUMN_DATA_BOOLEAN
                }
            }
            if (col == QUARTER_COL || col == REGION_COL) {
                def.span = true
            }
            builder.addColumns(def.build())
        }
        return builder.build()
    }

    private fun salesStatusDropdown(): ListEditorParams {
        val list = ListEditorParams.newBuilder()
            .setItemLayout(DropdownItemLayout.DROPDOWN_ITEM_AUTO)
        for (label in salesStatusItems) {
            list.addStaticItems(ListItem.newBuilder().setLabel(label).build())
        }
        return list.build()
    }
}
