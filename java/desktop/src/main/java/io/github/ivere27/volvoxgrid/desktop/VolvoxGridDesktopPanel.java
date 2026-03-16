package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.BufferReady;
import io.github.ivere27.volvoxgrid.ConfigureRequest;
import io.github.ivere27.volvoxgrid.CreateRequest;
import io.github.ivere27.volvoxgrid.CreateResponse;
import io.github.ivere27.volvoxgrid.CellRange;
import io.github.ivere27.volvoxgrid.EditRequest;
import io.github.ivere27.volvoxgrid.EventDecision;
import io.github.ivere27.volvoxgrid.FramePacingMode;
import io.github.ivere27.volvoxgrid.FrameDone;
import io.github.ivere27.volvoxgrid.GridConfig;
import io.github.ivere27.volvoxgrid.GridEvent;
import io.github.ivere27.volvoxgrid.GridHandle;
import io.github.ivere27.volvoxgrid.LayoutConfig;
import io.github.ivere27.volvoxgrid.PointerEvent;
import io.github.ivere27.volvoxgrid.RenderConfig;
import io.github.ivere27.volvoxgrid.RenderInput;
import io.github.ivere27.volvoxgrid.RenderOutput;
import io.github.ivere27.volvoxgrid.RendererMode;
import io.github.ivere27.volvoxgrid.ResizeViewportRequest;
import io.github.ivere27.volvoxgrid.ScrollEvent;
import io.github.ivere27.volvoxgrid.SelectRequest;
import io.github.ivere27.volvoxgrid.SelectionMode;
import io.github.ivere27.volvoxgrid.SelectionState;
import io.github.ivere27.volvoxgrid.common.VolvoxGridHost;
import io.github.ivere27.volvoxgrid.common.RendererBackend;
import java.awt.Color;
import java.awt.Dimension;
import java.awt.Graphics;
import java.awt.Toolkit;
import java.awt.event.ComponentAdapter;
import java.awt.event.ComponentEvent;
import java.awt.event.InputEvent;
import java.awt.event.KeyAdapter;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.awt.event.MouseMotionAdapter;
import java.awt.event.MouseWheelEvent;
import java.awt.event.MouseWheelListener;
import java.awt.image.BufferedImage;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.IntBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;
import javax.swing.Timer;

/**
 * Swing-based VolvoxGrid host with CPU shared-buffer rendering.
 */
public final class VolvoxGridDesktopPanel extends JPanel implements VolvoxGridHost<VolvoxGridDesktopController> {
    private static final Logger LOG = Logger.getLogger(VolvoxGridDesktopPanel.class.getName());
    private static final float WHEEL_SCROLL_GAIN = 3.0f;
    private static final float HOST_FLING_IMPULSE_GAIN = 2.2f;
    private static final float HOST_FLING_DAMPING = 0.90f;
    private static final float HOST_FLING_MIN_VELOCITY = 0.12f;
    private static final float HOST_FLING_MAX_VELOCITY = 120f;
    private static final long HOST_FLING_FRAME_MILLIS = 16L;
    private static final int AUTO_FALLBACK_FRAME_RATE_HZ = 30;
    private static final long FRAME_PACING_CONFIG_REFRESH_NANOS = 250_000_000L;

    public interface GridEventListener {
        void onGridEvent(GridEvent event);
    }

    @FunctionalInterface
    public interface BeforeEditListener {
        void onBeforeEdit(BeforeEditDetails details);
    }

    @FunctionalInterface
    public interface CellEditValidatingListener {
        void onCellEditValidating(CellEditValidatingDetails details);
    }

    @FunctionalInterface
    public interface BeforeSortListener {
        void onBeforeSort(BeforeSortDetails details);
    }

    public interface EditRequestListener {
        void onEditRequest(EditRequest request);
    }

    public static final class BeforeEditDetails {
        private final GridEvent rawEvent;
        private final int row;
        private final int col;
        private boolean cancel;

        private BeforeEditDetails(GridEvent rawEvent, int row, int col) {
            this.rawEvent = rawEvent;
            this.row = row;
            this.col = col;
        }

        public GridEvent getRawEvent() {
            return rawEvent;
        }

        public int getRow() {
            return row;
        }

        public int getCol() {
            return col;
        }

        public boolean isCancel() {
            return cancel;
        }

        public void setCancel(boolean cancel) {
            this.cancel = cancel;
        }
    }

    public static final class CellEditValidatingDetails {
        private final GridEvent rawEvent;
        private final int row;
        private final int col;
        private final String editText;
        private boolean cancel;

        private CellEditValidatingDetails(GridEvent rawEvent, int row, int col, String editText) {
            this.rawEvent = rawEvent;
            this.row = row;
            this.col = col;
            this.editText = editText;
        }

        public GridEvent getRawEvent() {
            return rawEvent;
        }

        public int getRow() {
            return row;
        }

        public int getCol() {
            return col;
        }

        public String getEditText() {
            return editText;
        }

        public boolean isCancel() {
            return cancel;
        }

        public void setCancel(boolean cancel) {
            this.cancel = cancel;
        }
    }

    public static final class BeforeSortDetails {
        private final GridEvent rawEvent;
        private final int col;
        private boolean cancel;

        private BeforeSortDetails(GridEvent rawEvent, int col) {
            this.rawEvent = rawEvent;
            this.col = col;
        }

        public GridEvent getRawEvent() {
            return rawEvent;
        }

        public int getCol() {
            return col;
        }

        public boolean isCancel() {
            return cancel;
        }

        public void setCancel(boolean cancel) {
            this.cancel = cancel;
        }
    }

    private static final class FrameTarget {
        final ByteBuffer pixelBuffer;
        final BufferedImage image;
        final int width;
        final int height;
        final int[] argbPixels;

        FrameTarget(ByteBuffer pixelBuffer, BufferedImage image, int width, int height) {
            this.pixelBuffer = pixelBuffer;
            this.image = image;
            this.width = width;
            this.height = height;
            this.argbPixels = new int[width * height];
        }
    }

    private final Object sendLock = new Object();
    private final Object imageLock = new Object();
    private final Object resizeLock = new Object();
    private final Object flingLock = new Object();

