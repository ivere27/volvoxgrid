#![cfg(all(
    any(target_os = "macos", target_os = "ios"),
    not(feature = "cosmic-text")
))]

use std::ffi::c_void;
use std::ptr;

use volvoxgrid_engine::text::{
    blend_external_text_mask_into_rgba, ExternalTextKey, ExternalTextMask, ExternalTextMaskCache,
    TextRenderer, DEFAULT_LAYOUT_CACHE_CAP,
};

type CGFloat = f64;
type CFIndex = isize;
type Boolean = u8;
type CFAllocatorRef = *const c_void;
type CFStringRef = *const c_void;
type CFDictionaryRef = *const c_void;
type CFAttributedStringRef = *const c_void;
type CTFontRef = *const c_void;
type CTFramesetterRef = *const c_void;
type CTFrameRef = *const c_void;
type CGColorSpaceRef = *mut c_void;
type CGContextRef = *mut c_void;
type CGMutablePathRef = *mut c_void;
type CFHashCode = usize;

const K_CF_STRING_ENCODING_UTF8: u32 = 0x0800_0100;
const K_CT_FONT_UI_TYPE_SYSTEM: u32 = 0;
const K_CT_FONT_ITALIC_TRAIT: u32 = 1 << 0;
const K_CT_FONT_BOLD_TRAIT: u32 = 1 << 1;
const K_CG_IMAGE_ALPHA_PREMULTIPLIED_LAST: u32 = 1;
const MAX_TEXT_MASK_PIXELS: usize = 4 * 1024 * 1024;

