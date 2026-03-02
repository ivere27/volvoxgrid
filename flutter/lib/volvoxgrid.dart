/// VolvoxGrid -- a pixel-rendering datagrid widget for Flutter.
///
/// This library provides [VolvoxGridWidget], a [StatefulWidget] that renders a
/// native VolvoxGrid via a bidirectional render session.  Touch, mouse, scroll,
/// and keyboard events are forwarded to the native engine which draws into a
/// shared pixel buffer. The current Flutter widget path decodes RGBA frames
/// with `decodeImageFromPixels` and displays them via [RawImage].
///
/// ## Quick start
///
/// ```dart
/// import 'package:volvoxgrid/volvoxgrid.dart';
///
/// final controller = VolvoxGridController();
/// await controller.create(rows: 100, cols: 5);
///
/// VolvoxGridWidget(controller: controller);
/// ```
library;

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'volvoxgrid_controller.dart';
import 'src/generated/volvoxgrid.pb.dart' as pb;

export 'volvoxgrid_controller.dart';
export 'volvoxgrid_ffi.dart';

// ---------------------------------------------------------------------------
// VolvoxGridWidget
// ---------------------------------------------------------------------------

/// A widget that displays a VolvoxGrid backed by a native Rust pixel-rendering
/// engine.
///
/// Requires a [VolvoxGridController] that has already been created via
/// [VolvoxGridController.create].
class VolvoxGridWidget extends StatefulWidget {
  /// Controller that owns the native grid handle.
  final VolvoxGridController controller;

  /// Optional callback invoked whenever the active cell selection changes.
  final ValueChanged<pb.SelectionUpdate>? onSelectionChanged;

  /// Optional callback for every native [GridEvent].
  final ValueChanged<pb.GridEvent>? onGridEvent;

  /// Optional callback for custom-render cell events.
  ///
  /// Receives either legacy `DrawCell` payloads or modern `CustomRenderCell`
  /// payloads depending on the generated proto version in use.
  final ValueChanged<Object>? onCustomRenderCell;

  /// Legacy alias for draw-cell events.
  final ValueChanged<Object>? onDrawCell;

  /// Optional callback for cancelable events.
  ///
  /// If this returns true for `BeforeEdit`, `ValidateEdit`, or `BeforeSort`,
  /// the corresponding native action is canceled.
  final bool Function(pb.GridEvent event)? onCancelableEvent;

  const VolvoxGridWidget({
    required this.controller,
    this.onSelectionChanged,
    this.onGridEvent,
    this.onCustomRenderCell,
    this.onDrawCell,
    this.onCancelableEvent,
    super.key,
  });

  @override
  State<VolvoxGridWidget> createState() => _VolvoxGridWidgetState();
}

class _VolvoxGridWidgetState extends State<VolvoxGridWidget> {
  static const bool _flingOverrideEnabled = bool.fromEnvironment(
    'VG_ENABLE_FLING',
    defaultValue: false,
  );

  /// Render session streams.
  StreamController<pb.RenderInput>? _inputController;
  StreamSubscription<pb.RenderOutput>? _outputSubscription;
  StreamSubscription<pb.GridEvent>? _eventSubscription;
  bool _decisionChannelEnabled = false;

  /// The latest rendered frame as raw RGBA pixels.
  ui.Image? _currentImage;
  Uint8List? _decodeScratch;

  /// Current viewport dimensions.
  int _viewportWidth = 0;
  int _viewportHeight = 0;
  double _devicePixelRatio = 1.0;
  int _pendingViewportWidth = 0;
  int _pendingViewportHeight = 0;
  double _pendingViewportDpr = 1.0;
  bool _viewportDispatchScheduled = false;

  /// Native RGBA render buffer shared with the plugin.
  ffi.Pointer<ffi.Uint8>? _pixelBuffer;
  int _bufferWidth = 0;
  int _bufferHeight = 0;
  int _bufferStride = 0;
  int _bufferSize = 0;

  /// Stale pixel buffers waiting to be freed after in-flight renders complete.
  /// When the viewport resizes while a render is in flight, the old buffer
  /// cannot be freed immediately because the native render thread may still
  /// be writing to it.  We keep it alive here and free it once the pending
  /// frame is acknowledged.
  final List<ffi.Pointer<ffi.Uint8>> _stalePixelBuffers =
      <ffi.Pointer<ffi.Uint8>>[];

  /// Render stream backpressure state.
  bool _pendingFrame = false;
  bool _needsFollowupRender = false;
  bool _decodeInFlight = false;

  /// Fallback snapshot used when native frame decoding is unavailable.
  List<List<String>> _fallbackCells = const <List<String>>[];
  bool _fallbackLoading = false;
  Object? _fallbackError;

  /// Overlay edit field state.
  bool _editing = false;
  Rect _editRect = Rect.zero;
  String _editInitialValue = '';
  final TextEditingController _editTextController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();

  /// Focus node for keyboard events on the grid itself.
  final FocusNode _gridFocusNode = FocusNode();
  int? _lastGpuTextureId;

  /// Touch-scroll gesture tracking.
  static const double _defaultTouchScrollUnitPx = 24.0;
  static const double _touchScrollGain = 1.0;
  static const int _largeGridGesturePreviewRows = 0x7fffffff;
  static const double _zoomStepNoiseEpsilon = 0.001;
  static const double _zoomRawScaleMin = 1.0e-12;
  static const double _zoomRawScaleMax = 1.0e12;
  static const double _zoomStepMinScale = 1.0 / 32.0;
  static const double _zoomStepMaxScale = 32.0;
  int _activeTouchPointer = -1;
  Offset _touchStart = Offset.zero;
  Offset _lastTouch = Offset.zero;
  bool _isTouchScrolling = false;
  final Map<int, Offset> _touchPoints = <int, Offset>{};
  bool _isTouchPinching = false;
  bool _ignoreTouchUntilAllReleased = false;
  double _pinchLastDistance = 0.0;
  Offset _pinchLastCenter = Offset.zero;

  /// Coalesced wheel/touch scroll deltas dispatched once per frame.
  double _pendingScrollDeltaX = 0.0;
  double _pendingScrollDeltaY = 0.0;
  bool _pendingScrollNeedsRender = false;
  bool _scrollDispatchScheduled = false;
  double _pendingZoomScale = 1.0;
  Offset _pendingZoomFocal = Offset.zero;
  bool _pendingZoomActive = false;
  bool _pendingZoomNeedsRender = false;
  bool _zoomDispatchScheduled = false;
  double _panZoomLastScale = 1.0;
  int _knownRows = 0;
  Int64 _knownRowsGridId = Int64.ZERO;
  bool _knownRowsRefreshInFlight = false;
  bool _knownRowsRefreshQueued = false;
  bool _gesturePreviewActive = false;
  double _gesturePreviewScale = 1.0;
  Offset _gesturePreviewPan = Offset.zero;
  Offset _gesturePreviewFocal = Offset.zero;
  bool _clearGesturePreviewOnNextFrame = false;

  /// Current selection row/col for context menu.
  int _selRow = -1;
  int _selCol = -1;
  int _selRangesHash = -1;

  double _touchScrollUnitPx = _defaultTouchScrollUnitPx;

