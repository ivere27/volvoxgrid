# VolvoxGrid

A pixel-rendering datagrid engine written in Rust with cross-platform support via [Synurang](https://github.com/ivere27/synurang) FFI.

VolvoxGrid renders grids directly to RGBA pixel buffers, giving you full control over appearance and behavior across every platform. The core engine handles layout, selection, editing, sorting, scrolling, merged cells, and more, then outputs pixel frames that platform shells display natively.

## Features

- **Pixel-perfect rendering** -- CPU (tiny-skia) and GPU (wgpu/WebGPU) backends
- **Cross-platform** -- Flutter, Web (WASM), Android, Java Desktop, ActiveX (Windows), GTK4 (Linux)
- **Protobuf API** -- All FFI communication uses Protocol Buffers for type-safe, language-agnostic bindings
- **Rich grid functionality**:
  - Cell editing with validation and cancelable events
  - Multi-mode selection (free, row, column, listbox)
  - Multi-column sorting (generic, numeric, string, case-insensitive, custom)
  - Merged cells with configurable span modes (free, row, column, adjacent, spill, group)
  - Fixed, frozen, sticky, and pinned rows/columns
  - Column drag-and-drop reordering
  - Outline/tree node grouping with collapse/expand
  - Subtotals and aggregates (sum, count, average, min, max, std dev, variance)
  - Clipboard copy/cut/paste
  - Cell search with regex
  - Pinch-to-zoom and momentum scrolling (fling)
  - Per-cell style overrides (font, color, background, borders, alignment, text effects)
  - Owner-draw cells via event callbacks
  - Print to paginated PNG images (portrait/landscape, headers/footers)
  - Save/load in multiple formats (binary FXGD, TSV, CSV, custom-delimited, Excel SpreadsheetML)
- **Adapter ecosystem** -- Feasibility-focused compatibility layers to test VolvoxGrid against battle-tested, mature grid frameworks and identify gaps:
  - AG Grid (Web/WASM)
  - Syncfusion SfDataGrid (Flutter)
  - Excel/Sheets spreadsheet UI (Web/WASM)
  - VSFlexGrid ActiveX (Windows COM/OCX)
- **Codegen** -- Auto-generated FFI bindings for Rust, Dart, Java, C/C++ from `.proto` definitions
- **Docker builds** -- Reproducible packaging for Android AAR, Desktop JAR, iOS XCFramework, and WASM

## Project Structure

```
volvoxgrid/
├── engine/           # Core grid engine (Rust) -- rendering, layout, data model
├── plugin/           # Synurang FFI plugin (cdylib) -- host/desktop runtime
├── flutter/          # Flutter plugin (Dart) -- VolvoxGridWidget + controller
├── web/
│   ├── crate/        # WebAssembly Rust crate (wasm-pack)
│   ├── js/           # TypeScript library (npm: volvoxgrid) -- WASM loader, proto utils, input handling
│   └── example/      # Vite dev server with demo pages
├── android/          # Android AAR build + example app (Gradle)
├── java/
│   ├── common/       # Shared Java controller + proto bindings
│   └── desktop/      # Java Desktop host (Swing panel) + demos
├── dotnet/           # .NET WinForms wrapper library + sample
├── adapters/
│   ├── aggrid/       # AG Grid-compatible adapter (TypeScript, npm: @volvoxgrid/ag-grid)
│   ├── excel/        # Excel/Sheets spreadsheet UI (TypeScript, npm: @volvoxgrid/excel)
│   ├── sfdatagrid/   # Syncfusion SfDataGrid adapter (Dart/Flutter)
│   └── vsflexgrid/   # ActiveX/COM OCX control (Rust + C, MinGW cross-compiled)
├── proto/            # Protobuf service definitions
├── codegen/          # Generated FFI bindings (Dart, Java, C++, Rust)
├── gtk-test/         # GTK4 visual test harness (Linux)
├── smoke-test/       # CLI smoke test (Rust host loads plugin)
├── docker/           # Docker build scripts
├── legacy/           # Adapter feasibility docs and planning
└── scripts/          # Utility scripts
```

## Quick Start

### Prerequisites

- **Rust** (stable, via [rustup](https://rustup.rs/))
- **Protobuf Compiler** (`protoc`) -- for codegen and proto builds
- **Go** -- for installing the `protoc-gen-synurang-ffi` codegen plugin

Platform-specific:

| Platform | Additional Requirements |
|---|---|
| Flutter | Flutter SDK |
| Android | Android SDK + NDK, `cargo-ndk` |
| Web | `wasm-pack`, Node.js/npm, Rust nightly |
| Java Desktop | JDK 8+, Gradle |
| .NET WinForms | .NET SDK, Wine (for Linux execution), MinGW-w64 (for Windows shim build) |
| GTK4 | GTK4 development libraries |
| ActiveX | MinGW-w64 cross-compiler |

### Build & Run

```bash
# Build engine + host plugin (debug)
make build

# Build engine + host plugin (release)
make release

# Run smoke test
make run

# Run unit tests
make test
```

### Web (WASM)

```bash
# Install Rust nightly toolchain (required for WASM builds)
rustup install nightly
rustup target add wasm32-unknown-unknown --toolchain nightly

# Build WASM + start Vite dev server
make web

# Build WASM with threads/atomics (requires COOP+COEP headers)
make wasm-threaded
```

### Flutter

```bash
# Run on connected Android device
make flutter-run

# Run on Linux desktop
make flutter-linux

```

```dart
import 'package:volvoxgrid/volvoxgrid.dart';

final controller = VolvoxGridController();
await controller.create(rows: 100, cols: 5);
await controller.setTextMatrix(0, 0, 'Name');
await controller.setTextMatrix(0, 1, 'Value');

VolvoxGridWidget(controller: controller);
```

### Android

```bash
# Build native plugin + install example app on device
make android

# Build release plugin + install
make android-run-release

# Use published Maven AAR in the example app (default is local project module)
make android-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VERSION=0.1.2
```

### Java Desktop

```bash
# Run Swing example
make java-desktop-run

# Run minimal demo
make java-desktop-run-simple

# Use published Maven JAR in the desktop example (default is local)
make java-desktop-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VERSION=0.1.2
```

### .NET WinForms

```bash
# Build .NET wrapper + sample + staged Windows plugin artifacts
make dotnet-build

# Run the sample under Wine
make dotnet-run
```

Direct scripts:

```bash
./dotnet/build_dotnet.sh
./dotnet/run_sample.sh
```

### GTK4

```bash
make gtk-test
```

## Adapters

VolvoxGrid provides API-compatible adapters for popular grid frameworks. Each adapter translates the host framework's API surface (column definitions, data binding, events, styles) into VolvoxGrid protobuf calls, so existing application code migrates with minimal changes while rendering moves to the VolvoxGrid engine.

All adapter code is written from scratch. No source code, binaries, or proprietary assets from the original frameworks are used. Adapters replicate the public API signatures and observable behavior for migration convenience, not the internal implementation.

### AG Grid (Web/WASM)

An AG Grid-compatible adapter (`@volvoxgrid/ag-grid`) that maps AG Grid column definitions, row data, events, and themes to VolvoxGrid. Supports column sorting, row selection, cell styling, column resizing, and theme mapping (alpine, balham, material).

```typescript
import { AgGridVolvox } from '@volvoxgrid/ag-grid';

const grid = new AgGridVolvox(container, {
  columnDefs: [
    { field: 'name', headerName: 'Name', sortable: true },
    { field: 'value', headerName: 'Value', type: 'numericColumn' },
  ],
  rowData: data,
  rowSelection: 'multiple',
});
```

### Excel/Sheets (Web/WASM)

A full spreadsheet UI (`@volvoxgrid/excel`) built on VolvoxGrid with formula bar, toolbar, sheet tabs, status bar, context menu, and find/replace. Supports cell editing, formatting (bold, italic, colors, borders, alignment), undo/redo, clipboard, merge/unmerge, freeze panes, insert/delete rows and columns, drag-fill, and A1-style cell references.

```typescript
import { VolvoxExcel } from '@volvoxgrid/excel';

const excel = new VolvoxExcel(container, {
  rows: 100,
  cols: 26,
  showFormulaBar: true,
  showToolbar: true,
  showSheetTabs: true,
});
```

```bash
# Build WASM + start Excel adapter dev server
make excel

# Build the npm package only
make excel-build
```

### SfDataGrid (Flutter)

A Syncfusion DataGrid-compatible adapter (`volvoxgrid_sfdatagrid`) for Flutter. Maps `DataGridSource`, `GridColumn`, selection modes, sorting, frozen areas, gridlines, and styling to VolvoxGrid.

```dart
import 'package:volvoxgrid_sfdatagrid/volvoxgrid_sfdatagrid.dart';

SfDataGridVolvox(
  source: employeeDataSource,
  columns: [
    GridColumn(columnName: 'id', label: Text('ID')),
    GridColumn(columnName: 'name', label: Text('Name')),
  ],
  selectionMode: SelectionMode.single,
  frozenColumnsCount: 1,
);
```

### VSFlexGrid ActiveX (Windows)

A COM/ActiveX OCX control (`VolvoxGrid.ocx`) for feasibility testing against
battle-tested, mature VSFlexGrid deployments. It exposes a
VSFlexGrid-compatible `IDispatch` interface for legacy VB6, VBA, and COM
applications so teams can identify current VolvoxGrid gaps and prioritize
improvements. Cross-compiled from Linux using MinGW-w64 with 200+ FFI
functions covering rows, columns, cells, colors, selection, sorting,
subtotals, and merged cells.

```bash
# Build ActiveX OCX (debug)
make activex

# Build ActiveX OCX (release)
make activex-release
```

### Comparison Testing

Each adapter includes automated comparison testing that renders identical scenarios in both the original framework and VolvoxGrid, captures screenshots, and generates HTML diff reports.

## Codegen

Regenerate FFI bindings for all languages from the proto definitions:

```bash
make codegen
```

This produces bindings in `codegen/`, `dotnet/src/net8/Generated/`, `plugin/src/`, `web/crate/src/`, and `adapters/vsflexgrid/`.

## Docker Builds

Build platform artifacts in reproducible Docker containers:

```bash
# Android AAR + Android lite AAR
make docker_android_aar

# Desktop JAR (Linux/macOS/Windows native libs)
make docker_desktop

# iOS XCFramework
make docker_ios

# All platforms at once
make docker_all
```

`make docker_desktop` also builds ActiveX OCX binaries (`release` and `release-lite`)
and writes them to `dist/desktop/ocx/`.
Output names are `VolvoxGrid_<arch>.ocx` and `VolvoxGrid_<arch>.lite.ocx`.
Use `make docker_desktop DESKTOP_BUILD_OCX=0` to skip OCX build.

`make docker_android_aar` and `make docker_desktop` automatically run
`make publish_local` only for `*-SNAPSHOT` versions, installing generated
snapshot artifacts into `~/.m2/repository`.

### Publishing to Maven Central

```bash
# Build Maven bundles first
make docker_android_aar docker_desktop

# Publish: android, android-lite, desktop
make publish_maven
```

Requires `.maven-settings.xml` with Sonatype Central credentials and GPG signing keys.

### Installing to Maven Local (Snapshots)

```bash
# Build snapshot artifacts
# (automatically installs to mavenLocal: ~/.m2/repository)
make docker_android_aar docker_desktop VOLVOXGRID_VERSION=0.1.2-SNAPSHOT
```

### Optional Features and Binary Size

VolvoxGrid's core engine is highly modular. You can disable heavy dependencies using Rust features to minimize the binary size for resource-constrained environments (like ActiveX controls or Lite WASM builds).

| Feature | Description | Approx. Size Impact |
|---|---|---|
| `gpu` | GPU rendering backend (wgpu/WebGPU). *Implies cosmic-text.* | **+1.2 MB** |
| `cosmic-text` | Built-in text shaping/layout engine (CPU path). | **+1.0 MB** |
| `rayon` | Parallel processing for sorting and demo generation. | **+0.8 MB** |
| `regex` | Regular expression support for cell searching. | **+0.1 MB** |
| **Base Engine** | Core layout, selection, and rendering logic. | **~0.9 MB** |

**Typical Build Sizes (Release):**

- **GPU Build**: **~3.1 MB** (Includes GPU, Cosmic-Text, Rayon, Regex)
- **Standard Build**: **~1.9 MB** (Includes Rayon/Regex, excludes GPU/Cosmic-Text)
- **Lite Build**: **~950 KB** (Base engine only; no GPU, Cosmic-Text, Rayon, or Regex)

*Note: Sizes measured using the x86_64 ActiveX (`.ocx`) target with `panic = "abort"` and `opt-level = "z"`. WASM sizes may vary slightly.*

## Architecture

### System Overview

Platform shells communicate with the Rust engine through two integration paths: native
platforms use the Synurang FFI plugin protocol with protobuf-encoded messages, while the
web platform uses wasm-bindgen to call the engine directly in-process.

Adapters sit on top of platform shells, translating third-party grid framework APIs
into VolvoxGrid protobuf calls.

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │                          Adapters                                   │
 │                                                                     │
 │  AG Grid         Excel/Sheets          SfDataGrid      VSFlexGrid   │
 │  (TypeScript)    (TypeScript)          (Dart)          (C/COM)      │
 └──┬───────────────┬─────────────────────┬───────────────┬────────────┘
    │               │                     │               │
    ▼               ▼                     ▼               ▼
 ┌─────────────────────────────────────────────────────────────────────┐
 │                        Platform Shells                              │
 │                                                                     │
 │  Flutter     Android     Java Desktop    ActiveX     GTK4     Web   │
 │  (Dart)    (Java/Kotlin)   (Swing)      (COM/C++)   (Rust)   (TS)  │
 └──┬──────────┬───────────┬──────────────┬──────────┬──────────┬──────┘
    │          │           │              │          │          │
    │ protobuf │ protobuf  │  protobuf    │ protobuf │ direct   │ wasm-
    │ FFI      │ JNI       │  JNI         │ C ABI    │ Rust     │ bindgen
    │          │           │              │          │          │
 ┌──▼──────────▼───────────▼──────────────▼──┐    ┌──▼──┐  ┌───▼──────┐
 │       Synurang FFI Plugin (cdylib)        │    │     │  │  WASM    │
 │              plugin/                      │    │     │  │ Bindings │
 └──────────────────┬────────────────────────┘    │     │  │web/crate/│
                    │                             │     │  └────┬─────┘
                    └──────────────┬───────────────┘     │       │
                                  │                     │       │
                    ┌─────────────▼─────────────────────▼───────▼──┐
                    │            Core Engine  (Rust)                │
                    │                                               │
                    │  GridManager ──► VolvoxGrid ──► Renderer      │
                    │                                               │
                    └───────────────────────────────────────────────┘
```

### Rendering Pipeline

The engine uses a `Canvas` trait to abstract over CPU and GPU backends. Both paths share
the same `render_grid()` orchestration function, ensuring pixel-identical output
regardless of backend.

```
 ┌──────────────────────┐
 │     VolvoxGrid       │
 │  (state + cell data) │
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │     LayoutCache      │
 │ (row/col positions)  │
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │    render_grid()     │         Canvas trait
 │     canvas.rs        │     (fill_rect, draw_text,
 │                      │      hline, vline, blit, …)
 └──────┬─────────┬─────┘
        │         │
   CPU path    GPU path
        │         │
        ▼         ▼
 ┌────────────┐  ┌─────────────────┐
 │ CpuCanvas  │  │   GpuCanvas     │
 │canvas_cpu  │  │  canvas_gpu.rs  │
 └─────┬──────┘  └──┬──────────┬───┘
       │             │          │
       ▼             ▼          ▼
 ┌──────────┐  ┌──────────┐ ┌──────────────┐
 │ tiny-skia │  │GlyphAtlas│ │ GpuRenderer  │
 │ software  │  │  glyph_  │ │ gpu_render.rs│
 │ rasterize │  │ atlas.rs │ └──────┬───────┘
 └─────┬─────┘  └──────────┘        │
       │                             ▼
       ▼                     ┌──────────────┐
 ┌───────────────┐           │     wgpu     │
 │  RGBA Pixel   │           │   WebGPU /   │
 │    Buffer     │           │Vulkan / Metal│
 │(shared memory)│           └──────────────┘
 └───────────────┘
```

### Render Session Data Flow

Platform shells drive rendering through a bidirectional stream. The shell sends input
events and buffer handles; the engine renders into the shared buffer and signals frame
completion.

```
  Platform Shell                FFI Plugin              Engine / Renderer
  ──────────────                ──────────              ─────────────────
       │                            │                          │
       │  RenderInput(Viewport)     │                          │
       │ ─────────────────────────► │  resize viewport         │
       │                            │ ────────────────────────►│
       │                            │                          │
       │  RenderInput(BufferReady)  │                          │
       │ ─────────────────────────► │  render_grid(grid, buf)  │
       │                            │ ────────────────────────►│
       │                            │           dirty rect     │
       │   RenderOutput(FrameDone)  │ ◄────────────────────────│
       │ ◄───────────────────────── │                          │
       │                            │                          │
       │  RenderInput(Pointer)      │                          │
       │ ─────────────────────────► │  handle_pointer_down()   │
       │                            │ ────────────────────────►│
       │                            │   events (selection …)   │
       │  RenderOutput(Selection)   │ ◄────────────────────────│
       │ ◄───────────────────────── │                          │
       │                            │                          │
       │  RenderInput(Scroll)       │                          │
       │ ─────────────────────────► │  apply_scroll_delta()    │
       │                            │ ────────────────────────►│
       │  RenderInput(BufferReady)  │                          │
       │ ─────────────────────────► │  render_grid(grid, buf)  │
       │                            │ ────────────────────────►│
       │   RenderOutput(FrameDone)  │ ◄────────────────────────│
       │ ◄───────────────────────── │                          │
       │                            │                          │
       │  RenderInput(Key)          │                          │
       │ ─────────────────────────► │  handle_key()            │
       │                            │ ────────────────────────►│
       │                            │     (may begin edit)     │
       │  RenderOutput(EditRequest) │ ◄────────────────────────│
       │ ◄───────────────────────── │                          │
       ▼                            ▼                          ▼
```

### Engine Internal Structure

The `VolvoxGrid` struct is the central data structure. It owns all state for a single
grid instance and is managed by `GridManager` which handles multi-grid lifecycle.

```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │  GridManager                                                           │
 │  HashMap<id, Arc<Mutex<VolvoxGrid>>>                                   │
 └────────┬────────────────────────────────────────────────────────────────┘
          │
          ▼
 ┌─────────────────────────────────────────────────────────────────────────┐
 │  VolvoxGrid                                                            │
 │                                                                        │
 │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │
 │  │  CellStore   │ │ ColumnProps[]│ │  RowProps{}   │ │GridStyleState│  │
 │  │ (sparse text │ │ (alignment,  │ │ (subtotal,   │ │ (colors,     │  │
 │  │  + values)   │ │  format,     │ │  outline lvl,│ │  fonts,      │  │
 │  │              │ │  data type,  │ │  collapsed,  │ │  grid lines, │  │
 │  │              │ │  sort, combo)│ │  pin)        │ │  appearance) │  │
 │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘  │
 │                                                                        │
 │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │
 │  │CellStyle     │ │SelectionState│ │ ScrollState  │ │  EditState   │  │
 │  │Overrides{}   │ │ (cursor,     │ │ (x/y offset, │ │ (active,     │  │
 │  │ (per-cell    │ │  extent,     │ │  fling       │ │  row/col,    │  │
 │  │  font, color,│ │  mode)       │ │  velocity)   │ │  text)       │  │
 │  │  border)     │ │              │ │              │ │              │  │
 │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘  │
 │                                                                        │
 │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │
 │  │ MergeState   │ │ OutlineState │ │  SortState   │ │  DragState   │  │
 │  │ (mode,       │ │ (tree nodes, │ │ (column,     │ │ (mode,       │  │
 │  │  per-row/col │ │  levels,     │ │  order,      │ │  tracking)   │  │
 │  │  flags)      │ │  bar style)  │ │  explorer)   │ │              │  │
 │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘  │
 │                                                                        │
 │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │
 │  │AnimationState│ │ EventQueue   │ │ LayoutCache  │ │ TextEngine   │  │
 │  │ (smooth      │ │ (pending     │ │ (cumulative  │ │ (cosmic-text │  │
 │  │  transitions)│ │  GridEvents) │ │  row/col px  │ │  shaping)    │  │
 │  │              │ │              │ │  offsets)    │ │              │  │
 │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘  │
 │                                                                        │
 └────────────────────────────────────────────────────────────────────────┘
```

### Codegen Pipeline

Proto definitions are the single source of truth. The `protoc-gen-synurang-ffi` plugin
generates type-safe FFI bindings for each target language and integration mode.

```
                      ┌────────────────────────┐
                      │ proto/volvoxgrid.proto  │
                      └───────────┬────────────┘
                                  │
                                  ▼
                  ┌───────────────────────────────┐
                  │  protoc                        │
                  │  + protoc-gen-synurang-ffi     │
                  └──┬────┬────┬────┬────┬────┬───┘
                     │    │    │    │    │    │
          ┌──────────┘    │    │    │    │    └──────────┐
          │          ┌────┘    │    │    └────┐          │
          ▼          ▼         ▼    ▼         ▼          ▼
 ┌──────────────┐ ┌───────┐ ┌───────┐ ┌──────────┐ ┌─────────┐ ┌───────┐
 │Rust (plugin) │ │ Rust  │ │ Rust  │ │   Dart   │ │  Java   │ │ C/C++ │
 │  plugin/src/ │ │(WASM) │ │(native│ │ codegen/ │ │codegen/ │ │activex│
 │              │ │ web/  │ │activex│ │          │ │         │ │/include│
 │              │ │crate/ │ │/crate/│ │          │ │         │ │       │
 └──────────────┘ └───────┘ └───────┘ └──────────┘ └─────────┘ └───────┘
```

### Build & Distribution

```
 ┌─────────────────────┐     ┌─────────────────────┐
 │   engine/ (Rust)    │     │  web/crate/ (Rust)   │
 └──────────┬──────────┘     └──────────┬───────────┘
            │                           │
            ▼                           ▼
 ┌─────────────────────┐     ┌─────────────────────┐
 │  plugin/ (cdylib)   │     │   wasm-pack build    │
 └──┬────┬────┬────┬───┘     └──────────┬───────────┘
    │    │    │    │                     │
    │    │    │    │                     ▼
    │    │    │    │          ┌─────────────────────┐
    │    │    │    └────────► │    WASM Package     │
    │    │    │              │ web/example/wasm/    │
    │    │    │              └─────────────────────┘
    │    │    │
    │    │    └──────────────────────────────────────┐
    │    │                                           │
    │    ▼                                           ▼
    │ ┌───────────────────────┐   ┌───────────────────────────┐
    │ │   Dockerfile.android  │   │   Dockerfile.desktop      │
    │ │   cargo-ndk cross     │   │   native compile          │
    │ └───────────┬───────────┘   └─────────────┬─────────────┘
    │             ▼                              ▼
    │ ┌───────────────────────┐   ┌───────────────────────────┐
    │ │   Android AAR         │   │   Desktop JAR             │
    │ │ (arm64, armv7, x86_64)│   │ (Linux .so, macOS .dylib, │
    │ └───────────┬───────────┘   │  Windows .dll)            │
    │             │               └─────────────┬─────────────┘
    │             │                              │
    │             └──────────┬──────────────────┘
    │                        ▼
    │             ┌─────────────────────┐
    │             │    Maven Central    │
    │             └─────────────────────┘
    │
    ▼
 ┌───────────────────────┐   ┌───────────────────────┐
 │   Host Plugin (.so)   │   │   Dockerfile.ios      │
 │  libvolvoxgrid_plugin │   └───────────┬───────────┘
 └───────────────────────┘               ▼
                              ┌───────────────────────┐
                              │   iOS XCFramework     │
                              └───────────────────────┘
```

### Text Rendering Architecture

Text rendering in VolvoxGrid has two independent extension points that serve different
purposes. They can be used separately or together depending on the platform.

```
                      ┌──────────────────────────────┐
                      │     render_grid(canvas)       │
                      └──────────────┬───────────────┘
                                     │
                           ┌─────────▼──────────┐
                           │ canvas.draw_text()  │
                           └─────────┬──────────┘
                                     │
                  ┌──────────────────┴──────────────────┐
                  │  Renderer.custom_text_renderer set?  │
                  └──────┬───────────────────────┬──────┘
                    Yes  │                       │  No
                         ▼                       ▼
              ┌────────────────────┐  ┌────────────────────────┐
              │  TextRenderer      │  │     TextEngine          │
              │  (full replacement)│  │    (cosmic-text)        │
              │                    │  │                         │
              │  e.g. GDI32 on    │  │  For each glyph:        │
              │  Windows/ActiveX   │  │  ┌───────────────────┐  │
              │  or Canvas2D on   │  │  │ glyph_id == 0 ?   │  │
              │  WASM Lite         │  │  │ (.notdef / missing)│  │
              │                    │  │  └──┬────────────┬───┘  │
              │  Handles ALL text  │  │  Yes│            │No    │
              │  measure + render  │  │     ▼            ▼      │
              └────────────────────┘  │ ┌──────────┐ ┌───────┐ │
                                      │ │External  │ │Swash  │ │
                                      │ │Glyph     │ │Cache  │ │
                                      │ │Rasterizer│ │(normal│ │
                                      │ │(fallback)│ │ path) │ │
                                      │ └──────────┘ └───────┘ │
                                      └────────────────────────┘
```

#### 1. TextRenderer trait — Full Replacement

`TextRenderer` (`engine/src/text.rs`) replaces the entire text pipeline. When set,
cosmic-text is bypassed completely — the custom renderer handles both measurement
and pixel rendering for all text.

```rust
pub trait TextRenderer {
    fn measure_text(&mut self, text, font_name, font_size, bold, italic, max_width) -> (f32, f32);
    fn render_text(&mut self, buffer, ..., text, font_name, font_size, ..., color) -> f32;
}
```

**Use case 1: Windows ActiveX (GDI32).** The ActiveX control registers a GDI-based
`TextRenderer` via C FFI callbacks at control creation time. GDI has access to all
system fonts so every character renders natively — no fallback needed.

```
  volvoxgrid_ocx.c                    vsflexgrid/crate/src/lib.rs
  ─────────────────                   ────────────────────────────
  gdi_measure_text() ◄──── C FFI ──── FfiTextRenderer.measure_text()
  gdi_render_text()  ◄──── C FFI ──── FfiTextRenderer.render_text()
        │
        ├─ CreateFontW()          Per-grid registration:
        ├─ GetTextExtentPoint32W()   volvox_grid_set_text_renderer(
        ├─ DrawTextW()                   grid_id, measure_fn, render_fn, user_data)
        └─ GetDIBits() → alpha blit
```

**Use case 2: WASM Lite (Browser Canvas2D) & Android Lite.** When VolvoxGrid is compiled without the `cosmic-text` feature (to minimize binary size):
- On Web, the JavaScript wrapper registers a Canvas2D-based `TextRenderer` (`web/js/src/canvas2d-text-renderer.ts`). It uses the browser's `CanvasRenderingContext2D.measureText()` and `fillText()` APIs to handle text measurement and pixel rendering, extracting the alpha channel and blitting it into the engine's shared pixel buffer.
- On Android (`volvoxgrid-android-lite`), the Kotlin wrapper registers an Android Canvas-based `TextRenderer` (`android/volvoxgrid-android/src/main/java/io/github/ivere27/volvoxgrid/AndroidCanvasTextRenderer.kt`) via JNI. It leverages `StaticLayout` for accurate multi-line measurement and Android `Canvas`/`Bitmap` for alpha mask rasterization. To avoid JNI crossing overhead, it maintains an LRU mask cache on the C-side bridge.

Registration: `Renderer.set_custom_text_renderer(Some(box))` or
`volvox_grid_set_text_renderer()` via FFI.

#### 2. ExternalGlyphRasterizer trait — Per-Glyph Fallback

`ExternalGlyphRasterizer` (`engine/src/glyph_rasterizer.rs`) is a per-character
fallback that works alongside cosmic-text. The engine still handles text shaping
and layout — only individual missing glyphs are delegated to the external rasterizer.

```rust
pub trait ExternalGlyphRasterizer: Send {
    fn rasterize_glyph(&mut self, character: char, font_name: &str,
                        font_size: f32, bold: bool, italic: bool) -> Option<GlyphBitmap>;
}

pub struct GlyphBitmap {
    pub width: u32, pub height: u32,
    pub offset_x: i32, pub offset_y: i32,  // bearing offsets
    pub alpha_data: Vec<u8>,                // R8 alpha, row-major
}
```

A glyph is considered "missing" when `glyph_id == 0` (the `.notdef` glyph),
meaning no loaded font has the character. The engine tries the external rasterizer
before falling back to the tofu square from SwashCache.

**Use case: WASM with CJK text.** On WASM, only explicitly loaded fonts are
available. If DejaVuSans is loaded but has no CJK glyphs, the Canvas2D rasterizer
renders CJK characters using the browser's font stack:

```
  TextEngine (CPU)                    GlyphAtlas (GPU)
  ────────────────                    ────────────────
  per-glyph loop:                    rasterize_glyph_or_fallback():
    glyph_id == 0?                     glyph_id == 0?
    ├─ Yes → external_rasterizer       ├─ Yes → external_rasterizer
    │        .rasterize_glyph(ch)      │        .rasterize_glyph(ch)
    │        blit alpha bitmap         │        pack into atlas
    └─ No  → SwashCache (normal)       └─ No  → SwashCache (normal)
```

On WASM, `set_glyph_rasterizer(callback)` registers a JS function as the external
rasterizer for both CPU and GPU renderers. The Canvas2D implementation
(`web/js/src/canvas2d-rasterizer.ts`) renders characters to an offscreen canvas
and extracts the alpha channel:

```javascript
import { createCanvas2DRasterizer } from './canvas2d-rasterizer';
wasm.set_glyph_rasterizer(createCanvas2DRasterizer());
```

#### When to Use Which

| Scenario | Mechanism | Example |
|---|---|---|
| Platform has native text API with full font access | `TextRenderer` (full replacement) | Windows GDI32 via ActiveX |
| WASM Lite build (no cosmic-text) to minimize binary size | `TextRenderer` (full replacement) | Canvas2D via JS |
| WASM with limited loaded fonts, browser has the fonts | `ExternalGlyphRasterizer` (per-glyph fallback) | CJK via Canvas2D |
| Native Linux/macOS with system fonts loaded | Neither needed | cosmic-text handles everything |

Both mechanisms are **complementary, not conflicting**. When a custom `TextRenderer`
is set, it handles all text and `ExternalGlyphRasterizer` is never called. When no
custom renderer is set, `TextEngine` (cosmic-text) handles layout and shaping,
with `ExternalGlyphRasterizer` covering missing glyphs.

### Engine Font System

Text layout and shaping is handled by [cosmic-text](https://github.com/pop-os/cosmic-text).

- The engine keeps a font database inside the renderers (`TextEngine`).
- On native desktop targets, a curated fallback set is loaded automatically at startup.
- On WASM, no OS/system font scan is done by default, so app-provided fonts are important.

Runtime font loading is available through protobuf:

```proto
rpc LoadFontData(LoadFontDataRequest) returns (Empty);

message LoadFontDataRequest {
  bytes data = 1;              // TTF/OTF/TTC bytes
  string font_name = 2;        // primary family name used by caller
  repeated string font_names = 3; // optional aliases/fallback names
}
```

Notes:

- `LoadFontData` is global (not tied to a grid id).
- The plugin stores loaded font bytes and replays them into both CPU and GPU renderers.
- Font selection in styles uses `font_name`/`font_names` fields (for example `StyleConfig.font_name`, `IconTextStyle.font_name`, `IconTextStyle.font_names`).
- For icon fonts (Material Icons, etc.), load the font bytes first, then set the icon slot glyph and font name in style config.

Dart example:

```dart
await VolvoxGridServiceFfi.LoadFontData(
  LoadFontDataRequest()
    ..data = fontBytes
    ..fontName = 'Material Icons'
    ..fontNames.addAll(['Material Icons', 'MaterialIcons']),
);
```

### Text Layout Cache (Behavior and Memory)

`RenderConfig.text_layout_cache_cap` controls the text layout cache size used by
the internal `TextEngine` (default: `8192` entries).

Behavior:

- Cache key includes text and layout-affecting style inputs (font, size, bold/italic, wrap width).
- Cache is FIFO-capped. When full, older entries are evicted before adding new ones.
- `0` disables the cache and clears existing cached layouts.
- Runtime changes are applied immediately (including when switching active grids/views).

Memory impact:

- Memory grows with the number of unique shaped strings and their layout complexity.
- Each entry stores key data plus shaped line/glyph runs, so per-entry size varies by content.
- Higher caps reduce repeated shaping CPU cost, but increase `text_engine_bytes`.
- Lower caps reduce memory, but can increase CPU usage during scroll/repaint when text repeats less.
- `text_engine_bytes` is a conservative cache metric (it does not include every allocator/backend internal allocation), so process RSS can be higher.

Expected usage (rough):

- Current x86_64 struct sizes are `MeasureKey=64B`, `CachedLayout=336B`.
- Reported cache memory is roughly:
  `~(layout_cache_capacity * 408) + (layout_fifo_capacity * 64) + duplicated key strings`.
- In practice, this is commonly around `0.55KB` to `0.75KB` per cached entry in `text_engine_bytes`.

Approximate `text_engine_bytes` by cap:

| cap | expected `text_engine_bytes` |
|---|---|
| 0 | ~0 MB |
| 256 | ~0.14 MB to 0.19 MB |
| 1024 | ~0.55 MB to 0.75 MB |
| 4096 | ~2.2 MB to 3.0 MB |
| 8192 | ~4.5 MB to 6.0 MB |

Real process memory is usually above these numbers because text layout backend internals and font/glyph caches are outside this single metric.

Practical tuning:

- `8192`: high reuse, highest memory usage (good for large repeated datasets).
- `1024` to `4096`: balanced default for many apps.
- `256`: low memory mode.
- `0`: no layout cache (use only when memory is very constrained or for diagnostics).

To observe memory impact, check `MemoryUsageResponse.text_engine_bytes` before/after cap changes.

### Debug Overlay

The engine includes a high-performance, backend-agnostic debug overlay for real-time performance monitoring and state inspection. It can be toggled via `RenderConfig.debug_overlay`.

| Line | Example | Description |
|---|---|---|
| **Line 1** | `Engine v0.1.5-SNAPSHOT · 59ccdeb · 2026-03-02 14:46 UTC` | Engine version, short git commit, and UTC build date. |
| **Line 2** | `FPS: 60.0 \| 1.2ms \| Q: 1242 \| ID: 1001 \| Z: 100% \| Res: 1080x2240` | FPS, Frame Time, Instance Count (Quads), Grid ID, Zoom level, Render Resolution. |
| **Line 3** | `Mode: GPU(Vulkan-Mailbox) \| Grid: 1,000,000x20 \| DIRTY` | Render Backend, Logical Grid Dimensions (Rows x Cols), Engine Status. |
| **Line 4** | `Vis: 42x8(336) \| P: 0,15420 \| M: 12.4MB \| C: 842/8192` | Visible Viewport Dimensions & Total Cells, Scroll Position, Estimated Heap Memory, Text Cache Usage. |

*Note: The displayed `FPS` is not a raw frame counter, but an **Exponential Moving Average (EMA)** of the time taken to render and present a frame.*

## Trademarks

AG Grid is a trademark of AG Grid Ltd. Syncfusion and SfDataGrid are trademarks of Syncfusion, Inc. VSFlexGrid and FlexGrid are trademarks of GrapeCity, Inc. (formerly ComponentOne). All other trademarks are the property of their respective owners. VolvoxGrid is not affiliated with or endorsed by any of these companies. Third-party names are used solely to describe API-level interoperability. All adapter code is an independent, clean-room implementation -- no source code, binaries, or proprietary assets from the original frameworks are included.

## License

[Apache License 2.0](LICENSE)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on submitting issues and pull requests.
