# VolvoxGrid Makefile
# Pixel-rendering grid engine as a Synurang FFI plugin
#
# Usage:
#   make              — build engine + host plugin
#   make run          — build & run smoke test (Rust host loads host plugin, creates grid)
#   make wasm         — build WASM crate
#   make web          — build WASM + start web dev server
#   make codegen      — regenerate FFI bindings for all languages
#   make excel        — build WASM + start Excel adapter dev server
#   make excel-lite   — build WASM lite + start Excel adapter dev server
#   make doom-deps    — download optional DOOM assets for web demo mode
#   make clean        — remove build artifacts

# =============================================================================
# Variables
# =============================================================================
SYNURANG_MODULE ?= github.com/ivere27/synurang
SYNURANG_VERSION ?= v0.5.3
PROTOC_PLUGIN ?= $(shell command -v protoc-gen-synurang-ffi 2>/dev/null)
ifeq ($(strip $(PROTOC_PLUGIN)),)
PROTOC_PLUGIN := $(shell go env GOPATH 2>/dev/null)/bin/protoc-gen-synurang-ffi
endif
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
JAVA_DESKTOP_PROJECT_DIR := java/desktop
UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(UNAME_S),Darwin)
SED_I := sed -i ''
else
SED_I := sed -i
endif
ifeq ($(OS),Windows_NT)
JAVA_DESKTOP_PLUGIN_BASENAME := volvoxgrid_plugin.dll
else ifeq ($(UNAME_S),Darwin)
JAVA_DESKTOP_PLUGIN_BASENAME := libvolvoxgrid_plugin.dylib
else
JAVA_DESKTOP_PLUGIN_BASENAME := libvolvoxgrid_plugin.so
endif
JAVA_DESKTOP_PLUGIN ?= $(abspath target/debug/$(JAVA_DESKTOP_PLUGIN_BASENAME))
JAVA_DESKTOP_PLUGIN_RELEASE ?= $(abspath target/release/$(JAVA_DESKTOP_PLUGIN_BASENAME))
VOLVOXGRID_VERSION ?= 0.1.0
VOLVOXGRID_ANDROID_SOURCE ?= local
VOLVOXGRID_ANDROID_GROUP ?= io.github.ivere27
VOLVOXGRID_ANDROID_ARTIFACT ?= volvoxgrid-android
VOLVOXGRID_JAVA_SOURCE ?= local
VOLVOXGRID_JAVA_GROUP ?= io.github.ivere27
VOLVOXGRID_JAVA_ARTIFACT ?= volvoxgrid-desktop
ANDROID_EXAMPLE_GRADLE_PROPS := \
	-PvolvoxgridAndroidSource=$(VOLVOXGRID_ANDROID_SOURCE) \
	-PvolvoxgridAndroidGroup=$(VOLVOXGRID_ANDROID_GROUP) \
	-PvolvoxgridAndroidArtifact=$(VOLVOXGRID_ANDROID_ARTIFACT) \
	-PvolvoxgridVersion=$(VOLVOXGRID_VERSION)
JAVA_DESKTOP_GRADLE_PROPS := \
	-PvolvoxgridDesktopSource=$(VOLVOXGRID_JAVA_SOURCE) \
	-PvolvoxgridDesktopGroup=$(VOLVOXGRID_JAVA_GROUP) \
	-PvolvoxgridDesktopArtifact=$(VOLVOXGRID_JAVA_ARTIFACT) \
	-PvolvoxgridVersion=$(VOLVOXGRID_VERSION)

