//! GPU glyph atlas for text rendering.
//!
//! Rasterizes glyphs via cosmic-text's `SwashCache` and packs them into
//! R8 GPU texture pages using a simple shelf-packing algorithm. The GPU
//! renderer draws text as instanced textured quads referencing atlas UV
//! coordinates.

use std::collections::HashMap;

#[cfg(feature = "cosmic-text")]
use cosmic_text::{CacheKey, FontSystem, SwashCache};
#[cfg(not(feature = "cosmic-text"))]
type CacheKey = ();
#[cfg(not(feature = "cosmic-text"))]
type FontSystem = ();
#[cfg(not(feature = "cosmic-text"))]
type SwashCache = ();

// Re-export shared types so existing `glyph_atlas::` paths keep working.
pub use crate::glyph_rasterizer::{ExternalGlyphRasterizer, GlyphBitmap};

/// Atlas page dimensions (power-of-two, fits most GPUs).
const ATLAS_SIZE: u32 = 2048;

/// Padding between glyphs to avoid texture filtering bleed.
const GLYPH_PAD: u32 = 1;

/// A single glyph entry in the atlas.
#[derive(Clone, Copy, Debug)]
pub struct GlyphEntry {
    /// Atlas page index.
    pub page: usize,
    /// UV coordinates (u_min, v_min, u_max, v_max) normalized to [0,1].
    pub uv: [f32; 4],
    /// Glyph pixel dimensions.
    pub width: u32,
    pub height: u32,
    /// Glyph bearing offsets (pixels from origin).
    pub offset_x: i32,
    pub offset_y: i32,
    /// Advance width from external rasterizer (if any).
    /// Used to correct glyph positions when cosmic-text's .notdef advance
    /// differs from the actual character width.
    pub advance_width: Option<f32>,
}

/// A single atlas page (R8 texture).
pub struct AtlasPage {
    /// CPU-side pixel data (R8, row-major).
    pub pixels: Vec<u8>,
    /// Current shelf cursor.
    shelf_x: u32,
    shelf_y: u32,
    shelf_height: u32,
    /// Whether this page has been modified since last GPU upload.
    pub dirty: bool,
}

impl AtlasPage {
    fn new() -> Self {
        Self {
            pixels: vec![0u8; (ATLAS_SIZE * ATLAS_SIZE) as usize],
            shelf_x: 0,
            shelf_y: 0,
            shelf_height: 0,
            dirty: true,
        }
    }

    /// Try to pack a glyph bitmap into this page.
    /// Returns `Some((u, v))` pixel coordinates if successful.
    fn pack(&mut self, w: u32, h: u32) -> Option<(u32, u32)> {
        let pw = w + GLYPH_PAD;
        let ph = h + GLYPH_PAD;

        // Try current shelf.
        if self.shelf_x + pw <= ATLAS_SIZE && self.shelf_y + ph.max(self.shelf_height) <= ATLAS_SIZE
        {
            let x = self.shelf_x;
            let y = self.shelf_y;
            self.shelf_x += pw;
            self.shelf_height = self.shelf_height.max(ph);
            return Some((x, y));
        }

        // Start new shelf.
        let new_y = self.shelf_y + self.shelf_height;
        if pw <= ATLAS_SIZE && new_y + ph <= ATLAS_SIZE {
            self.shelf_x = pw;
            self.shelf_y = new_y;
            self.shelf_height = ph;
            return Some((0, new_y));
        }

        None // Page full.
    }

    /// Blit an R8 glyph bitmap into the page at (px, py).
    fn blit(&mut self, px: u32, py: u32, w: u32, h: u32, data: &[u8]) {
        for row in 0..h {
            let src_start = (row * w) as usize;
            let src_end = src_start + w as usize;
            let dst_start = ((py + row) * ATLAS_SIZE + px) as usize;
            if src_end <= data.len() && dst_start + w as usize <= self.pixels.len() {
                self.pixels[dst_start..dst_start + w as usize]
                    .copy_from_slice(&data[src_start..src_end]);
            }
        }
        self.dirty = true;
    }
}

