import 'dart:math' as math;

import 'dart:ui' show Offset;
import 'package:volvoxgrid/volvoxgrid_controller.dart';
import 'package:volvoxgrid/volvoxgrid_ffi.dart' as vg;

import 'grid_column_mapper.dart';
import 'types.dart';

class SfDataGridEventMapper {
  final VolvoxGridController controller;
  final GridColumnMapping Function() getColumns;
  final List<DataGridRow> Function() getShadowRows;
  final int Function() getHeaderRows;

  final SelectionChangingCallback? onSelectionChanging;
  final SelectionChangedCallback? onSelectionChanged;
  final CellTapCallback? onCellTap;
  final ColumnResizeStartCallback? onColumnResizeStart;
  final ColumnResizeUpdateCallback? onColumnResizeUpdate;

  Set<int> _selectedRows = <int>{};

  SfDataGridEventMapper({
    required this.controller,
    required this.getColumns,
    required this.getShadowRows,
    required this.getHeaderRows,
    this.onSelectionChanging,
    this.onSelectionChanged,
    this.onCellTap,
    this.onColumnResizeStart,
    this.onColumnResizeUpdate,
  });

  Future<void> syncSelectionSnapshot() async {
    final selection = await controller.getSelection();
    _selectedRows = _selectionIndicesFromRanges(
      selection.ranges,
      fallbackActiveRow: selection.activeRow,
    );
  }

  bool onCancelableGridEvent(vg.GridEvent event) {
    if (event.hasBeforeUserResize() && onColumnResizeStart != null) {
      final col = event.beforeUserResize.col;
      if (col < 0 || col >= getColumns().count) {
        return false;
      }
      final mapped = getColumns().columns[col];
      final width = mapped.source.width.isFinite ? mapped.source.width : 0.0;
      final allow = onColumnResizeStart!(
        ColumnResizeStartDetails(
          columnName: mapped.source.columnName,
          width: width,
        ),
      );
      return !allow;
    }

    if (event.hasSelectionChanging() && onSelectionChanging != null) {
      final proposed = _selectionIndicesFromRanges(
        event.selectionChanging.newRanges,
        fallbackActiveRow: event.selectionChanging.activeRow,
      );
      final added = _rowsFromIndices(proposed.difference(_selectedRows));
      final removed = _rowsFromIndices(_selectedRows.difference(proposed));
      final allow = onSelectionChanging!(added, removed);
      return !allow;
    }

    return false;
  }

  Future<void> onGridEvent(vg.GridEvent event) async {
    if (event.hasSelectionChanged()) {
      await _emitSelectionChanged();
    }

    if (event.hasAfterUserResize() && onColumnResizeUpdate != null) {
      final col = event.afterUserResize.col;
      if (col >= 0 && col < getColumns().count) {
        final mapped = getColumns().columns[col];
        final width = mapped.source.width.isFinite ? mapped.source.width : 0.0;
        onColumnResizeUpdate!(
          ColumnResizeUpdateDetails(
            columnName: mapped.source.columnName,
            width: width,
          ),
        );
      }
    }

    if (event.hasClick() && onCellTap != null) {
      await _emitCellTap();
    }
  }

  Future<void> _emitSelectionChanged() async {
    final selection = await controller.getSelection();

    final next = _selectionIndicesFromRanges(
      selection.ranges,
      fallbackActiveRow: selection.activeRow,
    );
    final added = _rowsFromIndices(next.difference(_selectedRows));
    final removed = _rowsFromIndices(_selectedRows.difference(next));
    _selectedRows = next;

    if (added.isNotEmpty || removed.isNotEmpty) {
      onSelectionChanged?.call(added, removed);
    }
  }

  Future<void> _emitCellTap() async {
    final selection = await controller.getSelection();
    final rowIndex = selection.activeRow - getHeaderRows();
    final colIndex = selection.activeCol;
    if (rowIndex < 0 || rowIndex >= getShadowRows().length) {
      return;
    }
    if (colIndex < 0 || colIndex >= getColumns().count) {
      return;
    }

    onCellTap?.call(
      DataGridCellTapDetails(
        rowColumnIndex: RowColumnIndex(rowIndex, colIndex),
        localPosition: Offset.zero,
      ),
    );
  }

  Set<int> _selectionIndicesFromRanges(
    List<vg.CellRange> ranges, {
    int? fallbackActiveRow,
  }) {
    final out = <int>{};
    for (final range in ranges) {
      out.addAll(_selectionIndicesFromBounds(range.row1, range.row2));
    }
    if (out.isNotEmpty) {
      return out;
    }
    if (fallbackActiveRow != null) {
      return _selectionIndicesFromBounds(fallbackActiveRow, fallbackActiveRow);
    }
    return <int>{};
  }

  Set<int> _selectionIndicesFromBounds(int row, int rowEnd) {
    final headerRows = getHeaderRows();
    final rowCount = getShadowRows().length;
    if (rowCount <= 0) {
      return <int>{};
    }

    final from = math.min(row, rowEnd) - headerRows;
    final to = math.max(row, rowEnd) - headerRows;

    if (to < 0 || from >= rowCount) {
      return <int>{};
    }

    final clampedFrom = from.clamp(0, rowCount - 1);
    final clampedTo = to.clamp(0, rowCount - 1);

    final out = <int>{};
    for (var i = clampedFrom; i <= clampedTo; i += 1) {
      out.add(i);
    }
    return out;
  }

  List<DataGridRow> _rowsFromIndices(Set<int> indices) {
    final sorted = indices.toList()..sort();
    final rows = getShadowRows();
    final out = <DataGridRow>[];
    for (final i in sorted) {
      if (i >= 0 && i < rows.length) {
        out.add(rows[i]);
      }
    }
    return out;
  }
}