    private final AtomicBoolean running = new AtomicBoolean(false);
    private final AtomicBoolean pendingFrame = new AtomicBoolean(false);
    private final AtomicBoolean needsFollowupRender = new AtomicBoolean(false);
    private final AtomicBoolean renderRequestPending = new AtomicBoolean(false);
    private final AtomicBoolean followupRenderScheduled = new AtomicBoolean(false);

    private SynurangDesktopBridge plugin;
    private VolvoxGridDesktopClient client;
    private long gridId;
    private boolean ownsPlugin;

    private volatile VolvoxGridDesktopClient.RenderSession renderSession;
    private volatile VolvoxGridDesktopClient.EventStream eventStream;
    private volatile Thread renderThread;
    private volatile Thread eventThread;

    private volatile FrameTarget displayTarget;
    private volatile FrameTarget inflightTarget;
    private volatile int pendingResizeWidth;
    private volatile int pendingResizeHeight;

    private volatile GridEventListener gridEventListener;
    private volatile BeforeEditListener beforeEditListener;
    private volatile CellEditValidatingListener cellEditValidatingListener;
    private volatile BeforeSortListener beforeSortListener;
    private volatile EditRequestListener editRequestListener;
    private volatile boolean decisionChannelEnabled = false;

    private volatile RendererBackend rendererBackend = RendererBackend.CPU;
    private volatile boolean hostFlingEnabled = false;
    private volatile Thread flingThread;
    private volatile boolean flingActive = false;
    private volatile float flingVelocityY = 0f;
    private volatile int selectionModeValue = SelectionMode.SELECTION_FREE_VALUE;
    private volatile boolean multiRangeDragActive = false;
    private volatile List<CellRange> multiRangeBaseRanges = new ArrayList<CellRange>();
    private volatile int multiRangeAnchorRow = -1;
    private volatile int multiRangeAnchorCol = -1;
    private volatile int multiRangeDragRow = -1;
    private volatile int multiRangeDragCol = -1;
    private volatile int framePacingModeValue = FramePacingMode.FRAME_PACING_MODE_AUTO_VALUE;
    private volatile int targetFrameRateHz = AUTO_FALLBACK_FRAME_RATE_HZ;
    private volatile long framePacingConfigLastRefreshNanos = 0L;
    private volatile Timer followupRenderTimer;

    public VolvoxGridDesktopPanel() {
        setBackground(Color.WHITE);
        setPreferredSize(new Dimension(960, 600));
        setFocusable(true);
        setFocusTraversalKeysEnabled(false);

        installInputHandlers();

        addComponentListener(new ComponentAdapter() {
            @Override
            public void componentResized(ComponentEvent e) {
                handleResize();
            }
        });
    }

    public synchronized void initialize(
        String pluginPath,
        int rows,
        int cols
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(pluginPath, "pluginPath");

        release();

        this.plugin = SynurangDesktopBridge.load(pluginPath);
        this.ownsPlugin = true;
        this.client = new VolvoxGridDesktopClient(this.plugin);

        int w = resolveViewportWidth();
        int h = resolveViewportHeight();
        float scale = resolveScale();

        GridConfig config = GridConfig.newBuilder()
            .setLayout(
                LayoutConfig.newBuilder()
                    .setRows(rows)
                    .setCols(cols)
                    .build()
            )
            .setIndicators(VolvoxGridDesktopController.defaultIndicatorsConfig())
            .setRendering(
                RenderConfig.newBuilder()
                    .setRendererMode(RendererMode.RENDERER_CPU)
                    .setFramePacingMode(FramePacingMode.FRAME_PACING_MODE_AUTO)
                    .setTargetFrameRateHz(AUTO_FALLBACK_FRAME_RATE_HZ)
                    .build()
            )
            .build();

        CreateResponse response = client.create(
            CreateRequest.newBuilder()
                .setViewportWidth(w)
                .setViewportHeight(h)
                .setScale(scale)
                .setConfig(config)
                .build()
        );
        this.gridId = response.getHandle().getId();

        displayTarget = createFrameTarget(w, h);
        safeResizeViewport(w, h);
        startStreams();
    }

    public synchronized void initialize(
        SynurangDesktopBridge host,
        long existingGridId
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(host, "host");

        release();

        this.plugin = host;
        this.ownsPlugin = false;
        this.client = new VolvoxGridDesktopClient(host);
        this.gridId = existingGridId;

        int w = resolveViewportWidth();
        int h = resolveViewportHeight();
        displayTarget = createFrameTarget(w, h);
        safeResizeViewport(w, h);
        startStreams();
    }

    /**
     * Stop render/event streams but keep the engine grid alive.
     */
    public synchronized void detachGrid() {
        shutdownStreams(false);
        this.gridId = 0L;
        clearMultiRangeDrag();
        clearImage();
    }

    /**
     * Release panel resources. If this panel created the grid, it is destroyed.
     */
    @Override
    public synchronized void release() {
        shutdownStreams(true);

        if (ownsPlugin && plugin != null) {
            try {
                plugin.close();
            } catch (SynurangDesktopBridge.SynurangBridgeException e) {
                LOG.log(Level.WARNING, "Failed to close Synurang plugin host", e);
            }
        }

        plugin = null;
        client = null;
        ownsPlugin = false;
        gridId = 0L;
        clearMultiRangeDrag();
        clearImage();
    }

    public long getGridId() {
        return gridId;
    }

    public VolvoxGridDesktopClient getServiceClient() {
        return client;
    }

    @Override
    public VolvoxGridDesktopController createController() {
        VolvoxGridDesktopClient c = client;
        long id = gridId;
        if (c == null || id == 0L) {
            throw new IllegalStateException("VolvoxGridDesktopPanel is not initialized");
        }
        return new VolvoxGridDesktopController(c, id);
    }

    public void setGridEventListener(GridEventListener listener) {
        this.gridEventListener = listener;
    }

    public void setBeforeEditListener(BeforeEditListener listener) {
        this.beforeEditListener = listener;
        if (listener != null) {
            ensureDecisionChannelEnabled();
        }
    }

