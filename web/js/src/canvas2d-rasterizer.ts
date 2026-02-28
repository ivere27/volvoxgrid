/**
 * Canvas2D-based glyph rasterizer for VolvoxGrid WASM.
 *
 * When the engine's SwashCache cannot produce a glyph (e.g. font not loaded
 * into the engine but available to the browser), this rasterizer uses an
 * offscreen Canvas2D to render the character and returns the alpha bitmap.
 *
 * Usage:
 *   import { createCanvas2DRasterizer } from './canvas2d-rasterizer';
 *   import { set_glyph_rasterizer } from '../crate/pkg/volvoxgrid_web';
 *   set_glyph_rasterizer(createCanvas2DRasterizer());
 */

interface GlyphBitmap {
  width: number;
  height: number;
  offsetX: number;
  offsetY: number;
  advanceWidth: number;
  data: Uint8Array;
}

export function createCanvas2DRasterizer(): (
  char: string,
  fontName: string,
  fontSize: number,
  bold: boolean,
  italic: boolean,
) => GlyphBitmap | null {
  const canvas = document.createElement('canvas');
  canvas.width = 64;
  canvas.height = 64;
  const ctx = canvas.getContext('2d', { willReadFrequently: true })!;

  return function rasterizeGlyph(
    char: string,
    fontName: string,
    fontSize: number,
    bold: boolean,
    italic: boolean,
  ): GlyphBitmap | null {
    const style = `${italic ? 'italic ' : ''}${bold ? 'bold ' : ''}${fontSize}px "${fontName}", sans-serif`;
    ctx.font = style;
    const metrics = ctx.measureText(char);
    const w = Math.ceil(metrics.width);
    const asc = Math.ceil(metrics.actualBoundingBoxAscent || fontSize);
    const desc = Math.ceil(metrics.actualBoundingBoxDescent || 0);
    const h = asc + desc;

    if (w <= 0 || h <= 0) return null;

    // Grow canvas if needed (no shrink — avoids thrashing).
    if (canvas.width < w) canvas.width = w;
    if (canvas.height < h) canvas.height = h;

    ctx.clearRect(0, 0, w, h);
    ctx.font = style;
    ctx.fillStyle = 'white';
    ctx.textBaseline = 'alphabetic';
    ctx.fillText(char, 0, asc);

    const imageData = ctx.getImageData(0, 0, w, h);
    const alpha = new Uint8Array(w * h);
    for (let i = 0; i < w * h; i++) {
      alpha[i] = imageData.data[i * 4 + 3]; // extract alpha channel
    }

    return { width: w, height: h, offsetX: 0, offsetY: asc, advanceWidth: metrics.width, data: alpha };
  };
}
