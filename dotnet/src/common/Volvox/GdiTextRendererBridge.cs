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
            // compatibility experiments.
            return IsTruthyEnvironmentVariable("VOLVOXGRID_DOTNET_USE_HOST_TEXT_RENDERER")
                && !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("WINEPREFIX"));
        }

        public void Register(VolvoxClient client, long gridId)
        {
            if (_disposed || client == null || gridId == 0 || !ShouldUseForCurrentProcess() || !client.SupportsHostTextRenderer)
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
            MeasureTextInternal(
                textPtr,
                textLen,
                fontNamePtr,
                fontNameLen,
                fontSize,
                bold != 0,
                italic != 0,
                maxWidth,
                out outWidth,
                out outHeight);
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
            float measuredWidth;
            float measuredHeight;
            string text = Utf8FromPtr(textPtr, textLen);
            string fontName = Utf8FromPtr(fontNamePtr, fontNameLen);

            MeasureTextInternal(
                textPtr,
                textLen,
                fontNamePtr,
                fontNameLen,
                fontSize,
                bold != 0,
                italic != 0,
                maxWidth,
                out measuredWidth,
                out measuredHeight);

            if (_disposed
                || buffer == IntPtr.Zero
                || string.IsNullOrEmpty(text)
                || clipW <= 0
                || clipH <= 0
                || bufWidth <= 0
                || bufHeight <= 0
                || stride <= 0)
            {
                return measuredWidth;
            }

            Font font = GetFont(fontName, fontSize, bold != 0, italic != 0);
            using (var bitmap = new Bitmap(Math.Max(1, clipW), Math.Max(1, clipH), PixelFormat.Format32bppArgb))
            using (var graphics = Graphics.FromImage(bitmap))
            using (var format = CreateStringFormat(maxWidth))
            using (var brush = new SolidBrush(ColorFromArgb(color)))
            {
                ConfigureGraphics(graphics);
                graphics.Clear(Color.Transparent);

                float localX = x - clipX;
                float localY = y - clipY;
                if (maxWidth > 0.0f)
                {
                    graphics.DrawString(
                        text,
                        font,
                        brush,
                        new RectangleF(localX, localY, maxWidth, Math.Max(clipH, measuredHeight)),
                        format);
                }
                else
                {
                    graphics.DrawString(text, font, brush, new PointF(localX, localY), format);
                }

                BlendBitmapIntoBuffer(bitmap, buffer, bufWidth, bufHeight, stride, clipX, clipY, clipW, clipH);
            }

            return measuredWidth;
        }

        private void MeasureTextInternal(
            IntPtr textPtr,
            int textLen,
            IntPtr fontNamePtr,
            int fontNameLen,
            float fontSize,
            bool bold,
            bool italic,
            float maxWidth,
            out float outWidth,
            out float outHeight)
        {
            outWidth = 0.0f;
            outHeight = fontSize > 0.0f ? fontSize * 1.2f : 0.0f;

            if (_disposed)
            {
                return;
            }

            string text = Utf8FromPtr(textPtr, textLen);
            if (string.IsNullOrEmpty(text))
            {
                return;
            }

            string fontName = Utf8FromPtr(fontNamePtr, fontNameLen);
            Font font = GetFont(fontName, fontSize, bold, italic);

            using (var bitmap = new Bitmap(1, 1, PixelFormat.Format32bppArgb))
            using (var graphics = Graphics.FromImage(bitmap))
            using (var format = CreateStringFormat(maxWidth))
            {
                ConfigureGraphics(graphics);
                SizeF limit = maxWidth > 0.0f
                    ? new SizeF(maxWidth, 100000.0f)
                    : new SizeF(100000.0f, 100000.0f);
                SizeF measured = graphics.MeasureString(text, font, limit, format);
                outWidth = (float)Math.Ceiling(measured.Width);
                outHeight = Math.Max((float)Math.Ceiling(measured.Height), font.GetHeight(graphics));
            }
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

        private static Color ColorFromArgb(uint color)
        {
            return Color.FromArgb(
                (int)((color >> 24) & 0xFF),
                (int)((color >> 16) & 0xFF),
                (int)((color >> 8) & 0xFF),
                (int)(color & 0xFF));
        }

        private static void BlendBitmapIntoBuffer(
            Bitmap bitmap,
            IntPtr targetBuffer,
            int bufWidth,
            int bufHeight,
            int stride,
            int clipX,
            int clipY,
            int clipW,
            int clipH)
        {
            Rectangle rect = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
            BitmapData data = bitmap.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try
            {
                int srcX = 0;
                int srcY = 0;
                int dstX = clipX;
                int dstY = clipY;
                int blendW = clipW;
                int blendH = clipH;

                if (dstX < 0)
                {
                    srcX = -dstX;
                    blendW += dstX;
                    dstX = 0;
                }
                if (dstY < 0)
                {
                    srcY = -dstY;
                    blendH += dstY;
                    dstY = 0;
                }

                blendW = Math.Min(blendW, bufWidth - dstX);
                blendH = Math.Min(blendH, bufHeight - dstY);
                if (blendW <= 0 || blendH <= 0)
                {
                    return;
                }

                byte[] srcRow = new byte[blendW * 4];
                byte[] dstRow = new byte[blendW * 4];

                for (int row = 0; row < blendH; row++)
                {
                    IntPtr srcPtr = IntPtr.Add(data.Scan0, (srcY + row) * data.Stride + srcX * 4);
                    Marshal.Copy(srcPtr, srcRow, 0, srcRow.Length);

                    IntPtr dstPtr = IntPtr.Add(targetBuffer, (dstY + row) * stride + dstX * 4);
                    Marshal.Copy(dstPtr, dstRow, 0, dstRow.Length);

                    for (int i = 0; i < srcRow.Length; i += 4)
                    {
                        int alpha = srcRow[i + 3];
                        if (alpha <= 0)
                        {
                            continue;
                        }

                        int inv = 255 - alpha;
                        int srcB = srcRow[i];
                        int srcG = srcRow[i + 1];
                        int srcR = srcRow[i + 2];
                        int dstR = dstRow[i];
                        int dstG = dstRow[i + 1];
                        int dstB = dstRow[i + 2];
                        int dstA = dstRow[i + 3];

                        dstRow[i] = (byte)((srcR * alpha + dstR * inv + 127) / 255);
                        dstRow[i + 1] = (byte)((srcG * alpha + dstG * inv + 127) / 255);
                        dstRow[i + 2] = (byte)((srcB * alpha + dstB * inv + 127) / 255);

                        int outA = alpha + (dstA * inv + 127) / 255;
                        dstRow[i + 3] = (byte)(outA > 255 ? 255 : outA);
                    }

                    Marshal.Copy(dstRow, 0, dstPtr, dstRow.Length);
                }
            }
            finally
            {
                bitmap.UnlockBits(data);
            }
        }
    }
}
