import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 1,
  name: 'basic_rows',
  script: '''final columns = [
  GridColumn(columnName: 'name', label: Text('Name')),
  GridColumn(columnName: 'age', label: Text('Age')),
  GridColumn(columnName: 'city', label: Text('City')),
];''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'name', label: Text('Name')),
    vv.GridColumn(columnName: 'age', label: Text('Age')),
    vv.GridColumn(columnName: 'city', label: Text('City')),
  ],
  vvRows: [
    vr([vc('name', 'Alice'), vc('age', 31), vc('city', 'Seoul')]),
    vr([vc('name', 'Bob'), vc('age', 44), vc('city', 'Busan')]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(
        columnName: 'name', label: Text('Name', style: textStyle)),
    sf.GridColumn(columnName: 'age', label: Text('Age', style: textStyle)),
    sf.GridColumn(
        columnName: 'city', label: Text('City', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('name', 'Alice'), sc('age', 31), sc('city', 'Seoul')]),
    sr([sc('name', 'Bob'), sc('age', 44), sc('city', 'Busan')]),
  ]),
);
