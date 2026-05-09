package io.github.ivere27.volvoxgrid.desktop;

import com.sun.jna.Callback;
import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.FloatByReference;
import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.font.FontRenderContext;
import java.awt.font.LineBreakMeasurer;
import java.awt.font.LineMetrics;
import java.awt.font.TextAttribute;
import java.awt.font.TextLayout;
import java.awt.image.BufferedImage;
import java.awt.image.DataBufferInt;
import java.text.AttributedCharacterIterator;
import java.text.AttributedString;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.nio.charset.StandardCharsets;

/**
 * Host-side text renderer used by native lite builds that do not include cosmic-text.
 */
final class Java2DTextRendererBridge implements AutoCloseable {
    private static final Logger LOG = Logger.getLogger(Java2DTextRendererBridge.class.getName());
    private static final FontRenderContext FONT_CONTEXT =
        new FontRenderContext(null, RenderingHints.VALUE_TEXT_ANTIALIAS_ON, RenderingHints.VALUE_FRACTIONALMETRICS_ON);

    private final NativeApi api;
    private final MeasureCallback measureCallback;
    private final RenderCallback renderCallback;
    private final boolean hasBuiltinTextEngine;
    private final Set<Long> registeredGridIds = Collections.synchronizedSet(new HashSet<Long>());
    private final Map<FontKey, Font> fontCache = new HashMap<FontKey, Font>();

    private volatile boolean closed;

    interface NativeApi extends Library {
        int volvox_grid_has_builtin_text_engine();

        int volvox_grid_set_text_renderer(
            long gridId,
            MeasureCallback measure,
            RenderCallback render,
            Pointer userData
        );

        int volvox_grid_set_text_renderer_named(
            long gridId,
            MeasureCallback measure,
            RenderCallback render,
            Pointer userData,
            byte[] rendererName,
            int rendererNameLen
        );
    }

    interface MeasureCallback extends Callback {
        void invoke(
            Pointer textPtr,
            int textLen,
            Pointer fontNamePtr,
            int fontNameLen,
            float fontSize,
            int bold,
            int italic,
            float maxWidth,
            FloatByReference outWidth,
            FloatByReference outHeight,
            Pointer userData
        );
    }

    interface RenderCallback extends Callback {
        float invoke(
            Pointer buffer,
            int bufWidth,
            int bufHeight,
            int stride,
            int x,
            int y,
            int clipX,
            int clipY,
            int clipW,
            int clipH,
            Pointer textPtr,
            int textLen,
            Pointer fontNamePtr,
            int fontNameLen,
            float fontSize,
            int bold,
            int italic,
            int color,
            float maxWidth,
            Pointer userData
        );
    }

    static Java2DTextRendererBridge tryCreate(String libraryPath) {
        if (libraryPath == null || libraryPath.trim().isEmpty()) {
            return null;
        }
        try {
            return new Java2DTextRendererBridge(libraryPath);
        } catch (Throwable ex) {
            LOG.log(Level.FINE, "Java2D text renderer bridge unavailable", ex);
            return null;
        }
    }

