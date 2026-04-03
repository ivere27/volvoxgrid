import 'package:volvoxgrid/volvoxgrid.dart' hide Padding;

const List<int> _salesColWidths = [40, 80, 100, 120, 90, 90, 70, 56, 80, 140];
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
const int _salesBodyBg = 0xFFFFFFFF;
const int _salesBodyFg = 0xFF111827;
const int _salesCanvasBg = 0xFFFAFAFB;
const int _salesAltRowBg = 0xFFF9FAFB;
const int _salesFixedBg = 0xFFF3F4F6;
const int _salesFixedFg = 0xFF374151;
const int _salesGridColor = 0xFFE5E7EB;
const int _salesFixedGridColor = 0xFFD1D5DB;
const int _salesHeaderBg = 0xFFF9FAFB;
const int _salesHeaderFg = 0xFF111827;
const int _salesIndicatorBg = 0xFFF9FAFB;
const int _salesIndicatorFg = 0xFF6B7280;
const int _salesSelectionBg = 0xFF6366F1;
const int _salesSelectionFg = 0xFFFFFFFF;
const int _salesAccent = 0xFF818CF8;
const int _salesTreeColor = 0xFF9CA3AF;
const int _salesHoverBandBg = 0x106366F1;
const int _salesHoverCellBg = 0x1E818CF8;

Future<void> loadSalesJsonDemo(VolvoxGridController controller) async {
  await controller.setColCount(_salesColWidths.length);
  final columns = _salesDefineColumnsRequest();
  await controller.defineColumns(columns);
  final result = await controller.loadData(
    await controller.getDemoData('sales'),
    options: (LoadDataOptions()..autoCreateColumns = false),
  );
  if (result.status == LoadDataStatus.LOAD_FAILED) {
    throw StateError('LoadData failed for embedded sales demo');
  }
  await controller.defineColumns(columns);
  await controller.setColDropdownItems(8, _salesStatusItems);
  await controller.configure(_salesThemeConfig());

  await controller.subtotal(
    AggregateType.AGG_CLEAR,
    groupOnCol: 0,
    aggregateCol: 0,
    caption: '',
    backColor: 0,
    foreColor: 0,
    addOutline: false,
  );
  await controller.subtotal(
    AggregateType.AGG_SUM,
    groupOnCol: -1,
    aggregateCol: 4,
    caption: 'Grand Total',
    backColor: 0xFFEEF2FF,
    foreColor: 0xFF111827,
  );
  await controller.subtotal(
    AggregateType.AGG_SUM,
    groupOnCol: 0,
    aggregateCol: 4,
    caption: '',
    backColor: 0xFFF5F3FF,
    foreColor: 0xFF111827,
  );
  await controller.subtotal(
    AggregateType.AGG_SUM,
    groupOnCol: 1,
    aggregateCol: 4,
    caption: '',
    backColor: 0xFFF8F7FF,
    foreColor: 0xFF111827,
  );
  await controller.subtotal(
    AggregateType.AGG_SUM,
    groupOnCol: -1,
    aggregateCol: 5,
    caption: 'Grand Total',
    backColor: 0xFFEEF2FF,
    foreColor: 0xFF111827,
  );
  await controller.subtotal(
    AggregateType.AGG_SUM,
    groupOnCol: 0,
    aggregateCol: 5,
    caption: '',
    backColor: 0xFFF5F3FF,
    foreColor: 0xFF111827,
  );
  await controller.subtotal(
    AggregateType.AGG_SUM,
    groupOnCol: 1,
    aggregateCol: 5,
    caption: '',
    backColor: 0xFFF8F7FF,
    foreColor: 0xFF111827,
  );
  await _applySalesSubtotalDecorations(controller);
}

DefineColumnsRequest _salesDefineColumnsRequest() {
  final request = DefineColumnsRequest();
  for (var col = 0; col < _salesColWidths.length; col += 1) {
    final def = ColumnDef()
      ..index = col
      ..caption = _salesCaptions[col]
      ..key = _salesKeys[col]
      ..width = _salesColWidths[col];
    if (col == 0) {
      def.align = Align.ALIGN_CENTER_CENTER;
    } else if (col == 4 || col == 5) {
      def.align = Align.ALIGN_RIGHT_CENTER;
      def.dataType = ColumnDataType.COLUMN_DATA_CURRENCY;
      def.format = r'$#,##0';
    } else if (col == 6) {
      def.align = Align.ALIGN_CENTER_CENTER;
      def.dataType = ColumnDataType.COLUMN_DATA_NUMBER;
    } else if (col == 7) {
      def.align = Align.ALIGN_CENTER_CENTER;
      def.dataType = ColumnDataType.COLUMN_DATA_BOOLEAN;
    } else if (col == 8) {
      def.dropdownItems = _salesStatusItems;
    }
    if (col == 0 || col == 1) {
      def.span = true;
    }
    request.columns.add(def);
  }
  return request;
}

