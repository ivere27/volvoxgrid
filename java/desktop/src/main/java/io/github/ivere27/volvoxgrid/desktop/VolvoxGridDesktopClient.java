package io.github.ivere27.volvoxgrid.desktop;

import com.google.protobuf.InvalidProtocolBufferException;
import com.google.protobuf.MessageLite;
import com.google.protobuf.Parser;
import io.github.ivere27.volvoxgrid.ClearRequest;
import io.github.ivere27.volvoxgrid.CellRange;
import io.github.ivere27.volvoxgrid.ClipboardCommand;
import io.github.ivere27.volvoxgrid.ClipboardResponse;
import io.github.ivere27.volvoxgrid.ConfigureRequest;
import io.github.ivere27.volvoxgrid.CreateRequest;
import io.github.ivere27.volvoxgrid.DefineColumnsRequest;
import io.github.ivere27.volvoxgrid.DefineRowsRequest;
import io.github.ivere27.volvoxgrid.EditCommand;
import io.github.ivere27.volvoxgrid.EditState;
import io.github.ivere27.volvoxgrid.Empty;
import io.github.ivere27.volvoxgrid.AggregateRequest;
import io.github.ivere27.volvoxgrid.AggregateResponse;
import io.github.ivere27.volvoxgrid.ArchiveRequest;
import io.github.ivere27.volvoxgrid.ArchiveResponse;
import io.github.ivere27.volvoxgrid.AutoSizeRequest;
import io.github.ivere27.volvoxgrid.CellsResponse;
import io.github.ivere27.volvoxgrid.ExportRequest;
import io.github.ivere27.volvoxgrid.ExportResponse;
import io.github.ivere27.volvoxgrid.FindRequest;
import io.github.ivere27.volvoxgrid.FindResponse;
import io.github.ivere27.volvoxgrid.GetCellsRequest;
import io.github.ivere27.volvoxgrid.GetMergedRangeRequest;
import io.github.ivere27.volvoxgrid.GetNodeRequest;
import io.github.ivere27.volvoxgrid.GridConfig;
import io.github.ivere27.volvoxgrid.MergeCellsRequest;
import io.github.ivere27.volvoxgrid.UnmergeCellsRequest;
import io.github.ivere27.volvoxgrid.MergedRegionsResponse;
import io.github.ivere27.volvoxgrid.GridEvent;
import io.github.ivere27.volvoxgrid.GridHandle;
import io.github.ivere27.volvoxgrid.ImportRequest;
import io.github.ivere27.volvoxgrid.InsertRowsRequest;
import io.github.ivere27.volvoxgrid.LoadArrayRequest;
import io.github.ivere27.volvoxgrid.LoadDemoRequest;
import io.github.ivere27.volvoxgrid.MoveColumnRequest;
import io.github.ivere27.volvoxgrid.MoveRowRequest;
import io.github.ivere27.volvoxgrid.NodeInfo;
import io.github.ivere27.volvoxgrid.OutlineRequest;
import io.github.ivere27.volvoxgrid.PrintRequest;
import io.github.ivere27.volvoxgrid.PrintResponse;
import io.github.ivere27.volvoxgrid.RenderInput;
import io.github.ivere27.volvoxgrid.RenderOutput;
import io.github.ivere27.volvoxgrid.RemoveRowsRequest;
import io.github.ivere27.volvoxgrid.ResizeViewportRequest;
import io.github.ivere27.volvoxgrid.SelectionState;
import io.github.ivere27.volvoxgrid.SetRedrawRequest;
import io.github.ivere27.volvoxgrid.SortRequest;
import io.github.ivere27.volvoxgrid.SubtotalRequest;
import io.github.ivere27.volvoxgrid.UpdateCellsRequest;
import java.util.Objects;

/**
 * Minimal desktop client for VolvoxGridService over Synurang bridge.
 */
public final class VolvoxGridDesktopClient {
    private static final String SERVICE = "VolvoxGridService";

