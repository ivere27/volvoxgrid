import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 20,
  name: 'numeric_formatting',
  script: '// Numeric toString()',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'num', label: Text('Num')),
  ],
  vvRows: [
    vr([vc('num', 123)]),
    vr([vc('num', 123.456)]),
    vr([vc('num', -99)]),
    vr([vc('num', 0)]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'num', label: Text('Num', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('num', 123)]),
    sr([sc('num', 123.456)]),
    sr([sc('num', -99)]),
    sr([sc('num', 0)]),
  ]),
);
