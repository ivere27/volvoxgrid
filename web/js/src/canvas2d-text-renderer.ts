/**
 * Canvas2D-based full text renderer for VolvoxGrid WASM (Lite mode).
 *
 * When the engine is built without cosmic-text, this renderer handles both
 * text measurement and pixel-level rendering into the engine's buffer.
 */

export function createCanvas2DTextRenderer(wasm: any) {
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d', { willReadFrequently: true })!;

  interface LineMetrics {
    lineHeight: number;
    baseline: number;
  }

  const getMemory = () => (wasm.wasm_memory ? wasm.wasm_memory().buffer : wasm.memory.buffer);

  function setCacheSize(_size: number) {
    // Cache ownership lives in the Rust text renderer. Keep this method for
    // compatibility with older callers.
  }

  function cacheSize() {
    return 0;
  }

  function getFontStyle(fontName: string, fontSize: number, bold: boolean, italic: boolean): string {
    const family = fontName ? `"${fontName}", sans-serif` : 'sans-serif';
    return `${italic ? 'italic ' : ''}${bold ? 'bold ' : ''}${fontSize}px ${family}`;
  }

  function getLineMetrics(fontSize: number): LineMetrics {
    const sample = ctx.measureText('Mg');
    const ascent = Math.max(1, sample.fontBoundingBoxAscent ?? sample.actualBoundingBoxAscent ?? (fontSize * 0.8));
    const descent = Math.max(0, sample.fontBoundingBoxDescent ?? sample.actualBoundingBoxDescent ?? (fontSize * 0.2));
    const glyphHeight = ascent + descent;
    const lineHeight = Math.max(Math.ceil(fontSize * 1.2), Math.ceil(glyphHeight));
    // Split extra leading equally above/below the glyph box so line-box centering
    // does not look top-biased.
    const baseline = ((lineHeight - glyphHeight) * 0.5) + ascent;
    return { lineHeight, baseline };
  }

  function measureText(
    text: string,
    fontName: string,
    fontSize: number,
    bold: boolean,
    italic: boolean,
    maxWidth: number | null,
  ) {
    ctx.font = getFontStyle(fontName, fontSize, bold, italic);
    const { lineHeight } = getLineMetrics(fontSize);
    
    if (maxWidth !== null && maxWidth > 0) {
      const words = text.split(' ');
      let lines = 1;
      let currentLine = '';
      let maxW = 0;
      
      for (const word of words) {
        const testLine = currentLine ? currentLine + ' ' + word : word;
        const metrics = ctx.measureText(testLine);
        if (metrics.width > maxWidth && currentLine) {
          maxW = Math.max(maxW, ctx.measureText(currentLine).width);
          currentLine = word;
          lines++;
        } else {
          currentLine = testLine;
        }
      }
      maxW = Math.max(maxW, ctx.measureText(currentLine).width);
      return { width: maxW, height: lines * lineHeight };
    } else {
      const metrics = ctx.measureText(text);
      return { width: metrics.width, height: lineHeight };
    }
  }

  function renderText(
    ptr: number,
    bufWidth: number,
    bufHeight: number,
    stride: number,
    x: number,
    y: number,
    clipX: number,
    clipY: number,
    clipW: number,
    clipH: number,
    text: string,
    fontName: string,
    fontSize: number,
    bold: boolean,
    italic: boolean,
    color: number,
    maxWidth: number | null,
  ): number {
    const { lineHeight: lh, baseline } = getLineMetrics(fontSize);
    const style = getFontStyle(fontName, fontSize, bold, italic);
    ctx.font = style;

    let tw = 0;
    let th = 0;
    let lines: string[] = [];

    if (maxWidth !== null && maxWidth > 0) {
      const words = text.split(' ');
      let currentLine = '';
      for (const word of words) {
        const testLine = currentLine ? currentLine + ' ' + word : word;
        if (ctx.measureText(testLine).width > maxWidth && currentLine) {
          lines.push(currentLine);
          currentLine = word;
        } else {
          currentLine = testLine;
        }
      }
      lines.push(currentLine);
      tw = Math.ceil(maxWidth);
      th = Math.ceil(lines.length * lh);
    } else {
      const m = ctx.measureText(text);
      tw = Math.ceil(m.width);
      th = Math.ceil(lh);
      lines = [text];
    }

    if (tw <= 0 || th <= 0) return 0;

    if (canvas.width < tw) canvas.width = tw;
    if (canvas.height < th) canvas.height = th;

    // Render black text on white background and derive alpha from inverse
    // luminance. This captures subpixel antialiasing from all three colour
    // channels, producing a much sharper mask than white-on-transparent alpha.
    ctx.fillStyle = 'white';
    ctx.fillRect(0, 0, tw, th);
    ctx.font = style;
    ctx.textBaseline = 'alphabetic';
    ctx.fillStyle = 'black';

    lines.forEach((line, i) => {
      ctx.fillText(line, 0, i * lh + baseline);
    });

    const imageData = ctx.getImageData(0, 0, tw, th);
    const alphaData = new Uint8Array(tw * th);
    for (let i = 0; i < tw * th; i++) {
      const ri = imageData.data[i * 4];
      const gi = imageData.data[i * 4 + 1];
      const bi = imageData.data[i * 4 + 2];
      alphaData[i] = 255 - ((ri + gi + bi + 1) / 3 | 0);
    }

    const realWidth = (maxWidth !== null && maxWidth > 0) ? tw : ctx.measureText(text).width;
    const rx = Math.round(x);
    const ry = Math.round(y);
    const rcx = Math.round(clipX);
    const rcy = Math.round(clipY);
    const rcw = Math.round(clipW);
    const rch = Math.round(clipH);

    const xMin = Math.max(rx, rcx);
    const yMin = Math.max(ry, rcy);
    const xMax = Math.min(rx + tw, rcx + rcw, bufWidth);
    // Engine convention: clip_h is relative to text y, not clip_y.
    const yMax = Math.min(ry + th, ry + rch, bufHeight);
    
    if (xMax <= xMin || yMax <= yMin) return realWidth;

    const buf = new Uint8Array(getMemory(), ptr, bufHeight * stride);
    const r = (color >> 16) & 0xFF;
    const g = (color >> 8) & 0xFF;
    const b = color & 0xFF;
    const a_global = ((color >> 24) & 0xFF) / 255.0;

    for (let py = yMin; py < yMax; py++) {
      const sy = py - ry;
      const rowOff = py * stride;
      const srcRowOff = sy * tw;
      for (let px = xMin; px < xMax; px++) {
        const sx = px - rx;
        const alpha = (alphaData[srcRowOff + sx] / 255.0) * a_global;
        if (alpha <= 0) continue;
        
        const dstIdx = rowOff + px * 4;
        if (alpha >= 1.0) {
          buf[dstIdx] = r;
          buf[dstIdx + 1] = g;
          buf[dstIdx + 2] = b;
          buf[dstIdx + 3] = 255;
        } else {
          const inv = 1.0 - alpha;
          buf[dstIdx] = (r * alpha + buf[dstIdx] * inv);
          buf[dstIdx + 1] = (g * alpha + buf[dstIdx + 1] * inv);
          buf[dstIdx + 2] = (b * alpha + buf[dstIdx + 2] * inv);
          buf[dstIdx + 3] = (255 * alpha + buf[dstIdx + 3] * inv);
        }
      }
    }
    
    return realWidth;
  }

  return { measureText, renderText, setCacheSize, cacheSize };
}
