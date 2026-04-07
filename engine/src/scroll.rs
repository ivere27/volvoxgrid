/// Scroll state
#[derive(Clone, Debug)]
pub struct ScrollState {
    pub scroll_x: f32,
    pub scroll_y: f32,
    pub max_scroll_x: f32,
    pub max_scroll_y: f32,
    /// Horizontal fling velocity in px/sec.
    pub fling_vx: f32,
    /// Vertical fling velocity in px/sec.
    pub fling_vy: f32,
    /// True while inertial scroll animation is active.
    pub fling_active: bool,
}

impl Default for ScrollState {
    fn default() -> Self {
        Self {
            scroll_x: 0.0,
            scroll_y: 0.0,
            max_scroll_x: 0.0,
            max_scroll_y: 0.0,
            fling_vx: 0.0,
            fling_vy: 0.0,
            fling_active: false,
        }
    }
}

impl ScrollState {
    pub fn new() -> Self {
        Self::default()
    }

    /// Compute the maximum legal scroll offsets for the current layout and
    /// viewport geometry.
    pub fn compute_max_scroll(
        layout: &crate::layout::LayoutCache,
        viewport_width: i32,
        viewport_height: i32,
        fixed_rows: i32,
        fixed_cols: i32,
        pinned_height: i32,
        pinned_width: i32,
    ) -> (f32, f32) {
        let fixed_height = layout.row_pos(fixed_rows);
        let fixed_width = layout.col_pos(fixed_cols);
        let max_scroll_x =
            (layout.total_width - viewport_width + fixed_width + pinned_width).max(0) as f32;
        // Pinned rows have 0 height in layout (total_height excludes them),
        // but they consume viewport space, so we ADD pinned_height to reserve
        // that viewport space for the pinned sections.
        let max_scroll_y =
            (layout.total_height - viewport_height + fixed_height + pinned_height).max(0) as f32;
        (max_scroll_x, max_scroll_y)
    }

    /// Update max scroll values based on layout.
    ///
    /// `pinned_height` is the total pixel height of all structurally pinned rows
    /// (top + bottom). These rows are not part of the scrollable area, so their
    /// height is subtracted from the scrollable content extent.
    ///
    /// `pinned_width` is the total pixel width of all structurally pinned columns
    /// (left + right). These columns are excluded from layout width but consume
    /// viewport space, so horizontal max scroll reserves that space.
    pub fn update_bounds(
        &mut self,
        layout: &crate::layout::LayoutCache,
        viewport_width: i32,
        viewport_height: i32,
        fixed_rows: i32,
        fixed_cols: i32,
        pinned_height: i32,
        pinned_width: i32,
    ) {
        let (max_scroll_x, max_scroll_y) = Self::compute_max_scroll(
            layout,
            viewport_width,
            viewport_height,
            fixed_rows,
            fixed_cols,
            pinned_height,
            pinned_width,
        );
        self.max_scroll_x = max_scroll_x;
        self.max_scroll_y = max_scroll_y;
        self.clamp();
    }

    /// Scroll by delta
    pub fn scroll_by(&mut self, dx: f32, dy: f32) {
        self.scroll_x += dx;
        self.scroll_y += dy;
        self.clamp();
    }

    /// Set scroll position
    pub fn scroll_to(&mut self, x: f32, y: f32) {
        self.scroll_x = x;
        self.scroll_y = y;
        self.clamp();
    }

    /// Ensure cell is visible by adjusting scroll.
    ///
    /// `pinned_height` is the total pixel height of structurally pinned rows
    /// (top + bottom) that reduce the available scrollable viewport.
    ///
    /// `pinned_width` is the total pixel width of structurally pinned columns
    /// (left + right) that reduce the available horizontal scrollable viewport.
    pub fn show_cell(
        &mut self,
        row: i32,
        col: i32,
        layout: &crate::layout::LayoutCache,
        viewport_width: i32,
        viewport_height: i32,
        fixed_rows: i32,
        fixed_cols: i32,
        pinned_height: i32,
        pinned_width: i32,
    ) {
        if !layout.valid || row < 0 || col < 0 {
            return;
        }
        // Programmatic scroll-to-cell actions (e.g. fast scroller jumps) should
        // take precedence over inertial momentum.
        self.stop_fling();
        let (cx, cy, cw, ch) = layout.cell_rect(row, col);

        // Compute scrollable viewport area (after fixed rows/cols/pinned)
        let fixed_height = layout.row_pos(fixed_rows);
        let fixed_width = layout.col_pos(fixed_cols);

        // Vertical: ensure cell is within scrollable viewport
        if row >= fixed_rows {
            let visible_top = self.scroll_y as i32 + fixed_height;
            let visible_bottom = self.scroll_y as i32 + viewport_height - pinned_height;
            if cy < visible_top {
                self.scroll_y = (cy - fixed_height) as f32;
            } else if cy + ch > visible_bottom {
                self.scroll_y = (cy + ch - viewport_height + pinned_height) as f32;
            }
        }

        // Horizontal
        if col >= fixed_cols {
            let visible_left = self.scroll_x as i32 + fixed_width;
            let visible_right = self.scroll_x as i32 + viewport_width - pinned_width;
            if cx < visible_left {
                self.scroll_x = (cx - fixed_width) as f32;
            } else if cx + cw > visible_right {
                self.scroll_x = (cx + cw - viewport_width + pinned_width) as f32;
            }
        }

        self.clamp();
    }

