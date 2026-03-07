package io.github.ivere27.volvoxgrid.common;

/**
 * Platform-neutral rectangular cell range.
 */
public final class GridCellRange {
    private final int row1;
    private final int col1;
    private final int row2;
    private final int col2;

    public GridCellRange(int row1, int col1, int row2, int col2) {
        this.row1 = row1;
        this.col1 = col1;
        this.row2 = row2;
        this.col2 = col2;
    }

    public int getRow1() {
        return row1;
    }

    public int getCol1() {
        return col1;
    }

    public int getRow2() {
        return row2;
    }

    public int getCol2() {
        return col2;
    }
}