    public void setCellEditValidatingListener(CellEditValidatingListener listener) {
        this.cellEditValidatingListener = listener;
        if (listener != null) {
            ensureDecisionChannelEnabled();
        }
    }

    public void setBeforeSortListener(BeforeSortListener listener) {
        this.beforeSortListener = listener;
        if (listener != null) {
            ensureDecisionChannelEnabled();
        }
    }

    public void setEditRequestListener(EditRequestListener listener) {
        this.editRequestListener = listener;
    }

    public void setSelectionModeValue(int value) {
        this.selectionModeValue = value;
        if (value != SelectionMode.SELECTION_MULTI_RANGE_VALUE) {
            clearMultiRangeDrag();
        }
    }

    /**
     * CPU-only for now.
     */
    public void setRendererBackend(RendererBackend backend) throws SynurangDesktopBridge.SynurangBridgeException {
        Objects.requireNonNull(backend, "backend");
        if (backend == RendererBackend.GPU) {
            throw new UnsupportedOperationException("Desktop GPU path is not implemented yet. CPU mode only.");
        }
        this.rendererBackend = RendererBackend.CPU;

        VolvoxGridDesktopClient c = client;
        long id = gridId;
        if (c != null && id != 0L) {
            c.configure(
                ConfigureRequest.newBuilder()
                    .setGridId(id)
                    .setConfig(
                        GridConfig.newBuilder()
                            .setRendering(
                                RenderConfig.newBuilder()
                                    .setRendererMode(RendererMode.RENDERER_CPU)
                                    .setFramePacingMode(FramePacingMode.FRAME_PACING_MODE_AUTO)
                                    .setTargetFrameRateHz(AUTO_FALLBACK_FRAME_RATE_HZ)
                                    .build()
                            )
                            .build()
                    )
                    .build()
            );
            requestFrame();
        }
    }

    public RendererBackend rendererBackend() {
        return rendererBackend;
    }

    public boolean isGpuSupported() {
        return false;
    }

    /**
     * GPU stub hook for later native surface integration.
     */
    public void initializeGpuSurfaceStub() {
        throw new UnsupportedOperationException("GPU surface path is not implemented yet.");
    }

    public void setHostFlingEnabled(boolean enabled) {
        this.hostFlingEnabled = enabled;
        if (!enabled) {
            stopHostFling();
        }
    }

    public boolean isHostFlingEnabled() {
        return hostFlingEnabled;
    }

    /**
     * Send a zero-delta scroll signal to let the engine clear active fling state
     * when fling mode is temporarily disabled by the host.
     */
    public void cancelEngineFling() {
        stopHostFling();
        if (gridId == 0L || !running.get()) {
            return;
        }
        try {
            sendScrollDeltaInternal(0f, true, true);
        } catch (Exception e) {
            LOG.log(Level.FINER, "Engine fling cancel signal failed", e);
        }
    }

    @Override
    public void requestFrame() {
        if (gridId == 0L || !running.get()) {
            return;
        }
        if (!renderRequestPending.compareAndSet(false, true)) {
            return;
        }
        cancelScheduledFollowupRender();

        SwingUtilities.invokeLater(() -> {
            renderRequestPending.set(false);
            dispatchRenderFrame();
        });
    }

    @Override
    public void requestFrameImmediate() {
        if (gridId == 0L || !running.get()) {
            return;
        }
        if (renderRequestPending.get()) {
            return;
        }
        cancelScheduledFollowupRender();
        dispatchRenderFrame();
    }