# Docker + Maven publishing
# Resolve to the Makefile directory so docker mounts stay correct even when
# invoking `make -f /path/to/Makefile` or running from subdirectories.
CURRENT_DIR := $(patsubst %/,%,$(abspath $(dir $(lastword $(MAKEFILE_LIST)))))
AAR_DOCKER_IMAGE ?= volvoxgrid-android-aar:latest
AAR_VERSION ?= $(VOLVOXGRID_VERSION)
AAR_GROUP_ID ?= io.github.ivere27
AAR_ARTIFACT_ID ?= volvoxgrid-android
AAR_LITE_GROUP_ID ?= $(AAR_GROUP_ID)
AAR_LITE_ARTIFACT_ID ?= volvoxgrid-android-lite
AAR_ANDROID_ABIS ?= arm64-v8a,armeabi-v7a
DOCKER_GO_BUILD_CACHE_VOLUME ?= go-build-cache
DOCKER_GRADLE_BUILD_CACHE_VOLUME ?= gradle-build-cache
DOCKER_GO_BUILD_CACHE_DIR ?= /cache/go-build
DOCKER_GRADLE_CACHE_DIR ?= /cache/gradle
DESKTOP_DOCKER_IMAGE ?= volvoxgrid-desktop-jar:latest
DESKTOP_VERSION ?= $(VOLVOXGRID_VERSION)
DESKTOP_GROUP_ID ?= io.github.ivere27
DESKTOP_ARTIFACT_ID ?= volvoxgrid-desktop
IOS_DOCKER_IMAGE ?= volvoxgrid-ios:latest
ALL_DOCKER_IMAGE ?= volvoxgrid-all:latest
MAVEN_SETTINGS ?= $(CURRENT_DIR)/.maven-settings.xml
MAVEN_REPO_URL ?= https://central.sonatype.com/api/v1/publisher/upload

ifeq ($(VOLVOXGRID_ANDROID_SOURCE),maven)
ANDROID_INSTALL_PREREQ :=
ANDROID_INSTALL_RELEASE_PREREQ :=
else
ANDROID_INSTALL_PREREQ := android-plugin
ANDROID_INSTALL_RELEASE_PREREQ := android-plugin-release
endif

ifeq ($(VOLVOXGRID_JAVA_SOURCE),maven)
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
                build_plugin run run-release test wasm wasm-lite wasm-threaded web web-lite doom-deps \
        codegen \
        android android-build \
        android-plugin android-plugin-release android-install android-install-release android-run android-run-release flutter flutter-setup \
        flutter-run flutter-run-release flutter-linux \
        java-desktop-run java-desktop-run-release java-desktop-run-simple java-desktop-smoke \
        excel excel-lite excel-build \
        report report-build \
        activex activex-release activex-lite activex-lite-release \
        activex-gpu activex-gpu-release \
        vsflexgrid vsflexgrid-release \
        docker_android_aar_image docker_android_aar docker_desktop_jar_image docker_desktop_jar \
        docker_ios_image docker_ios docker_all_image docker_all publish_maven \
        gtk-test clean clean-all help

# =============================================================================
# Default
# =============================================================================
all: build
	@echo "Build complete. Run 'make run' for smoke test, 'make web' for browser demo."

