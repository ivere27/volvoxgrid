package io.github.ivere27.volvoxgrid

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.LinkedHashMap
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

internal class AndroidCanvasTextRenderer : NativeTextRendererBridge.Callback {

    private val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        isSubpixelText = true
        style = Paint.Style.FILL
        color = 0xFFFFFFFF.toInt()
    }

    private var scratchBitmap: Bitmap? = null
    private var scratchCanvas: Canvas? = null

    private val measureResult = FloatArray(2)
    private var rasterizeResult = ByteArray(1024)

    /**
     * Cache size is now managed entirely on the C-side.
     */
    @Synchronized
    fun setCacheSize(size: Int) {
        // No-op: handled by C-side cache via VolvoxGridView
    }

    @Synchronized
    override fun measureText(
        textUtf8: ByteArray,
        textLen: Int,
        fontNameUtf8: ByteArray,
        fontLen: Int,
        fontSize: Float,
        bold: Boolean,
        italic: Boolean,
        maxWidth: Float,
    ): FloatArray {
        val text = decodeUtf8(textUtf8, textLen)
        if (text.isEmpty()) {
            measureResult[0] = 0f
            measureResult[1] = fallbackHeight(fontSize)
            return measureResult
        }
        val fontName = decodeUtf8(fontNameUtf8, fontLen)
        configurePaint(fontName, fontSize, bold, italic)

        val rawWidth = paint.measureText(text)
        val wrapWidth = if (maxWidth > 0f) maxWidth else Float.NaN
        val isSingleLine = text.indexOf('\n') == -1 && (wrapWidth.isNaN() || rawWidth <= wrapWidth)

        var mWidth = 0f
        var mHeight = 0f
        if (isSingleLine) {
            mWidth = rawWidth
            val fm = paint.fontMetrics
            mHeight = max((fm.descent - fm.ascent), fallbackHeight(fontSize))
        } else {
            val effWidth = if (wrapWidth.isFinite()) wrapWidth else rawWidth.coerceAtLeast(1f)
            val layout = buildLayout(text, effWidth)
            mWidth = layoutMaxLineWidth(layout)
            mHeight = layout.height.toFloat()
        }

        measureResult[0] = mWidth
        measureResult[1] = mHeight
        return measureResult
    }

    @Synchronized
    override fun rasterizeText(
        textUtf8: ByteArray,
        textLen: Int,
        fontNameUtf8: ByteArray,
        fontLen: Int,
        fontSize: Float,
        bold: Boolean,
        italic: Boolean,
        maxWidth: Float,
    ): ByteArray {
        val text = decodeUtf8(textUtf8, textLen)
        if (text.isEmpty()) {
            return EMPTY_RASTERIZE_RESULT
        }
        val fontName = decodeUtf8(fontNameUtf8, fontLen)
        configurePaint(fontName, fontSize, bold, italic)

        val rawWidth = paint.measureText(text)
        val wrapWidth = if (maxWidth > 0f) maxWidth else Float.NaN
        val isSingleLine = text.indexOf('\n') == -1 && (wrapWidth.isNaN() || rawWidth <= wrapWidth)

        val realWidth: Float
        val realHeight: Float
        val drawWidth: Int
        val drawHeight: Int
        val layout: StaticLayout?

        if (isSingleLine) {
            realWidth = rawWidth
            val fm = paint.fontMetrics
            realHeight = max((fm.descent - fm.ascent), fallbackHeight(fontSize))
            drawWidth = ceil(realWidth.toDouble()).toInt().coerceAtLeast(1)
            drawHeight = ceil(realHeight.toDouble()).toInt().coerceAtLeast(1)
            layout = null
        } else {
            val effWidth = if (wrapWidth.isFinite()) wrapWidth else rawWidth.coerceAtLeast(1f)
            layout = buildLayout(text, effWidth)
            realWidth = layoutMaxLineWidth(layout)
            realHeight = layout.height.toFloat()
            drawWidth = layout.width.coerceAtLeast(1)
            drawHeight = layout.height.coerceAtLeast(1)
        }

        ensureScratch(drawWidth, drawHeight)

        val bitmap = scratchBitmap ?: return EMPTY_RASTERIZE_RESULT
        val canvas = scratchCanvas ?: return EMPTY_RASTERIZE_RESULT

        bitmap.eraseColor(0x00000000)
        
        if (isSingleLine) {
            val fm = paint.fontMetrics
            canvas.drawText(text, 0f, -fm.ascent, paint)
        } else {
            canvas.save()
            layout?.draw(canvas)
            canvas.restore()
        }

        val stride = bitmap.rowBytes
        val byteCount = bitmap.byteCount
        val requiredSize = RASTERIZE_HEADER_SIZE + byteCount
        if (rasterizeResult.size < requiredSize) {
            rasterizeResult = ByteArray(requiredSize * 2)
        }

        val res = rasterizeResult
        ByteBuffer.wrap(res).order(ByteOrder.LITTLE_ENDIAN).apply {
            putInt(drawWidth)
            putInt(drawHeight)
            putFloat(realWidth)
            putFloat(realHeight)
            putInt(stride)
        }

        val buffer = ByteBuffer.wrap(res, RASTERIZE_HEADER_SIZE, byteCount)
        bitmap.copyPixelsToBuffer(buffer)
        
        return res
    }

    private fun fallbackHeight(fontSize: Float): Float = max(1f, fontSize) * 1.2f

    private fun decodeUtf8(bytes: ByteArray, len: Int): String =
        if (len <= 0) "" else String(bytes, 0, len, Charsets.UTF_8)

    private fun configurePaint(fontName: String, fontSize: Float, bold: Boolean, italic: Boolean) {
        val style = (if (bold) Typeface.BOLD else 0) or (if (italic) Typeface.ITALIC else 0)
        val baseTypeface = if (fontName.isBlank()) Typeface.DEFAULT else Typeface.create(fontName, Typeface.NORMAL)
        paint.typeface = Typeface.create(baseTypeface, style)
        paint.textSize = fontSize.coerceAtLeast(1f)
    }

    private fun buildLayout(text: CharSequence, widthPx: Float): StaticLayout {
        val width = ceil(widthPx.toDouble()).toInt().coerceAtLeast(1)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setIncludePad(false)
                .setLineSpacing(0f, 1f)
                .setBreakStrategy(Layout.BREAK_STRATEGY_HIGH_QUALITY)
                .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NONE)
                .build()
        } else {
            @Suppress("DEPRECATION")
            StaticLayout(
                text,
                paint,
                width,
                Layout.Alignment.ALIGN_NORMAL,
                1f,
                0f,
                false,
            )
        }
    }

    private fun layoutMaxLineWidth(layout: StaticLayout): Float {
        var width = 0f
        val lines = layout.lineCount
        for (i in 0 until lines) {
            width = max(width, layout.getLineWidth(i))
        }
        return width
    }

    private fun ensureScratch(width: Int, height: Int) {
        val requiredBytes = (width + 4) * height
        var bmp = scratchBitmap
        if (bmp == null || bmp.allocationByteCount < requiredBytes) {
            val newW = max(width, 1024)
            val newH = max(height, 1024)
            bmp = Bitmap.createBitmap(newW, newH, Bitmap.Config.ALPHA_8)
            scratchBitmap = bmp
            if (scratchCanvas == null) scratchCanvas = Canvas()
        }
        bmp.reconfigure(width, height, Bitmap.Config.ALPHA_8)
        scratchCanvas!!.setBitmap(bmp)
    }

    private companion object {
        const val RASTERIZE_HEADER_SIZE = 20  // maskW:i32LE + maskH:i32LE + realWidth:f32LE + realHeight:f32LE + maskStride:i32LE
        val EMPTY_RASTERIZE_RESULT: ByteArray = ByteArray(RASTERIZE_HEADER_SIZE) // all zeros
    }
}
