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
  await _applySalesSubtotalDecorations(
    controller,
    await controller.subtotal(
      AggregateType.AGG_SUM,
      groupOnCol: -1,
      aggregateCol: 4,
      caption: 'Grand Total',
      backColor: 0xFFEEF2FF,
      foreColor: 0xFF111827,
    ),
  );
  await _applySalesSubtotalDecorations(
    controller,
    await controller.subtotal(
      AggregateType.AGG_SUM,
      groupOnCol: 0,
      aggregateCol: 4,
      caption: '',
      backColor: 0xFFF5F3FF,
      foreColor: 0xFF111827,
    ),
  );
  await _applySalesSubtotalDecorations(
    controller,
    await controller.subtotal(
      AggregateType.AGG_SUM,
      groupOnCol: 1,
      aggregateCol: 4,
      caption: '',
      backColor: 0xFFF8F7FF,
      foreColor: 0xFF111827,
    ),
  );
  await _applySalesSubtotalDecorations(
    controller,
    await controller.subtotal(
      AggregateType.AGG_SUM,
      groupOnCol: -1,
      aggregateCol: 5,
      caption: 'Grand Total',
      backColor: 0xFFEEF2FF,
      foreColor: 0xFF111827,
    ),
  );
  await _applySalesSubtotalDecorations(
    controller,
    await controller.subtotal(
      AggregateType.AGG_SUM,
      groupOnCol: 0,
      aggregateCol: 5,
      caption: '',
      backColor: 0xFFF5F3FF,
      foreColor: 0xFF111827,
    ),
  );
  await _applySalesSubtotalDecorations(
    controller,
    await controller.subtotal(
      AggregateType.AGG_SUM,
      groupOnCol: 1,
      aggregateCol: 5,
      caption: '',
      backColor: 0xFFF8F7FF,
      foreColor: 0xFF111827,
    ),
  );
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
      def.progressColor = _salesAccent;
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

Future<void> _applySalesSubtotalDecorations(
  VolvoxGridController controller,
  SubtotalResult result,
) async {
  await controller.setSpanCol(0, true);
  await controller.setSpanCol(1, true);

  final uniqueRows = result.rows.toSet().toList()..sort();
  for (final row in uniqueRows) {
    if ((await controller.getNode(row)).level <= 0) {
      await controller.mergeCells(row, 0, row, 1);
    }
  }
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
