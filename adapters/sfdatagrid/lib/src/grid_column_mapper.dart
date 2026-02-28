import 'package:flutter/widgets.dart';
import 'package:volvoxgrid/volvoxgrid_controller.dart';
import 'package:volvoxgrid/volvoxgrid_ffi.dart' as vg;

import 'sort_mapper.dart';
import 'types.dart';

class MappedGridColumn {
  final GridColumn source;
  final int index;
  final String headerText;

  const MappedGridColumn({
    required this.source,
    required this.index,
    required this.headerText,
  });
}

class GridColumnMapping {
  final List<MappedGridColumn> columns;
  final Map<String, int> indexByName;

  const GridColumnMapping({required this.columns, required this.indexByName});

  int get count => columns.length;
}

String _extractLabelText(Widget label, String fallback) {
  if (label is Text) {
    if (label.data != null && label.data!.trim().isNotEmpty) {
      return label.data!;
    }
    final span = label.textSpan;
    if (span != null) {
      final text = span.toPlainText();
      if (text.trim().isNotEmpty) {
        return text;
      }
    }
  }
  return fallback;
}

GridColumnMapping mapGridColumns(List<GridColumn> columns) {
  final mapped = <MappedGridColumn>[];
  final indexByName = <String, int>{};

  for (var i = 0; i < columns.length; i += 1) {
    final source = columns[i];
    final headerText = _extractLabelText(source.label, source.columnName);
    mapped.add(
      MappedGridColumn(source: source, index: i, headerText: headerText),
    );
    indexByName[source.columnName] = i;
  }

  return GridColumnMapping(columns: mapped, indexByName: indexByName);
}

Future<void> applyGridColumns(
  VolvoxGridController controller,
  GridColumnMapping mapping, {
  required int headerRow,
  required int footerFrozenColumnsCount,
  required bool allowSorting,
  required List<SortColumnDetails> sortedColumns,
}) async {
  final defineReq = vg.DefineColumnsRequest()..gridId = controller.gridId;
  final sortOrderByName = <String, vg.SortOrder>{};
  for (final sort in sortedColumns) {
    sortOrderByName[sort.name] = mapSortDirection(sort.sortDirection);
  }

  final stickyStart = footerFrozenColumnsCount > 0
      ? (mapping.count - footerFrozenColumnsCount).clamp(0, mapping.count)
      : mapping.count;

  for (final mapped in mapping.columns) {
    final col = mapped.source;
    final columnDef = vg.ColumnDef()..index = mapped.index;

    if (col.width.isFinite && col.width > 0) {
      columnDef.width = col.width.round();
    }
    if (col.minimumWidth.isFinite && col.minimumWidth > 0) {
      columnDef.minWidth = col.minimumWidth.round();
    }
    if (col.maximumWidth.isFinite && col.maximumWidth > 0) {
      columnDef.maxWidth = col.maximumWidth.round();
    }

    // Match SfDataGrid's common row-adapter default (left/center text).
    columnDef.alignment = vg.Align.ALIGN_LEFT_CENTER;
    columnDef.fixedAlignment = vg.Align.ALIGN_LEFT_CENTER;

    columnDef.key = col.columnName;
    columnDef.hidden = !col.visible;

    if (mapped.index >= stickyStart) {
      columnDef.sticky = vg.StickyEdge.STICKY_RIGHT;
    }

    if (allowSorting && col.allowSorting) {
      columnDef.sort =
          sortOrderByName[col.columnName] ?? vg.SortOrder.SORT_NONE;
    }

    defineReq.columns.add(columnDef);
  }

  await vg.VolvoxGridServiceFfi.DefineColumns(defineReq);

  for (final mapped in mapping.columns) {
    await controller.setTextMatrix(headerRow, mapped.index, mapped.headerText);
  }
}
