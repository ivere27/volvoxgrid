/// VolvoxGrid FFI bindings -- loads the native library and re-exports the
/// generated protobuf service client and messages.
///
/// The generated files live under `lib/src/generated/` and are produced by
/// `protoc` (for `volvoxgrid.pb.dart`) and `protoc-gen-synurang-ffi` (for
/// `volvoxgrid_ffi.pb.dart`).  Both are re-exported here so that downstream
/// code only needs:
///
/// ```dart
/// import 'package:volvoxgrid/volvoxgrid_ffi.dart';
/// ```
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ffi' as ffi;
import 'dart:io' show Directory, File, Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:protobuf/protobuf.dart' show GeneratedMessage;
import 'package:synurang/synurang.dart' as synurang;

import 'src/generated/volvoxgrid.pb.dart';

// Re-export generated protobuf messages and the FFI service client.
export 'src/generated/volvoxgrid.pb.dart';
export 'src/generated/volvoxgrid_ffi.pb.dart';

typedef _MessageDecoder<T> = T Function(List<int> bytes);

abstract class _VolvoxGridTransport {
  Future<Uint8List> invokeUnary(String method, Uint8List data);
  Stream<Uint8List> invokeServerStream(String method, Uint8List data);
  Stream<Uint8List> invokeBidiStream(String method, Stream<Uint8List> data);
}

class _SynurangVolvoxGridTransport implements _VolvoxGridTransport {
  const _SynurangVolvoxGridTransport();

  @override
  Future<Uint8List> invokeUnary(String method, Uint8List data) {
    return synurang.invokeBackendAsync(method, data);
  }

  @override
  Stream<Uint8List> invokeServerStream(String method, Uint8List data) {
    return synurang.invokeBackendServerStream(method, data);
  }

  @override
  Stream<Uint8List> invokeBidiStream(String method, Stream<Uint8List> data) {
    return synurang.invokeBackendBidiStream(method, data);
  }
}

class _NativeLibrarySpec {
  final String? path;

  const _NativeLibrarySpec.process() : path = null;
  const _NativeLibrarySpec.open(this.path);

  ffi.DynamicLibrary open() {
    final libraryPath = path;
    return libraryPath == null
        ? ffi.DynamicLibrary.process()
        : ffi.DynamicLibrary.open(libraryPath);
  }
}

typedef _NativeInvoke = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
  ffi.Pointer<ffi.Int32>,
);
typedef _DartInvoke = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  int,
  ffi.Pointer<ffi.Int32>,
);

typedef _NativeFree = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _DartFree = void Function(ffi.Pointer<ffi.Void>);

typedef _NativeStreamOpen = ffi.Uint64 Function(ffi.Pointer<ffi.Char>);
typedef _DartStreamOpen = int Function(ffi.Pointer<ffi.Char>);

typedef _NativeStreamSend = ffi.Int32 Function(
  ffi.Uint64,
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
);
typedef _DartStreamSend = int Function(
  int,
  ffi.Pointer<ffi.Char>,
  int,
);

typedef _NativeStreamRecv = ffi.Pointer<ffi.Char> Function(
  ffi.Uint64,
  ffi.Pointer<ffi.Int32>,
  ffi.Pointer<ffi.Int32>,
);
typedef _DartStreamRecv = ffi.Pointer<ffi.Char> Function(
  int,
  ffi.Pointer<ffi.Int32>,
  ffi.Pointer<ffi.Int32>,
);

typedef _NativeStreamCloseSend = ffi.Void Function(ffi.Uint64);
typedef _DartStreamCloseSend = void Function(int);

typedef _NativeStreamClose = ffi.Void Function(ffi.Uint64);
typedef _DartStreamClose = void Function(int);

class _NativeVolvoxGridSymbols {
  final _DartInvoke invoke;
  final _DartFree free;
  final _DartStreamOpen streamOpen;
  final _DartStreamSend streamSend;
  final _DartStreamRecv streamRecv;
  final _DartStreamCloseSend streamCloseSend;
  final _DartStreamClose streamClose;

  _NativeVolvoxGridSymbols._({
    required this.invoke,
    required this.free,
    required this.streamOpen,
    required this.streamSend,
    required this.streamRecv,
    required this.streamCloseSend,
    required this.streamClose,
  });

