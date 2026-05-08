package io.github.ivere27.volvoxgrid.compose

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import io.github.ivere27.volvoxgrid.VolvoxCellEdit
import io.github.ivere27.volvoxgrid.VolvoxColumn
import io.github.ivere27.volvoxgrid.VolvoxGridAdapter
import io.github.ivere27.volvoxgrid.VolvoxGridView

/**
 * Compose wrapper around [VolvoxGridView] + [VolvoxGridAdapter].
 *
 * Drop into any `setContent { ... }`. The composable owns the underlying
 * [VolvoxGridView]/[VolvoxGridAdapter] lifecycle — it detaches them on
 * disposal, so no manual cleanup is required from the caller.
 *
 * Example — full Activity using state-hoisted rows:
 *
 * ```kotlin
 * data class Product(val name: String, val price: Double)
 *
 * class MainActivity : ComponentActivity() {
 *     override fun onCreate(savedInstanceState: Bundle?) {
 *         super.onCreate(savedInstanceState)
 *         setContent {
 *             var products by remember {
 *                 mutableStateOf(listOf(
 *                     Product("Coffee", 3.50),
 *                     Product("Tea", 2.75),
 *                 ))
 *             }
 *             VolvoxGrid(
 *                 rows = products,
 *                 columns = listOf(
 *                     VolvoxColumn(field = "name", header = "Name", value = { it.name }),
 *                     VolvoxColumn(
 *                         field = "price",
 *                         header = "Price",
 *                         value = { "%.2f".format(it.price) },
 *                         editable = true,
 *                     ),
 *                 ),
 *                 onCellEdit = { edit ->
 *                     products = products.toMutableList().also { rows ->
 *                         val row = rows[edit.rowIndex]
 *                         rows[edit.rowIndex] = row.copy(
 *                             price = edit.newText.toDoubleOrNull() ?: row.price,
 *                         )
 *                     }
 *                 },
 *                 modifier = Modifier.fillMaxSize(),
 *             )
 *         }
 *     }
 * }
 * ```
 *
 * Refresh semantics:
 *
 * - Pass a **new** [rows] list reference to trigger a reload. Mutating the
 *   same list in place will not — Compose only re-invokes `update` when the
 *   parameter identity changes. This matches the convention of the Flutter
 *   `VolvoxDataGrid<T>` widget.
 * - The composable also tracks **[columns] identity**. Passing a new column
 *   list reference rebuilds the underlying adapter so column-shape changes
 *   (renames, toggling `editable`, reorder) take effect. To avoid spurious
 *   rebuilds across recomposition, hoist the column list with
 *   `remember { listOf(...) }` (or `remember(key) { ... }` if it depends on
 *   external state).
 *
 * Editing: a column with `editable = true` accepts cell edits; commits are
 * delivered to [onCellEdit] with the old/new text and the row reference at
 * the time of the edit.
 */
@Composable
fun <T> VolvoxGrid(
    rows: List<T>,
    columns: List<VolvoxColumn<T>>,
    modifier: Modifier = Modifier,
    onCellEdit: ((VolvoxCellEdit<T>) -> Unit)? = null,
) {
    val state = remember { ComposeState<T>() }

    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            val view = VolvoxGridView(ctx)
            state.view = view
            state.adapter = VolvoxGridAdapter(view = view, columns = columns).also {
                state.activeColumns = columns
            }
            view
        },
        update = { view ->
            val current = state.adapter
            val activeCols = state.activeColumns
            val adapter = if (current == null || activeCols !== columns) {
                current?.detach()
                VolvoxGridAdapter(view = view, columns = columns).also {
                    state.adapter = it
                    state.activeColumns = columns
                }
            } else {
                current
            }
            adapter.onCellEdit = onCellEdit
            adapter.submitList(rows)
        },
    )

    DisposableEffect(Unit) {
        onDispose {
            state.adapter?.detach()
            state.adapter = null
            state.view = null
            state.activeColumns = null
        }
    }
}

private class ComposeState<T> {
    var view: VolvoxGridView? = null
    var adapter: VolvoxGridAdapter<T>? = null
    var activeColumns: List<VolvoxColumn<T>>? = null
}
