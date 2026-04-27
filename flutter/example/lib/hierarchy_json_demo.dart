import 'dart:convert';
import 'dart:typed_data';

import 'package:volvoxgrid/volvoxgrid.dart' hide Padding;

const List<int> _hierarchyColWidths = [260, 80, 80, 120, 100, 92];
const List<String> _hierarchyCaptions = [
  'Name',
  'Type',
  'Size',
  'Modified',
  'Permissions',
  'Action',
];
const List<String> _hierarchyKeys = [
  'Name',
  'Type',
  'Size',
  'Modified',
  'Permissions',
  'Action',
];
const int hierarchyActionColumn = 5;

final RegExp _levelPattern = RegExp(r'"_level"\s*:\s*(-?\d+)');
final RegExp _typePattern = RegExp(r'"Type"\s*:\s*"([^"]+)"');
final RegExp _helperFieldPattern = RegExp(r',\s*"_level"\s*:\s*-?\d+');
const int _hierBodyBg = 0xFFFFFFFF;
const int _hierBodyFg = 0xFF1C1917;
const int _hierCanvasBg = 0xFFFAFAF9;
const int _hierAltRowBg = 0xFFF5F5F4;
const int _hierFixedBg = 0xFFF5F5F4;
const int _hierFixedFg = 0xFF44403C;
const int _hierGridColor = 0xFFE7E5E4;
const int _hierFixedGridColor = 0xFFD6D3D1;
const int _hierHeaderBg = 0xFFFAFAF9;
const int _hierHeaderFg = 0xFF1C1917;
const int _hierSelectionBg = 0xFFD97706;
const int _hierSelectionFg = 0xFFFFFFFF;
const int _hierAccent = 0xFFF59E0B;
const int _hierTreeColor = 0xFFA8A29E;
const int _hierHoverCellBg = 0x1AD97706;

Future<void> loadHierarchyJsonDemo(VolvoxGridController controller) async {
  final rawJson = utf8.decode(await controller.getDemoData('hierarchy'));
  final levels = _levelPattern
      .allMatches(rawJson)
      .map((match) => int.parse(match.group(1)!))
      .toList();
  final types =
      _typePattern.allMatches(rawJson).map((match) => match.group(1)!).toList();
  final sanitized = Uint8List.fromList(
    utf8.encode(rawJson.replaceAll(_helperFieldPattern, '')),
  );
  await controller.setColCount(_hierarchyColWidths.length);
  await controller.defineColumns(_hierarchyDefineColumnsRequest());
  final result = await controller.loadData(
    sanitized,
    options: (LoadDataOptions()..autoCreateColumns = false),
  );
  if (result.status == LoadDataStatus.LOAD_FAILED) {
    throw StateError('LoadData failed for embedded hierarchy demo');
  }

  await controller.configure(_hierarchyThemeConfig());

  final actionStyle = CellStyle()..foreground = 0xFF2563EB;
  final folderStyle = CellStyle()
    ..foreground = 0xFF92400E
    ..font = (Font()..bold = true);

  for (var row = 0; row < levels.length; row += 1) {
    final isFolder = row < types.length && types[row] == 'Folder';
    await controller.setRowOutlineLevel(row, levels[row]);
    await controller.setIsSubtotal(row, isFolder);
    await controller.setCellStyleRange(
      row,
      hierarchyActionColumn,
      row,
      hierarchyActionColumn,
      actionStyle,
    );
    if (isFolder) {
      await controller.setCellStyleRange(row, 0, row, 0, folderStyle);
    }
  }
}

DefineColumnsRequest _hierarchyDefineColumnsRequest() {
  final request = DefineColumnsRequest();
  for (var col = 0; col < _hierarchyColWidths.length; col += 1) {
    final def = ColumnDef()
      ..index = col
      ..caption = _hierarchyCaptions[col]
      ..key = _hierarchyKeys[col]
      ..width = _hierarchyColWidths[col];
    if (col == 2) {
      def.align = Align.ALIGN_RIGHT_CENTER;
    } else if (col == 3) {
      def.dataType = ColumnDataType.COLUMN_DATA_DATE;
      def.format = 'short date';
    } else if (col == 4 || col == hierarchyActionColumn) {
      def.align = Align.ALIGN_CENTER_CENTER;
    }
    if (col == hierarchyActionColumn) {
      def.interaction = CellInteraction.CELL_INTERACTION_TEXT_LINK;
    }
    request.columns.add(def);
  }
  return request;
}

