package io.github.ivere27.volvoxgrid.common;

/**
 * Platform-neutral column-indicator cell modes.
 */
public enum VolvoxGridColumnIndicatorCellMode {
    None(0),
    HeaderText(1),
    SortGlyph(2),
    SortPriority(4),
    FilterButton(8),
    FilterState(16),
    MenuButton(32),
    Chooser(64),
    DragReorder(128),
    HiddenMarker(256),
    ResizeHandle(512),
    SelectAll(1024),
    StatusIcon(2048),
    Custom(4096);

    private final int number;

    VolvoxGridColumnIndicatorCellMode(int number) {
        this.number = number;
    }

    public int getNumber() {
        return number;
    }

    public static VolvoxGridColumnIndicatorCellMode forNumber(int number) {
        for (VolvoxGridColumnIndicatorCellMode mode : values()) {
            if (mode.number == number) {
                return mode;
            }
        }
        return None;
    }
}
