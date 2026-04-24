package io.github.ivere27.volvoxgrid

import io.github.ivere27.volvoxgrid.common.VolvoxGridController as VolvoxGridControllerContract
import io.github.ivere27.volvoxgrid.common.GridCellText
import io.github.ivere27.volvoxgrid.common.GridCellRange
import io.github.ivere27.volvoxgrid.common.GridSelection
import io.github.ivere27.volvoxgrid.common.RendererBackend

private const val DEFAULT_ROW_INDICATOR_WIDTH_PX = 35
private const val DEFAULT_COL_INDICATOR_BAND_ROWS = 1

private val DEFAULT_ROW_INDICATOR_MODE_BITS =
    RowIndicatorMode.ROW_INDICATOR_CURRENT.number or
        RowIndicatorMode.ROW_INDICATOR_SELECTION.number

private val DEFAULT_COL_INDICATOR_MODE_BITS =
    ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT.number or
        ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH.number

private fun defaultRowIndicatorStartConfig(): RowIndicatorConfig =
    RowIndicatorConfig.newBuilder()
        .setVisible(false)
        .setWidth(DEFAULT_ROW_INDICATOR_WIDTH_PX)
        .setModeBits(DEFAULT_ROW_INDICATOR_MODE_BITS)
        .build()

private fun defaultColIndicatorTopConfig(): ColIndicatorConfig =
    ColIndicatorConfig.newBuilder()
        .setVisible(true)
        .setBandRows(DEFAULT_COL_INDICATOR_BAND_ROWS)
        .setModeBits(DEFAULT_COL_INDICATOR_MODE_BITS)
        .build()

internal fun defaultIndicatorsConfig(): IndicatorsConfig =
    IndicatorsConfig.newBuilder()
        .setRowStart(defaultRowIndicatorStartConfig())
        .setColTop(defaultColIndicatorTopConfig())
        .build()

/**
 * High-level Kotlin API wrapping the VolvoxGrid FFI calls.
 *
 * Provides property-style access to grid configuration and convenience methods
 * for common operations like sorting, subtotals, and cell manipulation.
 *
 * Usage:
 * ```kotlin
 * val controller = view.createController()
 * controller.rowCount = 100
 * controller.colCount = 5
 * controller.setCellText(0, 0, "Header")
 * controller.sort(SortOrder.SORT_ASCENDING, col = 2)
 * ```
 */
