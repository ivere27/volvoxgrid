// Public API with the real engine, event decision channel, and Flutter editor.
// No callbacks/events are synthesized and no private widget state is accessed.
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volvoxgrid/volvoxgrid.dart';

class _Product {
  const _Product(this.id, this.name, this.qty);
  final int id;
  final String name, qty;
}

void main() {
  final library = Platform.environment['VOLVOXGRID_TEST_LIB'];
  setUpAll(() async {
    if (library == null) return;
    await initVolvoxGrid(libraryName: library);
    final warmup = VolvoxGridController();
    await warmup.create(rows: 1, cols: 1);
    await warmup.destroyGrid();
    warmup.dispose();
  });

  Future<void> until(
      WidgetTester tester, bool Function() condition, String reason) async {
    for (var attempt = 0; !condition() && attempt < 500; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(condition(), isTrue, reason: reason);
  }

  Future<T> native<T>(WidgetTester tester, Future<T> Function() action) async {
    var done = false;
    T? value;
    Object? error;
    await tester.runAsync(() async {
      action().then((result) {
        value = result;
        done = true;
      }, onError: (Object failure) {
        error = failure;
        done = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1));
    });
    await until(tester, () => done, 'Native operation did not finish');
    if (error != null) throw error!;
    return value as T;
  }

  testWidgets('live edit channel validates and commits the sorted source row',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = VolvoxGridController();
    final edits = <VolvoxCellEdit<_Product>>[];
    final rejections = <String>[];
    var ready = false;
    Object? loadError;
    const rows = [
      _Product(1, '가', '100'),
      _Product(9007199254740993, '나', '2')
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: VolvoxDataGrid<_Product>(
        controller: controller,
        rows: rows,
        getRowId: (row) => row.id,
        columns: [
          VolvoxColumn(
              field: 'name',
              header: '상품',
              value: (row) => row.name,
              width: 180),
          VolvoxColumn(
              field: 'qty',
              header: '수량',
              value: (row) => row.qty,
              type: VolvoxColumnType.integer,
              editable: true,
              width: 180),
        ],
        validateEdit: (edit) => edit.newText == '99' ? 'Too many' : null,
        onValidationError: rejections.add,
        onCellEdit: edits.add,
        onError: (error, _) {
          loadError = error;
          ready = true;
        },
        onReady: (_) => ready = true,
      ),
    )));
    await until(tester, () => ready, 'Data binding did not finish');
    if (loadError != null) throw loadError!;
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await native(
        tester,
        () => controller.sort(SortOrder.SORT_ASCENDING,
            col: 1, type: SortType.SORT_TYPE_NUMERIC));
    expect(await native(tester, () => controller.getCellText(0, 0)), '나');

    await native(tester, () => controller.beginEdit(0, 1));
    await until(tester, () => find.byType(TextField).evaluate().length >= 2,
        'The live host editor did not open');
    final state = await native(tester, controller.getEditState);
    expect(state.session.rowId.toInt(), 9007199254740993);
    expect(state.session.viewportRect.height, 32,
        reason: 'The configured row height must survive data loading');
    final schema = await native(tester, controller.getSchema);
    expect(schema.columns.first.width, 180,
        reason: 'The configured column width must survive data loading');
    final editor = find.byType(TextField).last;
    await tester.enterText(editor, '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await until(tester, () => rejections.isNotEmpty,
        'The live validation event did not reach the binding');
    expect(edits, isEmpty);
    expect(await native(tester, () => controller.getCellText(0, 1)), '2');

    await tester.enterText(editor, '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await until(tester, () => edits.isNotEmpty,
        'The live afterEdit event did not reach onCellEdit');
    expect(edits.single.row, same(rows[1]));
    expect(edits.single.rowId, 9007199254740993);
    expect(edits.single.rowIndex, 1);
    expect(edits.single.displayRowIndex, 0);
    expect(edits.single.field, 'qty');
    expect(edits.single.newText, '7');
    expect(await native(tester, () => controller.getCellText(0, 1)), '7');

    await until(tester, () => find.byType(TextField).evaluate().length == 1,
        'Committed editor did not close');
    await native(tester, () => controller.moveColumn(1, 0));
    final readOnlyCell = tester.getTopLeft(find.byType(VolvoxGridWidget)) +
        const Offset(270, 44);
    await tester.tapAt(readOnlyCell, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(readOnlyCell, kind: PointerDeviceKind.mouse);
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(TextField), findsOneWidget,
        reason: 'Double-click must not open the moved read-only column');
    await native(tester, () => controller.beginEdit(0, 1));
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(TextField), findsOneWidget); // hidden IME proxy only
    expect(await native(tester, () => controller.getCellText(0, 1)), '나');
    final editableCell =
        tester.getTopLeft(find.byType(VolvoxGridWidget)) + const Offset(90, 44);
    await tester.tapAt(editableCell, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(editableCell, kind: PointerDeviceKind.mouse);
    await until(tester, () => find.byType(TextField).evaluate().length == 2,
        'Double-click must open the moved editable column');
    await tester.enterText(find.byType(TextField).last, '8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await until(tester, () => edits.length == 2,
        'Moved editable column did not commit through its live channel');
    expect(edits.last.field, 'qty');
    expect(edits.last.columnIndex, 1);
    expect(edits.last.displayColumnIndex, 0);
    expect(edits.last.rowId, 9007199254740993);
    expect(await native(tester, () => controller.getCellText(0, 0)), '8');
    await tester.pumpWidget(const SizedBox());
    await native(tester, controller.destroyGrid);
    controller.dispose();
  }, skip: library == null);
}