  /// Long-press context menu timer (for touch devices).
  Timer? _longPressTimer;
  Offset _longPressPosition = Offset.zero;
  static const Duration _longPressDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _syncEventStreamSubscription();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _closeRenderSession(controller: widget.controller);
    _closeEventStream();
    _freeRenderBuffer();
    widget.controller.removeListener(_onControllerChanged);
    _editTextController.dispose();
    _editFocusNode.dispose();
    _gridFocusNode.dispose();
    _safeDisposeImage(_currentImage);
    super.dispose();
  }

  void _safeDisposeImage(ui.Image? image) {
    if (image == null) {
      return;
    }
    try {
      image.dispose();
    } catch (_) {
      // The engine may already have reclaimed the native peer during shutdown.
    }
  }

  @override
  void didUpdateWidget(covariant VolvoxGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _closeRenderSession(controller: oldWidget.controller);
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _closeEventStream();
      _lastGpuTextureId = null;
      _knownRowsGridId = Int64.ZERO;
      _knownRows = 0;
      _gesturePreviewActive = false;
      _gesturePreviewScale = 1.0;
      _gesturePreviewPan = Offset.zero;
      _gesturePreviewFocal = Offset.zero;
      _clearGesturePreviewOnNextFrame = false;
      _syncEventStreamSubscription();
      if (widget.controller.isCreated &&
          _viewportWidth > 0 &&
          _viewportHeight > 0) {
        _ensureRenderSession();
        _requestRender();
      }
    }
    if (oldWidget.onGridEvent != widget.onGridEvent ||
        oldWidget.onCustomRenderCell != widget.onCustomRenderCell ||
        oldWidget.onDrawCell != widget.onDrawCell ||
        oldWidget.onCancelableEvent != widget.onCancelableEvent) {
      _syncEventStreamSubscription();
    }
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    final gpuTextureId = widget.controller.gpuTextureId;
    if (gpuTextureId != _lastGpuTextureId) {
      _lastGpuTextureId = gpuTextureId;
      // Backend/texture transitions can invalidate a pending frame signal.
      // Reset gating so the new surface receives a fresh render request.
      _pendingFrame = false;
      _needsFollowupRender = false;
      if (gpuTextureId != null && _viewportWidth > 0 && _viewportHeight > 0) {
        unawaited(
          widget.controller
              .setGpuTextureSize(_viewportWidth, _viewportHeight)
              .then((_) {
            if (!mounted) {
              return;
            }
            _requestRender();
          }),
        );
      }
    }
    _syncEventStreamSubscription();
    if (widget.controller.isCreated) {
      _syncTouchScrollUnitBestEffort();
      _scheduleKnownRowsRefresh(force: true);
      _requestRender();
    }
    setState(() {});
  }

  // ── Render session management ─────────────────────────────────────────────

  void _ensureRenderSession() {
    if (_inputController != null) return;
    if (!widget.controller.isCreated) return;
    unawaited(
      _setFlingEnabledBestEffort(
          widget.controller, _isMobilePlatform || _flingOverrideEnabled),
    );
    if (_isMobilePlatform) {
      unawaited(_setFastScrollEnabledBestEffort(widget.controller, true));
    }
    _inputController = StreamController<pb.RenderInput>();
    final outputStream = widget.controller.renderSession(
      _inputController!.stream,
    );
    _outputSubscription = outputStream.listen(
      _handleRenderOutput,
      onError: (Object e) {
        debugPrint('VolvoxGrid render session error: $e');
      },
      onDone: () {
        _inputController = null;
        _outputSubscription = null;
      },
    );

    // Send initial viewport state.
    _resizeRenderBuffer(_viewportWidth, _viewportHeight);
    _sendViewport();
    _sendBufferReady();
    _scheduleKnownRowsRefresh();

    if (_currentImage == null && _fallbackCells.isEmpty) {
      // ignore: discarded_futures
      _refreshFallbackSnapshot();
    }
  }

  void _closeRenderSession({VolvoxGridController? controller}) {
    if (controller != null) {
      unawaited(_setFlingEnabledBestEffort(controller, false));
    }
    _outputSubscription?.cancel();
    _outputSubscription = null;
    _inputController?.close();
    _inputController = null;
    _pendingFrame = false;
    _needsFollowupRender = false;
    _decodeInFlight = false;
    _activeTouchPointer = -1;
    _isTouchScrolling = false;
    _touchPoints.clear();
    _isTouchPinching = false;
    _ignoreTouchUntilAllReleased = false;
    _pinchLastDistance = 0.0;
    _pinchLastCenter = Offset.zero;
    _pendingScrollDeltaX = 0.0;
    _pendingScrollDeltaY = 0.0;
    _pendingScrollNeedsRender = false;
    _scrollDispatchScheduled = false;
    _pendingZoomScale = 1.0;
    _pendingZoomFocal = Offset.zero;
    _pendingZoomActive = false;
    _pendingZoomNeedsRender = false;
    _zoomDispatchScheduled = false;
    _gesturePreviewActive = false;
    _gesturePreviewScale = 1.0;
    _gesturePreviewPan = Offset.zero;
    _gesturePreviewFocal = Offset.zero;
    _clearGesturePreviewOnNextFrame = false;
    _pendingViewportWidth = 0;
    _pendingViewportHeight = 0;
    _pendingViewportDpr = 1.0;
    _viewportDispatchScheduled = false;
    _decisionChannelEnabled = false;
  }

  Future<void> _setFlingEnabledBestEffort(
    VolvoxGridController controller,
    bool enabled,
  ) async {
    if (!controller.isCreated) {
      return;
    }
    try {
      await controller.setFlingEnabled(enabled);
    } catch (_) {
      // Best-effort lifecycle hint.
    }
  }

  Future<void> _setFastScrollEnabledBestEffort(
    VolvoxGridController controller,
    bool enabled,
  ) async {
    if (!controller.isCreated) {
      return;
    }
    try {
      await controller.setFastScrollEnabled(enabled);
    } catch (_) {
      // Best-effort lifecycle hint.
    }
  }

  bool get _wantsGridEvents =>
      widget.onGridEvent != null ||
      widget.onCustomRenderCell != null ||
      widget.onDrawCell != null ||
      widget.onCancelableEvent != null;

  void _syncEventStreamSubscription() {
    if (!_wantsGridEvents || !widget.controller.isCreated) {
      _closeEventStream();
      return;
    }
    _ensureEventStream();
    if (widget.onCancelableEvent != null) {
      _enableDecisionChannel();
    }
  }

  void _ensureEventStream() {
    if (_eventSubscription != null) {
      return;
    }
    _eventSubscription = widget.controller.eventStream().listen(
      _handleGridEvent,
      onError: (Object e) {
        debugPrint('VolvoxGrid event stream error: $e');
      },
      onDone: () {
        _eventSubscription = null;
        _decisionChannelEnabled = false;
      },
    );
  }

  void _closeEventStream() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _decisionChannelEnabled = false;
  }

  bool _isCancelableGridEvent(pb.GridEvent event) {
    final dynamic dyn = event;
    var hasValidate = false;
    try {
      hasValidate = dyn.hasCellEditValidate() == true;
    } catch (_) {
      // Older generated bindings expose hasValidateEdit().
    }
    if (!hasValidate) {
      try {
        hasValidate = dyn.hasValidateEdit() == true;
      } catch (_) {
        // Newer generated bindings may only expose hasCellEditValidate().
      }
    }
    return event.hasBeforeEdit() || hasValidate || event.hasBeforeSort();
  }

  void _dispatchCustomRenderCell(pb.GridEvent event) {
    if (widget.onCustomRenderCell == null && widget.onDrawCell == null) {
      return;
    }
    final dynamic dyn = event;
    Object? payload;
    try {
      if (dyn.hasCustomRenderCell() == true) {
        payload = dyn.customRenderCell as Object?;
      }
    } catch (_) {
      // Older generated bindings expose drawCell.
    }
    if (payload == null) {
      try {
        if (dyn.hasDrawCell() == true) {
          payload = dyn.drawCell as Object?;
        }
      } catch (_) {
        // Newer generated bindings may only expose customRenderCell.
      }
    }
    if (payload == null) {
      return;
    }
    widget.onCustomRenderCell?.call(payload);
    widget.onDrawCell?.call(payload);
  }

  void _enableDecisionChannel() {
    if (_decisionChannelEnabled || !widget.controller.isCreated) {
      return;
    }
    if (_inputController == null) {
      _ensureRenderSession();
    }
    if (_inputController == null) {
      return;
    }
    _sendInput(
      pb.RenderInput()
        ..eventDecision = (pb.EventDecision()
          ..gridId = widget.controller.gridId
          ..eventId = Int64.ZERO
          ..cancel = false),
    );
    _decisionChannelEnabled = true;
  }

  void _handleGridEvent(pb.GridEvent event) {
    widget.onGridEvent?.call(event);
    _dispatchCustomRenderCell(event);

    final onCancelableEvent = widget.onCancelableEvent;
    if (onCancelableEvent == null || !_isCancelableGridEvent(event)) {
      return;
    }

    _enableDecisionChannel();
    if (_inputController == null) {
      return;
    }

    final cancel = onCancelableEvent(event);
    _sendInput(
      pb.RenderInput()
        ..eventDecision = (pb.EventDecision()
          ..gridId = widget.controller.gridId
          ..eventId = event.eventId
          ..cancel = cancel),
    );
    _requestRender();
  }

  void _sendInput(pb.RenderInput input, {bool tracksBufferReady = false}) {
    input.gridId = widget.controller.gridId;
    if (tracksBufferReady) {
      _pendingFrame = true;
    }
    _inputController?.add(input);
  }

  void _sendViewport() {
    if (_viewportWidth <= 0 || _viewportHeight <= 0) return;
    _sendInput(
      pb.RenderInput()
        ..viewport = (pb.ViewportState()
          ..width = _viewportWidth
          ..height = _viewportHeight
          ..scrollX = 0
          ..scrollY = 0),
    );
  }

  void _queueViewportResize(int width, int height, double dpr) {
    if (width <= 0 || height <= 0 || !dpr.isFinite || dpr <= 0) {
      return;
    }
    _pendingViewportWidth = width;
    _pendingViewportHeight = height;
    _pendingViewportDpr = dpr;
    if (_viewportDispatchScheduled) {
      return;
    }
    _viewportDispatchScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _viewportDispatchScheduled = false;
      _flushQueuedViewportResize();
    });
  }

  void _flushQueuedViewportResize() {
    if (!mounted) {
      _pendingViewportWidth = 0;
      _pendingViewportHeight = 0;
      return;
    }
    final width = _pendingViewportWidth;
    final height = _pendingViewportHeight;
    final dpr = _pendingViewportDpr;
    _pendingViewportWidth = 0;
    _pendingViewportHeight = 0;

    if (!widget.controller.isCreated || width <= 0 || height <= 0) {
      return;
    }
    if (width == _viewportWidth &&
        height == _viewportHeight &&
        (_devicePixelRatio - dpr).abs() <= 0.0001) {
      return;
    }

    _devicePixelRatio = dpr;
    _viewportWidth = width;
    _viewportHeight = height;
    _ensureRenderSession();
    if (widget.controller.gpuTextureId != null) {
      unawaited(widget.controller.setGpuTextureSize(width, height));
    }
    _resizeRenderBuffer(width, height);
    _sendViewport();
    _sendBufferReady();
  }

  void _resizeRenderBuffer(int width, int height) {
    if (width <= 0 || height <= 0) {
      return;
    }
    if (widget.controller.gpuTextureId != null) {
      _bufferWidth = width;
      _bufferHeight = height;
      if (!_pendingFrame) {
        _releaseCpuRenderBuffersForGpuMode();
      }
      return;
    }
    if (_pixelBuffer != null &&
        _bufferWidth == width &&
        _bufferHeight == height) {
      return;
    }

    // If a render is in flight, the native thread may still be writing to the
    // current buffer.  Move it to _stalePixelBuffers instead of freeing it
    // immediately; it will be freed when the pending frame completes.
    final oldBuffer = _pixelBuffer;
    if (oldBuffer != null) {
      if (_pendingFrame) {
        _stalePixelBuffers.add(oldBuffer);
      } else {
        malloc.free(oldBuffer);
      }
      _pixelBuffer = null;
    }
    _decodeScratch = null;

    _bufferWidth = width;
    _bufferHeight = height;
    _bufferStride = width * 4;
    _bufferSize = _bufferStride * height;
    _pixelBuffer = malloc<ffi.Uint8>(_bufferSize);
  }

  void _releaseCpuRenderBuffersForGpuMode() {
    final buffer = _pixelBuffer;
    if (buffer != null) {
      malloc.free(buffer);
      _pixelBuffer = null;
    }
    for (final stale in _stalePixelBuffers) {
      malloc.free(stale);
    }
    _stalePixelBuffers.clear();
    _decodeScratch = null;
    _bufferStride = 0;
    _bufferSize = 0;
  }

  void _freeRenderBuffer() {
    final buffer = _pixelBuffer;
    if (buffer != null) {
      malloc.free(buffer);
      _pixelBuffer = null;
    }
    for (final stale in _stalePixelBuffers) {
      malloc.free(stale);
    }
    _stalePixelBuffers.clear();
    _decodeScratch = null;
    _bufferWidth = 0;
    _bufferHeight = 0;
    _bufferStride = 0;
    _bufferSize = 0;
  }

  void _sendBufferReady() {
    final textureId = widget.controller.gpuTextureId;
    final surfaceHandle = widget.controller.gpuSurfaceHandle;

    if (textureId != null && surfaceHandle != null) {
      if (_pendingFrame) {
        _needsFollowupRender = true;
        return;
      }
      _releaseCpuRenderBuffersForGpuMode();
      _pendingFrame = true;
      _sendInput(
        pb.RenderInput()
          ..gpuSurface = (pb.GpuSurfaceReady()
            ..surfaceHandle = Int64(surfaceHandle)
            ..width = _bufferWidth
            ..height = _bufferHeight),
        tracksBufferReady: true,
      );
      return;
    }

    final buffer = _pixelBuffer;
    if (buffer == null || _inputController == null) {
      return;
    }
    if (_pendingFrame) {
      _needsFollowupRender = true;
      return;
    }

    _sendInput(
      pb.RenderInput()
        ..buffer = (pb.BufferReady()
          ..handle = Int64(buffer.address)
          ..stride = _bufferStride
          ..width = _bufferWidth
          ..height = _bufferHeight),
      tracksBufferReady: true,
    );
  }

  void _requestRender() {
    if (!widget.controller.isCreated ||
        _viewportWidth <= 0 ||
        _viewportHeight <= 0) {
      return;
    }
    if (_inputController == null) {
      _ensureRenderSession();
      return;
    }
    _resizeRenderBuffer(_viewportWidth, _viewportHeight);
    _sendBufferReady();
  }

  void _queueScrollDelta(
    double deltaX,
    double deltaY, {
    bool immediate = false,
  }) {
    _queueScrollDeltaInternal(
      deltaX,
      deltaY,
      requestRender: true,
      immediate: immediate,
    );
  }

  void _queueScrollDeltaInternal(
    double deltaX,
    double deltaY, {
    required bool requestRender,
    bool immediate = false,
  }) {
    _pendingScrollDeltaX += deltaX;
    _pendingScrollDeltaY += deltaY;
    _pendingScrollNeedsRender = _pendingScrollNeedsRender || requestRender;
    if (immediate) {
      _flushQueuedScroll();
      return;
    }
    if (_scrollDispatchScheduled) {
      return;
    }
    _scrollDispatchScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _scrollDispatchScheduled = false;
      _flushQueuedScroll();
    });
  }

  void _flushQueuedScroll() {
    final deltaX = _pendingScrollDeltaX;
    final deltaY = _pendingScrollDeltaY;
    if (deltaX == 0.0 && deltaY == 0.0) {
      _pendingScrollNeedsRender = false;
      return;
    }
    _pendingScrollDeltaX = 0.0;
    _pendingScrollDeltaY = 0.0;
    final shouldRender = _pendingScrollNeedsRender;
    _pendingScrollNeedsRender = false;

    _sendInput(
      pb.RenderInput()
        ..scroll = (pb.ScrollEvent()
          ..deltaX = deltaX
          ..deltaY = deltaY),
    );
    if (shouldRender) {
      _requestRender();
    }
  }

  void _queueZoomDelta({
    required double scaleDelta,
    required Offset focal,
    required bool requestRender,
  }) {
    if (!scaleDelta.isFinite || scaleDelta <= 0) {
      return;
    }
    final normalizedDelta =
        scaleDelta.clamp(_zoomStepMinScale, _zoomStepMaxScale);
    _pendingZoomScale = (_pendingZoomScale * normalizedDelta)
        .clamp(_zoomRawScaleMin, _zoomRawScaleMax);
    _pendingZoomFocal = focal;
    _pendingZoomNeedsRender = _pendingZoomNeedsRender || requestRender;
    _pendingZoomActive = true;
    if (_zoomDispatchScheduled) {
      return;
    }
    _zoomDispatchScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _zoomDispatchScheduled = false;
      _flushQueuedZoom();
    });
  }

  void _flushQueuedZoom() {
    if (!_pendingZoomActive) {
      _pendingZoomNeedsRender = false;
      return;
    }

    final scale = _pendingZoomScale;
    final focal = _pendingZoomFocal;
    final shouldRender = _pendingZoomNeedsRender;
    _pendingZoomScale = 1.0;
    _pendingZoomFocal = Offset.zero;
    _pendingZoomActive = false;
    _pendingZoomNeedsRender = false;

    if ((scale - 1.0).abs() <= _zoomStepNoiseEpsilon) {
      if (shouldRender) {
        _requestRender();
      }
      return;
    }

    final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
    var remaining = scale;
    while (remaining > _zoomStepMaxScale) {
      _sendZoomEvent(
        pb.ZoomEvent_Phase.ZOOM_UPDATE,
        scale: _zoomStepMaxScale,
        focalXPx: focal.dx * dpr,
        focalYPx: focal.dy * dpr,
        requestRender: false,
      );
      remaining /= _zoomStepMaxScale;
    }
    while (remaining < _zoomStepMinScale) {
      _sendZoomEvent(
        pb.ZoomEvent_Phase.ZOOM_UPDATE,
        scale: _zoomStepMinScale,
        focalXPx: focal.dx * dpr,
        focalYPx: focal.dy * dpr,
        requestRender: false,
      );
      remaining /= _zoomStepMinScale;
    }
    if ((remaining - 1.0).abs() <= _zoomStepNoiseEpsilon) {
      if (shouldRender) {
        _requestRender();
      }
      return;
    }
    _sendZoomEvent(
      pb.ZoomEvent_Phase.ZOOM_UPDATE,
      scale: remaining,
      focalXPx: focal.dx * dpr,
      focalYPx: focal.dy * dpr,
      requestRender: shouldRender,
    );
  }

  void _clearQueuedZoom() {
    _pendingZoomScale = 1.0;
    _pendingZoomFocal = Offset.zero;
    _pendingZoomActive = false;
    _pendingZoomNeedsRender = false;
  }

  // ── Render output handling ────────────────────────────────────────────────

  void _handleRenderOutput(pb.RenderOutput output) {
    if (output.hasFrameDone() || output.hasGpuFrameDone()) {
      _pendingFrame = false;
      // Free stale pixel buffers now that the in-flight render has completed
      // and the native thread is no longer writing to them.
      if (_stalePixelBuffers.isNotEmpty) {
        for (final stale in _stalePixelBuffers) {
          malloc.free(stale);
        }
        _stalePixelBuffers.clear();
      }
      if (_needsFollowupRender) {
        _needsFollowupRender = false;
        _sendBufferReady();
      }
    }

    if (output.rendered &&
        output.hasFrameDone() &&
        output.frameDone.dirtyW > 0) {
      _decodeFrame(output.frameDone);
    } else if (output.rendered &&
        (output.hasFrameDone() || output.hasGpuFrameDone()) &&
        _clearGesturePreviewOnNextFrame) {
      _clearGesturePreviewOnNextFrame = false;
      _stopGesturePreview();
    }
    if (output.hasSelection()) {
      final selection = output.selection;
      final ranges = selection.ranges;
      final rangeCount = ranges.length;
      // Hash all ranges to detect changes in any range, not just the first.
      var rangesHash = rangeCount;
      for (final r in ranges) {
        rangesHash = rangesHash * 31 + r.row1;
        rangesHash = rangesHash * 31 + r.col1;
        rangesHash = rangesHash * 31 + r.row2;
        rangesHash = rangesHash * 31 + r.col2;
      }
      final changed = _selRow != selection.activeRow ||
          _selCol != selection.activeCol ||
          _selRangesHash != rangesHash;

      _selRow = selection.activeRow;
      _selCol = selection.activeCol;
      _selRangesHash = rangesHash;

      if (changed) {
        widget.onSelectionChanged?.call(selection);
      }
    }
    if (output.hasEditRequest() && output.editRequest.width > 0) {
      _showEditOverlay(output.editRequest);
    }
    if (output.rendered) {
      _sendBufferReady();
    }
  }

  void _decodeFrame(pb.FrameDone frame) {
    if (_decodeInFlight) {
      _needsFollowupRender = true;
      return;
    }

    final int w = _bufferWidth;
    final int h = _bufferHeight;
    if (w <= 0 || h <= 0 || _bufferSize <= 0) {
      return;
    }

    final int bufferAddr = frame.handle.toInt();
    if (bufferAddr == 0) {
      return;
    }

    // Skip frames rendered to a stale buffer (viewport was resized while the
    // render was in flight).  The buffer dimensions no longer match _bufferSize
    // and reading from it would access invalid memory.
    if (_pixelBuffer == null || bufferAddr != _pixelBuffer!.address) {
      return;
    }

    final buffer = ffi.Pointer<ffi.Uint8>.fromAddress(bufferAddr);
    final source = buffer.asTypedList(_bufferSize);
    final snapshot =
        (_decodeScratch != null && _decodeScratch!.lengthInBytes == _bufferSize)
            ? _decodeScratch!
            : (_decodeScratch = Uint8List(_bufferSize));
    snapshot.setAll(0, source);
    _decodeInFlight = true;
    ui.decodeImageFromPixels(snapshot, w, h, ui.PixelFormat.rgba8888, (
      ui.Image image,
    ) {
      final oldImage = _currentImage;
      if (!mounted) {
        _safeDisposeImage(oldImage);
        _safeDisposeImage(image);
        _decodeInFlight = false;
        return;
      }
      setState(() {
        _currentImage = image;
        _fallbackCells = const <List<String>>[];
        _fallbackError = null;
        if (_clearGesturePreviewOnNextFrame) {
          _clearGesturePreviewOnNextFrame = false;
          _gesturePreviewActive = false;
          _gesturePreviewScale = 1.0;
          _gesturePreviewPan = Offset.zero;
          _gesturePreviewFocal = Offset.zero;
        }
      });
      _safeDisposeImage(oldImage);
      _decodeInFlight = false;
    }, rowBytes: _bufferStride);
  }

  Future<void> _refreshFallbackSnapshot() async {
    if (!mounted ||
        _fallbackLoading ||
        !widget.controller.isCreated ||
        _currentImage != null) {
      return;
    }
    _fallbackLoading = true;

    try {
      final rows = await widget.controller.getRows();
      final cols = await widget.controller.getCols();
      final maxRows = math.max(0, math.min(rows, 200));
      final maxCols = math.max(0, math.min(cols, 16));
      final snapshot = <List<String>>[];

      for (var r = 0; r < maxRows; r++) {
        final rowValues = await Future.wait(
          List.generate(maxCols, (c) => widget.controller.getTextMatrix(r, c)),
        );
        snapshot.add(rowValues);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _fallbackCells = snapshot;
        _fallbackError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fallbackError = error;
      });
    } finally {
      _fallbackLoading = false;
    }
  }

  Widget _buildSurface(BoxConstraints constraints) {
    final textureId = widget.controller.gpuTextureId;
    if (textureId != null) {
      return Texture(textureId: textureId);
    }

    if (_currentImage != null) {
      return RawImage(
        image: _currentImage,
        fit: BoxFit.none,
        scale: _devicePixelRatio,
        filterQuality: FilterQuality.none,
      );
    }

    return Stack(
      children: [
        CustomPaint(
          painter: _GridPlaceholderPainter(),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        ),
        if (_fallbackLoading)
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        if (_fallbackError != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Text(
              'Fallback snapshot failed: $_fallbackError',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ── Edit overlay ──────────────────────────────────────────────────────────

  void _showEditOverlay(pb.EditRequest req) {
    final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
    setState(() {
      _editing = true;
      _editRect = Rect.fromLTWH(
        req.x.toDouble() / dpr,
        req.y.toDouble() / dpr,
        req.width.toDouble() / dpr,
        req.height.toDouble() / dpr,
      );
      _editInitialValue = req.currentValue;
      _editTextController.text = _editInitialValue;
      _editTextController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editInitialValue.length,
      );
    });
    // Focus the edit field on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode.requestFocus();
    });
  }

  void _commitEdit() {
    final text = _editTextController.text;
    widget.controller.commitEdit(text);
    setState(() => _editing = false);
    _gridFocusNode.requestFocus();
    _requestRender();
  }

  void _cancelEdit() {
    widget.controller.cancelEdit();
    setState(() => _editing = false);
    _gridFocusNode.requestFocus();
    _requestRender();
  }

  // ── Event forwarding ─────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    _gridFocusNode.requestFocus();
    if (event.kind == PointerDeviceKind.touch) {
      _syncTouchScrollUnitBestEffort();
    }

    // Right-click detection (mouse button 2) -- show context menu.
    if (event.kind != PointerDeviceKind.touch && (event.buttons & 0x02) != 0) {
      // Send the pointer event to the engine so it updates selection.
      final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
      _sendInput(
        pb.RenderInput()
          ..pointer = (pb.PointerEvent()
            ..type = pb.PointerEvent_Type.DOWN
            ..x = event.localPosition.dx * dpr
            ..y = event.localPosition.dy * dpr
            ..button = event.buttons
            ..modifier = _modifiers()),
      );
      _requestRender();
      // Show context menu after a short delay to let engine process selection.
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _showGridContextMenu(context, event.position);
        }
      });
      return;
    }

    if (event.kind == PointerDeviceKind.touch) {
      _touchPoints[event.pointer] = event.localPosition;
      if (_ignoreTouchUntilAllReleased) {
        return;
      }
      if (_isTouchPinching) {
        return;
      }
      if (_touchPoints.length >= 2) {
        _beginTouchPinch();
        return;
      }
      _activeTouchPointer = event.pointer;
      _touchStart = event.localPosition;
      _lastTouch = event.localPosition;
      _isTouchScrolling = false;
      _pendingScrollDeltaX = 0.0;
      _pendingScrollDeltaY = 0.0;

      // Start long-press timer for touch context menu.
      _longPressTimer?.cancel();
      _longPressPosition = event.position;
      _longPressTimer = Timer(_longPressDuration, () {
        if (mounted && !_isTouchScrolling && !_isTouchPinching) {
          _showGridContextMenu(context, _longPressPosition);
        }
      });
    }
    final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
    _sendInput(
      pb.RenderInput()
        ..pointer = (pb.PointerEvent()
          ..type = pb.PointerEvent_Type.DOWN
          ..x = event.localPosition.dx * dpr
          ..y = event.localPosition.dy * dpr
          ..button = event.kind == PointerDeviceKind.touch ? 0 : event.buttons
          ..modifier = _modifiers()),
    );
    _requestRender();
  }

  void _onPointerUp(PointerUpEvent event) {
    _longPressTimer?.cancel();
    if (event.kind == PointerDeviceKind.touch) {
      _touchPoints.remove(event.pointer);
      if (_isTouchPinching) {
        if (_touchPoints.length < 2) {
          _endTouchPinch();
        }
        if (_touchPoints.isEmpty) {
          _ignoreTouchUntilAllReleased = false;
        }
        return;
      }
      if (_ignoreTouchUntilAllReleased) {
        if (_touchPoints.isEmpty) {
          _ignoreTouchUntilAllReleased = false;
        }
        return;
      }
      if (event.pointer == _activeTouchPointer) {
        _flushQueuedScroll();
        _activeTouchPointer = -1;
        _isTouchScrolling = false;
      }
    }
    final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
    _sendInput(
      pb.RenderInput()
        ..pointer = (pb.PointerEvent()
          ..type = pb.PointerEvent_Type.UP
          ..x = event.localPosition.dx * dpr
          ..y = event.localPosition.dy * dpr
          ..button = event.buttons
          ..modifier = _modifiers()),
    );
    _requestRender();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      _touchPoints[event.pointer] = event.localPosition;
      if (_isTouchPinching) {
        _updateTouchPinch();
        return;
      }
      if (_ignoreTouchUntilAllReleased) {
        return;
      }
      if (event.pointer != _activeTouchPointer) {
        return;
      }
      final dx = event.localPosition.dx - _lastTouch.dx;
      final dy = event.localPosition.dy - _lastTouch.dy;
      final totalDx = event.localPosition.dx - _touchStart.dx;
      final totalDy = event.localPosition.dy - _touchStart.dy;

      if (!_isTouchScrolling &&
          (totalDx.abs() > kTouchSlop || totalDy.abs() > kTouchSlop)) {
        _isTouchScrolling = true;
        _longPressTimer?.cancel();
      }

      if (_isTouchScrolling) {
        final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
        _sendInput(
          pb.RenderInput()
            ..pointer = (pb.PointerEvent()
              ..type = pb.PointerEvent_Type.MOVE
              ..x = event.localPosition.dx * dpr
              ..y = event.localPosition.dy * dpr
              ..button = 0
              ..modifier = _modifiers()),
        );
        _queueScrollDelta(
          (-dx / _touchScrollUnitPx) * _touchScrollGain,
          (-dy / _touchScrollUnitPx) * _touchScrollGain,
          immediate: true,
        );
      } else {
        final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
        _sendInput(
          pb.RenderInput()
            ..pointer = (pb.PointerEvent()
              ..type = pb.PointerEvent_Type.MOVE
              ..x = event.localPosition.dx * dpr
              ..y = event.localPosition.dy * dpr
              ..button = 0
              ..modifier = _modifiers()),
        );
        _requestRender();
      }

      _lastTouch = event.localPosition;
      return;
    }

    final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
    _sendInput(
      pb.RenderInput()
        ..pointer = (pb.PointerEvent()
          ..type = pb.PointerEvent_Type.MOVE
          ..x = event.localPosition.dx * dpr
          ..y = event.localPosition.dy * dpr
          ..button = event.buttons
          ..modifier = _modifiers()),
    );
    _requestRender();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _longPressTimer?.cancel();
    if (event.kind == PointerDeviceKind.touch) {
      _touchPoints.remove(event.pointer);
      if (_isTouchPinching) {
        if (_touchPoints.length < 2) {
          _endTouchPinch();
        }
        if (_touchPoints.isEmpty) {
          _ignoreTouchUntilAllReleased = false;
        }
        return;
      }
      if (_ignoreTouchUntilAllReleased) {
        if (_touchPoints.isEmpty) {
          _ignoreTouchUntilAllReleased = false;
        }
        return;
      }
      if (event.pointer == _activeTouchPointer) {
        _flushQueuedScroll();
        _activeTouchPointer = -1;
        _isTouchScrolling = false;
      }
    }
    final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
    _sendInput(
      pb.RenderInput()
        ..pointer = (pb.PointerEvent()
          ..type = pb.PointerEvent_Type.UP
          ..x = event.localPosition.dx * dpr
          ..y = event.localPosition.dy * dpr
          ..button = 0
          ..modifier = _modifiers()),
    );
    _requestRender();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _queueScrollDelta(
        (event.scrollDelta.dx / _touchScrollUnitPx) * _touchScrollGain,
        (event.scrollDelta.dy / _touchScrollUnitPx) * _touchScrollGain,
      );
    }
  }

  void _sendZoomEvent(
    pb.ZoomEvent_Phase phase, {
    double scale = 1.0,
    double focalXPx = 0.0,
    double focalYPx = 0.0,
    bool requestRender = true,
  }) {
    _sendInput(
      pb.RenderInput()
        ..zoom = (pb.ZoomEvent()
          ..phase = phase
          ..scale = scale
          ..focalXPx = focalXPx
          ..focalYPx = focalYPx),
    );
    if (requestRender) {
      _requestRender();
    }
  }

  _TouchPinchMetrics? _touchPinchMetrics() {
    if (_touchPoints.length < 2) {
      return null;
    }
    final points = _touchPoints.values.take(2).toList(growable: false);
    if (points.length < 2) {
      return null;
    }
    final p1 = points[0];
    final p2 = points[1];
    final center = Offset((p1.dx + p2.dx) * 0.5, (p1.dy + p2.dy) * 0.5);
    final distance = (p2 - p1).distance;
    return _TouchPinchMetrics(center: center, distance: distance);
  }

  void _beginTouchPinch() {
    final metrics = _touchPinchMetrics();
    if (metrics == null) {
      return;
    }
    final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
    if (_activeTouchPointer != -1) {
      _sendInput(
        pb.RenderInput()
          ..pointer = (pb.PointerEvent()
            ..type = pb.PointerEvent_Type.UP
            ..x = _lastTouch.dx * dpr
            ..y = _lastTouch.dy * dpr
            ..button = 0
            ..modifier = _modifiers()),
      );
    }
    _flushQueuedScroll();
    _clearQueuedZoom();
    _activeTouchPointer = -1;
    _isTouchScrolling = false;
    _isTouchPinching = true;
    _ignoreTouchUntilAllReleased = false;
    _clearGesturePreviewOnNextFrame = false;
    _pinchLastCenter = metrics.center;
    _pinchLastDistance = metrics.distance;
    _startGesturePreview(metrics.center);
    _sendZoomEvent(
      pb.ZoomEvent_Phase.ZOOM_BEGIN,
      focalXPx: metrics.center.dx * dpr,
      focalYPx: metrics.center.dy * dpr,
      requestRender: !_gesturePreviewActive,
    );
  }

  void _updateTouchPinch() {
    final metrics = _touchPinchMetrics();
    if (metrics == null) {
      return;
    }
    final panDx = metrics.center.dx - _pinchLastCenter.dx;
    final panDy = metrics.center.dy - _pinchLastCenter.dy;
    if (panDx != 0 || panDy != 0) {
      _queueScrollDeltaInternal(
        (-panDx / _touchScrollUnitPx) * _touchScrollGain,
        (-panDy / _touchScrollUnitPx) * _touchScrollGain,
        requestRender: !_gesturePreviewActive,
        immediate: true,
      );
    }
    var scaleDeltaForPreview = 1.0;
    if (_pinchLastDistance > 0 && metrics.distance > 0) {
      final scaleDelta = (metrics.distance / _pinchLastDistance)
          .clamp(_zoomStepMinScale, _zoomStepMaxScale);
      scaleDeltaForPreview = scaleDelta;
      _queueZoomDelta(
        scaleDelta: scaleDelta,
        focal: metrics.center,
        requestRender: !_gesturePreviewActive,
      );
    }
    _updateGesturePreview(
      focal: metrics.center,
      panDelta: Offset(panDx, panDy),
      scaleDelta: scaleDeltaForPreview,
    );
    _pinchLastCenter = metrics.center;
    _pinchLastDistance = metrics.distance;
  }

  void _endTouchPinch() {
    _flushQueuedZoom();
    _flushQueuedScroll();
    final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
    _clearGesturePreviewOnNextFrame = _gesturePreviewActive;
    _sendZoomEvent(
      pb.ZoomEvent_Phase.ZOOM_END,
      focalXPx: _pinchLastCenter.dx * dpr,
      focalYPx: _pinchLastCenter.dy * dpr,
    );
    _isTouchPinching = false;
    _ignoreTouchUntilAllReleased = _touchPoints.isNotEmpty;
    _pinchLastDistance = 0.0;
  }

  void _onPointerPanZoomStart(PointerPanZoomStartEvent event) {
    _pendingScrollDeltaX = 0.0;
    _pendingScrollDeltaY = 0.0;
    _pendingScrollNeedsRender = false;
    _clearQueuedZoom();
    _panZoomLastScale = 1.0;
    _clearGesturePreviewOnNextFrame = false;
    _startGesturePreview(event.localPosition);
    final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
    _sendZoomEvent(
      pb.ZoomEvent_Phase.ZOOM_BEGIN,
      focalXPx: event.localPosition.dx * dpr,
      focalYPx: event.localPosition.dy * dpr,
      requestRender: !_gesturePreviewActive,
    );
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    _queueScrollDeltaInternal(
      (-event.panDelta.dx / _touchScrollUnitPx) * _touchScrollGain,
      (-event.panDelta.dy / _touchScrollUnitPx) * _touchScrollGain,
      requestRender: !_gesturePreviewActive,
      immediate: true,
    );
    final nextScale = event.scale;
    if (nextScale.isFinite && nextScale > 0) {
      final scaleDelta = (nextScale / _panZoomLastScale)
          .clamp(_zoomStepMinScale, _zoomStepMaxScale);
      _panZoomLastScale = nextScale;
      _updateGesturePreview(
        focal: event.localPosition,
        panDelta: event.panDelta,
        scaleDelta: scaleDelta,
      );
      _queueZoomDelta(
        scaleDelta: scaleDelta,
        focal: event.localPosition,
        requestRender: !_gesturePreviewActive,
      );
    }
  }

  void _onPointerPanZoomEnd(PointerPanZoomEndEvent event) {
    _clearGesturePreviewOnNextFrame = _gesturePreviewActive;
    _flushQueuedZoom();
    _flushQueuedScroll();
    _panZoomLastScale = 1.0;
    final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
    _sendZoomEvent(
      pb.ZoomEvent_Phase.ZOOM_END,
      focalXPx: event.localPosition.dx * dpr,
      focalYPx: event.localPosition.dy * dpr,
    );
  }

  void _onKeyEvent(KeyEvent event) {
    if (_editing &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelEdit();
      return;
    }

    final pb.KeyEvent_Type type;
    if (event is KeyDownEvent) {
      type = pb.KeyEvent_Type.KEY_DOWN;
    } else if (event is KeyUpEvent) {
      type = pb.KeyEvent_Type.KEY_UP;
    } else {
      return;
    }

    _sendInput(
      pb.RenderInput()
        ..key = (pb.KeyEvent()
          ..type = type
          ..keyCode = (event.logicalKey.keyId & 0x7FFFFFFF).toInt()
          ..character = event.character ?? ''
          ..modifier = _modifiers()),
    );
    _requestRender();
  }

  // ── Context menu ───────────────────────────────────────────────────────

  void _showGridContextMenu(BuildContext ctx, Offset position) {
    final controller = widget.controller;
    final row = _selRow;
    final col = _selCol;
    if (row < 0 || col < 0) return;

    final items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
          value: 'pin_top', child: Text('Pin Row $row to Top')),
      PopupMenuItem<String>(
          value: 'pin_bottom', child: Text('Pin Row $row to Bottom')),
      PopupMenuItem<String>(value: 'unpin', child: Text('Unpin Row $row')),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
          value: 'sticky_top', child: Text('Sticky Row $row to Top')),
      PopupMenuItem<String>(
          value: 'sticky_bottom', child: Text('Sticky Row $row to Bottom')),
      PopupMenuItem<String>(
          value: 'sticky_both', child: Text('Sticky Row $row Both')),
      PopupMenuItem<String>(
          value: 'unsticky_row', child: Text('Unsticky Row $row')),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
          value: 'sticky_left', child: Text('Sticky Col $col to Left')),
      PopupMenuItem<String>(
          value: 'sticky_right', child: Text('Sticky Col $col to Right')),
      PopupMenuItem<String>(
          value: 'sticky_col_both', child: Text('Sticky Col $col Both')),
      PopupMenuItem<String>(
          value: 'unsticky_col', child: Text('Unsticky Col $col')),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(value: 'copy', child: Text('Copy')),
    ];

    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: items,
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'pin_top':
          controller.pinRow(row, pb.PinPosition.PIN_TOP);
        case 'pin_bottom':
          controller.pinRow(row, pb.PinPosition.PIN_BOTTOM);
        case 'unpin':
          controller.pinRow(row, pb.PinPosition.PIN_NONE);
        case 'sticky_top':
          controller.setRowSticky(row, pb.StickyEdge.STICKY_TOP);
        case 'sticky_bottom':
          controller.setRowSticky(row, pb.StickyEdge.STICKY_BOTTOM);
        case 'sticky_both':
          controller.setRowSticky(row, pb.StickyEdge.STICKY_BOTH);
        case 'unsticky_row':
          controller.setRowSticky(row, pb.StickyEdge.STICKY_NONE);
        case 'sticky_left':
          controller.setColSticky(col, pb.StickyEdge.STICKY_LEFT);
        case 'sticky_right':
          controller.setColSticky(col, pb.StickyEdge.STICKY_RIGHT);
        case 'sticky_col_both':
          controller.setColSticky(col, pb.StickyEdge.STICKY_BOTH);
        case 'unsticky_col':
          controller.setColSticky(col, pb.StickyEdge.STICKY_NONE);
        case 'copy':
          controller.copy().then((resp) {
            Clipboard.setData(ClipboardData(text: resp.text));
          });
      }
      _requestRender();
    });
  }

  int _modifiers() {
    int m = 0;
    if (HardwareKeyboard.instance.isShiftPressed) m |= 0x01;
    if (HardwareKeyboard.instance.isControlPressed) m |= 0x02;
    if (HardwareKeyboard.instance.isAltPressed) m |= 0x04;
    if (HardwareKeyboard.instance.isMetaPressed) m |= 0x08;
    return m;
  }

  bool get _useLargeGridGesturePreview =>
      _knownRows >= _largeGridGesturePreviewRows;

  void _scheduleKnownRowsRefresh({bool force = false}) {
    if (force) {
      // Row count can change without a grid-id change (e.g. loadDemo/setRows).
      // Force the next refresh call to fetch again.
      _knownRowsGridId = Int64.ZERO;
    }
    _knownRowsRefreshQueued = true;
    if (_knownRowsRefreshInFlight) {
      return;
    }
    // ignore: discarded_futures
    _drainKnownRowsRefreshQueue();
  }

  Future<void> _drainKnownRowsRefreshQueue() async {
    if (_knownRowsRefreshInFlight) {
      return;
    }
    _knownRowsRefreshInFlight = true;
    try {
      while (mounted && _knownRowsRefreshQueued) {
        _knownRowsRefreshQueued = false;
        await _refreshKnownRows();
      }
    } finally {
      _knownRowsRefreshInFlight = false;
    }
  }

  Future<void> _refreshKnownRows() async {
    if (!widget.controller.isCreated) {
      if (_knownRowsGridId != Int64.ZERO || _knownRows != 0) {
        setState(() {
          _knownRowsGridId = Int64.ZERO;
          _knownRows = 0;
        });
      }
      return;
    }
    final gridId = widget.controller.gridId;
    if (gridId == Int64.ZERO || _knownRowsGridId == gridId) {
      return;
    }
    _knownRowsGridId = gridId;
    try {
      final rows = await widget.controller.getRows();
      if (!mounted || widget.controller.gridId != gridId) {
        return;
      }
      if (_knownRows != rows) {
        setState(() {
          _knownRows = rows;
        });
      }
    } catch (_) {
      // Best-effort only. Keep preview mode disabled if row count lookup fails.
      if (mounted && _knownRowsGridId == gridId) {
        _knownRowsGridId = Int64.ZERO;
      }
    }
  }

  bool get _isMobilePlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _syncTouchScrollUnitBestEffort() {
    unawaited(_loadTouchScrollUnit());
  }

  Future<void> _loadTouchScrollUnit() async {
    if (!widget.controller.isCreated) {
      return;
    }
    try {
      final rowHeight = await widget.controller.getRowHeight(0);
      if (!mounted) {
        return;
      }
      if (rowHeight > 0) {
        _touchScrollUnitPx = rowHeight.toDouble();
      }
    } catch (_) {
      // Keep the current/default touch scroll unit on lookup failures.
    }
  }

  void _startGesturePreview(Offset focal) {
    if (!_useLargeGridGesturePreview) {
      return;
    }
    if (!_gesturePreviewActive ||
        _gesturePreviewScale != 1.0 ||
        _gesturePreviewPan != Offset.zero ||
        _gesturePreviewFocal != focal) {
      setState(() {
        _gesturePreviewActive = true;
        _gesturePreviewScale = 1.0;
        _gesturePreviewPan = Offset.zero;
        _gesturePreviewFocal = focal;
      });
    }
  }

  void _updateGesturePreview({
    required Offset focal,
    required Offset panDelta,
    required double scaleDelta,
  }) {
    if (!_gesturePreviewActive) {
      return;
    }
    setState(() {
      _gesturePreviewFocal = focal;
      _gesturePreviewPan += panDelta;
      _gesturePreviewScale =
          (_gesturePreviewScale * scaleDelta).clamp(0.25, 4.0);
    });
  }

  void _stopGesturePreview() {
    _clearGesturePreviewOnNextFrame = false;
    if (!_gesturePreviewActive &&
        _gesturePreviewScale == 1.0 &&
        _gesturePreviewPan == Offset.zero) {
      return;
    }
    setState(() {
      _gesturePreviewActive = false;
      _gesturePreviewScale = 1.0;
      _gesturePreviewPan = Offset.zero;
      _gesturePreviewFocal = Offset.zero;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isCreated) {
      return const Center(child: CircularProgressIndicator());
    }
    _syncEventStreamSubscription();

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaDpr = MediaQuery.maybeOf(context)?.devicePixelRatio;
        final dpr = (mediaDpr != null && mediaDpr.isFinite && mediaDpr > 0)
            ? mediaDpr
            : 1.0;
        final int w = math.max(1, (constraints.maxWidth * dpr).round());
        final int h = math.max(1, (constraints.maxHeight * dpr).round());

        // Detect viewport resize.
        if (w != _viewportWidth ||
            h != _viewportHeight ||
            (_devicePixelRatio - dpr).abs() > 0.0001) {
          _queueViewportResize(w, h, dpr);
        }

        return KeyboardListener(
          focusNode: _gridFocusNode,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            onPointerMove: _onPointerMove,
            onPointerCancel: _onPointerCancel,
            onPointerSignal: _onPointerSignal,
            onPointerPanZoomStart: _onPointerPanZoomStart,
            onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
            onPointerPanZoomEnd: _onPointerPanZoomEnd,
            child: Stack(
              children: [
                // Current Flutter path: decode native RGBA frames and show via
                // RawImage. A platform texture path can be added separately.
                SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: ClipRect(
                    child: _gesturePreviewActive
                        ? Transform(
                            transform: Matrix4.identity()
                              ..translate(
                                _gesturePreviewPan.dx + _gesturePreviewFocal.dx,
                                _gesturePreviewPan.dy + _gesturePreviewFocal.dy,
                              )
                              ..scale(
                                  _gesturePreviewScale, _gesturePreviewScale)
                              ..translate(
                                -_gesturePreviewFocal.dx,
                                -_gesturePreviewFocal.dy,
                              ),
                            filterQuality: FilterQuality.none,
                            child: _buildSurface(constraints),
                          )
                        : _buildSurface(constraints),
                  ),
                ),

                // Overlay edit TextField.
                if (_editing)
                  Positioned(
                    left: _editRect.left,
                    top: _editRect.top,
                    width: _editRect.width,
                    height: _editRect.height,
                    child: Material(
                      elevation: 2,
                      child: TextField(
                        controller: _editTextController,
                        focusNode: _editFocusNode,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13),
                        onSubmitted: (_) => _commitEdit(),
                        onTapOutside: (_) => _commitEdit(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TouchPinchMetrics {
  final Offset center;
  final double distance;

  const _TouchPinchMetrics({required this.center, required this.distance});
}

class _FallbackGridTable extends StatelessWidget {
  final List<List<String>> cells;

  const _FallbackGridTable({required this.cells});

  @override
  Widget build(BuildContext context) {
    final header = cells.isNotEmpty ? cells.first : const <String>[];
    final body = cells.length > 1 ? cells.sublist(1) : const <List<String>>[];
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final headerColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(140),
          border: TableBorder.all(color: borderColor, width: 0.5),
          children: [
            if (header.isNotEmpty)
              TableRow(
                decoration: BoxDecoration(color: headerColor),
                children: [
                  for (final value in header)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            for (var r = 0; r < body.length; r++)
              TableRow(
                decoration: BoxDecoration(
                  color: r.isEven ? Colors.white : const Color(0xFFF8F8F8),
                ),
                children: [
                  for (final value in body[r])
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A placeholder painter shown before the first native frame arrives.
class _GridPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFF5F5F5);
    canvas.drawRect(Offset.zero & size, paint);

    // Draw a subtle grid pattern to hint at the grid structure.
    final linePaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.5;

    const double cellWidth = 70;
    const double cellHeight = 20;

    for (double x = 0; x <= size.width; x += cellWidth) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y <= size.height; y += cellHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Draw header row background.
    final headerPaint = Paint()..color = const Color(0xFFE8E8E8);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cellHeight), headerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
