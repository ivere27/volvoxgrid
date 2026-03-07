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
    private final int leftCol;
    private final int bottomRow;
    private final int rightCol;
    private final int mouseRow;
    private final int mouseCol;
    private final GridCellRange[] ranges;

    public GridSelection(
        int row,
        int col,
        int rowEnd,
        int colEnd,
        int topRow,
        int leftCol,
        int bottomRow,
        int rightCol,
        int mouseRow,
        int mouseCol,
        GridCellRange[] ranges
    ) {
        this.row = row;
        this.col = col;
        this.rowEnd = rowEnd;
        this.colEnd = colEnd;
        this.topRow = topRow;
        this.leftCol = leftCol;
        this.bottomRow = bottomRow;
        this.rightCol = rightCol;
        this.mouseRow = mouseRow;
        this.mouseCol = mouseCol;
        this.ranges = ranges != null ? ranges.clone() : new GridCellRange[0];
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

    public int getTopRow() {
        return topRow;
    }

    public int getLeftCol() {
        return leftCol;
    }

    public int getBottomRow() {
        return bottomRow;
    }

    public int getRightCol() {
        return rightCol;
    }

    public int getMouseRow() {
        return mouseRow;
    }

    public int getMouseCol() {
        return mouseCol;
    }

    public GridCellRange[] getRanges() {
        return ranges.clone();
    }
}
