package io.github.ivere27.volvoxgrid

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.text.InputType
import android.util.AttributeSet
import android.view.KeyEvent as AndroidKeyEvent
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.VelocityTracker
import android.view.ViewConfiguration
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.OverScroller
import io.github.ivere27.volvoxgrid.common.VolvoxGridHost
import io.github.ivere27.synurang.BidiStream
import io.github.ivere27.synurang.PluginError
import io.github.ivere27.synurang.PluginHost
import java.nio.ByteBuffer
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
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

    private val surfaceView = SurfaceView(context)
    private var editOverlay: EditText? = null

    private var plugin: PluginHost? = null
    private var ffiClient: VolvoxGridServiceFfi? = null
    private var gridId: Long = 0

    @Volatile
    private var renderStream: BidiStream<RenderInput, RenderOutput>? = null
    private var eventIterator: Iterator<GridEvent>? = null

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

    /** Listener for edit commit/cancel from the inline EditText overlay. */
    var editListener: EditCommitListener? = null

    interface GridEventListener {
        fun onGridEvent(event: GridEvent)
    }

    interface EditCommitListener {
        fun onEditCommit(row: Int, col: Int, text: String)
        fun onEditCancel(row: Int, col: Int)
    }

    init {
        addView(surfaceView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        isFocusable = true
        isFocusableInTouchMode = true
        if (useHostFling) {
            flingScroller.setFriction(flingFriction)
        }

        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                surfaceReady.set(true)
                // If a frame arrived before surface creation, the bitmap is ready. Draw it now.
                drawBitmapToSurface()
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
                if (gpuSurfaceActive) {
                    gpuSurfaceActive = false
                    sendGpuSurfaceInvalidated()
                }
                if (ptr != 0L) NativeWindowHelper.releaseNativeWindow(ptr)
            }
        })
    }

    // =========================================================================
    // Public API
    // =========================================================================

    /**
     * Initialize the grid view with a plugin path and grid dimensions.
     *
     * @param pluginPath absolute path to libvolvoxgrid_plugin.so
     * @param rows initial number of rows
     * @param cols initial number of columns
     * @param fixedRows number of fixed header rows (default 1)
     * @param fixedCols number of fixed header columns (default 0)
     */
    fun initialize(
        pluginPath: String,
        rows: Int,
        cols: Int,
        fixedRows: Int = 1,
        fixedCols: Int = 0
    ) {
        released.set(false)
        val p = PluginHost.load(pluginPath)
        plugin = p
        val client = VolvoxGridServiceFfi(p)
        ffiClient = client

        val w = resolveViewportWidth()
        val h = resolveViewportHeight()
        val density = resources.displayMetrics.density
        val scale = if (density > 0f) density else 1f

        val handle = client.Create(
            CreateRequest.newBuilder()
                .setViewportWidth(w)
                .setViewportHeight(h)
                .setScale(scale)
                .setConfig(GridConfig.newBuilder()
                    .setLayout(LayoutConfig.newBuilder()
                        .setRows(rows)
                        .setCols(cols)
                        .setFixedRows(fixedRows)
                        .setFixedCols(fixedCols)
                        .build())
                    .build())
                .build()
        )
        gridId = handle.id

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
        plugin = host
        ffiClient = VolvoxGridServiceFfi(host)
        gridId = existingGridId

        val w = resolveViewportWidth()
        val h = resolveViewportHeight()
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
        dismissEditOverlay()

        val streamToClose = synchronized(sendLock) {
            val stream = renderStream
            renderStream = null
            stream
        }
        streamToClose?.let {
            try { it.closeSend() } catch (_: Exception) {}
            try { it.close() } catch (_: Exception) {}
        }

        eventIterator = null
        
        // Don't destroy gridId or plugin
        ffiClient = null
        // gridId = 0 // Keep gridId so we know what we were attached to? 
        // No, initialize overwrites it. But if we want to query it...
        // Let's reset it to 0 to indicate "detached".
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
     * Useful after out-of-band controller mutations (e.g. setTextMatrix/refresh)
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
     * Notify the view of a renderer mode change (CPU=0, GPU=1+).
     *
     * Call this after [VolvoxGridController.setRendererMode] so the view
     * can switch between buffer-based and GPU surface rendering paths.
     */
    fun setRendererMode(mode: Int) {
        currentRendererMode = mode
        if (gridId != 0L) {
            requestRenderFrame()
        }
    }

    /**
     * Release all resources. Call this when the view is no longer needed.
     */
    override fun release() {
        if (!released.compareAndSet(false, true)) return
        running.set(false)
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

        if (gridId != 0L) {
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
                requestFocus()
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
                sendPointerEvent(stream, PointerEvent.Type.DOWN, lastTouchX, lastTouchY)
                requestRenderFrame()
                longPressRunnable?.let { removeCallbacks(it) }
                longPressRunnable = Runnable {
                    if (!isTouchScrolling && !isPinchZooming) {
                        showGridContextMenu(event.x, event.y)
                    }
                }
                postDelayed(longPressRunnable!!, longPressTimeout)
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
        } catch (_: PluginError) {}
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
        } catch (_: PluginError) {}
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
        if (currentRendererMode >= 1 && surfaceReady.get()) {
            val ptr = acquireNativeWindow()
            if (ptr != 0L) {
                gpuSurfaceActive = true
                sendGpuSurfaceReady(ptr, bufferWidth, bufferHeight)
                return
            }
        }
        // Fallback: CPU buffer path
        gpuSurfaceActive = false
        sendBufferReady()
    }

    private fun sendPointerEvent(
        stream: BidiStream<RenderInput, RenderOutput>,
        pointerType: PointerEvent.Type,
        x: Float,
        y: Float
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
                        .build()
                )
                .build()
            sendRenderInput(input)
        } catch (_: PluginError) {
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
        } catch (_: PluginError) {
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
        } catch (_: PluginError) {
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
        } catch (_: PluginError) {
            // Best-effort on attach; resizeBuffer/sync path will retry.
        }
    }

    // =========================================================================
    // Buffer Management
    // =========================================================================

    private fun allocateBuffer(width: Int, height: Int) {
        bufferWidth = width
        bufferHeight = height
        val size = width * height * 4 // ARGB_8888 = 4 bytes per pixel
        pixelBuffer = ByteBuffer.allocateDirect(size)
        bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
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
        } catch (_: PluginError) {}

        // Send new buffer info to the render session
        sendBufferReady()
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
        } catch (_: PluginError) {
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
        nativeWindowPtr = ptr
        return ptr
    }

    private fun sendGpuSurfaceReady(handle: Long, w: Int, h: Int) {
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
        } catch (_: PluginError) {
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
        } catch (_: PluginError) {
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

        thread(name = "volvoxgrid-render", isDaemon = true) {
            try {
                val stream = client.RenderSession()
                renderStream = stream

                // Send initial frame (dispatches to GPU or CPU based on mode)
                dispatchRenderFrame()

                // Receive loop
                val responses = stream.responses()
                while (running.get() && responses.hasNext()) {
                    val output = responses.next()
                    handleRenderOutput(output)
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
            output.hasEditRequest() -> showEditOverlay(output.editRequest)
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
            buf.rewind()
            bmp.copyPixelsFromBuffer(buf)
        }

        // Draw if surface is ready
        drawBitmapToSurface()
    }

    private fun drawBitmapToSurface() {
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
            dismissEditOverlay()

            val editText = EditText(context).apply {
                setText(request.currentValue)
                setSelection(request.currentValue.length)
                inputType = InputType.TYPE_CLASS_TEXT
                setSingleLine(true)
                imeOptions = EditorInfo.IME_ACTION_DONE
                setBackgroundColor(0xFFFFFFFF.toInt())
                setPadding(4, 2, 4, 2)
                textSize = 14f

                setOnEditorActionListener { _, actionId, _ ->
                    if (actionId == EditorInfo.IME_ACTION_DONE) {
                        commitEdit(request.row, request.col, text.toString())
                        true
                    } else {
                        false
                    }
                }

                setOnKeyListener { _, keyCode, event ->
                    if (keyCode == AndroidKeyEvent.KEYCODE_ESCAPE
                        && event.action == AndroidKeyEvent.ACTION_UP) {
                        cancelEdit(request.row, request.col)
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
        }
    }

    private fun commitEdit(row: Int, col: Int, text: String) {
        try {
            ffiClient?.Edit(
                EditCommand.newBuilder()
                    .setGridId(gridId)
                    .setCommit(EditCommit.newBuilder().setText(text).build())
                    .build()
            )
        } catch (_: PluginError) {}
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
        } catch (_: PluginError) {}
        editListener?.onEditCancel(row, col)
        dismissEditOverlay()
    }

    private fun dismissEditOverlay() {
        post {
            editOverlay?.let {
                removeView(it)
                editOverlay = null
            }
        }
    }

    // =========================================================================
    // Combo Request
    // =========================================================================

    private fun handleDropdownRequest(request: DropdownRequest) {
        // Combo dropdown requests could show a Spinner or PopupMenu overlay.
        // For now, we handle it as a simplified edit overlay.
        post {
            dismissEditOverlay()
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
        }
    }

    // =========================================================================
    // Event Stream
    // =========================================================================

    private fun startEventStream() {
        val client = ffiClient ?: return

        thread(name = "volvoxgrid-events", isDaemon = true) {
            try {
                val handle = GridHandle.newBuilder().setId(gridId).build()
                val iter = client.EventStream(handle)
                eventIterator = iter

                while (running.get() && iter.hasNext()) {
                    val event = iter.next()
                    handleGridEvent(event)
                }
            } catch (e: Exception) {
                if (running.get()) {
                    android.util.Log.e(TAG, "Event stream error", e)
                }
            }
        }
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

        // Forward all events to the listener
        eventListener?.onGridEvent(event)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        release()
    }

    // =========================================================================
    // Long-Press Context Menu
    // =========================================================================

    private fun showGridContextMenu(x: Float, y: Float) {
        val client = ffiClient ?: return
        val ctrl = VolvoxGridController(client, gridId)
        val row = ctrl.row
        val col = ctrl.col
        if (row < 0 || col < 0) return

        // Create an invisible anchor view at the touch position so PopupMenu
        // appears near the finger instead of at top-left.
        val anchor = android.view.View(context)
        anchor.layoutParams = FrameLayout.LayoutParams(1, 1).apply {
            leftMargin = x.toInt()
            topMargin = y.toInt()
        }
        addView(anchor)

        val popup = android.widget.PopupMenu(context, anchor)
        popup.setOnDismissListener { removeView(anchor) }
        val menu = popup.menu

        // Get grid config for fixed row/col counts
        val config = client.GetConfig(
            GridHandle.newBuilder().setId(gridId).build()
        )
        val fixedRows = config.layout.fixedRows + config.layout.frozenRows
        val fixedCols = config.layout.fixedCols + config.layout.frozenCols

        // Pin items (for data rows only)
        if (row >= fixedRows) {
            menu.add("Pin Row $row to Top").setOnMenuItemClickListener {
                ctrl.pinRow(row, PinPosition.PIN_TOP)
                requestRenderFrame(); true
            }
            menu.add("Pin Row $row to Bottom").setOnMenuItemClickListener {
                ctrl.pinRow(row, PinPosition.PIN_BOTTOM)
                requestRenderFrame(); true
            }
            menu.add("Unpin Row $row").setOnMenuItemClickListener {
                ctrl.pinRow(row, PinPosition.PIN_NONE)
                requestRenderFrame(); true
            }
        }

        // Sticky row items (for data rows only)
        if (row >= fixedRows) {
            menu.add("Sticky Row $row to Top").setOnMenuItemClickListener {
                ctrl.setRowSticky(row, StickyEdge.STICKY_TOP)
                requestRenderFrame(); true
            }
            menu.add("Sticky Row $row to Bottom").setOnMenuItemClickListener {
                ctrl.setRowSticky(row, StickyEdge.STICKY_BOTTOM)
                requestRenderFrame(); true
            }
            menu.add("Sticky Row $row Both").setOnMenuItemClickListener {
                ctrl.setRowSticky(row, StickyEdge.STICKY_BOTH)
                requestRenderFrame(); true
            }
            menu.add("Unsticky Row $row").setOnMenuItemClickListener {
                ctrl.setRowSticky(row, StickyEdge.STICKY_NONE)
                requestRenderFrame(); true
            }
        }

        // Sticky col items (for data cols only)
        if (col >= fixedCols) {
            menu.add("Sticky Col $col to Left").setOnMenuItemClickListener {
                ctrl.setColSticky(col, StickyEdge.STICKY_LEFT)
                requestRenderFrame(); true
            }
            menu.add("Sticky Col $col to Right").setOnMenuItemClickListener {
                ctrl.setColSticky(col, StickyEdge.STICKY_RIGHT)
                requestRenderFrame(); true
            }
            menu.add("Sticky Col $col Both").setOnMenuItemClickListener {
                ctrl.setColSticky(col, StickyEdge.STICKY_BOTH)
                requestRenderFrame(); true
            }
            menu.add("Unsticky Col $col").setOnMenuItemClickListener {
                ctrl.setColSticky(col, StickyEdge.STICKY_NONE)
                requestRenderFrame(); true
            }
        }

        // Copy
        menu.add("Copy").setOnMenuItemClickListener {
            val resp = ctrl.copy()
            val clipboard = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
            clipboard.setPrimaryClip(android.content.ClipData.newPlainText("grid", resp.text))
            true
        }

        if (menu.size() > 0) {
            popup.show()
        }
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
    }
}
