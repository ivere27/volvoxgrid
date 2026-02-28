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

    int fixedRowCount();
    void setFixedRowCount(int value);

    int fixedColCount();
    void setFixedColCount(int value);

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
}
