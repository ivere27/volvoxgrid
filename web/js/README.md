# VolvoxGrid for the web

VolvoxGrid is a pixel-rendered datagrid: the Rust engine compiles to WebAssembly and paints rows, headers, IME caret and selection straight onto a `<canvas>`. You get spreadsheet-class scroll performance in the browser without leaning on DOM virtualization tricks.

## Quick start

Install the package and the runtime ships alongside it.

```bash
npm install volvoxgrid
```

```html
<div id="grid" style="width: 800px; height: 400px"></div>
```

```ts
import { VolvoxGrid } from "volvoxgrid";

const grid = new VolvoxGrid(document.getElementById("grid")!, {
  columnDefs: [
    { field: "name",  headerName: "Name",  width: 180 },
    { field: "price", headerName: "Price", width: 100 },
    { field: "qty",   headerName: "Qty",   width: 80 },
  ],
  rowData: [
    { id: "a", name: "Widget A", price: 29.99, qty: 150 },
    { id: "b", name: "Widget B", price: 49.99, qty: 200 },
  ],
  getRowId: ({ data }) => (data as { id: string }).id,
});

await grid.loaded;
grid.updateRows([{ id: "a", qty: 175 }]);
```

That's the whole hello-world. In five minutes you have a scrollable, focusable, IME-aware grid with two rows and three columns drawn pixel-for-pixel by the Rust engine.

## What you just built

A few things to call out:

- `new VolvoxGrid(host, options)` accepts any `HTMLElement`. Pass a `<canvas>` to render into it directly, or a container like a `<div>` and a child canvas is created to fill it.
- Construction loads the WASM module asynchronously. `grid.loaded` is a `Promise<this>` you await before calling render-affecting methods.
- `columnDefs`, `rowData`, `getRowId` mirror the vocabulary you already know from AG Grid / MUI / Kendo. `columns` and `data` are accepted as aliases.
- All grid state lives in WASM memory. The JS facade just owns the canvas, the render loop, and event forwarding.

## The custom element shortcut

If you're HTML-first or shipping a quick demo without a bundler, use `<volvox-grid>`.

```html
<script type="module">
  import "volvoxgrid/volvoxgrid-element.js";
</script>

<volvox-grid
  row-count="100"
  col-count="5"
  show-column-headers
  style="width: 800px; height: 400px;"
></volvox-grid>
```

Supported attributes:

| Attribute | Default | Meaning |
|---|---|---|
| `row-count` | `10` | Total row count |
| `col-count` | `5` | Total column count |
| `frozen-row-count` | `0` | Number of frozen data rows |
| `frozen-col-count` | `0` | Number of frozen data columns |
| `show-column-headers` | `true` | Top column indicator band |
| `show-row-indicator` | `false` | Start row indicator band |
| `wasm-url` | `./wasm/volvoxgrid_wasm.js` | URL of the WASM glue |

The element builds its own shadow DOM `<canvas>` and creates a `VolvoxGrid` once the WASM module is ready.

## Two packages: full vs lite

You pick the runtime by your bundle budget. The JS API lives in `volvoxgrid` either way — the `volvoxgrid-lite` package ships only the slimmer WASM bytes, which you point `wasmUrl` at. See [BUILD_VARIANTS.md](../../BUILD_VARIANTS.md) for the build matrix.

### `volvoxgrid` (full)

The default. Includes the built-in Rust text engine, GPU renderer, regex search, and (with the threaded build) rayon-parallel rasterization. WASM is around 3.3 MiB. Pick this for desktop apps and any deploy where bundle size isn't the bottleneck.

### `volvoxgrid-lite` (lite)

A smaller WASM — around 1.3 MiB — that drops the embedded text engine and GPU paths. Text measurement and rasterization fall back to the browser's Canvas2D APIs; the WASM still owns the external text-mask cache. Use this for low-bandwidth deploys, embeds, or anywhere you can't afford the full payload.

```ts
import { VolvoxGrid } from "volvoxgrid";

const grid = new VolvoxGrid(document.getElementById("grid")!, {
  wasmUrl: new URL("volvoxgrid-lite/wasm/volvoxgrid_wasm.js", import.meta.url).href,
  rowCount: 100,
  colCount: 5,
});
```

