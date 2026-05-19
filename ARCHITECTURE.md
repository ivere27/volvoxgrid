# Architecture

## Why this doc exists

You're here because you're changing VolvoxGrid itself — not consuming a package, but touching the engine, the protobuf contract, a wrapper, or the build. This doc gives you the mental model and the daily commands you'll lean on. For product overview and package installation, see [README.md](README.md). For renderer-specific design, see [GUI.md](GUI.md), [TUI.md](TUI.md), and [TEXT_RENDERING.md](TEXT_RENDERING.md).

## The mental model

VolvoxGrid is one Rust engine wrapped in many shells. There are four layers, in order from the inside out.

**The engine** in `engine/` owns retained grid state, layout, selection, edit flow, sorting, scrolling, rendering, and the semantic grid events you can react to. If a behavior should look the same on every platform, it lives here.

**The protocol** in `proto/` is the contract between the engine and everything else. Generated bindings flow into Rust, Dart, Java, C/C++, .NET, and Go consumers. If the shape of a request, response, or render-session message needs to change, start in `proto/` and run `make codegen`.

**The wrappers** in `runtime/` and the web bindings expose the engine outward. `runtime/` is the shared Rust crate behind the native Synurang FFI used by Flutter, Android, Java, .NET, and Go; the web path builds the same engine via `wasm-pack` and layers `web/js/` on top.

**The adapters and hosts** sit at the edge. Platform wrappers (`flutter/`, `android/`, `java/`, `dotnet/`, `go/`) handle windowing, input, packaging, and lifecycle. Compatibility adapters in `adapters/` translate third-party APIs (AG Grid, SfDataGrid, VSFlexGrid, etc.) into VolvoxGrid behavior. At runtime, calls flow:

```
host or adapter  ->  wrapper  ->  runtime or wasm binding  ->  engine
```

The engine doesn't know — or care — which language is driving it. That's what makes adding a new host tractable: generate protobuf bindings, load `libvolvoxgrid`, open a `RenderSession`, present the bytes.

## Repo tour

Here's what each top-level directory is for. Read it once, then refer back when you're deciding where a change goes.

- `engine/` — core retained grid model, layout, rendering, text integration, and event production. This is the source of truth.
- `runtime/` — the shared Rust crate behind the native Synurang FFI and the WASM build targets. Native hosts go through here.
- `proto/` — protobuf service and render-session contract. The single point of truth for the API shape.
- `codegen/` — generated bindings and shared generated outputs. Don't hand-edit; regenerate.
- `web/js/` — browser loader, TypeScript API, default input helpers, the npm package files, and WASM packaging glue.
- `web/example/` — Vite browser demo and release-demo source.
- `flutter/`, `android/`, `java/`, `dotnet/`, `go/` — platform wrappers and their sample apps.
- `adapters/` — compatibility layers: `aggrid`, `bubbletea`, `report`, `sfdatagrid`, `sheet`, `vsflexgrid`, `xtragrid`.
- `gtk-test/`, `smoke-test/` — focused local verification harnesses (workspace members alongside `engine` and `runtime`).
- `docker/` plus `Dockerfile*` at the repo root — reproducible packaging for published artifacts.
- `dist/` — packaged distribution artifacts.
- `public/` — static assets.
- `scripts/` — build and utility scripts.
- `testdata/` — test fixture data.
- `screenshots/`, `legacy/` — visual references and historical material.

The Cargo workspace itself is small: `engine`, `runtime`, `smoke-test`, `gtk-test`, and `adapters/vsflexgrid/crate`. Everything else is built by its own toolchain (Gradle, dotnet, pub, npm, go).

## Where each kind of change goes

When you're about to touch something, find the matching row first:

- Grid behavior, layout, painting, shared event semantics: `engine/`
- Native FFI / session behavior: `runtime/`
- Browser-only loading or JS ergonomics: `web/js/`
- Public API surface: `proto/`, then `make codegen`
- Flutter wrapper behavior: `flutter/`
- Android wrapper behavior: `android/`
- Java desktop or Java TUI behavior: `java/`
- .NET wrapper behavior: `dotnet/`
- Go wrapper or Go TUI behavior: `go/`
- Framework compatibility or migration behavior: `adapters/`