help:
	@echo "VolvoxGrid Makefile targets:"
	@echo ""
	@echo "  build_plugin   Install protoc-gen-synurang-ffi (requires Go)"
	@echo "  build          Build engine + host-plugin (debug)"
	@echo "  release        Build engine + host-plugin (release, optimized)"
	@echo "  host-plugin    Build host (desktop) plugin crate (debug)"
	@echo "  host-plugin-release  Build host (desktop) plugin crate (release)"
	@echo "  java-host-plugin  Build host plugin for Java desktop flows (debug)"
	@echo "  java-host-plugin-release  Build host plugin for Java desktop flows (release)"
	@echo "  run            Build & run smoke test (debug)"
	@echo "  run-release    Build & run smoke test (release)"
	@echo "  test           Run engine unit tests"
	@echo "  wasm           Build WASM crate (requires wasm-pack)"
	@echo "  wasm-lite      Build WASM crate without cosmic-text/gpu (~1MB)"
	@echo "  wasm-threaded  Build WASM crate with threads/atomics (requires COOP+COEP at runtime)"
	@echo "  web            Build WASM + start Vite dev server (Sales/Hierarchy/Stress/DOOM selector)"
	@echo "  web-lite       Build WASM lite + start Vite dev server"
	@echo "  codegen        Regenerate all FFI bindings"
	@echo "  activex        Build ActiveX OCX (debug)"
	@echo "  activex-lite   Build ActiveX OCX without rayon/regex (debug)"
	@echo "  activex-lite-release Build ActiveX OCX without rayon/regex (release, ~1MB)"
	@echo "  activex-gpu-release Build ActiveX OCX with GPU enabled (release, ~3MB)"
	@echo "  android        Build AAR, install example app, and launch on device"
	@echo "  android-build  Build Android AAR only (requires Android SDK)"
	@echo "  android-plugin Build/copy Android plugin .so into example jniLibs"
	@echo "  android-run    Install and launch Android example app on device"
	@echo "  android-run-release  Build release plugin, install debug app, and launch on device"
	@echo "  flutter        Build Flutter example (requires Flutter SDK)"
	@echo "  flutter-run    Run Flutter example on connected Android device"
	@echo "  flutter-run-release  Run Flutter example (release mode) on connected Android device"
	@echo "  flutter-linux  Run Flutter example on Linux desktop"
	@echo "  java-desktop-run    Run Java desktop Android-style example"
	@echo "  java-desktop-run-release  Run Java desktop Android-style example with release plugin"
	@echo "  java-desktop-run-simple  Run Java desktop minimal demo"
	@echo "  java-desktop-smoke  Run headless Java desktop smoke test with local synurang-desktop jars"
	@echo "  excel          Build WASM + start Excel adapter Vite dev server"
	@echo "  excel-lite     Build WASM lite + start Excel adapter Vite dev server"
	@echo "  excel-build    Build Excel adapter npm package only"
	@echo "  doom-deps      Download GPL-2.0 DOOM assets for web mode (not part of Apache-2.0 source)"
	@echo "  gtk-test       Build & launch GTK4 visual test (requires GTK4 dev libs)"
	@echo ""
	@echo "Docker + Maven:"
	@echo "  docker_android_aar_image  Build Docker image for Android AAR"
	@echo "  docker_android_aar        Build Android AAR + Android lite AAR + Maven artifacts via Docker"
	@echo "  docker_desktop_jar_image  Build Docker image for desktop JAR"
	@echo "  docker_desktop_jar        Build desktop JAR + Maven artifacts via Docker"
	@echo "  docker_ios_image          Build Docker image for iOS"
	@echo "  docker_ios                Build iOS XCFramework via Docker"
	@echo "  docker_all_image          Build unified Docker image (all toolchains)"
	@echo "  docker_all                Build all platform artifacts via unified Docker image"
	@echo "  publish_maven             Upload Android AAR + Android lite AAR + desktop JAR to Maven Central"
	@echo ""
	@echo "Example dependency source flags (default is local):"
	@echo "  make android-run VOLVOXGRID_ANDROID_SOURCE=maven VOLVOXGRID_VERSION=0.1.0"
	@echo "  make java-desktop-run VOLVOXGRID_JAVA_SOURCE=maven VOLVOXGRID_VERSION=0.1.0"
	@echo "  (maven mode skips local plugin build for the example targets)"
	@echo "  Optional override: VOLVOXGRID_*_GROUP and VOLVOXGRID_*_ARTIFACT"
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
	cd engine && cargo build --features gpu
	@echo "Engine build complete."

engine-release:
	@echo "Building engine crate (release)..."
	cd engine && cargo build --release --features gpu
	@echo "Engine release build complete."

host-plugin: engine
	@echo "Building plugin crate (debug)..."
	cd plugin && cargo build --features gpu
	@echo "Plugin build complete: target/debug/libvolvoxgrid_plugin.so"

host-plugin-release: engine-release
	@echo "Building plugin crate (release)..."
	cd plugin && cargo build --release --features gpu
	@echo "Plugin release build complete: target/release/libvolvoxgrid_plugin.so"

java-host-plugin: host-plugin

java-host-plugin-release: host-plugin-release

# =============================================================================
# Test
# =============================================================================
test:
	@echo "Running engine tests..."
	cd engine && cargo test --features gpu
	@echo "Tests complete."

# =============================================================================
# Smoke Test — Load plugin via Rust host, exercise basic RPCs
# =============================================================================
run: host-plugin
	@echo "Building smoke test..."
	cd smoke-test && cargo build --features gpu
	@echo "Running smoke test..."
	./target/debug/volvoxgrid-smoke
	@echo ""

