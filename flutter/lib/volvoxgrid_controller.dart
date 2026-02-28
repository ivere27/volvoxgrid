/// High-level Dart controller wrapping the VolvoxGrid FFI service.
///
/// [VolvoxGridController] creates a native grid via the Synurang plugin,
/// exposes property getters/setters (rows, cols, text, etc.), and notifies
/// listeners so that the [VolvoxGridWidget] can repaint when data changes.
///
/// The API is asynchronous because calls cross an FFI/plugin boundary.
/// For high-volume updates, prefer [setCells], [setTableData], and
/// [withRedrawSuspended] to minimize per-call overhead.
library;

import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';

import 'src/generated/volvoxgrid.pb.dart';
import 'src/generated/volvoxgrid_ffi.pb.dart';

/// Simple row/col/text entry used by [setCells] batch operations.
class CellTextEntry {
  final int row;
  final int col;
  final String text;

  const CellTextEntry({
    required this.row,
    required this.col,
    required this.text,
  });
}

/// Controller for a single VolvoxGrid instance.
///
/// Usage:
/// ```dart
/// final controller = VolvoxGridController();
/// await controller.create(rows: 101, cols: 6);
/// await controller.setTextMatrix(0, 0, 'Header');
/// ```
class VolvoxGridController extends ChangeNotifier {
  Int64 _gridId = Int64.ZERO;
  bool _disposed = false;

  /// The native grid handle. Zero until [create] completes.
  Int64 get gridId => _gridId;

  /// Whether the grid has been created successfully.
  bool get isCreated => _gridId != Int64.ZERO;

  GridHandle get _handle => GridHandle()..id = _gridId;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Create a new native grid instance.
  ///
  /// [rows] and [cols] include any fixed header rows/cols.
  /// [fixedRows] defaults to 1 (one header row).
  /// [fixedCols] defaults to 0.
  /// [viewportWidth] and [viewportHeight] set the initial pixel dimensions.
  Future<void> create({
    int rows = 50,
    int cols = 10,
    int fixedRows = 1,
    int fixedCols = 0,
    int viewportWidth = 800,
    int viewportHeight = 600,
    double scale = 1.0,
  }) async {
    final req = CreateRequest()
      ..viewportWidth = viewportWidth
      ..viewportHeight = viewportHeight
      ..scale = scale
      ..config = (GridConfig()
        ..layout = (LayoutConfig()
          ..rows = rows
          ..cols = cols
          ..fixedRows = fixedRows
          ..fixedCols = fixedCols));
    final handle = await VolvoxGridServiceFfi.Create(req);
    _gridId = handle.id;
    notifyListeners();
  }

  /// Destroy the native grid and release resources.
  Future<void> destroyGrid() async {
    if (!isCreated) return;
    await VolvoxGridServiceFfi.Destroy(_handle);
    _gridId = Int64.ZERO;
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      destroyGrid();
    }
    super.dispose();
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  Future<void> _configure(GridConfig config) async {
    await VolvoxGridServiceFfi.Configure(ConfigureRequest()
      ..gridId = _gridId
      ..config = config);
    notifyListeners();
  }

  Future<GridConfig> _getConfig() {
    return VolvoxGridServiceFfi.GetConfig(_handle);
  }

  SelectRequest _buildSingleRangeSelectRequest(
    int activeRow,
    int activeCol, {
    int? rowEnd,
    int? colEnd,
    bool show = false,
  }) {
    final endRow = rowEnd ?? activeRow;
    final endCol = colEnd ?? activeCol;
    final range = CellRange()
      ..row1 = activeRow < endRow ? activeRow : endRow
      ..col1 = activeCol < endCol ? activeCol : endCol
      ..row2 = activeRow > endRow ? activeRow : endRow
      ..col2 = activeCol > endCol ? activeCol : endCol;
    return SelectRequest()
      ..gridId = _gridId
      ..activeRow = activeRow
      ..activeCol = activeCol
      ..ranges.add(range)
      ..show = show;
  }

  // ── Grid Dimensions ───────────────────────────────────────────────────────

  /// Get the total number of rows.
  Future<int> getRows() async {
    final config = await _getConfig();
    return config.layout.rows;
  }

  /// Set the total number of rows (including fixed rows).
  Future<void> setRows(int n) async {
    await _configure(GridConfig()..layout = (LayoutConfig()..rows = n));
  }

  /// Get the total number of columns.
  Future<int> getCols() async {
    final config = await _getConfig();
    return config.layout.cols;
  }

  /// Set the total number of columns (including fixed cols).
  Future<void> setCols(int n) async {
    await _configure(GridConfig()..layout = (LayoutConfig()..cols = n));
  }

