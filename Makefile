# VolvoxGrid Makefile
# Pixel-rendering grid engine as a Synurang FFI plugin
#
# Usage:
#   make              — build engine + host plugin
#   make run          — build & run smoke test (Rust host loads host plugin, creates grid)
#   make dotnet-tui-run — build & run .NET 8 terminal example
#   make test_pixel   — run engine pixel regression tests
#   make wasm         — build WASM crate
#   make web          — build WASM + start web dev server
#   make codegen      — regenerate FFI bindings for all languages
#   make sheet        — build WASM + start Sheet adapter dev server
#   make sheet-lite   — build WASM lite + start Sheet adapter dev server
#   make doom-deps    — download optional DOOM assets for web demo mode
#   make publish_web  — copy dist/web into public and deploy to Firebase
#   make clean        — remove build artifacts

# =============================================================================
# Variables
# =============================================================================
SYNURANG_MODULE ?= github.com/ivere27/synurang
SYNURANG_VERSION ?= v0.5.10
PROTOC_PLUGIN ?= $(shell gobin=$$(go env GOBIN 2>/dev/null); if [ -n "$$gobin" ]; then printf '%s/protoc-gen-synurang-ffi' "$$gobin"; else printf '%s/bin/protoc-gen-synurang-ffi' "$$(go env GOPATH 2>/dev/null)"; fi)
PROTOC_PLUGIN_FLAG = --plugin=protoc-gen-synurang-ffi=$(PROTOC_PLUGIN)
ANDROID_PROJECT_DIR := android
ANDROID_GRADLEW := $(ANDROID_PROJECT_DIR)/gradlew
SHARED_GRADLEW := ../example/java/android/gradlew
ANDROID_GRADLE_TASK := :volvoxgrid-android:assembleDebug
ANDROID_INSTALL_TASK := :example:installDebug
ANDROID_EXAMPLE_PACKAGE := io.github.ivere27.volvoxgrid.example
ANDROID_EXAMPLE_ACTIVITY := .MainActivity
ANDROID_PLUGIN_OUTPUT_DIR := $(abspath android/volvoxgrid-android/src/main/jniLibs)
ANDROID_APP_PLUGIN_DIR := $(abspath android/example/src/main/jniLibs)
FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR := $(abspath flutter/android/src/main/jniLibs)
VOLVOXGRID_PLUGIN_DEBUG_DIR := $(abspath target/debug)
FLUTTER_EXAMPLE_DIR := flutter/example
FLUTTER_EXAMPLE_PACKAGE := com.example.volvoxgrid_example
DOOM_BUNDLE_URL := https://cdn.dos.zone/custom/dos/doom.jsdos?anonymous=1
DOOM_EMULATORS_VERSION ?= 8.3.9
WEB_HOST ?= 0.0.0.0
WEB_SCALE ?= 1.0
WEB_HOVER ?= false
DOTNET_TFM ?= net40
DOTNET_TUI_TFM ?= net8.0
DOTNET_ARCH ?= x64
ACTIVEX_ARCH ?= x86_64
GTK_BENCH_RUNS ?= 5
GTK_BENCH_ARGS ?=
JAVA_DESKTOP_PROJECT_DIR := java/desktop
GO_PROJECT_DIR := go
ROOT_DIR := $(patsubst %/,%,$(abspath $(dir $(lastword $(MAKEFILE_LIST)))))
UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(UNAME_S),Darwin)
SED_I := sed -i ''
else
SED_I := sed -i
endif
HOST_CPU_COUNT ?= $(shell nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
BUILD_JOBS_DEFAULT := $(shell c=$$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1); if [ "$$c" -gt 2 ] 2>/dev/null; then echo $$((c-2)); else echo 1; fi)
BUILD_JOBS ?= $(BUILD_JOBS_DEFAULT)
CARGO_BUILD_JOBS ?= $(BUILD_JOBS)
GRADLE_MAX_WORKERS ?= $(BUILD_JOBS)
CARGO_JOBS_FLAG := -j $(CARGO_BUILD_JOBS)
GRADLE_JOBS_FLAG := --max-workers=$(GRADLE_MAX_WORKERS)
ifeq ($(OS),Windows_NT)
JAVA_DESKTOP_PLUGIN_BASENAME := volvoxgrid_plugin.dll
else ifeq ($(UNAME_S),Darwin)
JAVA_DESKTOP_PLUGIN_BASENAME := libvolvoxgrid_plugin.dylib
else
JAVA_DESKTOP_PLUGIN_BASENAME := libvolvoxgrid_plugin.so
endif
JAVA_DESKTOP_PLUGIN ?= $(abspath target/debug/$(JAVA_DESKTOP_PLUGIN_BASENAME))
JAVA_DESKTOP_PLUGIN_RELEASE ?= $(abspath target/release/$(JAVA_DESKTOP_PLUGIN_BASENAME))
VERSION_FILE ?= $(ROOT_DIR)/VERSION
VERSION_FILE_VALUE := $(strip $(shell [ -f "$(VERSION_FILE)" ] && cat "$(VERSION_FILE)" 2>/dev/null))
VOLVOXGRID_VERSION ?= $(VERSION_FILE_VALUE)
ifeq ($(strip $(VOLVOXGRID_VERSION)),)
$(error VOLVOXGRID_VERSION is empty. Set VOLVOXGRID_VERSION or populate $(VERSION_FILE))
endif
VOLVOXGRID_SOURCE ?= local
VOLVOXGRID_SOURCE_RAW := $(strip $(VOLVOXGRID_SOURCE))
VOLVOXGRID_SOURCE_RESOLVED := $(VOLVOXGRID_SOURCE_RAW)
ifeq ($(filter $(VOLVOXGRID_SOURCE_RESOLVED),local maven),)
$(error Invalid VOLVOXGRID_SOURCE='$(VOLVOXGRID_SOURCE_RAW)'. Expected 'local' or 'maven')
endif
VOLVOXGRID_VARIANT ?=
VOLVOXGRID_ANDROID_GROUP ?= io.github.ivere27
VOLVOXGRID_ANDROID_ARTIFACT ?=
ifeq ($(strip $(VOLVOXGRID_VARIANT)),lite)
VOLVOXGRID_ANDROID_ARTIFACT_DEFAULT := volvoxgrid-android-lite
else
VOLVOXGRID_ANDROID_ARTIFACT_DEFAULT := volvoxgrid-android
endif
ifeq ($(strip $(VOLVOXGRID_ANDROID_ARTIFACT)),)
VOLVOXGRID_ANDROID_ARTIFACT := $(VOLVOXGRID_ANDROID_ARTIFACT_DEFAULT)
endif
VOLVOXGRID_JAVA_GROUP ?= io.github.ivere27
VOLVOXGRID_JAVA_ARTIFACT ?= volvoxgrid-desktop
ANDROID_EXAMPLE_GRADLE_PROPS := \
	-PvolvoxgridAndroidSource=$(VOLVOXGRID_SOURCE_RESOLVED) \
	-PvolvoxgridAndroidVariant=$(VOLVOXGRID_VARIANT) \
	-PvolvoxgridAndroidGroup=$(VOLVOXGRID_ANDROID_GROUP) \
	-PvolvoxgridAndroidArtifact=$(VOLVOXGRID_ANDROID_ARTIFACT) \
	-PvolvoxgridVersion=$(VOLVOXGRID_VERSION)
JAVA_DESKTOP_GRADLE_PROPS := \
	-PvolvoxgridDesktopSource=$(VOLVOXGRID_SOURCE_RESOLVED) \
	-PvolvoxgridDesktopGroup=$(VOLVOXGRID_JAVA_GROUP) \
	-PvolvoxgridDesktopArtifact=$(VOLVOXGRID_JAVA_ARTIFACT) \
	-PvolvoxgridVersion=$(VOLVOXGRID_VERSION)

# Docker + Maven publishing
# Resolve to the Makefile directory so docker mounts stay correct even when
# invoking `make -f /path/to/Makefile` or running from subdirectories.
CURRENT_DIR := $(ROOT_DIR)
AAR_DOCKER_IMAGE ?= volvoxgrid-android-aar:latest
AAR_VERSION ?= $(VOLVOXGRID_VERSION)
AAR_GROUP_ID ?= io.github.ivere27
AAR_ARTIFACT_ID ?= volvoxgrid-android
AAR_DEBUG_ARTIFACT_ID ?= $(AAR_ARTIFACT_ID)-debug
AAR_LITE_GROUP_ID ?= $(AAR_GROUP_ID)
AAR_LITE_ARTIFACT_ID ?= volvoxgrid-android-lite
AAR_LITE_DEBUG_ARTIFACT_ID ?= $(AAR_LITE_ARTIFACT_ID)-debug
AAR_GIT_COMMIT ?= $(shell git -C "$(CURRENT_DIR)" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)
AAR_BUILD_DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
AAR_ANDROID_ABIS ?= arm64-v8a,armeabi-v7a
DOCKER_GO_BUILD_CACHE_VOLUME ?= go-build-cache
DOCKER_GRADLE_BUILD_CACHE_VOLUME ?= gradle-build-cache
DOCKER_GO_BUILD_CACHE_DIR ?= /cache/go-build
DOCKER_GRADLE_CACHE_DIR ?= /cache/gradle
DESKTOP_DOCKER_IMAGE ?= volvoxgrid-desktop-jar:latest
DESKTOP_VERSION ?= $(VOLVOXGRID_VERSION)
DESKTOP_GROUP_ID ?= io.github.ivere27
DESKTOP_ARTIFACT_ID ?= volvoxgrid-desktop
DESKTOP_BUILD_OCX ?= 1
DESKTOP_BUILD_DOTNET ?= 1
DESKTOP_GIT_COMMIT ?= $(shell git -C "$(CURRENT_DIR)" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)
DESKTOP_BUILD_DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
WEB_DOCKER_IMAGE ?= volvoxgrid-web:latest
WEB_DOCKER_TARGET ?= all
WEB_DOCKER_PORT ?= 5173
WEB_GIT_COMMIT ?= $(AAR_GIT_COMMIT)
WEB_BUILD_DATE ?= $(AAR_BUILD_DATE)
IOS_DOCKER_IMAGE ?= volvoxgrid-ios:latest
IOS_VERSION ?= $(VOLVOXGRID_VERSION)
IOS_GIT_COMMIT ?= $(shell git -C "$(CURRENT_DIR)" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)
IOS_BUILD_DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
ALL_DOCKER_IMAGE ?= volvoxgrid-all:latest
ALL_GIT_COMMIT ?= $(AAR_GIT_COMMIT)
ALL_BUILD_DATE ?= $(AAR_BUILD_DATE)
ALL_BUILD_OCX ?= $(DESKTOP_BUILD_OCX)
FIXED_DATE ?=
ifneq ($(strip $(FIXED_DATE)),)
AAR_BUILD_DATE := $(FIXED_DATE)
DESKTOP_BUILD_DATE := $(FIXED_DATE)
IOS_BUILD_DATE := $(FIXED_DATE)
ALL_BUILD_DATE := $(FIXED_DATE)
endif
MAVEN_SETTINGS ?= $(CURRENT_DIR)/.maven-settings.xml
MAVEN_REPO_URL ?= https://central.sonatype.com/api/v1/publisher/upload
MAVEN_LOCAL_REPO ?= $(HOME)/.m2/repository

# iOS SPM publishing
IOS_XCFRAMEWORK_DIR := dist/ios/VolvoxGridPlugin.xcframework
IOS_XCFRAMEWORK_ZIP := dist/ios/VolvoxGridPlugin.xcframework.zip
IOS_GITHUB_REPO ?= ivere27/volvoxgrid
WEB_BUNDLE_DIR := dist/web
WEB_BUNDLE_ZIP := $(WEB_BUNDLE_DIR)/volvoxgrid-web-$(VOLVOXGRID_VERSION).zip
WEB_BUNDLE_LITE_ZIP := $(WEB_BUNDLE_DIR)/volvoxgrid-web-lite-$(VOLVOXGRID_VERSION).zip
FIREBASE_PUBLIC_DIR ?= public

ifeq ($(VOLVOXGRID_SOURCE_RESOLVED),maven)
ANDROID_INSTALL_PREREQ :=
ANDROID_INSTALL_RELEASE_PREREQ :=
else
ANDROID_INSTALL_PREREQ := android-plugin
ANDROID_INSTALL_RELEASE_PREREQ := android-plugin-release
endif

ifeq ($(VOLVOXGRID_SOURCE_RESOLVED),maven)
FLUTTER_RUN_PREREQ := flutter-setup
FLUTTER_RUN_RELEASE_PREREQ := flutter-setup
else
FLUTTER_RUN_PREREQ := flutter-setup android-plugin
FLUTTER_RUN_RELEASE_PREREQ := flutter-setup android-plugin-release
endif

ifeq ($(VOLVOXGRID_SOURCE_RESOLVED),maven)
JAVA_DESKTOP_RUN_PREREQ :=
JAVA_DESKTOP_RUN_RELEASE_PREREQ :=
JAVA_DESKTOP_RUN_SIMPLE_PREREQ :=
JAVA_DESKTOP_SMOKE_PREREQ :=
JAVA_DESKTOP_PLUGIN_ARG :=
JAVA_DESKTOP_PLUGIN_RELEASE_ARG :=
else
JAVA_DESKTOP_RUN_PREREQ := java-host-plugin
JAVA_DESKTOP_RUN_RELEASE_PREREQ := java-host-plugin-release
JAVA_DESKTOP_RUN_SIMPLE_PREREQ := java-host-plugin
JAVA_DESKTOP_SMOKE_PREREQ := java-host-plugin
JAVA_DESKTOP_PLUGIN_ARG := --args="$(JAVA_DESKTOP_PLUGIN)"
JAVA_DESKTOP_PLUGIN_RELEASE_ARG := --args="$(JAVA_DESKTOP_PLUGIN_RELEASE)"
endif

.PHONY: all build engine host-plugin java-host-plugin plugin engine-release host-plugin-release java-host-plugin-release release \
                build_plugin run run-release test test_pixel wasm wasm-lite wasm-threaded web web-lite doom-deps \
        codegen \
        android android-build \
        android-plugin android-plugin-release android-install android-install-release android-run android-run-release flutter flutter-setup \
        flutter-run flutter-run-release flutter-linux \
        java-desktop-run java-desktop-run-release java-desktop-run-simple java-desktop-smoke \
        java-tui-run java-tui-run-release java-tui-smoke java-tui-smoke-release \
        go-tui-build go-tui-build-release go-tui-run go-tui-run-release go-tui-smoke go-tui-smoke-release \
        dotnet-build dotnet-build-release dotnet-run dotnet-run-release dotnet-smoke dotnet-smoke-release \
        dotnet-tui-build dotnet-tui-build-release dotnet-tui-run dotnet-tui-run-release dotnet-tui-smoke dotnet-tui-smoke-release \
        sheet sheet-lite sheet-build \
        report report-build \
        activex activex-release activex-run activex-run-release activex-lite activex-lite-release \
        activex-gpu activex-gpu-release \
        vsflexgrid vsflexgrid-release \
        docker_android_aar_image docker_android docker_desktop_image docker_desktop \
        docker_web_image docker_web \
        docker_ios_image docker_ios docker_all_image docker_all publish_maven \
        publish_local publish_github publish_web publish_npm \
        gtk-test gtk-test-release gtk-bench clean clean-all help

