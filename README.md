# VolvoxGrid

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

VolvoxGrid is a pixel-rendered datagrid engine written in Rust. The engine owns layout, selection, editing, sorting, scrolling, merged cells, and rendering, while thin platform wrappers expose it to Android, Java desktop, Flutter, web/WASM, Go, `.NET`, and terminal hosts.

## Screenshots

Checked-in screenshots across the current GUI, mobile, desktop, terminal, and compatibility hosts.

WASM example: <https://volvox-171cc.web.app/demos/web/>

| Web / Wasm | ActiveX / Windows |
|---|---|
| <img src="screenshots/web.png" alt="VolvoxGrid web demo in Chrome" width="100%"> | <img src="screenshots/activex.png" alt="VolvoxGrid ActiveX demo on Windows" width="100%"> |

| Android | Flutter Android |
|---|---|
| <img src="screenshots/android.png" alt="VolvoxGrid Android demo" width="100%"> | <img src="screenshots/flutter-android.png" alt="VolvoxGrid Flutter Android demo" width="100%"> |

| Java Desktop | Java TUI |
|---|---|
| <img src="screenshots/java-desktop.png" alt="VolvoxGrid Java desktop demo" width="100%"> | <img src="screenshots/java-tui.png" alt="VolvoxGrid Java TUI demo" width="100%"> |

| .NET Desktop | .NET TUI |
|---|---|
| <img src="screenshots/dotnet-desktop.png" alt="VolvoxGrid .NET desktop demo" width="100%"> | <img src="screenshots/dotnet-tui.png" alt="VolvoxGrid .NET TUI demo" width="100%"> |

| Flutter Linux | Go TUI |
|---|---|
| <img src="screenshots/flutter-linux.png" alt="VolvoxGrid Flutter Linux demo" width="100%"> | <img src="screenshots/go-tui.png" alt="VolvoxGrid Go TUI demo" width="100%"> |

## What VolvoxGrid Is

VolvoxGrid is not a single-framework widget. It is a shared grid engine with platform-specific shells on top of it.

The same retained grid model can drive GUI surfaces, terminal hosts, and compatibility adapters, while the platform layer stays focused on windowing, input wiring, packaging, and native lifecycle.

If you are evaluating the rendering paths themselves, read [GUI.md](GUI.md), [TUI.md](TUI.md), and [TEXT_RENDERING.md](TEXT_RENDERING.md). If you are changing VolvoxGrid internals, read [ARCHITECTURE.md](ARCHITECTURE.md).

## Features

### Rendering

- Pixel-rendered GUI engine with CPU and native-surface GPU backends through `wgpu`
- Shared Rust engine across Flutter, Android, Java desktop, web/WASM, Go, `.NET`, and terminal hosts
- Full packages use the built-in Rust text engine; lite packages use OS/browser text fallback with an engine-owned cache, including CoreText on Apple platforms
- Thin-host TUI path for ANSI streams or structured cell buffers
- Fling physics scrolling with scrollbar fade animations
- Background images and custom icon themes

### Data

- Cell types: text, numbers, booleans, timestamps, checkboxes (with indeterminate state), progress bars, dropdowns, pictures
- CSV, JSON, and XML import and export
- Formula editing mode with reference highlighting
- Protobuf-based contract and code-generated bindings across all platforms

### Interaction

- Cell editing with IME and international text input support
- Selection modes: free, by row, by column, listbox, multi-range
- Sorting with multi-column and custom comparators
- Search (text and regex) and find
- Clipboard: copy, cut, paste, and delete
- Pull-to-refresh for mobile
- Right-to-left layout support

### Layout

- Merged cells and cell spanning modes
- Frozen rows and columns
- Pinned rows and columns (separate from frozen panes)
- Row and column insert, remove, move, hide, and auto-resize
- Word wrap, shrink-to-fit, and text overflow modes
- Outline and grouping with tree indicators
- Subtotals and aggregates

### Styling

- Per-cell and range-based style overrides
- Column data types and number/date/currency formatting
- Scrollbar modes and debug overlays
- Animation support with configurable duration

### Adapters

- Compatibility adapters for [AG Grid](adapters/aggrid), [Sheet](adapters/sheet), [SfDataGrid](adapters/sfdatagrid), [VSFlexGrid](adapters/vsflexgrid), [XtraGrid](adapters/xtragrid), and [Report](adapters/report) APIs

## Quick Start

### Web

```bash
npm install volvoxgrid
```

```html
<script type="module">
  import { VolvoxGrid } from "volvoxgrid";

  const grid = new VolvoxGrid(document.getElementById("grid"), {
    wasmUrl: "./wasm/volvoxgrid_wasm.js",
    columnDefs: [
      { field: "name", headerName: "Name" },
      { field: "status", headerName: "Status" },
    ],
    rowData: [
      { id: "1", name: "Hello", status: "Ready" },
      { id: "2", name: "World", status: "Queued" },
    ],
    getRowId: ({ data }) => data.id,
  });

  await grid.loaded;
  grid.updateRows([{ id: "2", status: "Done" }]);
</script>

<div id="grid" style="width: 800px; height: 400px;"></div>
```

Or use the `<volvox-grid>` custom element:

```html
<script type="module">
  import "volvoxgrid/volvoxgrid-element.js";
</script>

<volvox-grid row-count="100" col-count="5"></volvox-grid>
```

### Flutter

```yaml
dependencies:
  volvoxgrid: ^0.8.9
```

