import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid/volvoxgrid.dart' hide Align;
import 'package:volvoxgrid/volvoxgrid_ffi.dart' as vg_ffi;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;

// ── Test Case Definition ─────────────────────────────────────────────

class _Case {
  final int id;
  final String name;
  final String script;
  final List<vv.GridColumn> Function() vvColumnsFactory;
  final List<vv.DataGridRow> vvRows;
  final List<vv.SortColumnDetails> vvSortedColumns;
  final List<sf.GridColumn> Function() sfColumnsFactory;
  final sf.DataGridSource Function() sfSourceFactory;
  final int footerFrozenColumnsCount;

  _Case({
    required this.id,
    required this.name,
    required this.script,
    required this.vvColumnsFactory,
    required this.vvRows,
    this.vvSortedColumns = const [],
    required this.sfColumnsFactory,
    required this.sfSourceFactory,
    this.footerFrozenColumnsCount = 0,
  });
}

// ── Reference DataGridSource ─────────────────────────────────────────

class _StaticSfSource extends sf.DataGridSource {
  _StaticSfSource(this._rows, [this._sortedColumns = const []]);

  final List<sf.DataGridRow> _rows;
  final List<sf.SortColumnDetails> _sortedColumns;

  @override
  List<sf.DataGridRow> get rows => _rows;

  @override
  List<sf.SortColumnDetails> get sortedColumns => _sortedColumns;

