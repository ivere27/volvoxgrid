//! CPU pixel renderer for VolvoxGrid.
//!
//! Provides the `Renderer` struct which renders the grid model to an RGBA pixel
//! buffer. Actual rendering logic lives in `canvas.rs` (shared with the GPU
//! path); this module creates a `CpuCanvas` and delegates to `render_grid()`.

use crate::canvas::{render_grid, render_grid_partial, RenderResult};
use crate::canvas_cpu::CpuCanvas;
use crate::grid::VolvoxGrid;
use crate::scroll_cache::{ScrollCache, ScrollCacheState};
#[cfg(test)]
use crate::selection::HOVER_COLUMN;
use crate::text::{TextEngine, TextRenderer};

/// Full pixel renderer for VolvoxGrid.
///
/// Renders the grid model to an RGBA pixel buffer using the shared `Canvas`
/// trait pipeline. The buffer is typically a zero-copy shared memory region
/// provided by the platform shell via the `BufferReady` message.
pub struct Renderer {
    text_engine: TextEngine,
    custom_text_renderer: Option<Box<dyn TextRenderer + Send>>,
    scroll_cache: ScrollCache,
}

impl Renderer {
    pub fn new() -> Self {
        Self {
            text_engine: TextEngine::new(),
            custom_text_renderer: None,
            scroll_cache: ScrollCache::new(),
        }
    }

    /// Create a renderer with an externally-owned text engine.
    pub fn with_text_engine(text_engine: TextEngine) -> Self {
        Self {
            text_engine,
            custom_text_renderer: None,
            scroll_cache: ScrollCache::new(),
        }
    }

    /// Create a renderer with a custom text renderer.
    ///
    /// When set, the custom renderer handles all text measurement and rendering
    /// instead of the built-in cosmic-text engine.
    pub fn with_custom_text_renderer(custom: Box<dyn TextRenderer + Send>) -> Self {
        Self {
            text_engine: TextEngine::new(),
            custom_text_renderer: Some(custom),
            scroll_cache: ScrollCache::new(),
        }
    }

    /// Set or clear a custom text renderer.
    ///
    /// Pass `Some(renderer)` to use a platform-native text backend (GDI,
    /// Canvas2D, Skia, etc.), or `None` to revert to the default cosmic-text
    /// engine.
    pub fn set_custom_text_renderer(&mut self, custom: Option<Box<dyn TextRenderer + Send>>) {
        self.custom_text_renderer = custom;
    }

    /// Load font data (TTF/OTF/TTC) into the text engine.
    pub fn load_font_data(&mut self, data: Vec<u8>) {
        self.text_engine.load_font_data(data);
    }

    /// Register an external glyph rasterizer as a fallback for the CPU text
    /// engine when SwashCache cannot produce a glyph.
    pub fn set_external_glyph_rasterizer(
        &mut self,
        r: Box<dyn crate::glyph_rasterizer::ExternalGlyphRasterizer>,
    ) {
        self.text_engine.set_external_rasterizer(r);
    }

    /// Returns the number of entries currently in the text layout cache.
    pub fn text_cache_len(&self) -> usize {
        #[cfg(feature = "cosmic-text")]
        {
            self.text_engine.layout_cache.len()
        }
        #[cfg(not(feature = "cosmic-text"))]
        {
            0
        }
    }

    /// Main entry point: render the entire grid into the supplied RGBA buffer.
    ///
    /// `buffer` must be at least `stride * height` bytes.  `stride` is the
    /// number of bytes per row (typically `width * 4` for RGBA with no padding).
    ///
    /// Returns `RenderResult`: dirty rect, per-layer times (us), zone cell counts.
    pub fn render(
        &mut self,
        grid: &VolvoxGrid,
        buffer: &mut [u8],
        width: i32,
        height: i32,
        stride: i32,
    ) -> RenderResult {
        if width <= 0 || height <= 0 || buffer.len() < (stride * height) as usize {
            return ((0, 0, 0, 0), [0.0; crate::canvas::layer::COUNT], [0; 4]);
        }

        // Keep renderer-owned text cache policy in sync with runtime grid config.
        if self.text_engine.layout_cache_cap != grid.text_layout_cache_cap {
            self.text_engine
                .set_layout_cache_cap(grid.text_layout_cache_cap);
        }

        // Sync text rasterization options from current grid style.
        self.text_engine.set_render_options(
            grid.style.text_render_mode,
            grid.style.text_hinting_mode,
            grid.style.text_pixel_snap,
        );

        let text_renderer: &mut dyn TextRenderer = match self.custom_text_renderer.as_mut() {
            Some(custom) => &mut **custom,
            None => &mut self.text_engine,
        };

        let current_scroll_state = ScrollCacheState::snapshot(grid, width, height);
        let damage = self
            .scroll_cache
            .try_blit(buffer, stride, &current_scroll_state);
        let mut canvas = CpuCanvas::new(buffer, width, height, stride, text_renderer);
        let result = if let Some(damage) = damage.as_ref() {
            render_grid_partial(grid, &mut canvas, damage)
        } else {
            render_grid(grid, &mut canvas)
        };
        self.scroll_cache.finish(current_scroll_state);
        result
    }
}

