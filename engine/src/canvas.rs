//! Shared Canvas trait and render_grid orchestration.
//!
//! This module defines the backend-agnostic `Canvas` trait with core drawing
//! primitives, composed default methods, and all render-layer functions that
//! paint a `VolvoxGrid` onto any `Canvas` implementation.
//!
//! Concrete backends live in `canvas_cpu` (pixel-buffer) and `canvas_gpu`
//! (wgpu surface).

use crate::grid::VolvoxGrid;
use crate::proto::volvoxgrid::v1 as pb;
use crate::style::{CellStyleOverride, HeaderMarkHeight, IconThemeSlotStyle};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BorderEdge {
    Top,
    Right,
    Bottom,
    Left,
}

// ===========================================================================
// Canvas trait
// ===========================================================================

/// Backend-agnostic drawing surface.
///
/// Core primitives are implemented by each backend (CPU pixel buffer, GPU).
/// Composed operations have default implementations that call the primitives.
pub trait Canvas {
    // -- Core primitives (backend-specific) ----------------------------------

    /// Fill a rectangle with a solid color (no alpha blending).
    fn fill_rect(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32);

    /// Alpha-blend a semi-transparent rectangle over existing content.
    fn blend_rect(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32);

    /// Draw a horizontal line starting at (x, y) with length `w`.
    fn hline(&mut self, x: i32, y: i32, w: i32, color: u32);

    /// Draw a vertical line starting at (x, y) with height `h`.
    fn vline(&mut self, x: i32, y: i32, h: i32, color: u32);

    /// Set a single pixel.
    fn set_pixel(&mut self, x: i32, y: i32, color: u32);

    /// Draw text at (x, y), clipped to the rectangle (clip_x, clip_y, clip_w, clip_h).
    /// `clip_y` sets the top clip boundary; `clip_h` measures from `y` downward.
    /// Returns rendered width.
    fn draw_text(
        &mut self,
        x: i32,
        y: i32,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        color: u32,
        clip_x: i32,
        clip_y: i32,
        clip_w: i32,
        clip_h: i32,
        max_width: Option<f32>,
    ) -> f32;

