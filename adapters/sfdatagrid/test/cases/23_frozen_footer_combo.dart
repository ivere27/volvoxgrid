import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 23,
  name: 'frozen_footer_combo',
  script: '''SfDataGridVolvox(
  frozenColumnsCount: 1,
  frozenRowsCount: 1,
  footerFrozenColumnsCount: 1,
  footerFrozenRowsCount: 1,
  ...
)''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'id', label: Text('ID'), width: 70),
    vv.GridColumn(columnName: 'name', label: Text('Name'), minimumWidth: 140),
    vv.GridColumn(columnName: 'region', label: Text('Region')),
    vv.GridColumn(columnName: 'total', label: Text('Total'), width: 100),
  ],
  vvRows: List.generate(
    16,
    (index) => vr([
      vc('id', index + 1),
      vc('name', 'Item ${index + 1}'),
      vc('region', index.isEven ? 'APAC' : 'EMEA'),
      vc('total', (index + 1) * 12),
    ]),
  ),
  sfColumnsFactory: () => [
    sf.GridColumn(
        columnName: 'id', label: Text('ID', style: textStyle), width: 70),
    sf.GridColumn(
        columnName: 'name',
        label: Text('Name', style: textStyle),
        minimumWidth: 140),
    sf.GridColumn(
        columnName: 'region', label: Text('Region', style: textStyle)),
    sf.GridColumn(
        columnName: 'total',
        label: Text('Total', style: textStyle),
        width: 100),
  ],
  sfSourceFactory: () => StaticSfSource(List.generate(
    16,
    (index) => sr([
      sc('id', index + 1),
      sc('name', 'Item ${index + 1}'),
      sc('region', index.isEven ? 'APAC' : 'EMEA'),
      sc('total', (index + 1) * 12),
    ]),
  )),
  frozenColumnsCount: 1,
  frozenRowsCount: 1,
  footerFrozenColumnsCount: 1,
  footerFrozenRowsCount: 1,
);
