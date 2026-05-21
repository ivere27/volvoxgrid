# Build Variants and Binary Sizes

You're trying to figure out which VolvoxGrid binary to ship, why one is 10 MB and another is 2 MB, or how to inspect what's actually inside them. Here's how VolvoxGrid handles it on your platform.

This document covers the VolvoxGrid full, lite, .NET, Java desktop, WASM, and ActiveX build variants, and why their binary sizes differ.

Binary sizes are examples, not compatibility guarantees. They change with Rust, Zig/MinGW, LLVM, target OS ABI, enabled features, link-time optimization, and post-build stripping.

The example sizes below are illustrative and use current `0.8.11` filenames. The measurements were last inspected on 2026-05-19.

Next: there are two main variants for a reason.

## Why two variants exist

The split is simple:

- **Full** ships the built-in Rust text engine, the GPU renderer, and rayon parallelism. You drop it into your host, point it at a grid, and everything works without you wiring anything text-shaping-related.
- **Lite** drops text shaping, GPU, and rayon. The host has to provide its own text fallback (GDI+, Java2D, Canvas2D, CoreText), there's no GPU path, no rayon parallelism. Regex search stays in so hosts don't have to thread their own regex through FFI for grid search. In return, you get a much smaller binary.

If you're shipping into a constrained channel — small download, embedded surface, or a wrapper that already owns text — you want lite. Otherwise stay on full.

Next: the artifact types you'll actually see in `dist/`.

## Artifact types

| Artifact | What it is | Typical role |
| --- | --- | --- |
| `volvoxgrid.dll`, `libvolvoxgrid.so`, `libvolvoxgrid.dylib` | Rust native runtime | Used by Java desktop, .NET, Android, iOS, and WASM-adjacent packaging flows |
| `VolvoxGrid.DotNet.dll` | Managed C# wrapper | P/Invokes the native runtime; not the grid engine itself |
| `VolvoxGrid_*.ocx` | ActiveX/COM control | Separate Windows COM adapter built from the VSFlexGrid adapter crate |
| `volvoxgrid-android-*.aar` | Android native AAR | Android wrapper plus JNI bridge and Rust runtime `.so` files |
| `volvoxgrid-android-compose-*.aar` | Android Compose AAR | Thin Compose wrapper; depends on the native Android AAR and has no native symbols of its own |
| `volvoxgrid-desktop-*.jar` | Java desktop package | Contains Java classes plus native runtimes under `native/<platform>/` |
| `volvoxgrid-desktop-lite-*.jar` | Java desktop lite package | Same Java wrapper shape, but embeds lite native runtimes |
| `VolvoxGrid*.xcframework` | iOS static-library XCFramework | Contains stripped `libvolvoxgrid.a` slices for device and simulator |
| `volvoxgrid-web-*.zip` | Web bundle | Browser demos and WASM packaging output |
| `dist/symbols/*debug-symbols.zip` | Split debug symbols | Public debug-symbol archives uploaded beside GitHub release artifacts |

Don't compare `VolvoxGrid.DotNet.dll` directly to `volvoxgrid.dll`. The former is managed glue; the latter is the native engine/runtime.

Next: the runtime features that drive the size difference.

## Runtime features

The main native runtime lives in `runtime/Cargo.toml`.

| Feature | Pulls in | Size impact | Notes |
| --- | --- | --- | --- |
| `demo` | Demo/stress data paths | Small to moderate | Kept in lite builds so samples work |
| `cosmic-text` | Built-in Rust text shaping/raster support | Moderate | Full packages use built-in text; lite uses host text fallback |
| `rayon` | Parallel execution support | Moderate | Disabled in lite |
| Regex search | Always enabled | Small | `regex::Regex` API; no look-around/backreferences |
| `gpu` | `wgpu`, `pollster`, GPU surface/rendering path, and `cosmic-text` | Large | Largest full-vs-lite size driver |
| `wasm-threads` | `wasm-bindgen-rayon` and atomics flow | WASM-specific | Requires browser COOP/COEP at runtime |

### Feature groups

