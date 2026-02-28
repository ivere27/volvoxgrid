import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 26,
  name: 'empty_sortable_grid',
  script: '''final source = MySource()..sortedColumns = [
  SortColumnDetails(name: 'amount', sortDirection: SortDirection.descending),
]; // rows are empty''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'name', label: Text('Name'), allowSorting: true),
    vv.GridColumn(
        columnName: 'amount', label: Text('Amount'), allowSorting: true),
    vv.GridColumn(
        columnName: 'state', label: Text('State'), allowSorting: true),
  ],
  vvRows: const [],
  vvSortedColumns: [
    vv.SortColumnDetails(
        name: 'amount', sortDirection: vv.SortDirection.descending),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(
        columnName: 'name',
        label: Text('Name', style: textStyle),
        allowSorting: true),
    sf.GridColumn(
        columnName: 'amount',
        label: Text('Amount', style: textStyle),
        allowSorting: true),
    sf.GridColumn(
        columnName: 'state',
        label: Text('State', style: textStyle),
        allowSorting: true),
  ],
  sfSourceFactory: () => StaticSfSource(
    const [],
    [
      sf.SortColumnDetails(
          name: 'amount', sortDirection: sf.DataGridSortDirection.descending),
    ],
  ),
  allowSorting: true,
);
