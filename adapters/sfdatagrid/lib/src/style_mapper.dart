import 'package:volvoxgrid/volvoxgrid_controller.dart';
import 'package:volvoxgrid/volvoxgrid_ffi.dart' as vg;

import 'types.dart';

const int _whiteArgb = 0xFFFFFFFF;
const String _sortNoneGlyph = '⇅';
const String _sortAscendingGlyph = '↑';
const String _sortDescendingGlyph = '↓';

vg.GridLineStyle mapGridLines(GridLinesVisibility visibility) {
  switch (visibility) {
    case GridLinesVisibility.none:
      return vg.GridLineStyle.GRIDLINE_NONE;
    case GridLinesVisibility.horizontal:
      return vg.GridLineStyle.GRIDLINE_SOLID_HORIZONTAL;
    case GridLinesVisibility.vertical:
      return vg.GridLineStyle.GRIDLINE_SOLID_VERTICAL;
    case GridLinesVisibility.both:
      return vg.GridLineStyle.GRIDLINE_SOLID;
  }
}

Future<void> applyStyleConfig(
  VolvoxGridController controller, {
  required GridLinesVisibility gridLinesVisibility,
  required bool allowSorting,
  required double rowHeight,
  required double headerRowHeight,
  required double defaultColumnWidth,
}) async {
  final style = vg.StyleConfig()
    ..gridLines = mapGridLines(gridLinesVisibility)
    // Syncfusion's header/fixed area is white by default.
    ..backColorFixed = _whiteArgb
    ..iconThemeSlots = (vg.IconThemeSlots()
      ..sortNone = allowSorting ? _sortNoneGlyph : ''
      ..sortAscending = allowSorting ? _sortAscendingGlyph : ''
      ..sortDescending = allowSorting ? _sortDescendingGlyph : '');
  await controller.setGridStyle(style);

  final layout = vg.LayoutConfig();
  var shouldConfigureLayout = false;

  if (rowHeight.isFinite && rowHeight > 0) {
    layout.defaultRowHeight = rowHeight.round();
    shouldConfigureLayout = true;
  }
  if (defaultColumnWidth.isFinite && defaultColumnWidth > 0) {
    layout.defaultColWidth = defaultColumnWidth.round();
    shouldConfigureLayout = true;
  }

  if (shouldConfigureLayout) {
    await vg.VolvoxGridServiceFfi.Configure(
      vg.ConfigureRequest()
        ..gridId = controller.gridId
        ..config = (vg.GridConfig()..layout = layout),
    );
  }

  if (headerRowHeight.isFinite && headerRowHeight > 0) {
    await vg.VolvoxGridServiceFfi.Configure(
      vg.ConfigureRequest()
        ..gridId = controller.gridId
        ..config = (vg.GridConfig()
          ..indicatorBands = (vg.IndicatorBandsConfig()
            ..colIndicatorTop = (vg.ColIndicatorConfig()
              ..visible = true
              ..bandRows = 1
              ..defaultRowHeightPx = headerRowHeight.round()))),
    );
  }
}
