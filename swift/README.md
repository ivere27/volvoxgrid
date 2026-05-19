# VolvoxGrid for Swift

VolvoxGrid is a pixel-rendered datagrid for Swift apps on iOS, macOS, and tvOS. A native Rust engine draws cells, headers, selection, scrolling, and editors into a CPU pixel buffer, and the Swift views present that buffer through UIKit, AppKit, or SwiftUI.

You get:

- `VolvoxGridClient` for creating grids, loading data, editing cells, sorting, selection, export, events, and render streams.
- `VolvoxGridView` for SwiftUI.
- `VolvoxGridUIView` for UIKit.
- `VolvoxGridNSView` for AppKit.
- Public generated request/response structs for direct Synurang contract calls when you need the low-level surface.

## Quick Start

Add the Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/ivere27/volvoxgrid", from: "0.8.9"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "VolvoxGrid", package: "volvoxgrid"),
    ])
]
```

Create a grid and show it in SwiftUI:

```swift
import SwiftUI
import VolvoxGrid

@MainActor
final class GridModel: ObservableObject {
    let client: VolvoxGridClient
    @Published var gridId: Int64 = 0

    init() {
        self.client = try! VolvoxGridClient()
    }

    func start() async {
        do {
            let id = try await client.createGrid(
                viewportWidth: 0,
                viewportHeight: 0,
                scale: 2.0
            )
            try await client.loadDemo(id, demo: "sales")
            gridId = id
        } catch {
            print("VolvoxGrid: \(error)")
        }
    }
}

struct ContentView: View {
    @StateObject private var model = GridModel()

    var body: some View {
        Group {
            if model.gridId != 0 {
                VolvoxGridView(client: model.client, gridId: model.gridId)
                    .ignoresSafeArea()
            } else {
                ProgressView()
            }
        }
        .task { await model.start() }
    }
}
```

`createGrid` accepts an initial viewport size, but the view will send its real size on first layout and after every resize.

## Requirements

- Swift 5.9 or newer
- Xcode 15 or newer
- iOS 13, macOS 10.15, or tvOS 13

## Package Products

| Product | Purpose |
|---|---|
| `VolvoxGrid` | Recommended Swift wrapper. Includes the Swift API and the lite XCFramework runtime. |
| `VolvoxGridXCFramework` | Raw full XCFramework binary for custom integrations. |
| `VolvoxGridLiteXCFramework` | Raw lite XCFramework binary for custom integrations. |

The `VolvoxGrid` product has no SwiftProtobuf or grpc-swift dependency. It uses the included Synurang lite runtime and generated Swift message types.

## What You Just Built

The SwiftUI example creates a `VolvoxGridClient`, asks the engine for a grid, loads the built-in sales dataset, and passes the client/grid pair to `VolvoxGridView`.

`VolvoxGridView` owns the render loop for that grid. It sends viewport, pointer, scroll, zoom, keyboard, and editor events to the engine, then presents returned frames through the host layer.

## Two Paths

Use the high-level client for normal app code:

```swift
let client = try VolvoxGridClient()
let gridId = try await client.createGrid(
    viewportWidth: 1024,
    viewportHeight: 768,
    scale: 2.0
)
```

Use the generated Synurang service when you need the exact service contract:

```swift
let host = try PluginHost.attachToProcess()
let service = VolvoxGridServiceFfiLite(host: host)

var request = CreateRequest()
request.viewportWidth = 1024
request.viewportHeight = 768
request.scale = 2.0

let response = try await service.create(request)
print(response.gridId)
```

Both paths talk to the same native engine. The high-level client is the concise app API; the generated service is the low-level RPC API.

## Loading Data

`loadDemo` is useful for examples. Real apps usually use `defineColumns` with `loadTable`, `loadData`, or `updateCells`.

```swift
var idCol = ColumnDef()
idCol.index = 0
idCol.key = "id"
idCol.caption = "ID"
idCol.width = 90
idCol.dataType = .columnDataNumber

var nameCol = ColumnDef()
nameCol.index = 1
nameCol.key = "name"
nameCol.caption = "Name"
nameCol.width = 180
nameCol.dataType = .columnDataString

try await client.defineColumns(
    gridId,
    columns: [idCol, nameCol],
    hostEditorDefaults: true
)

var v1 = CellValue()
v1.value = .number(1)
var v2 = CellValue()
v2.value = .text("Alpha")
var v3 = CellValue()
v3.value = .number(2)
var v4 = CellValue()
v4.value = .text("Beta")

try await client.loadTable(
    gridId,
    rows: 2,
    cols: 2,
    values: [v1, v2, v3, v4]
)

