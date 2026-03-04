plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.protobuf")
}

fun findVolvoxgridVersionFile(startDir: java.io.File): java.io.File? {
    var current: java.io.File? = startDir.canonicalFile
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

val volvoxgridAndroidSource = providers.gradleProperty("volvoxgridAndroidSource")
    .orElse(System.getenv("VOLVOXGRID_SOURCE") ?: "local")
    .get()
    .trim()
    .lowercase()
val volvoxgridAndroidVariant = providers.gradleProperty("volvoxgridAndroidVariant")
    .orElse(System.getenv("VOLVOXGRID_VARIANT") ?: "")
    .get()
    .trim()
    .lowercase()
val isVolvoxgridAndroidLite = volvoxgridAndroidVariant == "lite"
val defaultVolvoxgridAndroidArtifact = if (isVolvoxgridAndroidLite) {
    "volvoxgrid-android-lite"
} else {
    "volvoxgrid-android"
}
val volvoxgridAndroidGroup = providers.gradleProperty("volvoxgridAndroidGroup")
    .orElse("io.github.ivere27")
    .get()
val volvoxgridAndroidArtifact = providers.gradleProperty("volvoxgridAndroidArtifact")
    .orElse(defaultVolvoxgridAndroidArtifact)
    .get()
val volvoxgridVersion = System.getenv("VOLVOXGRID_VERSION")
    ?: providers.gradleProperty("volvoxgridVersion")
        .orElse(providers.gradleProperty("volvoxgridAndroidVersion"))
        .orElse(defaultVolvoxgridVersion)
        .get()
val isVolvoxgridSnapshot = volvoxgridVersion.endsWith("-SNAPSHOT")

android {
    namespace = "io.github.ivere27.volvoxgrid.example"
    compileSdk = 34

    defaultConfig {
        applicationId = "io.github.ivere27.volvoxgrid.example"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
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
}

configurations.configureEach {
    if (isVolvoxgridSnapshot) {
        resolutionStrategy.cacheChangingModulesFor(0, "seconds")
    }
}

dependencies {
    when (volvoxgridAndroidSource) {
        "local" -> implementation(project(":volvoxgrid-android"))
        "maven" -> implementation("$volvoxgridAndroidGroup:$volvoxgridAndroidArtifact:$volvoxgridVersion") {
            isChanging = isVolvoxgridSnapshot
        }
        else -> throw GradleException(
            "Invalid volvoxgridAndroidSource='$volvoxgridAndroidSource'. Expected 'local' or 'maven'."
        )
    }

    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")

    // Protobuf lite (transitive from library, but explicit for clarity)
    implementation("com.google.protobuf:protobuf-javalite:3.25.1")
}