    @Override
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);

        FrameTarget target = displayTarget;
        if (target == null) {
            g.setColor(Color.GRAY);
            g.drawString("VolvoxGrid (desktop CPU mode)", 12, 20);
            return;
        }

        synchronized (imageLock) {
            g.drawImage(target.image, 0, 0, null);
        }
    }

    private void installInputHandlers() {
        addMouseListener(new MouseAdapter() {
            @Override
            public void mousePressed(MouseEvent e) {
                stopHostFling();
                requestFocusInWindow();
                if (SwingUtilities.isRightMouseButton(e)) {
                    sendPointer(
                        PointerEvent.Type.MOVE,
                        e.getX(),
                        e.getY(),
                        mapModifierFlags(e.getModifiersEx()),
                        0,
                        false
                    );
                    requestFrame();
                    return;
                }
                if (tryBeginMultiRangeSelection(e)) {
                    requestFrame();
                    return;
                }
                sendPointer(PointerEvent.Type.DOWN, e, e.getClickCount() >= 2);
                requestFrame();
            }

            @Override
            public void mouseReleased(MouseEvent e) {
                if (multiRangeDragActive) {
                    tryUpdateMultiRangeSelection(e);
                    clearMultiRangeDrag();
                    requestFrame();
                    return;
                }
                sendPointer(PointerEvent.Type.UP, e, false);
                requestFrame();
            }
        });

        addMouseMotionListener(new MouseMotionAdapter() {
            @Override
            public void mouseDragged(MouseEvent e) {
                stopHostFling();
                if (multiRangeDragActive) {
                    if (tryUpdateMultiRangeSelection(e)) {
                        requestFrame();
                    }
                    return;
                }
                sendPointer(PointerEvent.Type.MOVE, e, false);
                requestFrame();
            }

            @Override
            public void mouseMoved(MouseEvent e) {
                sendPointer(PointerEvent.Type.MOVE, e, false);
                requestFrame();
            }
        });

        addMouseWheelListener(new MouseWheelListener() {
            @Override
            public void mouseWheelMoved(MouseWheelEvent e) {
                sendScroll(e);
            }
        });

        addKeyListener(new KeyAdapter() {
            @Override
            public void keyPressed(java.awt.event.KeyEvent e) {
                sendKey(io.github.ivere27.volvoxgrid.KeyEvent.Type.KEY_DOWN, e, printableChar(e));
                requestFrame();
            }

            @Override
            public void keyTyped(java.awt.event.KeyEvent e) {
                char ch = e.getKeyChar();
                if (ch >= 0x20 && ch != 0x7F) {
                    sendKey(io.github.ivere27.volvoxgrid.KeyEvent.Type.KEY_PRESS, e, String.valueOf(ch));
                    requestFrame();
                }
            }

            @Override
            public void keyReleased(java.awt.event.KeyEvent e) {
                sendKey(io.github.ivere27.volvoxgrid.KeyEvent.Type.KEY_UP, e, "");
                requestFrame();
            }
        });
    }

    private String printableChar(java.awt.event.KeyEvent e) {
        char ch = e.getKeyChar();
        if (ch >= 0x20 && ch != 0x7F) {
            return String.valueOf(ch);
        }
        return "";
    }

    private void sendPointer(PointerEvent.Type type, MouseEvent e, boolean dblClick) {
        sendPointer(
            type,
            e.getX(),
            e.getY(),
            mapModifierFlags(e.getModifiersEx()),
            mapMouseButtons(e),
            dblClick
        );
    }

    private void sendPointer(PointerEvent.Type type, int x, int y, int modifier, int button, boolean dblClick) {
        try {
            RenderInput input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setPointer(
                    PointerEvent.newBuilder()
                        .setType(type)
                        .setX((float) x)
                        .setY((float) y)
                        .setModifier(modifier)
                        .setButton(button)
                        .setDblClick(dblClick)
                        .build()
                )
                .build();
            sendRenderInput(input);
        } catch (Exception ex) {
            LOG.log(Level.FINER, "Pointer send failed", ex);
        }
    }

    private int mapMouseButtons(MouseEvent e) {
        int buttons = 0;
        int modifiers = e.getModifiersEx();
        if ((modifiers & InputEvent.BUTTON1_DOWN_MASK) != 0) {
            buttons |= 1;
        }
        if ((modifiers & InputEvent.BUTTON3_DOWN_MASK) != 0) {
            buttons |= 2;
        }
        if ((modifiers & InputEvent.BUTTON2_DOWN_MASK) != 0) {
            buttons |= 4;
        }

        if (buttons != 0) {
            return buttons;
        }

        switch (e.getButton()) {
            case MouseEvent.BUTTON1:
                return 1;
            case MouseEvent.BUTTON3:
                return 2;
            case MouseEvent.BUTTON2:
                return 4;
            default:
                return 0;
        }
    }

    private boolean tryBeginMultiRangeSelection(MouseEvent e) {
        if (!isAdditiveMultiRangeGesture(e) || client == null || gridId == 0L) {
            return false;
        }
        try {
            SelectionState state = updateMouseSelectionState(e);
            if (!hasValidMouseCell(state)) {
                return false;
            }
            multiRangeBaseRanges = snapshotMultiRangeBaseRanges(state, state.getMouseRow(), state.getMouseCol());
            multiRangeAnchorRow = state.getMouseRow();
            multiRangeAnchorCol = state.getMouseCol();
            multiRangeDragRow = state.getMouseRow();
            multiRangeDragCol = state.getMouseCol();
            multiRangeDragActive = true;
            applyMultiRangeSelection(multiRangeDragRow, multiRangeDragCol);
            return true;
        } catch (Exception ex) {
            LOG.log(Level.FINER, "Multi-range press failed", ex);
            clearMultiRangeDrag();
            return false;
        }
    }

    private boolean tryUpdateMultiRangeSelection(MouseEvent e) {
        if (!multiRangeDragActive || client == null || gridId == 0L) {
            return false;
        }
        try {
            SelectionState state = updateMouseSelectionState(e);
            if (hasValidMouseCell(state)) {
                multiRangeDragRow = state.getMouseRow();
                multiRangeDragCol = state.getMouseCol();
            }
            applyMultiRangeSelection(multiRangeDragRow, multiRangeDragCol);
            return true;
        } catch (Exception ex) {
            LOG.log(Level.FINER, "Multi-range drag failed", ex);
            return false;
        }
    }

    private boolean isAdditiveMultiRangeGesture(MouseEvent e) {
        return selectionModeValue == SelectionMode.SELECTION_MULTI_RANGE_VALUE
            && SwingUtilities.isLeftMouseButton(e)
            && (e.getModifiersEx() & InputEvent.CTRL_DOWN_MASK) != 0;
    }

    private SelectionState updateMouseSelectionState(MouseEvent e) throws SynurangDesktopBridge.SynurangBridgeException {
        sendPointer(PointerEvent.Type.MOVE, e.getX(), e.getY(), mapModifierFlags(e.getModifiersEx()), 0, false);
        return client.getSelection(GridHandle.newBuilder().setId(gridId).build());
    }

    private boolean hasValidMouseCell(SelectionState state) {
        return state.getMouseRow() >= 0 && state.getMouseCol() >= 0;
    }

    private List<CellRange> snapshotMultiRangeBaseRanges(SelectionState state, int anchorRow, int anchorCol) {
        List<CellRange> ranges = new ArrayList<CellRange>();
        List<CellRange> stateRanges = state.getRangesList();
        if (stateRanges.isEmpty()) {
            ranges.add(
                CellRange.newBuilder()
                    .setRow1(state.getActiveRow())
                    .setCol1(state.getActiveCol())
                    .setRow2(state.getActiveRow())
                    .setCol2(state.getActiveCol())
                    .build()
            );
        } else {
            for (CellRange range : stateRanges) {
                if (range.getRow1() == anchorRow
                    && range.getCol1() == anchorCol
                    && range.getRow2() == anchorRow
                    && range.getCol2() == anchorCol) {
                    continue;
                }
                ranges.add(range);
            }
        }
        return ranges;
    }

    private void applyMultiRangeSelection(int targetRow, int targetCol) throws SynurangDesktopBridge.SynurangBridgeException {
        List<CellRange> ranges = new ArrayList<CellRange>(multiRangeBaseRanges);
        CellRange nextRange = CellRange.newBuilder()
            .setRow1(Math.min(multiRangeAnchorRow, targetRow))
            .setCol1(Math.min(multiRangeAnchorCol, targetCol))
            .setRow2(Math.max(multiRangeAnchorRow, targetRow))
            .setCol2(Math.max(multiRangeAnchorCol, targetCol))
            .build();
        boolean exists = false;
        for (CellRange range : ranges) {
            if (range.getRow1() == nextRange.getRow1()
                && range.getCol1() == nextRange.getCol1()
                && range.getRow2() == nextRange.getRow2()
                && range.getCol2() == nextRange.getCol2()) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            ranges.add(nextRange);
        }
        client.select(
            SelectRequest.newBuilder()
                .setGridId(gridId)
                .setActiveRow(targetRow)
                .setActiveCol(targetCol)
                .addAllRanges(ranges)
                .setShow(true)
                .build()
        );
    }

    private void clearMultiRangeDrag() {
        multiRangeDragActive = false;
        multiRangeBaseRanges = new ArrayList<CellRange>();
        multiRangeAnchorRow = -1;
        multiRangeAnchorCol = -1;
        multiRangeDragRow = -1;
        multiRangeDragCol = -1;
    }

    private void sendScroll(MouseWheelEvent e) {
        try {
            float deltaY = (float) e.getPreciseWheelRotation() * WHEEL_SCROLL_GAIN;
            sendScrollDelta(deltaY, true);
            boostHostFling(deltaY);
        } catch (Exception ex) {
            LOG.log(Level.FINER, "Scroll send failed", ex);
        }
    }

    private void sendKey(
        io.github.ivere27.volvoxgrid.KeyEvent.Type type,
        java.awt.event.KeyEvent awtEvent,
        String character
    ) {
        try {
            RenderInput input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setKey(
                    io.github.ivere27.volvoxgrid.KeyEvent.newBuilder()
                        .setType(type)
                        .setKeyCode(mapKeyCode(awtEvent))
                        .setModifier(mapModifierFlags(awtEvent.getModifiersEx()))
                        .setCharacter(character)
                        .build()
                )
                .build();
            sendRenderInput(input);
        } catch (Exception ex) {
            LOG.log(Level.FINER, "Key send failed", ex);
        }
    }

    private static int mapModifierFlags(int awtModifiers) {
        int flags = 0;
        if ((awtModifiers & InputEvent.SHIFT_DOWN_MASK) != 0) {
            flags |= 1;
        }
        if ((awtModifiers & InputEvent.CTRL_DOWN_MASK) != 0) {
            flags |= 2;
        }
        if ((awtModifiers & InputEvent.ALT_DOWN_MASK) != 0) {
            flags |= 4;
        }
        return flags;
    }

    private static int mapKeyCode(java.awt.event.KeyEvent e) {
        switch (e.getKeyCode()) {
            case java.awt.event.KeyEvent.VK_LEFT:
                return 37;
            case java.awt.event.KeyEvent.VK_UP:
                return 38;
            case java.awt.event.KeyEvent.VK_RIGHT:
                return 39;
            case java.awt.event.KeyEvent.VK_DOWN:
                return 40;
            case java.awt.event.KeyEvent.VK_PAGE_UP:
                return 33;
            case java.awt.event.KeyEvent.VK_PAGE_DOWN:
                return 34;
            case java.awt.event.KeyEvent.VK_HOME:
                return 36;
            case java.awt.event.KeyEvent.VK_END:
                return 35;
            case java.awt.event.KeyEvent.VK_TAB:
                return 9;
            case java.awt.event.KeyEvent.VK_ENTER:
                return 13;
            case java.awt.event.KeyEvent.VK_DELETE:
                return 46;
            case java.awt.event.KeyEvent.VK_BACK_SPACE:
                return 8;
            case java.awt.event.KeyEvent.VK_F2:
                return 113;
            case java.awt.event.KeyEvent.VK_ESCAPE:
                return 27;
            default:
                return e.getKeyCode();
        }
    }

    private void dispatchRenderFrame() {
        if (rendererBackend != RendererBackend.CPU) {
            return;
        }
        sendBufferReady();
    }

    private void sendScrollDelta(float deltaY, boolean immediateFrame) throws SynurangDesktopBridge.SynurangBridgeException {
        sendScrollDeltaInternal(deltaY, immediateFrame, false);
    }

    private void sendScrollDeltaInternal(
        float deltaY,
        boolean immediateFrame,
        boolean allowZero
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        if (!Float.isFinite(deltaY)) {
            return;
        }
        if (!allowZero && Math.abs(deltaY) < 0.001f) {
            return;
        }
        RenderInput input = RenderInput.newBuilder()
            .setGridId(gridId)
            .setScroll(
                ScrollEvent.newBuilder()
                    .setDeltaX(0f)
                    .setDeltaY(deltaY)
                    .build()
            )
            .build();
        sendRenderInput(input);
        if (immediateFrame) {
            requestFrameImmediate();
        } else {
            requestFrame();
        }
    }

    private void boostHostFling(float sourceDeltaY) {
        if (!hostFlingEnabled || !Float.isFinite(sourceDeltaY) || Math.abs(sourceDeltaY) < 0.001f) {
            return;
        }

        Thread toStart = null;
        synchronized (flingLock) {
            float boosted = sourceDeltaY * HOST_FLING_IMPULSE_GAIN;
            float next = flingVelocityY + boosted;
            flingVelocityY = clamp(next, -HOST_FLING_MAX_VELOCITY, HOST_FLING_MAX_VELOCITY);

            if (!flingActive) {
                flingActive = true;
                Thread t = new Thread(this::runHostFlingLoop, "volvoxgrid-desktop-fling");
                t.setDaemon(true);
                flingThread = t;
                toStart = t;
            }
        }

        if (toStart != null) {
            toStart.start();
        }
    }

    private void runHostFlingLoop() {
        try {
            while (running.get()) {
                float step;
                synchronized (flingLock) {
                    if (!flingActive) {
                        break;
                    }
                    flingVelocityY *= HOST_FLING_DAMPING;
                    if (Math.abs(flingVelocityY) < HOST_FLING_MIN_VELOCITY) {
                        flingActive = false;
                        break;
                    }
                    step = flingVelocityY;
                }

                try {
                    sendScrollDelta(step, false);
                } catch (Exception e) {
                    LOG.log(Level.FINER, "Host fling send failed", e);
                }

                try {
                    Thread.sleep(HOST_FLING_FRAME_MILLIS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        } finally {
            synchronized (flingLock) {
                if (Thread.currentThread() == flingThread) {
                    flingThread = null;
                }
                flingActive = false;
                flingVelocityY = 0f;
            }
        }
    }

    private void stopHostFling() {
        Thread t;
        synchronized (flingLock) {
            flingActive = false;
            flingVelocityY = 0f;
            t = flingThread;
            flingThread = null;
        }
        if (t != null) {
            t.interrupt();
            joinQuietly(t, 100);
        }
    }

    private static float clamp(float value, float min, float max) {
        if (value < min) {
            return min;
        }
        if (value > max) {
            return max;
        }
        return value;
    }

    private void sendRenderInput(RenderInput input) throws SynurangDesktopBridge.SynurangBridgeException {
        synchronized (sendLock) {
            VolvoxGridDesktopClient.RenderSession session = renderSession;
            if (session != null) {
                session.send(input);
            }
        }
    }

    private void sendBufferReady() {
        SynurangDesktopBridge p = plugin;
        if (p == null || gridId == 0L) {
            return;
        }

        if (!pendingFrame.compareAndSet(false, true)) {
            needsFollowupRender.set(true);
            return;
        }

        FrameTarget current = displayTarget;
        FrameTarget target = null;
        int resizeWidth = 0;
        int resizeHeight = 0;
        synchronized (resizeLock) {
            if (pendingResizeWidth > 0 && pendingResizeHeight > 0) {
                resizeWidth = pendingResizeWidth;
                resizeHeight = pendingResizeHeight;
                pendingResizeWidth = 0;
                pendingResizeHeight = 0;
            }
        }
        if (resizeWidth > 0 && resizeHeight > 0) {
            target = createFrameTarget(resizeWidth, resizeHeight);
            safeResizeViewport(resizeWidth, resizeHeight);
        } else {
            target = current;
        }
        inflightTarget = target;
        if (target == null) {
            inflightTarget = null;
            pendingFrame.set(false);
            return;
        }

        try {
            long nativePtr = p.getDirectBufferAddress(target.pixelBuffer);
            RenderInput input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setBuffer(
                    BufferReady.newBuilder()
                        .setHandle(nativePtr)
                        .setStride(target.width * 4)
                        .setWidth(target.width)
                        .setHeight(target.height)
                        .build()
                )
                .build();

            boolean sent;
            synchronized (sendLock) {
                VolvoxGridDesktopClient.RenderSession session = renderSession;
                if (session == null) {
                    sent = false;
                } else {
                    session.send(input);
                    sent = true;
                }
            }

            if (!sent) {
                if (target != current) {
                    queuePendingResize(target.width, target.height);
                }
                inflightTarget = null;
                pendingFrame.set(false);
                if (needsFollowupRender.getAndSet(false)) {
                    requestFrame();
                }
            }
        } catch (Exception e) {
            if (target != current) {
                queuePendingResize(target.width, target.height);
            }
            inflightTarget = null;
            pendingFrame.set(false);
            if (needsFollowupRender.getAndSet(false)) {
                requestFrame();
            }
            LOG.log(Level.FINER, "sendBufferReady failed", e);
        }
    }

    private void startStreams() {
        pendingFrame.set(false);
        needsFollowupRender.set(false);
        renderRequestPending.set(false);
        running.set(true);
        decisionChannelEnabled = false;

        startRenderSession();
        startEventStream();
        requestFrame();
    }

    private void startRenderSession() {
        VolvoxGridDesktopClient c = client;
        if (c == null) {
            return;
        }

        Thread t = new Thread(() -> {
            VolvoxGridDesktopClient.RenderSession session = null;
            try {
                session = c.openRenderSession();
                synchronized (sendLock) {
                    renderSession = session;
                }
                ensureDecisionChannelEnabled();
                requestFrameImmediate();

                while (running.get()) {
                    RenderOutput output = session.recv();
                    if (output == null) {
                        break;
                    }
                    handleRenderOutput(output);
                }
            } catch (Exception e) {
                if (running.get()) {
                    LOG.log(Level.WARNING, "Render session failed", e);
                }
            } finally {
                synchronized (sendLock) {
                    if (renderSession == session) {
                        renderSession = null;
                    }
                }
                if (session != null) {
                    try {
                        session.close();
                    } catch (Exception e) {
                        LOG.log(Level.FINER, "Render session close failed", e);
                    }
                }
            }
        }, "volvoxgrid-desktop-render");
        t.setDaemon(true);
        renderThread = t;
        t.start();
    }

    private void startEventStream() {
        VolvoxGridDesktopClient c = client;
        if (c == null || gridId == 0L) {
            return;
        }

        Thread t = new Thread(() -> {
            VolvoxGridDesktopClient.EventStream stream = null;
            try {
                stream = c.openEventStream(GridHandle.newBuilder().setId(gridId).build());
                eventStream = stream;

                while (running.get()) {
                    GridEvent event = stream.recv();
                    if (event == null) {
                        break;
                    }
                    handleGridEvent(event);
                }
            } catch (Exception e) {
                if (running.get()) {
                    LOG.log(Level.FINER, "Event stream ended", e);
                }
            } finally {
                if (eventStream == stream) {
                    eventStream = null;
                }
                if (stream != null) {
                    try {
                        stream.close();
                    } catch (Exception e) {
                        LOG.log(Level.FINER, "Event stream close failed", e);
                    }
                }
            }
        }, "volvoxgrid-desktop-events");
        t.setDaemon(true);
        eventThread = t;
        t.start();
    }

    private void handleGridEvent(GridEvent event) {
        if (decisionChannelEnabled && isCancelableGridEvent(event)) {
            boolean cancel = dispatchCancelableGridEvent(event);
            sendEventDecision(event.getEventId(), cancel);
        }

        GridEventListener listener = gridEventListener;
        if (listener != null) {
            SwingUtilities.invokeLater(() -> listener.onGridEvent(event));
        }
    }

    private boolean wantsCancelableGridEvents() {
        return beforeEditListener != null
            || cellEditValidatingListener != null
            || beforeSortListener != null;
    }

    private boolean isCancelableGridEvent(GridEvent event) {
        return event.hasBeforeEdit() || event.hasCellEditValidate() || event.hasBeforeSort();
    }

    private void ensureDecisionChannelEnabled() {
        if (decisionChannelEnabled || !wantsCancelableGridEvents() || gridId == 0L) {
            return;
        }

        VolvoxGridDesktopClient.RenderSession session;
        synchronized (sendLock) {
            session = renderSession;
        }
        if (session == null) {
            return;
        }

        try {
            session.send(
                RenderInput.newBuilder()
                    .setGridId(gridId)
                    .setEventDecision(
                        EventDecision.newBuilder()
                            .setGridId(gridId)
                            .setEventId(0L)
                            .setCancel(false)
                            .build()
                    )
                    .build()
            );
            decisionChannelEnabled = true;
        } catch (Exception e) {
            LOG.log(Level.FINER, "Decision channel enable failed", e);
        }
    }

    private void sendEventDecision(long eventId, boolean cancel) {
        if (!decisionChannelEnabled || gridId == 0L || eventId == 0L) {
            return;
        }

        try {
            sendRenderInput(
                RenderInput.newBuilder()
                    .setGridId(gridId)
                    .setEventDecision(
                        EventDecision.newBuilder()
                            .setGridId(gridId)
                            .setEventId(eventId)
                            .setCancel(cancel)
                            .build()
                    )
                    .build()
            );
            requestFrame();
        } catch (Exception e) {
            LOG.log(Level.FINER, "Event decision send failed", e);
        }
    }

    private boolean dispatchCancelableGridEvent(GridEvent event) {
        if (SwingUtilities.isEventDispatchThread()) {
            return dispatchCancelableGridEventOnEdt(event);
        }

        AtomicBoolean cancel = new AtomicBoolean(false);
        try {
            SwingUtilities.invokeAndWait(() -> cancel.set(dispatchCancelableGridEventOnEdt(event)));
        } catch (Exception e) {
            LOG.log(Level.WARNING, "Cancelable grid event dispatch failed", e);
            return false;
        }
        return cancel.get();
    }

    private boolean dispatchCancelableGridEventOnEdt(GridEvent event) {
        try {
            if (event.hasBeforeEdit()) {
                BeforeEditListener listener = beforeEditListener;
                BeforeEditDetails details = new BeforeEditDetails(
                    event,
                    event.getBeforeEdit().getRow(),
                    event.getBeforeEdit().getCol()
                );
                if (listener != null) {
                    listener.onBeforeEdit(details);
                }
                return details.isCancel();
            }

            if (event.hasCellEditValidate()) {
                CellEditValidatingListener listener = cellEditValidatingListener;
                CellEditValidatingDetails details = new CellEditValidatingDetails(
                    event,
                    event.getCellEditValidate().getRow(),
                    event.getCellEditValidate().getCol(),
                    event.getCellEditValidate().getEditText()
                );
                if (listener != null) {
                    listener.onCellEditValidating(details);
                }
                return details.isCancel();
            }

            if (event.hasBeforeSort()) {
                BeforeSortListener listener = beforeSortListener;
                BeforeSortDetails details = new BeforeSortDetails(
                    event,
                    event.getBeforeSort().getCol()
                );
                if (listener != null) {
                    listener.onBeforeSort(details);
                }
                return details.isCancel();
            }
        } catch (Exception e) {
            LOG.log(Level.WARNING, "Cancelable grid listener failed", e);
        }

        return false;
    }

    private void handleRenderOutput(RenderOutput output) {
        boolean isBufferResponse = output.hasFrameDone();
        boolean isGpuResponse = output.hasGpuFrameDone();
        boolean renderedFrame = output.getRendered() && (isBufferResponse || isGpuResponse);
        FrameTarget completedTarget = inflightTarget;

        if (output.hasFrameDone()) {
            if (output.getRendered()) {
                blitFrame(output.getFrameDone(), completedTarget);
            } else if (completedTarget != null && completedTarget != displayTarget) {
                queuePendingResize(completedTarget.width, completedTarget.height);
            }
        } else if (output.hasEditRequest()) {
            EditRequest request = output.getEditRequest();
            EditRequestListener listener = editRequestListener;
            if (listener != null) {
                SwingUtilities.invokeLater(() -> listener.onEditRequest(request));
            }
        } else if (output.hasTooltipRequest()) {
            String text = output.getTooltipRequest().getText();
            SwingUtilities.invokeLater(() -> setToolTipText(text));
        }

        if (isBufferResponse || isGpuResponse) {
            inflightTarget = null;
            pendingFrame.set(false);
            if (needsFollowupRender.getAndSet(false)) {
                requestFrame();
            } else if (renderedFrame) {
                scheduleFollowupFrame();
            }
        }
    }

    private void refreshFramePacingConfigIfStale() {
        VolvoxGridDesktopClient c = client;
        long id = gridId;
        if (c == null || id == 0L) {
            return;
        }
        long now = System.nanoTime();
        if (now - framePacingConfigLastRefreshNanos < FRAME_PACING_CONFIG_REFRESH_NANOS) {
            return;
        }
        try {
            GridConfig config = c.getConfig(GridHandle.newBuilder().setId(id).build());
            RenderConfig rendering = config.getRendering();
            framePacingModeValue = rendering.hasFramePacingMode()
                ? rendering.getFramePacingModeValue()
                : FramePacingMode.FRAME_PACING_MODE_AUTO_VALUE;
            targetFrameRateHz = normalizeTargetFrameRateHz(
                rendering.hasTargetFrameRateHz() ? rendering.getTargetFrameRateHz() : AUTO_FALLBACK_FRAME_RATE_HZ
            );
        } catch (Exception e) {
            LOG.log(Level.FINER, "refreshFramePacingConfigIfStale failed", e);
            framePacingModeValue = FramePacingMode.FRAME_PACING_MODE_AUTO_VALUE;
            targetFrameRateHz = AUTO_FALLBACK_FRAME_RATE_HZ;
        } finally {
            framePacingConfigLastRefreshNanos = now;
        }
    }

    private static int normalizeTargetFrameRateHz(int hz) {
        return hz > 0 ? hz : AUTO_FALLBACK_FRAME_RATE_HZ;
    }

    private void cancelScheduledFollowupRender() {
        followupRenderScheduled.set(false);
        Timer timer = followupRenderTimer;
        if (timer != null) {
            timer.stop();
            followupRenderTimer = null;
        }
    }

    private void scheduleFollowupFrame() {
        if (gridId == 0L || !running.get()) {
            return;
        }
        refreshFramePacingConfigIfStale();
        int mode = framePacingModeValue;
        if (mode == FramePacingMode.FRAME_PACING_MODE_UNLIMITED_VALUE) {
            requestFrame();
            return;
        }
        if (!followupRenderScheduled.compareAndSet(false, true)) {
            return;
        }

        int hz = AUTO_FALLBACK_FRAME_RATE_HZ;
        if (mode == FramePacingMode.FRAME_PACING_MODE_FIXED_VALUE) {
            hz = normalizeTargetFrameRateHz(targetFrameRateHz);
        }

        int delayMs = Math.max(1, Math.round(1000f / hz));
        Timer timer = new Timer(delayMs, event -> {
            followupRenderScheduled.set(false);
            followupRenderTimer = null;
            requestFrame();
        });
        timer.setRepeats(false);
        followupRenderTimer = timer;
        timer.start();
    }

    private void blitFrame(FrameDone frame, FrameTarget target) {
        if (target == null) {
            return;
        }

        boolean fullRepaint = false;
        synchronized (imageLock) {
            FrameTarget previous = displayTarget;
            ByteBuffer view = target.pixelBuffer.duplicate().order(ByteOrder.LITTLE_ENDIAN);
            IntBuffer intView = view.asIntBuffer();
            int pixelCount = Math.min(intView.remaining(), target.argbPixels.length);
            intView.get(target.argbPixels, 0, pixelCount);
            for (int i = 0; i < pixelCount; i++) {
                int px = target.argbPixels[i];
                // Engine writes RGBA bytes; Swing setRGB expects packed ARGB.
                target.argbPixels[i] = (px & 0xFF00FF00) | ((px & 0x00FF0000) >>> 16) | ((px & 0x000000FF) << 16);
            }
            target.image.setRGB(0, 0, target.width, target.height, target.argbPixels, 0, target.width);
            displayTarget = target;
            fullRepaint = previous != target;
        }

        if (fullRepaint) {
            repaint();
            return;
        }

        int dirtyX = Math.max(0, frame.getDirtyX());
        int dirtyY = Math.max(0, frame.getDirtyY());
        int dirtyW = Math.max(0, frame.getDirtyW());
        int dirtyH = Math.max(0, frame.getDirtyH());

        if (dirtyW > 0 && dirtyH > 0) {
            repaint(dirtyX, dirtyY, dirtyW, dirtyH);
        } else {
            repaint();
        }
    }

    private int resolveViewportWidth() {
        int w = getWidth();
        return w > 0 ? w : 960;
    }

    private int resolveViewportHeight() {
        int h = getHeight();
        return h > 0 ? h : 600;
    }

    private float resolveScale() {
        int dpi = Toolkit.getDefaultToolkit().getScreenResolution();
        if (dpi <= 0) {
            return 1f;
        }
        return Math.max(1f, dpi / 96f);
    }

    private FrameTarget createFrameTarget(int width, int height) {
        int w = Math.max(1, width);
        int h = Math.max(1, height);

        int size = Math.multiplyExact(Math.multiplyExact(w, h), 4);
        ByteBuffer newBuffer = ByteBuffer.allocateDirect(size);
        BufferedImage newImage = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        return new FrameTarget(newBuffer, newImage, w, h);
    }

    private void handleResize() {
        VolvoxGridDesktopClient c = client;
        if (c == null || gridId == 0L) {
            return;
        }

        int w = resolveViewportWidth();
        int h = resolveViewportHeight();
        queuePendingResize(w, h);
        requestFrameImmediate();
    }

    private void queuePendingResize(int width, int height) {
        int w = Math.max(1, width);
        int h = Math.max(1, height);
        synchronized (resizeLock) {
            pendingResizeWidth = w;
            pendingResizeHeight = h;
        }
    }

    private void safeResizeViewport(int width, int height) {
        VolvoxGridDesktopClient c = client;
        if (c == null || gridId == 0L) {
            return;
        }

        try {
            c.resizeViewport(
                ResizeViewportRequest.newBuilder()
                    .setGridId(gridId)
                    .setWidth(width)
                    .setHeight(height)
                    .build()
            );
        } catch (SynurangDesktopBridge.SynurangBridgeException e) {
            LOG.log(Level.FINER, "ResizeViewport failed", e);
        }
    }

    private synchronized void shutdownStreams(boolean destroyGrid) {
        stopHostFling();
        cancelScheduledFollowupRender();
        running.set(false);
        renderRequestPending.set(false);
        pendingFrame.set(false);
        needsFollowupRender.set(false);
        decisionChannelEnabled = false;
        framePacingConfigLastRefreshNanos = 0L;

        VolvoxGridDesktopClient.RenderSession render = renderSession;
        renderSession = null;
        if (render != null) {
            try {
                render.closeSend();
            } catch (Exception ignored) {
                // best effort
            }
            try {
                render.close();
            } catch (Exception ignored) {
                // best effort
            }
        }

        VolvoxGridDesktopClient.EventStream events = eventStream;
        eventStream = null;
        if (events != null) {
            try {
                events.close();
            } catch (Exception ignored) {
                // best effort
            }
        }

        Thread rt = renderThread;
        renderThread = null;
        joinQuietly(rt, 250);

        Thread et = eventThread;
        eventThread = null;
        joinQuietly(et, 250);

        if (destroyGrid && gridId != 0L && client != null) {
            try {
                client.destroy(GridHandle.newBuilder().setId(gridId).build());
            } catch (Exception e) {
                LOG.log(Level.FINER, "Destroy grid failed", e);
            }
            gridId = 0L;
        }
    }

    private void joinQuietly(Thread thread, long millis) {
        if (thread == null || thread == Thread.currentThread()) {
            return;
        }
        try {
            thread.join(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private void clearImage() {
        displayTarget = null;
        inflightTarget = null;
        synchronized (resizeLock) {
            pendingResizeWidth = 0;
            pendingResizeHeight = 0;
        }
        repaint();
    }
}
