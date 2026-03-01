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

    private val pluginHandleField by lazy {
        PluginHost::class.java.getDeclaredField("handle").apply { isAccessible = true }
    }

    private fun pluginHandle(host: PluginHost): Long = pluginHandleField.getLong(host)

    fun hasBuiltinTextEngine(host: PluginHost): Boolean {
        return runCatching {
            nativeHasBuiltinTextEngine(pluginHandle(host))
        }.getOrDefault(true)
    }

    fun registerTextRenderer(host: PluginHost, gridId: Long, callback: Callback): Boolean {
        val rc = runCatching {
            nativeRegisterTextRenderer(pluginHandle(host), gridId, callback)
        }.getOrElse { -1 }
        return rc == 0
    }

    fun clearTextRenderer(host: PluginHost, gridId: Long) {
        runCatching {
            nativeClearTextRenderer(pluginHandle(host), gridId)
        }
    }

    fun setCacheCap(host: PluginHost, gridId: Long, cap: Int) {
        runCatching {
            nativeSetTextRendererCacheCap(pluginHandle(host), gridId, cap)
        }
    }

    private external fun nativeHasBuiltinTextEngine(pluginHandle: Long): Boolean
    private external fun nativeRegisterTextRenderer(
        pluginHandle: Long,
        gridId: Long,
        callback: Callback
    ): Int
    private external fun nativeClearTextRenderer(pluginHandle: Long, gridId: Long): Int
    private external fun nativeSetTextRendererCacheCap(pluginHandle: Long, gridId: Long, cap: Int)
}
