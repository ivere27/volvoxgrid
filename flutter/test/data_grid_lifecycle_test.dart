import 'dart:async';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volvoxgrid/volvoxgrid.dart';

class DelayedController extends VolvoxGridController {
  final createGate = Completer<void>();
  final calls = <String>[];
  List<CellValue> values = [];
  List<int> nativeRowIds = [];
  List<ColumnDef> definitions = [];
  int columnCount = 0;
  int loadRevision = 0;
  Object? rowsFailure;
  final queryCounts = <int>[];
  Completer<void>? schemaGate;
  bool created = false;
  bool identitiesEnabled = false;
  Object? failure;
  Completer<void>? loadGate;
  @override
  bool get isCreated => created;
  @override
  bool get rowIdsEnabled => created && identitiesEnabled;
  void record(String method) {
    if (isDisposed) throw StateError('Late access: $method');
    calls.add(method);
  }

  @override
  Future<void> create(
      {int rows = 50,
      int cols = 10,
      int viewportWidth = 800,
      int viewportHeight = 600,
      double scale = 1,
      bool rowIdsEnabled = false}) async {
    record('create');
    await createGate.future;
    if (failure != null) throw failure!;
    created = true;
    identitiesEnabled = rowIdsEnabled;
    columnCount = cols;
    nativeRowIds = List.generate(rows < 1 ? 1 : rows, (i) => i + 1);
  }

  @override
  Future<void> cancelEdit({dynamic sessionId, dynamic stateVersion}) async =>
      record('cancel');
  @override
  Future<void> setEditTrigger(EditTrigger trigger) async => record('edit');
  @override
  Future<void> setRowCount(int count) async => record('rows');
  @override
  Future<void> setColCount(int count) async => record('cols');
  @override
  Future<void> defineColumns(DefineColumnsRequest request) async {
    record('columns');
    definitions = request.columns.toList();
  }

  @override
  Future<SchemaResponse> getSchema() async {
    final response = SchemaResponse(columns: definitions);
    if (schemaGate != null) await schemaGate!.future;
    return response;
  }

  @override
  Future<List<VolvoxRowIdentity>> getRows(
      {int startRow = 0, int rowCount = 0, List<int> rowIds = const []}) async {
    record('getRows');
    queryCounts.add(rowCount);
    if (rowsFailure != null) throw rowsFailure!;
    final indices = rowIds.isNotEmpty
        ? rowIds.map(nativeRowIds.indexOf).where((i) => i >= 0)
        : List.generate(
            rowCount == 0 ? nativeRowIds.length - startRow : rowCount,
            (i) => startRow + i);
    return [
      for (final i in indices)
        VolvoxRowIdentity(index: i, rowId: nativeRowIds[i])
    ];
  }

  @override
  Future<String> getCellText(int row, int col) async =>
      values[row * columnCount + col].text;
  @override
  Future<void> configure(GridConfig config) async => record('configure');
  @override
  Future<void> loadTable(int rows, int cols, List<CellValue> data,
      {bool atomic = false, List<int>? rowIds}) async {
    record('load');
    if (loadGate != null) await loadGate!.future;
    values = data;
    columnCount = cols;
    loadRevision++;
    nativeRowIds = rowIds != null && rowIds.isNotEmpty
        ? List.of(rowIds)
        : List.generate(
            rows < 1 ? 1 : rows, (i) => loadRevision * 10000 + i + 1);
  }

  @override
  Future<void> destroyGrid() async {
    created = false;
    identitiesEnabled = false;
  }
}

Widget binding(DelayedController c, List<String> rows,
        {int version = 0,
        void Function(Object, StackTrace)? onError,
        List<VolvoxColumn<String>>? columns,
        int Function(String)? getRowId}) =>
    MaterialApp(
        home: Scaffold(
            body: VolvoxDataGrid<String>(
      controller: c,
      rows: rows,
      getRowId: getRowId,
      dataVersion: version,
      active: false,
      columns: columns ??
          [VolvoxColumn(field: 'name', header: 'Name', value: (r) => r)],
      onError: onError,
    )));

