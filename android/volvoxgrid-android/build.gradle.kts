import com.google.protobuf.gradle.proto
import java.io.File
import java.time.Instant
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

fun quoteForBuildConfig(value: String): String =
    "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

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

val volvoxgridVersion = System.getenv("VOLVOXGRID_VERSION")
    ?: providers.gradleProperty("volvoxgridVersion")
        .orElse(System.getenv("VERSION") ?: defaultVolvoxgridVersion)
        .get()
val volvoxgridGitCommit = providers.gradleProperty("volvoxgridGitCommit")
    .orElse(captureCommandOutput(rootDir, "git", "rev-parse", "--short=12", "HEAD") ?: "unknown")
    .get()
val volvoxgridBuildDate = providers.gradleProperty("volvoxgridBuildDate")
    .orElse(Instant.now().toString())
    .get()

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("com.google.protobuf")
}

android {
    namespace = "io.github.ivere27.volvoxgrid"
    compileSdk = 34
    ndkVersion = "28.2.13676358"

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        minSdk = 21
        consumerProguardFiles("consumer-rules.pro")
        buildConfigField("String", "VOLVOXGRID_VERSION", quoteForBuildConfig(volvoxgridVersion))
        buildConfigField("String", "VOLVOXGRID_GIT_COMMIT", quoteForBuildConfig(volvoxgridGitCommit))
        buildConfigField("String", "VOLVOXGRID_BUILD_DATE", quoteForBuildConfig(volvoxgridBuildDate))

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }

        externalNativeBuild {
            cmake {
                // synurang_jni.so is provided by the synurang-android AAR dependency.
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/jni/CMakeLists.txt")
        }
    }

    sourceSets {
        getByName("main") {
            java.srcDir(layout.buildDirectory.dir("generated/source/volvoxgridFfi/main/java"))
            proto {
                srcDir(layout.buildDirectory.dir("proto-staging"))
            }
        }
    }
}

val stageProto = tasks.register<Copy>("stageProto") {
    from("../../proto/volvoxgrid.proto")
    into(layout.buildDirectory.dir("proto-staging"))
}

tasks.matching { it.name.startsWith("extract") && it.name.contains("Proto") }.configureEach {
    dependsOn(stageProto)
}

tasks.matching { it.name.startsWith("generate") && it.name.contains("Proto") }.configureEach {
    dependsOn(stageProto)
}

val copyFfiJava = tasks.register<Copy>("copyFfiJava") {
    from("../../codegen/volvoxgrid_ffi.java")
    into(layout.buildDirectory.dir("generated/source/volvoxgridFfi/main/java/io/github/ivere27/volvoxgrid"))
    rename { "VolvoxGridServiceFfi.java" }
    // protoc-gen-synurang-ffi emits `package volvoxgrid.v1;` for Java FFI stubs.
    // Android proto classes in this module use `option java_package = io.github.ivere27.volvoxgrid`,
    // so we normalize the copied FFI stub package to keep types in one package.
    filter { line: String ->
        if (line == "package volvoxgrid.v1;") {
            "package io.github.ivere27.volvoxgrid;"
        } else {
            line
        }
    }
}

tasks.named("preBuild") {
    dependsOn(copyFfiJava)
}

tasks.withType<KotlinCompile>().configureEach {
    // Protobuf-generated Java types change frequently and have caused flaky
    // incremental Kotlin classpath state (e.g. missing *OrBuilder supertypes).
    incremental = false
}

protobuf {
    protoc {
        artifact = "com.google.protobuf:protoc:3.25.1"
    }
    generateProtoTasks {
        all().forEach { task ->
            task.builtins {
                create("java") {
                    option("lite")
                }
            }
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    api("io.github.ivere27:volvoxgrid-java-common:$volvoxgridVersion")

    // Protobuf lite
    implementation("com.google.protobuf:protobuf-javalite:3.25.1")

    // Synurang runtime from Maven Central.
    api("io.github.ivere27:synurang-android:0.5.3")

}
