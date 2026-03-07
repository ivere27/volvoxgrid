# TODO

## Core

- [ ] **Pan fast-path: copy previous frame + redraw only exposed strips** (`engine/src/canvas.rs:1595,1689`, `engine/src/render.rs:77-79`, `engine/src/gpu_render.rs:664,765`): `render_grid()` still does full `canvas.clear()` + full repaint and returns full-viewport dirty rect. Implement scroll-region copy + redraw only newly exposed edge strips. Must handle fixed/frozen/sticky zones separately (they do not scroll with body content). Dirty-rect plumbing is already wired in plugin (`FrameDone/GpuFrameDone { dirty_x, dirty_y, dirty_w, dirty_h }`).
- [ ] **Cache decoded images** (`engine/src/canvas.rs:1378`): `decode_png_rgba()` (via `tiny_skia::Pixmap::decode_png`) still has no cache and is hit from 7 render call sites: background image (`2029`), cell pictures (`2560`), sort glyphs (`2875`), checkbox pics (`3222,3227,3232`), outline node pics (`3676`). Add cache keyed by content hash (or stable image id) and invalidate on style/data updates.
- [ ] **Keep span cache across frames** (`engine/src/span.rs:72-75`, `engine/src/canvas.rs:1592`): `clear_span_cache()` still clears on every frame. During scroll-only changes, span structure is typically unchanged; skip clear on scroll-only dirty reasons.
- [ ] **Subtotal-specific parent-key merge mode** (`proto/volvoxgrid.proto`, `engine/src/outline.rs`, `engine/src/demo.rs`): Add a subtotal/group-row merge option (for copied parent keys like Sales demo `Q`) instead of overloading generic `CELL_SPAN_ADJACENT`.
- [ ] **Reuse per-frame allocations** (`engine/src/canvas.rs:1598`, `engine/src/canvas.rs:2160`): `vis_cells: Vec` and `rendered_merges: HashSet` are still newly allocated each frame. Move reusable buffers onto renderer state (clear + retain capacity).
- [ ] **Cache or short-circuit `get_display_text` in overflow scanning** (`engine/src/canvas.rs:2425,2443`, `engine/src/grid.rs:1817-1854`): Neighbor overflow scans still call full `get_display_text()` (dropdown translation + format application). Short-circuit with `cells.get_text(row, c).is_empty()` before expensive display-text work, and/or memoize row display strings during render.
- [ ] **Out-of-Bounds / Panic Risks (Rust)** (`engine/src/layout.rs`, `engine/src/grid.rs`, `web/crate/src/lib.rs`): Unsafe use of `.last().unwrap()` and `.as_mut().unwrap()` will panic and crash the app if the layout is empty or values are `None`. Fix: Handle `None` gracefully instead of unwrapping.

## Wasm

- [ ] font style support in wasm: italic, bold, and strike-through.
- [ ] **WASM render buffer pointer use-after-free** (`web/crate/src/lib.rs:2034-2038`): `render_buffer_ptr()` returns raw pointer but drops Mutex guard immediately. Buffer reallocation → dangling pointer.
- [ ] **`unsafe impl Send/Sync` vs `wasm-threads`** (`web/crate/src/lib.rs:34,36,236`): Safe for single-threaded WASM but unsafe if `gpu` + `wasm-threads` features are both enabled.
- [ ] **Defensive `typeof wasm.xxx` fallbacks** (`web/js/src/volvoxgrid.ts:808-848`): 10+ legacy API name fallbacks. Consider removing once API is stabilized.

## Synurang

- [ ] **Use Synurang's `FfiError` instead of ad-hoc string errors** (`plugin/src/volvoxgrid_ffi_plugin.rs`, `adapters/vsflexgrid/crate/src/volvoxgrid_ffi_native.rs`, `protoc-gen-synurang-ffi`): current FFI layers still return raw status+message strings / thread-local last-error text. Canonicalize native/plugin error transport on Synurang's typed `FfiError`.
- [ ] **Plugin-server null-pointer safety** (`protoc-gen-synurang-ffi` template, `mode=plugin_server`): Generated `Synurang_Stream_Recv` dereferences `resp_len` / `status` without null checks. Add pointer guards in generator and regenerate `plugin/src/volvoxgrid_ffi_plugin.rs`.
- [ ] **Native Rust free safety** (`protoc-gen-synurang-ffi` template, `mode=native`): Generated `alloc_payload_with_header/free_payload_with_header` trusts pointer-adjacent header bytes and does not validate pointer ownership in `volvox_grid_free`. Track allocations (or add cookie+registry) and reject unknown pointers; regenerate `adapters/vsflexgrid/crate/src/volvoxgrid_ffi_native.rs` after upstream fix.

## Plugin

