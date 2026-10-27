// Public package API + real native engine; host hooks are invoked explicitly.
// These tests cover binding, not physical keyboard/gesture recognition.
import 'dart:io';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volvoxgrid/volvoxgrid.dart';

class Product {
  const Product(this.id, this.name, this.qty);
  final int id;
  final String name, qty;
}

void main() {
  final library = Platform.environment['VOLVOXGRID_TEST_LIB'];
  final skip = library == null;
  setUpAll(() async {
    if (library != null) {
      await initVolvoxGrid(libraryName: library);
      final warmup = VolvoxGridController();
      await warmup.create(rows: 1, cols: 1);
      await warmup.destroyGrid();
      warmup.dispose();
    }
  });
  test(
      'controller coalesces create and releases a create completed after disposal',
      () async {
    final controller = VolvoxGridController();
    final first = controller.create(rows: 2, cols: 2);
    final second = controller.create(rows: 3, cols: 3);
    expect(identical(first, second), isTrue);
    final incompatible = controller.create(rowIdsEnabled: true);
    controller.dispose();
    await expectLater(incompatible, throwsStateError);
    await first;
    expect(controller.isDisposed, isTrue);
    expect(controller.isCreated, isFalse);
    await expectLater(controller.create(), throwsStateError);
  }, skip: skip);
  test('default-off million-row grid rejects ID operations without mutations',
      () async {
    final c = VolvoxGridController();
    expect(c.rowIdsEnabled, isFalse);
    await c.create(rows: 1000000, cols: 1);
    expect(c.rowIdsEnabled, isFalse);
    await c.setCellText(0, 0, 'first');
    await c.setCellText(999999, 0, 'last');
    final nativeGrid = c.gridId;
    final disabled = throwsA(isA<StateError>().having((e) => e.message,
        'recovery instruction', contains('create(rowIdsEnabled: true)')));
    await expectLater(c.getRows(rowCount: 1), disabled);
    await expectLater(c.getRowId(0), disabled);
    await expectLater(c.findRowById(1), disabled);
    await expectLater(
        c.loadTable(1, 1, [CellValue(text: 'wrong')], rowIds: [1]), disabled);
    await expectLater(
        c.defineRows(DefineRowsRequest(rows: [
          RowDef(index: 0, rowId: Int64(1), height: 777),
        ])),
        disabled);
    await expectLater(c.create(rowIdsEnabled: true), throwsStateError);
    expect(c.gridId, nativeGrid);
    expect(c.rowIdsEnabled, isFalse);
    expect((await c.getConfig()).layout.rows, 1000000);
    expect(await c.getCellText(0, 0), 'first');
    expect(await c.getCellText(999999, 0), 'last');
    // Existing index-based loading and editing remain usable without IDs.
    await c.loadTable(1, 1, [CellValue(text: 'index-based')]);
    await c.setEditable(true);
    final editing = await c.beginEditState(0, 0);
    expect(editing.active, isTrue);
    expect(editing.session.rowId, Int64.ZERO);
    await c.commitEdit('edited');
    expect(await c.getCellText(0, 0), 'edited');
    await c.destroyGrid();
    expect(c.rowIdsEnabled, isFalse);
    await c.create(rows: 1, cols: 1, rowIdsEnabled: true);
    expect(c.rowIdsEnabled, isTrue);
    expect(await c.getRowId(0), greaterThan(0));
    await expectLater(c.create(), throwsStateError);
    await c.destroyGrid();
    expect(c.rowIdsEnabled, isFalse);
    c.dispose();
  }, skip: skip);
  test('numeric IDs preserve signed64 boundaries through public protobuf APIs',
      () {
    const ids = [9007199254740993, 0x7fffffffffffffff];
    final request = LoadTableRequest(rowIds: ids.map(Int64.new));
    final decoded = LoadTableRequest.fromBuffer(request.writeToBuffer());
    expect(decoded.rowIds.map((id) => id.toInt()), ids);
    final event = GridEvent(afterEdit: AfterEditEvent(rowId: Int64(ids.last)));
    expect(GridEvent.fromBuffer(event.writeToBuffer()).afterEdit.rowId.toInt(),
        ids.last);
  });
  List<VolvoxColumn<Product>> columns() => [
        VolvoxColumn(field: 'name', header: '상품', value: (p) => p.name),
        VolvoxColumn(
            field: 'qty',
            header: '수량',
            value: (p) => p.qty,
            type: VolvoxColumnType.integer,
            editable: true),
      ];
  Future<void> bind(
      WidgetTester tester, VolvoxGridController controller, List<Product> rows,
      {ValueChanged<VolvoxCellEdit<Product>>? onEdit,
      String? Function(VolvoxCellEdit<Product>)? validate,
      List<VolvoxColumn<Product>>? columnDefinitions,
      bool supplyIds = true}) async {
    var ready = false;
    Object? failure;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VolvoxDataGrid<Product>(
      controller: controller,
      rows: rows,
      columns: columnDefinitions ?? columns(),
      getRowId: supplyIds ? (p) => p.id : null,
      active: false,
      onCellEdit: onEdit,
      validateEdit: validate,
      onError: (error, stack) {
        failure = error;
        ready = true;
      },
      onReady: (_) => ready = true,
    ))));
    for (var attempt = 0; !ready && attempt < 1000; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    if (failure != null) throw failure!;
    expect(ready, isTrue, reason: 'Native data application did not finish');
    await tester.pump();
  }

  testWidgets('binding rejects a native ID-disabled controller before writes',
      (tester) async {
    final c = VolvoxGridController();
    await tester.runAsync(() async {
      await c.create(rows: 2, cols: 1);
      await c.setCellText(0, 0, 'existing source');
    });
    final originalGrid = c.gridId;
    final originalConfig =
        (await tester.runAsync(c.getConfig))!.writeToBuffer();
    Object? initializationError;
    try {
      await bind(tester, c, [const Product(1, 'replacement', '2')]);
    } catch (error) {
      initializationError = error;
    }
    expect(
        initializationError,
        isA<StateError>().having((e) => e.message, 'recovery instruction',
            contains('create(rowIdsEnabled: true)')));
    expect(c.gridId, originalGrid);
    expect(c.rowIdsEnabled, isFalse);
    expect(c.clipboardMutationsEnabled, isTrue);
    expect(
        (await tester.runAsync(c.getConfig))!.writeToBuffer(), originalConfig);
    expect(await tester.runAsync(() => c.getCellText(0, 0)), 'existing source');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(c.destroyGrid);
    c.dispose();
  }, skip: skip);

  Future<bool> edit(WidgetTester tester, int row, int col, String text) async {
    final widget =
        tester.widget<VolvoxGridWidget>(find.byType(VolvoxGridWidget));
    final rowId =
        (await tester.runAsync(() => widget.controller.getRowId(row)))!;
    final before = VolvoxGridBeforeEditDetails(
        rawEvent: GridEvent(), row: row, col: col, rowId: rowId);
    await tester.runAsync(() async => await widget.onBeforeEdit!(before));
    if (before.cancel) return false;
    final validating = VolvoxGridCellEditValidatingDetails(
        rawEvent: GridEvent(),
        row: row,
        col: col,
        rowId: rowId,
        editText: text);
    await tester
        .runAsync(() async => await widget.onCellEditValidating!(validating));
    if (validating.cancel) return false;
    final oldText =
        await tester.runAsync(() => widget.controller.getCellText(row, col));
    await tester.runAsync(() => widget.controller.setCellText(row, col, text));
    widget.onGridEvent!(GridEvent(
        afterEdit: AfterEditEvent(
            row: row,
            col: col,
            rowId: Int64(rowId),
            oldText: oldText,
            newText: text)));
    return true;
  }

  Future<void> close(WidgetTester tester, VolvoxGridController c) async {
    await tester.pumpWidget(const SizedBox());
    // Disposing the widget sends a best-effort fling-disable RPC to an externally
    // owned controller. Let its real isolate response reach the fake-async test
    // zone before destroying the native grid and checking pending timers.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    await tester.runAsync(c.destroyGrid);
    await tester.pump();
    c.dispose();
  }

  testWidgets(
      'sort B,A then edit first row targets B; moved permission follows field',
      (tester) async {
    final c = VolvoxGridController();
    final edits = <VolvoxCellEdit<Product>>[];
    const rows = [Product(1, 'A', '100'), Product(2, 'B', '2')];
    await bind(tester, c, rows, onEdit: edits.add);
    expect(await tester.runAsync(c.editable), isTrue);
    expect((await tester.runAsync(c.getSchema))!.columns, hasLength(2));
    await tester.runAsync(() => c.sort(SortOrder.SORT_DESCENDING,
        col: 0, type: SortType.SORT_TYPE_STRING));
    expect(await tester.runAsync(() => c.getCellText(0, 0)), 'B');
    expect(await edit(tester, 0, 1, '9'), isTrue);
    expect(edits.single.row, same(rows[1]));
    expect(edits.single.rowId, 2);
    expect(edits.single.rowIndex, 1);
    expect(edits.single.displayRowIndex, 0);
    await tester.runAsync(() => c.moveColumn(1, 0));
    expect(await edit(tester, 0, 1, 'forbidden'), isFalse);
    expect(await edit(tester, 0, 0, '10'), isTrue);
    expect(edits.last.field, 'qty');
    expect(edits.last.columnIndex, 1);
    expect(edits.last.displayColumnIndex, 0);
    expect(edits.last.rowId, 2);
    await close(tester, c);
  }, skip: skip);
  testWidgets(
      'replacement append delete repeated sorting; validation and clipboard guard',
      (tester) async {
    final c = VolvoxGridController();
    final edits = <VolvoxCellEdit<Product>>[];
    await bind(
        tester, c, [const Product(1, '가', '100'), const Product(2, '나', '2')],
        onEdit: edits.add);
    await tester.runAsync(() => c.sort(SortOrder.SORT_ASCENDING,
        col: 1, type: SortType.SORT_TYPE_NUMERIC));
    expect(await tester.runAsync(() => c.getCellText(0, 0)), '나');
    await tester.runAsync(() => c.moveColumn(0, 1));
    await bind(
        tester,
        c,
        [
          const Product(2, '새 나', '20'),
          const Product(3, '다', '3'),
          const Product(4, '라', '5')
        ],
        onEdit: edits.add,
        validate: (e) => e.newText == '99' ? 'Too many' : null);
    await tester.runAsync(() => c.sort(SortOrder.SORT_ASCENDING,
        col: 1, type: SortType.SORT_TYPE_NUMERIC));
    expect(await edit(tester, 0, 1, '99'), isFalse);
    expect(await edit(tester, 0, 1, 'bad'), isFalse);
    expect(await edit(tester, 0, 1, '4'), isTrue);
    expect(edits.last.rowId, 3);
    expect(edits.last.rowIndex, 1);
    await tester.runAsync(() async {
      await expectLater(c.paste('x\ty'), throwsStateError);
      await expectLater(c.cut(), throwsStateError);
      await expectLater(c.deleteSelection(), throwsStateError);
    });
    await bind(tester, c, [const Product(4, '라', '5')], onEdit: edits.add);
    expect(await edit(tester, 0, 1, '6'), isTrue);
    expect(edits.last.rowId, 4);
    expect(edits.last.rowIndex, 0);
    await close(tester, c);
    expect(c.clipboardMutationsEnabled, isTrue);
  }, skip: skip);
  testWidgets('10000 Korean rows numeric sort and exact value storage',
      (tester) async {
    final c = VolvoxGridController();
    final rows =
        List.generate(10000, (i) => Product(i + 1, '한글 상품 $i', '${10000 - i}'));
    await bind(tester, c, rows);
    await tester.runAsync(() => c.sort(SortOrder.SORT_ASCENDING,
        col: 1, type: SortType.SORT_TYPE_NUMERIC));
    expect(await tester.runAsync(() => c.getCellText(0, 1)), '1');
    expect(await tester.runAsync(() => c.getCellText(0, 0)), '한글 상품 9999');
    await bind(
        tester, c, [const Product(9007199254740993, '정확', '9007199254740993')]);
    expect(
        await tester.runAsync(() => c.getCellText(0, 1)), '9007199254740993');
    await close(tester, c);
  }, skip: skip);
  testWidgets('removing a width restores the scaled default without pinning it',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = VolvoxGridController();
    const rows = [Product(1, 'A', '1')];
    List<VolvoxColumn<Product>> schema(int? width) => [
          VolvoxColumn(
              field: 'name',
              header: 'Name',
              value: (row) => row.name,
              width: width),
        ];
    await bind(tester, c, rows, columnDefinitions: schema(120));
    expect((await tester.runAsync(c.getSchema))!.columns.single.width, 240);

    await bind(tester, c, rows, columnDefinitions: schema(null));
    expect((await tester.runAsync(c.getSchema))!.columns.single.width, 136);

    tester.view.devicePixelRatio = 3;
    await bind(tester, c, rows, columnDefinitions: schema(null));
    expect((await tester.runAsync(c.getSchema))!.columns.single.width, 204);

    // A later data reload must still preserve an interactive width override.
    await tester.runAsync(() => c.setColWidth(0, 400));
    await bind(tester, c, List.of(rows), columnDefinitions: schema(null));
    expect((await tester.runAsync(c.getSchema))!.columns.single.width, 400);
    await close(tester, c);
  }, skip: skip);
  test(
      'native row lookup follows sort move insert delete and metadata assignment',
      () async {
    final c = VolvoxGridController();
    await c.create(rows: 2, cols: 1, rowIdsEnabled: true);
    await c.loadTable(2, 1, [CellValue(text: 'A'), CellValue(text: 'B')],
        atomic: true, rowIds: [9007199254740993, 9223372036854775807]);
    expect(await c.getRowId(0), 9007199254740993);
    for (final invalid in [
      [0, 1],
      [-1, 1],
      [7, 7]
    ]) {
      await expectLater(
          c.loadTable(
              2, 1, [CellValue(text: 'wrong'), CellValue(text: 'wrong')],
              rowIds: invalid),
          throwsA(anything));
      expect(await c.getCellText(0, 0), 'A');
      expect(await c.getRowId(0), 9007199254740993);
    }
    await c.sort(SortOrder.SORT_DESCENDING,
        col: 0, type: SortType.SORT_TYPE_STRING);
    expect(await c.findRowById(9223372036854775807), 0);
    await c.moveRow(0, 1);
    expect(await c.getRowId(1), 9223372036854775807);
    expect(await c.getCellText(1, 0), 'B');
    await c.insertRows(0, text: ['new']);
    final insertedId = await c.getRowId(0);
    expect(insertedId, greaterThan(0));
    expect(insertedId, isNot(isIn([9007199254740993, 9223372036854775807])));
    expect(await c.findRowById(9223372036854775807), 2);
    await c.defineRows(
        DefineRowsRequest(rows: [RowDef(index: 0, rowId: Int64(3))]));
    expect(await c.findRowById(insertedId), isNull);
    final selected = await c.getRows(rowIds: [9223372036854775807, 4, 3]);
    expect(selected.map((r) => r.rowId), [9223372036854775807, 3]);
    await c.removeRows(1);
    expect(await c.findRowById(9007199254740993), isNull);
    expect(await c.findRowById(9223372036854775807), 1);
    await c.destroyGrid();
    c.dispose();
  }, skip: skip);
  testWidgets(
      'empty replacement and engine-generated IDs bind without phantom rows',
      (tester) async {
    final c = VolvoxGridController();
    final edits = <VolvoxCellEdit<Product>>[];
    await bind(tester, c, [], onEdit: edits.add, supplyIds: false);
    expect((await tester.runAsync(c.getSchema))!.columns, hasLength(2));
    expect(await edit(tester, 0, 1, '1'), isFalse);
    const rows = [Product(1, 'A', '100'), Product(2, 'B', '2')];
    await bind(tester, c, rows, onEdit: edits.add, supplyIds: false);
    final originalId = await tester.runAsync(() => c.getRowId(1));
    expect(originalId, greaterThan(0));
    await tester.runAsync(() => c.sort(SortOrder.SORT_DESCENDING,
        col: 0, type: SortType.SORT_TYPE_STRING));
    expect(await edit(tester, 0, 1, '3'), isTrue);
    expect(edits.single.row, same(rows[1]));
    expect(edits.single.rowId, originalId);
    await bind(tester, c, [], onEdit: edits.add, supplyIds: false);
    expect(await tester.runAsync(() => c.findRowById(originalId!)), isNull);
    expect(await edit(tester, 0, 1, '4'), isFalse);
    expect(edits, hasLength(1));
    await close(tester, c);
  }, skip: skip);
}
