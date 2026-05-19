# Text Rendering

## Who this is for

You're an engineer wiring up text for a VolvoxGrid host, or you're building a lite build that has to outsource rasterization to a platform font stack. This doc walks through how text works in full and lite modes.

After reading, you'll know which mode you're in, who owns the cache, what your host renderer has to do, and what the debug overlay is telling you. For broader GUI context, see [GUI.md](GUI.md). For repo structure and build workflow, see [ARCHITECTURE.md](ARCHITECTURE.md).

Next: why there are two modes at all.

## Why two modes exist

VolvoxGrid has two text-rendering modes. They exist for very different reasons.

**Engine text.** Normal native and WASM builds include the Rust text engine (`cosmic-text`). The engine measures, shapes, caches, and renders text. You don't think about it.

**External text.** Lite builds remove the built-in text engine. The host registers a platform text renderer, and the Rust engine still owns cache policy, clipping, color blending, and render orchestration.

The point of lite builds is artifact size. They use the operating system or browser font stack instead of bundling the full engine text stack. You give up exact glyph parity across platforms; you gain a much smaller binary and you inherit platform font fallback for free.

Next: which package is which.

## The package matrix

| Platform path | Full package | Lite package | Lite backend |
|---|---|---|---|
| Android View | `volvoxgrid-android` | `volvoxgrid-android-lite` | Android `TextPaint` / `Canvas` |
| Android Compose | `volvoxgrid-android-compose` | `volvoxgrid-android-compose-lite` | Android `TextPaint` / `Canvas` |
| Java desktop | `volvoxgrid-desktop` | `volvoxgrid-desktop-lite` | Java2D |
| macOS native / Flutter macOS | `volvoxgrid-desktop` | `volvoxgrid-desktop-lite` | CoreText / CoreGraphics |
| iOS native / Flutter iOS | `VolvoxGrid.xcframework` | `VolvoxGridLite.xcframework` | CoreText / CoreGraphics |
| Web / WASM | `volvoxgrid` | `volvoxgrid-lite` | Browser Canvas2D |
| `.NET` | `VolvoxGrid.DotNet` | `VolvoxGrid.DotNet.Lite` | GDI / GDI+ |

The same `VOLVOXGRID_VARIANT=lite` convention drives local sample targets where the host supports both variants.

Next: the key insight about lite mode.

## Who owns the cache?

The engine owns the primary text cache in both full and lite modes. This is the part that surprises people.

In full mode, `TextEngine` caches shaped layouts. In lite mode, the runtime wraps the host callbacks in an external text renderer and caches measured sizes plus alpha masks in Rust. Cached alpha masks are color-independent, so the engine can blend the same cached text mask with different cell colors.

The cache key includes:

- text
- font family
- font size
- bold and italic state
- wrapping width

The cache key does not include color.

In lite mode, the host isn't a caching layer. It's just a rasterizer that gets called on cache misses. The engine decides what gets cached, when to evict, and how to blend the result.

`text_layout_cache_cap` controls the cache capacity. Setting it to `0` disables and clears the cache.

Next: what that means for your host code.

## What the host renderer has to do

In lite mode, the host callback handles only the platform-specific parts:

- measure text
- rasterize text into an RGBA scratch buffer or mask
- use the host OS or browser font fallback stack

The engine remains responsible for:

- layout decisions
- cache capacity and eviction
- clipping
- color application
- final blending into the grid buffer
- debug overlay cache reporting

Hosts may keep small platform caches for font objects or scratch buffers. For example, Java2D caches `Font` objects, .NET caches `Font` objects, Android reuses a scratch `Bitmap` / `Canvas`, and Browser Canvas2D reuses canvas state. These aren't the main text layout or mask cache. They just avoid reallocating platform objects on every cache miss.

Next: how long caches stick around.

## Cache lifetime

Text caches are intentionally grid-local.

When a render stream switches from one active grid to another, the runtime clears the previous grid's text cache and the active renderer cache. That prevents stale caches from accumulating when an app opens grids A, B, and C, then only keeps rendering C.