```text
default       = standard + demo
standard      = cosmic-text + rayon
gpu           = cosmic-text + engine/gpu + pollster + wgpu
wasm-default  = demo
```

The Docker desktop/.NET full native runtime uses:

```bash
cargo build --release --features gpu
```

Because Cargo default features remain enabled, that means:

```text
demo + cosmic-text + rayon + gpu + wgpu + pollster
```

The lite native runtime uses:

```bash
cargo build --release --no-default-features --features demo
```

Which disables:

```text
cosmic-text, rayon, gpu, wgpu, pollster
```

Lite is still not tiny because it contains the core Rust runtime bridge, protobuf/prost encoding, the engine core, CPU raster support, demo support, and platform runtime code.

Next: ActiveX is built from a different crate and follows different rules.

## ActiveX features

ActiveX is built from `adapters/vsflexgrid/crate/Cargo.toml`, not from the same runtime crate used by Java desktop and .NET.

The packaged ActiveX release artifacts use these modes:

| Artifact | Build features | Notes |
| --- | --- | --- |
| `VolvoxGrid_*.ocx` | default: `demo + rayon` | CPU/COM ActiveX control |
| `VolvoxGrid_*.lite.ocx` | `--no-default-features --features lite` | No rayon |

That's why a normal OCX is much smaller than a normal runtime DLL: the normal OCX packaged by Docker isn't the GPU runtime. It's a CPU ActiveX adapter.

The OCX PE export table only exposes COM DLL entry points:

```text
DllCanUnloadNow
DllGetClassObject
DllRegisterServer
DllUnregisterServer
```

Its user-facing API is COM/ActiveX, not a large native C export table.

Next: capability matrix and host text fallback.

## Full vs lite behavior

| Capability | Full runtime | Lite runtime |
| --- | --- | --- |
| CPU rendering | Yes | Yes |
| Built-in Rust text engine | Yes | No |
| Host text fallback | Optional/host-dependent | Required by wrappers |
| Native GPU renderer | Yes | No |
| Regex search | Yes | Yes |
| Rayon parallelism | Yes | No |
| Demo/stress sample data | Yes | Yes |

Wrapper-specific host text fallback (this is what your wrapper has to supply when you ship lite):

| Wrapper | Lite text fallback |
| --- | --- |
| .NET WinForms | GDI/GDI+ host text fallback |
| Java desktop | Java2D host text fallback |
| Web lite | Browser Canvas2D text fallback |
| Apple platforms | OS text fallback, including CoreText where applicable |

Next: split debug symbols so you can still resolve crashes from a stripped build.

## Split debug symbols

`make docker_all VOLVOXGRID_VERSION=0.8.11` builds release binaries with line-table debug information, extracts that information into separate archives under `dist/symbols/`, then strips the production binaries that get packaged into Maven, GitHub release, .NET, and Apple artifacts.

The production artifacts stay thin. The symbol archives are only for post-mortem debugging, crash reports, and address-to-source-line resolution.

| Platform/package | Production artifact | Debug-symbol artifact |
| --- | --- | --- |
| Android native AAR | Stripped `jni/<abi>/*.so` | `.so.debug` files in `volvoxgrid-android*-debug-symbols.zip` |
| Java desktop JAR | Stripped `native/<platform>/*` | ELF/PE `.debug` files and macOS `.dSYM` bundles |
| .NET WinForms output | Stripped `volvoxgrid.dll`; no PDBs in `dist/dotnet/` | Managed `.pdb` files inside the desktop debug-symbol archive |
| ActiveX OCX | Stripped `VolvoxGrid_*.ocx` | `.ocx.debug` files in `volvoxgrid-activex-*-debug-symbols.zip` |
| iOS XCFramework | Stripped static `libvolvoxgrid.a` slices | Unstripped `libvolvoxgrid.a.unstripped` per XCFramework slice |
| Android Compose AAR | Thin wrapper, no native runtime | No separate native debug symbols |
| WASM/web | Optimized WASM bundle | No split debug-symbol archive in the current Docker build |

