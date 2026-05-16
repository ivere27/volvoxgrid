package io.github.ivere27.volvoxgrid.desktop;

public final class VolvoxGridSubtotalLevel {
    private static final long DEFAULT_FORE_COLOR = 0xFF111827L;

    private final Integer groupCol;
    private final String caption;
    private final long backColor;
    private final long foreColor;

    public VolvoxGridSubtotalLevel(Integer groupCol, String caption, long backColor) {
        this(groupCol, caption, backColor, DEFAULT_FORE_COLOR);
    }

    public VolvoxGridSubtotalLevel(Integer groupCol, String caption, long backColor, long foreColor) {
        this.groupCol = groupCol;
        this.caption = caption == null ? "" : caption;
        this.backColor = backColor;
        this.foreColor = foreColor;
    }

    public Integer getGroupCol() {
        return groupCol;
    }

    public String getCaption() {
        return caption;
    }

    public long getBackColor() {
        return backColor;
    }

    public long getForeColor() {
        return foreColor;
    }
}
