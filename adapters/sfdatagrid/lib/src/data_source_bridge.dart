import 'dart:typed_data';

import 'grid_column_mapper.dart';
import 'types.dart';

class DataSourceMatrix {
  final int rows;
  final int cols;
  final List<Object?> values;
  final List<DataGridRow> shadowRows;

  const DataSourceMatrix({
    required this.rows,
    required this.cols,
    required this.values,
    required this.shadowRows,
  });
}

Object? _normalizeValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String ||
      value is num ||
      value is bool ||
      value is DateTime ||
      value is Uint8List) {
    return value;
  }
  return value.toString();
}

DataSourceMatrix buildDataSourceMatrix({
  required DataGridSource source,
  required GridColumnMapping columns,
}) {
  final rows = source.rows;
  final rowCount = rows.length;
  final colCount = columns.count;
  final values = List<Object?>.filled(rowCount * colCount, null);

  for (var rowIndex = 0; rowIndex < rowCount; rowIndex += 1) {
    final row = rows[rowIndex];
    for (final mapped in columns.columns) {
      final rawValue = row.getValue(mapped.source.columnName);
      values[rowIndex * colCount + mapped.index] = _normalizeValue(rawValue);
    }
  }

  return DataSourceMatrix(
    rows: rowCount,
    cols: colCount,
    values: values,
    shadowRows: List<DataGridRow>.from(rows),
  );
}
