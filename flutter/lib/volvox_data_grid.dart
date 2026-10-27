/// Data binding for the native grid. Engine coordinates are never source indices.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'volvoxgrid.dart'
    show
        VolvoxGridBeforeEditDetails,
        VolvoxGridCellEditValidatingDetails,
        VolvoxGridWidget;
import 'volvoxgrid_controller.dart';
import 'src/generated/volvoxgrid.pb.dart' as pb;

/// Storage and sorting policy. No type inference is performed on strings.
enum VolvoxColumnType {
  text,

  /// Canonical signed integer text, retained exactly (including beyond 2^53).
  integer,

  /// Canonical decimal text, retained exactly; no currency symbols/grouping.
  decimal,

  /// IEEE-754 double. Use only when approximate numeric storage is intended.
  number,
  boolean,
}

/// A column's [field] is its identity, including after drag reordering.
@immutable
class VolvoxColumn<T> {
  final String field;
  final String header;

  /// Canonical cell text. Exact integers/decimals are never converted to double.
  final String Function(T row) value;
  final bool editable;
  final VolvoxColumnType type;

  /// Engine display format for text/number/boolean. Exact numeric types must
  /// remain unformatted because the native format engine uses floating point.
  final String? format;

  /// Width in Flutter logical pixels, converted to native physical pixels.
  /// Changing an explicit width to null restores the grid's default width.
  final int? width;

  /// Optional native editor specification. Exact numeric columns require a
  /// text editor to retain precision; the default is a host inline text editor.
  final pb.EditorSpec? editor;

  const VolvoxColumn({
    required this.field,
    required this.header,
    required this.value,
    this.editable = false,
    this.type = VolvoxColumnType.text,
    this.format,
    this.width,
    this.editor,
  });

  bool _sameConfiguration(VolvoxColumn<T> other) =>
      field == other.field &&
      header == other.header &&
      editable == other.editable &&
      type == other.type &&
      format == other.format &&
      width == other.width &&
      editor == other.editor;

  bool get _exact =>
      type == VolvoxColumnType.integer || type == VolvoxColumnType.decimal;

