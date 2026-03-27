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

class VolvoxGridBeforeEditDetails {
  final pb.GridEvent rawEvent;
  final int row;
  final int col;
  bool cancel;

  VolvoxGridBeforeEditDetails({
    required this.rawEvent,
    required this.row,
    required this.col,
    this.cancel = false,
  });
}

class VolvoxGridCellEditValidatingDetails {
  final pb.GridEvent rawEvent;
  final int row;
  final int col;
  final String editText;
  bool cancel;

  VolvoxGridCellEditValidatingDetails({
    required this.rawEvent,
    required this.row,
    required this.col,
    required this.editText,
    this.cancel = false,
  });
}

class VolvoxGridBeforeSortDetails {
  final pb.GridEvent rawEvent;
  final int col;
  bool cancel;

  VolvoxGridBeforeSortDetails({
    required this.rawEvent,
    required this.col,
    this.cancel = false,
  });
}

class _CellEditValidatingPayload {
  final int row;
  final int col;
  final String editText;

  const _CellEditValidatingPayload({
    required this.row,
    required this.col,
    required this.editText,
  });
}

enum _HostEditUiMode { enter, edit }

class _DeferredPointerCompletion {
  final PointerDeviceKind kind;
  final Offset localPosition;
  final int buttons;
  final int pointer;

  const _DeferredPointerCompletion._({
    required this.kind,
    required this.localPosition,
    required this.buttons,
    required this.pointer,
  });

  factory _DeferredPointerCompletion.up(PointerUpEvent event) {
    return _DeferredPointerCompletion._(
      kind: event.kind,
      localPosition: event.localPosition,
      buttons: event.buttons,
      pointer: event.pointer,
    );
  }

  factory _DeferredPointerCompletion.cancel(PointerCancelEvent event) {
    return _DeferredPointerCompletion._(
      kind: event.kind,
      localPosition: event.localPosition,
      buttons: 0,
      pointer: event.pointer,
    );
  }
}

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

  /// Optional callback fired before editing begins.
  ///
  /// Set [VolvoxGridBeforeEditDetails.cancel] to true to cancel the edit.
  ///
  /// This is one of the currently supported cancelable widget hooks.
  final ValueChanged<VolvoxGridBeforeEditDetails>? onBeforeEdit;

  /// Optional callback fired before an edited value is committed.
  ///
  /// Set [VolvoxGridCellEditValidatingDetails.cancel] to true to reject the
  /// pending edit.
  ///
  /// This is one of the currently supported cancelable widget hooks.
  final ValueChanged<VolvoxGridCellEditValidatingDetails>? onCellEditValidating;

  /// Optional callback fired before header-click sorting is applied.
  ///
  /// Set [VolvoxGridBeforeSortDetails.cancel] to true to keep the current sort.
  ///
  /// This is one of the currently supported cancelable widget hooks.
  final ValueChanged<VolvoxGridBeforeSortDetails>? onBeforeSort;

  /// Optional callback for custom-render cell events.
  ///
  /// Receives either legacy `DrawCell` payloads or modern `CustomRenderCell`
  /// payloads depending on the generated proto version in use.
  final ValueChanged<Object>? onCustomRenderCell;

  /// Legacy alias for draw-cell events.
  final ValueChanged<Object>? onDrawCell;

  /// Legacy raw callback for cancelable events.
  ///
  /// Prefer [onBeforeEdit], [onCellEditValidating], and [onBeforeSort] for a
  /// clearer cancel-style API. Returning true here still cancels the
  /// corresponding native action.
  final bool Function(pb.GridEvent event)? onCancelableEvent;

  const VolvoxGridWidget({
    required this.controller,
    this.onSelectionChanged,
    this.onGridEvent,
    this.onBeforeEdit,
    this.onCellEditValidating,
    this.onBeforeSort,
    this.onCustomRenderCell,
    this.onDrawCell,
    this.onCancelableEvent,
    super.key,
  });

  @override
  State<VolvoxGridWidget> createState() => _VolvoxGridWidgetState();
}

class _VolvoxGridWidgetState extends State<VolvoxGridWidget> {
  late final AppLifecycleListener _lifecycleListener;

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
  int _stagedBufferWidth = 0;
  int _stagedBufferHeight = 0;

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
  bool _editOverlayVisible = true;
  bool _editOverlayPendingReveal = false;
  int _editRow = -1;
  int _editCol = -1;
  Rect _editRect = Rect.zero;
  double _editFontSize = 13.0;
  String? _editFontFamily;
  bool _editFontBold = false;
  bool _editFontItalic = false;
  EdgeInsets _editPadding = EdgeInsets.zero;
  _HostEditUiMode _editUiMode = _HostEditUiMode.enter;
  int _editSessionToken = 0;
  bool _editCommitReplayActive = false;
  _DeferredPointerCompletion? _deferredPointerCompletionAfterEditCommit;

