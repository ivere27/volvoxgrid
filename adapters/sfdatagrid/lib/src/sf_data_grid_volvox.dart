import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError, kIsWeb;
import 'package:flutter/material.dart' hide SelectionChangedCallback;
import 'package:flutter/services.dart' show rootBundle;
import 'package:fixnum/fixnum.dart' show Int64;
import 'package:volvoxgrid/volvoxgrid.dart' show VolvoxGridWidget;
import 'package:volvoxgrid/volvoxgrid_controller.dart';
import 'package:volvoxgrid/volvoxgrid_ffi.dart' as vg;

import 'data_source_bridge.dart';
import 'event_mapper.dart';
import 'grid_column_mapper.dart';
import 'selection_mapper.dart';
import 'sort_mapper.dart';
import 'style_mapper.dart';
import 'types.dart';

class SfDataGridVolvox extends StatefulWidget {
  final DataGridSource source;
  final List<GridColumn> columns;

  final SelectionMode selectionMode;

  final int frozenColumnsCount;
  final int frozenRowsCount;
  final int footerFrozenColumnsCount;
  final int footerFrozenRowsCount;

  final bool allowSorting;
  final bool allowColumnsResizing;

  final GridLinesVisibility gridLinesVisibility;
  final double rowHeight;
  final double headerRowHeight;
  final double defaultColumnWidth;

  final SelectionChangingCallback? onSelectionChanging;
  final SelectionChangedCallback? onSelectionChanged;
  final CellTapCallback? onCellTap;
  final ColumnResizeStartCallback? onColumnResizeStart;
  final ColumnResizeUpdateCallback? onColumnResizeUpdate;

  final VolvoxGridController? controller;

  const SfDataGridVolvox({
    required this.source,
    required this.columns,
    this.selectionMode = SelectionMode.none,
    this.frozenColumnsCount = 0,
    this.frozenRowsCount = 0,
    this.footerFrozenColumnsCount = 0,
    this.footerFrozenRowsCount = 0,
    this.allowSorting = false,
    this.allowColumnsResizing = false,
    this.gridLinesVisibility = GridLinesVisibility.both,
    this.rowHeight = 32,
    this.headerRowHeight = 36,
    this.defaultColumnWidth = double.nan,
    this.onSelectionChanging,
    this.onSelectionChanged,
    this.onCellTap,
    this.onColumnResizeStart,
    this.onColumnResizeUpdate,
    this.controller,
    super.key,
  });

  @override
  State<SfDataGridVolvox> createState() => _SfDataGridVolvoxState();
}

class _SfDataGridVolvoxState extends State<SfDataGridVolvox> {
  static const String _materialIconsFontName = 'Material Icons';
  static const List<String> _materialIconsFontNames = <String>[
    'Material Icons',
    'MaterialIcons',
  ];
  static const List<String> _materialIconsAssetCandidates = <String>[
    'packages/flutter/fonts/MaterialIcons-Regular.otf',
    'fonts/MaterialIcons-Regular.otf',
  ];
  static Future<void>? _materialIconsLoadFuture;

  late VolvoxGridController _controller;
  late bool _ownsController;
  late SfDataGridEventMapper _eventMapper;

  bool _ready = false;
  int _reloadToken = 0;