  String? _validate(String text) {
    if (type == VolvoxColumnType.integer &&
        !RegExp(r'^[+-]?\d+$').hasMatch(text)) return 'Expected an integer';
    if (type == VolvoxColumnType.decimal &&
        !RegExp(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$').hasMatch(text)) {
      return 'Expected a decimal';
    }
    if (type == VolvoxColumnType.number &&
        !(double.tryParse(text)?.isFinite ?? false))
      return 'Expected a finite number';
    if (type == VolvoxColumnType.boolean && text != 'true' && text != 'false') {
      return 'Expected true or false';
    }
    return null;
  }

  pb.ColumnDef _definition(int index,
      {double devicePixelRatio = 1, bool resetWidth = false}) {
    if (editor != null &&
        (editor!.kind == pb.EditorKind.EDITOR_CHECKBOX ||
            editor!.kind == pb.EditorKind.EDITOR_BUTTON ||
            editor!.kind == pb.EditorKind.EDITOR_CUSTOM)) {
      throw ArgumentError('Column $field requires a commit-based editor. '
          'Use the low-level widget for checkbox/button/custom editor actions.');
    }
    if (_exact && format != null && format!.isNotEmpty) {
      throw ArgumentError(
          'Exact column $field cannot use a floating-point format');
    }
    if (_exact &&
        editor != null &&
        editor!.kind != pb.EditorKind.EDITOR_TEXT &&
        editor!.kind != pb.EditorKind.EDITOR_MULTILINE_TEXT) {
      throw ArgumentError('Exact column $field requires a text editor');
    }
    final spec = editor?.deepCopy() ??
        (pb.EditorSpec()
          ..kind = pb.EditorKind.EDITOR_TEXT
          ..owner = pb.EditorOwner.EDITOR_OWNER_HOST_NATIVE
          ..presentation = pb.EditorPresentation.EDITOR_INLINE);
    // Wire-compatible opt-in permission understood by the updated engine.
    // BeforeEdit is also enforced by the wrapper for all editing entry points.
    spec.customProps = spec.customProps.deepCopy()
      ..fields.removeWhere((f) => f.key == 'volvoxgrid.readOnly')
      ..fields.add(pb.StructField(
          key: 'volvoxgrid.readOnly',
          value: pb.ScalarValue(boolValue: !editable)));
    final def = pb.ColumnDef(
      index: index,
      key: field,
      caption: header,
      editor: spec,
      hidden: false,
      format: format ?? '',
      dataType: switch (type) {
        VolvoxColumnType.number => pb.ColumnDataType.COLUMN_DATA_NUMBER,
        VolvoxColumnType.boolean => pb.ColumnDataType.COLUMN_DATA_STRING,
        _ => pb.ColumnDataType.COLUMN_DATA_STRING,
      },
      sortType:
          type == VolvoxColumnType.text || type == VolvoxColumnType.boolean
              ? pb.SortType.SORT_TYPE_STRING
              : pb.SortType.SORT_TYPE_NUMERIC,
    );
    if (width != null) {
      def.width = (width! * devicePixelRatio).round();
    } else if (resetWidth) {
      def.width = -1; // Remove the native override so future defaults still apply.
    }
    return def;
  }

  pb.CellValue _cell(T row) {
    final text = value(row);
    final error = _validate(text);
    if (error != null) throw FormatException('$field: $error', text);
    return switch (type) {
      VolvoxColumnType.number => pb.CellValue(number: double.parse(text)),
      VolvoxColumnType.boolean => pb.CellValue(text: text),
      _ => pb.CellValue(text: text),
    };
  }
}

/// Source identities are captured at the edit decision, before the commit.
@immutable
class VolvoxCellEdit<T> {
  /// Zero-based index in the applied [VolvoxDataGrid.rows] snapshot, NOT the
  /// displayed row. For refreshes, use the business key on [row] or a supplied
  /// [rowId]; engine-generated IDs change on full replacement.
  final int rowIndex;
  final T row;

  /// Native row identity, independent of display order. Supply
  /// [VolvoxDataGrid.getRowId] to preserve IDs across full data replacements.
  final int rowId;

  /// Zero-based index in the applied [VolvoxDataGrid.columns], NOT display order.
  final int columnIndex;
  final String field;

  /// Zero-based engine coordinates at edit time; never use as source indices.
  final int? displayRowIndex;
  final int? displayColumnIndex;
  final String oldText;
  final String newText;

  const VolvoxCellEdit({
    required this.rowIndex,
    required this.row,
    required this.columnIndex,
    required this.field,
    required this.oldText,
    required this.newText,
    this.rowId = 0,
    this.displayRowIndex,
    this.displayColumnIndex,
  });
}

/// Binds immutable list snapshots to the native grid. Pass a new [rows] list
/// (or change [dataVersion]) after mutations. New, equivalent column lists do
/// not reload data; changing only a value callback requires [dataVersion].
///
/// Sort/reorder remain enabled. Row identity belongs to the native engine.
/// Creates its native grid with row identities enabled. A supplied controller
/// must be uncreated or created with rowIdsEnabled: true; an existing grid with
/// identities disabled is rejected before its data or edit policy is changed.
/// The wrapper owns the bound controller's data/schema/clipboard policy. Use the
/// low-level widget instead for direct structural or partial controller writes.
class VolvoxDataGrid<T> extends StatefulWidget {
  final List<T> rows;
  final List<VolvoxColumn<T>> columns;

  /// Optional unique, positive signed 64-bit ID, passed to the native engine.
  /// Keep business keys on the row object; do not hash string keys into IDs.
  /// Keep IDs stable when replacing rows. If omitted, the engine generates IDs
  /// for surviving rows through sort/move/insert/delete, but a full replacement
  /// generates fresh IDs. Changing this callback alone requires [dataVersion].
  final int Function(T row)? getRowId;
  final Object? dataVersion;
  final ValueChanged<VolvoxCellEdit<T>>? onCellEdit;

