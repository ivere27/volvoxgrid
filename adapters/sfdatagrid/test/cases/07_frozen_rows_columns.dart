import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 7,
  name: 'frozen_rows_columns',
  script: '''SfDataGridVolvox(
  frozenColumnsCount: 1,
  frozenRowsCount: 1,
  columns: [...],
  source: ...,
)''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'id', label: Text('ID'), width: 80),
    vv.GridColumn(columnName: 'name', label: Text('Name')),
    vv.GridColumn(columnName: 'city', label: Text('City')),
  ],
  vvRows: [
    vr([vc('id', 1), vc('name', 'Alice'), vc('city', 'Seoul')]),
    vr([vc('id', 2), vc('name', 'Bob'), vc('city', 'Busan')]),
    vr([vc('id', 3), vc('name', 'Charlie'), vc('city', 'New York')]),
    vr([vc('id', 4), vc('name', 'Dave'), vc('city', 'Tokyo')]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'id', label: Text('ID', style: textStyle), width: 80),
    sf.GridColumn(columnName: 'name', label: Text('Name', style: textStyle)),
    sf.GridColumn(columnName: 'city', label: Text('City', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('id', 1), sc('name', 'Alice'), sc('city', 'Seoul')]),
    sr([sc('id', 2), sc('name', 'Bob'), sc('city', 'Busan')]),
    sr([sc('id', 3), sc('name', 'Charlie'), sc('city', 'New York')]),
    sr([sc('id', 4), sc('name', 'Dave'), sc('city', 'Tokyo')]),
  ]),
  frozenColumnsCount: 1,
  frozenRowsCount: 1,
);
