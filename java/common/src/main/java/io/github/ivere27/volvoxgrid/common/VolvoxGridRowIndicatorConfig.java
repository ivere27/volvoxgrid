package io.github.ivere27.volvoxgrid.common;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Platform-neutral row-indicator band configuration.
 */
public final class VolvoxGridRowIndicatorConfig {
    private final Boolean visible;
    private final Integer width;
    private final Long background;
    private final Long foreground;
    private final Integer gridLines;
    private final Long gridColor;
    private final Boolean autoSize;
    private final Boolean allowResize;
    private final Boolean allowSelect;
    private final Boolean allowReorder;
    private final List<VolvoxGridRowIndicatorSlot> slots;

    private VolvoxGridRowIndicatorConfig(Builder builder) {
        this.visible = builder.visible;
        this.width = builder.width;
        this.background = builder.background;
        this.foreground = builder.foreground;
        this.gridLines = builder.gridLines;
        this.gridColor = builder.gridColor;
        this.autoSize = builder.autoSize;
        this.allowResize = builder.allowResize;
        this.allowSelect = builder.allowSelect;
        this.allowReorder = builder.allowReorder;
        this.slots = Collections.unmodifiableList(new ArrayList<>(builder.slots));
    }

    public static Builder builder() {
        return new Builder();
    }

    public Boolean getVisible() {
        return visible;
    }

    public Integer getWidth() {
        return width;
    }

    public Long getBackground() {
        return background;
    }

    public Long getForeground() {
        return foreground;
    }

    public Integer getGridLines() {
        return gridLines;
    }

    public Long getGridColor() {
        return gridColor;
    }

    public Boolean getAutoSize() {
        return autoSize;
    }

    public Boolean getAllowResize() {
        return allowResize;
    }

    public Boolean getAllowSelect() {
        return allowSelect;
    }

    public Boolean getAllowReorder() {
        return allowReorder;
    }

    public List<VolvoxGridRowIndicatorSlot> getSlots() {
        return slots;
    }

    public static final class Builder {
        private Boolean visible;
        private Integer width;
        private Long background;
        private Long foreground;
        private Integer gridLines;
        private Long gridColor;
        private Boolean autoSize;
        private Boolean allowResize;
        private Boolean allowSelect;
        private Boolean allowReorder;
        private final List<VolvoxGridRowIndicatorSlot> slots = new ArrayList<>();

        public Builder visible(Boolean value) {
            this.visible = value;
            return this;
        }

        public Builder width(Integer value) {
            this.width = value;
            return this;
        }

        public Builder background(Long value) {
            this.background = value;
            return this;
        }

        public Builder foreground(Long value) {
            this.foreground = value;
            return this;
        }

        public Builder gridLines(Integer value) {
            this.gridLines = value;
            return this;
        }

        public Builder gridColor(Long value) {
            this.gridColor = value;
            return this;
        }

        public Builder autoSize(Boolean value) {
            this.autoSize = value;
            return this;
        }

        public Builder allowResize(Boolean value) {
            this.allowResize = value;
            return this;
        }

        public Builder allowSelect(Boolean value) {
            this.allowSelect = value;
            return this;
        }

        public Builder allowReorder(Boolean value) {
            this.allowReorder = value;
            return this;
        }

        public Builder addSlot(VolvoxGridRowIndicatorSlot slot) {
            this.slots.add(slot);
            return this;
        }

        public Builder slots(List<VolvoxGridRowIndicatorSlot> slots) {
            this.slots.clear();
            if (slots != null) {
                this.slots.addAll(slots);
            }
            return this;
        }

        public VolvoxGridRowIndicatorConfig build() {
            return new VolvoxGridRowIndicatorConfig(this);
        }
    }
}
