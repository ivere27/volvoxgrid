import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 3,
  name: 'null_and_missing',
  script: '''final rows = [
  DataGridRow(cells: [DataGridCell(columnName: 'name', value: 'A')]),
  DataGridRow(cells: [DataGridCell(columnName: 'name', value: 'B'), DataGridCell(columnName: 'status', value: null)]),
];''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'name', label: Text('Name')),
    vv.GridColumn(columnName: 'status', label: Text('Status')),
    vv.GridColumn(columnName: 'note', label: Text('Note')),
  ],
  vvRows: [
    vr([vc('name', 'A')]),
    vr([vc('name', 'B'), vc('status', null)]),
    vr([vc('name', 'C'), vc('status', 'ok'), vc('note', '')]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(
        columnName: 'name', label: Text('Name', style: textStyle)),
    sf.GridColumn(
        columnName: 'status', label: Text('Status', style: textStyle)),
    sf.GridColumn(
        columnName: 'note', label: Text('Note', style: textStyle)),
  ],
  // SfDataGrid requires each row to have cells matching column count,
  // so pad missing cells with null values for the reference grid.
  sfSourceFactory: () => StaticSfSource([
    sr([sc('name', 'A'), sc('status', null), sc('note', null)]),
    sr([sc('name', 'B'), sc('status', null), sc('note', null)]),
    sr([sc('name', 'C'), sc('status', 'ok'), sc('note', '')]),
  ]),
);
