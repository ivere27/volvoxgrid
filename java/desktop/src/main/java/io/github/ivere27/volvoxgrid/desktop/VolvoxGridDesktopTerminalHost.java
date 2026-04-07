package io.github.ivere27.volvoxgrid.desktop;

import java.io.ByteArrayOutputStream;
import java.io.FileDescriptor;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.Locale;

public final class VolvoxGridDesktopTerminalHost implements AutoCloseable {
    private final InputStream stdin;
    private final OutputStream stdout;
    private final byte[] readBuffer = new byte[2048];
    private final String savedSttyState;
    private final VolvoxGridDesktopTerminalSession.Capabilities capabilities;
    private final Thread shutdownHook;
    private final Object eventLock = new Object();
    private final ArrayDeque<byte[]> pendingInput = new ArrayDeque<byte[]>();
    private final Thread inputThread;
    private final UnixSignalRegistration resizeSignalRegistration;
    private volatile boolean disposed;
    private volatile boolean cancelled;
    private volatile boolean resizePending;
    private volatile IOException pendingError;
    private volatile int width = 80;
    private volatile int height = 24;

    public VolvoxGridDesktopTerminalHost() throws IOException {
        String os = System.getProperty("os.name", "").toLowerCase(Locale.US);
        if (os.contains("win")) {
            throw new UnsupportedOperationException("The Java TUI sample currently supports Unix-like terminals only.");
        }

        this.stdin = new FileInputStream(FileDescriptor.in);
        this.stdout = new FileOutputStream(FileDescriptor.out);
        this.savedSttyState = runStty("-g", true).trim();
        runStty("cbreak -echo -ixon min 1 time 0", false);
        refreshTerminalSize();
        this.capabilities = detectTerminalCapabilities();
        this.resizeSignalRegistration = UnixSignalRegistration.install("WINCH", new Runnable() {
            @Override
            public void run() {
                handleResizeSignal();
            }
        });
        this.inputThread = new Thread(new Runnable() {
            @Override
            public void run() {
                readLoop();
            }
        }, "volvoxgrid-java-tui-input");
        this.inputThread.setDaemon(true);
        this.inputThread.start();
        this.shutdownHook = new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    VolvoxGridDesktopTerminalHost.this.close();
                } catch (Exception ignored) {
                }
            }
        }, "volvoxgrid-java-tui-restore");
        Runtime.getRuntime().addShutdownHook(shutdownHook);
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public VolvoxGridDesktopTerminalSession.Capabilities detectCapabilities() {
        return new VolvoxGridDesktopTerminalSession.Capabilities()
            .setColorLevel(capabilities.getColorLevel())
            .setSgrMouse(capabilities.isSgrMouse())
            .setFocusEvents(capabilities.isFocusEvents())
            .setBracketedPaste(capabilities.isBracketedPaste());
    }

    public byte[] readInput() {
        synchronized (eventLock) {
            if (pendingInput.isEmpty()) {
                return new byte[0];
            }
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            while (!pendingInput.isEmpty()) {
                byte[] chunk = pendingInput.removeFirst();
                bytes.write(chunk, 0, chunk.length);
            }
            return bytes.toByteArray();
        }
    }

    public boolean consumeCancelled() {
        boolean value = cancelled;
        cancelled = false;
        return value;
    }

    public IOException takePendingError() {
        IOException error = pendingError;
        pendingError = null;
        return error;
    }

    public boolean consumeResize() {
        boolean value = resizePending;
        resizePending = false;
        return value;
    }

    public boolean waitForEvent(long timeoutMillis) throws InterruptedException {
        synchronized (eventLock) {
            if (hasPendingEvent()) {
                return true;
            }
            if (timeoutMillis < 0L) {
                while (!hasPendingEvent() && !disposed) {
                    eventLock.wait();
                }
            } else if (timeoutMillis > 0L) {
                eventLock.wait(timeoutMillis);
            }
            return hasPendingEvent();
        }
    }

    public void signalWake() {
        synchronized (eventLock) {
            eventLock.notifyAll();
        }
    }

    public void write(byte[] buffer, int count) throws IOException {
        if (buffer == null || count <= 0) {
            return;
        }
        stdout.write(buffer, 0, Math.min(count, buffer.length));
        stdout.flush();
    }

    public void writeText(String text) throws IOException {
        byte[] bytes = (text == null ? "" : text).getBytes(StandardCharsets.UTF_8);
        stdout.write(bytes);
        stdout.flush();
    }

    @Override
    public void close() throws IOException {
        if (disposed) {
            return;
        }
        disposed = true;
        signalWake();

        try {
            resizeSignalRegistration.close();
        } catch (Exception ignored) {
        }

        try {
            writeText("\u001b[0m\u001b[?25h\u001b[?1006l\u001b[?1002l\u001b[?1000l\u001b[?1004l\u001b[?2004l");
        } catch (Exception ignored) {
        }

        try {
            if (!savedSttyState.isEmpty()) {
                runStty(savedSttyState, false);
            }
        } catch (Exception ignored) {
        }

        try {
            Runtime.getRuntime().removeShutdownHook(shutdownHook);
        } catch (IllegalStateException ignored) {
        }
    }

    private void refreshTerminalSize() {
        try {
            String output = runStty("size", true).trim();
            String[] parts = output.split("\\s+");
            if (parts.length >= 2) {
                int rows = Integer.parseInt(parts[0]);
                int cols = Integer.parseInt(parts[1]);
                if (cols > 1) {
                    width = cols;
                }
                if (rows > 1) {
                    height = rows;
                }
            }
        } catch (Exception ignored) {
        }
    }

    private void handleResizeSignal() {
        if (disposed) {
            return;
        }
        refreshTerminalSize();
        resizePending = true;
        signalWake();
    }

    private boolean hasPendingEvent() {
        return !pendingInput.isEmpty() || pendingError != null || resizePending || cancelled;
    }

    private void readLoop() {
        while (!disposed) {
            int count;
            try {
                count = stdin.read(readBuffer);
            } catch (IOException ex) {
                if (disposed) {
                    return;
                }
                pendingError = ex;
                cancelled = true;
                signalWake();
                return;
            }

            if (count < 0) {
                if (disposed) {
                    return;
                }
                pendingError = new IOException("Terminal input stream closed.");
                cancelled = true;
                signalWake();
                return;
            }
            if (count == 0) {
                continue;
            }

            byte[] data = new byte[count];
            System.arraycopy(readBuffer, 0, data, 0, count);
            synchronized (eventLock) {
                pendingInput.addLast(data);
            }
            signalWake();
        }
    }

    private static final class UnixSignalRegistration implements AutoCloseable {
        private final Method handleMethod;
        private final Object signal;
        private final Object previousHandler;

        private UnixSignalRegistration(Method handleMethod, Object signal, Object previousHandler) {
            this.handleMethod = handleMethod;
            this.signal = signal;
            this.previousHandler = previousHandler;
        }

        static UnixSignalRegistration install(String signalName, final Runnable handler) throws IOException {
            try {
                final Class<?> signalClass = Class.forName("sun.misc.Signal");
                Class<?> signalHandlerClass = Class.forName("sun.misc.SignalHandler");
                Object signal = signalClass.getConstructor(String.class).newInstance(signalName);
                Object proxy = Proxy.newProxyInstance(
                    VolvoxGridDesktopTerminalHost.class.getClassLoader(),
                    new Class<?>[] { signalHandlerClass },
                    new InvocationHandler() {
                        @Override
                        public Object invoke(Object proxy, Method method, Object[] args) {
                            if ("handle".equals(method.getName())) {
                                handler.run();
                            }
                            return null;
                        }
                    }
                );
                Method handleMethod = signalClass.getMethod("handle", signalClass, signalHandlerClass);
                Object previousHandler = handleMethod.invoke(null, signal, proxy);
                return new UnixSignalRegistration(handleMethod, signal, previousHandler);
            } catch (ClassNotFoundException ex) {
                throw new IOException("Unix signal support is unavailable for " + signalName + ".", ex);
            } catch (ReflectiveOperationException ex) {
                throw new IOException("Failed to register Unix signal " + signalName + ".", ex);
            } catch (SecurityException ex) {
                throw new IOException("Unix signal registration denied for " + signalName + ".", ex);
            }
        }

        @Override
        public void close() throws IOException {
            if (previousHandler == null) {
                return;
            }
            try {
                handleMethod.invoke(null, signal, previousHandler);
            } catch (ReflectiveOperationException ex) {
                throw new IOException("Failed to restore previous Unix signal handler.", ex);
            }
        }
    }

    private static VolvoxGridDesktopTerminalSession.Capabilities detectTerminalCapabilities() {
        String term = valueOfEnv("TERM").toLowerCase(Locale.US);
        String colorTerm = valueOfEnv("COLORTERM").toLowerCase(Locale.US);

        VolvoxGridDesktopTerminalSession.ColorLevel colorLevel;
        if (colorTerm.contains("truecolor") || colorTerm.contains("24bit")) {
            colorLevel = VolvoxGridDesktopTerminalSession.ColorLevel.TRUECOLOR;
        } else if (term.contains("256color")) {
            colorLevel = VolvoxGridDesktopTerminalSession.ColorLevel.INDEXED_256;
        } else {
            colorLevel = VolvoxGridDesktopTerminalSession.ColorLevel.ANSI_16;
        }

        return new VolvoxGridDesktopTerminalSession.Capabilities()
            .setColorLevel(colorLevel)
            .setSgrMouse(true)
            .setFocusEvents(true)
            .setBracketedPaste(true);
    }

    private static String valueOfEnv(String name) {
        String value = System.getenv(name);
        return value == null ? "" : value;
    }

    private static String runShell(String command, boolean captureOutput) throws IOException {
        ProcessBuilder builder = new ProcessBuilder("sh", "-lc", command);
        builder.redirectErrorStream(true);
        Process process = builder.start();
        String output;
        try {
            output = readFully(process.getInputStream());
        } finally {
            try {
                process.getOutputStream().close();
            } catch (IOException ignored) {
            }
        }
        try {
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                throw new IOException("Command failed: " + command + " -> " + output);
            }
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new IOException("Interrupted while running: " + command, ex);
        }
        return captureOutput ? output : "";
    }

    private static String runStty(String arguments, boolean captureOutput) throws IOException {
        try {
            return runShell("stty " + arguments + " < /dev/tty", captureOutput);
        } catch (IOException first) {
            return runShell("stty " + arguments, captureOutput);
        }
    }

    private static String readFully(InputStream input) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        byte[] buffer = new byte[1024];
        int count;
        while ((count = input.read(buffer)) >= 0) {
            if (count == 0) {
                continue;
            }
            bytes.write(buffer, 0, count);
        }
        return new String(bytes.toByteArray(), StandardCharsets.UTF_8);
    }
}