    private Java2DTextRendererBridge(String libraryPath) {
        this.api = Native.load(libraryPath, NativeApi.class);
        this.measureCallback = new MeasureCallback() {
            @Override
            public void invoke(
                Pointer textPtr,
                int textLen,
                Pointer fontNamePtr,
                int fontNameLen,
                float fontSize,
                int bold,
                int italic,
                float maxWidth,
                FloatByReference outWidth,
                FloatByReference outHeight,
                Pointer userData
            ) {
                measureTextCallback(
                    textPtr,
                    textLen,
                    fontNamePtr,
                    fontNameLen,
                    fontSize,
                    bold != 0,
                    italic != 0,
                    maxWidth,
                    outWidth,
                    outHeight
                );
            }
        };
        this.renderCallback = new RenderCallback() {
            @Override
            public float invoke(
                Pointer buffer,
                int bufWidth,
                int bufHeight,
                int stride,
                int x,
                int y,
                int clipX,
                int clipY,
                int clipW,
                int clipH,
                Pointer textPtr,
                int textLen,
                Pointer fontNamePtr,
                int fontNameLen,
                float fontSize,
                int bold,
                int italic,
                int color,
                float maxWidth,
                Pointer userData
            ) {
                return renderTextCallback(
                    buffer,
                    bufWidth,
                    bufHeight,
                    stride,
                    x,
                    y,
                    clipX,
                    clipY,
                    clipW,
                    clipH,
                    textPtr,
                    textLen,
                    fontNamePtr,
                    fontNameLen,
                    fontSize,
                    bold != 0,
                    italic != 0,
                    color,
                    maxWidth
                );
            }
        };
        this.hasBuiltinTextEngine = detectBuiltinTextEngine();
    }

    boolean shouldRegister() {
        return !closed && !hasBuiltinTextEngine;
    }

    void register(long gridId) {
        if (gridId == 0L || !shouldRegister()) {
            return;
        }
        try {
            byte[] rendererName = "Java2D".getBytes(StandardCharsets.UTF_8);
            int status;
            try {
                status = api.volvox_grid_set_text_renderer_named(
                    gridId,
                    measureCallback,
                    renderCallback,
                    null,
                    rendererName,
                    rendererName.length
                );
            } catch (UnsatisfiedLinkError ex) {
                status = api.volvox_grid_set_text_renderer(gridId, measureCallback, renderCallback, null);
            }
            if (status == 0) {
                registeredGridIds.add(Long.valueOf(gridId));
                LOG.log(Level.INFO, "Registered Java2D text renderer for grid {0}", Long.valueOf(gridId));
            } else {
                LOG.log(Level.WARNING, "Failed to register Java2D text renderer for grid {0}: status {1}",
                    new Object[] { Long.valueOf(gridId), Integer.valueOf(status) });
            }
        } catch (Throwable ex) {
            LOG.log(Level.WARNING, "Failed to register Java2D text renderer", ex);
        }
    }

    void clear(long gridId) {
        if (gridId == 0L || closed) {
            return;
        }
        if (!registeredGridIds.remove(Long.valueOf(gridId))) {
            return;
        }
        try {
            api.volvox_grid_set_text_renderer(gridId, null, null, null);
        } catch (Throwable ex) {
            LOG.log(Level.FINER, "Failed to clear Java2D text renderer", ex);
        }
    }

    @Override
    public void close() {
        if (closed) {
            return;
        }
        List<Long> ids;
        synchronized (registeredGridIds) {
            ids = new ArrayList<Long>(registeredGridIds);
        }
        for (Long id : ids) {
            clear(id.longValue());
        }
        closed = true;
        synchronized (fontCache) {
            fontCache.clear();
        }
    }

    private boolean detectBuiltinTextEngine() {
        try {
            return api.volvox_grid_has_builtin_text_engine() != 0;
        } catch (Throwable ex) {
            LOG.log(Level.FINE, "Could not query native text engine support; assuming built-in text is available", ex);
            return true;
        }
    }

    private synchronized void measureTextCallback(
        Pointer textPtr,
        int textLen,
        Pointer fontNamePtr,
        int fontNameLen,
        float fontSize,
        boolean bold,
        boolean italic,
        float maxWidth,
        FloatByReference outWidth,
        FloatByReference outHeight
    ) {
        TextMeasurement measurement = new TextMeasurement(0.0f, fallbackHeight(fontSize));
        try {
            String text = utf8(textPtr, textLen);
            if (!text.isEmpty()) {
                String fontName = utf8(fontNamePtr, fontNameLen);
                Font font = fontForText(fontName, fontSize, bold, italic, text);
                measurement = measureText(text, font, fontSize, maxWidth);
            }
        } catch (Throwable ex) {
            LOG.log(Level.FINER, "Java2D text measurement failed", ex);
        }

        if (outWidth != null) {
            outWidth.setValue(measurement.width);
        }
        if (outHeight != null) {
            outHeight.setValue(measurement.height);
        }
    }

