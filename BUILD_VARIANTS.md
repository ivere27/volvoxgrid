# Build Variants and Binary Sizes

This document explains the VolvoxGrid full, lite, .NET, Java desktop, WASM,
and ActiveX build variants, and why their binary sizes differ.

Binary sizes are examples, not compatibility guarantees. They change with Rust,
Zig/MinGW, LLVM, target OS ABI, enabled features, link-time optimization, and
post-build stripping.

The example sizes below come from a `0.8.8-SNAPSHOT` Docker build inspected on
2026-05-10.

## Artifact Types

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

Do not compare `VolvoxGrid.DotNet.dll` directly to `volvoxgrid.dll`. The former
is managed glue; the latter is the native engine/runtime.

## Runtime Features

The main native runtime is `runtime/Cargo.toml`.

| Feature | Pulls in | Size impact | Notes |
| --- | --- | --- | --- |
| `demo` | Demo/stress data paths | Small to moderate | Kept in lite builds so samples work |
| `cosmic-text` | Built-in Rust text shaping/raster support | Moderate | Full packages use built-in text; lite uses host text fallback |
| `rayon` | Parallel execution support | Moderate | Disabled in lite |
| `regex` | Regex search support | Moderate | Disabled in lite |
| `gpu` | `wgpu`, `pollster`, GPU surface/rendering path, and `cosmic-text` | Large | Largest full-vs-lite size driver |
| `wasm-threads` | `wasm-bindgen-rayon` and atomics flow | WASM-specific | Requires browser COOP/COEP at runtime |

The runtime feature groups are:

```text
default       = standard + demo
standard      = cosmic-text + rayon + regex
gpu           = cosmic-text + engine/gpu + pollster + wgpu
wasm-default  = regex + demo
```

The Docker desktop/.NET full native runtime uses:

```bash
cargo build --release --features gpu
```

Because Cargo default features remain enabled, this means:

```text
demo + cosmic-text + rayon + regex + gpu + wgpu + pollster
```

The lite native runtime uses:

```bash
cargo build --release --no-default-features --features demo
```

That disables:

```text
cosmic-text, rayon, regex, gpu, wgpu, pollster
```

Lite is still not tiny because it still contains the core Rust runtime bridge,
protobuf/prost encoding, the engine core, CPU raster support, demo support, and
platform runtime code.

## ActiveX Features

ActiveX is built from `adapters/vsflexgrid/crate/Cargo.toml`, not from the same
runtime crate used by Java desktop and .NET.

The packaged ActiveX release artifacts use these modes:

| Artifact | Build features | Notes |
| --- | --- | --- |
| `VolvoxGrid_*.ocx` | default: `demo + rayon + regex` | CPU/COM ActiveX control |
| `VolvoxGrid_*.lite.ocx` | `--no-default-features --features lite` | No rayon/regex |

This is why a normal OCX is much smaller than a normal runtime DLL: the normal
OCX packaged by Docker is not the GPU runtime. It is a CPU ActiveX adapter.

The OCX PE export table only exposes COM DLL entry points:

```text
DllCanUnloadNow
DllGetClassObject
DllRegisterServer
DllUnregisterServer
```

Its user-facing API is COM/ActiveX, not a large native C export table.

## Full vs Lite Behavior

| Capability | Full runtime | Lite runtime |
| --- | --- | --- |
| CPU rendering | Yes | Yes |
| Built-in Rust text engine | Yes | No |
| Host text fallback | Optional/host-dependent | Required by wrappers |
| Native GPU renderer | Yes | No |
| Regex search | Yes | No |
| Rayon parallelism | Yes | No |
| Demo/stress sample data | Yes | Yes |

Wrapper-specific host text fallback:

| Wrapper | Lite text fallback |
| --- | --- |
| .NET WinForms | GDI/GDI+ host text fallback |
| Java desktop | Java2D host text fallback |
| Web lite | Browser Canvas2D text fallback |
| Apple platforms | OS text fallback, including CoreText where applicable |

