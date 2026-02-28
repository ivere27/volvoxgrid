import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart' as sf;
import 'package:volvoxgrid/volvoxgrid_controller.dart';
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart' as vv;

// ── Test Case Definition ─────────────────────────────────────────────

class TestCase {
  final int id;
  final String name;
  final String script;
  final List<vv.GridColumn> Function() vvColumnsFactory;
  final List<vv.DataGridRow> vvRows;
  final List<vv.SortColumnDetails> vvSortedColumns;
  final List<sf.GridColumn> Function() sfColumnsFactory;
  final sf.DataGridSource Function() sfSourceFactory;
  final int frozenColumnsCount;
  final int frozenRowsCount;
  final int footerFrozenColumnsCount;
  final int footerFrozenRowsCount;
  final sf.GridLinesVisibility gridLinesVisibility;
  final double rowHeight;
  final double headerRowHeight;
  final sf.SelectionMode selectionMode;
  final bool allowSorting;
  final Future<void> Function(VolvoxGridController controller)? onVolvoxCreated;
  final Future<void> Function(
      sf.DataGridController controller, sf.DataGridSource source)? onSfCreated;
  final Future<void> Function(
      ScrollController vertical, ScrollController horizontal)? onSfScroll;

  TestCase({
    required this.id,
    required this.name,
    required this.script,
    required this.vvColumnsFactory,
    required this.vvRows,
    this.vvSortedColumns = const [],
    required this.sfColumnsFactory,
    required this.sfSourceFactory,
    this.frozenColumnsCount = 0,
    this.frozenRowsCount = 0,
    this.footerFrozenColumnsCount = 0,
    this.footerFrozenRowsCount = 0,
    this.gridLinesVisibility = sf.GridLinesVisibility.both,
    this.rowHeight = 32,
    this.headerRowHeight = 36, // default for testing consistency
    this.selectionMode = sf.SelectionMode.none,
    this.allowSorting = false,
    this.onVolvoxCreated,
    this.onSfCreated,
    this.onSfScroll,
  });
}

// ── Reference DataGridSource ─────────────────────────────────────────

class StaticSfSource extends sf.DataGridSource {
  StaticSfSource(this._rows, [this._sortedColumns = const []]);

  final List<sf.DataGridRow> _rows;
  final List<sf.SortColumnDetails> _sortedColumns;

  @override
  List<sf.DataGridRow> get rows => _rows;

  @override
  List<sf.SortColumnDetails> get sortedColumns => _sortedColumns;

  @override
  sf.DataGridRowAdapter buildRow(sf.DataGridRow row) {
    return sf.DataGridRowAdapter(
      cells: row.getCells().map((c) {
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${c.value ?? ''}',
            style: const TextStyle(fontSize: 14.0, fontFamily: 'Roboto'),
          ),
        );
      }).toList(growable: false),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────

final textStyle = const TextStyle(fontSize: 14.0, fontFamily: 'Roboto');

sf.DataGridCell<dynamic> sc(String name, dynamic value) =>
    sf.DataGridCell<dynamic>(columnName: name, value: value);

sf.DataGridRow sr(List<sf.DataGridCell<dynamic>> cells) =>
    sf.DataGridRow(cells: cells);

vv.DataGridCell<dynamic> vc(String name, dynamic value) =>
    vv.DataGridCell<dynamic>(columnName: name, value: value);

vv.DataGridRow vr(List<vv.DataGridCell<dynamic>> cells) =>
    vv.DataGridRow(cells: cells);

class VvSource extends vv.DataGridSource {
  VvSource(this._rows, [this._sortedColumns = const []]);
  final List<vv.DataGridRow> _rows;
  final List<vv.SortColumnDetails> _sortedColumns;
  @override
  List<vv.DataGridRow> get rows => _rows;
  @override
  List<vv.SortColumnDetails> get sortedColumns => _sortedColumns;
}