    private static final String CREATE = "/volvoxgrid.v1.VolvoxGridService/Create";
    private static final String DESTROY = "/volvoxgrid.v1.VolvoxGridService/Destroy";
    private static final String CONFIGURE = "/volvoxgrid.v1.VolvoxGridService/Configure";
    private static final String GET_CONFIG = "/volvoxgrid.v1.VolvoxGridService/GetConfig";
    private static final String DEFINE_COLUMNS = "/volvoxgrid.v1.VolvoxGridService/DefineColumns";
    private static final String DEFINE_ROWS = "/volvoxgrid.v1.VolvoxGridService/DefineRows";
    private static final String INSERT_ROWS = "/volvoxgrid.v1.VolvoxGridService/InsertRows";
    private static final String REMOVE_ROWS = "/volvoxgrid.v1.VolvoxGridService/RemoveRows";
    private static final String MOVE_COLUMN = "/volvoxgrid.v1.VolvoxGridService/MoveColumn";
    private static final String MOVE_ROW = "/volvoxgrid.v1.VolvoxGridService/MoveRow";
    private static final String UPDATE_CELLS = "/volvoxgrid.v1.VolvoxGridService/UpdateCells";
    private static final String GET_CELLS = "/volvoxgrid.v1.VolvoxGridService/GetCells";
    private static final String LOAD_ARRAY = "/volvoxgrid.v1.VolvoxGridService/LoadArray";
    private static final String CLEAR = "/volvoxgrid.v1.VolvoxGridService/Clear";
    private static final String SELECT = "/volvoxgrid.v1.VolvoxGridService/Select";
    private static final String GET_SELECTION = "/volvoxgrid.v1.VolvoxGridService/GetSelection";
    private static final String EDIT = "/volvoxgrid.v1.VolvoxGridService/Edit";
    private static final String SORT = "/volvoxgrid.v1.VolvoxGridService/Sort";
    private static final String SUBTOTAL = "/volvoxgrid.v1.VolvoxGridService/Subtotal";
    private static final String AUTO_SIZE = "/volvoxgrid.v1.VolvoxGridService/AutoSize";
    private static final String OUTLINE = "/volvoxgrid.v1.VolvoxGridService/Outline";
    private static final String GET_NODE = "/volvoxgrid.v1.VolvoxGridService/GetNode";
    private static final String FIND = "/volvoxgrid.v1.VolvoxGridService/Find";
    private static final String AGGREGATE = "/volvoxgrid.v1.VolvoxGridService/Aggregate";
    private static final String GET_MERGED_RANGE = "/volvoxgrid.v1.VolvoxGridService/GetMergedRange";
    private static final String MERGE_CELLS = "/volvoxgrid.v1.VolvoxGridService/MergeCells";
    private static final String UNMERGE_CELLS = "/volvoxgrid.v1.VolvoxGridService/UnmergeCells";
    private static final String GET_MERGED_REGIONS = "/volvoxgrid.v1.VolvoxGridService/GetMergedRegions";
    private static final String CLIPBOARD = "/volvoxgrid.v1.VolvoxGridService/Clipboard";
    private static final String EXPORT = "/volvoxgrid.v1.VolvoxGridService/Export";
    private static final String IMPORT = "/volvoxgrid.v1.VolvoxGridService/Import";
    private static final String PRINT = "/volvoxgrid.v1.VolvoxGridService/Print";
    private static final String ARCHIVE = "/volvoxgrid.v1.VolvoxGridService/Archive";
    private static final String RESIZE_VIEWPORT = "/volvoxgrid.v1.VolvoxGridService/ResizeViewport";
    private static final String SET_REDRAW = "/volvoxgrid.v1.VolvoxGridService/SetRedraw";
    private static final String REFRESH = "/volvoxgrid.v1.VolvoxGridService/Refresh";
    private static final String LOAD_DEMO = "/volvoxgrid.v1.VolvoxGridService/LoadDemo";

    private static final String RENDER_SESSION = "/volvoxgrid.v1.VolvoxGridService/RenderSession";
    private static final String EVENT_STREAM = "/volvoxgrid.v1.VolvoxGridService/EventStream";

    private final SynurangDesktopBridge bridge;

    public VolvoxGridDesktopClient(SynurangDesktopBridge bridge) {
        this.bridge = Objects.requireNonNull(bridge, "bridge");
    }

    public GridHandle create(CreateRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(CREATE, request, GridHandle.parser());
    }

    public Empty destroy(GridHandle request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(DESTROY, request, Empty.parser());
    }

    public Empty configure(ConfigureRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(CONFIGURE, request, Empty.parser());
    }

    public GridConfig getConfig(GridHandle request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(GET_CONFIG, request, GridConfig.parser());
    }

    public Empty defineColumns(DefineColumnsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(DEFINE_COLUMNS, request, Empty.parser());
    }

    public Empty defineRows(DefineRowsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(DEFINE_ROWS, request, Empty.parser());
    }

    public Empty insertRows(InsertRowsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(INSERT_ROWS, request, Empty.parser());
    }

    public Empty removeRows(RemoveRowsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(REMOVE_ROWS, request, Empty.parser());
    }

    public Empty moveColumn(MoveColumnRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(MOVE_COLUMN, request, Empty.parser());
    }

    public Empty moveRow(MoveRowRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(MOVE_ROW, request, Empty.parser());
    }

    public Empty updateCells(UpdateCellsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(UPDATE_CELLS, request, Empty.parser());
    }

    public CellsResponse getCells(GetCellsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(GET_CELLS, request, CellsResponse.parser());
    }

    public Empty loadArray(LoadArrayRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(LOAD_ARRAY, request, Empty.parser());
    }

    public Empty clear(ClearRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(CLEAR, request, Empty.parser());
    }

    public Empty select(io.github.ivere27.volvoxgrid.SelectRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(SELECT, request, Empty.parser());
    }

    public SelectionState getSelection(GridHandle request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(GET_SELECTION, request, SelectionState.parser());
    }

    public EditState edit(EditCommand request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(EDIT, request, EditState.parser());
    }

