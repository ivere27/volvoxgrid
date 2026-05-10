using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;

namespace VolvoxGrid.DotNet.Internal
{
    internal sealed class GdiTextRendererBridge : IDisposable
    {
        private struct FontKey : IEquatable<FontKey>
        {
            public string Family;
            public float SizePx;
            public FontStyle Style;

            public bool Equals(FontKey other)
            {
                return string.Equals(Family, other.Family, StringComparison.OrdinalIgnoreCase)
                    && SizePx.Equals(other.SizePx)
                    && Style == other.Style;
            }

            public override bool Equals(object obj)
            {
                return obj is FontKey && Equals((FontKey)obj);
            }

            public override int GetHashCode()
            {
                unchecked
                {
                    int hash = StringComparer.OrdinalIgnoreCase.GetHashCode(Family ?? string.Empty);
                    hash = (hash * 397) ^ SizePx.GetHashCode();
                    hash = (hash * 397) ^ (int)Style;
                    return hash;
                }
            }
        }

        private readonly object _fontSync = new object();
        private readonly Dictionary<FontKey, Font> _fonts = new Dictionary<FontKey, Font>();
        private readonly SynurangReflectionHost.SynMeasureTextCallback _measureCallback;
        private readonly SynurangReflectionHost.SynRenderTextCallback _renderCallback;
        private bool _disposed;

        public GdiTextRendererBridge()
        {
            _measureCallback = MeasureTextCallback;
            _renderCallback = RenderTextCallback;
        }

        public static bool ShouldUseForCurrentProcess()
        {
            // Default to the engine's built-in cosmic-text path. The host-side
            // GDI bridge remains available as an opt-in for Wine-specific
            // compatibility experiments. Lite native builds have no built-in
            // text engine and are handled automatically in Register().
            return IsTruthyEnvironmentVariable("VOLVOXGRID_DOTNET_USE_HOST_TEXT_RENDERER")
                && !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("WINEPREFIX"));
        }

        public void Register(VolvoxClient client, long gridId)
        {
            if (_disposed || client == null || gridId == 0 || !client.SupportsHostTextRenderer)
            {
                return;
            }

            if (client.HasBuiltinTextEngine && !ShouldUseForCurrentProcess())
            {
                return;
            }

            client.SetTextRenderer(gridId, _measureCallback, _renderCallback);
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            lock (_fontSync)
            {
                foreach (Font font in _fonts.Values)
                {
                    font.Dispose();
                }
                _fonts.Clear();
            }
        }

        private static bool IsTruthyEnvironmentVariable(string name)
        {
            string raw = Environment.GetEnvironmentVariable(name);
            if (string.IsNullOrEmpty(raw))
            {
                return false;
            }

            switch (raw.Trim().ToLowerInvariant())
            {
                case "1":
                case "true":
                case "yes":
                case "on":
                    return true;
                default:
                    return false;
            }
        }

        private void MeasureTextCallback(
            IntPtr textPtr,
            int textLen,
            IntPtr fontNamePtr,
            int fontNameLen,
            float fontSize,
            int bold,
            int italic,
            float maxWidth,
            out float outWidth,
            out float outHeight,
            IntPtr userData)
        {
            outWidth = 0.0f;
            outHeight = FallbackHeight(fontSize);

            string text = Utf8FromPtr(textPtr, textLen);
            if (_disposed || string.IsNullOrEmpty(text))
            {
                return;
            }

            string fontName = Utf8FromPtr(fontNamePtr, fontNameLen);
            Font font = GetFont(fontName, fontSize, bold != 0, italic != 0);
            TextMeasurement measurement = MeasureTextUncached(text, font, fontSize, maxWidth);
            outWidth = measurement.Width;
            outHeight = measurement.Height;
        }