GridConfig _hierarchyThemeConfig() {
  return GridConfig()
    ..layout = (LayoutConfig()..fixedRows = 0)
    ..style = (StyleConfig()
      ..background = _hierBodyBg
      ..foreground = _hierBodyFg
      ..alternateBackground = _hierAltRowBg
      ..progressColor = _hierAccent
      ..sheetBackground = _hierCanvasBg
      ..sheetBorder = _hierFixedGridColor
      ..gridLines = (GridLines()
        ..style = GridLineStyle.GRIDLINE_SOLID
        ..color = _hierGridColor)
      ..fixed = (RegionStyle()
        ..background = _hierFixedBg
        ..foreground = _hierFixedFg
        ..gridLines = (GridLines()
          ..style = GridLineStyle.GRIDLINE_SOLID
          ..color = _hierFixedGridColor))
      ..frozen = (RegionStyle()
        ..background = _hierBodyBg
        ..foreground = _hierBodyFg
        ..gridLines = (GridLines()
          ..style = GridLineStyle.GRIDLINE_SOLID
          ..color = _hierFixedGridColor))
      ..header = (HeaderStyle()
        ..separator = (HeaderSeparator()
          ..enabled = true
          ..color = _hierFixedGridColor
          ..width = 1)
        ..resizeHandle = (HeaderResizeHandle()
          ..enabled = true
          ..color = _hierFixedGridColor
          ..width = 1
          ..hitWidth = 6)))
    ..selection = (SelectionConfig()
      ..mode = SelectionMode.SELECTION_FREE
      ..style = (HighlightStyle()
        ..background = _hierSelectionBg
        ..foreground = _hierSelectionFg
        ..fillHandle = FillHandlePosition.FILL_HANDLE_NONE
        ..fillHandleColor = _hierAccent)
      ..activeCellStyle = (HighlightStyle()
        ..background = 0x22000000
        ..foreground = _hierSelectionFg
        ..borders = (Borders()
          ..all = (Border()
            ..style = BorderStyle.BORDER_THICK
            ..color = _hierAccent)))
      ..hover = (HoverConfig()
        ..cell = true
        ..cellStyle = (HighlightStyle()
          ..background = _hierHoverCellBg
          ..borders = (Borders()
            ..all = (Border()
              ..style = BorderStyle.BORDER_THIN
              ..color = _hierAccent)))))
    ..editing = (EditConfig()
      ..trigger = EditTrigger.EDIT_TRIGGER_NONE
      ..dropdownTrigger = DropdownTrigger.DROPDOWN_NEVER)
    ..scrolling = (ScrollConfig()
      ..scrollbars = ScrollBarsMode.SCROLLBAR_BOTH
      ..flingEnabled = true
      ..flingImpulseGain = 220.0
      ..flingFriction = 0.9)
    ..outline = (OutlineConfig()
      ..treeIndicator = TreeIndicatorStyle.TREE_INDICATOR_ARROWS_LEAF
      ..treeColumn = 0
      ..treeColor = _hierTreeColor)
    ..interaction = (InteractionConfig()
      ..resize = (ResizePolicy()
        ..columns = true
        ..rows = true)
      ..autoSizeMouse = true
      ..headerFeatures = (HeaderFeatures()
        ..sort = false
        ..reorder = false
        ..chooser = false))
    ..indicators = (IndicatorsConfig()
      ..rowStart = (RowIndicatorConfig()..visible = false)
      ..colTop = (ColIndicatorConfig()
        ..visible = true
        ..defaultRowHeight = 28
        ..bandRows = 1
        ..modeBits = ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT.value
        ..background = _hierHeaderBg
        ..foreground = _hierHeaderFg
        ..gridColor = _hierFixedGridColor
        ..allowResize = true));
}
