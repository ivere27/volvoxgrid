package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.AfterEditEvent;
import io.github.ivere27.volvoxgrid.GridEvent;
import io.github.ivere27.volvoxgrid.common.GridCellText;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Data-first binding for {@link VolvoxGridDesktopPanel} modeled after Swing's
 * {@code TableModel} idiom: pass typed columns and a row list, and the adapter
 * pushes captions / cell text into the engine and surfaces commits via
 * {@link #setOnCellEdit(Consumer)}.
 *
 * <p>The adapter assumes the panel is already initialized
 * ({@code panel.initialize(libraryPath, rows, cols)} has been called). It owns
 * the panel's {@code gridEventListener} and {@code beforeEditListener} slots
 * while attached.
 *
 * <pre>{@code
 * VolvoxGridTableModelAdapter<Product> adapter = new VolvoxGridTableModelAdapter<>(
 *     panel,
 *     Arrays.asList(
 *         VolvoxGridTableModelAdapter.column("name", "Name", Product::getName),
 *         VolvoxGridTableModelAdapter.editable("price", "Price",
 *             p -> String.format("%.2f", p.getPrice()))
 *     )
 * );
 * adapter.setOnCellEdit(edit -> {
 *     Product current = products.get(edit.getRowIndex());
 *     try {
 *         current.setPrice(Double.parseDouble(edit.getNewText()));
 *     } catch (NumberFormatException ignore) { }
 * });
 * adapter.setRows(products);
 * }</pre>
 */
public final class VolvoxGridTableModelAdapter<T> {
    private static final Logger LOG = Logger.getLogger(VolvoxGridTableModelAdapter.class.getName());

    /** Typed column definition. */
    public static final class VolvoxColumn<T> {
        private final String field;
        private final String header;
        private final Function<T, String> value;
        private final boolean editable;

        public VolvoxColumn(String field, String header, Function<T, String> value, boolean editable) {
            this.field = Objects.requireNonNull(field, "field");
            this.header = Objects.requireNonNull(header, "header");
            this.value = Objects.requireNonNull(value, "value");
            this.editable = editable;
        }

        public String getField() { return field; }
        public String getHeader() { return header; }
        public Function<T, String> getValue() { return value; }
        public boolean isEditable() { return editable; }
    }

    /** Cell-edit details surfaced by {@link #setOnCellEdit(Consumer)}. */
    public static final class VolvoxCellEdit<T> {
        private final int rowIndex;
        private final T row;
        private final int columnIndex;
        private final String field;
        private final String oldText;
        private final String newText;

        VolvoxCellEdit(int rowIndex, T row, int columnIndex, String field, String oldText, String newText) {
            this.rowIndex = rowIndex;
            this.row = row;
            this.columnIndex = columnIndex;
            this.field = field;
            this.oldText = oldText;
            this.newText = newText;
        }

        public int getRowIndex() { return rowIndex; }
        public T getRow() { return row; }
        public int getColumnIndex() { return columnIndex; }
        public String getField() { return field; }
        public String getOldText() { return oldText; }
        public String getNewText() { return newText; }
    }

    /** Convenience factory for a read-only column. */
    public static <T> VolvoxColumn<T> column(String field, String header, Function<T, String> value) {
        return new VolvoxColumn<>(field, header, value, false);
    }

    /** Convenience factory for an editable column. */
    public static <T> VolvoxColumn<T> editable(String field, String header, Function<T, String> value) {
        return new VolvoxColumn<>(field, header, value, true);
    }

    private final VolvoxGridDesktopPanel panel;
    private final List<VolvoxColumn<T>> columns;
    private List<T> rows = Collections.emptyList();
    private boolean attached = false;
    private boolean captionsApplied = false;
    private Consumer<VolvoxCellEdit<T>> onCellEdit;

    public VolvoxGridTableModelAdapter(VolvoxGridDesktopPanel panel, List<VolvoxColumn<T>> columns) {
        this.panel = Objects.requireNonNull(panel, "panel");
        this.columns = new ArrayList<>(Objects.requireNonNull(columns, "columns"));
        installListeners();
    }

    /** Receives committed cell edits on editable columns. */
    public void setOnCellEdit(Consumer<VolvoxCellEdit<T>> onCellEdit) {
        this.onCellEdit = onCellEdit;
    }

    /** The dataset most recently passed to {@link #setRows(List)}. */
    public List<T> getRows() {
        return Collections.unmodifiableList(rows);
    }

    /** Replace the dataset with {@code newRows}. */
    public void setRows(List<T> newRows) {
        Objects.requireNonNull(newRows, "newRows");
        this.rows = new ArrayList<>(newRows);
        try {
            VolvoxGridDesktopController controller = panel.createController();
            controller.setRowCount(rows.size());
            controller.setColCount(columns.size());
            if (!captionsApplied) {
                for (int i = 0; i < columns.size(); i++) {
                    controller.setColumnCaption(i, columns.get(i).getHeader());
                }
                captionsApplied = true;
            }
            applyCells(controller);
        } catch (SynurangDesktopBridge.SynurangBridgeException e) {
            LOG.log(Level.WARNING, "Failed to push rows to engine", e);
        }
    }

    @SafeVarargs
    public final void setRows(T... newRows) {
        setRows(Arrays.asList(newRows));
    }

    /**
     * Stop receiving events from the panel. Call this when discarding the
     * adapter while keeping the panel alive.
     */
    public void detach() {
        if (!attached) return;
        panel.setGridEventListener(null);
        panel.setBeforeEditListener(null);
        attached = false;
    }

    private void installListeners() {
        if (attached) return;
        panel.setGridEventListener(this::handleAfterEdit);
        panel.setBeforeEditListener(details -> {
            int col = details.getCol();
            if (col >= 0 && col < columns.size() && !columns.get(col).isEditable()) {
                details.setCancel(true);
            }
        });
        attached = true;
    }

    private void applyCells(VolvoxGridDesktopController controller) throws SynurangDesktopBridge.SynurangBridgeException {
        if (rows.isEmpty() || columns.isEmpty()) return;
        List<GridCellText> cells = new ArrayList<>(rows.size() * columns.size());
        for (int r = 0; r < rows.size(); r++) {
            T row = rows.get(r);
            for (int c = 0; c < columns.size(); c++) {
                cells.add(new GridCellText(r, c, columns.get(c).getValue().apply(row)));
            }
        }
        controller.setCells(cells);
    }

    private void handleAfterEdit(GridEvent event) {
        if (!event.hasAfterEdit()) return;
        Consumer<VolvoxCellEdit<T>> cb = onCellEdit;
        if (cb == null) return;
        AfterEditEvent after = event.getAfterEdit();
        int r = after.getRow();
        int c = after.getCol();
        if (r < 0 || r >= rows.size()) return;
        if (c < 0 || c >= columns.size()) return;
        VolvoxColumn<T> col = columns.get(c);
        if (!col.isEditable()) return;
        cb.accept(new VolvoxCellEdit<>(
            r,
            rows.get(r),
            c,
            col.getField(),
            after.getOldText(),
            after.getNewText()
        ));
    }
}