class VolvoxGridController(
    private val service: VolvoxGridServiceFfi,
    private val gridId: Long
) : VolvoxGridControllerContract {
    companion object {
        fun create(
            service: VolvoxGridServiceFfi,
            rows: Int = 50,
            cols: Int = 10,
            viewportWidth: Int = 800,
            viewportHeight: Int = 600,
            scale: Float = 1f
        ): VolvoxGridController {
            val req = CreateRequest.newBuilder()
                .setViewportWidth(viewportWidth)
                .setViewportHeight(viewportHeight)
                .setScale(scale)
                .setConfig(
                    GridConfig.newBuilder()
                        .setLayout(
                            LayoutConfig.newBuilder()
                                .setRows(rows)
                                .setCols(cols)
                                .build()
                        )
                        .setRendering(
                            RenderConfig.newBuilder()
                                .setFramePacingMode(FramePacingMode.FRAME_PACING_MODE_PLATFORM)
                                .build()
                        )
                        .setIndicators(defaultIndicatorsConfig())
                        .build()
                )
                .build()
            val response = service.Create(req)
            return VolvoxGridController(service, response.handle.id)
        }
    }

    private fun handle(): GridHandle = GridHandle.newBuilder().setId(gridId).build()

    private fun buildSingleRangeSelectRequest(
        activeRow: Int,
        activeCol: Int,
        rowEnd: Int = activeRow,
        colEnd: Int = activeCol,
        show: Boolean = false,
    ): SelectRequest {
        return buildSelectRequest(
            activeRow,
            activeCol,
            listOf(
                CellRange.newBuilder()
                    .setRow1(minOf(activeRow, rowEnd))
                    .setCol1(minOf(activeCol, colEnd))
                    .setRow2(maxOf(activeRow, rowEnd))
                    .setCol2(maxOf(activeCol, colEnd))
                    .build()
            ),
            show,
        )
    }

    private fun buildSelectRequest(
        activeRow: Int,
        activeCol: Int,
        ranges: Iterable<CellRange>,
        show: Boolean = false,
    ): SelectRequest {
        return SelectRequest.newBuilder()
            .setGridId(gridId)
            .setActiveRow(activeRow)
            .setActiveCol(activeCol)
            .addAllRanges(ranges)
            .setShow(show)
            .build()
    }

    private fun selectionEnd(sel: SelectionState): Pair<Int, Int> {
        if (sel.rangesCount <= 0) return Pair(sel.activeRow, sel.activeCol)
        val r = sel.rangesList.firstOrNull {
            (it.row1 == sel.activeRow && it.col1 == sel.activeCol)
                || (it.row2 == sel.activeRow && it.col2 == sel.activeCol)
        } ?: sel.getRanges(0)
        return if (r.row1 == sel.activeRow && r.col1 == sel.activeCol) {
            Pair(r.row2, r.col2)
        } else if (r.row2 == sel.activeRow && r.col2 == sel.activeCol) {
            Pair(r.row1, r.col1)
        } else {
            Pair(r.row2, r.col2)
        }
    }

    private fun selectionRanges(sel: SelectionState): Array<GridCellRange> =
        sel.rangesList.map { GridCellRange(it.row1, it.col1, it.row2, it.col2) }.toTypedArray()

    fun configure(config: GridConfig) {
        service.Configure(
            ConfigureRequest.newBuilder()
                .setGridId(gridId)
                .setConfig(config)
                .build()
        )
    }

    fun getConfig(): GridConfig {
        return service.GetConfig(handle())
    }

    fun destroy() {
        service.Destroy(handle())
    }

    // =========================================================================
    // Grid Dimensions
    // =========================================================================

    private var layoutRowCount: Int
        get() = getConfig().layout.rows
        set(value) {
            configure(GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setRows(value).build())
                .build())
        }

    private var layoutColCount: Int
        get() = getConfig().layout.cols
        set(value) {
            configure(GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setCols(value).build())
                .build())
        }

    private var layoutFrozenRowCount: Int
        get() = getConfig().layout.frozenRows
        set(value) {
            configure(GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setFrozenRows(value).build())
                .build())
        }

    private var layoutFrozenColCount: Int
        get() = getConfig().layout.frozenCols
        set(value) {
            configure(GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setFrozenCols(value).build())
                .build())
        }

    override fun getShowColumnHeaders(): Boolean {
        val config = getConfig()
        if (!config.hasIndicators() || !config.indicators.hasColTop()) {
            return false
        }
        return config.indicators.colTop.visible
    }

    override fun setShowColumnHeaders(value: Boolean) {
        configure(GridConfig.newBuilder()
            .setIndicators(
                IndicatorsConfig.newBuilder()
                    .setColTop(
                        ColIndicatorConfig.newBuilder()
                            .setVisible(value)
                            .build()
                    )
                    .build()
            )
            .build())
    }

    override fun getColumnIndicatorTopModeBits(): Int {
        val config = getConfig()
        if (!config.hasIndicators() || !config.indicators.hasColTop()) {
            return 0
        }
        return config.indicators.colTop.modeBits
    }

    override fun setColumnIndicatorTopModeBits(value: Int) {
        configure(GridConfig.newBuilder()
            .setIndicators(
                IndicatorsConfig.newBuilder()
                    .setColTop(
                        ColIndicatorConfig.newBuilder()
                            .setModeBits(value)
                            .build()
                    )
                    .build()
            )
            .build())
    }

    override fun getColumnIndicatorTopRowCount(): Int {
        val config = getConfig()
        if (!config.hasIndicators() || !config.indicators.hasColTop()) {
            return 0
        }
        return config.indicators.colTop.bandRows
    }

    override fun setColumnIndicatorTopRowCount(value: Int) {
        val normalized = value.coerceAtLeast(0)
        configure(GridConfig.newBuilder()
            .setIndicators(
                IndicatorsConfig.newBuilder()
                    .setColTop(
                        ColIndicatorConfig.newBuilder()
                            .setBandRows(normalized)
                            .build()
                    )
                    .build()
            )
            .build())
    }

    override fun getShowRowIndicator(): Boolean {
        val config = getConfig()
        if (!config.hasIndicators() || !config.indicators.hasRowStart()) {
            return false
        }
        return config.indicators.rowStart.visible
    }

    override fun setShowRowIndicator(value: Boolean) {
        configure(GridConfig.newBuilder()
            .setIndicators(
                IndicatorsConfig.newBuilder()
                    .setRowStart(
                        RowIndicatorConfig.newBuilder()
                            .setVisible(value)
                            .build()
                    )
                    .build()
            )
            .build())
    }

    override fun getRowIndicatorStartModeBits(): Int {
        val config = getConfig()
        if (!config.hasIndicators() || !config.indicators.hasRowStart()) {
            return 0
        }
        return config.indicators.rowStart.modeBits
    }

    override fun setRowIndicatorStartModeBits(value: Int) {
        configure(GridConfig.newBuilder()
            .setIndicators(
                IndicatorsConfig.newBuilder()
                    .setRowStart(
                        RowIndicatorConfig.newBuilder()
                            .setModeBits(value)
                            .build()
                    )
                    .build()
            )
            .build())
    }

    override fun getRowIndicatorStartWidth(): Int {
        val config = getConfig()
        if (!config.hasIndicators() || !config.indicators.hasRowStart()) {
            return DEFAULT_ROW_INDICATOR_WIDTH_PX
        }
        return config.indicators.rowStart.width
    }

    override fun setRowIndicatorStartWidth(value: Int) {
        configure(GridConfig.newBuilder()
            .setIndicators(
                IndicatorsConfig.newBuilder()
                    .setRowStart(
                        RowIndicatorConfig.newBuilder()
                            .setWidth(value.coerceAtLeast(1))
                            .build()
                    )
                    .build()
            )
            .build())
    }

    override fun rowCount(): Int = layoutRowCount

    override fun setRowCount(value: Int) {
        layoutRowCount = value
    }

    override fun colCount(): Int = layoutColCount

    override fun setColCount(value: Int) {
        layoutColCount = value
    }

    override fun frozenRowCount(): Int = layoutFrozenRowCount

    override fun setFrozenRowCount(value: Int) {
        layoutFrozenRowCount = value
    }

    override fun frozenColCount(): Int = layoutFrozenColCount

    override fun setFrozenColCount(value: Int) {
        layoutFrozenColCount = value
    }

    // =========================================================================
    // Cell Data
    // =========================================================================

    override fun setCellText(row: Int, col: Int, text: String) {
        service.UpdateCells(
            UpdateCellsRequest.newBuilder()
                .setGridId(gridId)
                .addCells(CellUpdate.newBuilder()
                    .setRow(row)
                    .setCol(col)
                    .setValue(CellValue.newBuilder().setText(text).build())
                    .build())
                .build()
        )
    }

    override fun getCellText(row: Int, col: Int): String {
        val resp = service.GetCells(
            GetCellsRequest.newBuilder()
                .setGridId(gridId)
                .setRow1(row)
                .setCol1(col)
                .setRow2(row)
                .setCol2(col)
                .build()
        )
        return if (resp.cellsCount > 0 && resp.getCells(0).value.hasText()) {
            resp.getCells(0).value.text
        } else ""
    }

    fun setCellTextEntries(cells: List<Triple<Int, Int, String>>) {
        val builder = UpdateCellsRequest.newBuilder().setGridId(gridId)
        for ((row, col, text) in cells) {
            builder.addCells(CellUpdate.newBuilder()
                .setRow(row)
                .setCol(col)
                .setValue(CellValue.newBuilder().setText(text).build())
                .build())
        }
        service.UpdateCells(builder.build())
    }

    override fun setCells(cells: List<GridCellText>) {
        val builder = UpdateCellsRequest.newBuilder().setGridId(gridId)
        for (cell in cells) {
            builder.addCells(CellUpdate.newBuilder()
                .setRow(cell.row)
                .setCol(cell.col)
                .setValue(CellValue.newBuilder().setText(cell.text).build())
                .build())
        }
        service.UpdateCells(builder.build())
    }

    fun setText(text: String) {
        val sel = service.GetSelection(handle())
        setCellText(sel.activeRow, sel.activeCol, text)
    }

    fun loadTable(rows: Int, cols: Int, values: List<CellValue>, atomic: Boolean = false) {
        service.LoadTable(
            LoadTableRequest.newBuilder()
                .setGridId(gridId)
                .setRows(rows)
                .setCols(cols)
                .addAllValues(values)
                .setAtomic(atomic)
                .build()
        )
    }

    fun getText(): String {
        val sel = service.GetSelection(handle())
        return getCellText(sel.activeRow, sel.activeCol)
    }

    // =========================================================================
    // Row / Column Sizing
    // =========================================================================

    override fun setRowHeight(row: Int, height: Int) {
        service.DefineRows(
            DefineRowsRequest.newBuilder()
                .setGridId(gridId)
                .addRows(RowDef.newBuilder()
                    .setIndex(row)
                    .setHeight(height)
                    .build())
                .build()
        )
    }

    override fun setColWidth(col: Int, width: Int) {
        service.DefineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder()
                    .setIndex(col)
                    .setWidth(width)
                    .build())
                .build()
        )
    }

    fun setColumnCaption(col: Int, caption: String) {
        service.DefineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder()
                    .setIndex(col)
                    .setCaption(caption)
                    .build())
                .build()
        )
    }

    fun defineColumns(request: DefineColumnsRequest) {
        service.DefineColumns(request.toBuilder().setGridId(gridId).build())
    }

    fun defineRows(request: DefineRowsRequest) {
        service.DefineRows(request.toBuilder().setGridId(gridId).build())
    }

    fun updateCells(request: UpdateCellsRequest): WriteResult {
        return service.UpdateCells(request.toBuilder().setGridId(gridId).build())
    }

    fun getRowHeight(row: Int): Int {
        return getConfig().layout.defaultRowHeight
    }

    fun getColWidth(col: Int): Int {
        return getConfig().layout.defaultColWidth
    }

    // =========================================================================
    // Row / Column Structure
    // =========================================================================

    fun insertRows(index: Int, count: Int = 1, text: List<String> = emptyList()) {
        val builder = InsertRowsRequest.newBuilder()
            .setGridId(gridId)
            .setIndex(index)
            .setCount(count)
        if (text.isNotEmpty()) {
            builder.addAllText(text)
        }
        service.InsertRows(builder.build())
    }

    fun removeRows(index: Int, count: Int = 1) {
        service.RemoveRows(
            RemoveRowsRequest.newBuilder()
                .setGridId(gridId)
                .setIndex(index)
                .setCount(count)
                .build()
        )
    }

    fun moveColumn(col: Int, position: Int) {
        service.MoveColumn(
            MoveColumnRequest.newBuilder()
                .setGridId(gridId)
                .setCol(col)
                .setPosition(position)
                .build()
        )
    }

    fun moveRow(row: Int, position: Int) {
        service.MoveRow(
            MoveRowRequest.newBuilder()
                .setGridId(gridId)
                .setRow(row)
                .setPosition(position)
                .build()
        )
    }

    // =========================================================================
    // Selection
    // =========================================================================

    override fun cursorRow(): Int = service.GetSelection(handle()).activeRow

    override fun setCursorRow(value: Int) {
        val currentCol = try {
            service.GetSelection(handle()).activeCol
        } catch (_: Exception) {
            0
        }
        service.Select(buildSingleRangeSelectRequest(value, currentCol, value, currentCol))
    }

    override fun cursorCol(): Int = service.GetSelection(handle()).activeCol

    override fun setCursorCol(value: Int) {
        val currentRow = try {
            service.GetSelection(handle()).activeRow
        } catch (_: Exception) {
            0
        }
        service.Select(buildSingleRangeSelectRequest(currentRow, value, currentRow, value))
    }

    override fun selectRange(row1: Int, col1: Int, row2: Int, col2: Int) {
        service.Select(buildSingleRangeSelectRequest(row1, col1, row2, col2))
    }

    override fun selectRanges(ranges: List<GridCellRange>) {
        if (ranges.isEmpty()) return
        val active = ranges[0]
        selectRanges(ranges, active.row1, active.col1)
    }

    override fun selectRanges(ranges: List<GridCellRange>, activeRow: Int, activeCol: Int) {
        if (ranges.isEmpty()) return
        service.Select(buildSelectRequest(
            activeRow,
            activeCol,
            ranges.map {
                CellRange.newBuilder()
                    .setRow1(minOf(it.row1, it.row2))
                    .setCol1(minOf(it.col1, it.col2))
                    .setRow2(maxOf(it.row1, it.row2))
                    .setCol2(maxOf(it.col1, it.col2))
                    .build()
            },
        ))
    }

    fun selectionState(): SelectionState {
        return service.GetSelection(handle())
    }

    override fun getSelection(): GridSelection {
        val sel = selectionState()
        val (rowEnd, colEnd) = selectionEnd(sel)
        return GridSelection(
            sel.activeRow,
            sel.activeCol,
            rowEnd,
            colEnd,
            sel.topRow,
            sel.leftCol,
            sel.bottomRow,
            sel.rightCol,
            sel.mouseRow,
            sel.mouseCol,
            selectionRanges(sel)
        )
    }

    override fun clearSelection() {
        val sel = selectionState()
        service.Select(
            buildSingleRangeSelectRequest(
                sel.activeRow,
                sel.activeCol,
                sel.activeRow,
                sel.activeCol
            )
        )
    }

    override fun showCell(row: Int, col: Int) {
        service.ShowCell(
            ShowCellRequest.newBuilder()
                .setGridId(gridId)
                .setRow(row)
                .setCol(col)
                .build()
        )
    }

    fun setSelectionMode(mode: SelectionMode) {
        configure(GridConfig.newBuilder()
            .setSelection(SelectionConfig.newBuilder().setMode(mode).build())
            .build())
    }

    fun setSelectionVisibility(style: SelectionVisibility) {
        configure(GridConfig.newBuilder()
            .setSelection(SelectionConfig.newBuilder().setVisibility(style).build())
            .build())
    }

    fun setSelectionStyle(style: HighlightStyle) {
        configure(GridConfig.newBuilder()
            .setSelection(SelectionConfig.newBuilder().setStyle(style).build())
            .build())
    }

    fun setHoverConfig(config: HoverConfig) {
        configure(GridConfig.newBuilder()
            .setSelection(SelectionConfig.newBuilder().setHover(config).build())
            .build())
    }

    fun setActiveCellStyle(style: HighlightStyle) {
        configure(GridConfig.newBuilder()
            .setSelection(SelectionConfig.newBuilder().setActiveCellStyle(style).build())
            .build())
    }

    fun setFocusBorder(style: FocusBorderStyle) {
        configure(GridConfig.newBuilder()
            .setSelection(SelectionConfig.newBuilder().setFocusBorder(style).build())
            .build())
    }

    override fun setTopRow(value: Int) {
        service.SetTopRow(
            SetRowRequest.newBuilder()
                .setGridId(gridId)
                .setRow(value)
                .build()
        )
    }

    override fun topRow(): Int {
        return service.GetSelection(handle()).topRow
    }

    override fun setLeftCol(value: Int) {
        service.SetLeftCol(
            SetColRequest.newBuilder()
                .setGridId(gridId)
                .setCol(value)
                .build()
        )
    }

    override fun leftCol(): Int {
        return service.GetSelection(handle()).leftCol
    }

    // =========================================================================
    // Sorting
    // =========================================================================

    fun sort(order: SortOrder, col: Int = 0, type: SortType? = null) {
        val sortColumn = SortColumn.newBuilder().setCol(col).setOrder(order)
        if (type != null) {
            sortColumn.type = type
        }
        service.Sort(
            SortRequest.newBuilder()
                .setGridId(gridId)
                .addSortColumns(sortColumn)
                .build()
        )
    }

    /** Sort by multiple columns. */
    fun sortMulti(columns: List<Pair<Int, SortOrder>>, types: Map<Int, SortType> = emptyMap()) {
        val req = SortRequest.newBuilder().setGridId(gridId)
        for ((col, order) in columns) {
            val sortColumn = SortColumn.newBuilder().setCol(col).setOrder(order)
            types[col]?.let { sortColumn.type = it }
            req.addSortColumns(sortColumn)
        }
        service.Sort(req.build())
    }

    override fun sort(col: Int, ascending: Boolean) {
        sort(
            if (ascending) SortOrder.SORT_ASCENDING else SortOrder.SORT_DESCENDING,
            col
        )
    }

    fun setHeaderFeatures(features: HeaderFeatures) {
        configure(GridConfig.newBuilder()
            .setInteraction(InteractionConfig.newBuilder().setHeaderFeatures(features).build())
            .build())
    }

    fun setColSort(col: Int, order: SortOrder) {
        service.DefineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder()
                    .setIndex(col)
                    .setSortOrder(order)
                    .build())
                .build()
        )
    }

    // =========================================================================
    // Spanning
    // =========================================================================

    fun setCellSpanMode(mode: CellSpanMode) {
        configure(GridConfig.newBuilder()
            .setSpan(SpanConfig.newBuilder().setCellSpan(mode).build())
            .build())
    }

    fun setSpanCol(col: Int, span: Boolean) {
        service.DefineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder()
                    .setIndex(col)
                    .setSpan(span)
                    .build())
                .build()
        )
    }

    fun setSpanRow(row: Int, span: Boolean) {
        service.DefineRows(
            DefineRowsRequest.newBuilder()
                .setGridId(gridId)
                .addRows(RowDef.newBuilder()
                    .setIndex(row)
                    .setSpan(span)
                    .build())
                .build()
        )
    }

    // =========================================================================
    // Explicit Merging
    // =========================================================================

    fun mergeCells(row1: Int, col1: Int, row2: Int, col2: Int) {
        service.MergeCells(
            MergeCellsRequest.newBuilder()
                .setGridId(gridId)
                .setRange(CellRange.newBuilder()
                    .setRow1(row1)
                    .setCol1(col1)
                    .setRow2(row2)
                    .setCol2(col2)
                    .build())
                .build()
        )
    }

    fun unmergeCells(row1: Int, col1: Int, row2: Int, col2: Int) {
        service.UnmergeCells(
            UnmergeCellsRequest.newBuilder()
                .setGridId(gridId)
                .setRange(CellRange.newBuilder()
                    .setRow1(row1)
                    .setCol1(col1)
                    .setRow2(row2)
                    .setCol2(col2)
                    .build())
                .build()
        )
    }

    fun getMergedRegions(): MergedRegionsResponse {
        return service.GetMergedRegions(
            GridHandle.newBuilder()
                .setId(gridId)
                .build()
        )
    }

    // =========================================================================
    // Subtotals & Outlining
    // =========================================================================

    fun subtotal(
        aggregateType: AggregateType,
        groupOnCol: Int,
        aggregateCol: Int,
        caption: String = "",
        backColor: Long = 0xFFE0E0E0.toLong(),
        foreColor: Long = 0xFF000000.toLong(),
        addOutline: Boolean = true,
        font: Font? = null
    ): SubtotalResult {
        val builder = SubtotalRequest.newBuilder()
            .setGridId(gridId)
            .setAggregate(aggregateType)
            .setGroupOnCol(groupOnCol)
            .setAggregateCol(aggregateCol)
            .setCaption(caption)
            .setBackground(backColor.toInt())
            .setForeground(foreColor.toInt())
            .setAddOutline(addOutline)
        if (font != null) {
            builder.font = font
        }
        return service.Subtotal(builder.build())
    }

    fun setTreeIndicator(style: TreeIndicatorStyle) {
        configure(GridConfig.newBuilder()
            .setOutline(OutlineConfig.newBuilder().setTreeIndicator(style).build())
            .build())
    }

    fun outline(level: Int) {
        service.Outline(
            OutlineRequest.newBuilder()
                .setGridId(gridId)
                .setLevel(level)
                .build()
        )
    }

    fun setRowOutlineLevel(row: Int, level: Int) {
        service.DefineRows(
            DefineRowsRequest.newBuilder()
                .setGridId(gridId)
                .addRows(RowDef.newBuilder()
                    .setIndex(row)
                    .setOutlineLevel(level)
                    .build())
                .build()
        )
    }

    fun setIsSubtotal(row: Int, isSubtotal: Boolean) {
        service.DefineRows(
            DefineRowsRequest.newBuilder()
                .setGridId(gridId)
                .addRows(RowDef.newBuilder()
                    .setIndex(row)
                    .setIsSubtotal(isSubtotal)
                    .build())
                .build()
        )
    }

    fun setColDropdownItems(col: Int, list: String) {
        service.DefineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder()
                    .setIndex(col)
                    .setDropdownItems(list)
                    .build())
                .build()
        )
    }

    // =========================================================================
    // Editing
    // =========================================================================

    fun editable(): Boolean = editTrigger() != EditTrigger.EDIT_TRIGGER_NONE

    fun setEditable(value: Boolean) {
        val current = editTrigger()
        val target = if (value) {
            if (current == EditTrigger.EDIT_TRIGGER_NONE) {
                EditTrigger.EDIT_TRIGGER_KEY_CLICK
            } else {
                current
            }
        } else {
            EditTrigger.EDIT_TRIGGER_NONE
        }
        setEditTrigger(target)
    }

    fun editTrigger(): EditTrigger {
        val config = getConfig()
        if (!config.hasEditing()) {
            return EditTrigger.EDIT_TRIGGER_NONE
        }
        return config.editing.trigger
    }

    fun setEditTrigger(mode: EditTrigger) {
        configure(GridConfig.newBuilder()
            .setEditing(EditConfig.newBuilder().setTrigger(mode).build())
            .build())
    }

    fun beginEdit(row: Int, col: Int) {
        service.Edit(
            EditCommand.newBuilder()
                .setGridId(gridId)
                .setStart(EditStart.newBuilder().setRow(row).setCol(col).build())
                .build()
        )
    }

    fun commitEdit(text: String? = null) {
        val commit = EditCommit.newBuilder()
        if (text != null) {
            commit.setText(text)
        }
        service.Edit(
            EditCommand.newBuilder()
                .setGridId(gridId)
                .setCommit(commit.build())
                .build()
        )
    }

    fun cancelEdit() {
        service.Edit(
            EditCommand.newBuilder()
                .setGridId(gridId)
                .setCancel(EditCancel.newBuilder().build())
                .build()
        )
    }

    // =========================================================================
    // Styling
    // =========================================================================

    fun setGridStyle(style: StyleConfig) {
        configure(GridConfig.newBuilder()
            .setStyle(style)
            .build())
    }

    fun getGridStyle(): StyleConfig {
        return getConfig().style
    }

    fun setCellStyleRange(row1: Int, col1: Int, row2: Int, col2: Int, style: CellStyle) {
        val builder = UpdateCellsRequest.newBuilder().setGridId(gridId)
        for (r in row1..row2) {
            for (c in col1..col2) {
                builder.addCells(CellUpdate.newBuilder()
                    .setRow(r)
                    .setCol(c)
                    .setStyle(style)
                    .build())
            }
        }
        service.UpdateCells(builder.build())
    }

    fun setColAlignment(col: Int, alignment: Align) {
        service.DefineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder()
                    .setIndex(col)
                    .setAlign(alignment)
                    .build())
                .build()
        )
    }

    fun setColFormat(col: Int, format: String) {
        service.DefineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder()
                    .setIndex(col)
                    .setFormat(format)
                    .build())
                .build()
        )
    }

    fun setColDataType(col: Int, dataType: ColumnDataType) {
        service.DefineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder()
                    .setIndex(col)
                    .setDataType(dataType)
                    .build())
                .build()
        )
    }

    fun setColKey(col: Int, key: String) {
        service.DefineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder()
                    .setIndex(col)
                    .setKey(key)
                    .build())
                .build()
        )
    }

    // =========================================================================
    // Appearance
    // =========================================================================

    fun setWordWrap(enabled: Boolean) {
        configure(GridConfig.newBuilder()
            .setStyle(StyleConfig.newBuilder().setWordWrap(enabled).build())
            .build())
    }

    fun setEllipsis(enabled: Boolean) {
        setEllipsisMode(if (enabled) 1 else 0)
    }

    fun setEllipsisMode(mode: Int) {
        configure(GridConfig.newBuilder()
            .setStyle(StyleConfig.newBuilder().setEllipsis(mode.coerceIn(0, 2)).build())
            .build())
    }

    fun setExtendLastCol(enabled: Boolean) {
        configure(GridConfig.newBuilder()
            .setLayout(LayoutConfig.newBuilder().setExtendLastCol(enabled).build())
            .build())
    }

    fun setResizePolicy(policy: ResizePolicy) {
        configure(GridConfig.newBuilder()
            .setInteraction(InteractionConfig.newBuilder().setResize(policy).build())
            .build())
    }

    fun setScrollBars(mode: ScrollBarsMode) {
        configure(GridConfig.newBuilder()
            .setScrolling(ScrollConfig.newBuilder().setScrollbars(mode).build())
            .build())
    }

    fun setFlingEnabled(enabled: Boolean) {
        configure(GridConfig.newBuilder()
            .setScrolling(ScrollConfig.newBuilder().setFlingEnabled(enabled).build())
            .build())
    }

    fun setFlingImpulseGain(gain: Float) {
        if (!gain.isFinite()) return
        configure(GridConfig.newBuilder()
            .setScrolling(ScrollConfig.newBuilder()
                .setFlingImpulseGain(gain.coerceAtLeast(0f))
                .build())
            .build())
    }

    fun setFlingFriction(friction: Float) {
        if (!friction.isFinite()) return
        configure(GridConfig.newBuilder()
            .setScrolling(ScrollConfig.newBuilder()
                .setFlingFriction(friction.coerceIn(0.1f, 20f))
                .build())
            .build())
    }

    fun autoSize(colFrom: Int = 0, colTo: Int = -1, equal: Boolean = false, maxWidth: Int = 0) {
        service.AutoSize(
            AutoSizeRequest.newBuilder()
                .setGridId(gridId)
                .setColFrom(colFrom)
                .setColTo(colTo)
                .setEqual(equal)
                .setMaxWidth(maxWidth)
                .build()
        )
    }

    // =========================================================================
    // Redraw Control
    // =========================================================================

    override fun setRedraw(enabled: Boolean) {
        service.SetRedraw(
            SetRedrawRequest.newBuilder()
                .setGridId(gridId)
                .setEnabled(enabled)
                .build()
        )
    }

    /**
     * Run [action] while redraw is suspended, then re-enable and refresh.
     *
     * This avoids per-call repaints when making many changes in a batch,
     * resulting in a single repaint at the end.
     *
     * ```kotlin
     * ctrl.withRedrawSuspended {
     *     ctrl.setCellText(0, 0, "A")
     *     ctrl.setCellText(0, 1, "B")
     *     ctrl.setCellText(1, 0, "C")
     * }
     * ```
     */
    inline fun <T> withRedrawSuspended(refreshAfter: Boolean = true, action: () -> T): T {
        setRedraw(false)
        try {
            return action()
        } finally {
            setRedraw(true)
            if (refreshAfter) {
                refresh()
            }
        }
    }

    fun setDebugOverlay(enabled: Boolean) {
        configure(GridConfig.newBuilder()
            .setRendering(RenderConfig.newBuilder().setDebugOverlay(enabled).build())
            .build())
    }

    fun setAnimationEnabled(enabled: Boolean, durationMs: Int = 0) {
        val rc = RenderConfig.newBuilder().setAnimationEnabled(enabled)
        if (durationMs > 0) rc.setAnimationDurationMs(durationMs)
        configure(GridConfig.newBuilder()
            .setRendering(rc.build())
            .build())
    }

    fun setScrollBlit(enabled: Boolean) {
        configure(GridConfig.newBuilder()
            .setRendering(RenderConfig.newBuilder().setScrollBlit(enabled).build())
            .build())
    }

    fun setTextLayoutCacheCap(cap: Int) {
        configure(GridConfig.newBuilder()
            .setRendering(
                RenderConfig.newBuilder()
                    .setTextLayoutCacheCap(cap.coerceAtLeast(0))
                    .build()
            )
            .build())
    }

    fun animationEnabled(): Boolean {
        return getConfig().rendering.animationEnabled
    }

    fun scrollBlitEnabled(): Boolean {
        return getConfig().rendering.scrollBlit
    }

    fun textLayoutCacheCap(): Int {
        return getConfig().rendering.textLayoutCacheCap
    }

    fun setRendererMode(mode: Int) {
        configure(GridConfig.newBuilder()
            .setRendering(RenderConfig.newBuilder()
                .setRendererModeValue(mode)
                .build())
            .build())
    }

    fun rendererMode(): Int {
        return getConfig().rendering.rendererModeValue
    }

    override fun setRenderLayerMask(mask: Long) {
        configure(GridConfig.newBuilder()
            .setRendering(
                RenderConfig.newBuilder()
                    .setRenderLayerMask(mask)
                    .build()
            )
            .build())
    }

    override fun renderLayerMask(): Long {
        return getConfig().rendering.renderLayerMask
    }

    override fun isRenderLayerEnabled(layer: RenderLayerBit): Boolean {
        val bit = 1L shl layer.number
        return (renderLayerMask() and bit) != 0L
    }

    override fun setRenderLayerEnabled(layer: RenderLayerBit, enabled: Boolean) {
        val mask = renderLayerMask()
        val bit = 1L shl layer.number
        val next = if (enabled) mask or bit else mask and bit.inv()
        if (next != mask) {
            setRenderLayerMask(next)
        }
    }

    override fun setRendererBackend(backend: RendererBackend) {
        when (backend) {
            RendererBackend.AUTO -> setRendererMode(0)
            RendererBackend.CPU -> setRendererMode(1)
            RendererBackend.GPU -> setRendererMode(2)
        }
    }

    override fun rendererBackend(): RendererBackend {
        return when (rendererMode()) {
            0 -> RendererBackend.AUTO
            1 -> RendererBackend.CPU
            else -> RendererBackend.GPU
        }
    }

    override fun refresh() {
        service.Refresh(handle())
    }

    // =========================================================================
    // Clipboard
    // =========================================================================

    fun copy(): ClipboardResponse {
        return service.Clipboard(
            ClipboardCommand.newBuilder()
                .setGridId(gridId)
                .setCopy(ClipboardCopy.newBuilder().build())
                .build()
        )
    }

    fun cut(): ClipboardResponse {
        return service.Clipboard(
            ClipboardCommand.newBuilder()
                .setGridId(gridId)
                .setCut(ClipboardCut.newBuilder().build())
                .build()
        )
    }

    fun paste(text: String) {
        service.Clipboard(
            ClipboardCommand.newBuilder()
                .setGridId(gridId)
                .setPaste(ClipboardPaste.newBuilder().setText(text).build())
                .build()
        )
    }

    fun delete() {
        service.Clipboard(
            ClipboardCommand.newBuilder()
                .setGridId(gridId)
                .setDelete(ClipboardDelete.newBuilder().build())
                .build()
        )
    }

    // =========================================================================
    // Pin & Sticky
    // =========================================================================

    /** Pin a row to top (1), bottom (2), or unpin (0). */
    fun pinRow(row: Int, pin: PinPosition) {
        service.DefineRows(
            DefineRowsRequest.newBuilder()
                .setGridId(gridId)
                .addRows(RowDef.newBuilder()
                    .setIndex(row)
                    .setPin(pin)
                    .build())
                .build()
        )
    }

    /** Check if a row is pinned. Returns PIN_NONE, PIN_TOP, or PIN_BOTTOM. */
    fun isRowPinned(row: Int): PinPosition {
        // Pin state is not exposed via GetCells; show all options in context menu.
        return PinPosition.PIN_NONE
    }

    /** Set sticky edge for a row (STICKY_NONE, STICKY_TOP, STICKY_BOTTOM, STICKY_BOTH). */
    fun setRowSticky(row: Int, edge: StickyEdge) {
        service.DefineRows(
            DefineRowsRequest.newBuilder()
                .setGridId(gridId)
                .addRows(RowDef.newBuilder()
                    .setIndex(row)
                    .setSticky(edge)
                    .build())
                .build()
        )
    }

    /** Set sticky edge for a column (STICKY_NONE, STICKY_LEFT, STICKY_RIGHT, STICKY_BOTH). */
    fun setColSticky(col: Int, edge: StickyEdge) {
        service.DefineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder()
                    .setIndex(col)
                    .setSticky(edge)
                    .build())
                .build()
        )
    }

    // =========================================================================
    // Find
    // =========================================================================

    fun findRow(text: String, col: Int, startRow: Int = 0, caseSensitive: Boolean = false): Int {
        return service.Find(
            FindRequest.newBuilder()
                .setGridId(gridId)
                .setCol(col)
                .setStartRow(startRow)
                .setTextQuery(TextQuery.newBuilder()
                    .setText(text)
                    .setCaseSensitive(caseSensitive)
                    .setFullMatch(false)
                    .build())
                .build()
        ).row
    }

    fun findRowByRegex(pattern: String, col: Int, startRow: Int = 0): Int {
        return service.Find(
            FindRequest.newBuilder()
                .setGridId(gridId)
                .setCol(col)
                .setStartRow(startRow)
                .setRegexQuery(RegexQuery.newBuilder().setPattern(pattern).build())
                .build()
        ).row
    }

    fun getNode(row: Int, relation: NodeRelation? = null): NodeInfo {
        val builder = GetNodeRequest.newBuilder()
            .setGridId(gridId)
            .setRow(row)
        if (relation != null) {
            builder.relation = relation
        }
        return service.GetNode(builder.build())
    }

    // =========================================================================
    // Aggregate
    // =========================================================================

    fun aggregate(type: AggregateType, row1: Int, col1: Int, row2: Int, col2: Int): Double {
        return service.Aggregate(
            AggregateRequest.newBuilder()
                .setGridId(gridId)
                .setAggregate(type)
                .setRow1(row1)
                .setCol1(col1)
                .setRow2(row2)
                .setCol2(col2)
                .build()
        ).value
    }

    fun getMergedRange(row: Int, col: Int): CellRange {
        return service.GetMergedRange(
            GetMergedRangeRequest.newBuilder()
                .setGridId(gridId)
                .setRow(row)
                .setCol(col)
                .build()
        )
    }

    // =========================================================================
    // Save / Load
    // =========================================================================

    fun saveGrid(format: ExportFormat = ExportFormat.EXPORT_BINARY): ExportResponse {
        return service.Export(
            ExportRequest.newBuilder()
                .setGridId(gridId)
                .setFormat(format)
                .setScope(ExportScope.EXPORT_ALL)
                .build()
        )
    }

    fun loadData(data: ByteArray, options: LoadDataOptions? = null): LoadDataResult {
        val builder = LoadDataRequest.newBuilder()
            .setGridId(gridId)
            .setData(com.google.protobuf.ByteString.copyFrom(data))
        if (options != null) {
            builder.setOptions(options)
        }
        return service.LoadData(builder.build())
    }

    fun printGrid(
        orientation: PrintOrientation = PrintOrientation.PRINT_PORTRAIT,
        marginLeft: Int = 0,
        marginTop: Int = 0,
        marginRight: Int = 0,
        marginBottom: Int = 0,
        header: String = "",
        footer: String = "",
        showPageNumbers: Boolean = true
    ): PrintResponse {
        return service.Print(
            PrintRequest.newBuilder()
                .setGridId(gridId)
                .setOrientation(orientation)
                .setMarginLeft(marginLeft)
                .setMarginTop(marginTop)
                .setMarginRight(marginRight)
                .setMarginBottom(marginBottom)
                .setHeader(header)
                .setFooter(footer)
                .setShowPageNumbers(showPageNumbers)
                .build()
        )
    }

    fun archive(
        action: ArchiveRequest.Action,
        name: String = "",
        data: ByteArray = byteArrayOf()
    ): ArchiveResponse {
        val builder = ArchiveRequest.newBuilder()
            .setGridId(gridId)
            .setName(name)
            .setAction(action)
        if (data.isNotEmpty()) {
            builder.data = com.google.protobuf.ByteString.copyFrom(data)
        }
        return service.Archive(builder.build())
    }

    // =========================================================================
    // Viewport / Streams
    // =========================================================================

    fun resizeViewport(width: Int, height: Int) {
        service.ResizeViewport(
            ResizeViewportRequest.newBuilder()
                .setGridId(gridId)
                .setWidth(width)
                .setHeight(height)
                .build()
        )
    }

    fun renderSession(): io.github.ivere27.synurang.BidiStream<RenderInput, RenderOutput> {
        return service.RenderSession()
    }

    fun eventStream(): Iterator<GridEvent> {
        return service.EventStream(handle())
    }

    // =========================================================================
    // Clear
    // =========================================================================

    fun clear(scope: ClearScope = ClearScope.CLEAR_EVERYTHING, region: ClearRegion = ClearRegion.CLEAR_SCROLLABLE) {
        service.Clear(
            ClearRequest.newBuilder()
                .setGridId(gridId)
                .setScope(scope)
                .setRegion(region)
                .build()
        )
    }

    // =========================================================================
    // Demo
    // =========================================================================

    fun loadDemo(demo: String) {
        service.LoadDemo(
            LoadDemoRequest.newBuilder()
                .setGridId(gridId)
                .setDemo(demo)
                .build()
        )
    }

    fun getDemoData(demo: String): ByteArray {
        return service.GetDemoData(
            GetDemoDataRequest.newBuilder()
                .setDemo(demo)
                .build()
        ).data.toByteArray()
    }
}