For iOS, the debug-symbol archive intentionally stores unstripped static archives instead of `.dSYM` bundles. In this Docker cross-build, the final deliverable is a static library archive, so the unstripped `.a` per slice is the practical symbol artifact that matches the stripped production `.a`.

`make publish_github` always uploads matching files from:

```text
dist/symbols/*<version>*debug-symbols.zip
```

No `publish_*` target is required to validate a local `dist/` tree. Publishing only creates or updates remote package/release entries.

Next: actual measured sizes from a 0.8.11 build.

## Example native runtime sizes

Sizes below are uncompressed native files inside the Java desktop JARs, measured with:

```bash
unzip -l dist/maven/volvoxgrid-desktop-0.8.11.jar 'native/*/*'
unzip -l dist/maven/volvoxgrid-desktop-lite-0.8.11.jar 'native/*/*'
```

| Target | Full native runtime | Lite native runtime |
| --- | ---: | ---: |
| `linux-aarch64/libvolvoxgrid.so` | 5.9 MiB | 2.1 MiB |
| `linux-armv7/libvolvoxgrid.so` | 5.3 MiB | 1.9 MiB |
| `linux-x86/libvolvoxgrid.so` | 7.3 MiB | 2.6 MiB |
| `linux-x86_64/libvolvoxgrid.so` | 7.0 MiB | 2.5 MiB |
| `macos-aarch64/libvolvoxgrid.dylib` | 8.3 MiB | 3.1 MiB |
| `macos-x86_64/libvolvoxgrid.dylib` | 9.3 MiB | 3.5 MiB |
| `windows-x86/volvoxgrid.dll` | 9.3 MiB | 3.1 MiB |
| `windows-x86_64/volvoxgrid.dll` | 9.4 MiB | 3.1 MiB |

Compressed JAR sizes from the same build:

| Artifact | Size |
| --- | ---: |
| `volvoxgrid-desktop-0.8.11.jar` | 27 MiB |
| `volvoxgrid-desktop-lite-0.8.11.jar` | 10 MiB |

The macOS native rows are lower than older builds because Docker now runs `llvm-strip` on packaged `.dylib` files after Zig cross-linking.

## Example Android, iOS, and WASM sizes

Android sizes from `dist/maven/`:

| Artifact | Size | Notes |
| --- | ---: | --- |
| `volvoxgrid-android-0.8.11.aar` | 6.8 MiB | `arm64-v8a` and `armeabi-v7a` native runtimes |
| `volvoxgrid-android-lite-0.8.11.aar` | 3.8 MiB | Lite native runtimes |
| `volvoxgrid-android-compose-0.8.11.aar` | 11 KiB | Thin Compose wrapper |
| `volvoxgrid-android-compose-lite-0.8.11.aar` | 11 KiB | Thin Compose wrapper for lite |

Uncompressed Android native runtime sizes inside the AARs:

| Target | Full native runtime | Lite native runtime |
| --- | ---: | ---: |
| `arm64-v8a` | 5.9 MiB | 2.0 MiB |
| `armeabi-v7a` | 3.8 MiB | 1.3 MiB |

iOS static-library sizes from `dist/ios/`:

| Artifact slice | Full | Lite |
| --- | ---: | ---: |
| `ios-arm64/libvolvoxgrid.a` | 5.2 MiB | 3.8 MiB |
| `ios-arm64_x86_64-simulator/libvolvoxgrid.a` | 10 MiB | 7.6 MiB |
| `VolvoxGrid.xcframework.zip` | 5.1 MiB | 3.6 MiB |

WASM and web bundle sizes:

| Artifact | Size |
| --- | ---: |
| `dist/wasm/volvoxgrid_wasm_bg.wasm` | 2.6 MiB |
| `dist/wasm-lite/volvoxgrid_wasm_bg.wasm` | 1.4 MiB |
| `volvoxgrid-web-0.8.11.zip` | 1.7 MiB |
| `volvoxgrid-web-lite-0.8.11.zip` | 1.2 MiB |

## Example .NET and ActiveX sizes

These files are from `dist/dotnet/` and `dist/desktop/ocx/`.

