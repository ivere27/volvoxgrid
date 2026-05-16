//! Shared types for external glyph rasterization.
//!
//! These are used by both the CPU `TextEngine` and the GPU `GlyphAtlas` to
//! fall back to a platform-native rasterizer (e.g. Canvas2D on WASM) when
//! SwashCache cannot produce a glyph.

use crate::debug_font;

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

const MAX_INTERNAL_FONT_SCALE: u32 = 8;

fn internal_font_scale(font_size: f32) -> u32 {
    let safe_size = if font_size.is_finite() && font_size > 0.0 {
        font_size
    } else {
        debug_font::GLYPH_H as f32
    };
    ((safe_size / debug_font::GLYPH_H as f32).round() as i32)
        .clamp(1, MAX_INTERNAL_FONT_SCALE as i32) as u32
}

fn tofu_label_scale(font_size: f32) -> u32 {
    let safe_size = if font_size.is_finite() && font_size > 0.0 {
        font_size
    } else {
        debug_font::GLYPH_H as f32
    };
    ((safe_size / 24.0).round() as i32).clamp(1, 4) as u32
}

fn codepoint_label(ch: char) -> String {
    let codepoint = ch as u32;
    if codepoint <= 0xFFFF {
        format!("{codepoint:04X}")
    } else {
        format!("{codepoint:X}")
    }
}

fn set_alpha(alpha: &mut [u8], width: u32, height: u32, x: u32, y: u32, value: u8) {
    if x < width && y < height {
        alpha[(y * width + x) as usize] = value;
    }
}

fn draw_internal_char(
    alpha: &mut [u8],
    width: u32,
    height: u32,
    x: u32,
    y: u32,
    ch: u8,
    scale: u32,
    bold: bool,
) {
    let idx = if (0x20..=0x7E).contains(&ch) {
        (ch - 0x20) as usize
    } else {
        (b'?' - 0x20) as usize
    };
    let glyph = &debug_font::FONT[idx];
    for row in 0..debug_font::GLYPH_H as u32 {
        let bits = glyph[row as usize];
        if bits == 0 {
            continue;
        }
        for col in 0..debug_font::GLYPH_W as u32 {
            if bits & (0x40 >> col) == 0 {
                continue;
            }
            let px = x + col * scale;
            let py = y + row * scale;
            for dy in 0..scale {
                for dx in 0..scale {
                    set_alpha(alpha, width, height, px + dx, py + dy, 0xFF);
                    if bold {
                        set_alpha(alpha, width, height, px + dx + 1, py + dy, 0xFF);
                    }
                }
            }
        }
    }
}

fn draw_internal_str(
    alpha: &mut [u8],
    width: u32,
    height: u32,
    x: u32,
    y: u32,
    text: &str,
    scale: u32,
    bold: bool,
) {
    let mut cx = x;
    let advance = debug_font::CELL_W as u32 * scale;
    for ch in text.bytes() {
        draw_internal_char(alpha, width, height, cx, y, ch, scale, bold);
        cx += advance;
    }
}

fn draw_rect_outline(alpha: &mut [u8], width: u32, height: u32, stroke: u32) {
    if width == 0 || height == 0 {
        return;
    }
    let stroke = stroke.max(1).min(width).min(height);
    for i in 0..stroke {
        for x in 0..width {
            set_alpha(alpha, width, height, x, i, 0xFF);
            set_alpha(alpha, width, height, x, height - 1 - i, 0xFF);
        }
        for y in 0..height {
            set_alpha(alpha, width, height, i, y, 0xFF);
            set_alpha(alpha, width, height, width - 1 - i, y, 0xFF);
        }
    }
}

fn internal_ascii_glyph(ch: char, font_size: f32, bold: bool) -> GlyphBitmap {
    let scale = internal_font_scale(font_size);
    let bold_extra = u32::from(bold);
    let width = debug_font::GLYPH_W as u32 * scale + bold_extra;
    let height = debug_font::GLYPH_H as u32 * scale;
    let advance = debug_font::CELL_W as f32 * scale as f32 + bold_extra as f32;
    let offset_y = ((debug_font::GLYPH_H - 2) as u32 * scale) as i32;

    let mut alpha_data = vec![0u8; (width * height) as usize];
    if ch != ' ' {
        draw_internal_char(&mut alpha_data, width, height, 0, 0, ch as u8, scale, bold);
    }

    GlyphBitmap {
        width,
        height,
        offset_x: 0,
        offset_y,
        alpha_data,
        advance_width: Some(advance),
    }
}

fn tofu_metrics(ch: char, font_size: f32) -> (String, u32, u32, u32, u32, u32) {
    let label = codepoint_label(ch);
    let label_scale = tofu_label_scale(font_size);
    let pad = 2 * label_scale;
    let label_w = label.len() as u32 * debug_font::CELL_W as u32 * label_scale;
    let label_h = debug_font::GLYPH_H as u32 * label_scale;
    let min_w = if font_size.is_finite() && font_size > 0.0 {
        (font_size * 0.85).ceil() as u32
    } else {
        label_w
    };
    let min_h = if font_size.is_finite() && font_size > 0.0 {
        font_size.ceil() as u32
    } else {
        label_h
    };
    let width = min_w.max(label_w + pad * 2).max(8);
    let height = min_h.max(label_h + pad * 2).max(8);
    (label, label_scale, pad, label_w, width, height)
}