    /// Measure text dimensions (width, height).
    fn measure_text(
        &mut self,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> (f32, f32);

    /// Blit RGBA image data stretched to fill (dx, dy, dw, dh).
    fn blit_image(&mut self, dx: i32, dy: i32, dw: i32, dh: i32, data: &[u8], iw: i32, ih: i32);

    /// Blit RGBA image data at native size at (dx, dy).
    fn blit_image_at(&mut self, dx: i32, dy: i32, data: &[u8], iw: i32, ih: i32);

    /// Fill a rectangle with a subtle checker pattern (scrollbar track look).
    fn fill_checker(&mut self, x: i32, y: i32, w: i32, h: i32);

    /// Canvas width in pixels.
    fn width(&self) -> i32;

    /// Canvas height in pixels.
    fn height(&self) -> i32;

    /// Called before overlay layers (editor, dropdown) that should render above grid content.
    fn begin_overlay(&mut self) {}

    /// Called after overlay layers complete.
    fn end_overlay(&mut self) {}

    // -- Composed operations (default implementations) -----------------------

    /// Clear the entire canvas with a solid color.
    fn clear(&mut self, color: u32) {
        let w = self.width();
        let h = self.height();
        self.fill_rect(0, 0, w, h, color);
    }

    /// Draw a 1px rectangle outline.
    fn rect_outline(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        if w <= 0 || h <= 0 {
            return;
        }
        self.hline(x, y, w, color);
        self.hline(x, y + h - 1, w, color);
        self.vline(x, y, h, color);
        self.vline(x + w - 1, y, h, color);
    }

    /// Draw a solid outline with configurable thickness.
    fn rect_outline_thick(&mut self, x: i32, y: i32, w: i32, h: i32, thickness: i32, color: u32) {
        let t = thickness.max(1);
        for i in 0..t {
            let iw = w - i * 2;
            let ih = h - i * 2;
            if iw <= 0 || ih <= 0 {
                break;
            }
            self.rect_outline(x + i, y + i, iw, ih, color);
        }
    }

    /// Draw a dotted or dashed outline.
    fn patterned_rect_outline(
        &mut self,
        x: i32,
        y: i32,
        w: i32,
        h: i32,
        on: i32,
        off: i32,
        thickness: i32,
        color: u32,
    ) {
        if w <= 0 || h <= 0 {
            return;
        }
        let on_len = on.max(1);
        let period = (on + off).max(1);
        let t = thickness.max(1);

        for d in 0..t {
            let ox = x + d;
            let oy = y + d;
            let ow = w - d * 2;
            let oh = h - d * 2;
            if ow <= 0 || oh <= 0 {
                break;
            }

            for i in 0..ow {
                if i % period < on_len {
                    self.set_pixel(ox + i, oy, color);
                    self.set_pixel(ox + i, oy + oh - 1, color);
                }
            }
            for i in 0..oh {
                if i % period < on_len {
                    self.set_pixel(ox, oy + i, color);
                    self.set_pixel(ox + ow - 1, oy + i, color);
                }
            }
        }
    }

    /// Draw a patterned horizontal line with thickness.
    fn patterned_hline(
        &mut self,
        x: i32,
        y: i32,
        w: i32,
        on: i32,
        off: i32,
        thickness: i32,
        color: u32,
    ) {
        if w <= 0 {
            return;
        }
        let on_len = on.max(1);
        let period = (on + off).max(1);
        for d in 0..thickness.max(1) {
            for i in 0..w {
                if i % period < on_len {
                    self.set_pixel(x + i, y + d, color);
                }
            }
        }
    }

    /// Draw a patterned vertical line with thickness.
    fn patterned_vline(
        &mut self,
        x: i32,
        y: i32,
        h: i32,
        on: i32,
        off: i32,
        thickness: i32,
        color: u32,
    ) {
        if h <= 0 {
            return;
        }
        let on_len = on.max(1);
        let period = (on + off).max(1);
        for d in 0..thickness.max(1) {
            for i in 0..h {
                if i % period < on_len {
                    self.set_pixel(x + d, y + i, color);
                }
            }
        }
    }

    /// Draw a dotted (alternating pixel) rectangle outline.
    fn dotted_rect(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        for i in 0..w {
            if i % 2 == 0 {
                self.set_pixel(x + i, y, color);
                self.set_pixel(x + i, y + h - 1, color);
            }
        }
        for i in 0..h {
            if i % 2 == 0 {
                self.set_pixel(x, y + i, color);
                self.set_pixel(x + w - 1, y + i, color);
            }
        }
    }

    /// Draw a 3D raised or inset rectangle border.
    fn rect_3d(&mut self, x: i32, y: i32, w: i32, h: i32, raised: bool) {
        let (tl, br) = if raised {
            (0xFFFFFFFF_u32, 0xFF808080_u32)
        } else {
            (0xFF808080_u32, 0xFFFFFFFF_u32)
        };
        self.hline(x, y, w, tl);
        self.vline(x, y, h, tl);
        self.hline(x, y + h - 1, w, br);
        self.vline(x + w - 1, y, h, br);
    }

    /// Draw a 3D raised/inset border using a base color.
    fn rect_3d_color(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32, raised: bool) {
        let light = lighten(color, 145);
        let dark = darken(color, 70);
        let (tl, br) = if raised { (light, dark) } else { (dark, light) };
        self.hline(x, y, w, tl);
        self.vline(x, y, h, tl);
        self.hline(x, y + h - 1, w, br);
        self.vline(x + w - 1, y, h, br);
    }

    /// Draw a border using VolvoxGrid border style constants.
    fn cell_border_style(&mut self, x: i32, y: i32, w: i32, h: i32, border_style: i32, color: u32) {
        if w <= 0 || h <= 0 {
            return;
        }
        match border_style {
            b if b == pb::BorderStyle::BorderNone as i32 => {}
            b if b == pb::BorderStyle::BorderThin as i32 => self.rect_outline(x, y, w, h, color),
            b if b == pb::BorderStyle::BorderThick as i32 => {
                self.rect_outline_thick(x, y, w, h, 2, color)
            }
            b if b == pb::BorderStyle::BorderDotted as i32 => {
                self.patterned_rect_outline(x, y, w, h, 1, 1, 1, color)
            }
            b if b == pb::BorderStyle::BorderDashed as i32 => {
                self.patterned_rect_outline(x, y, w, h, 4, 2, 1, color)
            }
            b if b == pb::BorderStyle::BorderDouble as i32 => {
                self.rect_outline(x, y, w, h, color);
                if w > 4 && h > 4 {
                    self.rect_outline(x + 2, y + 2, w - 4, h - 4, color);
                }
            }
            b if b == pb::BorderStyle::BorderRaised as i32 => {
                self.rect_3d_color(x, y, w, h, color, true)
            }
            b if b == pb::BorderStyle::BorderInset as i32 => {
                self.rect_3d_color(x, y, w, h, color, false)
            }
            _ => self.rect_outline(x, y, w, h, color),
        }
    }

    /// Draw a border style on a single edge of the cell rectangle.
    fn cell_border_edge_style(
        &mut self,
        x: i32,
        y: i32,
        w: i32,
        h: i32,
        edge: BorderEdge,
        border_style: i32,
        color: u32,
    ) {
        if w <= 0 || h <= 0 {
            return;
        }

        let horizontal = edge == BorderEdge::Top || edge == BorderEdge::Bottom;
        let line_x = if edge == BorderEdge::Right {
            x + w - 1
        } else {
            x
        };
        let line_y = if edge == BorderEdge::Bottom {
            y + h - 1
        } else {
            y
        };

        match border_style {
            b if b == pb::BorderStyle::BorderNone as i32 => {}
            b if b == pb::BorderStyle::BorderThin as i32 => {
                if horizontal {
                    self.hline(x, line_y, w, color);
                } else {
                    self.vline(line_x, y, h, color);
                }
            }
            b if b == pb::BorderStyle::BorderThick as i32 => {
                let t = 2;
                if horizontal {
                    let yy = if edge == BorderEdge::Bottom {
                        y + h - t
                    } else {
                        y
                    };
                    self.fill_rect(x, yy, w, t.min(h), color);
                } else {
                    let xx = if edge == BorderEdge::Right {
                        x + w - t
                    } else {
                        x
                    };
                    self.fill_rect(xx, y, t.min(w), h, color);
                }
            }
            b if b == pb::BorderStyle::BorderDotted as i32 => {
                if horizontal {
                    self.patterned_hline(x, line_y, w, 1, 1, 1, color);
                } else {
                    self.patterned_vline(line_x, y, h, 1, 1, 1, color);
                }
            }
            b if b == pb::BorderStyle::BorderDashed as i32 => {
                if horizontal {
                    self.patterned_hline(x, line_y, w, 4, 2, 1, color);
                } else {
                    self.patterned_vline(line_x, y, h, 4, 2, 1, color);
                }
            }
            b if b == pb::BorderStyle::BorderDouble as i32 => {
                if horizontal {
                    self.hline(x, line_y, w, color);
                    let second_y = if edge == BorderEdge::Bottom {
                        line_y - 2
                    } else {
                        line_y + 2
                    };
                    if second_y >= y && second_y < y + h {
                        self.hline(x, second_y, w, color);
                    }
                } else {
                    self.vline(line_x, y, h, color);
                    let second_x = if edge == BorderEdge::Right {
                        line_x - 2
                    } else {
                        line_x + 2
                    };
                    if second_x >= x && second_x < x + w {
                        self.vline(second_x, y, h, color);
                    }
                }
            }
            b if b == pb::BorderStyle::BorderRaised as i32
                || b == pb::BorderStyle::BorderInset as i32 =>
            {
                let light = lighten(color, 145);
                let dark = darken(color, 70);
                let edge_color = if b == pb::BorderStyle::BorderRaised as i32 {
                    match edge {
                        BorderEdge::Top | BorderEdge::Left => light,
                        BorderEdge::Right | BorderEdge::Bottom => dark,
                    }
                } else {
                    match edge {
                        BorderEdge::Top | BorderEdge::Left => dark,
                        BorderEdge::Right | BorderEdge::Bottom => light,
                    }
                };
                if horizontal {
                    self.hline(x, line_y, w, edge_color);
                } else {
                    self.vline(line_x, y, h, edge_color);
                }
            }
            _ => {
                if horizontal {
                    self.hline(x, line_y, w, color);
                } else {
                    self.vline(line_x, y, h, color);
                }
            }
        }
    }

    /// Draw text with text_style (underline, strikethrough, etc.).
    /// Default implementation delegates to draw_text (text_style is a hint).
    fn draw_text_styled(
        &mut self,
        x: i32,
        y: i32,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        color: u32,
        clip_x: i32,
        clip_y: i32,
        clip_w: i32,
        clip_h: i32,
        text_style: i32,
        max_width: Option<f32>,
    ) -> f32 {
        let tw = self.draw_text(
            x, y, text, font_name, font_size, bold, italic, color, clip_x, clip_y, clip_w, clip_h,
            max_width,
        );
        // text_style bit 0 = underline, bit 1 = strikethrough
        let line_height = (font_size * 1.2).ceil() as i32;
        if text_style & 1 != 0 {
            // Underline
            let uy = y + line_height - 2;
            let line_start = x.max(clip_x);
            let uw = (tw.ceil() as i32).min(clip_x + clip_w - line_start);
            self.hline(line_start, uy, uw.max(0), color);
        }
        if text_style & 2 != 0 {
            // Strikethrough
            let sy = y + line_height / 2;
            let line_start = x.max(clip_x);
            let sw = (tw.ceil() as i32).min(clip_x + clip_w - line_start);
            self.hline(line_start, sy, sw.max(0), color);
        }
        tw
    }

    /// Draw a classic scroll-bar button face.
    fn draw_scroll_button(&mut self, x: i32, y: i32, w: i32, h: i32, face: u32) {
        if w <= 0 || h <= 0 {
            return;
        }
        self.fill_rect(x, y, w, h, face);
        self.rect_3d(x, y, w, h, true);
    }

    /// Draw a classic scroll-bar thumb.
    fn draw_scroll_thumb(&mut self, x: i32, y: i32, w: i32, h: i32, face: u32) {
        if w <= 0 || h <= 0 {
            return;
        }
        self.fill_rect(x, y, w, h, face);
        self.rect_3d(x, y, w, h, true);
    }

    /// Draw a left-pointing scroll arrow.
    fn draw_scroll_arrow_left(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        let size = ((w.min(h) - 8) / 2).max(2);
        let cx = x + w / 2 - 1;
        let cy = y + h / 2;
        for dy in -size..=size {
            let span = size - dy.abs();
            for dx in 0..=span {
                self.set_pixel(cx - dx, cy + dy, color);
            }
        }
    }

    /// Draw a right-pointing scroll arrow.
    fn draw_scroll_arrow_right(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        let size = ((w.min(h) - 8) / 2).max(2);
        let cx = x + w / 2;
        let cy = y + h / 2;
        for dy in -size..=size {
            let span = size - dy.abs();
            for dx in 0..=span {
                self.set_pixel(cx + dx, cy + dy, color);
            }
        }
    }

    /// Draw an up-pointing scroll arrow.
    fn draw_scroll_arrow_up(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        let size = ((w.min(h) - 8) / 2).max(2);
        let cx = x + w / 2;
        let cy = y + h / 2 - 1;
        for dx in -size..=size {
            let span = size - dx.abs();
            for dy in 0..=span {
                self.set_pixel(cx + dx, cy - dy, color);
            }
        }
    }

    /// Draw a down-pointing scroll arrow.
    fn draw_scroll_arrow_down(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        let size = ((w.min(h) - 8) / 2).max(2);
        let cx = x + w / 2;
        let cy = y + h / 2;
        for dx in -size..=size {
            let span = size - dx.abs();
            for dy in 0..=span {
                self.set_pixel(cx + dx, cy + dy, color);
            }
        }
    }
}

// ===========================================================================
// VisibleRange
// ===========================================================================

/// Pre-computed visible ranges for fixed and scrollable row/column regions.
pub(crate) struct VisibleRange {
    /// Exclusive end of fixed + frozen rows.
    pub fixed_row_end: i32,
    /// Exclusive end of fixed + frozen cols.
    pub fixed_col_end: i32,
    /// Scrollable visible row window start (inclusive).
    pub scroll_row_start: i32,
    /// Scrollable visible row window end (exclusive).
    pub scroll_row_end: i32,
    /// Scrollable visible col window start (inclusive).
    pub scroll_col_start: i32,
    /// Scrollable visible col window end (exclusive).
    pub scroll_col_end: i32,
    /// Viewport width in pixels.
    pub viewport_w: i32,
    /// Viewport height in pixels.
    pub viewport_h: i32,
    /// Rows pinned to top (below fixed/frozen rows).
    pub pinned_top_rows: Vec<i32>,
    /// Rows pinned to bottom (footer).
    pub pinned_bottom_rows: Vec<i32>,
    /// Total pixel height of top pinned rows.
    pub pinned_top_height: i32,
    /// Total pixel height of bottom pinned rows.
    pub pinned_bottom_height: i32,
    /// Rows that need sticky overlay at top edge (scrolled past their position).
    pub sticky_top_rows: Vec<i32>,
    /// Rows that need sticky overlay at bottom edge.
    pub sticky_bottom_rows: Vec<i32>,
    /// Columns that need sticky overlay at left edge.
    pub sticky_left_cols: Vec<i32>,
    /// Columns that need sticky overlay at right edge.
    pub sticky_right_cols: Vec<i32>,
    /// Total pixel height of sticky-top rows (for clipping scrollable cells).
    pub sticky_top_height: i32,
    /// Total pixel height of sticky-bottom rows.
    pub sticky_bottom_height: i32,
    /// Total pixel width of sticky-left cols.
    pub sticky_left_width: i32,
    /// Total pixel width of sticky-right cols.
    pub sticky_right_width: i32,
}

impl VisibleRange {
    /// Compute fixed bands and the currently visible scrollable windows.
    pub fn compute(grid: &VolvoxGrid, vp_w: i32, vp_h: i32) -> Self {
        let fixed_row_end = (grid.fixed_rows + grid.frozen_rows).clamp(0, grid.rows);
        let fixed_col_end = (grid.fixed_cols + grid.frozen_cols).clamp(0, grid.cols);

        // Shrink the effective viewport when scrollbars are visible so that
        // pinned-bottom / sticky-bottom rows are placed above the horizontal
        // scrollbar (and pinned-right / sticky-right cols left of the vertical
        // scrollbar) rather than being partially obscured by them.
        const SB_SIZE: i32 = 16;
        let allow_h = grid.scroll_bars == pb::ScrollBarsMode::ScrollbarHorizontal as i32
            || grid.scroll_bars == pb::ScrollBarsMode::ScrollbarBoth as i32;
        let allow_v = grid.scroll_bars == pb::ScrollBarsMode::ScrollbarVertical as i32
            || grid.scroll_bars == pb::ScrollBarsMode::ScrollbarBoth as i32;

        let fixed_height = grid.layout.row_pos(grid.fixed_rows);
        let fixed_width = grid.layout.col_pos(grid.fixed_cols);
        let pinned_height_total = grid.pinned_top_height() + grid.pinned_bottom_height();
        let pinned_width_total = grid.pinned_left_width() + grid.pinned_right_width();
        let (mut show_h, mut show_v) = (false, false);
        for _ in 0..3 {
            let vw = (vp_w - if show_v { SB_SIZE } else { 0 }).max(1);
            let vh = (vp_h - if show_h { SB_SIZE } else { 0 }).max(1);
            let mx = (grid.layout.total_width - vw + fixed_width + pinned_width_total).max(0);
            let my = (grid.layout.total_height - vh + fixed_height + pinned_height_total).max(0);
            let next_h = allow_h && mx > 0;
            let next_v = allow_v && my > 0;
            if next_h == show_h && next_v == show_v {
                break;
            }
            show_h = next_h;
            show_v = next_v;
        }
        let vp_w = if show_v { (vp_w - SB_SIZE).max(1) } else { vp_w };
        let vp_h = if show_h { (vp_h - SB_SIZE).max(1) } else { vp_h };

        // Pinned rows — computed first so we can adjust visible_rows scroll
        let pinned_top_rows = grid.pinned_rows_top.clone();
        let pinned_bottom_rows = grid.pinned_rows_bottom.clone();
        let pinned_top_height = grid.pinned_top_height();
        let pinned_bottom_height = grid.pinned_bottom_height();
        let pinned_left_width = grid.pinned_left_width();
        let pinned_right_width = grid.pinned_right_width();

        let mut scroll_row_start = fixed_row_end;
        let mut scroll_row_end = fixed_row_end;
        if fixed_row_end < grid.rows && vp_h > 0 {
            // Scrollable rows are rendered with a pinned_top_height offset
            // (pushed down to make room for pinned-top rows), so adjust the
            // scroll position used for visible_rows accordingly.
            let adj_scroll = (grid.scroll.scroll_y - pinned_top_height as f32).max(0.0);
            let (first, last) = grid.layout.visible_rows(adj_scroll, vp_h, fixed_row_end);
            if first <= last && first < grid.rows {
                scroll_row_start = (first - 1).max(fixed_row_end);
                scroll_row_end = (last + 2).min(grid.rows);
            }
        }

        let mut scroll_col_start = fixed_col_end;
        let mut scroll_col_end = fixed_col_end;
        if fixed_col_end < grid.cols && vp_w > 0 {
            let scrollable_w = (vp_w - pinned_left_width - pinned_right_width).max(0);
            let (first, last) =
                grid.layout
                    .visible_cols(grid.scroll.scroll_x, scrollable_w, fixed_col_end);
            if first <= last && first < grid.cols {
                scroll_col_start = (first - 1).max(fixed_col_end);
                scroll_col_end = (last + 2).min(grid.cols);
            }
        }

        // Sticky rows: find rows marked sticky that are NOT currently visible
        // on screen. Uses cascading thresholds so that when row A sticks at
        // the top, row B becomes sticky when it reaches the bottom of A
        // (just like CSS position:sticky with stacking).
        let mut sticky_top_candidates = Vec::new();
        let mut sticky_bottom_candidates = Vec::new();
        let fixed_bottom = grid.layout.row_pos(fixed_row_end);
        let scrollable_top = fixed_bottom + pinned_top_height;
        let scrollable_bottom = vp_h - pinned_bottom_height;
        for (&row, &edge) in &grid.sticky_rows {
            if grid.is_row_pinned(row) != 0 || row < fixed_row_end {
                continue;
            }
            let is_both = edge == pb::StickyEdge::StickyBoth as i32;
            if is_both || edge == pb::StickyEdge::StickyTop as i32 {
                sticky_top_candidates.push(row);
            }
            if is_both || edge == pb::StickyEdge::StickyBottom as i32 {
                sticky_bottom_candidates.push(row);
            }
        }
        // Process top-sticky in ascending row order with cascading threshold
        sticky_top_candidates.sort_unstable();
        let mut sticky_top_rows = Vec::new();
        let mut threshold_top = scrollable_top;
        for row in sticky_top_candidates {
            let screen_y =
                grid.layout.row_pos(row) - grid.scroll.scroll_y as i32 + pinned_top_height;
            if screen_y < threshold_top {
                sticky_top_rows.push(row);
                threshold_top += grid.row_height(row);
            }
        }
        // Process bottom-sticky in descending row order with cascading threshold
        sticky_bottom_candidates.sort_unstable_by(|a, b| b.cmp(a));
        let mut sticky_bottom_rows = Vec::new();
        let mut threshold_bottom = scrollable_bottom;
        for row in sticky_bottom_candidates {
            let screen_y =
                grid.layout.row_pos(row) - grid.scroll.scroll_y as i32 + pinned_top_height;
            let row_h = grid.row_height(row);
            if screen_y + row_h > threshold_bottom {
                sticky_bottom_rows.push(row);
                threshold_bottom -= row_h;
            }
        }
        sticky_top_rows.sort_unstable();
        sticky_bottom_rows.sort_unstable();

        // Sticky cols: cascading thresholds (same logic as sticky rows).
        let mut sticky_left_candidates = Vec::new();
        let mut sticky_right_candidates = Vec::new();
        let fixed_right = grid.layout.col_pos(fixed_col_end);
        for (&col, &edge) in &grid.sticky_cols {
            if col < fixed_col_end {
                continue;
            }
            if grid.is_col_pinned(col) != 0 {
                continue;
            }
            let is_both = edge == pb::StickyEdge::StickyBoth as i32;
            if is_both || edge == pb::StickyEdge::StickyLeft as i32 {
                sticky_left_candidates.push(col);
            }
            if is_both || edge == pb::StickyEdge::StickyRight as i32 {
                sticky_right_candidates.push(col);
            }
        }
        sticky_left_candidates.sort_unstable();
        let mut sticky_left_cols = Vec::new();
        let mut threshold_left = fixed_right;
        for col in sticky_left_candidates {
            let screen_x = grid.layout.col_pos(col) - grid.scroll.scroll_x as i32;
            if screen_x < threshold_left {
                sticky_left_cols.push(col);
                threshold_left += grid.col_width(col);
            }
        }
        sticky_right_candidates.sort_unstable_by(|a, b| b.cmp(a));
        let mut sticky_right_cols = Vec::new();
        let mut threshold_right = vp_w;
        for col in sticky_right_candidates {
            let screen_x = grid.layout.col_pos(col) - grid.scroll.scroll_x as i32;
            let col_w = grid.col_width(col);
            if screen_x + col_w > threshold_right {
                sticky_right_cols.push(col);
                threshold_right -= col_w;
            }
        }
        for &col in &grid.pinned_cols_left {
            if col < fixed_col_end || grid.is_col_hidden(col) {
                continue;
            }
            if !sticky_left_cols.contains(&col) {
                sticky_left_cols.push(col);
            }
        }
        for &col in &grid.pinned_cols_right {
            if col < fixed_col_end || grid.is_col_hidden(col) {
                continue;
            }
            if !sticky_right_cols.contains(&col) {
                sticky_right_cols.push(col);
            }
        }
        sticky_left_cols.sort_unstable();
        sticky_right_cols.sort_unstable();

        // Compute total pixel sizes for sticky overlay areas (used for clipping)
        let sticky_top_height: i32 = sticky_top_rows.iter().map(|&r| grid.row_height(r)).sum();
        let sticky_bottom_height: i32 =
            sticky_bottom_rows.iter().map(|&r| grid.row_height(r)).sum();
        let sticky_left_width: i32 = sticky_left_cols.iter().map(|&c| grid.col_width(c)).sum();
        let sticky_right_width: i32 = sticky_right_cols.iter().map(|&c| grid.col_width(c)).sum();

        Self {
            fixed_row_end,
            fixed_col_end,
            scroll_row_start,
            scroll_row_end,
            scroll_col_start,
            scroll_col_end,
            viewport_w: vp_w,
            viewport_h: vp_h,
            pinned_top_rows,
            pinned_bottom_rows,
            pinned_top_height,
            pinned_bottom_height,
            sticky_top_rows,
            sticky_bottom_rows,
            sticky_left_cols,
            sticky_right_cols,
            sticky_top_height,
            sticky_bottom_height,
            sticky_left_width,
            sticky_right_width,
        }
    }
}

// ===========================================================================
// Helper: iterate visible cells
// ===========================================================================

/// Call `f(row, col, cell_x, cell_y, cell_w, cell_h)` for every visible cell
/// in the viewport. Fixed cells are always included regardless of scroll
/// offset. For merged cells the rectangle spans the full merge.
///
/// Render order (z-index bottom to top):
/// 1. Scrollable cells (normal, skipping pinned rows)
/// 2. Sticky overlay cells
/// 3. Pinned rows (top then bottom)
/// 4. Fixed/frozen cells (topmost)
pub(crate) fn iter_visible_cells<F>(grid: &VolvoxGrid, vp: &VisibleRange, mut f: F)
where
    F: FnMut(i32, i32, i32, i32, i32, i32),
{
    let col_ranges = [
        (vp.scroll_col_start, vp.scroll_col_end),
        (0, vp.fixed_col_end),
    ];

    // 1. Scrollable cells — skip pinned, sticky rows/cols (handled later)
    for row in vp.scroll_row_start..vp.scroll_row_end {
        if grid.is_row_hidden(row)
            || grid.is_row_pinned(row) != 0
            || vp.sticky_top_rows.contains(&row)
            || vp.sticky_bottom_rows.contains(&row)
        {
            continue;
        }
        for (col_start, col_end) in col_ranges {
            for col in col_start..col_end {
                if grid.is_col_hidden(col)
                    || vp.sticky_left_cols.contains(&col)
                    || vp.sticky_right_cols.contains(&col)
                {
                    continue;
                }
                if let Some((cx, cy, cw, ch)) = cell_rect(grid, row, col, vp) {
                    f(row, col, cx, cy, cw, ch);
                }
            }
        }
    }

    // 2. Sticky overlay rows (top and bottom edges)
    for &row in vp
        .sticky_top_rows
        .iter()
        .chain(vp.sticky_bottom_rows.iter())
    {
        for (col_start, col_end) in col_ranges {
            for col in col_start..col_end {
                if grid.is_col_hidden(col) {
                    continue;
                }
                if let Some((cx, cy, cw, ch)) = cell_rect(grid, row, col, vp) {
                    f(row, col, cx, cy, cw, ch);
                }
            }
        }
    }

    // 2b. Sticky overlay cols (left and right edges)
    //     Skip sticky rows (already emitted in Pass 2 above) and pinned rows
    //     (emitted in Pass 3).
    let row_ranges_for_sticky = [
        (vp.scroll_row_start, vp.scroll_row_end),
        (0, vp.fixed_row_end),
    ];
    for &col in vp
        .sticky_left_cols
        .iter()
        .chain(vp.sticky_right_cols.iter())
    {
        for (row_start, row_end) in row_ranges_for_sticky {
            for row in row_start..row_end {
                if grid.is_row_hidden(row)
                    || grid.is_row_pinned(row) != 0
                    || vp.sticky_top_rows.contains(&row)
                    || vp.sticky_bottom_rows.contains(&row)
                {
                    continue;
                }
                if let Some((cx, cy, cw, ch)) = cell_rect(grid, row, col, vp) {
                    f(row, col, cx, cy, cw, ch);
                }
            }
        }
    }

    // 3. Pinned rows (top then bottom)
    for &row in vp
        .pinned_top_rows
        .iter()
        .chain(vp.pinned_bottom_rows.iter())
    {
        if grid.is_row_hidden(row) {
            continue;
        }
        for (col_start, col_end) in col_ranges {
            for col in col_start..col_end {
                if grid.is_col_hidden(col) {
                    continue;
                }
                if let Some((cx, cy, cw, ch)) = cell_rect(grid, row, col, vp) {
                    f(row, col, cx, cy, cw, ch);
                }
            }
        }
    }

    // 4. Fixed/frozen cells (topmost)
    for row in 0..vp.fixed_row_end {
        if grid.is_row_hidden(row) {
            continue;
        }
        for (col_start, col_end) in col_ranges {
            for col in col_start..col_end {
                if grid.is_col_hidden(col) {
                    continue;
                }
                if let Some((cx, cy, cw, ch)) = cell_rect(grid, row, col, vp) {
                    f(row, col, cx, cy, cw, ch);
                }
            }
        }
    }
}

// ===========================================================================
// Helper: cell_rect
// ===========================================================================

/// Compute the pixel rectangle for a cell, accounting for scroll offset,
/// fixed/frozen state, hidden rows/cols, cell merging, pin, and sticky.
pub(crate) fn cell_rect(
    grid: &VolvoxGrid,
    row: i32,
    col: i32,
    vp: &VisibleRange,
) -> Option<(i32, i32, i32, i32)> {
    let mut x = grid.col_pos(col);
    let mut y = grid.row_pos(row);
    let mut w = grid.col_width(col);
    let mut h = grid.row_height(row);

    if w <= 0 || h <= 0 {
        return None;
    }

    // Check if this row is pinned — override y position
    let pin = grid.is_row_pinned(row);
    if pin != 0 {
        let fixed_bottom = grid.row_pos(grid.fixed_rows + grid.frozen_rows);
        if pin == 1 {
            // Top-pinned: stack below fixed/frozen area
            let mut pin_y = fixed_bottom;
            for &r in &vp.pinned_top_rows {
                if r == row {
                    break;
                }
                pin_y += grid.row_height(r);
            }
            y = pin_y;
        } else {
            // Bottom-pinned: stack from bottom of viewport upward
            let mut pin_y = vp.viewport_h - vp.pinned_bottom_height;
            for &r in &vp.pinned_bottom_rows {
                if r == row {
                    break;
                }
                pin_y += grid.row_height(r);
            }
            y = pin_y;
        }
        // Pinned rows don't scroll vertically, but do scroll horizontally
        let is_col_scrollable = col >= grid.fixed_cols + grid.frozen_cols;
        if is_col_scrollable {
            x -= grid.scroll.scroll_x as i32;
        }
        // Handle sticky cols for pinned rows
        if vp.sticky_left_cols.contains(&col) {
            let fixed_right = grid.col_pos(grid.fixed_cols + grid.frozen_cols);
            x = fixed_right;
        } else if vp.sticky_right_cols.contains(&col) {
            x = vp.viewport_w - w;
        } else if is_col_scrollable {
            // Clip scrollable cols against sticky area for pinned rows
            let clip_left = grid.col_pos(grid.fixed_cols + grid.frozen_cols)
                + vp.sticky_left_width;
            if x < clip_left {
                let clip = clip_left - x;
                w -= clip;
                x = clip_left;
                if w <= 0 {
                    return None;
                }
            }
            let clip_right = vp.viewport_w - vp.sticky_right_width;
            if x + w > clip_right {
                w = clip_right - x;
                if w <= 0 {
                    return None;
                }
            }
        }
        if grid.right_to_left {
            x = vp.viewport_w - (x + w);
        }
        if x + w <= 0 || y + h <= 0 || x >= vp.viewport_w || y >= vp.viewport_h {
            return None;
        }
        return Some((x, y, w, h));
    }

    // Check sticky flags
    let is_sticky_top_row = vp.sticky_top_rows.contains(&row);
    let is_sticky_bottom_row = vp.sticky_bottom_rows.contains(&row);
    let is_sticky_left_col = vp.sticky_left_cols.contains(&col);
    let is_sticky_right_col = vp.sticky_right_cols.contains(&col);
    let is_sticky_row = is_sticky_top_row || is_sticky_bottom_row;
    let is_sticky_col = is_sticky_left_col || is_sticky_right_col;

    // Apply animation offsets (before scroll subtraction)
    if grid.animation.active {
        y += grid.animation.row_offset(row) as i32;
        x += grid.animation.col_offset(col) as i32;
    }

    let is_row_scrollable = row >= grid.fixed_rows + grid.frozen_rows;
    let is_col_scrollable = col >= grid.fixed_cols + grid.frozen_cols;

    if is_row_scrollable {
        y -= grid.scroll.scroll_y as i32;
        // Offset scrollable rows downward to make room for pinned-top rows
        y += vp.pinned_top_height;
    }
    if is_col_scrollable {
        x -= grid.scroll.scroll_x as i32;
    }

    // Handle merged cells
    if let Some((mr1, mc1, mr2, mc2)) = grid.get_merged_range(row, col) {
        if mr1 != mr2 || mc1 != mc2 {
            x = grid.col_pos(mc1);
            y = grid.row_pos(mr1);
            if is_col_scrollable {
                x -= grid.scroll.scroll_x as i32;
            }
            if is_row_scrollable {
                y -= grid.scroll.scroll_y as i32;
                y += vp.pinned_top_height;
            }

            w = 0;
            for c in mc1..=mc2 {
                w += grid.col_width(c);
            }
            h = 0;
            for r in mr1..=mr2 {
                h += grid.row_height(r);
            }
        }
    }

    // ── Sticky position override (BEFORE clipping) ──
    // Sticky rows/cols that scrolled out of view are repositioned to stick
    // at the viewport edge. This must happen before clipping, otherwise the
    // row at its original (scrolled-out) position gets rejected.
    if is_sticky_top_row {
        let fixed_bottom = grid.row_pos(grid.fixed_rows + grid.frozen_rows);
        let mut sticky_y = fixed_bottom + vp.pinned_top_height;
        for &sr in &vp.sticky_top_rows {
            if sr == row {
                break;
            }
            sticky_y += grid.row_height(sr);
        }
        y = sticky_y;
        h = grid.row_height(row); // reset h (merge may have changed it)
    } else if is_sticky_bottom_row {
        let mut sticky_y = vp.viewport_h - vp.pinned_bottom_height;
        for &sr in vp.sticky_bottom_rows.iter().rev() {
            sticky_y -= grid.row_height(sr);
            if sr == row {
                break;
            }
        }
        y = sticky_y;
        h = grid.row_height(row);
    }

    if is_sticky_left_col {
        let fixed_right = grid.col_pos(grid.fixed_cols + grid.frozen_cols);
        x = fixed_right;
        for &sc in &vp.sticky_left_cols {
            if sc == col {
                break;
            }
            x += grid.col_width(sc);
        }
        w = grid.col_width(col);
    } else if is_sticky_right_col {
        x = vp.viewport_w - w;
        for &sc in vp.sticky_right_cols.iter().rev() {
            if sc == col {
                break;
            }
            x -= grid.col_width(sc);
        }
        w = grid.col_width(col);
    }

    // ── Clip scrollable cells to fixed/pinned/sticky area ──
    // Sticky-positioned cells bypass clipping (they're already placed correctly).
    if is_row_scrollable && !is_sticky_row {
        let clip_top = grid.row_pos(grid.fixed_rows + grid.frozen_rows)
            + vp.pinned_top_height
            + vp.sticky_top_height;
        if y < clip_top {
            let clip = clip_top - y;
            h -= clip;
            y = clip_top;
            if h <= 0 {
                return None;
            }
        }
        let clip_bottom = vp.viewport_h - vp.pinned_bottom_height - vp.sticky_bottom_height;
        if y + h > clip_bottom {
            h = clip_bottom - y;
            if h <= 0 {
                return None;
            }
        }
    }
    if is_col_scrollable && !is_sticky_col {
        let fixed_right = grid.col_pos(grid.fixed_cols + grid.frozen_cols) + vp.sticky_left_width;
        if x < fixed_right {
            let clip = fixed_right - x;
            w -= clip;
            x = fixed_right;
            if w <= 0 {
                return None;
            }
        }
        let clip_right = vp.viewport_w - vp.sticky_right_width;
        if x + w > clip_right {
            w = clip_right - x;
            if w <= 0 {
                return None;
            }
        }
    }

    if grid.extend_last_col && col == grid.cols - 1 && x < vp.viewport_w {
        w = w.max(vp.viewport_w - x);
    }

    if grid.right_to_left {
        x = vp.viewport_w - (x + w);
    }

    // Clip to viewport
    if x + w <= 0 || y + h <= 0 || x >= vp.viewport_w || y >= vp.viewport_h {
        return None;
    }

    Some((x, y, w, h))
}

/// Compute the original (pre-clip) pixel rectangle for a cell.
///
/// `cell_rect()` clips scrollable cells against fixed/frozen/sticky
/// boundaries.  This function reconstructs the position and size before
/// that clipping was applied so that renderers can position content at
/// its natural location and let per-pixel drawing clip at the buffer
/// edges.
///
/// Clipping in `cell_rect` is axis-independent:
///   * X is clipped when the column is scrollable AND not sticky/pinned.
///   * Y is clipped when the row is scrollable AND not sticky/pinned.
///
/// So a sticky-left column with a scrollable row needs original Y but
/// keeps the sticky X.  A sticky-top row with a scrollable column needs
/// original X but keeps the sticky Y.  Pinned rows return from
/// `cell_rect` before any clipping, so they are never adjusted here.
fn original_cell_bounds(
    grid: &VolvoxGrid,
    row: i32,
    col: i32,
    cx: i32,
    cy: i32,
    cw: i32,
    ch: i32,
    vp: &VisibleRange,
) -> (i32, i32, i32, i32) {
    let is_row_scrollable = row >= grid.fixed_rows + grid.frozen_rows;
    let is_col_scrollable = col >= grid.fixed_cols + grid.frozen_cols;
    let is_pinned = grid.is_row_pinned(row) != 0;
    let is_sticky_row = vp.sticky_top_rows.contains(&row)
        || vp.sticky_bottom_rows.contains(&row);
    let is_sticky_col = vp.sticky_left_cols.contains(&col)
        || vp.sticky_right_cols.contains(&col);

    // cell_rect clips X when: is_col_scrollable && !is_sticky_col
    // cell_rect clips Y when: is_row_scrollable && !is_sticky_row
    // Pinned rows return before clipping → never clipped.
    let need_orig_x = is_col_scrollable && !is_sticky_col && !is_pinned;
    let need_orig_y = is_row_scrollable && !is_sticky_row && !is_pinned;

    if !need_orig_x && !need_orig_y {
        return (cx, cy, cw, ch);
    }

    // Reconstruct the axis(es) that cell_rect clipped.
    if let Some((mr1, mc1, mr2, mc2)) = grid.get_merged_range(row, col) {
        if mr1 != mr2 || mc1 != mc2 {
            let (ox, ow) = if need_orig_x {
                let ox = grid.col_pos(mc1) - grid.scroll.scroll_x as i32;
                let ow: i32 = (mc1..=mc2).map(|c| grid.col_width(c)).sum();
                (ox, ow)
            } else {
                (cx, cw)
            };
            let (oy, oh) = if need_orig_y {
                let oy = grid.row_pos(mr1) - grid.scroll.scroll_y as i32
                    + vp.pinned_top_height;
                let oh: i32 = (mr1..=mr2).map(|r| grid.row_height(r)).sum();
                (oy, oh)
            } else {
                (cy, ch)
            };
            return (ox, oy, ow, oh);
        }
    }

    let (ox, ow) = if need_orig_x {
        let ox = grid.col_pos(col) - grid.scroll.scroll_x as i32;
        (ox, grid.col_width(col))
    } else {
        (cx, cw)
    };
    let (oy, oh) = if need_orig_y {
        let oy = grid.row_pos(row) - grid.scroll.scroll_y as i32
            + vp.pinned_top_height;
        (oy, grid.row_height(row))
    } else {
        (cy, ch)
    };
    (ox, oy, ow, oh)
}

// ===========================================================================
// Color helpers
// ===========================================================================

/// Darken a color by a percentage (0..100 where 100 = no change, 0 = black).
pub(crate) fn darken(color: u32, percent: u32) -> u32 {
    let a = (color >> 24) & 0xFF;
    let r = ((color >> 16) & 0xFF) * percent / 100;
    let g = ((color >> 8) & 0xFF) * percent / 100;
    let b = (color & 0xFF) * percent / 100;
    (a << 24) | (r << 16) | (g << 8) | b
}

/// Lighten a color by a percentage (100 = no change, 200 ~= 2x brightness).
pub(crate) fn lighten(color: u32, percent: u32) -> u32 {
    let a = (color >> 24) & 0xFF;
    let p = percent.max(100);
    let r = (((color >> 16) & 0xFF) * p / 100).min(255);
    let g = (((color >> 8) & 0xFF) * p / 100).min(255);
    let b = ((color & 0xFF) * p / 100).min(255);
    (a << 24) | (r << 16) | (g << 8) | b
}

// ===========================================================================
// Alignment helpers
// ===========================================================================

/// Decompose a combined alignment value into horizontal (0=left, 1=center,
/// 2=right) and vertical (0=top, 1=center, 2=bottom) components.
pub(crate) fn alignment_components(align: i32) -> (i32, i32) {
    match align {
        a if a == pb::Align::LeftTop as i32 => (0, 0),
        a if a == pb::Align::LeftCenter as i32 => (0, 1),
        a if a == pb::Align::LeftBottom as i32 => (0, 2),
        a if a == pb::Align::CenterTop as i32 => (1, 0),
        a if a == pb::Align::CenterCenter as i32 => (1, 1),
        a if a == pb::Align::CenterBottom as i32 => (1, 2),
        a if a == pb::Align::RightTop as i32 => (2, 0),
        a if a == pb::Align::RightCenter as i32 => (2, 1),
        a if a == pb::Align::RightBottom as i32 => (2, 2),
        _ => (0, 1), // default: left-center
    }
}

// ===========================================================================
// Text helpers
// ===========================================================================

/// Quick heuristic: does this text look like a number?
pub(crate) fn text_looks_numeric(text: &str) -> bool {
    if text.is_empty() {
        return false;
    }
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return false;
    }
    let s = trimmed.trim_start_matches(|c: char| {
        c == '-' || c == '+' || c == '$' || c == '\u{20AC}' || c == '\u{00A3}'
    });
    if s.is_empty() {
        return false;
    }
    let first = s.chars().next().unwrap();
    if !first.is_ascii_digit() && first != '.' {
        return false;
    }
    s.chars()
        .all(|c| c.is_ascii_digit() || c == '.' || c == ',' || c == '%')
}

