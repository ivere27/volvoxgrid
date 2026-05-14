package io.github.ivere27.volvoxgrid.example

import io.github.ivere27.volvoxgrid.Align
import io.github.ivere27.volvoxgrid.ColumnDataType
import io.github.ivere27.volvoxgrid.ColumnDef
import io.github.ivere27.volvoxgrid.DefineColumnsRequest
import io.github.ivere27.volvoxgrid.DropdownItemLayout
import io.github.ivere27.volvoxgrid.GridConfig
import io.github.ivere27.volvoxgrid.GroupTotalPosition
import io.github.ivere27.volvoxgrid.ListEditorParams
import io.github.ivere27.volvoxgrid.ListItem
import io.github.ivere27.volvoxgrid.LoadDataOptions
import io.github.ivere27.volvoxgrid.LoadDataStatus
import io.github.ivere27.volvoxgrid.OutlineConfig
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
    private const val GRAND_TOTAL_BACK_COLOR = 0xFFEEF2FFL
    private const val QUARTER_SUBTOTAL_BACK_COLOR = 0xFFF5F3FFL
    private const val REGION_SUBTOTAL_BACK_COLOR = 0xFFF8F7FFL
    private const val MARGIN_PROGRESS_COLOR = 0xFF818CF8.toInt()

    private val salesStatusItems = listOf("Active", "Pending", "Shipped", "Returned", "Cancelled")
    private val widths = intArrayOf(40, 80, 100, 120, 90, 90, 70, 56, 80, 140)
    private val captions = arrayOf(
        "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin%", "Flag", "Status", "Notes"
    )
    private val keys = arrayOf(
        "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin", "Flag", "Status", "Notes"
    )

    fun load(controller: VolvoxGridController) {
        controller.themePreset = ThemePreset.THEME_LIGHT
        controller.setShowRowIndicator(true)
        controller.configure(
            GridConfig.newBuilder()
                .setOutline(
                    OutlineConfig.newBuilder()
                        .setTreeIndicator(TreeIndicatorStyle.TREE_INDICATOR_NONE)
                        .setGroupTotalPosition(GroupTotalPosition.GROUP_TOTAL_BELOW)
                        .setMultiTotals(true)
                        .build()
                )
                .build()
        )

        controller.setColCount(widths.size)
        controller.defineColumns(salesColumnRequest())
        val result = controller.loadData(
            controller.getDemoData("sales"),
            LoadDataOptions.newBuilder()
                .setAutoCreateColumns(false)
                .build()
        )
        check(result.status != LoadDataStatus.LOAD_FAILED) { "LoadData failed for embedded sales demo" }
        controller.setColDropdown(STATUS_COL, salesStatusDropdown())
        controller.setSpanCol(QUARTER_COL, true)
        controller.setSpanCol(REGION_COL, true)

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
        controller.autoSize(SALES_COL, COST_COL)
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
