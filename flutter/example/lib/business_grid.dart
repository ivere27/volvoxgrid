import 'package:flutter/material.dart';
import 'package:volvoxgrid/volvoxgrid.dart';

// Run: flutter run -t lib/business_grid.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initVolvoxGrid();
  runApp(const MaterialApp(home: BusinessGrid()));
}

class Product {
  const Product(this.gridId, this.id, this.name, this.price, this.qty);
  final int
      gridId; // Optional stable numeric grid identity; id is the business key.
  final String id, name, price;
  final int qty;
}

class BusinessGrid extends StatefulWidget {
  const BusinessGrid({super.key});
  @override
  State<BusinessGrid> createState() => _BusinessGridState();
}

class _BusinessGridState extends State<BusinessGrid> {
  List<Product> rows = const [
    Product(101, 'sku-a', '상품 A', '29.99', 150),
    Product(102, 'sku-b', '상품 B', '19.50', 80),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sales & inventory')),
        body: VolvoxDataGrid<Product>(
          rows: rows,
          getRowId: (p) => p.gridId,
          columns: [
            VolvoxColumn(field: 'name', header: '상품', value: (p) => p.name),
            VolvoxColumn(
                field: 'price',
                header: '금액',
                value: (p) => p.price,
                type: VolvoxColumnType.decimal,
                editable: true),
            VolvoxColumn(
                field: 'qty',
                header: '수량',
                value: (p) => '${p.qty}',
                type: VolvoxColumnType.integer,
                editable: true),
          ],
          validateEdit: (e) {
            if (e.field == 'qty') {
              final qty = int.tryParse(e.newText);
              if (qty == null || qty < 0) return '수량은 0 이상의 정수여야 합니다.';
            }
            if (e.field == 'price' && e.newText.startsWith('-')) {
              return '금액을 확인하세요.';
            }
            return null;
          },
          onValidationError: (message) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message))),
          onError: (error, stack) => debugPrint('Grid error: $error'),
          onCellEdit: (e) => setState(() {
            rows = [
              for (final p in rows)
                if (p.id != e.row.id)
                  p
                else
                  Product(
                      p.gridId,
                      p.id,
                      p.name,
                      e.field == 'price' ? e.newText : p.price,
                      e.field == 'qty' ? int.parse(e.newText) : p.qty),
            ];
          }),
        ),
      );
}