## Split Debug Symbols

`make docker_all VOLVOXGRID_VERSION=0.8.8-SNAPSHOT` builds release binaries with
line-table debug information, extracts that information into separate archives
under `dist/symbols/`, then strips the production binaries that are packaged
into Maven, GitHub release, .NET, and Apple artifacts.

The production artifacts stay thin. The symbol archives are only for
post-mortem debugging, crash reports, and address-to-source-line resolution.

| Platform/package | Production artifact | Debug-symbol artifact |
| --- | --- | --- |
| Android native AAR | Stripped `jni/<abi>/*.so` | `.so.debug` files in `volvoxgrid-android*-debug-symbols.zip` |
| Java desktop JAR | Stripped `native/<platform>/*` | ELF/PE `.debug` files and macOS `.dSYM` bundles |
| .NET WinForms output | Stripped `volvoxgrid.dll`; no PDBs in `dist/dotnet/` | Managed `.pdb` files inside the desktop debug-symbol archive |
| ActiveX OCX | Stripped `VolvoxGrid_*.ocx` | `.ocx.debug` files in `volvoxgrid-activex-*-debug-symbols.zip` |
| iOS XCFramework | Stripped static `libvolvoxgrid.a` slices | Unstripped `libvolvoxgrid.a.unstripped` per XCFramework slice |
| Android Compose AAR | Thin wrapper, no native runtime | No separate native debug symbols |
| WASM/web | Optimized WASM bundle | No split debug-symbol archive in the current Docker build |

For iOS, the debug-symbol archive intentionally stores unstripped static
archives instead of `.dSYM` bundles. In this Docker cross-build, the final
deliverable is a static library archive, so the unstripped `.a` per slice is the
practical symbol artifact that matches the stripped production `.a`.

`make publish_github` always uploads matching files from:

```text
dist/symbols/*<version>*debug-symbols.zip
```

No `publish_*` target is required to validate a local `dist/` tree. Publishing
only creates or updates remote package/release entries.

## Example Native Runtime Sizes

Sizes below are uncompressed native files inside the Java desktop JARs, measured
with:

```bash
unzip -l dist/maven/volvoxgrid-desktop-0.8.8-SNAPSHOT.jar 'native/*/*'
unzip -l dist/maven/volvoxgrid-desktop-lite-0.8.8-SNAPSHOT.jar 'native/*/*'
```

| Target | Full native runtime | Lite native runtime |
| --- | ---: | ---: |
| `linux-aarch64/libvolvoxgrid.so` | 6.9 MiB | 1.9 MiB |
| `linux-armv7/libvolvoxgrid.so` | 6.1 MiB | 1.8 MiB |
| `linux-x86/libvolvoxgrid.so` | 8.2 MiB | 2.4 MiB |
| `linux-x86_64/libvolvoxgrid.so` | 8.1 MiB | 2.3 MiB |
| `macos-aarch64/libvolvoxgrid.dylib` | 9.1 MiB | 3.0 MiB |
| `macos-x86_64/libvolvoxgrid.dylib` | 10.3 MiB | 3.3 MiB |
| `windows-x86/volvoxgrid.dll` | 10.0 MiB | 2.9 MiB |
| `windows-x86_64/volvoxgrid.dll` | 10.3 MiB | 3.0 MiB |

Compressed JAR sizes from the same build:

| Artifact | Size |
| --- | ---: |
| `volvoxgrid-desktop-0.8.8-SNAPSHOT.jar` | 30 MiB |
| `volvoxgrid-desktop-lite-0.8.8-SNAPSHOT.jar` | 9.6 MiB |

The macOS native rows are lower than older builds because Docker now runs
`llvm-strip` on packaged `.dylib` files after Zig cross-linking.

## Example Android, iOS, and WASM Sizes

Android sizes from `dist/maven/`:

| Artifact | Size | Notes |
| --- | ---: | --- |
| `volvoxgrid-android-0.8.8-SNAPSHOT.aar` | 7.3 MiB | `arm64-v8a` and `armeabi-v7a` native runtimes |
| `volvoxgrid-android-lite-0.8.8-SNAPSHOT.aar` | 3.6 MiB | Lite native runtimes |
| `volvoxgrid-android-compose-0.8.8-SNAPSHOT.aar` | 12 KiB | Thin Compose wrapper |
| `volvoxgrid-android-compose-lite-0.8.8-SNAPSHOT.aar` | 12 KiB | Thin Compose wrapper for lite |

Uncompressed Android native runtime sizes inside the AARs:

| Target | Full native runtime | Lite native runtime |
| --- | ---: | ---: |
| `arm64-v8a` | 6.8 MiB | 1.9 MiB |
| `armeabi-v7a` | 4.5 MiB | 1.3 MiB |

iOS static-library sizes from `dist/ios/`:

| Artifact slice | Full | Lite |
| --- | ---: | ---: |
| `ios-arm64/libvolvoxgrid.a` | 6.1 MiB | 3.7 MiB |
| `ios-arm64_x86_64-simulator/libvolvoxgrid.a` | 12 MiB | 7.3 MiB |

WASM and web bundle sizes:

| Artifact | Size |
| --- | ---: |
| `dist/wasm/volvoxgrid_wasm_bg.wasm` | 3.3 MiB |
| `dist/wasm-lite/volvoxgrid_wasm_bg.wasm` | 1.3 MiB |
| `volvoxgrid-web-0.8.8-SNAPSHOT.zip` | 1.7 MiB |
| `volvoxgrid-web-lite-0.8.8-SNAPSHOT.zip` | 960 KiB |

## Example .NET and ActiveX Sizes

These files are from `dist/dotnet/` and `dist/desktop/ocx/`.

| Artifact | Full | Lite |
| --- | ---: | ---: |
| `.NET x64 native runtime`, `volvoxgrid.dll` | 10.3 MiB | 3.0 MiB |
| `.NET x86 native runtime`, `volvoxgrid.dll` | 10.0 MiB | 2.9 MiB |
| `.NET managed wrapper`, `VolvoxGrid.DotNet.dll` | 539 KiB | 539 KiB |
| `ActiveX x64 OCX`, `VolvoxGrid_x86_64*.ocx` | 2.7 MiB | 1.7 MiB |
| `ActiveX x86 OCX`, `VolvoxGrid_i686*.ocx` | 2.6 MiB | 1.7 MiB |

The managed .NET wrapper is almost unchanged between full and lite because the
feature difference lives in the native runtime beside it.

## Example Debug-Symbol Archive Sizes

These are the public symbol archives produced in `dist/symbols/` by the same
Docker build.

| Symbol archive | Size | Contains |
| --- | ---: | --- |
| `volvoxgrid-android-0.8.8-SNAPSHOT-debug-symbols.zip` | 16 MiB | Android full `.so.debug` files |
| `volvoxgrid-android-lite-0.8.8-SNAPSHOT-debug-symbols.zip` | 5.4 MiB | Android lite `.so.debug` files |
| `volvoxgrid-desktop-0.8.8-SNAPSHOT-debug-symbols.zip` | 63 MiB | Desktop native symbols, macOS `.dSYM`, and .NET PDBs |
| `volvoxgrid-desktop-lite-0.8.8-SNAPSHOT-debug-symbols.zip` | 22 MiB | Desktop lite native symbols and macOS `.dSYM` |
| `volvoxgrid-activex-0.8.8-SNAPSHOT-debug-symbols.zip` | 6.7 MiB | Full and lite OCX `.debug` files |
| `VolvoxGrid-0.8.8-SNAPSHOT-debug-symbols.zip` | 25 MiB | iOS full unstripped static archives |
| `VolvoxGridLite-0.8.8-SNAPSHOT-debug-symbols.zip` | 15 MiB | iOS lite unstripped static archives |

