import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' as services;
import 'package:flutter_test/flutter_test.dart';
import 'package:volvoxgrid/volvoxgrid.dart';
import 'package:volvoxgrid/volvoxgrid.dart' as vg;

class RecordingController extends VolvoxGridController {
  RecordingController(this.id);
  final int id;
  final outputs = StreamController<RenderOutput>.broadcast();
  final events = StreamController<GridEvent>.broadcast();
  final inputs = <RenderInput>[];
  final committed = <String>[];
  int sessions = 0;
  int columnReads = 0;
  Completer<int>? delayedRowCount;

  @override
  bool get isCreated => true;
  @override
  Int64 get gridId => Int64(id);
  @override
  Stream<RenderOutput> renderSession(Stream<RenderInput> stream) {
    sessions++;
    stream.listen(inputs.add);
    return outputs.stream;
  }

  @override
  Stream<GridEvent> eventStream() => events.stream;
  @override
  Future<void> setFlingEnabled(bool enabled) async {}
  @override
  Future<void> setFastScrollEnabled(bool enabled) async {}
  @override
  Future<int> rowCount() => delayedRowCount?.future ?? Future.value(2);
  @override
  Future<int> colCount() async {
    columnReads++;
    return 2;
  }

  @override
  Future<int> getRowHeight(int row) async => 24;
  @override
  Future<CellsResponse> getCellsRange(int row1, int col1, int row2, int col2,
          {bool includeStyle = false,
          bool includeChecked = false,
          bool includeTyped = false,
          bool includeRichText = false}) async =>
      CellsResponse();

  @override
  Future<EditState> commitEditState(String text,
      {bool cancel = false, Int64? sessionId, Int64? stateVersion}) async {
    committed.add(text);
    return EditState()..active = false;
  }

  @override
  Future<void> cancelEdit({Int64? sessionId, Int64? stateVersion}) async {}

  @override
  Future<EditCellStyle?> getEditCellStyle(int row, int col) async =>
      const EditCellStyle(fontSize: 13);
}

