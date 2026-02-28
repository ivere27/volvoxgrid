import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 15,
  name: 'programmatic_scroll',
  script: '''// Scroll to row 10
// Sf: scrollController.jumpTo(36 + 10 * 32);
// Vv hook is intentionally omitted in compare mode due
// Synurang request timeouts when calling setTopRow()/Select(show=true).
''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'id', label: Text('ID'), width: 60),
    vv.GridColumn(columnName: 'value', label: Text('Value')),
  ],
  vvRows: List.generate(
    50,
    (index) => vr([vc('id', index), vc('value', 'Row $index')]),
  ),
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'id', label: Text('ID', style: textStyle), width: 60),
    sf.GridColumn(columnName: 'value', label: Text('Value', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource(List.generate(
    50,
    (index) => sr([sc('id', index), sc('value', 'Row $index')]),
  )),
  onSfScroll: (v, h) async {
    // Header 36, Row 32. Scroll to row 10 (index 10).
    // Offset = 36 + 10 * 32 = 356.
    if (v.hasClients) {
      v.jumpTo(356);
    }
  },
);