    public Empty sort(SortRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(SORT, request, Empty.parser());
    }

    public Empty subtotal(SubtotalRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(SUBTOTAL, request, Empty.parser());
    }

    public Empty autoSize(AutoSizeRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(AUTO_SIZE, request, Empty.parser());
    }

    public Empty outline(OutlineRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(OUTLINE, request, Empty.parser());
    }

    public NodeInfo getNode(GetNodeRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(GET_NODE, request, NodeInfo.parser());
    }

    public FindResponse find(FindRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(FIND, request, FindResponse.parser());
    }

    public AggregateResponse aggregate(AggregateRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(AGGREGATE, request, AggregateResponse.parser());
    }

    public CellRange getMergedRange(GetMergedRangeRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(GET_MERGED_RANGE, request, CellRange.parser());
    }

    public Empty mergeCells(MergeCellsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(MERGE_CELLS, request, Empty.parser());
    }

    public Empty unmergeCells(UnmergeCellsRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(UNMERGE_CELLS, request, Empty.parser());
    }

    public MergedRegionsResponse getMergedRegions(GridHandle request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(GET_MERGED_REGIONS, request, MergedRegionsResponse.parser());
    }

    public ClipboardResponse clipboard(ClipboardCommand request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(CLIPBOARD, request, ClipboardResponse.parser());
    }

    public ExportResponse exportGrid(ExportRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(EXPORT, request, ExportResponse.parser());
    }

    public Empty importGrid(ImportRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(IMPORT, request, Empty.parser());
    }

    public PrintResponse printGrid(PrintRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(PRINT, request, PrintResponse.parser());
    }

    public ArchiveResponse archive(ArchiveRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(ARCHIVE, request, ArchiveResponse.parser());
    }

    public Empty resizeViewport(ResizeViewportRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(RESIZE_VIEWPORT, request, Empty.parser());
    }

    public Empty setRedraw(SetRedrawRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(SET_REDRAW, request, Empty.parser());
    }

    public Empty refresh(GridHandle request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(REFRESH, request, Empty.parser());
    }

    public Empty loadDemo(LoadDemoRequest request) throws SynurangDesktopBridge.SynurangBridgeException {
        return unary(LOAD_DEMO, request, Empty.parser());
    }

    public RenderSession openRenderSession() throws SynurangDesktopBridge.SynurangBridgeException {
        return new RenderSession(bridge.openStream(SERVICE, RENDER_SESSION));
    }

    public EventStream openEventStream(GridHandle request) throws SynurangDesktopBridge.SynurangBridgeException {
        SynurangDesktopBridge.PluginStreamBridge stream = bridge.openStream(SERVICE, EVENT_STREAM);
        stream.send(request.toByteArray());
        stream.closeSend();
        return new EventStream(stream);
    }

    private <T extends MessageLite> T unary(
        String methodPath,
        MessageLite request,
        Parser<T> parser
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        byte[] response = bridge.invoke(SERVICE, methodPath, request.toByteArray());
        try {
            return parser.parseFrom(response);
        } catch (InvalidProtocolBufferException e) {
            throw new SynurangDesktopBridge.SynurangBridgeException(
                "Failed to parse response for method: " + methodPath,
                e
            );
        }
    }

    public static final class RenderSession implements AutoCloseable {
        private final SynurangDesktopBridge.PluginStreamBridge stream;

        private RenderSession(SynurangDesktopBridge.PluginStreamBridge stream) {
            this.stream = Objects.requireNonNull(stream, "stream");
        }

        public void send(RenderInput input) throws SynurangDesktopBridge.SynurangBridgeException {
            stream.send(input.toByteArray());
        }

        public RenderOutput recv() throws SynurangDesktopBridge.SynurangBridgeException {
            byte[] data = stream.recv();
            if (data == null) {
                return null;
            }
            try {
                return RenderOutput.parseFrom(data);
            } catch (InvalidProtocolBufferException e) {
                throw new SynurangDesktopBridge.SynurangBridgeException("Failed to parse RenderOutput", e);
            }
        }

        public void closeSend() throws SynurangDesktopBridge.SynurangBridgeException {
            stream.closeSend();
        }

        @Override
        public void close() throws SynurangDesktopBridge.SynurangBridgeException {
            stream.close();
        }
    }

    public static final class EventStream implements AutoCloseable {
        private final SynurangDesktopBridge.PluginStreamBridge stream;

        private EventStream(SynurangDesktopBridge.PluginStreamBridge stream) {
            this.stream = Objects.requireNonNull(stream, "stream");
        }

        public GridEvent recv() throws SynurangDesktopBridge.SynurangBridgeException {
            byte[] data = stream.recv();
            if (data == null) {
                return null;
            }
            try {
                return GridEvent.parseFrom(data);
            } catch (InvalidProtocolBufferException e) {
                throw new SynurangDesktopBridge.SynurangBridgeException("Failed to parse GridEvent", e);
            }
        }

        @Override
        public void close() throws SynurangDesktopBridge.SynurangBridgeException {
            stream.close();
        }
    }
}
