import 'package:flutter/widgets.dart';

import '../lib/src/types.dart';

class SfCompareCase {
  final int id;
  final String name;
  final String script;
  final List<GridColumn> columns;
  final List<DataGridRow> rows;
  final List<SortColumnDetails> sortedColumns;

  const SfCompareCase({
    required this.id,
    required this.name,
    required this.script,
    required this.columns,
    required this.rows,
    this.sortedColumns = const <SortColumnDetails>[],
  });
}

class StaticDataGridSource extends DataGridSource {
  final List<DataGridRow> _rows;
  final List<SortColumnDetails> _sortedColumns;

  StaticDataGridSource({
    required List<DataGridRow> rows,
    List<SortColumnDetails> sortedColumns = const <SortColumnDetails>[],
  })  : _rows = rows,
        _sortedColumns = sortedColumns;

  @override
  List<DataGridRow> get rows => _rows;

  @override
  List<SortColumnDetails> get sortedColumns => _sortedColumns;
}

DataGridCell<dynamic> c(String name, dynamic value) {
  return DataGridCell<dynamic>(columnName: name, value: value);
}

DataGridRow r(List<DataGridCell<dynamic>> cells) {
  return DataGridRow(cells: cells);
}

final List<SfCompareCase> sfCompareCases = <SfCompareCase>[
  SfCompareCase(
    id: 1,
    name: 'basic_rows',
    script: '''final columns = [
  GridColumn(columnName: 'name', label: Text('Name')),
  GridColumn(columnName: 'age', label: Text('Age')),
  GridColumn(columnName: 'city', label: Text('City')),
];
final rows = [
  DataGridRow(cells: [
    DataGridCell(columnName: 'name', value: 'Alice'),
    DataGridCell(columnName: 'age', value: 31),
    DataGridCell(columnName: 'city', value: 'Seoul'),
  ]),
];''',
    columns: <GridColumn>[
      GridColumn(columnName: 'name', label: Text('Name')),
      GridColumn(columnName: 'age', label: Text('Age')),
      GridColumn(columnName: 'city', label: Text('City')),
    ],
    rows: <DataGridRow>[
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'name', value: 'Alice'),
        DataGridCell(columnName: 'age', value: 31),
        DataGridCell(columnName: 'city', value: 'Seoul'),
      ]),
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'name', value: 'Bob'),
        DataGridCell(columnName: 'age', value: 44),
        DataGridCell(columnName: 'city', value: 'Busan'),
      ]),
    ],
  ),
  SfCompareCase(
    id: 2,
    name: 'hidden_and_widths',
    script: '''final columns = [
  GridColumn(columnName: 'id', label: Text('ID'), width: 80),
  GridColumn(columnName: 'visible', label: Text('Visible'), minimumWidth: 60),
  GridColumn(columnName: 'secret', label: Text('Secret'), visible: false),
];''',
    columns: <GridColumn>[
      GridColumn(columnName: 'id', label: Text('ID'), width: 80),
      GridColumn(
          columnName: 'visible', label: Text('Visible'), minimumWidth: 60),
      GridColumn(columnName: 'secret', label: Text('Secret'), visible: false),
    ],
    rows: <DataGridRow>[
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'id', value: 'R-1'),
        DataGridCell(columnName: 'visible', value: 'on'),
        DataGridCell(columnName: 'secret', value: 'x1'),
      ]),
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'id', value: 'R-2'),
        DataGridCell(columnName: 'visible', value: 'off'),
        DataGridCell(columnName: 'secret', value: 'x2'),
      ]),
    ],
  ),
  SfCompareCase(
    id: 3,
    name: 'null_and_missing',
    script: '''final rows = [
  DataGridRow(cells: [DataGridCell(columnName: 'name', value: 'A')]),
  DataGridRow(cells: [DataGridCell(columnName: 'name', value: 'B'), DataGridCell(columnName: 'status', value: null)]),
];''',
    columns: <GridColumn>[
      GridColumn(columnName: 'name', label: Text('Name')),
      GridColumn(columnName: 'status', label: Text('Status')),
      GridColumn(columnName: 'note', label: Text('Note')),
    ],
    rows: <DataGridRow>[
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'name', value: 'A'),
      ]),
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'name', value: 'B'),
        DataGridCell(columnName: 'status', value: null),
      ]),
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'name', value: 'C'),
        DataGridCell(columnName: 'status', value: 'ok'),
        DataGridCell(columnName: 'note', value: ''),
      ]),
    ],
  ),
  SfCompareCase(
    id: 4,
    name: 'mixed_types',
    script: '''final rows = [
  DataGridRow(cells: [
    DataGridCell(columnName: 'id', value: 1),
    DataGridCell(columnName: 'active', value: true),
    DataGridCell(columnName: 'meta', value: {'r': 'NA'}),
  ]),
];''',
    columns: <GridColumn>[
      GridColumn(columnName: 'id', label: Text('ID')),
      GridColumn(columnName: 'active', label: Text('Active')),
      GridColumn(columnName: 'meta', label: Text('Meta')),
      GridColumn(columnName: 'created', label: Text('Created')),
    ],
    rows: <DataGridRow>[
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'id', value: 1),
        DataGridCell(columnName: 'active', value: true),
        DataGridCell(columnName: 'meta', value: <String, String>{'r': 'NA'}),
        DataGridCell(columnName: 'created', value: DateTime.utc(2026, 1, 20)),
      ]),
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'id', value: 2),
        DataGridCell(columnName: 'active', value: false),
        DataGridCell(columnName: 'meta', value: <String>['x', 'y']),
        DataGridCell(columnName: 'created', value: '2026-02-21'),
      ]),
    ],
  ),
  SfCompareCase(
    id: 5,
    name: 'sorted_columns_metadata',
    script: '''final source = MySource()..sortedColumns = [
  SortColumnDetails(name: 'amount', sortDirection: SortDirection.descending),
];''',
    columns: <GridColumn>[
      GridColumn(columnName: 'name', label: Text('Name'), allowSorting: true),
      GridColumn(
          columnName: 'amount', label: Text('Amount'), allowSorting: true),
    ],
    rows: <DataGridRow>[
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'name', value: 'A'),
        DataGridCell(columnName: 'amount', value: 100),
      ]),
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'name', value: 'B'),
        DataGridCell(columnName: 'amount', value: 80),
      ]),
    ],
    sortedColumns: <SortColumnDetails>[
      SortColumnDetails(
          name: 'amount', sortDirection: SortDirection.descending),
    ],
  ),
  SfCompareCase(
    id: 6,
    name: 'footer_frozen_column_shape',
    script: '''SfDataGridVolvox(
  footerFrozenColumnsCount: 1,
  columns: [
    GridColumn(columnName: 'product', label: Text('Product')),
    GridColumn(columnName: 'qty', label: Text('Qty')),
    GridColumn(columnName: 'total', label: Text('Total')),
  ],
)''',
    columns: <GridColumn>[
      GridColumn(columnName: 'product', label: Text('Product')),
      GridColumn(columnName: 'qty', label: Text('Qty')),
      GridColumn(columnName: 'total', label: Text('Total')),
    ],
    rows: <DataGridRow>[
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'product', value: 'Pen'),
        DataGridCell(columnName: 'qty', value: 4),
        DataGridCell(columnName: 'total', value: 12),
      ]),
      DataGridRow(cells: <DataGridCell<dynamic>>[
        DataGridCell(columnName: 'product', value: 'Notebook'),
        DataGridCell(columnName: 'qty', value: 2),
        DataGridCell(columnName: 'total', value: 14),
      ]),
    ],
  ),
];