```dart
import 'package:volvoxgrid/volvoxgrid.dart';

final controller = VolvoxGridController();
await controller.create(rows: 100, cols: 5);

await controller.setColumnCaption(0, 'Name');
await controller.setColumnCaption(1, 'Price');
await controller.setCellText(0, 0, 'Widget A');
await controller.setCellText(0, 1, '29.99');

// In your widget tree:
VolvoxGridWidget(controller: controller)
```

### Java Desktop

```kotlin
dependencies {
    implementation("io.github.ivere27:volvoxgrid-desktop:0.8.9")
}
```

```java
VolvoxGridDesktopPanel gridPanel = new VolvoxGridDesktopPanel();
frame.add(gridPanel, BorderLayout.CENTER);
gridPanel.initialize(null, 100, 5);

VolvoxGridDesktopController ctrl = gridPanel.createController();
ctrl.setColumnCaption(0, "Name");
ctrl.setCellText(0, 0, "Widget A");
```

## Packages

Examples below use `0.8.9`. Replace it with the release you want to consume.

### Maven / Gradle

Android:

```kotlin
dependencies {
    implementation("io.github.ivere27:volvoxgrid-android:0.8.9")
    // or: implementation("io.github.ivere27:volvoxgrid-android-lite:0.8.9")
    // Compose: implementation("io.github.ivere27:volvoxgrid-android-compose:0.8.9")
    // Compose lite: implementation("io.github.ivere27:volvoxgrid-android-compose-lite:0.8.9")
}
```

Java desktop:

```kotlin
repositories {
    mavenCentral()
}

dependencies {
    implementation("io.github.ivere27:volvoxgrid-desktop:0.8.9")
    // or: implementation("io.github.ivere27:volvoxgrid-desktop-lite:0.8.9")
}
```

Platform docs:

- [android/README.md](android/README.md)
- [java/README.md](java/README.md)

### Flutter / pub.dev

```yaml
dependencies:
  volvoxgrid: ^0.8.9
```

The Flutter package resolves Android and desktop native binaries from Maven Central at build time, and iOS XCFrameworks from GitHub releases. Set `VOLVOXGRID_VARIANT=lite` on supported platforms to use lite artifacts. See [flutter/README.md](flutter/README.md).

iOS native consumers can use the `VolvoxGrid` SwiftPM product for the full XCFramework, or `VolvoxGridLite` after a release has published `VolvoxGridLite.xcframework.zip`.

### Web / npm

```bash
npm install volvoxgrid
npm install volvoxgrid-lite
npm install @volvoxgrid/ag-grid
npm install @volvoxgrid/sheet
```

The web and adapter npm packages publish minified `dist/*.min.js` browser bundles for unpkg/jsDelivr usage in addition to their module exports.

The `volvoxgrid-lite` package ships the lite WASM runtime and uses browser Canvas2D for OS/browser font fallback. See [web/js/README.md](web/js/README.md) for the web package API and [TEXT_RENDERING.md](TEXT_RENDERING.md) for the text-rendering model.

### Go

The Go package provides a TUI host and client API for the native library. It is not published to a module proxy yet; use it from the repo:

```go
import (
    "github.com/ivere27/volvoxgrid/pkg/volvoxgrid"
    "github.com/ivere27/volvoxgrid/pkg/volvoxgrid/tui"
)
```

See [go/README.md](go/README.md) for setup and usage.

### .NET

The managed wrapper package IDs are `VolvoxGrid.DotNet` and `VolvoxGrid.DotNet.Lite`. The repo currently documents local project and local NuGet flows in [dotnet/README.md](dotnet/README.md):

```bash
dotnet pack dotnet/src/VolvoxGrid.DotNet.csproj -c Release
```

The NuGet packages embed staged native libraries for supported RIDs. Project-reference or manual deployment flows still need the native `volvoxgrid` library beside the app or configured through `VOLVOXGRID_LIBRARY_PATH`.

## Documents

- [GUI.md](GUI.md): GUI rendering design and host responsibilities
- [TUI.md](TUI.md): terminal rendering design and host responsibilities
- [BUILD_VARIANTS.md](BUILD_VARIANTS.md): full/lite features, artifact types, and binary size notes
- [TEXT_RENDERING.md](TEXT_RENDERING.md): full/lite text rendering and cache ownership
- [ARCHITECTURE.md](ARCHITECTURE.md): repo architecture, build workflow, and VolvoxGrid development
- [CONTRIBUTING.md](CONTRIBUTING.md): contribution guidelines
- [CHANGELOG.md](CHANGELOG.md): project-level changelog
- [android/README.md](android/README.md): Android wrapper usage
- [flutter/README.md](flutter/README.md): Flutter wrapper usage
- [java/README.md](java/README.md): Java desktop wrapper usage
- [dotnet/README.md](dotnet/README.md): `.NET` wrapper usage
- [go/README.md](go/README.md): Go TUI host usage
- [web/js/README.md](web/js/README.md): Web/npm package usage

## Trademarks

AG Grid is a trademark of AG Grid Ltd. Syncfusion and SfDataGrid are trademarks of Syncfusion, Inc. VSFlexGrid and FlexGrid are trademarks of GrapeCity, Inc. (formerly ComponentOne). All other trademarks are the property of their respective owners. VolvoxGrid is not affiliated with or endorsed by any of these companies. Third-party names are used solely to describe API-level interoperability. This repository does not include third-party proprietary source code, binaries, type libraries, or assets.

## License

[Apache License 2.0](LICENSE)
