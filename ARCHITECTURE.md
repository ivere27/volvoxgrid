# Architecture

This document is for developers changing VolvoxGrid itself.

For product overview and package installation, see [README.md](README.md). For renderer-specific design, see [GUI.md](GUI.md), [TUI.md](TUI.md), and [TEXT_RENDERING.md](TEXT_RENDERING.md).

## System Overview

VolvoxGrid is organized around one Rust grid engine with multiple host paths:

- GUI hosts use the shared pixel-rendering engine through the native runtime or WASM bindings
- TUI hosts use the same engine through terminal-oriented render sessions
- full builds use the built-in Rust text engine, while lite builds register host OS/browser text renderers
- platform wrappers stay thin and translate native events, buffers, and lifecycle into the shared contract
- adapters sit above wrappers and map third-party grid APIs into VolvoxGrid behavior

At a high level:

`host or adapter -> wrapper -> runtime or wasm binding -> engine`

The engine owns grid state, layout, selection, edit flow, sorting, scrolling, rendering, and semantic grid events. Hosts own windowing, event loops, surfaces, and packaging.

## Repo Layout

- `engine/`: core retained grid model, layout, rendering, text integration, and event production
- `runtime/`: shared Rust crate for the native Synurang runtime and WASM build targets
- `web/js/`: browser loader, TypeScript API, default input helpers, npm package files, and WASM packaging glue
- `web/example/`: Vite browser demo and release-demo source
- `proto/`: protobuf service and render-session contract
- `codegen/`: generated bindings and shared generated outputs
- `flutter/`, `android/`, `java/`, `dotnet/`, `go/`: platform wrappers and samples
- `adapters/`: compatibility layers such as AG Grid, Sheet, SfDataGrid, VSFlexGrid, and XtraGrid
- `gtk-test/`, `smoke-test/`: focused local verification harnesses
- `docker/`: reproducible packaging for published artifacts
- `dist/`: packaged distribution artifacts
- `public/`: static assets
- `scripts/`: build and utility scripts
- `testdata/`: test fixture data

## Core Layers

### Engine

The Rust engine is the source of truth for:

- retained grid state
- row and column layout
- selection and edit behavior
- render orchestration
- grid event generation

If behavior changes should be shared across platforms, they usually belong here.

### Contract

The protobuf definitions in `proto/` define the public contract between the engine and its wrappers. Generated outputs then flow into Rust, Dart, Java, C/C++, and `.NET` consumers.

If the shape of requests, responses, or render-session messages changes, start in `proto/`.

### Native Runtime

The native runtime is the shared host-facing boundary for non-web integrations. It exposes the protobuf-driven API over Synurang FFI and manages render and event streams for native clients.

### WASM Path

The web path builds the WASM-facing entry points from `runtime/` with `wasm-pack` and layers the `web/js/` TypeScript wrapper on top. The engine logic is still shared, but loading, JS interop, packaging, and browser integration are web-specific.

### Text Rendering

Text is still an engine concern even when a lite package delegates measurement and rasterization to the host.

- Full builds use the built-in Rust text engine.
- Lite builds register a named external text renderer, such as `Android`, `Browser`, `Java2D`, or `GDI`.
- The Rust engine/runtime owns cache capacity, cache eviction, color-independent alpha masks, clipping, and final blending.
- Platform bridges keep only small object or scratch-buffer caches.
- When a render stream switches to another active grid, the previous grid's text cache is cleared.

See [TEXT_RENDERING.md](TEXT_RENDERING.md) for the package matrix and debug-overlay behavior.

### Wrappers And Hosts

Platform wrappers should stay thin. Their job is to:

- create or attach a grid/session
- forward native input and viewport changes
- present the rendered output
- map platform-specific callbacks to the shared contract

If a fix is only about one toolkit's lifecycle, packaging, or event model, it usually belongs in that wrapper rather than the engine.

## Language And Platform Extensibility

