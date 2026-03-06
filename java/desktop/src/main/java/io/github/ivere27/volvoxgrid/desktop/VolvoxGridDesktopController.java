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
    private static final int DEFAULT_ROW_INDICATOR_WIDTH_PX = 35;
    private static final int DEFAULT_COL_INDICATOR_BAND_ROWS = 1;
    private static final int DEFAULT_ROW_INDICATOR_MODE_BITS =
        RowIndicatorMode.ROW_INDICATOR_CURRENT.getNumber()
            | RowIndicatorMode.ROW_INDICATOR_SELECTION.getNumber();
    private static final int DEFAULT_COL_INDICATOR_MODE_BITS =
        ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT.getNumber()
            | ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH.getNumber();

    private final VolvoxGridDesktopClient client;
    private final long gridId;

    private static RowIndicatorConfig defaultRowIndicatorStartConfig() {
        return RowIndicatorConfig.newBuilder()
            .setVisible(false)
            .setWidthPx(DEFAULT_ROW_INDICATOR_WIDTH_PX)
            .setModeBits(DEFAULT_ROW_INDICATOR_MODE_BITS)
            .build();
    }

    private static ColIndicatorConfig defaultColIndicatorTopConfig() {
        return ColIndicatorConfig.newBuilder()
            .setVisible(true)
            .setBandRows(DEFAULT_COL_INDICATOR_BAND_ROWS)
            .setModeBits(DEFAULT_COL_INDICATOR_MODE_BITS)
            .build();
    }

    public static IndicatorBandsConfig defaultIndicatorBandsConfig() {
        return IndicatorBandsConfig.newBuilder()
            .setRowIndicatorStart(defaultRowIndicatorStartConfig())
            .setColIndicatorTop(defaultColIndicatorTopConfig())
            .build();
    }

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

    public int getFrozenRows() throws SynurangDesktopBridge.SynurangBridgeException {
        return getConfig().getLayout().getFrozenRows();
    }

    public void setFrozenRows(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setFrozenRows(value).build())
                .build()
        );
    }

    public int getFrozenCols() throws SynurangDesktopBridge.SynurangBridgeException {
        return getConfig().getLayout().getFrozenCols();
    }

    public void setFrozenCols(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setFrozenCols(value).build())
                .build()
        );
    }

    public boolean isShowColumnHeaders() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        return config.hasIndicatorBands()
            && config.getIndicatorBands().hasColIndicatorTop()
            && config.getIndicatorBands().getColIndicatorTop().getVisible();
    }

    public void setShowColumnHeaders(boolean value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setIndicatorBands(
                    IndicatorBandsConfig.newBuilder()
                        .setColIndicatorTop(
                            defaultColIndicatorTopConfig().toBuilder()
                                .setVisible(value)
                                .build()
                        )
                        .build()
                )
                .build()
        );
    }

    public int getColumnIndicatorTopModeBits() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        if (!config.hasIndicatorBands() || !config.getIndicatorBands().hasColIndicatorTop()) {
            return 0;
        }
        return config.getIndicatorBands().getColIndicatorTop().getModeBits();
    }

    public void setColumnIndicatorTopModeBits(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setIndicatorBands(
                    IndicatorBandsConfig.newBuilder()
                        .setColIndicatorTop(
                            ColIndicatorConfig.newBuilder()
                                .setVisible(value != 0)
                                .setModeBits(value)
                                .build()
                        )
                        .build()
                )
                .build()
        );
    }

    public int getColumnIndicatorTopRowCount() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        if (!config.hasIndicatorBands() || !config.getIndicatorBands().hasColIndicatorTop()) {
            return 0;
        }
        return config.getIndicatorBands().getColIndicatorTop().getBandRows();
    }

    public void setColumnIndicatorTopRowCount(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        int normalized = Math.max(0, value);
        configure(
            GridConfig.newBuilder()
                .setIndicatorBands(
                    IndicatorBandsConfig.newBuilder()
                        .setColIndicatorTop(
                            ColIndicatorConfig.newBuilder()
                                .setVisible(normalized != 0)
                                .setBandRows(normalized)
                                .build()
                        )
                        .build()
                )
                .build()
        );
    }

    public boolean isShowIndicator() throws SynurangDesktopBridge.SynurangBridgeException {
        return isShowRowIndicator();
    }

    public void setShowIndicator(boolean value) throws SynurangDesktopBridge.SynurangBridgeException {
        setShowRowIndicator(value);
    }

    public boolean isShowRowIndicator() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        return config.hasIndicatorBands()
            && config.getIndicatorBands().hasRowIndicatorStart()
            && config.getIndicatorBands().getRowIndicatorStart().getVisible();
    }

    public void setShowRowIndicator(boolean value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setIndicatorBands(
                    IndicatorBandsConfig.newBuilder()
                        .setRowIndicatorStart(
                            defaultRowIndicatorStartConfig().toBuilder()
                                .setVisible(value)
                                .build()
                        )
                        .build()
                )
                .build()
        );
    }

    public int getRowIndicatorStartModeBits() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        if (!config.hasIndicatorBands() || !config.getIndicatorBands().hasRowIndicatorStart()) {
            return 0;
        }
        return config.getIndicatorBands().getRowIndicatorStart().getModeBits();
    }

    public void setRowIndicatorStartModeBits(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setIndicatorBands(
                    IndicatorBandsConfig.newBuilder()
                        .setRowIndicatorStart(
                            RowIndicatorConfig.newBuilder()
                                .setVisible(value != 0)
                                .setModeBits(value)
                                .build()
                        )
                        .build()
                )
                .build()
        );
    }

    public int getRowIndicatorStartWidth() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        if (!config.hasIndicatorBands() || !config.getIndicatorBands().hasRowIndicatorStart()) {
            return DEFAULT_ROW_INDICATOR_WIDTH_PX;
        }
        return config.getIndicatorBands().getRowIndicatorStart().getWidthPx();
    }

    public void setRowIndicatorStartWidth(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setIndicatorBands(
                    IndicatorBandsConfig.newBuilder()
                        .setRowIndicatorStart(
                            RowIndicatorConfig.newBuilder()
                                .setWidthPx(Math.max(1, value))
                                .build()
                        )
                        .build()
                )
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
    public int frozenRowCount() {
        return getFrozenRows();
    }

    @Override
    public void setFrozenRowCount(int value) {
        setFrozenRows(value);
    }

    @Override
    public int frozenColCount() {
        return getFrozenCols();
    }

    @Override
    public void setFrozenColCount(int value) {
        setFrozenCols(value);
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

    public WriteResult updateCells(UpdateCellsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.updateCells(request.toBuilder().setGridId(gridId).build());
    }

    public CellsResponse getCells(GetCellsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.getCells(request.toBuilder().setGridId(gridId).build());
    }

    public DefineColumnsRequest getSchema() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.getSchema(handle());
    }

    public WriteResult loadTable(LoadTableRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.loadTable(request.toBuilder().setGridId(gridId).build());
    }

    public void loadTable(int rows, int cols, List<CellValue> values, boolean atomic) throws SynurangDesktopBridge.SynurangBridgeException {
        LoadTableRequest.Builder builder = LoadTableRequest.newBuilder()
            .setGridId(gridId)
            .setRows(rows)
            .setCols(cols)
            .setAtomic(atomic);
        if (values != null && !values.isEmpty()) {
            builder.addAllValues(values);
        }
        client.loadTable(builder.build());
    }

    /**
     * Fill a 2D matrix into the grid starting at the given offset.
     *
     * <p>When {@code resizeGrid} is true (the default), the grid is enlarged
     * if the data exceeds the current row/column count.  Redraw is suspended
     * for the duration so only a single repaint occurs at the end.</p>
     */
    public void setTableData(List<List<String>> data, int startRow, int startCol, boolean resizeGrid) throws SynurangDesktopBridge.SynurangBridgeException {
        if (data == null || data.isEmpty()) return;
        int mc = 0;
        for (List<String> row : data) {
            if (row.size() > mc) mc = row.size();
        }
        if (mc <= 0) return;
        final int maxCols = mc;

        withRedrawSuspended(() -> {
            if (resizeGrid) {
                int neededRows = startRow + data.size();
                int neededCols = startCol + maxCols;
                if (neededRows > getRows()) setRows(neededRows);
                if (neededCols > getCols()) setCols(neededCols);
            }

            UpdateCellsRequest.Builder builder = UpdateCellsRequest.newBuilder().setGridId(gridId);
            for (int r = 0; r < data.size(); r++) {
                List<String> row = data.get(r);
                for (int c = 0; c < row.size(); c++) {
                    builder.addCells(
                        CellUpdate.newBuilder()
                            .setRow(startRow + r)
                            .setCol(startCol + c)
                            .setValue(CellValue.newBuilder().setText(row.get(c)).build())
                            .build()
                    );
                }
            }
            client.updateCells(builder.build());
        });
    }

    /**
     * Fill a 2D matrix into the grid starting at row 0, column 0, resizing as needed.
     */
    public void setTableData(List<List<String>> data) throws SynurangDesktopBridge.SynurangBridgeException {
        setTableData(data, 0, 0, true);
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

    public void setColumnCaption(int col, String caption) throws SynurangDesktopBridge.SynurangBridgeException {
        client.defineColumns(
            DefineColumnsRequest.newBuilder()
                .setGridId(gridId)
                .addColumns(
                    ColumnDef.newBuilder()
                        .setIndex(col)
                        .setCaption(caption == null ? "" : caption)
                        .build()
                )
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

    /**
     * Run {@code action} while redraw is suspended, then re-enable and refresh.
     *
     * <p>This avoids per-call repaints when making many changes in a batch,
     * resulting in a single repaint at the end.</p>
     */
    public void withRedrawSuspended(Runnable action) throws SynurangDesktopBridge.SynurangBridgeException {
        withRedrawSuspended(action, true);
    }

    /**
     * Run {@code action} while redraw is suspended.
     *
     * @param action       the batch operations to run
     * @param refreshAfter whether to call {@link #refresh()} after re-enabling redraw
     */
    public void withRedrawSuspended(Runnable action, boolean refreshAfter) throws SynurangDesktopBridge.SynurangBridgeException {
        setRedraw(false);
        try {
            action.run();
        } finally {
            setRedraw(true);
            if (refreshAfter) {
                refresh();
            }
        }
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
