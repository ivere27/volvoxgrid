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
}

impl<'a> Canvas for CpuCanvas<'a> {
    fn width(&self) -> i32 {
        self.width
    }

    fn height(&self) -> i32 {
        self.height
    }

    fn fill_rect(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        let r = ((color >> 16) & 0xFF) as u8;
        let g = ((color >> 8) & 0xFF) as u8;
        let b = (color & 0xFF) as u8;
        let a = ((color >> 24) & 0xFF) as u8;

        let x0 = x.max(0);
        let y0 = y.max(0);
        let x1 = (x + w).min(self.width);
        let y1 = (y + h).min(self.height);

        for py in y0..y1 {
            let row_off = (py * self.stride) as usize;
            for px in x0..x1 {
                let off = row_off + (px * 4) as usize;
                if off + 3 < self.buf.len() {
                    self.buf[off] = r;
                    self.buf[off + 1] = g;
                    self.buf[off + 2] = b;
                    self.buf[off + 3] = a;
                }
            }
        }
    }

    fn blend_rect(&mut self, x: i32, y: i32, w: i32, h: i32, color: u32) {
        let src_r = ((color >> 16) & 0xFF) as u32;
        let src_g = ((color >> 8) & 0xFF) as u32;
        let src_b = (color & 0xFF) as u32;
        let src_a = ((color >> 24) & 0xFF) as u32;

        if src_a == 0 {
            return;
        }
        if src_a == 255 {
            self.fill_rect(x, y, w, h, color);
            return;
        }

        let inv_a = 255 - src_a;
        let x0 = x.max(0);
        let y0 = y.max(0);
        let x1 = (x + w).min(self.width);
        let y1 = (y + h).min(self.height);

        for py in y0..y1 {
            let row_off = (py * self.stride) as usize;
            for px in x0..x1 {
                let off = row_off + (px * 4) as usize;
                if off + 3 < self.buf.len() {
                    let dr = self.buf[off] as u32;
                    let dg = self.buf[off + 1] as u32;
                    let db = self.buf[off + 2] as u32;
                    self.buf[off] = ((src_r * src_a + dr * inv_a + 127) / 255) as u8;
                    self.buf[off + 1] = ((src_g * src_a + dg * inv_a + 127) / 255) as u8;
                    self.buf[off + 2] = ((src_b * src_a + db * inv_a + 127) / 255) as u8;
                    self.buf[off + 3] = 255;
                }
            }
        }
    }

    fn hline(&mut self, x: i32, y: i32, w: i32, color: u32) {
        let py = y;
        if py < 0 || py >= self.height {
            return;
        }
        let r = ((color >> 16) & 0xFF) as u8;
        let g = ((color >> 8) & 0xFF) as u8;
        let b = (color & 0xFF) as u8;
        let a = ((color >> 24) & 0xFF) as u8;
        let x0 = x.max(0);
        let x1 = (x + w).min(self.width);
        let row_off = (py * self.stride) as usize;
        for px in x0..x1 {
            let off = row_off + (px * 4) as usize;
            if off + 3 < self.buf.len() {
                self.buf[off] = r;
                self.buf[off + 1] = g;
                self.buf[off + 2] = b;
                self.buf[off + 3] = a;
            }
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