  @override
  sf.DataGridRowAdapter buildRow(sf.DataGridRow row) {
    return sf.DataGridRowAdapter(
      cells: row.getCells().map((c) {
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${c.value ?? ''}',
            style: const TextStyle(fontSize: 14.0, fontFamily: 'Roboto'),
          ),
        );
      }).toList(growable: false),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────

sf.DataGridCell<dynamic> _sc(String name, dynamic value) =>
    sf.DataGridCell<dynamic>(columnName: name, value: value);

sf.DataGridRow _sr(List<sf.DataGridCell<dynamic>> cells) =>
    sf.DataGridRow(cells: cells);

vv.DataGridCell<dynamic> _vc(String name, dynamic value) =>
    vv.DataGridCell<dynamic>(columnName: name, value: value);

vv.DataGridRow _vr(List<vv.DataGridCell<dynamic>> cells) =>
    vv.DataGridRow(cells: cells);

// ── Test Cases ───────────────────────────────────────────────────────

const _textStyle = TextStyle(fontSize: 14.0, fontFamily: 'Roboto');

final List<_Case> _cases = [
  _Case(
    id: 1,
    name: 'basic_rows',
    script: '''final columns = [
  GridColumn(columnName: 'name', label: Text('Name')),
  GridColumn(columnName: 'age', label: Text('Age')),
  GridColumn(columnName: 'city', label: Text('City')),
];''',
    vvColumnsFactory: () => [
      vv.GridColumn(columnName: 'name', label: Text('Name')),
      vv.GridColumn(columnName: 'age', label: Text('Age')),
      vv.GridColumn(columnName: 'city', label: Text('City')),
    ],
    vvRows: [
      _vr([_vc('name', 'Alice'), _vc('age', 31), _vc('city', 'Seoul')]),
      _vr([_vc('name', 'Bob'), _vc('age', 44), _vc('city', 'Busan')]),
    ],
    sfColumnsFactory: () => [
      sf.GridColumn(
          columnName: 'name', label: Text('Name', style: _textStyle)),
      sf.GridColumn(columnName: 'age', label: Text('Age', style: _textStyle)),
      sf.GridColumn(
          columnName: 'city', label: Text('City', style: _textStyle)),
    ],
    sfSourceFactory: () => _StaticSfSource([
      _sr([_sc('name', 'Alice'), _sc('age', 31), _sc('city', 'Seoul')]),
      _sr([_sc('name', 'Bob'), _sc('age', 44), _sc('city', 'Busan')]),
    ]),
  ),
  _Case(
    id: 2,
    name: 'hidden_and_widths',
    script: '''final columns = [
  GridColumn(columnName: 'id', label: Text('ID'), width: 80),
  GridColumn(columnName: 'visible', label: Text('Visible'), minimumWidth: 60),
  GridColumn(columnName: 'secret', label: Text('Secret'), visible: false),
];''',
    vvColumnsFactory: () => [
      vv.GridColumn(columnName: 'id', label: Text('ID'), width: 80),
      vv.GridColumn(
          columnName: 'visible', label: Text('Visible'), minimumWidth: 60),
      vv.GridColumn(
          columnName: 'secret', label: Text('Secret'), visible: false),
    ],
    vvRows: [
      _vr([_vc('id', 'R-1'), _vc('visible', 'on'), _vc('secret', 'x1')]),
      _vr([_vc('id', 'R-2'), _vc('visible', 'off'), _vc('secret', 'x2')]),
    ],
    sfColumnsFactory: () => [
      sf.GridColumn(
          columnName: 'id', label: Text('ID', style: _textStyle), width: 80),
      sf.GridColumn(
          columnName: 'visible',
          label: Text('Visible', style: _textStyle),
          minimumWidth: 60),
      sf.GridColumn(
          columnName: 'secret',
          label: Text('Secret', style: _textStyle),
          visible: false),
    ],
    sfSourceFactory: () => _StaticSfSource([
      _sr([_sc('id', 'R-1'), _sc('visible', 'on'), _sc('secret', 'x1')]),
      _sr([_sc('id', 'R-2'), _sc('visible', 'off'), _sc('secret', 'x2')]),
    ]),
  ),
  _Case(
    id: 3,
    name: 'null_and_missing',
    script: '''final rows = [
  DataGridRow(cells: [DataGridCell(columnName: 'name', value: 'A')]),
  DataGridRow(cells: [DataGridCell(columnName: 'name', value: 'B'), DataGridCell(columnName: 'status', value: null)]),
];''',
    vvColumnsFactory: () => [
      vv.GridColumn(columnName: 'name', label: Text('Name')),
      vv.GridColumn(columnName: 'status', label: Text('Status')),
      vv.GridColumn(columnName: 'note', label: Text('Note')),
    ],
    vvRows: [
      _vr([_vc('name', 'A')]),
      _vr([_vc('name', 'B'), _vc('status', null)]),
      _vr([_vc('name', 'C'), _vc('status', 'ok'), _vc('note', '')]),
    ],
    sfColumnsFactory: () => [
      sf.GridColumn(
          columnName: 'name', label: Text('Name', style: _textStyle)),
      sf.GridColumn(
          columnName: 'status', label: Text('Status', style: _textStyle)),
      sf.GridColumn(
          columnName: 'note', label: Text('Note', style: _textStyle)),
    ],
    // SfDataGrid requires each row to have cells matching column count,
    // so pad missing cells with null values for the reference grid.
    sfSourceFactory: () => _StaticSfSource([
      _sr([_sc('name', 'A'), _sc('status', null), _sc('note', null)]),
      _sr([_sc('name', 'B'), _sc('status', null), _sc('note', null)]),
      _sr([_sc('name', 'C'), _sc('status', 'ok'), _sc('note', '')]),
    ]),
  ),
  _Case(
    id: 4,
    name: 'mixed_types',
    script: '''final rows = [
  DataGridRow(cells: [
    DataGridCell(columnName: 'id', value: 1),
    DataGridCell(columnName: 'active', value: true),
    DataGridCell(columnName: 'meta', value: {'r': 'NA'}),
  ]),
];''',
    vvColumnsFactory: () => [
      vv.GridColumn(columnName: 'id', label: Text('ID')),
      vv.GridColumn(columnName: 'active', label: Text('Active')),
      vv.GridColumn(columnName: 'meta', label: Text('Meta')),
      vv.GridColumn(columnName: 'created', label: Text('Created')),
    ],
    vvRows: [
      _vr([
        _vc('id', 1),
        _vc('active', true),
        _vc('meta', <String, String>{'r': 'NA'}),
        _vc('created', DateTime.utc(2026, 1, 20)),
      ]),
      _vr([
        _vc('id', 2),
        _vc('active', false),
        _vc('meta', <String>['x', 'y']),
        _vc('created', '2026-02-21'),
      ]),
    ],
    sfColumnsFactory: () => [
      sf.GridColumn(columnName: 'id', label: Text('ID', style: _textStyle)),
      sf.GridColumn(
          columnName: 'active', label: Text('Active', style: _textStyle)),
      sf.GridColumn(
          columnName: 'meta', label: Text('Meta', style: _textStyle)),
      sf.GridColumn(
          columnName: 'created', label: Text('Created', style: _textStyle)),
    ],
    sfSourceFactory: () => _StaticSfSource([
      _sr([
        _sc('id', 1),
        _sc('active', true),
        _sc('meta', <String, String>{'r': 'NA'}),
        _sc('created', DateTime.utc(2026, 1, 20)),
      ]),
      _sr([
        _sc('id', 2),
        _sc('active', false),
        _sc('meta', <String>['x', 'y']),
        _sc('created', '2026-02-21'),
      ]),
    ]),
  ),
  _Case(
    id: 5,
    name: 'sorted_columns_metadata',
    script: '''final source = MySource()..sortedColumns = [
  SortColumnDetails(name: 'amount', sortDirection: SortDirection.descending),
];''',
    vvColumnsFactory: () => [
      vv.GridColumn(
          columnName: 'name', label: Text('Name'), allowSorting: true),
      vv.GridColumn(
          columnName: 'amount', label: Text('Amount'), allowSorting: true),
    ],
    vvRows: [
      _vr([_vc('name', 'A'), _vc('amount', 100)]),
      _vr([_vc('name', 'B'), _vc('amount', 80)]),
    ],
    vvSortedColumns: [
      vv.SortColumnDetails(
          name: 'amount', sortDirection: vv.SortDirection.descending),
    ],
    sfColumnsFactory: () => [
      sf.GridColumn(
          columnName: 'name',
          label: Text('Name', style: _textStyle),
          allowSorting: true),
      sf.GridColumn(
          columnName: 'amount',
          label: Text('Amount', style: _textStyle),
          allowSorting: true),
    ],
    sfSourceFactory: () => _StaticSfSource(
      [
        _sr([_sc('name', 'A'), _sc('amount', 100)]),
        _sr([_sc('name', 'B'), _sc('amount', 80)]),
      ],
      [
        sf.SortColumnDetails(
            name: 'amount',
            sortDirection: sf.DataGridSortDirection.descending),
      ],
    ),
  ),
  _Case(
    id: 6,
    name: 'footer_frozen_column_shape',
    script: '''SfDataGridVolvox(
  footerFrozenColumnsCount: 1,
  columns: [
    GridColumn(columnName: 'product', label: Text('Product')),
    GridColumn(columnName: 'qty', label: Text('Qty')),
    GridColumn(columnName: 'total', label: Text('Total')),
  ],
)''',
    vvColumnsFactory: () => [
      vv.GridColumn(columnName: 'product', label: Text('Product')),
      vv.GridColumn(columnName: 'qty', label: Text('Qty')),
      vv.GridColumn(columnName: 'total', label: Text('Total')),
    ],
    vvRows: [
      _vr([_vc('product', 'Pen'), _vc('qty', 4), _vc('total', 12)]),
      _vr([_vc('product', 'Notebook'), _vc('qty', 2), _vc('total', 14)]),
    ],
    sfColumnsFactory: () => [
      sf.GridColumn(
          columnName: 'product', label: Text('Product', style: _textStyle)),
      sf.GridColumn(columnName: 'qty', label: Text('Qty', style: _textStyle)),
      sf.GridColumn(
          columnName: 'total', label: Text('Total', style: _textStyle)),
    ],
    sfSourceFactory: () => _StaticSfSource([
      _sr([_sc('product', 'Pen'), _sc('qty', 4), _sc('total', 12)]),
      _sr([_sc('product', 'Notebook'), _sc('qty', 2), _sc('total', 14)]),
    ]),
    footerFrozenColumnsCount: 1,
  ),
];

class _VvSource extends vv.DataGridSource {
  _VvSource(this._rows, [this._sortedColumns = const []]);
  final List<vv.DataGridRow> _rows;
  final List<vv.SortColumnDetails> _sortedColumns;
  @override
  List<vv.DataGridRow> get rows => _rows;
  @override
  List<vv.SortColumnDetails> get sortedColumns => _sortedColumns;
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

double _computeSimilarity(Uint8List a, Uint8List b) {
  final minLen = a.length < b.length ? a.length : b.length;
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 100.0;
  int matching = 0;
  for (var i = 0; i < minLen; i++) {
    if (a[i] == b[i]) matching++;
  }
  return (matching / maxLen) * 100.0;
}

// ── FFI pump helper ──────────────────────────────────────────────────
//
// Synurang FFI calls use isolate messaging with 30s timeout timers.
// In flutter_test's fake async zone, each FFI call needs:
//   1. runAsync — real-time wait so native side processes the request
//   2. pump    — deliver the response microtask to the fake zone
// With ~15 sequential awaits in _reloadAll, we need ≥15 cycles.

Future<void> _pumpFfi(WidgetTester tester, {int cycles = 40}) async {
  for (int i = 0; i < cycles; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
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

  setUpAll(() async {
    await Directory(outDir).create(recursive: true);
    await initVolvoxGrid();

    // Load DejaVu Sans for Flutter rendering (SfDataGrid)
    // Load as 'DejaVu Sans' and also 'Roboto' to satisfy default Material typography
    final fontBytes =
        await File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.view(bytes.buffer));

    final loader1 = FontLoader('DejaVu Sans')..addFont(Future.value(fontBytes));
    await loader1.load();

    final loader2 = FontLoader('Roboto')..addFont(Future.value(fontBytes));
    await loader2.load();
  });

  testWidgets('capture compare all cases', (tester) async {
    tester.view.physicalSize = const Size(1400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final tc in _cases) {
      final numStr = tc.id.toString().padLeft(2, '0');

      final refKey = GlobalKey();
      final vvKey = GlobalKey();

      final controller = VolvoxGridController();

      // Create columns fresh inside the test body — widgets created at file
      // scope conflict with flutter_test's fake async zone.
      final sfColumns = tc.sfColumnsFactory();
      final vvColumns = tc.vvColumnsFactory();
      final sfSource = tc.sfSourceFactory();
      final vvSource = _VvSource(tc.vvRows, tc.vvSortedColumns);

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
                    width: 620,
                    height: 400,
                    color: Colors.white,
                    child: sf.SfDataGrid(
                      source: sfSource,
                      columns: sfColumns,
                      gridLinesVisibility: sf.GridLinesVisibility.both,
                      headerGridLinesVisibility: sf.GridLinesVisibility.both,
                      footerFrozenColumnsCount: tc.footerFrozenColumnsCount,
                    ),
                  ),
                ),
                RepaintBoundary(
                  key: vvKey,
                  child: Container(
                    width: 620,
                    height: 400,
                    color: Colors.white,
                    child: vv.SfDataGridVolvox(
                      controller: controller,
                      source: vvSource,
                      columns: vvColumns,
                      gridLinesVisibility: vv.GridLinesVisibility.both,
                      footerFrozenColumnsCount: tc.footerFrozenColumnsCount,
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
      await _pumpFfi(tester, cycles: 20);

      // Force font settings on VolvoxGrid after initialization
      if (controller.isCreated) {
        await tester.runAsync(() async {
          await controller.setGridStyle(
            vg_ffi.StyleConfig()
              ..fontName = 'DejaVu Sans'
              ..fontSize = 14.0,
          );
        });
      }
      await _pumpFfi(tester, cycles: 40);

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

      final sim = _computeSimilarity(refBytes, vvBytes);
      // ignore: avoid_print
      print('[${numStr}] ${tc.name}  Similarity: ${sim.toStringAsFixed(1)}%');

      // Cleanup for this iteration
      await tester.pumpWidget(const SizedBox());
      await _pumpFfi(tester, cycles: 5);
      await tester.runAsync(() async {
        await controller.destroyGrid();
      });
      controller.dispose();
    }

    // Clean disposal after all cases.
    await tester.pumpWidget(const SizedBox());
    await _pumpFfi(tester, cycles: 20);

    // Write scripts.json for the HTML report.
    await tester.runAsync(() async {
      final scriptsMap = <String, String>{};
      for (final tc in _cases) {
        scriptsMap[tc.id.toString().padLeft(2, '0')] = tc.script;
      }
      await File('$outDir/scripts.json')
          .writeAsString(jsonEncode(scriptsMap));
    });
  });
}