  factory _NativeVolvoxGridSymbols.open(_NativeLibrarySpec spec) {
    final library = spec.open();
    return _NativeVolvoxGridSymbols._(
      invoke: library.lookupFunction<_NativeInvoke, _DartInvoke>(
        'Synurang_Invoke_VolvoxGridService',
      ),
      free: library.lookupFunction<_NativeFree, _DartFree>('Synurang_Free'),
      streamOpen: library.lookupFunction<_NativeStreamOpen, _DartStreamOpen>(
        'Synurang_Stream_VolvoxGridService_Open',
      ),
      streamSend: library.lookupFunction<_NativeStreamSend, _DartStreamSend>(
        'Synurang_Stream_Send',
      ),
      streamRecv: library.lookupFunction<_NativeStreamRecv, _DartStreamRecv>(
        'Synurang_Stream_Recv',
      ),
      streamCloseSend:
          library.lookupFunction<_NativeStreamCloseSend, _DartStreamCloseSend>(
              'Synurang_Stream_CloseSend'),
      streamClose: library.lookupFunction<_NativeStreamClose, _DartStreamClose>(
          'Synurang_Stream_Close'),
    );
  }
}

class _NativeVolvoxGridTransport implements _VolvoxGridTransport {
  final _NativeLibrarySpec _spec;
  final _NativeVolvoxGridSymbols _symbols;

  _NativeVolvoxGridTransport._(this._spec, this._symbols);

  factory _NativeVolvoxGridTransport.open(_NativeLibrarySpec spec) {
    return _NativeVolvoxGridTransport._(
      spec,
      _NativeVolvoxGridSymbols.open(spec),
    );
  }

  @override
  Future<Uint8List> invokeUnary(String method, Uint8List data) {
    return Future<Uint8List>.value(_invokeNativeUnary(_symbols, method, data));
  }

  @override
  Stream<Uint8List> invokeServerStream(String method, Uint8List data) {
    return _NativeVolvoxGridStream(_spec, _symbols, method, initialData: data)
        .stream;
  }

  @override
  Stream<Uint8List> invokeBidiStream(String method, Stream<Uint8List> data) {
    return _NativeVolvoxGridStream(_spec, _symbols, method, input: data).stream;
  }
}

_VolvoxGridTransport? _transport;
const _synurangTransport = _SynurangVolvoxGridTransport();

_VolvoxGridTransport get _activeTransport => _transport ?? _synurangTransport;

Uint8List _copyNativeBytes(ffi.Pointer<ffi.Char> ptr, int length) {
  if (ptr == ffi.nullptr || length <= 0) {
    return Uint8List(0);
  }
  return Uint8List.fromList(ptr.cast<ffi.Uint8>().asTypedList(length));
}

ffi.Pointer<ffi.Char> _copyBytesToNative(Uint8List bytes) {
  if (bytes.isEmpty) {
    return ffi.nullptr.cast<ffi.Char>();
  }
  final ptr = calloc<ffi.Uint8>(bytes.length);
  ptr.asTypedList(bytes.length).setAll(0, bytes);
  return ptr.cast<ffi.Char>();
}

Uint8List _invokeNativeUnary(
  _NativeVolvoxGridSymbols symbols,
  String method,
  Uint8List data,
) {
  final methodPtr = method.toNativeUtf8(allocator: calloc).cast<ffi.Char>();
  final dataPtr = _copyBytesToNative(data);
  final responseLengthPtr = calloc<ffi.Int32>();

  try {
    final resultPtr =
        symbols.invoke(methodPtr, dataPtr, data.length, responseLengthPtr);
    final responseLength = responseLengthPtr.value;

    if (resultPtr == ffi.nullptr) {
      if (responseLength == 0) {
        return Uint8List(0);
      }
      throw const synurang.FfiError('VolvoxGrid returned null', 2);
    }

    try {
      if (responseLength < 0) {
        final errorBytes = _copyNativeBytes(resultPtr, -responseLength);
        throw synurang.FfiError.fromBuffer(errorBytes);
      }
      return _copyNativeBytes(resultPtr, responseLength);
    } finally {
      symbols.free(resultPtr.cast<ffi.Void>());
    }
  } finally {
    calloc.free(methodPtr);
    if (dataPtr != ffi.nullptr) {
      calloc.free(dataPtr);
    }
    calloc.free(responseLengthPtr);
  }
}

