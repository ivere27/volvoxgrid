package io.github.ivere27.volvoxgrid.desktop;

import com.sun.jna.Library;
import com.sun.jna.Native;
import java.util.logging.Level;
import java.util.logging.Logger;

final class NativeLibraryCapabilities {
    private static final Logger LOG = Logger.getLogger(NativeLibraryCapabilities.class.getName());

    private NativeLibraryCapabilities() {}

    interface NativeApi extends Library {
        int volvox_grid_has_gpu_renderer();
    }

    static boolean hasGpuRenderer(String libraryPath) {
        if (libraryPath == null || libraryPath.trim().isEmpty()) {
            return false;
        }
        try {
            NativeApi api = Native.load(libraryPath, NativeApi.class);
            return api.volvox_grid_has_gpu_renderer() != 0;
        } catch (Throwable ex) {
            LOG.log(Level.FINE, "Native GPU capability check unavailable", ex);
            return false;
        }
    }
}