run-release: host-plugin-release
	@echo "Building smoke test (release)..."
	cd smoke-test && cargo build --release --features gpu
	@echo "Running smoke test..."
	./target/release/volvoxgrid-smoke target/release/libvolvoxgrid_plugin.so
	@echo ""

java-desktop-run: $(JAVA_DESKTOP_RUN_PREREQ)
	@echo "Running Java desktop Android-style example..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) run $(JAVA_DESKTOP_PLUGIN_ARG) --no-daemon
	@echo ""

java-desktop-run-release: $(JAVA_DESKTOP_RUN_RELEASE_PREREQ)
	@echo "Running Java desktop Android-style example (release plugin)..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) run $(JAVA_DESKTOP_PLUGIN_RELEASE_ARG) --no-daemon
	@echo ""

java-desktop-run-simple: $(JAVA_DESKTOP_RUN_SIMPLE_PREREQ)
	@echo "Running Java desktop minimal demo..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) runSimpleDemo $(JAVA_DESKTOP_PLUGIN_ARG) --no-daemon
	@echo ""

java-desktop-smoke: $(JAVA_DESKTOP_SMOKE_PREREQ)
	@echo "Running Java desktop smoke test..."
	./android/gradlew -p "$(JAVA_DESKTOP_PROJECT_DIR)" $(JAVA_DESKTOP_GRADLE_PROPS) runSmoke $(JAVA_DESKTOP_PLUGIN_ARG) --no-daemon
	@echo ""

# =============================================================================
# WASM
# =============================================================================
wasm:
	@command -v wasm-pack >/dev/null 2>&1 || { echo "Error: wasm-pack not found. Install with: cargo install wasm-pack"; exit 1; }
	@echo "Building WASM crate..."
	cd web/crate && rustup run nightly wasm-pack build . --target web --out-dir ../example/wasm --features gpu
	@echo "WASM build complete: web/example/wasm/"

wasm-lite:
	@command -v wasm-pack >/dev/null 2>&1 || { echo "Error: wasm-pack not found. Install with: cargo install wasm-pack"; exit 1; }
	@echo "Building WASM crate (lite)..."
	cd web/crate && rustup run nightly wasm-pack build . --target web --out-dir ../example/wasm --no-default-features
	@echo "WASM lite build complete: web/example/wasm/"

wasm-threaded:
	@command -v wasm-pack >/dev/null 2>&1 || { echo "Error: wasm-pack not found. Install with: cargo install wasm-pack"; exit 1; }
	@echo "Building WASM crate (threaded)..."
	cd web/crate && RUSTFLAGS='-C target-feature=+atomics,+bulk-memory,+mutable-globals' rustup run nightly wasm-pack build . --target web --out-dir ../example/wasm --features wasm-threads,gpu -Z build-std=std,panic_abort
	@echo "WASM threaded build complete: web/example/wasm/"

# =============================================================================
# Web Dev Server
# =============================================================================
web: wasm
	@if [ ! -f web/example/public/doom/vendor/doom.jsdos ] || [ ! -f web/example/public/doom/emulators/emulators.js ]; then \
		echo "Warning: DOOM mode assets are missing."; \
		echo "         Run 'make doom-deps' to enable DOOM in the web demo."; \
	fi
	@echo "Starting web dev server (host=$(WEB_HOST), scale=$(WEB_SCALE))..."
	cd web/example && npm install && VITE_VG_INITIAL_SCALE="$(WEB_SCALE)" npm run dev -- --host "$(WEB_HOST)"

web-lite: wasm-lite
	@echo "Starting web dev server (lite mode)..."
	cd web/example && npm install && VITE_VG_INITIAL_SCALE="$(WEB_SCALE)" npm run dev -- --host "$(WEB_HOST)"

# =============================================================================
# Excel Adapter — Spreadsheet UX on top of VolvoxGrid WASM
# =============================================================================
EXCEL_DIR := adapters/excel
EXCEL_WASM_DIR := $(EXCEL_DIR)/wasm

