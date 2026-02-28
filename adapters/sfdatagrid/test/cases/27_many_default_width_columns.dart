import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 27,
  name: 'many_default_width_columns',
  script: '''SfDataGridVolvox(
  // no per-column widths -> use adapter defaultColumnWidth
  columns: [id, name, team, role, city, score, note],
)''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'id', label: Text('ID')),
    vv.GridColumn(columnName: 'name', label: Text('Name')),
    vv.GridColumn(columnName: 'team', label: Text('Team')),
    vv.GridColumn(columnName: 'role', label: Text('Role')),
    vv.GridColumn(columnName: 'city', label: Text('City')),
    vv.GridColumn(columnName: 'score', label: Text('Score')),
    vv.GridColumn(columnName: 'note', label: Text('Note')),
  ],
  vvRows: [
    vr([
      vc('id', 1),
      vc('name', 'Mia'),
      vc('team', 'Alpha'),
      vc('role', 'Lead'),
      vc('city', 'Seoul'),
      vc('score', 91),
      vc('note', 'Core'),
    ]),
    vr([
      vc('id', 2),
      vc('name', 'Liam'),
      vc('team', 'Alpha'),
      vc('role', 'Analyst'),
      vc('city', 'Busan'),
      vc('score', 88),
      vc('note', 'Ops'),
    ]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'id', label: Text('ID', style: textStyle)),
    sf.GridColumn(columnName: 'name', label: Text('Name', style: textStyle)),
    sf.GridColumn(columnName: 'team', label: Text('Team', style: textStyle)),
    sf.GridColumn(columnName: 'role', label: Text('Role', style: textStyle)),
    sf.GridColumn(columnName: 'city', label: Text('City', style: textStyle)),
    sf.GridColumn(columnName: 'score', label: Text('Score', style: textStyle)),
    sf.GridColumn(columnName: 'note', label: Text('Note', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([
      sc('id', 1),
      sc('name', 'Mia'),
      sc('team', 'Alpha'),
      sc('role', 'Lead'),
      sc('city', 'Seoul'),
      sc('score', 91),
      sc('note', 'Core'),
    ]),
    sr([
      sc('id', 2),
      sc('name', 'Liam'),
      sc('team', 'Alpha'),
      sc('role', 'Analyst'),
      sc('city', 'Busan'),
      sc('score', 88),
      sc('note', 'Ops'),
    ]),
  ]),
);
