#[cfg(feature = "cosmic-text")]
use cosmic_text::{Attrs, Buffer, Family, FontSystem, Metrics, Shaping, SwashCache};
#[cfg(feature = "cosmic-text")]
use std::collections::{HashMap, VecDeque};

use crate::glyph_rasterizer::ExternalGlyphRasterizer;
use crate::proto::volvoxgrid::v1 as pb;

/// Pluggable text measurement and rendering interface.
///
/// Implement this trait to inject a platform-native text renderer (GDI, Canvas2D,
/// Skia, etc.) into the CPU rendering pipeline.  The default implementation
/// (`TextEngine`) uses cosmic-text.
pub trait TextRenderer: Send {
    /// Measure text dimensions (width, height) with given font settings.
    ///
    /// If `max_width` is `Some(w)`, text wraps at that width and the returned
    /// height reflects the multi-line layout.  `None` means single-line.
    fn measure_text(
        &mut self,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> (f32, f32);

    /// Render text into an RGBA pixel buffer at position (`x`, `y`).
    ///
    /// Glyphs are clipped to (`clip_x`, `clip_y`, `clip_w`, `clip_h`) and to
    /// buffer bounds.  Alpha blending is performed over existing content.
    /// Returns rendered text width.
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
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        color: u32,
        max_width: Option<f32>,
    ) -> f32;
}

#[derive(Clone, Copy, Debug)]
struct TextRenderOptions {
    render_mode: i32,
    hinting_mode: i32,
    pixel_snap: bool,
}

#[derive(Clone, Debug, Hash, PartialEq, Eq)]
pub struct MeasureKey {
    text: String,
    font_name: String,
    font_size_bits: u32,
    bold: bool,
    italic: bool,
    max_width_quarter_px: i32,
}

impl MeasureKey {
    fn heap_size_bytes(&self) -> usize {
        self.text.capacity() + self.font_name.capacity()
    }
}

#[cfg(feature = "cosmic-text")]
pub struct CachedLayout {
    pub buffer: Buffer,
    pub measured_width: f32,
    pub measured_height: f32,
}

#[cfg(feature = "cosmic-text")]
pub enum LayoutResult<'a> {
    Cached(&'a CachedLayout),
    Owned(CachedLayout),
}

#[cfg(feature = "cosmic-text")]
impl<'a> LayoutResult<'a> {
    pub fn layout(&self) -> &CachedLayout {
        match self {
            LayoutResult::Cached(c) => c,
            LayoutResult::Owned(c) => c,
        }
    }
}

/// Text measurement and rendering engine.
///
/// When the `cosmic-text` feature is enabled, provides glyph shaping,
/// measurement, and pixel-level rendering backed by pop-os/cosmic-text.
/// Otherwise, requires an external renderer to be registered.
pub struct TextEngine {
    #[cfg(feature = "cosmic-text")]
    pub font_system: FontSystem,
    #[cfg(feature = "cosmic-text")]
    pub swash_cache: SwashCache,
    #[cfg(feature = "cosmic-text")]
    pub layout_cache: HashMap<MeasureKey, CachedLayout>,
    #[cfg(feature = "cosmic-text")]
    pub layout_fifo: VecDeque<MeasureKey>,
    pub layout_cache_cap: usize,

    render_options: TextRenderOptions,
    external_rasterizer: Option<Box<dyn ExternalGlyphRasterizer>>,
    external_renderer: Option<Box<dyn TextRenderer>>,
}

pub const DEFAULT_LAYOUT_CACHE_CAP: usize = 8192;