    private synchronized float renderTextCallback(
        Pointer buffer,
        int bufWidth,
        int bufHeight,
        int stride,
        int x,
        int y,
        int clipX,
        int clipY,
        int clipW,
        int clipH,
        Pointer textPtr,
        int textLen,
        Pointer fontNamePtr,
        int fontNameLen,
        float fontSize,
        boolean bold,
        boolean italic,
        int color,
        float maxWidth
    ) {
        TextMeasurement measurement = new TextMeasurement(0.0f, fallbackHeight(fontSize));
        try {
            String text = utf8(textPtr, textLen);
            if (text.isEmpty()) {
                return measurement.width;
            }
            String fontName = utf8(fontNamePtr, fontNameLen);
            Font font = fontForText(fontName, fontSize, bold, italic, text);
            TextMeasurement measured = measureText(text, font, fontSize, maxWidth);
            TextMask mask = rasterizeMask(text, font, measured, maxWidth);
            measurement = mask.measurement;
            if (closed || buffer == null || bufWidth <= 0 || bufHeight <= 0 || stride <= 0 || clipW <= 0 || clipH <= 0) {
                return measurement.width;
            }

            blendMaskIntoBuffer(mask, buffer, bufWidth, bufHeight, stride, x, y, clipX, clipY, clipW, clipH, color);
        } catch (Throwable ex) {
            LOG.log(Level.FINER, "Java2D text rendering failed", ex);
        }
        return measurement.width;
    }

