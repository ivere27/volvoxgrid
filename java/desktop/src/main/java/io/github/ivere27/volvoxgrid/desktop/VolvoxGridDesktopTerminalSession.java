package io.github.ivere27.volvoxgrid.desktop;

import com.google.protobuf.ByteString;
import io.github.ivere27.volvoxgrid.BufferReady;
import io.github.ivere27.volvoxgrid.FrameKind;
import io.github.ivere27.volvoxgrid.FrameMetrics;
import io.github.ivere27.volvoxgrid.RenderInput;
import io.github.ivere27.volvoxgrid.RenderOutput;
import io.github.ivere27.volvoxgrid.TerminalCapabilities;
import io.github.ivere27.volvoxgrid.TerminalColorLevel;
import io.github.ivere27.volvoxgrid.TerminalCommand;
import io.github.ivere27.volvoxgrid.TerminalInputBytes;
import io.github.ivere27.volvoxgrid.TerminalViewport;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.Objects;

public final class VolvoxGridDesktopTerminalSession implements AutoCloseable {
    private static final int DEFAULT_BUFFER_CAPACITY = 32 * 1024;

    public enum ColorLevel {
        AUTO(TerminalColorLevel.TERMINAL_COLOR_LEVEL_AUTO),
        TRUECOLOR(TerminalColorLevel.TERMINAL_COLOR_LEVEL_TRUECOLOR),
        INDEXED_256(TerminalColorLevel.TERMINAL_COLOR_LEVEL_256),
        ANSI_16(TerminalColorLevel.TERMINAL_COLOR_LEVEL_16);

        private final TerminalColorLevel protoValue;

        ColorLevel(TerminalColorLevel protoValue) {
            this.protoValue = protoValue;
        }

        TerminalColorLevel toProto() {
            return protoValue;
        }
    }

    public enum RenderKind {
        FRAME,
        SESSION_START,
        SESSION_END;

        static RenderKind fromProto(FrameKind kind) {
            if (kind == FrameKind.FRAME_KIND_SESSION_START) {
                return SESSION_START;
            }
            if (kind == FrameKind.FRAME_KIND_SESSION_END) {
                return SESSION_END;
            }
            return FRAME;
        }
    }

    public static final class Capabilities {
        private ColorLevel colorLevel = ColorLevel.AUTO;
        private boolean sgrMouse = true;
        private boolean focusEvents = true;
        private boolean bracketedPaste = true;

        public ColorLevel getColorLevel() {
            return colorLevel;
        }

        public Capabilities setColorLevel(ColorLevel colorLevel) {
            this.colorLevel = colorLevel == null ? ColorLevel.AUTO : colorLevel;
            return this;
        }

        public boolean isSgrMouse() {
            return sgrMouse;
        }

        public Capabilities setSgrMouse(boolean sgrMouse) {
            this.sgrMouse = sgrMouse;
            return this;
        }

        public boolean isFocusEvents() {
            return focusEvents;
        }

        public Capabilities setFocusEvents(boolean focusEvents) {
            this.focusEvents = focusEvents;
            return this;
        }

        public boolean isBracketedPaste() {
            return bracketedPaste;
        }

        public Capabilities setBracketedPaste(boolean bracketedPaste) {
            this.bracketedPaste = bracketedPaste;
            return this;
        }

        TerminalCapabilities toProto() {
            return TerminalCapabilities.newBuilder()
                .setColorLevel(colorLevel.toProto())
                .setSgrMouse(sgrMouse)
                .setFocusEvents(focusEvents)
                .setBracketedPaste(bracketedPaste)
                .build();
        }
    }

    public static final class Frame {
        private final byte[] buffer;
        private final int bytesWritten;
        private final boolean rendered;
        private final RenderKind kind;
        private final FrameMetrics metrics;

        private Frame(
            byte[] buffer,
            int bytesWritten,
            boolean rendered,
            RenderKind kind,
            FrameMetrics metrics
        ) {
            this.buffer = buffer == null ? new byte[0] : buffer;
            this.bytesWritten = Math.max(0, bytesWritten);
            this.rendered = rendered;
            this.kind = kind == null ? RenderKind.FRAME : kind;
            this.metrics = metrics == null ? FrameMetrics.getDefaultInstance() : metrics;
        }

