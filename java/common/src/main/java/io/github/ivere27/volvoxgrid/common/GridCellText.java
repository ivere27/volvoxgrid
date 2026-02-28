package io.github.ivere27.volvoxgrid.common;

import java.util.Objects;

/**
 * Small immutable value for bulk text updates.
 */
public final class GridCellText {
    private final int row;
    private final int col;
    private final String text;

    public GridCellText(int row, int col, String text) {
        this.row = row;
        this.col = col;
        this.text = Objects.requireNonNull(text, "text");
    }

    public int getRow() {
        return row;
    }

    public int getCol() {
        return col;
    }

    public String getText() {
        return text;
    }
}
