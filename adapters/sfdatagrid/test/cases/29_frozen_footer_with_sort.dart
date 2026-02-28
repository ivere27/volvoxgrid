import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 29,
  name: 'frozen_footer_with_sort',
  script: '''SfDataGridVolvox(
  frozenColumnsCount: 1,
  footerFrozenColumnsCount: 1,
  allowSorting: true,
  source.sortedColumns = [SortColumnDetails(name: 'value', descending)],
)''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'id', label: Text('ID'), width: 70),
    vv.GridColumn(
        columnName: 'label', label: Text('Label'), allowSorting: true),
    vv.GridColumn(
        columnName: 'value', label: Text('Value'), allowSorting: true),
    vv.GridColumn(columnName: 'status', label: Text('Status'), width: 90),
  ],
  vvRows: List.generate(
    8,
    (i) => vr([
      vc('id', i + 1),
      vc('label', 'Item ${i + 1}'),
      vc('value', 100 - (i * 7)),
      vc('status', i.isEven ? 'OK' : 'Hold'),
    ]),
  ),
  vvSortedColumns: [
    vv.SortColumnDetails(
        name: 'value', sortDirection: vv.SortDirection.descending),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(
        columnName: 'id', label: Text('ID', style: textStyle), width: 70),
    sf.GridColumn(
        columnName: 'label',
        label: Text('Label', style: textStyle),
        allowSorting: true),
    sf.GridColumn(
        columnName: 'value',
        label: Text('Value', style: textStyle),
        allowSorting: true),
    sf.GridColumn(
        columnName: 'status',
        label: Text('Status', style: textStyle),
        width: 90),
  ],
  sfSourceFactory: () => StaticSfSource(
    List.generate(
      8,
      (i) => sr([
        sc('id', i + 1),
        sc('label', 'Item ${i + 1}'),
        sc('value', 100 - (i * 7)),
        sc('status', i.isEven ? 'OK' : 'Hold'),
      ]),
    ),
    [
      sf.SortColumnDetails(
          name: 'value', sortDirection: sf.DataGridSortDirection.descending),
    ],
  ),
  allowSorting: true,
  frozenColumnsCount: 1,
  footerFrozenColumnsCount: 1,
);
