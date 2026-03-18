package io.github.ivere27.volvoxgrid

import android.graphics.SurfaceTexture
import android.util.Log
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry

class VolvoxGridPlugin: FlutterPlugin, MethodCallHandler {
    companion object {
        private const val TAG = "VolvoxGridPlugin"
    }

    private lateinit var channel: MethodChannel
    private var textureRegistry: TextureRegistry? = null
    private val producers = mutableMapOf<Long, TextureRegistry.SurfaceProducer>()
    private val surfaceTextureEntries = mutableMapOf<Long, TextureRegistry.SurfaceTextureEntry>()
    private val surfaces = mutableMapOf<Long, Surface>()
    private val surfaceHandles = mutableMapOf<Long, Long>()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        android.util.Log.i("VolvoxGridPlugin", "onAttachedToEngine")
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "io.github.ivere27.volvoxgrid")
        channel.setMethodCallHandler(this)
        textureRegistry = flutterPluginBinding.textureRegistry
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "createTexture" -> {
                val registry = textureRegistry
                if (registry == null) {
                    result.error("NO_REGISTRY", "TextureRegistry is null", null)
                    return
                }

                val backend = call.argument<String>("backend")?.lowercase()
                val width = (call.argument<Int>("width") ?: 1).coerceAtLeast(1)
                val height = (call.argument<Int>("height") ?: 1).coerceAtLeast(1)

                val textureId: Long
                val handle: Long

                if (backend == "vulkan") {
                    // SurfaceProducer is backed by ImageReader when Impeller uses Vulkan.
                    val producer = registry.createSurfaceProducer()
                    producer.setSize(width, height)
                    val surface = producer.surface

                    handle = try {
                        NativeWindowCompat.getNativeWindow(surface)
                    } catch (t: Throwable) {
                        Log.e(
                            TAG,
                            "createTexture(vulkan): failed to acquire native window for ${surface.javaClass.name}; ${NativeWindowCompat.describeHelperState()}",
                            t
                        )
                        producer.release()
                        result.error("NATIVE_WINDOW_ERROR", "Failed to acquire native window: ${t.message}", null)
                        return
                    }
                    if (handle == 0L) {
                        Log.e(
                            TAG,
                            "createTexture(vulkan): helper returned 0 for ${surface.javaClass.name}; ${NativeWindowCompat.describeHelperState()}"
                        )
                        producer.release()
                        result.error(
                            "NATIVE_WINDOW_ERROR",
                            "Failed to acquire native window: helper returned 0",
                            null
                        )
                        return
                    }

                    textureId = producer.id()
                    producers[textureId] = producer
                } else {
                    // SurfaceTexture is EGL-native and works with GLES window surfaces.
                    @Suppress("DEPRECATION")
                    val entry = registry.createSurfaceTexture()
                    val surfaceTexture: SurfaceTexture = entry.surfaceTexture()
                    surfaceTexture.setDefaultBufferSize(width, height)
                    val surface = Surface(surfaceTexture)

                    handle = try {
                        NativeWindowCompat.getNativeWindow(surface)
                    } catch (t: Throwable) {
                        Log.e(
                            TAG,
                            "createTexture(gles): failed to acquire native window for ${surface.javaClass.name}; ${NativeWindowCompat.describeHelperState()}",
                            t
                        )
                        surface.release()
                        entry.release()
                        result.error("NATIVE_WINDOW_ERROR", "Failed to acquire native window: ${t.message}", null)
                        return
                    }
                    if (handle == 0L) {
                        Log.e(
                            TAG,
                            "createTexture(gles): helper returned 0 for ${surface.javaClass.name}; ${NativeWindowCompat.describeHelperState()}"
                        )
                        surface.release()
                        entry.release()
                        result.error(
                            "NATIVE_WINDOW_ERROR",
                            "Failed to acquire native window: helper returned 0",
                            null
                        )
                        return
                    }

                    textureId = entry.id()
                    surfaceTextureEntries[textureId] = entry
                    surfaces[textureId] = surface
                }

                surfaceHandles[textureId] = handle

                val map = mutableMapOf<String, Any>()
                map["textureId"] = textureId
                map["surfaceHandle"] = handle
                result.success(map)
            }
            "setTextureSize" -> {
                val textureId = call.argument<Number>("textureId")?.toLong() ?: 0L
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                producers[textureId]?.setSize(width, height)
                surfaceTextureEntries[textureId]?.surfaceTexture()?.setDefaultBufferSize(width, height)
                result.success(null)
            }
            "releaseTexture" -> {
                val textureId = call.argument<Number>("textureId")?.toLong() ?: 0L
                surfaceHandles.remove(textureId)?.let { NativeWindowCompat.releaseNativeWindow(it) }
                surfaces.remove(textureId)?.release()
                producers.remove(textureId)?.release()
                surfaceTextureEntries.remove(textureId)?.release()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        surfaceHandles.values.forEach { NativeWindowCompat.releaseNativeWindow(it) }
        surfaceHandles.clear()
        surfaces.values.forEach { it.release() }
        surfaces.clear()
        producers.values.forEach { it.release() }
        producers.clear()
        surfaceTextureEntries.values.forEach { it.release() }
        surfaceTextureEntries.clear()
        textureRegistry = null
    }
}

private object NativeWindowCompat {
    fun describeHelperState(): String {
        return try {
            val helperClass = NativeWindowHelper::class.java
            val available = helperClass.declaredMethods.joinToString { method ->
                "${method.name}${method.parameterTypes.contentToString()}"
            }
            "helper=${helperClass.name}, methods=[$available]"
        } catch (t: Throwable) {
            "helperStateError=${t.message}"
        }
    }

    fun getNativeWindow(surface: Surface): Long {
        try {
            return NativeWindowHelper.getNativeWindow(surface)
        } catch (t: Throwable) {
            Log.e(
                "VolvoxGridPlugin",
                "NativeWindowCompat.getNativeWindow failed for ${surface.javaClass.name}; ${describeHelperState()}",
                t
            )
            throw t
        }
    }

    fun releaseNativeWindow(ptr: Long) {
        if (ptr != 0L) {
            NativeWindowHelper.releaseNativeWindow(ptr)
        }
    }
}
