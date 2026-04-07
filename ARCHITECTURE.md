# Architecture

This document is for developers changing VolvoxGrid itself.

For product overview and package installation, see [README.md](README.md). For renderer-specific design, see [GUI.md](GUI.md) and [TUI.md](TUI.md).

## System Overview

VolvoxGrid is organized around one Rust grid engine with multiple host paths:

- GUI hosts use the shared pixel-rendering engine through the native plugin or WASM bindings
- TUI hosts use the same engine through terminal-oriented render sessions
- platform wrappers stay thin and translate native events, buffers, and lifecycle into the shared contract
- adapters sit above wrappers and map third-party grid APIs into VolvoxGrid behavior

At a high level:

`host or adapter -> wrapper -> plugin or wasm binding -> engine`

The engine owns grid state, layout, selection, edit flow, sorting, scrolling, rendering, and semantic grid events. Hosts own windowing, event loops, surfaces, and packaging.

## Repo Layout

- `engine/`: core retained grid model, layout, rendering, text integration, and event production
- `plugin/`: Synurang native plugin used by desktop, Android, Flutter, `.NET`, and other native hosts
- `web/crate/`: WASM-facing Rust crate
- `web/js/`: browser loader, TypeScript API, default input helpers, and WASM packaging glue
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

### Native Plugin

The native plugin is the shared host-facing boundary for non-web integrations. It exposes the protobuf-driven API over Synurang FFI and manages render and event streams for native clients.

### WASM Path

The web path uses the Rust WASM crate plus the TypeScript wrapper instead of the native plugin. The engine logic is still shared, but loading, JS interop, and browser integration are web-specific.

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

- **GUI (pixel)**: the engine renders to a CPU RGBA buffer or GPU surface. The host provides a window or canvas and blits the result. This path drives Flutter, Android, Java desktop, `.NET` desktop, and ActiveX hosts. The web/WASM host uses the same engine through wasm-bindgen instead of Synurang FFI.
- **TUI (terminal)**: the engine renders to ANSI escape sequences or structured cell buffers. The host writes the output to a terminal. This path drives Java TUI, `.NET` TUI, and Go TUI hosts.

Adding a new native language binding does not require changing the engine. The steps are:

1. Generate protobuf bindings for the target language (`make codegen` or run `protoc` directly).
2. Load `libvolvoxgrid_plugin` and call into it via Synurang FFI.
3. Open a `RenderSession` stream for GUI or TUI rendering.
4. Forward host input (pointer, keyboard, terminal bytes) and present the rendered output.

The existing native wrappers (Flutter/Dart, Java/Kotlin, C#, Go) are concrete examples of this pattern. Each is a thin shell over the same proto API — the engine does not know or care which language is driving it.

## Where To Change Things

- Grid behavior, layout, painting, or shared event semantics: `engine/`
- Native FFI/session behavior: `plugin/`
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

- Rust stable via `rustup` (engine, plugin, all native builds)
- `protoc` (proto contract changes via `make codegen`)
- Go 1.22+ for `protoc-gen-synurang-ffi` and the Go TUI host (`go/`)
- Node.js and npm for web and adapter packages (`web/`, `adapters/`)
- Rust nightly and `wasm-pack` for WASM builds (`web/crate/`)
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
make flutter-run
make android
make java-desktop-run
make dotnet-build
make gtk-test
make java-tui-run
make dotnet-tui-run
make go-tui-run
```

## Proto And Codegen Workflow

When changing the public contract:

1. Edit the relevant file in `proto/`.
2. Run `make codegen`.
3. Update the engine, plugin, and every affected wrapper.
4. Rebuild at least one affected host path.
5. Run the relevant smoke or sample flow.

Do not hand-edit generated binding outputs unless you are fixing the generation pipeline itself.

## Build And Packaging

Local developer builds:

- `make build`: debug plugin build
- `make release`: release plugin build

Packaging builds:

- `make docker_android_aar`
- `make docker_desktop`
- `make docker_ios`
- `make docker_all`

Publishing:

- `make publish_maven`

Snapshot note:

- `-SNAPSHOT` Docker packaging flows automatically install generated Maven artifacts into `~/.m2/repository`

## Testing And Verification

Use the smallest loop that proves the change:

- `make test`: Rust unit tests
- `make run`: plugin smoke test
- `make gtk-test`: native GUI host verification on Linux
- `make java-desktop-run`: desktop wrapper verification
- `make android` or `make flutter-run`: mobile wrapper verification
- `make java-tui-run`, `make dotnet-tui-run`, `make go-tui-run`: terminal host verification

Adapter-specific comparison tests and visual checks live with the adapter projects under `adapters/`.

## Recommended Reading Order

- [README.md](README.md) for project positioning and package entry points
- [GUI.md](GUI.md) if you are changing pixel-rendered GUI behavior
- [TUI.md](TUI.md) if you are changing terminal rendering or host integration
- this document for repo structure, build workflow, and development entry points
