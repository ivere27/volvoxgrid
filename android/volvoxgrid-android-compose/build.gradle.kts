import java.io.File

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
val volvoxgridVersion = System.getenv("VOLVOXGRID_VERSION")
    ?: providers.gradleProperty("volvoxgridVersion")
        .orElse(System.getenv("VERSION") ?: defaultVolvoxgridVersion)
        .get()

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "io.github.ivere27.volvoxgrid.compose"
    compileSdk = 36

    defaultConfig {
        minSdk = 21
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        // Pinned to the Compose Compiler version compatible with Kotlin 1.9.22.
        kotlinCompilerExtensionVersion = "1.5.10"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    api(project(":volvoxgrid-android"))

    implementation("androidx.compose.ui:ui:1.6.8")
    implementation("androidx.compose.runtime:runtime:1.6.8")
}