/// Parse progress percent from cell text.  Handles "75%", "75", "0.75".
pub(crate) fn parse_progress_percent(text: &str) -> f32 {
    let t = text.trim();
    if t.is_empty() {
        return 0.0;
    }
    let (num_str, is_percent) = if let Some(s) = t.strip_suffix('%') {
        (s.trim(), true)
    } else {
        (t, false)
    };
    let cleaned = num_str.replace(',', "");
    if let Ok(v) = cleaned.parse::<f32>() {
        let pct = if is_percent || v > 1.0 { v / 100.0 } else { v };
        if pct >= 0.0 && pct <= 1.0 {
            pct
        } else {
            0.0
        }
    } else {
        0.0
    }
}

/// Format a number with comma separators (e.g. 1000000 -> "1,000,000").
pub(crate) fn format_number(n: i32) -> String {
    let s = n.to_string();
    let bytes = s.as_bytes();
    let neg = bytes[0] == b'-';
    let digits = if neg { &bytes[1..] } else { bytes };
    let mut result = String::new();
    for (i, &b) in digits.iter().enumerate() {
        if i > 0 && (digits.len() - i) % 3 == 0 {
            result.push(',');
        }
        result.push(b as char);
    }
    if neg {
        format!("-{}", result)
    } else {
        result
    }
}

/// Convert a character index into a byte offset for UTF-8 strings.
pub(crate) fn byte_index_at_char(text: &str, char_index: i32) -> usize {
    let target = char_index.max(0) as usize;
    if target == 0 {
        return 0;
    }
    match text.char_indices().nth(target) {
        Some((idx, _)) => idx,
        None => text.len(),
    }
}

/// Decode a PNG byte slice into raw RGBA pixel data + dimensions.
/// Returns `None` if the data is not valid PNG.
pub(crate) fn decode_png_rgba(data: &[u8]) -> Option<(Vec<u8>, i32, i32)> {
    if data.len() < 8 || &data[0..8] != b"\x89PNG\r\n\x1a\n" {
        return None;
    }
    let pixmap = tiny_skia::Pixmap::decode_png(data).ok()?;
    let w = pixmap.width() as i32;
    let h = pixmap.height() as i32;
    Some((pixmap.data().to_vec(), w, h))
}

/// Resolve the alignment for a cell, considering column defaults, cell
/// overrides, and pb::Align::General as i32 (left for text, right for numbers).
pub(crate) fn resolve_alignment(
    grid: &VolvoxGrid,
    row: i32,
    col: i32,
    style_override: &CellStyleOverride,
    text: &str,
) -> i32 {
    // Check cell-level override first
    if let Some(a) = style_override.alignment {
        if a != pb::Align::General as i32 {
            return a;
        }
    }

    // Then column-level alignment
    let is_fixed = row < grid.fixed_rows || col < grid.fixed_cols;
    if let Some(cp) = grid.get_col_props(col) {
        if is_fixed {
            // When FixedAlignment stays at its default
            // left-center, an explicit ColAlignment still affects headers.
            if cp.fixed_alignment != pb::Align::General as i32 {
                if cp.fixed_alignment == pb::Align::LeftCenter as i32
                    && cp.alignment != pb::Align::General as i32
                {
                    return cp.alignment;
                }
                return cp.fixed_alignment;
            }
            if cp.alignment != pb::Align::General as i32 {
                return cp.alignment;
            }
        } else if cp.alignment != pb::Align::General as i32 {
            return cp.alignment;
        }
    }

    // Fixed/header cells default to left alignment.
    if is_fixed {
        return pb::Align::LeftCenter as i32;
    }

    // pb::Align::General as i32 for data cells: right-align numbers/dates, left-align text
    let col_data_type = grid.get_col_props(col).map_or(0, |cp| cp.data_type);
    if col_data_type == pb::ColumnDataType::ColumnDataDate as i32 {
        pb::Align::RightCenter as i32
    } else if col_data_type == pb::ColumnDataType::ColumnDataBoolean as i32 {
        pb::Align::CenterCenter as i32
    } else if text_looks_numeric(text) {
        pb::Align::RightCenter as i32
    } else {
        pb::Align::LeftCenter as i32
    }
}

/// Whether a dropdown button should be shown for a given cell.
pub(crate) fn show_dropdown_button_for_cell(grid: &VolvoxGrid, row: i32, col: i32) -> bool {
    let list = grid.active_dropdown_list(row, col);
    if list.is_empty() {
        return false;
    }
    match grid.dropdown_trigger {
        b if b == pb::DropdownTrigger::DropdownAlways as i32 => true,
        b if b == pb::DropdownTrigger::DropdownOnEdit as i32 => {
            grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col
        }
        /* ActiveX compatibility: show on current cell when dropdown lists exist. */
        3 => grid.selection.row == row && grid.selection.col == col,
        _ => false,
    }
}

/// Compute the pixel rect for a dropdown button within a cell.
pub(crate) fn dropdown_button_rect(
    cx: i32,
    cy: i32,
    cw: i32,
    ch: i32,
) -> Option<(i32, i32, i32, i32)> {
    if cw <= 2 || ch <= 2 {
        return None;
    }
    let mut bw = (ch - 2).clamp(12, 18);
    bw = bw.min((cw - 2).max(0));
    let bh = (ch - 2).max(0);
    if bw <= 0 || bh <= 0 {
        return None;
    }
    let bx = cx + cw - bw - 1;
    let by = cy + 1;
    Some((bx, by, bw, bh))
}

/// Truncate text to fit within `max_width`, appending "..." if needed.
pub(crate) fn compute_ellipsis_text<C: Canvas>(
    canvas: &mut C,
    text: &str,
    font_name: &str,
    font_size: f32,
    bold: bool,
    italic: bool,
    max_width: f32,
) -> String {
    let ellipsis = "...";
    let (ew, _) = canvas.measure_text(ellipsis, font_name, font_size, bold, italic, None);
    let available = max_width - ew;
    if available <= 0.0 {
        return ellipsis.to_string();
    }

    let chars: Vec<char> = text.chars().collect();
    let mut lo = 0_usize;
    let mut hi = chars.len();
    let mut best = 0_usize;

    while lo <= hi && hi > 0 {
        let mid = (lo + hi) / 2;
        let sub: String = chars[..mid].iter().collect();
        let (tw, _) = canvas.measure_text(&sub, font_name, font_size, bold, italic, None);
        if tw <= available {
            best = mid;
            lo = mid + 1;
        } else {
            if mid == 0 {
                break;
            }
            hi = mid - 1;
        }
    }

    let prefix: String = chars[..best].iter().collect();
    format!("{}{}", prefix, ellipsis)
}

/// Truncate text in "path style", keeping both prefix and suffix with "..."
/// in the middle.
pub(crate) fn compute_ellipsis_path_text<C: Canvas>(
    canvas: &mut C,
    text: &str,
    font_name: &str,
    font_size: f32,
    bold: bool,
    italic: bool,
    max_width: f32,
) -> String {
    let chars: Vec<char> = text.chars().collect();
    if chars.len() <= 1 {
        return text.to_string();
    }

    let ellipsis = "...";
    let (ew, _) = canvas.measure_text(ellipsis, font_name, font_size, bold, italic, None);
    if ew >= max_width {
        return ellipsis.to_string();
    }

    let mut keep_left = ((chars.len() as f32) * 0.5).ceil() as usize;
    let mut keep_right = chars.len().saturating_sub(keep_left);
    keep_left = keep_left.max(1);
    keep_right = keep_right.max(1);

    loop {
        if keep_left + keep_right >= chars.len() {
            let full = text.to_string();
            let (tw, _) = canvas.measure_text(&full, font_name, font_size, bold, italic, None);
            if tw <= max_width {
                return full;
            }
        }

        let prefix: String = chars[..keep_left].iter().collect();
        let suffix_start = chars.len().saturating_sub(keep_right);
        let suffix: String = chars[suffix_start..].iter().collect();
        let candidate = format!("{}{}{}", prefix, ellipsis, suffix);
        let (tw, _) = canvas.measure_text(&candidate, font_name, font_size, bold, italic, None);
        if tw <= max_width {
            return candidate;
        }

        if keep_left >= keep_right && keep_left > 1 {
            keep_left -= 1;
        } else if keep_right > 1 {
            keep_right -= 1;
        } else if keep_left > 1 {
            keep_left -= 1;
        } else {
            return ellipsis.to_string();
        }
    }
}

// ===========================================================================
// render_grid -- main entry point
// ===========================================================================

/// Render the entire grid onto a Canvas. Returns dirty rect (x, y, w, h).
pub fn render_grid<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C) -> (i32, i32, i32, i32) {
    let w = canvas.width();
    let h = canvas.height();
    if w <= 0 || h <= 0 {
        return (0, 0, 0, 0);
    }

    grid.span.clear_span_cache();

    let vp = VisibleRange::compute(grid, w, h);
    canvas.clear(grid.style.back_color_bkg);

    // Pre-compute visible cells once; every layer reuses this slice.
    let mut vis_cells: Vec<(i32, i32, i32, i32, i32, i32)> = Vec::new();
    iter_visible_cells(grid, &vp, |row, col, cx, cy, cw, ch| {
        vis_cells.push((row, col, cx, cy, cw, ch));
    });

    render_overlay_bands(grid, canvas, &vp);
    render_backgrounds(grid, canvas, &vis_cells);

    if grid.style.progress_color != 0
        || grid.columns.iter().any(|c| c.progress_color != 0)
    {
        render_progress_bars(grid, canvas, &vis_cells);
    }

    if grid.style.grid_lines != pb::GridLineStyle::GridlineNone as i32
        || grid.style.grid_lines_fixed != pb::GridLineStyle::GridlineNone as i32
    {
        render_grid_lines(grid, canvas, &vis_cells);
    }

    render_header_marks(grid, canvas, &vp);
    render_background_image(grid, canvas);

    if grid.cell_styles.values().any(|s| {
        s.border.is_some()
            || s.border_color.is_some()
            || s.border_top.is_some()
            || s.border_right.is_some()
            || s.border_bottom.is_some()
            || s.border_left.is_some()
            || s.border_top_color.is_some()
            || s.border_right_color.is_some()
            || s.border_bottom_color.is_some()
            || s.border_left_color.is_some()
    }) {
        render_cell_borders(grid, canvas, &vis_cells);
    }

    render_cell_text(grid, canvas, &vp, &vis_cells);
    render_cell_pictures(grid, canvas, &vp, &vis_cells);
    render_sort_glyphs(grid, canvas, &vp);
    render_col_drag_marker(grid, canvas, &vp);

    if grid
        .columns
        .iter()
        .any(|c| c.data_type == pb::ColumnDataType::ColumnDataBoolean as i32)
        || grid.style.checkbox_checked_picture.is_some()
        || grid.style.checkbox_unchecked_picture.is_some()
        || grid.style.checkbox_indeterminate_picture.is_some()
        || grid
            .style
            .icon_theme_slots
            .checkbox_checked
            .as_ref()
            .is_some_and(|s| !s.trim().is_empty())
        || grid
            .style
            .icon_theme_slots
            .checkbox_unchecked
            .as_ref()
            .is_some_and(|s| !s.trim().is_empty())
        || grid
            .style
            .icon_theme_slots
            .checkbox_indeterminate
            .as_ref()
            .is_some_and(|s| !s.trim().is_empty())
    {
        render_checkboxes(grid, canvas, &vp, &vis_cells);
    }

    if grid.dropdown_trigger != 0
        && grid.columns.iter().any(|c| !c.dropdown_items.is_empty())
    {
        render_dropdown_buttons(grid, canvas, &vp, &vis_cells);
    }

    render_selection(grid, canvas, &vis_cells);
    render_edit_highlights(grid, canvas, &vp);
    render_focus_rect(grid, canvas, &vp);
    render_fill_handle(grid, canvas, &vp);
    render_outline(grid, canvas, &vp);
    render_frozen_borders(grid, canvas, &vp);
    canvas.begin_overlay();
    render_active_editor(grid, canvas, &vp);
    render_active_dropdown(grid, canvas, &vp);
    canvas.end_overlay();
    render_scroll_bars(grid, canvas);
    render_fast_scroll(grid, canvas);
    render_debug_overlay(grid, canvas, &vp);

    (0, 0, w, h)
}

// ===========================================================================
// Selection highlight helpers
// ===========================================================================

/// Whether the grid's selection visibility setting is currently active
/// (controls selection background rendering). Always -> always; when focused
/// -> only when `has_focus`; none -> never.
fn is_highlight_active(grid: &VolvoxGrid) -> bool {
    match grid.selection.selection_visibility {
        h if h == pb::SelectionVisibility::SelectionVisAlways as i32 => true,
        h if h == pb::SelectionVisibility::SelectionVisWhenFocused as i32 => grid.has_focus,
        _ => false,
    }
}

/// Whether a cell should be rendered with selection highlight (back_color_sel /
/// fore_color_sel).  In listbox mode the current cursor row is always
/// highlighted regardless of the selection visibility setting.  In other modes the cursor
/// cell itself is excluded — the focus rect (Layer 8) handles it instead.
fn should_highlight_cell(grid: &VolvoxGrid, row: i32, col: i32) -> bool {
    if row < grid.fixed_rows || col < grid.fixed_cols {
        return false;
    }
    let is_listbox = grid.selection.mode == pb::SelectionMode::SelectionListbox as i32;
    if is_listbox {
        // Current cursor row: always highlighted (regardless of visibility setting)
        if row == grid.selection.row {
            return true;
        }
        // Other toggled rows: follow highlight setting
        return is_highlight_active(grid) && grid.selection.selected_rows.contains(&row);
    }
    // Row/column selection keeps the cursor cell highlighted as part of
    // the selected stripe; only free-mode cursor highlighting is suppressed.
    if row == grid.selection.row
        && col == grid.selection.col
        && grid.selection.mode == pb::SelectionMode::SelectionFree as i32
    {
        return false;
    }
    is_highlight_active(grid) && grid.is_cell_selected(row, col)
}

