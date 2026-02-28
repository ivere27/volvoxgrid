import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 17,
  name: 'empty_data',
  script: '// Empty rows list',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'name', label: Text('Name')),
    vv.GridColumn(columnName: 'age', label: Text('Age')),
  ],
  vvRows: [],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'name', label: Text('Name', style: textStyle)),
    sf.GridColumn(columnName: 'age', label: Text('Age', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([]),
);