const _nativeStreamOpened = 0;
const _nativeStreamData = 1;
const _nativeStreamEnd = 2;
const _nativeStreamError = 3;

class _NativeVolvoxGridStream {
  final _NativeLibrarySpec _spec;
  final _NativeVolvoxGridSymbols _symbols;
  final String _method;
  final Uint8List? _initialData;
  final Stream<Uint8List>? _input;
  final StreamController<Uint8List> _controller = StreamController<Uint8List>();
  final ReceivePort _receivePort = ReceivePort();

  Isolate? _isolate;
  int? _handle;
  bool _closed = false;

  _NativeVolvoxGridStream(
    this._spec,
    this._symbols,
    this._method, {
    Uint8List? initialData,
    Stream<Uint8List>? input,
  })  : _initialData = initialData,
        _input = input {
    _controller
      ..onListen = () {
        unawaited(_start());
      }
      ..onCancel = _close;
  }

  Stream<Uint8List> get stream => _controller.stream;

  Future<void> _start() async {
    _receivePort.listen(_handleWorkerMessage);
    try {
      final isolate = await Isolate.spawn<List<Object?>>(
        _nativeStreamWorkerMain,
        <Object?>[_receivePort.sendPort, _spec.path, _method],
      );
      if (_closed) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
    } catch (error, stackTrace) {
      _addError(error, stackTrace);
      await _close();
    }
  }

  void _handleWorkerMessage(Object? message) {
    if (_closed || message is! List<Object?> || message.isEmpty) {
      return;
    }

    switch (message[0]) {
      case _nativeStreamOpened:
        final handle = message[1] as int;
        if (handle == 0) {
          _addError(Exception('Failed to start VolvoxGrid stream'));
          unawaited(_close());
          return;
        }
        _handle = handle;
        final initialData = _initialData;
        if (initialData != null) {
          _send(handle, initialData);
        }
        final input = _input;
        if (input != null) {
          unawaited(_sendInput(handle, input));
        }
        break;
      case _nativeStreamData:
        _controller.add(message[1] as Uint8List);
        break;
      case _nativeStreamEnd:
        unawaited(_finish());
        break;
      case _nativeStreamError:
        final payload = message[1];
        if (payload is Uint8List) {
          _addError(_tryDecodeFfiError(payload) ??
              Exception('VolvoxGrid stream error: ${_bytePreview(payload)}'));
        } else {
          _addError(Exception(payload.toString()));
        }
        unawaited(_close());
        break;
    }
  }

  void _send(int handle, Uint8List data) {
    final dataPtr = _copyBytesToNative(data);
    try {
      final result = _symbols.streamSend(handle, dataPtr, data.length);
      if (result != 0) {
        throw Exception('VolvoxGrid stream send failed: $result');
      }
    } finally {
      if (dataPtr != ffi.nullptr) {
        calloc.free(dataPtr);
      }
    }
  }

  Future<void> _sendInput(int handle, Stream<Uint8List> input) async {
    try {
      await for (final data in input) {
        if (_closed) {
          return;
        }
        _send(handle, data);
      }
      if (!_closed) {
        _symbols.streamCloseSend(handle);
      }
    } catch (error, stackTrace) {
      _addError(error, stackTrace);
      await _close();
    }
  }

  Future<void> _finish() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _receivePort.close();
    await _controller.close();
  }

  Future<void> _close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    final handle = _handle;
    if (handle != null) {
      try {
        _symbols.streamClose(handle);
      } catch (_) {
        // Ignore close races with the worker's own stream cleanup.
      }
    }
    _receivePort.close();
    _isolate?.kill(priority: Isolate.immediate);
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  void _addError(Object error, [StackTrace? stackTrace]) {
    if (!_closed && !_controller.isClosed) {
      _controller.addError(error, stackTrace);
    }
  }
}

