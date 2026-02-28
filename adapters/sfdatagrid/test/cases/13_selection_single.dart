import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 13,
  name: 'selection_single',
  script: '''SfDataGridVolvox(
  selectionMode: SelectionMode.single,
  controller: controller,
  ...
)
// Hooks:
// sfController.selectedRow = source.rows[0]; // Select 1st data row (Alice)
// vv selection hook is intentionally omitted in compare mode due
// intermittent setRow() timeouts under flutter_test.
''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'name', label: Text('Name')),
    vv.GridColumn(columnName: 'city', label: Text('City')),
  ],
  vvRows: [
    vr([vc('name', 'Alice'), vc('city', 'Seoul')]),
    vr([vc('name', 'Bob'), vc('city', 'Busan')]),
    vr([vc('name', 'Charlie'), vc('city', 'New York')]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'name', label: Text('Name', style: textStyle)),
    sf.GridColumn(columnName: 'city', label: Text('City', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('name', 'Alice'), sc('city', 'Seoul')]),
    sr([sc('name', 'Bob'), sc('city', 'Busan')]),
    sr([sc('name', 'Charlie'), sc('city', 'New York')]),
  ]),
  selectionMode: sf.SelectionMode.single,
  onSfCreated: (c, s) async {
    if (s.rows.isNotEmpty) {
      c.selectedRow = s.rows[0];
    }
  },
);
