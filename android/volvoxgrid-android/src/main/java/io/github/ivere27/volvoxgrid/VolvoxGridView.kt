package io.github.ivere27.volvoxgrid

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.os.Looper
import android.os.Handler
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.util.AttributeSet
import android.util.TypedValue
import android.view.inputmethod.BaseInputConnection
import android.view.KeyEvent as AndroidKeyEvent
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.VelocityTracker
import android.view.View
import android.view.ViewConfiguration
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.OverScroller
import io.github.ivere27.volvoxgrid.common.VolvoxGridHost
import io.github.ivere27.synurang.BidiStream
import io.github.ivere27.synurang.FfiError
import io.github.ivere27.synurang.PluginHost
import io.github.ivere27.synurang.PluginStream
import java.io.File
import java.nio.ByteBuffer
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread
import kotlin.math.roundToInt

/**
 * SurfaceView-based widget that renders a VolvoxGrid via the Synurang FFI plugin.
 *
 * The render loop works as follows:
 * 1. A [DirectByteBuffer] is allocated for the pixel buffer (ARGB_8888).
 * 2. A bidi [RenderSession] stream is opened with the plugin.
 * 3. The view sends a [BufferReady] message with the native pointer address.
 * 4. On each frame, the plugin renders into the shared buffer and sends [FrameDone].
 * 5. The view blits the buffer to the SurfaceView canvas.
 *
 * Android touch/key events are forwarded as protobuf [PointerEvent] / [KeyEvent].
 * When the plugin sends an [EditRequest], an [EditText] overlay is shown for cell editing.
 * An [EventStream] is opened for grid events (BeforeEdit, AfterEdit, etc.).
 */
class VolvoxGridView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr), VolvoxGridHost<VolvoxGridController> {

    private var surfaceView = SurfaceView(context)
    private var editOverlay: EditText? = null

    private var plugin: PluginHost? = null
    private var ffiClient: VolvoxGridServiceFfi? = null
    private var gridId: Long = 0
    private var usingExternalTextRenderer = false
    private val androidTextRenderer = AndroidCanvasTextRenderer()
    private var pendingAndroidTextCacheSize: Int? = null

    @Volatile
    private var renderStream: BidiStream<RenderInput, RenderOutput>? = null
    @Volatile
    private var eventStream: PluginStream? = null
    @Volatile
    private var eventThread: Thread? = null
    private val eventStreamLock = Any()
    @Volatile
    private var decisionChannelEnabled = false

    private var pixelBuffer: ByteBuffer? = null
    private var bitmap: Bitmap? = null
    private val bitmapLock = Any()
    private var bufferWidth = 0
    private var bufferHeight = 0

    private val running = AtomicBoolean(false)
    private val released = AtomicBoolean(false)
    private val surfaceReady = AtomicBoolean(false)
    private val renderRequestPending = AtomicBoolean(false)
    private var activePointerId = MotionEvent.INVALID_POINTER_ID
    private var touchStartX = 0f
    private var touchStartY = 0f
    private var lastTouchX = 0f
    private var lastTouchY = 0f
    private var isTouchScrolling = false
    private var isPinchZooming = false
    private var pinchLastFocusX = 0f
    private var pinchLastFocusY = 0f
    private var ignoreTouchUntilUp = false
    private var scrollDispatchScheduled = false
    private var pendingScrollDeltaX = 0f
    private var pendingScrollDeltaY = 0f
    private var pendingScrollNeedsRender = false
    private var zoomDispatchScheduled = false
    private var pendingZoomScale = 1f
    private var pendingZoomFocalX = 0f
    private var pendingZoomFocalY = 0f
    private var pendingZoomNeedsRender = false
    private var pendingZoomActive = false
    private val touchSlop = (ViewConfiguration.get(context).scaledTouchSlop * 0.75f).coerceAtLeast(1f)
    private var touchScrollUnitPx = 50f
    private var knownRows = 0
    private var longPressRunnable: Runnable? = null
    private val longPressTimeout = 600L
    private var lastTapTime = 0L
    private var lastTapX = 0f
    private var lastTapY = 0f
    private val doubleTapTimeout = ViewConfiguration.getDoubleTapTimeout().toLong()
    private val doubleTapSlop = ViewConfiguration.get(context).scaledDoubleTapSlop.toFloat()

    // IME proxy: zero-size EditText that captures composition when no edit overlay is visible
    private var imeProxy: EditText? = null
    private var imeProxyComposing = false
    private var imeProxyLastCommittedLen = 0
    private var suppressImeProxyWatcher = false

    // Edit overlay IME state
    private var currentEditUiMode = EditUiMode.EDIT_UI_MODE_ENTER
    private var suppressEditorSync = false
    private var editOverlayComposing = false

    // Editing cell tracking (for scroll-into-view after resize)
    private var editingRow = -1
    private var editingCol = -1

    // Deferred overlay reveal
    private var deferOverlayWhileImeActive = false
    private var pendingEditRequest: EditRequest? = null
    private val deferOverlayHandler = Handler(Looper.getMainLooper())
    @Volatile
    private var gesturePreviewActive = false
    @Volatile
    private var gesturePreviewScale = 1f
    @Volatile
    private var gesturePreviewPanX = 0f
    @Volatile
    private var gesturePreviewPanY = 0f
    @Volatile
    private var gesturePreviewFocalX = 0f
    @Volatile
    private var gesturePreviewFocalY = 0f
    @Volatile
    private var clearGesturePreviewOnNextFrame = false
    private val gesturePreviewPaint = Paint().apply {
        isFilterBitmap = false
        isAntiAlias = false
        isDither = false
    }
    private val wheelScrollGain = 1.5f
    // A/B switch:
    // - false => unified engine-only fling physics
    // - true  => host-side Android OverScroller fling
    private val useHostFling = false
    private val engineFlingImpulseGain = 80f
    private val engineFlingFriction = 0.9f
    private val engineMomentumMaxFrames = 180
    private val engineMomentumIdleStopOutputs = 2
    private val minFlingVelocity = ViewConfiguration.get(context).scaledMinimumFlingVelocity.toFloat()
    private val maxFlingVelocity = ViewConfiguration.get(context).scaledMaximumFlingVelocity.toFloat()
    private val flingScroller = OverScroller(context)
    private var flingFriction = ViewConfiguration.getScrollFriction()
    private var velocityTracker: VelocityTracker? = null
    private var flingLastX = 0
    private var flingLastY = 0
    private var flingScheduled = false
    private var engineMomentumFramesRemaining = 0
    private var engineMomentumScheduled = false
    private var engineMomentumIdleOutputs = 0

    // GPU surface rendering state
    @Volatile private var gpuSurfaceActive = false
    @Volatile private var nativeWindowPtr: Long = 0
    @Volatile private var currentRendererMode: Int = 0