| Artifact | Full | Lite |
| --- | ---: | ---: |
| `.NET x64 native runtime`, `volvoxgrid.dll` | 9.4 MiB | 3.1 MiB |
| `.NET x86 native runtime`, `volvoxgrid.dll` | 9.3 MiB | 3.1 MiB |
| `.NET managed wrapper`, `VolvoxGrid.DotNet.dll` | 574 KiB | 574 KiB |
| `ActiveX x64 OCX`, `VolvoxGrid_x86_64*.ocx` | 1.9 MiB | 1.8 MiB |
| `ActiveX x86 OCX`, `VolvoxGrid_i686*.ocx` | 1.9 MiB | 1.8 MiB |
| `VolvoxGrid.DotNet.0.8.11.nupkg` | n/a | n/a |

`make docker_all` does not produce the `.nupkg` for 0.8.11; `dist/nuget/` still has the 0.8.10 archive (25 MiB full, 8.3 MiB lite). Run `make dotnet-pack VOLVOXGRID_VERSION=0.8.11` separately to refresh it.

The managed .NET wrapper is almost unchanged between full and lite because the feature difference lives in the native runtime beside it.

## Example debug-symbol archive sizes

These are the public symbol archives produced in `dist/symbols/` by the same Docker build.

| Symbol archive | Size | Contains |
| --- | ---: | --- |
| `volvoxgrid-android-0.8.11-debug-symbols.zip` | 14 MiB | Android full `.so.debug` files |
| `volvoxgrid-android-lite-0.8.11-debug-symbols.zip` | 5.7 MiB | Android lite `.so.debug` files |
| `volvoxgrid-desktop-0.8.11-debug-symbols.zip` | 58 MiB | Desktop native symbols, macOS `.dSYM`, and .NET PDBs |
| `volvoxgrid-desktop-lite-0.8.11-debug-symbols.zip` | 22 MiB | Desktop lite native symbols and macOS `.dSYM` |
| `volvoxgrid-activex-0.8.11-debug-symbols.zip` | 6.1 MiB | Full and lite OCX `.debug` files |
| `VolvoxGrid-0.8.11-debug-symbols.zip` | 22 MiB | iOS full unstripped static archives |
| `VolvoxGridLite-0.8.11-debug-symbols.zip` | 15 MiB | iOS lite unstripped static archives |

Next: where the bytes actually go.

## Why full runtime DLLs are around 10 MB

The full native runtime is large mostly because of compiled native code, read-only data, and unwind metadata, not debug symbols. The numbers below were measured on a fresh local Linux x86_64 build of `runtime/` because section-level inspection is most straightforward on ELF; the *shape* of the breakdown is the same on macOS Mach-O and Windows PE, with PE adding ~1–2 MiB of extra `.pdata`/`.xdata`/`.idata` overhead.

### Section-level deltas on Linux x86_64

Measured with `readelf -S` on stripped `libvolvoxgrid.so` built with `--features gpu` versus `--no-default-features --features demo`:

| Section | Full | Lite | Delta | What lives here |
| --- | ---: | ---: | ---: | --- |
| `.text` | 4.09 MiB | 1.59 MiB | +2.50 MiB | Machine code |
| `.rodata` | 745 KiB | 183 KiB | +562 KiB | Strings, tables, font tables |
| `.data.rel.ro` | 301 KiB | 60 KiB | +241 KiB | vtables for trait objects |
| `.eh_frame` | 416 KiB | 186 KiB | +230 KiB | Residual unwind tables from C deps and CRT (Rust-side dropped via `force-unwind-tables=no`) |
| On-disk total | 6.30 MiB | 2.27 MiB | +4.03 MiB | |

Windows DLLs land near 10 MiB / 3 MiB because PE metadata (`.pdata`, `.xdata`, import tables) adds more on top.

### Per-crate `.text` contribution (full unstripped)

Aggregated from `nm --print-size --size-sort` on the unstripped runtime, grouping by the top crate name in each demangled Itanium symbol. These are the crates that appear only in full, or grow noticeably from full to lite:

| Crate | Full `.text` | Lite `.text` | Delta | Why it is there |
| --- | ---: | ---: | ---: | --- |
| `naga` | 489 KiB | 0 | +489 KiB | wgpu shader compiler (WGSL/SPIR-V/GLSL/MSL/HLSL) |
| `wgpu_core` | 210 KiB | 0 | +210 KiB | wgpu state tracking and frontends |
| `wgpu_hal` | 138 KiB | 0 | +138 KiB | wgpu HAL backends (Vulkan, GLES, DX12, Metal) |
| `skrifa` | 128 KiB | 0 | +128 KiB | Font outline and hinting |
| `zeno` | 122 KiB | 0 | +122 KiB | Vector path rendering for cosmic-text |
| `volvoxgrid_engine` | 635 KiB | 519 KiB | +116 KiB | Engine GPU code paths |
| `rustybuzz` | 103 KiB | 0 | +103 KiB | OpenType shaper |
| `read_fonts` | 101 KiB | 0 | +101 KiB | Font table parsing |
| `regex_lite` | ~60 KiB | ~60 KiB | 0 | Lightweight regex; present in both variants |
| `ttf_parser` | 75 KiB | 0 | +75 KiB | TTF/OTF parser |
| `ash` | 49 KiB | 0 | +49 KiB | Vulkan bindings |
| `rayon` + `rayon_core` | 36 KiB | 0 | +36 KiB | Data parallelism |
| `swash` | 35 KiB | 0 | +35 KiB | Glyph rendering |
| `hashbrown` | 170 KiB | 62 KiB | +108 KiB | HashMaps monomorphized over wgpu/cosmic types |
| `core` | 424 KiB | 229 KiB | +195 KiB | `Map`/`Chain`/`Vec::drop` instances spawned by wgpu/text |
| `alloc` | 214 KiB | 89 KiB | +125 KiB | Same spillover from generic instantiations |

`prost` (~100 KiB) is roughly equal in both variants; it is the protobuf encoder used by the FFI surface, not a full/lite delta.

### Roll-up by subsystem

The 4.09 MiB delta is dominated by four subsystems pulled in by `--features gpu` (which transitively enables `cosmic-text`):

| Subsystem | Contribution | Notes |
| --- | ---: | --- |
| GPU stack (wgpu, naga, wgpu_hal, ash, glow, libloading, bytemuck) | ~1.4 MiB | `naga` alone is ~490 KiB because it compiles to every backend |
| Text shaping and rendering (cosmic-text, swash, rustybuzz, ttf_parser, read_fonts, skrifa, zeno, unicode-*) | ~900 KiB | Plus ~200 KiB of rodata for Unicode tables |
| Regex (regex-lite) | 0 (present in both) | Lightweight backtracking engine; no DFA or Unicode property data |
| Rayon (rayon, rayon_core, crossbeam) | ~150 KiB | |
| Monomorphization spillover in `core`/`alloc`/`hashbrown` driven by the above | ~430 KiB | Generic `Vec::drop`, `HashMap` instantiated over wgpu/text types |
| Residual unwind tables (`.eh_frame` from C deps + CRT) | ~235 KiB delta | Rust-side unwind metadata dropped via `force-unwind-tables=no` in `.cargo/config.toml` |
| vtables (`.data.rel.ro`) for the dyn-trait-heavy wgpu HAL layer | ~240 KiB | Shrinks when only one wgpu backend is enabled |
| Misc (png, libloading, smallvec growth, indexmap, etc.) | ~150 KiB | |

### Reproducing the measurements

Use these commands to re-measure after each refactor step:

```bash
# Build full and lite unstripped, side by side
CARGO_PROFILE_RELEASE_STRIP=false CARGO_PROFILE_RELEASE_DEBUG=1 \
  cargo build --release -p volvoxgrid-runtime --features gpu
cp target/release/libvolvoxgrid.so /tmp/lvg-full.so

CARGO_PROFILE_RELEASE_STRIP=false CARGO_PROFILE_RELEASE_DEBUG=1 \
  cargo build --release -p volvoxgrid-runtime --no-default-features --features demo
cp target/release/libvolvoxgrid.so /tmp/lvg-lite.so

# Section deltas
readelf -S -W /tmp/lvg-full.so | grep -E '\.text|\.rodata|\.eh_frame|\.data.rel'
readelf -S -W /tmp/lvg-lite.so | grep -E '\.text|\.rodata|\.eh_frame|\.data.rel'

# Per-crate .text contribution from demangled symbols
nm --print-size --size-sort --radix=d /tmp/lvg-full.so \
  | awk '($3=="t"||$3=="T") && $4 ~ /^_ZN/ {
      sym=$4; sub(/^_ZN/,"",sym);
      if (match(sym,/^[0-9]+/)) { l=substr(sym,RSTART,RLENGTH)+0;
        name=substr(sym,RSTART+RLENGTH,l); }
      else name="?";
      b[name]+=$2+0.0
    } END { for (n in b) printf "%10.0f  %s\n", b[n], n }' \
  | sort -rn | head -30

# Feature tree for finding disabled backends
cargo tree -e features -p volvoxgrid-runtime --features gpu | grep -E 'wgpu|naga'
```

### Remaining levers

VolvoxGrid is meant to render every script worldwide, so text shaping (cosmic-text + rustybuzz + swash) and the GPU stack (wgpu + naga) are non-negotiable on the full build. The remaining levers are real refactors, not flag flips.

Before reading the list, note one false lead: **setting `wgpu = { default-features = false, features = [ ... ] }` from outside wgpu does not trim `naga`** on wgpu 24. wgpu-hal already gates each naga writer on `cfg(target_os = ...)` via the `*-if-target-*` features (`hlsl-out-if-target-windows`, `msl-out-if-target-apple`), so wrong-platform writers produce zero machine code already. And `gles` + `vulkan` on Linux/Android are pulled in by wgpu's own `[target.'cfg(unix, not(apple))'.dependencies.wgc]` table, which downstream Cargo features cannot suppress. The 489 KiB of `naga` on the Linux full build is the minimum for the Vulkan + GLES backends Linux GPUs actually use. Dropping `naga` requires either dropping a backend (and losing GPU support on machines that need it) or patching wgpu via `[patch.crates-io]` to remove its target tables — neither is a flag flip.

The levers worth a real refactor:

1. Swap `cosmic-text` + `rustybuzz` + `swash` for `ttf-parser` + `ab_glyph`. Saves ~750 KiB but **breaks complex-script shaping** (Arabic/Hebrew/Indic/Thai). Only viable if you ship a Latin/CJK-only build variant.
2. Drop a GPU backend you do not need on a specific platform — e.g., ship Vulkan-only on Linux without the GLES fallback. Saves ~110 KiB by dropping `glsl-out`. Requires patching wgpu's target-conditional `wgc` dep or vendoring it.
3. Trim the residual ~416 KiB of `.eh_frame` that survives `force-unwind-tables=no`. The remainder comes from C deps (`cc` crate, CRT startup); a nightly toolchain with `-Z build-std-features=panic_immediate_abort` plus linker-script tweaks could push it lower.
4. The `core`/`alloc`/`hashbrown` spillover (~430 KiB of the full-vs-lite delta) is downstream of the lite/full split itself. It shrinks automatically as text generics leave the build. Do not chase it separately.

## Why OCX is smaller than a runtime DLL

The packaged normal OCX isn't built with the same feature set as the normal runtime DLL.

```text
normal runtime DLL = default features + gpu
normal OCX         = demo + rayon, CPU/COM adapter
lite runtime DLL   = demo only
lite OCX           = ActiveX lite feature, no rayon
```

So the OCX has an API, but it's a COM API, and the packaged OCX doesn't pull in the `wgpu` runtime stack that makes the full native runtime DLL large.

## Platform size notes

The same feature set can produce different sizes across OS/CPU targets.

Common reasons:

| Target difference | Effect |
| --- | --- |
| ELF vs PE vs Mach-O | Different relocation, unwind, export, and link metadata |
| x86/x86_64 vs ARM | Different instruction density and ABI metadata |
| Dynamic system libraries | Linux can leave more support in libc/libm/libgcc |
| Windows PE unwind sections | `.pdata` and `.xdata` add metadata |
| macOS Mach-O link metadata | `__LINKEDIT` can be large if symbols aren't stripped |

If a macOS dylib is unexpectedly large, check whether it was post-stripped with `llvm-strip`. Older Zig-based macOS cross-builds can retain large Mach-O symbol metadata because Zig 0.13 rejects Darwin `-exported_symbols_list`.

Next: commands for poking around inside a build.

## Inspection commands

Show JAR embedded native file sizes:

```bash
unzip -l dist/maven/volvoxgrid-desktop-0.8.11.jar 'native/*/*'
unzip -l dist/maven/volvoxgrid-desktop-lite-0.8.11.jar 'native/*/*'
```

Show local distribution sizes:

```bash
du -ah dist | sort -h
```

Validate local package archive integrity:

```bash
find dist/maven dist/web dist/symbols -type f \
  \( -name '*.jar' -o -name '*.aar' -o -name '*.zip' \) \
  -print0 | xargs -0 sh -c 'for f do unzip -tq "$f" || exit 1; done' sh
```

Verify embedded versions in native release artifacts:

```bash
bash scripts/verify_embedded_version.sh 0.8.11 \
  dist/maven/volvoxgrid-android-0.8.11.aar \
  dist/maven/volvoxgrid-android-lite-0.8.11.aar \
  dist/maven/volvoxgrid-desktop-0.8.11.jar \
  dist/maven/volvoxgrid-desktop-lite-0.8.11.jar \
  dist/ios/VolvoxGrid.xcframework \
  dist/ios/VolvoxGridLite.xcframework \
  dist/dotnet/winforms_release/volvoxgrid.dll \
  dist/dotnet/winforms_release_x86/volvoxgrid.dll \
  dist/dotnet/winforms_release_lite/volvoxgrid.dll \
  dist/dotnet/winforms_release_lite_x86/volvoxgrid.dll \
  dist/desktop/ocx/VolvoxGrid_i686.ocx \
  dist/desktop/ocx/VolvoxGrid_x86_64.ocx \
  dist/desktop/ocx/VolvoxGrid_i686.lite.ocx \
  dist/desktop/ocx/VolvoxGrid_x86_64.lite.ocx
```

Inspect Windows section sizes:

```bash
x86_64-w64-mingw32-objdump -h dist/dotnet/winforms_release/volvoxgrid.dll
x86_64-w64-mingw32-objdump -h dist/dotnet/winforms_release_lite/volvoxgrid.dll
x86_64-w64-mingw32-objdump -h dist/desktop/ocx/VolvoxGrid_x86_64.ocx
```

Inspect Linux section sizes:

```bash
unzip -p dist/maven/volvoxgrid-desktop-0.8.11.jar \
  native/linux-x86_64/libvolvoxgrid.so > /tmp/libvolvoxgrid.so
readelf -S -W /tmp/libvolvoxgrid.so
```

Inspect macOS Mach-O sections:

```bash
unzip -p dist/maven/volvoxgrid-desktop-0.8.11.jar \
  native/macos-aarch64/libvolvoxgrid.dylib > /tmp/libvolvoxgrid.dylib
llvm-objdump --macho --private-headers /tmp/libvolvoxgrid.dylib
```

Next: the build commands themselves.

## Build commands

Build everything:

```bash
make docker_all VOLVOXGRID_VERSION=0.8.11
```

Build Java desktop full and lite artifacts:

```bash
make docker_desktop VOLVOXGRID_VERSION=0.8.11
```

Build only Java desktop lite:

```bash
make docker_desktop_lite VOLVOXGRID_VERSION=0.8.11
```

Build ActiveX variants locally:

```bash
make activex-release
make activex-lite-release
```

Build .NET sample/runtime locally:

```bash
make dotnet-smoke-release
make dotnet-smoke-release VOLVOXGRID_VARIANT=lite
```