For the full picture of which features live where, see [TEXT_RENDERING.md](../../TEXT_RENDERING.md).

## Loading data

The application-level API takes `columnDefs` + `rowData` and resolves stable row identity through `getRowId`.

```ts
grid.setColumns([
  { field: "name",   headerName: "Name" },
  { field: "status", headerName: "Status" },
]);

grid.setData([
  { id: "1", name: "Alpha", status: "Ready" },
  { id: "2", name: "Beta",  status: "Queued" },
], {
  getRowId: ({ data }) => (data as { id: string }).id,
});
```

`columnDefs` accepts `field`, `colId`, `headerName`, `width`, plus `valueGetter` / `valueFormatter` for host-side projection and display.

Tree data passes through `setTreeData`, with either nested `children` or `parentId` fields:

```ts
grid.setTreeData([
  { id: "root", name: "Root", children: [
    { id: "child", name: "Child" },
  ]},
], {
  columns: [{ field: "name", headerName: "Name" }],
});
```

Bulk-load primitives are there when you don't want the row-id machinery:

```ts
// CSV or JSON bytes parsed by the engine
grid.loadData("Name,Price,Qty\nWidget A,29.99,150\nWidget B,49.99,200");

// Row-major flat value array
grid.loadTable(2, 3, ["Widget A", 29.99, 150, "Widget B", 49.99, 200]);

// Single-cell write
grid.setCellText(0, 0, "Alpha");
```

## Updating rows

You've got three knobs depending on what you know:

```ts
// 1. Partial-by-id: only the changed fields
grid.updateRows([{ id: "a", qty: 175 }]);

// 2. AG Grid-style transaction
grid.applyTransaction({
  add:    [{ id: "c", name: "Widget C", price: 9.99, qty: 80 }],
  update: [{ id: "a", qty: 200 }],
  remove: ["b"],
});

// 3. Direct cell writes when you already have (row, col)
grid.setCells([
  { row: 0, col: 0, text: "Alpha" },
  { row: 0, col: 1, text: "29.99" },
]);
```

`updateRows` and `applyTransaction` both use `getRowId` to match rows. Pass `{ atomic: true }` in the options to commit the whole batch under a single engine transaction.

## Events

Listen with `on(name, listener)`. Listeners are strongly typed via `VolvoxGridEventMap`.

```ts
grid.on("editorSessionStarted", (e) => {
  console.log("editing", e.row, e.col, e.initialText);
});

grid.on("editorSessionEnded", (e) => {
  if (e.committedText !== undefined) {
    console.log("committed", e.committedText);
  }
});

grid.on("beforeSort", (e) => {
  if (e.col === 0) e.cancel = true; // veto sort on column 0
});

grid.on("contextMenuRequest", (e) => {
  // e.clientX/Y, e.row, e.col, e.selection — open your own menu
});
```

Available events:

| Name | Cancelable | Payload |
|---|---|---|
| `beforeEdit` | yes | `VolvoxGridBeforeEditDetails` |
| `cellEditValidating` | yes | `VolvoxGridCellEditValidatingDetails` |
| `beforeSort` | yes | `VolvoxGridBeforeSortDetails` |
| `editorSessionStarted` | no | `VolvoxGridEditorSessionStartedDetails` |
| `editorSessionUpdated` | no | `VolvoxGridEditorSessionUpdatedDetails` |
| `editorSessionEnded` | no | `VolvoxGridEditorSessionEndedDetails` |
| `zoomChange` | no | `number` |
| `contextMenuRequest` | no | `VolvoxGridContextMenuRequest` |
| `gridEventRaw` | no | `Uint8Array` (raw protobuf — escape hatch) |

`off(name, listener)` removes; `once(name, listener)` runs once and unsubscribes. Cancelable events set `details.cancel = true` to veto.

## Editing

The grid runs its own editor session: text input, dropdowns, checkbox toggles, IME composition and validation are all native paths.

```ts
grid.on("beforeEdit", (e) => {
  if (e.col === 0) e.cancel = true; // make column 0 read-only
});

grid.on("cellEditValidating", (e) => {
  if (e.editText.trim() === "") e.cancel = true; // reject empty
});
```

