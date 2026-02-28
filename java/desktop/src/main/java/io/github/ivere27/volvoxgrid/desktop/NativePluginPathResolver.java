package io.github.ivere27.volvoxgrid.desktop;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Locale;

final class NativePluginPathResolver {
    private NativePluginPathResolver() {}

    static String resolvePluginPath(String[] args) {
        String fromArg = firstArg(args);
        if (fromArg != null) {
            return toAbsolutePath(fromArg);
        }

        String fromEnv = System.getenv("VOLVOXGRID_PLUGIN_PATH");
        if (fromEnv != null && !fromEnv.isBlank()) {
            return toAbsolutePath(fromEnv);
        }

        Path detected = detectFromWorkspace();
        if (detected != null) {
            return detected.toAbsolutePath().normalize().toString();
        }
        return null;
    }

    static String expectedPluginFileHint() {
        String[] names = pluginNamesForCurrentOs();
        if (names.length == 0) {
            return "libvolvoxgrid_plugin.so";
        }
        return names[0];
    }

    private static String firstArg(String[] args) {
        if (args == null || args.length == 0) {
            return null;
        }
        if (args[0] == null || args[0].isBlank()) {
            return null;
        }
        return args[0];
    }

    private static String toAbsolutePath(String rawPath) {
        return Paths.get(rawPath).toAbsolutePath().normalize().toString();
    }

    private static Path detectFromWorkspace() {
        Path cwd = Paths.get("").toAbsolutePath().normalize();
        Path parent = cwd.getParent();
        Path grandParent = parent != null ? parent.getParent() : null;
        Path[] roots = new Path[] {cwd, parent, grandParent};
        String[] relDirs = new String[] {"target/debug", "target/release"};
        String[] fileNames = pluginNamesForCurrentOs();

        for (Path root : roots) {
            if (root == null) {
                continue;
            }
            for (String relDir : relDirs) {
                for (String fileName : fileNames) {
                    Path candidate = root.resolve(relDir).resolve(fileName);
                    if (Files.isRegularFile(candidate)) {
                        return candidate;
                    }
                }
            }
        }
        return null;
    }

    private static String[] pluginNamesForCurrentOs() {
        String os = System.getProperty("os.name", "").toLowerCase(Locale.ROOT);
        if (os.contains("win")) {
            return new String[] {"volvoxgrid_plugin.dll", "libvolvoxgrid_plugin.dll"};
        }
        if (os.contains("mac") || os.contains("darwin")) {
            return new String[] {"libvolvoxgrid_plugin.dylib", "volvoxgrid_plugin.dylib"};
        }
        return new String[] {"libvolvoxgrid_plugin.so", "volvoxgrid_plugin.so"};
    }
}