impl TextEngine {
    pub fn new() -> Self {
        #[cfg(feature = "cosmic-text")]
        {
            // Start with an empty font database to avoid scanning /system/fonts (slow on Android).
            // We manually load a locale-aware fallback set below.
            let locale = Self::detect_locale_hint();
            let db = cosmic_text::fontdb::Database::new();
            let mut font_system = FontSystem::new_with_locale_and_db(locale.clone(), db);

            Self::load_platform_fallback_fonts(&mut font_system, &locale);

            Self {
                font_system,
                swash_cache: SwashCache::new(),
                layout_cache: HashMap::new(),
                layout_fifo: VecDeque::new(),
                layout_cache_cap: DEFAULT_LAYOUT_CACHE_CAP,
                render_options: TextRenderOptions {
                    render_mode: pb::TextRenderMode::TextRenderAuto as i32,
                    hinting_mode: pb::TextHintingMode::TextHintAuto as i32,
                    pixel_snap: false,
                },
                external_rasterizer: None,
                external_renderer: None,
            }
        }
        #[cfg(not(feature = "cosmic-text"))]
        {
            Self {
                layout_cache_cap: DEFAULT_LAYOUT_CACHE_CAP,
                render_options: TextRenderOptions {
                    render_mode: pb::TextRenderMode::TextRenderAuto as i32,
                    hinting_mode: pb::TextHintingMode::TextHintAuto as i32,
                    pixel_snap: false,
                },
                external_rasterizer: None,
                external_renderer: None,
            }
        }
    }

    pub fn heap_size_bytes(&self) -> usize {
        #[cfg(feature = "cosmic-text")]
        {
            let mut bytes = 0usize;
            // FontSystem and SwashCache maintain backend/font-db allocations that
            // are opaque here. We only report explicit text layout caches.
            bytes += self.layout_cache.capacity()
                * (std::mem::size_of::<MeasureKey>() + std::mem::size_of::<CachedLayout>() + 8);
            for key in self.layout_cache.keys() {
                bytes += key.heap_size_bytes();
            }

            bytes += self.layout_fifo.capacity() * std::mem::size_of::<MeasureKey>();
            for key in &self.layout_fifo {
                bytes += key.heap_size_bytes();
            }

            bytes
        }
        #[cfg(not(feature = "cosmic-text"))]
        {
            0
        }
    }

    pub fn layout_cache_len(&self) -> usize {
        #[cfg(feature = "cosmic-text")]
        {
            self.layout_cache.len()
        }
        #[cfg(not(feature = "cosmic-text"))]
        {
            0
        }
    }

    pub fn set_layout_cache_cap(&mut self, cap: usize) {
        self.layout_cache_cap = cap;
        #[cfg(feature = "cosmic-text")]
        {
            Self::enforce_cache_cap(&mut self.layout_cache, &mut self.layout_fifo, cap);
        }
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn detect_locale_hint() -> String {
        const KEYS: &[&str] = &[
            "VOLVOXGRID_LOCALE",
            "LC_ALL",
            "LC_MESSAGES",
            "LANG",
            "LANGUAGE",
        ];
        for key in KEYS {
            if let Ok(raw) = std::env::var(key) {
                if let Some(norm) = Self::normalize_locale_hint(&raw) {
                    return norm;
                }
            }
        }
        "en-US".to_string()
    }

    #[cfg(target_arch = "wasm32")]
    fn detect_locale_hint() -> String {
        "en-US".to_string()
    }

    fn normalize_locale_hint(raw: &str) -> Option<String> {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            return None;
        }
        let first = trimmed
            .split(':')
            .next()
            .unwrap_or(trimmed)
            .split('.')
            .next()
            .unwrap_or(trimmed)
            .split('@')
            .next()
            .unwrap_or(trimmed)
            .trim();
        if first.is_empty() {
            return None;
        }
        if first.eq_ignore_ascii_case("c") || first.eq_ignore_ascii_case("posix") {
            return None;
        }
        Some(first.replace('_', "-"))
    }

