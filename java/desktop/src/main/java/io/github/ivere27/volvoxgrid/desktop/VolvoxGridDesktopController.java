package io.github.ivere27.volvoxgrid.desktop;

import com.google.protobuf.ByteString;
import io.github.ivere27.volvoxgrid.*;
import io.github.ivere27.volvoxgrid.common.VolvoxGridController;
import io.github.ivere27.volvoxgrid.common.GridCellText;
import io.github.ivere27.volvoxgrid.common.GridSelection;
import io.github.ivere27.volvoxgrid.common.RendererBackend;
import java.util.List;
import java.util.Objects;

/**
 * High-level convenience controller for desktop Java.
 */
public final class VolvoxGridDesktopController implements VolvoxGridController {
    private final VolvoxGridDesktopClient client;
    private final long gridId;

    public static VolvoxGridDesktopController create(
        VolvoxGridDesktopClient client,
        CreateRequest request
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(client, "client");
        Objects.requireNonNull(request, "request");
        GridHandle handle = client.create(request);
        return new VolvoxGridDesktopController(client, handle.getId());
    }

    public VolvoxGridDesktopController(VolvoxGridDesktopClient client, long gridId) {
        this.client = Objects.requireNonNull(client, "client");
        this.gridId = gridId;
    }

    public long getGridId() {
        return gridId;
    }

    public void destroy() throws SynurangDesktopBridge.SynurangBridgeException {
        client.destroy(handle());
    }

    public int getRows() throws SynurangDesktopBridge.SynurangBridgeException {
        return getConfig().getLayout().getRows();
    }