Destroying or releasing a grid also clears the external text renderer registration for that grid.

Next: the debug overlay tells you everything you need.

## Debug overlay

The third debug-overlay line shows the renderer mode and text backend. Sample lines:

```text
CPU Text:Engine 1000000x12 CLEAN
CPU Text:Java2D 1000000x12 CLEAN
GPU(vulkan-fifo) Text:Engine 1000000x12 CLEAN
CPU Text:GDI 1000000x12 DIRTY(V:1200)
```

Backend names:

- `Engine`: built-in Rust text engine
- `Android`: Android lite fallback
- `Browser`: WASM lite fallback
- `CoreText`: macOS/iOS native lite fallback
- `Java2D`: Java desktop lite fallback
- `GDI`: .NET lite fallback

The next line contains `C:<used>/<cap>`, for example:

```text
Vis: 45x9(405) P:0,0 M:12.4MB C:3021/8192
```

In lite mode, `used` is the Rust-owned external text mask cache count, not a platform-side cache count.

If you see `C:0/8192` in lite mode while text is visible, the host probably hasn't registered its external renderer, or the grid is using an older WASM/native artifact.

Next: a few per-platform notes.

## Per-platform notes

### Android

Android lite registers an Android text renderer through JNI only when the native library has no built-in text engine. The Java/Kotlin side uses Android text APIs for font fallback, while the runtime owns the external text mask cache.

`VolvoxGridView.setAndroidTextCacheSize(...)` is kept as a compatibility API, but the effective lite cache size is driven by the engine's `text_layout_cache_cap`.

Flutter Android goes through the Android host layer, so it can use the same Android text fallback when the Android native/runtime artifact is lite.

### Flutter desktop

Flutter desktop uses the native library directly from Dart FFI. On macOS, `volvoxgrid-desktop-lite` uses the runtime's CoreText fallback, so Flutter macOS can use `VOLVOXGRID_VARIANT=lite`. Linux and Windows Flutter desktop should use the full native runtime until a platform text fallback bridge or native default backend exists for those hosts.

### Apple native

macOS and iOS lite runtimes register a CoreText/CoreGraphics renderer inside the native runtime when `cosmic-text` isn't compiled in. This path uses the Apple system font stack for fallback and keeps the primary measure/mask cache in Rust, so it works for Swift, Flutter, and any other host that loads the Apple native library.

iOS lite is packaged as `VolvoxGridLite.xcframework`. Consumers that link it directly must link `CoreFoundation`, `CoreGraphics`, and `CoreText`. The Flutter iOS podspec does this automatically.

### Java desktop

Java desktop lite registers a Java2D renderer only when the native library has no built-in text engine. The Java2D bridge keeps a small `Font` object cache, while Rust owns the layout/mask cache shown as `C:` in the overlay.

### Web / WASM

`volvoxgrid-lite` uses Browser Canvas2D callbacks. The WASM runtime owns the external text mask cache. Canvas2D only performs measurement and rasterization on cache misses.

### .NET

`VolvoxGrid.DotNet.Lite` registers a GDI/GDI+ renderer when the native library has no built-in text engine. Full .NET builds use the engine text path by default. On Wine, the GDI bridge can also be enabled for compatibility experiments with `VOLVOXGRID_DOTNET_USE_HOST_TEXT_RENDERER=1`.

Wine logs such as `fixme:gdiplus:GdipGetLineSpacing ignoring style` come from Wine's GDI+ implementation. They're not VolvoxGrid engine errors and won't appear on real Windows for the same reason.

Next: a short checklist when you add a new lite host.

## Checklist when adding a new lite host

1. Register a named external text renderer only when `volvox_grid_has_builtin_text_engine()` is false.
2. Implement measurement and rasterization callbacks in platform code.
3. Keep platform caches small and object-focused. Let Rust own layout and mask caching.
4. Clear the registration when the grid is released.
5. Confirm the debug overlay shows the expected `Text:<backend>` name and that `C:<used>/<cap>` behaves as text gets cached.
