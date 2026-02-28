import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 2,
  name: 'hidden_and_widths',
  script: '''final columns = [
  GridColumn(columnName: 'id', label: Text('ID'), width: 80),
  GridColumn(columnName: 'visible', label: Text('Visible'), minimumWidth: 60),
  GridColumn(columnName: 'secret', label: Text('Secret'), visible: false),
];''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'id', label: Text('ID'), width: 80),
    vv.GridColumn(
        columnName: 'visible', label: Text('Visible'), minimumWidth: 60),
    vv.GridColumn(
        columnName: 'secret', label: Text('Secret'), visible: false),
  ],
  vvRows: [
    vr([vc('id', 'R-1'), vc('visible', 'on'), vc('secret', 'x1')]),
    vr([vc('id', 'R-2'), vc('visible', 'off'), vc('secret', 'x2')]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(
        columnName: 'id', label: Text('ID', style: textStyle), width: 80),
    sf.GridColumn(
        columnName: 'visible',
        label: Text('Visible', style: textStyle),
        minimumWidth: 60),
    sf.GridColumn(
        columnName: 'secret',
        label: Text('Secret', style: textStyle),
        visible: false),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('id', 'R-1'), sc('visible', 'on'), sc('secret', 'x1')]),
    sr([sc('id', 'R-2'), sc('visible', 'off'), sc('secret', 'x2')]),
  ]),
);