        private float RenderTextCallback(
            IntPtr buffer,
            int bufWidth,
            int bufHeight,
            int stride,
            int x,
            int y,
            int clipX,
            int clipY,
            int clipW,
            int clipH,
            IntPtr textPtr,
            int textLen,
            IntPtr fontNamePtr,
            int fontNameLen,
            float fontSize,
            int bold,
            int italic,
            uint color,
            float maxWidth,
            IntPtr userData)
        {
            string text = Utf8FromPtr(textPtr, textLen);
            string fontName = Utf8FromPtr(fontNamePtr, fontNameLen);
            Font font = GetFont(fontName, fontSize, bold != 0, italic != 0);

            TextMeasurement measurement = MeasureTextUncached(text, font, fontSize, maxWidth);

            if (_disposed
                || buffer == IntPtr.Zero
                || string.IsNullOrEmpty(text)
                || clipW <= 0
                || clipH <= 0
                || bufWidth <= 0
                || bufHeight <= 0
                || stride <= 0)
            {
                return measurement.Width;
            }

            MaskCacheEntry mask = RasterizeMask(text, font, measurement, maxWidth);
            BlendMaskIntoBuffer(mask, buffer, bufWidth, bufHeight, stride, x, y, clipX, clipY, clipW, clipH, color);

            return measurement.Width;
        }

        private TextMeasurement MeasureTextUncached(string text, Font font, float fontSize, float maxWidth)
        {
            using (var bitmap = new Bitmap(1, 1, PixelFormat.Format32bppArgb))
            using (var graphics = Graphics.FromImage(bitmap))
            using (var format = CreateStringFormat(maxWidth))
            {
                ConfigureGraphics(graphics);
                SizeF limit = maxWidth > 0.0f
                    ? new SizeF(maxWidth, 100000.0f)
                    : new SizeF(100000.0f, 100000.0f);
                SizeF measured = graphics.MeasureString(text, font, limit, format);
                return new TextMeasurement(
                    (float)Math.Ceiling(measured.Width),
                    Math.Max((float)Math.Ceiling(measured.Height), font.GetHeight(graphics)));
            }
        }

        private MaskCacheEntry RasterizeMask(string text, Font font, TextMeasurement measurement, float maxWidth)
        {
            int maskW = Math.Max(1, (int)Math.Ceiling(measurement.Width));
            int maskH = Math.Max(1, (int)Math.Ceiling(measurement.Height));
            byte[] alpha;
            using (var bitmap = new Bitmap(maskW, maskH, PixelFormat.Format32bppArgb))
            using (var graphics = Graphics.FromImage(bitmap))
            using (var format = CreateStringFormat(maxWidth))
            using (var brush = new SolidBrush(Color.White))
            {
                ConfigureGraphics(graphics);
                graphics.Clear(Color.Transparent);
                if (maxWidth > 0.0f)
                {
                    graphics.DrawString(text, font, brush, new RectangleF(0.0f, 0.0f, maxWidth, maskH), format);
                }
                else
                {
                    graphics.DrawString(text, font, brush, new PointF(0.0f, 0.0f), format);
                }
                alpha = ExtractAlphaMask(bitmap);
            }

            return new MaskCacheEntry
            {
                Measurement = measurement,
                MaskWidth = maskW,
                MaskHeight = maskH,
                Alpha = alpha,
            };
        }

        private Font GetFont(string fontName, float fontSize, bool bold, bool italic)
        {
            float sizePx = fontSize > 0.0f ? fontSize : 11.0f;
            FontStyle style = FontStyle.Regular;
            if (bold)
            {
                style |= FontStyle.Bold;
            }
            if (italic)
            {
                style |= FontStyle.Italic;
            }

            string family = string.IsNullOrEmpty(fontName) ? SystemFonts.DefaultFont.FontFamily.Name : fontName;
            var key = new FontKey { Family = family, SizePx = sizePx, Style = style };

            lock (_fontSync)
            {
                Font font;
                if (_fonts.TryGetValue(key, out font))
                {
                    return font;
                }

                try
                {
                    font = new Font(family, sizePx, style, GraphicsUnit.Pixel);
                }
                catch
                {
                    font = new Font(SystemFonts.DefaultFont.FontFamily, sizePx, style, GraphicsUnit.Pixel);
                }

                _fonts[key] = font;
                return font;
            }
        }

        private static void ConfigureGraphics(Graphics graphics)
        {
            graphics.PageUnit = GraphicsUnit.Pixel;
            graphics.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        }

        private static StringFormat CreateStringFormat(float maxWidth)
        {
            var format = (StringFormat)StringFormat.GenericTypographic.Clone();
            format.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces;
            if (!(maxWidth > 0.0f))
            {
                format.FormatFlags |= StringFormatFlags.NoWrap;
            }
            return format;
        }