    private TextMask rasterizeMask(String text, Font font, TextMeasurement measurement, float maxWidth) {
        int imageW = Math.max(1, (int)Math.ceil(measurement.width));
        int imageH = Math.max(1, (int)Math.ceil(measurement.height));
        BufferedImage image = new BufferedImage(imageW, imageH, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = image.createGraphics();
        try {
            configureGraphics(g);
            g.setColor(Color.WHITE);
            drawText(g, text, font, 0.0f, 0.0f, maxWidth);
        } finally {
            g.dispose();
        }

        int[] pixels = ((DataBufferInt)image.getRaster().getDataBuffer()).getData();
        byte[] alpha = new byte[imageW * imageH];
        for (int i = 0; i < alpha.length; i++) {
            alpha[i] = (byte)((pixels[i] >>> 24) & 0xFF);
        }
        return new TextMask(measurement, imageW, imageH, alpha);
    }

    private TextMeasurement measureText(String text, Font font, float fontSize, float maxWidth) {
        float width = 0.0f;
        float height = 0.0f;
        List<String> paragraphs = paragraphs(text);
        boolean wrap = maxWidth > 0.0f && Float.isFinite(maxWidth);
        float wrapWidth = Math.max(1.0f, maxWidth);

        for (String paragraph : paragraphs) {
            if (paragraph.isEmpty()) {
                height += lineHeight(font, fontSize);
                continue;
            }
            if (wrap) {
                AttributedCharacterIterator iterator = attributed(paragraph, font).getIterator();
                LineBreakMeasurer measurer = new LineBreakMeasurer(iterator, FONT_CONTEXT);
                int end = iterator.getEndIndex();
                while (measurer.getPosition() < end) {
                    TextLayout layout = measurer.nextLayout(wrapWidth);
                    width = Math.max(width, layout.getAdvance());
                    height += lineHeight(layout, font, fontSize);
                }
            } else {
                TextLayout layout = new TextLayout(paragraph, font, FONT_CONTEXT);
                width = Math.max(width, layout.getAdvance());
                height += lineHeight(layout, font, fontSize);
            }
        }
        return new TextMeasurement(width, Math.max(height, fallbackHeight(fontSize)));
    }

    private void drawText(Graphics2D g, String text, Font font, float x, float y, float maxWidth) {
        List<String> paragraphs = paragraphs(text);
        boolean wrap = maxWidth > 0.0f && Float.isFinite(maxWidth);
        float wrapWidth = Math.max(1.0f, maxWidth);
        float penY = y;

        for (String paragraph : paragraphs) {
            if (paragraph.isEmpty()) {
                penY += lineHeight(font, font.getSize2D());
                continue;
            }
            if (wrap) {
                AttributedCharacterIterator iterator = attributed(paragraph, font).getIterator();
                LineBreakMeasurer measurer = new LineBreakMeasurer(iterator, FONT_CONTEXT);
                int end = iterator.getEndIndex();
                while (measurer.getPosition() < end) {
                    TextLayout layout = measurer.nextLayout(wrapWidth);
                    penY += layout.getAscent();
                    layout.draw(g, x, penY);
                    penY += layout.getDescent() + layout.getLeading();
                }
            } else {
                TextLayout layout = new TextLayout(paragraph, font, FONT_CONTEXT);
                penY += layout.getAscent();
                layout.draw(g, x, penY);
                penY += layout.getDescent() + layout.getLeading();
            }
        }
    }

    private Font font(String fontName, float fontSize, boolean bold, boolean italic) {
        float size = fontSize > 0.0f ? fontSize : 11.0f;
        int style = Font.PLAIN;
        if (bold) {
            style |= Font.BOLD;
        }
        if (italic) {
            style |= Font.ITALIC;
        }
        String family = fontName == null || fontName.trim().isEmpty() ? Font.DIALOG : fontName.trim();
        FontKey key = new FontKey(family, size, style);
        synchronized (fontCache) {
            Font cached = fontCache.get(key);
            if (cached != null) {
                return cached;
            }
            Font created = new Font(family, style, Math.max(1, Math.round(size))).deriveFont(size);
            if (fontCache.size() > 128) {
                fontCache.clear();
            }
            fontCache.put(key, created);
            return created;
        }
    }

    private Font fontForText(String fontName, float fontSize, boolean bold, boolean italic, String text) {
        Font requested = font(fontName, fontSize, bold, italic);
        if (text == null || text.isEmpty() || requested.canDisplayUpTo(text) < 0) {
            return requested;
        }
        return font(Font.DIALOG, fontSize, bold, italic);
    }

    private static void configureGraphics(Graphics2D g) {
        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_FRACTIONALMETRICS, RenderingHints.VALUE_FRACTIONALMETRICS_ON);
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
    }

    private static AttributedString attributed(String text, Font font) {
        AttributedString attributed = new AttributedString(text);
        attributed.addAttribute(TextAttribute.FONT, font);
        return attributed;
    }

    private static List<String> paragraphs(String text) {
        String normalized = text.replace("\r\n", "\n").replace('\r', '\n');
        String[] parts = normalized.split("\n", -1);
        List<String> paragraphs = new ArrayList<String>(parts.length);
        Collections.addAll(paragraphs, parts);
        return paragraphs;
    }

    private static float lineHeight(TextLayout layout, Font font, float fontSize) {
        return Math.max(layout.getAscent() + layout.getDescent() + layout.getLeading(), lineHeight(font, fontSize));
    }

    private static float lineHeight(Font font, float fontSize) {
        LineMetrics metrics = font.getLineMetrics("Mg", FONT_CONTEXT);
        return Math.max(metrics.getHeight(), fallbackHeight(fontSize));
    }

    private static float fallbackHeight(float fontSize) {
        return Math.max(1.0f, fontSize) * 1.2f;
    }

    private static String utf8(Pointer ptr, int len) {
        if (ptr == null || len <= 0) {
            return "";
        }
        return new String(ptr.getByteArray(0, len), StandardCharsets.UTF_8);
    }