For richer editor configuration — dropdowns, number/checkbox editors, custom presentation — use `setColDataType`, `setColDropdown`, `setCellDropdown`, and the typed editor APIs on the `VolvoxGrid` class.

IME (Hangul, Pinyin, Kana) composition is handled by the WASM runtime and rendered onto the canvas. See [IME.md](../../IME.md) for the architecture and any platform caveats. The rest of the GUI behavior — selection model, keyboard map, copy/paste — lives in [GUI.md](../../GUI.md).

## CDN / no-bundler usage

For demos and scratch pads, load the minified bundle directly from a CDN with an import map. The package's `unpkg` and `jsdelivr` fields both point at `dist/volvoxgrid.min.js`.

```html
<!doctype html>
<script type="importmap">
{
  "imports": {
    "volvoxgrid": "https://cdn.jsdelivr.net/npm/volvoxgrid@0.8.9/dist/volvoxgrid.min.js",
    "volvoxgrid/volvoxgrid-element.js":
      "https://cdn.jsdelivr.net/npm/volvoxgrid@0.8.9/dist/volvoxgrid-element.js"
  }
}
</script>

<div id="grid" style="width: 800px; height: 400px"></div>

<script type="module">
  import { VolvoxGrid } from "volvoxgrid";

  const grid = new VolvoxGrid(document.getElementById("grid"), {
    wasmUrl: "https://cdn.jsdelivr.net/npm/volvoxgrid@0.8.9/wasm/volvoxgrid_wasm.js",
    rowCount: 50,
    colCount: 6,
  });
  await grid.loaded;
</script>
```

Because `import.meta.url` no longer points at the package once a bundler inlines things, set `wasmUrl` explicitly when the default resolution can't find the WASM glue.

## Adapter packages

If you're migrating from another grid library, the adapter packages translate that library's API onto VolvoxGrid:

- **`@volvoxgrid/ag-grid`** — maps the AG Grid options surface (column defs, row models, the transaction API) onto `VolvoxGrid` so you can swap in with minimal code change. Ships as `dist/ag-grid-volvox.min.js`.
- **`@volvoxgrid/sheet`** — a spreadsheet-style facade on top of `VolvoxGrid` for cell-addressing workflows. Ships as `dist/volvox-sheet.min.js`.

Both adapters are thin wrappers — they don't fork the engine, and the underlying `VolvoxGrid` instance is reachable.

## Troubleshooting

**Threaded WASM build returns 0x0 canvas or crashes on load.** The threaded build needs cross-origin isolation. Serve with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. The non-threaded build has no such requirement.

**CSP blocks WASM instantiation.** Add `'wasm-unsafe-eval'` to `script-src` (or `'unsafe-eval'` for older policies). The WASM module is instantiated from bytes at load time.

**Lite WASM renders empty / wrong-glyph text.** Lite uses the browser's Canvas2D text engine, so it inherits whatever fonts are installed on the client. If your design ships custom fonts, register them with the browser font face set before constructing the grid, or use the full build.

**Mismatched `wasmUrl` and package.** Pointing the full JS facade at the lite WASM (or vice versa) usually shows up as undefined symbols at runtime. Keep the JS package and the WASM glue on the same side of the full/lite split.

**Font fallback substitutes glyphs I'd rather leave missing.** Disable it:

```ts
await grid.loaded;
grid.setFontFallbackEnabled(false);
```

The same setting lives on `RenderConfig.font_fallback_enabled` in the protobuf API.

## What's next

- [CHANGELOG](../../CHANGELOG.md) — current version is `0.8.9`
- [GUI.md](../../GUI.md) — selection model, keyboard map, mouse behavior
- [TEXT_RENDERING.md](../../TEXT_RENDERING.md) — text engine and cache ownership for full vs lite
- [IME.md](../../IME.md) — IME composition pipeline
- [ARCHITECTURE.md](../../ARCHITECTURE.md) — engine internals, FFI surface, render loop
- [BUILD_VARIANTS.md](../../BUILD_VARIANTS.md) — full vs lite vs threaded build matrix

If you're reaching for `grid.ffi`, `grid.rawWasm`, or `grid.callProto(...)` — the typed-proto and raw escape hatches in [src/index.ts](src/index.ts) — that's a signal the facade is missing a typed method. File an issue.

## License

[Apache License 2.0](../../LICENSE)