// ===========================================================================
// Layer 0 -- Opaque bands for overlay rows (pinned + sticky)
// ===========================================================================

/// Fill full-width/height opaque background bands for pinned and sticky
/// overlay rows/columns.  This prevents scrolled content from showing
/// through between cell gaps.
fn render_overlay_bands<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, vp: &VisibleRange) {
    let bg = grid.style.back_color_bkg;
    let w = vp.viewport_w;
    let h = vp.viewport_h;

    // Pinned-top band
    if vp.pinned_top_height > 0 {
        let fixed_bottom = grid.row_pos(grid.fixed_rows + grid.frozen_rows);
        canvas.fill_rect(0, fixed_bottom, w, vp.pinned_top_height, bg);
    }

    // Pinned-bottom band
    if vp.pinned_bottom_height > 0 {
        let y = vp.viewport_h - vp.pinned_bottom_height;
        canvas.fill_rect(0, y, w, vp.pinned_bottom_height, bg);
    }

    // Sticky-top row bands
    {
        let fixed_bottom = grid.row_pos(grid.fixed_rows + grid.frozen_rows);
        let mut y = fixed_bottom + vp.pinned_top_height;
        for &row in &vp.sticky_top_rows {
            let rh = grid.row_height(row);
            if rh > 0 {
                canvas.fill_rect(0, y, w, rh, bg);
            }
            y += rh;
        }
    }

    // Sticky-bottom row bands
    {
        let mut y = vp.viewport_h - vp.pinned_bottom_height;
        for &row in vp.sticky_bottom_rows.iter().rev() {
            let rh = grid.row_height(row);
            y -= rh;
            if rh > 0 {
                canvas.fill_rect(0, y, w, rh, bg);
            }
        }
    }

    // Sticky-left column bands
    {
        let fixed_right = grid.col_pos(grid.fixed_cols + grid.frozen_cols);
        let mut x = fixed_right;
        for &col in &vp.sticky_left_cols {
            let cw = grid.col_width(col);
            if cw > 0 {
                canvas.fill_rect(x, 0, cw, h, bg);
            }
            x += cw;
        }
    }

    // Sticky-right column bands
    {
        let mut x = vp.viewport_w;
        for &col in vp.sticky_right_cols.iter().rev() {
            let cw = grid.col_width(col);
            x -= cw;
            if cw > 0 {
                canvas.fill_rect(x, 0, cw, h, bg);
            }
        }
    }
}

// ===========================================================================
// Layer 1 -- Cell backgrounds
// ===========================================================================

fn render_backgrounds<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    vis_cells: &[(i32, i32, i32, i32, i32, i32)],
) {
    for &(row, col, cx, cy, cw, ch) in vis_cells {
        // For merged/spanned cells, always resolve style from the anchor
        // cell (top-left of the merge).  This prevents "blinking" when a
        // merged cell spans both sticky and non-sticky columns: without
        // this, the last-drawn column's style wins, and the winner changes
        // depending on whether the sticky threshold is crossed.
        let (style_row, style_col) =
            match grid.get_merged_range(row, col) {
                Some((mr1, mc1, mr2, mc2)) if mr1 != mr2 || mc1 != mc2 => (mr1, mc1),
                _ => (row, col),
            };

        let is_fixed = style_row < grid.fixed_rows || style_col < grid.fixed_cols;
        let is_frozen = !is_fixed
            && (style_row < grid.fixed_rows + grid.frozen_rows
                || style_col < grid.fixed_cols + grid.frozen_cols);
        let is_selected = should_highlight_cell(grid, style_row, style_col);
        let is_alternate = !is_fixed
            && !is_frozen
            && !is_selected
            && grid.style.back_color_alternate != 0x00000000
            && (style_row - grid.fixed_rows) % 2 == 1;

        let style_override = grid.get_cell_style(style_row, style_col);
        let bg = style_override.resolve_back_color(
            &grid.style,
            is_fixed,
            is_frozen,
            is_selected,
            is_alternate,
        );

        // Pinned/sticky cells overlay scrolled content, so they MUST always
        // get an opaque background fill (even when bg == back_color_bkg).
        let is_overlay = grid.is_row_pinned(row) != 0
            || grid.sticky_rows.contains_key(&row)
            || grid.sticky_cols.contains_key(&col)
            || grid.is_col_pinned(col) != 0;
        if bg != grid.style.back_color_bkg || is_overlay {
            canvas.fill_rect(cx, cy, cw, ch, bg);
        }
    }
}

// ===========================================================================
// Layer 2 -- Progress bars (data-bar rendering)
// ===========================================================================

fn render_progress_bars<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    vis_cells: &[(i32, i32, i32, i32, i32, i32)],
) {
    for &(row, col, cx, cy, cw, ch) in vis_cells {
        let col_progress = if col >= 0 && (col as usize) < grid.columns.len() {
            grid.columns[col as usize].progress_color
        } else {
            0
        };

        let (pct, color) = if let Some(cell) = grid.cells.get(row, col) {
            if cell.progress_percent() > 0.0 {
                let c = if cell.progress_color() != 0 {
                    cell.progress_color()
                } else if col_progress != 0 {
                    col_progress
                } else if grid.style.progress_color != 0 {
                    grid.style.progress_color
                } else {
                    0xFF0078D7
                };
                (cell.progress_percent(), c)
            } else if col_progress != 0 {
                (parse_progress_percent(&cell.text), col_progress)
            } else {
                (0.0, 0)
            }
        } else {
            (0.0, 0)
        };

        if pct > 0.0 && color != 0 {
            // Use original cell width so the progress bar doesn't resize
            // when the cell is partially scrolled off-screen.
            let is_col_scrollable = col >= grid.fixed_cols + grid.frozen_cols;
            let orig_x = if is_col_scrollable {
                grid.layout.col_pos(col) - grid.scroll.scroll_x as i32
            } else {
                cx
            };
            let orig_w = if is_col_scrollable {
                grid.col_width(col)
            } else {
                cw
            };
            let fill_w = ((orig_w as f32) * pct.clamp(0.0, 1.0)) as i32;
            if fill_w > 0 {
                // Clip the fill to the visible (clipped) cell area
                let fill_right = (orig_x + fill_w).min(cx + cw);
                let fill_left = orig_x.max(cx);
                let visible_w = fill_right - fill_left;
                if visible_w > 0 {
                    canvas.fill_rect(fill_left, cy, visible_w, ch, color);
                }
            }
        }
    }
}

// ===========================================================================
// Layer 3 -- Grid lines
// ===========================================================================

fn render_grid_lines<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    vis_cells: &[(i32, i32, i32, i32, i32, i32)],
) {
    draw_grid_lines_for_zone(grid, canvas, vis_cells, false);
    draw_grid_lines_for_zone(grid, canvas, vis_cells, true);
}

fn draw_grid_lines_for_zone<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    vis_cells: &[(i32, i32, i32, i32, i32, i32)],
    is_fixed_zone: bool,
) {
    let (mode, color) = if is_fixed_zone {
        (grid.style.grid_lines_fixed, grid.style.grid_color_fixed)
    } else {
        (grid.style.grid_lines, grid.style.grid_color)
    };

    if mode == pb::GridLineStyle::GridlineNone as i32 {
        return;
    }

    let draw_horz = mode == pb::GridLineStyle::GridlineSolid as i32
        || mode == pb::GridLineStyle::GridlineInset as i32
        || mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == pb::GridLineStyle::GridlineSolidHorizontal as i32
        || mode == pb::GridLineStyle::GridlineInsetHorizontal as i32
        || mode == pb::GridLineStyle::GridlineRaisedHorizontal as i32;
    let draw_vert = mode == pb::GridLineStyle::GridlineSolid as i32
        || mode == pb::GridLineStyle::GridlineInset as i32
        || mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == pb::GridLineStyle::GridlineSolidVertical as i32
        || mode == pb::GridLineStyle::GridlineInsetVertical as i32
        || mode == pb::GridLineStyle::GridlineRaisedVertical as i32;
    let is_3d = mode == pb::GridLineStyle::GridlineInset as i32
        || mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == pb::GridLineStyle::GridlineInsetHorizontal as i32
        || mode == pb::GridLineStyle::GridlineInsetVertical as i32
        || mode == pb::GridLineStyle::GridlineRaisedHorizontal as i32
        || mode == pb::GridLineStyle::GridlineRaisedVertical as i32;
    let is_raised = mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == pb::GridLineStyle::GridlineRaisedHorizontal as i32
        || mode == pb::GridLineStyle::GridlineRaisedVertical as i32;

    let (color_light, color_dark) = if is_3d {
        if is_raised {
            (0xFFFFFFFF_u32, darken(color, 80))
        } else {
            (darken(color, 80), 0xFFFFFFFF_u32)
        }
    } else {
        (color, color)
    };

    let buf_w = canvas.width();
    let buf_h = canvas.height();

    for &(row, col, cx, cy, cw, ch) in vis_cells {
        let cell_is_fixed = row < grid.fixed_rows || col < grid.fixed_cols;
        if cell_is_fixed != is_fixed_zone {
            continue;
        }

        let right = cx + cw;
        let bottom = cy + ch;

        if draw_vert && right >= 0 && right < buf_w {
            if is_3d {
                canvas.vline(right - 1, cy, ch, color_light);
                canvas.vline(right, cy, ch, color_dark);
            } else {
                canvas.vline(right, cy, ch, color);
            }
        }

        if draw_horz && bottom >= 0 && bottom < buf_h {
            if is_3d {
                canvas.hline(cx, bottom - 1, cw, color_light);
                canvas.hline(cx, bottom, cw, color_dark);
            } else {
                canvas.hline(cx, bottom, cw, color);
            }
        }
    }
}

// ===========================================================================
// Layer 3.5 -- Background image
// ===========================================================================

fn render_background_image<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C) {
    if grid.style.background_image.is_empty() {
        return;
    }
    let Some((img_data, img_w, img_h)) = decode_png_rgba(&grid.style.background_image) else {
        return;
    };
    if img_w == 0 || img_h == 0 {
        return;
    }

    let buf_w = canvas.width();
    let buf_h = canvas.height();

    let align = grid.style.background_image_alignment;
    match align {
        0 => {
            // Tile
            let mut ty = 0;
            while ty < buf_h {
                let mut tx = 0;
                while tx < buf_w {
                    canvas.blit_image_at(tx, ty, &img_data, img_w, img_h);
                    tx += img_w;
                }
                ty += img_h;
            }
        }
        1 => {
            // Center
            let cx = (buf_w - img_w) / 2;
            let cy = (buf_h - img_h) / 2;
            canvas.blit_image_at(cx, cy, &img_data, img_w, img_h);
        }
        2 => {
            // Stretch
            canvas.blit_image(0, 0, buf_w, buf_h, &img_data, img_w, img_h);
        }
        _ => {
            // Default: top-left
            canvas.blit_image_at(0, 0, &img_data, img_w, img_h);
        }
    }
}

// ===========================================================================
// Layer 3.6 -- Per-cell borders (CellBorder / CellBorderRange)
// ===========================================================================

fn render_cell_borders<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    vis_cells: &[(i32, i32, i32, i32, i32, i32)],
) {
    for &(row, col, cx, cy, cw, ch) in vis_cells {
        // For merged cells, draw border once at the merge-origin cell.
        if let Some((mr1, mc1, _mr2, _mc2)) = grid.get_merged_range(row, col) {
            if row != mr1 || col != mc1 {
                continue;
            }
        }

        let style_override = grid.get_cell_style(row, col);
        let all_style = style_override.border;
        let all_color = style_override.border_color;
        let has_edge_styles = style_override.border_top.is_some()
            || style_override.border_right.is_some()
            || style_override.border_bottom.is_some()
            || style_override.border_left.is_some();
        let has_edge_colors = style_override.border_top_color.is_some()
            || style_override.border_right_color.is_some()
            || style_override.border_bottom_color.is_some()
            || style_override.border_left_color.is_some();

        if !has_edge_styles && !has_edge_colors {
            let border_style = all_style.unwrap_or(pb::BorderStyle::BorderNone as i32);
            if border_style == pb::BorderStyle::BorderNone as i32 {
                continue;
            }
            let border_color = all_color.unwrap_or(grid.style.grid_color);
            canvas.cell_border_style(cx, cy, cw, ch, border_style, border_color);
            continue;
        }

        let edge_specs = [
            (
                BorderEdge::Top,
                style_override.border_top,
                style_override.border_top_color,
            ),
            (
                BorderEdge::Right,
                style_override.border_right,
                style_override.border_right_color,
            ),
            (
                BorderEdge::Bottom,
                style_override.border_bottom,
                style_override.border_bottom_color,
            ),
            (
                BorderEdge::Left,
                style_override.border_left,
                style_override.border_left_color,
            ),
        ];

        for (edge, edge_style, edge_color) in edge_specs {
            let style = edge_style
                .or(all_style)
                .unwrap_or(pb::BorderStyle::BorderNone as i32);
            if style == pb::BorderStyle::BorderNone as i32 {
                continue;
            }
            let color = edge_color.or(all_color).unwrap_or(grid.style.grid_color);
            canvas.cell_border_edge_style(cx, cy, cw, ch, edge, style, color);
        }
    }
}

// ===========================================================================
// Layer 4 -- Cell text
// ===========================================================================

