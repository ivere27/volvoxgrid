import 'package:volvoxgrid/volvoxgrid_controller.dart';
import 'package:volvoxgrid/volvoxgrid_ffi.dart' as vg;

import 'types.dart';

const int _whiteArgb = 0xFFFFFFFF;
const String _sortNoneGlyph = '⇅';
const String _sortAscendingGlyph = '↑';
const String _sortDescendingGlyph = '↓';

vg.GridLines mapGridLines(GridLinesVisibility visibility) {
  final lines = vg.GridLines()..style = vg.GridLineStyle.GRIDLINE_SOLID;
  switch (visibility) {
    case GridLinesVisibility.none:
      lines.style = vg.GridLineStyle.GRIDLINE_NONE;
      lines.direction = vg.GridLineDirection.GRIDLINE_BOTH;
      return lines;
    case GridLinesVisibility.horizontal:
      lines.direction = vg.GridLineDirection.GRIDLINE_HORIZONTAL;
      return lines;
    case GridLinesVisibility.vertical:
      lines.direction = vg.GridLineDirection.GRIDLINE_VERTICAL;
      return lines;
    case GridLinesVisibility.both:
      lines.direction = vg.GridLineDirection.GRIDLINE_BOTH;
      return lines;
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
    ..fixed = (vg.RegionStyle()..background = _whiteArgb)
    ..icons = (vg.IconTheme()
      ..slots = (vg.IconSlots()
        ..sortNone = allowSorting ? _sortNoneGlyph : ''
        ..sortAscending = allowSorting ? _sortAscendingGlyph : ''
        ..sortDescending = allowSorting ? _sortDescendingGlyph : ''));
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
          ..indicators = (vg.IndicatorsConfig()
            ..colTop = (vg.ColIndicatorConfig()
              ..visible = true
              ..bandRows = 1
              ..defaultRowHeight = headerRowHeight.round()))),
    );
  }
}