# =============================================================================
# Default
# =============================================================================
all: build
	@echo "Build complete. Run 'make run' for smoke test, 'make web' for browser demo."

help:
	@echo "VolvoxGrid Makefile targets:"
	@echo ""
	@echo "  build_plugin   Install protoc-gen-synurang-ffi from GitHub ($(SYNURANG_VERSION))"
	@echo "  build          Build engine + host-plugin (debug)"
	@echo "  release        Build engine + host-plugin (release, optimized)"
	@echo "  host-plugin    Build host (desktop) plugin crate (debug)"
	@echo "  host-plugin-release  Build host (desktop) plugin crate (release)"
	@echo "  java-host-plugin  Build host plugin for Java desktop flows (debug)"
	@echo "  java-host-plugin-release  Build host plugin for Java desktop flows (release)"
	@echo "  run            Build & run smoke test (debug)"
	@echo "  run-release    Build & run smoke test (release)"
	@echo "  test           Run engine unit tests"
	@echo "  test_pixel     Run engine pixel regression tests"
	@echo "  wasm           Build WASM crate (requires wasm-pack)"
	@echo "  wasm-lite      Build WASM crate without cosmic-text/gpu (~1MB)"
	@echo "  wasm-threaded  Build WASM crate with threads/atomics (requires COOP+COEP at runtime)"
	@echo "  web            Build WASM + start Vite dev server (Sales/Hierarchy/Stress/DOOM selector)"
	@echo "  web-lite       Build WASM lite + start Vite dev server"
	@echo "    web options: WEB_SCALE=<value>, WEB_HOVER={true|false} (default false)"
	@echo "  codegen        Regenerate all FFI bindings"
	@echo "  activex        Build ActiveX OCX (debug)"
	@echo "  activex-run    Build and run ActiveX demo shell (debug, default x86_64)"
	@echo "  activex-run-release  Build and run ActiveX demo shell (release, default x86_64)"
	@echo "  activex-lite   Build ActiveX OCX without rayon/regex (debug)"
	@echo "  activex-lite-release Build ActiveX OCX without rayon/regex (release, ~1MB)"
	@echo "  activex-gpu-release Build ActiveX OCX with GPU enabled (release, ~3MB)"
	@echo "    activex-run option: ACTIVEX_ARCH=i686|x86_64"
	@echo "  android        Build AAR, install example app, and launch on device"
	@echo "  android-build  Build Android AAR only (requires Android SDK)"
	@echo "  android-plugin Build debug Android plugin .so for Flutter jniLibs and package debug fat AAR"
	@echo "  android-plugin-release Build release plugin .so and package release fat AAR"
	@echo "  android-run    Install and launch Android example app on device"
	@echo "  android-run-release  Build release plugin, install debug app, and launch on device"
	@echo "  flutter        Build Flutter example (requires Flutter SDK)"
	@echo "  flutter-run    Run Flutter example on connected Android device"
	@echo "  flutter-run-release  Run Flutter example (release mode) on connected Android device"
	@echo "  flutter-linux  Run Flutter example on Linux desktop"
	@echo "  java-desktop-run    Run Java desktop Android-style example"
	@echo "  java-desktop-run-release  Run Java desktop Android-style example with release plugin"
	@echo "  java-desktop-run-simple  Run Java desktop minimal demo"
	@echo "  java-desktop-smoke  Run headless Java desktop smoke test"
	@echo "  java-tui-run    Run Java terminal TUI sample"
	@echo "  java-tui-run-release  Run Java terminal TUI sample with release plugin"
	@echo "  java-tui-smoke  Run Java terminal TUI smoke checks"
	@echo "  java-tui-smoke-release  Run Java terminal TUI smoke checks with release plugin"
	@echo "  go-tui-build  Build Go terminal TUI sample (debug binary)"
	@echo "  go-tui-build-release  Build Go terminal TUI sample (release-style binary)"
	@echo "  go-tui-run  Run Go terminal TUI sample (debug plugin)"
	@echo "  go-tui-run-release  Run Go terminal TUI sample (release plugin)"
	@echo "  go-tui-smoke  Run Go terminal TUI smoke checks (debug plugin)"
	@echo "  go-tui-smoke-release  Run Go terminal TUI smoke checks (release plugin)"
	@echo "  dotnet-build  Build VolvoxGrid .NET wrapper + sample (debug)"
	@echo "  dotnet-build-release  Build VolvoxGrid .NET wrapper + sample (release)"
	@echo "  dotnet-run    Run .NET sample (debug)"
	@echo "  dotnet-run-release  Run .NET sample (release)"
	@echo "  dotnet-smoke  Run automated .NET controller smoke checks (debug)"
	@echo "  dotnet-smoke-release  Run automated .NET controller smoke checks (release)"
	@echo "  dotnet-tui-build  Build .NET 8 terminal sample (debug)"
	@echo "  dotnet-tui-build-release  Build .NET 8 terminal sample (release)"
	@echo "  dotnet-tui-run  Run .NET 8 terminal sample (debug)"
	@echo "  dotnet-tui-run-release  Run .NET 8 terminal sample (release)"
	@echo "  dotnet-tui-smoke  Run non-interactive .NET 8 terminal sample smoke checks (debug)"
	@echo "  dotnet-tui-smoke-release  Run non-interactive .NET 8 terminal sample smoke checks (release)"
	@echo "    (set DOTNET_TFM=net8.0-windows to switch target; default: net40)"
	@echo "    (set DOTNET_ARCH=x86 to build 32-bit; default: x64)"
	@echo "    (TUI sample uses DOTNET_TUI_TFM=$(DOTNET_TUI_TFM))"
	@echo "  sheet          Build WASM + start Sheet adapter Vite dev server"
	@echo "  sheet-lite     Build WASM lite + start Sheet adapter Vite dev server"
	@echo "  sheet-build    Build Sheet adapter npm package only"
	@echo "  doom-deps      Download GPL-2.0 DOOM assets for web mode (not part of Apache-2.0 source)"
	@echo "  gtk-test       Build & launch GTK4 plugin-host visual test (debug; requires GTK4 dev libs)"
	@echo "  gtk-test-release  Build & launch GTK4 plugin-host visual test (release)"
	@echo "  gtk-bench      Build and run GTK4 benchmark matrix (release; real GPU surface for GPU cases, sudo with desktop session env)"
	@echo "    gtk bench options: GTK_BENCH_RUNS=<n>, GTK_BENCH_ARGS='<extra headless_bench args>'"
	@echo ""
	@echo "Docker + Maven:"
	@echo "  docker_android_aar_image  Build Docker image for Android AAR"
	@echo "  docker_android            Build Android AAR + Android lite AAR via Docker, auto-install SNAPSHOT to mavenLocal"
	@echo "  docker_desktop_image      Build Docker image for desktop JAR"
	@echo "  docker_desktop            Build desktop JAR + .NET WinForms x64+x86 artifacts via Docker (+ ActiveX OCX release/release-lite), auto-install SNAPSHOT to mavenLocal"
	@echo "  docker_web_image          Build Docker image for web dist/bundle tasks"
	@echo "  docker_web                Build in Docker (default WEB_DOCKER_TARGET=all): WEB_DOCKER_TARGET={all|bundle|web|sheet|sheet-lite|report|wasm|wasm-lite|wasm-threaded}"
	@echo "  docker_ios_image          Build Docker image for iOS"
	@echo "  docker_ios                Build iOS XCFramework via Docker"
	@echo "  docker_all_image          Build unified Docker image (all toolchains)"
	@echo "  docker_all                Build all platform artifacts via unified Docker image (Android full+lite, .NET WinForms x64+x86), auto-install SNAPSHOT to mavenLocal"
	@echo "  publish_maven             Upload Android AAR + Android lite AAR + desktop JAR to Maven Central"
	@echo "  publish_github            Upload all artifacts (xcframework, AAR, JAR, .NET, ActiveX, web zips) to GitHub release"
	@echo "  publish_local             Install built SNAPSHOT artifacts from dist/maven into ~/.m2/repository"
	@echo "  publish_web               Copy dist/web -> public (clean), then run firebase deploy"
	@echo "  publish_npm               Publish volvoxgrid + adapter npm packages from dist/web zip"
	@echo ""
	@echo "Example dependency source flags (default is local):"
	@echo "  make android-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VERSION=0.7.0"
	@echo "  make java-desktop-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VERSION=0.7.0"
	@echo "  make android-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VARIANT=lite VOLVOXGRID_VERSION=0.7.0"
	@echo "  (maven mode skips local plugin build for the example targets)"
	@echo "  Flutter defaults to maven when VOLVOXGRID_SOURCE is omitted."
	@echo "  VOLVOXGRID_SOURCE=local builds from source."
	@echo "  Android variant: set VOLVOXGRID_VARIANT=lite for lite; any other value uses normal"
	@echo "  Optional override: VOLVOXGRID_*_GROUP and VOLVOXGRID_*_ARTIFACT"
	@echo "  Build parallelism: BUILD_JOBS defaults to max(CPU-2,1); override with BUILD_JOBS=N"
	@echo ""
	@echo "  clean          Remove build artifacts"
	@echo "  clean-all      Remove all artifacts including WASM/node_modules"

# =============================================================================
# Build synurang FFI plugin
# =============================================================================
build_plugin:
	@echo "Installing protoc-gen-synurang-ffi from $(SYNURANG_MODULE)@$(SYNURANG_VERSION)..."
	@go install $(SYNURANG_MODULE)/cmd/protoc-gen-synurang-ffi@$(SYNURANG_VERSION)
	@test -x "$(PROTOC_PLUGIN)" || { echo "Error: protoc-gen-synurang-ffi not found at $(PROTOC_PLUGIN)"; exit 1; }
	@echo "Using plugin binary: $(PROTOC_PLUGIN)"

# =============================================================================
# Build
# =============================================================================
build: engine host-plugin

release: engine-release host-plugin-release

engine:
	@echo "Building engine crate (debug)..."
	cd engine && cargo build $(CARGO_JOBS_FLAG) --features gpu
	@echo "Engine build complete."

engine-release:
	@echo "Building engine crate (release)..."
	cd engine && cargo build $(CARGO_JOBS_FLAG) --release --features gpu
	@echo "Engine release build complete."

host-plugin: engine
	@echo "Building plugin crate (debug)..."
	cd plugin && cargo build $(CARGO_JOBS_FLAG) --features gpu
	@echo "Plugin build complete: target/debug/libvolvoxgrid_plugin.so"

host-plugin-release: engine-release
	@echo "Building plugin crate (release)..."
	cd plugin && cargo build $(CARGO_JOBS_FLAG) --release --features gpu
	@echo "Plugin release build complete: target/release/libvolvoxgrid_plugin.so"

java-host-plugin: host-plugin

java-host-plugin-release: host-plugin-release

# =============================================================================
# Test
# =============================================================================
test:
	@echo "Running engine tests..."
	cd engine && cargo test $(CARGO_JOBS_FLAG) --features gpu
	@echo "Tests complete."

test_pixel:
	@echo "Running engine pixel regression tests..."
	cargo test $(CARGO_JOBS_FLAG) -p volvoxgrid-engine --features demo --test pixel_regression
	@echo "Pixel regression tests complete."

# =============================================================================
# Smoke Test — Load plugin via Rust host, exercise basic RPCs
# =============================================================================
run: host-plugin
	@echo "Building smoke test..."
	cd smoke-test && cargo build $(CARGO_JOBS_FLAG) --features gpu
	@echo "Running smoke test..."
	./target/debug/volvoxgrid-smoke
	@echo ""

run-release: host-plugin-release
	@echo "Building smoke test (release)..."
	cd smoke-test && cargo build $(CARGO_JOBS_FLAG) --release --features gpu
	@echo "Running smoke test..."
	./target/release/volvoxgrid-smoke target/release/libvolvoxgrid_plugin.so
	@echo ""

java-desktop-run: $(JAVA_DESKTOP_RUN_PREREQ)
	@echo "Running Java desktop Android-style example..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) --no-daemon $(GRADLE_JOBS_FLAG) run $(JAVA_DESKTOP_PLUGIN_ARG)
	@echo ""

java-desktop-run-release: $(JAVA_DESKTOP_RUN_RELEASE_PREREQ)
	@echo "Running Java desktop Android-style example (release plugin)..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) --no-daemon $(GRADLE_JOBS_FLAG) run $(JAVA_DESKTOP_PLUGIN_RELEASE_ARG)
	@echo ""

java-desktop-run-simple: $(JAVA_DESKTOP_RUN_SIMPLE_PREREQ)
	@echo "Running Java desktop minimal demo..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) --no-daemon $(GRADLE_JOBS_FLAG) runSimpleDemo $(JAVA_DESKTOP_PLUGIN_ARG)
	@echo ""

java-desktop-smoke: $(JAVA_DESKTOP_SMOKE_PREREQ)
	@echo "Running Java desktop smoke test..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) --no-daemon $(GRADLE_JOBS_FLAG) runSmoke $(JAVA_DESKTOP_PLUGIN_ARG)
	@echo ""

java-tui-run: $(JAVA_DESKTOP_RUN_PREREQ)
	@echo "Running Java terminal TUI sample..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) --no-daemon $(GRADLE_JOBS_FLAG) installTuiDist
	"$(JAVA_DESKTOP_PROJECT_DIR)/build/install/volvoxgrid-desktop-tui/bin/volvoxgrid-desktop-tui" "$(JAVA_DESKTOP_PLUGIN)"
	@echo ""

java-tui-run-release: $(JAVA_DESKTOP_RUN_RELEASE_PREREQ)
	@echo "Running Java terminal TUI sample (release plugin)..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) --no-daemon $(GRADLE_JOBS_FLAG) installTuiDist
	"$(JAVA_DESKTOP_PROJECT_DIR)/build/install/volvoxgrid-desktop-tui/bin/volvoxgrid-desktop-tui" "$(JAVA_DESKTOP_PLUGIN_RELEASE)"
	@echo ""

java-tui-smoke: $(JAVA_DESKTOP_SMOKE_PREREQ)
	@echo "Running Java terminal TUI smoke test..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) --no-daemon $(GRADLE_JOBS_FLAG) installTuiDist
	VOLVOXGRID_DESKTOP_TUI_OPTS='-Dvolvoxgrid.tui.smoke=true' \
		"$(JAVA_DESKTOP_PROJECT_DIR)/build/install/volvoxgrid-desktop-tui/bin/volvoxgrid-desktop-tui" "$(JAVA_DESKTOP_PLUGIN)"
	@echo ""

java-tui-smoke-release: $(JAVA_DESKTOP_RUN_RELEASE_PREREQ)
	@echo "Running Java terminal TUI smoke test (release plugin)..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) --no-daemon $(GRADLE_JOBS_FLAG) installTuiDist
	VOLVOXGRID_DESKTOP_TUI_OPTS='-Dvolvoxgrid.tui.smoke=true' \
		"$(JAVA_DESKTOP_PROJECT_DIR)/build/install/volvoxgrid-desktop-tui/bin/volvoxgrid-desktop-tui" "$(JAVA_DESKTOP_PLUGIN_RELEASE)"
	@echo ""

GO_TUI_BINARY := $(abspath target/go/volvoxgrid-go-tui)
GO_TUI_BINARY_RELEASE := $(abspath target/go/volvoxgrid-go-tui-release)
GO_TUI_BUILD_ENV := GOCACHE=/tmp/volvoxgrid-go-build

