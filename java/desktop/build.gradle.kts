import com.google.protobuf.gradle.proto

plugins {
    java
    application
    id("com.google.protobuf") version "0.9.4"
}

group = "io.github.ivere27"
version = "0.1.0-SNAPSHOT"

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

repositories {
    mavenLocal()
    mavenCentral()
}

val synurangDesktopVersion = providers.gradleProperty("synurangDesktopVersion")
    .orElse("0.5.2")
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

dependencies {
    implementation("io.github.ivere27:volvoxgrid-java-common:0.1.0-SNAPSHOT")
    implementation("com.google.protobuf:protobuf-java:3.25.1")
    if (synurangDesktopSource == "maven") {
        implementation("io.github.ivere27:synurang-desktop:$synurangDesktopVersion")
        implementation("io.github.ivere27:synurang-desktop-grpc:$synurangDesktopVersion")
        implementation("io.grpc:grpc-api:1.60.0")
    } else {
        implementation(synurangDesktopJars)
    }

    testImplementation(platform("org.junit:junit-bom:5.10.2"))
    testImplementation("org.junit.jupiter:junit-jupiter")
}

sourceSets {
    getByName("main") {
        proto {
            srcDir(layout.buildDirectory.dir("proto-staging"))
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
