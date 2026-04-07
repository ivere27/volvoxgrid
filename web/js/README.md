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

await grid.loaded;

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