Future<void> _applySalesSubtotalDecorations(VolvoxGridController controller) async {
  await controller.setSpanCol(0, true);
  await controller.setSpanCol(1, true);

  final rowCount = await controller.rowCount();
  if (rowCount <= 0) {
    return;
  }

  final cells = await controller.getCellsRange(0, 3, rowCount - 1, 7);
  final rowTexts = List<List<String>>.generate(
    rowCount,
    (_) => List<String>.filled(5, ''),
  );
  for (final cell in cells.cells) {
    final row = cell.row;
    final colOffset = cell.col - 3;
    if (row < 0 ||
        row >= rowCount ||
        colOffset < 0 ||
        colOffset >= rowTexts[row].length ||
        !cell.hasValue() ||
        !cell.value.hasText()) {
      continue;
    }
    rowTexts[row][colOffset] = cell.value.text;
  }

  final updates = UpdateCellsRequest();
  final rowsNeedingMergeCheck = <int>[];
  for (var row = 0; row < rowCount; row += 1) {
    final values = rowTexts[row];
    final product = values[0];
    final sales = values[1];
    final cost = values[2];
    final isSubtotal = product.isEmpty && (sales.isNotEmpty || cost.isNotEmpty);
    if (!isSubtotal) {
      final margin = _parseSalesMarginPercent(values[3]);
      updates.cells.add(CellUpdate()
        ..row = row
        ..col = 6
        ..style = _salesProgressStyle(margin));
      final flagged = _parseSalesFlag(values[4]);
      updates.cells.add(CellUpdate()
        ..row = row
        ..col = 7
        ..value = (CellValue()..flag = flagged)
        ..checked = flagged
            ? CheckedState.CHECKED_CHECKED
            : CheckedState.CHECKED_UNCHECKED);
      updates.cells.add(CellUpdate()
        ..row = row
        ..col = 8
        ..dropdownItems = _salesStatusItems);
      continue;
    }
    if (sales.isEmpty && cost.isEmpty) {
      continue;
    }

    updates.cells.add(CellUpdate()
      ..row = row
      ..col = 7
      ..value = (CellValue()..flag = false)
      ..checked = CheckedState.CHECKED_GRAYED);

    final salesValue = _parseSalesMetric(sales);
    final costValue = _parseSalesMetric(cost);
    final margin = salesValue > 0
        ? ((salesValue - costValue) * 100.0) / salesValue
        : 0.0;
    updates.cells.add(CellUpdate()
      ..row = row
      ..col = 6
      ..value = (CellValue()..text = margin.toStringAsFixed(1))
      ..style = _salesProgressStyle(margin));

    rowsNeedingMergeCheck.add(row);
  }

  if (updates.cells.isNotEmpty) {
    await controller.updateCells(updates);
  }

  for (final row in rowsNeedingMergeCheck) {
    if ((await controller.getNode(row)).level <= 0) {
      await controller.mergeCells(row, 0, row, 1);
    }
  }
}

int _parseSalesMetric(String text) =>
    int.tryParse(text.trim().replaceAll(',', '')) ?? 0;

double _parseSalesMarginPercent(String text) =>
    double.tryParse(text.trim().replaceAll(',', '')) ?? 0.0;

bool _parseSalesFlag(String text) {
  switch (text.trim().toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'y':
    case 'on':
    case 'checked':
      return true;
    default:
      return false;
  }
}

CellStyle _salesProgressStyle(double marginPercent) {
  return CellStyle()
    ..progress = (marginPercent / 100.0).clamp(0.0, 1.0)
    ..progressColor = _salesAccent;
}

