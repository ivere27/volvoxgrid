//! GPU canvas backend — accumulates instanced quads for wgpu rendering.
//!
//! Implements the `Canvas` trait by pushing `RectInstance` and
//! `TexturedInstance` data that the GPU renderer later uploads and draws
//! in a single batched render pass.

use crate::canvas::{adjusted_text_max_width, normalize_font_stretch_scale, Canvas};
use std::hash::{Hash, Hasher};

use crate::glyph_atlas::{layout_text_glyphs, GlyphAtlas, GlyphEntry};
use crate::gpu_render::{RectInstance, TexturedInstance};
use crate::text::TextEngine;

/// Compute a u64 hash for glyph position cache lookup.
/// Note: max_width is intentionally excluded — glyph x/y offsets are
/// laid out relative to (0,0) and don't depend on wrap width.
fn glyph_cache_hash(text: &str, font_name: &str, font_size: f32, bold: bool, italic: bool) -> u64 {
    let mut h = std::hash::DefaultHasher::new();
    text.hash(&mut h);
    font_name.hash(&mut h);
    font_size.to_bits().hash(&mut h);
    bold.hash(&mut h);
    italic.hash(&mut h);
    h.finish()
}

/// Convert a packed 0xAARRGGBB color to normalized `[r, g, b, a]`.
fn color_to_f32(c: u32) -> [f32; 4] {
    let a = ((c >> 24) & 0xFF) as f32 / 255.0;
    let r = ((c >> 16) & 0xFF) as f32 / 255.0;
    let g = ((c >> 8) & 0xFF) as f32 / 255.0;
    let b = (c & 0xFF) as f32 / 255.0;
    [r, g, b, a]
}

/// GPU-side canvas that accumulates instanced draw data.
pub struct GpuCanvas<'a> {
    rect_instances: &'a mut Vec<RectInstance>,
    textured_instances: &'a mut Vec<TexturedInstance>,
    overlay_rect_instances: &'a mut Vec<RectInstance>,
    overlay_textured_instances: &'a mut Vec<TexturedInstance>,
    glyph_atlas: &'a mut GlyphAtlas,
    text_engine: &'a mut TextEngine,
    glyph_buf: &'a mut Vec<(GlyphEntry, f32, f32)>,
    glyph_pos_cache: &'a mut hashbrown::HashMap<u64, Vec<(GlyphEntry, f32, f32)>>,
    vp_width: i32,
    vp_height: i32,
    overlay_mode: bool,
}

