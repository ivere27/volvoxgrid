import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 28,
  name: 'custom_heights_with_sort',
  script: '''SfDataGridVolvox(
  rowHeight: 40,
  headerRowHeight: 44,
  allowSorting: true,
  source.sortedColumns = [SortColumnDetails(name: 'amount', descending)],
)''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'name', label: Text('Name'), allowSorting: true),
    vv.GridColumn(
        columnName: 'amount', label: Text('Amount'), allowSorting: true),
    vv.GridColumn(
        columnName: 'region', label: Text('Region'), allowSorting: true),
  ],
  vvRows: [
    vr([vc('name', 'A'), vc('amount', 100), vc('region', 'APAC')]),
    vr([vc('name', 'B'), vc('amount', 120), vc('region', 'EMEA')]),
    vr([vc('name', 'C'), vc('amount', 90), vc('region', 'NA')]),
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
    sf.GridColumn(
        columnName: 'region',
        label: Text('Region', style: textStyle),
        allowSorting: true),
  ],
  sfSourceFactory: () => StaticSfSource(
    [
      sr([sc('name', 'A'), sc('amount', 100), sc('region', 'APAC')]),
      sr([sc('name', 'B'), sc('amount', 120), sc('region', 'EMEA')]),
      sr([sc('name', 'C'), sc('amount', 90), sc('region', 'NA')]),
    ],
    [
      sf.SortColumnDetails(
          name: 'amount', sortDirection: sf.DataGridSortDirection.descending),
    ],
  ),
  allowSorting: true,
  gridLinesVisibility: sf.GridLinesVisibility.horizontal,
  rowHeight: 40,
  headerRowHeight: 44,
);