void _nativeStreamWorkerMain(List<Object?> args) {
  final replyTo = args[0] as SendPort;
  final libraryPath = args[1] as String?;
  final method = args[2] as String;
  final spec = libraryPath == null
      ? const _NativeLibrarySpec.process()
      : _NativeLibrarySpec.open(libraryPath);

  _NativeVolvoxGridSymbols? symbols;
  int handle = 0;
  final responseLengthPtr = calloc<ffi.Int32>();
  final statusPtr = calloc<ffi.Int32>();

  try {
    symbols = _NativeVolvoxGridSymbols.open(spec);
    final methodPtr = method.toNativeUtf8(allocator: calloc).cast<ffi.Char>();
    try {
      handle = symbols.streamOpen(methodPtr);
    } finally {
      calloc.free(methodPtr);
    }

    replyTo.send(<Object?>[_nativeStreamOpened, handle]);
    if (handle == 0) {
      return;
    }

    while (true) {
      final dataPtr = symbols.streamRecv(handle, responseLengthPtr, statusPtr);
      final responseLength = responseLengthPtr.value;
      final status = statusPtr.value;

      if (status == 1) {
        if (dataPtr != ffi.nullptr) {
          symbols.free(dataPtr.cast<ffi.Void>());
        }
        replyTo.send(<Object?>[_nativeStreamEnd]);
        return;
      }

      if (status < 0) {
        final errorBytes = _copyNativeBytes(dataPtr, responseLength);
        if (dataPtr != ffi.nullptr) {
          symbols.free(dataPtr.cast<ffi.Void>());
        }
        replyTo.send(<Object?>[_nativeStreamError, errorBytes]);
        return;
      }

      if (status != 0) {
        if (dataPtr != ffi.nullptr) {
          symbols.free(dataPtr.cast<ffi.Void>());
        }
        replyTo.send(<Object?>[
          _nativeStreamError,
          'unexpected VolvoxGrid stream status $status',
        ]);
        return;
      }

      final payload = _copyNativeBytes(dataPtr, responseLength);
      if (dataPtr != ffi.nullptr) {
        symbols.free(dataPtr.cast<ffi.Void>());
      }
      replyTo.send(<Object?>[_nativeStreamData, payload]);
    }
  } catch (error) {
    replyTo.send(<Object?>[_nativeStreamError, error.toString()]);
  } finally {
    calloc.free(responseLengthPtr);
    calloc.free(statusPtr);
    if (handle != 0 && symbols != null) {
      try {
        symbols.streamClose(handle);
      } catch (_) {
        // Best-effort cleanup from a worker isolate.
      }
    }
  }
}

String _serviceMethodPath(String method) =>
    '/volvoxgrid.v1.VolvoxGridService/$method';

Uint8List _serializeMessage(GeneratedMessage message) {
  return message.writeToBuffer();
}

String _bytePreview(Uint8List bytes, {int maxBytes = 24}) {
  final limit = bytes.length < maxBytes ? bytes.length : maxBytes;
  final hex = bytes
      .take(limit)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(' ');
  final suffix = bytes.length > limit ? ' ...' : '';
  return '$hex$suffix';
}

bool _isEmptyFfiErrorSentinel(Uint8List bytes) =>
    bytes.length == 2 && bytes[0] == 0x12 && bytes[1] == 0x00;

bool _looksLikeTextError(Uint8List bytes) {
  if (bytes.isEmpty) {
    return false;
  }

  var printable = 0;
  for (final byte in bytes) {
    final isWhitespace =
        byte == 0x09 || byte == 0x0a || byte == 0x0d || byte == 0x20;
    final isAsciiPrintable = byte >= 0x21 && byte <= 0x7e;
    if (isWhitespace || isAsciiPrintable) {
      printable++;
      continue;
    }
    if (byte == 0x00) {
      return false;
    }
  }

  return printable * 5 >= bytes.length * 4;
}

void _logDecodeFailure(
  String method,
  Uint8List bytes,
  Object error,
  synurang.FfiError? ffiError,
) {
  final details = ffiError == null
      ? 'decode_error=$error'
      : 'ffi_error=${ffiError.message} grpc=${ffiError.grpcCode} code=${ffiError.code}';
  developer.log(
    'VolvoxGrid decode failure method=$method bytes=${bytes.length} '
    'preview=${_bytePreview(bytes)} $details',
    name: 'volvoxgrid.ffi',
    error: error,
  );
}