/// Key for caching rasterized glyphs.
///
/// For glyphs rasterized via SwashCache, `ext_char` is `None`.
/// For glyphs rasterized via the external rasterizer (e.g. Canvas2D),
/// `ext_char` holds the actual character so that different characters
/// sharing the same `.notdef` cache_key get separate atlas entries.
#[derive(Clone, Copy, Debug, Hash, PartialEq, Eq)]
struct GlyphKey {
    cache_key: CacheKey,
    ext_char: Option<char>,
}

/// GPU glyph atlas manager.
pub struct GlyphAtlas {
    pages: Vec<AtlasPage>,
    cache: HashMap<GlyphKey, GlyphEntry>,
    external_rasterizer: Option<Box<dyn ExternalGlyphRasterizer>>,
}

impl GlyphAtlas {
    pub fn new() -> Self {
        Self {
            pages: vec![AtlasPage::new()],
            cache: HashMap::new(),
            external_rasterizer: None,
        }
    }

    /// Number of atlas pages.
    pub fn page_count(&self) -> usize {
        self.pages.len()
    }

    /// Get a reference to a page by index.
    pub fn page(&self, index: usize) -> &AtlasPage {
        &self.pages[index]
    }

    /// Get a mutable reference to a page by index.
    pub fn page_mut(&mut self, index: usize) -> &mut AtlasPage {
        &mut self.pages[index]
    }

    /// Atlas page size in pixels.
    pub fn atlas_size(&self) -> u32 {
        ATLAS_SIZE
    }

    /// Look up a cached glyph. Returns `None` if not yet rasterized.
    pub fn get_glyph(&self, cache_key: CacheKey) -> Option<&GlyphEntry> {
        self.cache.get(&GlyphKey {
            cache_key,
            ext_char: None,
        })
    }

    /// Rasterize and cache a glyph. Returns the atlas entry.
    ///
    /// `font_system` and `swash_cache` are borrowed from the caller's
    /// `TextEngine` to perform the actual glyph rasterization.
    pub fn rasterize_glyph(
        &mut self,
        font_system: &mut FontSystem,
        swash_cache: &mut SwashCache,
        cache_key: CacheKey,
    ) -> Option<GlyphEntry> {
        let key = GlyphKey {
            cache_key,
            ext_char: None,
        };
        if let Some(entry) = self.cache.get(&key) {
            return Some(*entry);
        }

        // Rasterize the glyph via cosmic-text's swash integration.
        let image = swash_cache.get_image(font_system, cache_key).as_ref()?;

        let w = image.placement.width;
        let h = image.placement.height;

        if w == 0 || h == 0 {
            // Whitespace glyph — cache with zero UV.
            let entry = GlyphEntry {
                page: 0,
                uv: [0.0, 0.0, 0.0, 0.0],
                width: 0,
                height: 0,
                offset_x: image.placement.left,
                offset_y: image.placement.top,
                advance_width: None,
            };
            self.cache.insert(key, entry);
            return Some(entry);
        }

        // Convert glyph data to R8 (alpha channel only).
        let alpha_data = match image.content {
            cosmic_text::SwashContent::Mask => image.data.clone(),
            cosmic_text::SwashContent::Color => {
                // RGBA data — extract alpha channel.
                image.data.iter().skip(3).step_by(4).copied().collect()
            }
            cosmic_text::SwashContent::SubpixelMask => {
                // RGB subpixel data — average to single alpha.
                image
                    .data
                    .chunks(3)
                    .map(|rgb| {
                        let sum = rgb[0] as u16 + rgb[1] as u16 + rgb[2] as u16;
                        (sum / 3) as u8
                    })
                    .collect()
            }
        };

        // Try to pack into an existing page.
        let (page_idx, px, py) = self.pack_glyph(w, h);

        // Blit the alpha data.
        self.pages[page_idx].blit(px, py, w, h, &alpha_data);

        let inv = 1.0 / ATLAS_SIZE as f32;
        let entry = GlyphEntry {
            page: page_idx,
            uv: [
                px as f32 * inv,
                py as f32 * inv,
                (px + w) as f32 * inv,
                (py + h) as f32 * inv,
            ],
            width: w,
            height: h,
            offset_x: image.placement.left,
            offset_y: image.placement.top,
            advance_width: None,
        };
        self.cache.insert(key, entry);
        Some(entry)
    }