excel: wasm
	@echo "Linking WASM output into Excel adapter..."
	@mkdir -p "$(EXCEL_WASM_DIR)"
	@ln -sf "$(abspath web/example/wasm)"/* "$(EXCEL_WASM_DIR)/"
	@echo "Starting Excel adapter dev server (host=$(WEB_HOST))..."
	cd "$(EXCEL_DIR)" && npm install && npx vite --host "$(WEB_HOST)"

excel-lite: wasm-lite
	@echo "Linking WASM lite output into Excel adapter..."
	@mkdir -p "$(EXCEL_WASM_DIR)"
	@ln -sf "$(abspath web/example/wasm)"/* "$(EXCEL_WASM_DIR)/"
	@echo "Starting Excel adapter dev server (lite mode, host=$(WEB_HOST))..."
	cd "$(EXCEL_DIR)" && npm install && npx vite --host "$(WEB_HOST)"

excel-build:
	@echo "Building Excel adapter npm package..."
	cd "$(EXCEL_DIR)" && npm install && npm run build
	@echo "Excel adapter build complete: $(EXCEL_DIR)/dist/"

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
PROTO_INCLUDES := -Iproto -I$(VSFLEXGRID_DIR)/proto
PROTO3_OPT := --experimental_allow_proto3_optional

codegen: build_plugin
	@test -n "$(PROTOC_PLUGIN)" || { echo "Error: protoc-gen-synurang-ffi not found in PATH"; exit 1; }
	@command -v protoc-gen-dart >/dev/null 2>&1 || { echo "Error: protoc-gen-dart not found in PATH."; exit 1; }
	@echo "Generating v1 runtime FFI bindings..."
	@mkdir -p codegen
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
		--synurang-ffi_out=$(VSFLEXGRID_DIR)/include --synurang-ffi_opt=lang=c,mode=activex \
		$(VSFLEXGRID_DIR)/proto/volvoxgrid_activex.proto
	@cp $(VSFLEXGRID_DIR)/include/volvoxgrid_activex_activex.h $(VSFLEXGRID_DIR)/include/volvoxgrid_activex.h
	@echo "Codegen complete: codegen/ + plugin/ + web/ + $(VSFLEXGRID_DIR)/"

# =============================================================================
# Android
# =============================================================================
android: android-build android-run

android-build:
	@echo "Building Android AAR..."
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
		"$(ANDROID_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_GRADLE_TASK)"; \
	elif [ -x "$(SHARED_GRADLEW)" ]; then \
		echo "Using shared Gradle wrapper: $(SHARED_GRADLEW)"; \
		"$(SHARED_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_GRADLE_TASK)"; \
	elif command -v gradle >/dev/null 2>&1; then \
		echo "Using system Gradle: $$(command -v gradle)"; \
		gradle -p "$(ANDROID_PROJECT_DIR)" $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_GRADLE_TASK)"; \
	else \
		echo "Error: no Gradle wrapper found."; \
		echo "Expected $(ANDROID_GRADLEW) or $(SHARED_GRADLEW), or install gradle."; \
		exit 1; \
	fi
	@echo "Android build complete."

android-plugin:
	@echo "Building Android VolvoxGrid plugin shared libraries..."
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
	NDK_TARGETS="-t arm64-v8a -t armeabi-v7a"; \
	if command -v rustup >/dev/null 2>&1 && rustup target list --installed 2>/dev/null | grep -qx "x86_64-linux-android"; then \
		NDK_TARGETS="$$NDK_TARGETS -t x86_64"; \
	else \
		echo "Note: Rust target x86_64-linux-android is not installed; skipping x86_64 plugin binary."; \
		echo "      Install with: rustup target add x86_64-linux-android"; \
	fi; \
	rm -rf "$(ANDROID_APP_PLUGIN_DIR)"; \
	rm -rf "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)"; \
	rm -rf "$(ANDROID_PROJECT_DIR)/example/build"; \
	cd plugin && ANDROID_NDK_HOME="$$NDK_DIR" cargo ndk $$NDK_TARGETS -o "$(ANDROID_PLUGIN_OUTPUT_DIR)" build --features gpu; \
	mkdir -p "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)"; \
	cp -a "$(ANDROID_PLUGIN_OUTPUT_DIR)/." "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)/"
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
	NDK_TARGETS="-t arm64-v8a -t armeabi-v7a"; \
	if command -v rustup >/dev/null 2>&1 && rustup target list --installed 2>/dev/null | grep -qx "x86_64-linux-android"; then \
		NDK_TARGETS="$$NDK_TARGETS -t x86_64"; \
	else \
		echo "Note: Rust target x86_64-linux-android is not installed; skipping x86_64 plugin binary."; \
		echo "      Install with: rustup target add x86_64-linux-android"; \
	fi; \
	rm -rf "$(ANDROID_APP_PLUGIN_DIR)"; \
	rm -rf "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)"; \
	rm -rf "$(ANDROID_PROJECT_DIR)/example/build"; \
	cd plugin && ANDROID_NDK_HOME="$$NDK_DIR" cargo ndk $$NDK_TARGETS -o "$(ANDROID_PLUGIN_OUTPUT_DIR)" build --release --features gpu; \
	mkdir -p "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)"; \
	cp -a "$(ANDROID_PLUGIN_OUTPUT_DIR)/." "$(FLUTTER_ANDROID_PLUGIN_OUTPUT_DIR)/"
	@echo "Android release plugin build complete."

android-install: $(ANDROID_INSTALL_PREREQ)
	@echo "Installing Android example app..."
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
		"$(ANDROID_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
	elif [ -x "$(SHARED_GRADLEW)" ]; then \
		echo "Using shared Gradle wrapper: $(SHARED_GRADLEW)"; \
		"$(SHARED_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
	elif command -v gradle >/dev/null 2>&1; then \
		echo "Using system Gradle: $$(command -v gradle)"; \
		gradle -p "$(ANDROID_PROJECT_DIR)" $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
	else \
		echo "Error: no Gradle wrapper found."; \
		echo "Expected $(ANDROID_GRADLEW) or $(SHARED_GRADLEW), or install gradle."; \
		exit 1; \
	fi
	@echo "Android install complete."

android-install-release: $(ANDROID_INSTALL_RELEASE_PREREQ)
	@echo "Installing Android example app (with release plugin libs)..."
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
		"$(ANDROID_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
	elif [ -x "$(SHARED_GRADLEW)" ]; then \
		echo "Using shared Gradle wrapper: $(SHARED_GRADLEW)"; \
		"$(SHARED_GRADLEW)" -p "$(ANDROID_PROJECT_DIR)" $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
	elif command -v gradle >/dev/null 2>&1; then \
		echo "Using system Gradle: $$(command -v gradle)"; \
		gradle -p "$(ANDROID_PROJECT_DIR)" $(ANDROID_EXAMPLE_GRADLE_PROPS) "$(ANDROID_INSTALL_TASK)"; \
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
	echo "Launched $(ANDROID_EXAMPLE_PACKAGE) on $$DEVICE_ID."

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
	echo "Launched $(ANDROID_EXAMPLE_PACKAGE) on $$DEVICE_ID."

# =============================================================================
# Docker Builds + Maven Publishing
# =============================================================================
docker_android_aar_image:
	@echo "Building Docker image for Android AAR packaging..."
	docker build -t "$(AAR_DOCKER_IMAGE)" -f Dockerfile.android .

docker_android_aar: docker_android_aar_image
	@echo "Packaging Android AAR + Android lite AAR (version $(AAR_VERSION), ABIs $(AAR_ANDROID_ABIS))..."
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
		-e GRADLE_USER_HOME="$(DOCKER_GRADLE_CACHE_DIR)" \
		-e VERSION="$(AAR_VERSION)" \
		-e GROUP_ID="$(AAR_GROUP_ID)" \
		-e ARTIFACT_ID="$(AAR_ARTIFACT_ID)" \
		-e ANDROID_ABIS="$(AAR_ANDROID_ABIS)" \
		"$(AAR_DOCKER_IMAGE)"
	docker run --rm \
		-u "$$(id -u):$$(id -g)" \
		-v "$(CURRENT_DIR):/workspace/volvoxgrid" \
		-v "$(DOCKER_GO_BUILD_CACHE_VOLUME):$(DOCKER_GO_BUILD_CACHE_DIR)" \
		-v "$(DOCKER_GRADLE_BUILD_CACHE_VOLUME):$(DOCKER_GRADLE_CACHE_DIR)" \
		-w /workspace/volvoxgrid \
		-e CARGO_TARGET_DIR="$(DOCKER_GO_BUILD_CACHE_DIR)/volvoxgrid-cargo-target" \
		-e GRADLE_USER_HOME="$(DOCKER_GRADLE_CACHE_DIR)" \
		-e VERSION="$(AAR_VERSION)" \
		-e GROUP_ID="$(AAR_LITE_GROUP_ID)" \
		-e ARTIFACT_ID="$(AAR_LITE_ARTIFACT_ID)" \
		-e ANDROID_ABIS="$(AAR_ANDROID_ABIS)" \
		-e PLUGIN_BUILD_MODE=lite \
		"$(AAR_DOCKER_IMAGE)"
	@echo "Android AAR artifacts (default + lite): dist/maven/"

docker_desktop_jar_image:
	@echo "Building Docker image for desktop JAR packaging..."
	docker build -t "$(DESKTOP_DOCKER_IMAGE)" -f Dockerfile.desktop .

docker_desktop_jar: docker_desktop_jar_image
	@echo "Packaging desktop JAR (version $(DESKTOP_VERSION))..."
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
		-e GRADLE_USER_HOME="$(DOCKER_GRADLE_CACHE_DIR)" \
		-e VERSION="$(DESKTOP_VERSION)" \
		-e GROUP_ID="$(DESKTOP_GROUP_ID)" \
		-e ARTIFACT_ID="$(DESKTOP_ARTIFACT_ID)" \
		"$(DESKTOP_DOCKER_IMAGE)"
	@echo "Desktop JAR artifacts: dist/maven/"

docker_ios_image:
	@echo "Building Docker image for iOS build..."
	docker build -t "$(IOS_DOCKER_IMAGE)" -f Dockerfile.ios .

docker_ios: docker_ios_image
	@echo "Building iOS XCFramework..."
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
		-e GRADLE_USER_HOME="$(DOCKER_GRADLE_CACHE_DIR)" \
		"$(IOS_DOCKER_IMAGE)"
	@echo "iOS artifacts: dist/ios/"


docker_all_image:
	@echo "Building unified Docker image (all toolchains)..."
	docker build -t "$(ALL_DOCKER_IMAGE)" -f Dockerfile.all .

docker_all: docker_all_image
	@echo "Building all platform artifacts via unified image..."
	@mkdir -p dist/maven dist/ios dist/wasm
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
		-e GRADLE_USER_HOME="$(DOCKER_GRADLE_CACHE_DIR)" \
		-e BUILD_TARGET=all \
		-e VERSION="$(AAR_VERSION)" \
		-e GROUP_ID="$(AAR_GROUP_ID)" \
		-e ARTIFACT_ID="$(AAR_ARTIFACT_ID)" \
		-e ANDROID_ABIS="$(AAR_ANDROID_ABIS)" \
		"$(ALL_DOCKER_IMAGE)"
	@echo "All platform artifacts built."

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
	upload_bundle() { \
		local ARTIFACT="$$1" VERSION="$$2" EXT="$$3" GROUP="$$4"; \
		local FILE="$$DIST/$$ARTIFACT-$$VERSION.$$EXT"; \
		local POM="$$DIST/$$ARTIFACT-$$VERSION.pom"; \
		local GROUP_PATH=$$(echo "$$GROUP" | tr '.' '/'); \
		local TOP_DIR=$$(echo "$$GROUP" | cut -d. -f1); \
		if [ ! -f "$$FILE" ] || [ ! -f "$$POM" ]; then \
			echo "Error: $$ARTIFACT-$$VERSION not found in $$DIST"; \
			echo "Run 'make docker_android_aar docker_desktop_jar' first."; \
			exit 1; \
		fi; \
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
		cd "$$BUNDLE_DIR" && zip -qr "$$BUNDLE_ZIP" "$$TOP_DIR" || { echo "zip failed"; exit 1; }; \
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

flutter: flutter-setup android-plugin
	@echo "Building Flutter example..."
	cd "$(FLUTTER_EXAMPLE_DIR)" && flutter build apk --debug
	@echo "Flutter build complete."

flutter-run: flutter-setup android-plugin
	@command -v adb >/dev/null 2>&1 || { echo "Error: adb not found in PATH."; exit 1; }
	@DEVICE_ID=$$(adb devices | awk 'NR>1 && $$2=="device"{print $$1; exit}'); \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "Error: no connected Android device found."; \
		exit 1; \
	fi; \
	echo "Using Android device: $$DEVICE_ID"; \
	adb -s "$$DEVICE_ID" shell am force-stop "$(FLUTTER_EXAMPLE_PACKAGE)" >/dev/null 2>&1 || true; \
	cd "$(FLUTTER_EXAMPLE_DIR)" && \
	  GRADLE_PROPS="android/gradle.properties"; \
	  grep -q 'volvoxgridNativeSource' "$$GRADLE_PROPS" 2>/dev/null && \
	    $(SED_I) 's/volvoxgridNativeSource=.*/volvoxgridNativeSource=local/' "$$GRADLE_PROPS" || \
	    echo 'volvoxgridNativeSource=local' >> "$$GRADLE_PROPS"; \
	  flutter run -d "$$DEVICE_ID"

