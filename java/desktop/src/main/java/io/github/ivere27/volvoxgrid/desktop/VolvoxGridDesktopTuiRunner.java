package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.EditState;
import io.github.ivere27.volvoxgrid.EditUiMode;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public final class VolvoxGridDesktopTuiRunner {
    public static final String ACTION_TOGGLE_DEBUG_PANEL = "toggle-debug-panel";

    public interface Controller {
        VolvoxGridDesktopTerminalSession ensureSession(int viewportWidth, int viewportHeight)
            throws SynurangDesktopBridge.SynurangBridgeException;

        EditState getCurrentEditState() throws SynurangDesktopBridge.SynurangBridgeException;

        void cancelActiveEdit() throws SynurangDesktopBridge.SynurangBridgeException;

        ActionOutcome handleAction(String action, int viewportWidth, int viewportHeight)
            throws SynurangDesktopBridge.SynurangBridgeException;

        void drawChrome(VolvoxGridDesktopTerminalHost terminal, int width, int height, String mode) throws IOException;
    }

    public interface HostInputHandler {
        HostInputResult handleHostInput(
            byte[] input,
            EditState editState,
            int viewportWidth,
            int viewportHeight
        ) throws SynurangDesktopBridge.SynurangBridgeException;
    }

    public interface DebugPanelProvider {
        boolean debugPanelVisible();

        int debugPanelRows();

        void toggleDebugPanel() throws SynurangDesktopBridge.SynurangBridgeException;

        List<String> debugPanelLines(DebugPanelContext context) throws SynurangDesktopBridge.SynurangBridgeException;
    }

    public static final class ShortcutSpec {
        private String action;
        private Byte ctrlKey;
        private Integer functionKey;

        public String getAction() {
            return action;
        }

        public ShortcutSpec setAction(String action) {
            this.action = action;
            return this;
        }

        public Byte getCtrlKey() {
            return ctrlKey;
        }

        public ShortcutSpec setCtrlKey(Byte ctrlKey) {
            this.ctrlKey = ctrlKey;
            return this;
        }

        public Integer getFunctionKey() {
            return functionKey;
        }

        public ShortcutSpec setFunctionKey(Integer functionKey) {
            this.functionKey = functionKey;
            return this;
        }
    }

    public static final class ActionOutcome {
        private boolean quit;
        private boolean chromeDirty;

        public boolean isQuit() {
            return quit;
        }

        public ActionOutcome setQuit(boolean quit) {
            this.quit = quit;
            return this;
        }

        public boolean isChromeDirty() {
            return chromeDirty;
        }

        public ActionOutcome setChromeDirty(boolean chromeDirty) {
            this.chromeDirty = chromeDirty;
            return this;
        }
    }

    public static final class HostInputResult {
        private byte[] forwardedInput = new byte[0];
        private boolean chromeDirty;
        private boolean render;
        private boolean quit;

        public byte[] getForwardedInput() {
            return forwardedInput;
        }

        public HostInputResult setForwardedInput(byte[] forwardedInput) {
            this.forwardedInput = forwardedInput == null ? new byte[0] : forwardedInput;
            return this;
        }

        public boolean isChromeDirty() {
            return chromeDirty;
        }

        public HostInputResult setChromeDirty(boolean chromeDirty) {
            this.chromeDirty = chromeDirty;
            return this;
        }

        public boolean isRender() {
            return render;
        }

        public HostInputResult setRender(boolean render) {
            this.render = render;
            return this;
        }

        public boolean isQuit() {
            return quit;
        }

        public HostInputResult setQuit(boolean quit) {
            this.quit = quit;
            return this;
        }
    }

    public static final class RunOptions {
        private int minWidth = 20;
        private int minHeight = 6;
        private int headerRows = 1;
        private int footerRows = 1;
        private long frameDelayMillis = 16L;
        private List<ShortcutSpec> shortcuts = new ArrayList<ShortcutSpec>();

        public int getMinWidth() {
            return minWidth;
        }

        public RunOptions setMinWidth(int minWidth) {
            this.minWidth = minWidth;
            return this;
        }

        public int getMinHeight() {
            return minHeight;
        }

        public RunOptions setMinHeight(int minHeight) {
            this.minHeight = minHeight;
            return this;
        }

        public int getHeaderRows() {
            return headerRows;
        }

        public RunOptions setHeaderRows(int headerRows) {
            this.headerRows = headerRows;
            return this;
        }

        public int getFooterRows() {
            return footerRows;
        }

        public RunOptions setFooterRows(int footerRows) {
            this.footerRows = footerRows;
            return this;
        }

        public long getFrameDelayMillis() {
            return frameDelayMillis;
        }

        public RunOptions setFrameDelayMillis(long frameDelayMillis) {
            this.frameDelayMillis = frameDelayMillis;
            return this;
        }

        public List<ShortcutSpec> getShortcuts() {
            return shortcuts;
        }

        public RunOptions setShortcuts(List<ShortcutSpec> shortcuts) {
            this.shortcuts = shortcuts == null ? new ArrayList<ShortcutSpec>() : shortcuts;
            return this;
        }
    }

    public static final class DebugPanelContext {
        private int width;
        private int height;
        private int viewportHeight;
        private String mode;
        private EditState editState;
        private VolvoxGridDesktopTerminalSession.Capabilities capabilities;
        private long renderNanos;
        private double renderFps;

        public int getWidth() {
            return width;
        }

        public DebugPanelContext setWidth(int width) {
            this.width = width;
            return this;
        }

        public int getHeight() {
            return height;
        }

        public DebugPanelContext setHeight(int height) {
            this.height = height;
            return this;
        }

        public int getViewportHeight() {
            return viewportHeight;
        }

        public DebugPanelContext setViewportHeight(int viewportHeight) {
            this.viewportHeight = viewportHeight;
            return this;
        }

        public String getMode() {
            return mode;
        }

        public DebugPanelContext setMode(String mode) {
            this.mode = mode;
            return this;
        }

        public EditState getEditState() {
            return editState;
        }

        public DebugPanelContext setEditState(EditState editState) {
            this.editState = editState;
            return this;
        }

        public VolvoxGridDesktopTerminalSession.Capabilities getCapabilities() {
            return capabilities;
        }

        public DebugPanelContext setCapabilities(VolvoxGridDesktopTerminalSession.Capabilities capabilities) {
            this.capabilities = capabilities;
            return this;
        }

        public long getRenderNanos() {
            return renderNanos;
        }

        public DebugPanelContext setRenderNanos(long renderNanos) {
            this.renderNanos = renderNanos;
            return this;
        }

        public double getRenderFps() {
            return renderFps;
        }

        public DebugPanelContext setRenderFps(double renderFps) {
            this.renderFps = renderFps;
            return this;
        }

        public VolvoxGridDesktopTerminalSession.Frame getFrame() {
            return frame;
        }

        public DebugPanelContext setFrame(VolvoxGridDesktopTerminalSession.Frame frame) {
            this.frame = frame;
            return this;
        }

        private VolvoxGridDesktopTerminalSession.Frame frame;
    }

    private VolvoxGridDesktopTuiRunner() {}

    public static void run(
        VolvoxGridDesktopTerminalHost terminal,
        Controller controller,
        RunOptions options
    ) throws SynurangDesktopBridge.SynurangBridgeException, IOException {
        if (terminal == null) {
            throw new NullPointerException("terminal");
        }
        if (controller == null) {
            throw new NullPointerException("controller");
        }

        RunOptions normalized = normalizeOptions(options);
        ShortcutRouter router = new ShortcutRouter(withBuiltInShortcuts(normalized.getShortcuts()));
        HostInputHandler hostInputHandler = controller instanceof HostInputHandler
            ? (HostInputHandler) controller
            : null;
        DebugPanelProvider debugPanel = controller instanceof DebugPanelProvider
            ? (DebugPanelProvider) controller
            : null;
        boolean cancelled = false;
        int lastWidth = -1;
        int lastHeight = -1;
        boolean chromeDirty = true;
        VolvoxGridDesktopTerminalSession session = null;
        boolean needRender = true;
        boolean animate = false;
        long renderNanos = 0L;
        double renderFps = 0.0;

        try {
            while (!cancelled) {
                if (needRender) {
                    ChromeLayout layout = calculateLayout(terminal, normalized, debugPanel);
                    int width = layout.width;
                    int height = layout.height;
                    int viewportHeight = layout.viewportHeight;
                    if (width != lastWidth || height != lastHeight) {
                        lastWidth = width;
                        lastHeight = height;
                        chromeDirty = true;
                    }

                    session = controller.ensureSession(width, viewportHeight);
                    if (session == null) {
                        throw new IllegalStateException("ensureSession returned null");
                    }
                    VolvoxGridDesktopTerminalSession.Capabilities capabilities = terminal.detectCapabilities();
                    session.setCapabilities(capabilities);
                    session.setViewport(0, layout.headerRows, width, viewportHeight, false);

                    EditState editState = controller.getCurrentEditState();
                    String mode = modeLabel(editState);
                    if (chromeDirty) {
                        controller.drawChrome(terminal, width, height, mode);
                        chromeDirty = false;
                    }

                    long renderStart = System.nanoTime();
                    VolvoxGridDesktopTerminalSession.Frame frame = session.render();
                    renderNanos = System.nanoTime() - renderStart;
                    renderFps = updateRenderFps(renderFps, renderNanos);
                    terminal.write(frame.getBuffer(), frame.getBytesWritten());
                    if (debugPanel != null && debugPanel.debugPanelVisible()) {
                        List<String> lines = debugPanel.debugPanelLines(
                            new DebugPanelContext()
                                .setWidth(width)
                                .setHeight(height)
                                .setViewportHeight(viewportHeight)
                                .setMode(mode)
                                .setEditState(editState)
                                .setCapabilities(capabilities)
                                .setRenderNanos(renderNanos)
                                .setRenderFps(renderFps)
                                .setFrame(frame)
                        );
                        writeDebugPanel(terminal, normalized.getHeaderRows(), width, getDebugPanelRows(debugPanel), lines);
                    }
                    needRender = false;
                    animate = frame != null && frame.isRendered();
                    continue;
                }

                long waitMillis = animate && normalized.getFrameDelayMillis() > 0L
                    ? normalized.getFrameDelayMillis()
                    : -1L;
                boolean signaled;
                try {
                    signaled = terminal.waitForEvent(waitMillis);
                } catch (InterruptedException ex) {
                    Thread.currentThread().interrupt();
                    cancelled = true;
                    continue;
                }
                if (!signaled) {
                    if (animate) {
                        needRender = true;
                    }
                    continue;
                }

                IOException pendingError = terminal.takePendingError();
                if (pendingError != null) {
                    throw pendingError;
                }
                if (terminal.consumeCancelled()) {
                    cancelled = true;
                    continue;
                }

                boolean resized = terminal.consumeResize();
                if (resized) {
                    chromeDirty = true;
                    needRender = true;
                    animate = false;
                }

                byte[] input = terminal.readInput();
                if (input.length == 0) {
                    continue;
                }

                ChromeLayout layout = calculateLayout(terminal, normalized, debugPanel);
                int width = layout.width;
                int height = layout.height;
                int viewportHeight = layout.viewportHeight;
                if (width != lastWidth || height != lastHeight) {
                    lastWidth = width;
                    lastHeight = height;
                    chromeDirty = true;
                }

                session = controller.ensureSession(width, viewportHeight);
                if (session == null) {
                    throw new IllegalStateException("ensureSession returned null");
                }
                session.setCapabilities(terminal.detectCapabilities());
                session.setViewport(0, layout.headerRows, width, viewportHeight, false);

                ShortcutResult shortcutResult = router.filter(input);
                byte[] forwardedInput = shortcutResult.forwardedInput;
                if (hostInputHandler != null && forwardedInput.length > 0) {
                    HostInputResult hostResult = hostInputHandler.handleHostInput(
                        forwardedInput,
                        controller.getCurrentEditState(),
                        width,
                        viewportHeight
                    );
                    if (hostResult != null) {
                        forwardedInput = hostResult.getForwardedInput();
                        if (hostResult.isChromeDirty()) {
                            chromeDirty = true;
                        }
                        if (hostResult.isRender()) {
                            needRender = true;
                        }
                        if (hostResult.isQuit()) {
                            cancelled = true;
                        }
                    }
                }
                if (cancelled) {
                    continue;
                }

                if (forwardedInput.length > 0) {
                    session.sendInputBytes(forwardedInput);
                    needRender = true;
                }

                if (ACTION_TOGGLE_DEBUG_PANEL.equals(shortcutResult.action)) {
                    if (debugPanel != null) {
                        debugPanel.toggleDebugPanel();
                        chromeDirty = true;
                        needRender = true;
                    }
                } else if (shortcutResult.action != null) {
                    controller.cancelActiveEdit();
                    ActionOutcome outcome = controller.handleAction(shortcutResult.action, width, viewportHeight);
                    if (outcome != null && outcome.isChromeDirty()) {
                        chromeDirty = true;
                    }
                    if (outcome != null && outcome.isQuit()) {
                        cancelled = true;
                        continue;
                    }

                    session = controller.ensureSession(width, viewportHeight);
                    if (session == null) {
                        throw new IllegalStateException("ensureSession returned null");
                    }
                    session.setCapabilities(terminal.detectCapabilities());
                    session.setViewport(0, layout.headerRows, width, viewportHeight, false);
                    needRender = true;
                }

                if (chromeDirty) {
                    needRender = true;
                }
                animate = false;
            }
        } finally {
            if (session != null) {
                try {
                    VolvoxGridDesktopTerminalSession.Frame frame = session.shutdown();
                    terminal.write(frame.getBuffer(), frame.getBytesWritten());
                } catch (Throwable ignored) {
                }
            }
        }
    }

    public static String modeLabel(EditState state) {
        if (state == null || !state.getActive()) {
            return "Ready";
        }
        return state.getUiMode() == EditUiMode.EDIT_UI_MODE_EDIT ? "Edit" : "Enter";
    }

    private static RunOptions normalizeOptions(RunOptions options) {
        RunOptions normalized = options == null ? new RunOptions() : options;
        if (normalized.getMinWidth() <= 0) {
            normalized.setMinWidth(20);
        }
        if (normalized.getMinHeight() <= 0) {
            normalized.setMinHeight(6);
        }
        if (normalized.getHeaderRows() < 0) {
            normalized.setHeaderRows(1);
        }
        if (normalized.getFooterRows() < 0) {
            normalized.setFooterRows(1);
        }
        if (normalized.getFrameDelayMillis() < 0) {
            normalized.setFrameDelayMillis(16L);
        }
        if (normalized.getShortcuts() == null) {
            normalized.setShortcuts(new ArrayList<ShortcutSpec>());
        }
        return normalized;
    }

    private static List<ShortcutSpec> withBuiltInShortcuts(List<ShortcutSpec> shortcuts) {
        ArrayList<ShortcutSpec> all = new ArrayList<ShortcutSpec>((shortcuts == null ? 0 : shortcuts.size()) + 1);
        all.add(new ShortcutSpec().setAction(ACTION_TOGGLE_DEBUG_PANEL).setFunctionKey(Integer.valueOf(12)));
        if (shortcuts != null) {
            all.addAll(shortcuts);
        }
        return all;
    }

    private static ChromeLayout calculateLayout(
        VolvoxGridDesktopTerminalHost terminal,
        RunOptions options,
        DebugPanelProvider debugPanel
    ) {
        ChromeLayout layout = new ChromeLayout();
        layout.width = Math.max(options.getMinWidth(), terminal.getWidth());
        layout.height = Math.max(options.getMinHeight(), terminal.getHeight());
        layout.headerRows = Math.max(0, options.getHeaderRows());
        layout.footerRows = Math.max(0, options.getFooterRows());
        if (debugPanel != null && debugPanel.debugPanelVisible()) {
            layout.headerRows += getDebugPanelRows(debugPanel);
        }
        layout.viewportHeight = Math.max(1, layout.height - layout.headerRows - layout.footerRows);
        return layout;
    }

    private static double updateRenderFps(double current, long renderNanos) {
        if (renderNanos <= 0L) {
            return current;
        }
        double inst = 1_000_000_000.0 / (double) renderNanos;
        if (current <= 0.0) {
            return inst;
        }
        return current * 0.9 + inst * 0.1;
    }

    private static int getDebugPanelRows(DebugPanelProvider debugPanel) {
        if (debugPanel == null) {
            return 0;
        }
        return Math.max(1, debugPanel.debugPanelRows());
    }

    private static void writeDebugPanel(
        VolvoxGridDesktopTerminalHost terminal,
        int baseHeaderRows,
        int width,
        int rows,
        List<String> lines
    ) throws IOException {
        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < rows; i += 1) {
            String line = lines != null && i < lines.size() ? lines.get(i) : "";
            int row = Math.max(1, baseHeaderRows + 1 + i);
            builder.append("\u001b[").append(row).append(";1H\u001b[0m").append(fitChromeLine(line, width));
        }
        terminal.writeText(builder.toString());
    }

    private static String fitChromeLine(String text, int width) {
        String value = text == null ? "" : text;
        if (width <= 0) {
            return "";
        }
        if (value.length() > width) {
            return value.substring(0, width);
        }
        if (value.length() < width) {
            StringBuilder builder = new StringBuilder(width);
            builder.append(value);
            while (builder.length() < width) {
                builder.append(' ');
            }
            return builder.toString();
        }
        return value;
    }

    private static final class ChromeLayout {
        private int width;
        private int height;
        private int headerRows;
        private int footerRows;
        private int viewportHeight;
    }

    private enum EscapeActionState {
        NO_MATCH,
        MATCHED,
        NEED_MORE_DATA,
    }

    private static final class ShortcutResult {
        private static final ShortcutResult EMPTY = new ShortcutResult(new byte[0], null);
        private final byte[] forwardedInput;
        private final String action;

        private ShortcutResult(byte[] forwardedInput, String action) {
            this.forwardedInput = forwardedInput == null ? new byte[0] : forwardedInput;
            this.action = action;
        }
    }

    private static final class EscapeMatchResult {
        private final EscapeActionState state;
        private final int functionKey;
        private final int consumed;

        private EscapeMatchResult(EscapeActionState state, int functionKey, int consumed) {
            this.state = state;
            this.functionKey = functionKey;
            this.consumed = consumed;
        }
    }

    private static final class ShortcutRouter {
        private final List<ShortcutSpec> shortcuts;
        private final ByteArrayOutputStream pending = new ByteArrayOutputStream();

        private ShortcutRouter(List<ShortcutSpec> shortcuts) {
            this.shortcuts = shortcuts == null ? new ArrayList<ShortcutSpec>() : shortcuts;
        }

        private ShortcutResult filter(byte[] input) {
            byte[] mergedInput = mergePending(input);
            if (mergedInput.length == 0) {
                return ShortcutResult.EMPTY;
            }

            ByteArrayOutputStream forwarded = new ByteArrayOutputStream(mergedInput.length);
            int index = 0;
            while (index < mergedInput.length) {
                byte value = mergedInput[index];
                String ctrlAction = matchCtrl(value);
                if (ctrlAction != null) {
                    return new ShortcutResult(forwarded.toByteArray(), ctrlAction);
                }

                if (value == 0x1B) {
                    EscapeMatchResult match = tryDecodeFunctionKey(mergedInput, index);
                    if (match.state == EscapeActionState.NEED_MORE_DATA) {
                        savePending(mergedInput, index);
                        return new ShortcutResult(forwarded.toByteArray(), null);
                    }
                    if (match.state == EscapeActionState.MATCHED) {
                        String functionAction = matchFunctionKey(match.functionKey);
                        if (functionAction != null) {
                            return new ShortcutResult(forwarded.toByteArray(), functionAction);
                        }
                        forwarded.write(mergedInput, index, match.consumed);
                        index += match.consumed;
                        continue;
                    }

                    int consumed = copyEscapeSequence(mergedInput, index, forwarded);
                    if (consumed <= 0) {
                        savePending(mergedInput, index);
                        return new ShortcutResult(forwarded.toByteArray(), null);
                    }
                    index += consumed;
                    continue;
                }

                forwarded.write(value);
                index += 1;
            }

            return new ShortcutResult(forwarded.toByteArray(), null);
        }

        private byte[] mergePending(byte[] input) {
            if (pending.size() == 0) {
                return input == null ? new byte[0] : input;
            }

            byte[] pendingBytes = pending.toByteArray();
            pending.reset();
            int inputLength = input == null ? 0 : input.length;
            byte[] merged = new byte[pendingBytes.length + inputLength];
            System.arraycopy(pendingBytes, 0, merged, 0, pendingBytes.length);
            if (inputLength > 0) {
                System.arraycopy(input, 0, merged, pendingBytes.length, inputLength);
            }
            return merged;
        }

        private void savePending(byte[] input, int start) {
            pending.reset();
            pending.write(input, start, input.length - start);
        }

        private String matchCtrl(byte value) {
            for (ShortcutSpec shortcut : shortcuts) {
                if (shortcut == null || shortcut.getAction() == null || shortcut.getCtrlKey() == null) {
                    continue;
                }
                if (shortcut.getCtrlKey().byteValue() == value) {
                    return shortcut.getAction();
                }
            }
            return null;
        }

        private String matchFunctionKey(int functionKey) {
            for (ShortcutSpec shortcut : shortcuts) {
                if (shortcut == null || shortcut.getAction() == null || shortcut.getFunctionKey() == null) {
                    continue;
                }
                if (shortcut.getFunctionKey().intValue() == functionKey) {
                    return shortcut.getAction();
                }
            }
            return null;
        }

        private EscapeMatchResult tryDecodeFunctionKey(byte[] input, int start) {
            int remaining = input.length - start;
            if (remaining <= 1) {
                return new EscapeMatchResult(EscapeActionState.NO_MATCH, 0, 0);
            }

            byte second = input[start + 1];
            if (second == 'O') {
                if (remaining < 3) {
                    return new EscapeMatchResult(EscapeActionState.NEED_MORE_DATA, 0, 0);
                }
                switch (input[start + 2]) {
                    case 'P':
                        return new EscapeMatchResult(EscapeActionState.MATCHED, 1, 3);
                    case 'Q':
                        return new EscapeMatchResult(EscapeActionState.MATCHED, 2, 3);
                    case 'R':
                        return new EscapeMatchResult(EscapeActionState.MATCHED, 3, 3);
                    case 'S':
                        return new EscapeMatchResult(EscapeActionState.MATCHED, 4, 3);
                    default:
                        return new EscapeMatchResult(EscapeActionState.NO_MATCH, 0, 3);
                }
            }
            if (second != '[') {
                return new EscapeMatchResult(EscapeActionState.NO_MATCH, 0, 2);
            }

            int index = start + 2;
            while (index < input.length) {
                byte value = input[index];
                if (isEscapeTerminator(value)) {
                    index += 1;
                    break;
                }
                index += 1;
            }

            if (index > input.length) {
                return new EscapeMatchResult(EscapeActionState.NEED_MORE_DATA, 0, 0);
            }
            if (index == input.length && !isEscapeTerminator(input[index - 1])) {
                return new EscapeMatchResult(EscapeActionState.NEED_MORE_DATA, 0, 0);
            }

            int consumed = index - start;
            if (input[index - 1] != '~') {
                return new EscapeMatchResult(EscapeActionState.NO_MATCH, 0, consumed);
            }

            String payload = new String(input, start + 2, consumed - 3, StandardCharsets.US_ASCII);
            int separator = payload.indexOf(';');
            String first = separator >= 0 ? payload.substring(0, separator) : payload;
            int code;
            try {
                code = Integer.parseInt(first);
            } catch (NumberFormatException ex) {
                return new EscapeMatchResult(EscapeActionState.NO_MATCH, 0, consumed);
            }

            switch (code) {
                case 11:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 1, consumed);
                case 12:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 2, consumed);
                case 13:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 3, consumed);
                case 14:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 4, consumed);
                case 15:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 5, consumed);
                case 17:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 6, consumed);
                case 18:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 7, consumed);
                case 19:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 8, consumed);
                case 20:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 9, consumed);
                case 21:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 10, consumed);
                case 23:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 11, consumed);
                case 24:
                    return new EscapeMatchResult(EscapeActionState.MATCHED, 12, consumed);
                default:
                    return new EscapeMatchResult(EscapeActionState.NO_MATCH, 0, consumed);
            }
        }

        private int copyEscapeSequence(byte[] input, int start, ByteArrayOutputStream forwarded) {
            int remaining = input.length - start;
            if (remaining <= 0) {
                return 0;
            }
            if (remaining == 1) {
                forwarded.write(input[start]);
                return 1;
            }

            byte second = input[start + 1];
            if (second == 'O') {
                if (remaining < 3) {
                    return 0;
                }
                forwarded.write(input, start, 3);
                return 3;
            }

            if (second != '[') {
                forwarded.write(input[start]);
                forwarded.write(second);
                return 2;
            }

            int index = start + 2;
            while (index < input.length) {
                byte value = input[index];
                if (isEscapeTerminator(value)) {
                    index += 1;
                    break;
                }
                index += 1;
            }

            if (index > input.length) {
                return 0;
            }
            if (index == input.length && !isEscapeTerminator(input[index - 1])) {
                return 0;
            }

            int consumed = index - start;
            if (consumed <= 0) {
                return 0;
            }
            forwarded.write(input, start, consumed);
            return consumed;
        }

        private boolean isEscapeTerminator(byte value) {
            return (value >= 'A' && value <= 'Z')
                || (value >= 'a' && value <= 'z')
                || value == '~';
        }
    }
}