  /// Synchronous, pre-commit validation. Return null to accept, a message to
  /// reject. Server I/O belongs in [onCellEdit], after this decision.
  final String? Function(VolvoxCellEdit<T> edit)? validateEdit;
  final ValueChanged<String>? onValidationError;
  final void Function(Object error, StackTrace stack)? onError;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Called after each successful data application, including initialization.
  final ValueChanged<VolvoxGridController>? onReady;
  final VolvoxGridController? controller;

  /// Pause rendering/input/events when this view is in an inactive tab.
  final bool active;

  /// Logical base dimensions, scaled together using MediaQuery's TextScaler,
  /// then converted to native physical pixels using the device pixel ratio.
  final double fontSize;
  final double rowHeight;
  final bool followSystemTextScale;

  const VolvoxDataGrid({
    required this.rows,
    required this.columns,
    this.getRowId,
    this.dataVersion,
    this.onCellEdit,
    this.validateEdit,
    this.onValidationError,
    this.onError,
    this.errorBuilder,
    this.onReady,
    this.controller,
    this.active = true,
    this.fontSize = 14,
    this.rowHeight = 32,
    this.followSystemTextScale = true,
    super.key,
  })  : assert(fontSize > 0),
        assert(rowHeight > 0);

  @override
  State<VolvoxDataGrid<T>> createState() => _VolvoxDataGridState<T>();
}

class _Snapshot<T> {
  final List<T> rows;
  final List<VolvoxColumn<T>> columns;
  final List<int> rowIds;
  final Map<int, int> sourceById;
  final int generation;
  _Snapshot(
      this.rows, this.columns, this.rowIds, this.sourceById, this.generation);
}

class _EditTarget<T> {
  final _Snapshot<T> snapshot;
  final int row, column, displayRow, displayColumn;
  final String oldText;
  _EditTarget(this.snapshot, this.row, this.column, this.displayRow,
      this.displayColumn, this.oldText);
  VolvoxCellEdit<T> details(String text, {String? previousText}) =>
      VolvoxCellEdit<T>(
        rowIndex: row,
        row: snapshot.rows[row],
        rowId: snapshot.rowIds[row],
        columnIndex: column,
        field: snapshot.columns[column].field,
        displayRowIndex: displayRow,
        displayColumnIndex: displayColumn,
        oldText: previousText ?? oldText,
        newText: text,
      );
}

class _VolvoxDataGridState<T> extends State<VolvoxDataGrid<T>> {
  late VolvoxGridController _controller;
  bool _ownController = false;
  bool _previousClipboardPolicy = true;
  Future<bool> Function(int row, int col)? _previousEditAuthorization;
  Future<void> _queue = Future.value();
  int _generation = 0;
  bool _ready = false;
  Object? _error;
  _Snapshot<T>? _applied;
  _EditTarget<T>? _editTarget;
  Set<String> _configuredWidthFields = {};
  double? _scaledFont;
  double? _scaledHeight;
  double _devicePixelRatio = 1;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _controller = widget.controller ?? VolvoxGridController();
    _configuredWidthFields = {};
    _ownController = widget.controller == null;
    _previousClipboardPolicy = _controller.clipboardMutationsEnabled;
    _previousEditAuthorization = _controller.editAuthorization;
    if (!_controller.isCreated || _controller.rowIdsEnabled) {
      _controller.clipboardMutationsEnabled = false;
      _controller.editAuthorization = _authorizeEdit;
    }
  }