    #[cfg(all(feature = "cosmic-text", not(target_arch = "wasm32")))]
    fn load_platform_fallback_fonts(font_system: &mut FontSystem, locale_hint: &str) {
        const MAX_FONT_FILES: usize = 10;
        let mut loaded = 0usize;
        for path in crate::font_fallbacks::platform_fallback_candidates(locale_hint) {
            if loaded >= MAX_FONT_FILES {
                break;
            }
            if let Ok(data) = std::fs::read(path) {
                let before = font_system.db().len();
                font_system.db_mut().load_font_data(data);
                if font_system.db().len() > before {
                    loaded += 1;
                }
            }
        }
    }

    #[cfg(all(feature = "cosmic-text", target_arch = "wasm32"))]
    fn load_platform_fallback_fonts(_font_system: &mut FontSystem, _locale_hint: &str) {}

    /// Load font data (TTF/OTF/TTC) into the font system.
    pub fn load_font_data(&mut self, data: Vec<u8>) {
        #[cfg(feature = "cosmic-text")]
        {
            self.font_system.db_mut().load_font_data(data);
            self.layout_cache.clear();
            self.layout_fifo.clear();
        }
        #[cfg(not(feature = "cosmic-text"))]
        let _ = data;
    }

    /// Check whether any fonts are available for text rendering.
    pub fn has_fonts(&self) -> bool {
        #[cfg(feature = "cosmic-text")]
        {
            self.font_system.db().len() > 0
        }
        #[cfg(not(feature = "cosmic-text"))]
        {
            self.external_renderer.is_some()
        }
    }

    /// Update text rasterization options from GridStyle.
    ///
    /// Unsupported backend modes are treated as hints and approximated where
    /// possible. MONO mode enforces binary alpha coverage for a crisp look.
    pub fn set_render_options(&mut self, render_mode: i32, hinting_mode: i32, pixel_snap: bool) {
        self.render_options = TextRenderOptions {
            render_mode,
            hinting_mode,
            pixel_snap,
        };
    }

    /// Register an external glyph rasterizer (e.g. Canvas2D on WASM) as a
    /// fallback when SwashCache cannot produce a glyph.
    pub fn set_external_rasterizer(&mut self, r: Box<dyn ExternalGlyphRasterizer>) {
        self.external_rasterizer = Some(r);
    }

    /// Register a complete external text renderer (e.g. Canvas2D on WASM) to
    /// bypass the built-in layout and rendering engine.
    pub fn set_external_renderer(&mut self, r: Option<Box<dyn TextRenderer>>) {
        self.external_renderer = r;
    }

    fn make_measure_key(
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> Option<MeasureKey> {
        // Avoid caching very large unique payloads.
        if text.len() > 96 {
            return None;
        }
        let max_width_quarter_px = match max_width {
            Some(w) => (w * 4.0).round() as i32,
            None => -1,
        };
        Some(MeasureKey {
            text: text.to_string(),
            font_name: font_name.to_string(),
            font_size_bits: font_size.to_bits(),
            bold,
            italic,
            max_width_quarter_px,
        })
    }

    #[cfg(feature = "cosmic-text")]
    pub fn get_or_shape_buffer<'a>(
        layout_cache: &'a mut HashMap<MeasureKey, CachedLayout>,
        layout_fifo: &mut VecDeque<MeasureKey>,
        cache_cap: usize,
        font_system: &mut FontSystem,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> Option<LayoutResult<'a>> {
        if text.is_empty() || font_system.db().len() == 0 {
            return None;
        }
        let cache_key = Self::make_measure_key(text, font_name, font_size, bold, italic, max_width);
        if let Some(key) = cache_key.as_ref() {
            if layout_cache.contains_key(key) {
                return Some(LayoutResult::Cached(layout_cache.get(key).unwrap()));
            }
        }

        let line_height = (font_size * 1.2).ceil();
        let metrics = Metrics::new(font_size, line_height);
        let attrs = Self::make_attrs(font_system, font_name, bold, italic);
        let mut buffer = Buffer::new(font_system, metrics);
        buffer.set_text(font_system, text, attrs, Shaping::Advanced);

        match max_width {
            Some(w) => buffer.set_size(font_system, Some(w), None),
            None => buffer.set_size(font_system, None, None),
        }

        buffer.shape_until_scroll(font_system, false);

        let mut width: f32 = 0.0;
        let mut height: f32 = 0.0;
        for run in buffer.layout_runs() {
            width = width.max(run.line_w);
            height += line_height;
        }

        if height < 0.001 {
            height = line_height;
        }

        let layout = CachedLayout {
            buffer,
            measured_width: width.ceil(),
            measured_height: height.ceil(),
        };

        if let Some(key) = cache_key {
            if cache_cap == 0 {
                return Some(LayoutResult::Owned(layout));
            }
            Self::enforce_cache_cap(layout_cache, layout_fifo, cache_cap.saturating_sub(1));
            if layout_cache.len() >= cache_cap {
                // If FIFO is stale/corrupted and cannot evict entries, fail closed.
                layout_cache.clear();
                layout_fifo.clear();
            }
            layout_fifo.push_back(key.clone());
            layout_cache.insert(key.clone(), layout);
            return Some(LayoutResult::Cached(layout_cache.get(&key).unwrap()));
        }

        Some(LayoutResult::Owned(layout))
    }

