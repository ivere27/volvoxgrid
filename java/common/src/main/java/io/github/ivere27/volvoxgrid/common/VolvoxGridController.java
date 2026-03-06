package io.github.ivere27.volvoxgrid.common;

import java.util.List;

/**
 * Common Java controller contract shared by Android and desktop shells.
 */
public interface VolvoxGridController {
    int rowCount();
    void setRowCount(int value);

    int colCount();
    void setColCount(int value);

    int frozenRowCount();
    void setFrozenRowCount(int value);

    int frozenColCount();
    void setFrozenColCount(int value);

    void setTextMatrix(int row, int col, String text);
    String getTextMatrix(int row, int col);
    void setCellTexts(List<GridCellText> cells);

    void setRowHeight(int row, int height);
    void setColWidth(int col, int width);

    void sortByColumn(int col, boolean ascending);

    void select(int row1, int col1, int row2, int col2);
    GridSelection getSelectionState();

    /**
     * Modern alias for {@link #select(int, int, int, int)}.
     */
    default void selectRange(int rowStart, int colStart, int rowEnd, int colEnd) {
        select(rowStart, colStart, rowEnd, colEnd);
    }

    void setRendererBackend(RendererBackend backend);
    RendererBackend getRendererBackend();

    void setRedraw(boolean enabled);
    void refresh();

    /**
     * Run {@code action} while redraw is suspended, then re-enable and refresh.
     *
     * <p>This avoids per-call repaints when making many changes in a batch,
     * resulting in a single repaint at the end.</p>
     */
    default void withRedrawSuspended(Runnable action) {
        withRedrawSuspended(action, true);
    }

    /**
     * Run {@code action} while redraw is suspended.
     *
     * @param action       the batch operations to run
     * @param refreshAfter whether to call {@link #refresh()} after re-enabling redraw
     */
    default void withRedrawSuspended(Runnable action, boolean refreshAfter) {
        setRedraw(false);
        try {
            action.run();
        } finally {
            setRedraw(true);
            if (refreshAfter) {
                refresh();
            }
        }
    }

    /**
     * Fill a 2D matrix into the grid starting at the given offset.
     *
     * <p>When {@code resizeGrid} is true, the grid is enlarged if the data
     * exceeds the current row/column count.  Redraw is suspended for the
     * duration so only a single repaint occurs at the end.</p>
     */
    default void setTableData(List<List<String>> data, int startRow, int startCol, boolean resizeGrid) {
        if (data == null || data.isEmpty()) return;
        int mc = 0;
        for (List<String> row : data) {
            if (row.size() > mc) mc = row.size();
        }
        if (mc <= 0) return;

        final int maxCols = mc;

        withRedrawSuspended(() -> {
            if (resizeGrid) {
                int neededRows = startRow + data.size();
                int neededCols = startCol + maxCols;
                if (neededRows > rowCount()) setRowCount(neededRows);
                if (neededCols > colCount()) setColCount(neededCols);
            }

            java.util.ArrayList<GridCellText> cells = new java.util.ArrayList<>();
            for (int r = 0; r < data.size(); r++) {
                List<String> row = data.get(r);
                for (int c = 0; c < row.size(); c++) {
                    cells.add(new GridCellText(startRow + r, startCol + c, row.get(c)));
                }
            }
            setCellTexts(cells);
        });
    }

    /**
     * Fill a 2D matrix into the grid starting at row 0, column 0, resizing as needed.
     */
    default void setTableData(List<List<String>> data) {
        setTableData(data, 0, 0, true);
    }
}
