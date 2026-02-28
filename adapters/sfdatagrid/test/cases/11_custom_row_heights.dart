import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 11,
  name: 'custom_row_heights',
  script: '''SfDataGridVolvox(
  rowHeight: 50,
  headerRowHeight: 60,
  ...
)''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'name', label: Text('Name')),
    vv.GridColumn(columnName: 'city', label: Text('City')),
  ],
  vvRows: [
    vr([vc('name', 'Alice'), vc('city', 'Seoul')]),
    vr([vc('name', 'Bob'), vc('city', 'Busan')]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'name', label: Text('Name', style: textStyle)),
    sf.GridColumn(columnName: 'city', label: Text('City', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('name', 'Alice'), sc('city', 'Seoul')]),
    sr([sc('name', 'Bob'), sc('city', 'Busan')]),
  ]),
  rowHeight: 50,
  headerRowHeight: 60,
);