## Why Full Runtime DLLs Are Around 10 MB

The full Windows runtime DLL is large mostly because of compiled native code and
read-only data, not debug symbols. In a representative x64 build:

```text
full volvoxgrid.dll:
  .text   about 7.0 MiB
  .rdata  about 2.4 MiB

lite volvoxgrid.dll:
  .text   about 2.3 MiB
  .rdata  about 426 KiB
```

The extra code/data comes primarily from:

```text
wgpu/GPU backend support
built-in text engine support
regex search
rayon parallelism
target-specific Rust std/platform support
```

## Why OCX Is Smaller Than Runtime DLL

The packaged normal OCX is not built with the same feature set as the normal
runtime DLL.

```text
normal runtime DLL = default features + gpu
normal OCX         = demo + rayon + regex, CPU/COM adapter
lite runtime DLL   = demo only
lite OCX           = ActiveX lite feature, no rayon/regex
```

So the OCX has an API, but it is a COM API and the packaged OCX does not pull in
the `wgpu` runtime stack that makes the full native runtime DLL large.

## Platform Size Notes

The same feature set can produce different sizes across OS/CPU targets.

Common reasons:

| Target difference | Effect |
| --- | --- |
| ELF vs PE vs Mach-O | Different relocation, unwind, export, and link metadata |
| x86/x86_64 vs ARM | Different instruction density and ABI metadata |
| Dynamic system libraries | Linux can leave more support in libc/libm/libgcc |
| Windows PE unwind sections | `.pdata` and `.xdata` add metadata |
| macOS Mach-O link metadata | `__LINKEDIT` can be large if symbols are not stripped |

If a macOS dylib is unexpectedly large, check whether it was post-stripped with
`llvm-strip`. Older Zig-based macOS cross-builds can retain large Mach-O symbol
metadata because Zig 0.13 rejects Darwin `-exported_symbols_list`.

## Inspection Commands

Show JAR embedded native file sizes:

```bash
unzip -l dist/maven/volvoxgrid-desktop-0.8.8-SNAPSHOT.jar 'native/*/*'
unzip -l dist/maven/volvoxgrid-desktop-lite-0.8.8-SNAPSHOT.jar 'native/*/*'
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
bash scripts/verify_embedded_version.sh 0.8.8-SNAPSHOT \
  dist/maven/volvoxgrid-android-0.8.8-SNAPSHOT.aar \
  dist/maven/volvoxgrid-android-lite-0.8.8-SNAPSHOT.aar \
  dist/maven/volvoxgrid-desktop-0.8.8-SNAPSHOT.jar \
  dist/maven/volvoxgrid-desktop-lite-0.8.8-SNAPSHOT.jar \
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
unzip -p dist/maven/volvoxgrid-desktop-0.8.8-SNAPSHOT.jar \
  native/linux-x86_64/libvolvoxgrid.so > /tmp/libvolvoxgrid.so
readelf -S -W /tmp/libvolvoxgrid.so
```

Inspect macOS Mach-O sections:

```bash
unzip -p dist/maven/volvoxgrid-desktop-0.8.8-SNAPSHOT.jar \
  native/macos-aarch64/libvolvoxgrid.dylib > /tmp/libvolvoxgrid.dylib
llvm-objdump --macho --private-headers /tmp/libvolvoxgrid.dylib
```

## Build Commands

Build everything:

```bash
make docker_all VOLVOXGRID_VERSION=0.8.8-SNAPSHOT
```

Build Java desktop full and lite artifacts:

```bash
make docker_desktop VOLVOXGRID_VERSION=0.8.8-SNAPSHOT
```

Build only Java desktop lite:

```bash
make docker_desktop_lite VOLVOXGRID_VERSION=0.8.8-SNAPSHOT
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
