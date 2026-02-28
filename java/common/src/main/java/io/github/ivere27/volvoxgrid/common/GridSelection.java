package io.github.ivere27.volvoxgrid.common;

/**
 * Platform-neutral selection snapshot.
 */
public final class GridSelection {
    private final int row;
    private final int col;
    private final int rowEnd;
    private final int colEnd;
    private final int topRow;

    public GridSelection(int row, int col, int rowEnd, int colEnd, int topRow) {
        this.row = row;
        this.col = col;
        this.rowEnd = rowEnd;
        this.colEnd = colEnd;
        this.topRow = topRow;
    }

    public int getRow() {
        return row;
    }

    public int getCol() {
        return col;
    }

    public int getRowEnd() {
        return rowEnd;
    }

    public int getColEnd() {
        return colEnd;
    }

    /**
     * Legacy alias for {@link #getRowEnd()}.
     */
    @Deprecated
    public int getRowSel() {
        return rowEnd;
    }

    /**
     * Legacy alias for {@link #getColEnd()}.
     */
    @Deprecated
    public int getColSel() {
        return colEnd;
    }

    public int getTopRow() {
        return topRow;
    }
}
