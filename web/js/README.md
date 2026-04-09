# VolvoxGrid for Web

The `volvoxgrid` npm package wraps the Rust VolvoxGrid engine compiled to WebAssembly. All grid state lives in WASM memory; the JavaScript layer manages the render loop, HTML canvas, and event forwarding.

## Installation

```bash
npm install volvoxgrid
```

## Quick Start

### Using `VolvoxGrid` directly

```js
import { VolvoxGrid } from "volvoxgrid";

const grid = new VolvoxGrid(document.getElementById("grid"), {
  wasmUrl: "./wasm/volvoxgrid_wasm.js",
  rowCount: 100,
  colCount: 5,
});

grid.setColumnCaption(0, "Name");
grid.setColumnCaption(1, "Price");
grid.setCellText(0, 0, "Widget A");
grid.setCellText(0, 1, "29.99");
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
| `volvoxgrid/generated/volvoxgrid_ffi.js` | Generated low-level FFI bindings |
| `volvoxgrid/default-input.js` | Default keyboard/mouse input helpers |

## Data Operations

#### LoadData

Parse CSV or JSON bytes into the grid:

```js
// CSV
grid.loadData("Name,Price,Qty\nWidget A,29.99,150\nWidget B,49.99,200");

// JSON matrix with options
grid.loadData(
  JSON.stringify([["Name", "Price"], ["Alpha", "10"]]),
  { format: "json", headerPolicy: "none" },
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

The WASM output is written to `web/js/wasm/`.

## Running the Example

From the repo root:

```bash
make web
```

This builds the WASM crate and starts the Vite dev server for the example app in `web/example/`.

## License

[Apache License 2.0](../../LICENSE)