The protobuf contract in `proto/` and the [Synurang](https://github.com/ivere27/synurang) FFI transport together make VolvoxGrid language-agnostic and platform-agnostic. In theory, any language that can load a shared library and exchange protobuf messages can become a VolvoxGrid host.

The engine exposes two output modes through the same proto API:

- **GUI (pixel)**: the engine renders to a CPU RGBA buffer or GPU surface. The host provides a window, canvas, buffer, or native surface and presents the result. This path drives Flutter, Android, Java desktop, `.NET` desktop, and ActiveX hosts. The web/WASM host uses the same engine through wasm-bindgen instead of Synurang FFI.
- **TUI (terminal)**: the engine renders to ANSI escape sequences or structured cell buffers. The host writes the output to a terminal. This path drives Java TUI, `.NET` TUI, and Go TUI hosts.

Adding a new native language binding does not require changing the engine. The steps are:

1. Generate protobuf bindings for the target language (`make codegen` or run `protoc` directly).
2. Load `libvolvoxgrid` and call into it via Synurang FFI.
3. Open a `RenderSession` stream for GUI or TUI rendering.
4. Forward host input (pointer, keyboard, terminal bytes) and present the rendered output.

The existing native wrappers (Flutter/Dart, Java/Kotlin, C#, Go) are concrete examples of this pattern. Each is a thin shell over the same proto API — the engine does not know or care which language is driving it.

## Where To Change Things

- Grid behavior, layout, painting, or shared event semantics: `engine/`
- Native FFI/session behavior: `runtime/`
- Browser-only loading or JS ergonomics: `web/js/`
- Shared API surface: `proto/` then `make codegen`
- Flutter wrapper behavior: `flutter/`
- Android wrapper behavior: `android/`
- Java wrapper behavior: `java/`
- `.NET` wrapper behavior: `dotnet/`
- Go wrapper behavior: `go/`
- Framework compatibility or migration behavior: `adapters/`

## Build Prerequisites

You do not need every tool for every change, but the full repo can involve:

- Rust stable via `rustup` (engine, runtime, all native builds)
- `protoc` (proto contract changes via `make codegen`)
- Go 1.22+ for `protoc-gen-synurang-ffi` and the Go TUI host (`go/`)
- Node.js and npm for web demos, the web package, and adapter packages (`web/js/`, `web/example/`, `adapters/`)
- Rust nightly and `wasm-pack` for WASM builds (`runtime/`)
- Flutter SDK for Flutter work (`flutter/`)
- Android SDK, Android NDK, and `cargo-ndk` for Android work (`android/`)
- JDK and Gradle for Java and Android packaging (`java/`, `android/`)
- `.NET` SDK for `.NET` wrappers (`dotnet/`)
- Wine and MinGW-w64 for some Windows-oriented local flows

## Common Development Commands

Core loop:

```bash
make build
make run
make test
```

Codegen:

```bash
make codegen
```

Targeted local loops:

```bash
make web
make web-lite
make sheet
make sheet-lite
make flutter-run
make android
make java-desktop-run
make java-desktop-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VARIANT=lite VOLVOXGRID_VERSION=0.8.9
make dotnet-build
make dotnet-run-release VOLVOXGRID_VARIANT=lite
make gtk-test
make java-tui-run
make dotnet-tui-run
make go-tui-run
```

## Proto And Codegen Workflow

When changing the public contract:

1. Edit the relevant file in `proto/`.
2. Run `make codegen`.
3. Update the engine, runtime, and every affected wrapper.
4. Rebuild at least one affected host path.
5. Run the relevant smoke or sample flow.

Do not hand-edit generated binding outputs unless you are fixing the generation pipeline itself.

## Build And Packaging

Local developer builds:

- `make build`: debug native library build
- `make release`: release native library build

Packaging builds:

- `make docker_android_aar`
- `make docker_desktop`
- `make docker_web`
- `make docker_ios`
- `make docker_all`

`make docker_all` builds the publishable full and lite Maven artifacts for Android, Android Compose, and Java desktop, plus iOS full and lite XCFrameworks. When `.NET` packaging is enabled, it also builds WinForms full and lite x64/x86 output for NuGet staging.

Web packaging is targetable with `WEB_DOCKER_TARGET={all|bundle|web|sheet|sheet-lite|report|wasm|wasm-lite|wasm-threaded}`. The web and sheet release-demo targets externalize package JavaScript through CDN import maps and use the minified browser bundles.

Publishing:

- `make publish_maven`
- `make publish_nuget`
- `make publish_npm`

Internal Maven local flow:

- Internal Docker packaging flows can install generated Maven artifacts, including lite artifacts, into `~/.m2/repository` for local wrapper testing.

## Testing And Verification

Use the smallest loop that proves the change:

- `make test`: Rust unit tests
- `make run`: native library smoke test
- `make gtk-test`: native GUI host verification on Linux
- `make java-desktop-run`: desktop wrapper verification
- `make android` or `make flutter-run`: mobile wrapper verification
- `make java-tui-run`, `make dotnet-tui-run`, `make go-tui-run`: terminal host verification

Adapter-specific comparison tests and visual checks live with the adapter projects under `adapters/`.

## Recommended Reading Order

- [README.md](README.md) for project positioning and package entry points
- [GUI.md](GUI.md) if you are changing pixel-rendered GUI behavior
- [TUI.md](TUI.md) if you are changing terminal rendering or host integration
- [TEXT_RENDERING.md](TEXT_RENDERING.md) if you are changing full/lite font fallback or text cache behavior
- this document for repo structure, build workflow, and development entry points