fn render_cell_text<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    vp: &VisibleRange,
    vis_cells: &[(i32, i32, i32, i32, i32, i32)],
) {
    let has_subtotal_nodes = grid.row_props.values().any(|rp| rp.is_subtotal);
    let subtotal_level_floor = first_subtotal_level(grid);

    // Track which merged ranges have already been rendered so each
    // merge is drawn exactly once, even when the origin row is off-screen.
    let mut rendered_merges: std::collections::HashSet<(i32, i32, i32, i32)> =
        std::collections::HashSet::new();

    for &(row, col, cx, cy, cw, ch) in vis_cells {
        // Determine the text source and visible rect for merged cells.
        // For a merged range, use the origin cell for text/style but
        // center the text within the viewport-clipped visible area.
        let (text_row, text_col, vis_x, vis_y, vis_w, vis_h) =
            if let Some((mr1, mc1, mr2, mc2)) = grid.get_merged_range(row, col) {
                if mr1 != mr2 || mc1 != mc2 {
                    let merge_key = (mr1, mc1, mr2, mc2);
                    if rendered_merges.contains(&merge_key) {
                        continue;
                    }
                    rendered_merges.insert(merge_key);

                    // cx/cy/cw/ch from cell_rect already cover the full
                    // merged range and are clipped against fixed/frozen.
                    // Further clip to the viewport so text centers in the
                    // visible portion only.
                    let vx = cx.max(0);
                    let vy = cy.max(0);
                    let vw = ((cx + cw).min(vp.viewport_w) - vx).max(1);
                    let vh = ((cy + ch).min(vp.viewport_h) - vy).max(1);
                    (mr1, mc1, vx, vy, vw, vh)
                } else {
                    (row, col, cx, cy, cw, ch)
                }
            } else {
                (row, col, cx, cy, cw, ch)
            };

        // Compute original (pre-clip) cell bounds for smooth panning.
        //
        // Merged cells: center text in the *visible* portion so it stays
        // readable as the merge scrolls.  Single cells: position text at
        // the original (pre-clip) location so content pans naturally.
        //
        // Per-axis logic: cell_rect clips X when the column is scrollable
        // and not sticky, clips Y when the row is scrollable and not
        // sticky.  Pinned rows return before clipping — no fix needed.
        let is_row_scrollable = text_row >= grid.fixed_rows + grid.frozen_rows;
        let is_col_scrollable = text_col >= grid.fixed_cols + grid.frozen_cols;
        let is_pinned = grid.is_row_pinned(text_row) != 0;
        let is_sticky_row = vp.sticky_top_rows.contains(&text_row)
            || vp.sticky_bottom_rows.contains(&text_row);
        let is_sticky_col = vp.sticky_left_cols.contains(&text_col)
            || vp.sticky_right_cols.contains(&text_col);

        let is_merged = grid.get_merged_range(text_row, text_col)
            .map_or(false, |(r1, c1, r2, c2)| r1 != r2 || c1 != c2);

        let (orig_x, orig_y, orig_w, orig_h) = if is_merged {
            // Merged cells: keep text centered in the visible portion.
            (vis_x, vis_y, vis_w, vis_h)
        } else {
            let need_orig_x = is_col_scrollable && !is_sticky_col && !is_pinned;
            let need_orig_y = is_row_scrollable && !is_sticky_row && !is_pinned;

            if !need_orig_x && !need_orig_y {
                (vis_x, vis_y, vis_w, vis_h)
            } else {
                let (ox, ow) = if need_orig_x {
                    let ox = grid.col_pos(text_col) - grid.scroll.scroll_x as i32;
                    (ox, grid.col_width(text_col))
                } else {
                    (vis_x, vis_w)
                };
                let (oy, oh) = if need_orig_y {
                    let oy = grid.row_pos(text_row) - grid.scroll.scroll_y as i32
                        + vp.pinned_top_height;
                    (oy, grid.row_height(text_row))
                } else {
                    (vis_y, vis_h)
                };
                (ox, oy, ow, oh)
            }
        };

        // Boolean columns render checkboxes in data rows (handled in layer 5)
        if let Some(cp) = grid.get_col_props(text_col) {
            if cp.data_type == pb::ColumnDataType::ColumnDataBoolean as i32
                && text_row >= grid.fixed_rows
            {
                continue;
            }
        }

        let display_text = grid.get_display_text(text_row, text_col);
        if display_text.is_empty() {
            continue;
        }

        // Resolve font and color from the merge-origin cell
        let is_fixed = text_row < grid.fixed_rows || text_col < grid.fixed_cols;
        let is_frozen = !is_fixed
            && (text_row < grid.fixed_rows + grid.frozen_rows
                || text_col < grid.fixed_cols + grid.frozen_cols);
        let is_selected = should_highlight_cell(grid, text_row, text_col);

        let style_override = grid.get_cell_style(text_row, text_col);
        let fore = style_override.resolve_fore_color(&grid.style, is_fixed, is_frozen, is_selected);

        let font_name = style_override
            .font_name
            .as_deref()
            .unwrap_or(&grid.style.font_name);
        let font_size = style_override.font_size.unwrap_or(grid.style.font_size);
        let font_bold = style_override.font_bold.unwrap_or(grid.style.font_bold);
        let font_italic = style_override.font_italic.unwrap_or(grid.style.font_italic);
        let text_style = if is_fixed {
            style_override
                .text_effect
                .unwrap_or(grid.style.text_effect_fixed)
        } else {
            style_override.text_effect.unwrap_or(grid.style.text_effect)
        };

        // Resolve alignment
        let alignment = resolve_alignment(grid, text_row, text_col, &style_override, &display_text);
        let cell_padding = grid.resolve_cell_padding(text_row, text_col, &style_override);

        let button_reserve = if show_dropdown_button_for_cell(grid, text_row, text_col) {
            dropdown_button_rect(vis_x, vis_y, vis_w, vis_h).map_or(0, |(_, _, bw, _)| bw + 2)
        } else {
            0
        };
        let usable_w = (orig_w - button_reserve).max(1);
        let uses_tree_indicator = grid.outline.tree_indicator
            != pb::TreeIndicatorStyle::TreeIndicatorNone as i32
            && text_col == grid.outline.tree_column
            && text_row >= grid.fixed_rows;

        // Compute text position based on alignment, centered in the
        // visible portion of the (possibly merged) cell.
        let (halign, valign) = alignment_components(alignment);
        let default_line_h = (font_size * 1.2).ceil();
        let ellipsis_mode = grid.ellipsis_mode;

        // Indent text in the outline column
        let outline_indent = if uses_tree_indicator {
            let (level, is_subtotal) = grid
                .get_row_props(text_row)
                .map_or((0, false), |rp| (rp.outline_level, rp.is_subtotal));
            let tg = crate::outline::TreeGeometry::from_grid(grid);
            if has_subtotal_nodes {
                // In subtotal trees, text should sit immediately to the right
                // of the +/- box, never underneath it.
                let visual_level = subtotal_visual_level(level, is_subtotal, subtotal_level_floor);
                if visual_level <= 0 {
                    0
                } else {
                    let line_x = tg.line_x(visual_level);
                    line_x + (tg.btn_size + 1) / 2 + 2
                }
            } else if level > 0 {
                tg.indent(level) + tg.connector_end
            } else {
                0
            }
        } else {
            0
        };

        let left_padding = if uses_tree_indicator {
            0
        } else {
            cell_padding.left
        };
        let right_padding = cell_padding.right;
        let top_padding = cell_padding.top;
        let bottom_padding = cell_padding.bottom;

        // Use original (pre-clip) bounds for text positioning so content
        // pans smoothly rather than being re-laid-out inside the clipped area.
        let inner_left = orig_x + left_padding + outline_indent;
        let inner_right = orig_x + usable_w - right_padding;
        let inner_w = (inner_right - inner_left).max(1);
        let inner_top = orig_y + top_padding;
        let inner_bottom = orig_y + orig_h - bottom_padding;
        let inner_h = (inner_bottom - inner_top).max(1);

        // Determine word-wrap width if enabled
        let wrap_width = if grid.word_wrap {
            Some(inner_w as f32)
        } else {
            None
        };

        let shrink_to_fit = style_override.shrink_to_fit.unwrap_or(false);
        let is_merged_cell = grid.get_merged_range(text_row, text_col)
            .map_or(false, |(r1, c1, r2, c2)| r1 != r2 || c1 != c2);

        let needs_measure = grid.word_wrap
            || halign != 0
            || valign != 1
            || (ellipsis_mode != 0 && !grid.word_wrap)
            || (shrink_to_fit && !grid.word_wrap)
            || (grid.text_overflow && !grid.word_wrap && !shrink_to_fit && !is_merged_cell);
        let (tw, th) = if needs_measure {
            canvas.measure_text(
                &display_text,
                font_name,
                font_size,
                font_bold,
                font_italic,
                wrap_width,
            )
        } else {
            (0.0, default_line_h)
        };

        // ── Shrink-to-fit: reduce font size so text fits cell width ──
        let (effective_font_size, tw, th) = if shrink_to_fit
            && !grid.word_wrap
            && tw > inner_w as f32
            && inner_w > 0
        {
            let scale = inner_w as f32 / tw;
            let shrunk = (font_size * scale).floor().max(6.0);
            let (stw, sth) = canvas.measure_text(
                &display_text,
                font_name,
                shrunk,
                font_bold,
                font_italic,
                None,
            );
            (shrunk, stw, sth)
        } else {
            (font_size, tw, th)
        };

        // ── Text overflow: extend into empty neighbor cells ──
        let (inner_left, inner_right, inner_w, clip_x_ov, _clip_w_ov) =
            if grid.text_overflow
                && !grid.word_wrap
                && !shrink_to_fit
                && !is_merged_cell
                && tw > inner_w as f32
                && text_row >= grid.fixed_rows
            {
                let scan_right = if grid.right_to_left {
                    halign == 2 // left-aligned in RTL scans right
                } else {
                    halign == 0 || halign == 1 // left or center aligned scans right
                };
                let scan_left = if grid.right_to_left {
                    halign == 0 || halign == 1
                } else {
                    halign == 2 || halign == 1 // right or center aligned scans left
                };
                let mut left_ext: i32 = 0;
                let mut right_ext: i32 = 0;

                // Scan rightward
                if scan_right {
                    let mut c = text_col + 1;
                    while c < grid.cols {
                        if grid.is_col_hidden(c) { c += 1; continue; }
                        if grid.get_merged_range(text_row, c)
                            .map_or(false, |(r1, c1, r2, c2)| r1 != r2 || c1 != c2)
                        {
                            break;
                        }
                        let neighbor_text = grid.get_display_text(text_row, c);
                        if !neighbor_text.is_empty() { break; }
                        right_ext += grid.get_col_width(c);
                        if (inner_w + left_ext + right_ext) as f32 >= tw { break; }
                        c += 1;
                    }
                }

                // Scan leftward
                if scan_left {
                    let mut c = text_col - 1;
                    while c >= grid.fixed_cols {
                        if grid.is_col_hidden(c) { c -= 1; continue; }
                        if grid.get_merged_range(text_row, c)
                            .map_or(false, |(r1, c1, r2, c2)| r1 != r2 || c1 != c2)
                        {
                            break;
                        }
                        let neighbor_text = grid.get_display_text(text_row, c);
                        if !neighbor_text.is_empty() { break; }
                        left_ext += grid.get_col_width(c);
                        if (inner_w + left_ext + right_ext) as f32 >= tw { break; }
                        c -= 1;
                    }
                }

                let ext_left = inner_left - left_ext;
                let ext_right = inner_right + right_ext;
                let ext_w = (ext_right - ext_left).max(1);
                (ext_left, ext_right, ext_w, ext_left, ext_w)
            } else {
                (inner_left, inner_right, inner_w, inner_left, inner_w)
            };

        let text_x = match halign {
            0 => inner_left,
            1 => inner_left + (inner_w - tw.ceil() as i32) / 2,
            _ => inner_right - tw.ceil() as i32,
        };

        let text_y = match valign {
            0 => inner_top,
            1 => inner_top + (inner_h - th.ceil() as i32) / 2,
            _ => inner_bottom - th.ceil() as i32,
        }
        .max(inner_top);

        // Clip text to the viewport-clipped cell area (vis_x/vis_y/vis_w/vis_h)
        // so content doesn't overdraw fixed headers or neighboring cells.
        let clip_x = clip_x_ov.max(vis_x);
        let clip_right = inner_right.min(vis_x + vis_w);
        let clip_w = (clip_right - clip_x).max(1);
        let clip_y_cell = vis_y;
        let clip_h = ((vis_y + vis_h).min(inner_bottom) - text_y).max(1);

        // Handle ellipsis (uses effective_font_size and possibly extended inner_w)
        if ellipsis_mode != 0 && !grid.word_wrap && tw > inner_w as f32 {
            let ellipsis_text = if ellipsis_mode == 2 {
                compute_ellipsis_path_text(
                    canvas,
                    &display_text,
                    font_name,
                    effective_font_size,
                    font_bold,
                    font_italic,
                    inner_w as f32,
                )
            } else {
                compute_ellipsis_text(
                    canvas,
                    &display_text,
                    font_name,
                    effective_font_size,
                    font_bold,
                    font_italic,
                    inner_w as f32,
                )
            };
            canvas.draw_text_styled(
                text_x,
                text_y,
                &ellipsis_text,
                font_name,
                effective_font_size,
                font_bold,
                font_italic,
                fore,
                clip_x,
                clip_y_cell,
                clip_w,
                clip_h,
                text_style,
                wrap_width,
            );
        } else {
            canvas.draw_text_styled(
                text_x,
                text_y,
                &display_text,
                font_name,
                effective_font_size,
                font_bold,
                font_italic,
                fore,
                clip_x,
                clip_y_cell,
                clip_w,
                clip_h,
                text_style,
                wrap_width,
            );
        }
    }
}

// ===========================================================================
// Layer 4.5 -- Cell pictures
// ===========================================================================

fn render_cell_pictures<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    vp: &VisibleRange,
    vis_cells: &[(i32, i32, i32, i32, i32, i32)],
) {
    for &(row, col, cx, cy, cw, ch) in vis_cells {
        let cell = match grid.cells.get(row, col) {
            Some(c) => c,
            None => continue,
        };
        let pic_data = match cell.picture() {
            Some(data) if !data.is_empty() => data,
            _ => continue,
        };

        let Some((img_rgba, img_w, img_h)) = decode_png_rgba(pic_data) else {
            continue;
        };
        if img_w == 0 || img_h == 0 {
            continue;
        }

        // Use original (pre-clip) bounds for positioning so images don't
        // shift during smooth scrolling.  blit_image/blit_image_at clip
        // at the buffer edges automatically.
        let (ox, oy, ow, oh) = original_cell_bounds(grid, row, col, cx, cy, cw, ch, vp);

        let pic_align = cell.picture_alignment();
        let (px, py) = match pic_align {
            a if a == pb::ImageAlignment::ImgAlignLeftTop as i32 => (ox, oy),
            a if a == pb::ImageAlignment::ImgAlignLeftCenter as i32 => (ox, oy + (oh - img_h) / 2),
            a if a == pb::ImageAlignment::ImgAlignLeftBottom as i32 => (ox, oy + oh - img_h),
            a if a == pb::ImageAlignment::ImgAlignCenterTop as i32 => (ox + (ow - img_w) / 2, oy),
            a if a == pb::ImageAlignment::ImgAlignCenterCenter as i32 => {
                (ox + (ow - img_w) / 2, oy + (oh - img_h) / 2)
            }
            a if a == pb::ImageAlignment::ImgAlignCenterBottom as i32 => {
                (ox + (ow - img_w) / 2, oy + oh - img_h)
            }
            a if a == pb::ImageAlignment::ImgAlignRightTop as i32 => (ox + ow - img_w, oy),
            a if a == pb::ImageAlignment::ImgAlignRightCenter as i32 => {
                (ox + ow - img_w, oy + (oh - img_h) / 2)
            }
            a if a == pb::ImageAlignment::ImgAlignRightBottom as i32 => {
                (ox + ow - img_w, oy + oh - img_h)
            }
            a if a == pb::ImageAlignment::ImgAlignStretch as i32 => {
                canvas.blit_image(ox, oy, ow, oh, &img_rgba, img_w, img_h);
                continue;
            }
            _ => (ox, oy),
        };

        canvas.blit_image_at(px, py, &img_rgba, img_w, img_h);
    }
}

// ===========================================================================
// Layer 4b -- Sort glyphs on column headers
// ===========================================================================

fn normalize_icon_align(value: i32) -> i32 {
    match value {
        v if v == pb::IconAlign::InlineEnd as i32 => v,
        v if v == pb::IconAlign::InlineStart as i32 => v,
        v if v == pb::IconAlign::Start as i32 => v,
        v if v == pb::IconAlign::End as i32 => v,
        v if v == pb::IconAlign::Center as i32 => v,
        _ => pb::IconAlign::InlineEnd as i32,
    }
}

fn first_font_name(names: &[String]) -> Option<&str> {
    names.iter().map(|v| v.trim()).find(|v| !v.is_empty())
}

fn resolve_icon_text_style(
    grid: &VolvoxGrid,
    slot_style: Option<&IconThemeSlotStyle>,
    fallback_font_size: f32,
    fallback_bold: bool,
    fallback_italic: bool,
    fallback_color: u32,
) -> (String, f32, bool, bool, u32) {
    let defaults = &grid.style.icon_theme_defaults.text_style;
    let slot_text = slot_style.map(|s| &s.text_style);

    let font_name = slot_text
        .and_then(|s| first_font_name(&s.font_names))
        .or_else(|| {
            slot_text
                .and_then(|s| s.font_name.as_deref())
                .map(|v| v.trim())
                .filter(|v| !v.is_empty())
        })
        .or_else(|| first_font_name(&defaults.font_names))
        .or_else(|| {
            defaults
                .font_name
                .as_deref()
                .map(|v| v.trim())
                .filter(|v| !v.is_empty())
        })
        .unwrap_or(&grid.style.font_name)
        .to_string();
    let font_size = slot_text
        .and_then(|s| s.font_size)
        .or(defaults.font_size)
        .unwrap_or(fallback_font_size)
        .clamp(1.0, 256.0);
    let font_bold = slot_text
        .and_then(|s| s.font_bold)
        .or(defaults.font_bold)
        .unwrap_or(fallback_bold);
    let font_italic = slot_text
        .and_then(|s| s.font_italic)
        .or(defaults.font_italic)
        .unwrap_or(fallback_italic);
    let color = slot_text
        .and_then(|s| s.color)
        .or(defaults.color)
        .unwrap_or(fallback_color);

    (font_name, font_size, font_bold, font_italic, color)
}

fn resolve_icon_layout_style(
    grid: &VolvoxGrid,
    slot_style: Option<&IconThemeSlotStyle>,
) -> crate::style::IconLayoutStyle {
    let mut layout = grid.style.icon_theme_defaults.layout;
    if let Some(slot) = slot_style {
        if let Some(slot_layout) = slot.layout {
            layout = slot_layout;
        }
    }
    layout.align = normalize_icon_align(layout.align);
    layout.gap_px = layout.gap_px.max(0);
    layout
}

fn resolve_sort_slot_style<'a>(
    grid: &'a VolvoxGrid,
    sort_order: i32,
) -> Option<&'a IconThemeSlotStyle> {
    if sort_order == pb::SortOrder::SortNone as i32 {
        grid.style.icon_theme_slot_styles.sort_none.as_ref()
    } else if sort_order_is_ascending(sort_order) {
        grid.style.icon_theme_slot_styles.sort_ascending.as_ref()
    } else {
        grid.style.icon_theme_slot_styles.sort_descending.as_ref()
    }
}

fn resolve_checkbox_slot_style<'a>(
    grid: &'a VolvoxGrid,
    checked_state: i32,
) -> Option<&'a IconThemeSlotStyle> {
    if checked_state == pb::CheckedState::CheckedChecked as i32 {
        grid.style.icon_theme_slot_styles.checkbox_checked.as_ref()
    } else if checked_state == pb::CheckedState::CheckedGrayed as i32 {
        grid.style
            .icon_theme_slot_styles
            .checkbox_indeterminate
            .as_ref()
            .or(grid
                .style
                .icon_theme_slot_styles
                .checkbox_unchecked
                .as_ref())
    } else {
        grid.style
            .icon_theme_slot_styles
            .checkbox_unchecked
            .as_ref()
    }
}

fn resolve_tree_slot_style<'a>(
    grid: &'a VolvoxGrid,
    is_collapsed: bool,
) -> Option<&'a IconThemeSlotStyle> {
    if is_collapsed {
        grid.style.icon_theme_slot_styles.tree_collapsed.as_ref()
    } else {
        grid.style.icon_theme_slot_styles.tree_expanded.as_ref()
    }
}

fn place_icon_x_from_layout(
    inner_left: i32,
    inner_right: i32,
    inner_w: i32,
    glyph_w: i32,
    layout: crate::style::IconLayoutStyle,
    header_has_text: bool,
    header_text_left: i32,
    header_text_right: i32,
) -> i32 {
    let max_x = (inner_right - glyph_w).max(inner_left);
    let align = normalize_icon_align(layout.align);
    let gap = layout.gap_px.max(0);
    let x = match align {
        a if a == pb::IconAlign::InlineStart as i32 => {
            if header_has_text {
                header_text_left - gap - glyph_w
            } else {
                inner_left + gap
            }
        }
        a if a == pb::IconAlign::Start as i32 => inner_left + gap,
        a if a == pb::IconAlign::End as i32 => inner_right - glyph_w - gap,
        a if a == pb::IconAlign::Center as i32 => inner_left + (inner_w - glyph_w) / 2,
        _ => {
            if header_has_text {
                header_text_right + gap
            } else {
                inner_left + gap
            }
        }
    };
    x.clamp(inner_left, max_x)
}

fn sort_order_is_ascending(sort_order: i32) -> bool {
    sort_order == pb::SortOrder::SortGenericAscending as i32
        || sort_order == pb::SortOrder::SortNumericAscending as i32
        || sort_order == pb::SortOrder::SortStringNoCaseAsc as i32
        || sort_order == pb::SortOrder::SortStringAsc as i32
}

