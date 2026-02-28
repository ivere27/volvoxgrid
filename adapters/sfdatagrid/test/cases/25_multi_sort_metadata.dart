import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 25,
  name: 'multi_sort_metadata',
  script: '''final source = MySource()..sortedColumns = [
  SortColumnDetails(name: 'team', sortDirection: SortDirection.ascending),
  SortColumnDetails(name: 'score', sortDirection: SortDirection.descending),
];''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'name', label: Text('Name'), allowSorting: true),
    vv.GridColumn(columnName: 'team', label: Text('Team'), allowSorting: true),
    vv.GridColumn(
        columnName: 'score', label: Text('Score'), allowSorting: true),
  ],
  vvRows: [
    vr([vc('name', 'Liam'), vc('team', 'Alpha'), vc('score', 88)]),
    vr([vc('name', 'Mia'), vc('team', 'Alpha'), vc('score', 91)]),
    vr([vc('name', 'Noah'), vc('team', 'Beta'), vc('score', 84)]),
    vr([vc('name', 'Olive'), vc('team', 'Beta'), vc('score', 95)]),
  ],
  vvSortedColumns: [
    vv.SortColumnDetails(
        name: 'team', sortDirection: vv.SortDirection.ascending),
    vv.SortColumnDetails(
        name: 'score', sortDirection: vv.SortDirection.descending),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(
        columnName: 'name',
        label: Text('Name', style: textStyle),
        allowSorting: true),
    sf.GridColumn(
        columnName: 'team',
        label: Text('Team', style: textStyle),
        allowSorting: true),
    sf.GridColumn(
        columnName: 'score',
        label: Text('Score', style: textStyle),
        allowSorting: true),
  ],
  sfSourceFactory: () => StaticSfSource(
    [
      sr([sc('name', 'Liam'), sc('team', 'Alpha'), sc('score', 88)]),
      sr([sc('name', 'Mia'), sc('team', 'Alpha'), sc('score', 91)]),
      sr([sc('name', 'Noah'), sc('team', 'Beta'), sc('score', 84)]),
      sr([sc('name', 'Olive'), sc('team', 'Beta'), sc('score', 95)]),
    ],
    [
      sf.SortColumnDetails(
          name: 'team', sortDirection: sf.DataGridSortDirection.ascending),
      sf.SortColumnDetails(
          name: 'score', sortDirection: sf.DataGridSortDirection.descending),
    ],
  ),
  allowSorting: true,
);