flutter-run-release: flutter-setup android-plugin-release
	@command -v adb >/dev/null 2>&1 || { echo "Error: adb not found in PATH."; exit 1; }
	@DEVICE_ID=$$(adb devices | awk 'NR>1 && $$2=="device"{print $$1; exit}'); \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "Error: no connected Android device found."; \
		exit 1; \
	fi; \
	echo "Using Android device: $$DEVICE_ID"; \
	adb -s "$$DEVICE_ID" shell am force-stop "$(FLUTTER_EXAMPLE_PACKAGE)" >/dev/null 2>&1 || true; \
	cd "$(FLUTTER_EXAMPLE_DIR)" && \
	  GRADLE_PROPS="android/gradle.properties"; \
	  grep -q 'volvoxgridNativeSource' "$$GRADLE_PROPS" 2>/dev/null && \
	    $(SED_I) 's/volvoxgridNativeSource=.*/volvoxgridNativeSource=local/' "$$GRADLE_PROPS" || \
	    echo 'volvoxgridNativeSource=local' >> "$$GRADLE_PROPS"; \
	  flutter run --release -d "$$DEVICE_ID"

flutter-linux: host-plugin flutter-setup
	cd "$(FLUTTER_EXAMPLE_DIR)" && LD_LIBRARY_PATH="$(VOLVOXGRID_PLUGIN_DEBUG_DIR):$${LD_LIBRARY_PATH}" flutter run -d linux --dart-define=VG_ENABLE_FLING=true

