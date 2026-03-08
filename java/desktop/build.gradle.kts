import com.google.protobuf.gradle.proto
import java.io.File
import java.time.Instant

fun captureCommandOutput(workDir: File, vararg command: String): String? {
    return try {
        val process = ProcessBuilder(*command)
            .directory(workDir)
            .redirectErrorStream(true)
            .start()
        val output = process.inputStream.bufferedReader().use { it.readText().trim() }
        if (process.waitFor() == 0) output.takeIf { it.isNotEmpty() } else null
    } catch (_: Exception) {
        null
    }
}

fun escapeJavaString(value: String): String =
    value.replace("\\", "\\\\").replace("\"", "\\\"")

fun requireExistingFile(path: String, label: String, sourceProperty: String): File {
    if (path.isBlank()) {
        throw org.gradle.api.GradleException("$label must be set when $sourceProperty=local")
    }
    val file = File(path)
    if (!file.isFile) {
        throw org.gradle.api.GradleException("$label file not found: $path")
    }
    return file
}

fun requireExistingDirectory(path: String, label: String, sourceProperty: String): File {
    if (path.isBlank()) {
        throw org.gradle.api.GradleException("$label must be set when $sourceProperty=local")
    }
    val file = File(path)
    if (!file.isDirectory) {
        throw org.gradle.api.GradleException("$label directory not found: $path")
    }
    return file
}

fun findVolvoxgridVersionFile(startDir: File): File? {
    var current: File? = startDir.canonicalFile
    while (current != null) {
        val candidate = current.resolve("VERSION")
        if (candidate.isFile) {
            return candidate
        }
        current = current.parentFile
    }
    return null
}

val versionFile = findVolvoxgridVersionFile(projectDir)
    ?: throw org.gradle.api.GradleException("VERSION file not found from $projectDir")
val defaultVolvoxgridVersion = versionFile.readText().trim()
if (defaultVolvoxgridVersion.isEmpty()) {
    throw org.gradle.api.GradleException("VERSION file is empty: $versionFile")
}

plugins {
    java
    application
    id("com.google.protobuf") version "0.9.4"
}

// Keep this demo/application module coordinates distinct from the published
// library coordinates (io.github.ivere27:volvoxgrid-desktop) to avoid
// self-resolution in maven mode.
group = "io.github.ivere27.examples"
version = "$defaultVolvoxgridVersion-SNAPSHOT"

java {
    sourceCompatibility = JavaVersion.VERSION_1_8
    targetCompatibility = JavaVersion.VERSION_1_8
}

repositories {
    mavenLocal()
    mavenCentral()
}

val synurangDesktopVersion = providers.gradleProperty("synurangDesktopVersion")
    .orElse("0.5.4")
    .get()
val isSynurangDesktopSnapshot = synurangDesktopVersion.endsWith("-SNAPSHOT")
val volvoxgridDesktopSource = providers.gradleProperty("volvoxgridDesktopSource")
    .orElse(System.getenv("VOLVOXGRID_SOURCE") ?: "local")
    .get()
    .trim()
    .lowercase()
val volvoxgridDesktopGroup = providers.gradleProperty("volvoxgridDesktopGroup")
    .orElse("io.github.ivere27")
    .get()
val volvoxgridDesktopArtifact = providers.gradleProperty("volvoxgridDesktopArtifact")
    .orElse("volvoxgrid-desktop")
    .get()
val volvoxgridVersion = System.getenv("VOLVOXGRID_VERSION")
    ?: providers.gradleProperty("volvoxgridVersion")
        .orElse(providers.gradleProperty("volvoxgridDesktopVersion"))
        .orElse(defaultVolvoxgridVersion)
        .get()
val isVolvoxgridSnapshot = volvoxgridVersion.endsWith("-SNAPSHOT")
val volvoxgridGitCommit = providers.gradleProperty("volvoxgridGitCommit")
    .orElse(captureCommandOutput(rootDir, "git", "rev-parse", "--short=12", "HEAD") ?: "unknown")
    .get()
val volvoxgridBuildDate = providers.gradleProperty("volvoxgridBuildDate")
    .orElse(Instant.now().toString())
    .get()
val synurangDesktopSource = providers.gradleProperty("synurangDesktopSource")
    .orElse(System.getenv("SYNURANG_DESKTOP_SOURCE") ?: "maven")
    .get()
    .trim()
    .lowercase()
val synurangJavaJar = providers.gradleProperty("synurangJavaJar")
    .orElse(providers.environmentVariable("SYNURANG_JAVA_JAR"))
    .orElse("")
    .get()
val synurangJavaLibDir = providers.gradleProperty("synurangJavaLibDir")
    .orElse(providers.environmentVariable("SYNURANG_JAVA_LIB_DIR"))
    .orElse("")
    .get()
val synurangNativeLibPath = providers.gradleProperty("synurangNativeLibPath")
    .orElse(providers.environmentVariable("SYNURANG_NATIVE_LIB_PATH"))
    .orElse("")
    .get()

configurations.configureEach {
    if (isVolvoxgridSnapshot || isSynurangDesktopSnapshot) {
        resolutionStrategy.cacheChangingModulesFor(0, "seconds")
    }
}

