//! CPU canvas backend — renders to an RGBA pixel buffer.
//!
//! Implements the `Canvas` trait by delegating each drawing primitive to
//! existing pixel-level helpers in `render.rs`.  The buffer is typically a
//! shared-memory region provided by the platform shell.

use crate::canvas::Canvas;
use crate::text::TextRenderer;

/// CPU-side canvas that writes directly to an RGBA pixel buffer.
pub struct CpuCanvas<'a> {
    buf: &'a mut [u8],
    width: i32,
    height: i32,
    stride: i32,
    text_renderer: &'a mut dyn TextRenderer,
}

impl<'a> CpuCanvas<'a> {
    /// Wrap an externally owned pixel buffer + text renderer as a `CpuCanvas`.
    ///
    /// `stride` is the number of bytes per row (typically `width * 4`).
    pub fn new(
        buf: &'a mut [u8],
        width: i32,
        height: i32,
        stride: i32,
        text_renderer: &'a mut dyn TextRenderer,
    ) -> Self {
        Self {
            buf,
            width,
            height,
            stride,
            text_renderer,
        }
    }

    fn clip_span(start: i32, len: i32, limit: i32) -> Option<(usize, usize)> {
        if limit <= 0 {
            return None;
        }
        let clipped_start = start.clamp(0, limit);
        let clipped_end = start.saturating_add(len).clamp(0, limit);
        if clipped_start >= clipped_end {
            None
        } else {
            Some((clipped_start as usize, clipped_end as usize))
        }
    }

    fn clip_rect(&self, x: i32, y: i32, w: i32, h: i32) -> Option<(usize, usize, usize, usize)> {
        let (x0, x1) = Self::clip_span(x, w, self.width)?;
        let (y0, y1) = Self::clip_span(y, h, self.height)?;
        Some((x0, y0, x1, y1))
    }
}

impl<'a> Canvas for CpuCanvas<'a> {
    fn width(&self) -> i32 {
        self.width
    }

    fn height(&self) -> i32 {
        self.height
    }

    fn fill_rect(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        let Some((x0, y0, x1, y1)) = self.clip_rect(x, y, w, h) else {
            return;
        };

        let stride = self.stride as usize;
        let pixel = color.to_ne_bytes(); // ARGB → native byte order
                                         // We store RGBA in the buffer, so rearrange:
        let rgba = [
            ((color >> 16) & 0xFF) as u8,
            ((color >> 8) & 0xFF) as u8,
            (color & 0xFF) as u8,
            ((color >> 24) & 0xFF) as u8,
        ];
        let _ = pixel;

        let row_bytes = (x1 - x0) * 4;
        let first_row_start = y0 * stride + x0 * 4;
        let first_row_end = first_row_start + row_bytes;

        if first_row_end > self.buf.len() {
            return;
        }

        // Fill first row pixel-by-pixel
        for chunk in self.buf[first_row_start..first_row_end].chunks_exact_mut(4) {
            chunk.copy_from_slice(&rgba);
        }

        // Copy first row to remaining rows
        for py in (y0 + 1)..y1 {
            let dst_start = py * stride + x0 * 4;
            let dst_end = dst_start + row_bytes;
            if dst_end > self.buf.len() {
                break;
            }
            self.buf
                .copy_within(first_row_start..first_row_end, dst_start);
        }
    }

    fn blend_rect(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        let src_a = ((color >> 24) & 0xFF) as u32;

        if src_a == 0 {
            return;
        }
        if src_a == 255 {
            self.fill_rect(x, y, w, h, color);
            return;
        }

        let src_r = ((color >> 16) & 0xFF) as u32;
        let src_g = ((color >> 8) & 0xFF) as u32;
        let src_b = (color & 0xFF) as u32;
        let inv_a = 255 - src_a;

        let Some((x0, y0, x1, y1)) = self.clip_rect(x, y, w, h) else {
            return;
        };

        let stride = self.stride as usize;
        let row_bytes = (x1 - x0) * 4;

        for py in y0..y1 {
            let row_start = py * stride + x0 * 4;
            let row_end = row_start + row_bytes;
            if row_end > self.buf.len() {
                break;
            }
            for chunk in self.buf[row_start..row_end].chunks_exact_mut(4) {
                let dr = chunk[0] as u32;
                let dg = chunk[1] as u32;
                let db = chunk[2] as u32;
                chunk[0] = ((src_r * src_a + dr * inv_a + 127) / 255) as u8;
                chunk[1] = ((src_g * src_a + dg * inv_a + 127) / 255) as u8;
                chunk[2] = ((src_b * src_a + db * inv_a + 127) / 255) as u8;
                chunk[3] = 255;
            }
        }
    }

