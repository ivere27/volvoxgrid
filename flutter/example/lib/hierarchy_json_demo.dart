import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:volvoxgrid/volvoxgrid.dart' hide Padding;

const int _hierNameColumnWidth = 260;
const int _hierTypeColumnWidth = 80;
const int _hierSizeColumnWidth = 80;
const int _hierModifiedColumnWidth = 120;
const int _hierPermissionsColumnWidth = 100;
const int _hierActionColumnWidth = 92;
const List<int> _hierarchyColWidths = [
  _hierNameColumnWidth,
  _hierTypeColumnWidth,
  _hierSizeColumnWidth,
  _hierModifiedColumnWidth,
  _hierPermissionsColumnWidth,
  _hierActionColumnWidth,
];
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
const int _hierarchySizeColumn = 2;
const int _hierarchyModifiedColumn = 3;
const int _hierarchyPermissionsColumn = 4;
const int hierarchyActionColumn = 5;
const int _hierTreeColor = 0xFFA8A29E;
const int _hierFolderTextColor = 0xFF92400E;
const int _hierActionTextColor = 0xFF2563EB;
const int _hierOutlineIndent = 20;
const int _hierMinOutlineIndicatorWidth = 56;
const int _hierNameExpanderWidth = 280;
const int _hierHeaderBandRows = 1;
const int _hierDesktopHeaderHeight = 28;
const int _hierMobileHeaderHeight = 44;
const String _hierShortDateFormat = 'short date';

bool get _hierTouchHeader {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}

int get _hierHeaderHeight =>
    _hierTouchHeader ? _hierMobileHeaderHeight : _hierDesktopHeaderHeight;

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

  final actionStyle = CellStyle()..foreground = _hierActionTextColor;
  final folderStyle = CellStyle()
    ..foreground = _hierFolderTextColor
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
      await controller.setCellStyleRange(
        row,
        hierarchyNameColumn,
        row,
        hierarchyNameColumn,
        folderStyle,
      );
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
    if (col == _hierarchySizeColumn) {
      def.align = Align.ALIGN_RIGHT_CENTER;
    } else if (col == _hierarchyModifiedColumn) {
      def.dataType = ColumnDataType.COLUMN_DATA_DATE;
      def.format = _hierShortDateFormat;
    } else if (col == _hierarchyPermissionsColumn ||
        col == hierarchyActionColumn) {
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
  return _hierarchyOutlineWidth(maxOutlineDepth) + _hierNameExpanderWidth;
}

GridConfig _hierarchyThemeConfig(int maxOutlineDepth, int maxOutlineLevel) {
  final outlineWidth = _hierarchyOutlineWidth(maxOutlineDepth);
  final expanderWidth = _hierarchyExpanderWidth(maxOutlineDepth);
  return GridConfig()
    ..themePreset = ThemePreset.THEME_AMBER
    ..layout = (LayoutConfig()..fixedRows = 0)
    ..selection = (SelectionConfig()..mode = SelectionMode.SELECTION_FREE)
    ..editing = (EditConfig()
      ..activation =
          (EditActivation()..trigger = EditTrigger.EDIT_TRIGGER_NONE))
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
        ..autoSize = false
        ..allowResize = true
        ..slots.add(RowIndicatorSlot()
          ..kind = RowIndicatorSlotKind.ROW_INDICATOR_SLOT_EXPANDER
          ..width = expanderWidth
          ..visible = true))
      ..cornerTopStart = (CornerIndicatorConfig()
        ..visible = true
        ..slots.add(CornerIndicatorSlot()
          ..kind = CornerIndicatorSlotKind.CORNER_SLOT_OUTLINE_LEVELS
          ..width = outlineWidth
          ..visible = true))
      ..colTop = (ColIndicatorConfig()
        ..visible = true
        ..defaultRowHeight = _hierHeaderHeight
        ..bandRows = _hierHeaderBandRows
        ..cellModes = (ColIndicatorCellModes()
          ..modes.add(ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT))
        ..allowResize = true)
      ..appearance = IndicatorAppearance.INDICATOR_APPEARANCE_MODERN);
}
