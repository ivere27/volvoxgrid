import 'package:volvoxgrid/volvoxgrid.dart' hide Padding;

const List<String> _salesCaptions = [
  'Q',
  'Region',
  'Category',
  'Product',
  'Sales',
  'Cost',
  'Margin%',
  'Flag',
  'Status',
  'Notes',
];
const List<String> _salesKeys = [
  'Q',
  'Region',
  'Category',
  'Product',
  'Sales',
  'Cost',
  'Margin',
  'Flag',
  'Status',
  'Notes',
];
const String _salesStatusItems = 'Active|Pending|Shipped|Returned|Cancelled';
const int _quarterCol = 0;
const int _regionCol = 1;
const int _salesCol = 4;
const int _costCol = 5;
const int _marginCol = 6;
const int _flagCol = 7;
const int _statusCol = 8;
const int _grandTotalBackColor = 0xFFEEF2FF;
const int _quarterSubtotalBackColor = 0xFFF5F3FF;
const int _regionSubtotalBackColor = 0xFFF8F7FF;
const int _marginProgressColor = 0xFF818CF8;

ListEditorParams _salesStatusDropdown() => ListEditorParams()
  ..staticItems.addAll(
      _salesStatusItems.split('|').map((label) => ListItem()..label = label));

Future<void> loadSalesJsonDemo(VolvoxGridController controller) async {
  await controller.setThemePreset(ThemePreset.THEME_LIGHT);
  await controller.setShowRowIndicator(true);
  await controller.configure(GridConfig()
    ..outline = (OutlineConfig()
      ..treeIndicator = TreeIndicatorStyle.TREE_INDICATOR_NONE
      ..groupTotalPosition = GroupTotalPosition.GROUP_TOTAL_BELOW
      ..multiTotals = true));

  await controller.setColCount(_salesKeys.length);
  final columns = _salesDefineColumnsRequest();
  await controller.defineColumns(columns);
  final result = await controller.loadData(
    await controller.getDemoData('sales'),
    options: (LoadDataOptions()..autoCreateColumns = false),
  );
  if (result.status == LoadDataStatus.LOAD_FAILED) {
    throw StateError('LoadData failed for embedded sales demo');
  }
  await controller.setColDropdown(_statusCol, _salesStatusDropdown());
  await controller.setSpanCol(_quarterCol, true);
  await controller.setSpanCol(_regionCol, true);

  await controller.addSubtotals(
    [_salesCol, _costCol],
    const [
      VolvoxGridSubtotalLevel(
        caption: 'Grand Total',
        backColor: _grandTotalBackColor,
      ),
      VolvoxGridSubtotalLevel(
        groupCol: _quarterCol,
        backColor: _quarterSubtotalBackColor,
      ),
      VolvoxGridSubtotalLevel(
        groupCol: _regionCol,
        backColor: _regionSubtotalBackColor,
      ),
    ],
    mergeColFrom: _quarterCol,
    mergeColTo: _regionCol,
  );
  await controller.autoSize(colFrom: _salesCol, colTo: _costCol);
}

DefineColumnsRequest _salesDefineColumnsRequest() {
  final request = DefineColumnsRequest();
  for (var col = 0; col < _salesKeys.length; col += 1) {
    final def = ColumnDef()
      ..index = col
      ..caption = _salesCaptions[col]
      ..key = _salesKeys[col];
    if (col == _quarterCol) {
      def.align = Align.ALIGN_CENTER_CENTER;
    } else if (col == _salesCol || col == _costCol) {
      def.align = Align.ALIGN_RIGHT_CENTER;
      def.dataType = ColumnDataType.COLUMN_DATA_CURRENCY;
      def.format = r'$#,##0';
    } else if (col == _marginCol) {
      def.align = Align.ALIGN_CENTER_CENTER;
      def.dataType = ColumnDataType.COLUMN_DATA_NUMBER;
      def.progressColor = _marginProgressColor;
    } else if (col == _flagCol) {
      def.align = Align.ALIGN_CENTER_CENTER;
      def.dataType = ColumnDataType.COLUMN_DATA_BOOLEAN;
    }
    if (col == _quarterCol || col == _regionCol) {
      def.span = true;
    }
    request.columns.add(def);
  }
  return request;
}