    #[cfg(feature = "cosmic-text")]
    fn enforce_cache_cap(
        layout_cache: &mut HashMap<MeasureKey, CachedLayout>,
        layout_fifo: &mut VecDeque<MeasureKey>,
        cap: usize,
    ) {
        if cap == 0 {
            layout_cache.clear();
            layout_fifo.clear();
            return;
        }

        while layout_cache.len() > cap {
            let mut removed = false;
            while let Some(old) = layout_fifo.pop_front() {
                if layout_cache.remove(&old).is_some() {
                    removed = true;
                    break;
                }
            }
            if !removed {
                layout_cache.clear();
                layout_fifo.clear();
                break;
            }
        }
    }

    /// Measure text dimensions (width, height) with given font settings.
    ///
    /// If `max_width` is provided, text will be wrapped at that width and the
    /// returned height reflects the multi-line layout.  Otherwise the text is
    /// treated as a single line and the width is the natural run width.
    pub fn measure_text(
        &mut self,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> (f32, f32) {
        if let Some(ext) = &mut self.external_renderer {
            return ext.measure_text(text, font_name, font_size, bold, italic, max_width);
        }

        #[cfg(feature = "cosmic-text")]
        {
            if let Some(res) = Self::get_or_shape_buffer(
                &mut self.layout_cache,
                &mut self.layout_fifo,
                self.layout_cache_cap,
                &mut self.font_system,
                text,
                font_name,
                font_size,
                bold,
                italic,
                max_width,
            ) {
                let layout = res.layout();
                (layout.measured_width, layout.measured_height)
            } else {
                (0.0, font_size * 1.2)
            }
        }
        #[cfg(not(feature = "cosmic-text"))]
        {
            (0.0, font_size * 1.2)
        }
    }

    /// Render text to an RGBA pixel buffer at position (`x`, `y`).
    ///
    /// Glyphs are clipped to the rectangle (`x`, `y`, `clip_w`, `clip_h`) and
    /// to the buffer dimensions.  Alpha blending is performed against the
    /// existing pixel content so that sub-pixel anti-aliasing composites
    /// correctly over cell backgrounds.
    ///
    /// Returns the rendered text width.
    pub fn render_text(
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
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        color: u32,
        max_width: Option<f32>,
    ) -> f32 {
        if text.is_empty() || clip_w <= 0 || clip_h <= 0 {
            return 0.0;
        }

        if let Some(ext) = &mut self.external_renderer {
            return ext.render_text(
                buffer_pixels,
                buf_width,
                buf_height,
                stride,
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
            );
        }

        #[cfg(feature = "cosmic-text")]
        {
            if !self.has_fonts() {
                return 0.0;
            }

            let layout_res = Self::get_or_shape_buffer(
                &mut self.layout_cache,
                &mut self.layout_fifo,
                self.layout_cache_cap,
                &mut self.font_system,
                text,
                font_name,
                font_size,
                bold,
                italic,
                max_width,
            );
            let text_buf = if let Some(r) = &layout_res {
                &r.layout().buffer
            } else {
                return 0.0;
            };

            let r = ((color >> 16) & 0xFF) as u8;
            let g = ((color >> 8) & 0xFF) as u8;
            let b = (color & 0xFF) as u8;

            let mut rendered_width: f32 = 0.0;
            let render_mode = self.render_options.render_mode;
            let hinting_mode = self.render_options.hinting_mode;

            // Precompute clip bounds in absolute pixel coordinates.
            let text_x = if self.render_options.pixel_snap { x } else { x };
            let text_y = if self.render_options.pixel_snap { y } else { y };
            let clip_x_min = clip_x;
            let clip_y_min = clip_y.max(0);
            let clip_x_max = (clip_x + clip_w).min(buf_width);
            let clip_y_max = (text_y + clip_h).min(buf_height);

            // Compute the maximum line width for the return value
            for run in text_buf.layout_runs() {
                rendered_width = rendered_width.max(run.line_w);
            }

            // Iterate glyphs individually so we can fall back to the external
            // rasterizer for characters that SwashCache cannot produce.
            let has_external = self.external_rasterizer.is_some();

            for run in text_buf.layout_runs() {
                let run_y = run.line_y;
                // Track cumulative x-offset adjustment when externally-rasterized
                // glyphs have a different advance width than cosmic-text's .notdef.
                let mut x_adjust: f32 = 0.0;
                for glyph in run.glyphs.iter() {
                    let physical = glyph.physical((text_x as f32, text_y as f32 + run_y), 1.0);
                    let x_off = x_adjust.round() as i32;

                    // glyph_id == 0 is the .notdef glyph — the font doesn't have
                    // this character. SwashCache would return the tofu rectangle,
                    // so prefer the external rasterizer when available.
                    let is_notdef = physical.cache_key.glyph_id == 0;

                    // Try external rasterizer first for .notdef glyphs.
                    if is_notdef && has_external {
                        let character = text.get(glyph.start..).and_then(|s| s.chars().next());
                        if let Some(ch) = character {
                            if let Some(bitmap) =
                                self.external_rasterizer.as_mut().and_then(|rast| {
                                    rast.rasterize_glyph(ch, font_name, font_size, bold, italic)
                                })
                            {
                                if bitmap.width > 0 && bitmap.height > 0 {
                                    let gx = physical.x + bitmap.offset_x + x_off;
                                    let gy = physical.y - bitmap.offset_y;
                                    blit_alpha_glyph(
                                        buffer_pixels,
                                        stride,
                                        &bitmap.alpha_data,
                                        bitmap.width as i32,
                                        bitmap.height as i32,
                                        gx,
                                        gy,
                                        r,
                                        g,
                                        b,
                                        clip_x_min,
                                        clip_y_min,
                                        clip_x_max,
                                        clip_y_max,
                                        render_mode,
                                        hinting_mode,
                                    );
                                }
                                // Adjust cumulative offset: actual advance vs cosmic-text's advance.
                                let actual_advance =
                                    bitmap.advance_width.unwrap_or(bitmap.width as f32);
                                x_adjust += actual_advance - glyph.w;
                                continue;
                            }
                        }
                        // External rasterizer returned None — fall through to swash.
                    }

                    // Normal path: rasterize via SwashCache.
                    let image = self
                        .swash_cache
                        .get_image(&mut self.font_system, physical.cache_key);

                    if let Some(image) = image.as_ref() {
                        let w = image.placement.width as i32;
                        let h = image.placement.height as i32;
                        if w == 0 || h == 0 {
                            continue;
                        }

                        let alpha_data: Vec<u8> = match image.content {
                            cosmic_text::SwashContent::Mask => image.data.clone(),
                            cosmic_text::SwashContent::Color => {
                                image.data.iter().skip(3).step_by(4).copied().collect()
                            }
                            cosmic_text::SwashContent::SubpixelMask => image
                                .data
                                .chunks(3)
                                .map(|rgb| {
                                    let sum = rgb[0] as u16 + rgb[1] as u16 + rgb[2] as u16;
                                    (sum / 3) as u8
                                })
                                .collect(),
                        };

                        let gx = physical.x + image.placement.left + x_off;
                        let gy = physical.y - image.placement.top;

                        blit_alpha_glyph(
                            buffer_pixels,
                            stride,
                            &alpha_data,
                            w,
                            h,
                            gx,
                            gy,
                            r,
                            g,
                            b,
                            clip_x_min,
                            clip_y_min,
                            clip_x_max,
                            clip_y_max,
                            render_mode,
                            hinting_mode,
                        );
                    } else if has_external {
                        // get_image returned None — try external rasterizer.
                        let character = text.get(glyph.start..).and_then(|s| s.chars().next());
                        if let Some(ch) = character {
                            if let Some(bitmap) =
                                self.external_rasterizer.as_mut().and_then(|rast| {
                                    rast.rasterize_glyph(ch, font_name, font_size, bold, italic)
                                })
                            {
                                if bitmap.width > 0 && bitmap.height > 0 {
                                    let gx = physical.x + bitmap.offset_x + x_off;
                                    let gy = physical.y - bitmap.offset_y;
                                    blit_alpha_glyph(
                                        buffer_pixels,
                                        stride,
                                        &bitmap.alpha_data,
                                        bitmap.width as i32,
                                        bitmap.height as i32,
                                        gx,
                                        gy,
                                        r,
                                        g,
                                        b,
                                        clip_x_min,
                                        clip_y_min,
                                        clip_x_max,
                                        clip_y_max,
                                        render_mode,
                                        hinting_mode,
                                    );
                                }
                                let actual_advance =
                                    bitmap.advance_width.unwrap_or(bitmap.width as f32);
                                x_adjust += actual_advance - glyph.w;
                            }
                        }
                    }
                }
            }

            rendered_width
        }
        #[cfg(not(feature = "cosmic-text"))]
        {
            0.0
        }
    }

    /// Render text with a shadow/offset for raised or inset text style effects.
    ///
    /// `text_style`:
    ///   - 0 = flat (no effect)
    ///   - 1 = raised (light shadow offset -1,-1)
    ///   - 2 = inset  (dark shadow offset +1,+1)
    ///   - 3 = raised light (lighter variant)
    ///   - 4 = inset light  (lighter variant)
    pub fn render_text_styled(
        &mut self,
        buffer_pixels: &mut [u8],
        buf_width: i32,
        buf_height: i32,
        stride: i32,
        x: i32,
        y: i32,
        clip_y: i32,
        clip_w: i32,
        clip_h: i32,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        color: u32,
        text_style: i32,
        max_width: Option<f32>,
    ) -> f32 {
        match text_style {
            s if s == pb::TextEffect::Emboss as i32 => {
                // Raised: draw dark shadow at +1,+1 then text on top
                let shadow = 0xFF404040;
                self.render_text(
                    buffer_pixels,
                    buf_width,
                    buf_height,
                    stride,
                    x + 1,
                    y + 1,
                    x,
                    clip_y,
                    clip_w,
                    clip_h,
                    text,
                    font_name,
                    font_size,
                    bold,
                    italic,
                    shadow,
                    max_width,
                );
                self.render_text(
                    buffer_pixels,
                    buf_width,
                    buf_height,
                    stride,
                    x,
                    y,
                    x,
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
            s if s == pb::TextEffect::Engrave as i32 => {
                // Inset: draw light highlight at -1,-1 then text on top
                let highlight = 0xFFFFFFFF;
                self.render_text(
                    buffer_pixels,
                    buf_width,
                    buf_height,
                    stride,
                    x - 1,
                    y - 1,
                    x,
                    clip_y,
                    clip_w,
                    clip_h,
                    text,
                    font_name,
                    font_size,
                    bold,
                    italic,
                    highlight,
                    max_width,
                );
                self.render_text(
                    buffer_pixels,
                    buf_width,
                    buf_height,
                    stride,
                    x,
                    y,
                    x,
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
            s if s == pb::TextEffect::EmbossLight as i32 => {
                // Raised light: lighter shadow
                let shadow = 0xFF808080;
                self.render_text(
                    buffer_pixels,
                    buf_width,
                    buf_height,
                    stride,
                    x + 1,
                    y + 1,
                    x,
                    clip_y,
                    clip_w,
                    clip_h,
                    text,
                    font_name,
                    font_size,
                    bold,
                    italic,
                    shadow,
                    max_width,
                );
                self.render_text(
                    buffer_pixels,
                    buf_width,
                    buf_height,
                    stride,
                    x,
                    y,
                    x,
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
            s if s == pb::TextEffect::EngraveLight as i32 => {
                // Inset light: lighter highlight
                let highlight = 0xFFE0E0E0;
                self.render_text(
                    buffer_pixels,
                    buf_width,
                    buf_height,
                    stride,
                    x - 1,
                    y - 1,
                    x,
                    clip_y,
                    clip_w,
                    clip_h,
                    text,
                    font_name,
                    font_size,
                    bold,
                    italic,
                    highlight,
                    max_width,
                );
                self.render_text(
                    buffer_pixels,
                    buf_width,
                    buf_height,
                    stride,
                    x,
                    y,
                    x,
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
            _ => {
                // 0 = flat, no style effect
                self.render_text(
                    buffer_pixels,
                    buf_width,
                    buf_height,
                    stride,
                    x,
                    y,
                    x,
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
        }
    }

    /// Build a cosmic-text `Attrs` descriptor from font parameters.
    #[cfg(feature = "cosmic-text")]
    fn make_attrs<'a>(
        font_system: &FontSystem,
        font_name: &'a str,
        bold: bool,
        italic: bool,
    ) -> Attrs<'a> {
        let mut attrs = Attrs::new();
        if !font_name.is_empty() {
            attrs = attrs.family(Family::Name(font_name));
        }
        if bold {
            attrs = attrs.weight(cosmic_text::Weight::BOLD);
        }
        if italic {
            // cosmic-text 0.12 panics in Shaping::run when Style::Italic is
            // requested but no italic/oblique font face is loaded.  Guard by
            // checking the font database first.
            let has_italic = font_system.db().faces().any(|face| {
                matches!(
                    face.style,
                    cosmic_text::fontdb::Style::Italic | cosmic_text::fontdb::Style::Oblique
                ) && (font_name.is_empty()
                    || face
                        .families
                        .iter()
                        .any(|(n, _)| n.eq_ignore_ascii_case(font_name)))
            });
            if has_italic {
                attrs = attrs.style(cosmic_text::Style::Italic);
            }
        }
        attrs
    }
}

fn mono_alpha_threshold(hinting_mode: i32) -> u32 {
    match hinting_mode {
        h if h == pb::TextHintingMode::TextHintNone as i32 => 192,
        h if h == pb::TextHintingMode::TextHintSlight as i32 => 160,
        h if h == pb::TextHintingMode::TextHintFull as i32 => 128,
        _ => 160, // AUTO
    }
}

/// Blit an R8 alpha glyph bitmap into an RGBA pixel buffer with color and
/// alpha blending, respecting clip bounds and render mode.
#[allow(clippy::too_many_arguments)]
fn blit_alpha_glyph(
    buffer_pixels: &mut [u8],
    stride: i32,
    alpha_data: &[u8],
    w: i32,
    h: i32,
    gx: i32,
    gy: i32,
    r: u8,
    g: u8,
    b: u8,
    clip_x_min: i32,
    clip_y_min: i32,
    clip_x_max: i32,
    clip_y_max: i32,
    render_mode: i32,
    hinting_mode: i32,
) {
    for row in 0..h {
        let py = gy + row;
        if py < clip_y_min || py >= clip_y_max {
            continue;
        }
        for col in 0..w {
            let px = gx + col;
            if px < clip_x_min || px >= clip_x_max || px < 0 || py < 0 {
                continue;
            }
            let src_idx = (row * w + col) as usize;
            if src_idx >= alpha_data.len() {
                continue;
            }

            let mut alpha = alpha_data[src_idx] as u32;
            if render_mode == pb::TextRenderMode::TextRenderMono as i32 {
                alpha = if alpha >= mono_alpha_threshold(hinting_mode) {
                    255
                } else {
                    0
                };
            }
            if alpha == 0 {
                continue;
            }

            let offset = (py * stride + px * 4) as usize;
            if offset + 3 >= buffer_pixels.len() {
                continue;
            }

            if alpha == 255 {
                buffer_pixels[offset] = r;
                buffer_pixels[offset + 1] = g;
                buffer_pixels[offset + 2] = b;
                buffer_pixels[offset + 3] = 255;
            } else {
                let inv = 255 - alpha;
                let dst_r = buffer_pixels[offset] as u32;
                let dst_g = buffer_pixels[offset + 1] as u32;
                let dst_b = buffer_pixels[offset + 2] as u32;
                let dst_a = buffer_pixels[offset + 3] as u32;

                buffer_pixels[offset] = ((r as u32 * alpha + dst_r * inv + 127) / 255) as u8;
                buffer_pixels[offset + 1] = ((g as u32 * alpha + dst_g * inv + 127) / 255) as u8;
                buffer_pixels[offset + 2] = ((b as u32 * alpha + dst_b * inv + 127) / 255) as u8;
                let out_a = alpha + (dst_a * inv + 127) / 255;
                buffer_pixels[offset + 3] = out_a.min(255) as u8;
            }
        }
    }
}

impl TextEngine {
    /// Borrow the underlying `FontSystem` mutably.
    ///
    /// Used by `GpuCanvas` to drive glyph rasterization through the shared
    /// `GlyphAtlas` while keeping a single font database for both CPU and GPU
    /// rendering paths.
    #[cfg(feature = "cosmic-text")]
    pub fn font_system_mut(&mut self) -> &mut FontSystem {
        &mut self.font_system
    }

    /// Borrow the underlying `SwashCache` mutably.
    ///
    /// Used together with `font_system_mut()` by the GPU renderer to
    /// rasterize glyphs into the glyph atlas.
    #[cfg(feature = "cosmic-text")]
    pub fn swash_cache_mut(&mut self) -> &mut SwashCache {
        &mut self.swash_cache
    }

    /// Borrow both `FontSystem` and `SwashCache` mutably at the same time.
    ///
    /// This avoids the double-mutable-borrow problem when both are needed
    /// in a single call (e.g. `layout_text_glyphs`).
    #[cfg(feature = "cosmic-text")]
    pub fn font_and_cache_mut(&mut self) -> (&mut FontSystem, &mut SwashCache) {
        (&mut self.font_system, &mut self.swash_cache)
    }
}

impl Default for TextEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl TextRenderer for TextEngine {
    fn measure_text(
        &mut self,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> (f32, f32) {
        TextEngine::measure_text(self, text, font_name, font_size, bold, italic, max_width)
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
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        color: u32,
        max_width: Option<f32>,
    ) -> f32 {
        TextEngine::render_text(
            self,
            buffer_pixels,
            buf_width,
            buf_height,
            stride,
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
}