        private static string Utf8FromPtr(IntPtr ptr, int len)
        {
            if (ptr == IntPtr.Zero || len <= 0)
            {
                return string.Empty;
            }

            byte[] bytes = new byte[len];
            Marshal.Copy(ptr, bytes, 0, len);
            return System.Text.Encoding.UTF8.GetString(bytes);
        }

        private static byte[] ExtractAlphaMask(Bitmap bitmap)
        {
            Rectangle rect = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
            BitmapData data = bitmap.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try
            {
                byte[] alpha = new byte[bitmap.Width * bitmap.Height];
                byte[] row = new byte[bitmap.Width * 4];
                for (int y = 0; y < bitmap.Height; y++)
                {
                    IntPtr srcPtr = IntPtr.Add(data.Scan0, y * data.Stride);
                    Marshal.Copy(srcPtr, row, 0, row.Length);
                    for (int x = 0; x < bitmap.Width; x++)
                    {
                        alpha[y * bitmap.Width + x] = row[x * 4 + 3];
                    }
                }
                return alpha;
            }
            finally
            {
                bitmap.UnlockBits(data);
            }
        }

        private static void BlendMaskIntoBuffer(
            MaskCacheEntry mask,
            IntPtr targetBuffer,
            int bufWidth,
            int bufHeight,
            int stride,
            int x,
            int y,
            int clipX,
            int clipY,
            int clipW,
            int clipH,
            uint color)
        {
            if (mask == null || mask.Alpha == null || mask.Alpha.Length == 0 || targetBuffer == IntPtr.Zero)
            {
                return;
            }

            int globalA = (int)((color >> 24) & 0xFF);
            if (globalA <= 0)
            {
                return;
            }
            int srcR = (int)((color >> 16) & 0xFF);
            int srcG = (int)((color >> 8) & 0xFF);
            int srcB = (int)(color & 0xFF);

            int minX = Math.Max(Math.Max(x, clipX), 0);
            int minY = Math.Max(Math.Max(y, clipY), 0);
            int maxX = Math.Min(Math.Min(x + mask.MaskWidth, clipX + clipW), bufWidth);
            int maxY = Math.Min(Math.Min(y + mask.MaskHeight, y + clipH), bufHeight);
            if (maxX <= minX || maxY <= minY)
            {
                return;
            }

            int blendW = maxX - minX;
            byte[] dstRow = new byte[blendW * 4];

            for (int row = minY; row < maxY; row++)
            {
                IntPtr dstPtr = IntPtr.Add(targetBuffer, row * stride + minX * 4);
                Marshal.Copy(dstPtr, dstRow, 0, dstRow.Length);

                int maskBase = (row - y) * mask.MaskWidth + (minX - x);
                for (int col = 0; col < blendW; col++)
                {
                    int maskA = mask.Alpha[maskBase + col];
                    if (maskA < 0)
                    {
                        maskA += 256;
                    }
                    if (maskA <= 0)
                    {
                        continue;
                    }

                    int srcA = (maskA * globalA + 127) / 255;
                    if (srcA <= 0)
                    {
                        continue;
                    }

                    int i = col * 4;
                    int inv = 255 - srcA;
                    int dstR = dstRow[i];
                    int dstG = dstRow[i + 1];
                    int dstB = dstRow[i + 2];
                    int dstA = dstRow[i + 3];

                    dstRow[i] = (byte)((srcR * srcA + dstR * inv + 127) / 255);
                    dstRow[i + 1] = (byte)((srcG * srcA + dstG * inv + 127) / 255);
                    dstRow[i + 2] = (byte)((srcB * srcA + dstB * inv + 127) / 255);

                    int outA = srcA + (dstA * inv + 127) / 255;
                    dstRow[i + 3] = (byte)(outA > 255 ? 255 : outA);
                }

                Marshal.Copy(dstRow, 0, dstPtr, dstRow.Length);
            }
        }

        private static float FallbackHeight(float fontSize)
        {
            return fontSize > 0.0f ? fontSize * 1.2f : 0.0f;
        }

        private struct TextMeasurement
        {
            public float Width;
            public float Height;

            public TextMeasurement(float width, float height)
            {
                Width = width;
                Height = height;
            }
        }

        private sealed class MaskCacheEntry
        {
            public TextMeasurement Measurement;
            public int MaskWidth;
            public int MaskHeight;
            public byte[] Alpha;
        }
    }
}
