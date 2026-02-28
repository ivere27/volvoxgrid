import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 14,
  name: 'sorting_disabled',
  script: '''SfDataGridVolvox(
  allowSorting: false,
  source: ... // has sortedColumns
  ...
)''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'name', label: Text('Name'), allowSorting: true),
    vv.GridColumn(columnName: 'amount', label: Text('Amount'), allowSorting: true),
  ],
  vvRows: [
    vr([vc('name', 'A'), vc('amount', 100)]),
    vr([vc('name', 'B'), vc('amount', 80)]),
  ],
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
  ],
  sfSourceFactory: () => StaticSfSource(
    [
      sr([sc('name', 'A'), sc('amount', 100)]),
      sr([sc('name', 'B'), sc('amount', 80)]),
    ],
    [
      sf.SortColumnDetails(
          name: 'amount',
          sortDirection: sf.DataGridSortDirection.descending),
    ],
  ),
  allowSorting: false,
);
