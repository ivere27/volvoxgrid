import 'package:flutter/widgets.dart';

class DataGridCell<T> {
  final String columnName;
  final T? value;

  const DataGridCell({required this.columnName, this.value});
}

class DataGridRow {
  final List<DataGridCell<dynamic>> cells;

  const DataGridRow({required this.cells});

  Object? getValue(String columnName) {
    for (final cell in cells) {
      if (cell.columnName == columnName) {
        return cell.value;
      }
    }
    return null;
  }
}

enum SortDirection { ascending, descending }

class SortColumnDetails {
  final String name;
  final SortDirection sortDirection;

  const SortColumnDetails({required this.name, required this.sortDirection});
}

abstract class DataGridSource extends ChangeNotifier {
  List<DataGridRow> get rows;

  List<SortColumnDetails> get sortedColumns => const <SortColumnDetails>[];
}

class GridColumn {
  final String columnName;
  final Widget label;
  final double width;
  final double minimumWidth;
  final double maximumWidth;
  final bool visible;
  final bool allowSorting;

  const GridColumn({
    required this.columnName,
    required this.label,
    this.width = double.nan,
    this.minimumWidth = 40,
    this.maximumWidth = double.infinity,
    this.visible = true,
    this.allowSorting = true,
  });
}

enum SelectionMode { none, single, multiple }

enum GridLinesVisibility { none, horizontal, vertical, both }

class RowColumnIndex {
  final int rowIndex;
  final int columnIndex;

  const RowColumnIndex(this.rowIndex, this.columnIndex);
}

class DataGridCellTapDetails {
  final RowColumnIndex rowColumnIndex;
  final Offset localPosition;

  const DataGridCellTapDetails({
    required this.rowColumnIndex,
    required this.localPosition,
  });
}

class ColumnResizeStartDetails {
  final String columnName;
  final double width;

  const ColumnResizeStartDetails({
    required this.columnName,
    required this.width,
  });
}

class ColumnResizeUpdateDetails {
  final String columnName;
  final double width;

  const ColumnResizeUpdateDetails({
    required this.columnName,
    required this.width,
  });
}

typedef SelectionChangingCallback =
    bool Function(List<DataGridRow> addedRows, List<DataGridRow> removedRows);

typedef SelectionChangedCallback =
    void Function(List<DataGridRow> addedRows, List<DataGridRow> removedRows);

typedef CellTapCallback = void Function(DataGridCellTapDetails details);

typedef ColumnResizeStartCallback =
    bool Function(ColumnResizeStartDetails details);

typedef ColumnResizeUpdateCallback =
    bool Function(ColumnResizeUpdateDetails details);
