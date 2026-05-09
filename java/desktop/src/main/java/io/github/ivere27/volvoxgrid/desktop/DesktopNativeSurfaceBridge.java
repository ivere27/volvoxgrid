package io.github.ivere27.volvoxgrid.desktop;

import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Platform;
import com.sun.jna.Pointer;
import java.awt.Component;
import java.awt.HeadlessException;
import java.io.File;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.logging.Level;
import java.util.logging.Logger;

final class DesktopNativeSurfaceBridge implements AutoCloseable {
    private static final Logger LOG = Logger.getLogger(DesktopNativeSurfaceBridge.class.getName());

    private static final int KIND_X11 = 2;
    private static final int KIND_WIN32 = 3;
    private static final int KIND_APPKIT = 4;
    private static final Object JAWT_LOAD_LOCK = new Object();
    private static volatile boolean jawtLoadAttempted = false;
    private static volatile String jawtLoadFailure = "";

    interface NativeSurfaceApi extends Library {
        Pointer volvox_grid_native_surface_descriptor_new(
            int kind,
            int screen,
            Pointer display,
            Pointer surface,
            long window
        );

        void volvox_grid_native_surface_descriptor_free(Pointer descriptor);
    }

    interface X11Api extends Library {
        Pointer XOpenDisplay(String displayName);
        int XDefaultScreen(Pointer display);
        int XCloseDisplay(Pointer display);
    }

    private final NativeSurfaceApi api;
    private X11Api x11;
    private Pointer x11Display;
    private Pointer descriptor;
    private int descriptorKind = -1;
    private int descriptorScreen = 0;
    private long descriptorDisplay = 0L;
    private long descriptorSurface = 0L;
    private long descriptorWindow = 0L;
    private String lastFailure = "";

    private DesktopNativeSurfaceBridge(NativeSurfaceApi api) {
        this.api = Objects.requireNonNull(api, "api");
    }

    static DesktopNativeSurfaceBridge tryCreate(String libraryPath) {
        if (libraryPath == null || libraryPath.trim().isEmpty()) {
            return null;
        }
        try {
            NativeSurfaceApi api = Native.load(libraryPath, NativeSurfaceApi.class);
            return new DesktopNativeSurfaceBridge(api);
        } catch (Throwable ex) {
            LOG.log(Level.FINE, "Native GPU surface bridge unavailable", ex);
            return null;
        }
    }

    synchronized String lastFailure() {
        return lastFailure;
    }

    synchronized long surfaceHandle(Component component) {
        if (component == null) {
            lastFailure = "AWT component is null";
            return 0L;
        }
        if (!component.isDisplayable()) {
            lastFailure = "AWT Canvas is not displayable yet";
            return 0L;
        }
        if (!component.isShowing()) {
            lastFailure = "AWT Canvas is not showing yet";
            return 0L;
        }
        if (!ensureJawtLoaded()) {
            lastFailure = jawtLoadFailure;
            return 0L;
        }
        try {
            if (Platform.isWindows()) {
                long hwnd = Native.getComponentID(component);
                if (hwnd == 0L) {
                    lastFailure = "JNA returned HWND=0";
                    return 0L;
                }
                lastFailure = "";
                return descriptor(KIND_WIN32, 0, null, null, hwnd);
            }
            if (Platform.isMac()) {
                Pointer nsView = Native.getComponentPointer(component);
                if (pointerValue(nsView) == 0L) {
                    lastFailure = "JNA returned NSView=null";
                    return 0L;
                }
                lastFailure = "";
                return descriptor(KIND_APPKIT, 0, null, nsView, 0L);
            }
            if (Platform.isLinux() || Platform.isX11()) {
                long xid = Native.getComponentID(component);
                if (xid == 0L) {
                    lastFailure = "JNA returned X11 window id=0";
                    return 0L;
                }
                Pointer display = ensureX11Display();
                if (display == null || pointerValue(display) == 0L) {
                    lastFailure = "XOpenDisplay failed for DISPLAY=" + String.valueOf(System.getenv("DISPLAY"));
                    return 0L;
                }
                int screen = x11.XDefaultScreen(display);
                lastFailure = "";
                return descriptor(KIND_X11, screen, display, null, xid);
            }
            lastFailure = "unsupported desktop platform for native GPU surface";
        } catch (HeadlessException ex) {
            lastFailure = "native surface unavailable in headless environment";
            LOG.log(Level.FINE, "Native surface unavailable in headless environment", ex);
        } catch (Throwable ex) {
            lastFailure = ex.getMessage() == null ? ex.getClass().getName() : ex.getMessage();
            LOG.log(Level.FINE, "Failed to resolve native GPU surface", ex);
        }
        return 0L;
    }

