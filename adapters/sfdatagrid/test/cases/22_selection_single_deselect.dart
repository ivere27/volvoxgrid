import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 22,
  name: 'selection_single_deselect',
  script: '''SfDataGridVolvox(
  selectionMode: SelectionMode.singleDeselect,
  ...
)
// vv fallback: singleDeselect is mapped to single selection mode.
''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'city', label: Text('City')),
    vv.GridColumn(columnName: 'country', label: Text('Country')),
  ],
  vvRows: [
    vr([vc('city', 'Seoul'), vc('country', 'KR')]),
    vr([vc('city', 'Busan'), vc('country', 'KR')]),
    vr([vc('city', 'Tokyo'), vc('country', 'JP')]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(columnName: 'city', label: Text('City', style: textStyle)),
    sf.GridColumn(
        columnName: 'country', label: Text('Country', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('city', 'Seoul'), sc('country', 'KR')]),
    sr([sc('city', 'Busan'), sc('country', 'KR')]),
    sr([sc('city', 'Tokyo'), sc('country', 'JP')]),
  ]),
  selectionMode: sf.SelectionMode.singleDeselect,
  onSfCreated: (c, s) async {
    if (s.rows.length >= 2) {
      c.selectedRow = s.rows[1];
    }
  },
);
