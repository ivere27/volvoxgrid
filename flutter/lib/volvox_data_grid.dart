/// Data-first VolvoxGrid widget for Flutter.
///
/// `VolvoxDataGrid<T>` wraps `VolvoxGridController` and `VolvoxGridWidget`
/// behind a typed-row, typed-column API that does not require any generated
/// protobuf objects in the calling code.
///
/// ```dart
/// import 'package:volvoxgrid/volvoxgrid.dart';
///
/// VolvoxDataGrid<Product>(
///   rows: products,
///   columns: [
///     VolvoxColumn(field: 'name', header: 'Name', value: (p) => p.name),
///     VolvoxColumn(
///       field: 'price',
///       header: 'Price',
///       value: (p) => p.price.toStringAsFixed(2),
///       editable: true,
///     ),
///   ],
///   onCellEdit: (edit) {
///     setState(() {
///       products[edit.rowIndex] = products[edit.rowIndex].copyWith(
///         price: double.tryParse(edit.newText) ?? products[edit.rowIndex].price,
///       );
///     });
///   },
/// );
/// ```
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'volvoxgrid.dart'
    show VolvoxGridBeforeEditDetails, VolvoxGridWidget;
import 'volvoxgrid_controller.dart';
import 'src/generated/volvoxgrid.pb.dart' as pb;

/// Typed column definition for [VolvoxDataGrid].
@immutable
class VolvoxColumn<T> {
  /// Stable identifier for this column. Surfaced as [VolvoxCellEdit.field].
  final String field;

  /// Header caption shown in the engine column-header band.
  final String header;

  /// Read the cell value for [row]. The returned string is what the engine
  /// renders.
  final String Function(T row) value;

  /// When true, the engine accepts edits on this column and committed values
  /// surface via [VolvoxDataGrid.onCellEdit]. When false, the column is
  /// read-only — the grid cancels edits before they start.
  final bool editable;

  const VolvoxColumn({
    required this.field,
    required this.header,
    required this.value,
    this.editable = false,
  });
}

/// Cell-edit details surfaced by [VolvoxDataGrid.onCellEdit].
@immutable
class VolvoxCellEdit<T> {
  /// Index of the edited row in [VolvoxDataGrid.rows].
  final int rowIndex;

  /// The row value at [rowIndex] before the edit.
  final T row;

  /// Index of the edited column in [VolvoxDataGrid.columns].
  final int columnIndex;

  /// Field identifier from [VolvoxColumn.field] of the edited column.
  final String field;

  /// Cell text before the edit.
  final String oldText;

  /// Cell text entered by the user.
  final String newText;

  const VolvoxCellEdit({
    required this.rowIndex,
    required this.row,
    required this.columnIndex,
    required this.field,
    required this.oldText,
    required this.newText,
  });
}

/// Data-first VolvoxGrid widget. Pass typed [rows] and [columns]; the widget
/// owns the controller lifecycle and pushes the values into the engine.
///
/// To replace the visible data, pass a new list reference (e.g. via
/// `setState`). Mutating the same list in place will not trigger a reload —
/// this matches the convention used by Flutter's other data widgets.
class VolvoxDataGrid<T> extends StatefulWidget {
  /// Rows to display. Treat as read-only from the widget's perspective.
  final List<T> rows;

  /// Column definitions controlling layout and data access.
  final List<VolvoxColumn<T>> columns;

  /// Called after the user commits an edit on an [VolvoxColumn.editable]
  /// column. The grid will redraw the new text immediately; mutate the
  /// underlying row in this callback to keep your own data in sync.
  final ValueChanged<VolvoxCellEdit<T>>? onCellEdit;

  /// Optional pre-existing controller. When null, the widget creates and
  /// disposes its own controller.
  final VolvoxGridController? controller;

  const VolvoxDataGrid({
    required this.rows,
    required this.columns,
    this.onCellEdit,
    this.controller,
    super.key,
  });

  @override
  State<VolvoxDataGrid<T>> createState() => _VolvoxDataGridState<T>();
}

class _VolvoxDataGridState<T> extends State<VolvoxDataGrid<T>> {
  late VolvoxGridController _controller;
  bool _ownController = false;

  // Track the references we last applied so didUpdateWidget can skip redundant
  // reloads when the parent rebuilds with the same lists.
  List<T>? _appliedRows;
  List<VolvoxColumn<T>>? _appliedColumns;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? VolvoxGridController();
    _ownController = widget.controller == null;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final rowCount = widget.rows.length;
    final colCount = widget.columns.length;
    if (!_controller.isCreated) {
      await _controller.create(rows: rowCount, cols: colCount);
    } else {
      await _controller.setRowCount(rowCount);
      await _controller.setColCount(colCount);
    }
    await _applyColumnsAndRows();
  }

  Future<void> _applyColumnsAndRows() async {
    for (var i = 0; i < widget.columns.length; i++) {
      await _controller.setColumnCaption(i, widget.columns[i].header);
    }
    final cells = <CellTextEntry>[];
    for (var r = 0; r < widget.rows.length; r++) {
      final row = widget.rows[r];
      for (var c = 0; c < widget.columns.length; c++) {
        cells.add(CellTextEntry(
          row: r,
          col: c,
          text: widget.columns[c].value(row),
        ));
      }
    }
    if (cells.isNotEmpty) {
      await _controller.setCells(cells);
    }
    _appliedRows = widget.rows;
    _appliedColumns = widget.columns;
  }

  @override
  void didUpdateWidget(covariant VolvoxDataGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rowsChanged = !identical(_appliedRows, widget.rows);
    final colsChanged = !identical(_appliedColumns, widget.columns);
    if (rowsChanged || colsChanged) {
      unawaited(_reload());
    }
  }

  Future<void> _reload() async {
    if (!_controller.isCreated) {
      return _bootstrap();
    }
    await _controller.setRowCount(widget.rows.length);
    await _controller.setColCount(widget.columns.length);
    await _applyColumnsAndRows();
  }

  void _onBeforeEdit(VolvoxGridBeforeEditDetails details) {
    if (details.col < 0 || details.col >= widget.columns.length) return;
    if (!widget.columns[details.col].editable) {
      details.cancel = true;
    }
  }

  void _onGridEvent(pb.GridEvent event) {
    final cb = widget.onCellEdit;
    if (cb == null) return;
    if (!event.hasAfterEdit()) return;
    final after = event.afterEdit;
    if (after.row < 0 || after.row >= widget.rows.length) return;
    if (after.col < 0 || after.col >= widget.columns.length) return;
    final col = widget.columns[after.col];
    if (!col.editable) return;
    cb(VolvoxCellEdit<T>(
      rowIndex: after.row,
      row: widget.rows[after.row],
      columnIndex: after.col,
      field: col.field,
      oldText: after.oldText,
      newText: after.newText,
    ));
  }

  @override
  void dispose() {
    if (_ownController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VolvoxGridWidget(
      controller: _controller,
      onGridEvent: _onGridEvent,
      onBeforeEdit: _onBeforeEdit,
    );
  }
}