    private static boolean ensureJawtLoaded() {
        if (jawtLoadAttempted) {
            return jawtLoadFailure.isEmpty();
        }
        synchronized (JAWT_LOAD_LOCK) {
            if (jawtLoadAttempted) {
                return jawtLoadFailure.isEmpty();
            }

            List<String> attempted = new ArrayList<String>();
            for (File candidate : jawtLibraryCandidates()) {
                attempted.add(candidate.getAbsolutePath());
                if (!candidate.isFile()) {
                    continue;
                }
                try {
                    System.load(candidate.getAbsolutePath());
                    jawtLoadFailure = "";
                    jawtLoadAttempted = true;
                    return true;
                } catch (Throwable ex) {
                    jawtLoadFailure = "failed to load " + candidate.getAbsolutePath() + ": " + failureMessage(ex);
                }
            }

            try {
                System.loadLibrary("jawt");
                jawtLoadFailure = "";
                jawtLoadAttempted = true;
                return true;
            } catch (Throwable ex) {
                String locations = attempted.isEmpty() ? "no java.home candidates" : String.join(", ", attempted);
                String javaHome = String.valueOf(System.getProperty("java.home"));
                jawtLoadFailure = "JAWT native library is not available for AWT native surface handles"
                    + " (java.home=" + javaHome + ", searched=" + locations + ", loadLibrary(jawt)="
                    + failureMessage(ex) + ")";
                jawtLoadAttempted = true;
                return false;
            }
        }
    }

    private static List<File> jawtLibraryCandidates() {
        List<File> candidates = new ArrayList<File>();
        String javaHome = System.getProperty("java.home");
        if (javaHome == null || javaHome.trim().isEmpty()) {
            return candidates;
        }

        File home = new File(javaHome);
        addJawtCandidates(candidates, home);
        File parent = home.getParentFile();
        if (parent != null) {
            addJawtCandidates(candidates, parent);
        }

        return candidates;
    }

    private static void addJawtCandidates(List<File> candidates, File home) {
        if (home == null) {
            return;
        }

        String name = System.mapLibraryName("jawt");
        Set<String> paths = new LinkedHashSet<String>();

        addCandidate(paths, new File(new File(home, "lib"), name));
        addCandidate(paths, new File(new File(home, "bin"), name));

        String[] archDirs = jawtArchDirs();
        for (String archDir : archDirs) {
            addCandidate(paths, new File(new File(new File(home, "lib"), archDir), name));
            addCandidate(paths, new File(new File(new File(home, "jre"), "lib"), archDir + File.separator + name));
        }
        addCandidate(paths, new File(new File(new File(home, "jre"), "lib"), name));
        addCandidate(paths, new File(new File(new File(home, "jre"), "bin"), name));

        for (String path : paths) {
            candidates.add(new File(path));
        }
    }

    private static void addCandidate(Set<String> paths, File file) {
        paths.add(file.getAbsolutePath());
    }

    private static String[] jawtArchDirs() {
        String arch = String.valueOf(System.getProperty("os.arch")).toLowerCase();
        if (arch.equals("amd64") || arch.equals("x86_64")) {
            return new String[] { "amd64", "x86_64" };
        }
        if (arch.equals("aarch64") || arch.equals("arm64")) {
            return new String[] { "aarch64", "arm64" };
        }
        if (arch.startsWith("arm")) {
            return new String[] { "arm" };
        }
        return new String[] { arch };
    }

    private static String failureMessage(Throwable throwable) {
        String message = throwable.getMessage();
        return message == null || message.trim().isEmpty()
            ? throwable.getClass().getName()
            : message.trim();
    }

    private Pointer ensureX11Display() {
        if (x11Display != null && pointerValue(x11Display) != 0L) {
            return x11Display;
        }
        if (x11 == null) {
            x11 = Native.load("X11", X11Api.class);
        }
        x11Display = x11.XOpenDisplay(null);
        return x11Display;
    }

    private long descriptor(
        int kind,
        int screen,
        Pointer display,
        Pointer surface,
        long window
    ) {
        long displayValue = pointerValue(display);
        long surfaceValue = pointerValue(surface);
        if (descriptor != null
            && descriptorKind == kind
            && descriptorScreen == screen
            && descriptorDisplay == displayValue
            && descriptorSurface == surfaceValue
            && descriptorWindow == window) {
            return pointerValue(descriptor);
        }

        freeDescriptor();
        descriptor = api.volvox_grid_native_surface_descriptor_new(
            kind,
            screen,
            display,
            surface,
            window
        );
        if (descriptor == null || pointerValue(descriptor) == 0L) {
            descriptor = null;
            return 0L;
        }
        descriptorKind = kind;
        descriptorScreen = screen;
        descriptorDisplay = displayValue;
        descriptorSurface = surfaceValue;
        descriptorWindow = window;
        return pointerValue(descriptor);
    }

    private void freeDescriptor() {
        if (descriptor != null) {
            api.volvox_grid_native_surface_descriptor_free(descriptor);
            descriptor = null;
        }
        descriptorKind = -1;
        descriptorDisplay = 0L;
        descriptorSurface = 0L;
        descriptorWindow = 0L;
    }

    private static long pointerValue(Pointer pointer) {
        return pointer == null ? 0L : Pointer.nativeValue(pointer);
    }

    @Override
    public synchronized void close() {
        freeDescriptor();
        if (x11 != null && x11Display != null && pointerValue(x11Display) != 0L) {
            try {
                x11.XCloseDisplay(x11Display);
            } catch (Throwable ex) {
                LOG.log(Level.FINER, "XCloseDisplay failed", ex);
            }
        }
        x11Display = null;
    }
}