        public byte[] getBuffer() {
            return buffer;
        }

        public int getBytesWritten() {
            return bytesWritten;
        }

        public boolean isRendered() {
            return rendered;
        }

        public RenderKind getKind() {
            return kind;
        }

        public FrameMetrics getMetrics() {
            return metrics;
        }
    }

    private final VolvoxGridDesktopClient client;
    private final long gridId;
    private final VolvoxGridDesktopClient.RenderSession renderSession;

    private Capabilities capabilities = new Capabilities();
    private boolean capabilitiesDirty = true;
    private ByteBuffer buffer;
    private int originX;
    private int originY;
    private int width;
    private int height;
    private boolean fullscreen;
    private boolean viewportDirty = true;
    private FrameMetrics lastMetrics = FrameMetrics.getDefaultInstance();
    private boolean disposed;

    VolvoxGridDesktopTerminalSession(VolvoxGridDesktopClient client, long gridId)
        throws SynurangDesktopBridge.SynurangBridgeException {
        this.client = Objects.requireNonNull(client, "client");
        if (gridId == 0L) {
            throw new IllegalArgumentException("gridId must be non-zero");
        }
        this.gridId = gridId;
        this.renderSession = client.openRenderSession();
    }

    public long getGridId() {
        ensureNotDisposed();
        return gridId;
    }

    public FrameMetrics getLastMetrics() {
        ensureNotDisposed();
        return lastMetrics;
    }

    public void setCapabilities(Capabilities capabilities) {
        ensureNotDisposed();
        this.capabilities = capabilities == null ? new Capabilities() : capabilities;
        this.capabilitiesDirty = true;
    }

    public void setViewport(int originX, int originY, int width, int height, boolean fullscreen) {
        ensureNotDisposed();
        if (width <= 0) {
            throw new IllegalArgumentException("width must be positive");
        }
        if (height <= 0) {
            throw new IllegalArgumentException("height must be positive");
        }
        if (this.originX == originX
            && this.originY == originY
            && this.width == width
            && this.height == height
            && this.fullscreen == fullscreen
            && !viewportDirty) {
            return;
        }
        this.originX = Math.max(0, originX);
        this.originY = Math.max(0, originY);
        this.width = width;
        this.height = height;
        this.fullscreen = fullscreen;
        this.viewportDirty = true;
    }

    public void sendInputBytes(byte[] data) throws SynurangDesktopBridge.SynurangBridgeException {
        if (data == null) {
            throw new NullPointerException("data");
        }
        sendInputBytes(data, 0, data.length);
    }

    public void sendInputBytes(byte[] data, int offset, int count)
        throws SynurangDesktopBridge.SynurangBridgeException {
        ensureNotDisposed();
        Objects.requireNonNull(data, "data");
        if (offset < 0 || count < 0 || offset + count > data.length) {
            throw new IndexOutOfBoundsException("offset/count out of range");
        }
        if (count == 0) {
            return;
        }

        byte[] payload = offset == 0 && count == data.length
            ? data
            : Arrays.copyOfRange(data, offset, offset + count);
        sendInput(
            RenderInput.newBuilder()
                .setGridId(gridId)
                .setTerminalInput(
                    TerminalInputBytes.newBuilder()
                        .setData(ByteString.copyFrom(payload))
                        .build()
                )
                .build()
        );
    }

    public Frame render() throws SynurangDesktopBridge.SynurangBridgeException {
        ensureNotDisposed();
        if (width <= 0 || height <= 0) {
            throw new IllegalStateException("setViewport must be called before render()");
        }
        ensureTerminalStateSent();
        ensureBuffer(DEFAULT_BUFFER_CAPACITY);
        return requestFrame();
    }

