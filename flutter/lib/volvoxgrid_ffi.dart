/// VolvoxGrid FFI bindings -- loads the native plugin and re-exports the
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
import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:protobuf/protobuf.dart' show GeneratedMessage;
import 'package:synurang/synurang.dart' as synurang;

import 'src/generated/volvoxgrid.pb.dart';

// Re-export generated protobuf messages and the FFI service client.
export 'src/generated/volvoxgrid.pb.dart';
export 'src/generated/volvoxgrid_ffi.pb.dart';

typedef _MessageDecoder<T> = T Function(List<int> bytes);

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
  final resultBytes = await synurang.invokeBackendAsync(
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
  return synurang
      .invokeBackendServerStream(method, _serializeMessage(request))
      .map((data) => _decodeMessage(method, data, decode));
}

Stream<TOut> _invokeBidiStream<TIn extends GeneratedMessage, TOut>(
  String method,
  Stream<TIn> requests,
  _MessageDecoder<TOut> decode,
) {
  return synurang
      .invokeBackendBidiStream(
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

  static Future<Empty> Destroy(GridHandle request) => _invokeUnary(
        _serviceMethodPath('Destroy'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> Configure(ConfigureRequest request) => _invokeUnary(
        _serviceMethodPath('Configure'),
        request,
        Empty.fromBuffer,
      );

  static Future<GridConfig> GetConfig(GridHandle request) => _invokeUnary(
        _serviceMethodPath('GetConfig'),
        request,
        GridConfig.fromBuffer,
      );

  static Future<Empty> LoadFontData(LoadFontDataRequest request) =>
      _invokeUnary(
        _serviceMethodPath('LoadFontData'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> DefineColumns(DefineColumnsRequest request) =>
      _invokeUnary(
        _serviceMethodPath('DefineColumns'),
        request,
        Empty.fromBuffer,
      );

  static Future<DefineColumnsRequest> GetSchema(GridHandle request) =>
      _invokeUnary(
        _serviceMethodPath('GetSchema'),
        request,
        DefineColumnsRequest.fromBuffer,
      );

  static Future<Empty> DefineRows(DefineRowsRequest request) => _invokeUnary(
        _serviceMethodPath('DefineRows'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> InsertRows(InsertRowsRequest request) => _invokeUnary(
        _serviceMethodPath('InsertRows'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> RemoveRows(RemoveRowsRequest request) => _invokeUnary(
        _serviceMethodPath('RemoveRows'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> MoveColumn(MoveColumnRequest request) => _invokeUnary(
        _serviceMethodPath('MoveColumn'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> MoveRow(MoveRowRequest request) => _invokeUnary(
        _serviceMethodPath('MoveRow'),
        request,
        Empty.fromBuffer,
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

  static Future<Empty> Clear(ClearRequest request) => _invokeUnary(
        _serviceMethodPath('Clear'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> Select(SelectRequest request) => _invokeUnary(
        _serviceMethodPath('Select'),
        request,
        Empty.fromBuffer,
      );

  static Future<SelectionState> GetSelection(GridHandle request) =>
      _invokeUnary(
        _serviceMethodPath('GetSelection'),
        request,
        SelectionState.fromBuffer,
      );

  static Future<Empty> ShowCell(ShowCellRequest request) => _invokeUnary(
        _serviceMethodPath('ShowCell'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> SetTopRow(SetRowRequest request) => _invokeUnary(
        _serviceMethodPath('SetTopRow'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> SetLeftCol(SetColRequest request) => _invokeUnary(
        _serviceMethodPath('SetLeftCol'),
        request,
        Empty.fromBuffer,
      );

  static Future<EditState> Edit(EditCommand request) => _invokeUnary(
        _serviceMethodPath('Edit'),
        request,
        EditState.fromBuffer,
      );

  static Future<Empty> Sort(SortRequest request) => _invokeUnary(
        _serviceMethodPath('Sort'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> Subtotal(SubtotalRequest request) => _invokeUnary(
        _serviceMethodPath('Subtotal'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> AutoSize(AutoSizeRequest request) => _invokeUnary(
        _serviceMethodPath('AutoSize'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> Outline(OutlineRequest request) => _invokeUnary(
        _serviceMethodPath('Outline'),
        request,
        Empty.fromBuffer,
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

  static Future<Empty> MergeCells(MergeCellsRequest request) => _invokeUnary(
        _serviceMethodPath('MergeCells'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> UnmergeCells(UnmergeCellsRequest request) =>
      _invokeUnary(
        _serviceMethodPath('UnmergeCells'),
        request,
        Empty.fromBuffer,
      );

  static Future<MergedRegionsResponse> GetMergedRegions(GridHandle request) =>
      _invokeUnary(
        _serviceMethodPath('GetMergedRegions'),
        request,
        MergedRegionsResponse.fromBuffer,
      );

  static Future<MemoryUsageResponse> GetMemoryUsage(GridHandle request) =>
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

  static Future<Empty> Import(ImportRequest request) => _invokeUnary(
        _serviceMethodPath('Import'),
        request,
        Empty.fromBuffer,
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

  static Future<Empty> ResizeViewport(ResizeViewportRequest request) =>
      _invokeUnary(
        _serviceMethodPath('ResizeViewport'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> SetRedraw(SetRedrawRequest request) => _invokeUnary(
        _serviceMethodPath('SetRedraw'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> Refresh(GridHandle request) => _invokeUnary(
        _serviceMethodPath('Refresh'),
        request,
        Empty.fromBuffer,
      );

  static Future<Empty> LoadDemo(LoadDemoRequest request) => _invokeUnary(
        _serviceMethodPath('LoadDemo'),
        request,
        Empty.fromBuffer,
      );

  static Stream<RenderOutput> RenderSession(Stream<RenderInput> requests) =>
      _invokeBidiStream(
        _serviceMethodPath('RenderSession'),
        requests,
        RenderOutput.fromBuffer,
      );

  static Stream<GridEvent> EventStream(GridHandle request) =>
      _invokeServerStream(
        _serviceMethodPath('EventStream'),
        request,
        GridEvent.fromBuffer,
      );
}

/// Initialize the VolvoxGrid plugin FFI runtime.
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
    return 'libvolvoxgrid_plugin.so';
  }
  if (Platform.isMacOS) {
    return 'libvolvoxgrid_plugin.dylib';
  }
  if (Platform.isWindows) {
    return 'volvoxgrid_plugin.dll';
  }
  return 'libvolvoxgrid_plugin.so';
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
    addExistingPath(join(root, 'target${separator}debug${separator}$fileName'));
    addExistingPath(
        join(root, 'target${separator}release${separator}$fileName'));
    addExistingPath(join(root,
        'target${separator}x86_64-unknown-linux-gnu${separator}debug${separator}$fileName'));
    addExistingPath(join(root,
        'target${separator}x86_64-unknown-linux-gnu${separator}release${separator}$fileName'));
  }

  add(fileName);

  if (Platform.isAndroid && fileName != 'libvolvoxgrid_plugin.so') {
    add('libvolvoxgrid_plugin.so');
  }

  yield* candidates;
}

Future<void> initVolvoxGrid({String? libraryName}) {
  final raw = libraryName?.trim();
  final hasRaw = raw != null && raw.isNotEmpty;
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
