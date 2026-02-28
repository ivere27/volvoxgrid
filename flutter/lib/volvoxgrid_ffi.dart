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

import 'dart:io' show Platform;

import 'package:synurang/synurang.dart' as synurang;

// Re-export generated protobuf messages and the FFI service client.
export 'src/generated/volvoxgrid.pb.dart';
export 'src/generated/volvoxgrid_ffi.pb.dart';

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

Future<void> initVolvoxGrid({String? libraryName}) {
  final raw = libraryName?.trim();
  final hasRaw = raw != null && raw.isNotEmpty;
  final treatAsPath = hasRaw && _looksLikeLibraryPath(raw);
  final effectivePath = treatAsPath ? raw : _defaultLibraryFileName();
  final candidates = <String>{effectivePath};

  if (Platform.isAndroid && !treatAsPath) {
    candidates.add('libvolvoxgrid_plugin.so');
  }

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
