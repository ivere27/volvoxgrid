package io.github.ivere27.volvoxgrid.desktop;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.nio.Buffer;
import java.nio.ByteBuffer;
import java.util.Objects;

/**
 * Reflection bridge for Synurang desktop runtime.
 *
 * Expected runtime classes:
 * - io.github.ivere27.synurang.PluginHost
 * - io.github.ivere27.synurang.PluginStream
 */
public final class SynurangDesktopBridge implements AutoCloseable {
    private static final String PLUGIN_HOST_CLASS = "io.github.ivere27.synurang.PluginHost";

    private final Object pluginHost;
    private final Method invokeMethod;
    private final Method openStreamMethod;
    private final Method closeMethod;
    private final Method directBufferAddressMethod;

    private SynurangDesktopBridge(Object pluginHost, Class<?> pluginHostClass) throws SynurangBridgeException {
        this.pluginHost = pluginHost;
        try {
            this.invokeMethod = pluginHostClass.getMethod("invoke", String.class, String.class, byte[].class);
            this.openStreamMethod = pluginHostClass.getMethod("openStream", String.class, String.class);
            this.closeMethod = pluginHostClass.getMethod("close");
            Method directBufferMethod;
            try {
                directBufferMethod = pluginHostClass.getMethod("getDirectBufferAddress", Buffer.class);
            } catch (NoSuchMethodException ignored) {
                directBufferMethod = pluginHostClass.getMethod("getDirectBufferAddress", ByteBuffer.class);
            }
            this.directBufferAddressMethod = directBufferMethod;
        } catch (NoSuchMethodException e) {
            throw new SynurangBridgeException("Synurang runtime API mismatch", e);
        }
    }

    public static boolean isRuntimeAvailable() {
        try {
            Class.forName(PLUGIN_HOST_CLASS);
            return true;
        } catch (ClassNotFoundException e) {
            return false;
        }
    }

    public static SynurangDesktopBridge load(String pluginPath) throws SynurangBridgeException {
        Objects.requireNonNull(pluginPath, "pluginPath");
        try {
            Class<?> hostClass = Class.forName(PLUGIN_HOST_CLASS);
            Method loadMethod = hostClass.getMethod("load", String.class);
            Object host = loadMethod.invoke(null, pluginPath);
            return new SynurangDesktopBridge(host, hostClass);
        } catch (ClassNotFoundException e) {
            throw new SynurangBridgeException(
                "Synurang desktop runtime is not available. "
                    + "Expected class: " + PLUGIN_HOST_CLASS,
                e
            );
        } catch (NoSuchMethodException e) {
            throw new SynurangBridgeException("Synurang runtime missing PluginHost.load(String)", e);
        } catch (InvocationTargetException e) {
            throw unwrap("Failed to load plugin host", e);
        } catch (IllegalAccessException e) {
            throw new SynurangBridgeException("Cannot access Synurang runtime", e);
        }
    }

    public byte[] invoke(String service, String methodPath, byte[] payload) throws SynurangBridgeException {
        Objects.requireNonNull(service, "service");
        Objects.requireNonNull(methodPath, "methodPath");
        Objects.requireNonNull(payload, "payload");
        try {
            return (byte[]) invokeMethod.invoke(pluginHost, service, methodPath, payload);
        } catch (InvocationTargetException e) {
            throw unwrap("Synurang invoke failed: " + methodPath, e);
        } catch (IllegalAccessException e) {
            throw new SynurangBridgeException("Cannot access Synurang invoke", e);
        }
    }

    public PluginStreamBridge openStream(String service, String methodPath) throws SynurangBridgeException {
        Objects.requireNonNull(service, "service");
        Objects.requireNonNull(methodPath, "methodPath");
        try {
            Object stream = openStreamMethod.invoke(pluginHost, service, methodPath);
            return new PluginStreamBridge(stream);
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
            closeMethod.invoke(pluginHost);
        } catch (InvocationTargetException e) {
            throw unwrap("Failed to close plugin host", e);
        } catch (IllegalAccessException e) {
            throw new SynurangBridgeException("Cannot access PluginHost.close", e);
        }
    }

    private static SynurangBridgeException unwrap(String message, InvocationTargetException e) {
        Throwable cause = e.getTargetException() != null ? e.getTargetException() : e;
        return new SynurangBridgeException(message + ": " + cause.getMessage(), cause);
    }

    public static final class PluginStreamBridge implements AutoCloseable {
        private final Object stream;
        private final Method sendMethod;
        private final Method recvMethod;
        private final Method closeSendMethod;
        private final Method closeMethod;

        private PluginStreamBridge(Object stream) throws SynurangBridgeException {
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
