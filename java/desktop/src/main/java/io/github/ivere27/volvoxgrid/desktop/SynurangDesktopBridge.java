package io.github.ivere27.volvoxgrid.desktop;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.nio.Buffer;
import java.nio.ByteBuffer;
import java.util.Objects;

/**
 * Reflection bridge for Synurang desktop host.
 *
 * Expected host classes:
 * - io.github.ivere27.synurang.PluginHost
 * - io.github.ivere27.synurang.PluginStream
 */
public final class SynurangDesktopBridge implements AutoCloseable {
    private static final String SYNURANG_HOST_CLASS = "io.github.ivere27.synurang.PluginHost";

    private final Object host;
    private final Method invokeMethod;
    private final Method openStreamMethod;
    private final Method closeMethod;
    private final Method directBufferAddressMethod;

    private SynurangDesktopBridge(Object host, Class<?> hostClass) throws SynurangBridgeException {
        this.host = host;
        try {
            this.invokeMethod = hostClass.getMethod("invoke", String.class, String.class, byte[].class);
            this.openStreamMethod = hostClass.getMethod("openStream", String.class, String.class);
            this.closeMethod = hostClass.getMethod("close");
            Method directBufferMethod;
            try {
                directBufferMethod = hostClass.getMethod("getDirectBufferAddress", Buffer.class);
            } catch (NoSuchMethodException ignored) {
                directBufferMethod = hostClass.getMethod("getDirectBufferAddress", ByteBuffer.class);
            }
            this.directBufferAddressMethod = directBufferMethod;
        } catch (NoSuchMethodException e) {
            throw new SynurangBridgeException("Synurang host API mismatch", e);
        }
    }

    public static boolean isHostAvailable() {
        try {
            Class.forName(SYNURANG_HOST_CLASS);
            return true;
        } catch (ClassNotFoundException e) {
            return false;
        }
    }

    public static SynurangDesktopBridge load(String libraryPath) throws SynurangBridgeException {
        Objects.requireNonNull(libraryPath, "libraryPath");
        try {
            Class<?> hostClass = Class.forName(SYNURANG_HOST_CLASS);
            Method loadMethod = hostClass.getMethod("load", String.class);
            Object host = loadMethod.invoke(null, libraryPath);
            VolvoxGridBuildInfo.logDesktopLibraryLoadOnce(libraryPath);
            return new SynurangDesktopBridge(host, hostClass);
        } catch (ClassNotFoundException e) {
            throw new SynurangBridgeException(
                "Synurang desktop host is not available. "
                    + "Expected class: " + SYNURANG_HOST_CLASS,
                e
            );
        } catch (NoSuchMethodException e) {
            throw new SynurangBridgeException("Synurang host missing PluginHost.load(String)", e);
        } catch (InvocationTargetException e) {
            throw unwrap("Failed to load Synurang host", e);
        } catch (IllegalAccessException e) {
            throw new SynurangBridgeException("Cannot access Synurang host", e);
        }
    }

    public byte[] invoke(String service, String methodPath, byte[] payload) throws SynurangBridgeException {
        Objects.requireNonNull(service, "service");
        Objects.requireNonNull(methodPath, "methodPath");
        Objects.requireNonNull(payload, "payload");
        try {
            return (byte[]) invokeMethod.invoke(host, service, methodPath, payload);
        } catch (InvocationTargetException e) {
            throw unwrap("Synurang invoke failed: " + methodPath, e);
        } catch (IllegalAccessException e) {
            throw new SynurangBridgeException("Cannot access Synurang invoke", e);
        }
    }

    public RuntimeStreamBridge openStream(String service, String methodPath) throws SynurangBridgeException {
        Objects.requireNonNull(service, "service");
        Objects.requireNonNull(methodPath, "methodPath");
        try {
            Object stream = openStreamMethod.invoke(host, service, methodPath);
            return new RuntimeStreamBridge(stream);
        } catch (InvocationTargetException e) {
            throw unwrap("Failed to open stream: " + methodPath, e);
        } catch (IllegalAccessException e) {
            throw new SynurangBridgeException("Cannot access Synurang openStream", e);
        }
    }

