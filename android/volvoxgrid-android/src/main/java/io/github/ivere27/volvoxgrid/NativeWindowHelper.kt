package io.github.ivere27.volvoxgrid

import android.view.Surface

/**
 * JNI helper for acquiring/releasing ANativeWindow pointers from Android Surfaces.
 *
 * Used by [VolvoxGridView] to pass a raw surface handle to the GPU renderer plugin.
 */
object NativeWindowHelper {
    init {
        System.loadLibrary("volvoxgrid_jni")
    }

    /**
     * Acquire an ANativeWindow* from a [Surface].
     * The returned pointer must be released via [releaseNativeWindow].
     */
    fun getNativeWindow(surface: Surface): Long {
        return nativeGetNativeWindow(surface)
    }

    /** Release an ANativeWindow* previously acquired via [getNativeWindow]. */
    fun releaseNativeWindow(ptr: Long) {
        nativeReleaseNativeWindow(ptr)
    }

    /** Increment the reference count of an ANativeWindow*. */
    fun acquireNativeWindow(ptr: Long) {
        nativeAcquireNativeWindow(ptr)
    }

    private external fun nativeGetNativeWindow(surface: Any): Long
    private external fun nativeReleaseNativeWindow(ptr: Long)
    private external fun nativeAcquireNativeWindow(ptr: Long)
}