  void _detach() {
    if (_ownController) {
      _controller.dispose();
    } else if (!_controller.isDisposed) {
      _controller.clipboardMutationsEnabled = _previousClipboardPolicy;
      _controller.editAuthorization = _previousEditAuthorization;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateScale();
  }

  void _updateScale() {
    final scaler = widget.followSystemTextScale
        ? MediaQuery.textScalerOf(context)
        : TextScaler.noScaling;
    final reportedDpr = MediaQuery.devicePixelRatioOf(context);
    final dpr = reportedDpr.isFinite && reportedDpr > 0 ? reportedDpr : 1.0;
    final logicalFont = scaler.scale(widget.fontSize);
    final font = logicalFont * dpr;
    final height = widget.rowHeight * logicalFont / widget.fontSize * dpr;
    if (_devicePixelRatio != dpr ||
        _scaledFont != font ||
        _scaledHeight != height) {
      _devicePixelRatio = dpr;
      _scaledFont = font;
      _scaledHeight = height;
      _schedule();
    }
  }

  bool _current(VolvoxGridController controller, int generation) =>
      mounted &&
      !controller.isDisposed &&
      identical(controller, _controller) &&
      generation == _generation;

  void _schedule() {
    final controller = _controller;
    final configuredWidthFields = _configuredWidthFields;
    final generation = ++_generation;
    // Keep immutable source references while queued; only the newest request
    // allocates snapshot arrays once it starts applying.
    final requestedRows = widget.rows;
    final requestedColumns = widget.columns;
    final idOf = widget.getRowId;
    final font = _scaledFont ?? widget.fontSize;
    final height = _scaledHeight ?? widget.rowHeight;
    final dpr = _devicePixelRatio;
    _ready = false;
    _editTarget = null;
    _error = null;
    _queue = _queue.then((_) async {
      if (!_current(controller, generation)) return;
      final rows = List<T>.of(requestedRows);
      final columns = List<VolvoxColumn<T>>.of(requestedColumns);
      try {
        if (controller.isCreated && !controller.rowIdsEnabled) {
          // Reject before building values or mutating an existing grid. Never
          // recreate an app-owned controller to change its creation options.
          throw StateError(
              'VolvoxDataGrid requires create(rowIdsEnabled: true). '
              'Destroy and recreate the supplied controller with row IDs enabled '
              'before binding it.');
        }
        final fields = <String>{};
        for (final column in columns) {
          if (column.field.isEmpty || !fields.add(column.field)) {
            throw ArgumentError('Column fields must be unique and nonempty');
          }
        }
        final suppliedIds = idOf == null ? null : <int>[];
        final sourceById = <int, int>{};
        final values = <pb.CellValue>[];
        for (var r = 0; r < rows.length; r++) {
          if (idOf != null) {
            final id = idOf(rows[r]);
            if (id <= 0 ||
                id > 0x7fffffffffffffff ||
                sourceById.containsKey(id)) {
              throw ArgumentError(
                  'Row IDs must be unique positive signed 64-bit integers: $id');
            }
            sourceById[id] = r;
            suppliedIds!.add(id);
          }
          for (final column in columns) {
            values.add(column._cell(rows[r]));
          }
        }
        final definitions = <pb.ColumnDef>[
          for (var c = 0; c < columns.length; c++)
            columns[c]._definition(c,
                devicePixelRatio: dpr,
                resetWidth: configuredWidthFields.contains(columns[c].field)),
        ];
        // Every await is a cancellation boundary. Only the newest snapshot can
        // publish readiness or start another native call.
        if (!controller.isCreated) {
          await controller.create(
              rows: rows.length,
              cols: columns.length,
              scale: dpr,
              rowIdsEnabled: true);
          if (!_current(controller, generation)) return;
        }
        await controller.cancelEdit();
        if (!_current(controller, generation)) return;
        await controller.setEditTrigger(pb.EditTrigger.EDIT_TRIGGER_NONE);
        if (!_current(controller, generation)) return;
        // Rebuild the schema in source order before applying the replacement.
        await controller.setRowCount(1);
        if (!_current(controller, generation)) return;
        await controller.setColCount(1);
        if (!_current(controller, generation)) return;
        await controller.setColCount(columns.length);
        if (!_current(controller, generation)) return;
        await controller.configure(pb.GridConfig(
          layout: pb.LayoutConfig(
              defaultRowHeight: height.round(),
              defaultColWidth: (68 * dpr).round()),
          style: pb.StyleConfig(font: pb.Font(size: font)),
          indicators: pb.IndicatorsConfig(
              colTop: pb.ColIndicatorConfig(defaultRowHeight: height.round())),
          span: pb.SpanConfig(cellSpan: pb.CellSpanMode.CELL_SPAN_NONE),
          // loadTable otherwise replaces explicit widths/heights with measured
          // text sizes, defeating both app layout and accessibility scaling.
          interaction: pb.InteractionConfig(autoResize: false),
        ));
        if (!_current(controller, generation)) return;
        await controller
            .defineColumns(pb.DefineColumnsRequest(columns: definitions));
        // Record the schema even if this load was superseded during the call:
        // the next queued load must clear any explicit widths already applied.
        configuredWidthFields
          ..clear()
          ..addAll(columns.where((c) => c.width != null).map((c) => c.field));
        if (!_current(controller, generation)) return;
        await controller.loadTable(rows.length, columns.length, values,
            atomic: true, rowIds: suppliedIds);
        if (!_current(controller, generation)) return;
        // Caller IDs are already known and the native atomic load validates
        // them. Avoid serializing/decoding every ID again for keyed datasets.
        final identities = suppliedIds ?? List<int>.filled(rows.length, 0);
        if (suppliedIds == null && rows.isNotEmpty) {
          final nativeRows = await controller.getRows(rowCount: rows.length);
          if (!_current(controller, generation)) return;
          for (final identity in nativeRows) {
            if (identity.index < 0 ||
                identity.index >= rows.length ||
                identities[identity.index] != 0 ||
                identity.rowId <= 0 ||
                sourceById.containsKey(identity.rowId)) {
              throw StateError('Native engine returned invalid row identities');
            }
            identities[identity.index] = identity.rowId;
            sourceById[identity.rowId] = identity.index;
          }
          if (sourceById.length != rows.length) {
            throw StateError('Native engine omitted table row IDs');
          }
        }
        final snapshot =
            _Snapshot(rows, columns, identities, sourceById, generation);
        await controller.setEditTrigger(columns.any((c) => c.editable)
            ? pb.EditTrigger.EDIT_TRIGGER_KEY_CLICK
            : pb.EditTrigger.EDIT_TRIGGER_NONE);
        if (!_current(controller, generation)) return;
        setState(() {
          _applied = snapshot;
          _ready = true;
        });
        widget.onReady?.call(controller);
      } catch (error, stack) {
        if (!_current(controller, generation)) return;
        setState(() {
          _error = error;
          _ready = false;
        });
        _report(error, stack);
      }
    });
  }

  void _report(Object error, StackTrace stack) {
    if (widget.onError != null) {
      try {
        widget.onError!(error, stack);
      } catch (callbackError, callbackStack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: callbackError,
          stack: callbackStack,
          library: 'volvoxgrid',
          context: ErrorDescription('in the application onError callback'),
        ));
      }
    } else {
      FlutterError.reportError(FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'volvoxgrid',
          context:
              ErrorDescription('while applying or editing bound grid data')));
    }
  }

  @override
  void didUpdateWidget(covariant VolvoxDataGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      _detach();
      _attach();
    }
    final columnsChanged = oldWidget.columns.length != widget.columns.length ||
        List.generate(widget.columns.length, (i) => i).any(
            (i) => !oldWidget.columns[i]._sameConfiguration(widget.columns[i]));
    final oldFont = _scaledFont;
    final oldHeight = _scaledHeight;
    final oldDpr = _devicePixelRatio;
    _updateScale();
    if (oldFont != _scaledFont ||
        oldHeight != _scaledHeight ||
        oldDpr != _devicePixelRatio) return;
    if (controllerChanged ||
        !identical(oldWidget.rows, widget.rows) ||
        oldWidget.dataVersion != widget.dataVersion ||
        columnsChanged) {
      _schedule();
    }
  }

  Future<_EditTarget<T>?> _resolve(int rowId, int row, int col) async {
    final controller = _controller;
    final snapshot = _applied;
    if (!_ready || snapshot == null || rowId <= 0 || row < 0 || col < 0) {
      return null;
    }
    // The event carries identity from emission time. Its row coordinate may
    // already be stale after a sort/move; never use that coordinate as identity.
    final sourceRow = snapshot.sourceById[rowId];
    if (sourceRow == null) return null; // Unknown inserted row: fail closed.
    final schema = await controller.getSchema();
    if (!_current(controller, snapshot.generation) || !_ready) return null;
    final definitions = schema.columns.where((c) => c.index == col);
    if (definitions.length != 1) return null;
    final column =
        snapshot.columns.indexWhere((c) => c.field == definitions.single.key);
    if (column < 0 || !snapshot.columns[column].editable) return null;
    final currentRow = await controller.findRowById(rowId);
    if (!_current(controller, snapshot.generation) ||
        !_ready ||
        currentRow == null) {
      return null;
    }
    final oldText = await controller.getCellText(currentRow, col);
    if (!_current(controller, snapshot.generation) || !_ready) return null;
    final stillAtRow = await controller.getRowId(currentRow);
    if (!_current(controller, snapshot.generation) ||
        !_ready ||
        stillAtRow != rowId) {
      return null;
    }
    return _EditTarget(snapshot, sourceRow, column, row, col, oldText);
  }

  Future<void> _onBeforeEdit(VolvoxGridBeforeEditDetails details) async {
    details.cancel = true;
    final controller = _controller;
    final generation = _generation;
    try {
      final target = await _resolve(details.rowId, details.row, details.col);
      if (!_current(controller, generation)) return;
      _editTarget = target;
      details.cancel = target == null;
    } catch (error, stack) {
      if (_current(controller, generation)) _report(error, stack);
    }
  }

  Future<bool> _authorizeEdit(int row, int col) async {
    final controller = _controller;
    final generation = _generation;
    try {
      final rowId = await controller.getRowId(row);
      if (!_current(controller, generation)) return false;
      final target = await _resolve(rowId, row, col);
      if (target == null) return false;
      _editTarget = target;
      return true;
    } catch (error, stack) {
      if (_current(controller, generation)) _report(error, stack);
      return false;
    }
  }

  Future<void> _onValidating(
      VolvoxGridCellEditValidatingDetails details) async {
    details.cancel = true;
    final controller = _controller;
    final generation = _generation;
    try {
      final target = await _resolve(details.rowId, details.row, details.col);
      if (target == null) return;
      final original = _editTarget;
      if (original == null ||
          original.snapshot != target.snapshot ||
          original.row != target.row ||
          original.column != target.column) return;
      final error =
          target.snapshot.columns[target.column]._validate(details.editText) ??
              widget.validateEdit?.call(target.details(details.editText));
      if (error != null) {
        widget.onValidationError?.call(error);
        return;
      }
      _editTarget = target;
      details.cancel = false;
    } catch (error, stack) {
      if (_current(controller, generation)) _report(error, stack);
    }
  }

  void _onGridEvent(pb.GridEvent event) {
    if (event.hasError()) {
      _report(StateError('Native grid: ${event.error}'), StackTrace.current);
      return;
    }
    if (!event.hasAfterEdit()) return;
    final target = _editTarget;
    final after = event.afterEdit;
    if (target == null ||
        !_ready ||
        target.snapshot.generation != _generation ||
        after.rowId.toInt() != target.snapshot.rowIds[target.row] ||
        after.col != target.displayColumn) return;
    _editTarget = null;
    widget.onCellEdit
        ?.call(target.details(after.newText, previousText: after.oldText));
  }

  @override
  void dispose() {
    ++_generation;
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!) ??
          Text('Unable to load grid: $_error');
    }
    if (_controller.isCreated && !_controller.rowIdsEnabled) {
      // Initialization will report the incompatible creation option. Even an
      // inactive renderer configures fling policy, so do not mount one against
      // this rejected app-owned grid.
      return const SizedBox.expand();
    }
    return VolvoxGridWidget(
      key: ObjectKey(_controller),
      controller: _controller,
      active: widget.active && _ready,
      allowBulkEdits: false,
      onGridEvent: _onGridEvent,
      onBeforeEdit: _onBeforeEdit,
      onCellEditValidating: _onValidating,
    );
  }
}
