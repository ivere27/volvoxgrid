plugins {
    `java-library`
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

group = "io.github.ivere27"
version = "$defaultVolvoxgridVersion-SNAPSHOT"

java {
    sourceCompatibility = JavaVersion.VERSION_1_8
    targetCompatibility = JavaVersion.VERSION_1_8
}

repositories {
    mavenCentral()
}