    private static Color color(int argb) {
        int alpha = (argb >>> 24) & 0xFF;
        int red = (argb >>> 16) & 0xFF;
        int green = (argb >>> 8) & 0xFF;
        int blue = argb & 0xFF;
        return new Color(red, green, blue, alpha);
    }

    private static void blendMaskIntoBuffer(
        TextMask mask,
        Pointer target,
        int bufWidth,
        int bufHeight,
        int stride,
        int x,
        int y,
        int clipX,
        int clipY,
        int clipW,
        int clipH,
        int argb
    ) {
        if (mask == null || mask.alpha.length == 0 || target == null || bufWidth <= 0 || bufHeight <= 0 || stride <= 0) {
            return;
        }

        int globalA = (argb >>> 24) & 0xFF;
        if (globalA <= 0) {
            return;
        }
        int srcR = (argb >>> 16) & 0xFF;
        int srcG = (argb >>> 8) & 0xFF;
        int srcB = argb & 0xFF;

        int minX = Math.max(Math.max(x, clipX), 0);
        int minY = Math.max(Math.max(y, clipY), 0);
        int maxX = Math.min(Math.min(x + mask.width, clipX + clipW), bufWidth);
        int maxY = Math.min(Math.min(y + mask.height, y + clipH), bufHeight);
        if (maxX <= minX || maxY <= minY) {
            return;
        }

        int blendW = maxX - minX;
        byte[] row = new byte[blendW * 4];
        for (int rowIndex = minY; rowIndex < maxY; rowIndex++) {
            long targetOffset = (long)rowIndex * (long)stride + (long)minX * 4L;
            target.read(targetOffset, row, 0, row.length);
            int maskBase = (rowIndex - y) * mask.width + (minX - x);
            for (int col = 0; col < blendW; col++) {
                int maskA = mask.alpha[maskBase + col] & 0xFF;
                if (maskA == 0) {
                    continue;
                }
                int srcA = (maskA * globalA + 127) / 255;
                if (srcA == 0) {
                    continue;
                }
                int i = col * 4;
                int dstR = row[i] & 0xFF;
                int dstG = row[i + 1] & 0xFF;
                int dstB = row[i + 2] & 0xFF;
                int dstA = row[i + 3] & 0xFF;
                int invA = 255 - srcA;
                row[i] = (byte)((srcR * srcA + dstR * invA + 127) / 255);
                row[i + 1] = (byte)((srcG * srcA + dstG * invA + 127) / 255);
                row[i + 2] = (byte)((srcB * srcA + dstB * invA + 127) / 255);
                int outA = srcA + (dstA * invA + 127) / 255;
                row[i + 3] = (byte)(outA > 255 ? 255 : outA);
            }
            target.write(targetOffset, row, 0, row.length);
        }
    }

    private static final class TextMeasurement {
        final float width;
        final float height;

        TextMeasurement(float width, float height) {
            this.width = width;
            this.height = height;
        }
    }

    private static final class TextMask {
        final TextMeasurement measurement;
        final int width;
        final int height;
        final byte[] alpha;

        TextMask(TextMeasurement measurement, int width, int height, byte[] alpha) {
            this.measurement = measurement;
            this.width = width;
            this.height = height;
            this.alpha = alpha;
        }
    }

    private static final class FontKey {
        private final String family;
        private final float size;
        private final int style;

        FontKey(String family, float size, int style) {
            this.family = family;
            this.size = size;
            this.style = style;
        }

        @Override
        public boolean equals(Object obj) {
            if (!(obj instanceof FontKey)) {
                return false;
            }
            FontKey other = (FontKey)obj;
            return family.equals(other.family) && Float.floatToIntBits(size) == Float.floatToIntBits(other.size)
                && style == other.style;
        }

        @Override
        public int hashCode() {
            int result = family.hashCode();
            result = 31 * result + Float.floatToIntBits(size);
            result = 31 * result + style;
            return result;
        }
    }
}
