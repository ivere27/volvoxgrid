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
use crate::scrollbar::{
    compute_scrollbar_geometry, normalize_scrollbar_appearance, normalize_scrollbar_mode,
    scale_color_alpha, scrollbar_mode_visible, scrollbar_overlays_content,
};
use crate::selection::{hover_mode_has, HOVER_CELL, HOVER_COLUMN, HOVER_NONE, HOVER_ROW};
use crate::sort::{sort_order_is_ascending as sort_order_is_ascending_internal, SORT_NONE};
use crate::style::{CellStylePatch, HeaderMarkHeight, HighlightStyle, IconSlotStyle};
use std::collections::BTreeMap;
use std::sync::Arc;

#[cfg(not(target_arch = "wasm32"))]
use std::time::Instant as PortableInstant;
#[cfg(target_arch = "wasm32")]
use web_time::Instant as PortableInstant;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BorderEdge {
    Top,
    Right,
    Bottom,
    Left,
}

const LEGACY_BORDER_RAISED: i32 = 6;
const LEGACY_BORDER_INSET: i32 = 7;
const LEGACY_GRIDLINE_SOLID_HORIZONTAL: i32 = 4;
const LEGACY_GRIDLINE_SOLID_VERTICAL: i32 = 5;
const LEGACY_GRIDLINE_INSET_HORIZONTAL: i32 = 6;
const LEGACY_GRIDLINE_INSET_VERTICAL: i32 = 7;
const LEGACY_GRIDLINE_RAISED_HORIZONTAL: i32 = 8;
const LEGACY_GRIDLINE_RAISED_VERTICAL: i32 = 9;

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

    /// Fill a rounded rectangle with a solid color.
    fn fill_rounded_rect(&mut self, x: i32, y: i32, w: i32, h: i32, radius: i32, color: u32) {
        if w <= 0 || h <= 0 {
            return;
        }
        let r = radius.max(0).min(w / 2).min(h / 2);
        if r <= 0 {
            self.fill_rect(x, y, w, h, color);
            return;
        }
        let rf = r as f32;
        for row in 0..h {
            let dy = if row < r {
                (r - 1 - row) as f32 + 0.5
            } else if row >= h - r {
                (row - (h - r)) as f32 + 0.5
            } else {
                -1.0
            };
            let inset = if dy >= 0.0 {
                (rf - (rf * rf - dy * dy).max(0.0).sqrt()).ceil() as i32
            } else {
                0
            };
            let span_w = (w - inset * 2).max(0);
            if span_w > 0 {
                self.fill_rect(x + inset, y + row, span_w, 1, color);
            }
        }
    }

    /// Alpha-blend a rounded rectangle over existing content.
    fn blend_rounded_rect(&mut self, x: i32, y: i32, w: i32, h: i32, radius: i32, color: u32) {
        if w <= 0 || h <= 0 {
            return;
        }
        let r = radius.max(0).min(w / 2).min(h / 2);
        if r <= 0 {
            self.blend_rect(x, y, w, h, color);
            return;
        }
        let rf = r as f32;
        for row in 0..h {
            let dy = if row < r {
                (r - 1 - row) as f32 + 0.5
            } else if row >= h - r {
                (row - (h - r)) as f32 + 0.5
            } else {
                -1.0
            };
            let inset = if dy >= 0.0 {
                (rf - (rf * rf - dy * dy).max(0.0).sqrt()).ceil() as i32
            } else {
                0
            };
            let span_w = (w - inset * 2).max(0);
            if span_w > 0 {
                self.blend_rect(x + inset, y + row, span_w, 1, color);
            }
        }
    }

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

    /// Draw text when the caller does not need the rendered width.
    ///
    /// Backends can override this to avoid width bookkeeping in hot paths.
    fn draw_text_fast(
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
    ) {
        let _ = self.draw_text(
            x, y, text, font_name, font_size, bold, italic, color, clip_x, clip_y, clip_w, clip_h,
            max_width,
        );
    }

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

    /// Draw a single bitmap-font character (7x13 debug font) at the given
    /// scale.  Returns the advance width in pixels.
    ///
    /// The default implementation renders pixel-by-pixel via `set_pixel` /
    /// `fill_rect`.  GPU backends override this to emit a single textured
    /// quad from a pre-rasterised atlas, avoiding tens-of-thousands of tiny
    /// rect instances per overlay frame.
    fn draw_bitmap_char(&mut self, x: i32, y: i32, ch: u8, color: u32, scale: i32) -> i32 {
        use crate::debug_font;
        let idx = if ch >= 0x20 && ch <= 0x7E {
            (ch - 0x20) as usize
        } else {
            0
        };
        let glyph = &debug_font::FONT[idx];
        let s = scale;
        for row in 0..debug_font::GLYPH_H {
            let bits = glyph[row as usize];
            if bits == 0 {
                continue;
            }
            for col in 0..debug_font::GLYPH_W {
                if bits & (0x40 >> col) != 0 {
                    let px = x + col * s;
                    let py = y + row * s;
                    if s == 1 {
                        self.set_pixel(px, py, color);
                    } else {
                        self.fill_rect(px, py, s, s, color);
                    }
                }
            }
        }
        debug_font::CELL_W * s
    }

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
            b if b == LEGACY_BORDER_RAISED => self.rect_3d_color(x, y, w, h, color, true),
            b if b == LEGACY_BORDER_INSET => self.rect_3d_color(x, y, w, h, color, false),
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
            b if b == LEGACY_BORDER_RAISED || b == LEGACY_BORDER_INSET => {
                let light = lighten(color, 145);
                let dark = darken(color, 70);
                let edge_color = if b == LEGACY_BORDER_RAISED {
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

    /// Draw styled text when the caller does not need the rendered width.
    fn draw_text_styled_fast(
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
    ) {
        if text_style & 3 == 0 {
            self.draw_text_fast(
                x, y, text, font_name, font_size, bold, italic, color, clip_x, clip_y, clip_w,
                clip_h, max_width,
            );
        } else {
            let _ = self.draw_text_styled(
                x, y, text, font_name, font_size, bold, italic, color, clip_x, clip_y, clip_w,
                clip_h, text_style, max_width,
            );
        }
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
#[derive(Clone, Debug)]
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
    /// Data viewport origin X in canvas coordinates.
    pub data_x: i32,
    /// Data viewport origin Y in canvas coordinates.
    pub data_y: i32,
    /// Data viewport width in pixels.
    pub data_w: i32,
    /// Data viewport height in pixels.
    pub data_h: i32,
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

type MergeRange = (i32, i32, i32, i32);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
struct CellKey {
    row: i32,
    col: i32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct CellRect {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct DamageRect {
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
}

impl DamageRect {
    fn intersects(self, rect: CellRect) -> bool {
        rect.x + rect.w > self.x
            && rect.y + rect.h > self.y
            && rect.x < self.x + self.w
            && rect.y < self.y + self.h
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct DamageRegion {
    rects: [Option<DamageRect>; 4],
    scrolled_x: bool,
    scrolled_y: bool,
}

impl DamageRegion {
    pub(crate) fn push(&mut self, rect: DamageRect) {
        if rect.w <= 0 || rect.h <= 0 {
            return;
        }
        for slot in &mut self.rects {
            if slot.is_none() {
                *slot = Some(rect);
                return;
            }
        }
    }

    fn intersects(self, rect: CellRect) -> bool {
        self.rects
            .into_iter()
            .flatten()
            .any(|damage| damage.intersects(rect))
    }

    pub(crate) fn is_empty(self) -> bool {
        self.rects.iter().all(Option::is_none)
    }

    pub(crate) fn mark_scrolled_x(&mut self) {
        self.scrolled_x = true;
    }

    pub(crate) fn mark_scrolled_y(&mut self) {
        self.scrolled_y = true;
    }

    fn scrolled_x(self) -> bool {
        self.scrolled_x
    }

    fn scrolled_y(self) -> bool {
        self.scrolled_y
    }
}

impl Default for DamageRegion {
    fn default() -> Self {
        Self {
            rects: [None, None, None, None],
            scrolled_x: false,
            scrolled_y: false,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum VisibleCellZone {
    Scrollable,
    Sticky,
    Pinned,
    Fixed,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct VisibleCell {
    key: CellKey,
    rect: CellRect,
    zone: VisibleCellZone,
    merge: Option<MergeRange>,
    // Stable source cell for merged spans. This is the natural hook for a
    // future cross-frame cache keyed by cell content rather than viewport clip.
    source_key: CellKey,
}

impl VisibleCell {
    fn parts(self) -> (i32, i32, i32, i32, i32, i32) {
        (
            self.key.row,
            self.key.col,
            self.rect.x,
            self.rect.y,
            self.rect.w,
            self.rect.h,
        )
    }

    fn is_merged_span(self) -> bool {
        self.merge
            .map_or(false, |(r1, c1, r2, c2)| r1 != r2 || c1 != c2)
    }
}

#[derive(Clone, Debug)]
struct PreparedTextCell {
    source_key: CellKey,
    vis_rect: CellRect,
    orig_rect: CellRect,
    meta: Arc<crate::grid::TextCellStaticMeta>,
    is_merged: bool,
}

pub(crate) struct RenderContext {
    vp: VisibleRange,
    vis_cells: Vec<VisibleCell>,
    text_cells: Vec<PreparedTextCell>,
    zone_counts: [u32; 4],
    visible_row_rects: BTreeMap<i32, (i32, i32)>,
    visible_col_rects: BTreeMap<i32, (i32, i32)>,
}

impl VisibleRange {
    /// Compute fixed bands and the currently visible scrollable windows.
    pub fn compute(grid: &VolvoxGrid, vp_w: i32, vp_h: i32) -> Self {
        let fixed_row_end = (grid.fixed_rows + grid.frozen_rows).clamp(0, grid.rows);
        let fixed_col_end = (grid.fixed_cols + grid.frozen_cols).clamp(0, grid.cols);
        let indicator_start_w = grid.indicator_start_width().max(0);
        let indicator_end_w = grid.indicator_end_width().max(0);
        let indicator_top_h = grid.indicator_top_height().max(0);
        let indicator_bottom_h = grid.indicator_bottom_height().max(0);

        // Shrink the effective viewport when non-overlay scrollbars are visible so
        // pinned-bottom / sticky-bottom rows are placed above the horizontal
        // scrollbar (and pinned-right / sticky-right cols left of the vertical
        // scrollbar) rather than being partially obscured by them.
        let sb_size = grid.scrollbar_size.max(1);
        let overlay_scrollbars = scrollbar_overlays_content(grid.scrollbar_appearance);
        let mode_h = normalize_scrollbar_mode(grid.scrollbar_show_h);
        let mode_v = normalize_scrollbar_mode(grid.scrollbar_show_v);

        let fixed_height = grid.layout.row_pos(grid.fixed_rows);
        let fixed_width = grid.layout.col_pos(grid.fixed_cols);
        let pinned_height_total = grid.pinned_top_height() + grid.pinned_bottom_height();
        let pinned_width_total = grid.pinned_left_width() + grid.pinned_right_width();
        let mut show_h = mode_h == pb::ScrollBarMode::ScrollbarModeAlways as i32;
        let mut show_v = mode_v == pb::ScrollBarMode::ScrollbarModeAlways as i32;
        for _ in 0..3 {
            let vw = (vp_w
                - if show_v && !overlay_scrollbars {
                    sb_size
                } else {
                    0
                })
            .max(1);
            let vh = (vp_h
                - if show_h && !overlay_scrollbars {
                    sb_size
                } else {
                    0
                })
            .max(1);
            let data_vw = (vw - indicator_start_w - indicator_end_w).max(1);
            let data_vh = (vh - indicator_top_h - indicator_bottom_h).max(1);
            let mx = (grid.layout.total_width - data_vw + fixed_width + pinned_width_total).max(0);
            let my =
                (grid.layout.total_height - data_vh + fixed_height + pinned_height_total).max(0);
            let next_h = scrollbar_mode_visible(mode_h, mx > 0);
            let next_v = scrollbar_mode_visible(mode_v, my > 0);
            if next_h == show_h && next_v == show_v {
                break;
            }
            show_h = next_h;
            show_v = next_v;
        }
        let vp_w = if show_v && !overlay_scrollbars {
            (vp_w - sb_size).max(1)
        } else {
            vp_w
        };
        let vp_h = if show_h && !overlay_scrollbars {
            (vp_h - sb_size).max(1)
        } else {
            vp_h
        };
        let data_x = indicator_start_w;
        let data_y = indicator_top_h;
        let data_w = (vp_w - indicator_start_w - indicator_end_w).max(1);
        let data_h = (vp_h - indicator_top_h - indicator_bottom_h).max(1);

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
            let (first, last) = grid.layout.visible_rows(adj_scroll, data_h, fixed_row_end);
            if first <= last && first < grid.rows {
                scroll_row_start = (first - 1).max(fixed_row_end);
                scroll_row_end = (last + 2).min(grid.rows);
            }
        }

        let mut scroll_col_start = fixed_col_end;
        let mut scroll_col_end = fixed_col_end;
        if fixed_col_end < grid.cols && vp_w > 0 {
            let scrollable_w = (data_w - pinned_left_width - pinned_right_width).max(0);
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
        let scrollable_top = data_y + fixed_bottom + pinned_top_height;
        let scrollable_bottom = data_y + data_h - pinned_bottom_height;
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
        let mut threshold_left = data_x + fixed_right;
        for col in sticky_left_candidates {
            let screen_x = data_x + grid.layout.col_pos(col) - grid.scroll.scroll_x as i32;
            if screen_x < threshold_left {
                sticky_left_cols.push(col);
                threshold_left += grid.col_width(col);
            }
        }
        sticky_right_candidates.sort_unstable_by(|a, b| b.cmp(a));
        let mut sticky_right_cols = Vec::new();
        let mut threshold_right = data_x + data_w;
        for col in sticky_right_candidates {
            let screen_x = data_x + grid.layout.col_pos(col) - grid.scroll.scroll_x as i32;
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
            data_x,
            data_y,
            data_w,
            data_h,
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

impl RenderContext {
    fn new(grid: &VolvoxGrid, vp_w: i32, vp_h: i32, damage: Option<&DamageRegion>) -> Self {
        let vp = VisibleRange::compute(grid, vp_w, vp_h);
        let mut vis_cells: Vec<VisibleCell> = Vec::new();
        let zone_counts =
            iter_visible_cells(grid, &vp, damage, |zone, row, col, cx, cy, cw, ch| {
                let key = CellKey { row, col };
                let merge = grid.get_merged_range(row, col);
                let source_key = match merge {
                    Some((mr1, mc1, _mr2, _mc2)) => CellKey { row: mr1, col: mc1 },
                    None => key,
                };
                vis_cells.push(VisibleCell {
                    key,
                    rect: CellRect {
                        x: cx,
                        y: cy,
                        w: cw,
                        h: ch,
                    },
                    zone,
                    merge,
                    source_key,
                });
            });
        let visible_row_rects = build_visible_row_rects(grid, &vp);
        let visible_col_rects = build_visible_col_rects(grid, &vp);
        let text_cells = build_text_cells(grid, &vp, &vis_cells);
        Self {
            vp,
            vis_cells,
            text_cells,
            zone_counts,
            visible_row_rects,
            visible_col_rects,
        }
    }
}

// ===========================================================================
// Helper: iterate visible cells
// ===========================================================================

/// Call `f(zone, row, col, cell_x, cell_y, cell_w, cell_h)` for every visible cell
/// in the viewport. Fixed cells are always included regardless of scroll
/// offset. For merged cells the rectangle spans the full merge.
///
/// Render order (z-index bottom to top):
/// 1. Scrollable cells (normal, skipping pinned rows)
/// 2. Sticky overlay cells
/// 3. Pinned rows (top then bottom)
/// 4. Fixed/frozen cells (topmost)
///
/// Returns `[scrollable, sticky, pinned, fixed]` cell counts per zone.
fn should_emit_partial_cell(
    vp: &VisibleRange,
    damage: &DamageRegion,
    zone: VisibleCellZone,
    row: i32,
    col: i32,
    rect: CellRect,
) -> bool {
    let row_is_locked = row < vp.fixed_row_end
        || vp.pinned_top_rows.contains(&row)
        || vp.pinned_bottom_rows.contains(&row)
        || vp.sticky_top_rows.contains(&row)
        || vp.sticky_bottom_rows.contains(&row);
    let col_is_locked = col < vp.fixed_col_end
        || vp.sticky_left_cols.contains(&col)
        || vp.sticky_right_cols.contains(&col);

    if damage.scrolled_x() && row_is_locked && zone != VisibleCellZone::Scrollable {
        return true;
    }
    if damage.scrolled_x() && row < vp.fixed_row_end {
        return true;
    }
    if damage.scrolled_y() && col_is_locked && zone != VisibleCellZone::Scrollable {
        return true;
    }
    if damage.scrolled_y() && col < vp.fixed_col_end {
        return true;
    }

    damage.intersects(rect)
}

fn iter_visible_cells<F>(
    grid: &VolvoxGrid,
    vp: &VisibleRange,
    damage: Option<&DamageRegion>,
    mut f: F,
) -> [u32; 4]
where
    F: FnMut(VisibleCellZone, i32, i32, i32, i32, i32, i32),
{
    let mut zone_counts: [u32; 4] = [0; 4];
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
                    let rect = CellRect {
                        x: cx,
                        y: cy,
                        w: cw,
                        h: ch,
                    };
                    if damage.is_some_and(|region| {
                        !should_emit_partial_cell(
                            vp,
                            region,
                            VisibleCellZone::Scrollable,
                            row,
                            col,
                            rect,
                        )
                    }) {
                        continue;
                    }
                    zone_counts[0] += 1;
                    f(VisibleCellZone::Scrollable, row, col, cx, cy, cw, ch);
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
                    let rect = CellRect {
                        x: cx,
                        y: cy,
                        w: cw,
                        h: ch,
                    };
                    if damage.is_some_and(|region| {
                        !should_emit_partial_cell(
                            vp,
                            region,
                            VisibleCellZone::Sticky,
                            row,
                            col,
                            rect,
                        )
                    }) {
                        continue;
                    }
                    zone_counts[1] += 1;
                    f(VisibleCellZone::Sticky, row, col, cx, cy, cw, ch);
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
                    let rect = CellRect {
                        x: cx,
                        y: cy,
                        w: cw,
                        h: ch,
                    };
                    if damage.is_some_and(|region| {
                        !should_emit_partial_cell(
                            vp,
                            region,
                            VisibleCellZone::Sticky,
                            row,
                            col,
                            rect,
                        )
                    }) {
                        continue;
                    }
                    zone_counts[1] += 1;
                    f(VisibleCellZone::Sticky, row, col, cx, cy, cw, ch);
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
                    let rect = CellRect {
                        x: cx,
                        y: cy,
                        w: cw,
                        h: ch,
                    };
                    if damage.is_some_and(|region| {
                        !should_emit_partial_cell(
                            vp,
                            region,
                            VisibleCellZone::Pinned,
                            row,
                            col,
                            rect,
                        )
                    }) {
                        continue;
                    }
                    zone_counts[2] += 1;
                    f(VisibleCellZone::Pinned, row, col, cx, cy, cw, ch);
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
                    let rect = CellRect {
                        x: cx,
                        y: cy,
                        w: cw,
                        h: ch,
                    };
                    if damage.is_some_and(|region| {
                        !should_emit_partial_cell(
                            vp,
                            region,
                            VisibleCellZone::Fixed,
                            row,
                            col,
                            rect,
                        )
                    }) {
                        continue;
                    }
                    zone_counts[3] += 1;
                    f(VisibleCellZone::Fixed, row, col, cx, cy, cw, ch);
                }
            }
        }
    }

    zone_counts
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
            let mut pin_y = vp.data_y + fixed_bottom;
            for &r in &vp.pinned_top_rows {
                if r == row {
                    break;
                }
                pin_y += grid.row_height(r);
            }
            y = pin_y;
        } else {
            // Bottom-pinned: stack from bottom of viewport upward
            let mut pin_y = vp.data_y + vp.data_h - vp.pinned_bottom_height;
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
        x += vp.data_x;
        // Handle sticky cols for pinned rows
        if vp.sticky_left_cols.contains(&col) {
            let fixed_right = vp.data_x + grid.col_pos(grid.fixed_cols + grid.frozen_cols);
            x = fixed_right;
        } else if vp.sticky_right_cols.contains(&col) {
            x = vp.data_x + vp.data_w - w;
        } else if is_col_scrollable {
            // Clip scrollable cols against sticky area for pinned rows
            let clip_left =
                vp.data_x + grid.col_pos(grid.fixed_cols + grid.frozen_cols) + vp.sticky_left_width;
            if x < clip_left {
                let clip = clip_left - x;
                w -= clip;
                x = clip_left;
                if w <= 0 {
                    return None;
                }
            }
            let clip_right = vp.data_x + vp.data_w - vp.sticky_right_width;
            if x + w > clip_right {
                w = clip_right - x;
                if w <= 0 {
                    return None;
                }
            }
        }
        if grid.right_to_left {
            x = vp.data_x + vp.data_w - ((x - vp.data_x) + w);
        }
        if x + w <= vp.data_x
            || y + h <= vp.data_y
            || x >= vp.data_x + vp.data_w
            || y >= vp.data_y + vp.data_h
        {
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
    x += vp.data_x;
    y += vp.data_y;

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
            x += vp.data_x;
            y += vp.data_y;

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
        let mut sticky_y = vp.data_y + fixed_bottom + vp.pinned_top_height;
        for &sr in &vp.sticky_top_rows {
            if sr == row {
                break;
            }
            sticky_y += grid.row_height(sr);
        }
        y = sticky_y;
        h = grid.row_height(row); // reset h (merge may have changed it)
    } else if is_sticky_bottom_row {
        let mut sticky_y = vp.data_y + vp.data_h - vp.pinned_bottom_height;
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
        let fixed_right = vp.data_x + grid.col_pos(grid.fixed_cols + grid.frozen_cols);
        x = fixed_right;
        for &sc in &vp.sticky_left_cols {
            if sc == col {
                break;
            }
            x += grid.col_width(sc);
        }
        w = grid.col_width(col);
    } else if is_sticky_right_col {
        x = vp.data_x + vp.data_w - w;
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
        let clip_top = vp.data_y
            + grid.row_pos(grid.fixed_rows + grid.frozen_rows)
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
        let clip_bottom = vp.data_y + vp.data_h - vp.pinned_bottom_height - vp.sticky_bottom_height;
        if y + h > clip_bottom {
            h = clip_bottom - y;
            if h <= 0 {
                return None;
            }
        }
    }
    if is_col_scrollable && !is_sticky_col {
        let fixed_right =
            vp.data_x + grid.col_pos(grid.fixed_cols + grid.frozen_cols) + vp.sticky_left_width;
        if x < fixed_right {
            let clip = fixed_right - x;
            w -= clip;
            x = fixed_right;
            if w <= 0 {
                return None;
            }
        }
        let clip_right = vp.data_x + vp.data_w - vp.sticky_right_width;
        if x + w > clip_right {
            w = clip_right - x;
            if w <= 0 {
                return None;
            }
        }
    }

    if grid.extend_last_col && col == grid.cols - 1 && x < vp.data_x + vp.data_w {
        w = w.max(vp.data_x + vp.data_w - x);
    }

    if grid.right_to_left {
        x = vp.data_x + vp.data_w - ((x - vp.data_x) + w);
    }

    // Clip to viewport
    if x + w <= vp.data_x
        || y + h <= vp.data_y
        || x >= vp.data_x + vp.data_w
        || y >= vp.data_y + vp.data_h
    {
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
    let is_sticky_row = vp.sticky_top_rows.contains(&row) || vp.sticky_bottom_rows.contains(&row);
    let is_sticky_col = vp.sticky_left_cols.contains(&col) || vp.sticky_right_cols.contains(&col);

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
                let ox = grid.col_pos(mc1) - grid.scroll.scroll_x as i32 + vp.data_x;
                let ow: i32 = (mc1..=mc2).map(|c| grid.col_width(c)).sum();
                (ox, ow)
            } else {
                (cx, cw)
            };
            let (oy, oh) = if need_orig_y {
                let oy = grid.row_pos(mr1) - grid.scroll.scroll_y as i32
                    + vp.pinned_top_height
                    + vp.data_y;
                let oh: i32 = (mr1..=mr2).map(|r| grid.row_height(r)).sum();
                (oy, oh)
            } else {
                (cy, ch)
            };
            return (ox, oy, ow, oh);
        }
    }

    let (ox, ow) = if need_orig_x {
        let ox = grid.col_pos(col) - grid.scroll.scroll_x as i32 + vp.data_x;
        (ox, grid.col_width(col))
    } else {
        (cx, cw)
    };
    let (oy, oh) = if need_orig_y {
        let oy = grid.row_pos(row) - grid.scroll.scroll_y as i32 + vp.pinned_top_height + vp.data_y;
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

/// Parse progress percent from cell text. Handles "75%", "75", "0.75", "1".
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
        // Treat whole-number input as percentage points so editing a progress
        // cell to "1" produces 1% instead of a full bar. Fractional values
        // below 1.0 still work as ratios, e.g. "0.75" -> 75%.
        let pct = if is_percent || v >= 1.0 { v / 100.0 } else { v };
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
    style_override: &CellStylePatch,
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
fn should_show_dropdown_button_with_list(
    grid: &VolvoxGrid,
    row: i32,
    col: i32,
    has_dropdown_list: bool,
) -> bool {
    if !has_dropdown_list {
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

pub(crate) fn show_dropdown_button_for_cell(grid: &VolvoxGrid, row: i32, col: i32) -> bool {
    should_show_dropdown_button_with_list(
        grid,
        row,
        col,
        !grid.active_dropdown_list(row, col).is_empty(),
    )
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
// Render layer bitmask constants
// ===========================================================================

pub mod layer {
    pub const OVERLAY_BANDS: u32 = 0;
    pub const INDICATORS: u32 = 1;
    pub const BACKGROUNDS: u32 = 2;
    pub const PROGRESS_BARS: u32 = 3;
    pub const GRID_LINES: u32 = 4;
    pub const HEADER_MARKS: u32 = 5;
    pub const BACKGROUND_IMAGE: u32 = 6;
    pub const CELL_BORDERS: u32 = 7;
    pub const CELL_TEXT: u32 = 8;
    pub const CELL_PICTURES: u32 = 9;
    pub const SORT_GLYPHS: u32 = 10;
    pub const COL_DRAG_MARKER: u32 = 11;
    pub const CHECKBOXES: u32 = 12;
    pub const DROPDOWN_BUTTONS: u32 = 13;
    pub const SELECTION: u32 = 14;
    pub const HOVER_HIGHLIGHT: u32 = 15;
    pub const EDIT_HIGHLIGHTS: u32 = 16;
    pub const FOCUS_RECT: u32 = 17;
    pub const FILL_HANDLE: u32 = 18;
    pub const OUTLINE: u32 = 19;
    pub const FROZEN_BORDERS: u32 = 20;
    pub const ACTIVE_EDITOR: u32 = 21;
    pub const ACTIVE_DROPDOWN: u32 = 22;
    pub const SCROLL_BARS: u32 = 23;
    pub const FAST_SCROLL: u32 = 24;
    pub const DEBUG_OVERLAY: u32 = 25;

    pub const COUNT: usize = 26;
    pub const ALL: u64 = (1u64 << COUNT) - 1;

    pub const NAMES: [&str; COUNT] = [
        "bands",
        "indicators",
        "bkgrounds",
        "progress",
        "gridlines",
        "hdr_marks",
        "bg_image",
        "borders",
        "text",
        "pictures",
        "sort",
        "col_drag",
        "checkbox",
        "dropdown",
        "selection",
        "hover",
        "edit_hl",
        "focus",
        "fill_hnd",
        "outline",
        "frozen_bd",
        "editor",
        "dd_active",
        "scrollbar",
        "fast_scrl",
        "debug_ovl",
    ];
}

/// Return type from `render_grid`: dirty rect, per-layer times (us), zone cell counts.
pub type RenderResult = ((i32, i32, i32, i32), [f32; layer::COUNT], [u32; 4]);

// ===========================================================================
// render_grid -- main entry point
// ===========================================================================

/// Render the entire grid onto a Canvas. Returns dirty rect, layer times, and zone cell counts.
pub fn render_grid<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C) -> RenderResult {
    render_grid_internal(grid, canvas, None)
}

pub(crate) fn render_grid_partial<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    damage: &DamageRegion,
) -> RenderResult {
    render_grid_internal(grid, canvas, Some(damage))
}

fn clear_partial_regions<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    ctx: &RenderContext,
    damage: &DamageRegion,
) {
    let bg = grid.style.back_color_bkg;
    for rect in damage.rects.into_iter().flatten() {
        canvas.fill_rect(rect.x, rect.y, rect.w, rect.h, bg);
    }

    // Partially re-emitted cells can paint outside the exposed damage band
    // (for example, antialiased glyph coverage inside the rest of the cell).
    // Clear the full cell rects we are about to redraw to avoid stacking
    // alpha on top of preserved scrolled pixels.
    for cell in &ctx.vis_cells {
        canvas.fill_rect(cell.rect.x, cell.rect.y, cell.rect.w, cell.rect.h, bg);
    }

    if ctx.vp.data_y > 0 {
        canvas.fill_rect(0, 0, canvas.width(), ctx.vp.data_y, bg);
    }
    if ctx.vp.data_x > 0 {
        canvas.fill_rect(0, 0, ctx.vp.data_x, canvas.height(), bg);
    }
    let right_x = ctx.vp.data_x + ctx.vp.data_w;
    if right_x < canvas.width() {
        canvas.fill_rect(right_x, 0, canvas.width() - right_x, canvas.height(), bg);
    }
    let bottom_y = ctx.vp.data_y + ctx.vp.data_h;
    if bottom_y < canvas.height() {
        canvas.fill_rect(0, bottom_y, canvas.width(), canvas.height() - bottom_y, bg);
    }
}

fn render_grid_internal<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    damage: Option<&DamageRegion>,
) -> RenderResult {
    let w = canvas.width();
    let h = canvas.height();
    if w <= 0 || h <= 0 {
        return ((0, 0, 0, 0), [0.0; layer::COUNT], [0; 4]);
    }

    let mask = grid.render_layer_mask;
    let profiling = grid.layer_profiling;
    let mut times = [0.0f32; layer::COUNT];

    macro_rules! run_layer {
        ($bit:expr, $body:expr) => {
            if mask & (1u64 << $bit) != 0 {
                if profiling {
                    let t0 = PortableInstant::now();
                    $body;
                    times[$bit as usize] = t0.elapsed().as_secs_f32() * 1_000_000.0;
                } else {
                    $body;
                }
            }
        };
    }

    grid.span.clear_span_cache();

    let ctx = RenderContext::new(grid, w, h, damage);
    if let Some(damage) = damage {
        clear_partial_regions(grid, canvas, &ctx, damage);
    } else {
        canvas.clear(grid.style.back_color_bkg);
    }

    run_layer!(
        layer::OVERLAY_BANDS,
        render_overlay_bands(grid, canvas, &ctx)
    );
    run_layer!(
        layer::INDICATORS,
        render_indicator_surfaces(grid, canvas, &ctx)
    );
    run_layer!(layer::BACKGROUNDS, render_backgrounds(grid, canvas, &ctx));
    run_layer!(layer::SELECTION, render_selection(grid, canvas, &ctx));

    run_layer!(layer::PROGRESS_BARS, {
        if grid.style.progress_color != 0 || grid.columns.iter().any(|c| c.progress_color != 0) {
            render_progress_bars(grid, canvas, &ctx);
        }
    });

    run_layer!(layer::GRID_LINES, {
        if grid.style.grid_lines != pb::GridLineStyle::GridlineNone as i32
            || grid.style.grid_lines_fixed != pb::GridLineStyle::GridlineNone as i32
        {
            render_grid_lines(grid, canvas, &ctx);
        }
    });

    run_layer!(layer::HEADER_MARKS, render_header_marks(grid, canvas, &ctx));
    run_layer!(
        layer::BACKGROUND_IMAGE,
        render_background_image(grid, canvas)
    );

    run_layer!(layer::CELL_BORDERS, {
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
            render_cell_borders(grid, canvas, &ctx);
        }
    });

    run_layer!(layer::CELL_TEXT, render_cell_text(grid, canvas, &ctx));
    run_layer!(
        layer::CELL_PICTURES,
        render_cell_pictures(grid, canvas, &ctx)
    );
    run_layer!(layer::SORT_GLYPHS, render_sort_glyphs(grid, canvas, &ctx));
    run_layer!(
        layer::COL_DRAG_MARKER,
        render_col_drag_marker(grid, canvas, &ctx)
    );

    run_layer!(layer::CHECKBOXES, render_checkboxes(grid, canvas, &ctx));

    run_layer!(layer::DROPDOWN_BUTTONS, {
        if grid.dropdown_trigger != 0 && grid.columns.iter().any(|c| !c.dropdown_items.is_empty()) {
            render_dropdown_buttons(grid, canvas, &ctx);
        }
    });

    run_layer!(
        layer::HOVER_HIGHLIGHT,
        render_hover_highlight(grid, canvas, &ctx)
    );
    run_layer!(
        layer::EDIT_HIGHLIGHTS,
        render_edit_highlights(grid, canvas, &ctx)
    );
    run_layer!(layer::FOCUS_RECT, render_focus_rect(grid, canvas, &ctx));
    run_layer!(layer::FILL_HANDLE, render_fill_handle(grid, canvas, &ctx));
    run_layer!(layer::OUTLINE, render_outline(grid, canvas, &ctx));
    run_layer!(
        layer::FROZEN_BORDERS,
        render_frozen_borders(grid, canvas, &ctx)
    );
    canvas.begin_overlay();
    run_layer!(
        layer::ACTIVE_EDITOR,
        render_active_editor(grid, canvas, &ctx)
    );
    run_layer!(
        layer::ACTIVE_DROPDOWN,
        render_active_dropdown(grid, canvas, &ctx)
    );
    run_layer!(layer::SCROLL_BARS, render_scroll_bars(grid, canvas));
    run_layer!(layer::FAST_SCROLL, render_fast_scroll(grid, canvas));
    run_layer!(
        layer::DEBUG_OVERLAY,
        render_debug_overlay(grid, canvas, &ctx)
    );
    canvas.end_overlay();

    ((0, 0, w, h), times, ctx.zone_counts)
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

fn is_selection_layer_enabled(grid: &VolvoxGrid) -> bool {
    grid.render_layer_mask & (1u64 << layer::SELECTION) != 0
}

fn active_cell_origin(grid: &VolvoxGrid) -> Option<(i32, i32)> {
    if grid.rows <= 0 || grid.cols <= 0 {
        return None;
    }
    let row = grid.selection.row.clamp(0, grid.rows - 1);
    let col = grid.selection.col.clamp(0, grid.cols - 1);
    Some(match grid.get_merged_range(row, col) {
        Some((r1, c1, _, _)) => (r1, c1),
        None => (row, col),
    })
}

fn is_active_cell_origin(grid: &VolvoxGrid, row: i32, col: i32) -> bool {
    active_cell_origin(grid)
        .is_some_and(|(active_row, active_col)| row == active_row && col == active_col)
}

/// Whether a cell should be rendered with selection highlight (selection_style
/// back/fore colors). In listbox mode the current cursor row is always
/// highlighted regardless of the selection visibility setting.
fn should_highlight_cell(grid: &VolvoxGrid, row: i32, col: i32) -> bool {
    if !is_selection_layer_enabled(grid) {
        return false;
    }
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
    is_highlight_active(grid) && grid.is_cell_selected(row, col)
}

fn should_highlight_row_indicator(grid: &VolvoxGrid, row: i32) -> bool {
    if !is_selection_layer_enabled(grid) {
        return false;
    }
    if grid.selection.mode == pb::SelectionMode::SelectionListbox as i32 {
        if row == grid.selection.row {
            return true;
        }
        return is_highlight_active(grid) && grid.selection.selected_rows.contains(&row);
    }
    if !is_highlight_active(grid) {
        return false;
    }
    if grid.selection.mode == pb::SelectionMode::SelectionByColumn as i32 {
        return false;
    }
    grid.selection
        .all_ranges(grid.rows, grid.cols)
        .iter()
        .any(|&(row_lo, _, row_hi, _)| row >= row_lo && row <= row_hi)
}

fn should_highlight_col_indicator(grid: &VolvoxGrid, col: i32) -> bool {
    if !is_selection_layer_enabled(grid) {
        return false;
    }
    if !is_highlight_active(grid) {
        return false;
    }
    if grid.selection.mode == pb::SelectionMode::SelectionByRow as i32
        || grid.selection.mode == pb::SelectionMode::SelectionListbox as i32
    {
        return false;
    }
    grid.selection
        .all_ranges(grid.rows, grid.cols)
        .iter()
        .any(|&(_, col_lo, _, col_hi)| col >= col_lo && col <= col_hi)
}

fn span_has_highlighted_col(grid: &VolvoxGrid, col1: i32, col2: i32) -> bool {
    let start = col1.max(0);
    let end = col2.max(col1).min(grid.cols - 1);
    if start > end {
        return false;
    }
    (start..=end).any(|col| should_highlight_col_indicator(grid, col))
}

fn selection_back_color(grid: &VolvoxGrid) -> u32 {
    grid.selection
        .selection_style
        .back_color
        .unwrap_or(0xFF000080)
}

fn selection_fore_color(grid: &VolvoxGrid) -> u32 {
    grid.selection
        .selection_style
        .fore_color
        .unwrap_or(0xFFFFFFFF)
}

fn hover_matches_row(grid: &VolvoxGrid, row: i32) -> bool {
    hover_mode_has(grid.selection.hover_mode, HOVER_ROW)
        && grid.mouse_row >= 0
        && row == grid.mouse_row
}

fn hover_matches_column(grid: &VolvoxGrid, col: i32) -> bool {
    hover_mode_has(grid.selection.hover_mode, HOVER_COLUMN)
        && grid.mouse_col >= 0
        && col == grid.mouse_col
}

fn hover_matches_cell(grid: &VolvoxGrid, row: i32, col: i32) -> bool {
    hover_mode_has(grid.selection.hover_mode, HOVER_CELL)
        && grid.mouse_row >= 0
        && grid.mouse_col >= 0
        && row == grid.mouse_row
        && col == grid.mouse_col
}

fn draw_highlight_fill<C: Canvas>(
    canvas: &mut C,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    style: &HighlightStyle,
) {
    let Some(color) = style.back_color else {
        return;
    };
    if ((color >> 24) & 0xFF) == 0xFF {
        canvas.fill_rect(x, y, w, h, color);
    } else {
        canvas.blend_rect(x, y, w, h, color);
    }
}

// ===========================================================================
// Layer 0 -- Opaque bands for overlay rows (pinned + sticky)
// ===========================================================================

/// Fill full-width/height opaque background bands for pinned and sticky
/// overlay rows/columns.  This prevents scrolled content from showing
/// through between cell gaps.
fn render_overlay_bands<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    let bg = grid.style.back_color_bkg;
    let x0 = vp.data_x;
    let y0 = vp.data_y;
    let w = vp.data_w;
    let h = vp.data_h;

    // Pinned-top band
    if vp.pinned_top_height > 0 {
        let fixed_bottom = grid.row_pos(grid.fixed_rows + grid.frozen_rows);
        canvas.fill_rect(x0, y0 + fixed_bottom, w, vp.pinned_top_height, bg);
    }

    // Pinned-bottom band
    if vp.pinned_bottom_height > 0 {
        let y = y0 + h - vp.pinned_bottom_height;
        canvas.fill_rect(x0, y, w, vp.pinned_bottom_height, bg);
    }

    // Sticky-top row bands
    {
        let fixed_bottom = grid.row_pos(grid.fixed_rows + grid.frozen_rows);
        let mut y = y0 + fixed_bottom + vp.pinned_top_height;
        for &row in &vp.sticky_top_rows {
            let rh = grid.row_height(row);
            if rh > 0 {
                canvas.fill_rect(x0, y, w, rh, bg);
            }
            y += rh;
        }
    }

    // Sticky-bottom row bands
    {
        let mut y = y0 + h - vp.pinned_bottom_height;
        for &row in vp.sticky_bottom_rows.iter().rev() {
            let rh = grid.row_height(row);
            y -= rh;
            if rh > 0 {
                canvas.fill_rect(x0, y, w, rh, bg);
            }
        }
    }

    // Sticky-left column bands
    {
        let fixed_right = x0 + grid.col_pos(grid.fixed_cols + grid.frozen_cols);
        let mut x = fixed_right;
        for &col in &vp.sticky_left_cols {
            let cw = grid.col_width(col);
            if cw > 0 {
                canvas.fill_rect(x, y0, cw, h, bg);
            }
            x += cw;
        }
    }

    // Sticky-right column bands
    {
        let mut x = x0 + w;
        for &col in vp.sticky_right_cols.iter().rev() {
            let cw = grid.col_width(col);
            x -= cw;
            if cw > 0 {
                canvas.fill_rect(x, y0, cw, h, bg);
            }
        }
    }
}

fn insert_visible_row_rect(
    rows: &mut BTreeMap<i32, (i32, i32)>,
    row: i32,
    mut y: i32,
    mut h: i32,
    clip_top: i32,
    clip_bottom: i32,
) {
    if h <= 0 {
        return;
    }
    if y < clip_top {
        let clip = clip_top - y;
        y = clip_top;
        h -= clip;
    }
    if y + h > clip_bottom {
        h = clip_bottom - y;
    }
    if h > 0 {
        rows.insert(row, (y, h));
    }
}

fn build_visible_row_rects(grid: &VolvoxGrid, vp: &VisibleRange) -> BTreeMap<i32, (i32, i32)> {
    let mut rows = BTreeMap::new();
    let band_top = vp.data_y;
    let band_bottom = vp.data_y + vp.data_h;
    let fixed_bottom = grid.row_pos(vp.fixed_row_end);

    for row in 0..vp.fixed_row_end {
        if grid.is_row_hidden(row) {
            continue;
        }
        insert_visible_row_rect(
            &mut rows,
            row,
            vp.data_y + grid.row_pos(row),
            grid.row_height(row),
            band_top,
            band_bottom,
        );
    }

    let mut pinned_top_y = vp.data_y + fixed_bottom;
    for &row in &vp.pinned_top_rows {
        if grid.is_row_hidden(row) {
            continue;
        }
        let row_h = grid.row_height(row);
        insert_visible_row_rect(&mut rows, row, pinned_top_y, row_h, band_top, band_bottom);
        pinned_top_y += row_h;
    }

    let scroll_clip_top = vp.data_y + fixed_bottom + vp.pinned_top_height + vp.sticky_top_height;
    let scroll_clip_bottom =
        vp.data_y + vp.data_h - vp.pinned_bottom_height - vp.sticky_bottom_height;
    for row in vp.scroll_row_start..vp.scroll_row_end {
        if grid.is_row_hidden(row)
            || grid.is_row_pinned(row) != 0
            || vp.sticky_top_rows.contains(&row)
            || vp.sticky_bottom_rows.contains(&row)
        {
            continue;
        }
        insert_visible_row_rect(
            &mut rows,
            row,
            vp.data_y + grid.row_pos(row) - grid.scroll.scroll_y as i32 + vp.pinned_top_height,
            grid.row_height(row),
            scroll_clip_top,
            scroll_clip_bottom,
        );
    }

    let mut sticky_top_y = vp.data_y + fixed_bottom + vp.pinned_top_height;
    for &row in &vp.sticky_top_rows {
        if grid.is_row_hidden(row) {
            continue;
        }
        let row_h = grid.row_height(row);
        insert_visible_row_rect(&mut rows, row, sticky_top_y, row_h, band_top, band_bottom);
        sticky_top_y += row_h;
    }

    let mut sticky_bottom_y = vp.data_y + vp.data_h - vp.pinned_bottom_height;
    for &row in vp.sticky_bottom_rows.iter().rev() {
        if grid.is_row_hidden(row) {
            continue;
        }
        let row_h = grid.row_height(row);
        sticky_bottom_y -= row_h;
        insert_visible_row_rect(
            &mut rows,
            row,
            sticky_bottom_y,
            row_h,
            band_top,
            band_bottom,
        );
    }

    let mut pinned_bottom_y = vp.data_y + vp.data_h - vp.pinned_bottom_height;
    for &row in &vp.pinned_bottom_rows {
        if grid.is_row_hidden(row) {
            continue;
        }
        let row_h = grid.row_height(row);
        insert_visible_row_rect(
            &mut rows,
            row,
            pinned_bottom_y,
            row_h,
            band_top,
            band_bottom,
        );
        pinned_bottom_y += row_h;
    }

    rows
}

fn insert_visible_col_rect(
    cols: &mut BTreeMap<i32, (i32, i32)>,
    col: i32,
    mut x: i32,
    mut w: i32,
    clip_left: i32,
    clip_right: i32,
) {
    if w <= 0 {
        return;
    }
    if x < clip_left {
        let clip = clip_left - x;
        x = clip_left;
        w -= clip;
    }
    if x + w > clip_right {
        w = clip_right - x;
    }
    if w > 0 {
        cols.insert(col, (x, w));
    }
}

fn build_visible_col_rects(grid: &VolvoxGrid, vp: &VisibleRange) -> BTreeMap<i32, (i32, i32)> {
    let mut cols = BTreeMap::new();
    let band_left = vp.data_x;
    let band_right = vp.data_x + vp.data_w;
    let fixed_right = grid.col_pos(vp.fixed_col_end);

    for col in 0..vp.fixed_col_end {
        if grid.is_col_hidden(col) {
            continue;
        }
        insert_visible_col_rect(
            &mut cols,
            col,
            vp.data_x + grid.col_pos(col),
            grid.col_width(col),
            band_left,
            band_right,
        );
    }

    let scroll_clip_left = vp.data_x + fixed_right + vp.sticky_left_width;
    let scroll_clip_right = vp.data_x + vp.data_w - vp.sticky_right_width;
    for col in vp.scroll_col_start..vp.scroll_col_end {
        if grid.is_col_hidden(col)
            || vp.sticky_left_cols.contains(&col)
            || vp.sticky_right_cols.contains(&col)
        {
            continue;
        }
        insert_visible_col_rect(
            &mut cols,
            col,
            vp.data_x + grid.col_pos(col) - grid.scroll.scroll_x as i32,
            grid.col_width(col),
            scroll_clip_left,
            scroll_clip_right,
        );
    }

    let mut sticky_left_x = vp.data_x + fixed_right;
    for &col in &vp.sticky_left_cols {
        if grid.is_col_hidden(col) {
            continue;
        }
        let col_w = grid.col_width(col);
        insert_visible_col_rect(&mut cols, col, sticky_left_x, col_w, band_left, band_right);
        sticky_left_x += col_w;
    }

    let mut sticky_right_x = vp.data_x + vp.data_w - vp.sticky_right_width;
    for &col in &vp.sticky_right_cols {
        if grid.is_col_hidden(col) {
            continue;
        }
        let col_w = grid.col_width(col);
        insert_visible_col_rect(&mut cols, col, sticky_right_x, col_w, band_left, band_right);
        sticky_right_x += col_w;
    }

    if grid.right_to_left {
        let mut rtl_cols = BTreeMap::new();
        for (col, (x, w)) in cols {
            rtl_cols.insert(col, (vp.data_x + vp.data_w - ((x - vp.data_x) + w), w));
        }
        rtl_cols
    } else {
        cols
    }
}

fn build_text_cells(
    grid: &VolvoxGrid,
    vp: &VisibleRange,
    vis_cells: &[VisibleCell],
) -> Vec<PreparedTextCell> {
    let mut text_cells = Vec::new();
    let mut prepared_sources: std::collections::HashSet<CellKey> = std::collections::HashSet::new();

    for &cell in vis_cells {
        if !prepared_sources.insert(cell.source_key) {
            continue;
        }

        let text_row = cell.source_key.row;
        let text_col = cell.source_key.col;
        let vis_rect = if cell.is_merged_span() {
            let vx = cell.rect.x.max(vp.data_x);
            let vy = cell.rect.y.max(vp.data_y);
            let vw = ((cell.rect.x + cell.rect.w).min(vp.data_x + vp.data_w) - vx).max(1);
            let vh = ((cell.rect.y + cell.rect.h).min(vp.data_y + vp.data_h) - vy).max(1);
            CellRect {
                x: vx,
                y: vy,
                w: vw,
                h: vh,
            }
        } else {
            cell.rect
        };
        let orig_rect = if cell.is_merged_span() {
            vis_rect
        } else {
            let (x, y, w, h) = original_cell_bounds(
                grid, text_row, text_col, vis_rect.x, vis_rect.y, vis_rect.w, vis_rect.h, vp,
            );
            CellRect { x, y, w, h }
        };

        let meta = grid.build_text_cell_static_meta(text_row, text_col);
        if meta.suppress_text || meta.display_text.is_empty() {
            continue;
        }

        text_cells.push(PreparedTextCell {
            source_key: cell.source_key,
            vis_rect,
            orig_rect,
            meta,
            is_merged: cell.is_merged_span(),
        });
    }

    text_cells
}

fn build_indicator_row_offsets(
    band: &crate::indicator::ColIndicatorState,
    band_y: i32,
) -> Vec<(i32, i32, i32)> {
    let row_count = band.row_count().max(1);
    let mut row_offsets = Vec::new();
    let mut y = band_y;
    for row in 0..row_count {
        let h = band.row_height_px(row).max(1);
        row_offsets.push((row, y, h));
        y += h;
    }
    row_offsets
}

fn indicator_span_x(cols: &BTreeMap<i32, (i32, i32)>, col1: i32, col2: i32) -> Option<(i32, i32)> {
    let mut left = i32::MAX;
    let mut right = i32::MIN;
    for col in col1.min(col2)..=col1.max(col2) {
        if let Some(&(x, w)) = cols.get(&col) {
            left = left.min(x);
            right = right.max(x + w);
        }
    }
    if left == i32::MAX || right <= left {
        None
    } else {
        Some((left, right - left))
    }
}

fn indicator_cell_range(
    band: &crate::indicator::ColIndicatorState,
    row: i32,
    col: i32,
) -> (i32, i32, i32, i32) {
    for cell in &band.cells {
        let row1 = cell.row1.min(cell.row2).max(0);
        let row2 = cell.row1.max(cell.row2).max(0);
        let col1 = cell.col1.min(cell.col2).max(0);
        let col2 = cell.col1.max(cell.col2).max(0);
        if row >= row1 && row <= row2 && col >= col1 && col <= col2 {
            return (row1, col1, row2, col2);
        }
    }
    (row, col, row, col)
}

fn indicator_slots_share_cell(
    band: &crate::indicator::ColIndicatorState,
    row_a: i32,
    col_a: i32,
    row_b: i32,
    col_b: i32,
) -> bool {
    indicator_cell_range(band, row_a, col_a) == indicator_cell_range(band, row_b, col_b)
}

fn indicator_draws_vertical_grid_lines(band: &crate::indicator::ColIndicatorState) -> bool {
    let mode = band
        .grid_lines
        .unwrap_or(pb::GridLineStyle::GridlineNone as i32);
    mode == pb::GridLineStyle::GridlineSolid as i32
        || mode == pb::GridLineStyle::GridlineInset as i32
        || mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == LEGACY_GRIDLINE_SOLID_VERTICAL
        || mode == LEGACY_GRIDLINE_INSET_VERTICAL
        || mode == LEGACY_GRIDLINE_RAISED_VERTICAL
}

fn indicator_cell_rect_for_col(
    band: &crate::indicator::ColIndicatorState,
    row_offsets: &[(i32, i32, i32)],
    col_rects: &BTreeMap<i32, (i32, i32)>,
    col: i32,
) -> Option<(i32, i32, i32, i32)> {
    let mut best: Option<(i32, i32, i32, i32, i32, i32)> = None;
    for cell in &band.cells {
        let col1 = cell.col1.min(cell.col2).max(0);
        let col2 = cell.col1.max(cell.col2).max(0);
        if col < col1 || col > col2 {
            continue;
        }
        let row1 = cell.row1.min(cell.row2).max(0);
        let row2 = cell.row1.max(cell.row2).max(0);
        let col_span = col2 - col1;
        let row_span = row2 - row1;
        match best {
            None => best = Some((row1, row2, col1, col2, col_span, row_span)),
            Some((best_row1, best_row2, best_col1, best_col2, best_col_span, best_row_span)) => {
                let replace = col_span < best_col_span
                    || (col_span == best_col_span && row_span < best_row_span)
                    || (col_span == best_col_span && row_span == best_row_span && row2 > best_row2)
                    || (col_span == best_col_span
                        && row_span == best_row_span
                        && row2 == best_row2
                        && col1 == col2
                        && best_col1 != best_col2)
                    || (col_span == best_col_span
                        && row_span == best_row_span
                        && row2 == best_row2
                        && row1 > best_row1);
                if replace {
                    best = Some((row1, row2, col1, col2, col_span, row_span));
                }
            }
        }
    }

    if let Some((row1, row2, col1, col2, _, _)) = best {
        let (cx, cw) = indicator_span_x(col_rects, col1, col2)?;
        let start = row1 as usize;
        let end = row2 as usize;
        if start >= row_offsets.len() || end >= row_offsets.len() {
            return None;
        }
        let cy = row_offsets[start].1;
        let ch = row_offsets[start..=end].iter().map(|(_, _, h)| *h).sum();
        return Some((cx, cy, cw, ch));
    }

    let (cx, cw) = col_rects.get(&col).copied()?;
    let (_row_idx, row_y, row_h) = *row_offsets.last()?;
    Some((cx, row_y, cw, row_h))
}

fn column_header_text(grid: &VolvoxGrid, col: i32) -> String {
    if col < 0 || (col as usize) >= grid.columns.len() {
        return String::new();
    }
    let cp = &grid.columns[col as usize];
    if !cp.caption.trim().is_empty() {
        return cp.caption.clone();
    }
    if !cp.key.trim().is_empty() {
        return cp.key.clone();
    }
    if grid.fixed_rows > 0 {
        let legacy = grid.get_display_text(0, col);
        if !legacy.trim().is_empty() {
            return legacy;
        }
    }
    String::new()
}

fn indicator_fore_color(color: Option<u32>, fallback: u32) -> u32 {
    color.unwrap_or(fallback)
}

fn indicator_back_color(color: Option<u32>, fallback: u32) -> u32 {
    color.unwrap_or(fallback)
}

fn draw_indicator_text<C: Canvas>(
    canvas: &mut C,
    grid: &VolvoxGrid,
    text: &str,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    halign: i32,
    color: u32,
) {
    if text.trim().is_empty() || w <= 2 || h <= 2 {
        return;
    }
    let font_size = grid.style.font_size;
    let font_name = &grid.style.font_name;
    let (tw, th) = canvas.measure_text(text, font_name, font_size, false, false, None);
    let text_w = tw.ceil() as i32;
    let text_h = th.ceil() as i32;
    let tx = match halign {
        1 => x + (w - text_w) / 2,
        2 => x + w - text_w - 4,
        _ => x + 4,
    }
    .clamp(x + 1, (x + w - text_w - 1).max(x + 1));
    let ty = (y + (h - text_h) / 2).clamp(y + 1, (y + h - text_h - 1).max(y + 1));
    canvas.draw_text_styled_fast(
        tx, ty, text, font_name, font_size, false, false, color, x, y, w, h, 0, None,
    );
}

fn sort_arrow_box_size(cell_h: i32) -> i32 {
    cell_h.saturating_sub(6).clamp(8, 16)
}

fn draw_sort_direction_arrow<C: Canvas>(
    canvas: &mut C,
    x: i32,
    y: i32,
    size: i32,
    ascending: bool,
    color: u32,
) {
    if size < 6 {
        return;
    }
    if ascending {
        canvas.draw_scroll_arrow_up(x, y, size, size, color);
    } else {
        canvas.draw_scroll_arrow_down(x, y, size, size, color);
    }
}

fn draw_indicator_checkbox<C: Canvas>(
    canvas: &mut C,
    rect: (i32, i32, i32, i32),
    checked: bool,
    fore_color: u32,
) {
    let (x, y, w, h) = rect;
    let box_size = 13.min((w - 4).max(0)).min((h - 4).max(0));
    if box_size <= 4 {
        return;
    }
    let bx = x + (w - box_size) / 2;
    let by = y + (h - box_size) / 2;
    canvas.rect_outline(bx, by, box_size, box_size, 0xFF707070);
    canvas.fill_rect(bx + 1, by + 1, box_size - 2, box_size - 2, 0xFFFFFFFF);
    if checked {
        let mark_y = by + box_size / 2;
        canvas.hline(bx + 3, mark_y, (box_size - 6).max(2), fore_color);
    }
}

fn render_row_indicator_slot<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    row: i32,
    rect: (i32, i32, i32, i32),
    kind: i32,
    fore_color: u32,
) {
    let slot_kind = kind;
    if slot_kind == pb::RowIndicatorSlotKind::RowIndicatorSlotNumbers as i32 {
        let label = (row - grid.fixed_rows + 1).max(1).to_string();
        draw_indicator_text(
            canvas, grid, &label, rect.0, rect.1, rect.2, rect.3, 1, fore_color,
        );
        return;
    }
    if slot_kind == pb::RowIndicatorSlotKind::RowIndicatorSlotCurrent as i32 {
        if row == grid.selection.row {
            draw_indicator_text(
                canvas, grid, "▶", rect.0, rect.1, rect.2, rect.3, 1, fore_color,
            );
        }
        return;
    }
    if slot_kind == pb::RowIndicatorSlotKind::RowIndicatorSlotSelection as i32 {
        let selected = should_highlight_row_indicator(grid, row);
        if selected {
            draw_indicator_text(
                canvas, grid, "•", rect.0, rect.1, rect.2, rect.3, 1, fore_color,
            );
        }
        return;
    }
    if slot_kind == pb::RowIndicatorSlotKind::RowIndicatorSlotCheckbox as i32 {
        let checked = should_highlight_row_indicator(grid, row);
        draw_indicator_checkbox(canvas, rect, checked, fore_color);
        return;
    }
    if slot_kind == pb::RowIndicatorSlotKind::RowIndicatorSlotHandle as i32 {
        draw_indicator_text(
            canvas, grid, "≡", rect.0, rect.1, rect.2, rect.3, 1, fore_color,
        );
        return;
    }
    if slot_kind == pb::RowIndicatorSlotKind::RowIndicatorSlotEditing as i32 {
        if grid.edit.is_active() && grid.edit.edit_row == row {
            draw_indicator_text(
                canvas, grid, "✎", rect.0, rect.1, rect.2, rect.3, 1, fore_color,
            );
        }
        return;
    }
    if slot_kind == pb::RowIndicatorSlotKind::RowIndicatorSlotExpander as i32 {
        if let Some(rp) = grid.get_row_props(row) {
            let glyph = if rp.is_collapsed { "+" } else { "-" };
            draw_indicator_text(
                canvas, grid, glyph, rect.0, rect.1, rect.2, rect.3, 1, fore_color,
            );
        }
        return;
    }
}

fn render_row_indicator_start<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    let band = &grid.indicator_bands.row_start;
    if !band.visible || vp.data_x <= 0 || vp.data_h <= 0 {
        return;
    }

    let back_color = indicator_back_color(band.back_color, grid.style.back_color_fixed);
    let fore_color = indicator_fore_color(band.fore_color, grid.style.fore_color_fixed);
    let grid_color = band.grid_color.unwrap_or(grid.style.grid_color_fixed);
    let band_x = 0;
    let band_y = vp.data_y;
    let band_w = vp.data_x;
    let band_h = vp.data_h;
    canvas.fill_rect(band_x, band_y, band_w, band_h, back_color);

    for (&row, &(cy, ch)) in &ctx.visible_row_rects {
        let is_selected = should_highlight_row_indicator(grid, row);
        if is_selected {
            if let Some(ind_style) = &grid.selection.indicator_row_style {
                draw_highlight_fill(canvas, band_x, cy, band_w, ch, ind_style);
                draw_highlight_border(canvas, band_x, cy, band_w, ch, ind_style, 0);
            } else {
                canvas.fill_rect(band_x, cy, band_w, ch, selection_back_color(grid));
            }
        } else if hover_matches_row(grid, row) {
            draw_highlight_fill(
                canvas,
                band_x,
                cy,
                band_w,
                ch,
                &grid.selection.hover_row_style,
            );
        }
        let row_fore_color = if is_selected {
            if let Some(ind_style) = &grid.selection.indicator_row_style {
                ind_style.fore_color.unwrap_or(fore_color)
            } else {
                selection_fore_color(grid)
            }
        } else {
            fore_color
        };
        if !band.slots.is_empty() {
            let mut slot_x = band_x;
            for slot in band.slots.iter().filter(|slot| slot.visible) {
                let remaining = (band_x + band_w - slot_x).max(0);
                if remaining <= 0 {
                    break;
                }
                let slot_w = slot.width_px.max(1).min(remaining);
                render_row_indicator_slot(
                    grid,
                    canvas,
                    row,
                    (slot_x, cy, slot_w, ch),
                    slot.kind,
                    row_fore_color,
                );
                slot_x += slot_w;
            }
        } else {
            let composite_rect = (band_x, cy, band_w, ch);
            if band.has_mode(pb::RowIndicatorMode::RowIndicatorNumbers) {
                render_row_indicator_slot(
                    grid,
                    canvas,
                    row,
                    composite_rect,
                    pb::RowIndicatorSlotKind::RowIndicatorSlotNumbers as i32,
                    row_fore_color,
                );
            } else if band.has_mode(pb::RowIndicatorMode::RowIndicatorCurrent)
                && row == grid.selection.row
            {
                render_row_indicator_slot(
                    grid,
                    canvas,
                    row,
                    composite_rect,
                    pb::RowIndicatorSlotKind::RowIndicatorSlotCurrent as i32,
                    row_fore_color,
                );
            } else if band.has_mode(pb::RowIndicatorMode::RowIndicatorSelection) {
                render_row_indicator_slot(
                    grid,
                    canvas,
                    row,
                    composite_rect,
                    pb::RowIndicatorSlotKind::RowIndicatorSlotSelection as i32,
                    row_fore_color,
                );
            }
            if band.has_mode(pb::RowIndicatorMode::RowIndicatorCheckbox) {
                render_row_indicator_slot(
                    grid,
                    canvas,
                    row,
                    composite_rect,
                    pb::RowIndicatorSlotKind::RowIndicatorSlotCheckbox as i32,
                    row_fore_color,
                );
            }
            if band.has_mode(pb::RowIndicatorMode::RowIndicatorEditing) {
                render_row_indicator_slot(
                    grid,
                    canvas,
                    row,
                    composite_rect,
                    pb::RowIndicatorSlotKind::RowIndicatorSlotEditing as i32,
                    row_fore_color,
                );
            }
        }
    }
    for &(cy, ch) in ctx.visible_row_rects.values() {
        canvas.hline(band_x, cy + ch - 1, band_w, grid_color);
    }
    canvas.vline(band_x + band_w - 1, band_y, band_h, grid_color);
}

fn render_col_indicator_top<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    let band = &grid.indicator_bands.col_top;
    if !band.visible || vp.data_y <= 0 || vp.data_w <= 0 {
        return;
    }

    let back_color = indicator_back_color(band.back_color, grid.style.back_color_fixed);
    let fore_color = indicator_fore_color(band.fore_color, grid.style.fore_color_fixed);
    let grid_color = band.grid_color.unwrap_or(grid.style.grid_color_fixed);
    let band_x = vp.data_x;
    let band_y = 0;
    let band_w = vp.data_w;
    let band_h = vp.data_y;
    canvas.fill_rect(band_x, band_y, band_w, band_h, back_color);

    let col_rects = &ctx.visible_col_rects;
    for (&col, &(cx, cw)) in col_rects {
        if should_highlight_col_indicator(grid, col) {
            if let Some(ind_style) = &grid.selection.indicator_col_style {
                draw_highlight_fill(canvas, cx, band_y, cw, band_h, ind_style);
                draw_highlight_border(canvas, cx, band_y, cw, band_h, ind_style, 0);
            } else {
                canvas.fill_rect(cx, band_y, cw, band_h, selection_back_color(grid));
            }
        } else if hover_matches_column(grid, col) {
            draw_highlight_fill(
                canvas,
                cx,
                band_y,
                cw,
                band_h,
                &grid.selection.hover_column_style,
            );
        }
    }
    let row_offsets = build_indicator_row_offsets(band, band_y);

    let auto_headers = band.cells.is_empty()
        && band.has_mode(pb::ColIndicatorCellMode::ColIndicatorCellHeaderText);
    if auto_headers {
        for col in 0..grid.cols {
            let Some((cx, cw)) = col_rects.get(&col).copied() else {
                continue;
            };
            let text = column_header_text(grid, col);
            if text.is_empty() {
                continue;
            }
            let (_row_idx, row_y, row_h) = row_offsets[0];
            let text_color = if should_highlight_col_indicator(grid, col) {
                if let Some(ind_style) = &grid.selection.indicator_col_style {
                    ind_style.fore_color.unwrap_or(fore_color)
                } else {
                    selection_fore_color(grid)
                }
            } else {
                fore_color
            };
            draw_indicator_text(canvas, grid, &text, cx, row_y, cw, row_h, 1, text_color);
        }
    }

    for cell in &band.cells {
        let Some((cx, cw)) = indicator_span_x(col_rects, cell.col1, cell.col2) else {
            continue;
        };
        let row1 = cell.row1.max(0) as usize;
        let row2 = cell.row2.max(cell.row1).max(0) as usize;
        if row1 >= row_offsets.len() || row2 >= row_offsets.len() {
            continue;
        }
        let cy = row_offsets[row1].1;
        let ch = row_offsets[row1..=row2].iter().map(|(_, _, h)| *h).sum();
        let mode_bits = if cell.mode_bits != 0 {
            cell.mode_bits
        } else {
            band.mode_bits
        };
        let text = if !cell.text.trim().is_empty() {
            cell.text.clone()
        } else if cell.col1 == cell.col2
            && (mode_bits & (pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32) != 0)
        {
            column_header_text(grid, cell.col1)
        } else {
            String::new()
        };
        if !text.is_empty() {
            let text_color = if span_has_highlighted_col(grid, cell.col1, cell.col2) {
                if let Some(ind_style) = &grid.selection.indicator_col_style {
                    ind_style.fore_color.unwrap_or(fore_color)
                } else {
                    selection_fore_color(grid)
                }
            } else {
                fore_color
            };
            draw_indicator_text(canvas, grid, &text, cx, cy, cw, ch, 1, text_color);
        }
    }

    if band.has_mode(pb::ColIndicatorCellMode::ColIndicatorCellSortGlyph)
        && grid.header_features & 1 != 0
    {
        let sort_targets = if grid.sort_state.sort_keys.is_empty() {
            (0..grid.cols)
                .filter_map(|col| {
                    grid.get_col_props(col).and_then(|cp| {
                        if cp.sort_defined {
                            Some((col, cp.sort_order))
                        } else {
                            None
                        }
                    })
                })
                .collect::<Vec<_>>()
        } else {
            grid.sort_state.sort_keys.clone()
        };
        for (sort_idx, (sort_col, sort_order)) in sort_targets.iter().enumerate() {
            let Some((cx, cy, cw, ch)) =
                indicator_cell_rect_for_col(band, &row_offsets, &col_rects, *sort_col)
            else {
                continue;
            };
            let sort_fore_color = if should_highlight_col_indicator(grid, *sort_col) {
                if let Some(ind_style) = &grid.selection.indicator_col_style {
                    ind_style.fore_color.unwrap_or(fore_color)
                } else {
                    selection_fore_color(grid)
                }
            } else {
                fore_color
            };
            let glyph = if *sort_order == SORT_NONE {
                continue;
            } else if sort_order_is_ascending(*sort_order) {
                true
            } else {
                false
            };
            let glyph_box = sort_arrow_box_size(ch).min((cw - 4).max(0));
            if glyph_box < 6 {
                continue;
            }
            let glyph_x = (cx + cw - glyph_box - 4).max(cx + 2);
            let glyph_y = cy + ((ch - glyph_box).max(0) / 2);
            draw_sort_direction_arrow(canvas, glyph_x, glyph_y, glyph_box, glyph, sort_fore_color);
            if grid.style.show_sort_numbers && sort_targets.len() > 1 {
                let label = format!("{}", sort_idx + 1);
                let num_font_size = ((grid.style.font_size - 1.0).max(8.0) * 0.8).max(7.0);
                let (nw, nh) = canvas.measure_text(
                    &label,
                    &grid.style.font_name,
                    num_font_size,
                    false,
                    false,
                    None,
                );
                let num_w = nw.ceil() as i32;
                let num_h = nh.ceil() as i32;
                let num_x = (glyph_x - num_w - 2).max(cx + 2);
                let num_y = cy + (ch - num_h) / 2;
                canvas.draw_text_styled_fast(
                    num_x,
                    num_y,
                    &label,
                    &grid.style.font_name,
                    num_font_size,
                    false,
                    false,
                    sort_fore_color,
                    cx,
                    cy,
                    cw,
                    ch,
                    0,
                    None,
                );
            }
        }
    }

    for row_idx in 0..row_offsets.len().saturating_sub(1) {
        let row = row_offsets[row_idx].0;
        let next_row = row_offsets[row_idx + 1].0;
        let boundary_y = row_offsets[row_idx].1 + row_offsets[row_idx].2 - 1;
        for (&col, &(cx, cw)) in col_rects {
            if indicator_slots_share_cell(band, row, col, next_row, col) {
                continue;
            }
            canvas.hline(cx, boundary_y, cw, grid_color);
        }
    }
    if let Some((_row, cy, ch)) = row_offsets.last() {
        canvas.hline(band_x, *cy + *ch - 1, band_w, grid_color);
    }

    if indicator_draws_vertical_grid_lines(band) {
        let visible_cols = col_rects
            .iter()
            .map(|(&col, &(cx, cw))| (col, cx, cw))
            .collect::<Vec<_>>();
        for pair in visible_cols.windows(2) {
            let (left_col, left_x, left_w) = pair[0];
            let (right_col, _right_x, _right_w) = pair[1];
            let boundary_x = left_x + left_w - 1;
            for (row, cy, ch) in &row_offsets {
                if indicator_slots_share_cell(band, *row, left_col, *row, right_col) {
                    continue;
                }
                canvas.vline(boundary_x, *cy, *ch, grid_color);
            }
        }
        if let Some((_, cx, cw)) = visible_cols.last() {
            canvas.vline(*cx + *cw - 1, band_y, band_h, grid_color);
        }
    }
}

fn render_corner_top_start<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    if vp.data_x <= 0 || vp.data_y <= 0 {
        return;
    }
    let corner = &grid.indicator_bands.corner_top_start;
    let col_top = &grid.indicator_bands.col_top;
    let back_color = indicator_back_color(
        corner.back_color,
        indicator_back_color(col_top.back_color, grid.style.back_color_fixed),
    );
    let fore_color = indicator_fore_color(corner.fore_color, grid.style.fore_color_fixed);
    let grid_color = col_top
        .grid_color
        .or(grid.indicator_bands.row_start.grid_color)
        .unwrap_or(grid.style.grid_color_fixed);
    canvas.fill_rect(0, 0, vp.data_x, vp.data_y, back_color);
    if corner.visible && grid.selection.allow_selection {
        draw_indicator_text(canvas, grid, "▣", 0, 0, vp.data_x, vp.data_y, 1, fore_color);
    }

    let row_count = col_top.row_count().max(1);
    let mut y = 0;
    for row in 0..row_count {
        y += col_top.row_height_px(row).max(1);
        let line_y = y - 1;
        if line_y >= vp.data_y {
            break;
        }
        canvas.hline(0, line_y, vp.data_x, grid_color);
    }
    canvas.vline(vp.data_x - 1, 0, vp.data_y, grid_color);
}

fn render_indicator_surfaces<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    render_col_indicator_top(grid, canvas, ctx);
    render_row_indicator_start(grid, canvas, ctx);
    render_corner_top_start(grid, canvas, ctx);
}

// ===========================================================================
// Layer 1 -- Cell backgrounds
// ===========================================================================

fn render_backgrounds<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    // Track which merged ranges have already been rendered so each
    // merge is drawn exactly once, avoiding expensive overdraw in CPU mode.
    let mut rendered_merges: std::collections::HashSet<(i32, i32, i32, i32)> =
        std::collections::HashSet::new();

    for &cell in &ctx.vis_cells {
        let (row, col, cx, cy, cw, ch) = cell.parts();
        // For merged/spanned cells, always resolve style from the anchor
        // cell (top-left of the merge).  This prevents "blinking" when a
        // merged cell spans both sticky and non-sticky columns: without
        // this, the last-drawn column's style wins, and the winner changes
        // depending on whether the sticky threshold is crossed.
        let (style_row, style_col) = match cell.merge {
            Some((mr1, mc1, mr2, mc2)) if cell.is_merged_span() => {
                let merge_key = (mr1, mc1, mr2, mc2);
                if !rendered_merges.insert(merge_key) {
                    continue;
                }
                (mr1, mc1)
            }
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
            false,
            is_alternate,
            selection_back_color(grid),
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

        // Hover overlays are layered after base/selection backgrounds so row/column/cell
        // hover emphasis can stack (row -> column -> cell). Keep selected cells stable.
        if !is_selected && style_row >= grid.fixed_rows && style_col >= grid.fixed_cols {
            if hover_matches_row(grid, style_row) {
                draw_highlight_fill(canvas, cx, cy, cw, ch, &grid.selection.hover_row_style);
            }
            if hover_matches_column(grid, style_col) {
                draw_highlight_fill(canvas, cx, cy, cw, ch, &grid.selection.hover_column_style);
            }
            if hover_matches_cell(grid, style_row, style_col) {
                draw_highlight_fill(canvas, cx, cy, cw, ch, &grid.selection.hover_cell_style);
            }
        }
    }
}

// ===========================================================================
// Layer 2 -- Progress bars (data-bar rendering)
// ===========================================================================

fn render_progress_bars<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    for &cell in &ctx.vis_cells {
        let (row, col, cx, cy, cw, ch) = cell.parts();
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
            let (orig_x, _orig_y, orig_w, _orig_h) =
                original_cell_bounds(grid, row, col, cx, cy, cw, ch, vp);
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

fn render_grid_lines<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    draw_grid_lines_for_zone(grid, canvas, &ctx.vis_cells, false);
    draw_grid_lines_for_zone(grid, canvas, &ctx.vis_cells, true);
}

fn draw_grid_lines_for_zone<C: Canvas>(
    grid: &VolvoxGrid,
    canvas: &mut C,
    vis_cells: &[VisibleCell],
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
        || mode == LEGACY_GRIDLINE_SOLID_HORIZONTAL
        || mode == LEGACY_GRIDLINE_INSET_HORIZONTAL
        || mode == LEGACY_GRIDLINE_RAISED_HORIZONTAL;
    let draw_vert = mode == pb::GridLineStyle::GridlineSolid as i32
        || mode == pb::GridLineStyle::GridlineInset as i32
        || mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == LEGACY_GRIDLINE_SOLID_VERTICAL
        || mode == LEGACY_GRIDLINE_INSET_VERTICAL
        || mode == LEGACY_GRIDLINE_RAISED_VERTICAL;
    let is_3d = mode == pb::GridLineStyle::GridlineInset as i32
        || mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == LEGACY_GRIDLINE_INSET_HORIZONTAL
        || mode == LEGACY_GRIDLINE_INSET_VERTICAL
        || mode == LEGACY_GRIDLINE_RAISED_HORIZONTAL
        || mode == LEGACY_GRIDLINE_RAISED_VERTICAL;
    let is_raised = mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == LEGACY_GRIDLINE_RAISED_HORIZONTAL
        || mode == LEGACY_GRIDLINE_RAISED_VERTICAL;

    let shade_percent = if is_fixed_zone { 68 } else { 80 };
    let (color_light, color_dark) = if is_3d {
        if is_raised {
            (0xFFFFFFFF_u32, darken(color, shade_percent))
        } else {
            (darken(color, shade_percent), 0xFFFFFFFF_u32)
        }
    } else {
        (color, color)
    };

    let buf_w = canvas.width();
    let buf_h = canvas.height();

    for &cell in vis_cells {
        let (row, col, cx, cy, cw, ch) = cell.parts();
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
                canvas.vline(right - 1, cy, ch, color);
            }
        }

        if draw_horz && bottom >= 0 && bottom < buf_h {
            if is_3d {
                canvas.hline(cx, bottom - 1, cw, color_light);
                canvas.hline(cx, bottom, cw, color_dark);
            } else {
                canvas.hline(cx, bottom - 1, cw, color);
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

fn render_cell_borders<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    for &cell in &ctx.vis_cells {
        let (row, col, cx, cy, cw, ch) = cell.parts();
        // For merged cells, draw border once at the merge-origin cell.
        if let Some((mr1, mc1, _mr2, _mc2)) = cell.merge {
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

    if is_selection_layer_enabled(grid) && has_highlight_border(&grid.selection.active_cell_style) {
        if let Some((cx, cy, cw, ch)) =
            cell_rect(grid, grid.selection.row, grid.selection.col, &ctx.vp)
        {
            draw_highlight_border(
                canvas,
                cx,
                cy,
                cw,
                ch,
                &grid.selection.active_cell_style,
                selection_fore_color(grid),
            );
        }
    }
}

// ===========================================================================
// Layer 4 -- Cell text
// ===========================================================================

fn render_cell_text<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let has_subtotal_nodes = grid.row_props.values().any(|rp| rp.is_subtotal);
    let subtotal_level_floor = first_subtotal_level(grid);
    for text_cell in &ctx.text_cells {
        let text_row = text_cell.source_key.row;
        let text_col = text_cell.source_key.col;
        let meta = text_cell.meta.as_ref();
        let style_override = meta.style_override.as_ref();
        let CellRect {
            x: vis_x,
            y: vis_y,
            w: vis_w,
            h: vis_h,
        } = text_cell.vis_rect;
        let CellRect {
            x: orig_x,
            y: orig_y,
            w: orig_w,
            h: orig_h,
        } = text_cell.orig_rect;
        let display_text = meta.display_text.as_ref();
        let is_fixed = text_row < grid.fixed_rows || text_col < grid.fixed_cols;
        let is_frozen = !is_fixed
            && (text_row < grid.fixed_rows + grid.frozen_rows
                || text_col < grid.fixed_cols + grid.frozen_cols);
        let is_selected = should_highlight_cell(grid, text_row, text_col);
        let mut fore = style_override.resolve_fore_color(
            &grid.style,
            is_fixed,
            is_frozen,
            is_selected,
            selection_fore_color(grid),
        );
        if is_selection_layer_enabled(grid) && is_active_cell_origin(grid, text_row, text_col) {
            if let Some(active_fore) = grid.selection.active_cell_style.fore_color {
                fore = active_fore;
            }
        }
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
        let alignment = meta.alignment;
        let cell_padding = meta.padding;

        let button_reserve = if should_show_dropdown_button_with_list(
            grid,
            text_row,
            text_col,
            meta.has_dropdown_list,
        ) {
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

        let shrink_to_fit = meta.shrink_to_fit;
        let is_merged_cell = text_cell.is_merged;

        let needs_measure = grid.word_wrap
            || halign != 0
            || valign != 1
            || (ellipsis_mode != 0 && !grid.word_wrap)
            || (shrink_to_fit && !grid.word_wrap)
            || (grid.text_overflow && !grid.word_wrap && !shrink_to_fit && !is_merged_cell);
        let (tw, th) = if needs_measure {
            canvas.measure_text(
                display_text,
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
        let (effective_font_size, tw, th) =
            if shrink_to_fit && !grid.word_wrap && tw > inner_w as f32 && inner_w > 0 {
                let scale = inner_w as f32 / tw;
                let shrunk = (font_size * scale).floor().max(6.0);
                let (stw, sth) = canvas.measure_text(
                    display_text,
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
        let (inner_left, inner_right, inner_w, clip_x_ov, _clip_w_ov) = if grid.text_overflow
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
                    if grid.is_col_hidden(c) {
                        c += 1;
                        continue;
                    }
                    if grid
                        .get_merged_range(text_row, c)
                        .map_or(false, |(r1, c1, r2, c2)| r1 != r2 || c1 != c2)
                    {
                        break;
                    }
                    let neighbor_text = grid.get_display_text(text_row, c);
                    if !neighbor_text.is_empty() {
                        break;
                    }
                    right_ext += grid.get_col_width(c);
                    if (inner_w + left_ext + right_ext) as f32 >= tw {
                        break;
                    }
                    c += 1;
                }
            }

            // Scan leftward
            if scan_left {
                let mut c = text_col - 1;
                while c >= grid.fixed_cols {
                    if grid.is_col_hidden(c) {
                        c -= 1;
                        continue;
                    }
                    if grid
                        .get_merged_range(text_row, c)
                        .map_or(false, |(r1, c1, r2, c2)| r1 != r2 || c1 != c2)
                    {
                        break;
                    }
                    let neighbor_text = grid.get_display_text(text_row, c);
                    if !neighbor_text.is_empty() {
                        break;
                    }
                    left_ext += grid.get_col_width(c);
                    if (inner_w + left_ext + right_ext) as f32 >= tw {
                        break;
                    }
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
        let clip_bottom = (vis_y + vis_h).min(inner_bottom);
        let clip_h = (clip_bottom - clip_y_cell).max(1);

        // Handle ellipsis (uses effective_font_size and possibly extended inner_w)
        if ellipsis_mode != 0 && !grid.word_wrap && tw > inner_w as f32 {
            let ellipsis_text = if ellipsis_mode == 2 {
                compute_ellipsis_path_text(
                    canvas,
                    display_text,
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
            canvas.draw_text_styled_fast(
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
            canvas.draw_text_styled_fast(
                text_x,
                text_y,
                display_text,
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

fn render_cell_pictures<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    for &cell in &ctx.vis_cells {
        let (row, col, cx, cy, cw, ch) = cell.parts();
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
    slot_style: Option<&IconSlotStyle>,
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
    slot_style: Option<&IconSlotStyle>,
) -> crate::style::IconLayout {
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

fn resolve_sort_slot_style<'a>(grid: &'a VolvoxGrid, sort_order: i32) -> Option<&'a IconSlotStyle> {
    if sort_order == SORT_NONE {
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
) -> Option<&'a IconSlotStyle> {
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
) -> Option<&'a IconSlotStyle> {
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
    layout: crate::style::IconLayout,
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
    sort_order_is_ascending_internal(sort_order)
}

fn render_sort_glyphs<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    if grid.indicator_bands.col_top.visible && vp.data_y > 0 {
        return;
    }
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
        let is_sort_none = sort_order == SORT_NONE;

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
                                    canvas,
                                    grid,
                                    sort_idx,
                                    draw_x + draw_w + 1,
                                    inner_top,
                                    inner_h,
                                    inner_bottom,
                                    inner_left,
                                    inner_w,
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
                        canvas.draw_text_styled_fast(
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
                                canvas,
                                grid,
                                sort_idx,
                                glyph_x + text_w + 1,
                                inner_top,
                                inner_h,
                                inner_bottom,
                                inner_left,
                                inner_w,
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

                // Default fallback: draw a vector arrow so it does not depend
                // on the active font containing arrow glyphs.
                let (_icon_font_name, _font_size, _font_bold, _font_italic, color) =
                    resolve_icon_text_style(
                        grid,
                        slot_style,
                        (grid.style.font_size + 1.0).max(8.0),
                        false,
                        false,
                        grid.style.fore_color_fixed,
                    );
                let glyph_box = sort_arrow_box_size(inner_h).min(inner_w.max(0));
                if glyph_box < 6 {
                    continue;
                }
                let glyph_x = place_sort_icon_x(glyph_box);
                let glyph_y = inner_top + ((inner_h - glyph_box).max(0) / 2);
                draw_sort_direction_arrow(
                    canvas,
                    glyph_x,
                    glyph_y,
                    glyph_box,
                    sort_order_is_ascending(sort_order),
                    color,
                );
                if show_sort_numbers {
                    draw_sort_priority_number(
                        canvas,
                        grid,
                        sort_idx,
                        glyph_x + glyph_box + 1,
                        inner_top,
                        inner_h,
                        inner_bottom,
                        inner_left,
                        inner_w,
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
    canvas.draw_text_styled_fast(
        x,
        num_y,
        &label,
        &grid.style.font_name,
        num_size,
        false,
        false,
        color,
        clip_x,
        0,
        clip_w,
        clip_h,
        0,
        None,
    );
}

// ===========================================================================
// Layer 4c -- Column drag insertion marker
// ===========================================================================

fn render_col_drag_marker<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    if !grid.col_drag_active || grid.col_drag_insert_pos < 0 {
        return;
    }

    let buf_w = canvas.width();
    let (header_top, header_bottom) = if grid.indicator_bands.col_top.visible && vp.data_y > 0 {
        (0, vp.data_y.clamp(0, canvas.height()))
    } else if grid.fixed_rows > 0 {
        (
            0,
            grid.layout
                .row_pos(grid.fixed_rows)
                .clamp(0, canvas.height()),
        )
    } else {
        (0, 0)
    };
    if header_bottom <= header_top {
        return;
    }

    let insert_before = grid.col_drag_insert_pos.clamp(0, grid.cols);
    let mut marker_x: Option<i32> = None;
    let probe_row = if grid.fixed_rows > 0 {
        0
    } else if vp.scroll_row_start < grid.rows {
        vp.scroll_row_start
    } else {
        0
    };
    if probe_row < grid.rows {
        if insert_before < grid.cols {
            if let Some((cx, _cy, _cw, _ch)) = cell_rect(grid, probe_row, insert_before, vp) {
                marker_x = Some(cx);
            }
        } else if grid.cols > 0 {
            let last_col = grid.cols - 1;
            if let Some((cx, _cy, cw, _ch)) = cell_rect(grid, probe_row, last_col, vp) {
                marker_x = Some(cx + cw);
            }
        }
    } else if grid.cols == 0 {
        marker_x = Some(vp.data_x);
    }

    let Some(x) = marker_x else {
        return;
    };
    if x < -4 || x > buf_w + 4 {
        return;
    }

    let rail_color = 0xFF101010_u32;
    let center_color = 0xFFF5F5F5_u32;
    let h = header_bottom - header_top;
    canvas.vline(x - 1, header_top, h, rail_color);
    canvas.vline(x, header_top, h, center_color);
    canvas.vline(x + 1, header_top, h, rail_color);
    canvas.fill_rect(x - 3, header_top, 7, 2, rail_color);
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

fn render_header_marks<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    if grid.cols <= 1 {
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
    if grid.indicator_bands.col_top.visible && vp.data_y > 0 {
        let band = &grid.indicator_bands.col_top;
        let row_offsets = build_indicator_row_offsets(band, 0);
        let col_rects = &ctx.visible_col_rects;
        for col in 0..max_col {
            if grid.is_col_hidden(col) || grid.is_col_hidden(col + 1) {
                continue;
            }
            // Use stable per-column rects instead of sampling one scroll row.
            // Sampling a merged row makes the separator jump as fling crosses
            // row boundaries.
            let Some((lx, lw)) = col_rects.get(&col).copied() else {
                continue;
            };
            let Some((_rx, rw)) = col_rects.get(&(col + 1)).copied() else {
                continue;
            };
            if lw <= 0 || rw <= 0 {
                continue;
            }
            let boundary_x = lx + lw - 1;
            let draw_x = boundary_x - ((width_px - 1) / 2);
            for (row, row_y, row_h) in &row_offsets {
                if skip_merged && indicator_slots_share_cell(band, *row, col, *row, col + 1) {
                    continue;
                }
                let mark_height = resolve_header_mark_height_px(height_spec, (*row_h).max(1));
                if mark_height <= 0 {
                    continue;
                }
                let draw_y = *row_y + (((*row_h).max(1) - mark_height) / 2);
                for dx in 0..width_px {
                    canvas.vline(draw_x + dx, draw_y, mark_height, color);
                }
            }
        }
        return;
    }

    if grid.fixed_rows <= 0 {
        return;
    }

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

            let boundary_x = lx + lw - 1;
            let draw_x = boundary_x - ((width_px - 1) / 2);
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

fn render_checkboxes<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
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

    for &cell in &ctx.vis_cells {
        let (row, col, cx, cy, cw, ch) = cell.parts();
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
            canvas.draw_text_styled_fast(
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

fn render_dropdown_buttons<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    for &cell in &ctx.vis_cells {
        let (row, col, cx, cy, cw, ch) = cell.parts();
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

fn render_selection<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let show_selection_fill = grid.selection.selection_style.back_color.is_some();
    let show_active_fill = grid.selection.active_cell_style.back_color.is_some();
    if !show_selection_fill && !show_active_fill {
        return;
    }

    if show_selection_fill {
        // Merged selections should paint once per visible merged range.
        let mut rendered_merges: std::collections::HashSet<(i32, i32, i32, i32)> =
            std::collections::HashSet::new();

        for &cell in &ctx.vis_cells {
            let (row, col, cx, cy, cw, ch) = cell.parts();
            let (style_row, style_col) = match cell.merge {
                Some((mr1, mc1, mr2, mc2)) if cell.is_merged_span() => {
                    let merge_key = (mr1, mc1, mr2, mc2);
                    if !rendered_merges.insert(merge_key) {
                        continue;
                    }
                    (mr1, mc1)
                }
                _ => (row, col),
            };

            if !should_highlight_cell(grid, style_row, style_col) {
                continue;
            }

            draw_highlight_fill(canvas, cx, cy, cw, ch, &grid.selection.selection_style);
        }
    }

    if show_active_fill {
        if let Some((cx, cy, cw, ch)) =
            cell_rect(grid, grid.selection.row, grid.selection.col, &ctx.vp)
        {
            draw_highlight_fill(canvas, cx, cy, cw, ch, &grid.selection.active_cell_style);
        }
    }
}

fn has_highlight_border(style: &HighlightStyle) -> bool {
    style.border.is_some()
        || style.border_top.is_some()
        || style.border_right.is_some()
        || style.border_bottom.is_some()
        || style.border_left.is_some()
}

fn draw_highlight_border<C: Canvas>(
    canvas: &mut C,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    style: &HighlightStyle,
    default_color: u32,
) {
    let base_style = style.border.unwrap_or(pb::BorderStyle::BorderNone as i32);
    let base_color = style.border_color.unwrap_or(default_color);

    let top_style = style.border_top.unwrap_or(base_style);
    let right_style = style.border_right.unwrap_or(base_style);
    let bottom_style = style.border_bottom.unwrap_or(base_style);
    let left_style = style.border_left.unwrap_or(base_style);

    let top_color = style.border_top_color.unwrap_or(base_color);
    let right_color = style.border_right_color.unwrap_or(base_color);
    let bottom_color = style.border_bottom_color.unwrap_or(base_color);
    let left_color = style.border_left_color.unwrap_or(base_color);

    canvas.cell_border_edge_style(x, y, w, h, BorderEdge::Top, top_style, top_color);
    canvas.cell_border_edge_style(x, y, w, h, BorderEdge::Right, right_style, right_color);
    canvas.cell_border_edge_style(x, y, w, h, BorderEdge::Bottom, bottom_style, bottom_color);
    canvas.cell_border_edge_style(x, y, w, h, BorderEdge::Left, left_style, left_color);
}

fn render_hover_highlight<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    if grid.selection.hover_mode == HOVER_NONE {
        return;
    }

    let row_border = has_highlight_border(&grid.selection.hover_row_style);
    let col_border = has_highlight_border(&grid.selection.hover_column_style);
    let cell_border = has_highlight_border(&grid.selection.hover_cell_style);
    if !row_border && !col_border && !cell_border {
        return;
    }

    for &cell in &ctx.vis_cells {
        let (row, col, cx, cy, cw, ch) = cell.parts();
        let (style_row, style_col) = match cell.merge {
            Some((mr1, mc1, _mr2, _mc2)) if cell.is_merged_span() => (mr1, mc1),
            _ => (row, col),
        };

        if style_row < grid.fixed_rows || style_col < grid.fixed_cols {
            continue;
        }
        if should_highlight_cell(grid, style_row, style_col) {
            continue;
        }

        if row_border && hover_matches_row(grid, style_row) {
            draw_highlight_border(
                canvas,
                cx,
                cy,
                cw,
                ch,
                &grid.selection.hover_row_style,
                0xFF1A73E8,
            );
        }
        if col_border && hover_matches_column(grid, style_col) {
            draw_highlight_border(
                canvas,
                cx,
                cy,
                cw,
                ch,
                &grid.selection.hover_column_style,
                0xFF1A73E8,
            );
        }
        if cell_border && hover_matches_cell(grid, style_row, style_col) {
            draw_highlight_border(
                canvas,
                cx,
                cy,
                cw,
                ch,
                &grid.selection.hover_cell_style,
                0xFF1A73E8,
            );
        }
    }
}

// ===========================================================================
// Layer 7.5 -- Formula reference highlights (edit mode)
// ===========================================================================

fn range_screen_rect(
    grid: &VolvoxGrid,
    ctx: &RenderContext,
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

    for &cell in &ctx.vis_cells {
        let (row, col, x, y, w, h) = cell.parts();
        if row < r1 || row > r2 || col < c1 || col > c2 {
            continue;
        }
        if w <= 0 || h <= 0 {
            continue;
        }
        any = true;
        min_x = min_x.min(x);
        min_y = min_y.min(y);
        max_x = max_x.max(x + w);
        max_y = max_y.max(y + h);
    }

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

fn draw_fill_handle_square<C: Canvas>(canvas: &mut C, anchor_x: i32, anchor_y: i32, color: u32) {
    let size = 7i32;
    let half = size / 2;
    let sx = anchor_x - half;
    let sy = anchor_y - half;
    canvas.fill_rect(sx, sy, size, size, 0xFFFFFFFF);
    canvas.fill_rect(sx + 1, sy + 1, size - 2, size - 2, color);
}

fn render_edit_highlights<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    if !grid.edit.is_active() || grid.edit.formula_highlights.is_empty() {
        return;
    }

    for region in &grid.edit.formula_highlights {
        let Some((x, y, w, h)) = range_screen_rect(
            grid,
            ctx,
            region.row1,
            region.col1,
            region.row2,
            region.col2,
        ) else {
            continue;
        };
        let color = region.color();
        if has_highlight_border(&region.style) {
            draw_highlight_border(canvas, x, y, w, h, &region.style, color);
        } else {
            canvas.rect_outline_thick(x, y, w, h, 2, color);
        }
        if region.show_corner_handles() {
            draw_corner_handles(canvas, x, y, w, h, color);
        }
    }
}

// ===========================================================================
// Layer 8 -- Focus rect
// ===========================================================================

fn render_focus_rect<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    if grid.selection.focus_border == pb::FocusBorderStyle::FocusBorderNone as i32 {
        return;
    }

    let active_has_custom_style = grid.selection.active_cell_style.back_color.is_some()
        || grid.selection.active_cell_style.fore_color.is_some()
        || has_highlight_border(&grid.selection.active_cell_style);

    if grid.selection.focus_border == pb::FocusBorderStyle::FocusBorderThin as i32
        && should_highlight_cell(grid, grid.selection.row, grid.selection.col)
        && !active_has_custom_style
    {
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

fn render_fill_handle<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    if !is_highlight_active(grid) {
        return;
    }

    let handle_pos = grid
        .selection
        .selection_style
        .fill_handle
        .unwrap_or(pb::FillHandlePosition::FillHandleNone as i32);
    if handle_pos == pb::FillHandlePosition::FillHandleNone as i32 {
        return;
    }
    let handle_color = grid
        .selection
        .selection_style
        .fill_handle_color
        .unwrap_or(0xFF217346);

    let (r1, c1, r2, c2) = grid.selection.get_range();
    let r1 = r1.clamp(0, grid.rows - 1);
    let c1 = c1.clamp(0, grid.cols - 1);
    let r2 = r2.clamp(0, grid.rows - 1);
    let c2 = c2.clamp(0, grid.cols - 1);

    let draw_at = |canvas: &mut C, row: i32, col: i32, at_right: bool, at_bottom: bool| {
        let Some((cx, cy, cw, ch)) = cell_rect(grid, row, col, vp) else {
            return;
        };
        let anchor_x = if at_right { cx + cw - 1 } else { cx };
        let anchor_y = if at_bottom { cy + ch - 1 } else { cy };
        draw_fill_handle_square(canvas, anchor_x, anchor_y, handle_color);
    };

    match handle_pos {
        p if p == pb::FillHandlePosition::FillHandleBottomRight as i32 => {
            draw_at(canvas, r2, c2, true, true);
        }
        p if p == pb::FillHandlePosition::FillHandleBottomLeft as i32 => {
            draw_at(canvas, r2, c1, false, true);
        }
        p if p == pb::FillHandlePosition::FillHandleTopRight as i32 => {
            draw_at(canvas, r1, c2, true, false);
        }
        p if p == pb::FillHandlePosition::FillHandleTopLeft as i32 => {
            draw_at(canvas, r1, c1, false, false);
        }
        p if p == pb::FillHandlePosition::FillHandleAllCorners as i32 => {
            draw_at(canvas, r1, c1, false, false);
            draw_at(canvas, r1, c2, true, false);
            draw_at(canvas, r2, c1, false, true);
            draw_at(canvas, r2, c2, true, true);
        }
        _ => {}
    }
}

// ===========================================================================
// Layer 9 -- Outline tree lines and +/- buttons
// ===========================================================================

fn render_outline<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
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
            let (ox, oy, _ow, oh) = original_cell_bounds(grid, row, tree_col, cx, cy, cw, ch, vp);

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
                    canvas.draw_text_styled_fast(
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

fn render_frozen_borders<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    let buf_w = canvas.width();
    let buf_h = canvas.height();
    let mode = grid.style.grid_lines_fixed;
    if mode == pb::GridLineStyle::GridlineNone as i32 {
        return;
    }
    let color = grid.style.grid_color_fixed;
    let draw_horz = mode == pb::GridLineStyle::GridlineSolid as i32
        || mode == pb::GridLineStyle::GridlineInset as i32
        || mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == LEGACY_GRIDLINE_SOLID_HORIZONTAL
        || mode == LEGACY_GRIDLINE_INSET_HORIZONTAL
        || mode == LEGACY_GRIDLINE_RAISED_HORIZONTAL;
    let draw_vert = mode == pb::GridLineStyle::GridlineSolid as i32
        || mode == pb::GridLineStyle::GridlineInset as i32
        || mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == LEGACY_GRIDLINE_SOLID_VERTICAL
        || mode == LEGACY_GRIDLINE_INSET_VERTICAL
        || mode == LEGACY_GRIDLINE_RAISED_VERTICAL;
    let is_3d = mode == pb::GridLineStyle::GridlineInset as i32
        || mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == LEGACY_GRIDLINE_INSET_HORIZONTAL
        || mode == LEGACY_GRIDLINE_INSET_VERTICAL
        || mode == LEGACY_GRIDLINE_RAISED_HORIZONTAL
        || mode == LEGACY_GRIDLINE_RAISED_VERTICAL;
    let is_raised = mode == pb::GridLineStyle::GridlineRaised as i32
        || mode == LEGACY_GRIDLINE_RAISED_HORIZONTAL
        || mode == LEGACY_GRIDLINE_RAISED_VERTICAL;
    let (color_inner, color_outer) = if is_3d {
        if is_raised {
            (0xFFFFFFFF_u32, darken(color, 68))
        } else {
            (darken(color, 68), 0xFFFFFFFF_u32)
        }
    } else {
        (color, color)
    };

    // Grid content boundaries — lines should not extend beyond these.
    // Account for indicator bands and scroll offset so separators align with
    // the same canvas-space coordinates as rendered cells.
    let scroll_x = grid.scroll.scroll_x as i32;
    let scroll_y = grid.scroll.scroll_y as i32;
    let content_right = (vp.data_x + grid.col_pos(grid.cols) - scroll_x).clamp(0, buf_w);
    let content_bottom = (vp.data_y + grid.row_pos(grid.rows) - scroll_y).clamp(0, buf_h);

    // Horizontal frozen row border
    if draw_horz && grid.frozen_rows > 0 {
        let frozen_row_bottom = vp.data_y + grid.row_pos(grid.fixed_rows + grid.frozen_rows);
        if frozen_row_bottom > 0 && frozen_row_bottom < buf_h {
            if is_3d {
                canvas.hline(0, frozen_row_bottom - 1, content_right, color_inner);
                canvas.hline(0, frozen_row_bottom, content_right, color_outer);
            } else {
                canvas.hline(0, frozen_row_bottom - 1, content_right, color);
            }
        }
    }

    // Vertical frozen col border
    if draw_vert && grid.frozen_cols > 0 {
        let frozen_col_right = vp.data_x + grid.col_pos(grid.fixed_cols + grid.frozen_cols);
        if frozen_col_right > 0 && frozen_col_right < buf_w {
            if is_3d {
                canvas.vline(frozen_col_right - 1, 0, content_bottom, color_inner);
                canvas.vline(frozen_col_right, 0, content_bottom, color_outer);
            } else {
                canvas.vline(frozen_col_right - 1, 0, content_bottom, color);
            }
        }
    }
}

// ===========================================================================
// Layer 11 -- Active in-place editor
// ===========================================================================

pub(crate) fn compose_preedit_display_text(
    text: &str,
    sel_start: i32,
    sel_end: i32,
    preedit: &str,
) -> String {
    let text_char_count = text.chars().count() as i32;
    let sel_start = sel_start.clamp(0, text_char_count);
    let sel_end = sel_end.clamp(sel_start, text_char_count);
    let before_byte = byte_index_at_char(text, sel_start);
    let after_byte = byte_index_at_char(text, sel_end);

    format!("{}{}{}", &text[..before_byte], preedit, &text[after_byte..])
}

fn render_active_editor<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
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
    let fore = style_override.resolve_fore_color(
        &grid.style,
        is_fixed,
        is_frozen,
        false,
        selection_fore_color(grid),
    );
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

    let composing = grid.edit.composing && !grid.edit.preedit_text.is_empty();
    let text = grid.edit.edit_text.as_str();
    let text_char_count = text.chars().count() as i32;
    let sel_start = grid.edit.sel_start.clamp(0, text_char_count);
    let sel_end = (grid.edit.sel_start + grid.edit.sel_length).clamp(0, text_char_count);

    let text_x = cx + left_padding;
    let clip_w = (edit_w - left_padding - right_padding).max(1);
    let clip_h = inner_h;
    let scroll_margin = 2; // pixels of margin to keep between caret and clip edge

    if composing {
        // IME composition mode: preview the preedit text replacing any active selection.
        let preedit = grid.edit.preedit_text.as_str();
        let before_preedit_byte = byte_index_at_char(text, sel_start);
        let composite = compose_preedit_display_text(text, sel_start, sel_end, preedit);

        let (_, th) = canvas.measure_text(
            &composite,
            font_name,
            font_size,
            font_bold,
            font_italic,
            None,
        );
        let text_y = cy + top_padding + ((inner_h - th.ceil() as i32) / 2).max(0);

        // Compute caret position for scroll offset.
        let before_preedit = &text[..before_preedit_byte];
        let (before_w, _) = canvas.measure_text(
            before_preedit,
            font_name,
            font_size,
            font_bold,
            font_italic,
            None,
        );
        let (preedit_w, _) =
            canvas.measure_text(preedit, font_name, font_size, font_bold, font_italic, None);
        let preedit_cursor = grid
            .edit
            .preedit_cursor
            .clamp(0, preedit.chars().count() as i32);
        let cursor_prefix = &preedit[..byte_index_at_char(preedit, preedit_cursor)];
        let (cursor_w, _) = canvas.measure_text(
            cursor_prefix,
            font_name,
            font_size,
            font_bold,
            font_italic,
            None,
        );
        let caret_px = before_w.ceil() as i32 + cursor_w.ceil() as i32;
        let scroll_offset = if caret_px + scroll_margin > clip_w {
            caret_px + scroll_margin - clip_w
        } else {
            0
        };
        let draw_x = text_x - scroll_offset;

        // Draw the full composite string.
        canvas.draw_text_styled_fast(
            draw_x,
            text_y,
            &composite,
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

        // Draw underline under the preedit portion.
        let underline_x = draw_x + before_w.ceil() as i32;
        let underline_w = preedit_w.ceil() as i32;
        let underline_y = text_y + th.ceil() as i32;
        if underline_w > 0 {
            let ul_left = underline_x.max(text_x);
            let ul_right = (underline_x + underline_w).min(text_x + clip_w);
            if ul_right > ul_left {
                canvas.hline(ul_left, underline_y, ul_right - ul_left, fore);
            }
        }

        // Caret within the preedit.
        let caret_x = (draw_x + caret_px).clamp(text_x, (text_x + clip_w).max(text_x));
        canvas.vline(caret_x, cy + top_padding, inner_h, 0xFF000000);
    } else {
        // Normal editing mode (no IME composition).
        let prefix = &text[..byte_index_at_char(text, sel_start)];
        let selected =
            &text[byte_index_at_char(text, sel_start)..byte_index_at_char(text, sel_end)];
        let (_, th) = canvas.measure_text(text, font_name, font_size, font_bold, font_italic, None);
        let text_y = cy + top_padding + ((inner_h - th.ceil() as i32) / 2).max(0);

        // Compute scroll offset to keep the caret (or selection end) visible.
        let caret_char = if sel_end > sel_start {
            sel_end
        } else {
            sel_start
        };
        let caret_prefix = &text[..byte_index_at_char(text, caret_char)];
        let (caret_prefix_w, _) = canvas.measure_text(
            caret_prefix,
            font_name,
            font_size,
            font_bold,
            font_italic,
            None,
        );
        let caret_px = caret_prefix_w.ceil() as i32;
        let scroll_offset = if caret_px + scroll_margin > clip_w {
            caret_px + scroll_margin - clip_w
        } else {
            0
        };
        let draw_x = text_x - scroll_offset;

        // Selection highlight
        if sel_end > sel_start {
            let (prefix_w, _) =
                canvas.measure_text(prefix, font_name, font_size, font_bold, font_italic, None);
            let (sel_w, _) =
                canvas.measure_text(selected, font_name, font_size, font_bold, font_italic, None);
            let sel_x = draw_x + prefix_w.ceil() as i32;
            let sel_w_px = sel_w.ceil() as i32;
            let sel_left = sel_x.max(text_x);
            let sel_right = (sel_x + sel_w_px).min(text_x + clip_w);
            if sel_right > sel_left {
                canvas.fill_rect(
                    sel_left,
                    cy + top_padding,
                    sel_right - sel_left,
                    inner_h,
                    0xFFBDD7FF,
                );
            }
        }

        // Editor text
        canvas.draw_text_styled_fast(
            draw_x,
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
            let sel_x = draw_x + prefix_w.ceil() as i32;
            canvas.draw_text_styled_fast(
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
            let caret_x = (draw_x + caret_px).clamp(text_x, (text_x + clip_w).max(text_x));
            canvas.vline(caret_x, cy + top_padding, inner_h, 0xFF000000);
        }
    }
}

// ===========================================================================
// Layer 12 -- Active dropdown list
// ===========================================================================

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct DropdownPopupGeometry {
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
    pub item_h: i32,
    pub visible_count: i32,
    pub start: i32,
}

pub(crate) fn active_dropdown_popup_geometry(
    grid: &VolvoxGrid,
    cell_rect: (i32, i32, i32, i32),
    surface_w: i32,
    surface_h: i32,
) -> Option<DropdownPopupGeometry> {
    let count = grid.edit.dropdown_count();
    if count <= 0 {
        return None;
    }

    let (cx, cy, cw, ch) = cell_rect;
    let visible_count = count.min(8).max(1);
    let item_h = ch.max(18);
    let drop_h = item_h * visible_count;
    let drop_w = cw.max(90);
    let mut drop_x = cx;
    let mut drop_y = cy + ch - 1;

    if drop_x + drop_w > surface_w {
        drop_x = (surface_w - drop_w).max(0);
    }
    if drop_y + drop_h > surface_h {
        drop_y = cy - drop_h + 1;
    }
    if drop_y < 0 {
        drop_y = 0;
    }
    if drop_y + drop_h > surface_h {
        drop_y = (surface_h - drop_h).max(0);
    }

    let sel = grid.edit.dropdown_index;
    let mut start = 0;
    if sel >= 0 && sel >= visible_count {
        start = sel - visible_count + 1;
    }
    let max_start = (count - visible_count).max(0);
    if start > max_start {
        start = max_start;
    }

    Some(DropdownPopupGeometry {
        x: drop_x,
        y: drop_y,
        w: drop_w,
        h: drop_h,
        item_h,
        visible_count,
        start,
    })
}

fn render_active_dropdown<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
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

    let Some(drop) =
        active_dropdown_popup_geometry(grid, (cx, cy, cw, ch), canvas.width(), canvas.height())
    else {
        return;
    };

    canvas.blend_rect(drop.x + 2, drop.y + 2, drop.w, drop.h, 0x55000000);
    canvas.fill_rect(drop.x, drop.y, drop.w, drop.h, 0xFFFFFFFF);
    canvas.rect_outline(drop.x, drop.y, drop.w, drop.h, 0xFF4A4A4A);

    let sel = grid.edit.dropdown_index;

    let font_name = &grid.style.font_name;
    let font_size = grid.style.font_size;
    let font_bold = grid.style.font_bold;
    let font_italic = grid.style.font_italic;
    let text_style = grid.style.text_effect;
    let text_padding = 4_i32;

    for slot in 0..drop.visible_count {
        let idx = drop.start + slot;
        let item_y = drop.y + slot * drop.item_h;
        let selected = idx == sel;

        let row_bg = if selected {
            selection_back_color(grid)
        } else {
            0xFFFFFFFF
        };
        canvas.fill_rect(
            drop.x + 1,
            item_y + 1,
            (drop.w - 2).max(0),
            (drop.item_h - 1).max(0),
            row_bg,
        );

        let text_color = if selected {
            selection_fore_color(grid)
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
        let text_y = item_y + ((drop.item_h - th.ceil() as i32) / 2).max(0);
        canvas.draw_text_styled_fast(
            drop.x + text_padding,
            text_y,
            item_text,
            font_name,
            font_size,
            font_bold,
            font_italic,
            text_color,
            drop.x + text_padding,
            0,
            (drop.w - text_padding * 2).max(1),
            drop.item_h,
            text_style,
            None,
        );
    }
}

// ===========================================================================
// Layer 13 -- Scroll bars
// ===========================================================================

fn render_scroll_bars<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C) {
    let geom = compute_scrollbar_geometry(grid, canvas.width(), canvas.height());
    if !geom.show_h && !geom.show_v {
        return;
    }

    let appearance = normalize_scrollbar_appearance(grid.scrollbar_appearance);
    let overlay = geom.overlays_content;
    let mode_h = normalize_scrollbar_mode(grid.scrollbar_show_h);
    let mode_v = normalize_scrollbar_mode(grid.scrollbar_show_v);
    let fade_opacity = grid.scrollbar_fade_opacity.clamp(0.0, 1.0);
    let axis_opacity = |mode: i32| {
        if !overlay || mode == pb::ScrollBarMode::ScrollbarModeAlways as i32 {
            1.0
        } else {
            fade_opacity
        }
    };
    let opacity_h = axis_opacity(mode_h);
    let opacity_v = axis_opacity(mode_v);
    if (!geom.show_h || opacity_h <= 0.0) && (!geom.show_v || opacity_v <= 0.0) {
        return;
    }

    let thumb_base_color = |active: bool| {
        if active {
            grid.scrollbar_colors.thumb_active
        } else if grid.scrollbar_hover {
            grid.scrollbar_colors.thumb_hover
        } else {
            grid.scrollbar_colors.thumb
        }
    };

    let fill_box = |canvas: &mut C, x: i32, y: i32, w: i32, h: i32, color: u32| {
        if w <= 0 || h <= 0 || (color >> 24) == 0 {
            return;
        }
        if overlay {
            canvas.blend_rect(x, y, w, h, color);
        } else {
            canvas.fill_rect(x, y, w, h, color);
        }
    };
    let outline_box = |canvas: &mut C, x: i32, y: i32, w: i32, h: i32, color: u32| {
        if w <= 0 || h <= 0 || (color >> 24) == 0 {
            return;
        }
        if overlay {
            canvas.blend_rect(x, y, w, 1, color);
            if h > 1 {
                canvas.blend_rect(x, y + h - 1, w, 1, color);
            }
            if h > 2 {
                canvas.blend_rect(x, y + 1, 1, h - 2, color);
                if w > 1 {
                    canvas.blend_rect(x + w - 1, y + 1, 1, h - 2, color);
                }
            }
        } else {
            canvas.rect_outline(x, y, w, h, color);
        }
    };
    let rounded_box = |canvas: &mut C, x: i32, y: i32, w: i32, h: i32, r: i32, color: u32| {
        if w <= 0 || h <= 0 || (color >> 24) == 0 {
            return;
        }
        if overlay {
            canvas.blend_rounded_rect(x, y, w, h, r, color);
        } else {
            canvas.fill_rounded_rect(x, y, w, h, r, color);
        }
    };

    if geom.show_h && opacity_h > 0.0 {
        let apply_alpha = |color: u32| {
            if overlay {
                scale_color_alpha(color, opacity_h)
            } else {
                color
            }
        };
        let track = apply_alpha(grid.scrollbar_colors.track);
        let border = apply_alpha(grid.scrollbar_colors.border);
        let arrow = apply_alpha(grid.scrollbar_colors.arrow);
        let thumb = apply_alpha(thumb_base_color(
            grid.scrollbar_drag_active && grid.scrollbar_drag_horizontal,
        ));
        if appearance == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32
            || appearance == pb::ScrollBarAppearance::ScrollbarAppearanceFlat as i32
        {
            let flat_button = |canvas: &mut C, x: i32, y: i32, w: i32, h: i32, color: u32| {
                fill_box(canvas, x, y, w, h, color);
                outline_box(canvas, x, y, w, h, border);
            };
            let flat_thumb = |canvas: &mut C, x: i32, y: i32, w: i32, h: i32, color: u32| {
                fill_box(canvas, x, y, w, h, color);
                outline_box(canvas, x, y, w, h, border);
            };
            fill_box(
                canvas,
                geom.h_bar_x,
                geom.h_bar_y,
                geom.h_bar_w,
                geom.h_bar_h,
                track,
            );
            outline_box(
                canvas,
                geom.h_bar_x,
                geom.h_bar_y,
                geom.h_bar_w,
                geom.h_bar_h,
                border,
            );

            if geom.uses_arrows {
                if appearance == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32 {
                    canvas.draw_scroll_button(
                        geom.h_left_arrow_x,
                        geom.h_bar_y,
                        geom.bar_size,
                        geom.h_bar_h,
                        thumb,
                    );
                    canvas.draw_scroll_button(
                        geom.h_right_arrow_x,
                        geom.h_bar_y,
                        geom.bar_size,
                        geom.h_bar_h,
                        thumb,
                    );
                } else {
                    flat_button(
                        canvas,
                        geom.h_left_arrow_x,
                        geom.h_bar_y,
                        geom.bar_size,
                        geom.h_bar_h,
                        thumb,
                    );
                    flat_button(
                        canvas,
                        geom.h_right_arrow_x,
                        geom.h_bar_y,
                        geom.bar_size,
                        geom.h_bar_h,
                        thumb,
                    );
                }
                if (arrow >> 24) != 0 {
                    canvas.draw_scroll_arrow_left(
                        geom.h_left_arrow_x,
                        geom.h_bar_y,
                        geom.bar_size,
                        geom.h_bar_h,
                        arrow,
                    );
                    canvas.draw_scroll_arrow_right(
                        geom.h_right_arrow_x,
                        geom.h_bar_y,
                        geom.bar_size,
                        geom.h_bar_h,
                        arrow,
                    );
                }
            }

            if geom.h_track_w > 0 {
                fill_box(
                    canvas,
                    geom.h_track_x,
                    geom.h_track_y,
                    geom.h_track_w,
                    geom.h_track_h,
                    track,
                );
                if appearance == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32 {
                    canvas.fill_checker(
                        geom.h_track_x,
                        geom.h_track_y,
                        geom.h_track_w,
                        geom.h_track_h,
                    );
                }
                outline_box(
                    canvas,
                    geom.h_track_x,
                    geom.h_track_y,
                    geom.h_track_w,
                    geom.h_track_h,
                    border,
                );
                if geom.h_thumb_w > 0 {
                    if appearance == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32 {
                        canvas.draw_scroll_thumb(
                            geom.h_thumb_x,
                            geom.h_thumb_y,
                            geom.h_thumb_w,
                            geom.h_thumb_h,
                            thumb,
                        );
                    } else {
                        flat_thumb(
                            canvas,
                            geom.h_thumb_x,
                            geom.h_thumb_y,
                            geom.h_thumb_w,
                            geom.h_thumb_h,
                            thumb,
                        );
                    }
                }
            }
        } else {
            if geom.h_track_w > 0 {
                fill_box(
                    canvas,
                    geom.h_track_x,
                    geom.h_track_y,
                    geom.h_track_w,
                    geom.h_track_h,
                    track,
                );
                outline_box(
                    canvas,
                    geom.h_track_x,
                    geom.h_track_y,
                    geom.h_track_w,
                    geom.h_track_h,
                    border,
                );
                rounded_box(
                    canvas,
                    geom.h_thumb_x,
                    geom.h_thumb_y,
                    geom.h_thumb_w,
                    geom.h_thumb_h,
                    grid.scrollbar_corner_radius.max(0),
                    thumb,
                );
            }
        }
    }

    if geom.show_v && opacity_v > 0.0 {
        let apply_alpha = |color: u32| {
            if overlay {
                scale_color_alpha(color, opacity_v)
            } else {
                color
            }
        };
        let track = apply_alpha(grid.scrollbar_colors.track);
        let border = apply_alpha(grid.scrollbar_colors.border);
        let arrow = apply_alpha(grid.scrollbar_colors.arrow);
        let thumb = apply_alpha(thumb_base_color(
            grid.scrollbar_drag_active && !grid.scrollbar_drag_horizontal,
        ));
        if appearance == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32
            || appearance == pb::ScrollBarAppearance::ScrollbarAppearanceFlat as i32
        {
            let flat_button = |canvas: &mut C, x: i32, y: i32, w: i32, h: i32, color: u32| {
                fill_box(canvas, x, y, w, h, color);
                outline_box(canvas, x, y, w, h, border);
            };
            let flat_thumb = |canvas: &mut C, x: i32, y: i32, w: i32, h: i32, color: u32| {
                fill_box(canvas, x, y, w, h, color);
                outline_box(canvas, x, y, w, h, border);
            };
            fill_box(
                canvas,
                geom.v_bar_x,
                geom.v_bar_y,
                geom.v_bar_w,
                geom.v_bar_h,
                track,
            );
            outline_box(
                canvas,
                geom.v_bar_x,
                geom.v_bar_y,
                geom.v_bar_w,
                geom.v_bar_h,
                border,
            );

            if geom.uses_arrows {
                if appearance == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32 {
                    canvas.draw_scroll_button(
                        geom.v_bar_x,
                        geom.v_top_arrow_y,
                        geom.v_bar_w,
                        geom.bar_size,
                        thumb,
                    );
                    canvas.draw_scroll_button(
                        geom.v_bar_x,
                        geom.v_bot_arrow_y,
                        geom.v_bar_w,
                        geom.bar_size,
                        thumb,
                    );
                } else {
                    flat_button(
                        canvas,
                        geom.v_bar_x,
                        geom.v_top_arrow_y,
                        geom.v_bar_w,
                        geom.bar_size,
                        thumb,
                    );
                    flat_button(
                        canvas,
                        geom.v_bar_x,
                        geom.v_bot_arrow_y,
                        geom.v_bar_w,
                        geom.bar_size,
                        thumb,
                    );
                }
                if (arrow >> 24) != 0 {
                    canvas.draw_scroll_arrow_up(
                        geom.v_bar_x,
                        geom.v_top_arrow_y,
                        geom.v_bar_w,
                        geom.bar_size,
                        arrow,
                    );
                    canvas.draw_scroll_arrow_down(
                        geom.v_bar_x,
                        geom.v_bot_arrow_y,
                        geom.v_bar_w,
                        geom.bar_size,
                        arrow,
                    );
                }
            }

            if geom.v_track_h > 0 {
                fill_box(
                    canvas,
                    geom.v_track_x,
                    geom.v_track_y,
                    geom.v_track_w,
                    geom.v_track_h,
                    track,
                );
                if appearance == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32 {
                    canvas.fill_checker(
                        geom.v_track_x,
                        geom.v_track_y,
                        geom.v_track_w,
                        geom.v_track_h,
                    );
                }
                outline_box(
                    canvas,
                    geom.v_track_x,
                    geom.v_track_y,
                    geom.v_track_w,
                    geom.v_track_h,
                    border,
                );
                if geom.v_thumb_h > 0 {
                    if appearance == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32 {
                        canvas.draw_scroll_thumb(
                            geom.v_thumb_x,
                            geom.v_thumb_y,
                            geom.v_thumb_w,
                            geom.v_thumb_h,
                            thumb,
                        );
                    } else {
                        flat_thumb(
                            canvas,
                            geom.v_thumb_x,
                            geom.v_thumb_y,
                            geom.v_thumb_w,
                            geom.v_thumb_h,
                            thumb,
                        );
                    }
                }
            }
        } else {
            if geom.v_track_h > 0 {
                fill_box(
                    canvas,
                    geom.v_track_x,
                    geom.v_track_y,
                    geom.v_track_w,
                    geom.v_track_h,
                    track,
                );
                outline_box(
                    canvas,
                    geom.v_track_x,
                    geom.v_track_y,
                    geom.v_track_w,
                    geom.v_track_h,
                    border,
                );
                rounded_box(
                    canvas,
                    geom.v_thumb_x,
                    geom.v_thumb_y,
                    geom.v_thumb_w,
                    geom.v_thumb_h,
                    grid.scrollbar_corner_radius.max(0),
                    thumb,
                );
            }
        }
    }

    if geom.corner_w > 0 && geom.corner_h > 0 {
        let corner_track = grid.scrollbar_colors.track;
        let corner_border = grid.scrollbar_colors.border;
        fill_box(
            canvas,
            geom.corner_x,
            geom.corner_y,
            geom.corner_w,
            geom.corner_h,
            corner_track,
        );
        if appearance == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32 {
            canvas.fill_checker(geom.corner_x, geom.corner_y, geom.corner_w, geom.corner_h);
        }
        outline_box(
            canvas,
            geom.corner_x,
            geom.corner_y,
            geom.corner_w,
            geom.corner_h,
            corner_border,
        );
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

fn short_commit(commit: &str) -> String {
    let trimmed = commit.trim();
    if trimmed.is_empty() || trimmed.eq_ignore_ascii_case("unknown") {
        "unknown".to_string()
    } else {
        trimmed.chars().take(7).collect()
    }
}

fn format_build_date_utc(date: &str) -> String {
    let trimmed = date.trim();
    if trimmed.is_empty() || trimmed.eq_ignore_ascii_case("unknown") {
        return "unknown".to_string();
    }

    let Some((ymd, rest)) = trimmed.split_once('T') else {
        return trimmed.to_string();
    };

    if ymd.len() != 10 {
        return trimmed.to_string();
    }

    let mut parts = rest.split(':');
    let (Some(hour), Some(minute)) = (parts.next(), parts.next()) else {
        return trimmed.to_string();
    };
    if hour.len() != 2 || minute.len() != 2 {
        return trimmed.to_string();
    }

    if !hour.chars().all(|c| c.is_ascii_digit()) || !minute.chars().all(|c| c.is_ascii_digit()) {
        return trimmed.to_string();
    }

    format!("{ymd} {hour}:{minute} UTC")
}

fn render_debug_overlay<C: Canvas>(grid: &VolvoxGrid, canvas: &mut C, ctx: &RenderContext) {
    let vp = &ctx.vp;
    if !grid.debug_overlay {
        return;
    }

    use crate::debug_font as df;

    let buf_w = canvas.width();
    let buf_h = canvas.height();

    // Keep the debug overlay at a fixed 2x on Android; raw density makes the
    // bitmap font comically large on modern phones and tablets.
    #[cfg(target_os = "android")]
    let s = 2;
    #[cfg(not(target_os = "android"))]
    let s = (grid.scale.round() as i32).max(1);
    let lh = df::line_height(s);
    let pad = 4 * s;
    let text_color: u32 = 0xFFFFFFFF;
    let dim_color: u32 = 0xFF808080;
    let bg_color: u32 = 0xC0000000;

    // ── Build header lines ──
    let mut lines: Vec<String> = Vec::new();

    lines.push(format!(
        "Engine v{} | {} | {}",
        VolvoxGrid::version(),
        short_commit(VolvoxGrid::git_commit()),
        format_build_date_utc(VolvoxGrid::build_date())
    ));

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
        "FPS:{:>6.1} {:>5.1}ms Q:{} ID:{} Z:{:.0}% {}x{}",
        grid.debug_fps,
        grid.debug_frame_time_ms,
        grid.debug_instance_count,
        grid.id,
        grid.debug_zoom_level * 100.0,
        buf_w,
        buf_h,
    ));

    let status_str = if grid.dirty {
        let mut reasons = Vec::new();
        if grid.animation.active {
            reasons.push("ANIM".to_string());
        }
        if grid.background_loading {
            reasons.push("LOAD".to_string());
        }
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
        "{} {}x{} {}",
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
        "Vis: {}x{}({}) P:{},{} M:{} C:{}/{}",
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

    // Zone cell counts
    let zc = &grid.zone_cell_counts;
    if zc[0] + zc[1] + zc[2] + zc[3] > 0 {
        lines.push(format!(
            "Cells: {} scrl {} stky {} pin {} fix",
            zc[0], zc[1], zc[2], zc[3]
        ));
    }

    // Disabled layers
    if grid.render_layer_mask != u64::MAX {
        let mut disabled: Vec<&str> = Vec::new();
        for i in 0..layer::COUNT {
            if grid.render_layer_mask & (1u64 << i) == 0 {
                disabled.push(layer::NAMES[i]);
            }
        }
        if !disabled.is_empty() {
            lines.push(format!("Off: {}", disabled.join(",")));
        }
    }

    // ── Compute geometry ──
    let num_header = lines.len() as i32;
    let mut max_header_w: i32 = 0;
    for line in &lines {
        max_header_w = max_header_w.max(df::str_width(line, s));
    }

    let profiling = grid.layer_profiling;
    let total_us: f32 = if profiling {
        grid.layer_times_us.iter().sum()
    } else {
        0.0
    };
    // Layer grid: 2 columns, ceil(26/2)=13 rows + 1 title
    let layer_rows = if profiling { (layer::COUNT + 1) / 2 } else { 0 }; // 13
    let layer_extra = if profiling { 1 + layer_rows as i32 } else { 0 };

    // Column layout for layer grid:
    // |<name 10ch>|<value 6ch>|<pct 4ch>|<gap 2ch>|<name 10ch>|<value 6ch>|<pct 4ch>|
    let name_chars = 10;
    let val_chars = 6; // " 9999u"
    let pct_chars = 4; // " 99%"
    let gap_chars = 2;
    let one_col_chars = name_chars + val_chars + pct_chars;
    let two_col_chars = one_col_chars * 2 + gap_chars;
    let layer_grid_w = if profiling {
        df::str_width("x", s) * two_col_chars as i32
    } else {
        0
    };

    let content_w = max_header_w.max(layer_grid_w);
    let overlay_w = (content_w + pad * 2).min(buf_w);
    let overlay_h = ((num_header + layer_extra) * lh + pad * 2).min(buf_h);
    let overlay_x = 0;
    let overlay_y = (buf_h - overlay_h).max(0);

    canvas.blend_rect(overlay_x, overlay_y, overlay_w, overlay_h, bg_color);

    // ── Draw header lines ──
    let x0 = overlay_x + pad;
    let mut y = overlay_y + pad;
    for line in &lines {
        df::draw_str(canvas, x0, y, line, text_color, s);
        y += lh;
    }

    // ── Draw layer profiling grid ──
    if profiling {
        // Title
        let title = format!("Layers: {:5.0}us total", total_us);
        df::draw_str(canvas, x0, y, &title, text_color, s);
        y += lh;

        let char_w = df::CELL_W * s;
        let col2_x = x0 + (one_col_chars + gap_chars) as i32 * char_w;
        let val_off = name_chars as i32 * char_w;
        let pct_off = (name_chars + val_chars) as i32 * char_w;

        for i in 0..layer::COUNT {
            let ci = i / layer_rows; // 0 or 1
            let ri = i % layer_rows;
            let cx = if ci == 0 { x0 } else { col2_x };
            let cy = y + ri as i32 * lh;

            let off = grid.render_layer_mask & (1u64 << i) == 0;
            let color = if off { dim_color } else { text_color };

            // Name (left-aligned)
            df::draw_str(canvas, cx, cy, layer::NAMES[i], color, s);

            if off {
                df::draw_str_right(
                    canvas,
                    cx + pct_off + pct_chars as i32 * char_w,
                    cy,
                    "OFF",
                    dim_color,
                    s,
                );
            } else if total_us > 0.0 {
                let t = grid.layer_times_us[i];
                let pct = t / total_us * 100.0;
                // Value right-aligned in val column
                let val_s = format!("{:5.0}u", t);
                df::draw_str_right(
                    canvas,
                    cx + val_off + val_chars as i32 * char_w,
                    cy,
                    &val_s,
                    color,
                    s,
                );
                // Percent right-aligned in pct column
                let pct_s = format!("{:3.0}%", pct);
                df::draw_str_right(
                    canvas,
                    cx + pct_off + pct_chars as i32 * char_w,
                    cy,
                    &pct_s,
                    color,
                    s,
                );
            } else {
                df::draw_str_right(
                    canvas,
                    cx + pct_off + pct_chars as i32 * char_w,
                    cy,
                    "-",
                    color,
                    s,
                );
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{compose_preedit_display_text, parse_progress_percent};

    #[test]
    fn parse_progress_percent_treats_one_as_one_percent() {
        assert!((parse_progress_percent("1") - 0.01).abs() < 1e-6);
        assert!((parse_progress_percent("0.75") - 0.75).abs() < 1e-6);
        assert!((parse_progress_percent("75") - 0.75).abs() < 1e-6);
        assert!((parse_progress_percent("100") - 1.0).abs() < 1e-6);
    }

    #[test]
    fn compose_preedit_display_text_replaces_selected_text() {
        assert_eq!(compose_preedit_display_text("abcd", 0, 4, "우"), "우");
        assert_eq!(compose_preedit_display_text("abcd", 1, 3, "우"), "a우d");
        assert_eq!(compose_preedit_display_text("abcd", 4, 4, "우"), "abcd우");
    }
}