void main() {
  test('row ID APIs reject disabled controllers before native access',
      () async {
    final c = VolvoxGridController();
    expect(c.rowIdsEnabled, isFalse);
    final disabled = throwsA(isA<StateError>().having((e) => e.message,
        'recovery instruction', contains('create(rowIdsEnabled: true)')));
    await expectLater(c.getRows(), disabled);
    await expectLater(c.getRowId(0), disabled);
    await expectLater(c.findRowById(1), disabled);
    await expectLater(
        c.loadTable(1, 1, [CellValue(text: 'ignored')], rowIds: [1]), disabled);
    await expectLater(
        c.defineRows(DefineRowsRequest(rows: [
          RowDef(index: 0, rowId: Int64(1)),
        ])),
        disabled);
    expect(c.rowIdsEnabled, isFalse);
    c.dispose();
  });
  testWidgets('binding rejects an existing ID-disabled grid without changes',
      (tester) async {
    final c = DelayedController()..createGate.complete();
    await c.create(rows: 1, cols: 1);
    c.values = [CellValue(text: 'preserved')];
    final originalCalls = List.of(c.calls);
    Future<bool> originalAuthorization(int row, int col) async => true;
    c.editAuthorization = originalAuthorization;
    var valueCalls = 0;
    final errors = <Object>[];
    await tester.pumpWidget(binding(c, ['replacement'],
        onError: (error, _) => errors.add(error),
        columns: [
          VolvoxColumn(
              field: 'name',
              header: 'Name',
              value: (row) {
                valueCalls++;
                return row;
              }),
        ]));
    await tester.pump();
    expect(errors.single, isStateError);
    expect(errors.single.toString(), contains('create(rowIdsEnabled: true)'));
    expect(c.calls, originalCalls);
    expect(c.values.single.text, 'preserved');
    expect(c.clipboardMutationsEnabled, isTrue);
    expect(c.editAuthorization, same(originalAuthorization));
    expect(c.rowIdsEnabled, isFalse);
    expect(valueCalls, 0);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'rapid updates while create is pending apply only newest snapshot',
      (tester) async {
    final c = DelayedController();
    await tester.pumpWidget(binding(c, ['old']));
    await tester.pumpWidget(binding(c, ['middle']));
    await tester.pumpWidget(binding(c, ['latest']));
    c.createGate.complete();
    await tester.pump();
    expect(c.values.first.text, 'latest');
    expect(c.rowIdsEnabled, isTrue,
        reason: 'High-level binding must explicitly enable native row IDs');
    expect(c.calls.where((c) => c == 'load').length, 1);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('latest replacement wins after a load already in flight',
      (tester) async {
    final c = DelayedController()..createGate.complete();
    final gate = c.loadGate = Completer<void>();
    await tester.pumpWidget(binding(c, ['first']));
    expect(c.calls, contains('load'));
    await tester.pumpWidget(binding(c, ['last']));
    c.loadGate = null;
    gate.complete();
    await tester.pump();
    expect(c.values.first.text, 'last');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('dispose or controller replacement cancels old continuation',
      (tester) async {
    final old = DelayedController();
    final replacement = DelayedController()..createGate.complete();
    await tester.pumpWidget(binding(old, ['old']));
    await tester.pumpWidget(binding(replacement, ['new']));
    old.dispose();
    old.createGate.complete();
    await tester.pump();
    expect(old.calls, ['create']);
    expect(replacement.values.first.text, 'new');
    await tester.pumpWidget(const SizedBox());
    replacement.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'new equivalent columns skip reload; explicit version refreshes mutated list',
      (tester) async {
    final c = DelayedController()..createGate.complete();
    final rows = ['first'];
    await tester.pumpWidget(binding(c, rows));
    final loads = c.calls.where((c) => c == 'load').length;
    await tester.pumpWidget(binding(c, rows));
    expect(c.calls.where((c) => c == 'load').length, loads);
    rows[0] = 'mutated';
    await tester.pumpWidget(binding(c, rows));
    expect(c.values.first.text, 'first');
    await tester.pumpWidget(binding(c, rows, version: 1));
    expect(c.values.first.text, 'mutated');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'initialization errors reach app and render an error instead of unhandled futures',
      (tester) async {
    final errors = <Object>[];
    final c = DelayedController()..failure = StateError('native unavailable');
    await tester
        .pumpWidget(binding(c, ['row'], onError: (e, _) => errors.add(e)));
    c.createGate.complete();
    await tester.pump();
    expect(errors.single, isStateError);
    expect(find.textContaining('native unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('duplicate fields fail before native writes', (tester) async {
    final errors = <Object>[];
    final c = DelayedController();
    await tester.pumpWidget(binding(c, ['row'],
        onError: (e, _) => errors.add(e),
        columns: [
          VolvoxColumn(field: 'x', header: 'X', value: (r) => r),
          VolvoxColumn(field: 'x', header: 'Y', value: (r) => r),
        ]));
    await tester.pump();
    expect(errors.single, isArgumentError);
    expect(c.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('application row IDs stay native and do not consume a column',
      (tester) async {
    final c = DelayedController()..createGate.complete();
    await tester.pumpWidget(binding(c, ['상품-a', '상품-b'],
        getRowId: (r) => const {
              '상품-a': 1,
              '상품-b': 2,
              'A': 1,
              'B': 2,
              'old': 1,
              'new': 2
            }[r]!,
        columns: [
          VolvoxColumn(
              field: '__volvox_data_grid_row_identity__',
              header: 'Name',
              value: (r) => r)
        ]));
    expect(c.nativeRowIds, [1, 2]);
    expect(c.columnCount, 1);
    expect(c.definitions, hasLength(1));
    expect(c.definitions.single.hidden, isFalse);
    expect(c.values, hasLength(2));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('empty data then populated then empty keeps no source identity',
      (tester) async {
    final c = DelayedController()..createGate.complete();
    final errors = <Object>[];
    await tester.pumpWidget(binding(c, [], onError: (e, _) => errors.add(e)));
    expect(c.values, isEmpty);
    expect(c.columnCount, 1);
    expect(await c.editAuthorization!(0, 0), isFalse);
    await tester
        .pumpWidget(binding(c, ['new'], onError: (e, _) => errors.add(e)));
    expect(c.values.single.text, 'new');
    await tester.pumpWidget(binding(c, [], onError: (e, _) => errors.add(e)));
    expect(c.values, isEmpty);
    expect(await c.editAuthorization!(0, 0), isFalse);
    expect(errors, isEmpty);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('zero negative or duplicate IDs fail before native writes',
      (tester) async {
    for (final id in [0, -1, 1]) {
      final c = DelayedController();
      final errors = <Object>[];
      await tester.pumpWidget(binding(c, ['A', 'B'],
          getRowId: (_) => id, onError: (e, _) => errors.add(e)));
      expect(errors.single, isArgumentError);
      expect(c.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }
  });
  testWidgets('generated identity read errors are reported to the app',
      (tester) async {
    final failure = StateError('row identity read failed');
    final c = DelayedController()
      ..createGate.complete()
      ..rowsFailure = failure;
    final errors = <Object>[];
    await tester
        .pumpWidget(binding(c, ['A'], onError: (e, _) => errors.add(e)));
    expect(errors.single, same(failure));
    expect(c.calls, contains('load'));
    expect(c.values.single.text, 'A');
    expect(await c.editAuthorization!(0, 0), isFalse,
        reason: 'A failed mapping cannot authorize source-object edits');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('queued edit identity survives changed row coordinates',
      (tester) async {
    final c = DelayedController()..createGate.complete();
    final edits = <VolvoxCellEdit<String>>[];
    await tester.pumpWidget(MaterialApp(
        home: VolvoxDataGrid<String>(
      controller: c,
      active: false,
      rows: const ['A', 'B'],
      getRowId: (r) =>
          const {'상품-a': 1, '상품-b': 2, 'A': 1, 'B': 2, 'old': 1, 'new': 2}[r]!,
      columns: [
        VolvoxColumn(
            field: 'value', header: 'Value', value: (r) => r, editable: true)
      ],
      onCellEdit: edits.add,
    )));
    final grid = tester.widget<VolvoxGridWidget>(find.byType(VolvoxGridWidget));
    // B was at display row 0 when this event was emitted; the engine has since
    // sorted back to A,B before Dart handles the queued event.
    final before = VolvoxGridBeforeEditDetails(
        rawEvent: GridEvent(), row: 0, col: 0, rowId: 2);
    await grid.onBeforeEdit!(before);
    expect(before.cancel, isFalse);
    final validate = VolvoxGridCellEditValidatingDetails(
        rawEvent: GridEvent(), row: 1, col: 0, rowId: 2, editText: 'updated');
    await grid.onCellEditValidating!(validate);
    expect(validate.cancel, isFalse);
    grid.onGridEvent!(GridEvent(
        afterEdit: AfterEditEvent(
            row: 0,
            col: 0,
            rowId: Int64(2),
            oldText: 'B',
            newText: 'updated')));
    expect(edits.single.row, 'B');
    expect(edits.single.rowId, 2);
    expect(edits.single.rowIndex, 1);
    expect(edits.single.oldText, 'B');
    final unknown = VolvoxGridBeforeEditDetails(
        rawEvent: GridEvent(), row: 0, col: 0, rowId: 999);
    await grid.onBeforeEdit!(unknown);
    expect(unknown.cancel, isTrue);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('late prior edit lookup cannot clear a replacement edit target',
      (tester) async {
    final c = DelayedController()..createGate.complete();
    final edits = <VolvoxCellEdit<String>>[];
    Widget app(List<String> rows) => MaterialApp(
            home: Scaffold(
                body: VolvoxDataGrid<String>(
          controller: c,
          active: false,
          rows: rows,
          getRowId: (_) => 1,
          columns: [
            VolvoxColumn(
                field: 'value',
                header: 'Value',
                value: (r) => r,
                editable: true)
          ],
          onCellEdit: edits.add,
        )));
    await tester.pumpWidget(app(['old']));
    var grid = tester.widget<VolvoxGridWidget>(find.byType(VolvoxGridWidget));
    final gate = c.schemaGate = Completer<void>();
    final stale = VolvoxGridBeforeEditDetails(
        rawEvent: GridEvent(), row: 0, col: 0, rowId: 1);
    final pending = Future<void>.sync(() => grid.onBeforeEdit!(stale));
    await tester.pump();
    c.schemaGate = null;
    await tester.pumpWidget(app(['new']));
    grid = tester.widget<VolvoxGridWidget>(find.byType(VolvoxGridWidget));
    final current = VolvoxGridBeforeEditDetails(
        rawEvent: GridEvent(), row: 0, col: 0, rowId: 1);
    await grid.onBeforeEdit!(current);
    expect(current.cancel, isFalse);
    gate.complete();
    await pending;
    expect(stale.cancel, isTrue);
    final validate = VolvoxGridCellEditValidatingDetails(
        rawEvent: GridEvent(), row: 0, col: 0, rowId: 1, editText: 'saved');
    await grid.onCellEditValidating!(validate);
    expect(validate.cancel, isFalse);
    grid.onGridEvent!(GridEvent(
        afterEdit: AfterEditEvent(
            row: 0,
            col: 0,
            rowId: Int64(1),
            oldText: 'new',
            newText: 'saved')));
    expect(edits.single.rowId, 1);
    expect(edits.single.row, 'new');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('keyed refresh reuses supplied IDs without ID queries',
      (tester) async {
    final c = DelayedController()..createGate.complete();
    const maxId = 0x7fffffffffffffff;
    const wideId = 9007199254740993;
    int idFor(String row) => row == 'A' ? wideId : maxId;
    await tester.pumpWidget(binding(c, ['A', 'B'], getRowId: idFor));
    expect(c.nativeRowIds, [wideId, maxId]);
    expect(c.queryCounts, isEmpty);
    await tester.pumpWidget(binding(c, ['B', 'A'], getRowId: idFor));
    expect(c.nativeRowIds, [maxId, wideId]);
    expect(c.queryCounts, isEmpty,
        reason: 'Supplied IDs need neither capability probes nor readback');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
