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

    boolean getShowColumnHeaders();
    void setShowColumnHeaders(boolean value);

    int getColumnIndicatorTopModeBits();
    void setColumnIndicatorTopModeBits(int value);

    int getColumnIndicatorTopRowCount();
    void setColumnIndicatorTopRowCount(int value);

    boolean getShowRowIndicator();
    void setShowRowIndicator(boolean value);

    int getRowIndicatorStartModeBits();
    void setRowIndicatorStartModeBits(int value);

    int getRowIndicatorStartWidth();
    void setRowIndicatorStartWidth(int value);

    void setCellText(int row, int col, String text);
    String getCellText(int row, int col);
    void setCells(List<GridCellText> cells);

    void setRowHeight(int row, int height);
    void setColWidth(int col, int width);

    void sort(int col, boolean ascending);

    void selectRange(int row1, int col1, int row2, int col2);
    default void selectRanges(List<GridCellRange> ranges) {
        if (ranges == null || ranges.isEmpty()) return;
        GridCellRange first = ranges.get(0);
        selectRanges(ranges, first.getRow1(), first.getCol1());
    }
    void selectRanges(List<GridCellRange> ranges, int activeRow, int activeCol);
    GridSelection getSelection();
    void clearSelection();
    void showCell(int row, int col);

    int topRow();
    void setTopRow(int value);

    int leftCol();
    void setLeftCol(int value);

    int cursorRow();
    void setCursorRow(int value);

    int cursorCol();
    void setCursorCol(int value);

    void setRendererBackend(RendererBackend backend);
    RendererBackend rendererBackend();

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

}
