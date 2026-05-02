package io.github.ivere27.volvoxgrid

import io.github.ivere27.synurang.PluginHost

internal object NativeTextRendererBridge {
    init {
        System.loadLibrary("volvoxgrid_jni")
    }

    interface Callback {
        fun measureText(
            textUtf8: ByteArray,
            textLen: Int,
            fontNameUtf8: ByteArray,
            fontLen: Int,
            fontSize: Float,
            bold: Boolean,
            italic: Boolean,
            maxWidth: Float
        ): FloatArray

        fun rasterizeText(
            textUtf8: ByteArray,
            textLen: Int,
            fontNameUtf8: ByteArray,
            fontLen: Int,
            fontSize: Float,
            bold: Boolean,
            italic: Boolean,
            maxWidth: Float
        ): ByteArray
    }

    private val runtimeHandleField by lazy {
        PluginHost::class.java.getDeclaredField("handle").apply { isAccessible = true }
    }

    private fun runtimeHandle(host: PluginHost): Long = runtimeHandleField.getLong(host)

    fun hasBuiltinTextEngine(host: PluginHost): Boolean {
        return runCatching {
            nativeHasBuiltinTextEngine(runtimeHandle(host))
        }.getOrDefault(true)
    }

    fun registerTextRenderer(host: PluginHost, gridId: Long, callback: Callback): Boolean {
        val rc = runCatching {
            nativeRegisterTextRenderer(runtimeHandle(host), gridId, callback)
        }.getOrElse { -1 }
        return rc == 0
    }

    fun clearTextRenderer(host: PluginHost, gridId: Long) {
        runCatching {
            nativeClearTextRenderer(runtimeHandle(host), gridId)
        }
    }

    fun setCacheCap(host: PluginHost, gridId: Long, cap: Int) {
        runCatching {
            nativeSetTextRendererCacheCap(runtimeHandle(host), gridId, cap)
        }
    }

    private external fun nativeHasBuiltinTextEngine(runtimeHandle: Long): Boolean
    private external fun nativeRegisterTextRenderer(
        runtimeHandle: Long,
        gridId: Long,
        callback: Callback
    ): Int
    private external fun nativeClearTextRenderer(runtimeHandle: Long, gridId: Long): Int
    private external fun nativeSetTextRendererCacheCap(runtimeHandle: Long, gridId: Long, cap: Int)
}
