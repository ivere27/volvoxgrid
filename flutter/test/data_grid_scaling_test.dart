import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volvoxgrid/volvoxgrid.dart';

import 'data_grid_lifecycle_test.dart' show DelayedController;

class ScalingController extends DelayedController {
  double? creationScale;
  GridConfig? configured;
  DefineColumnsRequest? defined;

  @override
  Future<void> create(
      {int rows = 50,
      int cols = 10,
      int viewportWidth = 800,
      int viewportHeight = 600,
      double scale = 1,
      bool rowIdsEnabled = false}) {
    creationScale = scale;
    return super.create(
        rows: rows,
        cols: cols,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        scale: scale,
        rowIdsEnabled: rowIdsEnabled);
  }

  @override
  Future<void> configure(GridConfig config) async {
    configured = config;
    await super.configure(config);
  }

  @override
  Future<void> defineColumns(DefineColumnsRequest request) async {
    defined = request;
    await super.defineColumns(request);
  }
}

void main() {
  testWidgets('logical grid metrics combine text scaling and device pixels',
      (tester) async {
    final controller = ScalingController()..createGate.complete();
    final rows = ['item'];
    Widget app(double dpr) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
                devicePixelRatio: dpr,
                textScaler: const TextScaler.linear(1.5)),
            child: Material(
                child: VolvoxDataGrid<String>(
              controller: controller,
              active: false,
              rows: rows,
              columns: [
                VolvoxColumn(
                    field: 'name',
                    header: 'Name',
                    value: (row) => row,
                    width: 120)
              ],
            )),
          ),
        );
    await tester.pumpWidget(app(3));
    await tester.pump();
    expect(controller.creationScale, 3);
    expect(controller.configured!.style.font.size, 63);
    expect(controller.configured!.layout.defaultRowHeight, 144);
    expect(controller.configured!.layout.defaultColWidth, 204);
    expect(controller.configured!.indicators.colTop.defaultRowHeight, 144);
    expect(controller.defined!.columns.first.width, 360);

    await tester.pumpWidget(app(2));
    await tester.pump();
    expect(controller.configured!.style.font.size, 42);
    expect(controller.configured!.layout.defaultRowHeight, 96);
    expect(controller.defined!.columns.first.width, 240);
    expect(controller.values.first.text, 'item');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