go-tui-build:
	@echo "Building Go terminal TUI sample..."
	@mkdir -p target/go
	cd "$(GO_PROJECT_DIR)" && $(GO_TUI_BUILD_ENV) go build -o "$(GO_TUI_BINARY)" ./examples/tui
	@echo ""

go-tui-build-release:
	@echo "Building Go terminal TUI sample (release-style binary)..."
	@mkdir -p target/go
	cd "$(GO_PROJECT_DIR)" && $(GO_TUI_BUILD_ENV) go build -trimpath -ldflags='-s -w' -o "$(GO_TUI_BINARY_RELEASE)" ./examples/tui
	@echo ""

go-tui-run: host-plugin go-tui-build
	@echo "Running Go terminal TUI sample (debug plugin)..."
	"$(GO_TUI_BINARY)" "$(JAVA_DESKTOP_PLUGIN)"
	@echo ""

go-tui-run-release: host-plugin-release go-tui-build-release
	@echo "Running Go terminal TUI sample (release plugin)..."
	"$(GO_TUI_BINARY_RELEASE)" "$(JAVA_DESKTOP_PLUGIN_RELEASE)"
	@echo ""

go-tui-smoke: host-plugin go-tui-build
	@echo "Running Go terminal TUI smoke test (debug plugin)..."
	VOLVOXGRID_GO_TUI_SMOKE_MODE=1 "$(GO_TUI_BINARY)" "$(JAVA_DESKTOP_PLUGIN)"
	@echo ""

go-tui-smoke-release: host-plugin-release go-tui-build-release
	@echo "Running Go terminal TUI smoke test (release plugin)..."
	VOLVOXGRID_GO_TUI_SMOKE_MODE=1 "$(GO_TUI_BINARY_RELEASE)" "$(JAVA_DESKTOP_PLUGIN_RELEASE)"
	@echo ""

dotnet-build:
	@echo "Building VolvoxGrid .NET wrapper + sample (debug, $(DOTNET_TFM), $(DOTNET_ARCH))..."
	./dotnet/build_dotnet.sh --tfm "$(DOTNET_TFM)" --arch "$(DOTNET_ARCH)"
	@echo ""

dotnet-build-release:
	@echo "Building VolvoxGrid .NET wrapper + sample (release, $(DOTNET_TFM), $(DOTNET_ARCH))..."
	./dotnet/build_dotnet.sh --tfm "$(DOTNET_TFM)" --arch "$(DOTNET_ARCH)" release
	@echo ""

dotnet-run: dotnet-build
	@echo "Running .NET sample (debug, $(DOTNET_TFM), $(DOTNET_ARCH))..."
	./dotnet/run_sample.sh --tfm "$(DOTNET_TFM)" --arch "$(DOTNET_ARCH)"
	@echo ""

dotnet-run-release: dotnet-build-release
	@echo "Running .NET sample (release, $(DOTNET_TFM), $(DOTNET_ARCH))..."
	./dotnet/run_sample.sh --tfm "$(DOTNET_TFM)" --arch "$(DOTNET_ARCH)" release
	@echo ""

activex-run: activex
	@echo "Running ActiveX demo (debug, $(ACTIVEX_ARCH))..."
	ACTIVEX_ARCH="$(ACTIVEX_ARCH)" ./adapters/vsflexgrid/mingw/run_demo.sh
	@echo ""

activex-run-release: activex-release
	@echo "Running ActiveX demo (release, $(ACTIVEX_ARCH))..."
	ACTIVEX_ARCH="$(ACTIVEX_ARCH)" ./adapters/vsflexgrid/mingw/run_demo.sh release
	@echo ""

dotnet-smoke: dotnet-build
	@echo "Running .NET controller smoke checks (debug, $(DOTNET_TFM), $(DOTNET_ARCH))..."
	VOLVOXGRID_SMOKE_MODE=1 VOLVOXGRID_SMOKE_EXIT=1 ./dotnet/run_sample.sh --tfm "$(DOTNET_TFM)" --arch "$(DOTNET_ARCH)"
	@echo ""

dotnet-smoke-release: dotnet-build-release
	@echo "Running .NET controller smoke checks (release, $(DOTNET_TFM), $(DOTNET_ARCH))..."
	VOLVOXGRID_SMOKE_MODE=1 VOLVOXGRID_SMOKE_EXIT=1 ./dotnet/run_sample.sh --tfm "$(DOTNET_TFM)" --arch "$(DOTNET_ARCH)" release
	@echo ""

dotnet-tui-build:
	@echo "Building VolvoxGrid .NET TUI sample (debug, $(DOTNET_TUI_TFM))..."
	./dotnet/build_dotnet.sh --sample tui --tfm "$(DOTNET_TUI_TFM)" --arch "$(DOTNET_ARCH)"
	@echo ""

dotnet-tui-build-release:
	@echo "Building VolvoxGrid .NET TUI sample (release, $(DOTNET_TUI_TFM))..."
	./dotnet/build_dotnet.sh --sample tui --tfm "$(DOTNET_TUI_TFM)" --arch "$(DOTNET_ARCH)" release
	@echo ""

dotnet-tui-run: dotnet-tui-build
	@echo "Running .NET TUI sample (debug, $(DOTNET_TUI_TFM))..."
	./dotnet/run_sample.sh --sample tui --tfm "$(DOTNET_TUI_TFM)" --arch "$(DOTNET_ARCH)"
	@echo ""

dotnet-tui-run-release: dotnet-tui-build-release
	@echo "Running .NET TUI sample (release, $(DOTNET_TUI_TFM))..."
	./dotnet/run_sample.sh --sample tui --tfm "$(DOTNET_TUI_TFM)" --arch "$(DOTNET_ARCH)" release
	@echo ""

dotnet-tui-smoke: dotnet-tui-build
	@echo "Running .NET TUI sample smoke checks (debug, $(DOTNET_TUI_TFM))..."
	VOLVOXGRID_TUI_SMOKE_MODE=1 ./dotnet/run_sample.sh --sample tui --tfm "$(DOTNET_TUI_TFM)" --arch "$(DOTNET_ARCH)"
	@echo ""

dotnet-tui-smoke-release: dotnet-tui-build-release
	@echo "Running .NET TUI sample smoke checks (release, $(DOTNET_TUI_TFM))..."
	VOLVOXGRID_TUI_SMOKE_MODE=1 ./dotnet/run_sample.sh --sample tui --tfm "$(DOTNET_TUI_TFM)" --arch "$(DOTNET_ARCH)" release
	@echo ""

# =============================================================================
# WASM
# =============================================================================
WASM_OUTPUT_DIR := web/example/wasm
WASM_OUTPUT_MAIN := $(WASM_OUTPUT_DIR)/volvoxgrid_wasm_bg.wasm

wasm:
	@command -v wasm-pack >/dev/null 2>&1 || { echo "Error: wasm-pack not found. Install with: cargo install wasm-pack"; exit 1; }
	@echo "Building WASM crate..."
	cd web/crate && CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" rustup run nightly wasm-pack build . --target web --out-dir ../example/wasm --features gpu
	@echo "WASM build complete: web/example/wasm/"

wasm-lite:
	@command -v wasm-pack >/dev/null 2>&1 || { echo "Error: wasm-pack not found. Install with: cargo install wasm-pack"; exit 1; }
	@echo "Building WASM crate (lite)..."
	cd web/crate && CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" rustup run nightly wasm-pack build . --target web --out-dir ../example/wasm --no-default-features
	@echo "WASM lite build complete: web/example/wasm/"

wasm-threaded:
	@command -v wasm-pack >/dev/null 2>&1 || { echo "Error: wasm-pack not found. Install with: cargo install wasm-pack"; exit 1; }
	@echo "Building WASM crate (threaded)..."
	cd web/crate && CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" RUSTFLAGS='-C target-feature=+atomics,+bulk-memory,+mutable-globals' rustup run nightly wasm-pack build . --target web --out-dir ../example/wasm --features wasm-threads,gpu -Z build-std=std,panic_abort
	@echo "WASM threaded build complete: web/example/wasm/"

wasm-ready:
	@if [ "$(FORCE_WASM)" = "1" ] || [ ! -f "$(WASM_OUTPUT_MAIN)" ]; then \
		$(MAKE) wasm; \
	else \
		echo "Using existing WASM build: $(WASM_OUTPUT_MAIN)"; \
	fi

# =============================================================================
# Web Dev Server
# =============================================================================
web: wasm
	@if [ ! -f web/example/public/doom/vendor/doom.jsdos ] || [ ! -f web/example/public/doom/emulators/emulators.js ]; then \
		echo "Warning: DOOM mode assets are missing."; \
		echo "         Run 'make doom-deps' to enable DOOM in the web demo."; \
	fi
	@echo "Starting web dev server (host=$(WEB_HOST), scale=$(WEB_SCALE), hover=$(WEB_HOVER))..."
	cd web/example && npm install && VITE_VG_INITIAL_SCALE="$(WEB_SCALE)" VITE_VG_ENABLE_HOVER="$(WEB_HOVER)" npm run dev -- --host "$(WEB_HOST)"

web-lite: wasm-lite
	@echo "Starting web dev server (lite mode, hover=$(WEB_HOVER))..."
	cd web/example && npm install && VITE_VG_INITIAL_SCALE="$(WEB_SCALE)" VITE_VG_ENABLE_HOVER="$(WEB_HOVER)" npm run dev -- --host "$(WEB_HOST)"

# =============================================================================
# Sheet Adapter — Spreadsheet UX on top of VolvoxGrid WASM
# =============================================================================
SHEET_DIR := adapters/sheet
SHEET_WASM_DIR := $(SHEET_DIR)/wasm
WEB_JS_DIR := web/js