# =============================================================================
# GTK4 Visual Test — Direct engine embedding, no plugin
# =============================================================================
gtk-test: engine
	@echo "Building GTK4 test..."
	cd gtk-test && cargo build --features gpu
	@echo "Launching GTK4 test..."
	./target/debug/volvoxgrid-gtk-test

# =============================================================================
# ActiveX OCX — Windows control via MinGW cross-compilation
# =============================================================================
activex:
	@echo "Building ActiveX OCX (debug)..."
	cd $(VSFLEXGRID_DIR)/mingw && ./build_ocx.sh

activex-release:
	@echo "Building ActiveX OCX (release)..."
	cd $(VSFLEXGRID_DIR)/mingw && ./build_ocx.sh release

activex-lite:
	@echo "Building ActiveX OCX (debug lite)..."
	cd $(VSFLEXGRID_DIR)/mingw && ./build_ocx.sh lite

activex-lite-release:
	@echo "Building ActiveX OCX (release lite)..."
	cd $(VSFLEXGRID_DIR)/mingw && ./build_ocx.sh release lite

activex-gpu:
	@echo "Building ActiveX OCX (debug gpu)..."
	cd $(VSFLEXGRID_DIR)/mingw && ./build_ocx.sh gpu

activex-gpu-release:
	@echo "Building ActiveX OCX (release gpu)..."
	cd $(VSFLEXGRID_DIR)/mingw && ./build_ocx.sh release gpu

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
	rm -rf adapters/excel/node_modules adapters/excel/dist adapters/excel/wasm