fn render_sort_glyphs<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, vp: &VisibleRange) {
    if grid.header_features & 1 == 0 {
        return; // HEADER_SORT not enabled
    }
    let mut sort_targets: Vec<(i32, i32)> = Vec::new();
    for col in 0..grid.cols {
        if let Some(cp) = grid.get_col_props(col) {
            if cp.sort_defined {
                sort_targets.push((col, cp.sort_order));
            }
        }
    }
    if sort_targets.is_empty() {
        if grid.sort_state.sort_keys.is_empty() {
            return;
        }
        sort_targets = grid.sort_state.sort_keys.clone();
    }
    let show_sort_numbers = grid.style.show_sort_numbers && sort_targets.len() > 1;

    for (sort_idx, &(sort_col, sort_order)) in sort_targets.iter().enumerate() {
        let is_sort_none = sort_order == pb::SortOrder::SortNone as i32;

        for row in 0..grid.fixed_rows {
            if grid.is_row_hidden(row) {
                continue;
            }
            if let Some((cx, cy, cw, ch)) = cell_rect(grid, row, sort_col, vp) {
                let style_override = grid.get_cell_style(row, sort_col);
                let header_text = grid.get_display_text(row, sort_col);
                let header_font_name = style_override
                    .font_name
                    .as_deref()
                    .unwrap_or(&grid.style.font_name);
                let header_font_size = style_override.font_size.unwrap_or(grid.style.font_size);
                let header_font_bold = style_override.font_bold.unwrap_or(grid.style.font_bold);
                let header_font_italic =
                    style_override.font_italic.unwrap_or(grid.style.font_italic);

                let padding = grid.resolve_cell_padding(row, sort_col, &style_override);
                let inner_left = cx + padding.left;
                let inner_right = cx + cw - padding.right;
                let inner_top = cy + padding.top;
                let inner_bottom = cy + ch - padding.bottom;
                let inner_w = (inner_right - inner_left).max(1);
                let inner_h = (inner_bottom - inner_top).max(1);

                let alignment =
                    resolve_alignment(grid, row, sort_col, &style_override, &header_text);
                let (halign, _) = alignment_components(alignment);
                let header_has_text = !header_text.trim().is_empty();
                let header_text_w = if header_has_text {
                    canvas
                        .measure_text(
                            &header_text,
                            header_font_name,
                            header_font_size,
                            header_font_bold,
                            header_font_italic,
                            None,
                        )
                        .0
                        .ceil() as i32
                } else {
                    0
                };
                let header_text_x = match halign {
                    0 => inner_left,
                    1 => inner_left + (inner_w - header_text_w) / 2,
                    _ => inner_right - header_text_w,
                };
                let header_text_right = if header_has_text {
                    header_text_x + header_text_w
                } else {
                    inner_left
                };
                let slot_style = resolve_sort_slot_style(grid, sort_order);
                let layout = resolve_icon_layout_style(grid, slot_style);
                let place_sort_icon_x = |glyph_w: i32| {
                    place_icon_x_from_layout(
                        inner_left,
                        inner_right,
                        inner_w,
                        glyph_w,
                        layout,
                        header_has_text,
                        header_text_x,
                        header_text_right,
                    )
                };

                let sort_picture = if is_sort_none {
                    None
                } else if sort_order_is_ascending(sort_order) {
                    grid.sort_state.sort_ascending_picture.as_deref()
                } else {
                    grid.sort_state.sort_descending_picture.as_deref()
                };
                if let Some(pic_data) = sort_picture {
                    if let Some((img_rgba, img_w, img_h)) = decode_png_rgba(pic_data) {
                        if img_w > 0 && img_h > 0 {
                            let max_h = (inner_h - 2).max(6);
                            let draw_h = img_h.min(max_h).max(1);
                            let mut draw_w = ((img_w as i64 * draw_h as i64) / img_h as i64) as i32;
                            draw_w = draw_w.max(1).min(inner_w.max(1));
                            let draw_x = place_sort_icon_x(draw_w);
                            let draw_y = inner_top + (inner_h - draw_h) / 2;
                            if draw_w == img_w && draw_h == img_h {
                                canvas.blit_image_at(draw_x, draw_y, &img_rgba, img_w, img_h);
                            } else {
                                canvas.blit_image(
                                    draw_x, draw_y, draw_w, draw_h, &img_rgba, img_w, img_h,
                                );
                            }
                            if show_sort_numbers {
                                draw_sort_priority_number(
                                    canvas, grid, sort_idx,
                                    draw_x + draw_w + 1, inner_top, inner_h, inner_bottom,
                                    inner_left, inner_w,
                                );
                            }
                            continue;
                        }
                    }
                }

                let sort_icon = if is_sort_none {
                    grid.style.icon_theme_slots.sort_none.as_deref()
                } else if sort_order_is_ascending(sort_order) {
                    grid.style.icon_theme_slots.sort_ascending.as_deref()
                } else {
                    grid.style.icon_theme_slots.sort_descending.as_deref()
                };
                if let Some(icon) = sort_icon {
                    let icon_text = icon.trim();
                    if !icon_text.is_empty() {
                        let (icon_font_name, font_size, font_bold, font_italic, color) =
                            resolve_icon_text_style(
                                grid,
                                slot_style,
                                (grid.style.font_size - 1.0).max(8.0),
                                false,
                                false,
                                grid.style.fore_color_fixed,
                            );
                        let (tw, th) = canvas.measure_text(
                            icon_text,
                            &icon_font_name,
                            font_size,
                            font_bold,
                            font_italic,
                            None,
                        );
                        let text_w = tw.ceil() as i32;
                        let text_h = th.ceil() as i32;
                        let glyph_x = place_sort_icon_x(text_w);
                        let glyph_y = inner_top + ((inner_h - text_h).max(0) / 2);
                        let clip_h = (inner_bottom - glyph_y).max(1);
                        canvas.draw_text_styled(
                            glyph_x,
                            glyph_y,
                            icon_text,
                            &icon_font_name,
                            font_size,
                            font_bold,
                            font_italic,
                            color,
                            inner_left,
                            0,
                            inner_w,
                            clip_h,
                            0,
                            None,
                        );
                        if show_sort_numbers {
                            draw_sort_priority_number(
                                canvas, grid, sort_idx,
                                glyph_x + text_w + 1, inner_top, inner_h, inner_bottom,
                                inner_left, inner_w,
                            );
                        }
                        continue;
                    }
                }

                if is_sort_none {
                    // Keep default behavior: unsorted state shows no glyph unless
                    // caller explicitly configured icon_theme_slots.sort_none.
                    continue;
                }

                // Default fallback: text arrows.
                let mut fallback_icon = if sort_order_is_ascending(sort_order) {
                    "↑"
                } else {
                    "↓"
                };
                let (icon_font_name, font_size, font_bold, font_italic, color) =
                    resolve_icon_text_style(
                        grid,
                        slot_style,
                        (grid.style.font_size + 1.0).max(8.0),
                        false,
                        false,
                        grid.style.fore_color_fixed,
                    );
                let mut measured = canvas.measure_text(
                    fallback_icon,
                    &icon_font_name,
                    font_size,
                    font_bold,
                    font_italic,
                    None,
                );
                if measured.0 <= 0.1 {
                    fallback_icon = if sort_order_is_ascending(sort_order) {
                        "^"
                    } else {
                        "v"
                    };
                    measured = canvas.measure_text(
                        fallback_icon,
                        &icon_font_name,
                        font_size,
                        font_bold,
                        font_italic,
                        None,
                    );
                }
                let text_w = measured.0.ceil() as i32;
                let text_h = measured.1.ceil() as i32;
                let glyph_x = place_sort_icon_x(text_w);
                let glyph_y = inner_top + ((inner_h - text_h).max(0) / 2);
                let clip_h = (inner_bottom - glyph_y).max(1);
                canvas.draw_text_styled(
                    glyph_x,
                    glyph_y,
                    fallback_icon,
                    &icon_font_name,
                    font_size,
                    font_bold,
                    font_italic,
                    color,
                    inner_left,
                    0,
                    inner_w,
                    clip_h,
                    0,
                    None,
                );
                if show_sort_numbers {
                    draw_sort_priority_number(
                        canvas, grid, sort_idx,
                        glyph_x + text_w + 1, inner_top, inner_h, inner_bottom,
                        inner_left, inner_w,
                    );
                }
            }
        }
    }
}

/// Draw a small sort priority number (1, 2, 3…) next to the sort indicator.
fn draw_sort_priority_number<C: Canvas>(
    canvas: &mut C,
    grid: &VolvoxGrid,
    sort_idx: usize,
    x: i32,
    inner_top: i32,
    inner_h: i32,
    inner_bottom: i32,
    clip_x: i32,
    clip_w: i32,
) {
    let label = format!("{}", sort_idx + 1);
    let num_size = (grid.style.font_size * 0.7).max(7.0);
    let color = grid.style.fore_color_fixed;
    let (_, th) = canvas.measure_text(&label, &grid.style.font_name, num_size, false, false, None);
    let num_y = inner_top + ((inner_h - th.ceil() as i32).max(0) / 2);
    let clip_h = (inner_bottom - num_y).max(1);
    canvas.draw_text_styled(
        x, num_y, &label,
        &grid.style.font_name, num_size, false, false, color,
        clip_x, 0, clip_w, clip_h, 0, None,
    );
}

// ===========================================================================
// Layer 4c -- Column drag insertion marker
// ===========================================================================

fn render_col_drag_marker<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, vp: &VisibleRange) {
    if !grid.col_drag_active || grid.col_drag_insert_pos < 0 || grid.fixed_rows <= 0 {
        return;
    }

    let buf_w = canvas.width();
    let buf_h = canvas.height();

    let header_bottom = grid.layout.row_pos(grid.fixed_rows).clamp(0, buf_h);
    if header_bottom <= 0 {
        return;
    }

    let insert_before = grid.col_drag_insert_pos.clamp(0, grid.cols);
    let mut marker_x: Option<i32> = None;
    for row in 0..grid.fixed_rows {
        if grid.is_row_hidden(row) {
            continue;
        }
        if insert_before < grid.cols {
            if let Some((cx, _cy, _cw, _ch)) = cell_rect(grid, row, insert_before, vp) {
                marker_x = Some(cx);
                break;
            }
        } else if grid.cols > 0 {
            let last_col = grid.cols - 1;
            if let Some((cx, _cy, cw, _ch)) = cell_rect(grid, row, last_col, vp) {
                marker_x = Some(cx + cw);
                break;
            }
        } else {
            marker_x = Some(0);
            break;
        }
    }

    let Some(x) = marker_x else {
        return;
    };
    if x < -4 || x > buf_w + 4 {
        return;
    }

    let rail_color = 0xFF101010_u32;
    let center_color = 0xFFF5F5F5_u32;
    let h = header_bottom;
    canvas.vline(x - 1, 0, h, rail_color);
    canvas.vline(x, 0, h, center_color);
    canvas.vline(x + 1, 0, h, rail_color);
    canvas.fill_rect(x - 3, 0, 7, 2, rail_color);
    canvas.fill_rect(x - 3, (header_bottom - 2).max(0), 7, 2, rail_color);
}

fn can_resize_columns(grid: &VolvoxGrid) -> bool {
    matches!(grid.allow_user_resizing, 1 | 3 | 4 | 6)
}

fn resolve_header_mark_height_px(height: HeaderMarkHeight, row_height: i32) -> i32 {
    if row_height <= 0 {
        return 0;
    }
    match height {
        HeaderMarkHeight::Ratio(r) => {
            let raw = ((row_height as f32) * r.clamp(0.0, 1.0)).round() as i32;
            raw.clamp(1, row_height)
        }
        HeaderMarkHeight::Px(px) => px.max(1).min(row_height),
    }
}

// ===========================================================================
// Layer 4a -- Header separator / resize handle marks
// ===========================================================================

fn render_header_marks<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, vp: &VisibleRange) {
    if grid.fixed_rows <= 0 || grid.cols <= 1 {
        return;
    }

    let sep = grid.style.header_separator;
    let handle = grid.style.header_resize_handle;
    let show_resize_handle =
        handle.enabled && (!handle.show_only_when_resizable || can_resize_columns(grid));
    if !sep.enabled && !show_resize_handle {
        return;
    }

    let (color, width_px, height_spec, skip_merged) = if show_resize_handle {
        (
            handle.color,
            handle.width_px.max(1),
            handle.height,
            // Handle follows explicit boundaries; still skip when both cells share one merge.
            true,
        )
    } else {
        (sep.color, sep.width_px.max(1), sep.height, sep.skip_merged)
    };

    let max_col = grid.cols - 1;
    for row in 0..grid.fixed_rows {
        if grid.is_row_hidden(row) {
            continue;
        }
        for col in 0..max_col {
            if grid.is_col_hidden(col) || grid.is_col_hidden(col + 1) {
                continue;
            }
            let Some((lx, ly, lw, lh)) = cell_rect(grid, row, col, vp) else {
                continue;
            };
            let Some((_rx, _ry, rw, rh)) = cell_rect(grid, row, col + 1, vp) else {
                continue;
            };
            if lw <= 0 || rw <= 0 || lh <= 0 || rh <= 0 {
                continue;
            }

            if skip_merged {
                let left_merge = grid.get_merged_range(row, col);
                if left_merge.is_some() && left_merge == grid.get_merged_range(row, col + 1) {
                    continue;
                }
            }

            let row_height = lh.min(rh).max(1);
            let mark_height = resolve_header_mark_height_px(height_spec, row_height);
            if mark_height <= 0 {
                continue;
            }

            let center_x = lx + lw;
            let draw_x = center_x - (width_px / 2);
            let draw_y = ly + ((row_height - mark_height) / 2);
            for dx in 0..width_px {
                canvas.vline(draw_x + dx, draw_y, mark_height, color);
            }
        }
    }
}

// ===========================================================================
// Layer 5 -- Checkboxes
// ===========================================================================

fn render_checkboxes<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    vp: &VisibleRange,
    vis_cells: &[(i32, i32, i32, i32, i32, i32)],
) {
    let checked_pic = grid
        .style
        .checkbox_checked_picture
        .as_deref()
        .and_then(decode_png_rgba);
    let unchecked_pic = grid
        .style
        .checkbox_unchecked_picture
        .as_deref()
        .and_then(decode_png_rgba);
    let indeterminate_pic = grid
        .style
        .checkbox_indeterminate_picture
        .as_deref()
        .and_then(decode_png_rgba);
    let checked_text = grid
        .style
        .icon_theme_slots
        .checkbox_checked
        .as_deref()
        .filter(|s| !s.trim().is_empty());
    let unchecked_text = grid
        .style
        .icon_theme_slots
        .checkbox_unchecked
        .as_deref()
        .filter(|s| !s.trim().is_empty());
    let indeterminate_text = grid
        .style
        .icon_theme_slots
        .checkbox_indeterminate
        .as_deref()
        .filter(|s| !s.trim().is_empty());

    for &(row, col, cx, cy, cw, ch) in vis_cells {
        let is_boolean_col = grid.get_col_props(col).map_or(false, |cp| {
            cp.data_type == pb::ColumnDataType::ColumnDataBoolean as i32
        });

        let checked_state = grid
            .cells
            .get(row, col)
            .map_or(pb::CheckedState::CheckedUnchecked as i32, |c| c.checked());
        let slot_style = resolve_checkbox_slot_style(grid, checked_state);
        let icon_layout = resolve_icon_layout_style(grid, slot_style);

        if !is_boolean_col && checked_state == pb::CheckedState::CheckedUnchecked as i32 {
            continue;
        }

        if row < grid.fixed_rows {
            continue;
        }

        // Use original (pre-clip) bounds for positioning so checkboxes
        // don't shift during smooth scrolling.
        let (ox, oy, ow, oh) = original_cell_bounds(grid, row, col, cx, cy, cw, ch, vp);

        let box_size = 13_i32;
        let style_override = grid.get_cell_style(row, col);
        let alignment = resolve_alignment(grid, row, col, &style_override, "");
        let (halign, valign) = alignment_components(alignment);

        let max_bx = ox + ow - box_size;
        let max_by = oy + oh - box_size;
        if max_bx < ox || max_by < oy {
            continue;
        }

        let bx = match halign {
            0 => ox + 3,
            1 => ox + (ow - box_size) / 2,
            _ => ox + ow - box_size - 3,
        }
        .clamp(ox, max_bx);

        let by = match valign {
            0 => oy + 1,
            1 => oy + (oh - box_size) / 2,
            _ => oy + oh - box_size - 1,
        }
        .clamp(oy, max_by);
        let place_icon_x = |item_w: i32| {
            let max_tx = (ox + ow - item_w).max(ox);
            let gap = icon_layout.gap_px.max(0);
            let align = normalize_icon_align(icon_layout.align);
            let tx = match align {
                a if a == pb::IconAlign::InlineStart as i32 || a == pb::IconAlign::Start as i32 => {
                    ox + gap
                }
                a if a == pb::IconAlign::InlineEnd as i32 || a == pb::IconAlign::End as i32 => {
                    ox + ow - item_w - gap
                }
                _ => ox + (ow - item_w) / 2,
            };
            tx.clamp(ox, max_tx)
        };

        let pic_spec = if checked_state == pb::CheckedState::CheckedChecked as i32 {
            checked_pic.as_ref()
        } else if checked_state == pb::CheckedState::CheckedGrayed as i32 {
            indeterminate_pic.as_ref().or(unchecked_pic.as_ref())
        } else {
            unchecked_pic.as_ref()
        };
        if let Some((img_rgba, img_w, img_h)) = pic_spec {
            if *img_w > 0 && *img_h > 0 {
                let draw_h = (*img_h).min(oh - 2).max(1);
                let draw_w = ((*img_w as i64 * draw_h as i64) / *img_h as i64).max(1) as i32;
                let max_ty = (oy + oh - draw_h).max(oy);
                let tx = place_icon_x(draw_w);
                let ty = (oy + (oh - draw_h) / 2).clamp(oy, max_ty);
                if draw_w == *img_w && draw_h == *img_h {
                    canvas.blit_image_at(tx, ty, img_rgba, *img_w, *img_h);
                } else {
                    canvas.blit_image(tx, ty, draw_w, draw_h, img_rgba, *img_w, *img_h);
                }
                continue;
            }
        }

        let slot_text = if checked_state == pb::CheckedState::CheckedChecked as i32 {
            checked_text
        } else if checked_state == pb::CheckedState::CheckedGrayed as i32 {
            indeterminate_text.or(unchecked_text)
        } else {
            unchecked_text
        };
        if let Some(icon_text) = slot_text {
            let fallback_color = if checked_state == pb::CheckedState::CheckedGrayed as i32 {
                0xFF808080
            } else {
                grid.style.fore_color
            };
            let (icon_font_name, font_size, font_bold, font_italic, color) =
                resolve_icon_text_style(
                    grid,
                    slot_style,
                    (grid.style.font_size + 1.0).max(8.0),
                    false,
                    false,
                    fallback_color,
                );
            let (tw, th) = canvas.measure_text(
                icon_text,
                &icon_font_name,
                font_size,
                font_bold,
                font_italic,
                None,
            );
            let text_w = tw.ceil() as i32;
            let text_h = th.ceil() as i32;
            let max_ty = (oy + oh - text_h).max(oy);
            let tx = place_icon_x(text_w);
            let ty = (oy + (oh - text_h) / 2).clamp(oy, max_ty);
            canvas.draw_text_styled(
                tx,
                ty,
                icon_text,
                &icon_font_name,
                font_size,
                font_bold,
                font_italic,
                color,
                cx,
                cy,
                cw,
                ch,
                0,
                None,
            );
            continue;
        }

        // Clip checkbox against visible cell bounds so it doesn't draw
        // into fixed/frozen rows when scrolling.
        if bx < cx || by < cy || bx + box_size > cx + cw || by + box_size > cy + ch {
            continue;
        }

        // Draw checkbox outline
        let border_color = 0xFF707070_u32;
        canvas.rect_outline(bx, by, box_size, box_size, border_color);

        // Fill interior
        let interior_color = if checked_state == pb::CheckedState::CheckedGrayed as i32 {
            0xFFC0C0C0
        } else {
            0xFFFFFFFF
        };
        canvas.fill_rect(bx + 1, by + 1, box_size - 2, box_size - 2, interior_color);

        // Draw checkmark
        if checked_state == pb::CheckedState::CheckedChecked as i32
            || checked_state == pb::CheckedState::CheckedGrayed as i32
        {
            let mark_color = if checked_state == pb::CheckedState::CheckedGrayed as i32 {
                0xFF808080
            } else {
                0xFF000000
            };
            // Downstroke: (bx+3, by+6) to (bx+5, by+9)
            for i in 0..3 {
                canvas.set_pixel(bx + 3 + i, by + 6 + i, mark_color);
                canvas.set_pixel(bx + 3 + i + 1, by + 6 + i, mark_color);
            }
            // Upstroke: (bx+5, by+9) to (bx+10, by+4)
            for i in 0..5 {
                canvas.set_pixel(bx + 5 + i, by + 9 - i, mark_color);
                canvas.set_pixel(bx + 5 + i + 1, by + 9 - i, mark_color);
            }
        }
    }
}

// ===========================================================================
// Layer 6 -- Dropdown buttons
// ===========================================================================

fn render_dropdown_buttons<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    vp: &VisibleRange,
    vis_cells: &[(i32, i32, i32, i32, i32, i32)],
) {
    for &(row, col, cx, cy, cw, ch) in vis_cells {
        if !show_dropdown_button_for_cell(grid, row, col) {
            continue;
        }

        // Use original (pre-clip) bounds so the button stays at a fixed
        // position within the cell during smooth scrolling.
        let (ox, oy, ow, oh) = original_cell_bounds(grid, row, col, cx, cy, cw, ch, vp);

        let Some((bx, by, bw, bh)) = dropdown_button_rect(ox, oy, ow, oh) else {
            continue;
        };

        // Clip button against visible cell bounds so it doesn't draw into
        // fixed/frozen rows when scrolling — partial draw, not full skip.
        let vx0 = bx.max(cx);
        let vy0 = by.max(cy);
        let vx1 = (bx + bw).min(cx + cw);
        let vy1 = (by + bh).min(cy + ch);
        let vw = vx1 - vx0;
        let vh = vy1 - vy0;
        if vw <= 0 || vh <= 0 {
            continue;
        }

        // Button body — draw only the visible portion.
        canvas.fill_rect(vx0, vy0, vw, vh, 0xFFEAEAEA);
        canvas.rect_outline(vx0, vy0, vw, vh, 0xFF6A6A6A);

        // Glyph — draw per-pixel only within visible bounds.
        let list = grid.active_dropdown_list(row, col);
        if list.trim() == "..." {
            // Ellipsis glyph
            let gy = by + bh / 2;
            let start_x = bx + (bw / 2) - 3;
            for i in 0..3 {
                let gx = start_x + i * 3;
                if gx >= vx0 && gx < vx1 && gy >= vy0 && gy < vy1 {
                    canvas.set_pixel(gx, gy, 0xFF202020);
                }
            }
        } else {
            // Dropdown arrow glyph
            let cxm = bx + bw / 2;
            let cym = by + bh / 2;
            for row_off in 0..4 {
                let py = cym - 1 + row_off;
                if py < vy0 || py >= vy1 {
                    continue;
                }
                let half = 3 - row_off;
                for dx in -half..=half {
                    let px = cxm + dx;
                    if px >= vx0 && px < vx1 {
                        canvas.set_pixel(px, py, 0xFF202020);
                    }
                }
            }
        }
    }
}

