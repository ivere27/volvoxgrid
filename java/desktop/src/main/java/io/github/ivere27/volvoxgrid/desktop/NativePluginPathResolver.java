package io.github.ivere27.volvoxgrid.desktop;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;

final class NativePluginPathResolver {
    private static volatile Path extractedPluginPath;

    private NativePluginPathResolver() {}

    static String resolvePluginPath(String[] args) {
        String fromArg = firstArg(args);
        if (fromArg != null) {
            return toAbsolutePath(fromArg);
        }

        String fromEnv = System.getenv("VOLVOXGRID_PLUGIN_PATH");
        if (!isBlank(fromEnv)) {
            return toAbsolutePath(fromEnv);
        }

        Path fromClasspath = detectFromClasspathArtifact();
        if (fromClasspath != null) {
            return fromClasspath.toAbsolutePath().normalize().toString();
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
        for (String arg : args) {
            if (isBlank(arg)) {
                continue;
            }
            if (arg.startsWith("--")) {
                continue;
            }
            return arg;
        }
        return null;
    }

    private static boolean isBlank(String value) {
        if (value == null) {
            return true;
        }
        for (int i = 0; i < value.length(); i++) {
            if (!Character.isWhitespace(value.charAt(i))) {
                return false;
            }
        }
        return true;
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

    private static Path detectFromClasspathArtifact() {
        Path cached = extractedPluginPath;
        if (cached != null && Files.isRegularFile(cached)) {
            return cached;
        }

        String[] platforms = classpathPlatformDirsForCurrentOs();
        String[] fileNames = pluginNamesForCurrentOs();
        ClassLoader classLoader = NativePluginPathResolver.class.getClassLoader();
        for (String platform : platforms) {
            for (String fileName : fileNames) {
                String resourcePath = "native/" + platform + "/" + fileName;
                try (InputStream input = classLoader.getResourceAsStream(resourcePath)) {
                    if (input == null) {
                        continue;
                    }
                    Path extracted = extractTempPlugin(input, fileName);
                    extractedPluginPath = extracted;
                    return extracted;
                } catch (IOException ignored) {
                    // Try the next candidate.
                }
            }
        }
        return null;
    }

    private static Path extractTempPlugin(InputStream input, String fileName) throws IOException {
        String prefix = "volvoxgrid-plugin-";
        String suffix = fileName.startsWith(".") ? fileName : "-" + fileName;
        Path extracted = Files.createTempFile(prefix, suffix);
        Files.copy(input, extracted, StandardCopyOption.REPLACE_EXISTING);
        extracted.toFile().deleteOnExit();
        return extracted;
    }

    private static String[] classpathPlatformDirsForCurrentOs() {
        String os = System.getProperty("os.name", "").toLowerCase(Locale.ROOT);
        String arch = System.getProperty("os.arch", "").toLowerCase(Locale.ROOT);
        Set<String> dirs = new LinkedHashSet<>();

        if (os.contains("win")) {
            if (arch.contains("64") || arch.contains("amd64") || arch.contains("x86_64")) {
                dirs.add("windows-x86_64");
            }
            dirs.add("windows-x86");
            return dirs.toArray(new String[0]);
        }

        if (os.contains("mac") || os.contains("darwin")) {
            if (arch.contains("aarch64") || arch.contains("arm64")) {
                dirs.add("macos-aarch64");
            } else {
                dirs.add("macos-x86_64");
            }
            dirs.add("macos-aarch64");
            dirs.add("macos-x86_64");
            return dirs.toArray(new String[0]);
        }

        if (arch.contains("aarch64") || arch.contains("arm64")) {
            dirs.add("linux-aarch64");
        } else if (arch.startsWith("arm") || arch.contains("armv7")) {
            dirs.add("linux-armv7");
        } else if (arch.contains("x86_64") || arch.contains("amd64") || arch.contains("64")) {
            dirs.add("linux-x86_64");
        } else if (arch.contains("x86") || arch.contains("i386") || arch.contains("i686")) {
            dirs.add("linux-x86");
        }
        dirs.add("linux-x86_64");
        dirs.add("linux-x86");
        dirs.add("linux-aarch64");
        dirs.add("linux-armv7");
        return dirs.toArray(new String[0]);
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
