# VolvoxGrid Bubble Tea adapter Makefile

ROOT_DIR := $(abspath ../..)
TARGET_DIR := $(ROOT_DIR)/target/go
GO_BUILD_ENV := GOCACHE=/tmp/volvoxgrid-go-build

UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(OS),Windows_NT)
LIB_BASENAME := volvoxgrid.dll
else ifeq ($(UNAME_S),Darwin)
LIB_BASENAME := libvolvoxgrid.dylib
else
LIB_BASENAME := libvolvoxgrid.so
endif

VOLVOXGRID_LIBRARY ?= $(ROOT_DIR)/target/debug/$(LIB_BASENAME)
VOLVOXGRID_LIBRARY_RELEASE ?= $(ROOT_DIR)/target/release/$(LIB_BASENAME)
TUI_BINARY := $(TARGET_DIR)/volvoxgrid-bubbletea-tui
TUI_BINARY_RELEASE := $(TARGET_DIR)/volvoxgrid-bubbletea-tui-release

.PHONY: help tui-build tui-build-release tui-run tui-run-release tui-smoke tui-smoke-release \
        bubbletea-tui-build bubbletea-tui-build-release bubbletea-tui-run bubbletea-tui-run-release \
        bubbletea-tui-smoke bubbletea-tui-smoke-release

help:
	@echo "Bubble Tea adapter targets:"
	@echo "  tui-build          Build the Bubble Tea typed-row TUI example"
	@echo "  tui-run            Build native debug library and run the typed-row example"
	@echo "  tui-smoke          Run non-interactive smoke check"
	@echo "  tui-build-release  Build release-style example binary"
	@echo "  tui-run-release    Build native release library and run the typed-row example"
	@echo "  tui-smoke-release  Run release-library smoke check"

tui-build:
	@echo "Building Bubble Tea typed-row TUI example..."
	@mkdir -p "$(TARGET_DIR)"
	$(GO_BUILD_ENV) go build -o "$(TUI_BINARY)" ./examples/tui
	@echo ""

tui-build-release:
	@echo "Building Bubble Tea typed-row TUI example (release-style binary)..."
	@mkdir -p "$(TARGET_DIR)"
	$(GO_BUILD_ENV) go build -trimpath -ldflags='-s -w' -o "$(TUI_BINARY_RELEASE)" ./examples/tui
	@echo ""

tui-run: tui-build
	@$(MAKE) -C "$(ROOT_DIR)" host-library
	@echo "Running Bubble Tea typed-row TUI example (debug library)..."
	"$(TUI_BINARY)" "$(VOLVOXGRID_LIBRARY)"
	@echo ""

tui-run-release: tui-build-release
	@$(MAKE) -C "$(ROOT_DIR)" host-library-release
	@echo "Running Bubble Tea typed-row TUI example (release library)..."
	"$(TUI_BINARY_RELEASE)" "$(VOLVOXGRID_LIBRARY_RELEASE)"
	@echo ""

tui-smoke: tui-build
	@$(MAKE) -C "$(ROOT_DIR)" host-library
	@echo "Running Bubble Tea typed-row TUI smoke test (debug library)..."
	VOLVOXGRID_BUBBLETEA_TUI_SMOKE_MODE=1 "$(TUI_BINARY)" "$(VOLVOXGRID_LIBRARY)"
	@echo ""

tui-smoke-release: tui-build-release
	@$(MAKE) -C "$(ROOT_DIR)" host-library-release
	@echo "Running Bubble Tea typed-row TUI smoke test (release library)..."
	VOLVOXGRID_BUBBLETEA_TUI_SMOKE_MODE=1 "$(TUI_BINARY_RELEASE)" "$(VOLVOXGRID_LIBRARY_RELEASE)"
	@echo ""

bubbletea-tui-build: tui-build
bubbletea-tui-build-release: tui-build-release
bubbletea-tui-run: tui-run
bubbletea-tui-run-release: tui-run-release
bubbletea-tui-smoke: tui-smoke
bubbletea-tui-smoke-release: tui-smoke-release