// ===========================================================================
// Layer 7 -- Selection highlight
// ===========================================================================

fn render_selection<C: Canvas>(
    grid: &VolvoxGrid,
    _canvas: &mut C,
    _vis_cells: &[(i32, i32, i32, i32, i32, i32)],
) {
    // Selection background is now fully handled by Layer 1 (render_backgrounds)
    // via should_highlight_cell() → back_color_sel.  No additional overlay needed.
    let _ = grid;
}

// ===========================================================================
// Layer 7.5 -- Formula reference highlights (edit mode)
// ===========================================================================

fn range_screen_rect(
    grid: &VolvoxGrid,
    vp: &VisibleRange,
    row1: i32,
    col1: i32,
    row2: i32,
    col2: i32,
) -> Option<(i32, i32, i32, i32)> {
    if grid.rows <= 0 || grid.cols <= 0 {
        return None;
    }

    let r1 = row1.min(row2).clamp(0, grid.rows - 1);
    let c1 = col1.min(col2).clamp(0, grid.cols - 1);
    let r2 = row1.max(row2).clamp(0, grid.rows - 1);
    let c2 = col1.max(col2).clamp(0, grid.cols - 1);

    let mut min_x = i32::MAX;
    let mut min_y = i32::MAX;
    let mut max_x = i32::MIN;
    let mut max_y = i32::MIN;
    let mut any = false;

    iter_visible_cells(grid, vp, |row, col, x, y, w, h| {
        if row < r1 || row > r2 || col < c1 || col > c2 {
            return;
        }
        if w <= 0 || h <= 0 {
            return;
        }
        any = true;
        min_x = min_x.min(x);
        min_y = min_y.min(y);
        max_x = max_x.max(x + w);
        max_y = max_y.max(y + h);
    });

    if !any {
        return None;
    }
    let w = (max_x - min_x).max(1);
    let h = (max_y - min_y).max(1);
    Some((min_x, min_y, w, h))
}

fn draw_corner_handles<C: Canvas>(canvas: &mut C, x: i32, y: i32, w: i32, h: i32, color: u32) {
    if w <= 0 || h <= 0 {
        return;
    }
    let size = 7;
    let half = size / 2;
    let corners = [
        (x, y),
        (x + w - 1, y),
        (x, y + h - 1),
        (x + w - 1, y + h - 1),
    ];
    for (cx, cy) in corners {
        let sx = cx - half;
        let sy = cy - half;
        canvas.fill_rect(sx, sy, size, size, 0xFFFFFFFF);
        canvas.rect_outline(sx, sy, size, size, color);
        canvas.fill_rect(sx + 1, sy + 1, size - 2, size - 2, color);
    }
}

fn render_edit_highlights<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, vp: &VisibleRange) {
    if !grid.edit.is_active() || grid.edit.formula_highlights.is_empty() {
        return;
    }

    for region in &grid.edit.formula_highlights {
        let Some((x, y, w, h)) =
            range_screen_rect(grid, vp, region.row1, region.col1, region.row2, region.col2)
        else {
            continue;
        };
        let color = region.color;
        canvas.rect_outline_thick(x, y, w, h, 2, color);
        if region.show_corner_handles {
            draw_corner_handles(canvas, x, y, w, h, color);
        }
    }
}

// ===========================================================================
// Layer 8 -- Focus rect
// ===========================================================================

fn render_focus_rect<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, vp: &VisibleRange) {
    if grid.selection.focus_border == pb::FocusBorderStyle::FocusBorderNone as i32 {
        return;
    }

    let (cx, cy, cw, ch) = match cell_rect(grid, grid.selection.row, grid.selection.col, vp) {
        Some(r) => r,
        None => return,
    };

    match grid.selection.focus_border {
        f if f == pb::FocusBorderStyle::FocusBorderThin as i32 => {
            canvas.dotted_rect(cx, cy, cw, ch, 0xFF000000);
        }
        f if f == pb::FocusBorderStyle::FocusBorderThick as i32 => {
            canvas.rect_outline(cx, cy, cw, ch, 0xFF000000);
            canvas.rect_outline(cx + 1, cy + 1, cw - 2, ch - 2, 0xFF000000);
        }
        f if f == pb::FocusBorderStyle::FocusBorderInset as i32 => {
            canvas.rect_3d(cx, cy, cw, ch, false);
        }
        f if f == pb::FocusBorderStyle::FocusBorderRaised as i32 => {
            canvas.rect_3d(cx, cy, cw, ch, true);
        }
        _ => {}
    }
}

// ===========================================================================
// Layer 8b -- Fill handle (small square at selection corner)
// ===========================================================================

fn render_fill_handle<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, vp: &VisibleRange) {
    if !grid.selection.show_fill_handle {
        return;
    }
    if !is_highlight_active(grid) {
        return;
    }

    // Get the bottom-right cell of the selection range
    let (_, _, r2, c2) = grid.selection.get_range();
    let r2 = r2.min(grid.rows - 1);
    let c2 = c2.min(grid.cols - 1);

    let (cx, cy, cw, ch) = match cell_rect(grid, r2, c2, vp) {
        Some(r) => r,
        None => return,
    };

    // 7-device-pixel square centered on the cell's bottom-right corner
    let size = 7i32;
    let half = size / 2; // 3
    let anchor_x = cx + cw - 1;
    let anchor_y = cy + ch - 1;
    let sx = anchor_x - half;
    let sy = anchor_y - half;

    // White border (7×7)
    canvas.fill_rect(sx, sy, size, size, 0xFFFFFFFF);
    // Colored interior (5×5)
    canvas.fill_rect(sx + 1, sy + 1, size - 2, size - 2, grid.style.fill_handle_color);
}

// ===========================================================================
// Layer 9 -- Outline tree lines and +/- buttons
// ===========================================================================

fn render_outline<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, vp: &VisibleRange) {
    if grid.outline.tree_indicator == pb::TreeIndicatorStyle::TreeIndicatorNone as i32 {
        return;
    }
    if grid.outline.tree_column < 0 || grid.outline.tree_column >= grid.cols {
        return;
    }

    let tree_color = grid.style.tree_color;
    let tree_col = grid.outline.tree_column;
    let tg = crate::outline::TreeGeometry::from_grid(grid);
    let has_subtotal_nodes = grid.row_props.values().any(|rp| rp.is_subtotal);
    let subtotal_level_floor = first_subtotal_level(grid);

    let row_ranges = [
        (0, vp.fixed_row_end),
        (vp.scroll_row_start, vp.scroll_row_end),
    ];
    for (row_start, row_end) in row_ranges {
        for row in row_start..row_end {
            if row < grid.fixed_rows {
                continue;
            }

            let row_props = grid.get_row_props(row);
            let level = row_props.map_or(0, |rp| rp.outline_level);
            let is_subtotal = row_props.map_or(false, |rp| rp.is_subtotal);
            if has_subtotal_nodes && !is_subtotal {
                continue;
            }
            // Subtotal trees are rendered one visual level deeper
            // than stored outline_level (root subtotal L=0 still has tree gutter).
            let visual_level = if has_subtotal_nodes {
                subtotal_visual_level(level, is_subtotal, subtotal_level_floor)
            } else {
                level
            };
            if visual_level <= 0 {
                continue;
            }

            let (cx, cy, cw, ch) = match cell_rect(grid, row, tree_col, vp) {
                Some(r) => r,
                None => continue,
            };

            // Use original (pre-clip) bounds so tree elements don't
            // shift during smooth scrolling.
            let (ox, oy, _ow, oh) =
                original_cell_bounds(grid, row, tree_col, cx, cy, cw, ch, vp);

            let indent = tg.indent(visual_level);
            let line_x = ox + tg.line_x(visual_level);
            let mid_y = oy + oh / 2;

            // Subtotal rendering uses +/- nodes without connector lines.
            let draw_lines = !has_subtotal_nodes
                && (grid.outline.tree_indicator
                    == pb::TreeIndicatorStyle::TreeIndicatorConnectors as i32
                    || grid.outline.tree_indicator
                        == pb::TreeIndicatorStyle::TreeIndicatorConnectorsLeaf as i32);
            if draw_lines {
                // Vertical tree line
                canvas.vline(line_x, oy, oh, tree_color);

                // Horizontal connector line
                let h_start = line_x;
                let h_end = ox + indent + tg.connector_end;
                if h_end > h_start {
                    canvas.hline(h_start, mid_y, h_end - h_start, tree_color);
                }
            }

            // +/- button for subtotal tree nodes
            if is_subtotal {
                let is_collapsed = row_props.map_or(false, |rp| rp.is_collapsed);
                let bx = line_x - tg.btn_size / 2;
                let by = mid_y - tg.btn_size / 2;
                let node_picture = if is_collapsed {
                    grid.outline.node_closed_picture.as_deref()
                } else {
                    grid.outline.node_open_picture.as_deref()
                };
                if let Some(pic_data) = node_picture {
                    if let Some((img_rgba, img_w, img_h)) = decode_png_rgba(pic_data) {
                        if img_w > 0 && img_h > 0 {
                            let draw_h = img_h.min(tg.btn_size).max(1);
                            let draw_w =
                                ((img_w as i64 * draw_h as i64) / img_h as i64).max(1) as i32;
                            let tx = bx + (tg.btn_size - draw_w) / 2;
                            let ty = by + (tg.btn_size - draw_h) / 2;
                            if draw_w == img_w && draw_h == img_h {
                                canvas.blit_image_at(tx, ty, &img_rgba, img_w, img_h);
                            } else {
                                canvas.blit_image(tx, ty, draw_w, draw_h, &img_rgba, img_w, img_h);
                            }
                            continue;
                        }
                    }
                }
                let node_icon = if is_collapsed {
                    grid.style
                        .icon_theme_slots
                        .tree_collapsed
                        .as_deref()
                        .filter(|s| !s.trim().is_empty())
                } else {
                    grid.style
                        .icon_theme_slots
                        .tree_expanded
                        .as_deref()
                        .filter(|s| !s.trim().is_empty())
                };
                let node_slot_style = resolve_tree_slot_style(grid, is_collapsed);
                if let Some(icon) = node_icon {
                    let (icon_font_name, font_size, font_bold, font_italic, icon_color) =
                        resolve_icon_text_style(
                            grid,
                            node_slot_style,
                            (grid.style.font_size + 1.0).max(8.0),
                            false,
                            false,
                            tree_color,
                        );
                    let (tw, th) = canvas.measure_text(
                        icon,
                        &icon_font_name,
                        font_size,
                        font_bold,
                        font_italic,
                        None,
                    );
                    let text_w = tw.ceil() as i32;
                    let text_h = th.ceil() as i32;
                    let tx = bx + (tg.btn_size - text_w) / 2;
                    let ty = by + (tg.btn_size - text_h) / 2;
                    canvas.draw_text_styled(
                        tx,
                        ty,
                        icon,
                        &icon_font_name,
                        font_size,
                        font_bold,
                        font_italic,
                        icon_color,
                        cx,
                        cy,
                        cw,
                        ch,
                        0,
                        None,
                    );
                    continue;
                }

                // Draw button box
                canvas.fill_rect(bx, by, tg.btn_size, tg.btn_size, 0xFFFFFFFF);
                canvas.rect_outline(bx, by, tg.btn_size, tg.btn_size, tree_color);

                // Draw minus sign
                canvas.hline(
                    bx + tg.sign_margin,
                    mid_y,
                    tg.btn_size - tg.sign_margin * 2,
                    tree_color,
                );

                // Draw vertical part of plus sign if collapsed
                if is_collapsed {
                    canvas.vline(
                        line_x,
                        by + tg.sign_margin,
                        tg.btn_size - tg.sign_margin * 2,
                        tree_color,
                    );
                }
            }
        }
    }
}

/// Lowest positive outline level among subtotal rows, or 0 when there are no
/// positive levels.
///
/// Subtotal trees can contain helper subtotal rows at level 0 (and even
/// grand rows at -1) while deeper subtotal rows carry the actual branch level.
/// Normalizing from the first positive level keeps mixed trees aligned instead
/// of over-indenting deep subtotal rows.
fn first_subtotal_level(grid: &VolvoxGrid) -> i32 {
    grid.row_props
        .values()
        .filter(|rp| rp.is_subtotal)
        .map(|rp| rp.outline_level)
        .filter(|lvl| *lvl > 0)
        .min()
        .unwrap_or(0)
}

/// Map stored outline levels to visual gutter levels for subtotal trees.
///
/// Layouts with only one subtotal depth store subtotals at level 1 but
/// still render the tree at the first gutter position (no extra leading pad).
/// Mixed trees (level 0 + level 1 subtotals) keep the deeper detail alignment.
fn subtotal_visual_level(level: i32, is_subtotal: bool, subtotal_level_floor: i32) -> i32 {
    if is_subtotal {
        if level < 0 {
            0
        } else {
            (level - subtotal_level_floor + 1).max(1)
        }
    } else {
        (2 - subtotal_level_floor).max(1)
    }
}

// ===========================================================================
// Layer 10 -- Frozen pane separator lines
// ===========================================================================

fn render_frozen_borders<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, _vp: &VisibleRange) {
    let border_color = 0xFF000000_u32;
    let buf_w = canvas.width();
    let buf_h = canvas.height();

    // Grid content boundaries — lines should not extend beyond these.
    // Account for scroll offset: scrollable cells are rendered shifted by scroll_x/scroll_y,
    // so the visible right/bottom edge is the total extent minus the scroll offset.
    let scroll_x = grid.scroll.scroll_x as i32;
    let scroll_y = grid.scroll.scroll_y as i32;
    let content_w = (grid.col_pos(grid.cols) - scroll_x).min(buf_w);
    let content_h = (grid.row_pos(grid.rows) - scroll_y).min(buf_h);

    // Horizontal frozen row border
    if grid.frozen_rows > 0 {
        let frozen_row_bottom = grid.row_pos(grid.fixed_rows + grid.frozen_rows);
        if frozen_row_bottom > 0 && frozen_row_bottom < buf_h {
            canvas.hline(0, frozen_row_bottom, content_w, border_color);
        }
    }

    // Vertical frozen col border
    if grid.frozen_cols > 0 {
        let frozen_col_right = grid.col_pos(grid.fixed_cols + grid.frozen_cols);
        if frozen_col_right > 0 && frozen_col_right < buf_w {
            canvas.vline(frozen_col_right, 0, content_h, border_color);
        }
    }

    // Fixed row/col separator line (single pixel)
    if grid.fixed_rows > 0 {
        let fixed_row_bottom = grid.row_pos(grid.fixed_rows);
        if fixed_row_bottom > 0 && fixed_row_bottom < buf_h {
            canvas.hline(0, fixed_row_bottom, content_w, border_color);
        }
    }
    if grid.fixed_cols > 0 {
        let fixed_col_right = grid.col_pos(grid.fixed_cols);
        if fixed_col_right > 0 && fixed_col_right < buf_w {
            canvas.vline(fixed_col_right, 0, content_h, border_color);
        }
    }
}

// ===========================================================================
// Layer 11 -- Active in-place editor
// ===========================================================================

fn render_active_editor<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, vp: &VisibleRange) {
    if !grid.edit.is_active() {
        return;
    }

    let row = grid.edit.edit_row;
    let col = grid.edit.edit_col;
    if row < 0 || row >= grid.rows || col < 0 || col >= grid.cols {
        return;
    }

    let Some((cx, cy, cw, ch)) = cell_rect(grid, row, col, vp) else {
        return;
    };

    let style_override = grid.get_cell_style(row, col);
    let is_fixed = row < grid.fixed_rows || col < grid.fixed_cols;
    let is_frozen = !is_fixed
        && (row < grid.fixed_rows + grid.frozen_rows || col < grid.fixed_cols + grid.frozen_cols);
    let fore = style_override.resolve_fore_color(&grid.style, is_fixed, is_frozen, false);
    let font_name = style_override
        .font_name
        .as_deref()
        .unwrap_or(&grid.style.font_name);
    let font_size = style_override.font_size.unwrap_or(grid.style.font_size);
    let font_bold = style_override.font_bold.unwrap_or(grid.style.font_bold);
    let font_italic = style_override.font_italic.unwrap_or(grid.style.font_italic);
    let text_style = if is_fixed {
        style_override
            .text_effect
            .unwrap_or(grid.style.text_effect_fixed)
    } else {
        style_override.text_effect.unwrap_or(grid.style.text_effect)
    };

    let button_reserve = if show_dropdown_button_for_cell(grid, row, col) {
        dropdown_button_rect(cx, cy, cw, ch).map_or(0, |(_, _, bw, _)| bw + 2)
    } else {
        0
    };
    let edit_w = (cw - button_reserve).max(1);
    let padding = grid.resolve_cell_padding(row, col, &style_override);
    let left_padding = padding.left;
    let top_padding = padding.top;
    let right_padding = padding.right;
    let bottom_padding = padding.bottom;
    let inner_h = (ch - top_padding - bottom_padding).max(1);

    // Editor frame
    let editor_bg = 0xFFFFFFFF;
    let editor_border = 0xFF2D6CDF;
    canvas.fill_rect(
        cx + 1,
        cy + 1,
        (edit_w - 2).max(0),
        (ch - 2).max(0),
        editor_bg,
    );
    canvas.rect_outline(cx, cy, edit_w, ch, editor_border);

    let text = grid.edit.edit_text.as_str();
    let text_char_count = text.chars().count() as i32;
    let sel_start = grid.edit.sel_start.clamp(0, text_char_count);
    let sel_end = (grid.edit.sel_start + grid.edit.sel_length).clamp(0, text_char_count);

    let prefix = &text[..byte_index_at_char(text, sel_start)];
    let selected = &text[byte_index_at_char(text, sel_start)..byte_index_at_char(text, sel_end)];
    let (_, th) = canvas.measure_text(text, font_name, font_size, font_bold, font_italic, None);
    let text_y = cy + top_padding + ((inner_h - th.ceil() as i32) / 2).max(0);

    let text_x = cx + left_padding;
    let clip_w = (edit_w - left_padding - right_padding).max(1);
    let clip_h = inner_h;

    // Selection highlight
    if sel_end > sel_start {
        let (prefix_w, _) =
            canvas.measure_text(prefix, font_name, font_size, font_bold, font_italic, None);
        let (sel_w, _) =
            canvas.measure_text(selected, font_name, font_size, font_bold, font_italic, None);
        let sel_x = text_x + prefix_w.ceil() as i32;
        let sel_w_px = sel_w.ceil() as i32;
        let sel_left = sel_x.max(text_x);
        let sel_right = (sel_x + sel_w_px).min(cx + edit_w - right_padding);
        canvas.fill_rect(
            sel_left,
            cy + top_padding,
            (sel_right - sel_left).max(1),
            inner_h,
            0xFFBDD7FF,
        );
    }

    // Editor text
    canvas.draw_text_styled(
        text_x,
        text_y,
        text,
        font_name,
        font_size,
        font_bold,
        font_italic,
        fore,
        text_x,
        0,
        clip_w,
        clip_h,
        text_style,
        None,
    );

    // Re-render selected run with selection foreground for contrast.
    if sel_end > sel_start && !selected.is_empty() {
        let (prefix_w, _) =
            canvas.measure_text(prefix, font_name, font_size, font_bold, font_italic, None);
        let sel_x = text_x + prefix_w.ceil() as i32;
        canvas.draw_text_styled(
            sel_x,
            text_y,
            selected,
            font_name,
            font_size,
            font_bold,
            font_italic,
            0xFF000000,
            sel_x,
            0,
            clip_w,
            clip_h,
            text_style,
            None,
        );
    }

    // Caret (when no range is selected)
    if sel_end == sel_start {
        let (prefix_w, _) =
            canvas.measure_text(prefix, font_name, font_size, font_bold, font_italic, None);
        let caret_max = (cx + edit_w - right_padding).max(text_x);
        let caret_x = (text_x + prefix_w.ceil() as i32).clamp(text_x, caret_max);
        canvas.vline(caret_x, cy + top_padding, inner_h, 0xFF000000);
    }
}

