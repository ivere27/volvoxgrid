import 'grid_column_mapper.dart';
import 'types.dart';

class DataSourceMatrix {
  final int rows;
  final int cols;
  final List<String> values;
  final List<DataGridRow> shadowRows;

  const DataSourceMatrix({
    required this.rows,
    required this.cols,
    required this.values,
    required this.shadowRows,
  });
}

String _stringify(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  if (value is DateTime) {
    return value.toIso8601String();
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
  final values = List<String>.filled(rowCount * colCount, '');

  for (var rowIndex = 0; rowIndex < rowCount; rowIndex += 1) {
    final row = rows[rowIndex];
    for (final mapped in columns.columns) {
      final rawValue = row.getValue(mapped.source.columnName);
      values[rowIndex * colCount + mapped.index] = _stringify(rawValue);
    }
  }

  return DataSourceMatrix(
    rows: rowCount,
    cols: colCount,
    values: values,
    shadowRows: List<DataGridRow>.from(rows),
  );
}