    fn hline(&mut self, x: i32, y: i32, w: i32, color: u32) {
        if y < 0 || y >= self.height || w <= 0 {
            return;
        }
        let rgba = [
            ((color >> 16) & 0xFF) as u8,
            ((color >> 8) & 0xFF) as u8,
            (color & 0xFF) as u8,
            ((color >> 24) & 0xFF) as u8,
        ];
        let Some((x0, x1)) = Self::clip_span(x, w, self.width) else {
            return;
        };
        let start = y as usize * self.stride as usize + x0 * 4;
        let end = start + (x1 - x0) * 4;
        if end > self.buf.len() {
            return;
        }
        for chunk in self.buf[start..end].chunks_exact_mut(4) {
            chunk.copy_from_slice(&rgba);
        }
    }

    fn vline(&mut self, x: i32, y: i32, h: i32, color: u32) {
        let px = x;
        if px < 0 || px >= self.width {
            return;
        }
        let r = ((color >> 16) & 0xFF) as u8;
        let g = ((color >> 8) & 0xFF) as u8;
        let b = (color & 0xFF) as u8;
        let a = ((color >> 24) & 0xFF) as u8;
        let y0 = y.max(0);
        let y1 = (y + h).min(self.height);
        for py in y0..y1 {
            let off = (py * self.stride + px * 4) as usize;
            if off + 3 < self.buf.len() {
                self.buf[off] = r;
                self.buf[off + 1] = g;
                self.buf[off + 2] = b;
                self.buf[off + 3] = a;
            }
        }
    }

