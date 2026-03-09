import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid/volvoxgrid.dart' hide Align, Border, Padding;
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initVolvoxGrid();
  runApp(const _CompareApp());
}

class _CompareApp extends StatelessWidget {
  const _CompareApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SfDataGrid Linux Compare',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
      home: const _ComparePage(),
    );
  }
}

class _Record {
  final String sku;
  final String product;
  final int qty;
  final double price;
  final String region;

  const _Record({
    required this.sku,
    required this.product,
    required this.qty,
    required this.price,
    required this.region,
  });
}

const List<_Record> _kRecords = <_Record>[
  _Record(sku: 'A-100', product: 'Keyboard', qty: 4, price: 89.0, region: 'NA'),
  _Record(sku: 'A-101', product: 'Mouse', qty: 8, price: 39.5, region: 'NA'),
  _Record(sku: 'B-205', product: 'Monitor', qty: 3, price: 249.0, region: 'EU'),
  _Record(sku: 'C-310', product: 'Dock', qty: 6, price: 119.0, region: 'APAC'),
  _Record(
      sku: 'D-450', product: 'Laptop Stand', qty: 5, price: 79.0, region: 'EU'),
  _Record(sku: 'E-510', product: 'Webcam', qty: 7, price: 129.0, region: 'NA'),
  _Record(
      sku: 'F-640', product: 'Headset', qty: 9, price: 149.0, region: 'APAC'),
  _Record(sku: 'G-777', product: 'USB Hub', qty: 10, price: 45.0, region: 'EU'),
];

class _SfSource extends sf.DataGridSource {
  _SfSource(this.records) {
    _rows = records
        .map(
          (r) => sf.DataGridRow(cells: <sf.DataGridCell<dynamic>>[
            sf.DataGridCell<String>(columnName: 'sku', value: r.sku),
            sf.DataGridCell<String>(columnName: 'product', value: r.product),
            sf.DataGridCell<int>(columnName: 'qty', value: r.qty),
            sf.DataGridCell<double>(columnName: 'price', value: r.price),
            sf.DataGridCell<String>(columnName: 'region', value: r.region),
          ]),
        )
        .toList(growable: false);
  }

  final List<_Record> records;
  late final List<sf.DataGridRow> _rows;

  @override
  List<sf.DataGridRow> get rows => _rows;

  @override
  sf.DataGridRowAdapter buildRow(sf.DataGridRow row) {
    return sf.DataGridRowAdapter(
      cells: row.getCells().map((c) {
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('${c.value ?? ''}'),
        );
      }).toList(growable: false),
    );
  }
}

class _VvSource extends vv.DataGridSource {
  _VvSource(this.records);

  final List<_Record> records;

  @override
  List<vv.DataGridRow> get rows => records
      .map(
        (r) => vv.DataGridRow(cells: <vv.DataGridCell<dynamic>>[
          vv.DataGridCell<String>(columnName: 'sku', value: r.sku),
          vv.DataGridCell<String>(columnName: 'product', value: r.product),
          vv.DataGridCell<int>(columnName: 'qty', value: r.qty),
          vv.DataGridCell<double>(columnName: 'price', value: r.price),
          vv.DataGridCell<String>(columnName: 'region', value: r.region),
        ]),
      )
      .toList(growable: false);
}

class _ComparePage extends StatefulWidget {
  const _ComparePage();

  @override
  State<_ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<_ComparePage> {
  late final _SfSource _sfSource;
  late final _VvSource _vvSource;

  final List<sf.GridColumn> _sfColumns = <sf.GridColumn>[
    sf.GridColumn(
      columnName: 'sku',
      width: 100,
      label: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: Alignment.centerLeft, child: Text('SKU')),
      ),
    ),
    sf.GridColumn(
      columnName: 'product',
      width: 220,
      label: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: Alignment.centerLeft, child: Text('Product')),
      ),
    ),
    sf.GridColumn(
      columnName: 'qty',
      width: 90,
      label: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: Alignment.centerLeft, child: Text('Qty')),
      ),
    ),
    sf.GridColumn(
      columnName: 'price',
      width: 100,
      label: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: Alignment.centerLeft, child: Text('Price')),
      ),
    ),
    sf.GridColumn(
      columnName: 'region',
      width: 110,
      label: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: Alignment.centerLeft, child: Text('Region')),
      ),
    ),
  ];

  final List<vv.GridColumn> _vvColumns = <vv.GridColumn>[
    vv.GridColumn(columnName: 'sku', label: Text('SKU'), width: 100),
    vv.GridColumn(columnName: 'product', label: Text('Product'), width: 220),
    vv.GridColumn(columnName: 'qty', label: Text('Qty'), width: 90),
    vv.GridColumn(columnName: 'price', label: Text('Price'), width: 100),
    vv.GridColumn(columnName: 'region', label: Text('Region'), width: 110),
  ];

  @override
  void initState() {
    super.initState();
    _sfSource = _SfSource(_kRecords);
    _vvSource = _VvSource(_kRecords);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _Panel(
                  title: 'Syncfusion SfDataGrid (Linux)',
                  child: sf.SfDataGrid(
                    source: _sfSource,
                    columns: _sfColumns,
                    selectionMode: sf.SelectionMode.multiple,
                    frozenColumnsCount: 1,
                    allowSorting: true,
                    allowColumnsResizing: true,
                    rowHeight: 34,
                    headerRowHeight: 38,
                    gridLinesVisibility: sf.GridLinesVisibility.both,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Panel(
                  title: 'VolvoxGrid SfDataGrid Adapter (Linux)',
                  child: vv.SfDataGridVolvox(
                    source: _vvSource,
                    columns: _vvColumns,
                    selectionMode: vv.SelectionMode.multiple,
                    frozenColumnsCount: 1,
                    allowSorting: true,
                    allowColumnsResizing: true,
                    rowHeight: 34,
                    headerRowHeight: 38,
                    gridLinesVisibility: vv.GridLinesVisibility.both,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD0D7DE)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5EAF0))),
            ),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
