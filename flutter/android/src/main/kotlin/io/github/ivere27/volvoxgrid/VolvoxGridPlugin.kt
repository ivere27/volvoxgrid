package io.github.ivere27.volvoxgrid

import android.graphics.SurfaceTexture
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry

class VolvoxGridPlugin: FlutterPlugin, MethodCallHandler {
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
                        producer.release()
                        result.error("NATIVE_WINDOW_ERROR", "Failed to acquire native window: ${t.message}", null)
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
                        surface.release()
                        entry.release()
                        result.error("NATIVE_WINDOW_ERROR", "Failed to acquire native window: ${t.message}", null)
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
    private val helperClass: Class<*> by lazy {
        Class.forName("io.github.ivere27.volvoxgrid.NativeWindowHelper")
    }

    private val helperInstance: Any by lazy {
        helperClass.getField("INSTANCE").get(null)
            ?: error("NativeWindowHelper.INSTANCE is null")
    }

    private val getNativeWindowMethod by lazy {
        helperClass.getDeclaredMethod("getNativeWindow", Surface::class.java)
    }

    private val releaseNativeWindowMethod by lazy {
        helperClass.getDeclaredMethod("releaseNativeWindow", Long::class.javaPrimitiveType)
    }

    fun getNativeWindow(surface: Surface): Long {
        val value = getNativeWindowMethod.invoke(helperInstance, surface) as? Number
        return value?.toLong() ?: 0L
    }

    fun releaseNativeWindow(ptr: Long) {
        if (ptr != 0L) {
            releaseNativeWindowMethod.invoke(helperInstance, ptr)
        }
    }
}
