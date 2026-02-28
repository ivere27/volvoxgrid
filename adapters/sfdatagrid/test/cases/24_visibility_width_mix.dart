import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;
import '../common.dart';

final testCase = TestCase(
  id: 24,
  name: 'visibility_width_mix',
  script: '''final columns = [
  GridColumn(columnName: 'internal', label: Text('Internal'), visible: false),
  GridColumn(columnName: 'sku', label: Text('SKU'), width: 90),
  GridColumn(columnName: 'title', label: Text('Title'), minimumWidth: 180),
  GridColumn(columnName: 'qty', label: Text('Qty'), width: 70, maximumWidth: 80),
  GridColumn(columnName: 'note', label: Text('Note')),
];''',
  vvColumnsFactory: () => [
    vv.GridColumn(
        columnName: 'internal', label: Text('Internal'), visible: false),
    vv.GridColumn(columnName: 'sku', label: Text('SKU'), width: 90),
    vv.GridColumn(columnName: 'title', label: Text('Title'), minimumWidth: 180),
    vv.GridColumn(
        columnName: 'qty', label: Text('Qty'), width: 70, maximumWidth: 80),
    vv.GridColumn(columnName: 'note', label: Text('Note')),
  ],
  vvRows: [
    vr([
      vc('internal', 'SYS-101'),
      vc('sku', 'A-100'),
      vc('title', 'Premium Chair'),
      vc('qty', 4),
      vc('note', 'Ready'),
    ]),
    vr([
      vc('internal', 'SYS-102'),
      vc('sku', 'B-200'),
      vc('title', 'Desk Lamp with Long Name'),
      vc('qty', 12),
      vc('note', 'Backorder'),
    ]),
    vr([
      vc('internal', 'SYS-103'),
      vc('sku', 'C-300'),
      vc('title', 'Cable Set'),
      vc('qty', 99),
      vc('note', ''),
    ]),
  ],
  sfColumnsFactory: () => [
    sf.GridColumn(
        columnName: 'internal',
        label: Text('Internal', style: textStyle),
        visible: false),
    sf.GridColumn(
        columnName: 'sku', label: Text('SKU', style: textStyle), width: 90),
    sf.GridColumn(
        columnName: 'title',
        label: Text('Title', style: textStyle),
        minimumWidth: 180),
    sf.GridColumn(
        columnName: 'qty',
        label: Text('Qty', style: textStyle),
        width: 70,
        maximumWidth: 80),
    sf.GridColumn(columnName: 'note', label: Text('Note', style: textStyle)),
  ],
  sfSourceFactory: () => StaticSfSource([
    sr([
      sc('internal', 'SYS-101'),
      sc('sku', 'A-100'),
      sc('title', 'Premium Chair'),
      sc('qty', 4),
      sc('note', 'Ready'),
    ]),
    sr([
      sc('internal', 'SYS-102'),
      sc('sku', 'B-200'),
      sc('title', 'Desk Lamp with Long Name'),
      sc('qty', 12),
      sc('note', 'Backorder'),
    ]),
    sr([
      sc('internal', 'SYS-103'),
      sc('sku', 'C-300'),
      sc('title', 'Cable Set'),
      sc('qty', 99),
      sc('note', ''),
    ]),
  ]),
);
