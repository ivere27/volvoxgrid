//! Shared types for external glyph rasterization.
//!
//! These are used by both the CPU `TextEngine` and the GPU `GlyphAtlas` to
//! fall back to a platform-native rasterizer (e.g. Canvas2D on WASM) when
//! SwashCache cannot produce a glyph.

/// Rasterized glyph bitmap returned by an external rasterizer.
pub struct GlyphBitmap {
    pub width: u32,
    pub height: u32,
    /// Horizontal bearing (pixels from glyph origin to left edge of bitmap).
    pub offset_x: i32,
    /// Vertical bearing (pixels from baseline to top edge of bitmap).
    pub offset_y: i32,
    /// Alpha-only (R8) pixel data, row-major, `width * height` bytes.
    pub alpha_data: Vec<u8>,
    /// Advance width for cursor positioning (pixels).
    /// When `Some`, this is the true advance from the platform rasterizer.
    /// When `None`, `width` is used as the advance.
    pub advance_width: Option<f32>,
}

/// Trait for external glyph rasterization when SwashCache cannot produce a glyph
/// (e.g. missing font on WASM). Implementations must be `Send` so the atlas can
/// live in a `Send` context, but actual calls happen on the render thread.
pub trait ExternalGlyphRasterizer: Send {
    fn rasterize_glyph(
        &mut self,
        character: char,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
    ) -> Option<GlyphBitmap>;
}
