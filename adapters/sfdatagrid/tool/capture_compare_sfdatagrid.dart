import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid/volvoxgrid.dart' hide Align, Border, Padding;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;

// ── Test Case Definition ─────────────────────────────────────────────

class _Case {
  final int id;
  final String name;
  final String script;
  final List<vv.GridColumn> vvColumns;
  final List<vv.DataGridRow> vvRows;
  final List<vv.SortColumnDetails> vvSortedColumns;
  // Reference side built lazily.
  final List<sf.GridColumn> sfColumns;
  final sf.DataGridSource Function() sfSourceFactory;

  _Case({
    required this.id,
    required this.name,
    required this.script,
    required this.vvColumns,
    required this.vvRows,
    this.vvSortedColumns = const [],
    required this.sfColumns,
    required this.sfSourceFactory,
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
          child: Text('${c.value ?? ''}'),
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

// ── Test Cases (mirror of compare_cases.dart) ────────────────────────

final List<_Case> _cases = [
  _Case(
    id: 1,
    name: 'basic_rows',
    script: '''final columns = [
  GridColumn(columnName: 'name', label: Text('Name')),
  GridColumn(columnName: 'age', label: Text('Age')),
  GridColumn(columnName: 'city', label: Text('City')),
];''',
    vvColumns: [
      vv.GridColumn(columnName: 'name', label: Text('Name')),
      vv.GridColumn(columnName: 'age', label: Text('Age')),
      vv.GridColumn(columnName: 'city', label: Text('City')),
    ],
    vvRows: [
      _vr([_vc('name', 'Alice'), _vc('age', 31), _vc('city', 'Seoul')]),
      _vr([_vc('name', 'Bob'), _vc('age', 44), _vc('city', 'Busan')]),
    ],
    sfColumns: [
      sf.GridColumn(columnName: 'name', label: Text('Name')),
      sf.GridColumn(columnName: 'age', label: Text('Age')),
      sf.GridColumn(columnName: 'city', label: Text('City')),
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
    vvColumns: [
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
    sfColumns: [
      sf.GridColumn(columnName: 'id', label: Text('ID'), width: 80),
      sf.GridColumn(
          columnName: 'visible', label: Text('Visible'), minimumWidth: 60),
      sf.GridColumn(
          columnName: 'secret', label: Text('Secret'), visible: false),
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
    vvColumns: [
      vv.GridColumn(columnName: 'name', label: Text('Name')),
      vv.GridColumn(columnName: 'status', label: Text('Status')),
      vv.GridColumn(columnName: 'note', label: Text('Note')),
    ],
    vvRows: [
      _vr([_vc('name', 'A')]),
      _vr([_vc('name', 'B'), _vc('status', null)]),
      _vr([_vc('name', 'C'), _vc('status', 'ok'), _vc('note', '')]),
    ],
    sfColumns: [
      sf.GridColumn(columnName: 'name', label: Text('Name')),
      sf.GridColumn(columnName: 'status', label: Text('Status')),
      sf.GridColumn(columnName: 'note', label: Text('Note')),
    ],
    sfSourceFactory: () => _StaticSfSource([
      _sr([_sc('name', 'A')]),
      _sr([_sc('name', 'B'), _sc('status', null)]),
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
    vvColumns: [
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
    sfColumns: [
      sf.GridColumn(columnName: 'id', label: Text('ID')),
      sf.GridColumn(columnName: 'active', label: Text('Active')),
      sf.GridColumn(columnName: 'meta', label: Text('Meta')),
      sf.GridColumn(columnName: 'created', label: Text('Created')),
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
    vvColumns: [
      vv.GridColumn(columnName: 'name', label: Text('Name'), allowSorting: true),
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
    sfColumns: [
      sf.GridColumn(
          columnName: 'name', label: Text('Name'), allowSorting: true),
      sf.GridColumn(
          columnName: 'amount', label: Text('Amount'), allowSorting: true),
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
    vvColumns: [
      vv.GridColumn(columnName: 'product', label: Text('Product')),
      vv.GridColumn(columnName: 'qty', label: Text('Qty')),
      vv.GridColumn(columnName: 'total', label: Text('Total')),
    ],
    vvRows: [
      _vr([_vc('product', 'Pen'), _vc('qty', 4), _vc('total', 12)]),
      _vr([_vc('product', 'Notebook'), _vc('qty', 2), _vc('total', 14)]),
    ],
    sfColumns: [
      sf.GridColumn(columnName: 'product', label: Text('Product')),
      sf.GridColumn(columnName: 'qty', label: Text('Qty')),
      sf.GridColumn(columnName: 'total', label: Text('Total')),
    ],
    sfSourceFactory: () => _StaticSfSource([
      _sr([_sc('product', 'Pen'), _sc('qty', 4), _sc('total', 12)]),
      _sr([_sc('product', 'Notebook'), _sc('qty', 2), _sc('total', 14)]),
    ]),
  ),
];

// ── VolvoxGrid DataGridSource ────────────────────────────────────────

class _VvSource extends vv.DataGridSource {
  _VvSource(this._rows, [this._sortedColumns = const []]);

  final List<vv.DataGridRow> _rows;
  final List<vv.SortColumnDetails> _sortedColumns;

  @override
  List<vv.DataGridRow> get rows => _rows;

  @override
  List<vv.SortColumnDetails> get sortedColumns => _sortedColumns;
}

// ── Main ─────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initVolvoxGrid();

  final outDir = Platform.environment['CAPTURE_COMPARE_OUT'] ??
      'target/sfdatagrid/compare';
  await Directory(outDir).create(recursive: true);

  runApp(_CaptureApp(outDir: outDir));
}

class _CaptureApp extends StatelessWidget {
  const _CaptureApp({required this.outDir});
  final String outDir;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
      home: _CaptureRunner(outDir: outDir),
    );
  }
}

class _CaptureRunner extends StatefulWidget {
  const _CaptureRunner({required this.outDir});
  final String outDir;

  @override
  State<_CaptureRunner> createState() => _CaptureRunnerState();
}

class _CaptureRunnerState extends State<_CaptureRunner> {
  // One key pair per case — all rendered at once.
  late final List<GlobalKey> _refKeys;
  late final List<GlobalKey> _vvKeys;

  @override
  void initState() {
    super.initState();
    _refKeys = List.generate(_cases.length, (_) => GlobalKey());
    _vvKeys = List.generate(_cases.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCapture());
  }

  Future<void> _runCapture() async {
    // Single wait: all grids init in parallel.
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    await _waitForFrame();

    final similarities = <double>[];

    for (var i = 0; i < _cases.length; i++) {
      final tc = _cases[i];
      final numStr = tc.id.toString().padLeft(2, '0');

      final refImage = await _captureWidget(_refKeys[i]);
      final vvImage = await _captureWidget(_vvKeys[i]);

      if (refImage == null || vvImage == null) {
        // ignore: avoid_print
        print('[${numStr}] ${tc.name}');
        // ignore: avoid_print
        print('  Similarity: 0.0% (capture failed)');
        similarities.add(0.0);
        continue;
      }

      await File('${widget.outDir}/test_${numStr}_${tc.name}_ref.png')
          .writeAsBytes(refImage);
      await File('${widget.outDir}/test_${numStr}_${tc.name}_vv.png')
          .writeAsBytes(vvImage);

      final sim = _computeSimilarity(refImage, vvImage);
      similarities.add(sim);

      // ignore: avoid_print
      print('[${numStr}] ${tc.name}');
      // ignore: avoid_print
      print('  Similarity: ${sim.toStringAsFixed(1)}%');
    }

    final avgSim = similarities.isEmpty
        ? 0.0
        : similarities.reduce((a, b) => a + b) / similarities.length;
    // ignore: avoid_print
    print('AVG similarity: ${avgSim.toStringAsFixed(1)}%');

    // Write scripts.json for HTML report generation
    final scriptsMap = <String, String>{};
    for (final tc in _cases) {
      scriptsMap[tc.id.toString().padLeft(2, '0')] = tc.script;
    }
    await File('${widget.outDir}/scripts.json')
        .writeAsString(jsonEncode(scriptsMap));

    exit(0);
  }

  Future<void> _waitForFrame() async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    await completer.future;
  }

  Future<Uint8List?> _captureWidget(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  double _computeSimilarity(Uint8List refPng, Uint8List vvPng) {
    final minLen = refPng.length < vvPng.length ? refPng.length : vvPng.length;
    final maxLen = refPng.length > vvPng.length ? refPng.length : vvPng.length;
    if (maxLen == 0) return 100.0;
    int matching = 0;
    for (var i = 0; i < minLen; i++) {
      if (refPng[i] == vvPng[i]) matching++;
    }
    return (matching / maxLen) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    // Render all cases at once in a vertical list — all grids init in parallel.
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SingleChildScrollView(
        child: Column(
          children: [
            for (var i = 0; i < _cases.length; i++) _buildCase(i),
          ],
        ),
      ),
    );
  }

  Widget _buildCase(int i) {
    final tc = _cases[i];
    final sfSource = tc.sfSourceFactory();
    final vvSource = _VvSource(tc.vvRows, tc.vvSortedColumns);
    final isFooterCase = tc.id == 6;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _refKeys[i],
            child: Container(
              width: 620,
              height: 400,
              color: Colors.white,
              child: sf.SfDataGrid(
                source: sfSource,
                columns: tc.sfColumns,
                gridLinesVisibility: sf.GridLinesVisibility.both,
                headerGridLinesVisibility: sf.GridLinesVisibility.both,
                footerFrozenColumnsCount: isFooterCase ? 1 : 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          RepaintBoundary(
            key: _vvKeys[i],
            child: Container(
              width: 620,
              height: 400,
              color: Colors.white,
              child: vv.SfDataGridVolvox(
                source: vvSource,
                columns: tc.vvColumns,
                gridLinesVisibility: vv.GridLinesVisibility.both,
                footerFrozenColumnsCount: isFooterCase ? 1 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
