package io.github.ivere27.volvoxgrid.desktop;

import com.google.protobuf.ByteString;
import io.github.ivere27.volvoxgrid.*;
import io.github.ivere27.volvoxgrid.common.VolvoxGridController;
import io.github.ivere27.volvoxgrid.common.GridCellText;
import io.github.ivere27.volvoxgrid.common.GridCellRange;
import io.github.ivere27.volvoxgrid.common.GridSelection;
import io.github.ivere27.volvoxgrid.common.RendererBackend;
import java.util.ArrayList;
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
            .setWidth(DEFAULT_ROW_INDICATOR_WIDTH_PX)
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

    public static IndicatorsConfig defaultIndicatorsConfig() {
        return IndicatorsConfig.newBuilder()
            .setRowStart(defaultRowIndicatorStartConfig())
            .setColTop(defaultColIndicatorTopConfig())
            .build();
    }

    public static VolvoxGridDesktopController create(
        VolvoxGridDesktopClient client,
        CreateRequest request
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(client, "client");
        Objects.requireNonNull(request, "request");
        CreateResponse response = client.create(request);
        return new VolvoxGridDesktopController(client, response.getGridId());
    }

    public VolvoxGridDesktopController(VolvoxGridDesktopClient client, long gridId) {
        this.client = Objects.requireNonNull(client, "client");
        this.gridId = gridId;
    }

    public long getGridId() {
        return gridId;
    }

    public void destroy() throws SynurangDesktopBridge.SynurangBridgeException {
        client.destroy(DestroyRequest.newBuilder().setGridId(gridId).build());
    }

    private int readRowCount() throws SynurangDesktopBridge.SynurangBridgeException {
        return getConfig().getLayout().getRows();
    }

    private void writeRowCount(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setRows(value).build())
                .build()
        );
    }

    private int readColCount() throws SynurangDesktopBridge.SynurangBridgeException {
        return getConfig().getLayout().getCols();
    }

    private void writeColCount(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setCols(value).build())
                .build()
        );
    }

    private int readFrozenRowCount() throws SynurangDesktopBridge.SynurangBridgeException {
        return getConfig().getLayout().getFrozenRows();
    }

    private void writeFrozenRowCount(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setFrozenRows(value).build())
                .build()
        );
    }

    private int readFrozenColCount() throws SynurangDesktopBridge.SynurangBridgeException {
        return getConfig().getLayout().getFrozenCols();
    }

    private void writeFrozenColCount(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setFrozenCols(value).build())
                .build()
        );
    }

    @Override
    public boolean getShowColumnHeaders() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        return config.hasIndicators()
            && config.getIndicators().hasColTop()
            && config.getIndicators().getColTop().getVisible();
    }

    public boolean isShowColumnHeaders() throws SynurangDesktopBridge.SynurangBridgeException {
        return getShowColumnHeaders();
    }

    @Override
    public void setShowColumnHeaders(boolean value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setIndicators(
                    IndicatorsConfig.newBuilder()
                        .setColTop(
                            ColIndicatorConfig.newBuilder()
                                .setVisible(value)
                                .build()
                        )
                        .build()
                )
                .build()
        );
    }

    @Override
    public int getColumnIndicatorTopModeBits() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        if (!config.hasIndicators() || !config.getIndicators().hasColTop()) {
            return 0;
        }
        return config.getIndicators().getColTop().getModeBits();
    }

    @Override
    public void setColumnIndicatorTopModeBits(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setIndicators(
                    IndicatorsConfig.newBuilder()
                        .setColTop(
                            ColIndicatorConfig.newBuilder()
                                .setModeBits(value)
                                .build()
                        )
                        .build()
                )
                .build()
        );
    }

    @Override
    public int getColumnIndicatorTopRowCount() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        if (!config.hasIndicators() || !config.getIndicators().hasColTop()) {
            return 0;
        }
        return config.getIndicators().getColTop().getBandRows();
    }

    @Override
    public void setColumnIndicatorTopRowCount(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        int normalized = Math.max(0, value);
        configure(
            GridConfig.newBuilder()
                .setIndicators(
                    IndicatorsConfig.newBuilder()
                        .setColTop(
                            ColIndicatorConfig.newBuilder()
                                .setBandRows(normalized)
                                .build()
                        )
                        .build()
                )
                .build()
        );
    }

    @Override
    public boolean getShowRowIndicator() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        return config.hasIndicators()
            && config.getIndicators().hasRowStart()
            && config.getIndicators().getRowStart().getVisible();
    }

    public boolean isShowRowIndicator() throws SynurangDesktopBridge.SynurangBridgeException {
        return getShowRowIndicator();
    }

    @Override
    public void setShowRowIndicator(boolean value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setIndicators(
                    IndicatorsConfig.newBuilder()
                        .setRowStart(
                            RowIndicatorConfig.newBuilder()
                                .setVisible(value)
                                .build()
                        )
                        .build()
                )
                .build()
        );
    }

    @Override
    public int getRowIndicatorStartModeBits() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        if (!config.hasIndicators() || !config.getIndicators().hasRowStart()) {
            return 0;
        }
        return config.getIndicators().getRowStart().getModeBits();
    }

    @Override
    public void setRowIndicatorStartModeBits(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setIndicators(
                    IndicatorsConfig.newBuilder()
                        .setRowStart(
                            RowIndicatorConfig.newBuilder()
                                .setModeBits(value)
                                .build()
                        )
                        .build()
                )
                .build()
        );
    }

    @Override
    public int getRowIndicatorStartWidth() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        if (!config.hasIndicators() || !config.getIndicators().hasRowStart()) {
            return DEFAULT_ROW_INDICATOR_WIDTH_PX;
        }
        return config.getIndicators().getRowStart().getWidth();
    }

    @Override
    public void setRowIndicatorStartWidth(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setIndicators(
                    IndicatorsConfig.newBuilder()
                        .setRowStart(
                            RowIndicatorConfig.newBuilder()
                                .setWidth(Math.max(1, value))
                                .build()
                        )
                        .build()
                )
                .build()
        );
    }

    @Override
    public int rowCount() {
        return readRowCount();
    }

    @Override
    public void setRowCount(int value) {
        writeRowCount(value);
    }

    @Override
    public int colCount() {
        return readColCount();
    }

    @Override
    public void setColCount(int value) {
        writeColCount(value);
    }

    @Override
    public int frozenRowCount() {
        return readFrozenRowCount();
    }

    @Override
    public void setFrozenRowCount(int value) {
        writeFrozenRowCount(value);
    }

    @Override
    public int frozenColCount() {
        return readFrozenColCount();
    }

    @Override
    public void setFrozenColCount(int value) {
        writeFrozenColCount(value);
    }

    public boolean editable() throws SynurangDesktopBridge.SynurangBridgeException {
        return editTrigger() != EditTrigger.EDIT_TRIGGER_NONE;
    }

    public void setEditable(boolean editable) throws SynurangDesktopBridge.SynurangBridgeException {
        EditTrigger current = editTrigger();
        EditTrigger target = editable
            ? (current == EditTrigger.EDIT_TRIGGER_NONE ? EditTrigger.EDIT_TRIGGER_KEY_CLICK : current)
            : EditTrigger.EDIT_TRIGGER_NONE;
        setEditTrigger(target);
    }

    public EditTrigger editTrigger() throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = getConfig();
        if (!config.hasEditing()) {
            return EditTrigger.EDIT_TRIGGER_NONE;
        }
        return config.getEditing().getTrigger();
    }

    public void setEditTrigger(EditTrigger value) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(value, "value");
        configure(
            GridConfig.newBuilder()
                .setEditing(EditConfig.newBuilder().setTrigger(value).build())
                .build()
        );
    }

    public void beginEdit(int row, int col) throws SynurangDesktopBridge.SynurangBridgeException {
        client.edit(
            EditCommand.newBuilder()
                .setGridId(gridId)
                .setStart(EditStart.newBuilder().setRow(row).setCol(col).build())
                .build()
        );
    }

    public void commitEdit(String text) throws SynurangDesktopBridge.SynurangBridgeException {
        EditCommit.Builder commit = EditCommit.newBuilder();
        if (text != null) {
            commit.setText(text);
        }
        client.edit(
            EditCommand.newBuilder()
                .setGridId(gridId)
                .setCommit(commit.build())
                .build()
        );
    }

    public void cancelEdit() throws SynurangDesktopBridge.SynurangBridgeException {
        client.edit(
            EditCommand.newBuilder()
                .setGridId(gridId)
                .setCancel(EditCancel.newBuilder().build())
                .build()
        );
    }

    @Override
    public void setCellText(int row, int col, String text) throws SynurangDesktopBridge.SynurangBridgeException {
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
    public String getCellText(int row, int col) throws SynurangDesktopBridge.SynurangBridgeException {
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
    public void setCells(List<GridCellText> cells) throws SynurangDesktopBridge.SynurangBridgeException {
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

    public void setCellTextEntries(List<CellText> cells) throws SynurangDesktopBridge.SynurangBridgeException {
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

    public SchemaResponse getSchema() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.getSchema(GetSchemaRequest.newBuilder().setGridId(gridId).build());
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

    public DefineColumnsResponse defineColumns(DefineColumnsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.defineColumns(request.toBuilder().setGridId(gridId).build());
    }

    public DefineRowsResponse defineRows(DefineRowsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.defineRows(request.toBuilder().setGridId(gridId).build());
    }

    public InsertRowsResponse insertRows(InsertRowsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
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

    public RemoveRowsResponse removeRows(RemoveRowsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
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

    public MoveColumnResponse moveColumn(MoveColumnRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
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

    public MoveRowResponse moveRow(MoveRowRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
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
        sort(order, col, null);
    }

    public void sort(SortOrder order, int col, SortType type) throws SynurangDesktopBridge.SynurangBridgeException {
        SortColumn.Builder sortColumn = SortColumn.newBuilder().setCol(col).setOrder(order);
        if (type != null) {
            sortColumn.setType(type);
        }
        client.sort(
            SortRequest.newBuilder()
                .setGridId(gridId)
                .addSortColumns(sortColumn)
                .build()
        );
    }

    public SortResponse sort(SortRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.sort(request.toBuilder().setGridId(gridId).build());
    }

    public SubtotalResult subtotal(SubtotalRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.subtotal(request.toBuilder().setGridId(gridId).build());
    }

    public SubtotalResult subtotal(
        AggregateType aggregateType,
        int groupOnCol,
        int aggregateCol,
        String caption,
        long backColor,
        long foreColor,
        boolean addOutline
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        return subtotal(
            aggregateType,
            groupOnCol,
            aggregateCol,
            caption,
            backColor,
            foreColor,
            addOutline,
            null
        );
    }

    public SubtotalResult subtotal(
        AggregateType aggregateType,
        int groupOnCol,
        int aggregateCol,
        String caption,
        long backColor,
        long foreColor,
        boolean addOutline,
        Font font
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        SubtotalRequest.Builder builder = SubtotalRequest.newBuilder()
            .setGridId(gridId)
            .setAggregate(aggregateType)
            .setGroupOnCol(groupOnCol)
            .setAggregateCol(aggregateCol)
            .setCaption(caption == null ? "" : caption)
            .setBackground((int) backColor)
            .setForeground((int) foreColor)
            .setAddOutline(addOutline);
        if (font != null) {
            builder.setFont(font);
        }
        return client.subtotal(builder.build());
    }

    public AutoSizeResponse autoSize(AutoSizeRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
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

    public OutlineResponse outline(OutlineRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
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
            GetMergedRegionsRequest.newBuilder()
                .setGridId(gridId)
                .build()
        );
    }

    @Override
    public void sort(int col, boolean ascending) throws SynurangDesktopBridge.SynurangBridgeException {
        sort(col, ascending, null);
    }

    public void sort(int col, boolean ascending, SortType type) throws SynurangDesktopBridge.SynurangBridgeException {
        sort(
            ascending ? SortOrder.SORT_ASCENDING : SortOrder.SORT_DESCENDING,
            col,
            type
        );
    }

    @Override
    public void selectRange(int row1, int col1, int row2, int col2) throws SynurangDesktopBridge.SynurangBridgeException {
        client.select(buildSingleRangeSelectRequest(row1, col1, row2, col2, false));
    }

    public void selectCell(int row, int col, boolean show) throws SynurangDesktopBridge.SynurangBridgeException {
        client.select(buildSingleRangeSelectRequest(row, col, row, col, show));
    }

    @Override
    public void selectRanges(List<GridCellRange> ranges) throws SynurangDesktopBridge.SynurangBridgeException {
        VolvoxGridController.super.selectRanges(ranges);
    }

    @Override
    public void selectRanges(
        List<GridCellRange> ranges,
        int activeRow,
        int activeCol
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        if (ranges == null || ranges.isEmpty()) {
            return;
        }
        client.select(buildSelectRequest(ranges, activeRow, activeCol, false));
    }

    public SelectResponse applySelection(SelectRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.select(request.toBuilder().setGridId(gridId).build());
    }

    public EditState edit(EditCommand request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.edit(request.toBuilder().setGridId(gridId).build());
    }

    public EditState getEditState() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.edit(
            EditCommand.newBuilder()
                .setGridId(gridId)
                .build()
        );
    }

    public ClearResponse clear(ClearRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
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

    @Override
    public int cursorRow() throws SynurangDesktopBridge.SynurangBridgeException {
        return selectionState().getActiveRow();
    }

    @Override
    public void setCursorRow(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        int currentCol;
        try {
            currentCol = selectionState().getActiveCol();
        } catch (SynurangDesktopBridge.SynurangBridgeException ex) {
            currentCol = 0;
        }
        client.select(buildSingleRangeSelectRequest(value, currentCol, value, currentCol, false));
    }

    @Override
    public int cursorCol() throws SynurangDesktopBridge.SynurangBridgeException {
        return selectionState().getActiveCol();
    }

    @Override
    public void setCursorCol(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        int currentRow;
        try {
            currentRow = selectionState().getActiveRow();
        } catch (SynurangDesktopBridge.SynurangBridgeException ex) {
            currentRow = 0;
        }
        client.select(buildSingleRangeSelectRequest(currentRow, value, currentRow, value, false));
    }

    public SelectionState selectionState() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.getSelection(GetSelectionRequest.newBuilder().setGridId(gridId).build());
    }

    public SelectionMode getSelectionMode() throws SynurangDesktopBridge.SynurangBridgeException {
        return getConfig().getSelection().getMode();
    }

    public void setSelectionMode(SelectionMode mode) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(mode, "mode");
        configure(
            GridConfig.newBuilder()
                .setSelection(SelectionConfig.newBuilder().setMode(mode).build())
                .build()
        );
    }

    public void setActiveCellStyle(HighlightStyle style) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(style, "style");
        configure(
            GridConfig.newBuilder()
                .setSelection(SelectionConfig.newBuilder().setActiveCellStyle(style).build())
                .build()
        );
    }

    @Override
    public GridSelection getSelection() throws SynurangDesktopBridge.SynurangBridgeException {
        SelectionState sel = selectionState();
        int[] end = selectionEnd(sel);
        return new GridSelection(
            sel.getActiveRow(),
            sel.getActiveCol(),
            end[0],
            end[1],
            sel.getTopRow(),
            sel.getLeftCol(),
            sel.getBottomRow(),
            sel.getRightCol(),
            sel.getMouseRow(),
            sel.getMouseCol(),
            selectionRanges(sel)
        );
    }

    @Override
    public void clearSelection() throws SynurangDesktopBridge.SynurangBridgeException {
        SelectionState sel = selectionState();
        client.select(
            buildSingleRangeSelectRequest(
                sel.getActiveRow(),
                sel.getActiveCol(),
                sel.getActiveRow(),
                sel.getActiveCol(),
                false
            )
        );
    }

    @Override
    public void showCell(int row, int col) throws SynurangDesktopBridge.SynurangBridgeException {
        client.showCell(
            ShowCellRequest.newBuilder()
                .setGridId(gridId)
                .setRow(row)
                .setCol(col)
                .build()
        );
    }

    @Override
    public int topRow() throws SynurangDesktopBridge.SynurangBridgeException {
        return selectionState().getTopRow();
    }

    @Override
    public void setTopRow(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        client.setTopRow(
            SetRowRequest.newBuilder()
                .setGridId(gridId)
                .setRow(value)
                .build()
        );
    }

    @Override
    public int leftCol() throws SynurangDesktopBridge.SynurangBridgeException {
        return selectionState().getLeftCol();
    }

    @Override
    public void setLeftCol(int value) throws SynurangDesktopBridge.SynurangBridgeException {
        client.setLeftCol(
            SetColRequest.newBuilder()
                .setGridId(gridId)
                .setCol(value)
                .build()
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

    public void setRendererModeTui() throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setRendering(
                    RenderConfig.newBuilder().setRendererMode(RendererMode.RENDERER_TUI).build()
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
    public RendererBackend rendererBackend() throws SynurangDesktopBridge.SynurangBridgeException {
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

    public void setScrollBlit(boolean enabled) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setRendering(RenderConfig.newBuilder().setScrollBlit(enabled).build())
                .build()
        );
    }

    @Override
    public long renderLayerMask() throws SynurangDesktopBridge.SynurangBridgeException {
        RenderConfig rendering = getConfig().getRendering();
        return rendering.hasRenderLayerMask() ? rendering.getRenderLayerMask() : -1L;
    }

    @Override
    public void setRenderLayerMask(long mask) throws SynurangDesktopBridge.SynurangBridgeException {
        configure(
            GridConfig.newBuilder()
                .setRendering(RenderConfig.newBuilder().setRenderLayerMask(mask).build())
                .build()
        );
    }

    public boolean isRenderLayerEnabled(RenderLayerBit layer) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(layer, "layer");
        return VolvoxGridController.super.isRenderLayerEnabled(layer.getNumber());
    }

    public void setRenderLayerEnabled(RenderLayerBit layer, boolean enabled) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(layer, "layer");
        VolvoxGridController.super.setRenderLayerEnabled(layer.getNumber(), enabled);
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

    public SetRedrawResponse setRedraw(SetRedrawRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.setRedraw(request.toBuilder().setGridId(gridId).build());
    }

    public ResizeViewportResponse resizeViewport(ResizeViewportRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
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
        client.refresh(RefreshRequest.newBuilder().setGridId(gridId).build());
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

    public LoadDemoResponse loadDemo(LoadDemoRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
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

    public GetDemoDataResponse getDemoData(GetDemoDataRequest request)
        throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.getDemoData(request);
    }

    public byte[] getDemoData(String demoName) throws SynurangDesktopBridge.SynurangBridgeException {
        return client.getDemoData(
            GetDemoDataRequest.newBuilder()
                .setDemo(demoName)
                .build()
        ).getData().toByteArray();
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

    public LoadDataResult loadData(LoadDataRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(request, "request");
        return client.loadData(request.toBuilder().setGridId(gridId).build());
    }

    public LoadDataResult loadData(byte[] data) throws SynurangDesktopBridge.SynurangBridgeException {
        return loadData(data, null);
    }

    public LoadDataResult loadData(byte[] data, LoadDataOptions options) throws SynurangDesktopBridge.SynurangBridgeException {
        LoadDataRequest.Builder builder = LoadDataRequest.newBuilder()
            .setGridId(gridId);
        if (data != null && data.length > 0) {
            builder.setData(ByteString.copyFrom(data));
        }
        if (options != null) {
            builder.setOptions(options);
        }
        return client.loadData(builder.build());
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

    public VolvoxGridDesktopTerminalSession openTerminalSession()
        throws SynurangDesktopBridge.SynurangBridgeException {
        setRendererModeTui();
        return new VolvoxGridDesktopTerminalSession(client, gridId);
    }

    public VolvoxGridDesktopClient.EventStream openEventStream() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.openEventStream(EventStreamRequest.newBuilder().setGridId(gridId).build());
    }

    public VolvoxGridDesktopClient.EventStream eventStream() throws SynurangDesktopBridge.SynurangBridgeException {
        return openEventStream();
    }

    public GridConfig getConfig() throws SynurangDesktopBridge.SynurangBridgeException {
        return client.getConfig(GetConfigRequest.newBuilder().setGridId(gridId).build());
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

    private SelectRequest buildSelectRequest(
        List<GridCellRange> ranges,
        int activeRow,
        int activeCol,
        boolean show
    ) {
        SelectRequest.Builder builder = SelectRequest.newBuilder()
            .setGridId(gridId)
            .setActiveRow(activeRow)
            .setActiveCol(activeCol)
            .setShow(show);
        for (GridCellRange range : ranges) {
            builder.addRanges(
                CellRange.newBuilder()
                    .setRow1(Math.min(range.getRow1(), range.getRow2()))
                    .setCol1(Math.min(range.getCol1(), range.getCol2()))
                    .setRow2(Math.max(range.getRow1(), range.getRow2()))
                    .setCol2(Math.max(range.getCol1(), range.getCol2()))
                    .build()
            );
        }
        return builder.build();
    }

    private static int[] selectionEnd(SelectionState sel) {
        if (sel.getRangesCount() <= 0) {
            return new int[] { sel.getActiveRow(), sel.getActiveCol() };
        }
        CellRange r = sel.getRangesList().stream()
            .filter(range ->
                (range.getRow1() == sel.getActiveRow() && range.getCol1() == sel.getActiveCol())
                || (range.getRow2() == sel.getActiveRow() && range.getCol2() == sel.getActiveCol()))
            .findFirst()
            .orElse(sel.getRanges(0));
        if (r.getRow1() == sel.getActiveRow() && r.getCol1() == sel.getActiveCol()) {
            return new int[] { r.getRow2(), r.getCol2() };
        }
        if (r.getRow2() == sel.getActiveRow() && r.getCol2() == sel.getActiveCol()) {
            return new int[] { r.getRow1(), r.getCol1() };
        }
        return new int[] { r.getRow2(), r.getCol2() };
    }

    private static GridCellRange[] selectionRanges(SelectionState sel) {
        List<GridCellRange> ranges = new ArrayList<>(sel.getRangesCount());
        for (CellRange range : sel.getRangesList()) {
            ranges.add(new GridCellRange(
                range.getRow1(),
                range.getCol1(),
                range.getRow2(),
                range.getCol2()
            ));
        }
        return ranges.toArray(new GridCellRange[0]);
    }

    public ConfigureResponse configure(ConfigureRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
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