fn tofu_glyph(ch: char, font_size: f32, bold: bool) -> GlyphBitmap {
    let (label, label_scale, pad, label_w, width, height) = tofu_metrics(ch, font_size);
    let mut alpha_data = vec![0u8; (width * height) as usize];
    draw_rect_outline(&mut alpha_data, width, height, label_scale);

    let label_h = debug_font::GLYPH_H as u32 * label_scale;
    let label_x = ((width - label_w) / 2).max(pad);
    let label_y = ((height - label_h) / 2).max(pad);
    draw_internal_str(
        &mut alpha_data,
        width,
        height,
        label_x,
        label_y,
        &label,
        label_scale,
        bold,
    );

    GlyphBitmap {
        width,
        height,
        offset_x: 0,
        offset_y: (height as f32 * 0.82).round() as i32,
        alpha_data,
        advance_width: Some(width as f32 + label_scale as f32),
    }
}

pub fn final_fallback_glyph_advance(ch: char, font_size: f32, bold: bool, _italic: bool) -> f32 {
    if ch.is_ascii() && !ch.is_ascii_control() {
        let scale = internal_font_scale(font_size);
        debug_font::CELL_W as f32 * scale as f32 + if bold { 1.0 } else { 0.0 }
    } else {
        let (_, label_scale, _, _, width, _) = tofu_metrics(ch, font_size);
        width as f32 + label_scale as f32
    }
}

pub fn final_fallback_line_height(font_size: f32) -> f32 {
    let scale = internal_font_scale(font_size);
    let bitmap_height = debug_font::CELL_H as f32 * scale as f32;
    let requested_height = if font_size.is_finite() && font_size > 0.0 {
        (font_size * 1.2).ceil()
    } else {
        bitmap_height
    };
    requested_height.max(bitmap_height)
}

pub fn measure_final_fallback_text(
    text: &str,
    font_size: f32,
    bold: bool,
    italic: bool,
    max_width: Option<f32>,
) -> (f32, f32) {
    if text.is_empty() {
        return (0.0, final_fallback_line_height(font_size));
    }

    let wrap_width = max_width.filter(|w| w.is_finite() && *w > 0.0);
    let line_height = final_fallback_line_height(font_size);
    let mut max_line_width: f32 = 0.0;
    let mut line_width: f32 = 0.0;
    let mut lines: u32 = 1;

    for ch in text.chars() {
        if ch == '\r' {
            continue;
        }
        if ch == '\n' {
            max_line_width = max_line_width.max(line_width);
            line_width = 0.0;
            lines += 1;
            continue;
        }

        let advance = final_fallback_glyph_advance(ch, font_size, bold, italic);
        if let Some(max_w) = wrap_width {
            if line_width > 0.0 && line_width + advance > max_w {
                max_line_width = max_line_width.max(line_width);
                line_width = 0.0;
                lines += 1;
            }
        }
        line_width += advance;
    }

    max_line_width = max_line_width.max(line_width);
    (max_line_width.ceil(), (lines as f32 * line_height).ceil())
}

pub fn rasterize_final_fallback_glyph(
    ch: char,
    font_size: f32,
    bold: bool,
    italic: bool,
) -> GlyphBitmap {
    let _ = italic;
    if ch.is_ascii() && !ch.is_ascii_control() {
        internal_ascii_glyph(ch, font_size, bold)
    } else {
        tofu_glyph(ch, font_size, bold)
    }
}

#[cfg(test)]
mod tests {
    use super::{
        final_fallback_glyph_advance, measure_final_fallback_text, rasterize_final_fallback_glyph,
    };

    #[test]
    fn ascii_fallback_renders_static_bitmap() {
        let glyph = rasterize_final_fallback_glyph('A', 14.0, false, false);
        assert!(glyph.width > 0);
        assert!(glyph.height > 0);
        assert!(glyph.alpha_data.iter().any(|&a| a != 0));
        assert!(glyph.advance_width.unwrap() >= glyph.width as f32);
    }

    #[test]
    fn tofu_fallback_contains_codepoint_pixels() {
        let glyph = rasterize_final_fallback_glyph('가', 14.0, false, false);
        assert!(glyph.width >= 32);
        assert!(glyph.height >= 17);
        assert!(glyph.alpha_data.iter().any(|&a| a != 0));
    }

    #[test]
    fn fallback_measure_wraps() {
        let single = final_fallback_glyph_advance('A', 14.0, false, false);
        let (_w, h) = measure_final_fallback_text("AAAA", 14.0, false, false, Some(single * 2.0));
        assert!(h > 14.0);
    }
}