impl Default for Renderer {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::indicator::ColIndicatorCellState;
    use crate::proto::volvoxgrid::v1 as pb;

    fn pixel_argb(buffer: &[u8], width: i32, x: i32, y: i32) -> u32 {
        let off = ((y * width + x) * 4) as usize;
        ((buffer[off + 3] as u32) << 24)
            | ((buffer[off] as u32) << 16)
            | ((buffer[off + 1] as u32) << 8)
            | (buffer[off + 2] as u32)
    }

    fn configure_mixed_depth_indicator_band(
        grid: &mut VolvoxGrid,
        back_color: u32,
        grid_color: u32,
    ) {
        grid.style.grid_lines = pb::GridLineStyle::GridlineNone as i32;
        grid.style.grid_lines_fixed = pb::GridLineStyle::GridlineNone as i32;
        for col in 0..grid.cols {
            grid.set_col_width(col, 60);
        }
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 2;
        grid.indicator_bands.col_top.default_row_height_px = 20;
        grid.indicator_bands.col_top.back_color = Some(back_color);
        grid.indicator_bands.col_top.grid_color = Some(grid_color);
        grid.indicator_bands.col_top.cells = vec![
            ColIndicatorCellState {
                row1: 1,
                row2: 1,
                col1: 0,
                col2: 0,
                text: "ID".to_string(),
                ..Default::default()
            },
            ColIndicatorCellState {
                row1: 1,
                row2: 1,
                col1: 1,
                col2: 1,
                text: "Name".to_string(),
                ..Default::default()
            },
            ColIndicatorCellState {
                row1: 0,
                row2: 0,
                col1: 0,
                col2: 1,
                text: "Identity".to_string(),
                ..Default::default()
            },
            ColIndicatorCellState {
                row1: 0,
                row2: 1,
                col1: 2,
                col2: 2,
                text: "Country".to_string(),
                ..Default::default()
            },
            ColIndicatorCellState {
                row1: 1,
                row2: 1,
                col1: 3,
                col2: 3,
                text: "Qty".to_string(),
                ..Default::default()
            },
            ColIndicatorCellState {
                row1: 1,
                row2: 1,
                col1: 4,
                col2: 4,
                text: "Amount".to_string(),
                ..Default::default()
            },
            ColIndicatorCellState {
                row1: 0,
                row2: 0,
                col1: 3,
                col2: 4,
                text: "Metrics".to_string(),
                ..Default::default()
            },
        ];
    }

    struct SolidTextRenderer;

    impl TextRenderer for SolidTextRenderer {
        fn measure_text(
            &mut self,
            text: &str,
            _font_name: &str,
            _font_size: f32,
            _bold: bool,
            _italic: bool,
            _max_width: Option<f32>,
        ) -> (f32, f32) {
            ((text.len().max(1) as f32) * 6.0, 8.0)
        }