#[repr(C)]
#[derive(Clone, Copy)]
struct CFRange {
    location: CFIndex,
    length: CFIndex,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct CGPoint {
    x: CGFloat,
    y: CGFloat,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct CGSize {
    width: CGFloat,
    height: CGFloat,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct CGRect {
    origin: CGPoint,
    size: CGSize,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct CGAffineTransform {
    a: CGFloat,
    b: CGFloat,
    c: CGFloat,
    d: CGFloat,
    tx: CGFloat,
    ty: CGFloat,
}

#[repr(C)]
struct CFDictionaryKeyCallBacks {
    version: CFIndex,
    retain: Option<unsafe extern "C" fn(CFAllocatorRef, *const c_void) -> *const c_void>,
    release: Option<unsafe extern "C" fn(CFAllocatorRef, *const c_void)>,
    copy_description: Option<unsafe extern "C" fn(*const c_void) -> CFStringRef>,
    equal: Option<unsafe extern "C" fn(*const c_void, *const c_void) -> Boolean>,
    hash: Option<unsafe extern "C" fn(*const c_void) -> CFHashCode>,
}

#[repr(C)]
struct CFDictionaryValueCallBacks {
    version: CFIndex,
    retain: Option<unsafe extern "C" fn(CFAllocatorRef, *const c_void) -> *const c_void>,
    release: Option<unsafe extern "C" fn(CFAllocatorRef, *const c_void)>,
    copy_description: Option<unsafe extern "C" fn(*const c_void) -> CFStringRef>,
    equal: Option<unsafe extern "C" fn(*const c_void, *const c_void) -> Boolean>,
}

const CG_AFFINE_TRANSFORM_IDENTITY: CGAffineTransform = CGAffineTransform {
    a: 1.0,
    b: 0.0,
    c: 0.0,
    d: 1.0,
    tx: 0.0,
    ty: 0.0,
};

#[link(name = "CoreFoundation", kind = "framework")]
unsafe extern "C" {
    static kCFTypeDictionaryKeyCallBacks: CFDictionaryKeyCallBacks;
    static kCFTypeDictionaryValueCallBacks: CFDictionaryValueCallBacks;

    fn CFRelease(cf: *const c_void);
    fn CFStringCreateWithBytes(
        alloc: CFAllocatorRef,
        bytes: *const u8,
        num_bytes: CFIndex,
        encoding: u32,
        is_external_representation: Boolean,
    ) -> CFStringRef;
    fn CFDictionaryCreate(
        allocator: CFAllocatorRef,
        keys: *const *const c_void,
        values: *const *const c_void,
        num_values: CFIndex,
        key_callbacks: *const c_void,
        value_callbacks: *const c_void,
    ) -> CFDictionaryRef;
    fn CFAttributedStringCreate(
        alloc: CFAllocatorRef,
        str: CFStringRef,
        attributes: CFDictionaryRef,
    ) -> CFAttributedStringRef;
}

#[link(name = "CoreGraphics", kind = "framework")]
unsafe extern "C" {
    fn CGColorSpaceCreateDeviceRGB() -> CGColorSpaceRef;
    fn CGContextSetShouldAntialias(context: CGContextRef, should_antialias: Boolean);
    fn CGContextSetAllowsAntialiasing(context: CGContextRef, allows_antialiasing: Boolean);
    fn CGContextSetRGBFillColor(
        context: CGContextRef,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat,
    );
    fn CGContextSetTextMatrix(context: CGContextRef, t: CGAffineTransform);
    fn CGContextTranslateCTM(context: CGContextRef, tx: CGFloat, ty: CGFloat);
    fn CGContextScaleCTM(context: CGContextRef, sx: CGFloat, sy: CGFloat);
    fn CGBitmapContextCreate(
        data: *mut c_void,
        width: usize,
        height: usize,
        bits_per_component: usize,
        bytes_per_row: usize,
        space: CGColorSpaceRef,
        bitmap_info: u32,
    ) -> CGContextRef;
    fn CGPathCreateMutable() -> CGMutablePathRef;
    fn CGPathAddRect(path: CGMutablePathRef, m: *const CGAffineTransform, rect: CGRect);
}

#[link(name = "CoreText", kind = "framework")]
unsafe extern "C" {
    static kCTFontAttributeName: CFStringRef;

    fn CTFontCreateUIFontForLanguage(
        ui_type: u32,
        size: CGFloat,
        language: CFStringRef,
    ) -> CTFontRef;
    fn CTFontCreateWithName(
        name: CFStringRef,
        size: CGFloat,
        matrix: *const CGAffineTransform,
    ) -> CTFontRef;
    fn CTFontCreateCopyWithSymbolicTraits(
        font: CTFontRef,
        size: CGFloat,
        matrix: *const CGAffineTransform,
        symbolic_trait_value: u32,
        symbolic_trait_mask: u32,
    ) -> CTFontRef;
    fn CTFramesetterCreateWithAttributedString(string: CFAttributedStringRef) -> CTFramesetterRef;
    fn CTFramesetterSuggestFrameSizeWithConstraints(
        framesetter: CTFramesetterRef,
        string_range: CFRange,
        frame_attributes: CFDictionaryRef,
        constraints: CGSize,
        fit_range: *mut CFRange,
    ) -> CGSize;
    fn CTFramesetterCreateFrame(
        framesetter: CTFramesetterRef,
        string_range: CFRange,
        path: CGMutablePathRef,
        frame_attributes: CFDictionaryRef,
    ) -> CTFrameRef;
    fn CTFrameDraw(frame: CTFrameRef, context: CGContextRef);
}

pub struct AppleTextRenderer {
    cache: ExternalTextMaskCache,
}

impl AppleTextRenderer {
    pub fn new() -> Self {
        Self {
            cache: ExternalTextMaskCache::new(DEFAULT_LAYOUT_CACHE_CAP),
        }
    }

    fn measure_uncached(
        &mut self,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> (f32, f32) {
        if text.is_empty() {
            return (0.0, fallback_height(font_size));
        }
        with_framesetter(text, font_name, font_size, bold, italic, |framesetter| {
            let constraints = CGSize {
                width: max_width
                    .filter(|v| *v > 0.0 && v.is_finite())
                    .unwrap_or(1_000_000.0) as CGFloat,
                height: 1_000_000.0,
            };
            let size = unsafe {
                CTFramesetterSuggestFrameSizeWithConstraints(
                    framesetter,
                    whole_string_range(),
                    ptr::null(),
                    constraints,
                    ptr::null_mut(),
                )
            };
            (
                (size.width as f32).ceil().max(0.0),
                (size.height as f32).ceil().max(fallback_height(font_size)),
            )
        })
        .unwrap_or((0.0, fallback_height(font_size)))
    }

    fn render_uncached(
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
        let (measured_width, measured_height) =
            self.measure_uncached(text, font_name, font_size, bold, italic, max_width);
        let mask_width = measured_width.ceil().max(1.0) as i32;
        let mask_height = measured_height.ceil().max(1.0) as i32;
        let Some(alpha) = self.rasterize_alpha_mask(
            text,
            font_name,
            font_size,
            bold,
            italic,
            max_width,
            mask_width,
            mask_height,
        ) else {
            return measured_width;
        };
        blend_external_text_mask_into_rgba(
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
            mask_width,
            mask_height,
            &alpha,
            color,
        );
        measured_width
    }

    fn rasterize_alpha_mask(
        &mut self,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
        mask_width: i32,
        mask_height: i32,
    ) -> Option<Vec<u8>> {
        if text.is_empty() || mask_width <= 0 || mask_height <= 0 {
            return None;
        }
        let pixels = (mask_width as usize).checked_mul(mask_height as usize)?;
        if pixels == 0 || pixels > MAX_TEXT_MASK_PIXELS {
            return None;
        }
        let stride = (mask_width as usize).checked_mul(4)?;
        let byte_len = stride.checked_mul(mask_height as usize)?;
        let mut rgba = vec![0u8; byte_len];

        let drawn = with_framesetter(text, font_name, font_size, bold, italic, |framesetter| {
            let color_space = unsafe { CGColorSpaceCreateDeviceRGB() };
            if color_space.is_null() {
                return false;
            }
            let context = unsafe {
                CGBitmapContextCreate(
                    rgba.as_mut_ptr() as *mut c_void,
                    mask_width as usize,
                    mask_height as usize,
                    8,
                    stride,
                    color_space,
                    K_CG_IMAGE_ALPHA_PREMULTIPLIED_LAST,
                )
            };
            unsafe {
                CFRelease(color_space as *const c_void);
            }
            if context.is_null() {
                return false;
            }

            unsafe {
                CGContextSetShouldAntialias(context, 1);
                CGContextSetAllowsAntialiasing(context, 1);
                CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
                CGContextSetTextMatrix(context, CG_AFFINE_TRANSFORM_IDENTITY);
                CGContextTranslateCTM(context, 0.0, mask_height as CGFloat);
                CGContextScaleCTM(context, 1.0, -1.0);
            }

            let path = unsafe { CGPathCreateMutable() };
            if path.is_null() {
                unsafe {
                    CFRelease(context as *const c_void);
                }
                return false;
            }
            let width = max_width
                .filter(|v| *v > 0.0 && v.is_finite())
                .unwrap_or(mask_width as f32)
                .max(1.0);
            unsafe {
                CGPathAddRect(
                    path,
                    ptr::null(),
                    CGRect {
                        origin: CGPoint { x: 0.0, y: 0.0 },
                        size: CGSize {
                            width: width as CGFloat,
                            height: mask_height as CGFloat,
                        },
                    },
                );
                let frame =
                    CTFramesetterCreateFrame(framesetter, whole_string_range(), path, ptr::null());
                if frame.is_null() {
                    CFRelease(path as *const c_void);
                    CFRelease(context as *const c_void);
                    return false;
                }
                CTFrameDraw(frame, context);
                CFRelease(frame as *const c_void);
                CFRelease(path as *const c_void);
                CFRelease(context as *const c_void);
            }
            true
        })
        .unwrap_or(false);
        if !drawn {
            return None;
        }

        let mut alpha = vec![0u8; pixels];
        for i in 0..pixels {
            alpha[i] = rgba[i * 4 + 3];
        }
        Some(alpha)
    }

    fn ensure_cached_mask(
        &mut self,
        key: ExternalTextKey,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> bool {
        if self.cache.with_mask(&key, |_| ()).is_some() {
            return true;
        }

        let (measured_width, measured_height) =
            self.cached_measure(text, font_name, font_size, bold, italic, max_width);
        let mask_width = measured_width.ceil().max(1.0) as i32;
        let mask_height = measured_height.ceil().max(1.0) as i32;
        let Some(alpha) = self.rasterize_alpha_mask(
            text,
            font_name,
            font_size,
            bold,
            italic,
            max_width,
            mask_width,
            mask_height,
        ) else {
            return false;
        };
        self.cache.put_mask(
            key,
            ExternalTextMask {
                measured_width,
                measured_height,
                mask_width,
                mask_height,
                alpha,
            },
        );
        true
    }

    fn cached_measure(
        &mut self,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> (f32, f32) {
        if self.cache.is_disabled() {
            return self.measure_uncached(text, font_name, font_size, bold, italic, max_width);
        }

        let key = ExternalTextKey::new(text, font_name, font_size, bold, italic, max_width);
        if let Some(result) = self.cache.get_measure(&key) {
            return result;
        }
        let (width, height) =
            self.measure_uncached(text, font_name, font_size, bold, italic, max_width);
        self.cache.put_measure(key, width, height);
        (width, height)
    }
}

impl TextRenderer for AppleTextRenderer {
    fn renderer_name(&self) -> &str {
        "CoreText"
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
        self.cached_measure(text, font_name, font_size, bold, italic, max_width)
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
        if self.cache.is_disabled() {
            return self.render_uncached(
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

        let key = ExternalTextKey::new(text, font_name, font_size, bold, italic, max_width);
        if self.ensure_cached_mask(
            key.clone(),
            text,
            font_name,
            font_size,
            bold,
            italic,
            max_width,
        ) {
            if let Some(width) = self.cache.with_mask(&key, |entry| {
                blend_external_text_mask_into_rgba(
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
                    entry.mask_width,
                    entry.mask_height,
                    &entry.alpha,
                    color,
                );
                entry.measured_width
            }) {
                return width;
            }
        }

        self.render_uncached(
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

    fn cache_len(&self) -> usize {
        self.cache.len()
    }

    fn set_cache_cap(&mut self, cap: usize) {
        self.cache.set_cap(cap);
    }

    fn clear_cache(&mut self) {
        self.cache.clear();
    }
}

fn fallback_height(font_size: f32) -> f32 {
    font_size.max(1.0) * 1.2
}

fn whole_string_range() -> CFRange {
    CFRange {
        location: 0,
        length: 0,
    }
}

fn with_framesetter<R>(
    text: &str,
    font_name: &str,
    font_size: f32,
    bold: bool,
    italic: bool,
    f: impl FnOnce(CTFramesetterRef) -> R,
) -> Option<R> {
    unsafe {
        let text_ref = cf_string(text)?;
        let font = create_font(font_name, font_size, bold, italic)?;
        let keys = [kCTFontAttributeName as *const c_void];
        let values = [font as *const c_void];
        let attrs = CFDictionaryCreate(
            ptr::null(),
            keys.as_ptr(),
            values.as_ptr(),
            1,
            &kCFTypeDictionaryKeyCallBacks as *const _ as *const c_void,
            &kCFTypeDictionaryValueCallBacks as *const _ as *const c_void,
        );
        if attrs.is_null() {
            CFRelease(font as *const c_void);
            CFRelease(text_ref as *const c_void);
            return None;
        }
        let attributed = CFAttributedStringCreate(ptr::null(), text_ref, attrs);
        CFRelease(attrs as *const c_void);
        CFRelease(font as *const c_void);
        CFRelease(text_ref as *const c_void);
        if attributed.is_null() {
            return None;
        }
        let framesetter = CTFramesetterCreateWithAttributedString(attributed);
        CFRelease(attributed as *const c_void);
        if framesetter.is_null() {
            return None;
        }
        let result = f(framesetter);
        CFRelease(framesetter as *const c_void);
        Some(result)
    }
}

unsafe fn cf_string(s: &str) -> Option<CFStringRef> {
    let ptr = if s.is_empty() {
        b"\0".as_ptr()
    } else {
        s.as_ptr()
    };
    let len = if s.is_empty() { 0 } else { s.len() };
    let value = CFStringCreateWithBytes(
        ptr::null(),
        ptr,
        len as CFIndex,
        K_CF_STRING_ENCODING_UTF8,
        0,
    );
    (!value.is_null()).then_some(value)
}

unsafe fn create_font(
    font_name: &str,
    font_size: f32,
    bold: bool,
    italic: bool,
) -> Option<CTFontRef> {
    let size = font_size.max(1.0) as CGFloat;
    let mut font = if font_name.trim().is_empty() {
        CTFontCreateUIFontForLanguage(K_CT_FONT_UI_TYPE_SYSTEM, size, ptr::null())
    } else if let Some(name) = cf_string(font_name.trim()) {
        let created = CTFontCreateWithName(name, size, ptr::null());
        CFRelease(name as *const c_void);
        created
    } else {
        ptr::null()
    };
    if font.is_null() {
        let fallback = cf_string("Helvetica Neue")?;
        font = CTFontCreateWithName(fallback, size, ptr::null());
        CFRelease(fallback as *const c_void);
    }
    if font.is_null() {
        return None;
    }

    let mut traits = 0u32;
    if bold {
        traits |= K_CT_FONT_BOLD_TRAIT;
    }
    if italic {
        traits |= K_CT_FONT_ITALIC_TRAIT;
    }
    if traits != 0 {
        let styled = CTFontCreateCopyWithSymbolicTraits(font, size, ptr::null(), traits, traits);
        if !styled.is_null() {
            CFRelease(font as *const c_void);
            font = styled;
        }
    }
    Some(font)
}