// ===========================================================================
// Layer 12 -- Active dropdown list
// ===========================================================================

fn render_active_dropdown<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, vp: &VisibleRange) {
    if grid.host_dropdown_overlay {
        return;
    }
    if !grid.edit.is_active() {
        return;
    }

    let row = grid.edit.edit_row;
    let col = grid.edit.edit_col;
    if row < 0 || row >= grid.rows || col < 0 || col >= grid.cols {
        return;
    }

    let list = grid.active_dropdown_list(row, col);
    if list.is_empty() || list.trim() == "..." {
        return;
    }

    let count = grid.edit.dropdown_count();
    if count <= 0 {
        return;
    }

    let Some((cx, cy, cw, ch)) = cell_rect(grid, row, col, vp) else {
        return;
    };

    let buf_w = canvas.width();
    let buf_h = canvas.height();

    let visible_count = count.min(8).max(1);
    let item_h = ch.max(18);
    let drop_h = item_h * visible_count;
    /* Listbox geometry: width follows the source column. */
    let drop_w = cw.max(90);
    let mut drop_x = cx;
    let mut drop_y = cy + ch - 1;

    if drop_x + drop_w > buf_w {
        drop_x = (buf_w - drop_w).max(0);
    }
    if drop_y + drop_h > buf_h {
        drop_y = cy - drop_h + 1;
    }
    if drop_y < 0 {
        drop_y = 0;
    }
    if drop_y + drop_h > buf_h {
        drop_y = (buf_h - drop_h).max(0);
    }

    canvas.blend_rect(drop_x + 2, drop_y + 2, drop_w, drop_h, 0x55000000);
    canvas.fill_rect(drop_x, drop_y, drop_w, drop_h, 0xFFFFFFFF);
    canvas.rect_outline(drop_x, drop_y, drop_w, drop_h, 0xFF4A4A4A);

    let mut start = 0;
    let sel = grid.edit.dropdown_index;
    if sel >= 0 && sel >= visible_count {
        start = sel - visible_count + 1;
    }
    let max_start = (count - visible_count).max(0);
    if start > max_start {
        start = max_start;
    }

    let font_name = &grid.style.font_name;
    let font_size = grid.style.font_size;
    let font_bold = grid.style.font_bold;
    let font_italic = grid.style.font_italic;
    let text_style = grid.style.text_effect;
    let text_padding = 4_i32;

    for slot in 0..visible_count {
        let idx = start + slot;
        let item_y = drop_y + slot * item_h;
        let selected = idx == sel;

        let row_bg = if selected {
            grid.style.back_color_sel
        } else {
            0xFFFFFFFF
        };
        canvas.fill_rect(
            drop_x + 1,
            item_y + 1,
            (drop_w - 2).max(0),
            (item_h - 1).max(0),
            row_bg,
        );

        let text_color = if selected {
            grid.style.fore_color_sel
        } else {
            grid.style.fore_color
        };
        let item_text = grid.edit.get_dropdown_item(idx);
        let (_, th) = canvas.measure_text(
            item_text,
            font_name,
            font_size,
            font_bold,
            font_italic,
            None,
        );
        let text_y = item_y + ((item_h - th.ceil() as i32) / 2).max(0);
        canvas.draw_text_styled(
            drop_x + text_padding,
            text_y,
            item_text,
            font_name,
            font_size,
            font_bold,
            font_italic,
            text_color,
            drop_x + text_padding,
            0,
            (drop_w - text_padding * 2).max(1),
            item_h,
            text_style,
            None,
        );
    }
}

// ===========================================================================
// Layer 13 -- Scroll bars
// ===========================================================================

fn render_scroll_bars<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C) {
    let allow_h = grid.scroll_bars == pb::ScrollBarsMode::ScrollbarHorizontal as i32
        || grid.scroll_bars == pb::ScrollBarsMode::ScrollbarBoth as i32;
    let allow_v = grid.scroll_bars == pb::ScrollBarsMode::ScrollbarVertical as i32
        || grid.scroll_bars == pb::ScrollBarsMode::ScrollbarBoth as i32;
    if !allow_h && !allow_v {
        return;
    }

    const SB_SIZE: i32 = 16;
    let buf_w = canvas.width();
    let buf_h = canvas.height();
    if buf_w <= SB_SIZE || buf_h <= SB_SIZE {
        return;
    }

    let fixed_height = grid.layout.row_pos(grid.fixed_rows);
    let fixed_width = grid.layout.col_pos(grid.fixed_cols);
    let pinned_height = grid.pinned_top_height() + grid.pinned_bottom_height();
    let pinned_width = grid.pinned_left_width() + grid.pinned_right_width();

    let compute_max_scroll = |view_w: i32, view_h: i32| -> (f32, f32) {
        let mx = (grid.layout.total_width - view_w + fixed_width + pinned_width).max(0) as f32;
        let my = (grid.layout.total_height - view_h + fixed_height + pinned_height).max(0) as f32;
        (mx, my)
    };

    // Resolve bar visibility iteratively
    let mut show_h = false;
    let mut show_v = false;
    for _ in 0..3 {
        let view_w = (buf_w - if show_v { SB_SIZE } else { 0 }).max(1);
        let view_h = (buf_h - if show_h { SB_SIZE } else { 0 }).max(1);
        let (mx, my) = compute_max_scroll(view_w, view_h);
        let next_h = allow_h && mx > 0.0;
        let next_v = allow_v && my > 0.0;
        if next_h == show_h && next_v == show_v {
            break;
        }
        show_h = next_h;
        show_v = next_v;
    }

    if !show_h && !show_v {
        return;
    }

    let view_w = (buf_w - if show_v { SB_SIZE } else { 0 }).max(1);
    let view_h = (buf_h - if show_h { SB_SIZE } else { 0 }).max(1);
    let (max_x, max_y) = compute_max_scroll(view_w, view_h);
    let scroll_x = grid.scroll.scroll_x.clamp(0.0, max_x);
    let scroll_y = grid.scroll.scroll_y.clamp(0.0, max_y);

    let face = 0xFFC0C0C0_u32;
    let track = 0xFFD8D8D8_u32;
    let arrow = 0xFF000000_u32;
    let border = 0xFF606060_u32;

    if show_h {
        let x = 0;
        let y = buf_h - SB_SIZE;
        let w = (buf_w - if show_v { SB_SIZE } else { 0 }).max(SB_SIZE);
        let h = SB_SIZE;

        canvas.fill_rect(x, y, w, h, face);
        canvas.rect_outline(x, y, w, h, border);

        let left_x = x;
        let right_x = x + w - SB_SIZE;
        canvas.draw_scroll_button(left_x, y, SB_SIZE, h, face);
        canvas.draw_scroll_button(right_x, y, SB_SIZE, h, face);
        canvas.draw_scroll_arrow_left(left_x, y, SB_SIZE, h, arrow);
        canvas.draw_scroll_arrow_right(right_x, y, SB_SIZE, h, arrow);

        let track_x = x + SB_SIZE;
        let track_w = (w - SB_SIZE * 2).max(0);
        if track_w > 0 {
            canvas.fill_rect(track_x, y, track_w, h, track);
            canvas.fill_checker(track_x, y, track_w, h);
            canvas.rect_outline(track_x, y, track_w, h, border);

            let mut thumb_w = if max_x > 0.0 {
                ((view_w as f32 / (view_w as f32 + max_x)) * track_w as f32).round() as i32
            } else {
                track_w
            };
            thumb_w = thumb_w.clamp(12, track_w.max(12)).min(track_w);
            let thumb_range = (track_w - thumb_w).max(0);
            let thumb_off = if max_x > 0.0 && thumb_range > 0 {
                ((scroll_x / max_x) * thumb_range as f32).round() as i32
            } else {
                0
            };
            let thumb_x = track_x + thumb_off;
            canvas.draw_scroll_thumb(thumb_x, y + 1, thumb_w, h - 2, face);
        }
    }

    if show_v {
        let x = buf_w - SB_SIZE;
        let y = 0;
        let w = SB_SIZE;
        let h = (buf_h - if show_h { SB_SIZE } else { 0 }).max(SB_SIZE);

        canvas.fill_rect(x, y, w, h, face);
        canvas.rect_outline(x, y, w, h, border);

        let top_y = y;
        let bot_y = y + h - SB_SIZE;
        canvas.draw_scroll_button(x, top_y, w, SB_SIZE, face);
        canvas.draw_scroll_button(x, bot_y, w, SB_SIZE, face);
        canvas.draw_scroll_arrow_up(x, top_y, w, SB_SIZE, arrow);
        canvas.draw_scroll_arrow_down(x, bot_y, w, SB_SIZE, arrow);

        let track_y = y + SB_SIZE;
        let track_h = (h - SB_SIZE * 2).max(0);
        if track_h > 0 {
            canvas.fill_rect(x, track_y, w, track_h, track);
            canvas.fill_checker(x, track_y, w, track_h);
            canvas.rect_outline(x, track_y, w, track_h, border);

            let mut thumb_h = if max_y > 0.0 {
                ((view_h as f32 / (view_h as f32 + max_y)) * track_h as f32).round() as i32
            } else {
                track_h
            };
            thumb_h = thumb_h.clamp(12, track_h.max(12)).min(track_h);
            let thumb_range = (track_h - thumb_h).max(0);
            let thumb_off = if max_y > 0.0 && thumb_range > 0 {
                ((scroll_y / max_y) * thumb_range as f32).round() as i32
            } else {
                0
            };
            let thumb_y = track_y + thumb_off;
            canvas.draw_scroll_thumb(x + 1, thumb_y, w - 2, thumb_h, face);
        }
    }

    if show_h && show_v {
        let x = buf_w - SB_SIZE;
        let y = buf_h - SB_SIZE;
        canvas.fill_rect(x, y, SB_SIZE, SB_SIZE, track);
        canvas.fill_checker(x, y, SB_SIZE, SB_SIZE);
        canvas.rect_outline(x, y, SB_SIZE, SB_SIZE, border);
    }
}

// ===========================================================================
// Layer 13.5 -- Fast scroll overlay
// ===========================================================================

fn render_fast_scroll<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C) {
    if !grid.fast_scroll_active || !grid.fast_scroll_enabled {
        return;
    }
    let rows = grid.rows;
    let fixed = grid.fixed_rows;
    if rows <= fixed + 1 {
        return;
    }

    let s = grid.scale.max(0.01);
    let vp_w = canvas.width();
    let vp_h = canvas.height();

    // Constants scaled by DPI
    let rail_w = (6.0 * s).round() as i32;
    let right_inset = (8.0 * s).round() as i32;
    let vert_inset = (12.0 * s).round() as i32;
    let thumb_min_h = (56.0 * s).round() as i32;

    // Track rect
    let track_left = vp_w - right_inset - rail_w;
    let track_top = vert_inset;
    let track_bottom = (vp_h - vert_inset).max(track_top + 1);
    let track_h = track_bottom - track_top;

    // Draw track (semi-transparent gray)
    let track_color: u32 = 0x66404040;
    canvas.blend_rect(track_left, track_top, rail_w, track_h, track_color);

    // Compute thumb position
    let max_row = (rows - 1).max(fixed);
    let current_row = if grid.fast_scroll_target_row >= fixed {
        grid.fast_scroll_target_row.min(max_row)
    } else {
        fixed
    };
    let data_rows = (rows - fixed).max(1);
    let ratio = if data_rows <= 1 {
        0.0
    } else {
        ((current_row - fixed) as f32 / (data_rows - 1) as f32).clamp(0.0, 1.0)
    };

    let thumb_h = thumb_min_h.min(track_h).max((20.0 * s).round() as i32);
    let thumb_travel = (track_h - thumb_h).max(0);
    let thumb_top = track_top + (ratio * thumb_travel as f32).round() as i32;
    let thumb_expand = (4.0 * s).round() as i32;
    let thumb_left = track_left - thumb_expand;
    let thumb_w = rail_w + thumb_expand * 2;

    // Draw thumb (dark, opaque)
    let thumb_color: u32 = 0xFF1F1F1F;
    canvas.fill_rect(thumb_left, thumb_top, thumb_w, thumb_h, thumb_color);

    // Draw bubble with row label
    let label = format!(
        "{} / {}",
        format_number(current_row),
        format_number(max_row)
    );
    let font_size = (13.0 * s).round();
    let font_name = "";
    let (text_w, text_h) = canvas.measure_text(&label, font_name, font_size, false, false, None);
    let pad_x = (10.0 * s).round() as i32;
    let pad_y = (6.0 * s).round() as i32;
    let bubble_w = text_w.ceil() as i32 + pad_x * 2;
    let bubble_h = text_h.ceil() as i32 + pad_y * 2;
    let bubble_gap = (12.0 * s).round() as i32;
    let bubble_right = track_left - bubble_gap;
    let bubble_left = (bubble_right - bubble_w).max((8.0 * s).round() as i32);
    let thumb_center_y = thumb_top + thumb_h / 2;
    let margin = (8.0 * s).round() as i32;
    let bubble_top = (thumb_center_y - bubble_h / 2)
        .max(margin)
        .min(vp_h - bubble_h - margin);

    // Draw bubble background (near-black, ~90% opaque)
    let bubble_color: u32 = 0xE6191919;
    canvas.blend_rect(bubble_left, bubble_top, bubble_w, bubble_h, bubble_color);

    // Draw label text (white)
    let text_x = bubble_left + pad_x;
    let text_y = bubble_top + pad_y;
    canvas.draw_text(
        text_x,
        text_y,
        &label,
        font_name,
        font_size,
        false,
        false,
        0xFFFFFFFF,
        bubble_left,
        0,
        bubble_w,
        bubble_h,
        None,
    );
}

// ===========================================================================
// Layer 14 -- Debug overlay
// ===========================================================================

fn render_debug_overlay<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, vp: &VisibleRange) {
    if !grid.debug_overlay {
        return;
    }

    let buf_w = canvas.width();
    let buf_h = canvas.height();

    let scale = (grid.style.font_size / 14.0).clamp(0.5, 3.0);
    let font_name = "";
    let font_size: f32 = (11.0 * scale).round();
    let line_height: i32 = (font_size * 1.35).ceil() as i32;
    let padding: i32 = (6.0 * scale).round() as i32;
    let text_color: u32 = 0xFFFFFFFF;
    let bg_color: u32 = 0xC0000000;

    let mut lines: Vec<String> = Vec::new();

    let mode_str = match grid.renderer_mode {
        m if m == pb::RendererMode::RendererAuto as i32 => {
            if grid.debug_renderer_actual == pb::RendererMode::RendererGpu as i32 {
                if !grid.debug_gpu_backend.is_empty() {
                    let pm = if !grid.debug_gpu_present_mode.is_empty() {
                        format!("-{}", grid.debug_gpu_present_mode)
                    } else {
                        "".to_string()
                    };
                    format!("AUTO(GPU-{}{})", grid.debug_gpu_backend, pm)
                } else {
                    "AUTO(GPU)".to_string()
                }
            } else {
                "AUTO(CPU)".to_string()
            }
        }
        m if m >= pb::RendererMode::RendererGpu as i32 => {
            if !grid.debug_gpu_backend.is_empty() {
                let pm = if !grid.debug_gpu_present_mode.is_empty() {
                    format!("-{}", grid.debug_gpu_present_mode)
                } else {
                    "".to_string()
                };
                format!("GPU({}{})", grid.debug_gpu_backend, pm)
            } else {
                "GPU".to_string()
            }
        }
        _ => "CPU".to_string(),
    };

    lines.push(format!(
        "FPS: {:.1} | {:.1}ms | Q: {} | ID: {} | Z: {:.0}% | Res: {}x{}",
        grid.debug_fps, grid.debug_frame_time_ms, grid.debug_instance_count, grid.id, grid.debug_zoom_level * 100.0, buf_w, buf_h,
    ));

    let status_str = if grid.dirty {
        let mut reasons = Vec::new();
        if grid.animation.active { reasons.push("ANIM".to_string()); }
        if grid.background_loading { reasons.push("LOAD".to_string()); }
        if grid.scroll.fling_active {
            let vel = (grid.scroll.fling_vx.powi(2) + grid.scroll.fling_vy.powi(2)).sqrt();
            reasons.push(format!("V:{:.0}", vel));
        }
        if reasons.is_empty() {
            "DIRTY".to_string()
        } else {
            format!("DIRTY({})", reasons.join("+"))
        }
    } else {
        "CLEAN".to_string()
    };

    lines.push(format!(
        "Mode: {} | Grid: {}x{} | {}",
        mode_str,
        format_number(grid.rows),
        grid.cols,
        status_str
    ));

    let visible_rows = vp.scroll_row_end - vp.scroll_row_start + grid.fixed_rows + grid.frozen_rows;
    let visible_cols = vp.scroll_col_end - vp.scroll_col_start + grid.fixed_cols + grid.frozen_cols;
    let mem_mb = grid.debug_total_mem_bytes as f64 / 1024.0 / 1024.0;
    let mem_str = if mem_mb >= 1.0 {
        format!("{:.1}MB", mem_mb)
    } else {
        format!("{:.0}KB", grid.debug_total_mem_bytes as f64 / 1024.0)
    };

    lines.push(format!(
        "Vis: {}x{}({}) | P: {},{} | M: {} | C: {}/{}",
        visible_rows,
        visible_cols,
        visible_rows * visible_cols,
        grid.scroll.scroll_x as i32,
        grid.scroll.scroll_y as i32,
        mem_str,
        grid.debug_text_cache_len,
        grid.text_layout_cache_cap,
    ));

    if !grid.sort_state.sort_keys.is_empty() {
        let keys_str: Vec<String> = grid
            .sort_state
            .sort_keys
            .iter()
            .map(|&(col, order)| {
                let o = match order {
                    1 => "ASC",
                    2 => "DESC",
                    _ => "NONE",
                };
                format!("{}:{}", col, o)
            })
            .collect();
        lines.push(format!(
            "Sort: {} | {:.2}ms",
            keys_str.join(", "),
            grid.sort_state.last_sort_elapsed_ms
        ));
    }

    let num_lines = lines.len() as i32;
    let overlay_h = num_lines * line_height + padding * 2;
    let overlay_w = ((320.0 * scale) as i32).min(buf_w);
    let overlay_x = 0;
    let overlay_y = buf_h - overlay_h;

    if overlay_y < 0 {
        return;
    }

    canvas.blend_rect(overlay_x, overlay_y, overlay_w, overlay_h, bg_color);

    for (i, line) in lines.iter().enumerate() {
        let tx = overlay_x + padding;
        let ty = overlay_y + padding + (i as i32) * line_height;
        canvas.draw_text(
            tx,
            ty,
            line,
            font_name,
            font_size,
            false,
            false,
            text_color,
            tx,
            0,
            overlay_w - padding * 2,
            line_height,
            None,
        );
    }
}
