package io.github.ivere27.volvoxgrid.common;

/**
 * Platform-neutral row-indicator slot kinds.
 */
public enum VolvoxGridRowIndicatorSlotKind {
    None(0),
    Numbers(1),
    Current(2),
    Selection(3),
    Checkbox(4),
    Handle(5),
    Editing(6),
    Modified(7),
    Error(8),
    NewRow(9),
    Expander(10),
    Resize(11),
    Action(12),
    StatusIcon(13),
    Custom(14),
    NumbersDataOnly(15);

    private final int number;

    VolvoxGridRowIndicatorSlotKind(int number) {
        this.number = number;
    }

    public int getNumber() {
        return number;
    }

    public static VolvoxGridRowIndicatorSlotKind forNumber(int number) {
        for (VolvoxGridRowIndicatorSlotKind kind : values()) {
            if (kind.number == number) {
                return kind;
            }
        }
        return None;
    }
}