    fn set_pixel(&mut self, x: i32, y: i32, color: u32) {
        if x < 0 || y < 0 || x >= self.width || y >= self.height {
            return;
        }
        let off = (y * self.stride + x * 4) as usize;
        if off + 3 < self.buf.len() {
            self.buf[off] = ((color >> 16) & 0xFF) as u8;
            self.buf[off + 1] = ((color >> 8) & 0xFF) as u8;
            self.buf[off + 2] = (color & 0xFF) as u8;
            self.buf[off + 3] = ((color >> 24) & 0xFF) as u8;
        }
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
        self.text_renderer.render_text(
            self.buf,
            self.width,
            self.height,
            self.stride,
            x,
            y,
            clip_x,
            clip_y,
            clip_w,
            clip_h,
            text,
            font_name,
            font_size,
            bold,
            italic,
            color,
            max_width,
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
        self.text_renderer
            .measure_text(text, font_name, font_size, bold, italic, max_width)
    }

    fn blit_image(
        &mut self,
        dx: i32,
        dy: i32,
        dw: i32,
        dh: i32,
        src: &[u8],
        src_w: i32,
        src_h: i32,
    ) {
        if dw <= 0 || dh <= 0 || src_w <= 0 || src_h <= 0 {
            return;
        }
        for py in 0..dh {
            let by = dy + py;
            if by < 0 || by >= self.height {
                continue;
            }
            let sy = ((py as i64 * src_h as i64) / dh as i64) as i32;
            for px in 0..dw {
                let bx = dx + px;
                if bx < 0 || bx >= self.width {
                    continue;
                }
                let sx = ((px as i64 * src_w as i64) / dw as i64) as i32;
                let src_off = ((sy * src_w + sx) * 4) as usize;
                if src_off + 3 >= src.len() {
                    continue;
                }
                let src_a = src[src_off + 3] as u32;
                if src_a == 0 {
                    continue;
                }
                let dst_off = (by * self.stride + bx * 4) as usize;
                if dst_off + 3 >= self.buf.len() {
                    continue;
                }
                if src_a == 255 {
                    self.buf[dst_off] = src[src_off];
                    self.buf[dst_off + 1] = src[src_off + 1];
                    self.buf[dst_off + 2] = src[src_off + 2];
                    self.buf[dst_off + 3] = 255;
                } else {
                    let inv_a = 255 - src_a;
                    let sr = src[src_off] as u32;
                    let sg = src[src_off + 1] as u32;
                    let sb = src[src_off + 2] as u32;
                    let dr = self.buf[dst_off] as u32;
                    let dg = self.buf[dst_off + 1] as u32;
                    let db = self.buf[dst_off + 2] as u32;
                    self.buf[dst_off] = ((sr * src_a + dr * inv_a + 127) / 255) as u8;
                    self.buf[dst_off + 1] = ((sg * src_a + dg * inv_a + 127) / 255) as u8;
                    self.buf[dst_off + 2] = ((sb * src_a + db * inv_a + 127) / 255) as u8;
                    self.buf[dst_off + 3] = 255;
                }
            }
        }
    }

    fn blit_image_at(&mut self, dx: i32, dy: i32, src: &[u8], src_w: i32, src_h: i32) {
        for sy in 0..src_h {
            let by = dy + sy;
            if by < 0 || by >= self.height {
                continue;
            }
            for sx in 0..src_w {
                let bx = dx + sx;
                if bx < 0 || bx >= self.width {
                    continue;
                }
                let src_off = ((sy * src_w + sx) * 4) as usize;
                if src_off + 3 >= src.len() {
                    continue;
                }
                let src_a = src[src_off + 3] as u32;
                if src_a == 0 {
                    continue;
                }
                let dst_off = (by * self.stride + bx * 4) as usize;
                if dst_off + 3 >= self.buf.len() {
                    continue;
                }
                if src_a == 255 {
                    self.buf[dst_off] = src[src_off];
                    self.buf[dst_off + 1] = src[src_off + 1];
                    self.buf[dst_off + 2] = src[src_off + 2];
                    self.buf[dst_off + 3] = 255;
                } else {
                    let inv_a = 255 - src_a;
                    let sr = src[src_off] as u32;
                    let sg = src[src_off + 1] as u32;
                    let sb = src[src_off + 2] as u32;
                    let dr = self.buf[dst_off] as u32;
                    let dg = self.buf[dst_off + 1] as u32;
                    let db = self.buf[dst_off + 2] as u32;
                    self.buf[dst_off] = ((sr * src_a + dr * inv_a + 127) / 255) as u8;
                    self.buf[dst_off + 1] = ((sg * src_a + dg * inv_a + 127) / 255) as u8;
                    self.buf[dst_off + 2] = ((sb * src_a + db * inv_a + 127) / 255) as u8;
                    self.buf[dst_off + 3] = 255;
                }
            }
        }
    }

    fn fill_checker(&mut self, x: i32, y: i32, w: i32, h: i32) {
        let x0 = x.max(0);
        let y0 = y.max(0);
        let x1 = (x + w).min(self.width);
        let y1 = (y + h).min(self.height);
        for py in y0..y1 {
            for px in x0..x1 {
                let c: u32 = if ((px + py) & 1) == 0 {
                    0xFFDCDCDC
                } else {
                    0xFFCFCFCF
                };
                let off = (py * self.stride + px * 4) as usize;
                if off + 3 < self.buf.len() {
                    self.buf[off] = ((c >> 16) & 0xFF) as u8;
                    self.buf[off + 1] = ((c >> 8) & 0xFF) as u8;
                    self.buf[off + 2] = (c & 0xFF) as u8;
                    self.buf[off + 3] = ((c >> 24) & 0xFF) as u8;
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::text::TextRenderer;

    struct NoopTextRenderer;

    impl TextRenderer for NoopTextRenderer {
        fn measure_text(
            &mut self,
            _text: &str,
            _font_name: &str,
            _font_size: f32,
            _bold: bool,
            _italic: bool,
            _max_width: Option<f32>,
        ) -> (f32, f32) {
            (0.0, 0.0)
        }

        fn render_text(
            &mut self,
            _buffer_pixels: &mut [u8],
            _buf_width: i32,
            _buf_height: i32,
            _stride: i32,
            _x: i32,
            _y: i32,
            _clip_x: i32,
            _clip_y: i32,
            _clip_w: i32,
            _clip_h: i32,
            _text: &str,
            _font_name: &str,
            _font_size: f32,
            _bold: bool,
            _italic: bool,
            _color: u32,
            _max_width: Option<f32>,
        ) -> f32 {
            0.0
        }
    }

    fn make_canvas<'a>(buf: &'a mut [u8], text: &'a mut NoopTextRenderer) -> CpuCanvas<'a> {
        CpuCanvas::new(buf, 8, 4, 8 * 4, text)
    }

    #[test]
    fn fill_rect_ignores_fully_offscreen_negative_rect() {
        let mut buffer = vec![0u8; 8 * 4 * 4];
        let original = buffer.clone();
        let mut text = NoopTextRenderer;
        let mut canvas = make_canvas(&mut buffer, &mut text);

        canvas.fill_rect(-200, 1, 100, 2, 0xFFFF0000);

        assert_eq!(buffer, original);
    }

    #[test]
    fn blend_rect_ignores_fully_offscreen_negative_rect() {
        let mut buffer = vec![0u8; 8 * 4 * 4];
        let original = buffer.clone();
        let mut text = NoopTextRenderer;
        let mut canvas = make_canvas(&mut buffer, &mut text);

        canvas.blend_rect(1, -200, 3, 100, 0x80FF0000);

        assert_eq!(buffer, original);
    }

    #[test]
    fn hline_clips_partially_offscreen_negative_span() {
        let mut buffer = vec![0u8; 8 * 4 * 4];
        let mut text = NoopTextRenderer;
        let mut canvas = make_canvas(&mut buffer, &mut text);

        canvas.hline(-2, 1, 5, 0xFF112233);

        for x in 0..3 {
            let off = ((1 * 8 + x) * 4) as usize;
            assert_eq!(&buffer[off..off + 4], &[0x11, 0x22, 0x33, 0xFF]);
        }
        for x in 3..8 {
            let off = ((1 * 8 + x) * 4) as usize;
            assert_eq!(&buffer[off..off + 4], &[0, 0, 0, 0]);
        }
    }
}
