package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.BufferReady;
import io.github.ivere27.volvoxgrid.ConfigureRequest;
import io.github.ivere27.volvoxgrid.CreateRequest;
import io.github.ivere27.volvoxgrid.EditRequest;
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
import java.util.Objects;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;

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

    public interface GridEventListener {
        void onGridEvent(GridEvent event);
    }

    public interface EditRequestListener {
        void onEditRequest(EditRequest request);
    }

    private final Object sendLock = new Object();
    private final Object imageLock = new Object();
    private final Object flingLock = new Object();

    private final AtomicBoolean running = new AtomicBoolean(false);
    private final AtomicBoolean pendingFrame = new AtomicBoolean(false);
    private final AtomicBoolean needsFollowupRender = new AtomicBoolean(false);
    private final AtomicBoolean renderRequestPending = new AtomicBoolean(false);

    private SynurangDesktopBridge plugin;
    private VolvoxGridDesktopClient client;
    private long gridId;
    private boolean ownsPlugin;

    private volatile VolvoxGridDesktopClient.RenderSession renderSession;
    private volatile VolvoxGridDesktopClient.EventStream eventStream;
    private volatile Thread renderThread;
    private volatile Thread eventThread;

    private volatile ByteBuffer pixelBuffer;
    private volatile BufferedImage image;
    private volatile int bufferWidth;
    private volatile int bufferHeight;
    private volatile int[] argbPixels = new int[0];

    private volatile GridEventListener gridEventListener;
    private volatile EditRequestListener editRequestListener;

    private volatile RendererBackend rendererBackend = RendererBackend.CPU;
    private volatile boolean hostFlingEnabled = false;
    private volatile Thread flingThread;
    private volatile boolean flingActive = false;
    private volatile float flingVelocityY = 0f;

    public VolvoxGridDesktopPanel() {
        setBackground(Color.WHITE);
        setPreferredSize(new Dimension(960, 600));
        setFocusable(true);

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
            .setIndicatorBands(VolvoxGridDesktopController.defaultIndicatorBandsConfig())
            .setRendering(RenderConfig.newBuilder().setRendererMode(RendererMode.RENDERER_CPU).build())
            .build();

        GridHandle handle = client.create(
            CreateRequest.newBuilder()
                .setViewportWidth(w)
                .setViewportHeight(h)
                .setScale(scale)
                .setConfig(config)
                .build()
        );
        this.gridId = handle.getId();

        allocateBuffer(w, h);
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
        allocateBuffer(w, h);
        safeResizeViewport(w, h);
        startStreams();
    }

    /**
     * Stop render/event streams but keep the engine grid alive.
     */
    public synchronized void detachGrid() {
        shutdownStreams(false);
        this.gridId = 0L;
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

    public void setEditRequestListener(EditRequestListener listener) {
        this.editRequestListener = listener;
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
                            .setRendering(RenderConfig.newBuilder().setRendererMode(RendererMode.RENDERER_CPU).build())
                            .build()
                    )
                    .build()
            );
            requestFrame();
        }
    }

    public RendererBackend getRendererBackend() {
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
        dispatchRenderFrame();
    }

    @Override
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);

        BufferedImage current = image;
        if (current == null) {
            g.setColor(Color.GRAY);
            g.drawString("VolvoxGrid (desktop CPU mode)", 12, 20);
            return;
        }

        synchronized (imageLock) {
            g.drawImage(current, 0, 0, getWidth(), getHeight(), null);
        }
    }

    private void installInputHandlers() {
        addMouseListener(new MouseAdapter() {
            @Override
            public void mousePressed(MouseEvent e) {
                stopHostFling();
                requestFocusInWindow();
                sendPointer(PointerEvent.Type.DOWN, e, e.getClickCount() >= 2);
                requestFrame();
            }

            @Override
            public void mouseReleased(MouseEvent e) {
                sendPointer(PointerEvent.Type.UP, e, false);
                requestFrame();
            }
        });

        addMouseMotionListener(new MouseMotionAdapter() {
            @Override
            public void mouseDragged(MouseEvent e) {
                stopHostFling();
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
        try {
            RenderInput input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setPointer(
                    PointerEvent.newBuilder()
                        .setType(type)
                        .setX((float) e.getX())
                        .setY((float) e.getY())
                        .setModifier(e.getModifiersEx())
                        .setButton(mapMouseButton(e))
                        .setDblClick(dblClick)
                        .build()
                )
                .build();
            sendRenderInput(input);
        } catch (Exception ex) {
            LOG.log(Level.FINER, "Pointer send failed", ex);
        }
    }

    private int mapMouseButton(MouseEvent e) {
        int button = e.getButton();
        if (button == MouseEvent.NOBUTTON && (e.getModifiersEx() & InputEvent.BUTTON1_DOWN_MASK) != 0) {
            return MouseEvent.BUTTON1;
        }
        if (button == MouseEvent.NOBUTTON && (e.getModifiersEx() & InputEvent.BUTTON2_DOWN_MASK) != 0) {
            return MouseEvent.BUTTON2;
        }
        if (button == MouseEvent.NOBUTTON && (e.getModifiersEx() & InputEvent.BUTTON3_DOWN_MASK) != 0) {
            return MouseEvent.BUTTON3;
        }
        return button;
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
                        .setKeyCode(awtEvent.getKeyCode())
                        .setModifier(awtEvent.getModifiersEx())
                        .setCharacter(character)
                        .build()
                )
                .build();
            sendRenderInput(input);
        } catch (Exception ex) {
            LOG.log(Level.FINER, "Key send failed", ex);
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
        ByteBuffer buf = pixelBuffer;
        SynurangDesktopBridge p = plugin;
        if (buf == null || p == null || gridId == 0L) {
            return;
        }

        if (!pendingFrame.compareAndSet(false, true)) {
            needsFollowupRender.set(true);
            return;
        }

        try {
            long nativePtr = p.getDirectBufferAddress(buf);
            RenderInput input = RenderInput.newBuilder()
                .setGridId(gridId)
                .setBuffer(
                    BufferReady.newBuilder()
                        .setHandle(nativePtr)
                        .setStride(bufferWidth * 4)
                        .setWidth(bufferWidth)
                        .setHeight(bufferHeight)
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
                pendingFrame.set(false);
                if (needsFollowupRender.getAndSet(false)) {
                    requestFrame();
                }
            }
        } catch (Exception e) {
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
                    GridEventListener listener = gridEventListener;
                    if (listener != null) {
                        SwingUtilities.invokeLater(() -> listener.onGridEvent(event));
                    }
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

    private void handleRenderOutput(RenderOutput output) {
        boolean isBufferResponse = output.hasFrameDone();
        boolean isGpuResponse = output.hasGpuFrameDone();
        boolean renderedFrame = output.getRendered() && (isBufferResponse || isGpuResponse);

        if (output.hasFrameDone()) {
            if (output.getRendered()) {
                blitFrame(output.getFrameDone());
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
            pendingFrame.set(false);
            if (needsFollowupRender.getAndSet(false)) {
                requestFrame();
            } else if (renderedFrame) {
                // Keep pumping frames while the engine still reports rendered output (e.g. fling).
                requestFrame();
            }
        }
    }

    private void blitFrame(FrameDone frame) {
        ByteBuffer buf = pixelBuffer;
        BufferedImage img = image;
        if (buf == null || img == null) {
            return;
        }

        synchronized (imageLock) {
            ByteBuffer view = buf.duplicate().order(ByteOrder.LITTLE_ENDIAN);
            IntBuffer intView = view.asIntBuffer();
            int pixelCount = Math.min(intView.remaining(), argbPixels.length);
            intView.get(argbPixels, 0, pixelCount);
            for (int i = 0; i < pixelCount; i++) {
                int px = argbPixels[i];
                // Engine writes RGBA bytes; Swing setRGB expects packed ARGB.
                argbPixels[i] = (px & 0xFF00FF00) | ((px & 0x00FF0000) >>> 16) | ((px & 0x000000FF) << 16);
            }
            img.setRGB(0, 0, bufferWidth, bufferHeight, argbPixels, 0, bufferWidth);
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

    private void allocateBuffer(int width, int height) {
        int w = Math.max(1, width);
        int h = Math.max(1, height);

        int size = Math.multiplyExact(Math.multiplyExact(w, h), 4);
        ByteBuffer newBuffer = ByteBuffer.allocateDirect(size);
        BufferedImage newImage = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);

        bufferWidth = w;
        bufferHeight = h;
        pixelBuffer = newBuffer;
        image = newImage;
        argbPixels = new int[w * h];
    }

    private void handleResize() {
        VolvoxGridDesktopClient c = client;
        if (c == null || gridId == 0L) {
            return;
        }

        int w = resolveViewportWidth();
        int h = resolveViewportHeight();
        allocateBuffer(w, h);
        safeResizeViewport(w, h);
        requestFrameImmediate();
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
        running.set(false);
        renderRequestPending.set(false);
        pendingFrame.set(false);
        needsFollowupRender.set(false);

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
        image = null;
        pixelBuffer = null;
        argbPixels = new int[0];
        bufferWidth = 0;
        bufferHeight = 0;
        repaint();
    }
}
