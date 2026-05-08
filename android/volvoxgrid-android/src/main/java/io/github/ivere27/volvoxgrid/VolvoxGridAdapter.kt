package io.github.ivere27.volvoxgrid

import io.github.ivere27.volvoxgrid.common.GridCellText

/**
 * Typed column definition for [VolvoxGridAdapter].
 */
data class VolvoxColumn<T>(
    /** Stable identifier surfaced in [VolvoxCellEdit.field]. */
    val field: String,
    /** Header caption shown in the engine's column-header band. */
    val header: String,
    /** Reads the cell value for [row]. */
    val value: (T) -> String,
    /**
     * When true, the engine accepts edits on this column and committed values
     * surface via [VolvoxGridAdapter.onCellEdit]. When false, the column is
     * read-only — the adapter cancels edits before they start.
     */
    val editable: Boolean = false,
)

/** Cell-edit details surfaced by [VolvoxGridAdapter.onCellEdit]. */
data class VolvoxCellEdit<T>(
    val rowIndex: Int,
    val row: T,
    val columnIndex: Int,
    val field: String,
    val oldText: String,
    val newText: String,
)

/**
 * Data-first binding for [VolvoxGridView] modeled after `RecyclerView.Adapter`
 * / `ListAdapter`. Pass typed [columns] and call [submitList] with rows.
 *
 * The adapter initializes the view on the first [submitList] call if it is
 * not already initialized, applies column captions, and pushes cell text into
 * the engine. It owns the view's `eventListener` and `beforeEditListener`
 * slots while attached.
 *
 * ```kotlin
 * val adapter = VolvoxGridAdapter(
 *     view = gridView,
 *     columns = listOf(
 *         VolvoxColumn(field = "name", header = "Name", value = { it.name }),
 *         VolvoxColumn(
 *             field = "price",
 *             header = "Price",
 *             value = { "%.2f".format(it.price) },
 *             editable = true,
 *         ),
 *     ),
 * )
 * adapter.onCellEdit = { edit ->
 *     items[edit.rowIndex] = items[edit.rowIndex].copy(
 *         price = edit.newText.toDoubleOrNull() ?: items[edit.rowIndex].price,
 *     )
 * }
 * adapter.submitList(items)
 * ```
 */
class VolvoxGridAdapter<T>(
    private val view: VolvoxGridView,
    private val columns: List<VolvoxColumn<T>>,
) {
    /** Receives committed cell edits on [VolvoxColumn.editable] columns. */
    var onCellEdit: ((VolvoxCellEdit<T>) -> Unit)? = null

    private var items: List<T> = emptyList()
    private var listenersInstalled = false
    private var captionsApplied = false

    /** The dataset most recently passed to [submitList]. */
    val currentList: List<T>
        get() = items

    /** Replace the dataset with [newItems]. */
    fun submitList(newItems: List<T>) {
        items = newItems
        if (view.getGridId() == 0L) {
            view.initialize(newItems.size, columns.size)
        } else {
            val controller = view.createController()
            controller.setRowCount(newItems.size)
            controller.setColCount(columns.size)
        }
        installListeners()
        if (!captionsApplied) {
            applyColumnCaptions()
            captionsApplied = true
        }
        applyCells()
        view.requestFrame()
    }

    /**
     * Stop receiving events from the view. Call this when discarding the
     * adapter while keeping the view alive.
     */
    fun detach() {
        if (!listenersInstalled) return
        view.eventListener = null
        view.beforeEditListener = null
        listenersInstalled = false
    }

    private fun installListeners() {
        if (listenersInstalled) return
        view.eventListener = object : VolvoxGridView.GridEventListener {
            override fun onGridEvent(event: GridEvent) = handleAfterEdit(event)
        }
        view.beforeEditListener = object : VolvoxGridView.BeforeEditListener {
            override fun onBeforeEdit(details: VolvoxGridView.BeforeEditDetails) {
                if (details.col in columns.indices && !columns[details.col].editable) {
                    details.cancel = true
                }
            }
        }
        listenersInstalled = true
    }

    private fun applyColumnCaptions() {
        val controller = view.createController()
        for ((i, col) in columns.withIndex()) {
            controller.setColumnCaption(i, col.header)
        }
    }

    private fun applyCells() {
        if (items.isEmpty() || columns.isEmpty()) return
        val controller = view.createController()
        val cells = ArrayList<GridCellText>(items.size * columns.size)
        for ((r, row) in items.withIndex()) {
            for ((c, col) in columns.withIndex()) {
                cells += GridCellText(r, c, col.value(row))
            }
        }
        controller.setCells(cells)
    }

    private fun handleAfterEdit(event: GridEvent) {
        if (!event.hasAfterEdit()) return
        val cb = onCellEdit ?: return
        val after = event.afterEdit
        if (after.row !in items.indices) return
        if (after.col !in columns.indices) return
        val col = columns[after.col]
        if (!col.editable) return
        cb(
            VolvoxCellEdit(
                rowIndex = after.row,
                row = items[after.row],
                columnIndex = after.col,
                field = col.field,
                oldText = after.oldText,
                newText = after.newText,
            )
        )
    }
}