sheet: wasm-ready
	@echo "Building VolvoxGrid JS package for Sheet adapter..."
	cd "$(WEB_JS_DIR)" && npm install && npm run build
	@echo "Linking WASM output into Sheet adapter..."
	@mkdir -p "$(SHEET_WASM_DIR)"
	@ln -sf "$(abspath web/example/wasm)"/* "$(SHEET_WASM_DIR)/"
	@echo "Starting Sheet adapter dev server (host=$(WEB_HOST))..."
	cd "$(SHEET_DIR)" && npm install && npx vite --host "$(WEB_HOST)"

sheet-lite: wasm-lite
	@echo "Building VolvoxGrid JS package for Sheet adapter..."
	cd "$(WEB_JS_DIR)" && npm install && npm run build
	@echo "Linking WASM lite output into Sheet adapter..."
	@mkdir -p "$(SHEET_WASM_DIR)"
	@ln -sf "$(abspath web/example/wasm)"/* "$(SHEET_WASM_DIR)/"
	@echo "Starting Sheet adapter dev server (lite mode, host=$(WEB_HOST))..."
	cd "$(SHEET_DIR)" && npm install && npx vite --host "$(WEB_HOST)"

sheet-build:
	@echo "Building VolvoxGrid JS package for Sheet adapter..."
	cd "$(WEB_JS_DIR)" && npm install && npm run build
	@echo "Building Sheet adapter npm package..."
	cd "$(SHEET_DIR)" && npm install && npm run build
	@echo "Sheet adapter build complete: $(SHEET_DIR)/dist/"

# =============================================================================
# Report Engine — YAML-based reporting on top of VolvoxGrid WASM
# =============================================================================
REPORT_DIR := adapters/report
REPORT_WASM_DIR := $(REPORT_DIR)/wasm

report: wasm
	@echo "Linking WASM output into Report adapter..."
	@mkdir -p "$(REPORT_WASM_DIR)"
	@ln -sf "$(abspath web/example/wasm)"/* "$(REPORT_WASM_DIR)/"
	@echo "Starting Report Designer dev server (host=$(WEB_HOST))..."
	cd "$(REPORT_DIR)" && npm install && npx vite --host "$(WEB_HOST)"

report-build:
	@echo "Linking WASM output into Report adapter..."
	@mkdir -p "$(REPORT_WASM_DIR)"
	@ln -sf "$(abspath web/example/wasm)"/* "$(REPORT_WASM_DIR)/"
	@echo "Building Report adapter package..."
	cd "$(REPORT_DIR)" && npm install && npm run build
	@echo "Report adapter build complete: $(REPORT_DIR)/dist/"

# =============================================================================
# DOOM Demo — js-dos + VolvoxGrid performance showcase
# GPL-2.0 assets are downloaded at runtime, never committed to this repo.
# =============================================================================
doom-deps:
	@echo "Downloading GPL-2.0 assets (not part of Apache-2.0 source)..."
	@mkdir -p web/example/public/doom/vendor
	@mkdir -p web/example/public/doom/emulators
	@test -f web/example/public/doom/vendor/doom.jsdos || \
		curl -L -o web/example/public/doom/vendor/doom.jsdos "$(DOOM_BUNDLE_URL)"
	@cd web/example && npm install --ignore-scripts --no-save --no-package-lock emulators@$(DOOM_EMULATORS_VERSION) 2>/dev/null && \
		cp -r node_modules/emulators/dist/* public/doom/emulators/ 2>/dev/null || true
	@if [ -f web/example/public/doom/emulators/emulators.js ]; then \
		echo "DOOM assets ready in web/example/public/doom/"; \
	else \
		echo "Warning: emulators runtime was not prepared. Retry 'make doom-deps'."; \
	fi

# =============================================================================
# Codegen — Regenerate FFI bindings
# =============================================================================
VSFLEXGRID_DIR := adapters/vsflexgrid
DOTNET_COMMON_CODEGEN_DIR := dotnet/src/common/Generated
WEB_TS_CODEGEN_DIR := web/js/src/generated
PROTO_INCLUDES := -Iproto -I$(VSFLEXGRID_DIR)/proto
PROTO3_OPT := --experimental_allow_proto3_optional

codegen: build_plugin
	@test -x "$(PROTOC_PLUGIN)" || { echo "Error: protoc-gen-synurang-ffi not found at $(PROTOC_PLUGIN)"; exit 1; }
	@command -v protoc-gen-dart >/dev/null 2>&1 || { echo "Error: protoc-gen-dart not found in PATH."; exit 1; }
	@command -v protoc-gen-go >/dev/null 2>&1 || { echo "Error: protoc-gen-go not found in PATH."; exit 1; }
	@command -v protoc-gen-go-grpc >/dev/null 2>&1 || { echo "Error: protoc-gen-go-grpc not found in PATH."; exit 1; }
	@echo "Generating v1 runtime FFI bindings..."
	@mkdir -p codegen
	@mkdir -p $(DOTNET_COMMON_CODEGEN_DIR)
	@mkdir -p $(WEB_TS_CODEGEN_DIR)
	@mkdir -p $(GO_PROJECT_DIR)/api/v1
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		--go_out=$(GO_PROJECT_DIR) --go_opt=module=github.com/ivere27/volvoxgrid \
		--go-grpc_out=$(GO_PROJECT_DIR) --go-grpc_opt=module=github.com/ivere27/volvoxgrid \
		proto/volvoxgrid.proto
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=codegen --synurang-ffi_opt=lang=java \
		proto/volvoxgrid.proto
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=codegen --synurang-ffi_opt=lang=dart \
		proto/volvoxgrid.proto
	# Flutter protobuf messages
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		--dart_out=flutter/lib/src/generated \
		proto/volvoxgrid.proto
	@cp codegen/volvoxgrid_ffi.pb.dart flutter/lib/src/generated/volvoxgrid_ffi.pb.dart
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=codegen --synurang-ffi_opt=lang=cpp \
		proto/volvoxgrid.proto
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=codegen --synurang-ffi_opt=lang=rust \
		proto/volvoxgrid.proto
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=$(WEB_TS_CODEGEN_DIR) --synurang-ffi_opt=lang=typescript \
		proto/volvoxgrid.proto
	# .NET lite protobuf + FFI stubs (shared)
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=$(DOTNET_COMMON_CODEGEN_DIR) --synurang-ffi_opt=lang=csharp,mode=lite \
		proto/volvoxgrid.proto
	# Plugin server trait + dispatcher
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=plugin/src --synurang-ffi_opt=lang=rust,mode=plugin_server \
		proto/volvoxgrid.proto
	@$(SED_I) '/^#!\[allow(dead_code)\]/a use super::*;' plugin/src/volvoxgrid_ffi_plugin.rs
	@$(SED_I) 's/PLUGIN_VOLVOX_GRID_SERVICE\.get()\.map(|p| p\.as_ref())/Some(PLUGIN_VOLVOX_GRID_SERVICE.get_or_init(super::create_plugin).as_ref())/' plugin/src/volvoxgrid_ffi_plugin.rs
	# WASM bindings
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=web/crate/src --synurang-ffi_opt=lang=rust,mode=wasm \
		proto/volvoxgrid.proto
	@$(SED_I) '/^#!\[allow(dead_code)\]/a use super::*;' web/crate/src/volvoxgrid_wasm.rs
	# ActiveX native runtime bindings now come from v1 proto
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=$(VSFLEXGRID_DIR)/crate/src --synurang-ffi_opt=lang=rust,mode=native \
		proto/volvoxgrid.proto
	@$(SED_I) '/^#!\[allow(clippy/a use super::*;' $(VSFLEXGRID_DIR)/crate/src/volvoxgrid_ffi_native.rs
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=$(VSFLEXGRID_DIR)/include --synurang-ffi_opt=lang=c,mode=native \
		proto/volvoxgrid.proto
	# ActiveX COM dispatch metadata
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=$(VSFLEXGRID_DIR)/include --synurang-ffi_opt=lang=c,mode=native \
		$(VSFLEXGRID_DIR)/proto/volvoxgrid_activex.proto
	@tmp_activex_dir=$$(mktemp -d); \
	protoc $(PROTO_INCLUDES) $(PROTO3_OPT) \
		$(PROTOC_PLUGIN_FLAG) \
		--synurang-ffi_out=$$tmp_activex_dir --synurang-ffi_opt=lang=c,mode=activex \
		$(VSFLEXGRID_DIR)/proto/volvoxgrid_activex.proto; \
	cp $$tmp_activex_dir/volvoxgrid_activex_activex.h $(VSFLEXGRID_DIR)/include/volvoxgrid_activex.h; \
	rm -f $(VSFLEXGRID_DIR)/include/volvoxgrid_activex_activex.h; \
	rm -rf $$tmp_activex_dir
	@rustfmt \
		codegen/volvoxgrid_ffi.rs \
		plugin/src/volvoxgrid_ffi_plugin.rs \
		web/crate/src/volvoxgrid_wasm.rs \
		$(VSFLEXGRID_DIR)/crate/src/volvoxgrid_ffi_native.rs
	@echo "Codegen complete: codegen/ + $(DOTNET_COMMON_CODEGEN_DIR)/ + $(WEB_TS_CODEGEN_DIR)/ + plugin/ + web/ + $(VSFLEXGRID_DIR)/"

# =============================================================================
# Android
# =============================================================================
android: android-build android-run

android-build:
	@echo "Building Android AAR..."
	@echo "Using BUILD_JOBS=$(BUILD_JOBS) (cargo=$(CARGO_BUILD_JOBS), gradle=$(GRADLE_MAX_WORKERS))"
	@SDK_DIR=""; \
	if [ -n "$$ANDROID_HOME" ]; then \
		SDK_DIR="$$ANDROID_HOME"; \
	elif [ -n "$$ANDROID_SDK_ROOT" ]; then \
		SDK_DIR="$$ANDROID_SDK_ROOT"; \
	elif [ -d "$$HOME/Android/Sdk" ]; then \
		SDK_DIR="$$HOME/Android/Sdk"; \
	fi; \
	if [ -n "$$SDK_DIR" ]; then \
		echo "Using Android SDK: $$SDK_DIR"; \
		export ANDROID_HOME="$$SDK_DIR"; \
		export ANDROID_SDK_ROOT="$$SDK_DIR"; \
	else \
		echo "Warning: ANDROID_HOME/ANDROID_SDK_ROOT not set and $$HOME/Android/Sdk not found."; \
	fi; \
	if [ -x "$(ANDROID_GRADLEW)" ]; then \
		echo "Using project Gradle wrapper: $(ANDROID_GRADLEW)"; \
		"$(ANDROID_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_GRADLE_TASK)"; \
	elif [ -x "$(SHARED_GRADLEW)" ]; then \
		echo "Using shared Gradle wrapper: $(SHARED_GRADLEW)"; \
		"$(SHARED_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_GRADLE_TASK)"; \
	elif command -v gradle >/dev/null 2>&1; then \
		echo "Using system Gradle: $$(command -v gradle)"; \
		gradle -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_GRADLE_TASK)"; \
	else \
		echo "Error: no Gradle wrapper found."; \
		echo "Expected $(ANDROID_GRADLEW) or $(SHARED_GRADLEW), or install gradle."; \
		exit 1; \
	fi
	@echo "Android build complete."

android-plugin:
	@echo "Building Android VolvoxGrid plugin shared libraries (debug + debug AAR)..."
	@set -e; \
	SDK_DIR=""; \
	if [ -n "$$ANDROID_HOME" ]; then \
		SDK_DIR="$$ANDROID_HOME"; \
	elif [ -n "$$ANDROID_SDK_ROOT" ]; then \
		SDK_DIR="$$ANDROID_SDK_ROOT"; \
	elif [ -d "$$HOME/Android/Sdk" ]; then \
		SDK_DIR="$$HOME/Android/Sdk"; \
	fi; \
	NDK_DIR=""; \
	if [ -n "$$ANDROID_NDK_HOME" ]; then \
		NDK_DIR="$$ANDROID_NDK_HOME"; \
	elif [ -n "$$ANDROID_NDK_ROOT" ]; then \
		NDK_DIR="$$ANDROID_NDK_ROOT"; \
	elif [ -n "$$SDK_DIR" ] && [ -d "$$SDK_DIR/ndk" ]; then \
		NDK_DIR=$$(ls -1d "$$SDK_DIR"/ndk/* 2>/dev/null | sort -V | tail -n 1); \
	fi; \
	if [ -z "$$NDK_DIR" ]; then \
		echo "Error: Android NDK not found."; \
		echo "Set ANDROID_NDK_HOME or install NDK under $$HOME/Android/Sdk/ndk."; \
		exit 1; \
	fi; \
	echo "Using Android NDK: $$NDK_DIR"; \
	command -v cargo >/dev/null 2>&1 || { echo "Error: cargo not found in PATH."; exit 1; }; \
	cargo ndk --version >/dev/null 2>&1 || { echo "Error: cargo-ndk not found. Install with: cargo install cargo-ndk"; exit 1; }; \
	echo "Using CARGO_BUILD_JOBS=$(CARGO_BUILD_JOBS)"; \
	NDK_TARGETS="-t arm64-v8a -t armeabi-v7a"; \
	if command -v rustup >/dev/null 2>&1 && rustup target list --installed 2>/dev/null | grep -qx "x86_64-linux-android"; then \
		NDK_TARGETS="$$NDK_TARGETS -t x86_64"; \
	else \
		echo "Note: Rust target x86_64-linux-android is not installed; skipping x86_64 plugin binary."; \
		echo "      Install with: rustup target add x86_64-linux-android"; \
	fi; \
	PLUGIN_FEATURE_ARGS="--features gpu"; \
	PLUGIN_SO_NAME="libvolvoxgrid_plugin.so"; \
	if [ "$(strip $(VOLVOXGRID_VARIANT))" = "lite" ]; then \
		echo "Using Android plugin variant: lite (--no-default-features --features demo)"; \
		PLUGIN_FEATURE_ARGS="--no-default-features --features demo"; \
		PLUGIN_SO_NAME="libvolvoxgrid_plugin_lite.so"; \
	elif [ -n "$(strip $(VOLVOXGRID_VARIANT))" ]; then \
		echo "Note: unknown VOLVOXGRID_VARIANT='$(VOLVOXGRID_VARIANT)', falling back to normal."; \
	fi; \
	rm -rf "$(ANDROID_PLUGIN_OUTPUT_DIR)"; \
	rm -rf "$(ANDROID_APP_PLUGIN_DIR)"; \
	rm -rf "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)"; \
	rm -rf "$(ANDROID_PROJECT_DIR)/example/build"; \
	cd plugin && ANDROID_NDK_HOME="$$NDK_DIR" cargo ndk $$NDK_TARGETS -o "$(ANDROID_PLUGIN_OUTPUT_DIR)" build -j "$(CARGO_BUILD_JOBS)" $$PLUGIN_FEATURE_ARGS; \
	if [ "$$PLUGIN_SO_NAME" != "libvolvoxgrid_plugin.so" ]; then \
		for ABI in arm64-v8a armeabi-v7a x86_64; do \
			SRC_SO="$(ANDROID_PLUGIN_OUTPUT_DIR)/$$ABI/libvolvoxgrid_plugin.so"; \
			DST_SO="$(ANDROID_PLUGIN_OUTPUT_DIR)/$$ABI/$$PLUGIN_SO_NAME"; \
			if [ -f "$$SRC_SO" ]; then \
				mv "$$SRC_SO" "$$DST_SO"; \
			fi; \
		done; \
		fi; \
		mkdir -p "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)"; \
		cp -a "$(ANDROID_PLUGIN_OUTPUT_DIR)/." "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)/"; \
		if [ -n "$$SDK_DIR" ]; then \
			export ANDROID_HOME="$$SDK_DIR"; \
			export ANDROID_SDK_ROOT="$$SDK_DIR"; \
		fi; \
		cd "$(CURRENT_DIR)"; \
		rm -rf "$(ANDROID_PROJECT_DIR)/volvoxgrid-android/.cxx"; \
		echo "Building Android JNI bridge (debug) for Flutter local mode..."; \
		if [ -x "$(ANDROID_GRADLEW)" ]; then \
			"$(ANDROID_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) :volvoxgrid-android:externalNativeBuildDebug >/dev/null; \
		elif [ -x "$(SHARED_GRADLEW)" ]; then \
			"$(SHARED_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) :volvoxgrid-android:externalNativeBuildDebug >/dev/null; \
		elif command -v gradle >/dev/null 2>&1; then \
			gradle -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) :volvoxgrid-android:externalNativeBuildDebug >/dev/null; \
		else \
			echo "Error: no Gradle wrapper found for building libvolvoxgrid_jni.so."; \
			exit 1; \
		fi; \
		JNI_COPIED=0; \
		for ABI in arm64-v8a armeabi-v7a x86_64; do \
			for ROOT in \
				"$(ANDROID_PROJECT_DIR)/volvoxgrid-android/build/intermediates/library_and_local_jars_jni/debug/jni" \
				"$(ANDROID_PROJECT_DIR)/volvoxgrid-android/build/intermediates/merged_native_libs/debug/out/lib" \
				"$(ANDROID_PROJECT_DIR)/volvoxgrid-android/build/intermediates/stripped_native_libs/debug/out/lib"; do \
				SRC_JNI="$$ROOT/$$ABI/libvolvoxgrid_jni.so"; \
				if [ -f "$$SRC_JNI" ]; then \
					mkdir -p "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)/$$ABI"; \
					cp -f "$$SRC_JNI" "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)/$$ABI/libvolvoxgrid_jni.so"; \
					JNI_COPIED=1; \
					break; \
				fi; \
			done; \
		done; \
		if [ "$$JNI_COPIED" -eq 0 ]; then \
			echo "Error: libvolvoxgrid_jni.so not found after Gradle build."; \
			exit 1; \
		fi; \
		echo "Packaging Android debug fat AAR..."; \
		PACKAGE_MODE="full"; \
		PACKAGE_GROUP_ID="$(AAR_GROUP_ID)"; \
		PACKAGE_ARTIFACT_ID="$(AAR_DEBUG_ARTIFACT_ID)"; \
		if [ "$(strip $(VOLVOXGRID_VARIANT))" = "lite" ]; then \
			PACKAGE_MODE="lite"; \
			PACKAGE_GROUP_ID="$(AAR_LITE_GROUP_ID)"; \
			PACKAGE_ARTIFACT_ID="$(AAR_LITE_DEBUG_ARTIFACT_ID)"; \
		fi; \
		ANDROID_HOME="$$SDK_DIR" \
		ANDROID_SDK_ROOT="$$SDK_DIR" \
		ANDROID_NDK_HOME="$$NDK_DIR" \
		VERSION="$(VOLVOXGRID_VERSION)" \
		SYNURANG_VERSION="$${SYNURANG_VERSION:-$(patsubst v%,%,$(SYNURANG_VERSION))}" \
		GROUP_ID="$$PACKAGE_GROUP_ID" \
		ARTIFACT_ID="$$PACKAGE_ARTIFACT_ID" \
		GIT_COMMIT="$(AAR_GIT_COMMIT)" \
		BUILD_DATE="$(AAR_BUILD_DATE)" \
		PLUGIN_BUILD_MODE="$$PACKAGE_MODE" \
		AAR_BUILD_TYPE="debug" \
		ANDROID_ABIS="$(AAR_ANDROID_ABIS)" \
		BUILD_JOBS="$(BUILD_JOBS)" \
		CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" \
		GRADLE_MAX_WORKERS="$(GRADLE_MAX_WORKERS)" \
		bash "$(CURRENT_DIR)/docker/build_android_aar.sh"; \
		if [ "$(VOLVOXGRID_SOURCE_RESOLVED)" = "maven" ] && echo "$(VOLVOXGRID_VERSION)" | grep -q -- '-SNAPSHOT$$'; then \
			if [ "$$PACKAGE_MODE" = "lite" ]; then \
				$(MAKE) publish_local \
					AAR_VERSION="$(VOLVOXGRID_VERSION)" \
					AAR_ARTIFACT_ID="__skip__" \
					AAR_LITE_ARTIFACT_ID="$(AAR_LITE_DEBUG_ARTIFACT_ID)" \
					DESKTOP_VERSION=0; \
			else \
				$(MAKE) publish_local \
					AAR_VERSION="$(VOLVOXGRID_VERSION)" \
					AAR_ARTIFACT_ID="$(AAR_DEBUG_ARTIFACT_ID)" \
					AAR_LITE_ARTIFACT_ID="__skip__" \
					DESKTOP_VERSION=0; \
			fi; \
		fi
	@echo "Android plugin build complete."

android-plugin-release:
	@echo "Building Android VolvoxGrid plugin shared libraries (release)..."
	@set -e; \
	SDK_DIR=""; \
	if [ -n "$$ANDROID_HOME" ]; then \
		SDK_DIR="$$ANDROID_HOME"; \
	elif [ -n "$$ANDROID_SDK_ROOT" ]; then \
		SDK_DIR="$$ANDROID_SDK_ROOT"; \
	elif [ -d "$$HOME/Android/Sdk" ]; then \
		SDK_DIR="$$HOME/Android/Sdk"; \
	fi; \
	NDK_DIR=""; \
	if [ -n "$$ANDROID_NDK_HOME" ]; then \
		NDK_DIR="$$ANDROID_NDK_HOME"; \
	elif [ -n "$$ANDROID_NDK_ROOT" ]; then \
		NDK_DIR="$$ANDROID_NDK_ROOT"; \
	elif [ -n "$$SDK_DIR" ] && [ -d "$$SDK_DIR/ndk" ]; then \
		NDK_DIR=$$(ls -1d "$$SDK_DIR"/ndk/* 2>/dev/null | sort -V | tail -n 1); \
	fi; \
	if [ -z "$$NDK_DIR" ]; then \
		echo "Error: Android NDK not found."; \
		echo "Set ANDROID_NDK_HOME or install NDK under $$HOME/Android/Sdk/ndk."; \
		exit 1; \
	fi; \
	echo "Using Android NDK: $$NDK_DIR"; \
	command -v cargo >/dev/null 2>&1 || { echo "Error: cargo not found in PATH."; exit 1; }; \
	cargo ndk --version >/dev/null 2>&1 || { echo "Error: cargo-ndk not found. Install with: cargo install cargo-ndk"; exit 1; }; \
	echo "Using CARGO_BUILD_JOBS=$(CARGO_BUILD_JOBS)"; \
	NDK_TARGETS="-t arm64-v8a -t armeabi-v7a"; \
	if command -v rustup >/dev/null 2>&1 && rustup target list --installed 2>/dev/null | grep -qx "x86_64-linux-android"; then \
		NDK_TARGETS="$$NDK_TARGETS -t x86_64"; \
	else \
		echo "Note: Rust target x86_64-linux-android is not installed; skipping x86_64 plugin binary."; \
		echo "      Install with: rustup target add x86_64-linux-android"; \
	fi; \
	PLUGIN_FEATURE_ARGS="--features gpu"; \
	PLUGIN_SO_NAME="libvolvoxgrid_plugin.so"; \
	if [ "$(strip $(VOLVOXGRID_VARIANT))" = "lite" ]; then \
		echo "Using Android plugin variant: lite (--no-default-features --features demo)"; \
		PLUGIN_FEATURE_ARGS="--no-default-features --features demo"; \
		PLUGIN_SO_NAME="libvolvoxgrid_plugin_lite.so"; \
	elif [ -n "$(strip $(VOLVOXGRID_VARIANT))" ]; then \
		echo "Note: unknown VOLVOXGRID_VARIANT='$(VOLVOXGRID_VARIANT)', falling back to normal."; \
	fi; \
	rm -rf "$(ANDROID_PLUGIN_OUTPUT_DIR)"; \
	rm -rf "$(ANDROID_APP_PLUGIN_DIR)"; \
	rm -rf "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)"; \
	rm -rf "$(ANDROID_PROJECT_DIR)/example/build"; \
	cd plugin && ANDROID_NDK_HOME="$$NDK_DIR" cargo ndk $$NDK_TARGETS -o "$(ANDROID_PLUGIN_OUTPUT_DIR)" build -j "$(CARGO_BUILD_JOBS)" --release $$PLUGIN_FEATURE_ARGS; \
	if [ "$$PLUGIN_SO_NAME" != "libvolvoxgrid_plugin.so" ]; then \
		for ABI in arm64-v8a armeabi-v7a x86_64; do \
			SRC_SO="$(ANDROID_PLUGIN_OUTPUT_DIR)/$$ABI/libvolvoxgrid_plugin.so"; \
			DST_SO="$(ANDROID_PLUGIN_OUTPUT_DIR)/$$ABI/$$PLUGIN_SO_NAME"; \
			if [ -f "$$SRC_SO" ]; then \
				mv "$$SRC_SO" "$$DST_SO"; \
			fi; \
		done; \
		fi; \
		mkdir -p "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)"; \
		cp -a "$(ANDROID_PLUGIN_OUTPUT_DIR)/." "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)/"; \
		if [ -n "$$SDK_DIR" ]; then \
			export ANDROID_HOME="$$SDK_DIR"; \
			export ANDROID_SDK_ROOT="$$SDK_DIR"; \
		fi; \
		cd "$(CURRENT_DIR)"; \
		rm -rf "$(ANDROID_PROJECT_DIR)/volvoxgrid-android/.cxx"; \
		echo "Building Android JNI bridge (release) for Flutter local mode..."; \
		if [ -x "$(ANDROID_GRADLEW)" ]; then \
			"$(ANDROID_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) :volvoxgrid-android:externalNativeBuildRelease >/dev/null; \
		elif [ -x "$(SHARED_GRADLEW)" ]; then \
			"$(SHARED_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) :volvoxgrid-android:externalNativeBuildRelease >/dev/null; \
		elif command -v gradle >/dev/null 2>&1; then \
			gradle -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) :volvoxgrid-android:externalNativeBuildRelease >/dev/null; \
		else \
			echo "Error: no Gradle wrapper found for building libvolvoxgrid_jni.so."; \
			exit 1; \
		fi; \
		JNI_COPIED=0; \
		for ABI in arm64-v8a armeabi-v7a x86_64; do \
			for ROOT in \
				"$(ANDROID_PROJECT_DIR)/volvoxgrid-android/build/intermediates/library_and_local_jars_jni/release/jni" \
				"$(ANDROID_PROJECT_DIR)/volvoxgrid-android/build/intermediates/merged_native_libs/release/out/lib" \
				"$(ANDROID_PROJECT_DIR)/volvoxgrid-android/build/intermediates/stripped_native_libs/release/out/lib"; do \
				SRC_JNI="$$ROOT/$$ABI/libvolvoxgrid_jni.so"; \
				if [ -f "$$SRC_JNI" ]; then \
					mkdir -p "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)/$$ABI"; \
					cp -f "$$SRC_JNI" "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)/$$ABI/libvolvoxgrid_jni.so"; \
					JNI_COPIED=1; \
					break; \
				fi; \
			done; \
			done; \
			if [ "$$JNI_COPIED" -eq 0 ]; then \
				echo "Error: libvolvoxgrid_jni.so not found after Gradle build."; \
				exit 1; \
			fi; \
				echo "Packaging Android release fat AAR..."; \
				PACKAGE_MODE="full"; \
				PACKAGE_GROUP_ID="$(AAR_GROUP_ID)"; \
				PACKAGE_ARTIFACT_ID="$(AAR_ARTIFACT_ID)"; \
				if [ "$(strip $(VOLVOXGRID_VARIANT))" = "lite" ]; then \
					PACKAGE_MODE="lite"; \
					PACKAGE_GROUP_ID="$(AAR_LITE_GROUP_ID)"; \
					PACKAGE_ARTIFACT_ID="$(AAR_LITE_ARTIFACT_ID)"; \
				fi; \
				ANDROID_HOME="$$SDK_DIR" \
				ANDROID_SDK_ROOT="$$SDK_DIR" \
				ANDROID_NDK_HOME="$$NDK_DIR" \
				VERSION="$(VOLVOXGRID_VERSION)" \
				SYNURANG_VERSION="$${SYNURANG_VERSION:-$(patsubst v%,%,$(SYNURANG_VERSION))}" \
				GROUP_ID="$$PACKAGE_GROUP_ID" \
				ARTIFACT_ID="$$PACKAGE_ARTIFACT_ID" \
				GIT_COMMIT="$(AAR_GIT_COMMIT)" \
				BUILD_DATE="$(AAR_BUILD_DATE)" \
				PLUGIN_BUILD_MODE="$$PACKAGE_MODE" \
				AAR_BUILD_TYPE="release" \
				ANDROID_ABIS="$(AAR_ANDROID_ABIS)" \
				BUILD_JOBS="$(BUILD_JOBS)" \
				CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" \
				GRADLE_MAX_WORKERS="$(GRADLE_MAX_WORKERS)" \
				bash "$(CURRENT_DIR)/docker/build_android_aar.sh"; \
				if [ "$(VOLVOXGRID_SOURCE_RESOLVED)" = "maven" ] && echo "$(VOLVOXGRID_VERSION)" | grep -q -- '-SNAPSHOT$$'; then \
					if [ "$$PACKAGE_MODE" = "lite" ]; then \
						$(MAKE) publish_local \
							AAR_VERSION="$(VOLVOXGRID_VERSION)" \
							AAR_ARTIFACT_ID="__skip__" \
							AAR_LITE_ARTIFACT_ID="$(AAR_LITE_ARTIFACT_ID)" \
							DESKTOP_VERSION=0; \
					else \
						$(MAKE) publish_local \
							AAR_VERSION="$(VOLVOXGRID_VERSION)" \
							AAR_ARTIFACT_ID="$(AAR_ARTIFACT_ID)" \
							AAR_LITE_ARTIFACT_ID="__skip__" \
							DESKTOP_VERSION=0; \
					fi; \
				fi
	@echo "Android release plugin build complete."

android-install: $(ANDROID_INSTALL_PREREQ)
	@echo "Installing Android example app..."
	@echo "Using GRADLE_MAX_WORKERS=$(GRADLE_MAX_WORKERS)"
	@SDK_DIR=""; \
	if [ -n "$$ANDROID_HOME" ]; then \
		SDK_DIR="$$ANDROID_HOME"; \
	elif [ -n "$$ANDROID_SDK_ROOT" ]; then \
		SDK_DIR="$$ANDROID_SDK_ROOT"; \
	elif [ -d "$$HOME/Android/Sdk" ]; then \
		SDK_DIR="$$HOME/Android/Sdk"; \
	fi; \
	if [ -n "$$SDK_DIR" ]; then \
		echo "Using Android SDK: $$SDK_DIR"; \
		export ANDROID_HOME="$$SDK_DIR"; \
		export ANDROID_SDK_ROOT="$$SDK_DIR"; \
	else \
		echo "Warning: ANDROID_HOME/ANDROID_SDK_ROOT not set and $$HOME/Android/Sdk not found."; \
	fi; \
	if [ -x "$(ANDROID_GRADLEW)" ]; then \
		echo "Using project Gradle wrapper: $(ANDROID_GRADLEW)"; \
		"$(ANDROID_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
	elif [ -x "$(SHARED_GRADLEW)" ]; then \
		echo "Using shared Gradle wrapper: $(SHARED_GRADLEW)"; \
		"$(SHARED_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
	elif command -v gradle >/dev/null 2>&1; then \
		echo "Using system Gradle: $$(command -v gradle)"; \
		gradle -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
	else \
		echo "Error: no Gradle wrapper found."; \
		echo "Expected $(ANDROID_GRADLEW) or $(SHARED_GRADLEW), or install gradle."; \
		exit 1; \
	fi
	@echo "Android install complete."

android-install-release: $(ANDROID_INSTALL_RELEASE_PREREQ)
	@echo "Installing Android example app (with release plugin libs)..."
	@echo "Using GRADLE_MAX_WORKERS=$(GRADLE_MAX_WORKERS)"
	@SDK_DIR=""; \
	if [ -n "$$ANDROID_HOME" ]; then \
		SDK_DIR="$$ANDROID_HOME"; \
	elif [ -n "$$ANDROID_SDK_ROOT" ]; then \
		SDK_DIR="$$ANDROID_SDK_ROOT"; \
	elif [ -d "$$HOME/Android/Sdk" ]; then \
		SDK_DIR="$$HOME/Android/Sdk"; \
	fi; \
	if [ -n "$$SDK_DIR" ]; then \
		echo "Using Android SDK: $$SDK_DIR"; \
		export ANDROID_HOME="$$SDK_DIR"; \
		export ANDROID_SDK_ROOT="$$SDK_DIR"; \
	else \
		echo "Warning: ANDROID_HOME/ANDROID_SDK_ROOT not set and $$HOME/Android/Sdk not found."; \
	fi; \
	if [ -x "$(ANDROID_GRADLEW)" ]; then \
		echo "Using project Gradle wrapper: $(ANDROID_GRADLEW)"; \
		"$(ANDROID_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
	elif [ -x "$(SHARED_GRADLEW)" ]; then \
		echo "Using shared Gradle wrapper: $(SHARED_GRADLEW)"; \
		"$(SHARED_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
	elif command -v gradle >/dev/null 2>&1; then \
		echo "Using system Gradle: $$(command -v gradle)"; \
		gradle -p "$(ANDROID_PROJECT_DIR)" $(GRADLE_JOBS_FLAG) $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
	else \
		echo "Error: no Gradle wrapper found."; \
		echo "Expected $(ANDROID_GRADLEW) or $(SHARED_GRADLEW), or install gradle."; \
		exit 1; \
	fi
	@echo "Android install complete."

android-run: android-install
	@command -v adb >/dev/null 2>&1 || { echo "Error: adb not found in PATH."; exit 1; }
	@DEVICE_ID=$$(adb devices | awk 'NR>1 && $$2=="device"{print $$1; exit}'); \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "Error: no connected Android device found."; \
		exit 1; \
	fi; \
	echo "Using Android device: $$DEVICE_ID"; \
	adb -s "$$DEVICE_ID" shell am force-stop "$(ANDROID_EXAMPLE_PACKAGE)" >/dev/null 2>&1 || true; \
	adb -s "$$DEVICE_ID" shell am start \
		-a android.intent.action.MAIN \
		-c android.intent.category.LAUNCHER \
		-n "$(ANDROID_EXAMPLE_PACKAGE)/$(ANDROID_EXAMPLE_ACTIVITY)"; \
	echo "Launched $(ANDROID_EXAMPLE_PACKAGE) on $$DEVICE_ID."; \
	sleep 1; \
	APP_PID=$$(adb -s "$$DEVICE_ID" shell pidof -s "$(ANDROID_EXAMPLE_PACKAGE)"); \
	if [ -n "$$APP_PID" ]; then \
		echo "App PID: $$APP_PID. Starting logcat (Ctrl+C to stop)..."; \
		adb -s "$$DEVICE_ID" logcat --pid="$$APP_PID"; \
	else \
		echo "Warning: could not find PID for $(ANDROID_EXAMPLE_PACKAGE); skipping logcat."; \
	fi

android-run-release: android-install-release
	@command -v adb >/dev/null 2>&1 || { echo "Error: adb not found in PATH."; exit 1; }
	@DEVICE_ID=$$(adb devices | awk 'NR>1 && $$2=="device"{print $$1; exit}'); \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "Error: no connected Android device found."; \
		exit 1; \
	fi; \
	echo "Using Android device: $$DEVICE_ID"; \
	adb -s "$$DEVICE_ID" shell am force-stop "$(ANDROID_EXAMPLE_PACKAGE)" >/dev/null 2>&1 || true; \
	adb -s "$$DEVICE_ID" shell am start \
		-a android.intent.action.MAIN \
		-c android.intent.category.LAUNCHER \
		-n "$(ANDROID_EXAMPLE_PACKAGE)/$(ANDROID_EXAMPLE_ACTIVITY)"; \
	echo "Launched $(ANDROID_EXAMPLE_PACKAGE) on $$DEVICE_ID."; \
	sleep 1; \
	APP_PID=$$(adb -s "$$DEVICE_ID" shell pidof -s "$(ANDROID_EXAMPLE_PACKAGE)"); \
	if [ -n "$$APP_PID" ]; then \
		echo "App PID: $$APP_PID. Starting logcat (Ctrl+C to stop)..."; \
		adb -s "$$DEVICE_ID" logcat --pid="$$APP_PID"; \
	else \
		echo "Warning: could not find PID for $(ANDROID_EXAMPLE_PACKAGE); skipping logcat."; \
	fi

# =============================================================================
# Docker Builds + Maven Publishing
# =============================================================================
docker_android_aar_image:
	@echo "Building Docker image for Android AAR packaging..."
	docker build -t "$(AAR_DOCKER_IMAGE)" -f Dockerfile.android .

docker_android: docker_android_aar_image
	@echo "Packaging Android AAR + Android lite AAR (version $(AAR_VERSION), ABIs $(AAR_ANDROID_ABIS))..."
	@echo "Using BUILD_JOBS=$(BUILD_JOBS) (cargo=$(CARGO_BUILD_JOBS), gradle=$(GRADLE_MAX_WORKERS))"
	@mkdir -p dist/maven
	docker run --rm \
		--entrypoint /bin/bash \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		-v "$(DOCKER_GRADLE_BUILD_CACHE_VOLUME):$(DOCKER_GRADLE_CACHE_DIR)" \
		"$(AAR_DOCKER_IMAGE)" \
		-lc 'chmod -R a+rwx /cache/go-build /cache/gradle || true'
	docker run --rm \
		-u "$$(id -u):$$(id -g)" \
		-v "$(CURRENT_DIR):/workspace/volvoxgrid" \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		-v "$(DOCKER_GRADLE_BUILD_CACHE_VOLUME):$(DOCKER_GRADLE_CACHE_DIR)" \
		-w /workspace/volvoxgrid \
		-e CARGO_TARGET_DIR="$(DOCKER_GO_BUILD_CACHE_DIR)/volvoxgrid-cargo-target" \
		-e BUILD_JOBS="$(BUILD_JOBS)" \
		-e CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" \
		-e GRADLE_MAX_WORKERS="$(GRADLE_MAX_WORKERS)" \
		-e GRADLE_USER_HOME="$(DOCKER_GRADLE_CACHE_DIR)" \
		-e VERSION="$(AAR_VERSION)" \
		-e GROUP_ID="$(AAR_GROUP_ID)" \
		-e ARTIFACT_ID="$(AAR_ARTIFACT_ID)" \
		-e GIT_COMMIT="$(AAR_GIT_COMMIT)" \
		-e BUILD_DATE="$(AAR_BUILD_DATE)" \
		-e ANDROID_ABIS="$(AAR_ANDROID_ABIS)" \
		"$(AAR_DOCKER_IMAGE)"
	docker run --rm \
		-u "$$(id -u):$$(id -g)" \
		-v "$(CURRENT_DIR):/workspace/volvoxgrid" \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		-v "$(DOCKER_GRADLE_BUILD_CACHE_VOLUME):$(DOCKER_GRADLE_CACHE_DIR)" \
		-w /workspace/volvoxgrid \
		-e CARGO_TARGET_DIR="$(DOCKER_GO_BUILD_CACHE_DIR)/volvoxgrid-cargo-target" \
		-e BUILD_JOBS="$(BUILD_JOBS)" \
		-e CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" \
		-e GRADLE_MAX_WORKERS="$(GRADLE_MAX_WORKERS)" \
		-e GRADLE_USER_HOME="$(DOCKER_GRADLE_CACHE_DIR)" \
		-e VERSION="$(AAR_VERSION)" \
		-e GROUP_ID="$(AAR_LITE_GROUP_ID)" \
		-e ARTIFACT_ID="$(AAR_LITE_ARTIFACT_ID)" \
		-e GIT_COMMIT="$(AAR_GIT_COMMIT)" \
		-e BUILD_DATE="$(AAR_BUILD_DATE)" \
		-e ANDROID_ABIS="$(AAR_ANDROID_ABIS)" \
		-e PLUGIN_BUILD_MODE=lite \
		"$(AAR_DOCKER_IMAGE)"
	@echo "Android AAR artifacts (default + lite): dist/maven/"
	@if echo "$(AAR_VERSION)" | grep -q -- '-SNAPSHOT$$'; then \
		$(MAKE) publish_local; \
	else \
		echo "Skip publish_local: AAR_VERSION=$(AAR_VERSION) is not a SNAPSHOT."; \
	fi

docker_desktop_image:
	@echo "Building Docker image for desktop JAR packaging..."
	docker build -t "$(DESKTOP_DOCKER_IMAGE)" -f Dockerfile.desktop .

docker_desktop: docker_desktop_image
	@echo "Packaging desktop JAR (version $(DESKTOP_VERSION))..."
	@echo "Using BUILD_JOBS=$(BUILD_JOBS) (cargo=$(CARGO_BUILD_JOBS), gradle=$(GRADLE_MAX_WORKERS), dotnet=$(DESKTOP_BUILD_DOTNET))"
	@mkdir -p dist/maven
	docker run --rm \
		--entrypoint /bin/bash \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		-v "$(DOCKER_GRADLE_BUILD_CACHE_VOLUME):$(DOCKER_GRADLE_CACHE_DIR)" \
		"$(DESKTOP_DOCKER_IMAGE)" \
		-lc 'chmod -R a+rwx /cache/go-build /cache/gradle || true'
	docker run --rm \
		-u "$$(id -u):$$(id -g)" \
		-v "$(CURRENT_DIR):/workspace/volvoxgrid" \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		-v "$(DOCKER_GRADLE_BUILD_CACHE_VOLUME):$(DOCKER_GRADLE_CACHE_DIR)" \
		-w /workspace/volvoxgrid \
		-e CARGO_TARGET_DIR="$(DOCKER_GO_BUILD_CACHE_DIR)/volvoxgrid-cargo-target" \
		-e BUILD_JOBS="$(BUILD_JOBS)" \
		-e CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" \
		-e GRADLE_MAX_WORKERS="$(GRADLE_MAX_WORKERS)" \
		-e GRADLE_USER_HOME="$(DOCKER_GRADLE_CACHE_DIR)" \
		-e VERSION="$(DESKTOP_VERSION)" \
		-e GROUP_ID="$(DESKTOP_GROUP_ID)" \
		-e ARTIFACT_ID="$(DESKTOP_ARTIFACT_ID)" \
		-e GIT_COMMIT="$(DESKTOP_GIT_COMMIT)" \
		-e BUILD_DATE="$(DESKTOP_BUILD_DATE)" \
		-e BUILD_OCX="$(DESKTOP_BUILD_OCX)" \
		-e BUILD_DOTNET="$(DESKTOP_BUILD_DOTNET)" \
		"$(DESKTOP_DOCKER_IMAGE)"
	@echo "Desktop JAR artifacts: dist/maven/"
	@echo "ActiveX OCX artifacts: dist/desktop/ocx/ (set DESKTOP_BUILD_OCX=0 to skip)"
	@if [ "$(DESKTOP_BUILD_DOTNET)" = "0" ]; then \
		echo ".NET artifacts: skipped (set DESKTOP_BUILD_DOTNET=1 to enable)"; \
	else \
		echo ".NET artifacts: dist/dotnet/winforms_release/ and dist/dotnet/winforms_release_x86/ (set DESKTOP_BUILD_DOTNET=0 to skip)"; \
	fi
	@if echo "$(DESKTOP_VERSION)" | grep -q -- '-SNAPSHOT$$'; then \
		$(MAKE) publish_local; \
	else \
		echo "Skip publish_local: DESKTOP_VERSION=$(DESKTOP_VERSION) is not a SNAPSHOT."; \
	fi

docker_web_image:
	@echo "Building Docker image for web dist/bundle tasks..."
	docker build -t "$(WEB_DOCKER_IMAGE)" -f Dockerfile.web .

docker_web: docker_web_image
	@echo "Running Docker web build target: $(WEB_DOCKER_TARGET)"
	@echo "Using BUILD_JOBS=$(BUILD_JOBS) (cargo=$(CARGO_BUILD_JOBS), version=$(VOLVOXGRID_VERSION), git=$(WEB_GIT_COMMIT), date=$(WEB_BUILD_DATE))"
	docker run --rm \
		--entrypoint /bin/bash \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		"$(WEB_DOCKER_IMAGE)" \
		-lc 'mkdir -p /cache/go-build && chmod -R a+rwx /cache/go-build || true'
	docker run --rm \
		-u "$$(id -u):$$(id -g)" \
		-v "$(CURRENT_DIR):/workspace/volvoxgrid" \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		-w /workspace/volvoxgrid \
		-e CARGO_TARGET_DIR="$(DOCKER_GO_BUILD_CACHE_DIR)/volvoxgrid-cargo-target" \
		-e BUILD_JOBS="$(BUILD_JOBS)" \
		-e CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" \
		-e VOLVOXGRID_VERSION="$(VOLVOXGRID_VERSION)" \
		-e VOLVOXGRID_GIT_COMMIT="$(WEB_GIT_COMMIT)" \
		-e VOLVOXGRID_BUILD_DATE="$(WEB_BUILD_DATE)" \
		-e WEB_SCALE="$(WEB_SCALE)" \
		-e WEB_DOCKER_TARGET="$(WEB_DOCKER_TARGET)" \
		"$(WEB_DOCKER_IMAGE)"

docker_ios_image:
	@echo "Building Docker image for iOS build..."
	docker build -t "$(IOS_DOCKER_IMAGE)" -f Dockerfile.ios .

docker_ios: docker_ios_image
	@echo "Building iOS XCFramework..."
	@echo "Using BUILD_JOBS=$(BUILD_JOBS) (cargo=$(CARGO_BUILD_JOBS))"
	@mkdir -p dist/ios
	docker run --rm \
		--entrypoint /bin/bash \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		-v "$(DOCKER_GRADLE_BUILD_CACHE_VOLUME):$(DOCKER_GRADLE_CACHE_DIR)" \
		"$(IOS_DOCKER_IMAGE)" \
		-lc 'chmod -R a+rwx /cache/go-build /cache/gradle || true'
	docker run --rm \
		-u "$$(id -u):$$(id -g)" \
		-v "$(CURRENT_DIR):/workspace/volvoxgrid" \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		-v "$(DOCKER_GRADLE_BUILD_CACHE_VOLUME):$(DOCKER_GRADLE_CACHE_DIR)" \
		-w /workspace/volvoxgrid \
		-e CARGO_TARGET_DIR="$(DOCKER_GO_BUILD_CACHE_DIR)/volvoxgrid-cargo-target" \
		-e BUILD_JOBS="$(BUILD_JOBS)" \
		-e CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" \
		-e GRADLE_USER_HOME="$(DOCKER_GRADLE_CACHE_DIR)" \
		-e VERSION="$(IOS_VERSION)" \
		-e GIT_COMMIT="$(IOS_GIT_COMMIT)" \
		-e BUILD_DATE="$(IOS_BUILD_DATE)" \
		"$(IOS_DOCKER_IMAGE)"
	@echo "iOS artifacts: dist/ios/"


docker_all_image:
	@echo "Building unified Docker image (all toolchains)..."
	docker build -t "$(ALL_DOCKER_IMAGE)" -f Dockerfile.all .

docker_all: docker_all_image
	@echo "Building all platform artifacts via unified image..."
	@echo "Using BUILD_JOBS=$(BUILD_JOBS) (cargo=$(CARGO_BUILD_JOBS), gradle=$(GRADLE_MAX_WORKERS), dotnet=$(DESKTOP_BUILD_DOTNET), build_date=$(ALL_BUILD_DATE), desktop_ocx=$(ALL_BUILD_OCX))"
	@mkdir -p dist/maven dist/dotnet dist/ios dist/wasm dist/wasm-lite dist/web
	docker run --rm \
		--entrypoint /bin/bash \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		-v "$(DOCKER_GRADLE_BUILD_CACHE_VOLUME):$(DOCKER_GRADLE_CACHE_DIR)" \
		"$(ALL_DOCKER_IMAGE)" \
		-lc 'chmod -R a+rwx /cache/go-build /cache/gradle || true'
	docker run --rm \
		-u "$$(id -u):$$(id -g)" \
		-v "$(CURRENT_DIR):/workspace/volvoxgrid" \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		-v "$(DOCKER_GRADLE_BUILD_CACHE_VOLUME):$(DOCKER_GRADLE_CACHE_DIR)" \
		-w /workspace/volvoxgrid \
		-e CARGO_TARGET_DIR="$(DOCKER_GO_BUILD_CACHE_DIR)/volvoxgrid-cargo-target" \
		-e BUILD_JOBS="$(BUILD_JOBS)" \
		-e CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" \
		-e GRADLE_MAX_WORKERS="$(GRADLE_MAX_WORKERS)" \
		-e GRADLE_USER_HOME="$(DOCKER_GRADLE_CACHE_DIR)" \
		-e BUILD_TARGET=all \
		-e VERSION="$(AAR_VERSION)" \
		-e GIT_COMMIT="$(ALL_GIT_COMMIT)" \
		-e BUILD_DATE="$(ALL_BUILD_DATE)" \
		-e WEB_BUNDLE_VERSION="$(VOLVOXGRID_VERSION)" \
		-e BUILD_OCX="$(ALL_BUILD_OCX)" \
		-e BUILD_DOTNET="$(DESKTOP_BUILD_DOTNET)" \
		-e BUILD_ANDROID_INCLUDE_LITE=1 \
		-e GROUP_ID="$(AAR_GROUP_ID)" \
		-e ARTIFACT_ID="$(AAR_ARTIFACT_ID)" \
		-e AAR_LITE_GROUP_ID="$(AAR_LITE_GROUP_ID)" \
		-e AAR_LITE_ARTIFACT_ID="$(AAR_LITE_ARTIFACT_ID)" \
		-e DESKTOP_GROUP_ID="$(DESKTOP_GROUP_ID)" \
		-e DESKTOP_ARTIFACT_ID="$(DESKTOP_ARTIFACT_ID)" \
		-e DESKTOP_VERSION="$(DESKTOP_VERSION)" \
		-e DESKTOP_GIT_COMMIT="$(DESKTOP_GIT_COMMIT)" \
		-e DESKTOP_BUILD_DATE="$(DESKTOP_BUILD_DATE)" \
		-e ANDROID_ABIS="$(AAR_ANDROID_ABIS)" \
		"$(ALL_DOCKER_IMAGE)"
	@echo "All platform artifacts built."
	@if [ "$(DESKTOP_BUILD_DOTNET)" = "0" ]; then \
		echo ".NET artifacts: skipped (set DESKTOP_BUILD_DOTNET=1 to enable)"; \
	else \
		echo ".NET artifacts: dist/dotnet/winforms_release/ and dist/dotnet/winforms_release_x86/"; \
	fi
	@if echo "$(AAR_VERSION)" | grep -q -- '-SNAPSHOT$$' || echo "$(DESKTOP_VERSION)" | grep -q -- '-SNAPSHOT$$'; then \
		$(MAKE) publish_local; \
	else \
		echo "Skip publish_local: AAR_VERSION=$(AAR_VERSION), DESKTOP_VERSION=$(DESKTOP_VERSION) are not SNAPSHOT."; \
	fi

publish_maven:
	@if [ ! -f "$(MAVEN_SETTINGS)" ]; then \
		echo "Error: Maven settings not found: $(MAVEN_SETTINGS)"; \
		echo "Create .maven-settings.xml with your Sonatype Central credentials:"; \
		echo "  <settings><servers><server>"; \
		echo "    <username>YOUR_TOKEN</username>"; \
		echo "    <password>YOUR_PASSWORD</password>"; \
		echo "  </server></servers></settings>"; \
		exit 1; \
	fi
	@MAVEN_USER=$$(sed -n 's|.*<username>\(.*\)</username>.*|\1|p' "$(MAVEN_SETTINGS)" | head -1); \
	MAVEN_PASS=$$(sed -n 's|.*<password>\(.*\)</password>.*|\1|p' "$(MAVEN_SETTINGS)" | head -1); \
	DIST="$(CURRENT_DIR)/dist/maven"; \
	VERIFY_SCRIPT="$(CURRENT_DIR)/scripts/verify_embedded_version.sh"; \
	if [ ! -f "$$VERIFY_SCRIPT" ]; then \
		echo "Error: version verification script not found: $$VERIFY_SCRIPT"; \
		exit 1; \
	fi; \
	upload_bundle() { \
		local ARTIFACT="$$1" VERSION="$$2" EXT="$$3" GROUP="$$4"; \
		local FILE="$$DIST/$$ARTIFACT-$$VERSION.$$EXT"; \
		local POM="$$DIST/$$ARTIFACT-$$VERSION.pom"; \
		local GROUP_PATH=$$(echo "$$GROUP" | tr '.' '/'); \
		local TOP_DIR=$$(echo "$$GROUP" | cut -d. -f1); \
		if [ ! -f "$$FILE" ] || [ ! -f "$$POM" ]; then \
			echo "Error: $$ARTIFACT-$$VERSION not found in $$DIST"; \
			echo "Run 'make docker_android docker_desktop' first."; \
			exit 1; \
		fi; \
		echo "Verifying embedded version for $$ARTIFACT-$$VERSION..."; \
		bash "$$VERIFY_SCRIPT" "$$VERSION" "$$FILE" || exit 1; \
		echo "Creating bundle for $$ARTIFACT-$$VERSION..."; \
		BUNDLE_DIR=$$(mktemp -d); \
		BUNDLE_ZIP="/tmp/volvoxgrid-bundle-$$$$.zip"; \
		rm -f "$$BUNDLE_ZIP"; \
		TARGET="$$BUNDLE_DIR/$$GROUP_PATH/$$ARTIFACT/$$VERSION"; \
		mkdir -p "$$TARGET"; \
		cp "$$FILE" "$$TARGET/"; \
		cp "$$POM" "$$TARGET/"; \
		for CLASSIFIER in sources javadoc; do \
			CFILE="$$DIST/$$ARTIFACT-$$VERSION-$$CLASSIFIER.jar"; \
			if [ -f "$$CFILE" ]; then cp "$$CFILE" "$$TARGET/"; fi; \
		done; \
		for f in "$$TARGET"/*; do \
			md5sum "$$f" | cut -d' ' -f1 > "$$f.md5"; \
			sha1sum "$$f" | cut -d' ' -f1 > "$$f.sha1"; \
			gpg -ab "$$f"; \
		done; \
		( cd "$$BUNDLE_DIR" && zip -qr "$$BUNDLE_ZIP" "$$TOP_DIR" ) || { echo "zip failed"; rm -rf "$$BUNDLE_DIR"; exit 1; }; \
		rm -rf "$$BUNDLE_DIR"; \
		echo "Uploading $$ARTIFACT-$$VERSION to Maven Central..."; \
		RESPONSE=$$(curl -s -w "\n%{http_code}" \
			-u "$$MAVEN_USER:$$MAVEN_PASS" \
			-X POST "$(MAVEN_REPO_URL)" \
			-F "bundle=@$$BUNDLE_ZIP" \
			-F "name=$$ARTIFACT-$$VERSION" \
			-F "publishingType=AUTOMATIC"); \
		rm -f "$$BUNDLE_ZIP"; \
		HTTP_CODE=$$(echo "$$RESPONSE" | tail -1); \
		BODY=$$(echo "$$RESPONSE" | head -n -1); \
		if [ "$$HTTP_CODE" -ge 200 ] && [ "$$HTTP_CODE" -lt 300 ]; then \
			echo "Upload successful (HTTP $$HTTP_CODE): $$ARTIFACT-$$VERSION"; \
			echo "$$BODY"; \
		else \
			echo "Upload failed (HTTP $$HTTP_CODE): $$ARTIFACT-$$VERSION"; \
			echo "$$BODY"; \
			exit 1; \
		fi; \
	}; \
	upload_bundle "$(AAR_ARTIFACT_ID)" "$(AAR_VERSION)" "aar" "$(AAR_GROUP_ID)"; \
	upload_bundle "$(AAR_LITE_ARTIFACT_ID)" "$(AAR_VERSION)" "aar" "$(AAR_LITE_GROUP_ID)"; \
	upload_bundle "$(DESKTOP_ARTIFACT_ID)" "$(DESKTOP_VERSION)" "jar" "$(DESKTOP_GROUP_ID)"

publish_local:
	@DIST="$(CURRENT_DIR)/dist/maven"; \
	LOCAL_REPO="$(MAVEN_LOCAL_REPO)"; \
	if [ ! -d "$$DIST" ]; then \
		echo "Error: dist/maven not found at $$DIST"; \
		echo "Run 'make docker_android docker_desktop VOLVOXGRID_VERSION=...'" ; \
		exit 1; \
	fi; \
	mkdir -p "$$LOCAL_REPO"; \
	is_snapshot() { \
		case "$$1" in \
			*-SNAPSHOT) return 0 ;; \
			*) return 1 ;; \
		esac; \
	}; \
	install_artifact() { \
		local ARTIFACT="$$1" VERSION="$$2" EXT="$$3" GROUP="$$4"; \
		if ! is_snapshot "$$VERSION"; then \
			echo "Skip: $$GROUP:$$ARTIFACT:$$VERSION is not a SNAPSHOT."; \
			return 2; \
		fi; \
		local FILE="$$DIST/$$ARTIFACT-$$VERSION.$$EXT"; \
		local POM="$$DIST/$$ARTIFACT-$$VERSION.pom"; \
		if [ ! -f "$$FILE" ] || [ ! -f "$$POM" ]; then \
			echo "Skip: missing $$ARTIFACT-$$VERSION.$$EXT or .pom in $$DIST"; \
			return 1; \
		fi; \
		local GROUP_PATH=$$(echo "$$GROUP" | tr '.' '/'); \
		local TARGET_DIR="$$LOCAL_REPO/$$GROUP_PATH/$$ARTIFACT/$$VERSION"; \
		mkdir -p "$$TARGET_DIR"; \
		cp -f "$$FILE" "$$TARGET_DIR/"; \
		cp -f "$$POM" "$$TARGET_DIR/"; \
		for CLASSIFIER in sources javadoc; do \
			local CFILE="$$DIST/$$ARTIFACT-$$VERSION-$$CLASSIFIER.jar"; \
			if [ -f "$$CFILE" ]; then cp -f "$$CFILE" "$$TARGET_DIR/"; fi; \
		done; \
		echo "Installed $$GROUP:$$ARTIFACT:$$VERSION -> $$TARGET_DIR"; \
		return 0; \
	}; \
	SNAPSHOT_REQUESTED=0; \
	INSTALLED=0; \
	if is_snapshot "$(AAR_VERSION)"; then SNAPSHOT_REQUESTED=$$((SNAPSHOT_REQUESTED+1)); fi; \
	if is_snapshot "$(DESKTOP_VERSION)"; then SNAPSHOT_REQUESTED=$$((SNAPSHOT_REQUESTED+1)); fi; \
	if install_artifact "$(AAR_ARTIFACT_ID)" "$(AAR_VERSION)" "aar" "$(AAR_GROUP_ID)"; then INSTALLED=$$((INSTALLED+1)); fi; \
	if install_artifact "$(AAR_LITE_ARTIFACT_ID)" "$(AAR_VERSION)" "aar" "$(AAR_LITE_GROUP_ID)"; then INSTALLED=$$((INSTALLED+1)); fi; \
	if install_artifact "$(DESKTOP_ARTIFACT_ID)" "$(DESKTOP_VERSION)" "jar" "$(DESKTOP_GROUP_ID)"; then INSTALLED=$$((INSTALLED+1)); fi; \
	if [ "$$INSTALLED" -eq 0 ]; then \
		if [ "$$SNAPSHOT_REQUESTED" -eq 0 ]; then \
			echo "Skip: no SNAPSHOT versions requested; nothing installed to mavenLocal."; \
			exit 0; \
		fi; \
		echo "Error: no SNAPSHOT artifacts were installed."; \
		echo "Build at least one SNAPSHOT artifact first (docker_android or docker_desktop)."; \
		exit 1; \
	fi; \
	echo "Installed $$INSTALLED SNAPSHOT artifact bundle(s) into $$LOCAL_REPO"

publish_github:
	@command -v gh >/dev/null 2>&1 || { echo "Error: gh (GitHub CLI) not found in PATH."; exit 1; }
	@TAG="v$(VOLVOXGRID_VERSION)"; \
	VERIFY_SCRIPT="$(CURRENT_DIR)/scripts/verify_embedded_version.sh"; \
	PRERELEASE_FLAG=""; \
	case "$(VOLVOXGRID_VERSION)" in \
		*-SNAPSHOT) PRERELEASE_FLAG="--prerelease" ;; \
	esac; \
	if [ ! -f "$$VERIFY_SCRIPT" ]; then \
		echo "Error: version verification script not found: $$VERIFY_SCRIPT"; \
		exit 1; \
	fi; \
	echo "Creating/updating GitHub release $$TAG..."; \
	gh release view "$$TAG" --repo "$(IOS_GITHUB_REPO)" >/dev/null 2>&1 || \
		gh release create "$$TAG" $$PRERELEASE_FLAG --repo "$(IOS_GITHUB_REPO)" --title "$$TAG" --notes "Release $$TAG"; \
		if [ -d "$(IOS_XCFRAMEWORK_DIR)" ]; then \
			echo "Verifying embedded version for XCFramework (expected $(IOS_VERSION))..."; \
			bash "$$VERIFY_SCRIPT" "$(IOS_VERSION)" "$(IOS_XCFRAMEWORK_DIR)" || exit 1; \
			echo "Zipping XCFramework..."; \
		cd dist/ios && rm -f VolvoxGridPlugin.xcframework.zip && \
			zip -r VolvoxGridPlugin.xcframework.zip VolvoxGridPlugin.xcframework/; \
		cd "$(CURRENT_DIR)"; \
		CHECKSUM=$$(swift package compute-checksum "$(IOS_XCFRAMEWORK_ZIP)" 2>/dev/null || shasum -a 256 "$(IOS_XCFRAMEWORK_ZIP)" | cut -d' ' -f1); \
		echo "Checksum: $$CHECKSUM"; \
		gh release upload "$$TAG" "$(IOS_XCFRAMEWORK_ZIP)" --repo "$(IOS_GITHUB_REPO)" --clobber; \
		echo "Updating Package.swift..."; \
		URL="https://github.com/$(IOS_GITHUB_REPO)/releases/download/$$TAG/VolvoxGridPlugin.xcframework.zip"; \
		printf '// swift-tools-version:5.9\nimport PackageDescription\n\nlet package = Package(\n    name: "VolvoxGrid",\n    products: [\n        .library(name: "VolvoxGrid", targets: ["VolvoxGridPlugin"]),\n    ],\n    targets: [\n        .binaryTarget(\n            name: "VolvoxGridPlugin",\n            url: "%s",\n            checksum: "%s"\n        ),\n    ]\n)\n' "$$URL" "$$CHECKSUM" > Package.swift; \
		echo "XCFramework uploaded, Package.swift updated."; \
	else \
		echo "Skip iOS: $(IOS_XCFRAMEWORK_DIR) not found."; \
	fi; \
	DIST="$(CURRENT_DIR)/dist/maven"; \
	for entry in \
	  "$(AAR_VERSION):$$DIST/$(AAR_ARTIFACT_ID)-$(AAR_VERSION).aar" \
	  "$(AAR_VERSION):$$DIST/$(AAR_LITE_ARTIFACT_ID)-$(AAR_VERSION).aar" \
	  "$(DESKTOP_VERSION):$$DIST/$(DESKTOP_ARTIFACT_ID)-$(DESKTOP_VERSION).jar"; \
	do \
	  expected="$${entry%%:*}"; \
	  f="$${entry#*:}"; \
		  if [ -f "$$f" ]; then \
		    echo "Verifying embedded version for $$(basename "$$f") (expected $$expected)..."; \
		    bash "$$VERIFY_SCRIPT" "$$expected" "$$f" || exit 1; \
		    echo "Uploading $$(basename $$f) to $$TAG..."; \
	    gh release upload "$$TAG" "$$f" --repo "$(IOS_GITHUB_REPO)" --clobber; \
	  fi; \
	done; \
	for f in "$(WEB_BUNDLE_ZIP)" "$(WEB_BUNDLE_LITE_ZIP)"; \
	do \
	  if [ -f "$$f" ]; then \
	    echo "Uploading $$(basename "$$f") to $$TAG..."; \
	    gh release upload "$$TAG" "$$f" --repo "$(IOS_GITHUB_REPO)" --clobber; \
	  else \
	    echo "Skip web bundle: $$f not found."; \
	  fi; \
	done; \
	DOTNET_X64_DIR="$(CURRENT_DIR)/dist/dotnet/winforms_release"; \
	DOTNET_X86_DIR="$(CURRENT_DIR)/dist/dotnet/winforms_release_x86"; \
	if [ ! -d "$$DOTNET_X64_DIR" ]; then DOTNET_X64_DIR="$(CURRENT_DIR)/target/dotnet/winforms_release"; fi; \
	if [ ! -d "$$DOTNET_X86_DIR" ]; then DOTNET_X86_DIR="$(CURRENT_DIR)/target/dotnet/winforms_release_x86"; fi; \
	for entry in \
	  "x64:$$DOTNET_X64_DIR" \
	  "x86:$$DOTNET_X86_DIR"; \
	do \
	  arch="$${entry%%:*}"; \
	  dir="$${entry#*:}"; \
	  if [ -d "$$dir" ]; then \
	    stage_dir=$$(mktemp -d); \
	    top_dir="volvoxgrid-dotnet-winforms-$(VOLVOXGRID_VERSION)-$$arch"; \
	    zip_path="/tmp/$${top_dir}.zip"; \
	    mkdir -p "$$stage_dir/$$top_dir"; \
	    cp -a "$$dir/." "$$stage_dir/$$top_dir/"; \
	    find "$$stage_dir/$$top_dir" -maxdepth 1 -type f -name '*.log' -delete; \
	    (cd "$$stage_dir" && zip -qr "$$zip_path" "$$top_dir") || { rm -rf "$$stage_dir" "$$zip_path"; exit 1; }; \
	    echo "Uploading $$(basename "$$zip_path") to $$TAG..."; \
	    gh release upload "$$TAG" "$$zip_path" --repo "$(IOS_GITHUB_REPO)" --clobber; \
	    rm -rf "$$stage_dir" "$$zip_path"; \
	  else \
	    echo "Skip .NET $$arch bundle: $$dir not found."; \
	  fi; \
	done; \
	OCX_DIR="$(CURRENT_DIR)/dist/desktop/ocx"; \
	if [ ! -d "$$OCX_DIR" ]; then OCX_DIR="$(CURRENT_DIR)/target/ocx"; fi; \
	if [ -d "$$OCX_DIR" ]; then \
	  found_ocx=0; \
	  ocx_stage_dir=$$(mktemp -d); \
	  ocx_top_dir="volvoxgrid-activex-$(VOLVOXGRID_VERSION)"; \
	  ocx_zip="/tmp/$${ocx_top_dir}.zip"; \
	  mkdir -p "$$ocx_stage_dir/$$ocx_top_dir"; \
	  for f in "$$OCX_DIR"/*.ocx; \
	  do \
	    if [ -f "$$f" ]; then \
	      found_ocx=1; \
	      cp -a "$$f" "$$ocx_stage_dir/$$ocx_top_dir/"; \
	    fi; \
	  done; \
	  if [ "$$found_ocx" = "0" ]; then \
	    rm -rf "$$ocx_stage_dir" "$$ocx_zip"; \
	    echo "Skip ActiveX OCX: no .ocx files found in $$OCX_DIR."; \
	  else \
	    (cd "$$ocx_stage_dir" && zip -qr "$$ocx_zip" "$$ocx_top_dir") || { rm -rf "$$ocx_stage_dir" "$$ocx_zip"; exit 1; }; \
	    echo "Uploading $$(basename "$$ocx_zip") to $$TAG..."; \
	    gh release upload "$$TAG" "$$ocx_zip" --repo "$(IOS_GITHUB_REPO)" --clobber; \
	    rm -rf "$$ocx_stage_dir" "$$ocx_zip"; \
	  fi; \
	else \
	  echo "Skip ActiveX OCX: no OCX output directory found."; \
	fi; \
	echo "All artifacts uploaded to $$TAG"

publish_web:
	@command -v firebase >/dev/null 2>&1 || { echo "Error: firebase CLI not found in PATH."; echo "Install with: npm install -g firebase-tools"; exit 1; }
	@if [ ! -d "$(WEB_BUNDLE_DIR)" ]; then \
		echo "Error: $(WEB_BUNDLE_DIR) not found."; \
		echo "Build web artifacts first (for example: make docker_web)."; \
		exit 1; \
	fi
	@echo "Syncing $(WEB_BUNDLE_DIR) -> $(FIREBASE_PUBLIC_DIR) (clean copy, keeping index.html)..."
	@mkdir -p "$(FIREBASE_PUBLIC_DIR)"
	@find "$(FIREBASE_PUBLIC_DIR)" -mindepth 1 -maxdepth 1 ! -name 'index.html' -exec rm -rf {} +
	@cp -a "$(WEB_BUNDLE_DIR)/." "$(FIREBASE_PUBLIC_DIR)/"
	@echo "Running Firebase deploy..."
	firebase deploy

publish_npm:
	@command -v npm >/dev/null 2>&1 || { echo "Error: npm not found in PATH."; exit 1; }
	@ZIP="$(CURRENT_DIR)/dist/web/volvoxgrid-web-$(VOLVOXGRID_VERSION).zip"; \
	if [ ! -f "$$ZIP" ]; then \
		echo "Error: $$ZIP not found."; \
		echo "Build web artifacts first (for example: make docker_web)."; \
		exit 1; \
	fi; \
	STAGE=$$(mktemp -d); \
	trap 'rm -rf "$$STAGE"' EXIT; \
	echo "Extracting $$ZIP..."; \
	unzip -q "$$ZIP" -d "$$STAGE"; \
	JS_DIR="$$STAGE/volvoxgrid-web/js"; \
	WASM_DIR="$$STAGE/volvoxgrid-web/wasm"; \
	if [ ! -d "$$JS_DIR" ] || [ ! -d "$$WASM_DIR" ]; then \
		echo "Error: unexpected zip layout (expected volvoxgrid-web/js and volvoxgrid-web/wasm)."; \
		exit 1; \
	fi; \
	PKG_DIR="$$STAGE/pkg"; \
	mkdir -p "$$PKG_DIR/dist" "$$PKG_DIR/wasm"; \
	cp -a "$$JS_DIR/"*.js "$$JS_DIR/"*.d.ts "$$JS_DIR/"*.map "$$PKG_DIR/dist/" 2>/dev/null || true; \
	if [ -d "$$JS_DIR/generated" ]; then cp -a "$$JS_DIR/generated" "$$PKG_DIR/dist/"; fi; \
	cp -a "$$WASM_DIR/"* "$$PKG_DIR/wasm/"; \
	rm -f "$$PKG_DIR/wasm/package.json"; \
	cp "$(CURRENT_DIR)/web/js/package.json" "$$PKG_DIR/package.json"; \
	echo "Publishing volvoxgrid@$(VOLVOXGRID_VERSION) to npm..."; \
	(cd "$$PKG_DIR" && npm publish --access public); \
	echo ""; \
	LITE_ZIP="$(CURRENT_DIR)/dist/web/volvoxgrid-web-lite-$(VOLVOXGRID_VERSION).zip"; \
	if [ -f "$$LITE_ZIP" ]; then \
		LITE_STAGE=$$(mktemp -d); \
		echo "Extracting $$LITE_ZIP..."; \
		unzip -q "$$LITE_ZIP" -d "$$LITE_STAGE"; \
		LITE_WASM_DIR="$$LITE_STAGE/volvoxgrid-web-lite/wasm"; \
		LITE_PKG_DIR="$$LITE_STAGE/pkg"; \
		mkdir -p "$$LITE_PKG_DIR/wasm"; \
		cp -a "$$LITE_WASM_DIR/"* "$$LITE_PKG_DIR/wasm/"; \
		rm -f "$$LITE_PKG_DIR/wasm/package.json"; \
		cp "$(CURRENT_DIR)/web/js/package-lite.json" "$$LITE_PKG_DIR/package.json"; \
		echo "Publishing volvoxgrid-lite@$(VOLVOXGRID_VERSION) to npm..."; \
		(cd "$$LITE_PKG_DIR" && npm publish --access public); \
		rm -rf "$$LITE_STAGE"; \
	else \
		echo "Skip volvoxgrid-lite: $$LITE_ZIP not found."; \
	fi; \
	echo ""; \
	for adapter_dir in $(CURRENT_DIR)/adapters/aggrid $(CURRENT_DIR)/adapters/sheet; do \
		if [ -d "$$adapter_dir/dist" ] && [ -f "$$adapter_dir/package.json" ]; then \
			name=$$(node -p "require('$$adapter_dir/package.json').name"); \
			echo "Publishing $$name@$(VOLVOXGRID_VERSION) to npm..."; \
			(cd "$$adapter_dir" && npm publish --access public); \
		else \
			echo "Skip $$(basename $$adapter_dir): dist/ not found (run npm run build first)."; \
		fi; \
	done; \
	echo "npm publish complete."

# =============================================================================
# Flutter
# =============================================================================
flutter-setup:
	@command -v flutter >/dev/null 2>&1 || { echo "Error: flutter not found in PATH."; exit 1; }
	@if [ ! -d "$(FLUTTER_EXAMPLE_DIR)/android" ] || [ ! -d "$(FLUTTER_EXAMPLE_DIR)/linux" ]; then \
		echo "Generating Flutter platform folders (android, linux)..."; \
		cd "$(FLUTTER_EXAMPLE_DIR)" && flutter create . --platforms=android,linux; \
	fi
	@cd "$(FLUTTER_EXAMPLE_DIR)" && flutter pub get

flutter: $(FLUTTER_RUN_PREREQ)
	@echo "Building Flutter example..."
	cd "$(FLUTTER_EXAMPLE_DIR)" && flutter build apk --debug
	@echo "Flutter build complete."

flutter-run: $(FLUTTER_RUN_PREREQ)
	@command -v adb >/dev/null 2>&1 || { echo "Error: adb not found in PATH."; exit 1; }
	@DEVICE_ID=$$(adb devices | awk 'NR>1 && $$2=="device"{print $$1; exit}'); \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "Error: no connected Android device found."; \
		exit 1; \
	fi; \
	echo "Using Android device: $$DEVICE_ID"; \
	adb -s "$$DEVICE_ID" shell am force-stop "$(FLUTTER_EXAMPLE_PACKAGE)" >/dev/null 2>&1 || true; \
	cd "$(FLUTTER_EXAMPLE_DIR)" && \
	  VOLVOXGRID_SOURCE=$(VOLVOXGRID_SOURCE_RESOLVED) VOLVOXGRID_VERSION=$(VOLVOXGRID_VERSION) \
	  ORG_GRADLE_PROJECT_volvoxgridSource=$(VOLVOXGRID_SOURCE_RESOLVED) ORG_GRADLE_PROJECT_volvoxgridVersion=$(VOLVOXGRID_VERSION) \
	  flutter run -d "$$DEVICE_ID" \
	    --dart-define=VOLVOXGRID_SOURCE=$(VOLVOXGRID_SOURCE_RESOLVED) \
	    --dart-define=VOLVOXGRID_VERSION=$(VOLVOXGRID_VERSION)

flutter-run-release: $(FLUTTER_RUN_RELEASE_PREREQ)
	@command -v adb >/dev/null 2>&1 || { echo "Error: adb not found in PATH."; exit 1; }
	@DEVICE_ID=$$(adb devices | awk 'NR>1 && $$2=="device"{print $$1; exit}'); \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "Error: no connected Android device found."; \
		exit 1; \
	fi; \
	echo "Using Android device: $$DEVICE_ID"; \
	adb -s "$$DEVICE_ID" shell am force-stop "$(FLUTTER_EXAMPLE_PACKAGE)" >/dev/null 2>&1 || true; \
	cd "$(FLUTTER_EXAMPLE_DIR)" && \
	  VOLVOXGRID_SOURCE=$(VOLVOXGRID_SOURCE_RESOLVED) VOLVOXGRID_VERSION=$(VOLVOXGRID_VERSION) \
	  ORG_GRADLE_PROJECT_volvoxgridSource=$(VOLVOXGRID_SOURCE_RESOLVED) ORG_GRADLE_PROJECT_volvoxgridVersion=$(VOLVOXGRID_VERSION) \
	  flutter run --release -d "$$DEVICE_ID" \
	    --dart-define=VOLVOXGRID_SOURCE=$(VOLVOXGRID_SOURCE_RESOLVED) \
	    --dart-define=VOLVOXGRID_VERSION=$(VOLVOXGRID_VERSION)

flutter-linux: flutter-setup
	@if [ "$(VOLVOXGRID_SOURCE_RESOLVED)" != "maven" ]; then \
		$(MAKE) host-plugin; \
	fi
	cd "$(FLUTTER_EXAMPLE_DIR)" && \
	  if [ "$(VOLVOXGRID_SOURCE_RESOLVED)" = "maven" ]; then \
	    VOLVOXGRID_SOURCE=$(VOLVOXGRID_SOURCE_RESOLVED) VOLVOXGRID_VERSION=$(VOLVOXGRID_VERSION) \
	    flutter run -d linux --dart-define=VG_ENABLE_FLING=true \
	      --dart-define=VOLVOXGRID_SOURCE=$(VOLVOXGRID_SOURCE_RESOLVED) \
	      --dart-define=VOLVOXGRID_VERSION=$(VOLVOXGRID_VERSION); \
	  else \
	    VOLVOXGRID_SOURCE=$(VOLVOXGRID_SOURCE_RESOLVED) VOLVOXGRID_VERSION=$(VOLVOXGRID_VERSION) \
	    LD_LIBRARY_PATH="$(VOLVOXGRID_PLUGIN_DEBUG_DIR):$${LD_LIBRARY_PATH}" \
	    flutter run -d linux --dart-define=VG_ENABLE_FLING=true \
	      --dart-define=VOLVOXGRID_SOURCE=$(VOLVOXGRID_SOURCE_RESOLVED) \
	      --dart-define=VOLVOXGRID_VERSION=$(VOLVOXGRID_VERSION); \
	  fi

# =============================================================================
# GTK4 Visual Test — plugin FFI host path
# =============================================================================
gtk-test: host-plugin
	@echo "Building GTK4 test..."
	cd gtk-test && cargo build $(CARGO_JOBS_FLAG)
	@echo "Launching GTK4 test..."
	VOLVOXGRID_PLUGIN_PATH="$(JAVA_DESKTOP_PLUGIN)" ./target/debug/volvoxgrid-gtk-test

gtk-test-release: host-plugin-release
	@echo "Building GTK4 test (release)..."
	cd gtk-test && cargo build $(CARGO_JOBS_FLAG) --release
	@echo "Launching GTK4 test (release)..."
	VOLVOXGRID_PLUGIN_PATH="$(JAVA_DESKTOP_PLUGIN_RELEASE)" ./target/release/volvoxgrid-gtk-test

gtk-bench: host-plugin-release
	@echo "Building GTK4 benchmark (release)..."
	cd gtk-test && cargo build $(CARGO_JOBS_FLAG) --release --bin headless_bench
	@echo "Running GTK4 benchmark matrix (release, sudo with session env)..."
	sudo env \
		"PATH=$$PATH" \
		"XDG_RUNTIME_DIR=/run/user/$$(id -u)" \
		"DISPLAY=$$DISPLAY" \
		"WAYLAND_DISPLAY=$${WAYLAND_DISPLAY:-}" \
		"XAUTHORITY=$${XAUTHORITY:-$$HOME/.Xauthority}" \
		./scripts/run_headless_bench_matrix.sh --runs "$(GTK_BENCH_RUNS)" --profile release --no-build -- --visual-host --gpu-path surface $(GTK_BENCH_ARGS)

# =============================================================================
# ActiveX OCX — Windows control via MinGW cross-compilation
# =============================================================================
activex:
	@echo "Building ActiveX OCX (debug)..."
	cd $(VSFLEXGRID_DIR)/mingw && BUILD_JOBS="$(BUILD_JOBS)" CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" ./build_ocx.sh

activex-release:
	@echo "Building ActiveX OCX (release)..."
	cd $(VSFLEXGRID_DIR)/mingw && BUILD_JOBS="$(BUILD_JOBS)" CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" ./build_ocx.sh release

activex-lite:
	@echo "Building ActiveX OCX (debug lite)..."
	cd $(VSFLEXGRID_DIR)/mingw && BUILD_JOBS="$(BUILD_JOBS)" CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" ./build_ocx.sh lite

activex-lite-release:
	@echo "Building ActiveX OCX (release lite)..."
	cd $(VSFLEXGRID_DIR)/mingw && BUILD_JOBS="$(BUILD_JOBS)" CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" ./build_ocx.sh release lite

activex-gpu:
	@echo "Building ActiveX OCX (debug gpu)..."
	cd $(VSFLEXGRID_DIR)/mingw && BUILD_JOBS="$(BUILD_JOBS)" CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" ./build_ocx.sh gpu

activex-gpu-release:
	@echo "Building ActiveX OCX (release gpu)..."
	cd $(VSFLEXGRID_DIR)/mingw && BUILD_JOBS="$(BUILD_JOBS)" CARGO_BUILD_JOBS="$(CARGO_BUILD_JOBS)" ./build_ocx.sh release gpu

vsflexgrid: activex

vsflexgrid-release: activex-release

# =============================================================================
# Clean
# =============================================================================
clean:
	@for dir in engine plugin smoke-test gtk-test web/crate $(VSFLEXGRID_DIR)/crate; do \
		echo "Cleaning $$dir..."; \
		( cd "$$dir" && cargo clean ); \
	done
	rm -rf "$(FLUTTER_EXAMPLE_DIR)/build"
clean-all: clean
	rm -rf web/crate/pkg web/example/wasm web/example/node_modules web/js/node_modules
	rm -rf web/example/public/doom
	rm -rf adapters/sheet/node_modules adapters/sheet/dist adapters/sheet/wasm