    /// Pack a glyph of given dimensions, allocating new pages as needed.
    fn pack_glyph(&mut self, w: u32, h: u32) -> (usize, u32, u32) {
        for (i, page) in self.pages.iter_mut().enumerate() {
            if let Some((px, py)) = page.pack(w, h) {
                return (i, px, py);
            }
        }
        // All pages full — allocate a new one.
        let mut page = AtlasPage::new();
        let pos = page
            .pack(w, h)
            .expect("glyph too large for empty atlas page");
        self.pages.push(page);
        (self.pages.len() - 1, pos.0, pos.1)
    }

    /// Clear all cached glyphs (e.g. on font change).
    pub fn clear(&mut self) {
        self.cache.clear();
        self.pages.clear();
        self.pages.push(AtlasPage::new());
    }

    /// Register an external glyph rasterizer (e.g. Canvas2D on WASM).
    pub fn set_external_rasterizer(&mut self, r: Box<dyn ExternalGlyphRasterizer>) {
        self.external_rasterizer = Some(r);
    }

    /// Remove the external rasterizer.
    pub fn clear_external_rasterizer(&mut self) {
        self.external_rasterizer = None;
    }

    /// Pack an alpha bitmap into the atlas and return a `GlyphEntry`.
    fn pack_alpha_bitmap(
        &mut self,
        key: GlyphKey,
        w: u32,
        h: u32,
        offset_x: i32,
        offset_y: i32,
        alpha_data: &[u8],
        advance_width: Option<f32>,
    ) -> GlyphEntry {
        let (page_idx, px, py) = self.pack_glyph(w, h);
        self.pages[page_idx].blit(px, py, w, h, alpha_data);
        let inv = 1.0 / ATLAS_SIZE as f32;
        let entry = GlyphEntry {
            page: page_idx,
            uv: [
                px as f32 * inv,
                py as f32 * inv,
                (px + w) as f32 * inv,
                (py + h) as f32 * inv,
            ],
            width: w,
            height: h,
            offset_x,
            offset_y,
            advance_width,
        };
        self.cache.insert(key, entry);
        entry
    }

    /// Rasterize a glyph, falling back to the external rasterizer when SwashCache
    /// fails to produce an image or when the glyph is `.notdef` (glyph_id == 0),
    /// indicating the loaded fonts don't have the character.
    pub fn rasterize_glyph_or_fallback(
        &mut self,
        font_system: &mut FontSystem,
        swash_cache: &mut SwashCache,
        cache_key: CacheKey,
        character: Option<char>,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
    ) -> Option<GlyphEntry> {
        // glyph_id == 0 is the .notdef glyph — the font doesn't have this
        // character. SwashCache would return the tofu rectangle, so prefer the
        // external rasterizer when available.
        let is_notdef = cache_key.glyph_id == 0;
        if is_notdef {
            if let Some(entry) = self.try_external_rasterize(
                cache_key, character, font_name, font_size, bold, italic,
            ) {
                return Some(entry);
            }
            // External rasterizer unavailable or returned None — fall through
            // to SwashCache (renders tofu).
        }

        // Try normal SwashCache path.
        if let Some(entry) = self.rasterize_glyph(font_system, swash_cache, cache_key) {
            return Some(entry);
        }

        // SwashCache returned None — try external rasterizer as last resort.
        self.try_external_rasterize(cache_key, character, font_name, font_size, bold, italic)
    }