  /// Set the number of non-scrollable header rows.
  Future<void> setFixedRows(int n) async {
    await _configure(GridConfig()..layout = (LayoutConfig()..fixedRows = n));
  }

  /// Set the number of non-scrollable header columns.
  Future<void> setFixedCols(int n) async {
    await _configure(GridConfig()..layout = (LayoutConfig()..fixedCols = n));
  }

  /// Set frozen (non-scrollable data) rows below the fixed rows.
  Future<void> setFrozenRows(int n) async {
    await _configure(GridConfig()..layout = (LayoutConfig()..frozenRows = n));
  }

  /// Set frozen (non-scrollable data) columns.
  Future<void> setFrozenCols(int n) async {
    await _configure(GridConfig()..layout = (LayoutConfig()..frozenCols = n));
  }

  // ── Row / Column Sizing ───────────────────────────────────────────────────

  /// Set the height of a specific row in pixels.
  Future<void> setRowHeight(int row, int height) async {
    await VolvoxGridServiceFfi.DefineRows(DefineRowsRequest()
      ..gridId = _gridId
      ..rows.add(RowDef()
        ..index = row
        ..height = height));
    notifyListeners();
  }

  /// Set the width of a specific column in pixels.
  Future<void> setColWidth(int col, int width) async {
    await VolvoxGridServiceFfi.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..width = width));
    notifyListeners();
  }

  /// Get the height of a specific row.
  Future<int> getRowHeight(int row) async {
    // Use GetConfig to read default; per-row heights require GetCells or
    // specialized query — for now read from config defaults.
    final config = await _getConfig();
    return config.layout.defaultRowHeight;
  }

  /// Get the width of a specific column.
  Future<int> getColWidth(int col) async {
    final config = await _getConfig();
    return config.layout.defaultColWidth;
  }

  // ── Row / Column Structure ────────────────────────────────────────────────

  /// Insert [count] rows before [index] (`-1` appends at end).
  ///
  /// Optional [text] entries map to the proto tab-separated row payload.
  Future<void> insertRows(
    int index, {
    int count = 1,
    List<String> text = const [],
  }) async {
    final req = InsertRowsRequest()
      ..gridId = _gridId
      ..index = index
      ..count = count;
    if (text.isNotEmpty) {
      req.text.addAll(text);
    }
    await VolvoxGridServiceFfi.InsertRows(req);
    notifyListeners();
  }

  /// Remove [count] rows starting at [index].
  Future<void> removeRows(int index, {int count = 1}) async {
    await VolvoxGridServiceFfi.RemoveRows(RemoveRowsRequest()
      ..gridId = _gridId
      ..index = index
      ..count = count);
    notifyListeners();
  }

  /// Move a column to a new [position].
  Future<void> moveColumn(int col, int position) async {
    await VolvoxGridServiceFfi.MoveColumn(MoveColumnRequest()
      ..gridId = _gridId
      ..col = col
      ..position = position);
    notifyListeners();
  }

  /// Move a row to a new [position].
  Future<void> moveRow(int row, int position) async {
    await VolvoxGridServiceFfi.MoveRow(MoveRowRequest()
      ..gridId = _gridId
      ..row = row
      ..position = position);
    notifyListeners();
  }

  // ── Cell Text ─────────────────────────────────────────────────────────────

  /// Set the text of a cell at the given [row] and [col].
  Future<void> setTextMatrix(int row, int col, String text) async {
    await VolvoxGridServiceFfi.UpdateCells(UpdateCellsRequest()
      ..gridId = _gridId
      ..cells.add(CellUpdate()
        ..row = row
        ..col = col
        ..value = (CellValue()..text = text)));
    notifyListeners();
  }

  /// Get the text of a cell at the given [row] and [col].
  Future<String> getTextMatrix(int row, int col) async {
    final resp = await VolvoxGridServiceFfi.GetCells(GetCellsRequest()
      ..gridId = _gridId
      ..row1 = row
      ..col1 = col
      ..row2 = row
      ..col2 = col);
    if (resp.cells.isNotEmpty) {
      final v = resp.cells.first.value;
      if (v.hasText()) return v.text;
    }
    return '';
  }

  /// Batch set many cell values in a single RPC.
  Future<void> setCells(List<CellTextEntry> cells) async {
    if (cells.isEmpty) return;
    final req = UpdateCellsRequest()..gridId = _gridId;
    for (final cell in cells) {
      req.cells.add(CellUpdate()
        ..row = cell.row
        ..col = cell.col
        ..value = (CellValue()..text = cell.text));
    }
    await VolvoxGridServiceFfi.UpdateCells(req);
    notifyListeners();
  }

  /// Fill a 2D matrix into the grid starting at [startRow]/[startCol].
  ///
  /// When [resizeGrid] is true, rows/cols are grown before applying data.
  Future<void> setTableData(
    List<List<String>> rows, {
    int startRow = 0,
    int startCol = 0,
    bool resizeGrid = true,
  }) async {
    if (rows.isEmpty) return;
    final maxCols =
        rows.fold<int>(0, (m, row) => row.length > m ? row.length : m);
    if (maxCols <= 0) return;

    await withRedrawSuspended(() async {
      if (resizeGrid) {
        final neededRows = startRow + rows.length;
        final neededCols = startCol + maxCols;
        final currentRows = await getRows();
        final currentCols = await getCols();
        if (neededRows > currentRows || neededCols > currentCols) {
          final layout = LayoutConfig();
          if (neededRows > currentRows) layout.rows = neededRows;
          if (neededCols > currentCols) layout.cols = neededCols;
          await _configure(GridConfig()..layout = layout);
        }
      }

      final cells = <CellTextEntry>[];
      for (var r = 0; r < rows.length; r++) {
        final row = rows[r];
        for (var c = 0; c < row.length; c++) {
          cells.add(CellTextEntry(
            row: startRow + r,
            col: startCol + c,
            text: row[c],
          ));
        }
      }
      await setCells(cells);
    });
  }

  /// Load a row-major string matrix in one RPC.
  ///
  /// [values] must be `rows * cols` long in row-major order.
  Future<void> loadArray(
    int rows,
    int cols,
    List<String> values, {
    bool bind = false,
  }) async {
    await VolvoxGridServiceFfi.LoadArray(LoadArrayRequest()
      ..gridId = _gridId
      ..rows = rows
      ..cols = cols
      ..values.addAll(values)
      ..bind = bind);
    notifyListeners();
  }

  /// Clear content/formatting based on [scope] and [region].
  Future<void> clear({
    ClearScope scope = ClearScope.CLEAR_EVERYTHING,
    ClearRegion region = ClearRegion.CLEAR_SCROLLABLE,
  }) async {
    await VolvoxGridServiceFfi.Clear(ClearRequest()
      ..gridId = _gridId
      ..scope = scope
      ..region = region);
    notifyListeners();
  }

  // ── Cursor & Selection ────────────────────────────────────────────────────

  /// Move the active cursor to the given row.
  Future<void> setRow(int row) async {
    await VolvoxGridServiceFfi.Select(_buildSingleRangeSelectRequest(row, -1));
    notifyListeners();
  }

  /// Move the active cursor to the given column.
  Future<void> setCol(int col) async {
    await VolvoxGridServiceFfi.Select(_buildSingleRangeSelectRequest(-1, col));
    notifyListeners();
  }

  /// Get the current cursor row.
  Future<int> getRow() async {
    final sel = await VolvoxGridServiceFfi.GetSelection(_handle);
    return sel.activeRow;
  }

  /// Get the current cursor column.
  Future<int> getCol() async {
    final sel = await VolvoxGridServiceFfi.GetSelection(_handle);
    return sel.activeCol;
  }

  /// Select a rectangular range of cells.
  Future<void> selectRange(
      int rowStart, int colStart, int rowEnd, int colEnd) async {
    await VolvoxGridServiceFfi.Select(_buildSingleRangeSelectRequest(
      rowStart,
      colStart,
      rowEnd: rowEnd,
      colEnd: colEnd,
    ));
    notifyListeners();
  }

  /// Legacy alias for [selectRange].
  Future<void> select(int row1, int col1, int row2, int col2) async {
    await selectRange(row1, col1, row2, col2);
  }

  /// Get the current selection state.
  Future<SelectionState> getSelection() async {
    return VolvoxGridServiceFfi.GetSelection(_handle);
  }

  /// Set the selection mode (free, by-row, by-column, listbox).
  Future<void> setSelectionMode(SelectionMode mode) async {
    await _configure(
        GridConfig()..selection = (SelectionConfig()..mode = mode));
  }

  /// Set the selection visibility style.
  Future<void> setSelectionVisibility(SelectionVisibility style) async {
    await _configure(
        GridConfig()..selection = (SelectionConfig()..selectionVisibility = style));
  }

  /// Legacy alias for [setSelectionVisibility].
  Future<void> setHighLight(SelectionVisibility style) async {
    await setSelectionVisibility(style);
  }

  /// Scroll the grid so that the specified cell is visible.
  Future<void> showCell(int row, int col) async {
    await VolvoxGridServiceFfi.Select(
      _buildSingleRangeSelectRequest(row, col, show: true),
    );
  }

  /// Set the topmost visible scrollable row.
  ///
  /// If [col] is omitted, the current selected column is preserved.
  Future<void> setTopRow(int row, {int? col}) async {
    var targetCol = col;
    if (targetCol == null || targetCol < 0) {
      try {
        targetCol = (await VolvoxGridServiceFfi.GetSelection(_handle)).activeCol;
      } catch (_) {
        targetCol = 0;
      }
    }
    // Select with show=true scrolls to the cell.
    await VolvoxGridServiceFfi.Select(
      _buildSingleRangeSelectRequest(row, targetCol, show: true),
    );
  }

  /// Get the topmost visible scrollable row.
  Future<int> getTopRow() async {
    final sel = await VolvoxGridServiceFfi.GetSelection(_handle);
    return sel.topRow;
  }

  // ── Sorting ───────────────────────────────────────────────────────────────

  /// Sort the grid by one or more columns.
  ///
  /// Single-column: `sort(SortOrder.SORT_GENERIC_ASCENDING, col: 0)`
  /// Multi-column:  `sortMulti([(0, SortOrder.SORT_GENERIC_ASCENDING), (2, SortOrder.SORT_GENERIC_DESCENDING)])`
  Future<void> sort(SortOrder order, {int col = -1}) async {
    await VolvoxGridServiceFfi.Sort(SortRequest()
      ..gridId = _gridId
      ..sortColumns.add(SortColumn()
        ..col = col
        ..order = order));
    notifyListeners();
  }

  /// Sort the grid by multiple columns.
  Future<void> sortMulti(List<(int, SortOrder)> columns) async {
    final req = SortRequest()..gridId = _gridId;
    for (final (col, order) in columns) {
      req.sortColumns.add(SortColumn()
        ..col = col
        ..order = order);
    }
    await VolvoxGridServiceFfi.Sort(req);
    notifyListeners();
  }

  /// Configure header features (sort/reorder/chooser behavior).
  Future<void> setHeaderFeatures(HeaderFeatures mode) async {
    await _configure(
        GridConfig()..interaction = (InteractionConfig()..headerFeatures = mode));
  }

  /// Legacy alias for [setHeaderFeatures].
  Future<void> setExplorerBar(HeaderFeatures mode) async {
    await setHeaderFeatures(mode);
  }

  // ── Subtotals ─────────────────────────────────────────────────────────────

  /// Insert subtotal rows grouping on [groupOnCol] and aggregating
  /// [aggregateCol] with the specified [aggregate] function.
  Future<void> subtotal(
    AggregateType aggregate, {
    required int groupOnCol,
    required int aggregateCol,
    String caption = '',
    int backColor = 0xFFE0E0E0,
    int foreColor = 0xFF000000,
    bool addOutline = true,
  }) async {
    await VolvoxGridServiceFfi.Subtotal(SubtotalRequest()
      ..gridId = _gridId
      ..aggregate = aggregate
      ..groupOnCol = groupOnCol
      ..aggregateCol = aggregateCol
      ..caption = caption
      ..backColor = backColor
      ..foreColor = foreColor
      ..addOutline = addOutline);
    notifyListeners();
  }

  // ── Outline ───────────────────────────────────────────────────────────────

  /// Set the tree indicator display mode.
  Future<void> setTreeIndicator(TreeIndicatorStyle style) async {
    await _configure(
        GridConfig()..outline = (OutlineConfig()..treeIndicator = style));
  }

  /// Legacy alias for [setTreeIndicator].
  Future<void> setOutlineBar(TreeIndicatorStyle style) async {
    await setTreeIndicator(style);
  }

  /// Set the outline level for a specific row.
  Future<void> setRowOutlineLevel(int row, int level) async {
    await VolvoxGridServiceFfi.DefineRows(DefineRowsRequest()
      ..gridId = _gridId
      ..rows.add(RowDef()
        ..index = row
        ..outlineLevel = level));
  }

  /// Expand/collapse rows to the requested [level].
  Future<void> outline(int level) async {
    await VolvoxGridServiceFfi.Outline(OutlineRequest()
      ..gridId = _gridId
      ..level = level);
    notifyListeners();
  }

  /// Mark a row as a subtotal node (shows +/- expand/collapse button).
  Future<void> setIsSubtotal(int row, bool isSubtotal) async {
    await VolvoxGridServiceFfi.DefineRows(DefineRowsRequest()
      ..gridId = _gridId
      ..rows.add(RowDef()
        ..index = row
        ..isSubtotal = isSubtotal));
  }

  /// Query outline node information for [row].
  Future<NodeInfo> getNode(int row, {NodeRelation? relation}) async {
    final req = GetNodeRequest()
      ..gridId = _gridId
      ..row = row;
    if (relation != null) {
      req.relation = relation;
    }
    return VolvoxGridServiceFfi.GetNode(req);
  }

  // ── Span ─────────────────────────────────────────────────────────────────

  /// Set the cell span mode.
  Future<void> setCellSpanMode(CellSpanMode mode) async {
    await _configure(GridConfig()..span = (SpanConfig()..cellSpan = mode));
  }

  /// Legacy alias for [setCellSpanMode].
  Future<void> setSpanCells(CellSpanMode mode) async {
    await setCellSpanMode(mode);
  }

  /// Enable or disable spanning for a specific column.
  Future<void> setSpanCol(int col, bool span) async {
    await VolvoxGridServiceFfi.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..span = span));
    notifyListeners();
  }

  /// Enable or disable spanning for a specific row.
  Future<void> setSpanRow(int row, bool span) async {
    await VolvoxGridServiceFfi.DefineRows(DefineRowsRequest()
      ..gridId = _gridId
      ..rows.add(RowDef()
        ..index = row
        ..span = span));
    notifyListeners();
  }

  // ── Column Combo Lists ──────────────────────────────────────────────────

  /// Set the dropdown items for a column (pipe-delimited, e.g. "A|B|C").
  Future<void> setColDropdownItems(int col, String items) async {
    await VolvoxGridServiceFfi.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..dropdownItems = items));
  }

  /// Legacy alias for [setColDropdownItems].
  Future<void> setColComboList(int col, String list) async {
    await setColDropdownItems(col, list);
  }

  /// Set dropdown items for an individual cell.
  Future<void> setCellDropdownItems(int row, int col, String items) async {
    await VolvoxGridServiceFfi.UpdateCells(UpdateCellsRequest()
      ..gridId = _gridId
      ..cells.add(CellUpdate()
        ..row = row
        ..col = col
        ..dropdownItems = items));
    notifyListeners();
  }

  // ── Editing ───────────────────────────────────────────────────────────────

  /// Set the edit trigger mode for the grid.
  Future<void> setEditTrigger(EditTrigger mode) async {
    await _configure(GridConfig()..editing = (EditConfig()..editTrigger = mode));
  }

  /// Legacy alias for [setEditTrigger].
  Future<void> setEditable(EditTrigger mode) async {
    await setEditTrigger(mode);
  }

  /// Commit or cancel the current cell edit.
  Future<void> commitEdit(String text, {bool cancel = false}) async {
    if (cancel) {
      await VolvoxGridServiceFfi.Edit(EditCommand()
        ..gridId = _gridId
        ..cancel = EditCancel());
    } else {
      await VolvoxGridServiceFfi.Edit(EditCommand()
        ..gridId = _gridId
        ..commit = (EditCommit()..text = text));
    }
    notifyListeners();
  }

  /// Cancel the current cell edit.
  Future<void> cancelEdit() async {
    await VolvoxGridServiceFfi.Edit(EditCommand()
      ..gridId = _gridId
      ..cancel = EditCancel());
    notifyListeners();
  }

  // ── Column Formatting ─────────────────────────────────────────────────────

  /// Set the data type for a column (string, number, date, etc.).
  Future<void> setColDataType(int col, ColumnDataType dataType) async {
    await VolvoxGridServiceFfi.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..dataType = dataType));
  }

  /// Set the text alignment for a column.
  Future<void> setColAlignment(int col, Align alignment) async {
    await VolvoxGridServiceFfi.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..alignment = alignment));
  }

  /// Set the format string for a column (e.g. '#,##0.00' for currency).
  Future<void> setColFormat(int col, String format) async {
    await VolvoxGridServiceFfi.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..format = format));
  }

  /// Enable native custom-render mode.
  Future<void> setCustomRender(CustomRenderMode mode) async {
    await _configure(GridConfig()..style = (StyleConfig()..customRender = mode));
  }

  /// Legacy alias for [setCustomRender].
  Future<void> setOwnerDraw(CustomRenderMode mode) async {
    await setCustomRender(mode);
  }

  /// Apply grid-level style defaults (font, colors, lines, etc.).
  Future<void> setGridStyle(StyleConfig style) async {
    await _configure(GridConfig()..style = style);
  }

  /// Get the current effective grid-level style.
  Future<StyleConfig> getGridStyle() async {
    final config = await _getConfig();
    return config.style;
  }

  /// Apply cell style to an explicit range.
  Future<void> setCellStyleRange(
    int row1,
    int col1,
    int row2,
    int col2,
    CellStyleOverride style,
  ) async {
    final req = UpdateCellsRequest()..gridId = _gridId;
    for (var r = row1; r <= row2; r++) {
      for (var c = col1; c <= col2; c++) {
        req.cells.add(CellUpdate()
          ..row = r
          ..col = c
          ..style = style);
      }
    }
    await VolvoxGridServiceFfi.UpdateCells(req);
    notifyListeners();
  }

  // ── User Interaction ──────────────────────────────────────────────────────

  /// Allow the user to resize rows and/or columns.
  Future<void> setAllowUserResizing(AllowUserResizingMode mode) async {
    await _configure(GridConfig()
      ..interaction = (InteractionConfig()..allowUserResizing = mode));
  }

  /// Set scrollbar visibility mode.
  Future<void> setScrollBars(ScrollBarsMode mode) async {
    await _configure(
        GridConfig()..scrolling = (ScrollConfig()..scrollbars = mode));
  }

  /// Enable/disable engine-side inertial fling.
  Future<void> setFlingEnabled(bool enabled) async {
    await _configure(
        GridConfig()..scrolling = (ScrollConfig()..flingEnabled = enabled));
  }

  /// Enable/disable engine-side fast scroll thumb.
  Future<void> setFastScrollEnabled(bool enabled) async {
    await _configure(
        GridConfig()..scrolling = (ScrollConfig()..fastScroll = enabled));
  }

  /// Set common interaction/UX behavior in one call.
  Future<void> setInteractionConfig(InteractionConfig config) async {
    await _configure(GridConfig()..interaction = config);
  }

  /// Auto-size a range of columns.
  Future<void> autoSize({
    int colFrom = 0,
    int colTo = -1,
    bool equal = false,
    int maxWidth = 0,
  }) async {
    await VolvoxGridServiceFfi.AutoSize(AutoSizeRequest()
      ..gridId = _gridId
      ..colFrom = colFrom
      ..colTo = colTo
      ..equal = equal
      ..maxWidth = maxWidth);
    notifyListeners();
  }

  /// Get the current interaction/UX configuration.
  Future<InteractionConfig> getInteractionConfig() async {
    final config = await _getConfig();
    return config.interaction;
  }

  /// Set engine inertial impulse gain (higher values fling farther/faster).
  Future<void> setFlingImpulseGain(double gain) async {
    if (!gain.isFinite) return;
    await _configure(GridConfig()
      ..scrolling = (ScrollConfig()..flingImpulseGain = gain < 0 ? 0.0 : gain));
  }

  /// Set engine inertial friction (higher values stop sooner).
  Future<void> setFlingFriction(double friction) async {
    if (!friction.isFinite) return;
    final clamped = friction.clamp(0.1, 20.0);
    await _configure(GridConfig()
      ..scrolling = (ScrollConfig()..flingFriction = clamped.toDouble()));
  }

  // ── Viewport ──────────────────────────────────────────────────────────────

  /// Notify the native grid that the viewport size changed.
  Future<void> resizeViewport(int width, int height) async {
    await VolvoxGridServiceFfi.ResizeViewport(ResizeViewportRequest()
      ..gridId = _gridId
      ..width = width
      ..height = height);
    notifyListeners();
  }

  // ── Save / Load / Print ───────────────────────────────────────────────────

  /// Save the grid to an in-memory payload.
  Future<ExportResponse> saveGrid({
    ExportFormat format = ExportFormat.EXPORT_BINARY,
    ExportScope scope = ExportScope.EXPORT_ALL,
  }) async {
    return VolvoxGridServiceFfi.Export(ExportRequest()
      ..gridId = _gridId
      ..format = format
      ..scope = scope);
  }

  /// Load grid data from a previously saved payload.
  Future<void> loadGrid(
    List<int> data, {
    ExportFormat format = ExportFormat.EXPORT_BINARY,
    ExportScope scope = ExportScope.EXPORT_ALL,
  }) async {
    await VolvoxGridServiceFfi.Import(ImportRequest()
      ..gridId = _gridId
      ..data = data
      ..format = format
      ..scope = scope);
    notifyListeners();
  }

  /// Render printable pages.
  Future<PrintResponse> printGrid({
    PrintOrientation orientation = PrintOrientation.PRINT_PORTRAIT,
    int marginLeft = 0,
    int marginTop = 0,
    int marginRight = 0,
    int marginBottom = 0,
    String header = '',
    String footer = '',
    bool showPageNumbers = true,
  }) async {
    return VolvoxGridServiceFfi.Print(PrintRequest()
      ..gridId = _gridId
      ..orientation = orientation
      ..marginLeft = marginLeft
      ..marginTop = marginTop
      ..marginRight = marginRight
      ..marginBottom = marginBottom
      ..header = header
      ..footer = footer
      ..showPageNumbers = showPageNumbers);
  }

  /// Store/load/list/delete named archive snapshots.
  Future<ArchiveResponse> archive({
    required ArchiveRequest_Action action,
    String name = '',
    List<int> data = const [],
  }) async {
    final req = ArchiveRequest()
      ..gridId = _gridId
      ..name = name
      ..action = action;
    if (data.isNotEmpty) {
      req.data = data;
    }
    return VolvoxGridServiceFfi.Archive(req);
  }

  // ── Clipboard ──────────────────────────────────────────────────────────────

  /// Copy current selection to clipboard payload.
  Future<ClipboardResponse> copy() async {
    return VolvoxGridServiceFfi.Clipboard(ClipboardCommand()
      ..gridId = _gridId
      ..copy = ClipboardCopy());
  }

  /// Cut current selection to clipboard payload.
  Future<ClipboardResponse> cut() async {
    final data = await VolvoxGridServiceFfi.Clipboard(ClipboardCommand()
      ..gridId = _gridId
      ..cut = ClipboardCut());
    notifyListeners();
    return data;
  }

  /// Paste provided clipboard text into current selection.
  Future<void> paste(String text) async {
    await VolvoxGridServiceFfi.Clipboard(ClipboardCommand()
      ..gridId = _gridId
      ..paste = (ClipboardPaste()..text = text));
    notifyListeners();
  }

  /// Delete current selection contents.
  Future<void> deleteSelection() async {
    await VolvoxGridServiceFfi.Clipboard(ClipboardCommand()
      ..gridId = _gridId
      ..delete = ClipboardDelete());
    notifyListeners();
  }

  // ── Pin & Sticky ──────────────────────────────────────────────────────────

  /// Pin a row to top or bottom, or unpin it.
  Future<void> pinRow(int row, PinPosition pin) async {
    await VolvoxGridServiceFfi.DefineRows(DefineRowsRequest()
      ..gridId = _gridId
      ..rows.add(RowDef()
        ..index = row
        ..pin = pin));
    notifyListeners();
  }

  /// Set sticky edge for a row.
  Future<void> setRowSticky(int row, StickyEdge edge) async {
    await VolvoxGridServiceFfi.DefineRows(DefineRowsRequest()
      ..gridId = _gridId
      ..rows.add(RowDef()
        ..index = row
        ..sticky = edge));
    notifyListeners();
  }

  /// Set sticky edge for a column.
  Future<void> setColSticky(int col, StickyEdge edge) async {
    await VolvoxGridServiceFfi.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..sticky = edge));
    notifyListeners();
  }

  // ── Query Actions ─────────────────────────────────────────────────────────

  /// Find a row using plain text query. Returns `-1` when not found.
  Future<int> findRowByText(
    String text, {
    required int col,
    int startRow = 0,
    bool caseSensitive = false,
    bool fullMatch = false,
  }) async {
    final resp = await VolvoxGridServiceFfi.Find(FindRequest()
      ..gridId = _gridId
      ..col = col
      ..startRow = startRow
      ..textQuery = (TextQuery()
        ..text = text
        ..caseSensitive = caseSensitive
        ..fullMatch = fullMatch));
    return resp.row;
  }

  /// Find a row using regex query. Returns `-1` when not found.
  Future<int> findRowByRegex(
    String pattern, {
    required int col,
    int startRow = 0,
  }) async {
    final resp = await VolvoxGridServiceFfi.Find(FindRequest()
      ..gridId = _gridId
      ..col = col
      ..startRow = startRow
      ..regexQuery = (RegexQuery()..pattern = pattern));
    return resp.row;
  }

  /// Aggregate a rectangular range and return the numeric result.
  Future<double> aggregate(
    AggregateType type,
    int row1,
    int col1,
    int row2,
    int col2,
  ) async {
    final resp = await VolvoxGridServiceFfi.Aggregate(AggregateRequest()
      ..gridId = _gridId
      ..aggregate = type
      ..row1 = row1
      ..col1 = col1
      ..row2 = row2
      ..col2 = col2);
    return resp.value;
  }

  /// Return the merged range containing ([row], [col]).
  Future<CellRange> getMergedRange(int row, int col) async {
    return VolvoxGridServiceFfi.GetMergedRange(GetMergedRangeRequest()
      ..gridId = _gridId
      ..row = row
      ..col = col);
  }

  /// Merge cells in the given range.
  Future<void> mergeCells(int row1, int col1, int row2, int col2) async {
    await VolvoxGridServiceFfi.MergeCells(MergeCellsRequest()
      ..gridId = _gridId
      ..range = (CellRange()
        ..row1 = row1
        ..col1 = col1
        ..row2 = row2
        ..col2 = col2));
    notifyListeners();
  }

  /// Unmerge cells in the given range.
  Future<void> unmergeCells(int row1, int col1, int row2, int col2) async {
    await VolvoxGridServiceFfi.UnmergeCells(UnmergeCellsRequest()
      ..gridId = _gridId
      ..range = (CellRange()
        ..row1 = row1
        ..col1 = col1
        ..row2 = row2
        ..col2 = col2));
    notifyListeners();
  }

  /// Return all explicit merge regions.
  Future<MergedRegionsResponse> getMergedRegions() async {
    return VolvoxGridServiceFfi.GetMergedRegions(GridHandle()..id = _gridId);
  }

  // ── Render Session ────────────────────────────────────────────────────────

  /// Open a bidirectional render session.
  Stream<RenderOutput> renderSession(Stream<RenderInput> inputs) {
    return VolvoxGridServiceFfi.RenderSession(inputs);
  }

  // ── Event Stream ──────────────────────────────────────────────────────────

  /// Subscribe to native grid events (selection changes, edits, etc.).
  Stream<GridEvent> eventStream() {
    return VolvoxGridServiceFfi.EventStream(_handle);
  }

  // ── Demo ─────────────────────────────────────────────────────────────────

  /// Load a built-in engine demo ("sales", "hierarchy", or "stress").
  Future<void> loadDemo(String demo) async {
    await VolvoxGridServiceFfi.LoadDemo(LoadDemoRequest()
      ..gridId = _gridId
      ..demo = demo);
    notifyListeners();
  }

  // ── Redraw Control ────────────────────────────────────────────────────────

  /// Suspend or resume native redraw.
  Future<void> setRedraw(bool enabled) async {
    await VolvoxGridServiceFfi.SetRedraw(SetRedrawRequest()
      ..gridId = _gridId
      ..enabled = enabled);
  }

  /// Enable or disable the debug overlay.
  Future<void> setDebugOverlay(bool enabled) async {
    await _configure(
        GridConfig()..rendering = (RenderConfig()..debugOverlay = enabled));
  }

  /// Enable or disable layout animation.
  Future<void> setAnimationEnabled(bool enabled, {int durationMs = 0}) async {
    final rc = RenderConfig()..animationEnabled = enabled;
    if (durationMs > 0) rc.animationDurationMs = durationMs;
    await _configure(GridConfig()..rendering = rc);
  }

  /// Set the text layout cache capacity (0 = disabled).
  Future<void> setTextLayoutCacheCap(int cap) async {
    final safeCap = cap < 0 ? 0 : cap;
    await _configure(
        GridConfig()..rendering = (RenderConfig()..textLayoutCacheCap = safeCap));
  }

  /// Get whether layout animation is enabled.
  Future<bool> getAnimationEnabled() async {
    final config = await _getConfig();
    return config.rendering.animationEnabled;
  }

  /// Get text layout cache capacity.
  Future<int> getTextLayoutCacheCap() async {
    final config = await _getConfig();
    return config.rendering.textLayoutCacheCap;
  }

  /// Set renderer mode: 0=CPU, 1=GPU, 2=AUTO.
  Future<void> setRendererMode(int mode) async {
    await _configure(GridConfig()
      ..rendering = (RenderConfig()
        ..rendererMode =
            (RendererMode.valueOf(mode) ?? RendererMode.RENDERER_CPU)));
  }

  /// Get the current renderer mode (0=CPU, 1=GPU, 2=AUTO).
  Future<int> getRendererMode() async {
    final config = await _getConfig();
    return config.rendering.rendererMode.value;
  }

  /// Run [action] while redraw is disabled, then restore and refresh.
  Future<T> withRedrawSuspended<T>(
    Future<T> Function() action, {
    bool refreshAfter = true,
  }) async {
    await setRedraw(false);
    try {
      return await action();
    } finally {
      await setRedraw(true);
      if (refreshAfter) {
        await refresh();
      }
    }
  }

  /// Force a full repaint.
  Future<void> refresh() async {
    await VolvoxGridServiceFfi.Refresh(_handle);
    notifyListeners();
  }
}
