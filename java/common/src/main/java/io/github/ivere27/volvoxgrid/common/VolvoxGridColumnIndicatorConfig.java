package io.github.ivere27.volvoxgrid.common;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;

/**
 * Platform-neutral column-indicator band configuration.
 */
public final class VolvoxGridColumnIndicatorConfig {
    private final Boolean visible;
    private final Integer defaultRowHeight;
    private final Integer bandRows;
    private final List<VolvoxGridColumnIndicatorCellMode> cellModes;
    private final Long background;
    private final Long foreground;
    private final Integer gridLines;
    private final Long gridColor;
    private final Boolean autoSize;
    private final Boolean allowResize;
    private final Boolean allowReorder;
    private final Boolean allowMenu;

    private VolvoxGridColumnIndicatorConfig(Builder builder) {
        this.visible = builder.visible;
        this.defaultRowHeight = builder.defaultRowHeight;
        this.bandRows = builder.bandRows;
        this.cellModes = builder.cellModes == null
            ? null
            : Collections.unmodifiableList(new ArrayList<>(builder.cellModes));
        this.background = builder.background;
        this.foreground = builder.foreground;
        this.gridLines = builder.gridLines;
        this.gridColor = builder.gridColor;
        this.autoSize = builder.autoSize;
        this.allowResize = builder.allowResize;
        this.allowReorder = builder.allowReorder;
        this.allowMenu = builder.allowMenu;
    }

    public static Builder builder() {
        return new Builder();
    }

    public Boolean getVisible() {
        return visible;
    }

    public Integer getDefaultRowHeight() {
        return defaultRowHeight;
    }

    public Integer getBandRows() {
        return bandRows;
    }

    public boolean hasCellModes() {
        return cellModes != null;
    }

    public List<VolvoxGridColumnIndicatorCellMode> getCellModes() {
        return cellModes == null ? Collections.<VolvoxGridColumnIndicatorCellMode>emptyList() : cellModes;
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

    public Boolean getAllowReorder() {
        return allowReorder;
    }

    public Boolean getAllowMenu() {
        return allowMenu;
    }

    public static final class Builder {
        private Boolean visible;
        private Integer defaultRowHeight;
        private Integer bandRows;
        private List<VolvoxGridColumnIndicatorCellMode> cellModes;
        private Long background;
        private Long foreground;
        private Integer gridLines;
        private Long gridColor;
        private Boolean autoSize;
        private Boolean allowResize;
        private Boolean allowReorder;
        private Boolean allowMenu;

        public Builder visible(Boolean value) {
            this.visible = value;
            return this;
        }

        public Builder defaultRowHeight(Integer value) {
            this.defaultRowHeight = value;
            return this;
        }

        public Builder bandRows(Integer value) {
            this.bandRows = value;
            return this;
        }

        public Builder cellModes(Collection<VolvoxGridColumnIndicatorCellMode> value) {
            this.cellModes = value == null ? null : new ArrayList<>(value);
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

        public Builder allowReorder(Boolean value) {
            this.allowReorder = value;
            return this;
        }

        public Builder allowMenu(Boolean value) {
            this.allowMenu = value;
            return this;
        }

        public VolvoxGridColumnIndicatorConfig build() {
            return new VolvoxGridColumnIndicatorConfig(this);
        }
    }
}
