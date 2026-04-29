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
const int hierarchyNameColumn = 0;
const int hierarchyActionColumn = 5;

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
const int _hierOutlineIndent = 20;
const int _hierMinOutlineIndicatorWidth = 56;

Future<void> loadHierarchyJsonDemo(VolvoxGridController controller) async {
  final rawJson = utf8.decode(await controller.getDemoData('hierarchy'));
  final rows = (jsonDecode(rawJson) as List<dynamic>)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();
  final levels = _hierarchyLevels(rows);
  final types = rows.map((row) => _hierarchyString(row, 'Type')).toList();
  final visibleRows = rows.map(_hierarchyVisibleRow).toList();
  final sanitized = Uint8List.fromList(
    utf8.encode(jsonEncode(visibleRows)),
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

  await controller.configure(
    _hierarchyThemeConfig(
      _hierarchyMaxVisualDepth(levels),
      _hierarchyMaxLevel(levels),
    ),
  );

  final actionStyle = CellStyle()..foreground = 0xFF2563EB;
  final folderStyle = CellStyle()
    ..foreground = 0xFF92400E
    ..font = (Font()..bold = true);

  for (var row = 0; row < levels.length; row += 1) {
    final isFolder = row < types.length && types[row] == 'Folder';
    await controller.setRowOutlineLevel(row, levels[row]);
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

String _hierarchyString(Map<String, dynamic> row, String key) =>
    row[key]?.toString() ?? '';

Map<String, dynamic> _hierarchyVisibleRow(Map<String, dynamic> row) {
  return {
    for (final key in _hierarchyKeys) key: row[key] ?? '',
  };
}

List<int> _hierarchyLevels(List<Map<String, dynamic>> rows) {
  final rowsById = <String, Map<String, dynamic>>{};
  for (final row in rows) {
    final id = _hierarchyString(row, 'Id');
    if (id.isEmpty) {
      throw StateError('Hierarchy demo row is missing Id');
    }
    rowsById[id] = row;
  }

  final cache = <String, int>{};
  int depthOf(Map<String, dynamic> row, Set<String> visiting) {
    final id = _hierarchyString(row, 'Id');
    final cached = cache[id];
    if (cached != null) {
      return cached;
    }
    if (!visiting.add(id)) {
      throw StateError('Hierarchy demo data contains a parent cycle at $id');
    }
    final parentId = row['ParentId']?.toString() ?? '';
    var depth = 0;
    if (parentId.isNotEmpty) {
      final parent = rowsById[parentId];
      if (parent == null) {
        throw StateError(
            'Hierarchy demo data references missing parent $parentId');
      }
      depth = depthOf(parent, visiting) + 1;
    }
    visiting.remove(id);
    cache[id] = depth;
    return depth;
  }

  return rows.map((row) => depthOf(row, <String>{})).toList();
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
    if (col == hierarchyNameColumn) {
      def.hidden = true;
    }
    request.columns.add(def);
  }
  return request;
}

int _hierarchyMaxVisualDepth(List<int> levels) {
  var hasMinLevel = false;
  var minLevel = 0;
  var maxLevel = 0;
  for (final level in levels) {
    if (level >= 0 && (!hasMinLevel || level < minLevel)) {
      hasMinLevel = true;
      minLevel = level;
    }
    if (level > maxLevel) {
      maxLevel = level;
    }
  }
  final depth = maxLevel - minLevel;
  return depth < 0 ? 0 : depth;
}

int _hierarchyMaxLevel(List<int> levels) {
  var hasMaxLevel = false;
  var maxLevel = 0;
  for (final level in levels) {
    if (level >= 0 && (!hasMaxLevel || level > maxLevel)) {
      hasMaxLevel = true;
      maxLevel = level;
    }
  }
  return hasMaxLevel ? maxLevel : 0;
}

int _hierarchyOutlineWidth(int maxOutlineDepth) {
  final sanitizedMaxDepth = maxOutlineDepth < 0 ? 0 : maxOutlineDepth;
  final width = (sanitizedMaxDepth + 1) * _hierOutlineIndent;
  return width < _hierMinOutlineIndicatorWidth
      ? _hierMinOutlineIndicatorWidth
      : width;
}

int _hierarchyExpanderWidth(int maxOutlineDepth) {
  return _hierarchyOutlineWidth(maxOutlineDepth) + 280;
}

GridConfig _hierarchyThemeConfig(int maxOutlineDepth, int maxOutlineLevel) {
  final outlineWidth = _hierarchyOutlineWidth(maxOutlineDepth);
  final expanderWidth = _hierarchyExpanderWidth(maxOutlineDepth);
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
      ..indicatorIndent = _hierOutlineIndent
      ..maxLevels = maxOutlineLevel < 0 ? 0 : maxOutlineLevel
      ..showLevelButtons = true
      ..labelColumn = hierarchyNameColumn
      ..treeColor = _hierTreeColor)
    ..interaction = (InteractionConfig()
      ..resize = (ResizePolicy()
        ..columns = true
        ..rows = false)
      ..autoSizeMouse = true
      ..headerFeatures = (HeaderFeatures()
        ..sort = false
        ..reorder = false
        ..chooser = false))
    ..indicators = (IndicatorsConfig()
      ..rowStart = (RowIndicatorConfig()
        ..visible = true
        ..width = expanderWidth
        ..background = _hierHeaderBg
        ..foreground = _hierFixedFg
        ..gridColor = _hierFixedGridColor
        ..autoSize = false
        ..allowResize = true
        ..slots.add(RowIndicatorSlot()
          ..kind = RowIndicatorSlotKind.ROW_INDICATOR_SLOT_EXPANDER
          ..width = expanderWidth
          ..visible = true))
      ..cornerTopStart = (CornerIndicatorConfig()
        ..visible = true
        ..background = _hierHeaderBg
        ..foreground = _hierFixedFg
        ..slots.add(CornerIndicatorSlot()
          ..kind = CornerIndicatorSlotKind.CORNER_SLOT_OUTLINE_LEVELS
          ..width = outlineWidth
          ..visible = true))
      ..colTop = (ColIndicatorConfig()
        ..visible = true
        ..defaultRowHeight = 28
        ..bandRows = 1
        ..modeBits = ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT.value
        ..background = _hierHeaderBg
        ..foreground = _hierHeaderFg
        ..gridColor = _hierFixedGridColor
        ..allowResize = true)
      ..appearance = IndicatorAppearance.INDICATOR_APPEARANCE_MODERN);
}
