import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 4,
  name: 'mixed_types',
  script: '''final rows = [
  DataGridRow(cells: [
    DataGridCell(columnName: 'id', value: 1),
    DataGridCell(columnName: 'active', value: true),
    DataGridCell(columnName: 'meta', value: {'r': 'NA'}),
  ]),
];''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'id', label: Text('ID')),
    vv.GridColumn(columnName: 'active', label: Text('Active')),
    vv.GridColumn(columnName: 'meta', label: Text('Meta')),
    vv.GridColumn(columnName: 'created', label: Text('Created')),
  ],
  vvRows: [
    vr([
      vc('id', 1),
      vc('active', true),
      vc('meta', <String, String>{'r': 'NA'}),
      vc('created', DateTime.utc(2026, 1, 20)),
    ]),
    vr([
      vc('id', 2),
      vc('active', false),
      vc('meta', <String>['x', 'y']),
      vc('created', '2026-02-21'),
    ]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'id', label: Text('ID', style: textStyle)),
    sf.GridColumn(
        columnName: 'active', label: Text('Active', style: textStyle)),
    sf.GridColumn(
        columnName: 'meta', label: Text('Meta', style: textStyle)),
    sf.GridColumn(
        columnName: 'created', label: Text('Created', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([
      sc('id', 1),
      sc('active', true),
      sc('meta', <String, String>{'r': 'NA'}),
      sc('created', DateTime.utc(2026, 1, 20)),
    ]),
    sr([
      sc('id', 2),
      sc('active', false),
      sc('meta', <String>['x', 'y']),
      sc('created', '2026-02-21'),
    ]),
  ]),
);
