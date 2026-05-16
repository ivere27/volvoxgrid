# VolvoxGrid for Web

The `volvoxgrid` npm package wraps the Rust VolvoxGrid engine compiled to WebAssembly. All grid state lives in WASM memory; the JavaScript layer manages the render loop, HTML canvas, and event forwarding.

## Installation

```bash
npm install volvoxgrid
```

For the lite WASM runtime:

```bash
npm install volvoxgrid-lite
```

## Quick Start

### Using `VolvoxGrid` directly

```js
import { VolvoxGrid } from "volvoxgrid";

const grid = new VolvoxGrid(document.getElementById("grid"), {
  wasmUrl: "./wasm/volvoxgrid_wasm.js",
  columnDefs: [
    { field: "name", headerName: "Name", width: 180 },
    { field: "price", headerName: "Price", width: 90 },
    { field: "qty", headerName: "Qty", width: 80 },
  ],
  rowData: [
    { id: "a", name: "Widget A", price: 29.99, qty: 150 },
    { id: "b", name: "Widget B", price: 49.99, qty: 200 },
  ],
  getRowId: ({ data }) => data.id,
});

await grid.loaded;
grid.updateRows([{ id: "a", qty: 175 }]);
grid.applyTransaction({ add: [{ id: "c", name: "Widget C", price: 9.99, qty: 80 }] });
```

### Using the `<volvox-grid>` custom element

```html
<script type="module">
  import "volvoxgrid/volvoxgrid-element.js";
</script>

<volvox-grid
  row-count="100"
  col-count="5"
  show-column-headers
></volvox-grid>
```

The custom element creates a shadow DOM canvas and initializes VolvoxGrid automatically. Supported attributes:

| Attribute | Default | Description |
|---|---|---|
| `row-count` | `10` | Total row count |
| `col-count` | `5` | Total column count |
| `frozen-row-count` | `0` | Number of frozen data rows |
| `frozen-col-count` | `0` | Number of frozen data columns |
| `show-column-headers` | `true` | Show the top column indicator band |
| `show-row-indicator` | `false` | Show the start row indicator band |
| `wasm-url` | `"./wasm/volvoxgrid_wasm.js"` | URL of the WASM module |

## Package Exports

| Export | Description |
|---|---|
| `volvoxgrid` | Main entry: `VolvoxGrid`, `VolvoxGridElement`, types |
| `volvoxgrid/generated/volvoxgrid_ffi.js` | Generated low-level FFI constants |
| `volvoxgrid/generated/volvoxgrid_lite.js` | Generated protobuf-lite message codecs |
| `volvoxgrid/default-input.js` | Default keyboard/mouse input helpers |
| `volvoxgrid/volvoxgrid-element.js` | Custom element registration |

## Package Builds

```bash
npm run build
```

This compiles the TypeScript package into `dist/` and also writes the minified browser bundle at `dist/volvoxgrid.min.js` with a source map. The package `unpkg` and `jsdelivr` fields point to that minified file.

The adapter packages follow the same release shape:

| Package | Minified bundle |
|---|---|
| `volvoxgrid` | `dist/volvoxgrid.min.js` |
| `@volvoxgrid/ag-grid` | `dist/ag-grid-volvox.min.js` |
| `@volvoxgrid/sheet` | `dist/volvox-sheet.min.js` |

Release demos can load these bundles from jsDelivr with import maps, while generated low-level modules remain available under `dist/generated/`.

## Lite WASM Runtime

`volvoxgrid-lite` contains the lite WASM runtime. Use the normal `volvoxgrid` JavaScript API and point `wasmUrl` at the lite package's WASM glue:

```js
import { VolvoxGrid } from "volvoxgrid";

const grid = new VolvoxGrid(document.getElementById("grid"), {
  wasmUrl: new URL("volvoxgrid-lite/wasm/volvoxgrid_wasm.js", import.meta.url).href,
  rowCount: 100,
  colCount: 5,
});
```

Lite WASM excludes the built-in Rust text engine, GPU renderer, regex search, and rayon parallelism. Browser Canvas2D provides text measurement and rasterization on cache misses, while the WASM runtime owns the external text mask cache shown as `C:<used>/<cap>` in the debug overlay.

See [../../TEXT_RENDERING.md](../../TEXT_RENDERING.md) for full/lite text rendering and cache ownership.

## Font Fallback Policy

Font fallback is enabled by default. When enabled, the WASM runtime can use the
registered browser glyph rasterizer for missing glyphs; the web demo may also
fall back to browser Canvas2D text rendering when demo font downloads fail.
Browser fallback font families are derived from the runtime fallback policy and
the browser locale hints.

If no font source can render a glyph, the engine uses a small internal final
fallback: printable ASCII uses an embedded bitmap font, and other missing
characters render as a diagnostic tofu box with the codepoint inside.

Disable fallback at runtime if you prefer missing text over substituted or
diagnostic fallback glyphs:

```js
await grid.loaded;
grid.fontFallbackEnabled = false;
// or:
grid.setFontFallbackEnabled(false);
```

