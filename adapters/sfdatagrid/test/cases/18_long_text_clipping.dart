import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 18,
  name: 'long_text_clipping',
  script: '// Long text in narrow column',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'text', label: Text('Text'), width: 50),
  ],
  vvRows: [
    vr([vc('text', 'This is a very long text that should clip or wrap')]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'text', label: Text('Text', style: textStyle), width: 50),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('text', 'This is a very long text that should clip or wrap')]),
  ]),
);