    /// Attempt to rasterize a character via the external rasterizer.
    fn try_external_rasterize(
        &mut self,
        cache_key: CacheKey,
        character: Option<char>,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
    ) -> Option<GlyphEntry> {
        let ch = character?;
        // Use ext_char in the key so different characters sharing the same
        // .notdef cache_key get separate atlas entries.
        let key = GlyphKey {
            cache_key,
            ext_char: Some(ch),
        };
        if let Some(entry) = self.cache.get(&key) {
            return Some(*entry);
        }
        let rasterizer = self.external_rasterizer.as_mut()?;
        let bitmap = rasterizer.rasterize_glyph(ch, font_name, font_size, bold, italic)?;
        if bitmap.width == 0 || bitmap.height == 0 {
            let entry = GlyphEntry {
                page: 0,
                uv: [0.0, 0.0, 0.0, 0.0],
                width: 0,
                height: 0,
                offset_x: bitmap.offset_x,
                offset_y: bitmap.offset_y,
                advance_width: bitmap.advance_width,
            };
            self.cache.insert(key, entry);
            return Some(entry);
        }
        Some(self.pack_alpha_bitmap(
            key,
            bitmap.width,
            bitmap.height,
            bitmap.offset_x,
            bitmap.offset_y,
            &bitmap.alpha_data,
            bitmap.advance_width,
        ))
    }
}

/// Collect glyph quads for a text string positioned at `(x, y)` in pixel
/// space, clipped to `(clip_x, clip_y, clip_w, clip_h)`.
///
/// Returns a list of `(GlyphEntry, dest_x, dest_y)` tuples that the GPU
/// renderer converts to `TexturedInstance` data.
pub fn layout_text_glyphs(
    atlas: &mut GlyphAtlas,
    font_system: &mut FontSystem,
    swash_cache: &mut SwashCache,
    buffer: &cosmic_text::Buffer,
    text: &str,
    font_name: &str,
    font_size: f32,
    bold: bool,
    italic: bool,
    x: f32,
    y: f32,
) -> Vec<(GlyphEntry, f32, f32)> {
    let mut result = Vec::new();

    if text.is_empty() || font_system.db().len() == 0 {
        return result;
    }

    let has_external = atlas.external_rasterizer.is_some();

    for run in buffer.layout_runs() {
        let run_y = y + run.line_y;
        // Track cumulative x-offset adjustment when externally-rasterized
        // glyphs have a different advance width than cosmic-text's .notdef.
        let mut x_adjust: f32 = 0.0;
        for glyph in run.glyphs.iter() {
            let physical = glyph.physical((x, run_y), 1.0);
            let entry = if has_external {
                // Extract the character from the original text using cosmic-text's
                // start field (byte index into the source string).
                let character = text.get(glyph.start..).and_then(|s| s.chars().next());
                atlas.rasterize_glyph_or_fallback(
                    font_system,
                    swash_cache,
                    physical.cache_key,
                    character,
                    font_name,
                    font_size,
                    bold,
                    italic,
                )
            } else {
                atlas.rasterize_glyph(font_system, swash_cache, physical.cache_key)
            };
            if let Some(entry) = entry {
                if entry.width > 0 && entry.height > 0 {
                    let dx = physical.x as f32 + entry.offset_x as f32 + x_adjust;
                    let dy = physical.y as f32 - entry.offset_y as f32;
                    result.push((entry, dx, dy));
                }
                // Adjust cumulative offset for externally-rasterized glyphs
                // whose true advance differs from cosmic-text's .notdef advance.
                if let Some(actual_advance) = entry.advance_width {
                    x_adjust += actual_advance - glyph.w;
                }
            }
        }
    }

    result
}