  final TextEditingController _editTextController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();
  final TextEditingController _imeProxyController = TextEditingController();
  final FocusNode _imeProxyFocusNode = FocusNode();
  pb.EditRequest? _deferredEditRequest;
  Timer? _imeProxyRevealTimer;
  Future<void> _queuedEditCommand = Future<void>.value();
  bool _deferOverlayWhileImeProxyActive = false;
  bool _imeProxySessionActive = false;
  bool _suppressImeProxyChanges = false;
  String _imeProxyCommittedText = '';
  String? _suppressedPlainProxyText;

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
  Duration? _lastPrimaryMouseDownAt;
  Offset? _lastPrimaryMouseDownPosition;
  Duration? _lastTouchDownAt;
  Offset? _lastTouchDownPosition;

  bool _wasUsingGpuTexture = false;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: _onPause,
      onResume: _onResume,
    );
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
    _imeProxyController.addListener(_handleImeProxyChanged);
    widget.controller.addListener(_onControllerChanged);
    _syncEventStreamSubscription();
  }

  void _onPause() {
    unawaited(_setFlingEnabledBestEffort(widget.controller, false));

    // Reset render gating so resume can always submit a fresh frame.
    _pendingFrame = false;
    _needsFollowupRender = false;

    // Tear down the bidi render session while backgrounded. This guarantees
    // native GPU surface/swapchain state is dropped, avoiding stale-surface
    // reuse races when Android recreates compositor surfaces on resume.
    _closeRenderSession(controller: widget.controller);

    if (defaultTargetPlatform == TargetPlatform.android &&
        widget.controller.gpuTextureId != null) {
      _wasUsingGpuTexture = true;
      // Render session is already closed, so a graceful invalidate frame is not
      // required here.
      unawaited(widget.controller.releaseGpuTexture(graceful: false));
    } else {
      _wasUsingGpuTexture = false;
    }
  }

  void _onResume() {
    unawaited(_setFlingEnabledBestEffort(
        widget.controller, _isMobilePlatform || _flingOverrideEnabled));

    if (defaultTargetPlatform != TargetPlatform.android) {
      _ensureRenderSession();
      _requestRender();
      return;
    }
    if (!_wasUsingGpuTexture && widget.controller.gpuTextureId == null) {
      _ensureRenderSession();
      _requestRender();
      return;
    }

    _wasUsingGpuTexture = false;
    final backendToRestore = widget.controller.gpuBackend ?? 'gles';
    // Backgrounding invalidates the native texture/surface on many devices.
    // Recreate the texture and force a guaranteed redraw into the new surface.
    unawaited(() async {
      try {
        await widget.controller.releaseGpuTexture(graceful: true);
        if (!mounted) {
          return;
        }
        await widget.controller.createGpuTexture(
          backend: backendToRestore,
          width: _viewportWidth > 0 ? _viewportWidth : 1,
          height: _viewportHeight > 0 ? _viewportHeight : 1,
        );
        if (!mounted) {
          return;
        }
        _pendingFrame = false;
        _needsFollowupRender = false;
        if (_viewportWidth > 0 && _viewportHeight > 0) {
          await widget.controller
              .setGpuTextureSize(_viewportWidth, _viewportHeight);
        }
        // Force a fresh frame for the newly attached surface even if the grid
        // was previously clean.
        if (widget.controller.gpuTextureId != null &&
            widget.controller.isCreated) {
          await widget.controller.refresh();
        }
        if (!mounted) {
          return;
        }
        _requestRender();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _pendingFrame = false;
          _needsFollowupRender = false;
          _requestRender();
        });
      } finally {
        if (mounted) {
          _ensureRenderSession();
          setState(() {});
        }
      }
    }());
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _longPressTimer?.cancel();
    _imeProxyRevealTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    _closeRenderSession(controller: widget.controller);
    _closeEventStream();
    _freeRenderBuffer();
    widget.controller.removeListener(_onControllerChanged);
    _imeProxyController.dispose();
    _imeProxyFocusNode.dispose();
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
        oldWidget.onBeforeEdit != widget.onBeforeEdit ||
        oldWidget.onCellEditValidating != widget.onCellEditValidating ||
        oldWidget.onBeforeSort != widget.onBeforeSort ||
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
    _stagedBufferWidth = 0;
    _stagedBufferHeight = 0;
    _decisionChannelEnabled = false;
    _imeProxyRevealTimer?.cancel();
    _imeProxyRevealTimer = null;
    _deferredEditRequest = null;
    _deferOverlayWhileImeProxyActive = false;
    _imeProxySessionActive = false;
    _editOverlayPendingReveal = false;
    _imeProxyCommittedText = '';
    _suppressedPlainProxyText = null;
    _suppressImeProxyChanges = false;
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
      widget.onBeforeEdit != null ||
      widget.onCellEditValidating != null ||
      widget.onBeforeSort != null ||
      widget.onCustomRenderCell != null ||
      widget.onDrawCell != null ||
      widget.onCancelableEvent != null;

  bool get _wantsCancelableGridEvents =>
      widget.onBeforeEdit != null ||
      widget.onCellEditValidating != null ||
      widget.onBeforeSort != null ||
      widget.onCancelableEvent != null;

  void _syncEventStreamSubscription() {
    if (!_wantsGridEvents || !widget.controller.isCreated) {
      _closeEventStream();
      return;
    }
    _ensureEventStream();
    if (_wantsCancelableGridEvents) {
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
    if (event.hasBeforeEdit() || event.hasBeforeSort()) {
      return true;
    }
    return _tryGetCellEditValidatingPayload(event) != null;
  }

  _CellEditValidatingPayload? _tryGetCellEditValidatingPayload(
      pb.GridEvent event) {
    final dynamic dyn = event;
    try {
      if (dyn.hasCellEditValidate() == true) {
        final payload = dyn.cellEditValidate;
        return _CellEditValidatingPayload(
          row: payload.row as int,
          col: payload.col as int,
          editText: (payload.editText as String?) ?? '',
        );
      }
    } catch (_) {
      // Older generated bindings expose hasValidateEdit().
    }
    try {
      if (dyn.hasValidateEdit() == true) {
        final payload = dyn.validateEdit;
        return _CellEditValidatingPayload(
          row: payload.row as int,
          col: payload.col as int,
          editText: (payload.editText as String?) ?? '',
        );
      }
    } catch (_) {
      // Newer generated bindings may only expose hasCellEditValidate().
    }
    return null;
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

    if (!_wantsCancelableGridEvents || !_isCancelableGridEvent(event)) {
      return;
    }

    _enableDecisionChannel();
    if (_inputController == null) {
      return;
    }

    final cancel = _dispatchCancelableGridEvent(event);
    _sendInput(
      pb.RenderInput()
        ..eventDecision = (pb.EventDecision()
          ..gridId = widget.controller.gridId
          ..eventId = event.eventId
          ..cancel = cancel),
    );
    _requestRender();
  }

  bool _dispatchCancelableGridEvent(pb.GridEvent event) {
    var cancel = false;

    if (event.hasBeforeEdit()) {
      final details = VolvoxGridBeforeEditDetails(
        rawEvent: event,
        row: event.beforeEdit.row,
        col: event.beforeEdit.col,
      );
      widget.onBeforeEdit?.call(details);
      cancel = cancel || details.cancel;
    }

    final validate = _tryGetCellEditValidatingPayload(event);
    if (validate != null) {
      final details = VolvoxGridCellEditValidatingDetails(
        rawEvent: event,
        row: validate.row,
        col: validate.col,
        editText: validate.editText,
      );
      widget.onCellEditValidating?.call(details);
      cancel = cancel || details.cancel;
    }

    if (event.hasBeforeSort()) {
      final details = VolvoxGridBeforeSortDetails(
        rawEvent: event,
        col: event.beforeSort.col,
      );
      widget.onBeforeSort?.call(details);
      cancel = cancel || details.cancel;
    }

    final onCancelableEvent = widget.onCancelableEvent;
    if (onCancelableEvent != null) {
      cancel = onCancelableEvent(event) || cancel;
    }

    return cancel;
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
    if (_editing && _editRow >= 0 && _editCol >= 0) {
      unawaited(widget.controller.showCell(_editRow, _editCol));
    }
  }

  void _resizeRenderBuffer(int width, int height) {
    if (width <= 0 || height <= 0) {
      return;
    }
    _stagedBufferWidth = width;
    _stagedBufferHeight = height;
    if (_pendingFrame) {
      return;
    }
    _applyStagedRenderBufferResize();
  }

  void _applyStagedRenderBufferResize() {
    final width = _stagedBufferWidth > 0 ? _stagedBufferWidth : _bufferWidth;
    final height =
        _stagedBufferHeight > 0 ? _stagedBufferHeight : _bufferHeight;
    if (width <= 0 || height <= 0) {
      return;
    }
    _stagedBufferWidth = 0;
    _stagedBufferHeight = 0;

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

    // Freeze-and-swap resize: hold the front buffer stable until the previous
    // frame completes, then swap to a freshly sized back buffer.
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
    _stagedBufferWidth = 0;
    _stagedBufferHeight = 0;
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
    _stagedBufferWidth = 0;
    _stagedBufferHeight = 0;
  }

  void _sendBufferReady() {
    final textureId = widget.controller.gpuTextureId;
    final surfaceHandle = widget.controller.gpuSurfaceHandle;

    if (textureId != null && surfaceHandle != null) {
      if (_pendingFrame) {
        _needsFollowupRender = true;
        return;
      }
      _applyStagedRenderBufferResize();
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

    if (_pendingFrame) {
      _needsFollowupRender = true;
      return;
    }
    _applyStagedRenderBufferResize();
    final buffer = _pixelBuffer;
    if (buffer == null || _inputController == null) {
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

    if ((output.hasFrameDone() || output.hasGpuFrameDone()) &&
        !output.rendered &&
        _editOverlayPendingReveal &&
        !_pendingFrame &&
        _editing) {
      setState(() {
        _editOverlayVisible = true;
        _editOverlayPendingReveal = false;
      });
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
      if (_deferOverlayWhileImeProxyActive) {
        _deferredEditRequest = pb.EditRequest()
          ..mergeFromMessage(output.editRequest);
      } else {
        _showEditOverlay(output.editRequest);
      }
    }
    if (output.hasDropdownRequest() && output.dropdownRequest.width > 0) {
      if (output.dropdownRequest.editable) {
        unawaited(_showEditableDropdownOverlay(output.dropdownRequest));
      } else {
        _showReadonlyDropdownOverlay(output.dropdownRequest);
      }
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
      final rows = await widget.controller.rowCount();
      final cols = await widget.controller.colCount();
      final maxRows = math.max(0, math.min(rows, 200));
      final maxCols = math.max(0, math.min(cols, 16));
      final snapshot = <List<String>>[];

      for (var r = 0; r < maxRows; r++) {
        final rowValues = await Future.wait(
          List.generate(maxCols, (c) => widget.controller.getCellText(r, c)),
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

  void _queueEditCommand(Future<void> Function() op) {
    _queuedEditCommand = _queuedEditCommand.then((_) async {
      if (!mounted || !widget.controller.isCreated) {
        return;
      }
      await op();
    }).catchError((Object _) {});
  }

  int _codePointOffsetFromCodeUnitOffset(String text, int codeUnitOffset) {
    final clamped = codeUnitOffset.clamp(0, text.length);
    var codePointOffset = 0;
    var consumed = 0;
    for (final rune in text.runes) {
      final runeLength = String.fromCharCode(rune).length;
      if (consumed + runeLength > clamped) {
        break;
      }
      consumed += runeLength;
      codePointOffset += 1;
    }
    return codePointOffset;
  }

  int _codeUnitOffsetFromCodePointOffset(String text, int codePointOffset) {
    final target = codePointOffset < 0 ? 0 : codePointOffset;
    var currentCodePoint = 0;
    var codeUnitOffset = 0;
    for (final rune in text.runes) {
      if (currentCodePoint >= target) {
        break;
      }
      codeUnitOffset += String.fromCharCode(rune).length;
      currentCodePoint += 1;
    }
    return codeUnitOffset.clamp(0, text.length);
  }

  TextSelection _textSelectionFromEditRequest(pb.EditRequest req) {
    final start = _codeUnitOffsetFromCodePointOffset(
      req.currentValue,
      req.selStart,
    );
    final extent = _codeUnitOffsetFromCodePointOffset(
      req.currentValue,
      req.selStart + req.selLength,
    );
    return TextSelection(
      baseOffset: start,
      extentOffset: extent,
    );
  }

  void _applyEditRequestSelection(pb.EditRequest req) {
    final selection = _textSelectionFromEditRequest(req);
    final text = _editTextController.text;
    final clampedBase = selection.baseOffset.clamp(0, text.length);
    final clampedExtent = selection.extentOffset.clamp(0, text.length);
    _editTextController.selection = TextSelection(
      baseOffset: clampedBase,
      extentOffset: clampedExtent,
    );
  }

  void _clearImeProxyValue() {
    if (_imeProxyController.value.text.isEmpty &&
        (!_imeProxyController.value.composing.isValid ||
            _imeProxyController.value.composing.isCollapsed)) {
      return;
    }
    _suppressImeProxyChanges = true;
    _imeProxyController.value = const TextEditingValue();
    _suppressImeProxyChanges = false;
  }

  void _requestIdleInputFocus() {
    if (_editing) {
      return;
    }
    // On mobile (Android/iOS), focusing the hidden imeProxy TextField would
    // open the soft keyboard on every tap.  The imeProxy is only useful on
    // desktop where a hardware keyboard may produce IME composition without
    // an active edit overlay.
    if (_isMobilePlatform) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _editing) {
        return;
      }
      _imeProxyFocusNode.requestFocus();
    });
  }

  void _showEditOverlay(pb.EditRequest req) {
    _imeProxyRevealTimer?.cancel();
    _imeProxyRevealTimer = null;
    _deferredEditRequest = null;
    _deferOverlayWhileImeProxyActive = false;
    _imeProxySessionActive = false;
    _imeProxyCommittedText = '';
    _suppressedPlainProxyText = null;
    _clearImeProxyValue();

    final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
    final nextRect = Rect.fromLTWH(
      req.x.toDouble() / dpr,
      req.y.toDouble() / dpr,
      req.width.toDouble() / dpr,
      req.height.toDouble() / dpr,
    );
    final nextMode = req.uiMode == pb.EditUiMode.EDIT_UI_MODE_EDIT
        ? _HostEditUiMode.edit
        : _HostEditUiMode.enter;
    final sameSession = _editing && _editRow == req.row && _editCol == req.col;

    if (sameSession) {
      final shouldHideDuringMove =
          defaultTargetPlatform == TargetPlatform.android &&
              _editRect != nextRect;
      setState(() {
        _editRect = nextRect;
        _editUiMode = nextMode;
        if (shouldHideDuringMove) {
          _editOverlayVisible = false;
          _editOverlayPendingReveal = true;
        }
      });
      return;
    }

    final selection = _textSelectionFromEditRequest(req);
    setState(() {
      _editing = true;
      _editOverlayVisible = true;
      _editOverlayPendingReveal = false;
      _editRow = req.row;
      _editCol = req.col;
      _editRect = nextRect;
      _editUiMode = nextMode;
      _editSessionToken += 1;
      // Reset style state so stale values from a previous cell don't flash.
      _editFontSize = 13.0;
      _editFontFamily = null;
      _editFontBold = false;
      _editFontItalic = false;
      _editPadding = EdgeInsets.zero;
      _editTextController.value = TextEditingValue(
        text: req.currentValue,
        selection: selection,
      );
    });
    // Resolve the cell's effective style asynchronously.
    _resolveEditCellStyle(req.row, req.col);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing || _editRow != req.row || _editCol != req.col) {
        return;
      }
      _editFocusNode.requestFocus();
      _applyEditRequestSelection(req);
      // Re-apply after another frame — on desktop, requestFocus() can
      // trigger an async selection-all that overrides our caret position.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_editing ||
            _editRow != req.row ||
            _editCol != req.col) {
          return;
        }
        _applyEditRequestSelection(req);
      });
    });
  }

  void _resolveEditCellStyle(int row, int col) {
    widget.controller.getEditCellStyle(row, col).then((style) {
      if (!mounted || !_editing || _editRow != row || _editCol != col) return;
      if (style == null) return;
      // Engine values are in physical pixels; convert to logical.
      final dpr = _devicePixelRatio <= 0 ? 1.0 : _devicePixelRatio;
      setState(() {
        if (style.fontSize != null) _editFontSize = style.fontSize! / dpr;
        _editFontFamily = style.fontFamily;
        _editFontBold = style.bold;
        _editFontItalic = style.italic;
        _editPadding = EdgeInsets.fromLTRB(
          style.padLeft / dpr,
          style.padTop / dpr,
          style.padRight / dpr,
          style.padBottom / dpr,
        );
      });
    });
  }

  void _scheduleDeferredImeOverlayReveal() {
    _imeProxyRevealTimer?.cancel();
    _imeProxyRevealTimer = Timer(const Duration(milliseconds: 40), () {
      if (!mounted) {
        return;
      }
      _deferOverlayWhileImeProxyActive = false;
      _imeProxySessionActive = false;
      final pending = _deferredEditRequest;
      _deferredEditRequest = null;
      if (pending != null) {
        _showEditOverlay(pending);
      } else {
        _requestRender();
      }
    });
  }

  void _handleImeProxyChanged() {
    if (_suppressImeProxyChanges) {
      return;
    }
    final value = _imeProxyController.value;
    final composing = value.composing.isValid && !value.composing.isCollapsed;

    if (_editing) {
      if (value.text.isNotEmpty || composing) {
        _clearImeProxyValue();
      }
      return;
    }

    if (!composing &&
        _suppressedPlainProxyText != null &&
        value.text == _suppressedPlainProxyText &&
        !_imeProxySessionActive) {
      _suppressedPlainProxyText = null;
      _clearImeProxyValue();
      return;
    }

    if (composing) {
      if (_selRow < 0 || _selCol < 0) {
        _clearImeProxyValue();
        return;
      }
      _suppressedPlainProxyText = null;
      _imeProxyRevealTimer?.cancel();
      _deferOverlayWhileImeProxyActive = true;
      if (!_imeProxySessionActive) {
        _imeProxySessionActive = true;
        _imeProxyCommittedText = '';
        _deferredEditRequest = null;
        final row = _selRow;
        final col = _selCol;
        _queueEditCommand(() async {
          await widget.controller.beginEdit(row, col, seedText: '');
          _requestRender();
        });
      }
      final start = value.composing.start.clamp(0, value.text.length);
      final end = value.composing.end.clamp(start, value.text.length);
      final prefix = value.text.substring(0, start);
      var delta = prefix;
      if (_imeProxyCommittedText.isNotEmpty &&
          prefix.startsWith(_imeProxyCommittedText)) {
        delta = prefix.substring(_imeProxyCommittedText.length);
      }
      _imeProxyCommittedText = prefix;
      if (delta.isNotEmpty) {
        _queueEditCommand(() async {
          await widget.controller.setEditPreedit(delta, commit: true);
          _requestRender();
        });
      }
      final preedit = value.text.substring(start, end);
      final extentOffset = value.selection.isValid
          ? value.selection.extentOffset.clamp(start, end)
          : end;
      final cursor = _codePointOffsetFromCodeUnitOffset(
        preedit,
        extentOffset - start,
      );
      _queueEditCommand(() async {
        await widget.controller.setEditPreedit(preedit, cursor: cursor);
        _requestRender();
      });
      return;
    }

    if (_imeProxySessionActive) {
      final committed = value.text;
      var delta = committed;
      if (_imeProxyCommittedText.isNotEmpty &&
          committed.startsWith(_imeProxyCommittedText)) {
        delta = committed.substring(_imeProxyCommittedText.length);
      }
      _imeProxyCommittedText = '';
      if (delta.isNotEmpty) {
        _queueEditCommand(() async {
          await widget.controller.setEditPreedit(delta, commit: true);
          _requestRender();
        });
      } else {
        _queueEditCommand(() async {
          await widget.controller.setEditPreedit('', cursor: 0);
          _requestRender();
        });
      }
      _clearImeProxyValue();
      _scheduleDeferredImeOverlayReveal();
      return;
    }

    if (value.text.isEmpty) {
      return;
    }
    if (_selRow < 0 || _selCol < 0) {
      _clearImeProxyValue();
      return;
    }
    final row = _selRow;
    final col = _selCol;
    final seedText = value.text;
    _imeProxyRevealTimer?.cancel();
    _deferOverlayWhileImeProxyActive = true;
    _imeProxySessionActive = true;
    _imeProxyCommittedText = '';
    _deferredEditRequest = null;
    _clearImeProxyValue();
    _queueEditCommand(() async {
      await widget.controller.beginEdit(row, col, seedText: seedText);
      _requestRender();
    });
    _scheduleDeferredImeOverlayReveal();
  }

  void _forwardRawKeyEvent(KeyEvent event) {
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

  bool _isPrintableKey(KeyEvent event) {
    final character = event.character;
    if (character == null || character.isEmpty) {
      return false;
    }
    return character.runes.any((rune) => rune >= 0x20 && rune != 0x7F);
  }

  bool _shouldLetImeProxyHandleText(KeyEvent event) {
    final hasTextModifiers = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    return _isPrintableKey(event) && !hasTextModifiers;
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    if (!mounted) {
      return false;
    }
    if (_editing ||
        _imeProxySessionActive ||
        _deferOverlayWhileImeProxyActive ||
        !_imeProxyFocusNode.hasFocus) {
      return false;
    }
    if (event is! KeyDownEvent && event is! KeyUpEvent) {
      return false;
    }
    if (_shouldLetImeProxyHandleText(event)) {
      return false;
    }
    _forwardRawKeyEvent(event);
    return false;
  }

  KeyEventResult _onGridFocusKeyEvent(FocusNode node, KeyEvent event) {
    if (_editing ||
        _imeProxySessionActive ||
        _deferOverlayWhileImeProxyActive) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    if (_shouldLetImeProxyHandleText(event) && event is KeyDownEvent) {
      _suppressedPlainProxyText = event.character;
    }
    _forwardRawKeyEvent(event);
    return KeyEventResult.ignored;
  }

  void _moveEditCaretToEdge({required bool end}) {
    final offset = end ? _editTextController.text.length : 0;
    _editTextController.selection = TextSelection.collapsed(offset: offset);
  }

  KeyEventResult _onEditOverlayKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final composing = _editTextController.value.composing.isValid &&
        !_editTextController.value.composing.isCollapsed;
    if (composing) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelEdit();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_editUiMode == _HostEditUiMode.edit) {
        _moveEditCaretToEdge(end: false);
      } else {
        unawaited(_commitEditAndMove(-1));
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_editUiMode == _HostEditUiMode.edit) {
        _moveEditCaretToEdge(end: true);
      } else {
        unawaited(_commitEditAndMove(1));
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _commitEditAndMove(int rowDelta) async {
    final currentRow = _editRow >= 0 ? _editRow : _selRow;
    final currentCol = _editCol >= 0 ? _editCol : _selCol;
    await widget.controller.commitEdit(_editTextController.text);

    if (currentRow >= 0 && currentCol >= 0) {
      try {
        final rowCount = await widget.controller.rowCount();
        final maxRow = rowCount > 0 ? rowCount - 1 : 0;
        final targetRow = (currentRow + rowDelta).clamp(0, maxRow);
        await widget.controller.selectRange(
          targetRow,
          currentCol,
          targetRow,
          currentCol,
        );
        await widget.controller.showCell(targetRow, currentCol);
        _selRow = targetRow;
        _selCol = currentCol;
      } catch (_) {
        // Best-effort navigation after commit.
      }
    }

    if (!mounted) {
      return;
    }
    _closeLocalEditOverlay();
    _requestRender();
  }

  Future<void> _commitActiveEdit() async {
    await widget.controller.commitEdit(_editTextController.text);
    if (!mounted) {
      return;
    }
    _closeLocalEditOverlay();
    _requestRender();
  }

  void _commitEdit() {
    unawaited(_commitActiveEdit());
  }

  Future<void> _cancelActiveEdit() async {
    await widget.controller.cancelEdit();
    if (!mounted) {
      return;
    }
    _closeLocalEditOverlay();
    _requestRender();
  }

  void _cancelEdit() {
    unawaited(_cancelActiveEdit());
  }

  void _showReadonlyDropdownOverlay(pb.DropdownRequest req) {
    if (_editing) {
      _closeLocalEditOverlay(requestIdleInputFocus: false);
    }
    _editFocusNode.unfocus();
    _imeProxyFocusNode.unfocus();
    _requestRender();
  }

  Future<void> _showEditableDropdownOverlay(pb.DropdownRequest req) async {
    var text = "";
    if (req.selected >= 0 && req.selected < req.items.length) {
      text = req.items[req.selected];
    }
    try {
      final state = await widget.controller.getEditState();
      if (state.active && state.row == req.row && state.col == req.col) {
        text = state.text;
      }
    } catch (_) {
      // Fall back to the selected item text when the current edit state is unavailable.
    }
    if (!mounted) {
      return;
    }
    final codePointLength = text.runes.length;
    _showEditOverlay(pb.EditRequest()
      ..row = req.row
      ..col = req.col
      ..x = req.x
      ..y = req.y
      ..width = req.width
      ..height = req.height
      ..currentValue = text
      ..selStart = codePointLength
      ..selLength = 0
      ..uiMode = pb.EditUiMode.EDIT_UI_MODE_ENTER);
  }

  bool _isPointerWithinActiveEditOverlay(Offset localPosition) {
    if (!_editing || !_editOverlayVisible) {
      return false;
    }
    return _editRect.contains(localPosition);
  }

  void _closeLocalEditOverlay({bool requestIdleInputFocus = true}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _editing = false;
      _editOverlayVisible = true;
      _editOverlayPendingReveal = false;
      _editRow = -1;
      _editCol = -1;
      _editSessionToken += 1;
    });
    if (requestIdleInputFocus) {
      _requestIdleInputFocus();
    }
  }

  void _commitEditIfSessionCurrent(int sessionToken, int row, int col) {
    if (_editCommitReplayActive ||
        !_editing ||
        _editSessionToken != sessionToken ||
        _editRow != row ||
        _editCol != col) {
      return;
    }
    _commitEdit();
  }

  Future<void> _commitEditBeforeDispatchingPointerDown(
    PointerDownEvent event,
    bool isDoubleClick,
  ) async {
    if (_editCommitReplayActive) {
      return;
    }
    _editCommitReplayActive = true;
    _deferredPointerCompletionAfterEditCommit = null;
    final sessionToken = _editSessionToken;
    final row = _editRow;
    final col = _editCol;
    final textValue = _editTextController.text;
    try {
      await widget.controller.commitEdit(textValue);
      final state = await widget.controller.getEditState();
      if (!mounted) {
        return;
      }
      if (state.active) {
        _requestRender();
        return;
      }
      if (_editSessionToken == sessionToken &&
          _editRow == row &&
          _editCol == col) {
        _closeLocalEditOverlay();
      } else {
        _requestIdleInputFocus();
      }
      _dispatchPointerDown(event, isDoubleClick);
      final deferred = _deferredPointerCompletionAfterEditCommit;
      _deferredPointerCompletionAfterEditCommit = null;
      if (deferred != null) {
        _dispatchPointerCompletion(deferred);
      }
    } catch (_) {
      if (mounted) {
        _requestRender();
      }
    } finally {
      _editCommitReplayActive = false;
    }
  }

  // ── Event forwarding ─────────────────────────────────────────────────────

  bool _isPrimaryMouseDoubleClick(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return false;
    }
    final lastAt = _lastPrimaryMouseDownAt;
    final lastPosition = _lastPrimaryMouseDownPosition;
    final isDoubleClick = lastAt != null &&
        event.timeStamp >= lastAt &&
        event.timeStamp - lastAt <= kDoubleTapTimeout &&
        lastPosition != null &&
        (event.localPosition - lastPosition).distance <= kDoubleTapSlop;
    _lastPrimaryMouseDownAt = event.timeStamp;
    _lastPrimaryMouseDownPosition = event.localPosition;
    return isDoubleClick;
  }

  bool _isTouchDoubleTap(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) {
      return false;
    }
    final lastAt = _lastTouchDownAt;
    final lastPosition = _lastTouchDownPosition;
    final isDoubleTap = lastAt != null &&
        event.timeStamp >= lastAt &&
        event.timeStamp - lastAt <= kDoubleTapTimeout &&
        lastPosition != null &&
        (event.localPosition - lastPosition).distance <= kDoubleTapSlop;
    _lastTouchDownAt = event.timeStamp;
    _lastTouchDownPosition = event.localPosition;
    return isDoubleTap;
  }

  void _onPointerDown(PointerDownEvent event) {
    final isDoubleClick =
        _isPrimaryMouseDoubleClick(event) || _isTouchDoubleTap(event);
    if (_editing && !_isPointerWithinActiveEditOverlay(event.localPosition)) {
      unawaited(_commitEditBeforeDispatchingPointerDown(event, isDoubleClick));
      return;
    }
    _dispatchPointerDown(event, isDoubleClick);
  }

  void _dispatchPointerDown(PointerDownEvent event, bool isDoubleClick) {
    _requestIdleInputFocus();
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
            ..modifier = _modifiers()
            ..dblClick = isDoubleClick),
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
          ..modifier = _modifiers()
          ..dblClick = isDoubleClick),
    );
    _requestRender();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_editCommitReplayActive) {
      _deferredPointerCompletionAfterEditCommit =
          _DeferredPointerCompletion.up(event);
      return;
    }
    _dispatchPointerCompletion(_DeferredPointerCompletion.up(event));
  }

  void _dispatchPointerCompletion(_DeferredPointerCompletion event) {
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

  void _onPointerHover(PointerHoverEvent event) {
    // Mouse hover (no button pressed) is delivered as PointerHoverEvent,
    // not PointerMoveEvent. Forward it as MOVE so engine hover highlight updates.
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

  void _onPointerCancel(PointerCancelEvent event) {
    if (_editCommitReplayActive) {
      _deferredPointerCompletionAfterEditCommit =
          _DeferredPointerCompletion.cancel(event);
      return;
    }
    _dispatchPointerCompletion(_DeferredPointerCompletion.cancel(event));
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
      final rows = await widget.controller.rowCount();
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

        final currentEditSessionToken = _editSessionToken;
        final currentEditRow = _editRow;
        final currentEditCol = _editCol;

        return Focus(
          focusNode: _gridFocusNode,
          autofocus: true,
          onKeyEvent: _onGridFocusKeyEvent,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: ClipRect(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerUp: _onPointerUp,
                onPointerMove: _onPointerMove,
                onPointerHover: _onPointerHover,
                onPointerCancel: _onPointerCancel,
                onPointerSignal: _onPointerSignal,
                onPointerPanZoomStart: _onPointerPanZoomStart,
                onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
                onPointerPanZoomEnd: _onPointerPanZoomEnd,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -1000,
                      top: -1000,
                      width: 1,
                      height: 1,
                      child: IgnorePointer(
                        ignoring: true,
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: _imeProxyController,
                            focusNode: _imeProxyFocusNode,
                            decoration:
                                const InputDecoration.collapsed(hintText: ''),
                            style: const TextStyle(
                              fontSize: 1,
                              color: Colors.transparent,
                            ),
                            cursorColor: Colors.transparent,
                            autocorrect: false,
                            enableSuggestions: false,
                            enableInteractiveSelection: false,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),

                    // Current Flutter path: decode native RGBA frames and
                    // show via RawImage.  A platform texture path can be
                    // added separately.
                    SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: ClipRect(
                        child: _gesturePreviewActive
                            ? Transform(
                                transform: Matrix4.identity()
                                  ..translate(
                                    _gesturePreviewPan.dx +
                                        _gesturePreviewFocal.dx,
                                    _gesturePreviewPan.dy +
                                        _gesturePreviewFocal.dy,
                                  )
                                  ..scale(_gesturePreviewScale,
                                      _gesturePreviewScale)
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
                        child: IgnorePointer(
                          ignoring: !_editOverlayVisible,
                          child: Opacity(
                            opacity: _editOverlayVisible ? 1 : 0,
                            child: Material(
                              elevation: 2,
                              child: Focus(
                                onKeyEvent: _onEditOverlayKeyEvent,
                                child: TextField(
                                  controller: _editTextController,
                                  focusNode: _editFocusNode,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: _editPadding,
                                    border: InputBorder.none,
                                  ),
                                  style: TextStyle(
                                    fontSize: _editFontSize,
                                    height: 1.0,
                                    fontFamily: _editFontFamily,
                                    fontWeight: _editFontBold
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontStyle: _editFontItalic
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                  textAlignVertical: TextAlignVertical.center,
                                  maxLines: 1,
                                  onSubmitted: (_) =>
                                      _commitEditIfSessionCurrent(
                                    currentEditSessionToken,
                                    currentEditRow,
                                    currentEditCol,
                                  ),
                                  onTapOutside: (_) =>
                                      _commitEditIfSessionCurrent(
                                    currentEditSessionToken,
                                    currentEditRow,
                                    currentEditCol,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
