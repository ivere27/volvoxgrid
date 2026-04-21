// This is a generated file - do not edit.
//
// Generated from volvoxgrid.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'volvoxgrid.pb.dart' as $0;
import 'volvoxgrid.pbjson.dart';

export 'volvoxgrid.pb.dart';

abstract class VolvoxGridServiceBase extends $pb.GeneratedService {
  $async.Future<$0.CreateResponse> create(
      $pb.ServerContext ctx, $0.CreateRequest request);
  $async.Future<$0.DestroyResponse> destroy(
      $pb.ServerContext ctx, $0.GridHandle request);
  $async.Future<$0.ConfigureResponse> configure(
      $pb.ServerContext ctx, $0.ConfigureRequest request);
  $async.Future<$0.GridConfig> getConfig(
      $pb.ServerContext ctx, $0.GridHandle request);
  $async.Future<$0.LoadFontDataResponse> loadFontData(
      $pb.ServerContext ctx, $0.LoadFontDataRequest request);
  $async.Future<$0.DefineColumnsResponse> defineColumns(
      $pb.ServerContext ctx, $0.DefineColumnsRequest request);
  $async.Future<$0.DefineColumnsRequest> getSchema(
      $pb.ServerContext ctx, $0.GridHandle request);
  $async.Future<$0.DefineRowsResponse> defineRows(
      $pb.ServerContext ctx, $0.DefineRowsRequest request);
  $async.Future<$0.InsertRowsResponse> insertRows(
      $pb.ServerContext ctx, $0.InsertRowsRequest request);
  $async.Future<$0.RemoveRowsResponse> removeRows(
      $pb.ServerContext ctx, $0.RemoveRowsRequest request);
  $async.Future<$0.MoveColumnResponse> moveColumn(
      $pb.ServerContext ctx, $0.MoveColumnRequest request);
  $async.Future<$0.MoveRowResponse> moveRow(
      $pb.ServerContext ctx, $0.MoveRowRequest request);
  $async.Future<$0.WriteResult> updateCells(
      $pb.ServerContext ctx, $0.UpdateCellsRequest request);
  $async.Future<$0.CellsResponse> getCells(
      $pb.ServerContext ctx, $0.GetCellsRequest request);
  $async.Future<$0.WriteResult> loadTable(
      $pb.ServerContext ctx, $0.LoadTableRequest request);
  $async.Future<$0.LoadDataResult> loadData(
      $pb.ServerContext ctx, $0.LoadDataRequest request);
  $async.Future<$0.ClearResponse> clear(
      $pb.ServerContext ctx, $0.ClearRequest request);
  $async.Future<$0.SelectResponse> select(
      $pb.ServerContext ctx, $0.SelectRequest request);
  $async.Future<$0.SelectionState> getSelection(
      $pb.ServerContext ctx, $0.GridHandle request);
  $async.Future<$0.ShowCellResponse> showCell(
      $pb.ServerContext ctx, $0.ShowCellRequest request);
  $async.Future<$0.SetTopRowResponse> setTopRow(
      $pb.ServerContext ctx, $0.SetRowRequest request);
  $async.Future<$0.SetLeftColResponse> setLeftCol(
      $pb.ServerContext ctx, $0.SetColRequest request);
  $async.Future<$0.EditState> edit(
      $pb.ServerContext ctx, $0.EditCommand request);
  $async.Future<$0.SortResponse> sort(
      $pb.ServerContext ctx, $0.SortRequest request);
  $async.Future<$0.SubtotalResult> subtotal(
      $pb.ServerContext ctx, $0.SubtotalRequest request);
  $async.Future<$0.AutoSizeResponse> autoSize(
      $pb.ServerContext ctx, $0.AutoSizeRequest request);
  $async.Future<$0.OutlineResponse> outline(
      $pb.ServerContext ctx, $0.OutlineRequest request);
  $async.Future<$0.NodeInfo> getNode(
      $pb.ServerContext ctx, $0.GetNodeRequest request);
  $async.Future<$0.FindResponse> find(
      $pb.ServerContext ctx, $0.FindRequest request);
  $async.Future<$0.AggregateResponse> aggregate(
      $pb.ServerContext ctx, $0.AggregateRequest request);
  $async.Future<$0.CellRange> getMergedRange(
      $pb.ServerContext ctx, $0.GetMergedRangeRequest request);
  $async.Future<$0.MergeCellsResponse> mergeCells(
      $pb.ServerContext ctx, $0.MergeCellsRequest request);
  $async.Future<$0.UnmergeCellsResponse> unmergeCells(
      $pb.ServerContext ctx, $0.UnmergeCellsRequest request);
  $async.Future<$0.MergedRegionsResponse> getMergedRegions(
      $pb.ServerContext ctx, $0.GridHandle request);
  $async.Future<$0.MemoryUsageResponse> getMemoryUsage(
      $pb.ServerContext ctx, $0.GridHandle request);
  $async.Future<$0.ClipboardResponse> clipboard(
      $pb.ServerContext ctx, $0.ClipboardCommand request);
  $async.Future<$0.ExportResponse> export(
      $pb.ServerContext ctx, $0.ExportRequest request);
  $async.Future<$0.PrintResponse> print(
      $pb.ServerContext ctx, $0.PrintRequest request);
  $async.Future<$0.ArchiveResponse> archive(
      $pb.ServerContext ctx, $0.ArchiveRequest request);
  $async.Future<$0.ResizeViewportResponse> resizeViewport(
      $pb.ServerContext ctx, $0.ResizeViewportRequest request);
  $async.Future<$0.SetRedrawResponse> setRedraw(
      $pb.ServerContext ctx, $0.SetRedrawRequest request);
  $async.Future<$0.RefreshResponse> refresh(
      $pb.ServerContext ctx, $0.GridHandle request);
  $async.Future<$0.LoadDemoResponse> loadDemo(
      $pb.ServerContext ctx, $0.LoadDemoRequest request);
  $async.Future<$0.GetDemoDataResponse> getDemoData(
      $pb.ServerContext ctx, $0.GetDemoDataRequest request);
  $async.Future<$0.RenderOutput> renderSession(
      $pb.ServerContext ctx, $0.RenderInput request);
  $async.Future<$0.GridEvent> eventStream(
      $pb.ServerContext ctx, $0.GridHandle request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'Create':
        return $0.CreateRequest();
      case 'Destroy':
        return $0.GridHandle();
      case 'Configure':
        return $0.ConfigureRequest();
      case 'GetConfig':
        return $0.GridHandle();
      case 'LoadFontData':
        return $0.LoadFontDataRequest();
      case 'DefineColumns':
        return $0.DefineColumnsRequest();
      case 'GetSchema':
        return $0.GridHandle();
      case 'DefineRows':
        return $0.DefineRowsRequest();
      case 'InsertRows':
        return $0.InsertRowsRequest();
      case 'RemoveRows':
        return $0.RemoveRowsRequest();
      case 'MoveColumn':
        return $0.MoveColumnRequest();
      case 'MoveRow':
        return $0.MoveRowRequest();
      case 'UpdateCells':
        return $0.UpdateCellsRequest();
      case 'GetCells':
        return $0.GetCellsRequest();
      case 'LoadTable':
        return $0.LoadTableRequest();
      case 'LoadData':
        return $0.LoadDataRequest();
      case 'Clear':
        return $0.ClearRequest();
      case 'Select':
        return $0.SelectRequest();
      case 'GetSelection':
        return $0.GridHandle();
      case 'ShowCell':
        return $0.ShowCellRequest();
      case 'SetTopRow':
        return $0.SetRowRequest();
      case 'SetLeftCol':
        return $0.SetColRequest();
      case 'Edit':
        return $0.EditCommand();
      case 'Sort':
        return $0.SortRequest();
      case 'Subtotal':
        return $0.SubtotalRequest();
      case 'AutoSize':
        return $0.AutoSizeRequest();
      case 'Outline':
        return $0.OutlineRequest();
      case 'GetNode':
        return $0.GetNodeRequest();
      case 'Find':
        return $0.FindRequest();
      case 'Aggregate':
        return $0.AggregateRequest();
      case 'GetMergedRange':
        return $0.GetMergedRangeRequest();
      case 'MergeCells':
        return $0.MergeCellsRequest();
      case 'UnmergeCells':
        return $0.UnmergeCellsRequest();
      case 'GetMergedRegions':
        return $0.GridHandle();
      case 'GetMemoryUsage':
        return $0.GridHandle();
      case 'Clipboard':
        return $0.ClipboardCommand();
      case 'Export':
        return $0.ExportRequest();
      case 'Print':
        return $0.PrintRequest();
      case 'Archive':
        return $0.ArchiveRequest();
      case 'ResizeViewport':
        return $0.ResizeViewportRequest();
      case 'SetRedraw':
        return $0.SetRedrawRequest();
      case 'Refresh':
        return $0.GridHandle();
      case 'LoadDemo':
        return $0.LoadDemoRequest();
      case 'GetDemoData':
        return $0.GetDemoDataRequest();
      case 'RenderSession':
        return $0.RenderInput();
      case 'EventStream':
        return $0.GridHandle();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'Create':
        return create(ctx, request as $0.CreateRequest);
      case 'Destroy':
        return destroy(ctx, request as $0.GridHandle);
      case 'Configure':
        return configure(ctx, request as $0.ConfigureRequest);
      case 'GetConfig':
        return getConfig(ctx, request as $0.GridHandle);
      case 'LoadFontData':
        return loadFontData(ctx, request as $0.LoadFontDataRequest);
      case 'DefineColumns':
        return defineColumns(ctx, request as $0.DefineColumnsRequest);
      case 'GetSchema':
        return getSchema(ctx, request as $0.GridHandle);
      case 'DefineRows':
        return defineRows(ctx, request as $0.DefineRowsRequest);
      case 'InsertRows':
        return insertRows(ctx, request as $0.InsertRowsRequest);
      case 'RemoveRows':
        return removeRows(ctx, request as $0.RemoveRowsRequest);
      case 'MoveColumn':
        return moveColumn(ctx, request as $0.MoveColumnRequest);
      case 'MoveRow':
        return moveRow(ctx, request as $0.MoveRowRequest);
      case 'UpdateCells':
        return updateCells(ctx, request as $0.UpdateCellsRequest);
      case 'GetCells':
        return getCells(ctx, request as $0.GetCellsRequest);
      case 'LoadTable':
        return loadTable(ctx, request as $0.LoadTableRequest);
      case 'LoadData':
        return loadData(ctx, request as $0.LoadDataRequest);
      case 'Clear':
        return clear(ctx, request as $0.ClearRequest);
      case 'Select':
        return select(ctx, request as $0.SelectRequest);
      case 'GetSelection':
        return getSelection(ctx, request as $0.GridHandle);
      case 'ShowCell':
        return showCell(ctx, request as $0.ShowCellRequest);
      case 'SetTopRow':
        return setTopRow(ctx, request as $0.SetRowRequest);
      case 'SetLeftCol':
        return setLeftCol(ctx, request as $0.SetColRequest);
      case 'Edit':
        return edit(ctx, request as $0.EditCommand);
      case 'Sort':
        return sort(ctx, request as $0.SortRequest);
      case 'Subtotal':
        return subtotal(ctx, request as $0.SubtotalRequest);
      case 'AutoSize':
        return autoSize(ctx, request as $0.AutoSizeRequest);
      case 'Outline':
        return outline(ctx, request as $0.OutlineRequest);
      case 'GetNode':
        return getNode(ctx, request as $0.GetNodeRequest);
      case 'Find':
        return find(ctx, request as $0.FindRequest);
      case 'Aggregate':
        return aggregate(ctx, request as $0.AggregateRequest);
      case 'GetMergedRange':
        return getMergedRange(ctx, request as $0.GetMergedRangeRequest);
      case 'MergeCells':
        return mergeCells(ctx, request as $0.MergeCellsRequest);
      case 'UnmergeCells':
        return unmergeCells(ctx, request as $0.UnmergeCellsRequest);
      case 'GetMergedRegions':
        return getMergedRegions(ctx, request as $0.GridHandle);
      case 'GetMemoryUsage':
        return getMemoryUsage(ctx, request as $0.GridHandle);
      case 'Clipboard':
        return clipboard(ctx, request as $0.ClipboardCommand);
      case 'Export':
        return export(ctx, request as $0.ExportRequest);
      case 'Print':
        return print(ctx, request as $0.PrintRequest);
      case 'Archive':
        return archive(ctx, request as $0.ArchiveRequest);
      case 'ResizeViewport':
        return resizeViewport(ctx, request as $0.ResizeViewportRequest);
      case 'SetRedraw':
        return setRedraw(ctx, request as $0.SetRedrawRequest);
      case 'Refresh':
        return refresh(ctx, request as $0.GridHandle);
      case 'LoadDemo':
        return loadDemo(ctx, request as $0.LoadDemoRequest);
      case 'GetDemoData':
        return getDemoData(ctx, request as $0.GetDemoDataRequest);
      case 'RenderSession':
        return renderSession(ctx, request as $0.RenderInput);
      case 'EventStream':
        return eventStream(ctx, request as $0.GridHandle);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json =>
      VolvoxGridServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => VolvoxGridServiceBase$messageJson;
}