        fn render_text(
            &mut self,
            buffer_pixels: &mut [u8],
            buf_width: i32,
            buf_height: i32,
            stride: i32,
            x: i32,
            y: i32,
            clip_x: i32,
            clip_y: i32,
            clip_w: i32,
            clip_h: i32,
            text: &str,
            _font_name: &str,
            _font_size: f32,
            _bold: bool,
            _italic: bool,
            color: u32,
            _max_width: Option<f32>,
        ) -> f32 {
            let draw_w = (text.len().max(1) as i32) * 6;
            let draw_h = 8;
            let x0 = x.max(clip_x).max(0);
            let y0 = y.max(clip_y).max(0);
            let x1 = (x + draw_w).min(clip_x + clip_w).min(buf_width);
            let y1 = (y + draw_h).min(clip_y + clip_h).min(buf_height);
            if x1 <= x0 || y1 <= y0 {
                return draw_w as f32;
            }

            let r = ((color >> 16) & 0xFF) as u8;
            let g = ((color >> 8) & 0xFF) as u8;
            let b = (color & 0xFF) as u8;
            let a = ((color >> 24) & 0xFF) as u8;
            for py in y0..y1 {
                for px in x0..x1 {
                    let off = (py * stride + px * 4) as usize;
                    buffer_pixels[off] = r;
                    buffer_pixels[off + 1] = g;
                    buffer_pixels[off + 2] = b;
                    buffer_pixels[off + 3] = a;
                }
            }
            draw_w as f32
        }
    }

    #[test]
    fn render_syncs_text_layout_cache_cap_from_grid() {
        let mut grid = VolvoxGrid::new(1, 320, 240, 2, 2, 1, 1);
        grid.text_layout_cache_cap = 256;

        let mut renderer = Renderer::new();
        assert_ne!(
            renderer.text_engine.layout_cache_cap,
            grid.text_layout_cache_cap
        );

        let mut buffer = vec![0u8; 4];
        renderer.render(&grid, &mut buffer, 1, 1, 4);

        assert_eq!(renderer.text_engine.layout_cache_cap, 256);
    }

    #[test]
    fn render_draws_data_text_with_top_indicator_without_row_resize() {
        let mut grid = VolvoxGrid::new(1, 120, 80, 1, 1, 0, 0);
        grid.cells.set_text(0, 0, "Hello".to_string());
        grid.columns[0].caption = "Value".to_string();
        grid.style.grid_lines = pb::GridLineStyle::GridlineNone as i32;
        grid.style.grid_lines_fixed = pb::GridLineStyle::GridlineNone as i32;
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.col_top.mode_bits =
            pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32;
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (120 * 80 * 4) as usize];
        renderer.render(&grid, &mut buffer, 120, 80, 120 * 4);

        let mut ink_pixels = 0usize;
        for py in 26..38 {
            for px in 4..50 {
                let off = ((py * 120 + px) * 4) as usize;
                let px_rgba = &buffer[off..off + 4];
                if px_rgba != [0xFF, 0xFF, 0xFF, 0xFF] {
                    ink_pixels += 1;
                }
            }
        }