- [ ] **Unsafe buffer access from protobuf handle** (`plugin/src/lib.rs:2160-2166`): `handle` (i64 from protobuf) cast to `*mut u8` with only null check. Malformed message → segfault.
- [ ] **Unnecessary `data.clone()` in stream recv** (`plugin/src/volvoxgrid_ffi_plugin.rs:985`): Double allocation for every stream message. Fix: save `len`, then `data.into_boxed_slice()`.
- [ ] **`Vec::remove(0)` is O(n) for FIFO queues** (`plugin/src/volvoxgrid_ffi_plugin.rs:51,203,920`): Should use `VecDeque` for O(1) `pop_front()`.
- [ ] **`STREAMS.write().unwrap()` can panic across FFI boundary** (`plugin/src/volvoxgrid_ffi_plugin.rs:888`): Only `.write()` call that doesn't handle poison gracefully.

## Adapter/Excel

- [ ] Formula multi-selection mode like Excel: while editing formulas (e.g. `=SUM(`), allow selecting multiple ranges/cells and keep all referenced ranges visibly highlighted at the same time.
- [ ] **`clearRange` triggers O(n*m) recalculations** (`adapters/sheet/src/core/data-store.ts:147-153`): Each `setCellValue` recalculates entire sheet. Fix: batch-set values, then recalculate once.
- [ ] **`console.log` in production code** (`adapters/sheet/src/core/data-store.ts:109`): Logs every batch cell update. Remove or guard behind debug flag.
- [ ] **Leftover Debug Logging (HTML)** (`adapters/sheet/index.html`): Stray `console.log` statements left from testing (e.g., `console.log("[test] editInput keydown...");`).
- [ ] **Hand-rolled protobuf encoder in JS** (`adapters/sheet/src/proto/proto-utils.ts`): Manual varint/zigzag/tag encoding. Correct but high maintenance burden on proto schema changes.

## Adapter/AG Grid

## Adapter/SfDataGrid

- [ ] **Programmatic scroll hook timeout in compare test** (`adapters/sfdatagrid/test/cases/15_programmatic_scroll.dart`): `setTopRow()`/`Select(show=true)` can hang and hit Synurang's 30s request timeout under `flutter_test`; hook is currently omitted as a workaround. Root cause appears to be in Synurang request/stream concurrency and should be fixed upstream.

## Adapter/VSFlexGrid (ActiveX)

- [ ] **Support `ADORecordset` as `DataSource` in MinGW ActiveX path** (`adapters/vsflexgrid/mingw/volvoxgrid_ocx.c`, `adapters/vsflexgrid/include/volvoxgrid_activex.h`, `adapters/vsflexgrid/src/ADOAdapter.cpp`): Add `DataSource` (`propputref`) dispatch support and bind ADODB/DAO recordsets in the MinGW COM implementation (parity with ATL `putref_DataSource`). Handle forward-only cursors (`RecordCount = -1`), `Null` values, and rebind refresh behavior.

## Adapters/Shared

- [ ] **`wasm: any` throughout TS adapters** (14 occurrences across 8 files): No compile-time safety for WASM API boundary. Add proper interface type.
- [ ] **Shell scripts inject paths into inline Python/Node** (`adapters/*/run_compare_ui.sh`): Pass paths as CLI args instead of string interpolation.

## Flutter

- [ ] Flutter Linux: add maven/local dual-mode to CMakeLists.txt (download JAR from Maven, extract .so)
- [ ] Flutter iOS: add podspec with vendored XCFramework (from Docker `build_ios` output), declare `ios: ffiPlugin: true` in pubspec.yaml
- [ ] **`VolvoxGridController.dispose()` doesn't await `destroyGrid()`** (`flutter/lib/volvoxgrid_controller.dart:93-99`): Native grid may not be cleaned up before Dart GC runs.

## Android

- [ ] **Workaround for Adreno driver Vulkan probing** (`engine/src/gpu_render.rs`): Current Vulkan backend on some Android devices (Adreno) fails during internal capability probing for formats 56/59 (4x4 allocation failure), even when unused. Fixed by pinning to OpenGL ES by default. Investigate if `InstanceFlags` or newer `wgpu` versions allow safe Vulkan initialization. **Needs more testing for stability across different devices.**
- [ ] **Silenced Exceptions (Kotlin)** (`android/volvoxgrid-android/src/.../VolvoxGridView.kt`, `MainActivity.kt`): Empty `catch (_: Exception) {}` blocks hide critical runtime failures. Fix: Log the exception or handle it appropriately.

## Build / Portability

- [ ] **iOS Dockerfile can't produce linkable binaries** (`Dockerfile.ios`): No Apple SDK for linking. May be intentional for compile-check only.
- [ ] **Add iOS + macOS binary smoke tests in CI** (`docker/build_ios.sh`, `docker/build_desktop_jar.sh`, `Makefile`): After artifact builds, validate iOS XCFramework and macOS `.dylib` outputs for expected architectures and loadability (missing symbol / bad arch checks) on a macOS runner.