Widget app(RecordingController controller,
    {bool active = true,
    bool tickers = true,
    bool allowBulkEdits = true,
    FutureOr<void> Function(VolvoxGridBeforeEditDetails)? beforeEdit,
    ValueChanged<GridEvent>? onEvent}) {
  return MaterialApp(
    home: Scaffold(
      body: TickerMode(
        enabled: tickers,
        child: VolvoxGridWidget(
          controller: controller,
          active: active,
          allowBulkEdits: allowBulkEdits,
          onBeforeEdit: beforeEdit,
          onGridEvent: onEvent,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('inactive tab and TickerMode suspend native sessions and events',
      (tester) async {
    final controller = RecordingController(1);
    var eventCount = 0;
    void event(GridEvent _) => eventCount++;
    await tester.pumpWidget(app(controller, active: false, onEvent: event));
    await tester.pump();
    expect(controller.sessions, 0);
    expect(controller.events.hasListener, isFalse);

    await tester.pumpWidget(app(controller, onEvent: event));
    await tester.pump();
    expect(controller.sessions, 1);
    controller.events.add(GridEvent());
    await tester.pump();
    expect(eventCount, 1);

    await tester.pumpWidget(app(controller, tickers: false, onEvent: event));
    await tester.pump();
    expect(controller.events.hasListener, isFalse);
    final sent = controller.inputs.length;
    controller.notifyListeners();
    controller.events.add(GridEvent());
    await tester.pump();
    expect(controller.inputs.length, sent);
    expect(eventCount, 1);

    await tester.pumpWidget(app(controller, onEvent: event));
    await tester.pump();
    expect(controller.sessions, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('controller replacement cancels stale snapshot continuation',
      (tester) async {
    final old = RecordingController(1)..delayedRowCount = Completer<int>();
    final next = RecordingController(2);
    await tester.pumpWidget(app(old));
    await tester.pump();
    await tester.pumpWidget(app(next));
    await tester.pump();
    final reads = next.columnReads;
    old.delayedRowCount!.complete(10);
    await tester.pump();
    expect(old.columnReads, 0);
    expect(next.columnReads, reads);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late edit decision cannot authorize replacement controller',
      (tester) async {
    final old = RecordingController(1);
    final next = RecordingController(2);
    final decision = Completer<void>();
    int? emittedRowId;
    await tester.pumpWidget(app(old, beforeEdit: (event) {
      emittedRowId = event.rowId;
      return decision.future;
    }));
    await tester.pump();
    old.events.add(GridEvent()
      ..eventId = Int64(42)
      ..beforeEdit = (BeforeEditEvent()
        ..row = 0
        ..col = 0
        ..rowId = Int64(9007199254740993)));
    await tester.pump();
    expect(emittedRowId, 9007199254740993);
    await tester.pumpWidget(app(next));
    decision.complete();
    await tester.pump();
    expect(
        [...old.inputs, ...next.inputs].where((input) =>
            input.hasEventDecision() &&
            input.eventDecision.eventId == Int64(42)),
        isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bulk delete cut paste keys do not bypass cell validation',
      (tester) async {
    final controller = RecordingController(1);
    await tester.pumpWidget(app(controller, allowBulkEdits: false));
    await tester.pump();
    controller.inputs.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    final keys = controller.inputs.where((input) => input.hasKey()).toList();
    expect(keys.where((input) => [8, 46, 86, 88].contains(input.key.keyCode)),
        isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unbounded scroll parent receives actionable viewport error',
      (tester) async {
    final controller = RecordingController(1);
    await tester.pumpWidget(MaterialApp(
      home: SingleChildScrollView(
        child: VolvoxGridWidget(controller: controller),
      ),
    ));
    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(error.toString(), contains('finite viewport'));
    expect(error.toString(), contains('SizedBox'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('host editor preserves Korean composing text until submission',
      (tester) async {
    final controller = RecordingController(1);
    await tester.pumpWidget(app(controller, allowBulkEdits: false));
    await tester.pump();
    controller.outputs.add(RenderOutput()
      ..editorStarted = (EditorSessionStarted()
        ..session = (EditorSession()
          ..sessionId = Int64(1)
          ..row = 0
          ..col = 0
          ..viewportRect = (vg.Rect()
            ..x = 0
            ..y = 30
            ..width = 180
            ..height = 40)
          ..editor = (EditorSpec()
            ..kind = EditorKind.EDITOR_TEXT
            ..presentation = EditorPresentation.EDITOR_INLINE)
          ..value = (EditorValue()..editText = ''))));
    await tester.pump();
    await tester.pump();
    for (final text in ['ㅎ', '하', '한']) {
      tester.testTextInput.updateEditingValue(TextEditingValue(
        text: text,
        selection: services.TextSelection.collapsed(offset: text.length),
        composing: TextRange(start: 0, end: text.length),
      ));
      await tester.pump();
    }
    expect(controller.committed, isEmpty);
    final field = tester.widgetList<TextField>(find.byType(TextField)).last;
    expect(field.controller!.value.text, '한');
    expect(
        field.controller!.value.composing, const TextRange(start: 0, end: 1));

    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '한글',
      selection: services.TextSelection.collapsed(offset: 2),
    ));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(controller.committed, ['한글']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('touch drag forwards scroll without a pressed mouse button',
      (tester) async {
    final controller = RecordingController(1);
    await tester.pumpWidget(app(controller));
    await tester.pump();
    controller.inputs.clear();
    final gesture = await tester.startGesture(const Offset(200, 200));
    await gesture.moveBy(const Offset(0, -80));
    await gesture.up();
    await tester.pump();
    expect(controller.inputs.where((input) => input.hasScroll()), isNotEmpty);
    expect(
      controller.inputs
          .where((input) => input.hasPointer())
          .every((input) => input.pointer.button == 0),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
