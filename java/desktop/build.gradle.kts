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

plugins {
    java
    application
    id("com.google.protobuf") version "0.9.4"
}

// Keep this demo/application module coordinates distinct from the published
// library coordinates (io.github.ivere27:volvoxgrid-desktop) to avoid
// self-resolution in maven mode.
group = "io.github.ivere27.examples"
version = "0.1.4-SNAPSHOT"

java {
    sourceCompatibility = JavaVersion.VERSION_1_8
    targetCompatibility = JavaVersion.VERSION_1_8
}

repositories {
    mavenLocal()
    mavenCentral()
}

val synurangDesktopVersion = providers.gradleProperty("synurangDesktopVersion")
    .orElse("0.5.3")
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
val volvoxgridVersion = providers.gradleProperty("volvoxgridVersion")
    .orElse(providers.gradleProperty("volvoxgridDesktopVersion"))
    .orElse("0.1.4")
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
val defaultSynurangMavenDir = rootDir.toPath()
    .resolve("../../../../../open/synurang/dist/maven")
    .normalize()
    .toAbsolutePath()
    .toString()
val synurangMavenDir = providers.gradleProperty("synurangMavenDir")
    .orElse(providers.environmentVariable("SYNURANG_MAVEN_DIR"))
    .orElse(defaultSynurangMavenDir)
    .get()
val synurangDesktopJars = fileTree(synurangMavenDir) {
    include("synurang-desktop-*.jar")
    include("synurang-desktop-grpc-*.jar")
    include("classes.jar")
}

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
        implementation(synurangDesktopJars)
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

tasks.test {
    useJUnitPlatform()
}
