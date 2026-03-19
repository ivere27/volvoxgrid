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
import 'package:flutter/services.dart';

import 'volvoxgrid_ffi.dart';

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

int _rowIndicatorModeBits(Iterable<RowIndicatorMode> modes) =>
    modes.fold<int>(0, (bits, mode) => bits | mode.value);

int _colIndicatorModeBits(Iterable<ColIndicatorCellMode> modes) =>
    modes.fold<int>(0, (bits, mode) => bits | mode.value);

IndicatorsConfig _defaultIndicatorsConfig() => IndicatorsConfig()
  ..rowStart = (RowIndicatorConfig()
    ..visible = false
    ..width = 35
    ..modeBits = _rowIndicatorModeBits([
      RowIndicatorMode.ROW_INDICATOR_CURRENT,
      RowIndicatorMode.ROW_INDICATOR_SELECTION,
    ]))
  ..colTop = (ColIndicatorConfig()
    ..visible = true
    ..bandRows = 1
    ..modeBits = _colIndicatorModeBits([
      ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT,
      ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH,
    ]));

/// Supported rendering backends.
enum RendererBackend {
  /// Automatic selection (prefers GPU if available).
  auto,

  /// Software rendering to a pixel buffer.
  cpu,

  /// Hardware-accelerated rendering.
  gpu,

  /// Explicit Vulkan hardware rendering (Android only).
  vulkan,

  /// Explicit OpenGL ES hardware rendering (Android only).
  gles,
}

