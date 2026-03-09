import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 21,
  name: 'selection_multiple',
  script: '''SfDataGridVolvox(
  selectionMode: SelectionMode.multiple,
  controller: controller,
  ...
)
// Hooks:
// sfController.selectedRows = [rows[0], rows[1], rows[2]];
// vvController.selectRange(1, 0, 3, 0); // header row is 0
''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'name', label: Text('Name')),
    vv.GridColumn(columnName: 'team', label: Text('Team')),
    vv.GridColumn(columnName: 'score', label: Text('Score')),
  ],
  vvRows: [
    vr([vc('name', 'Alice'), vc('team', 'Core'), vc('score', 84)]),
    vr([vc('name', 'Bob'), vc('team', 'Infra'), vc('score', 71)]),
    vr([vc('name', 'Cara'), vc('team', 'Design'), vc('score', 92)]),
    vr([vc('name', 'Duke'), vc('team', 'Core'), vc('score', 67)]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'name', label: Text('Name', style: textStyle)),
    sf.GridColumn(columnName: 'team', label: Text('Team', style: textStyle)),
    sf.GridColumn(columnName: 'score', label: Text('Score', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('name', 'Alice'), sc('team', 'Core'), sc('score', 84)]),
    sr([sc('name', 'Bob'), sc('team', 'Infra'), sc('score', 71)]),
    sr([sc('name', 'Cara'), sc('team', 'Design'), sc('score', 92)]),
    sr([sc('name', 'Duke'), sc('team', 'Core'), sc('score', 67)]),
  ]),
  selectionMode: sf.SelectionMode.multiple,
  onSfCreated: (c, s) async {
    if (s.rows.length >= 3) {
      c.selectedRows = [s.rows[0], s.rows[1], s.rows[2]];
    }
  },
  onVolvoxCreated: (c) async {
    await c.selectRange(1, 0, 3, 0);
  },
);
