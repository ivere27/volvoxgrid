using System.Collections.Generic;

namespace VolvoxGrid.DotNet.Internal
{
    internal interface IProtoCodec
    {
        byte[] EncodeCreateRequest(int viewportWidth, int viewportHeight, float scale);
        long DecodeGridHandle(byte[] payload);
        byte[] EncodeGridHandle(long gridId);

        byte[] EncodeConfigureRequest(long gridId, VolvoxGridConfigData config);
        byte[] EncodeGetConfigRequest(long gridId);
        VolvoxGridConfigData DecodeGridConfig(byte[] payload);

        byte[] EncodeDefineColumnsRequest(long gridId, IList<VolvoxColumnDefinition> columns);
        byte[] EncodeDefineRowsRequest(long gridId, IList<VolvoxRowDefinition> rows);
        byte[] EncodeInsertRowsRequest(long gridId, int index, int count, IList<string> text);
        byte[] EncodeRemoveRowsRequest(long gridId, int index, int count);
        byte[] EncodeMoveColumnRequest(long gridId, int col, int position);
        byte[] EncodeMoveRowRequest(long gridId, int row, int position);

        byte[] EncodeLoadTableRequest(long gridId, int rows, int cols, IList<VolvoxCellValueData> values, bool atomic);
        byte[] EncodeUpdateCellsRequest(long gridId, IList<VolvoxCellUpdateData> updates, bool atomic);
        byte[] EncodeGetCellsRequest(long gridId, int row1, int col1, int row2, int col2, bool includeStyle, bool includeChecked, bool includeTyped);
        List<VolvoxCellUpdateData> DecodeCellsResponse(byte[] payload);
        byte[] EncodeClearRequest(long gridId, VolvoxClearScope scope, VolvoxClearRegion region);

        byte[] EncodeSelectRequest(long gridId, int activeRow, int activeCol, IList<VolvoxCellRangeData> ranges, bool? show);
        byte[] EncodeShowCellRequest(long gridId, int row, int col);
        byte[] EncodeSetTopRowRequest(long gridId, int row);
        byte[] EncodeSetLeftColRequest(long gridId, int col);
        VolvoxSelectionStateData DecodeSelectionState(byte[] payload);

        byte[] EncodeSortRequest(long gridId, IList<VolvoxSortColumn> sorts);
        byte[] EncodeSubtotalRequest(long gridId, VolvoxAggregateType aggregate, int groupOnCol, int aggregateCol, string caption, uint backColor, uint foreColor, bool addOutline);
        byte[] EncodeAutoSizeRequest(long gridId, int colFrom, int colTo, bool equal, int maxWidth);
        byte[] EncodeOutlineRequest(long gridId, int level);
        byte[] EncodeGetNodeRequest(long gridId, int row, VolvoxNodeRelation? relation);
        VolvoxNodeInfoData DecodeNodeInfo(byte[] payload);
        byte[] EncodeFindRequest(long gridId, int col, int startRow, string text, bool caseSensitive, bool fullMatch, string regex);
        int DecodeFindResponse(byte[] payload);
        byte[] EncodeAggregateRequest(long gridId, VolvoxAggregateType aggregate, int row1, int col1, int row2, int col2);
        double DecodeAggregateResponse(byte[] payload);
        byte[] EncodeGetMergedRangeRequest(long gridId, int row, int col);
        VolvoxCellRangeData DecodeCellRange(byte[] payload);
        byte[] EncodeMergeCellsRequest(long gridId, VolvoxCellRangeData range);
        byte[] EncodeUnmergeCellsRequest(long gridId, VolvoxCellRangeData range);
        List<VolvoxCellRangeData> DecodeMergedRegionsResponse(byte[] payload);

        byte[] EncodeEditCommandStart(long gridId, int row, int col, bool? selectAll, bool? caretEnd, string seedText);
        byte[] EncodeEditCommandCommit(long gridId, string text);
        byte[] EncodeEditCommandCancel(long gridId);
        byte[] EncodeEditCommandSetPreedit(long gridId, string text, int cursor, bool commit);
        byte[] EncodeEditCommandSetText(long gridId, string text);

        byte[] EncodeClipboardRequest(long gridId, string action, string pasteText);
        VolvoxClipboardResponseData DecodeClipboardResponse(byte[] payload);

        byte[] EncodeExportRequest(long gridId, VolvoxExportFormat format, VolvoxExportScope scope);
        VolvoxExportResponseData DecodeExportResponse(byte[] payload);
        byte[] EncodeImportRequest(long gridId, byte[] data, VolvoxExportFormat format, VolvoxExportScope scope);
        byte[] EncodePrintRequest(long gridId, bool landscape, int marginL, int marginT, int marginR, int marginB, string header, string footer, bool showPageNumbers);
        byte[] EncodeArchiveRequest(long gridId, VolvoxArchiveAction action, string name, byte[] data);
        VolvoxArchiveResponseData DecodeArchiveResponse(byte[] payload);

        byte[] EncodeLoadDemoRequest(long gridId, string demo);
        byte[] EncodeSetRedrawRequest(long gridId, bool enabled);
        byte[] EncodeResizeViewportRequest(long gridId, int width, int height);

        byte[] EncodeRenderInputBufferReady(long gridId, long handle, int stride, int width, int height);
        byte[] EncodeRenderInputPointer(long gridId, VolvoxPointerType type, float x, float y, int modifier, int button, bool dblClick);
        byte[] EncodeRenderInputKey(long gridId, VolvoxKeyType type, int keyCode, int modifier, string character);
        byte[] EncodeRenderInputScroll(long gridId, float deltaX, float deltaY);
        byte[] EncodeRenderInputEventDecision(long gridId, long eventId, bool cancel);

        VolvoxRenderOutputData DecodeRenderOutput(byte[] payload);
        VolvoxGridEventData DecodeGridEvent(byte[] payload);
    }
}