let row = try await client.find(gridId, col: 1, startRow: 0, text: "Beta")
print(row)
```

`CellValue` supports text, number, boolean flag, raw bytes, and timestamp values.

## Client API

Every method is `async throws`. Most methods take the `gridId` returned by `createGrid`.

| Area | Methods |
|---|---|
| Lifecycle | `createGrid`, `destroyGrid`, `configureGrid`, `getConfig`, `getSchema` |
| Columns and rows | `defineColumns`, `defineRows`, `insertRows`, `removeRows`, `moveColumn`, `moveRow` |
| Data | `loadTable`, `loadData`, `appendData`, `updateCells`, `getCells`, `clear` |
| Selection and scrolling | `select`, `getSelection`, `showCell`, `setTopRow`, `setLeftCol` |
| Editing | `editStart`, `editSetText`, `editSetSelection`, `editSetPreedit`, `editCommit`, `editCancel`, `getEditState` |
| Analysis | `sort`, `subtotal`, `aggregate`, `autoSize`, `outline`, `getNode`, `find` |
| Merged cells | `mergeCells`, `unmergeCells`, `getMergedRange`, `getMergedRegions` |
| I/O | `clipboard`, `export`, `print`, `archive` |
| Rendering and events | `refresh`, `resizeViewport`, `setRedraw`, `openRenderSession`, `openEventStream` |

## Views

| View | Platform | Notes |
|---|---|---|
| `VolvoxGridView` | SwiftUI | Wraps the UIKit or AppKit view for the current platform. |
| `VolvoxGridUIView` | iOS, tvOS, Mac Catalyst | Call `bind(client:gridId:)` to start rendering. |
| `VolvoxGridNSView` | macOS | AppKit view with the same `bind` and `unbind` surface. |

UIKit and AppKit usage:

```swift
let gridView = VolvoxGridUIView(frame: .zero)
gridView.bind(client: client, gridId: gridId)
```

```swift
let gridView = VolvoxGridNSView(frame: .zero)
gridView.bind(client: client, gridId: gridId)
```

Keep the `VolvoxGridClient` alive for as long as the view is bound. In SwiftUI, store it in an `ObservableObject` or another stable owner.

## Input and Editing

The views forward touch, mouse, scroll, pinch, and hardware keyboard input to the engine. Coordinates are converted from points to engine pixels with `layer.contentsScale`.

Text-like cell editors use native host controls:

- iOS/tvOS: inline `UITextView`
- macOS: inline `NSTextView`

Text, number, multiline text, and host-owned editable combo sessions use this native overlay path. Engine-owned dropdowns and checkboxes render on the grid canvas.

IME composition is forwarded through `editSetPreedit`, and committed text is applied through the edit session. Enter, Tab, Escape, and arrow-key behavior is handled by the native editor while a host-owned edit session is active.

## Edit Sessions

The engine uses `sessionId` and `stateVersion` to reject stale edit commands. The Swift client will fetch the current edit session when you use the default `0` values:

```swift
try await client.editStart(
    gridId,
    row: 0,
    col: 0,
    reason: .editStartProgrammatic,
    seedText: "hello"
)

try await client.editSetText(gridId, text: "hello world")
try await client.editCommit(gridId, text: "hello world")
```

Pass explicit `sessionId` and `stateVersion` when you already have them from an event or `getEditState`.

## Streams

`openRenderSession()` opens the bidirectional render stream:

```swift
let stream = try await client.openRenderSession()
try await stream.send(input)

for try await output in stream {
    print(output)
}
```

`openEventStream(gridId)` returns semantic grid events:

```swift
let events = try await client.openEventStream(gridId)

for try await event in events {
    print(event)
}
```

`client.close()` closes open streams owned by the client.

## Loading the Native Engine

`VolvoxGridClient(libraryPath:)` resolves the engine in this order:

1. An explicit `libraryPath`, if provided.
2. `VOLVOXGRID_LIBRARY_PATH`, if set.
3. Symbols already linked into the current process.

Apps that use the SwiftPM `VolvoxGrid` product normally use:

```swift
let client = try VolvoxGridClient()
```

Command-line tools and custom deployments can pass a library path:

```swift
let client = try VolvoxGridClient(libraryPath: "./libvolvoxgrid.dylib")
```

## Code Generation

Generated Swift bindings live in `swift/Sources/VolvoxGrid/Generated/volvoxgrid_lite.swift`. Regenerate all language bindings after changing `proto/volvoxgrid.proto`:

```bash
make codegen
```

`make codegen` uses the Synurang generator version pinned in the root Makefile.

## Examples

Example SwiftUI apps live in [Examples](Examples/):

| Example | What it shows |
|---|---|
| [Sales](Examples/SalesExampleApp.swift) | Sales data, subtotal rows, currency columns, progress cells, and a status dropdown. |
| [Hierarchy](Examples/HierarchyExampleApp.swift) | File-tree style outline with expand/collapse behavior. |
| [Stress](Examples/StressExampleApp.swift) | Large-grid rendering and scrolling with one million rows. |

See [Examples/README.md](Examples/README.md) for Xcode setup.

## Related

- [../ARCHITECTURE.md](../ARCHITECTURE.md)
- [../GUI.md](../GUI.md)
- [../TEXT_RENDERING.md](../TEXT_RENDERING.md)

## License

See the repository root for license terms.