If you find yourself patching the same fix into three wrappers, it almost certainly belongs in the engine.

## Building locally

You don't need every tool for every change. Install what the area you're touching requires.

- Rust stable via `rustup` — engine, runtime, every native build
- `protoc` — proto contract changes via `make codegen`
- Go 1.24+ — `protoc-gen-synurang-ffi` and the Go TUI host (matches `go/go.mod`)
- Node.js and npm — web demos, the web package, adapter packages
- Rust nightly and `wasm-pack` — WASM builds in `runtime/`
- Flutter SDK — anything in `flutter/`
- Android SDK, Android NDK, and `cargo-ndk` — anything in `android/`
- JDK and Gradle — Java desktop and Android packaging
- .NET SDK — `dotnet/` wrappers
- Wine and MinGW-w64 — some Windows-oriented local flows (e.g. ActiveX)

## Daily commands

These are the make targets you'll run most. Each one is wired up in the root `Makefile`.

**The core loop.** Build the engine and native library, smoke-test it, run unit tests. If your change is in `engine/` or `runtime/`, this is usually enough.

```bash
make build      # debug native library
make release    # release native library
make run        # smoke test against the native library
make test       # Rust unit tests
```

**Codegen.** Run this every time you change a `.proto` file. It regenerates bindings for every language.

```bash
make codegen
```

**Targeted host runs.** Pick the one that matches what you're working on.

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

Notice the env-var overrides on the desktop runs — that's how you switch between local builds, Maven Central, and full/lite variants without editing the Makefile.

## Proto and codegen workflow

When you change the public contract, follow these steps in order:

1. Edit the relevant file in `proto/`.
2. Run `make codegen`.
3. Update the engine, the runtime, and every affected wrapper.
4. Rebuild at least one affected host path.
5. Run the relevant smoke or sample flow.

Generated bindings live in `codegen/` and inside per-wrapper directories. Don't hand-edit them — fix the generation pipeline instead.

Next: [proto/volvoxgrid.proto](proto/volvoxgrid.proto) for the schema itself.

## Packaging and publishing

Local developer builds:

```bash
make build      # debug
make release    # release
```

Docker packaging (reproducible, what releases are built from):

```bash
make docker_android
make docker_desktop
make docker_web
make docker_ios
make docker_all
```

`make docker_all` builds the publishable full and lite Maven artifacts for Android, Android Compose, and Java desktop, plus iOS full and lite XCFrameworks. When .NET packaging is enabled it also produces WinForms full and lite x64/x86 output for NuGet staging.

Web packaging is targetable with `WEB_DOCKER_TARGET={all|bundle|web|sheet|sheet-lite|report|wasm|wasm-lite|wasm-threaded}`. The web and sheet release-demo targets externalize package JavaScript through CDN import maps and use the minified browser bundles.

Publishing:

```bash
make publish_maven
make publish_nuget
make publish_npm
```

For local wrapper testing, the internal Docker packaging flows can install generated Maven artifacts (including lite) into `~/.m2/repository`.

## Testing and verification

Pick the smallest loop that proves your change.

- `make test` — Rust unit tests in the workspace
- `make run` — native library smoke test (the fastest end-to-end check)
- `make gtk-test` — native GUI host verification on Linux
- `make java-desktop-run` — desktop wrapper verification
- `make android` or `make flutter-run` — mobile wrapper verification
- `make java-tui-run`, `make dotnet-tui-run`, `make go-tui-run` — terminal host verification

Adapter-specific comparison tests and visual checks live with each adapter under `adapters/`.

Next: [CONTRIBUTING.md](CONTRIBUTING.md) for how to land changes.

## What to read next

- [README.md](README.md) — project positioning and package entry points
- [GUI.md](GUI.md) — if you're changing pixel-rendered GUI behavior
- [TUI.md](TUI.md) — if you're changing terminal rendering or host integration
- [TEXT_RENDERING.md](TEXT_RENDERING.md) — if you're changing full/lite font fallback or text cache behavior
- [BUILD_VARIANTS.md](BUILD_VARIANTS.md) — full vs lite features and artifact types
- [CONTRIBUTING.md](CONTRIBUTING.md) — CLA, PR flow, and code style