        assert!(
            ink_pixels > 0,
            "data-cell text should render below the top indicator band before any row resize"
        );
    }

    #[test]
    fn render_highlights_selected_column_in_top_indicator_band() {
        let mut grid = VolvoxGrid::new(1, 220, 80, 4, 3, 0, 0);
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.col_top.mode_bits =
            pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32;
        grid.selection.selection_style.back_color = Some(0xFF224466);
        grid.selection.selection_style.fore_color = Some(0xFFFFFFFF);
        grid.selection
            .select(0, 1, grid.rows - 1, 1, grid.rows, grid.cols);
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (220 * 80 * 4) as usize];
        renderer.render(&grid, &mut buffer, 220, 80, 220 * 4);

        assert_eq!(pixel_argb(&buffer, 220, 72, 4), 0xFF224466);
    }

    #[test]
    fn render_col_indicator_keeps_vertical_boundary_aligned_with_data_cells() {
        let mut grid = VolvoxGrid::new(1, 180, 80, 2, 2, 0, 0);
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.col_top.grid_lines = Some(pb::GridLineStyle::GridlineSolid as i32);
        grid.indicator_bands.col_top.grid_color = Some(0xFF112233);
        grid.indicator_bands.col_top.back_color = Some(0xFFE0E0E0);
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (180 * 80 * 4) as usize];
        renderer.render(&grid, &mut buffer, 180, 80, 180 * 4);

        assert_eq!(pixel_argb(&buffer, 180, 67, 10), 0xFF112233);
        assert_eq!(pixel_argb(&buffer, 180, 68, 10), 0xFFE0E0E0);
    }

    #[test]
    fn render_highlights_hovered_column_in_top_indicator_band() {
        let mut grid = VolvoxGrid::new(1, 220, 80, 4, 3, 0, 0);
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.col_top.mode_bits =
            pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32;
        grid.selection.hover_mode = HOVER_COLUMN;
        grid.selection.hover_column_style.back_color = Some(0xFF557799);
        grid.mouse_row = -1;
        grid.mouse_col = 2;
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (220 * 80 * 4) as usize];
        renderer.render(&grid, &mut buffer, 220, 80, 220 * 4);

        assert_eq!(pixel_argb(&buffer, 220, 140, 4), 0xFF557799);
    }

    #[test]
    fn render_col_indicator_top_skips_internal_grid_lines_for_spanned_cells() {
        let back_color = 0xFFE0E0E0;
        let grid_color = 0xFF112233;
        let mut grid = VolvoxGrid::new(1, 300, 120, 1, 5, 0, 0);
        configure_mixed_depth_indicator_band(&mut grid, back_color, grid_color);
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (300 * 120 * 4) as usize];
        renderer.render(&grid, &mut buffer, 300, 120, 300 * 4);

        assert_eq!(pixel_argb(&buffer, 300, 120, 2), back_color);
        assert_eq!(pixel_argb(&buffer, 300, 60, 2), back_color);
        assert_eq!(pixel_argb(&buffer, 300, 60, 30), back_color);
        assert_eq!(pixel_argb(&buffer, 300, 125, 20), back_color);
        assert_eq!(pixel_argb(&buffer, 300, 10, 19), grid_color);
    }

    #[test]
    fn render_header_separator_skips_spanned_indicator_boundaries() {
        let back_color = 0xFFE0E0E0;
        let separator_color = 0xFF445566;
        let mut grid = VolvoxGrid::new(1, 300, 120, 1, 5, 0, 0);
        configure_mixed_depth_indicator_band(&mut grid, back_color, back_color);
        grid.style.header_separator.enabled = true;
        grid.style.header_separator.color = separator_color;
        grid.style.header_separator.height = crate::style::HeaderMarkHeight::Px(10);
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (300 * 120 * 4) as usize];
        renderer.render(&grid, &mut buffer, 300, 120, 300 * 4);

        assert_ne!(pixel_argb(&buffer, 300, 59, 5), separator_color);
        assert_eq!(pixel_argb(&buffer, 300, 59, 30), separator_color);
        assert_eq!(pixel_argb(&buffer, 300, 119, 5), separator_color);
        assert_eq!(pixel_argb(&buffer, 300, 119, 30), separator_color);
    }

    #[test]
    fn render_header_separator_stays_on_column_boundary_when_scroll_row_changes() {
        let back_color = 0xFFE0E0E0;
        let separator_color = 0xFF445566;
        let mut grid = VolvoxGrid::new(1, 180, 80, 6, 3, 0, 0);
        grid.style.grid_lines = pb::GridLineStyle::GridlineNone as i32;
        grid.style.grid_lines_fixed = pb::GridLineStyle::GridlineNone as i32;
        for row in 0..grid.rows {
            grid.set_row_height(row, 20);
        }
        for col in 0..grid.cols {
            grid.set_col_width(col, 60);
        }
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.col_top.back_color = Some(back_color);
        grid.indicator_bands.col_top.grid_color = Some(back_color);
        grid.style.header_separator.enabled = true;
        grid.style.header_separator.color = separator_color;
        grid.style.header_separator.height = crate::style::HeaderMarkHeight::Px(12);
        grid.merged_regions.add_merge(0, 0, 0, 1);
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut top_row_merged = vec![0u8; (180 * 80 * 4) as usize];
        renderer.render(&grid, &mut top_row_merged, 180, 80, 180 * 4);

        grid.scroll.scroll_y = 20.0;
        let mut next_row_visible = vec![0u8; (180 * 80 * 4) as usize];
        renderer.render(&grid, &mut next_row_visible, 180, 80, 180 * 4);

        assert_eq!(pixel_argb(&top_row_merged, 180, 59, 12), separator_color);
        assert_eq!(pixel_argb(&next_row_visible, 180, 59, 12), separator_color);
    }

    #[test]
    fn render_grouped_header_sort_glyph_uses_leaf_header_row() {
        let back_color = 0xFFE0E0E0;
        let mut grid = VolvoxGrid::new(1, 300, 120, 1, 5, 0, 0);
        configure_mixed_depth_indicator_band(&mut grid, back_color, back_color);
        grid.header_features = 1;
        grid.sort_state
            .sort_keys
            .push((2, crate::sort::SORT_DESCENDING_AUTO));
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (300 * 120 * 4) as usize];
        renderer.render(&grid, &mut buffer, 300, 120, 300 * 4);

        let mut top_ink = 0usize;
        let mut bottom_ink = 0usize;
        for y in 2..16 {
            for x in 162..176 {
                if pixel_argb(&buffer, 300, x, y) != back_color {
                    top_ink += 1;
                }
            }
        }
        for y in 22..36 {
            for x in 162..176 {
                if pixel_argb(&buffer, 300, x, y) != back_color {
                    bottom_ink += 1;
                }
            }
        }

        assert_eq!(top_ink, 0);
        assert!(bottom_ink > 0);
    }

    #[test]
    fn render_highlights_selected_row_in_row_indicator_band() {
        let mut grid = VolvoxGrid::new(1, 180, 80, 4, 3, 0, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 40;
        grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;
        grid.selection.selection_style.back_color = Some(0xFF335577);
        grid.selection.selection_style.fore_color = Some(0xFFFFFFFF);
        grid.selection
            .select(1, 0, 1, grid.cols - 1, grid.rows, grid.cols);
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (180 * 80 * 4) as usize];
        renderer.render(&grid, &mut buffer, 180, 80, 180 * 4);

        assert_eq!(pixel_argb(&buffer, 180, 4, 24), 0xFF335577);
    }

    #[test]
    fn render_row_indicator_keeps_separator_line_when_selected() {
        let mut grid = VolvoxGrid::new(1, 180, 80, 4, 3, 0, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 40;
        grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;
        grid.indicator_bands.row_start.grid_color = Some(0xFF112233);
        grid.selection.selection_style.back_color = Some(0xFF335577);
        grid.selection
            .select(1, 0, 1, grid.cols - 1, grid.rows, grid.cols);
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (180 * 80 * 4) as usize];
        renderer.render(&grid, &mut buffer, 180, 80, 180 * 4);

        assert_eq!(pixel_argb(&buffer, 180, 4, 19), 0xFF112233);
    }

    #[test]
    fn render_row_indicator_keeps_separator_line_with_merged_data_cells() {
        let mut grid = VolvoxGrid::new(1, 180, 80, 4, 3, 0, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 40;
        grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;
        grid.indicator_bands.row_start.grid_color = Some(0xFF112233);
        grid.cells.set_text(0, 0, "North".to_string());
        grid.cells.set_text(1, 0, "North".to_string());
        grid.cells.set_text(2, 0, "South".to_string());
        grid.cells.set_text(0, 1, "A".to_string());
        grid.cells.set_text(1, 1, "B".to_string());
        grid.cells.set_text(2, 1, "C".to_string());
        grid.merged_regions.add_merge(0, 0, 1, 0);
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (180 * 80 * 4) as usize];
        renderer.render(&grid, &mut buffer, 180, 80, 180 * 4);

        assert_eq!(pixel_argb(&buffer, 180, 4, 19), 0xFF112233);
    }

    #[test]
    fn render_corner_top_start_uses_same_bottom_border_as_col_indicator() {
        let mut grid = VolvoxGrid::new(1, 180, 80, 2, 2, 0, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 40;
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.col_top.grid_color = Some(0xFF112233);
        grid.indicator_bands.col_top.back_color = Some(0xFFE0E0E0);
        grid.indicator_bands.corner_top_start.visible = true;
        grid.selection.allow_selection = false;
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (180 * 80 * 4) as usize];
        renderer.render(&grid, &mut buffer, 180, 80, 180 * 4);

        assert_eq!(pixel_argb(&buffer, 180, 4, 23), 0xFF112233);
        assert_eq!(pixel_argb(&buffer, 180, 4, 22), 0xFFE0E0E0);
    }

    #[test]
    fn render_corner_top_start_has_no_glyph_when_feature_disabled() {
        let mut grid = VolvoxGrid::new(1, 180, 80, 2, 2, 0, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 40;
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.col_top.back_color = Some(0xFFE0E0E0);
        grid.selection.allow_selection = true;
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (180 * 80 * 4) as usize];
        renderer.render(&grid, &mut buffer, 180, 80, 180 * 4);

        assert_eq!(pixel_argb(&buffer, 180, 20, 12), 0xFFE0E0E0);
    }

    #[test]
    fn render_frozen_column_separator_offsets_by_row_indicator_width() {
        let mut grid = VolvoxGrid::new(1, 200, 80, 4, 3, 0, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 40;
        grid.frozen_cols = 1;
        grid.selection.allow_selection = false;
        grid.selection.focus_border = pb::FocusBorderStyle::FocusBorderNone as i32;
        grid.selection.selection_visibility = pb::SelectionVisibility::SelectionVisNone as i32;
        grid.ensure_layout();

        let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut buffer = vec![0u8; (200 * 80 * 4) as usize];
        renderer.render(&grid, &mut buffer, 200, 80, 200 * 4);

        // Frozen inset separator is offset by the 40px row indicator band:
        // indicator width (40) + first column width (68) = 108.
        // In inset mode the dark edge is drawn at x-1 and the light edge at x.
        assert_eq!(pixel_argb(&buffer, 200, 107, 10), 0xFF828282);
        assert_eq!(pixel_argb(&buffer, 200, 108, 10), 0xFFFFFFFF);
        assert_ne!(pixel_argb(&buffer, 200, 68, 10), 0xFF828282);
    }

    fn scroll_blit_test_grid(scroll_blit_enabled: bool) -> VolvoxGrid {
        let mut grid = VolvoxGrid::new(1, 320, 220, 40, 12, 1, 1);
        grid.scroll_blit_enabled = scroll_blit_enabled;
        grid.scroll_bars = pb::ScrollBarsMode::ScrollbarBoth as i32;
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 36;
        grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.col_top.mode_bits =
            pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32;

        for row in 0..grid.rows {
            grid.set_row_height(row, 20 + (row % 3) * 4);
            for col in 0..grid.cols {
                grid.cells.set_text(row, col, format!("R{row}C{col}"));
            }
        }
        for col in 0..grid.cols {
            grid.set_col_width(col, 56 + (col % 4) * 8);
        }
        grid.ensure_layout();
        grid
    }

    #[test]
    fn scroll_blit_matches_full_render_after_diagonal_scroll() {
        let mut blit_grid = scroll_blit_test_grid(true);
        let mut blit_renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut blit_buffer = vec![0u8; (320 * 220 * 4) as usize];
        blit_renderer.render(&blit_grid, &mut blit_buffer, 320, 220, 320 * 4);
        let seeded_buffer = blit_buffer.clone();

        blit_grid.scroll.scroll_x = 17.0;
        blit_grid.scroll.scroll_y = 29.0;
        blit_renderer.render(&blit_grid, &mut blit_buffer, 320, 220, 320 * 4);

        let mut full_grid = scroll_blit_test_grid(false);
        full_grid.scroll.scroll_x = 17.0;
        full_grid.scroll.scroll_y = 29.0;
        let mut full_renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
        let mut full_buffer = vec![0u8; (320 * 220 * 4) as usize];
        full_renderer.render(&full_grid, &mut full_buffer, 320, 220, 320 * 4);

        if let Some(idx) = blit_buffer
            .iter()
            .zip(full_buffer.iter())
            .position(|(left, right)| left != right)
        {
            let pixel = idx / 4;
            let x = (pixel % 320) as i32;
            let y = (pixel / 320) as i32;
            let source_right = pixel_argb(&seeded_buffer, 320, (x + 17).min(319), y);
            let source_left = pixel_argb(&seeded_buffer, 320, (x - 17).max(0), y);
            let source_diag = pixel_argb(&seeded_buffer, 320, (x + 17).min(319), (y + 29).min(219));
            panic!(
                "scroll blit mismatch at ({x}, {y}): got {:02X?}, expected {:02X?}, seeded {:02X?}, seeded_right=0x{source_right:08X}, seeded_left=0x{source_left:08X}, seeded_diag=0x{source_diag:08X}",
                &blit_buffer[idx - (idx % 4)..idx - (idx % 4) + 4],
                &full_buffer[idx - (idx % 4)..idx - (idx % 4) + 4],
                &seeded_buffer[idx - (idx % 4)..idx - (idx % 4) + 4],
            );
        }
    }
}