impl<'a> GpuCanvas<'a> {
    /// Create a new GPU canvas that pushes instances into the supplied vectors.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        rect_instances: &'a mut Vec<RectInstance>,
        textured_instances: &'a mut Vec<TexturedInstance>,
        overlay_rect_instances: &'a mut Vec<RectInstance>,
        overlay_textured_instances: &'a mut Vec<TexturedInstance>,
        glyph_atlas: &'a mut GlyphAtlas,
        text_engine: &'a mut TextEngine,
        glyph_buf: &'a mut Vec<(GlyphEntry, f32, f32)>,
        glyph_pos_cache: &'a mut hashbrown::HashMap<u64, Vec<(GlyphEntry, f32, f32)>>,
        vp_width: i32,
        vp_height: i32,
    ) -> Self {
        Self {
            rect_instances,
            textured_instances,
            overlay_rect_instances,
            overlay_textured_instances,
            glyph_atlas,
            text_engine,
            glyph_buf,
            glyph_pos_cache,
            vp_width,
            vp_height,
            overlay_mode: false,
        }
    }

    /// Get current rect instance target (main or overlay).
    fn rects(&mut self) -> &mut Vec<RectInstance> {
        if self.overlay_mode {
            self.overlay_rect_instances
        } else {
            self.rect_instances
        }
    }

    /// Get current textured instance target (main or overlay).
    fn texts(&mut self) -> &mut Vec<TexturedInstance> {
        if self.overlay_mode {
            self.overlay_textured_instances
        } else {
            self.textured_instances
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn draw_text_internal(
        &mut self,
        x: i32,
        y: i32,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        stretch: f32,
        color: u32,
        clip_x: i32,
        clip_y: i32,
        clip_w: i32,
        clip_h: i32,
        max_width: Option<f32>,
    ) -> f32 {
        if text.is_empty() || clip_w <= 0 || clip_h <= 0 || !self.text_engine.has_fonts() {
            return 0.0;
        }

        let scale = normalize_font_stretch_scale(stretch);
        let adjusted_max_width = adjusted_text_max_width(max_width, stretch);

        let cache_key = glyph_cache_hash(text, font_name, font_size, bold, italic);
        if let Some(cached) = self.glyph_pos_cache.get(&cache_key) {
            self.glyph_buf.clear();
            self.glyph_buf.extend_from_slice(cached);
        } else {
            let layout_res = crate::text::TextEngine::get_or_shape_buffer(
                &mut self.text_engine.layout_cache,
                &mut self.text_engine.layout_fifo,
                self.text_engine.layout_cache_cap,
                &mut self.text_engine.font_system,
                text,
                font_name,
                font_size,
                bold,
                italic,
                adjusted_max_width,
            );
            let buffer = if let Some(r) = &layout_res {
                &r.layout().buffer
            } else {
                return 0.0;
            };

            let font_system = &mut self.text_engine.font_system;
            let swash_cache = &mut self.text_engine.swash_cache;

            layout_text_glyphs(
                self.glyph_atlas,
                font_system,
                swash_cache,
                buffer,
                text,
                font_name,
                font_size,
                bold,
                italic,
                0.0,
                0.0,
                &mut *self.glyph_buf,
            );

            if self.glyph_pos_cache.len() >= 8192 {
                self.glyph_pos_cache.clear();
            }
            self.glyph_pos_cache
                .insert(cache_key, self.glyph_buf.clone());
        }

        let color_f32 = color_to_f32(color);
        let mut rendered_width: f32 = 0.0;
        let clip_x_max = clip_x as f32 + clip_w as f32;
        let clip_y_max = y as f32 + clip_h as f32;
        let clip_x_min = clip_x as f32;
        let clip_y_min = (clip_y.max(0)) as f32;
        let xf = x as f32;
        let yf = y as f32;

        for i in 0..self.glyph_buf.len() {
            let (entry, dx, dy) = self.glyph_buf[i];
            rendered_width = rendered_width.max((dx + entry.width as f32) * scale);
            if entry.width == 0 || entry.height == 0 {
                continue;
            }

            let gx = xf + dx * scale;
            let gy = yf + dy;
            let gw = entry.width as f32 * scale;
            let gh = entry.height as f32;

            let inst = if gx >= clip_x_min
                && gy >= clip_y_min
                && gx + gw <= clip_x_max
                && gy + gh <= clip_y_max
            {
                TexturedInstance {
                    rect: [gx, gy, gw, gh],
                    uv_rect: entry.uv,
                    color: color_f32,
                    flags: [0.0, entry.page as f32],
                }
            } else {
                let left = gx.max(clip_x_min);
                let top = gy.max(clip_y_min);
                let right = (gx + gw).min(clip_x_max);
                let bottom = (gy + gh).min(clip_y_max);

                if left >= right || top >= bottom {
                    continue;
                }

                let u_min = entry.uv[0];
                let v_min = entry.uv[1];
                let u_max = entry.uv[2];
                let v_max = entry.uv[3];
                let u_range = u_max - u_min;
                let v_range = v_max - v_min;

                let new_u_min = u_min + u_range * ((left - gx) / gw);
                let new_v_min = v_min + v_range * ((top - gy) / gh);
                let new_u_max = u_max - u_range * ((gx + gw - right) / gw);
                let new_v_max = v_max - v_range * ((gy + gh - bottom) / gh);

                TexturedInstance {
                    rect: [left, top, right - left, bottom - top],
                    uv_rect: [new_u_min, new_v_min, new_u_max, new_v_max],
                    color: color_f32,
                    flags: [0.0, entry.page as f32],
                }
            };
            self.texts().push(inst);
        }

        rendered_width
    }
}

impl<'a> Canvas for GpuCanvas<'a> {
    fn width(&self) -> i32 {
        self.vp_width
    }

    fn height(&self) -> i32 {
        self.vp_height
    }

    fn begin_overlay(&mut self) {
        self.overlay_mode = true;
    }

    fn end_overlay(&mut self) {
        self.overlay_mode = false;
    }

    fn fill_rect(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        if w <= 0 || h <= 0 {
            return;
        }
        let inst = RectInstance {
            rect: [x as f32, y as f32, w as f32, h as f32],
            color: color_to_f32(color),
            pattern: [0.0, 0.0], // solid
        };
        self.rects().push(inst);
    }

    fn blend_rect(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        // GPU blending is handled by the pipeline blend state, so we just push
        // the rect with its alpha.  The wgpu blend mode (SrcAlpha,
        // OneMinusSrcAlpha) composites correctly.
        self.fill_rect(x, y, w, h, color);
    }

    fn hline(&mut self, x: i32, y: i32, w: i32, color: u32) {
        self.fill_rect(x, y, w, 1, color);
    }

    fn vline(&mut self, x: i32, y: i32, h: i32, color: u32) {
        self.fill_rect(x, y, 1, h, color);
    }

    fn set_pixel(&mut self, x: i32, y: i32, color: u32) {
        self.fill_rect(x, y, 1, 1, color);
    }

    fn draw_bitmap_char(&mut self, x: i32, y: i32, ch: u8, color: u32, scale: i32) -> i32 {
        self.glyph_atlas.ensure_bitmap_font(scale);
        if let Some(entry) = self.glyph_atlas.bitmap_glyph(ch) {
            let inst = TexturedInstance {
                rect: [x as f32, y as f32, entry.width as f32, entry.height as f32],
                uv_rect: entry.uv,
                color: color_to_f32(color),
                flags: [0.0, entry.page as f32],
            };
            self.texts().push(inst);
        }
        crate::debug_font::CELL_W * scale
    }

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
    ) -> f32 {
        self.draw_text_internal(
            x, y, text, font_name, font_size, bold, italic, 0.0, color, clip_x, clip_y, clip_w,
            clip_h, max_width,
        )
    }

    fn draw_text_stretched(
        &mut self,
        x: i32,
        y: i32,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        stretch: f32,
        color: u32,
        clip_x: i32,
        clip_y: i32,
        clip_w: i32,
        clip_h: i32,
        max_width: Option<f32>,
    ) -> f32 {
        self.draw_text_internal(
            x, y, text, font_name, font_size, bold, italic, stretch, color, clip_x, clip_y, clip_w,
            clip_h, max_width,
        )
    }

    fn measure_text(
        &mut self,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> (f32, f32) {
        // Use the shared TextEngine for measurement — identical to CPU path.
        self.text_engine
            .measure_text(text, font_name, font_size, bold, italic, max_width)
    }

    fn measure_text_stretched(
        &mut self,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        stretch: f32,
        max_width: Option<f32>,
    ) -> (f32, f32) {
        let scale = normalize_font_stretch_scale(stretch);
        let (w, h) = self.text_engine.measure_text(
            text,
            font_name,
            font_size,
            bold,
            italic,
            adjusted_text_max_width(max_width, stretch),
        );
        (w * scale, h)
    }

    fn blit_image(
        &mut self,
        _dx: i32,
        _dy: i32,
        _dw: i32,
        _dh: i32,
        _data: &[u8],
        _iw: i32,
        _ih: i32,
    ) {
        // Image blitting not yet implemented for GPU canvas.
        // Cell pictures and background image will be skipped in GPU mode.
    }

    fn blit_image_at(&mut self, _dx: i32, _dy: i32, _data: &[u8], _iw: i32, _ih: i32) {
        // Image blitting not yet implemented for GPU canvas.
    }

    fn fill_checker(&mut self, x: i32, y: i32, w: i32, h: i32) {
        // Approximate the checker pattern with a solid mid-gray for GPU.
        self.fill_rect(x, y, w, h, 0xFFD5D5D5);
    }
}
