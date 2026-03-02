package io.github.ivere27.volvoxgrid

import io.github.ivere27.volvoxgrid.common.VolvoxGridController as VolvoxGridControllerContract
import io.github.ivere27.volvoxgrid.common.GridCellText
import io.github.ivere27.volvoxgrid.common.GridSelection
import io.github.ivere27.volvoxgrid.common.RendererBackend

/**
 * High-level Kotlin API wrapping the VolvoxGrid FFI calls.
 *
 * Provides property-style access to grid configuration and convenience methods
 * for common operations like sorting, subtotals, and cell manipulation.
 *
 * Usage:
 * ```kotlin
 * val controller = view.createController()
 * controller.rows = 100
 * controller.cols = 5
 * controller.setTextMatrix(0, 0, "Header")
 * controller.sort(SortOrder.SORT_GENERIC_ASCENDING, col = 2)
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
            fixedRows: Int = 1,
            fixedCols: Int = 0,
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
                                .setFixedRows(fixedRows)
                                .setFixedCols(fixedCols)
                                .build()
                        )
                        .build()
                )
                .build()
            val handle = service.Create(req)
            return VolvoxGridController(service, handle.id)
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
        val range = CellRange.newBuilder()
            .setRow1(minOf(activeRow, rowEnd))
            .setCol1(minOf(activeCol, colEnd))
            .setRow2(maxOf(activeRow, rowEnd))
            .setCol2(maxOf(activeCol, colEnd))
            .build()
        return SelectRequest.newBuilder()
            .setGridId(gridId)
            .setActiveRow(activeRow)
            .setActiveCol(activeCol)
            .addRanges(range)
            .setShow(show)
            .build()
    }

    private fun selectionEnd(sel: SelectionState): Pair<Int, Int> {
        if (sel.rangesCount <= 0) return Pair(sel.activeRow, sel.activeCol)
        val r = sel.getRanges(0)
        return if (r.row1 == sel.activeRow && r.col1 == sel.activeCol) {
            Pair(r.row2, r.col2)
        } else if (r.row2 == sel.activeRow && r.col2 == sel.activeCol) {
            Pair(r.row1, r.col1)
        } else {
            Pair(r.row2, r.col2)
        }
    }

    private fun configure(config: GridConfig) {
        service.Configure(
            ConfigureRequest.newBuilder()
                .setGridId(gridId)
                .setConfig(config)
                .build()
        )
    }

    private fun getConfig(): GridConfig {
        return service.GetConfig(handle())
    }

    fun destroy() {
        service.Destroy(handle())
    }

    // =========================================================================
    // Grid Dimensions
    // =========================================================================

    var rows: Int
        get() = getConfig().layout.rows
        set(value) {
            configure(GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setRows(value).build())
                .build())
        }

    var cols: Int
        get() = getConfig().layout.cols
        set(value) {
            configure(GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setCols(value).build())
                .build())
        }

    var fixedRows: Int
        get() = getConfig().layout.fixedRows
        set(value) {
            configure(GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setFixedRows(value).build())
                .build())
        }

    var fixedCols: Int
        get() = getConfig().layout.fixedCols
        set(value) {
            configure(GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setFixedCols(value).build())
                .build())
        }

    override fun rowCount(): Int = rows

    override fun setRowCount(value: Int) {
        rows = value
    }

    override fun colCount(): Int = cols

    override fun setColCount(value: Int) {
        cols = value
    }

    override fun fixedRowCount(): Int = fixedRows

    override fun setFixedRowCount(value: Int) {
        fixedRows = value
    }

    override fun fixedColCount(): Int = fixedCols

    override fun setFixedColCount(value: Int) {
        fixedCols = value
    }

    // =========================================================================
    // Cell Data
    // =========================================================================

    override fun setTextMatrix(row: Int, col: Int, text: String) {
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

    override fun getTextMatrix(row: Int, col: Int): String {
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

    fun setCells(cells: List<Triple<Int, Int, String>>) {
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

    override fun setCellTexts(cells: List<GridCellText>) {
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
        setTextMatrix(sel.activeRow, sel.activeCol, text)
    }

    fun loadArray(rows: Int, cols: Int, values: List<String>, bind: Boolean = false) {
        service.LoadArray(
            LoadArrayRequest.newBuilder()
                .setGridId(gridId)
                .setRows(rows)
                .setCols(cols)
                .addAllValues(values)
                .setBind(bind)
                .build()
        )
    }

    /**
     * Fill a 2D matrix into the grid starting at [startRow]/[startCol].
     *
     * When [resizeGrid] is true (the default), the grid is enlarged if the
     * data exceeds the current row/column count.  Redraw is suspended for
     * the duration so only a single repaint occurs at the end.
     */
    override fun setTableData(
        data: List<List<String>>,
        startRow: Int,
        startCol: Int,
        resizeGrid: Boolean
    ) {
        if (data.isEmpty()) return
        val maxCols = data.maxOf { it.size }
        if (maxCols <= 0) return

        withRedrawSuspended {
            if (resizeGrid) {
                val neededRows = startRow + data.size
                val neededCols = startCol + maxCols
                val currentRows = rows
                val currentCols = cols
                if (neededRows > currentRows) rows = neededRows
                if (neededCols > currentCols) cols = neededCols
            }

            val builder = UpdateCellsRequest.newBuilder().setGridId(gridId)
            for ((r, row) in data.withIndex()) {
                for ((c, text) in row.withIndex()) {
                    builder.addCells(
                        CellUpdate.newBuilder()
                            .setRow(startRow + r)
                            .setCol(startCol + c)
                            .setValue(CellValue.newBuilder().setText(text).build())
                            .build()
                    )
                }
            }
            service.UpdateCells(builder.build())
        }
    }

    fun getText(): String {
        val sel = service.GetSelection(handle())
        return getTextMatrix(sel.activeRow, sel.activeCol)
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

    var row: Int
        get() = service.GetSelection(handle()).activeRow
        set(value) {
            service.Select(buildSingleRangeSelectRequest(value, -1))
        }

    var col: Int
        get() = service.GetSelection(handle()).activeCol
        set(value) {
            service.Select(buildSingleRangeSelectRequest(-1, value))
        }

    override fun select(row1: Int, col1: Int, row2: Int, col2: Int) {
        service.Select(buildSingleRangeSelectRequest(row1, col1, row2, col2))
    }

    fun getSelection(): SelectionState {
        return service.GetSelection(handle())
    }

    override fun getSelectionState(): GridSelection {
        val sel = getSelection()
        val (rowEnd, colEnd) = selectionEnd(sel)
        return GridSelection(sel.activeRow, sel.activeCol, rowEnd, colEnd, sel.topRow)
    }

    fun setSelectionMode(mode: SelectionMode) {
        configure(GridConfig.newBuilder()
            .setSelection(SelectionConfig.newBuilder().setMode(mode).build())
            .build())
    }

    fun setSelectionVisibility(style: SelectionVisibility) {
        configure(GridConfig.newBuilder()
            .setSelection(SelectionConfig.newBuilder().setSelectionVisibility(style).build())
            .build())
    }

    fun setHighLight(style: SelectionVisibility) {
        setSelectionVisibility(style)
    }

    fun setFocusBorder(style: FocusBorderStyle) {
        configure(GridConfig.newBuilder()
            .setSelection(SelectionConfig.newBuilder().setFocusBorder(style).build())
            .build())
    }

    fun setFocusRect(style: FocusBorderStyle) {
        setFocusBorder(style)
    }

    fun setTopRow(row: Int) {
        val currentCol = try {
            service.GetSelection(handle()).activeCol
        } catch (_: Exception) {
            0
        }
        service.Select(buildSingleRangeSelectRequest(row, currentCol, show = true))
    }

    fun getTopRow(): Int {
        return service.GetSelection(handle()).topRow
    }

    // =========================================================================
    // Sorting
    // =========================================================================

    fun sort(order: SortOrder, col: Int = 0) {
        service.Sort(
            SortRequest.newBuilder()
                .setGridId(gridId)
                .addSortColumns(SortColumn.newBuilder().setCol(col).setOrder(order))
                .build()
        )
    }

    /** Sort by multiple columns. */
    fun sortMulti(columns: List<Pair<Int, SortOrder>>) {
        val req = SortRequest.newBuilder().setGridId(gridId)
        for ((col, order) in columns) {
            req.addSortColumns(SortColumn.newBuilder().setCol(col).setOrder(order))
        }
        service.Sort(req.build())
    }

    override fun sortByColumn(col: Int, ascending: Boolean) {
        sort(
            if (ascending) SortOrder.SORT_GENERIC_ASCENDING else SortOrder.SORT_GENERIC_DESCENDING,
            col
        )
    }

    fun setHeaderFeatures(mode: HeaderFeatures) {
        configure(GridConfig.newBuilder()
            .setInteraction(InteractionConfig.newBuilder().setHeaderFeatures(mode).build())
            .build())
    }

    fun setExplorerBar(mode: HeaderFeatures) {
        setHeaderFeatures(mode)
    }

    fun setColSort(col: Int, order: SortOrder) {
        service.DefineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder()
                    .setIndex(col)
                    .setSort(order)
                    .build())
                .build()
        )
    }

    // =========================================================================
    // Spanning
    // =========================================================================

    fun setCellSpan(mode: CellSpanMode) {
        configure(GridConfig.newBuilder()
            .setSpan(SpanConfig.newBuilder().setCellSpan(mode).build())
            .build())
    }

    fun setSpanCells(mode: CellSpanMode) {
        setCellSpan(mode)
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
        addOutline: Boolean = true
    ) {
        service.Subtotal(
            SubtotalRequest.newBuilder()
                .setGridId(gridId)
                .setAggregate(aggregateType)
                .setGroupOnCol(groupOnCol)
                .setAggregateCol(aggregateCol)
                .setCaption(caption)
                .setBackColor(backColor.toInt())
                .setForeColor(foreColor.toInt())
                .setAddOutline(addOutline)
                .build()
        )
    }

    fun setTreeIndicator(style: TreeIndicatorStyle) {
        configure(GridConfig.newBuilder()
            .setOutline(OutlineConfig.newBuilder().setTreeIndicator(style).build())
            .build())
    }

    fun setOutlineBar(style: TreeIndicatorStyle) {
        setTreeIndicator(style)
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

    fun setColComboList(col: Int, list: String) {
        setColDropdownItems(col, list)
    }

    // =========================================================================
    // Editing
    // =========================================================================

    fun setEditTrigger(mode: EditTrigger) {
        configure(GridConfig.newBuilder()
            .setEditing(EditConfig.newBuilder().setEditTrigger(mode).build())
            .build())
    }

    fun setEditable(mode: EditTrigger) {
        setEditTrigger(mode)
    }

    fun editCell(row: Int, col: Int) {
        service.Edit(
            EditCommand.newBuilder()
                .setGridId(gridId)
                .setStart(EditStart.newBuilder().setRow(row).setCol(col).build())
                .build()
        )
    }

    fun finishEditing() {
        service.Edit(
            EditCommand.newBuilder()
                .setGridId(gridId)
                .setFinish(EditFinish.newBuilder().build())
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

    fun setCellStyleRange(row1: Int, col1: Int, row2: Int, col2: Int, style: CellStyleOverride) {
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
                    .setAlignment(alignment)
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
            .setLayout(LayoutConfig.newBuilder().setWordWrap(enabled).build())
            .build())
    }

    fun setEllipsis(enabled: Boolean) {
        setEllipsisMode(if (enabled) 1 else 0)
    }

    fun setEllipsisMode(mode: Int) {
        configure(GridConfig.newBuilder()
            .setLayout(LayoutConfig.newBuilder().setEllipsis(mode.coerceIn(0, 2)).build())
            .build())
    }

    fun setExtendLastCol(enabled: Boolean) {
        configure(GridConfig.newBuilder()
            .setLayout(LayoutConfig.newBuilder().setExtendLastCol(enabled).build())
            .build())
    }

    fun setAllowUserResizing(mode: AllowUserResizingMode) {
        configure(GridConfig.newBuilder()
            .setInteraction(InteractionConfig.newBuilder().setAllowUserResizing(mode).build())
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
     *     ctrl.setTextMatrix(0, 0, "A")
     *     ctrl.setTextMatrix(0, 1, "B")
     *     ctrl.setTextMatrix(1, 0, "C")
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

    fun setTextLayoutCacheCap(cap: Int) {
        configure(GridConfig.newBuilder()
            .setRendering(
                RenderConfig.newBuilder()
                    .setTextLayoutCacheCap(cap.coerceAtLeast(0))
                    .build()
            )
            .build())
    }

    fun getAnimationEnabled(): Boolean {
        return getConfig().rendering.animationEnabled
    }

    fun getTextLayoutCacheCap(): Int {
        return getConfig().rendering.textLayoutCacheCap
    }

    fun setRendererMode(mode: Int) {
        configure(GridConfig.newBuilder()
            .setRendering(RenderConfig.newBuilder()
                .setRendererModeValue(mode)
                .build())
            .build())
    }

    fun getRendererMode(): Int {
        return getConfig().rendering.rendererModeValue
    }

    override fun setRendererBackend(backend: RendererBackend) {
        when (backend) {
            RendererBackend.AUTO -> setRendererMode(0)
            RendererBackend.CPU -> setRendererMode(1)
            RendererBackend.GPU -> setRendererMode(2)
        }
    }

    override fun getRendererBackend(): RendererBackend {
        return when (getRendererMode()) {
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

    fun loadGrid(data: ByteArray, format: ExportFormat = ExportFormat.EXPORT_BINARY) {
        service.Import(
            ImportRequest.newBuilder()
                .setGridId(gridId)
                .setData(com.google.protobuf.ByteString.copyFrom(data))
                .setFormat(format)
                .setScope(ExportScope.EXPORT_ALL)
                .build()
        )
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
}