    pub fn quantize_to_cells(&mut self) {
        self.max_scroll_x = self.max_scroll_x.round().max(0.0);
        self.max_scroll_y = self.max_scroll_y.round().max(0.0);
        self.scroll_x = self.scroll_x.round();
        self.scroll_y = self.scroll_y.round();
        self.clamp();
    }

    fn clamp(&mut self) {
        self.scroll_x = self.scroll_x.clamp(0.0, self.max_scroll_x);
        self.scroll_y = self.scroll_y.clamp(0.0, self.max_scroll_y);
    }

    /// Add fling impulse in px/sec. Multiple impulses are blended.
    pub fn add_fling_impulse(&mut self, vx: f32, vy: f32) {
        if !vx.is_finite() || !vy.is_finite() {
            return;
        }
        let threshold = 1.0_f32;
        if vx.abs() < threshold && vy.abs() < threshold {
            return;
        }
        if self.fling_active {
            self.fling_vx = self.fling_vx * 0.35 + vx * 0.65;
            self.fling_vy = self.fling_vy * 0.35 + vy * 0.65;
        } else {
            self.fling_vx = vx;
            self.fling_vy = vy;
            self.fling_active = true;
        }
    }

    /// Stop any active fling animation.
    pub fn stop_fling(&mut self) {
        self.fling_active = false;
        self.fling_vx = 0.0;
        self.fling_vy = 0.0;
    }

    /// Advance fling simulation.
    ///
    /// Returns true if the scroll position changed.
    pub fn tick_fling(&mut self, dt_seconds: f32, friction: f32) -> bool {
        if !self.fling_active || !dt_seconds.is_finite() || dt_seconds <= 0.0 {
            return false;
        }

        let prev_x = self.scroll_x;
        let prev_y = self.scroll_y;

        self.scroll_x += self.fling_vx * dt_seconds;
        self.scroll_y += self.fling_vy * dt_seconds;
        self.clamp();

        // If we hit a boundary, zero out velocity in that axis.
        if (self.scroll_x <= 0.0 && self.fling_vx < 0.0)
            || (self.scroll_x >= self.max_scroll_x && self.fling_vx > 0.0)
        {
            self.fling_vx = 0.0;
        }
        if (self.scroll_y <= 0.0 && self.fling_vy < 0.0)
            || (self.scroll_y >= self.max_scroll_y && self.fling_vy > 0.0)
        {
            self.fling_vy = 0.0;
        }

        // Exponential damping: ~7x slower speed after 1 second.
        let friction = friction.clamp(0.1, 20.0);
        let damping = (-friction * dt_seconds).exp();
        self.fling_vx *= damping;
        self.fling_vy *= damping;

        let stop_threshold = 8.0_f32;
        if self.fling_vx.abs() < stop_threshold && self.fling_vy.abs() < stop_threshold {
            self.stop_fling();
        }

        (self.scroll_x - prev_x).abs() > f32::EPSILON
            || (self.scroll_y - prev_y).abs() > f32::EPSILON
    }
}

#[cfg(test)]
mod tests {
    use super::ScrollState;
    use crate::layout::LayoutCache;

    fn uniform_layout(rows: i32, cols: i32, row_height: i32, col_width: i32) -> LayoutCache {
        LayoutCache {
            row_positions: Vec::new(),
            col_positions: Vec::new(),
            total_width: cols.saturating_mul(col_width.max(0)),
            total_height: rows.saturating_mul(row_height.max(0)),
            valid: true,
            generation: 0,
            rows,
            cols,
            uniform_rows: true,
            uniform_cols: true,
            uniform_row_height: row_height.max(0),
            uniform_col_width: col_width.max(0),
        }
    }

    #[test]
    fn show_cell_stops_active_fling() {
        let mut scroll = ScrollState::new();
        scroll.max_scroll_x = 10_000.0;
        scroll.max_scroll_y = 10_000.0;
        scroll.scroll_x = 300.0;
        scroll.scroll_y = 400.0;
        scroll.add_fling_impulse(1200.0, 800.0);
        assert!(scroll.fling_active);

        let layout = uniform_layout(500, 20, 24, 80);
        scroll.show_cell(200, 5, &layout, 800, 600, 1, 0, 0, 0);

        assert!(!scroll.fling_active);
        assert_eq!(scroll.fling_vx, 0.0);
        assert_eq!(scroll.fling_vy, 0.0);
    }

    #[test]
    fn update_bounds_clamps_scroll_when_content_shrinks() {
        let mut scroll = ScrollState::new();
        scroll.scroll_x = 640.0;
        scroll.scroll_y = 1_600.0;

        let layout = uniform_layout(20, 10, 20, 80);
        scroll.update_bounds(&layout, 240, 100, 0, 0, 0, 0);

        assert_eq!(scroll.max_scroll_x, 560.0);
        assert_eq!(scroll.max_scroll_y, 300.0);
        assert_eq!(scroll.scroll_x, 560.0);
        assert_eq!(scroll.scroll_y, 300.0);
    }
}