    public void setRows(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setRows(value).build())
                .build()
        );
    }

    public int getCols() throws SynurangDesktopBridge.SynurangBridgeException {
        return getConfig().getLayout().getCols();
    }

    public void setCols(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setCols(value).build())
                .build()
        );
    }

    public int getFixedRows() throws SynurangDesktopBridge.SynurangBridgeException {
        return getConfig().getLayout().getFixedRows();
    }

    public void setFixedRows(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setFixedRows(value).build())
                .build()
        );
    }

    public int getFixedCols() throws SynurangDesktopBridge.SynurangBridgeException {
        return getConfig().getLayout().getFixedCols();
    }

    public void setFixedCols(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setFixedCols(value).build())
                .build()
        );
    }

    @Override
    public int rowCount() {
        return getRows();
    }

    @Override
    public void setRowCount(int value) {
        setRows(value);
    }

    @Override
    public int colCount() {
        return getCols();
    }

    @Override
    public void setColCount(int value) {
        setCols(value);
    }

    @Override
    public int fixedRowCount() {
        return getFixedRows();
    }

    @Override
    public void setFixedRowCount(int value) {
        setFixedRows(value);
    }

    @Override
    public int fixedColCount() {
        return getFixedCols();
    }

    @Override
    public void setFixedColCount(int value) {
        setFixedCols(value);
    }

    public void setEditable(boolean editable) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setEditing(EditConfig.newBuilder().setEditTriggerValue(editable ? 2 : 0).build())
                .build()
        );
    }

    @Override
    public void setTextMatrix(int row, int col, String text) throws SynurangDesktopBridge.SynurangBridgeException {
        client.updateCells(
            UpdateCellsRequest.newBuilder()
                .setGridId(gridId)
                .addCells(
                    CellUpdate.newBuilder()
                        .setRow(row)
                        .setCol(col)
                        .setValue(CellValue.newBuilder().setText(text).build())
                        .build()
                )
                .build()
        );
    }

    @Override
    public String getTextMatrix(int row, int col) throws SynurangDesktopBridge.SynurangBridgeException {
        CellsResponse response = client.getCells(
            GetCellsRequest.newBuilder()
                .setGridId(gridId)
                .setRow1(row)
                .setCol1(col)
                .setRow2(row)
                .setCol2(col)
                .build()
        );
        if (response.getCellsCount() > 0 && response.getCells(0).getValue().hasText()) {
            return response.getCells(0).getValue().getText();
        }
        return "";
    }

    @Override
    public void setCellTexts(List<GridCellText> cells) throws SynurangDesktopBridge.SynurangBridgeException {
        UpdateCellsRequest.Builder builder = UpdateCellsRequest.newBuilder().setGridId(gridId);
        for (GridCellText cell : cells) {
            builder.addCells(
                CellUpdate.newBuilder()
                    .setRow(cell.getRow())
                    .setCol(cell.getCol())
                    .setValue(CellValue.newBuilder().setText(cell.getText()).build())
                    .build()
            );
        }
        client.updateCells(builder.build());
    }

    public void setCells(List<CellText> cells) throws SynurangDesktopBridge.SynurangBridgeException {
        UpdateCellsRequest.Builder builder = UpdateCellsRequest.newBuilder().setGridId(gridId);
        for (CellText cell : cells) {
            builder.addCells(
                CellUpdate.newBuilder()
                    .setRow(cell.row)
                    .setCol(cell.col)
                    .setValue(CellValue.newBuilder().setText(cell.text).build())
                    .build()
            );
        }
        client.updateCells(builder.build());
    }

    public Empty updateCells(UpdateCellsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.updateCells(request.toBuilder().setGridId(gridId).build());
    }

    public CellsResponse getCells(GetCellsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.getCells(request.toBuilder().setGridId(gridId).build());
    }

    public Empty loadArray(LoadArrayRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.loadArray(request.toBuilder().setGridId(gridId).build());
    }

    public void loadArray(int rows, int cols, List<String> values, boolean bind) throws SynurangDesktopBridge.SynurangBridgeException {
        LoadArrayRequest.Builder builder = LoadArrayRequest.newBuilder()
            .setGridId(gridId)
            .setRows(rows)
            .setCols(cols)
            .setBind(bind);
        if (values != null && !values.isEmpty()) {
            builder.addAllValues(values);
        }
        client.loadArray(builder.build());
    }

    @Override
    public void setRowHeight(int row, int height) throws SynurangDesktopBridge.SynurangBridgeException {
        client.defineRows(
            DefineRowsRequest.newBuilder()
                .setGridId(gridId)
                .addRows(RowDef.newBuilder().setIndex(row).setHeight(height).build())
                .build()
        );
    }

    @Override
    public void setColWidth(int col, int width) throws SynurangDesktopBridge.SynurangBridgeException {
        client.defineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(ColumnDef.newBuilder().setIndex(col).setWidth(width).build())
                .build()
        );
    }

    public Empty defineColumns(DefineColumnsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.defineColumns(request.toBuilder().setGridId(gridId).build());
    }

    public Empty defineRows(DefineRowsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.defineRows(request.toBuilder().setGridId(gridId).build());
    }

    public Empty insertRows(InsertRowsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.insertRows(request.toBuilder().setGridId(gridId).build());
    }

    public void insertRows(int index, int count, List<String> text) throws SynurangDesktopBridge.SynurangBridgeException {
        InsertRowsRequest.Builder builder = InsertRowsRequest.newBuilder()
            .setGridId(gridId)
            .setIndex(index)
            .setCount(count);
        if (text != null && !text.isEmpty()) {
            builder.addAllText(text);
        }
        client.insertRows(builder.build());
    }

    public Empty removeRows(RemoveRowsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.removeRows(request.toBuilder().setGridId(gridId).build());
    }

    public void removeRows(int index, int count) throws SynurangDesktopBridge.SynurangBridgeException {
        client.removeRows(
            RemoveRowsRequest.newBuilder()
                .setGridId(gridId)
                .setIndex(index)
                .setCount(count)
                .build()
        );
    }

    public Empty moveColumn(MoveColumnRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.moveColumn(request.toBuilder().setGridId(gridId).build());
    }

    public void moveColumn(int col, int position) throws SynurangDesktopBridge.SynurangBridgeException {
        client.moveColumn(
            MoveColumnRequest.newBuilder()
                .setGridId(gridId)
                .setCol(col)
                .setPosition(position)
                .build()
        );
    }

    public Empty moveRow(MoveRowRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.moveRow(request.toBuilder().setGridId(gridId).build());
    }

    public void moveRow(int row, int position) throws SynurangDesktopBridge.SynurangBridgeException {
        client.moveRow(
            MoveRowRequest.newBuilder()
                .setGridId(gridId)
                .setRow(row)
                .setPosition(position)
                .build()
        );
    }

    public void sort(SortOrder order, int col) throws SynurangDesktopBridge.SynurangBridgeException {
        client.sort(
            SortRequest.newBuilder()
                .setGridId(gridId)
                .addSortColumns(SortColumn.newBuilder().setCol(col).setOrder(order))
                .build()
        );
    }

    public Empty sort(SortRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.sort(request.toBuilder().setGridId(gridId).build());
    }

    public Empty subtotal(SubtotalRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.subtotal(request.toBuilder().setGridId(gridId).build());
    }

    public void subtotal(
        AggregateType aggregateType,
        int groupOnCol,
        int aggregateCol,
        String caption,
        long backColor,
        long foreColor,
        boolean addOutline
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        client.subtotal(
            SubtotalRequest.newBuilder()
                .setGridId(gridId)
                .setAggregate(aggregateType)
                .setGroupOnCol(groupOnCol)
                .setAggregateCol(aggregateCol)
                .setCaption(caption == null ? "" : caption)
                .setBackColor((int) backColor)
                .setForeColor((int) foreColor)
                .setAddOutline(addOutline)
                .build()
        );
    }

    public Empty autoSize(AutoSizeRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.autoSize(request.toBuilder().setGridId(gridId).build());
    }

    public void autoSize(int colFrom, int colTo, boolean equal, int maxWidth) throws SynurangDesktopBridge.SynurangBridgeException {
        client.autoSize(
            AutoSizeRequest.newBuilder()
                .setGridId(gridId)
                .setColFrom(colFrom)
                .setColTo(colTo)
                .setEqual(equal)
                .setMaxWidth(maxWidth)
                .build()
        );
    }

    public Empty outline(OutlineRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.outline(request.toBuilder().setGridId(gridId).build());
    }

    public void outline(int level) throws SynurangDesktopBridge.SynurangBridgeException {
        client.outline(
            OutlineRequest.newBuilder()
                .setGridId(gridId)
                .setLevel(level)
                .build()
        );
    }

    public NodeInfo getNode(GetNodeRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.getNode(request.toBuilder().setGridId(gridId).build());
    }

    public NodeInfo getNode(int row, NodeRelation relation) throws SynurangDesktopBridge.SynurangBridgeException {
        GetNodeRequest.Builder builder = GetNodeRequest.newBuilder()
            .setGridId(gridId)
            .setRow(row);
        if (relation != null) {
            builder.setRelation(relation);
        }
        return client.getNode(builder.build());
    }

    public FindResponse find(FindRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.find(request.toBuilder().setGridId(gridId).build());
    }

    public int findRow(String text, int col, int startRow, boolean caseSensitive) throws SynurangDesktopBridge.SynurangBridgeException {
        return client.find(
            FindRequest.newBuilder()
                .setGridId(gridId)
                .setCol(col)
                .setStartRow(startRow)
                .setTextQuery(
                    TextQuery.newBuilder()
                        .setText(text)
                        .setCaseSensitive(caseSensitive)
                        .setFullMatch(false)
                        .build()
                )
                .build()
        ).getRow();
    }

    public int findRowByRegex(String pattern, int col, int startRow) throws SynurangDesktopBridge.SynurangBridgeException {
        return client.find(
            FindRequest.newBuilder()
                .setGridId(gridId)
                .setCol(col)
                .setStartRow(startRow)
                .setRegexQuery(RegexQuery.newBuilder().setPattern(pattern).build())
                .build()
        ).getRow();
    }

    public AggregateResponse aggregate(AggregateRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.aggregate(request.toBuilder().setGridId(gridId).build());
    }

    public double aggregate(AggregateType type, int row1, int col1, int row2, int col2) throws SynurangDesktopBridge.SynurangBridgeException {
        return client.aggregate(
            AggregateRequest.newBuilder()
                .setGridId(gridId)
                .setAggregate(type)
                .setRow1(row1)
                .setCol1(col1)
                .setRow2(row2)
                .setCol2(col2)
                .build()
        ).getValue();
    }

    public CellRange getMergedRange(GetMergedRangeRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.getMergedRange(request.toBuilder().setGridId(gridId).build());
    }

    public CellRange getMergedRange(int row, int col) throws SynurangDesktopBridge.SynurangBridgeException {
        return client.getMergedRange(
            GetMergedRangeRequest.newBuilder()
                .setGridId(gridId)
                .setRow(row)
                .setCol(col)
                .build()
        );
    }

    public void mergeCells(int row1, int col1, int row2, int col2) throws SynurangDesktopBridge.SynurangBridgeException {
        client.mergeCells(
            MergeCellsRequest.newBuilder()
                .setGridId(gridId)
                .setRange(CellRange.newBuilder()
                    .setRow1(row1)
                    .setCol1(col1)
                    .setRow2(row2)
                    .setCol2(col2)
                    .build())
                .build()
        );
    }

    public void unmergeCells(int row1, int col1, int row2, int col2) throws SynurangDesktopBridge.SynurangBridgeException {
        client.unmergeCells(
            UnmergeCellsRequest.newBuilder()
                .setGridId(gridId)
                .setRange(CellRange.newBuilder()
                    .setRow1(row1)
                    .setCol1(col1)
                    .setRow2(row2)
                    .setCol2(col2)
                    .build())
                .build()
        );
    }

    public MergedRegionsResponse getMergedRegions() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.getMergedRegions(
            GridHandle.newBuilder()
                .setId(gridId)
                .build()
        );
    }

    @Override
    public void sortByColumn(int col, boolean ascending) throws SynurangDesktopBridge.SynurangBridgeException {
        sort(
            ascending ? SortOrder.SORT_GENERIC_ASCENDING : SortOrder.SORT_GENERIC_DESCENDING,
            col
        );
    }

    @Override
    public void select(int row1, int col1, int row2, int col2) throws SynurangDesktopBridge.SynurangBridgeException {
        client.select(buildSingleRangeSelectRequest(row1, col1, row2, col2, false));
    }

    public Empty select(SelectRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.select(request.toBuilder().setGridId(gridId).build());
    }

    public EditState edit(EditCommand request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.edit(request.toBuilder().setGridId(gridId).build());
    }

    public Empty clear(ClearRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.clear(request.toBuilder().setGridId(gridId).build());
    }

    public void clear(ClearScope scope, ClearRegion region) throws SynurangDesktopBridge.SynurangBridgeException {
        client.clear(
            ClearRequest.newBuilder()
                .setGridId(gridId)
                .setScope(scope)
                .setRegion(region)
                .build()
        );
    }

    public SelectionState getSelection() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.getSelection(handle());
    }

    @Override
    public GridSelection getSelectionState() throws SynurangDesktopBridge.SynurangBridgeException {
        SelectionState sel = getSelection();
        int[] end = selectionEnd(sel);
        return new GridSelection(
            sel.getActiveRow(),
            sel.getActiveCol(),
            end[0],
            end[1],
            sel.getTopRow()
        );
    }

    public void setRendererModeCpu() throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setRendering(
                    RenderConfig.newBuilder().setRendererMode(RendererMode.RENDERER_CPU).build()
                )
                .build()
        );
    }

    /**
     * GPU stub for future desktop implementation.
     */
    public void setRendererModeGpuStub() {
        throw new UnsupportedOperationException("Desktop GPU path is not implemented yet. CPU mode only.");
    }

    @Override
    public void setRendererBackend(RendererBackend backend) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(backend, "backend");
        switch (backend) {
            case CPU:
                setRendererModeCpu();
                return;
            case GPU:
                setRendererModeGpuStub();
                return;
            case AUTO:
                // Desktop host is currently CPU-only; AUTO is treated as CPU fallback.
                setRendererModeCpu();
                return;
            default:
                throw new IllegalArgumentException("Unknown renderer backend: " + backend);
        }
    }

    @Override
    public RendererBackend getRendererBackend() throws SynurangDesktopBridge.SynurangBridgeException {
        RendererMode mode = getConfig().getRendering().getRendererMode();
        switch (mode) {
            case RENDERER_CPU:
                return RendererBackend.CPU;
            case RENDERER_GPU:
                return RendererBackend.GPU;
            case RENDERER_AUTO:
                return RendererBackend.CPU;
            case UNRECOGNIZED:
            default:
                return RendererBackend.CPU;
        }
    }

    public void setDebugOverlay(boolean enabled) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setRendering(RenderConfig.newBuilder().setDebugOverlay(enabled).build())
                .build()
        );
    }

    public void setScrollBars(ScrollBarsMode mode) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(mode, "mode");
        configure(
            GridConfig.newBuilder()
                .setScrolling(ScrollConfig.newBuilder().setScrollbars(mode).build())
                .build()
        );
    }

    public void setFlingEnabled(boolean enabled) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setScrolling(ScrollConfig.newBuilder().setFlingEnabled(enabled).build())
                .build()
        );
    }

    @Override
    public void setRedraw(boolean enabled) throws SynurangDesktopBridge.SynurangBridgeException {
        client.setRedraw(
            SetRedrawRequest.newBuilder()
                .setGridId(gridId)
                .setEnabled(enabled)
                .build()
        );
    }

    public Empty setRedraw(SetRedrawRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.setRedraw(request.toBuilder().setGridId(gridId).build());
    }

    public Empty resizeViewport(ResizeViewportRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.resizeViewport(request.toBuilder().setGridId(gridId).build());
    }

    public void resizeViewport(int width, int height) throws SynurangDesktopBridge.SynurangBridgeException {
        client.resizeViewport(
            ResizeViewportRequest.newBuilder()
                .setGridId(gridId)
                .setWidth(width)
                .setHeight(height)
                .build()
        );
    }

    @Override
    public void refresh() throws SynurangDesktopBridge.SynurangBridgeException {
        client.refresh(handle());
    }

    public Empty loadDemo(LoadDemoRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.loadDemo(request.toBuilder().setGridId(gridId).build());
    }

    public void loadDemo(String demoName) throws SynurangDesktopBridge.SynurangBridgeException {
        client.loadDemo(
            LoadDemoRequest.newBuilder()
                .setGridId(gridId)
                .setDemo(demoName)
                .build()
        );
    }

    public ClipboardResponse copy() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.clipboard(
            ClipboardCommand.newBuilder()
                .setGridId(gridId)
                .setCopy(ClipboardCopy.newBuilder().build())
                .build()
        );
    }

    public ClipboardResponse cut() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.clipboard(
            ClipboardCommand.newBuilder()
                .setGridId(gridId)
                .setCut(ClipboardCut.newBuilder().build())
                .build()
        );
    }

    public void paste(String text) throws SynurangDesktopBridge.SynurangBridgeException {
        client.clipboard(
            ClipboardCommand.newBuilder()
                .setGridId(gridId)
                .setPaste(ClipboardPaste.newBuilder().setText(text).build())
                .build()
        );
    }

    public void deleteSelection() throws SynurangDesktopBridge.SynurangBridgeException {
        client.clipboard(
            ClipboardCommand.newBuilder()
                .setGridId(gridId)
                .setDelete(ClipboardDelete.newBuilder().build())
                .build()
        );
    }

    public ClipboardResponse clipboard(ClipboardCommand request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.clipboard(request.toBuilder().setGridId(gridId).build());
    }

    public ExportResponse exportGrid(ExportRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.exportGrid(request.toBuilder().setGridId(gridId).build());
    }

    public ExportResponse saveGrid(ExportFormat format, ExportScope scope) throws SynurangDesktopBridge.SynurangBridgeException {
        return client.exportGrid(
            ExportRequest.newBuilder()
                .setGridId(gridId)
                .setFormat(format)
                .setScope(scope)
                .build()
        );
    }

    public Empty importGrid(ImportRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.importGrid(request.toBuilder().setGridId(gridId).build());
    }

    public void loadGrid(byte[] data, ExportFormat format, ExportScope scope) throws SynurangDesktopBridge.SynurangBridgeException {
        ImportRequest.Builder builder = ImportRequest.newBuilder()
            .setGridId(gridId)
            .setFormat(format)
            .setScope(scope);
        if (data != null && data.length > 0) {
            builder.setData(ByteString.copyFrom(data));
        }
        client.importGrid(builder.build());
    }

    public PrintResponse printGrid(PrintRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.printGrid(request.toBuilder().setGridId(gridId).build());
    }

    public ArchiveResponse archive(ArchiveRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.archive(request.toBuilder().setGridId(gridId).build());
    }

    public ArchiveResponse archive(
        ArchiveRequest.Action action,
        String name,
        byte[] data
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        ArchiveRequest.Builder builder = ArchiveRequest.newBuilder()
            .setGridId(gridId)
            .setAction(action)
            .setName(name == null ? "" : name);
        if (data != null && data.length > 0) {
            builder.setData(ByteString.copyFrom(data));
        }
        return client.archive(builder.build());
    }

    public VolvoxGridDesktopClient.RenderSession openRenderSession() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.openRenderSession();
    }

    public VolvoxGridDesktopClient.RenderSession renderSession() throws SynurangDesktopBridge.SynurangBridgeException {
        return openRenderSession();
    }

    public VolvoxGridDesktopClient.EventStream openEventStream() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.openEventStream(handle());
    }

    public VolvoxGridDesktopClient.EventStream eventStream() throws SynurangDesktopBridge.SynurangBridgeException {
        return openEventStream();
    }

    public GridConfig getConfig() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.getConfig(handle());
    }

    private GridHandle handle() {
        return GridHandle.newBuilder().setId(gridId).build();
    }

    private SelectRequest buildSingleRangeSelectRequest(
        int activeRow,
        int activeCol,
        int rowEnd,
        int colEnd,
        boolean show
    ) {
        CellRange range = CellRange.newBuilder()
            .setRow1(Math.min(activeRow, rowEnd))
            .setCol1(Math.min(activeCol, colEnd))
            .setRow2(Math.max(activeRow, rowEnd))
            .setCol2(Math.max(activeCol, colEnd))
            .build();
        return SelectRequest.newBuilder()
            .setGridId(gridId)
            .setActiveRow(activeRow)
            .setActiveCol(activeCol)
            .addRanges(range)
            .setShow(show)
            .build();
    }

    private static int[] selectionEnd(SelectionState sel) {
        if (sel.getRangesCount() <= 0) {
            return new int[] { sel.getActiveRow(), sel.getActiveCol() };
        }
        CellRange r = sel.getRanges(0);
        if (r.getRow1() == sel.getActiveRow() && r.getCol1() == sel.getActiveCol()) {
            return new int[] { r.getRow2(), r.getCol2() };
        }
        if (r.getRow2() == sel.getActiveRow() && r.getCol2() == sel.getActiveCol()) {
            return new int[] { r.getRow1(), r.getCol1() };
        }
        return new int[] { r.getRow2(), r.getCol2() };
    }

    public Empty configure(ConfigureRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.configure(request.toBuilder().setGridId(gridId).build());
    }

    public void configure(GridConfig config) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            ConfigureRequest.newBuilder()
                .setGridId(gridId)
                .setConfig(config)
                .build()
        );
    }

    public static final class CellText {
        public final int row;
        public final int col;
        public final String text;

        public CellText(int row, int col, String text) {
            this.row = row;
            this.col = col;
            this.text = text;
        }
    }
}
