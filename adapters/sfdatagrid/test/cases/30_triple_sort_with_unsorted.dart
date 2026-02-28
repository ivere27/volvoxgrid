import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 30,
  name: 'triple_sort_with_unsorted',
  script: '''final source = MySource()..sortedColumns = [
  SortColumnDetails(name: 'dept', sortDirection: SortDirection.ascending),
  SortColumnDetails(name: 'salary', sortDirection: SortDirection.descending),
  SortColumnDetails(name: 'name', sortDirection: SortDirection.ascending),
];''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'dept', label: Text('Dept'), allowSorting: true),
    vv.GridColumn(columnName: 'name', label: Text('Name'), allowSorting: true),
    vv.GridColumn(
        columnName: 'salary', label: Text('Salary'), allowSorting: true),
    vv.GridColumn(
        columnName: 'level', label: Text('Level'), allowSorting: true),
  ],
  vvRows: [
    vr([
      vc('dept', 'Core'),
      vc('name', 'Mia'),
      vc('salary', 95000),
      vc('level', 'L3'),
    ]),
    vr([
      vc('dept', 'Core'),
      vc('name', 'Liam'),
      vc('salary', 92000),
      vc('level', 'L2'),
    ]),
    vr([
      vc('dept', 'Ops'),
      vc('name', 'Noah'),
      vc('salary', 88000),
      vc('level', 'L2'),
    ]),
    vr([
      vc('dept', 'Ops'),
      vc('name', 'Olive'),
      vc('salary', 99000),
      vc('level', 'L4'),
    ]),
  ],
  vvSortedColumns: [
    vv.SortColumnDetails(
        name: 'dept', sortDirection: vv.SortDirection.ascending),
    vv.SortColumnDetails(
        name: 'salary', sortDirection: vv.SortDirection.descending),
    vv.SortColumnDetails(
        name: 'name', sortDirection: vv.SortDirection.ascending),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(
        columnName: 'dept',
        label: Text('Dept', style: textStyle),
        allowSorting: true),
    sf.GridColumn(
        columnName: 'name',
        label: Text('Name', style: textStyle),
        allowSorting: true),
    sf.GridColumn(
        columnName: 'salary',
        label: Text('Salary', style: textStyle),
        allowSorting: true),
    sf.GridColumn(
        columnName: 'level',
        label: Text('Level', style: textStyle),
        allowSorting: true),
  ],
  sfSourceFactory: () => StaticSfSource(
    [
      sr([
        sc('dept', 'Core'),
        sc('name', 'Mia'),
        sc('salary', 95000),
        sc('level', 'L3'),
      ]),
      sr([
        sc('dept', 'Core'),
        sc('name', 'Liam'),
        sc('salary', 92000),
        sc('level', 'L2'),
      ]),
      sr([
        sc('dept', 'Ops'),
        sc('name', 'Noah'),
        sc('salary', 88000),
        sc('level', 'L2'),
      ]),
      sr([
        sc('dept', 'Ops'),
        sc('name', 'Olive'),
        sc('salary', 99000),
        sc('level', 'L4'),
      ]),
    ],
    [
      sf.SortColumnDetails(
          name: 'dept', sortDirection: sf.DataGridSortDirection.ascending),
      sf.SortColumnDetails(
          name: 'salary', sortDirection: sf.DataGridSortDirection.descending),
      sf.SortColumnDetails(
          name: 'name', sortDirection: sf.DataGridSortDirection.ascending),
    ],
  ),
  allowSorting: true,
);