    public Frame shutdown() throws SynurangDesktopBridge.SynurangBridgeException {
        ensureNotDisposed();
        try {
            sendInput(
                RenderInput.newBuilder()
                    .setGridId(gridId)
                    .setTerminalCommand(
                        TerminalCommand.newBuilder()
                            .setKind(TerminalCommand.Kind.TERMINAL_COMMAND_EXIT)
                            .build()
                    )
                    .build()
            );
            ensureBuffer(256);
            return requestFrame();
        } catch (LinkageError error) {
            // Some launcher/classpath combinations can resolve the outer generated
            // message class but fail late on its synthetic parser helper class.
            // Falling back to host-side terminal restore keeps shutdown graceful.
            return new Frame(new byte[0], 0, false, RenderKind.SESSION_END, lastMetrics);
        }
    }

    @Override
    public void close() throws SynurangDesktopBridge.SynurangBridgeException {
        if (disposed) {
            return;
        }
        disposed = true;
        renderSession.close();
        buffer = null;
    }

    private void ensureTerminalStateSent() throws SynurangDesktopBridge.SynurangBridgeException {
        if (capabilitiesDirty) {
            sendInput(
                RenderInput.newBuilder()
                    .setGridId(gridId)
                    .setTerminalCapabilities(capabilities.toProto())
                    .build()
            );
            capabilitiesDirty = false;
        }

        if (viewportDirty) {
            sendInput(
                RenderInput.newBuilder()
                    .setGridId(gridId)
                    .setTerminalViewport(
                        TerminalViewport.newBuilder()
                            .setOriginX(originX)
                            .setOriginY(originY)
                            .setWidth(width)
                            .setHeight(height)
                            .setFullscreen(fullscreen)
                            .build()
                    )
                    .build()
            );
            viewportDirty = false;
        }
    }

    private Frame requestFrame() throws SynurangDesktopBridge.SynurangBridgeException {
        while (true) {
            long handle = client.getDirectBufferAddress(buffer);
            renderSession.send(
                RenderInput.newBuilder()
                    .setGridId(gridId)
                    .setBuffer(
                        BufferReady.newBuilder()
                            .setHandle(handle)
                            .setCapacity(buffer.capacity())
                            .setWidth(width)
                            .setHeight(height)
                            .build()
                    )
                    .build()
            );

            while (true) {
                RenderOutput output = renderSession.recv();
                if (output == null) {
                    throw new IllegalStateException("VolvoxGrid terminal render stream closed.");
                }
                if (!output.hasFrameDone()) {
                    continue;
                }
                if (output.getFrameDone().getHandle() != handle) {
                    continue;
                }
                if (output.getFrameDone().getRequiredCapacity() > buffer.capacity()) {
                    ensureBuffer(output.getFrameDone().getRequiredCapacity());
                    break;
                }

                int bytesWritten = Math.max(0, output.getFrameDone().getBytesWritten());
                byte[] bytes = copyBuffer(bytesWritten);
                lastMetrics = output.getFrameDone().getMetrics();
                return new Frame(
                    bytes,
                    bytesWritten,
                    output.getRendered(),
                    RenderKind.fromProto(output.getFrameDone().getFrameKind()),
                    output.getFrameDone().getMetrics()
                );
            }
        }
    }

    private void sendInput(RenderInput input) throws SynurangDesktopBridge.SynurangBridgeException {
        renderSession.send(input);
    }

    private void ensureBuffer(int capacity) {
        int target = Math.max(DEFAULT_BUFFER_CAPACITY, capacity);
        if (buffer != null && buffer.capacity() >= target) {
            return;
        }
        buffer = ByteBuffer.allocateDirect(target);
    }

    private byte[] copyBuffer(int bytesWritten) {
        if (bytesWritten <= 0) {
            return new byte[0];
        }
        int count = Math.min(bytesWritten, buffer.capacity());
        byte[] bytes = new byte[count];
        ByteBuffer view = buffer.duplicate();
        view.position(0);
        view.limit(count);
        view.get(bytes);
        return bytes;
    }

    private void ensureNotDisposed() {
        if (disposed) {
            throw new IllegalStateException("VolvoxGridDesktopTerminalSession is closed.");
        }
    }
}
