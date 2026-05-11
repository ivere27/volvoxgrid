package io.github.ivere27.volvoxgrid.common;

import java.util.Arrays;
import java.util.Objects;

/**
 * Platform-neutral row-indicator slot configuration.
 */
public final class VolvoxGridRowIndicatorSlot {
    private final VolvoxGridRowIndicatorSlotKind kind;
    private final Integer width;
    private final Boolean visible;
    private final String customKey;
    private final byte[] data;

    public VolvoxGridRowIndicatorSlot(VolvoxGridRowIndicatorSlotKind kind, Integer width, Boolean visible) {
        this(kind, width, visible, null, null);
    }

    public VolvoxGridRowIndicatorSlot(
        VolvoxGridRowIndicatorSlotKind kind,
        Integer width,
        Boolean visible,
        String customKey,
        byte[] data
    ) {
        this.kind = Objects.requireNonNull(kind, "kind");
        this.width = width;
        this.visible = visible;
        this.customKey = customKey;
        this.data = data == null ? null : Arrays.copyOf(data, data.length);
    }

    public VolvoxGridRowIndicatorSlotKind getKind() {
        return kind;
    }

    public Integer getWidth() {
        return width;
    }

    public Boolean getVisible() {
        return visible;
    }

    public String getCustomKey() {
        return customKey;
    }

    public byte[] getData() {
        return data == null ? null : Arrays.copyOf(data, data.length);
    }
}