/// Controller for a single VolvoxGrid instance.
///
/// Usage:
/// ```dart
/// final controller = VolvoxGridController();
/// await controller.create(rows: 101, cols: 6);
/// await controller.setCellText(0, 0, 'Header');
/// ```
class VolvoxGridController extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('io.github.ivere27.volvoxgrid');

  Int64 _gridId = Int64.ZERO;
  bool _disposed = false;

  int? _gpuTextureId;
  int? _gpuSurfaceHandle;
  String? _gpuBackend;

  /// The native grid handle. Zero until [create] completes.
  Int64 get gridId => _gridId;

  /// Whether the grid has been created successfully.
  bool get isCreated => _gridId != Int64.ZERO;

  /// Active GPU texture ID (if created via [createGpuTexture]).
  int? get gpuTextureId => _gpuTextureId;

  /// Active GPU native surface handle (if created via [createGpuTexture]).
  int? get gpuSurfaceHandle => _gpuSurfaceHandle;

  /// The backend string used for the active GPU texture ('gles' or 'vulkan').
  String? get gpuBackend => _gpuBackend;

  GridHandle get _handle => GridHandle()..id = _gridId;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Create a new native grid instance.
  ///
  /// [rows] and [cols] include the data body plus any true frozen panes.
  /// Column headers live in the top column-indicator band by default.
  /// [viewportWidth] and [viewportHeight] set the initial pixel dimensions.
  Future<void> create({
    int rows = 50,
    int cols = 10,
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
          ..cols = cols)
        ..indicators = _defaultIndicatorsConfig());
    final response = await VolvoxGridService.Create(req);
    _gridId = response.handle.id;
    notifyListeners();
  }

  /// Destroy the native grid and release resources.
  Future<void> destroyGrid() async {
    if (!isCreated) return;
    await VolvoxGridService.Destroy(_handle);
    _gridId = Int64.ZERO;
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      releaseGpuTexture(graceful: true).whenComplete(() => destroyGrid());
    }
    super.dispose();
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  Future<void> _configure(GridConfig config) async {
    await VolvoxGridService.Configure(ConfigureRequest()
      ..gridId = _gridId
      ..config = config);
    notifyListeners();
  }

  Future<GridConfig> _getConfig() {
    return VolvoxGridService.GetConfig(_handle);
  }

  SelectRequest _buildSelectRequest(
    int activeRow,
    int activeCol,
    Iterable<CellRange> ranges, {
    bool show = false,
  }) {
    return SelectRequest()
      ..gridId = _gridId
      ..activeRow = activeRow
      ..activeCol = activeCol
      ..ranges.addAll(ranges)
      ..show = show;
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
    return _buildSelectRequest(activeRow, activeCol, [range], show: show);
  }

  // ── Grid Dimensions ───────────────────────────────────────────────────────

  /// Get the total number of rows.
  Future<int> rowCount() async {
    final config = await _getConfig();
    return config.layout.rows;
  }

  /// Set the total number of rows.
  Future<void> setRowCount(int n) async {
    await _configure(GridConfig()..layout = (LayoutConfig()..rows = n));
  }

  /// Get the total number of columns.
  Future<int> colCount() async {
    final config = await _getConfig();
    return config.layout.cols;
  }

  /// Set the total number of columns.
  Future<void> setColCount(int n) async {
    await _configure(GridConfig()..layout = (LayoutConfig()..cols = n));
  }

  /// Show or hide the top column-indicator band used for headers.
  Future<void> setShowColumnHeaders(bool visible) async {
    final top = ColIndicatorConfig()..visible = visible;
    await _configure(
      GridConfig()..indicators = (IndicatorsConfig()..colTop = top),
    );
  }

  /// Set the top column-indicator content bitmask.
  Future<void> setColumnIndicatorTopModeBits(int modeBits) async {
    final top = ColIndicatorConfig()..modeBits = modeBits;
    await _configure(
      GridConfig()..indicators = (IndicatorsConfig()..colTop = top),
    );
  }

  /// Set the number of rows in the top column-indicator band.
  Future<void> setColumnIndicatorTopRowCount(int rows) async {
    final top = ColIndicatorConfig()..bandRows = rows < 0 ? 0 : rows;
    await _configure(
      GridConfig()..indicators = (IndicatorsConfig()..colTop = top),
    );
  }

  /// Show or hide the start-side row-indicator band.
  Future<void> setShowRowIndicator(bool visible) async {
    final row = RowIndicatorConfig()..visible = visible;
    await _configure(
      GridConfig()..indicators = (IndicatorsConfig()..rowStart = row),
    );
  }

  /// Set the start-side row-indicator content bitmask.
  Future<void> setRowIndicatorStartModeBits(int modeBits) async {
    final row = RowIndicatorConfig()..modeBits = modeBits;
    await _configure(
      GridConfig()..indicators = (IndicatorsConfig()..rowStart = row),
    );
  }

  /// Set the start-side row-indicator width.
  Future<void> setRowIndicatorStartWidth(int width) async {
    await _configure(
      GridConfig()
        ..indicators = (IndicatorsConfig()
          ..rowStart = (RowIndicatorConfig()..width = width < 1 ? 1 : width)),
    );
  }

  /// Get the number of frozen (non-scrollable data) rows below the header band.
  Future<int> frozenRowCount() async {
    final config = await _getConfig();
    return config.layout.frozenRows;
  }

  /// Set frozen (non-scrollable data) rows below the header band.
  Future<void> setFrozenRowCount(int n) async {
    await _configure(GridConfig()..layout = (LayoutConfig()..frozenRows = n));
  }

  /// Get the number of frozen (non-scrollable data) columns.
  Future<int> frozenColCount() async {
    final config = await _getConfig();
    return config.layout.frozenCols;
  }

  /// Set frozen (non-scrollable data) columns.
  Future<void> setFrozenColCount(int n) async {
    await _configure(GridConfig()..layout = (LayoutConfig()..frozenCols = n));
  }

  // ── Row / Column Sizing ───────────────────────────────────────────────────

  /// Set the height of a specific row in pixels.
  Future<void> setRowHeight(int row, int height) async {
    await VolvoxGridService.DefineRows(DefineRowsRequest()
      ..gridId = _gridId
      ..rows.add(RowDef()
        ..index = row
        ..height = height));
    notifyListeners();
  }

  /// Set the width of a specific column in pixels.
  Future<void> setColWidth(int col, int width) async {
    await VolvoxGridService.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..width = width));
    notifyListeners();
  }

  /// Set the caption shown in the top column-indicator band for a column.
  Future<void> setColumnCaption(int col, String caption) async {
    await VolvoxGridService.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..caption = caption));
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
    await VolvoxGridService.InsertRows(req);
    notifyListeners();
  }

  /// Remove [count] rows starting at [index].
  Future<void> removeRows(int index, {int count = 1}) async {
    await VolvoxGridService.RemoveRows(RemoveRowsRequest()
      ..gridId = _gridId
      ..index = index
      ..count = count);
    notifyListeners();
  }

  /// Move a column to a new [position].
  Future<void> moveColumn(int col, int position) async {
    await VolvoxGridService.MoveColumn(MoveColumnRequest()
      ..gridId = _gridId
      ..col = col
      ..position = position);
    notifyListeners();
  }

  /// Move a row to a new [position].
  Future<void> moveRow(int row, int position) async {
    await VolvoxGridService.MoveRow(MoveRowRequest()
      ..gridId = _gridId
      ..row = row
      ..position = position);
    notifyListeners();
  }

  // ── Cell Text ─────────────────────────────────────────────────────────────

  /// Set the text of a cell at the given [row] and [col].
  Future<void> setCellText(int row, int col, String text) async {
    await VolvoxGridService.UpdateCells(UpdateCellsRequest()
      ..gridId = _gridId
      ..cells.add(CellUpdate()
        ..row = row
        ..col = col
        ..value = (CellValue()..text = text)));
    notifyListeners();
  }

  /// Get the text of a cell at the given [row] and [col].
  Future<String> getCellText(int row, int col) async {
    final resp = await VolvoxGridService.GetCells(GetCellsRequest()
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
    await VolvoxGridService.UpdateCells(req);
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
        final currentRows = await rowCount();
        final currentCols = await colCount();
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

  /// Load a row-major typed matrix in one RPC.
  ///
  /// [values] should be `rows * cols` long in row-major order.
  Future<void> loadTable(
    int rows,
    int cols,
    List<CellValue> values, {
    bool atomic = false,
  }) async {
    await VolvoxGridService.LoadTable(LoadTableRequest()
      ..gridId = _gridId
      ..rows = rows
      ..cols = cols
      ..values.addAll(values)
      ..atomic = atomic);
    notifyListeners();
  }

  /// Clear content/formatting based on [scope] and [region].
  Future<void> clear({
    ClearScope scope = ClearScope.CLEAR_EVERYTHING,
    ClearRegion region = ClearRegion.CLEAR_SCROLLABLE,
  }) async {
    await VolvoxGridService.Clear(ClearRequest()
      ..gridId = _gridId
      ..scope = scope
      ..region = region);
    notifyListeners();
  }

  // ── Cursor & Selection ────────────────────────────────────────────────────

  /// Move the active cursor to the given row.
  Future<void> setCursorRow(int row) async {
    int targetCol;
    try {
      targetCol = (await VolvoxGridService.GetSelection(_handle)).activeCol;
    } catch (_) {
      targetCol = 0;
    }
    await VolvoxGridService.Select(
      _buildSingleRangeSelectRequest(row, targetCol,
          rowEnd: row, colEnd: targetCol),
    );
    notifyListeners();
  }

  /// Move the active cursor to the given column.
  Future<void> setCursorCol(int col) async {
    int targetRow;
    try {
      targetRow = (await VolvoxGridService.GetSelection(_handle)).activeRow;
    } catch (_) {
      targetRow = 0;
    }
    await VolvoxGridService.Select(
      _buildSingleRangeSelectRequest(targetRow, col,
          rowEnd: targetRow, colEnd: col),
    );
    notifyListeners();
  }

  /// Get the current cursor row.
  Future<int> cursorRow() async {
    final sel = await VolvoxGridService.GetSelection(_handle);
    return sel.activeRow;
  }

  /// Get the current cursor column.
  Future<int> cursorCol() async {
    final sel = await VolvoxGridService.GetSelection(_handle);
    return sel.activeCol;
  }

  /// Select a rectangular range of cells.
  Future<void> selectRange(
      int rowStart, int colStart, int rowEnd, int colEnd) async {
    await VolvoxGridService.Select(_buildSingleRangeSelectRequest(
      rowStart,
      colStart,
      rowEnd: rowEnd,
      colEnd: colEnd,
    ));
    notifyListeners();
  }

  /// Select multiple rectangular ranges.
  Future<void> selectRanges(
    Iterable<CellRange> ranges, {
    int? activeRow,
    int? activeCol,
    bool show = false,
  }) async {
    final normalized = ranges
        .map((range) => CellRange()
          ..row1 = range.row1 < range.row2 ? range.row1 : range.row2
          ..col1 = range.col1 < range.col2 ? range.col1 : range.col2
          ..row2 = range.row1 > range.row2 ? range.row1 : range.row2
          ..col2 = range.col1 > range.col2 ? range.col1 : range.col2)
        .toList(growable: false);
    if (normalized.isEmpty) return;
    await VolvoxGridService.Select(_buildSelectRequest(
      activeRow ?? normalized.first.row1,
      activeCol ?? normalized.first.col1,
      normalized,
      show: show,
    ));
    notifyListeners();
  }

  /// Get the current selection state, including all returned ranges.
  Future<SelectionState> getSelection() async {
    return VolvoxGridService.GetSelection(_handle);
  }

  /// Clear the current selection.
  Future<void> clearSelection() async {
    final sel = await VolvoxGridService.GetSelection(_handle);
    await VolvoxGridService.Select(_buildSingleRangeSelectRequest(
      sel.activeRow,
      sel.activeCol,
      rowEnd: sel.activeRow,
      colEnd: sel.activeCol,
    ));
    notifyListeners();
  }

  /// Set the selection mode (free, by-row, by-column, listbox).
  Future<void> setSelectionMode(SelectionMode mode) async {
    await _configure(
        GridConfig()..selection = (SelectionConfig()..mode = mode));
  }

  /// Set the selection visibility style.
  Future<void> setSelectionVisibility(SelectionVisibility style) async {
    await _configure(
        GridConfig()..selection = (SelectionConfig()..visibility = style));
  }

  /// Scroll the grid so that the specified cell is visible.
  Future<void> showCell(int row, int col) async {
    await VolvoxGridService.ShowCell(
      ShowCellRequest()
        ..gridId = _gridId
        ..row = row
        ..col = col,
    );
  }

  /// Set the topmost visible scrollable row.
  Future<void> setTopRow(int row) async {
    await VolvoxGridService.SetTopRow(
      SetRowRequest()
        ..gridId = _gridId
        ..row = row,
    );
  }

  /// Get the topmost visible scrollable row.
  Future<int> topRow() async {
    final sel = await VolvoxGridService.GetSelection(_handle);
    return sel.topRow;
  }

  /// Set the leftmost visible scrollable column.
  Future<void> setLeftCol(int col) async {
    await VolvoxGridService.SetLeftCol(
      SetColRequest()
        ..gridId = _gridId
        ..col = col,
    );
  }

  /// Get the leftmost visible scrollable column.
  Future<int> leftCol() async {
    final sel = await VolvoxGridService.GetSelection(_handle);
    return sel.leftCol;
  }

  // ── Sorting ───────────────────────────────────────────────────────────────

  /// Sort the grid by one or more columns.
  ///
  /// Single-column: `sort(SortOrder.SORT_ASCENDING, col: 0)`
  /// Multi-column:  `sortMulti([(0, SortOrder.SORT_ASCENDING), (2, SortOrder.SORT_DESCENDING)])`
  Future<void> sort(SortOrder order, {int col = -1}) async {
    await VolvoxGridService.Sort(SortRequest()
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
    await VolvoxGridService.Sort(req);
    notifyListeners();
  }

  /// Configure header features (sort/reorder/chooser behavior).
  Future<void> setHeaderFeatures(HeaderFeatures features) async {
    await _configure(GridConfig()
      ..interaction = (InteractionConfig()..headerFeatures = features));
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
    await VolvoxGridService.Subtotal(SubtotalRequest()
      ..gridId = _gridId
      ..aggregate = aggregate
      ..groupOnCol = groupOnCol
      ..aggregateCol = aggregateCol
      ..caption = caption
      ..background = backColor
      ..foreground = foreColor
      ..addOutline = addOutline);
    notifyListeners();
  }

  // ── Outline ───────────────────────────────────────────────────────────────

  /// Set the tree indicator display mode.
  Future<void> setTreeIndicator(TreeIndicatorStyle style) async {
    await _configure(
        GridConfig()..outline = (OutlineConfig()..treeIndicator = style));
  }

  /// Set the outline level for a specific row.
  Future<void> setRowOutlineLevel(int row, int level) async {
    await VolvoxGridService.DefineRows(DefineRowsRequest()
      ..gridId = _gridId
      ..rows.add(RowDef()
        ..index = row
        ..outlineLevel = level));
  }

  /// Expand/collapse rows to the requested [level].
  Future<void> outline(int level) async {
    await VolvoxGridService.Outline(OutlineRequest()
      ..gridId = _gridId
      ..level = level);
    notifyListeners();
  }

  /// Mark a row as a subtotal node (shows +/- expand/collapse button).
  Future<void> setIsSubtotal(int row, bool isSubtotal) async {
    await VolvoxGridService.DefineRows(DefineRowsRequest()
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
    return VolvoxGridService.GetNode(req);
  }

  // ── Span ─────────────────────────────────────────────────────────────────

  /// Set the cell span mode.
  Future<void> setCellSpanMode(CellSpanMode mode) async {
    await _configure(GridConfig()..span = (SpanConfig()..cellSpan = mode));
  }

  /// Enable or disable spanning for a specific column.
  Future<void> setSpanCol(int col, bool span) async {
    await VolvoxGridService.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..span = span));
    notifyListeners();
  }

  /// Enable or disable spanning for a specific row.
  Future<void> setSpanRow(int row, bool span) async {
    await VolvoxGridService.DefineRows(DefineRowsRequest()
      ..gridId = _gridId
      ..rows.add(RowDef()
        ..index = row
        ..span = span));
    notifyListeners();
  }

  // ── Column Combo Lists ──────────────────────────────────────────────────

  /// Set the dropdown items for a column (pipe-delimited, e.g. "A|B|C").
  Future<void> setColDropdownItems(int col, String items) async {
    await VolvoxGridService.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..dropdownItems = items));
  }

  /// Set dropdown items for an individual cell.
  Future<void> setCellDropdownItems(int row, int col, String items) async {
    await VolvoxGridService.UpdateCells(UpdateCellsRequest()
      ..gridId = _gridId
      ..cells.add(CellUpdate()
        ..row = row
        ..col = col
        ..dropdownItems = items));
    notifyListeners();
  }

  // ── Editing ───────────────────────────────────────────────────────────────

  /// Get whether editing is enabled.
  Future<bool> editable() async {
    return await editTrigger() != EditTrigger.EDIT_TRIGGER_NONE;
  }

  /// Enable or disable editing.
  Future<void> setEditable(bool enabled) async {
    final current = await editTrigger();
    final target = enabled
        ? (current == EditTrigger.EDIT_TRIGGER_NONE
            ? EditTrigger.EDIT_TRIGGER_KEY_CLICK
            : current)
        : EditTrigger.EDIT_TRIGGER_NONE;
    await setEditTrigger(target);
  }

  /// Get the edit trigger mode for the grid.
  Future<EditTrigger> editTrigger() async {
    final config = await _getConfig();
    if (!config.hasEditing()) {
      return EditTrigger.EDIT_TRIGGER_NONE;
    }
    return config.editing.trigger;
  }

  /// Set the edit trigger mode for the grid.
  Future<void> setEditTrigger(EditTrigger mode) async {
    await _configure(GridConfig()..editing = (EditConfig()..trigger = mode));
  }

  /// Begin editing the given cell.
  Future<void> beginEdit(
    int row,
    int col, {
    bool? selectAll,
    bool? caretEnd,
    String? seedText,
    bool? formulaMode,
  }) async {
    final start = EditStart()
      ..row = row
      ..col = col;
    if (selectAll != null) {
      start.selectAll = selectAll;
    }
    if (caretEnd != null) {
      start.caretEnd = caretEnd;
    }
    if (seedText != null) {
      start.seedText = seedText;
    }
    if (formulaMode != null) {
      start.formulaMode = formulaMode;
    }
    await VolvoxGridService.Edit(EditCommand()
      ..gridId = _gridId
      ..start = start);
    notifyListeners();
  }

  /// Commit or cancel the current cell edit.
  Future<void> commitEdit(String text, {bool cancel = false}) async {
    if (cancel) {
      await VolvoxGridService.Edit(EditCommand()
        ..gridId = _gridId
        ..cancel = EditCancel());
    } else {
      await VolvoxGridService.Edit(EditCommand()
        ..gridId = _gridId
        ..commit = (EditCommit()..text = text));
    }
    notifyListeners();
  }

  /// Cancel the current cell edit.
  Future<void> cancelEdit() async {
    await VolvoxGridService.Edit(EditCommand()
      ..gridId = _gridId
      ..cancel = EditCancel());
    notifyListeners();
  }

  // ── Column Formatting ─────────────────────────────────────────────────────

  /// Set the data type for a column (string, number, date, etc.).
  Future<void> setColDataType(int col, ColumnDataType dataType) async {
    await VolvoxGridService.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..dataType = dataType));
  }

  /// Set the text alignment for a column.
  Future<void> setColAlignment(int col, Align alignment) async {
    await VolvoxGridService.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..align = alignment));
  }

  /// Set the format string for a column (e.g. '#,##0.00' for currency).
  Future<void> setColFormat(int col, String format) async {
    await VolvoxGridService.DefineColumns(DefineColumnsRequest()
      ..gridId = _gridId
      ..columns.add(ColumnDef()
        ..index = col
        ..format = format));
  }

  /// Get the active custom render mode.
  Future<CustomRenderMode> customRenderMode() async {
    final config = await _getConfig();
    return config.style.customRender;
  }

  /// Enable native custom-render mode.
  Future<void> setCustomRenderMode(CustomRenderMode mode) async {
    await _configure(
        GridConfig()..style = (StyleConfig()..customRender = mode));
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
    CellStyle style,
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
    await VolvoxGridService.UpdateCells(req);
    notifyListeners();
  }

  // ── User Interaction ──────────────────────────────────────────────────────

  /// Configure row/column resizing behavior.
  Future<void> setResizePolicy(ResizePolicy policy) async {
    await _configure(
        GridConfig()..interaction = (InteractionConfig()..resize = policy));
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
    await VolvoxGridService.AutoSize(AutoSizeRequest()
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
    await VolvoxGridService.ResizeViewport(ResizeViewportRequest()
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
    return VolvoxGridService.Export(ExportRequest()
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
    await VolvoxGridService.Import(ImportRequest()
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
    return VolvoxGridService.Print(PrintRequest()
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
    return VolvoxGridService.Archive(req);
  }

  // ── Clipboard ──────────────────────────────────────────────────────────────

  /// Copy current selection to clipboard payload.
  Future<ClipboardResponse> copy() async {
    return VolvoxGridService.Clipboard(ClipboardCommand()
      ..gridId = _gridId
      ..copy = ClipboardCopy());
  }

  /// Cut current selection to clipboard payload.
  Future<ClipboardResponse> cut() async {
    final data = await VolvoxGridService.Clipboard(ClipboardCommand()
      ..gridId = _gridId
      ..cut = ClipboardCut());
    notifyListeners();
    return data;
  }

  /// Paste provided clipboard text into current selection.
  Future<void> paste(String text) async {
    await VolvoxGridService.Clipboard(ClipboardCommand()
      ..gridId = _gridId
      ..paste = (ClipboardPaste()..text = text));
    notifyListeners();
  }

  /// Delete current selection contents.
  Future<void> deleteSelection() async {
    await VolvoxGridService.Clipboard(ClipboardCommand()
      ..gridId = _gridId
      ..delete = ClipboardDelete());
    notifyListeners();
  }

  // ── Pin & Sticky ──────────────────────────────────────────────────────────

  /// Pin a row to top or bottom, or unpin it.
  Future<void> pinRow(int row, PinPosition pin) async {
    await VolvoxGridService.DefineRows(DefineRowsRequest()
      ..gridId = _gridId
      ..rows.add(RowDef()
        ..index = row
        ..pin = pin));
    notifyListeners();
  }

  /// Set sticky edge for a row.
  Future<void> setRowSticky(int row, StickyEdge edge) async {
    await VolvoxGridService.DefineRows(DefineRowsRequest()
      ..gridId = _gridId
      ..rows.add(RowDef()
        ..index = row
        ..sticky = edge));
    notifyListeners();
  }

  /// Set sticky edge for a column.
  Future<void> setColSticky(int col, StickyEdge edge) async {
    await VolvoxGridService.DefineColumns(DefineColumnsRequest()
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
    final resp = await VolvoxGridService.Find(FindRequest()
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
    final resp = await VolvoxGridService.Find(FindRequest()
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
    final resp = await VolvoxGridService.Aggregate(AggregateRequest()
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
    return VolvoxGridService.GetMergedRange(GetMergedRangeRequest()
      ..gridId = _gridId
      ..row = row
      ..col = col);
  }

  /// Merge cells in the given range.
  Future<void> mergeCells(int row1, int col1, int row2, int col2) async {
    await VolvoxGridService.MergeCells(MergeCellsRequest()
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
    await VolvoxGridService.UnmergeCells(UnmergeCellsRequest()
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
    return VolvoxGridService.GetMergedRegions(GridHandle()..id = _gridId);
  }

  // ── Render Session ────────────────────────────────────────────────────────

  /// Open a bidirectional render session.
  Stream<RenderOutput> renderSession(Stream<RenderInput> inputs) {
    return VolvoxGridService.RenderSession(inputs);
  }

  // ── Event Stream ──────────────────────────────────────────────────────────

  /// Subscribe to native grid events (selection changes, edits, etc.).
  Stream<GridEvent> eventStream() {
    return VolvoxGridService.EventStream(_handle);
  }

  // ── Demo ─────────────────────────────────────────────────────────────────

  /// Load a built-in engine demo ("sales", "hierarchy", or "stress").
  Future<void> loadDemo(String demo) async {
    await VolvoxGridService.LoadDemo(LoadDemoRequest()
      ..gridId = _gridId
      ..demo = demo);
    notifyListeners();
  }

  // ── Redraw Control ────────────────────────────────────────────────────────

  /// Suspend or resume native redraw.
  Future<void> setRedraw(bool enabled) async {
    await VolvoxGridService.SetRedraw(SetRedrawRequest()
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

  /// Enable or disable scroll blitting during panning/scrolling.
  Future<void> setScrollBlit(bool enabled) async {
    await _configure(
        GridConfig()..rendering = (RenderConfig()..scrollBlit = enabled));
  }

  /// Set the render layer visibility bitmask.
  ///
  /// Each bit corresponds to a [RenderLayerBit] position.
  /// Pass `Int64(-1)` (all bits set) to show all layers.
  Future<void> setRenderLayerMask(Int64 mask) async {
    await _configure(
        GridConfig()..rendering = (RenderConfig()..renderLayerMask = mask));
  }

  /// Set the text layout cache capacity (0 = disabled).
  Future<void> setTextLayoutCacheCap(int cap) async {
    final safeCap = cap < 0 ? 0 : cap;
    await _configure(GridConfig()
      ..rendering = (RenderConfig()..textLayoutCacheCap = safeCap));
  }

  /// Get whether layout animation is enabled.
  Future<bool> animationEnabled() async {
    final config = await _getConfig();
    return config.rendering.animationEnabled;
  }

  /// Get whether scroll blitting is enabled.
  Future<bool> scrollBlitEnabled() async {
    final config = await _getConfig();
    return config.rendering.scrollBlit;
  }

  /// Get text layout cache capacity.
  Future<int> textLayoutCacheCap() async {
    final config = await _getConfig();
    return config.rendering.textLayoutCacheCap;
  }

  /// Set renderer mode: 0=AUTO, 1=CPU, 2=GPU, 3=Vulkan, 4=GLES.
  Future<void> setRendererMode(int mode) async {
    await _configure(GridConfig()
      ..rendering = (RenderConfig()
        ..rendererMode =
            (RendererMode.valueOf(mode) ?? RendererMode.RENDERER_AUTO)));
  }

  /// Get the current renderer mode (0=AUTO, 1=CPU, 2=GPU).
  Future<int> rendererMode() async {
    final config = await _getConfig();
    return config.rendering.rendererMode.value;
  }

  /// Set the presentation mode: 0=Auto, 1=Fifo (vsync), 2=Mailbox, 3=Immediate.
  Future<void> setPresentMode(int mode) async {
    await _configure(GridConfig()
      ..rendering = (RenderConfig()
        ..presentMode =
            (PresentMode.valueOf(mode) ?? PresentMode.PRESENT_AUTO)));
  }

  /// Get the current presentation mode (0=Auto, 1=Fifo, 2=Mailbox, 3=Immediate).
  Future<int> presentMode() async {
    final config = await _getConfig();
    return config.rendering.presentMode.value;
  }

  /// Set the preferred renderer backend.
  ///
  /// On Android, this automatically manages the native GPU texture surface
  /// when switching between CPU and hardware-accelerated modes.
  Future<void> setRendererBackend(RendererBackend backend) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (backend == RendererBackend.cpu) {
        // Move engine to CPU mode before releasing the native GPU surface.
        // This avoids a transition window where pending GPU work can touch
        // an already-released ANativeWindow.
        await setRendererMode(backend.index);
        await releaseGpuTexture(graceful: true);
        return;
      }

      try {
        // For any GPU mode transition, drop the old surface first so no frame
        // is rendered against an incompatible surface/backend pair.
        await releaseGpuTexture(graceful: true);

        if (backend == RendererBackend.vulkan) {
          await setRendererMode(RendererBackend.vulkan.index);
          await createGpuTexture(backend: 'vulkan');
        } else {
          // Bootstrap through explicit GLES so AUTO/GPU never inherit a stale
          // Vulkan renderer after a mode transition.
          await setRendererMode(RendererBackend.gles.index);
          await createGpuTexture(backend: 'gles');
          if (backend != RendererBackend.gles) {
            await setRendererMode(backend.index);
          }
        }

        // Ensure the newly attached GPU surface gets a fresh frame even when
        // the grid was previously clean (not dirty).
        if (isCreated) {
          await refresh();
        }
      } catch (_) {
        // A failed Android GPU transition must not leave the engine claiming a
        // GPU backend without a valid native window/texture.
        try {
          await releaseGpuTexture(graceful: false);
        } catch (_) {}
        try {
          await setRendererMode(RendererBackend.cpu.index);
          if (isCreated) {
            await refresh();
          }
        } catch (_) {}
        rethrow;
      }
      return;
    }
    await setRendererMode(backend.index);
  }

  /// Get the current renderer backend.
  Future<RendererBackend> rendererBackend() async {
    final modeValue = await rendererMode();
    if (modeValue >= 0 && modeValue < RendererBackend.values.length) {
      return RendererBackend.values[modeValue];
    }
    return RendererBackend.auto; // AUTO = 0
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
    await VolvoxGridService.Refresh(_handle);
    notifyListeners();
  }

  /// (Android only) Create a native GPU texture for zero-copy rendering.
  Future<int?> createGpuTexture({
    String backend = 'gles',
    int width = 1,
    int height = 1,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    await releaseGpuTexture(graceful: true);
    final Map<dynamic, dynamic>? res = await _channel.invokeMethod(
      'createTexture',
      <String, Object>{
        'backend': backend,
        'width': width < 1 ? 1 : width,
        'height': height < 1 ? 1 : height,
      },
    );
    if (res != null) {
      final textureId = res['textureId'] as int?;
      final surfaceHandle = res['surfaceHandle'] as int?;
      if (textureId == null || surfaceHandle == null || surfaceHandle == 0) {
        if (textureId != null) {
          try {
            await _channel
                .invokeMethod('releaseTexture', {'textureId': textureId});
          } catch (_) {
            // Best effort cleanup only.
          }
        }
        throw PlatformException(
          code: 'NATIVE_WINDOW_ERROR',
          message: 'Failed to acquire native window',
        );
      }
      _gpuTextureId = textureId;
      _gpuSurfaceHandle = surfaceHandle;
      _gpuBackend = backend;
      notifyListeners();
    }
    return _gpuTextureId;
  }

  /// (Android only) Update the GPU texture size.
  Future<void> setGpuTextureSize(int width, int height) async {
    if (_gpuTextureId != null) {
      await _channel.invokeMethod('setTextureSize', {
        'textureId': _gpuTextureId,
        'width': width,
        'height': height,
      });
    }
  }

  /// (Android only) Release the native GPU texture.
  Future<void> releaseGpuTexture({bool graceful = false}) async {
    final textureId = _gpuTextureId;
    if (textureId == null) {
      return;
    }

    if (graceful && _gpuSurfaceHandle != null && _gpuSurfaceHandle != 0) {
      // Ask the render stream to drop the current GPU surface before we tear
      // down the platform texture to avoid transient BufferQueue/Vulkan errors.
      _gpuSurfaceHandle = 0;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    _gpuTextureId = null;
    _gpuSurfaceHandle = null;
    // Do not clear _gpuBackend so _onResume can know what backend to restore.
    notifyListeners();

    try {
      await _channel.invokeMethod('releaseTexture', {'textureId': textureId});
    } catch (_) {
      // Best effort; local controller state is already detached.
    }
  }
}