T _decodeMessage<T>(
  String method,
  Uint8List bytes,
  _MessageDecoder<T> decode,
) {
  try {
    return decode(bytes);
  } catch (error, stackTrace) {
    final ffiError = _tryDecodeFfiError(bytes);
    _logDecodeFailure(method, bytes, error, ffiError);
    if (ffiError != null) {
      Error.throwWithStackTrace(ffiError, stackTrace);
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

synurang.FfiError? _tryDecodeFfiError(Uint8List bytes) {
  if (bytes.isEmpty) {
    return null;
  }

  try {
    final error = synurang.Error.fromBuffer(bytes);
    final hasKnownFields = error.message.isNotEmpty ||
        error.grpcCode != 0 ||
        error.code != 0 ||
        _isEmptyFfiErrorSentinel(bytes);
    if (!hasKnownFields) {
      return _looksLikeTextError(bytes)
          ? synurang.FfiError.fromBuffer(bytes)
          : null;
    }
    return synurang.FfiError.fromBuffer(bytes);
  } catch (_) {
    return _looksLikeTextError(bytes)
        ? synurang.FfiError.fromBuffer(bytes)
        : null;
  }
}

Future<T> _invokeUnary<T>(
  String method,
  GeneratedMessage request,
  _MessageDecoder<T> decode,
) async {
  final resultBytes = await _activeTransport.invokeUnary(
    method,
    _serializeMessage(request),
  );
  return _decodeMessage(method, resultBytes, decode);
}

Stream<T> _invokeServerStream<T>(
  String method,
  GeneratedMessage request,
  _MessageDecoder<T> decode,
) {
  return _activeTransport
      .invokeServerStream(method, _serializeMessage(request))
      .map((data) => _decodeMessage(method, data, decode));
}

Stream<TOut> _invokeBidiStream<TIn extends GeneratedMessage, TOut>(
  String method,
  Stream<TIn> requests,
  _MessageDecoder<TOut> decode,
) {
  return _activeTransport
      .invokeBidiStream(
        method,
        requests.map((request) => _serializeMessage(request)),
      )
      .map((data) => _decodeMessage(method, data, decode));
}

/// Handwritten wrapper over the generated Synurang transport output.
///
/// This keeps generated files untouched while allowing us to normalize
/// protobuf decode failures into [synurang.FfiError] when the backend
/// actually returned a serialized `core.v1.Error`.
class VolvoxGridService {
  static Future<CreateResponse> Create(CreateRequest request) => _invokeUnary(
        _serviceMethodPath('Create'),
        request,
        CreateResponse.fromBuffer,
      );

  static Future<DestroyResponse> Destroy(DestroyRequest request) =>
      _invokeUnary(
        _serviceMethodPath('Destroy'),
        request,
        DestroyResponse.fromBuffer,
      );

  static Future<ConfigureResponse> Configure(ConfigureRequest request) =>
      _invokeUnary(
        _serviceMethodPath('Configure'),
        request,
        ConfigureResponse.fromBuffer,
      );

  static Future<GridConfig> GetConfig(GetConfigRequest request) => _invokeUnary(
        _serviceMethodPath('GetConfig'),
        request,
        GridConfig.fromBuffer,
      );

  static Future<LoadFontDataResponse> LoadFontData(
          LoadFontDataRequest request) =>
      _invokeUnary(
        _serviceMethodPath('LoadFontData'),
        request,
        LoadFontDataResponse.fromBuffer,
      );

  static Future<DefineColumnsResponse> DefineColumns(
          DefineColumnsRequest request) =>
      _invokeUnary(
        _serviceMethodPath('DefineColumns'),
        request,
        DefineColumnsResponse.fromBuffer,
      );

  static Future<SchemaResponse> GetSchema(GetSchemaRequest request) =>
      _invokeUnary(
        _serviceMethodPath('GetSchema'),
        request,
        SchemaResponse.fromBuffer,
      );

  static Future<DefineRowsResponse> DefineRows(DefineRowsRequest request) =>
      _invokeUnary(
        _serviceMethodPath('DefineRows'),
        request,
        DefineRowsResponse.fromBuffer,
      );

  static Future<InsertRowsResponse> InsertRows(InsertRowsRequest request) =>
      _invokeUnary(
        _serviceMethodPath('InsertRows'),
        request,
        InsertRowsResponse.fromBuffer,
      );

  static Future<RemoveRowsResponse> RemoveRows(RemoveRowsRequest request) =>
      _invokeUnary(
        _serviceMethodPath('RemoveRows'),
        request,
        RemoveRowsResponse.fromBuffer,
      );

  static Future<MoveColumnResponse> MoveColumn(MoveColumnRequest request) =>
      _invokeUnary(
        _serviceMethodPath('MoveColumn'),
        request,
        MoveColumnResponse.fromBuffer,
      );

  static Future<MoveRowResponse> MoveRow(MoveRowRequest request) =>
      _invokeUnary(
        _serviceMethodPath('MoveRow'),
        request,
        MoveRowResponse.fromBuffer,
      );

  static Future<WriteResult> UpdateCells(UpdateCellsRequest request) =>
      _invokeUnary(
        _serviceMethodPath('UpdateCells'),
        request,
        WriteResult.fromBuffer,
      );

  static Future<CellsResponse> GetCells(GetCellsRequest request) =>
      _invokeUnary(
        _serviceMethodPath('GetCells'),
        request,
        CellsResponse.fromBuffer,
      );

  static Future<WriteResult> LoadTable(LoadTableRequest request) =>
      _invokeUnary(
        _serviceMethodPath('LoadTable'),
        request,
        WriteResult.fromBuffer,
      );

  static Future<ClearResponse> Clear(ClearRequest request) => _invokeUnary(
        _serviceMethodPath('Clear'),
        request,
        ClearResponse.fromBuffer,
      );

  static Future<SelectResponse> Select(SelectRequest request) => _invokeUnary(
        _serviceMethodPath('Select'),
        request,
        SelectResponse.fromBuffer,
      );

  static Future<SelectionState> GetSelection(GetSelectionRequest request) =>
      _invokeUnary(
        _serviceMethodPath('GetSelection'),
        request,
        SelectionState.fromBuffer,
      );

  static Future<ShowCellResponse> ShowCell(ShowCellRequest request) =>
      _invokeUnary(
        _serviceMethodPath('ShowCell'),
        request,
        ShowCellResponse.fromBuffer,
      );

  static Future<SetTopRowResponse> SetTopRow(SetRowRequest request) =>
      _invokeUnary(
        _serviceMethodPath('SetTopRow'),
        request,
        SetTopRowResponse.fromBuffer,
      );

  static Future<SetLeftColResponse> SetLeftCol(SetColRequest request) =>
      _invokeUnary(
        _serviceMethodPath('SetLeftCol'),
        request,
        SetLeftColResponse.fromBuffer,
      );

  static Future<EditState> Edit(EditCommand request) => _invokeUnary(
        _serviceMethodPath('Edit'),
        request,
        EditState.fromBuffer,
      );

  static Future<SortResponse> Sort(SortRequest request) => _invokeUnary(
        _serviceMethodPath('Sort'),
        request,
        SortResponse.fromBuffer,
      );

  static Future<SubtotalResult> Subtotal(SubtotalRequest request) =>
      _invokeUnary(
        _serviceMethodPath('Subtotal'),
        request,
        SubtotalResult.fromBuffer,
      );

  static Future<AutoSizeResponse> AutoSize(AutoSizeRequest request) =>
      _invokeUnary(
        _serviceMethodPath('AutoSize'),
        request,
        AutoSizeResponse.fromBuffer,
      );

  static Future<OutlineResponse> Outline(OutlineRequest request) =>
      _invokeUnary(
        _serviceMethodPath('Outline'),
        request,
        OutlineResponse.fromBuffer,
      );

  static Future<NodeInfo> GetNode(GetNodeRequest request) => _invokeUnary(
        _serviceMethodPath('GetNode'),
        request,
        NodeInfo.fromBuffer,
      );

  static Future<FindResponse> Find(FindRequest request) => _invokeUnary(
        _serviceMethodPath('Find'),
        request,
        FindResponse.fromBuffer,
      );

  static Future<AggregateResponse> Aggregate(AggregateRequest request) =>
      _invokeUnary(
        _serviceMethodPath('Aggregate'),
        request,
        AggregateResponse.fromBuffer,
      );

  static Future<CellRange> GetMergedRange(GetMergedRangeRequest request) =>
      _invokeUnary(
        _serviceMethodPath('GetMergedRange'),
        request,
        CellRange.fromBuffer,
      );

  static Future<MergeCellsResponse> MergeCells(MergeCellsRequest request) =>
      _invokeUnary(
        _serviceMethodPath('MergeCells'),
        request,
        MergeCellsResponse.fromBuffer,
      );

  static Future<UnmergeCellsResponse> UnmergeCells(
          UnmergeCellsRequest request) =>
      _invokeUnary(
        _serviceMethodPath('UnmergeCells'),
        request,
        UnmergeCellsResponse.fromBuffer,
      );

  static Future<MergedRegionsResponse> GetMergedRegions(
          GetMergedRegionsRequest request) =>
      _invokeUnary(
        _serviceMethodPath('GetMergedRegions'),
        request,
        MergedRegionsResponse.fromBuffer,
      );

  static Future<MemoryUsageResponse> GetMemoryUsage(
          GetMemoryUsageRequest request) =>
      _invokeUnary(
        _serviceMethodPath('GetMemoryUsage'),
        request,
        MemoryUsageResponse.fromBuffer,
      );

  static Future<ClipboardResponse> Clipboard(ClipboardCommand request) =>
      _invokeUnary(
        _serviceMethodPath('Clipboard'),
        request,
        ClipboardResponse.fromBuffer,
      );

  static Future<ExportResponse> Export(ExportRequest request) => _invokeUnary(
        _serviceMethodPath('Export'),
        request,
        ExportResponse.fromBuffer,
      );

  static Future<LoadDataResult> LoadData(LoadDataRequest request) =>
      _invokeUnary(
        _serviceMethodPath('LoadData'),
        request,
        LoadDataResult.fromBuffer,
      );

  static Future<LoadDataResult> AppendData(AppendDataRequest request) =>
      _invokeUnary(
        _serviceMethodPath('AppendData'),
        request,
        LoadDataResult.fromBuffer,
      );

  static Future<PrintResponse> Print(PrintRequest request) => _invokeUnary(
        _serviceMethodPath('Print'),
        request,
        PrintResponse.fromBuffer,
      );

  static Future<ArchiveResponse> Archive(ArchiveRequest request) =>
      _invokeUnary(
        _serviceMethodPath('Archive'),
        request,
        ArchiveResponse.fromBuffer,
      );

  static Future<ResizeViewportResponse> ResizeViewport(
          ResizeViewportRequest request) =>
      _invokeUnary(
        _serviceMethodPath('ResizeViewport'),
        request,
        ResizeViewportResponse.fromBuffer,
      );

  static Future<SetRedrawResponse> SetRedraw(SetRedrawRequest request) =>
      _invokeUnary(
        _serviceMethodPath('SetRedraw'),
        request,
        SetRedrawResponse.fromBuffer,
      );

  static Future<RefreshResponse> Refresh(RefreshRequest request) =>
      _invokeUnary(
        _serviceMethodPath('Refresh'),
        request,
        RefreshResponse.fromBuffer,
      );

  static Future<LoadDemoResponse> LoadDemo(LoadDemoRequest request) =>
      _invokeUnary(
        _serviceMethodPath('LoadDemo'),
        request,
        LoadDemoResponse.fromBuffer,
      );

  static Future<GetDemoDataResponse> GetDemoData(GetDemoDataRequest request) =>
      _invokeUnary(
        _serviceMethodPath('GetDemoData'),
        request,
        GetDemoDataResponse.fromBuffer,
      );

  static Stream<RenderOutput> RenderSession(Stream<RenderInput> requests) =>
      _invokeBidiStream(
        _serviceMethodPath('RenderSession'),
        requests,
        RenderOutput.fromBuffer,
      );

  static Stream<GridEvent> EventStream(EventStreamRequest request) =>
      _invokeServerStream(
        _serviceMethodPath('EventStream'),
        request,
        GridEvent.fromBuffer,
      );
}

/// Initialize the VolvoxGrid FFI runtime.
///
/// Call this once at app startup, before any grid operations:
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await initVolvoxGrid();
///   runApp(const MyApp());
/// }
/// ```
String _defaultLibraryFileName() {
  if (Platform.isAndroid || Platform.isLinux) {
    return 'libvolvoxgrid.so';
  }
  if (Platform.isMacOS) {
    return 'libvolvoxgrid.dylib';
  }
  if (Platform.isWindows) {
    return 'volvoxgrid.dll';
  }
  if (Platform.isIOS) {
    return 'VolvoxGrid.framework/VolvoxGrid';
  }
  return 'libvolvoxgrid.so';
}

bool _looksLikeLibraryPath(String value) {
  return value.contains('/') ||
      value.contains('\\') ||
      value.endsWith('.so') ||
      value.endsWith('.dylib') ||
      value.endsWith('.dll') ||
      value.contains('.framework/');
}

Iterable<String> _searchRoots() sync* {
  final seen = <String>{};
  final roots = <String>[];

  void walk(Directory start) {
    Directory? current = start.absolute;
    while (current != null) {
      if (seen.add(current.path)) {
        roots.add(current.path);
      }
      final parent = current.parent;
      current = parent.path == current.path ? null : parent;
    }
  }

  walk(Directory.current);
  walk(File(Platform.resolvedExecutable).absolute.parent);
  yield* roots;
}

Iterable<String> _candidateLibraryPaths(String fileName) sync* {
  final seen = <String>{};
  final separator = Platform.pathSeparator;

  String join(String root, String suffix) => '$root$separator$suffix';

  final candidates = <String>[];

  void add(String candidate) {
    if (candidate.isNotEmpty && seen.add(candidate)) {
      candidates.add(candidate);
    }
  }

  void addExistingPath(String candidate) {
    if (File(candidate).existsSync()) {
      add(candidate);
    }
  }

  final envPath = Platform.environment['VOLVOXGRID_LIBRARY_PATH']?.trim();
  if (envPath != null && envPath.isNotEmpty) {
    add(envPath);
  }

  for (final root in _searchRoots()) {
    addExistingPath(join(root, fileName));
    addExistingPath(join(root, 'Frameworks${separator}$fileName'));
    addExistingPath(
        join(root, 'Contents${separator}Frameworks${separator}$fileName'));
    addExistingPath(join(root, 'target${separator}debug${separator}$fileName'));
    addExistingPath(
        join(root, 'target${separator}release${separator}$fileName'));
    addExistingPath(join(root,
        'target${separator}x86_64-unknown-linux-gnu${separator}debug${separator}$fileName'));
    addExistingPath(join(root,
        'target${separator}x86_64-unknown-linux-gnu${separator}release${separator}$fileName'));
  }

  add(fileName);

  if (Platform.isAndroid && fileName != 'libvolvoxgrid.so') {
    add('libvolvoxgrid.so');
  }

  yield* candidates;
}

Future<void> initVolvoxGrid({String? libraryName}) {
  final raw = libraryName?.trim();
  final hasRaw = raw != null && raw.isNotEmpty;

  if (Platform.isIOS && !hasRaw) {
    _transport = _NativeVolvoxGridTransport.open(
      const _NativeLibrarySpec.process(),
    );
    return Future<void>.value();
  }

  final treatAsPath = hasRaw && _looksLikeLibraryPath(raw);
  final effectivePath = treatAsPath ? raw : _defaultLibraryFileName();
  final candidates = treatAsPath
      ? <String>[effectivePath]
      : _candidateLibraryPaths(effectivePath).toList(growable: false);

  Object? lastError;
  StackTrace? lastStackTrace;
  for (final candidate in candidates) {
    try {
      synurang.registerPlugin(candidate, ['VolvoxGridService']);
      _transport = _synurangTransport;
      return Future<void>.value();
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
    }
  }

  if (lastError != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace ?? StackTrace.current);
  }
  return Future<void>.value();
}
