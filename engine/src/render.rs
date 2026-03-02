//! CPU pixel renderer for VolvoxGrid.
//!
//! Provides the `Renderer` struct which renders the grid model to an RGBA pixel
//! buffer. Actual rendering logic lives in `canvas.rs` (shared with the GPU
//! path); this module creates a `CpuCanvas` and delegates to `render_grid()`.

use crate::canvas::render_grid;
use crate::canvas_cpu::CpuCanvas;
use crate::grid::VolvoxGrid;
use crate::text::{TextEngine, TextRenderer};

/// Full pixel renderer for VolvoxGrid.
///
/// Renders the grid model to an RGBA pixel buffer using the shared `Canvas`
/// trait pipeline. The buffer is typically a zero-copy shared memory region
/// provided by the platform shell via the `BufferReady` message.
pub struct Renderer {
    text_engine: TextEngine,
    custom_text_renderer: Option<Box<dyn TextRenderer + Send>>,
}

impl Renderer {
    pub fn new() -> Self {
        Self {
            text_engine: TextEngine::new(),
            custom_text_renderer: None,
        }
    }

    /// Create a renderer with an externally-owned text engine.
    pub fn with_text_engine(text_engine: TextEngine) -> Self {
        Self {
            text_engine,
            custom_text_renderer: None,
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
    /// Returns a dirty rect `(x, y, w, h)` describing the region that was
    /// painted.  Currently the entire viewport is always repainted.
    pub fn render(
        &mut self,
        grid: &VolvoxGrid,
        buffer: &mut [u8],
        width: i32,
        height: i32,
        stride: i32,
    ) -> (i32, i32, i32, i32) {
        if width <= 0 || height <= 0 || buffer.len() < (stride * height) as usize {
            return (0, 0, 0, 0);
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

        let mut canvas = CpuCanvas::new(buffer, width, height, stride, text_renderer);
        render_grid(grid, &mut canvas)
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

    #[test]
    fn render_syncs_text_layout_cache_cap_from_grid() {
        let mut grid = VolvoxGrid::new(1, 320, 240, 2, 2, 1, 1);
        grid.text_layout_cache_cap = 256;

        let mut renderer = Renderer::new();
        assert_ne!(renderer.text_engine.layout_cache_cap, grid.text_layout_cache_cap);

        let mut buffer = vec![0u8; 4];
        renderer.render(&grid, &mut buffer, 1, 1, 4);

        assert_eq!(renderer.text_engine.layout_cache_cap, 256);
    }
}
