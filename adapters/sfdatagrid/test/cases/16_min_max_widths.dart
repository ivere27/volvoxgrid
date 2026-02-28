import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 16,
  name: 'min_max_widths',
  script: '''// Col 1: width 20, min 60 -> should be 60?
// Col 2: width 200, max 60 -> should be 60?
''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'min', label: Text('Min'), width: 20, minimumWidth: 60),
    vv.GridColumn(columnName: 'max', label: Text('Max'), width: 200, maximumWidth: 60),
  ],
  vvRows: [
    vr([vc('min', 'A'), vc('max', 'B')]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'min', label: Text('Min', style: textStyle), width: 20, minimumWidth: 60),
    sf.GridColumn(columnName: 'max', label: Text('Max', style: textStyle), width: 200, maximumWidth: 60),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('min', 'A'), sc('max', 'B')]),
  ]),
);
