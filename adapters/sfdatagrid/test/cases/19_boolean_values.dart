import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 19,
  name: 'boolean_values',
  script: '// Boolean true/false',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'bool', label: Text('Bool')),
  ],
  vvRows: [
    vr([vc('bool', true)]),
    vr([vc('bool', false)]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'bool', label: Text('Bool', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('bool', true)]),
    sr([sc('bool', false)]),
  ]),
);