    // Flow control / Backpressure
    private val pendingFrame = AtomicBoolean(false)
    private val needsFollowupRender = AtomicBoolean(false)
    private val sendLock = Any()
    private val scaleGestureDetector = ScaleGestureDetector(
        context,
        object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScaleBegin(detector: ScaleGestureDetector): Boolean {
                longPressRunnable?.let { removeCallbacks(it) }
                if (useHostFling) {
                    stopFling()
                }
                stopEngineMomentumPump()
                recycleVelocityTracker()
                flushQueuedScroll()
                clearQueuedZoom()

                renderStream?.let { stream ->
                    if (activePointerId != MotionEvent.INVALID_POINTER_ID) {
                        sendPointerEvent(stream, PointerEvent.Type.UP, lastTouchX, lastTouchY)
                    }
                }
                activePointerId = MotionEvent.INVALID_POINTER_ID
                isTouchScrolling = false
                pendingScrollDeltaX = 0f
                pendingScrollDeltaY = 0f
                pendingScrollNeedsRender = false
                isPinchZooming = true
                pinchLastFocusX = detector.focusX
                pinchLastFocusY = detector.focusY
                clearGesturePreviewOnNextFrame = false
                ignoreTouchUntilUp = false
                startGesturePreview(detector.focusX, detector.focusY)
                sendZoomEvent(
                    phase = ZoomEvent.Phase.ZOOM_BEGIN,
                    scale = 1f,
                    focalX = detector.focusX,
                    focalY = detector.focusY,
                    requestRender = !gesturePreviewActive
                )
                return true
            }

            override fun onScale(detector: ScaleGestureDetector): Boolean {
                if (!isPinchZooming) {
                    return false
                }
                val focusDx = detector.focusX - pinchLastFocusX
                val focusDy = detector.focusY - pinchLastFocusY
                val moved = kotlin.math.abs(focusDx) > 0.01f || kotlin.math.abs(focusDy) > 0.01f
                if (moved) {
                    queueScrollDelta(
                        pixelsToScrollUnits(-focusDx),
                        pixelsToScrollUnits(-focusDy),
                        immediate = false,
                        requestRender = !gesturePreviewActive
                    )
                }
                pinchLastFocusX = detector.focusX
                pinchLastFocusY = detector.focusY
                val scale = detector.scaleFactor
                if (!scale.isFinite() || scale <= 0f) {
                    return true
                }
                val scaleDeltaForPreview = scale.coerceIn(ZOOM_STEP_MIN_SCALE, ZOOM_STEP_MAX_SCALE)
                queueZoomDelta(
                    scaleDelta = scaleDeltaForPreview,
                    focalX = detector.focusX,
                    focalY = detector.focusY,
                    requestRender = !gesturePreviewActive
                )
                updateGesturePreview(
                    focalX = detector.focusX,
                    focalY = detector.focusY,
                    panDx = focusDx,
                    panDy = focusDy,
                    scaleDelta = scaleDeltaForPreview
                )
                if (!moved && !gesturePreviewActive) {
                    requestRenderFrameImmediate()
                }
                return true
            }

            override fun onScaleEnd(detector: ScaleGestureDetector) {
                if (!isPinchZooming) {
                    return
                }
                clearGesturePreviewOnNextFrame = gesturePreviewActive
                flushQueuedZoom()
                flushQueuedScroll()
                sendZoomEvent(
                    phase = ZoomEvent.Phase.ZOOM_END,
                    scale = 1f,
                    focalX = detector.focusX,
                    focalY = detector.focusY,
                    requestRender = true
                )
                isPinchZooming = false
                pinchLastFocusX = 0f
                pinchLastFocusY = 0f
                ignoreTouchUntilUp = true
            }
        }
    )

    /** Listener for grid events delivered by the EventStream. */
    var eventListener: GridEventListener? = null

    var beforeEditListener: BeforeEditListener? = null
        set(value) {
            field = value
            if (value != null) {
                ensureDecisionChannelEnabled()
            }
        }

    var cellEditValidatingListener: CellEditValidatingListener? = null
        set(value) {
            field = value
            if (value != null) {
                ensureDecisionChannelEnabled()
            }
        }

    var beforeSortListener: BeforeSortListener? = null
        set(value) {
            field = value
            if (value != null) {
                ensureDecisionChannelEnabled()
            }
        }

    /** Listener for edit commit/cancel from the inline EditText overlay. */
    var editListener: EditCommitListener? = null

    /** Optional listener for wrapper-side context menu requests. */
    var contextMenuRequestListener: ContextMenuRequestListener? = null

    interface GridEventListener {
        fun onGridEvent(event: GridEvent)
    }

    interface BeforeEditListener {
        fun onBeforeEdit(details: BeforeEditDetails)
    }

    interface CellEditValidatingListener {
        fun onCellEditValidating(details: CellEditValidatingDetails)
    }

    interface BeforeSortListener {
        fun onBeforeSort(details: BeforeSortDetails)
    }

    interface EditCommitListener {
        fun onEditCommit(row: Int, col: Int, text: String)
        fun onEditCancel(row: Int, col: Int)
    }

    enum class ContextMenuTrigger {
        LONG_PRESS,
        SECONDARY_CLICK,
    }

    data class ContextMenuRequest(
        val trigger: ContextMenuTrigger,
        val localX: Float,
        val localY: Float,
        val screenX: Float,
        val screenY: Float,
        val row: Int,
        val col: Int,
        val selectionRow1: Int,
        val selectionCol1: Int,
        val selectionRow2: Int,
        val selectionCol2: Int,
    )

    interface ContextMenuRequestListener {
        fun onContextMenuRequest(request: ContextMenuRequest)
    }

    data class BeforeEditDetails(
        val rawEvent: GridEvent,
        val row: Int,
        val col: Int,
        var cancel: Boolean = false
    )

    data class CellEditValidatingDetails(
        val rawEvent: GridEvent,
        val row: Int,
        val col: Int,
        val editText: String,
        var cancel: Boolean = false
    )

    data class BeforeSortDetails(
        val rawEvent: GridEvent,
        val col: Int,
        var cancel: Boolean = false
    )

    init {
        isFocusable = true
        isFocusableInTouchMode = true
        clipChildren = false
        clipToPadding = false
        if (useHostFling) {
            flingScroller.setFriction(flingFriction)
        }

        setupSurfaceView()
        setupImeProxy()
    }

    private fun setupSurfaceView() {
        // wgpu creates its own GLES (or Vulkan) swapchain and negotiates format directly with the ANativeWindow.
        // On Android, we prefer OpenGL ES to avoid common Adreno driver bugs during Vulkan capability probing.
        // Explicitly setting PixelFormat.RGBA_8888 here can still cause allocation failures on some drivers.
        addView(surfaceView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                surfaceReady.set(true)
                // If a frame arrived before surface creation, the bitmap is ready. Draw it now.
                drawBitmapToSurface()
                if (gridId != 0L) {
                    requestRenderFrame()
                    // Force a follow-up render in case the Rust side needs to drop 
                    // a stale surface handle and reconfigure on the next frame.
                    needsFollowupRender.set(true)
                }
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                if (gridId != 0L) {
                    resizeBuffer(width, height)
                }
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                surfaceReady.set(false)
                val ptr = nativeWindowPtr
                nativeWindowPtr = 0
                gpuSurfaceActive = false
                // Always notify invalidation on surface teardown in GPU mode.
                // A stale native handle can be pointer-reused by the platform;
                // forcing drop avoids rendering to an invalid old swapchain.
                if (currentRendererMode >= 2 && gridId != 0L) {
                    sendGpuSurfaceInvalidated()
                }
                if (ptr != 0L) NativeWindowHelper.releaseNativeWindow(ptr)
            }
        })
    }

    private fun recreateSurfaceView() {
        surfaceReady.set(false)
        removeView(surfaceView)
        surfaceView = SurfaceView(context)
        setupSurfaceView()
    }

    private fun setupImeProxy() {
        val proxy = EditText(context).apply {
            isFocusable = true
            isFocusableInTouchMode = true
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            showSoftInputOnFocus = false
            layoutParams = LayoutParams(1, 1).apply {
                leftMargin = -1
                topMargin = -1
            }
            alpha = 0f
            setBackgroundColor(0)
            setPadding(0, 0, 0, 0)
        }
        // Don't addView here — adding an EditText to the tree at init causes
        // some Android versions to auto-focus it and show the soft keyboard.
        // It is added lazily in requestIdleInputFocus() on first user touch.
        imeProxy = proxy

        proxy.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable) {
                if (suppressImeProxyWatcher) return
                if (gridId == 0L) return

                val composingStart = BaseInputConnection.getComposingSpanStart(s)
                val composingEnd = BaseInputConnection.getComposingSpanEnd(s)
                val isComposing = composingStart >= 0 && composingEnd > composingStart

                if (isComposing) {
                    val preeditText = s.subSequence(composingStart, composingEnd).toString()
                    if (!imeProxyComposing) {
                        // Composition just started — begin edit in engine
                        imeProxyComposing = true
                        deferOverlayWhileImeActive = true
                        imeProxyLastCommittedLen = composingStart
                        try {
                            ffiClient?.Edit(
                                EditCommand.newBuilder()
                                    .setGridId(gridId)
                                    .setStart(EditStart.newBuilder().build())
                                    .build()
                            )
                        } catch (_: FfiError) {}
                    }
                    sendPreedit(preeditText, preeditText.length, commit = false)
                } else if (imeProxyComposing) {
                    // Composition just ended — commit
                    imeProxyComposing = false
                    val fullText = s.toString()
                    val delta = if (fullText.length > imeProxyLastCommittedLen) {
                        fullText.substring(imeProxyLastCommittedLen)
                    } else {
                        ""
                    }
                    if (delta.isNotEmpty()) {
                        sendPreedit(delta, 0, commit = true)
                    }
                    imeProxyLastCommittedLen = fullText.length
                    // Schedule deferred overlay reveal
                    deferOverlayHandler.postDelayed({
                        val pending = pendingEditRequest
                        if (pending != null) {
                            pendingEditRequest = null
                            deferOverlayWhileImeActive = false
                            showEditOverlay(pending)
                        } else {
                            deferOverlayWhileImeActive = false
                        }
                    }, 60L)
                } else {
                    // Plain text without composition (hardware keyboard)
                    val fullText = s.toString()
                    if (fullText.length > imeProxyLastCommittedLen) {
                        val delta = fullText.substring(imeProxyLastCommittedLen)
                        imeProxyLastCommittedLen = fullText.length
                        // Start edit with seed text
                        deferOverlayWhileImeActive = true
                        try {
                            ffiClient?.Edit(
                                EditCommand.newBuilder()
                                    .setGridId(gridId)
                                    .setStart(EditStart.newBuilder()
                                        .setSeedText(delta)
                                        .build())
                                    .build()
                            )
                        } catch (_: FfiError) {}
                        deferOverlayHandler.postDelayed({
                            val pending = pendingEditRequest
                            if (pending != null) {
                                pendingEditRequest = null
                                deferOverlayWhileImeActive = false
                                showEditOverlay(pending)
                            } else {
                                deferOverlayWhileImeActive = false
                            }
                        }, 60L)
                    }
                }
            }
        })

        // Forward hardware key events from imeProxy to the engine
        proxy.setOnKeyListener { _, keyCode, event ->
            if (editOverlay != null) return@setOnKeyListener false
            renderStream ?: return@setOnKeyListener false
            when (keyCode) {
                AndroidKeyEvent.KEYCODE_DPAD_UP,
                AndroidKeyEvent.KEYCODE_DPAD_DOWN,
                AndroidKeyEvent.KEYCODE_DPAD_LEFT,
                AndroidKeyEvent.KEYCODE_DPAD_RIGHT,
                AndroidKeyEvent.KEYCODE_ENTER,
                AndroidKeyEvent.KEYCODE_NUMPAD_ENTER,
                AndroidKeyEvent.KEYCODE_ESCAPE,
                AndroidKeyEvent.KEYCODE_TAB -> {
                    if (event.action == AndroidKeyEvent.ACTION_DOWN) {
                        onKeyDown(keyCode, event)
                    } else if (event.action == AndroidKeyEvent.ACTION_UP) {
                        onKeyUp(keyCode, event)
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun requestIdleInputFocus() {
        // On touch-only Android devices, focusing the hidden IME proxy can still
        // surface the soft keyboard on some OEM builds. Keep the proxy only for
        // physical-keyboard scenarios where composition without an edit overlay
        // is still useful.
        val cfg = resources.configuration
        if (cfg.keyboard == android.content.res.Configuration.KEYBOARD_NOKEYS ||
            cfg.hardKeyboardHidden != android.content.res.Configuration.HARDKEYBOARDHIDDEN_NO) {
            return
        }
        val proxy = imeProxy ?: return
        if (proxy.parent == null) {
            addView(proxy, 0) // behind SurfaceView
        }
        if (!proxy.hasFocus()) {
            proxy.requestFocus()
        }
    }

    private fun clearImeProxy() {
        suppressImeProxyWatcher = true
        imeProxy?.setText("")
        imeProxyComposing = false
        imeProxyLastCommittedLen = 0
        suppressImeProxyWatcher = false
    }

    private fun sendPreedit(text: String, cursor: Int, commit: Boolean) {
        try {
            ffiClient?.Edit(
                EditCommand.newBuilder()
                    .setGridId(gridId)
                    .setSetPreedit(
                        EditSetPreedit.newBuilder()
                            .setText(text)
                            .setCursor(cursor)
                            .setCommit(commit)
                            .build()
                    )
                    .build()
            )
        } catch (_: FfiError) {}
        requestRenderFrame()
    }

    private fun codeUnitOffset(text: String, codePointOffset: Int): Int {
        if (codePointOffset <= 0) return 0
        val len = text.length
        var cpCount = 0
        var i = 0
        while (i < len && cpCount < codePointOffset) {
            if (Character.isHighSurrogate(text[i]) && i + 1 < len && Character.isLowSurrogate(text[i + 1])) {
                i += 2
            } else {
                i += 1
            }
            cpCount++
        }
        return i.coerceAtMost(len)
    }

    // =========================================================================
    // Public API
    // =========================================================================

    /**
     * Updates the host-side (Android callback) text rendering cache size.
     *
     * This affects lite mode immediately and is safe to call at runtime.
     * For full mode with built-in text engine, this setting is simply unused.
     */
    fun setAndroidTextCacheSize(size: Int) {
        pendingAndroidTextCacheSize = size
        androidTextRenderer.setCacheSize(size)
        val p = plugin
        val id = gridId
        if (p != null && id != 0L) {
            NativeTextRendererBridge.setCacheCap(p, id, size)
        }
    }

    /**
     * Initialize the grid view with the plugin bundled in the app/AAR and grid dimensions.
     *
     * This auto-detects either `libvolvoxgrid_plugin.so` (standard) or
     * `libvolvoxgrid_plugin_lite.so` (lite) from `nativeLibraryDir`.
     */
    @JvmOverloads
    fun initialize(
        rows: Int,
        cols: Int
    ) {
        initialize(resolveBundledPluginPath(context), rows, cols)
    }

    /**
     * Initialize the grid view with a plugin path and grid dimensions.
     *
     * @param pluginPath absolute path to `libvolvoxgrid_plugin.so` or
     * `libvolvoxgrid_plugin_lite.so`
     * @param rows initial number of rows
     * @param cols initial number of columns
     */
    fun initialize(
        pluginPath: String,
        rows: Int,
        cols: Int
    ) {
        released.set(false)
        val p = PluginHost.load(pluginPath)
        logPluginLoadBannerOnce(pluginPath)
        plugin = p
        val client = VolvoxGridServiceFfi(p)
        ffiClient = client

        val w = resolveViewportWidth()
        val h = resolveViewportHeight()
        val density = resources.displayMetrics.density
        val scale = if (density > 0f) density else 1f

        val response = client.Create(
            CreateRequest.newBuilder()
                .setViewportWidth(w)
                .setViewportHeight(h)
                .setScale(scale)
                .setConfig(GridConfig.newBuilder()
                    .setLayout(LayoutConfig.newBuilder()
                        .setRows(rows)
                        .setCols(cols)
                        .build())
                    .setRendering(RenderConfig.newBuilder()
                        .setFramePacingMode(FramePacingMode.FRAME_PACING_MODE_PLATFORM)
                        .build())
                    .setIndicators(defaultIndicatorsConfig())
                    .build())
                .build()
        )
        gridId = response.handle.id

        maybeRegisterExternalTextRenderer()
        applyAndroidScrollDefaults()
        updateTouchScrollUnitFromGrid()
        syncViewportSizeOnAttach(w, h)
        allocateBuffer(w, h)
        startRenderSession()
        startEventStream()
        syncViewportToMeasuredSize()
    }

    /**
     * Initialize the grid view with a pre-loaded plugin host and existing grid ID.
     */
    fun initialize(host: PluginHost, existingGridId: Long) {
        detachGrid() // Ensure previous session is stopped
        released.set(false)
        logPluginLoadBannerOnce("<preloaded>")
        plugin = host
        ffiClient = VolvoxGridServiceFfi(host)
        gridId = existingGridId

        val w = resolveViewportWidth()
        val h = resolveViewportHeight()
        maybeRegisterExternalTextRenderer()
        applyAndroidScrollDefaults()
        updateTouchScrollUnitFromGrid()
        syncViewportSizeOnAttach(w, h)
        allocateBuffer(w, h)
        startRenderSession()
        startEventStream()
        syncViewportToMeasuredSize()
    }

    /**
     * Stop the current render/event session but keep the grid alive in the engine.
     * Use this when switching between multiple grids on the same view.
     */
    fun detachGrid() {
        running.set(false)
        decisionChannelEnabled = false
        stopEngineFlingForCurrentGrid()
        stopFling()
        stopEngineMomentumPump()
        recycleVelocityTracker()
        scrollDispatchScheduled = false
        pendingScrollDeltaX = 0f
        pendingScrollDeltaY = 0f
        pendingScrollNeedsRender = false
        zoomDispatchScheduled = false
        clearQueuedZoom()
        activePointerId = MotionEvent.INVALID_POINTER_ID
        isTouchScrolling = false
        isPinchZooming = false
        ignoreTouchUntilUp = false
        clearGesturePreviewOnNextFrame = false
        stopGesturePreview()
        knownRows = 0
        pendingFrame.set(false)
        needsFollowupRender.set(false)
        renderRequestPending.set(false)
        deferOverlayWhileImeActive = false
        pendingEditRequest = null
        deferOverlayHandler.removeCallbacksAndMessages(null)
        clearImeProxy()
        dismissEditOverlay()

        // Release GPU native window to avoid resource leak across grid switches.
        gpuSurfaceActive = false
        val ptr = nativeWindowPtr
        nativeWindowPtr = 0
        if (ptr != 0L) NativeWindowHelper.releaseNativeWindow(ptr)

        val streamToClose = synchronized(sendLock) {
            val stream = renderStream
            renderStream = null
            stream
        }
        streamToClose?.let {
            try { it.closeSend() } catch (_: Exception) {}
            try { it.close() } catch (_: Exception) {}
        }

        stopEventStream(waitForThread = true)

        clearExternalTextRenderer(gridId)
        usingExternalTextRenderer = false

        // Don't destroy gridId or plugin
        ffiClient = null
        gridId = 0
    }

    /** Get the underlying FFI client for direct API calls. */
    fun getService(): VolvoxGridServiceFfi? = ffiClient

    /** Get the grid handle ID for use with the controller or direct FFI calls. */
    fun getGridId(): Long = gridId

    /** Create a [VolvoxGridController] wrapping this view's FFI client and grid ID. */
    override fun createController(): VolvoxGridController {
        val client = ffiClient ?: throw IllegalStateException("VolvoxGridView not initialized")
        return VolvoxGridController(client, gridId)
    }

    /**
     * Request a render frame on the next VSync.
     *
     * Useful after out-of-band controller mutations (e.g. setCellText/refresh)
     * that do not flow through the render input stream.
     */
    override fun requestFrame() {
        if (gridId == 0L) return
        requestRenderFrame()
    }

    /**
     * Request a render frame immediately.
     */
    override fun requestFrameImmediate() {
        if (gridId == 0L) return
        requestRenderFrameImmediate()
    }

    /**
     * Tune fling deceleration. Higher values stop faster, lower values glide longer.
     */
    fun setFlingFriction(friction: Float) {
        val clamped = friction.coerceIn(0.001f, 0.15f)
        flingFriction = clamped
        flingScroller.setFriction(clamped)
    }

    fun getFlingFriction(): Float = flingFriction

    /**
     * Notify the view of a renderer mode change (AUTO=0, CPU=1, GPU=2+).
     *
     * Call this after [VolvoxGridController.setRendererMode] so the view
     * can switch between buffer-based and GPU surface rendering paths.
     */
    fun setRendererMode(mode: Int) {
        if (android.os.Looper.myLooper() != android.os.Looper.getMainLooper()) {
            post { setRendererMode(mode) }
            return
        }
        val prevMode = currentRendererMode
        if (prevMode == mode) return
        currentRendererMode = mode

        // Reset flow control state for the new mode
        pendingFrame.set(false)
        needsFollowupRender.set(false)

        if (prevMode >= 2 && mode < 2) {
            // Switching GPU -> CPU
            gpuSurfaceActive = false
            sendGpuSurfaceInvalidated()
            val ptr = nativeWindowPtr
            nativeWindowPtr = 0
            if (ptr != 0L) {
                NativeWindowHelper.releaseNativeWindow(ptr)
            }
            // Recreate SurfaceView to avoid CPU canvas contention after GPU usage.
            recreateSurfaceView()
        } else if (mode >= 2 && prevMode < 2) {
            // Switching CPU -> GPU
            recreateSurfaceView()
        }

        if (gridId != 0L && surfaceReady.get()) {
            requestRenderFrame()
        }
    }

    /**
     * Release all resources. Call this when the view is no longer needed.
     */
    override fun release() {
        if (!released.compareAndSet(false, true)) return
        running.set(false)
        decisionChannelEnabled = false
        stopEngineFlingForCurrentGrid()
        if (useHostFling) {
            stopFling()
        }
        stopEngineMomentumPump()
        recycleVelocityTracker()
        activePointerId = MotionEvent.INVALID_POINTER_ID
        isTouchScrolling = false
        isPinchZooming = false
        pinchLastFocusX = 0f
        pinchLastFocusY = 0f
        ignoreTouchUntilUp = false
        pendingScrollDeltaX = 0f
        pendingScrollDeltaY = 0f
        pendingScrollNeedsRender = false
        zoomDispatchScheduled = false
        clearQueuedZoom()
        clearGesturePreviewOnNextFrame = false
        stopGesturePreview()
        knownRows = 0
        deferOverlayWhileImeActive = false
        pendingEditRequest = null
        deferOverlayHandler.removeCallbacksAndMessages(null)
        clearImeProxy()
        dismissEditOverlay()

        gpuSurfaceActive = false
        val ptr = nativeWindowPtr
        nativeWindowPtr = 0
        if (ptr != 0L) NativeWindowHelper.releaseNativeWindow(ptr)

        renderStream?.let {
            try { it.closeSend() } catch (_: Exception) {}
            try { it.close() } catch (_: Exception) {}
        }
        renderStream = null
        stopEventStream(waitForThread = true)

        if (gridId != 0L) {
            clearExternalTextRenderer(gridId)
            usingExternalTextRenderer = false
            try {
                ffiClient?.Destroy(GridHandle.newBuilder().setId(gridId).build())
            } catch (_: Exception) {}
            gridId = 0
        }

        plugin?.close()
        plugin = null
        ffiClient = null
        bitmap?.recycle()
        bitmap = null
        pixelBuffer = null
    }

    // =========================================================================
    // Input Handling
    // =========================================================================

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val stream = renderStream ?: return super.onTouchEvent(event)
        scaleGestureDetector.onTouchEvent(event)

        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            updateTouchScrollUnitFromGrid()
        }

        if (isPinchZooming || ignoreTouchUntilUp) {
            when (event.actionMasked) {
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (event.actionMasked == MotionEvent.ACTION_CANCEL) {
                        if (useHostFling) {
                            stopFling()
                        }
                        stopEngineMomentumPump()
                        clearGesturePreviewOnNextFrame = false
                    }
                    recycleVelocityTracker()
                    activePointerId = MotionEvent.INVALID_POINTER_ID
                    isTouchScrolling = false
                    pendingScrollDeltaX = 0f
                    pendingScrollDeltaY = 0f
                    pendingScrollNeedsRender = false
                    clearQueuedZoom()
                    pinchLastFocusX = 0f
                    pinchLastFocusY = 0f
                    ignoreTouchUntilUp = false
                    if (event.actionMasked == MotionEvent.ACTION_CANCEL || !clearGesturePreviewOnNextFrame) {
                        stopGesturePreview()
                    }
                }
            }
            return true
        }

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                if (useHostFling) {
                    stopFling()
                }
                resetVelocityTracker(event)
                stopEngineMomentumPump()
                if (editOverlay != null) {
                    commitEdit(editingRow, editingCol, editOverlay?.text?.toString() ?: "")
                } else {
                    requestIdleInputFocus()
                }
                activePointerId = event.getPointerId(0)
                touchStartX = event.x
                touchStartY = event.y
                lastTouchX = event.x
                lastTouchY = event.y
                isTouchScrolling = false
                pendingScrollDeltaX = 0f
                pendingScrollDeltaY = 0f
                pendingScrollNeedsRender = false
                clearQueuedZoom()
                val now = android.os.SystemClock.uptimeMillis()
                val dx = event.x - lastTapX
                val dy = event.y - lastTapY
                val isDoubleTap = (now - lastTapTime) <= doubleTapTimeout
                    && (dx * dx + dy * dy) <= doubleTapSlop * doubleTapSlop
                lastTapTime = now
                lastTapX = event.x
                lastTapY = event.y
                val isSecondaryClick =
                    event.getToolType(0) != MotionEvent.TOOL_TYPE_FINGER &&
                        (event.buttonState and MotionEvent.BUTTON_SECONDARY) != 0
                val downX = event.x
                val downY = event.y
                sendPointerEvent(stream, PointerEvent.Type.DOWN, lastTouchX, lastTouchY, dblClick = isDoubleTap)
                requestRenderFrame()
                longPressRunnable?.let { removeCallbacks(it) }
                if (isSecondaryClick) {
                    if (contextMenuRequestListener != null) {
                        postDelayed(
                            {
                                dispatchContextMenuRequest(
                                    ContextMenuTrigger.SECONDARY_CLICK,
                                    downX,
                                    downY
                                )
                            },
                            50L
                        )
                    }
                    return true
                }
                if (contextMenuRequestListener != null) {
                    longPressRunnable = Runnable {
                        if (!isTouchScrolling && !isPinchZooming) {
                            dispatchContextMenuRequest(ContextMenuTrigger.LONG_PRESS, downX, downY)
                        }
                    }
                    postDelayed(longPressRunnable!!, longPressTimeout)
                }
                return true
            }

            MotionEvent.ACTION_POINTER_DOWN -> {
                velocityTracker?.addMovement(event)
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                velocityTracker?.addMovement(event)
                val pointerIndex = event.findPointerIndex(activePointerId).takeIf { it >= 0 } ?: 0
                val x = event.getX(pointerIndex)
                val y = event.getY(pointerIndex)
                val dx = x - lastTouchX
                val dy = y - lastTouchY
                val totalDx = x - touchStartX
                val totalDy = y - touchStartY

                if (!isTouchScrolling &&
                    (kotlin.math.abs(totalDx) > touchSlop || kotlin.math.abs(totalDy) > touchSlop)
                ) {
                    isTouchScrolling = true
                    longPressRunnable?.let { removeCallbacks(it) }
                    if (editOverlay != null) {
                        cancelEdit(editingRow, editingCol)
                    }
                }

                // Always forward pointer MOVE so engine-side long-press header
                // reorder can activate even after touch crosses scroll slop.
                sendPointerEvent(stream, PointerEvent.Type.MOVE, x, y)
                if (isTouchScrolling) {
                    // Engine scroll deltas are "row units"; convert finger pixels
                    // to row units using current default row height for 1:1 feel.
                    queueScrollDelta(
                        pixelsToScrollUnits(-dx),
                        pixelsToScrollUnits(-dy),
                        immediate = true
                    )
                } else {
                    requestRenderFrame()
                }

                lastTouchX = x
                lastTouchY = y
                return true
            }

            MotionEvent.ACTION_POINTER_UP -> {
                velocityTracker?.addMovement(event)
                val liftedId = event.getPointerId(event.actionIndex)
                if (liftedId == activePointerId) {
                    val newIndex = when {
                        event.pointerCount <= 1 -> -1
                        event.actionIndex == 0 -> 1
                        else -> 0
                    }
                    if (newIndex >= 0) {
                        activePointerId = event.getPointerId(newIndex)
                        touchStartX = event.getX(newIndex)
                        touchStartY = event.getY(newIndex)
                        lastTouchX = event.getX(newIndex)
                        lastTouchY = event.getY(newIndex)
                    } else {
                        activePointerId = MotionEvent.INVALID_POINTER_ID
                    }
                }
                return true
            }

            MotionEvent.ACTION_UP -> {
                longPressRunnable?.let { removeCallbacks(it) }
                velocityTracker?.addMovement(event)
                if (useHostFling) {
                    maybeStartFling()
                } else {
                    maybeStartEngineFling()
                }
                recycleVelocityTracker()
                flushQueuedScroll()
                val pointerIndex = event.findPointerIndex(activePointerId)
                val upX = if (pointerIndex >= 0 && pointerIndex < event.pointerCount) {
                    event.getX(pointerIndex)
                } else {
                    lastTouchX
                }
                val upY = if (pointerIndex >= 0 && pointerIndex < event.pointerCount) {
                    event.getY(pointerIndex)
                } else {
                    lastTouchY
                }
                sendPointerEvent(stream, PointerEvent.Type.UP, upX, upY)
                requestRenderFrame()
                if (!isTouchScrolling) {
                    performClick()
                }
                activePointerId = MotionEvent.INVALID_POINTER_ID
                isTouchScrolling = false
                isPinchZooming = false
                pinchLastFocusX = 0f
                pinchLastFocusY = 0f
                pendingScrollNeedsRender = false
                clearQueuedZoom()
                clearGesturePreviewOnNextFrame = false
                stopGesturePreview()
                return true
            }

            MotionEvent.ACTION_CANCEL -> {
                longPressRunnable?.let { removeCallbacks(it) }
                if (useHostFling) {
                    stopFling()
                }
                stopEngineMomentumPump()
                recycleVelocityTracker()
                flushQueuedScroll()
                val pointerIndex = event.findPointerIndex(activePointerId)
                val cancelX = if (pointerIndex >= 0 && pointerIndex < event.pointerCount) {
                    event.getX(pointerIndex)
                } else {
                    lastTouchX
                }
                val cancelY = if (pointerIndex >= 0 && pointerIndex < event.pointerCount) {
                    event.getY(pointerIndex)
                } else {
                    lastTouchY
                }
                sendPointerEvent(stream, PointerEvent.Type.UP, cancelX, cancelY)
                requestRenderFrame()
                activePointerId = MotionEvent.INVALID_POINTER_ID
                isTouchScrolling = false
                isPinchZooming = false
                pinchLastFocusX = 0f
                pinchLastFocusY = 0f
                pendingScrollNeedsRender = false
                clearQueuedZoom()
                ignoreTouchUntilUp = false
                clearGesturePreviewOnNextFrame = false
                stopGesturePreview()
                return true
            }

            else -> return super.onTouchEvent(event)
        }
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }

    override fun onKeyDown(keyCode: Int, event: AndroidKeyEvent): Boolean {
        val stream = renderStream ?: return super.onKeyDown(keyCode, event)
        try {
            val keyDown = RenderInput.newBuilder()
                .setGridId(gridId)
                .setKey(
                    KeyEvent.newBuilder()
                        .setType(KeyEvent.Type.KEY_DOWN)
                        .setKeyCode(keyCode)
                        .setModifier(event.metaState)
                        .setCharacter(
                            if (event.unicodeChar != 0) event.unicodeChar.toChar().toString()
                            else ""
                        )
                        .build()
                )
                .build()
            sendRenderInput(keyDown)

            val ch = event.unicodeChar
            if (ch >= 0x20 && !event.isCtrlPressed && !event.isAltPressed && !event.isMetaPressed) {
                val keyPress = RenderInput.newBuilder()
                    .setGridId(gridId)
                    .setKey(
                        KeyEvent.newBuilder()
                            .setType(KeyEvent.Type.KEY_PRESS)
                            .setKeyCode(keyCode)
                            .setModifier(event.metaState)
                            .setCharacter(ch.toChar().toString())
                            .build()
                    )
                    .build()
                sendRenderInput(keyPress)
            }
            requestRenderFrame()
        } catch (_: FfiError) {}
        return true
    }

    override fun onKeyUp(keyCode: Int, event: AndroidKeyEvent): Boolean {
        val stream = renderStream ?: return super.onKeyUp(keyCode, event)
        try {
            val input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setKey(
                    KeyEvent.newBuilder()
                        .setType(KeyEvent.Type.KEY_UP)
                        .setKeyCode(keyCode)
                        .setModifier(event.metaState)
                        .build()
                )
                .build()
            sendRenderInput(input)
            requestRenderFrame()
        } catch (_: FfiError) {}
        return true
    }

    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        // Handle scroll wheel / trackpad scroll
        if (event.action == MotionEvent.ACTION_SCROLL) {
            queueScrollDelta(
                event.getAxisValue(MotionEvent.AXIS_HSCROLL) * wheelScrollGain,
                event.getAxisValue(MotionEvent.AXIS_VSCROLL) * wheelScrollGain
            )
            return true
        }
        return super.onGenericMotionEvent(event)
    }

    private fun queueScrollDelta(
        deltaX: Float,
        deltaY: Float,
        immediate: Boolean = false,
        requestRender: Boolean = true
    ) {
        pendingScrollDeltaX += deltaX
        pendingScrollDeltaY += deltaY
        pendingScrollNeedsRender = pendingScrollNeedsRender || requestRender
        if (immediate) {
            flushQueuedScroll()
            return
        }
        if (scrollDispatchScheduled) {
            return
        }
        scrollDispatchScheduled = true
        postOnAnimation {
            scrollDispatchScheduled = false
            flushQueuedScroll()
        }
    }

    private fun flushQueuedScroll() {
        val dx = pendingScrollDeltaX
        val dy = pendingScrollDeltaY
        if (dx == 0f && dy == 0f) {
            pendingScrollNeedsRender = false
            return
        }
        pendingScrollDeltaX = 0f
        pendingScrollDeltaY = 0f
        val shouldRender = pendingScrollNeedsRender
        pendingScrollNeedsRender = false
        val stream = renderStream ?: return
        sendScrollEvent(stream, dx, dy)
        if (shouldRender) {
            // Scroll is already throttled by queueScrollDelta; render immediately to avoid double-latency.
            requestRenderFrameImmediate()
        }
        if (!useHostFling && !isTouchScrolling && !isPinchZooming) {
            startEngineMomentumPump()
        }
    }

    private fun queueZoomDelta(
        scaleDelta: Float,
        focalX: Float,
        focalY: Float,
        requestRender: Boolean = true
    ) {
        if (!scaleDelta.isFinite() || scaleDelta <= 0f) {
            return
        }
        val normalizedDelta = scaleDelta.coerceIn(ZOOM_STEP_MIN_SCALE, ZOOM_STEP_MAX_SCALE)
        pendingZoomScale = (pendingZoomScale * normalizedDelta).coerceIn(ZOOM_RAW_SCALE_MIN, ZOOM_RAW_SCALE_MAX)
        pendingZoomFocalX = focalX
        pendingZoomFocalY = focalY
        pendingZoomNeedsRender = pendingZoomNeedsRender || requestRender
        pendingZoomActive = true
        if (zoomDispatchScheduled) {
            return
        }
        zoomDispatchScheduled = true
        postOnAnimation {
            zoomDispatchScheduled = false
            flushQueuedZoom()
        }
    }

    private fun flushQueuedZoom() {
        if (!pendingZoomActive) {
            pendingZoomNeedsRender = false
            return
        }
        val scale = pendingZoomScale
        val focalX = pendingZoomFocalX
        val focalY = pendingZoomFocalY
        val shouldRender = pendingZoomNeedsRender
        clearQueuedZoom()
        if (kotlin.math.abs(scale - 1f) <= ZOOM_STEP_NOISE_EPSILON) {
            if (shouldRender) {
                requestRenderFrame()
            }
            return
        }
        var remaining = scale
        while (remaining > ZOOM_STEP_MAX_SCALE) {
            sendZoomEvent(
                phase = ZoomEvent.Phase.ZOOM_UPDATE,
                scale = ZOOM_STEP_MAX_SCALE,
                focalX = focalX,
                focalY = focalY,
                requestRender = false
            )
            remaining /= ZOOM_STEP_MAX_SCALE
        }
        while (remaining < ZOOM_STEP_MIN_SCALE) {
            sendZoomEvent(
                phase = ZoomEvent.Phase.ZOOM_UPDATE,
                scale = ZOOM_STEP_MIN_SCALE,
                focalX = focalX,
                focalY = focalY,
                requestRender = false
            )
            remaining /= ZOOM_STEP_MIN_SCALE
        }
        if (kotlin.math.abs(remaining - 1f) <= ZOOM_STEP_NOISE_EPSILON) {
            if (shouldRender) {
                requestRenderFrame()
            }
            return
        }
        sendZoomEvent(
            phase = ZoomEvent.Phase.ZOOM_UPDATE,
            scale = remaining,
            focalX = focalX,
            focalY = focalY,
            requestRender = shouldRender
        )
    }

    private fun clearQueuedZoom() {
        pendingZoomScale = 1f
        pendingZoomFocalX = 0f
        pendingZoomFocalY = 0f
        pendingZoomNeedsRender = false
        pendingZoomActive = false
    }

    private fun resetVelocityTracker(event: MotionEvent) {
        val tracker = velocityTracker ?: VelocityTracker.obtain().also { velocityTracker = it }
        tracker.clear()
        tracker.addMovement(event)
    }

    private fun recycleVelocityTracker() {
        velocityTracker?.recycle()
        velocityTracker = null
    }

    private fun pixelsToScrollUnits(deltaPx: Float): Float {
        return deltaPx / touchScrollUnitPx.coerceAtLeast(1f)
    }

    private fun updateTouchScrollUnitFromGrid() {
        val client = ffiClient ?: return
        if (gridId == 0L) return
        try {
            val config = client.GetConfig(
                GridHandle.newBuilder()
                    .setId(gridId)
                    .build()
            )
            knownRows = config.layout.rows
            val defaultRowHeight = config.layout.defaultRowHeight
            if (defaultRowHeight > 0) {
                touchScrollUnitPx = defaultRowHeight.toFloat()
            }
        } catch (_: Exception) {
            // Keep last known unit
            knownRows = 0
        }
    }

    private fun useLargeGridGesturePreview(): Boolean {
        return knownRows >= LARGE_GRID_GESTURE_PREVIEW_ROWS
    }

    private fun startGesturePreview(focalX: Float, focalY: Float) {
        // Row count can change at runtime; refresh once per gesture start.
        updateTouchScrollUnitFromGrid()
        if (!useLargeGridGesturePreview()) {
            return
        }
        gesturePreviewActive = true
        gesturePreviewScale = 1f
        gesturePreviewPanX = 0f
        gesturePreviewPanY = 0f
        gesturePreviewFocalX = focalX
        gesturePreviewFocalY = focalY
        drawBitmapToSurface()
    }

    private fun updateGesturePreview(
        focalX: Float,
        focalY: Float,
        panDx: Float,
        panDy: Float,
        scaleDelta: Float
    ) {
        if (!gesturePreviewActive) {
            return
        }
        val normalizedDelta = if (scaleDelta.isFinite() && scaleDelta > 0f) {
            scaleDelta
        } else {
            1f
        }
        gesturePreviewFocalX = focalX
        gesturePreviewFocalY = focalY
        gesturePreviewPanX += panDx
        gesturePreviewPanY += panDy
        val nextScale = (gesturePreviewScale * normalizedDelta)
            .coerceIn(GESTURE_PREVIEW_MIN_SCALE, GESTURE_PREVIEW_MAX_SCALE)
        gesturePreviewScale = if (kotlin.math.abs(nextScale - 1f) < 0.0005f) 1f else nextScale
        drawBitmapToSurface()
    }

    private fun stopGesturePreview() {
        clearGesturePreviewOnNextFrame = false
        val wasActive = gesturePreviewActive ||
            gesturePreviewScale != 1f ||
            gesturePreviewPanX != 0f ||
            gesturePreviewPanY != 0f
        gesturePreviewActive = false
        gesturePreviewScale = 1f
        gesturePreviewPanX = 0f
        gesturePreviewPanY = 0f
        gesturePreviewFocalX = 0f
        gesturePreviewFocalY = 0f
        if (wasActive) {
            drawBitmapToSurface()
        }
    }

    private fun dp(px: Float): Float {
        return px * resources.displayMetrics.density
    }

    private fun currentViewportWidthPx(): Float {
        val w = surfaceView.width.takeIf { it > 0 } ?: bufferWidth
        return w.toFloat().coerceAtLeast(1f)
    }

    private fun currentViewportHeightPx(): Float {
        val h = surfaceView.height.takeIf { it > 0 } ?: bufferHeight
        return h.toFloat().coerceAtLeast(1f)
    }

    private fun applyAndroidScrollDefaults() {
        val client = ffiClient ?: return
        if (gridId == 0L) return
        try {
            // Unified engine-only path for inertia on modern touch platforms.
            // Flip via `useHostFling` for A/B comparison.
            val scrollConfig = ScrollConfig.newBuilder()
                .setFlingEnabled(!useHostFling)
                .setScrollTrack(true)
                .setFastScroll(true)
            if (!useHostFling) {
                scrollConfig
                    .setFlingImpulseGain(engineFlingImpulseGain)
                    .setFlingFriction(engineFlingFriction)
            }
            client.Configure(
                ConfigureRequest.newBuilder()
                    .setGridId(gridId)
                    .setConfig(GridConfig.newBuilder()
                        .setScrolling(scrollConfig.build())
                        .build())
                    .build()
            )
        } catch (_: Exception) {
            // Best-effort
        }
    }

    private fun maybeRegisterExternalTextRenderer() {
        val host = plugin ?: return
        val id = gridId
        if (id == 0L) return

        val hasBuiltin = NativeTextRendererBridge.hasBuiltinTextEngine(host)
        usingExternalTextRenderer = false
        if (hasBuiltin) {
            return
        }

        val registered = NativeTextRendererBridge.registerTextRenderer(
            host = host,
            gridId = id,
            callback = androidTextRenderer
        )
        usingExternalTextRenderer = registered
        if (registered) {
            android.util.Log.i(TAG, "Registered Android text renderer callback for grid=$id")
            pendingAndroidTextCacheSize?.let {
                NativeTextRendererBridge.setCacheCap(host, id, it)
            }
        } else {
            android.util.Log.w(TAG, "Failed to register Android text renderer callback for grid=$id")
        }
    }

    private fun clearExternalTextRenderer(id: Long) {
        if (id == 0L) return
        val host = plugin ?: return
        if (!usingExternalTextRenderer) return
        NativeTextRendererBridge.clearTextRenderer(host, id)
    }

    private fun stopEngineFlingForCurrentGrid() {
        val client = ffiClient ?: return
        if (gridId == 0L) return
        try {
            client.Configure(
                ConfigureRequest.newBuilder()
                    .setGridId(gridId)
                    .setConfig(GridConfig.newBuilder()
                        .setScrolling(ScrollConfig.newBuilder()
                            .setFlingEnabled(false)
                            .build())
                        .build())
                    .build()
            )
        } catch (_: Exception) {
            // Best-effort
        }
    }

    private fun maybeStartFling() {
        if (!isTouchScrolling) {
            return
        }
        val tracker = velocityTracker ?: return
        tracker.computeCurrentVelocity(1000, maxFlingVelocity)
        val pointerId = activePointerId
        val vx = if (pointerId != MotionEvent.INVALID_POINTER_ID) {
            tracker.getXVelocity(pointerId)
        } else {
            tracker.xVelocity
        }
        val vy = if (pointerId != MotionEvent.INVALID_POINTER_ID) {
            tracker.getYVelocity(pointerId)
        } else {
            tracker.yVelocity
        }
        if (kotlin.math.abs(vx) < minFlingVelocity && kotlin.math.abs(vy) < minFlingVelocity) {
            return
        }
        startFling(vx, vy)
    }

    private fun maybeStartEngineFling() {
        if (useHostFling || !isTouchScrolling) {
            return
        }
        val tracker = velocityTracker ?: return
        tracker.computeCurrentVelocity(1000, maxFlingVelocity)
        val pointerId = activePointerId
        val vx = if (pointerId != MotionEvent.INVALID_POINTER_ID) {
            tracker.getXVelocity(pointerId)
        } else {
            tracker.xVelocity
        }
        val vy = if (pointerId != MotionEvent.INVALID_POINTER_ID) {
            tracker.getYVelocity(pointerId)
        } else {
            tracker.yVelocity
        }
        if (kotlin.math.abs(vx) < minFlingVelocity && kotlin.math.abs(vy) < minFlingVelocity) {
            return
        }

        val unitPx = touchScrollUnitPx.coerceAtLeast(1f)
        val gain = engineFlingImpulseGain.coerceAtLeast(1f)
        // Inject one velocity-derived impulse into engine physics.
        // handle_scroll converts units->px and then px->velocity via fling impulse gain.
        queueScrollDelta(
            (-vx / gain) / unitPx,
            (-vy / gain) / unitPx,
            immediate = true
        )
        startEngineMomentumPump()
    }

    private fun startFling(velocityX: Float, velocityY: Float) {
        val vx = velocityX.coerceIn(-maxFlingVelocity, maxFlingVelocity).toInt()
        val vy = velocityY.coerceIn(-maxFlingVelocity, maxFlingVelocity).toInt()
        if (vx == 0 && vy == 0) {
            return
        }

        flingScroller.forceFinished(true)
        flingLastX = 0
        flingLastY = 0
        flingScroller.fling(
            0, 0,
            vx, vy,
            -1_000_000, 1_000_000,
            -1_000_000, 1_000_000
        )

        if (flingScheduled) {
            return
        }
        flingScheduled = true
        postOnAnimation { runFlingStep() }
    }

    private fun runFlingStep() {
        flingScheduled = false
        if (!running.get() || gridId == 0L || flingScroller.isFinished) {
            return
        }
        if (!flingScroller.computeScrollOffset()) {
            return
        }

        val currX = flingScroller.currX
        val currY = flingScroller.currY
        val dxPixels = (currX - flingLastX).toFloat()
        val dyPixels = (currY - flingLastY).toFloat()
        flingLastX = currX
        flingLastY = currY

        if (dxPixels != 0f || dyPixels != 0f) {
            pendingScrollDeltaX += pixelsToScrollUnits(-dxPixels)
            pendingScrollDeltaY += pixelsToScrollUnits(-dyPixels)
            flushQueuedScroll()
        }

        if (!flingScroller.isFinished) {
            flingScheduled = true
            postOnAnimation { runFlingStep() }
        }
    }

    private fun stopFling() {
        if (!flingScroller.isFinished) {
            flingScroller.forceFinished(true)
        }
        flingScheduled = false
    }

    private fun startEngineMomentumPump() {
        if (useHostFling || gridId == 0L) {
            return
        }
        engineMomentumFramesRemaining = engineMomentumMaxFrames
        engineMomentumIdleOutputs = 0
        if (engineMomentumScheduled) {
            return
        }
        engineMomentumScheduled = true
        postOnAnimation { runEngineMomentumPumpStep() }
    }

    private fun runEngineMomentumPumpStep() {
        engineMomentumScheduled = false
        if (useHostFling || gridId == 0L || !running.get()) {
            return
        }
        if (engineMomentumFramesRemaining <= 0) {
            return
        }
        if (engineMomentumIdleOutputs >= engineMomentumIdleStopOutputs) {
            stopEngineMomentumPump()
            return
        }
        engineMomentumFramesRemaining -= 1
        requestRenderFrameImmediate()
        if (engineMomentumFramesRemaining > 0) {
            engineMomentumScheduled = true
            postOnAnimation { runEngineMomentumPumpStep() }
        }
    }

    private fun stopEngineMomentumPump() {
        engineMomentumFramesRemaining = 0
        engineMomentumIdleOutputs = 0
        engineMomentumScheduled = false
    }

    private fun requestRenderFrame() {
        if (!renderRequestPending.compareAndSet(false, true)) {
            return
        }
        postOnAnimation {
            renderRequestPending.set(false)
            dispatchRenderFrame()
        }
    }

    private fun requestRenderFrameImmediate() {
        // If a request is already pending (via postOnAnimation), we can't easily cancel it,
        // but we can try to grab the token. If renderRequestPending is true, a frame is coming anyway.
        // If false, we send now.
        if (renderRequestPending.get()) {
            return
        }
        // We don't set renderRequestPending because we are executing synchronously/immediately
        // and relying on sendBufferReady/sendGpuSurfaceReady internal backpressure (pendingFrame).
        dispatchRenderFrame()
    }

    private fun dispatchRenderFrame() {
        if (windowVisibility != View.VISIBLE) {
            return
        }
        if (currentRendererMode >= 2) {
            if (!surfaceReady.get()) {
                // Surface not ready for GPU yet; surfaceCreated will trigger it.
                return
            }

            val ptr = acquireNativeWindow()
            if (ptr == 0L) {
                // Do not fall back to CPU path while in GPU mode: CPU frames are
                // not blitted in GPU mode and can consume the dirty state,
                // resulting in a black surface after resume.
                gpuSurfaceActive = false
                requestRenderFrame()
                return
            }

            gpuSurfaceActive = true
            sendGpuSurfaceReady(ptr, bufferWidth, bufferHeight)
            return
        }

        // CPU buffer path
        gpuSurfaceActive = false
        sendBufferReady()
    }

    private fun sendPointerEvent(
        stream: BidiStream<RenderInput, RenderOutput>,
        pointerType: PointerEvent.Type,
        x: Float,
        y: Float,
        dblClick: Boolean = false
    ) {
        try {
            val input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setPointer(
                    PointerEvent.newBuilder()
                        .setType(pointerType)
                        .setX(x)
                        .setY(y)
                        .setButton(0)
                        .setDblClick(dblClick)
                        .build()
                )
                .build()
            sendRenderInput(input)
        } catch (_: FfiError) {
            // Stream may have been closed
        }
    }

    private fun sendScrollEvent(
        stream: BidiStream<RenderInput, RenderOutput>,
        deltaX: Float,
        deltaY: Float
    ) {
        try {
            val input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setScroll(
                    ScrollEvent.newBuilder()
                        .setDeltaX(deltaX)
                        .setDeltaY(deltaY)
                        .build()
                )
                .build()
            sendRenderInput(input)
        } catch (_: FfiError) {
            // Stream may have been closed
        }
    }

    private fun sendZoomEvent(
        phase: ZoomEvent.Phase,
        scale: Float,
        focalX: Float,
        focalY: Float,
        requestRender: Boolean = true
    ) {
        val normalizedScale = if (scale.isFinite() && scale > 0f) {
            scale.coerceIn(ZOOM_STEP_MIN_SCALE, ZOOM_STEP_MAX_SCALE)
        } else {
            1f
        }
        try {
            val input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setZoom(
                    ZoomEvent.newBuilder()
                        .setPhase(phase)
                        .setScale(normalizedScale)
                        .setFocalXPx(focalX)
                        .setFocalYPx(focalY)
                        .build()
                )
                .build()
            sendRenderInput(input)
        } catch (_: FfiError) {
            // Stream may have been closed
        }
        if (requestRender) {
            requestRenderFrame()
        }
    }

    private fun sendRenderInput(input: RenderInput) {
        synchronized(sendLock) {
            renderStream?.send(input)
        }
    }

    private fun syncViewportSizeOnAttach(width: Int, height: Int) {
        if (gridId == 0L) return
        try {
            ffiClient?.ResizeViewport(
                ResizeViewportRequest.newBuilder()
                    .setGridId(gridId)
                    .setWidth(width)
                    .setHeight(height)
                    .build()
            )
        } catch (_: FfiError) {
            // Best-effort on attach; resizeBuffer/sync path will retry.
        }
    }

    // =========================================================================
    // Buffer Management
    // =========================================================================

    private fun allocateBuffer(width: Int, height: Int) {
        synchronized(bitmapLock) {
            bitmap?.recycle()
            bufferWidth = width
            bufferHeight = height
            val size = width * height * 4 // ARGB_8888 = 4 bytes per pixel
            pixelBuffer = ByteBuffer.allocateDirect(size)
            bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        }
    }

    private fun resolveViewportWidth(): Int {
        val measured = surfaceView.width.takeIf { it > 0 } ?: width
        return if (measured > 0) measured else 800
    }

    private fun resolveViewportHeight(): Int {
        val measured = surfaceView.height.takeIf { it > 0 } ?: height
        return if (measured > 0) measured else 600
    }

    private fun syncViewportToMeasuredSize() {
        post {
            if (gridId == 0L) return@post
            val w = resolveViewportWidth()
            val h = resolveViewportHeight()
            if (w > 0 && h > 0) {
                resizeBuffer(w, h)
            }
        }
    }

    private fun resizeBuffer(width: Int, height: Int) {
        if (width != bufferWidth || height != bufferHeight) {
            allocateBuffer(width, height)
        }

        // Notify the plugin of the viewport size (always, to mark engine dirty)
        try {
            ffiClient?.ResizeViewport(
                ResizeViewportRequest.newBuilder()
                    .setGridId(gridId)
                    .setWidth(width)
                    .setHeight(height)
                    .build()
            )
        } catch (_: FfiError) {}

        // Dispatch a new frame (GPU or CPU) with updated size
        requestRenderFrame()

        if (editingRow >= 0 && editingCol >= 0) {
            try {
                ffiClient?.ShowCell(
                    ShowCellRequest.newBuilder()
                        .setGridId(gridId)
                        .setRow(editingRow)
                        .setCol(editingCol)
                        .build()
                )
            } catch (_: FfiError) {}
        }
    }

    private fun sendBufferReady() {
        val buf = pixelBuffer ?: return

        // Atomically claim the single in-flight slot.
        // This prevents concurrent callers from sending multiple BufferReady messages.
        if (!pendingFrame.compareAndSet(false, true)) {
            needsFollowupRender.set(true)
            return
        }

        try {
            val nativePtr = PluginHost.getDirectBufferAddress(buf)
            val input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setBuffer(
                    BufferReady.newBuilder()
                        .setHandle(nativePtr)
                        .setStride(bufferWidth * 4)
                        .setWidth(bufferWidth)
                        .setHeight(bufferHeight)
                        .build()
                )
                .build()

            val sent = synchronized(sendLock) {
                val stream = renderStream
                if (stream != null) {
                    stream.send(input)
                    true
                } else {
                    false
                }
            }
            if (!sent) {
                pendingFrame.set(false)
                if (needsFollowupRender.getAndSet(false)) {
                    requestRenderFrame()
                }
            }
        } catch (_: FfiError) {
            pendingFrame.set(false)
            if (needsFollowupRender.getAndSet(false)) {
                requestRenderFrame()
            }
        }
    }

    // =========================================================================
    // GPU Surface Rendering
    // =========================================================================

    private fun acquireNativeWindow(): Long {
        if (nativeWindowPtr != 0L) return nativeWindowPtr
        val surface = surfaceView.holder.surface ?: return 0
        if (!surface.isValid) return 0
        val ptr = NativeWindowHelper.getNativeWindow(surface)
        if (ptr != 0L) {
            nativeWindowPtr = ptr
        }
        return ptr
    }

    private fun sendGpuSurfaceReady(handle: Long, w: Int, h: Int) {
        // Keep GPU mode on the same single in-flight frame model as CPU mode.
        // If the surface changes while a frame is still in flight, keep only one
        // follow-up request; the next dispatch will send the latest handle/size.
        if (!pendingFrame.compareAndSet(false, true)) {
            needsFollowupRender.set(true)
            return
        }

        try {
            val input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setGpuSurface(
                    GpuSurfaceReady.newBuilder()
                        .setSurfaceHandle(handle)
                        .setWidth(w)
                        .setHeight(h)
                        .build()
                )
                .build()

            val sent = synchronized(sendLock) {
                val stream = renderStream
                if (stream != null) {
                    stream.send(input)
                    true
                } else {
                    false
                }
            }
            if (!sent) {
                pendingFrame.set(false)
                if (needsFollowupRender.getAndSet(false)) {
                    requestRenderFrame()
                }
            }
        } catch (_: FfiError) {
            pendingFrame.set(false)
            if (needsFollowupRender.getAndSet(false)) {
                requestRenderFrame()
            }
        }
    }

    private fun sendGpuSurfaceInvalidated() {
        try {
            val input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setGpuSurface(
                    GpuSurfaceReady.newBuilder()
                        .setSurfaceHandle(0)
                        .setWidth(0)
                        .setHeight(0)
                        .build()
                )
                .build()
            sendRenderInput(input)
        } catch (_: FfiError) {
            // Best-effort
        }
    }

    // =========================================================================
    // Render Session
    // =========================================================================

    private fun startRenderSession() {
        val client = ffiClient ?: return
        pendingFrame.set(false)
        needsFollowupRender.set(false)
        renderRequestPending.set(false)
        running.set(true)
        decisionChannelEnabled = false

        thread(name = "volvoxgrid-render", isDaemon = true) {
            try {
                val stream = client.RenderSession()
                renderStream = stream
                ensureDecisionChannelEnabled()

                // Send initial frame (dispatches to GPU or CPU based on mode)
                dispatchRenderFrame()

                // Receive loop
                val responses = stream.responses()
                while (running.get() && responses.hasNext()) {
                    val output = responses.next()
                    try {
                        handleRenderOutput(output)
                    } catch (e: Exception) {
                        android.util.Log.e(TAG, "Error handling render output", e)
                        // Recover flow control so we don't hang if an error occurred after pendingFrame.set(true)
                        pendingFrame.set(false)
                    }
                }
            } catch (e: Exception) {
                if (running.get()) {
                    android.util.Log.e(TAG, "Render session error", e)
                }
            }
        }
    }

    private fun handleRenderOutput(output: RenderOutput) {
        val isBufferResponse = output.hasFrameDone()
        val isGpuResponse = output.hasGpuFrameDone()

        if (!useHostFling && (isBufferResponse || isGpuResponse) && engineMomentumFramesRemaining > 0) {
            if (output.rendered) {
                engineMomentumIdleOutputs = 0
            } else {
                engineMomentumIdleOutputs += 1
            }
        }

        when {
            output.hasFrameDone() -> {
                if (output.rendered) {
                    blitFrame(output.frameDone)
                }
                if (clearGesturePreviewOnNextFrame) {
                    clearGesturePreviewOnNextFrame = false
                    stopGesturePreview()
                }
            }
            output.hasGpuFrameDone() -> {
                // GPU rendered directly to surface — no blit needed.
                // SurfaceView composites automatically.
                if (clearGesturePreviewOnNextFrame) {
                    clearGesturePreviewOnNextFrame = false
                    stopGesturePreview()
                }
            }
            output.hasEditRequest() -> {
                if (deferOverlayWhileImeActive) {
                    pendingEditRequest = output.editRequest
                } else {
                    showEditOverlay(output.editRequest)
                }
            }
            output.hasDropdownRequest() -> handleDropdownRequest(output.dropdownRequest)
            output.hasTooltipRequest() -> {
                surfaceView.tooltipText = output.tooltipRequest.text
            }
            output.hasSelection() -> {
                // Selection update -- can be forwarded to listeners
            }
            output.hasCursor() -> {
                // Cursor change -- could change the Android cursor if needed
            }
        }

        if (isBufferResponse || isGpuResponse) {
            // Mark frame slot available only after handling this frame.
            pendingFrame.set(false)
            if (needsFollowupRender.getAndSet(false)) {
                requestRenderFrame()  // will dispatch to GPU or CPU
            }
        }
    }

    private fun blitFrame(frame: FrameDone) {
        val buf = pixelBuffer ?: return
        val bmp = bitmap ?: return

        // Always update the bitmap with the latest engine output
        synchronized(bitmapLock) {
            if (bmp.isRecycled) return
            buf.rewind()
            bmp.copyPixelsFromBuffer(buf)
        }

        // Draw if surface is ready
        drawBitmapToSurface()
    }

    private fun drawBitmapToSurface() {
        // In GPU mode, the plugin renders directly to the SurfaceView's native
        // surface. Avoid lockCanvas() here to prevent CPU canvas contention.
        if (currentRendererMode >= 2) return
        if (!surfaceReady.get()) return
        val bmp = bitmap ?: return
        val holder = surfaceView.holder
        val canvas = try { holder.lockCanvas() } catch (_: Exception) { null } ?: return
        try {
            synchronized(bitmapLock) {
                canvas.drawColor(Color.WHITE)
                if (gesturePreviewActive) {
                    canvas.save()
                    canvas.translate(
                        gesturePreviewPanX + gesturePreviewFocalX,
                        gesturePreviewPanY + gesturePreviewFocalY
                    )
                    canvas.scale(gesturePreviewScale, gesturePreviewScale)
                    canvas.translate(-gesturePreviewFocalX, -gesturePreviewFocalY)
                    canvas.drawBitmap(bmp, 0f, 0f, gesturePreviewPaint)
                    canvas.restore()
                } else {
                    canvas.drawBitmap(bmp, 0f, 0f, gesturePreviewPaint)
                }
            }
        } finally {
            holder.unlockCanvasAndPost(canvas)
        }
    }

    // =========================================================================
    // Edit Overlay
    // =========================================================================

    private fun showEditOverlay(request: EditRequest) {
        post {
            if (deferOverlayWhileImeActive) {
                pendingEditRequest = request
                return@post
            }

            val existingOverlay = editOverlay
            val refreshingSameCell = existingOverlay != null &&
                editingRow == request.row &&
                editingCol == request.col

            editingRow = request.row
            editingCol = request.col

            // Remove imeProxy so only the edit overlay captures IME input.
            // It will be re-added on the next touch via requestIdleInputFocus().
            imeProxy?.let { proxy ->
                if (proxy.parent != null) removeView(proxy)
            }
            clearImeProxy()
            dismissActiveDropdownPopup()

            val uiMode = request.uiMode
            currentEditUiMode = uiMode

            if (refreshingSameCell) {
                // A geometry refresh can happen when the IME shows or hides.
                // Keep the existing editor in place, but do not force the IME
                // back open after the user dismissed it with the back button.
                positionEditOverlay(existingOverlay!!, request)
                return@post
            }

            // Remove old overlay directly (we are already on the UI thread).
            // Do NOT call dismissEditOverlay() here — it uses post{} which
            // would defer the removal and race with the new overlay we are
            // about to create.
            editOverlay?.let { removeView(it) }
            editOverlay = null
            editOverlayComposing = false
            suppressEditorSync = false

            // Resolve the effective style for the edited cell.
            val cellStyle = resolveEditCellStyle(request.row, request.col)

            val editText = EditText(context).apply {
                inputType = InputType.TYPE_CLASS_TEXT
                setSingleLine(true)
                imeOptions = EditorInfo.IME_ACTION_DONE
                setBackgroundColor(0xFFFFFFFF.toInt())
                setPadding(cellStyle.padLeft, cellStyle.padTop, cellStyle.padRight, cellStyle.padBottom)
                setTextSize(TypedValue.COMPLEX_UNIT_PX, cellStyle.fontSize)
                includeFontPadding = false
                setLineSpacing(0f, 1f)
                gravity = android.view.Gravity.CENTER_VERTICAL
                val typefaceStyle = (if (cellStyle.bold) android.graphics.Typeface.BOLD else 0) or
                    (if (cellStyle.italic) android.graphics.Typeface.ITALIC else 0)
                val tf = if (cellStyle.fontFamily != null)
                    android.graphics.Typeface.create(cellStyle.fontFamily, typefaceStyle)
                else if (typefaceStyle != 0)
                    android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, typefaceStyle)
                else null
                if (tf != null) typeface = tf

                suppressEditorSync = true
                setText(request.currentValue)
                // Map code-point offsets to code-unit offsets for selection
                val text = request.currentValue
                val selStartCu = codeUnitOffset(text, request.selStart)
                val selEndCu = codeUnitOffset(text, request.selStart + request.selLength)
                    .coerceAtMost(text.length)
                if (selStartCu in 0..text.length && selEndCu in selStartCu..text.length) {
                    setSelection(selStartCu, selEndCu)
                } else {
                    setSelection(text.length)
                }
                suppressEditorSync = false

                setOnEditorActionListener { _, _, _ ->
                    commitEdit(request.row, request.col, getText().toString())
                    true
                }

                setOnKeyListener { _, keyCode, event ->
                    if (event.action != AndroidKeyEvent.ACTION_UP) return@setOnKeyListener false
                    when (keyCode) {
                        AndroidKeyEvent.KEYCODE_ENTER,
                        AndroidKeyEvent.KEYCODE_NUMPAD_ENTER -> {
                            commitEdit(request.row, request.col, getText().toString())
                            true
                        }
                        AndroidKeyEvent.KEYCODE_ESCAPE -> {
                            cancelEdit(request.row, request.col)
                            true
                        }
                        AndroidKeyEvent.KEYCODE_DPAD_UP,
                        AndroidKeyEvent.KEYCODE_DPAD_DOWN -> {
                            if (uiMode == EditUiMode.EDIT_UI_MODE_ENTER) {
                                commitEdit(request.row, request.col, getText().toString())
                                // Forward arrow to engine for cell navigation
                                val stream = renderStream
                                if (stream != null) {
                                    this@VolvoxGridView.onKeyDown(keyCode, event)
                                    this@VolvoxGridView.onKeyUp(keyCode, event)
                                }
                                true
                            } else {
                                false // let EditText handle caret movement
                            }
                        }
                        else -> false
                    }
                }

                // TextWatcher for composition forwarding
                addTextChangedListener(object : TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                    override fun afterTextChanged(s: Editable) {
                        if (suppressEditorSync) return
                        if (gridId == 0L) return

                        val composingStart = BaseInputConnection.getComposingSpanStart(s)
                        val composingEnd = BaseInputConnection.getComposingSpanEnd(s)
                        val isComposing = composingStart >= 0 && composingEnd > composingStart

                        if (isComposing) {
                            val preeditText = s.subSequence(composingStart, composingEnd).toString()
                            editOverlayComposing = true
                            sendPreedit(preeditText, preeditText.length, commit = false)
                        } else if (editOverlayComposing) {
                            // Composition ended — commit preedit
                            editOverlayComposing = false
                            sendPreedit(s.toString(), 0, commit = true)
                        } else {
                            // Plain text change — sync to engine
                            try {
                                ffiClient?.Edit(
                                    EditCommand.newBuilder()
                                        .setGridId(gridId)
                                        .setSetText(
                                            EditSetText.newBuilder()
                                                .setText(s.toString())
                                                .build()
                                        )
                                        .build()
                                )
                            } catch (_: FfiError) {}
                            requestRenderFrame()
                        }
                    }
                })
            }

            addView(editText, editOverlayLayoutParams(request))
            editOverlay = editText
            positionEditOverlay(editText, request)
            editText.requestFocus()
            val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.showSoftInput(editText, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    private fun editOverlayLayoutParams(request: EditRequest): LayoutParams {
        return LayoutParams(
            request.width.toInt().coerceAtLeast(60),
            request.height.toInt().coerceAtLeast(30)
        ).apply {
            leftMargin = request.x.toInt()
            topMargin = request.y.toInt()
        }
    }

    private fun positionEditOverlay(editText: EditText, request: EditRequest) {
        val lp = (editText.layoutParams as? LayoutParams) ?: editOverlayLayoutParams(request)
        lp.width = request.width.toInt().coerceAtLeast(60)
        lp.height = request.height.toInt().coerceAtLeast(30)
        lp.leftMargin = request.x.toInt()
        lp.topMargin = request.y.toInt()
        editText.layoutParams = lp
        val overlayZ = dp(8f)
        editText.elevation = overlayZ
        editText.translationZ = overlayZ
        editText.bringToFront()
    }

    private class EditCellStyle(
        val fontSize: Float = 14f,
        val fontFamily: String? = null,
        val bold: Boolean = false,
        val italic: Boolean = false,
        val padLeft: Int = 0,
        val padTop: Int = 0,
        val padRight: Int = 0,
        val padBottom: Int = 0,
    )

    /** Resolve the effective style for the cell being edited. */
    private fun resolveEditCellStyle(row: Int, col: Int): EditCellStyle {
        try {
            val client = ffiClient ?: return EditCellStyle()
            val resp = client.GetCells(
                GetCellsRequest.newBuilder()
                    .setGridId(gridId)
                    .setRow1(row).setCol1(col)
                    .setRow2(row).setCol2(col)
                    .setIncludeStyle(true)
                    .build()
            )
            val config = client.GetConfig(
                GridHandle.newBuilder().setId(gridId).build()
            )
            val cellFont = if (resp.cellsCount > 0) resp.getCells(0).style.font else null
            val gridFont = config.style.font
            val cellPad = if (resp.cellsCount > 0 && resp.getCells(0).style.hasPadding())
                resp.getCells(0).style.padding else null
            val gridPad = if (config.style.hasCellPadding()) config.style.cellPadding else null
            return EditCellStyle(
                fontSize = when {
                    cellFont != null && cellFont.hasSize() && cellFont.size > 0f -> cellFont.size
                    gridFont.hasSize() && gridFont.size > 0f -> gridFont.size
                    else -> 14f
                },
                fontFamily = when {
                    cellFont != null && cellFont.hasFamily() && cellFont.family.isNotEmpty() -> cellFont.family
                    gridFont.hasFamily() && gridFont.family.isNotEmpty() -> gridFont.family
                    else -> null
                },
                bold = if (cellFont != null && cellFont.hasBold()) cellFont.bold
                       else gridFont.hasBold() && gridFont.bold,
                italic = if (cellFont != null && cellFont.hasItalic()) cellFont.italic
                         else gridFont.hasItalic() && gridFont.italic,
                padLeft = cellPad?.left ?: gridPad?.left ?: 0,
                padTop = cellPad?.top ?: gridPad?.top ?: 0,
                padRight = cellPad?.right ?: gridPad?.right ?: 0,
                padBottom = cellPad?.bottom ?: gridPad?.bottom ?: 0,
            )
        } catch (_: Exception) {}
        return EditCellStyle()
    }

    private fun commitEdit(row: Int, col: Int, text: String) {
        try {
            ffiClient?.Edit(
                EditCommand.newBuilder()
                    .setGridId(gridId)
                    .setCommit(EditCommit.newBuilder().setText(text).build())
                    .build()
            )
        } catch (_: FfiError) {}
        editListener?.onEditCommit(row, col, text)
        dismissEditOverlay()
    }

    private fun cancelEdit(row: Int, col: Int) {
        try {
            ffiClient?.Edit(
                EditCommand.newBuilder()
                    .setGridId(gridId)
                    .setCancel(EditCancel.newBuilder().build())
                    .build()
            )
        } catch (_: FfiError) {}
        editListener?.onEditCancel(row, col)
        dismissEditOverlay()
    }

    private fun dismissEditOverlay() {
        post {
            editingRow = -1
            editingCol = -1
            dismissActiveDropdownPopup()
            editOverlay?.let {
                val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                imm?.hideSoftInputFromWindow(it.windowToken, 0)
                removeView(it)
                editOverlay = null
                editOverlayComposing = false
                suppressEditorSync = false
                clearImeProxy()
            }
        }
    }

    // =========================================================================
    // Combo Request
    // =========================================================================

    private fun dismissActiveDropdownPopup() {
    }

    private fun showEditableDropdownOverlay(request: DropdownRequest) {
        val editText = EditText(context).apply {
            if (request.selected in 0 until request.itemsCount) {
                setText(request.getItems(request.selected))
            }
            setSingleLine(true)
            imeOptions = EditorInfo.IME_ACTION_DONE
            setBackgroundColor(0xFFFFFFFF.toInt())
            setPadding(4, 2, 4, 2)

            setOnEditorActionListener { _, actionId, _ ->
                if (actionId == EditorInfo.IME_ACTION_DONE) {
                    commitEdit(request.row, request.col, text.toString())
                    true
                } else {
                    false
                }
            }
        }

        val lp = LayoutParams(
            request.width.toInt().coerceAtLeast(60),
            request.height.toInt().coerceAtLeast(30)
        )
        lp.leftMargin = request.x.toInt()
        lp.topMargin = request.y.toInt()

        addView(editText, lp)
        editOverlay = editText
        editText.requestFocus()
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.showSoftInput(editText, InputMethodManager.SHOW_IMPLICIT)
    }

    private fun showReadonlyDropdownPopup(request: DropdownRequest) {
        if (request.itemsCount <= 0) {
            cancelEdit(request.row, request.col)
            return
        }

        imeProxy?.clearFocus()
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.hideSoftInputFromWindow(windowToken, 0)
        requestRenderFrame()
    }

    private fun handleDropdownRequest(request: DropdownRequest) {
        post {
            editingRow = request.row
            editingCol = request.col
            imeProxy?.let { proxy ->
                if (proxy.parent != null) removeView(proxy)
            }
            clearImeProxy()
            dismissActiveDropdownPopup()
            editOverlay?.let {
                val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                imm?.hideSoftInputFromWindow(it.windowToken, 0)
                removeView(it)
            }
            editOverlay = null
            editOverlayComposing = false
            suppressEditorSync = false

            if (request.editable) {
                showEditableDropdownOverlay(request)
            } else {
                showReadonlyDropdownPopup(request)
            }
        }
    }

    // =========================================================================
    // Event Stream
    // =========================================================================

    private fun stopEventStream(waitForThread: Boolean) {
        val streamToClose = synchronized(eventStreamLock) {
            val stream = eventStream
            eventStream = null
            stream
        }
        streamToClose?.let {
            try { it.close() } catch (_: Exception) {}
        }

        if (!waitForThread) return

        val threadToJoin = synchronized(eventStreamLock) { eventThread }
        if (threadToJoin != null && threadToJoin !== Thread.currentThread()) {
            try {
                threadToJoin.join(1000)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
    }

    private fun startEventStream() {
        val host = plugin ?: return
        val handle = GridHandle.newBuilder().setId(gridId).build()
        val stream = host.openStream("VolvoxGridService", "/volvoxgrid.v1.VolvoxGridService/EventStream")
        try {
            stream.send(handle.toByteArray())
            stream.closeSend()
        } catch (e: Exception) {
            try { stream.close() } catch (_: Exception) {}
            throw e
        }

        val worker = thread(name = "volvoxgrid-events", isDaemon = true, start = false) {
            try {
                while (running.get()) {
                    val payload = stream.recv() ?: break
                    val event = GridEvent.parseFrom(payload)
                    handleGridEvent(event)
                }
            } catch (e: Exception) {
                if (running.get()) {
                    android.util.Log.e(TAG, "Event stream error", e)
                }
            } finally {
                try { stream.close() } catch (_: Exception) {}
                synchronized(eventStreamLock) {
                    if (eventStream === stream) {
                        eventStream = null
                    }
                    if (eventThread === Thread.currentThread()) {
                        eventThread = null
                    }
                }
            }
        }
        synchronized(eventStreamLock) {
            eventStream = stream
            eventThread = worker
        }
        worker.start()
    }

    private fun handleGridEvent(event: GridEvent) {
        // Forward edit-related events to show/dismiss the edit overlay
        when {
            event.hasBeforeEdit() -> {
                // Plugin is about to start editing -- prepare
            }
            event.hasStartEdit() -> {
                // Edit mode has started in the plugin
            }
            event.hasAfterEdit() -> {
                // Edit is complete, dismiss overlay
                dismissEditOverlay()
            }
        }

        if (decisionChannelEnabled && isCancelableGridEvent(event)) {
            val cancel = dispatchCancelableGridEvent(event)
            sendEventDecision(event.eventId, cancel)
        }

        // Forward all events to the listener
        eventListener?.onGridEvent(event)
    }

    private fun wantsCancelableGridEvents(): Boolean =
        beforeEditListener != null ||
            cellEditValidatingListener != null ||
            beforeSortListener != null

    private fun isCancelableGridEvent(event: GridEvent): Boolean =
        event.hasBeforeEdit() || event.hasCellEditValidate() || event.hasBeforeSort()

    private fun ensureDecisionChannelEnabled() {
        if (decisionChannelEnabled || !wantsCancelableGridEvents() || gridId == 0L) {
            return
        }
        val stream = synchronized(sendLock) { renderStream } ?: return
        try {
            stream.send(
                RenderInput.newBuilder()
                    .setGridId(gridId)
                    .setEventDecision(
                        EventDecision.newBuilder()
                            .setGridId(gridId)
                            .setEventId(0L)
                            .setCancel(false)
                            .build()
                    )
                    .build()
            )
            decisionChannelEnabled = true
        } catch (_: Exception) {
            // Render session may not be ready yet. The next attach/listener update will retry.
        }
    }

    private fun sendEventDecision(eventId: Long, cancel: Boolean) {
        if (!decisionChannelEnabled || gridId == 0L || eventId == 0L) {
            return
        }
        try {
            sendRenderInput(
                RenderInput.newBuilder()
                    .setGridId(gridId)
                    .setEventDecision(
                        EventDecision.newBuilder()
                            .setGridId(gridId)
                            .setEventId(eventId)
                            .setCancel(cancel)
                            .build()
                    )
                    .build()
            )
            requestRenderFrame()
        } catch (_: Exception) {
            // Best-effort; a closed stream will be reopened by the next session attach.
        }
    }

    private fun dispatchCancelableGridEvent(event: GridEvent): Boolean {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            return dispatchCancelableGridEventOnMain(event)
        }

        val latch = CountDownLatch(1)
        val cancelRef = AtomicBoolean(false)
        if (!post {
                try {
                    cancelRef.set(dispatchCancelableGridEventOnMain(event))
                } finally {
                    latch.countDown()
                }
            }) {
            return false
        }

        return try {
            latch.await(200, TimeUnit.MILLISECONDS)
            cancelRef.get()
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
    }

    private fun dispatchCancelableGridEventOnMain(event: GridEvent): Boolean {
        when {
            event.hasBeforeEdit() -> {
                val details = BeforeEditDetails(
                    rawEvent = event,
                    row = event.beforeEdit.row,
                    col = event.beforeEdit.col,
                )
                beforeEditListener?.onBeforeEdit(details)
                return details.cancel
            }
            event.hasCellEditValidate() -> {
                val details = CellEditValidatingDetails(
                    rawEvent = event,
                    row = event.cellEditValidate.row,
                    col = event.cellEditValidate.col,
                    editText = event.cellEditValidate.editText,
                )
                cellEditValidatingListener?.onCellEditValidating(details)
                return details.cancel
            }
            event.hasBeforeSort() -> {
                val details = BeforeSortDetails(
                    rawEvent = event,
                    col = event.beforeSort.col,
                )
                beforeSortListener?.onBeforeSort(details)
                return details.cancel
            }
            else -> return false
        }
    }

    override fun onWindowVisibilityChanged(visibility: Int) {
        super.onWindowVisibilityChanged(visibility)
        if (visibility == View.VISIBLE) {
            if (gridId != 0L && surfaceReady.get()) {
                requestRenderFrame()
            }
            return
        }

        if (useHostFling) {
            stopFling()
        }
        stopEngineMomentumPump()
        pendingScrollNeedsRender = false
        pendingZoomNeedsRender = false
        renderRequestPending.set(false)
        needsFollowupRender.set(false)

        if (currentRendererMode >= 2 && gridId != 0L) {
            sendGpuSurfaceInvalidated()
        }
        gpuSurfaceActive = false
        val ptr = nativeWindowPtr
        nativeWindowPtr = 0
        if (ptr != 0L) {
            NativeWindowHelper.releaseNativeWindow(ptr)
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        release()
    }

    private fun dispatchContextMenuRequest(trigger: ContextMenuTrigger, localX: Float, localY: Float) {
        val listener = contextMenuRequestListener ?: return
        val client = ffiClient ?: return
        val ctrl = VolvoxGridController(client, gridId)
        val selection = ctrl.getSelection()
        val row = if (selection.mouseRow >= 0) selection.mouseRow else selection.row
        val col = if (selection.mouseCol >= 0) selection.mouseCol else selection.col
        if (row < 0 || col < 0) return
        val location = IntArray(2)
        getLocationOnScreen(location)
        listener.onContextMenuRequest(
            ContextMenuRequest(
                trigger = trigger,
                localX = localX,
                localY = localY,
                screenX = location[0] + localX,
                screenY = location[1] + localY,
                row = row,
                col = col,
                selectionRow1 = minOf(selection.row, selection.rowEnd),
                selectionCol1 = minOf(selection.col, selection.colEnd),
                selectionRow2 = maxOf(selection.row, selection.rowEnd),
                selectionCol2 = maxOf(selection.col, selection.colEnd),
            )
        )
    }

    companion object {
        private const val TAG = "VolvoxGridView"
        private const val LARGE_GRID_GESTURE_PREVIEW_ROWS = Int.MAX_VALUE
        private const val GESTURE_PREVIEW_MIN_SCALE = 0.25f
        private const val GESTURE_PREVIEW_MAX_SCALE = 4.0f
        private const val ZOOM_STEP_NOISE_EPSILON = 0.001f
        private const val ZOOM_RAW_SCALE_MIN = 1e-12f
        private const val ZOOM_RAW_SCALE_MAX = 1e12f
        private const val ZOOM_STEP_MIN_SCALE = 1f / 32f
        private const val ZOOM_STEP_MAX_SCALE = 32f
        private val pluginLoadBannerPrinted = AtomicBoolean(false)

        /**
         * Resolve the bundled VolvoxGrid plugin path for this app process.
         *
         * Checks standard first, then lite. Throws if neither is present.
         */
        @JvmStatic
        fun resolveBundledPluginPath(context: Context): String {
            val nativeLibDir = context.applicationInfo.nativeLibraryDir
            val candidates = arrayOf(
                "libvolvoxgrid_plugin.so",
                "libvolvoxgrid_plugin_lite.so",
            )
            for (name in candidates) {
                val file = File(nativeLibDir, name)
                if (file.exists()) {
                    return file.absolutePath
                }
            }
            throw IllegalStateException(
                "VolvoxGrid plugin not found in nativeLibraryDir=$nativeLibDir " +
                    "(expected libvolvoxgrid_plugin.so or libvolvoxgrid_plugin_lite.so)"
            )
        }

        private fun logPluginLoadBannerOnce(pluginPath: String) {
            if (!pluginLoadBannerPrinted.compareAndSet(false, true)) {
                return
            }
            android.util.Log.i(
                TAG,
                "Loaded VolvoxGrid plugin " +
                    "version=${BuildConfig.VOLVOXGRID_VERSION} " +
                    "commit=${BuildConfig.VOLVOXGRID_GIT_COMMIT} " +
                    "buildDate=${BuildConfig.VOLVOXGRID_BUILD_DATE} " +
                    "path=$pluginPath"
            )
        }
    }
}