  GridColumnMapping _columnMapping = const GridColumnMapping(
    columns: <MappedGridColumn>[],
    indexByName: <String, int>{},
  );
  List<DataGridRow> _shadowRows = <DataGridRow>[];

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
    widget.source.addListener(_onSourceChanged);
    _rebuildEventMapper();
    unawaited(_ensureReady());
  }

  @override
  void didUpdateWidget(covariant SfDataGridVolvox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.source != widget.source) {
      oldWidget.source.removeListener(_onSourceChanged);
      widget.source.addListener(_onSourceChanged);
    }

    if (oldWidget.controller != widget.controller) {
      _detachControllerIfOwned();
      _attachController(widget.controller);
      _ready = false;
    }

    if (oldWidget.onSelectionChanging != widget.onSelectionChanging ||
        oldWidget.onSelectionChanged != widget.onSelectionChanged ||
        oldWidget.onCellTap != widget.onCellTap ||
        oldWidget.onColumnResizeStart != widget.onColumnResizeStart ||
        oldWidget.onColumnResizeUpdate != widget.onColumnResizeUpdate ||
        oldWidget.source != widget.source ||
        oldWidget.columns != widget.columns) {
      _rebuildEventMapper();
    }

    if (oldWidget.source != widget.source ||
        oldWidget.columns != widget.columns ||
        oldWidget.selectionMode != widget.selectionMode ||
        oldWidget.frozenColumnsCount != widget.frozenColumnsCount ||
        oldWidget.frozenRowsCount != widget.frozenRowsCount ||
        oldWidget.footerFrozenColumnsCount != widget.footerFrozenColumnsCount ||
        oldWidget.footerFrozenRowsCount != widget.footerFrozenRowsCount ||
        oldWidget.allowSorting != widget.allowSorting ||
        oldWidget.allowColumnsResizing != widget.allowColumnsResizing ||
        oldWidget.gridLinesVisibility != widget.gridLinesVisibility ||
        oldWidget.rowHeight != widget.rowHeight ||
        oldWidget.headerRowHeight != widget.headerRowHeight ||
        oldWidget.defaultColumnWidth != widget.defaultColumnWidth) {
      unawaited(_reloadAll());
    }
  }

  @override
  void dispose() {
    widget.source.removeListener(_onSourceChanged);
    _detachControllerIfOwned();
    super.dispose();
  }

  void _attachController(VolvoxGridController? external) {
    if (external != null) {
      _controller = external;
      _ownsController = false;
      return;
    }
    _controller = VolvoxGridController();
    _ownsController = true;
  }

  void _detachControllerIfOwned() {
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _rebuildEventMapper() {
    _eventMapper = SfDataGridEventMapper(
      controller: _controller,
      getColumns: () => _columnMapping,
      getShadowRows: () => _shadowRows,
      getHeaderRows: () => 0,
      onSelectionChanging: widget.onSelectionChanging,
      onSelectionChanged: widget.onSelectionChanged,
      onCellTap: widget.onCellTap,
      onColumnResizeStart: widget.onColumnResizeStart,
      onColumnResizeUpdate: widget.onColumnResizeUpdate,
    );
  }

  void _onSourceChanged() {
    unawaited(_reloadAll());
  }

  Future<void> _ensureMaterialIconsFontLoaded() {
    _materialIconsLoadFuture ??= _loadMaterialIconsFontOnce();
    return _materialIconsLoadFuture!;
  }

  Future<void> _loadMaterialIconsFontOnce() async {
    for (final assetKey in _materialIconsAssetCandidates) {
      try {
        final byteData = await rootBundle.load(assetKey);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        if (bytes.isEmpty) {
          continue;
        }

        await vg.VolvoxGridServiceFfi.LoadFontData(
          vg.LoadFontDataRequest()
            ..data = bytes
            ..fontName = _materialIconsFontName
            ..fontNames.addAll(_materialIconsFontNames),
        );
        return;
      } on FlutterError {
        // Asset key does not exist in this Flutter build.
      } catch (_) {
        // Try the next candidate path.
      }
    }
  }

  Future<void> _ensureReady() async {
    if (!_controller.isCreated) {
      final cols = math.max(1, widget.columns.length);
      await _controller.create(rows: 1, cols: cols);
    }
    await _reloadAll();
  }

  Future<void> _reloadAll() async {
    if (!_controller.isCreated) {
      return;
    }

    if (widget.allowSorting) {
      await _ensureMaterialIconsFontLoaded();
    }

    final token = ++_reloadToken;
    _columnMapping = mapGridColumns(widget.columns);

    final matrix = buildDataSourceMatrix(
      source: widget.source,
      columns: _columnMapping,
    );

    _shadowRows = matrix.shadowRows;

    final totalCols = math.max(1, matrix.cols);
    final totalRows = math.max(1, matrix.rows);

    await _controller.setColCount(totalCols);
    await _controller.setRowCount(totalRows);
    await _controller.setShowColumnHeaders(true);
    await _controller.setColumnIndicatorTopRowCount(1);

    await _controller.setFrozenColCount(math.max(0, widget.frozenColumnsCount));
    await _controller.setFrozenRowCount(math.max(0, widget.frozenRowsCount));

    await _controller.setSelectionMode(mapSelectionMode(widget.selectionMode));
    await _controller.setSelectionVisibility(
      mapSelectionVisibility(widget.selectionMode),
    );

    await _controller.setHeaderFeatures(
      widget.allowSorting
          ? vg.HeaderFeatures.HEADER_SORT
          : vg.HeaderFeatures.HEADER_NONE,
    );

    await _controller.setAllowUserResizing(
      widget.allowColumnsResizing
          ? vg.AllowUserResizingMode.RESIZE_COLUMNS
          : vg.AllowUserResizingMode.RESIZE_NONE,
    );

    final platform = Theme.of(context).platform;
    final isDesktop = kIsWeb ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    final effectiveDefaultColumnWidth =
        widget.defaultColumnWidth.isFinite && widget.defaultColumnWidth > 0
            ? widget.defaultColumnWidth
            : (isDesktop ? 100.0 : 90.0);

    await applyStyleConfig(
      _controller,
      gridLinesVisibility: widget.gridLinesVisibility,
      allowSorting: widget.allowSorting,
      rowHeight: widget.rowHeight,
      headerRowHeight: widget.headerRowHeight,
      defaultColumnWidth: effectiveDefaultColumnWidth,
    );

    await applyGridColumns(
      _controller,
      _columnMapping,
      footerFrozenColumnsCount: math.max(0, widget.footerFrozenColumnsCount),
      allowSorting: widget.allowSorting,
      sortedColumns: widget.source.sortedColumns,
    );

    final values = List<vg.CellValue>.generate(totalRows * totalCols, (_) {
      return vg.CellValue();
    });

    for (var row = 0; row < matrix.rows; row += 1) {
      for (var col = 0; col < matrix.cols; col += 1) {
        final from = row * matrix.cols + col;
        final to = row * totalCols + col;
        values[to] = _toCellValue(matrix.values[from]);
      }
    }

    await _controller.loadTable(totalRows, totalCols, values);

    await _applyFooterFrozenRows();
    await _applySourceSort();
    await _eventMapper.syncSelectionSnapshot();

    if (!mounted || token != _reloadToken) {
      return;
    }

    setState(() {
      _ready = true;
    });
  }

  vg.CellValue _toCellValue(Object? value) {
    final cell = vg.CellValue();
    if (value == null) {
      return cell;
    }
    if (value is String) {
      cell.text = value;
      return cell;
    }
    if (value is bool) {
      cell.flag = value;
      return cell;
    }
    if (value is num) {
      cell.number = value.toDouble();
      return cell;
    }
    if (value is DateTime) {
      cell.timestamp = Int64(value.millisecondsSinceEpoch);
      return cell;
    }
    if (value is Uint8List) {
      cell.data = value;
      return cell;
    }
    cell.text = value.toString();
    return cell;
  }

  Future<void> _applyFooterFrozenRows() async {
    final footerCount = math.max(0, widget.footerFrozenRowsCount);
    final rowCount = _shadowRows.length;
    if (rowCount <= 0) {
      return;
    }

    final stickyStart = rowCount - footerCount;

    final request = vg.DefineRowsRequest()..gridId = _controller.gridId;

    for (var i = 0; i < rowCount; i += 1) {
      request.rows.add(
        vg.RowDef()
          ..index = 1 + i
          ..sticky = i >= stickyStart
              ? vg.StickyEdge.STICKY_BOTTOM
              : vg.StickyEdge.STICKY_NONE,
      );
    }

    await vg.VolvoxGridServiceFfi.DefineRows(request);
  }

  Future<void> _applySourceSort() async {
    if (!widget.allowSorting || widget.source.sortedColumns.isEmpty) {
      return;
    }
    final columns = <(int, vg.SortOrder)>[];
    for (final sort in widget.source.sortedColumns) {
      final colIndex = _columnMapping.indexByName[sort.name];
      if (colIndex == null) {
        continue;
      }
      final mapped = _columnMapping.columns[colIndex];
      if (!mapped.source.allowSorting) {
        continue;
      }
      columns.add((colIndex, mapSortDirection(sort.sortDirection)));
    }
    if (columns.isEmpty) {
      return;
    }
    await _controller.sortMulti(columns);
  }

  void _onGridEvent(vg.GridEvent event) {
    unawaited(_eventMapper.onGridEvent(event));
  }

  bool _onCancelableEvent(vg.GridEvent event) {
    return _eventMapper.onCancelableGridEvent(event);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SizedBox.expand();
    }

    return VolvoxGridWidget(
      controller: _controller,
      onGridEvent: _onGridEvent,
      onCancelableEvent: _onCancelableEvent,
    );
  }
}
