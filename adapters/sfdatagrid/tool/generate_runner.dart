import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 3) {
    print(
        'Usage: dart generate_runner.dart <cases_dir> <output_file> <scripts_json>');
    exit(1);
  }

  final casesDir = Directory(args[0]);
  final outputFile = File(args[1]);
  final scriptsJsonFile = File(args[2]);

  if (!casesDir.existsSync()) {
    print('Error: Cases directory not found: ${casesDir.path}');
    exit(1);
  }

  final files = casesDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('common.dart'))
      .toList();

  files.sort((a, b) => a.path.compareTo(b.path));

  final buffer = StringBuffer();
  final caseVars = <String>[];
  final scriptsMap = <String, String>{};

  // 1. Imports
  buffer.writeln("import 'dart:async';");
  buffer.writeln("import 'dart:convert';");
  buffer.writeln("import 'dart:io';");
  buffer.writeln("import 'dart:typed_data';");
  buffer.writeln("import 'dart:ui' as ui;");
  buffer.writeln("");
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln("import 'package:flutter/rendering.dart';");
  buffer.writeln("import 'package:flutter/services.dart';");
  buffer.writeln("import 'package:flutter_test/flutter_test.dart';");
  buffer.writeln(
      "import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;");
  buffer.writeln(
      "import 'package:volvoxgrid/volvoxgrid.dart' hide Align, Border, Padding;");
  buffer.writeln("import 'package:volvoxgrid/volvoxgrid_ffi.dart' as vg_ffi;");
  buffer.writeln(
      "import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;");
  buffer
      .writeln("import 'sfdatagrid_cases/common.dart';"); // Common definitions
  buffer.writeln("");

  // 2. Case Imports
  for (var i = 0; i < files.length; i++) {
    final file = files[i];
    final filename = file.uri.pathSegments.last;
    final prefix = 'case_$i';
    buffer.writeln("import 'sfdatagrid_cases/cases/$filename' as $prefix;");
    caseVars.add('$prefix.testCase');

    // Extract ID from filename (e.g. 01_foo.dart -> 01)
    final idPart = filename.split('_')[0];
    scriptsMap[idPart] = file.readAsStringSync();
  }

  // Write scripts.json immediately
  scriptsJsonFile.writeAsStringSync(jsonEncode(scriptsMap));
  print('Generated ${scriptsJsonFile.path}');

  buffer.writeln("");
  buffer.writeln(
      "// ── Test Cases ───────────────────────────────────────────────────────");
  buffer.writeln("");
  buffer.writeln("final List<TestCase> _cases = [");
  for (final v in caseVars) {
    buffer.writeln("  $v,");
  }
  buffer.writeln("];");
  buffer.writeln("");

  // 3. Helpers and Main (Template)
  buffer.writeln(r'''
// ── Helpers ──────────────────────────────────────────────────────────

vv.GridLinesVisibility _mapGridLines(sf.GridLinesVisibility visibility) {
  switch (visibility) {
    case sf.GridLinesVisibility.none:
      return vv.GridLinesVisibility.none;
    case sf.GridLinesVisibility.horizontal:
      return vv.GridLinesVisibility.horizontal;
    case sf.GridLinesVisibility.vertical:
      return vv.GridLinesVisibility.vertical;
    case sf.GridLinesVisibility.both:
      return vv.GridLinesVisibility.both;
  }
}

vv.SelectionMode _mapSelectionMode(sf.SelectionMode mode) {
  switch (mode) {
    case sf.SelectionMode.none:
      return vv.SelectionMode.none;
    case sf.SelectionMode.single:
      return vv.SelectionMode.single;
    case sf.SelectionMode.singleDeselect:
      return vv.SelectionMode.single;
    case sf.SelectionMode.multiple:
      return vv.SelectionMode.multiple;
  }
}

// ── Capture helper ───────────────────────────────────────────────────

Future<Uint8List?> _captureWidget(GlobalKey key) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData?.buffer.asUint8List();
}

Future<void> _loadFontFromFile(String family, String path) async {
  final bytes =
      await File(path).readAsBytes().then((b) => ByteData.view(b.buffer));
  final loader = FontLoader(family)..addFont(Future.value(bytes));
  await loader.load();
}

Future<bool> _loadFontFromCandidates(String family, List<String> candidates) async {
  for (final path in candidates) {
    if (path.isEmpty) {
      continue;
    }
    final file = File(path);
    if (!await file.exists()) {
      continue;
    }
    await _loadFontFromFile(family, path);
    // ignore: avoid_print
    print('[font] loaded $family from $path');
    return true;
  }
  return false;
}

Future<bool> _loadFontFromAsset(String family, String assetPath) async {
  try {
    final bytes = await rootBundle.load(assetPath);
    final loader = FontLoader(family)..addFont(Future.value(bytes));
    await loader.load();
    // ignore: avoid_print
    print('[font] loaded $family from asset $assetPath');
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> _loadPackagedFontAliases({
  required String baseFamily,
  required String package,
  required String assetPath,
}) async {
  final direct = await _loadFontFromAsset(baseFamily, assetPath);
  final packaged = await _loadFontFromAsset(
    'packages/$package/$baseFamily',
    assetPath,
  );
  return direct || packaged;
}

// ── FFI pump helper ──────────────────────────────────────────────────
//
// Synurang FFI calls use isolate messaging with 30s timeout timers.
// In flutter_test's fake async zone, each FFI call needs:
//   1. runAsync — real-time wait so native side processes the request
//   2. pump    — deliver the response microtask to the fake zone
// Keep the delay/cycles configurable via env to trade speed vs stability.

int _envInt(String key, int fallback, {int min = 0, int? max}) {
  final raw = Platform.environment[key];
  if (raw == null || raw.isEmpty) {
    return fallback;
  }
  final parsed = int.tryParse(raw);
  if (parsed == null) {
    return fallback;
  }
  var value = parsed;
  if (value < min) {
    value = min;
  }
  if (max != null && value > max) {
    value = max;
  }
  return value;
}

Future<void> _pumpFfi(
  WidgetTester tester, {
  required int cycles,
  required int sleepMs,
}) async {
  if (cycles <= 0) {
    return;
  }
  final delay = Duration(milliseconds: sleepMs);
  for (int i = 0; i < cycles; i++) {
    await tester.runAsync(() => Future<void>.delayed(delay));
    await tester.pump();
  }
}

// ── Test ─────────────────────────────────────────────────────────────
//
// All cases run in a single testWidgets to keep the Synurang FFI render
// session alive — destroying and re-creating the bidirectional stream
// across separate testWidgets doesn't work in flutter_test's fake async zone.

void main() {
  final outDir = Platform.environment['CAPTURE_COMPARE_OUT'] ??
      '../../target/sfdatagrid/compare';
  final testFilter = Platform.environment['TEST_FILTER'] ?? '';
  final ffiSleepMs = _envInt('FFI_PUMP_SLEEP_MS', 8, min: 0, max: 250);
  final ffiInitCycles = _envInt('FFI_INIT_CYCLES', 14, min: 0, max: 250);
  final ffiStyleCycles = _envInt('FFI_STYLE_CYCLES', 10, min: 0, max: 250);
  final ffiHookCycles = _envInt('FFI_HOOK_CYCLES', 8, min: 0, max: 250);
  final ffiCleanupCycles = _envInt('FFI_CLEANUP_CYCLES', 6, min: 0, max: 250);
  final ffiFinalCycles = _envInt('FFI_FINAL_CYCLES', 4, min: 0, max: 250);

  setUpAll(() async {
    await Directory(outDir).create(recursive: true);
    await initVolvoxGrid();

    await _loadFontFromCandidates('DejaVu Sans', <String>[
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
      '/usr/share/fonts/noto/NotoSans-Regular.ttf',
    ]);

    // Ensure Material typography has a concrete glyph fallback.
    final robotoLoaded = await _loadFontFromCandidates('Roboto', <String>[
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
      '/usr/share/fonts/noto/NotoSans-Regular.ttf',
    ]);
    if (!robotoLoaded) {
      // ignore: avoid_print
      print('WARNING: could not load Roboto fallback font');
    }

    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
    final homeDir = Platform.environment['HOME'] ?? '';
    final materialLoaded =
        await _loadFontFromCandidates('MaterialIcons', <String>[
      if (flutterRoot.isNotEmpty)
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      if (homeDir.isNotEmpty)
        '$homeDir/snap/flutter/common/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      '/usr/local/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
    if (!materialLoaded) {
      // ignore: avoid_print
      print('WARNING: could not load MaterialIcons font; icon glyphs may be squares');
    }

    final unsortLoaded = await _loadPackagedFontAliases(
      baseFamily: 'UnsortIcon',
      package: 'syncfusion_flutter_datagrid',
      assetPath: 'packages/syncfusion_flutter_datagrid/assets/font/UnsortIcon.ttf',
    );
    if (!unsortLoaded) {
      // ignore: avoid_print
      print('WARNING: could not load UnsortIcon font; unsorted icon may be a square');
    }

    // Filter icons can also appear in headers when filtering is enabled.
    await _loadPackagedFontAliases(
      baseFamily: 'FilterIcon',
      package: 'syncfusion_flutter_datagrid',
      assetPath: 'packages/syncfusion_flutter_datagrid/assets/font/FilterIcon.ttf',
    );
  });

  testWidgets('capture compare all cases', (tester) async {
    print(
      '[config] FFI pump: sleep=${ffiSleepMs}ms, '
      'cycles init/style/hook/cleanup/final='
      '$ffiInitCycles/$ffiStyleCycles/$ffiHookCycles/$ffiCleanupCycles/$ffiFinalCycles',
    );

    tester.view.physicalSize = const Size(1800, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final filteredCases = _cases.where((tc) {
      if (testFilter.isEmpty) return true;
      final parts = testFilter.split(',');
      for (final part in parts) {
        if (part.contains('-')) {
          final range = part.split('-');
          final start = int.parse(range[0]);
          final end = int.parse(range[1]);
          if (tc.id >= start && tc.id <= end) return true;
        } else {
          if (tc.id == int.parse(part)) return true;
        }
      }
      return false;
    }).toList();

    for (final tc in filteredCases) {
      final numStr = tc.id.toString().padLeft(2, '0');

      final refKey = GlobalKey();
      final vvKey = GlobalKey();

      final controller = VolvoxGridController();
      final sfController = sf.DataGridController();
      final sfVerticalScroll = ScrollController();
      final sfHorizontalScroll = ScrollController();

      // Create columns fresh inside the test body — widgets created at file
      // scope conflict with flutter_test's fake async zone.
      final sfColumns = tc.sfColumnsFactory();
      final vvColumns = tc.vvColumnsFactory();
      final sfSource = tc.sfSourceFactory();
      final vvSource = VvSource(tc.vvRows, tc.vvSortedColumns);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.blueGrey,
            fontFamily: 'Roboto',
          ),
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Row(
              children: [
                RepaintBoundary(
                  key: refKey,
                  child: Container(
                    width: 820,
                    height: 560,
                    color: Colors.white,
                    child: sf.SfDataGrid(
                      source: sfSource,
                      columns: sfColumns,
                      controller: sfController,
                      verticalScrollController: sfVerticalScroll,
                      horizontalScrollController: sfHorizontalScroll,
                      gridLinesVisibility: tc.gridLinesVisibility,
                      headerGridLinesVisibility: tc.gridLinesVisibility,
                      frozenColumnsCount: tc.frozenColumnsCount,
                      frozenRowsCount: tc.frozenRowsCount,
                      footerFrozenColumnsCount: tc.footerFrozenColumnsCount,
                      footerFrozenRowsCount: tc.footerFrozenRowsCount,
                      rowHeight: tc.rowHeight,
                      headerRowHeight: tc.headerRowHeight,
                      selectionMode: tc.selectionMode,
                      allowSorting: tc.allowSorting,
                    ),
                  ),
                ),
                RepaintBoundary(
                  key: vvKey,
                  child: Container(
                    width: 820,
                    height: 560,
                    color: Colors.white,
                    child: vv.SfDataGridVolvox(
                      controller: controller,
                      source: vvSource,
                      columns: vvColumns,
                      gridLinesVisibility: _mapGridLines(tc.gridLinesVisibility),
                      frozenColumnsCount: tc.frozenColumnsCount,
                      frozenRowsCount: tc.frozenRowsCount,
                      footerFrozenColumnsCount: tc.footerFrozenColumnsCount,
                      footerFrozenRowsCount: tc.footerFrozenRowsCount,
                      rowHeight: tc.rowHeight,
                      headerRowHeight: tc.headerRowHeight,
                      selectionMode: _mapSelectionMode(tc.selectionMode),
                      allowSorting: tc.allowSorting,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Pump FFI cycles: create() + ~15 reloadAll FFI calls + rebuild +
      // viewport resize + render session + native render + frame decode.
      await _pumpFfi(
        tester,
        cycles: ffiInitCycles,
        sleepMs: ffiSleepMs,
      );

      // Force font settings on VolvoxGrid after initialization
      if (controller.isCreated) {
        await tester.runAsync(() async {
          try {
            await controller.setGridStyle(
              vg_ffi.StyleConfig()
                ..font = (vg_ffi.Font()
                  ..family = 'DejaVu Sans'
                  ..size = 14.0),
            );
          } catch (e) {
            print('WARNING: setGridStyle failed for test \$numStr: \$e');
          }
        });
      }
      await _pumpFfi(
        tester,
        cycles: ffiStyleCycles,
        sleepMs: ffiSleepMs,
      );

      // Execute hooks
      if (tc.onSfCreated != null) {
        await tc.onSfCreated!(sfController, sfSource);
      }
      if (tc.onSfScroll != null) {
        await tc.onSfScroll!(sfVerticalScroll, sfHorizontalScroll);
      }
      if (tc.onVolvoxCreated != null) {
        await tester.runAsync(() => tc.onVolvoxCreated!(controller));
      }
      await _pumpFfi(
        tester,
        cycles: ffiHookCycles,
        sleepMs: ffiSleepMs,
      );

      // Capture via runAsync — toImage() is a real engine call.
      final refImage =
          await tester.runAsync(() => _captureWidget(refKey));
      final vvImage =
          await tester.runAsync(() => _captureWidget(vvKey));

      expect(refImage, isNotNull, reason: '[$numStr] ref capture failed');
      expect(vvImage, isNotNull, reason: '[$numStr] vv capture failed');
      final refBytes = refImage!;
      final vvBytes = vvImage!;

      // File I/O needs runAsync in flutter_test's fake async zone.
      await tester.runAsync(() async {
        await File('$outDir/test_${numStr}_${tc.name}_ref.png')
            .writeAsBytes(refBytes);
        await File('$outDir/test_${numStr}_${tc.name}_vv.png')
            .writeAsBytes(vvBytes);
      });

      // Cleanup for this iteration
      await tester.pumpWidget(const SizedBox());
      await _pumpFfi(
        tester,
        cycles: ffiCleanupCycles,
        sleepMs: ffiSleepMs,
      );
      await tester.runAsync(() async {
        await controller.destroyGrid();
      });
      controller.dispose();
    }

    // Clean disposal after all cases.
    await tester.pumpWidget(const SizedBox());
    await _pumpFfi(
      tester,
      cycles: ffiFinalCycles,
      sleepMs: ffiSleepMs,
    );
  });
}
''');

  outputFile.writeAsStringSync(buffer.toString());
  print('Generated ${outputFile.path}');
}