dependencies {
    when (volvoxgridDesktopSource) {
        "local" -> implementation("io.github.ivere27:volvoxgrid-java-common:$volvoxgridVersion")
        "maven" -> implementation("$volvoxgridDesktopGroup:$volvoxgridDesktopArtifact:$volvoxgridVersion") {
            isChanging = isVolvoxgridSnapshot
        }
        else -> throw GradleException(
            "Invalid volvoxgridDesktopSource='$volvoxgridDesktopSource'. Expected 'local' or 'maven'."
        )
    }
    implementation("com.google.protobuf:protobuf-java:3.25.1")
    if (synurangDesktopSource == "maven") {
        implementation("io.github.ivere27:synurang-desktop:$synurangDesktopVersion") {
            isChanging = isSynurangDesktopSnapshot
        }
        implementation("io.github.ivere27:synurang-desktop-grpc:$synurangDesktopVersion") {
            isChanging = isSynurangDesktopSnapshot
        }
        implementation("io.grpc:grpc-api:1.60.0")
    } else {
        val localSynurangJavaJar = requireExistingFile(
            synurangJavaJar,
            "synurangJavaJar/SYNURANG_JAVA_JAR",
            "synurangDesktopSource"
        )
        val localSynurangJavaLibDir = requireExistingDirectory(
            synurangJavaLibDir,
            "synurangJavaLibDir/SYNURANG_JAVA_LIB_DIR",
            "synurangDesktopSource"
        )
        implementation(
            files(
                localSynurangJavaJar,
                fileTree(localSynurangJavaLibDir) {
                    include("*.jar")
                }
            )
        )
    }

    testImplementation(platform("org.junit:junit-bom:5.10.2"))
    testImplementation("org.junit.jupiter:junit-jupiter")
}

sourceSets {
    getByName("main") {
        java.srcDir(layout.buildDirectory.dir("generated/source/volvoxgridBuildInfo/main/java"))
        proto {
            srcDir(layout.buildDirectory.dir("proto-staging"))
        }
    }
}

val stageProto = tasks.register<Copy>("stageProto") {
    from("../../proto/volvoxgrid.proto")
    into(layout.buildDirectory.dir("proto-staging"))
}

val generateVolvoxGridBuildInfo = tasks.register("generateVolvoxGridBuildInfo") {
    val outputDir = layout.buildDirectory.dir("generated/source/volvoxgridBuildInfo/main/java")
    outputs.dir(outputDir)
    doLast {
        val targetDir = outputDir.get().asFile.resolve("io/github/ivere27/volvoxgrid/desktop")
        targetDir.mkdirs()
        targetDir.resolve("VolvoxGridBuildInfo.java").writeText(
            """
            package io.github.ivere27.volvoxgrid.desktop;
            
            import java.util.concurrent.atomic.AtomicBoolean;
            
            final class VolvoxGridBuildInfo {
                private static final AtomicBoolean LOGGED = new AtomicBoolean(false);
            
                static final String VERSION = "${escapeJavaString(volvoxgridVersion)}";
                static final String GIT_COMMIT = "${escapeJavaString(volvoxgridGitCommit)}";
                static final String BUILD_DATE = "${escapeJavaString(volvoxgridBuildDate)}";
            
                private VolvoxGridBuildInfo() {}
            
                static void logDesktopPluginLoadOnce(String pluginPath) {
                    if (!LOGGED.compareAndSet(false, true)) {
                        return;
                    }
                    System.err.println(
                        "Loaded VolvoxGrid plugin " +
                        "version=" + VERSION + " " +
                        "commit=" + GIT_COMMIT + " " +
                        "buildDate=" + BUILD_DATE + " " +
                        "path=" + pluginPath
                    );
                }
            }
            """.trimIndent() + "\n"
        )
    }
}

tasks.matching { it.name.startsWith("extract") && it.name.contains("Proto") }.configureEach {
    dependsOn(stageProto)
}

tasks.matching { it.name.startsWith("generate") && it.name.contains("Proto") }.configureEach {
    dependsOn(stageProto)
}

tasks.named("compileJava") {
    dependsOn(generateVolvoxGridBuildInfo)
}

protobuf {
    protoc {
        artifact = "com.google.protobuf:protoc:3.25.1"
    }
}

application {
    mainClass.set("io.github.ivere27.volvoxgrid.desktop.VolvoxGridDesktopExample")
}

tasks.register<JavaExec>("runSmoke") {
    group = "application"
    description = "Run headless desktop smoke test with Synurang desktop runtime."
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("io.github.ivere27.volvoxgrid.desktop.VolvoxGridDesktopSmoke")
}

tasks.register<JavaExec>("runSimpleDemo") {
    group = "application"
    description = "Run the minimal desktop demo."
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("io.github.ivere27.volvoxgrid.desktop.VolvoxGridDesktopDemo")
}

tasks.withType<JavaExec>().configureEach {
    if (synurangDesktopSource == "local" && synurangNativeLibPath.isNotBlank()) {
        val nativeLibFile = file(synurangNativeLibPath)
        if (nativeLibFile.isFile) {
            systemProperty("synurang.library.path", nativeLibFile.absolutePath)
        }
    }
}

tasks.test {
    useJUnitPlatform()
}