    public long getDirectBufferAddress(ByteBuffer buffer) throws SynurangBridgeException {
        Objects.requireNonNull(buffer, "buffer");
        try {
            Object result = directBufferAddressMethod.invoke(null, buffer);
            if (!(result instanceof Number)) {
                throw new SynurangBridgeException("getDirectBufferAddress returned non-number value");
            }
            return ((Number) result).longValue();
        } catch (InvocationTargetException e) {
            throw unwrap("Failed to get direct buffer address", e);
        } catch (IllegalAccessException e) {
            throw new SynurangBridgeException("Cannot access getDirectBufferAddress", e);
        }
    }

    @Override
    public void close() throws SynurangBridgeException {
        try {
            closeMethod.invoke(host);
        } catch (InvocationTargetException e) {
            throw unwrap("Failed to close Synurang host", e);
        } catch (IllegalAccessException e) {
            throw new SynurangBridgeException("Cannot access PluginHost.close", e);
        }
    }

    private static SynurangBridgeException unwrap(String message, InvocationTargetException e) {
        Throwable cause = e.getTargetException() != null ? e.getTargetException() : e;
        return new SynurangBridgeException(message + ": " + cause.getMessage(), cause);
    }

    public static final class RuntimeStreamBridge implements AutoCloseable {
        private final Object stream;
        private final Method sendMethod;
        private final Method recvMethod;
        private final Method closeSendMethod;
        private final Method closeMethod;

        private RuntimeStreamBridge(Object stream) throws SynurangBridgeException {
            this.stream = Objects.requireNonNull(stream, "stream");
            Class<?> streamClass = stream.getClass();
            try {
                this.sendMethod = streamClass.getMethod("send", byte[].class);
                this.recvMethod = streamClass.getMethod("recv");
                this.closeSendMethod = streamClass.getMethod("closeSend");
                this.closeMethod = streamClass.getMethod("close");
            } catch (NoSuchMethodException e) {
                throw new SynurangBridgeException("Synurang PluginStream API mismatch", e);
            }
        }

        public void send(byte[] data) throws SynurangBridgeException {
            Objects.requireNonNull(data, "data");
            try {
                sendMethod.invoke(stream, data);
            } catch (InvocationTargetException e) {
                throw unwrap("PluginStream.send failed", e);
            } catch (IllegalAccessException e) {
                throw new SynurangBridgeException("Cannot access PluginStream.send", e);
            }
        }

        public byte[] recv() throws SynurangBridgeException {
            try {
                Object result = recvMethod.invoke(stream);
                return (byte[]) result;
            } catch (InvocationTargetException e) {
                throw unwrap("PluginStream.recv failed", e);
            } catch (IllegalAccessException e) {
                throw new SynurangBridgeException("Cannot access PluginStream.recv", e);
            }
        }

        public void closeSend() throws SynurangBridgeException {
            try {
                closeSendMethod.invoke(stream);
            } catch (InvocationTargetException e) {
                throw unwrap("PluginStream.closeSend failed", e);
            } catch (IllegalAccessException e) {
                throw new SynurangBridgeException("Cannot access PluginStream.closeSend", e);
            }
        }

        @Override
        public void close() throws SynurangBridgeException {
            try {
                closeMethod.invoke(stream);
            } catch (InvocationTargetException e) {
                throw unwrap("PluginStream.close failed", e);
            } catch (IllegalAccessException e) {
                throw new SynurangBridgeException("Cannot access PluginStream.close", e);
            }
        }
    }

    public static class SynurangBridgeException extends RuntimeException {
        public SynurangBridgeException(String message) {
            super(message);
        }

        public SynurangBridgeException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
