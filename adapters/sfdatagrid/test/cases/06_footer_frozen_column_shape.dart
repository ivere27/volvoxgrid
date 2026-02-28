import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 6,
  name: 'footer_frozen_column_shape',
  script: '''SfDataGridVolvox(
  footerFrozenColumnsCount: 1,
  columns: [
    GridColumn(columnName: 'product', label: Text('Product')),
    GridColumn(columnName: 'qty', label: Text('Qty')),
    GridColumn(columnName: 'total', label: Text('Total')),
  ],
)''',
  vvColumnsFactory: () => [
    vv.GridColumn(columnName: 'product', label: Text('Product')),
    vv.GridColumn(columnName: 'qty', label: Text('Qty')),
    vv.GridColumn(columnName: 'total', label: Text('Total')),
  ],
  vvRows: [
    vr([vc('product', 'Pen'), vc('qty', 4), vc('total', 12)]),
    vr([vc('product', 'Notebook'), vc('qty', 2), vc('total', 14)]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(
        columnName: 'product', label: Text('Product', style: textStyle)),
    sf.GridColumn(columnName: 'qty', label: Text('Qty', style: textStyle)),
    sf.GridColumn(
        columnName: 'total', label: Text('Total', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([sc('product', 'Pen'), sc('qty', 4), sc('total', 12)]),
    sr([sc('product', 'Notebook'), sc('qty', 2), sc('total', 14)]),
  ]),
  footerFrozenColumnsCount: 1,
);