The same setting is also available in the shared protobuf API as
`RenderConfig.font_fallback_enabled`. It applies to CPU and GPU rendering in
the WASM runtime.

## Data Operations

#### RowData / Transactions

Use `columnDefs` and `rowData` for the normal application API:

```js
grid.setColumns([
  { field: "name", headerName: "Name" },
  { field: "status", headerName: "Status" },
]);

grid.setData([
  { id: "1", name: "Alpha", status: "Ready" },
  { id: "2", name: "Beta", status: "Queued" },
], {
  getRowId: ({ data }) => data.id,
});

grid.updateRows([{ id: "2", status: "Done" }]);

grid.applyTransaction({
  add: [{ id: "3", name: "Gamma", status: "Ready" }],
  update: [{ id: "1", status: "Paused" }],
  remove: ["2"],
});
```

For tree data, pass nested children or parent ids:

```js
grid.setTreeData([
  {
    id: "root",
    name: "Root",
    children: [{ id: "child", name: "Child" }],
  },
], {
  columns: [{ field: "name", headerName: "Name" }],
});
```

#### Raw Protobuf Calls

For exact `proto/volvoxgrid.proto` request/response access, import the generated
protobuf-lite messages and call the runtime RPC by service method name:

```js
import { VolvoxGrid } from "volvoxgrid";
import {
  CellUpdate,
  CellValue,
  UpdateCellsRequest,
  WriteResult,
} from "volvoxgrid/generated/volvoxgrid_lite.js";

const request = new UpdateCellsRequest({
  cells: [
    new CellUpdate({
      row: 0,
      col: 0,
      value: new CellValue({ text: "Raw protobuf write" }),
    }),
  ],
  atomic: true,
});

const result = grid.callProto("UpdateCells", request, WriteResult);
```

`callProto` fills `request.gridId` with the current engine id when the generated
message has an unset `gridId` field. `callProtoBytes(method, bytes)` is available
when you already have encoded protobuf bytes.

#### LoadData

Parse CSV or JSON bytes into the grid:

```js
// CSV
grid.loadData("Name,Price,Qty\nWidget A,29.99,150\nWidget B,49.99,200");

// JSON matrix with options
grid.loadData(
  JSON.stringify([["Name", "Price"], ["Alpha", "10"]]),
  { json: {}, headerPolicy: HeaderPolicy.HEADER_NONE },
);
```

#### UpdateCells

Batch update cells:

```js
grid.setCells([
  { row: 0, col: 0, text: "Alpha" },
  { row: 0, col: 1, text: "29.99" },
  { row: 1, col: 0, text: "Beta" },
  { row: 1, col: 1, text: "49.99" },
]);
```

#### GetCells

Read cell values:

```js
const text = grid.getCellText(0, 0);
const price = grid.getCellText(0, 1);
```

#### Clear

```js
// Clear everything
grid.clear();

// Clear only data (keep formatting)
grid.clear(/* scope */ 2, /* region */ 0);
// Scopes: 0 = EVERYTHING, 1 = FORMATTING, 2 = DATA, 3 = SELECTION
// Regions: 0 = SCROLLABLE, 1 = FIXED_ROWS, 2 = FIXED_COLS, 5 = ALL_REGIONS

// Clear a specific cell range
grid.clearCellRange(0, 0, 9, 4);
```

#### LoadTable

`loadTable` bulk-loads a row-major flat array of values in a single call:

```js
grid.loadTable(2, 3, ["Widget A", 29.99, 150, "Widget B", 49.99, 200]);
```

Values are coerced to strings internally. For typed `CellValue` payloads (text, number, boolean, bytes, timestamp), use the generated FFI bindings in `volvoxgrid/generated/volvoxgrid_ffi.js`. For the full `LoadTableRequest` schema, see [`proto/volvoxgrid.proto`](../../proto/volvoxgrid.proto).

## Adapter Packages

Compatibility adapters that map third-party grid APIs to VolvoxGrid:

- [`@volvoxgrid/ag-grid`](../../adapters/aggrid) - AG Grid API adapter
- [`@volvoxgrid/sheet`](../../adapters/sheet) - Spreadsheet-style sheet adapter

## WASM Build

To rebuild the WASM module from source:

```bash
# Standard build
npm run build:wasm

# Threaded build (requires nightly Rust)
npm run build:wasm:threaded
```

These scripts build the WASM-facing target from the shared `runtime/` crate and write package-local output to `web/js/wasm/`. Repo-level `make wasm` and `make web` write demo output to `web/example/wasm/`.

Repo-level lite build:

```bash
make wasm-lite
make web-lite
```

## Running the Example

From the repo root:

```bash
make web
```

This builds the runtime WASM target and starts the Vite dev server for the example app in `web/example/`.

For release-style demo output:

```bash
WEB_DOCKER_TARGET=web make docker_web
```

That build writes `dist/web/demos/web/` and externalizes `volvoxgrid` through a CDN import map. Use `WEB_DOCKER_TARGET=sheet` or `WEB_DOCKER_TARGET=sheet-lite` for the sheet demos.

## License

[Apache License 2.0](../../LICENSE)
