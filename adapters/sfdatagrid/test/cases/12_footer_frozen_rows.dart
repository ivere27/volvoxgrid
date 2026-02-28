import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 12,
  name: 'footer_frozen_rows',
  script: '''SfDataGridVolvox(
  footerFrozenRowsCount: 2,
  ...
)''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'id', label: Text('ID'), width: 60),
    vv.GridColumn(columnName: 'name', label: Text('Name')),
  ],
  vvRows: List.generate(
    15,
    (index) => vr([vc('id', index), vc('name', 'Item $index')]),
  ),
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'id', label: Text('ID', style: textStyle), width: 60),
    sf.GridColumn(columnName: 'name', label: Text('Name', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource(List.generate(
    15,
    (index) => sr([sc('id', index), sc('name', 'Item $index')]),
  )),
  footerFrozenRowsCount: 2,
);