GridConfig _salesThemeConfig() {
  return GridConfig()
    ..layout = (LayoutConfig()
      ..fixedRows = 0
      ..extendLastCol = true)
    ..style = (StyleConfig()
      ..background = _salesBodyBg
      ..foreground = _salesBodyFg
      ..alternateBackground = _salesAltRowBg
      ..progressColor = _salesAccent
      ..sheetBackground = _salesCanvasBg
      ..sheetBorder = _salesFixedGridColor
      ..gridLines = (GridLines()
        ..style = GridLineStyle.GRIDLINE_SOLID
        ..color = _salesGridColor)
      ..fixed = (RegionStyle()
        ..background = _salesFixedBg
        ..foreground = _salesFixedFg
        ..gridLines = (GridLines()
          ..style = GridLineStyle.GRIDLINE_SOLID
          ..color = _salesFixedGridColor))
      ..frozen = (RegionStyle()
        ..background = _salesBodyBg
        ..foreground = _salesBodyFg
        ..gridLines = (GridLines()
          ..style = GridLineStyle.GRIDLINE_SOLID
          ..color = _salesFixedGridColor))
      ..header = (HeaderStyle()
        ..separator = (HeaderSeparator()
          ..enabled = true
          ..color = _salesFixedGridColor
          ..width = 1)
        ..resizeHandle = (HeaderResizeHandle()
          ..enabled = true
          ..color = _salesFixedGridColor
          ..width = 1
          ..hitWidth = 6)))
    ..selection = (SelectionConfig()
      ..mode = SelectionMode.SELECTION_FREE
      ..style = (HighlightStyle()
        ..background = _salesSelectionBg
        ..foreground = _salesSelectionFg
        ..fillHandle = FillHandlePosition.FILL_HANDLE_NONE
        ..fillHandleColor = _salesAccent)
      ..activeCellStyle = (HighlightStyle()
        ..background = 0x22000000
        ..foreground = _salesSelectionFg
        ..borders = (Borders()
          ..all = (Border()
            ..style = BorderStyle.BORDER_THICK
            ..color = _salesAccent)))
      ..hover = (HoverConfig()
        ..row = true
        ..column = true
        ..cell = true
        ..rowStyle = (HighlightStyle()..background = _salesHoverBandBg)
        ..columnStyle = (HighlightStyle()..background = _salesHoverBandBg)
        ..cellStyle = (HighlightStyle()
          ..background = _salesHoverCellBg
          ..borders = (Borders()
            ..all = (Border()
              ..style = BorderStyle.BORDER_THIN
              ..color = _salesAccent)))))
    ..editing = (EditConfig()
      ..trigger = EditTrigger.EDIT_TRIGGER_NONE
      ..dropdownTrigger = DropdownTrigger.DROPDOWN_ALWAYS
      ..dropdownSearch = false
      ..tabBehavior = TabBehavior.TAB_CELLS)
    ..scrolling = (ScrollConfig()
      ..scrollbars = ScrollBarsMode.SCROLLBAR_BOTH
      ..flingEnabled = true
      ..flingImpulseGain = 220.0
      ..flingFriction = 0.9)
    ..outline = (OutlineConfig()
      ..treeIndicator = TreeIndicatorStyle.TREE_INDICATOR_NONE
      ..treeColor = _salesTreeColor
      ..groupTotalPosition = GroupTotalPosition.GROUP_TOTAL_BELOW
      ..multiTotals = true)
    ..span = (SpanConfig()
      ..cellSpan = CellSpanMode.CELL_SPAN_ADJACENT
      ..cellSpanFixed = CellSpanMode.CELL_SPAN_NONE
      ..cellSpanCompare = 1)
    ..interaction = (InteractionConfig()
      ..resize = (ResizePolicy()
        ..columns = true
        ..rows = true)
      ..freeze_2 = (FreezePolicy()
        ..columns = true
        ..rows = true)
      ..autoSizeMouse = true
      ..headerFeatures = (HeaderFeatures()
        ..sort = true
        ..reorder = true
        ..chooser = false))
    ..indicators = (IndicatorsConfig()
      ..rowStart = (RowIndicatorConfig()
        ..visible = true
        ..width = 40
        ..modeBits = RowIndicatorMode.ROW_INDICATOR_NUMBERS.value
        ..background = _salesIndicatorBg
        ..foreground = _salesIndicatorFg
        ..gridColor = _salesFixedGridColor
        ..allowResize = true)
      ..colTop = (ColIndicatorConfig()
        ..visible = true
        ..defaultRowHeight = 28
        ..bandRows = 1
        ..modeBits = ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT.value |
            ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH.value
        ..background = _salesHeaderBg
        ..foreground = _salesHeaderFg
        ..gridColor = _salesFixedGridColor
        ..allowResize = true));
}
