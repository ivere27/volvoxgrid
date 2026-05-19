# VolvoxGrid ActiveX (OCX)

Welcome. If you've spent years writing VB6, Excel VBA, or VBScript against the classic FlexGrid OCX and you're wondering whether you can swap that control out for something modern without rewriting your forms, this adapter is for you. It packages the VolvoxGrid Rust engine as a standard COM/OLE control — a single self-contained `.ocx` you can `regsvr32` and drop into any COM-aware host. The ProgID is `VolvoxGrid.VolvoxGridCtrl`, and most of the property and method names you already know map straight through.

The other reason this adapter exists is more pragmatic. FlexGrid is battle-tested in a way no new control can claim, so we treat it as the reference oracle. Every release runs through a 36-scenario side-by-side comparison harness, pixel-diffs the renders, and surfaces gaps in VolvoxGrid that we can then prioritize. If you're a VolvoxGrid contributor, this directory is where you'll run that harness. If you're an evaluator, the same harness gives you an honest, visual answer to "does it look like FlexGrid yet?" without taking our word for it.

If you'd like to skip ahead and just see it working under Wine on Linux:

```bash
make activex-run-release
```

That builds the `x86_64` OCX, registers it in your Wine prefix, and launches the classic demo shell.

## Screenshot

<img src="../../screenshots/activex.png" alt="VolvoxGrid ActiveX demo running under Wine on Ubuntu" width="100%">

## Architecture

Here's the shape of what gets built, because it explains the trade-offs in the rest of the document. The OCX is a thin C shim that implements COM, calling through a stable C FFI into a Rust static library. There is no Rust runtime to ship and no separate engine DLL — everything links into one file.

```
┌─────────────────────────────────────────────────────────┐
│  COM Client (VB6, Excel VBA, VBScript, C++ ...)         │
│    IDispatch::Invoke(DISPID, args)                      │
│    IViewObject::Draw(hDC, ...)                          │
└──────────┬──────────────────────────────┬───────────────┘
           │                              │
     ┌─────▼──────────┐          ┌───────▼─────────┐
     │  dllexports.c  │          │ volvoxgrid_ocx.c │
     │  ClassFactory   │          │  IDispatch impl  │
     │  DllRegister    │          │  IViewObject impl│
     │  DllMain        │          │  DISPID dispatch  │
     └────────────────┘          └───────┬─────────┘
                                         │  C FFI calls
                              ┌──────────▼──────────┐
                              │  volvoxgrid_ffi_     │
                              │  native.h            │
                              │  (200+ C functions)  │
                              └──────────┬──────────┘
                                         │
                              ┌──────────▼──────────┐
                              │  Rust static lib     │
                              │  libvolvoxgrid_      │
                              │  activex.a           │
                              │                      │
                              │  ┌────────────────┐  │
                              │  │ volvoxgrid-     │  │
                              │  │ engine          │  │
                              │  │ (grid, render,  │  │
                              │  │  text, layout)  │  │
                              │  └────────────────┘  │
                              └─────────────────────┘
```

The C shim `volvoxgrid_ocx.c` handles `IDispatch` and `IViewObject` and dispatches every property and method call through the C FFI into the Rust engine, which is linked as a `.a` static library. The output is one `.ocx` file with no Rust runtime dependency, which is the only sane way to ship into VB6 and legacy COM environments.

## Directory structure

If you want to know where to look before you start changing things, here's the layout under `adapters/vsflexgrid/`.

```
adapters/vsflexgrid/
├── crate/                       Rust static library
│   ├── Cargo.toml               Package config (staticlib output)
│   └── src/
│       ├── lib.rs               Entry point, GridManager, FFI bridge
│       └── volvoxgrid_ffi_native.rs  Generated FFI trait (200+ methods)
├── include/
│   └── volvoxgrid_ffi_native.h  C header (200+ function declarations)
├── mingw/                       MinGW cross-compilation sources
│   ├── build_ocx.sh             Build script (i686 + x86_64)
│   ├── setup_mdac28.sh          One-time MDAC prefix setup helper
│   ├── run_compare_ui.sh        UI comparison test runner + HTML report
│   ├── run_compare_ux.sh        UX interaction comparison test + HTML report
│   ├── dllexports.c             DLL entry, COM class factory, self-registration
│   ├── volvoxgrid_ocx.c         COM object: IDispatch + IViewObject
│   ├── VolvoxGrid.def           DLL export table
│   ├── VolvoxGrid_guids.h       CLSID, IID, LIBID definitions
│   ├── compat_shims.c           GetHostNameW shim (MinGW gap)
│   ├── xp_compat.c              Windows XP compatibility stubs
│   ├── stub_bcryptprimitives.c  Wine stub DLL: ProcessPrng
│   ├── stub_synch.c             Wine stub DLL: WaitOnAddress family
│   ├── bcryptprimitives.def     Export def for stub DLL
│   ├── grid_capture_test.c      Single-control render test
│   ├── grid_compare_test.c      Side-by-side comparison (36 scenarios)
│   └── tests/                   VBScript test scenarios (01-36)
│       ├── 01_default.vbs
│       ├── ...
│       └── 36_unicode.vbs
└── README.md                    This file
```

## Prerequisites

You'll build this from Linux using MinGW-w64. That's the supported path; native MSVC builds aren't wired up because Wine is the cheapest way to run the comparison harness without a Windows VM.

Install the Rust cross targets:

```
rustup target add i686-pc-windows-gnu
rustup target add x86_64-pc-windows-gnu
```

Install the MinGW cross compilers:

```
sudo apt install gcc-mingw-w64-i686 gcc-mingw-w64-x86-64
```

Install Wine so you can run and register the OCX:

```
sudo apt install wine
```

ImageMagick is optional, but the capture tests write BMP and the conversion to PNG for reports is friendlier with it:

```
sudo apt install imagemagick
```

## Building

When you're ready to actually produce an `.ocx`, run the build script from the `mingw` directory. It builds both 32-bit (i686) and 64-bit (x86_64) variants in one shot.

```bash
cd adapters/vsflexgrid/mingw
./build_ocx.sh           # Debug build (both i686 and x86_64)
./build_ocx.sh release   # Release build (stripped)

# Or from the repo root, build and launch the classic demo shell under Wine
make activex-run-release
```

The `make activex-run-release` target defaults to `ACTIVEX_ARCH=x86_64`. Set `ACTIVEX_ARCH=i686` only when you specifically need the 32-bit Wine and 32-bit OCX host — VB6 IDE, older Office, that sort of thing.

Everything lands in `target/ocx/`:

| File | Description |
|------|-------------|
| `VolvoxGrid_i686.ocx` | 32-bit OCX (for 32-bit VB6, Office) |
| `VolvoxGrid_x86_64.ocx` | 64-bit OCX (for 64-bit Office) |
| `grid_capture_test_i686.exe` | Single-control render test |
| `grid_compare_test_i686.exe` | Side-by-side comparison test |
| `bcryptprimitives.dll` | Wine stub DLL (not needed on real Windows) |
| `api-ms-win-core-synch-l1-2-0.dll` | Wine stub DLL (not needed on real Windows) |

### Build flow

If something breaks mid-build, this is the order of operations so you can pick up where it failed:

```
1. cargo build --target i686-pc-windows-gnu
       → target/i686-pc-windows-gnu/debug/libvolvoxgrid_activex.a

2. i686-w64-mingw32-gcc -c dllexports.c volvoxgrid_ocx.c compat_shims.c xp_compat.c
       → .o files

3. i686-w64-mingw32-gcc -shared  \
       xp_compat.o               \  ← MUST be before Rust lib (overrides imports)
       dllexports.o               \
       volvoxgrid_ocx.o           \
       compat_shims.o             \
       libvolvoxgrid_activex.a    \
       VolvoxGrid.def             \
       -lole32 -loleaut32 ...
       → VolvoxGrid_i686.ocx
```

The link order matters. `xp_compat.o` MUST be linked before the Rust static library. It defines symbols (`__imp_ProcessPrng`, `_InitOnceBeginInitialize@16`, and friends) that override Rust's DLL import stubs, which is what lets the resulting OCX run on Windows XP without dragging in Vista, Win8, or Win10 APIs.

## Registration

Once the build finishes, register the OCX the same way you'd register any classic COM control. On the target Windows machine, or under Wine:

```
regsvr32 VolvoxGrid_i686.ocx       # Register
regsvr32 /u VolvoxGrid_i686.ocx    # Unregister
```

This writes the standard self-registration entries:

| Key | Value |
|-----|-------|
| `HKCR\CLSID\{A7E3B4D1-5C2F-4E8A-B9D6-1F3C7E2A4B5D}` | VolvoxGrid Control |
| `HKCR\CLSID\{...}\InprocServer32` | Path to OCX |
| `HKCR\CLSID\{...}\ProgID` | VolvoxGrid.VolvoxGridCtrl |
| `HKCR\VolvoxGrid.VolvoxGridCtrl\CLSID` | `{A7E3B4D1-...}` |

The ProgID is `VolvoxGrid.VolvoxGridCtrl`, so `CreateObject("VolvoxGrid.VolvoxGridCtrl")` from VB6, VBA, or VBScript will instantiate the control.

## Comparison harness

This is the part you'll spend the most time in if you're tracking compatibility. The harness drives both controls from VBScript, captures their renders, and produces an HTML report with pixel diffs. To make ADO-bound scenarios match real Windows behavior, the runners default to a Wine prefix configured with Microsoft MDAC 2.8 SP1 instead of Wine's builtin `msado15`. This is required for `CreateObject("ADODB.Recordset")` and the binding patterns legacy hosts use.

The default compare environment looks like this:

- `WINEPREFIX=$HOME/.wine`
- `WINEDLLOVERRIDES=msado15,mtxdm,odbc32,odbccp32,oledb32=n,b`

Use `$HOME/...`, not a quoted literal `~`, when setting the prefix path — Wine's argument handling is unkind to unexpanded tildes.

Typical usage:

```bash
cd adapters/vsflexgrid/mingw
./run_compare_ui.sh
./run_compare_ui.sh --data
```

Before your first compare run, prepare the Wine prefix once with MDAC:

```bash
cd adapters/vsflexgrid/mingw
MDAC28SDK_DIR=/path/to/mdac28sdk ./setup_mdac28.sh /path/to/MDAC_TYP.EXE
```

The UI compare suite includes SQL cases `84-103` by default, which need a live MSSQL server. Bring one up in Docker:

```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=sapassword12#$%" -e "MSSQL_PID=Express" -p 1433:1433 -d mcr.microsoft.com/mssql/server:2017-latest
```

`run_compare_ui.sh` verifies the MDAC and MSSQL client setup when SQL cases are selected, but it won't install anything for you — that's what `setup_mdac28.sh` is for, and you only need to run it once per prefix.

Override the SQL target with these environment variables when needed:

- `VFG_SQL_SERVER` (default `127.0.0.1,1433`)
- `VFG_SQL_DATABASE` (default `tempdb`)
- `VFG_SQL_USER` (default `sa`)
- `VFG_SQL_PASSWORD` (default `sapassword12#$%`)

The defaults match the Docker command above, so if you used that you can skip the overrides.

If the typelibs in `~/.wine` still point to `/tmp/mdac28sdk` from an earlier run, rerun `setup_mdac28.sh` with `MDAC28SDK_DIR` set so it rehomes them into `C:\windows\system32\mdac28` inside the prefix.

To override the defaults entirely:

```bash
WINEPREFIX=/path/to/prefix \
WINEDLLOVERRIDES=msado15,mtxdm,odbc32,odbccp32,oledb32=n,b \
./run_compare_ui.sh --data
```

If the default native MDAC prefix does not exist, `run_compare_ui.sh` exits with an error and asks you to supply a valid `WINEPREFIX` or `DEFAULT_NATIVE_WINEPREFIX`.

## COM interfaces

The OCX exposes two interfaces. Everything you'd recognize from a normal control — properties, indexed properties, methods — comes through `IDispatch`. Rendering is separated out into `IViewObject` because the OCX is windowless.

### IDispatch (property and method access)

Properties and methods are routed through `IDispatch::Invoke()`. `GetIDsOfNames()` maps the name your VB code uses to a stable DISPID, and the tables below are the property map: if you're wondering whether a particular FlexGrid property is wired up, find it here.

**Grid structure**

| DISPID | Name | Type | Description |
|--------|------|------|-------------|
| 1 | Rows | int | Total row count |
| 2 | Cols | int | Total column count |
| 3 | FixedRows | int | Non-scrollable header rows |
| 4 | FixedCols | int | Non-scrollable left columns |
| 5 | TextMatrix(r,c) | string | Cell text (indexed by row, col) |
| 6 | Text | string | Text of current cell |
| 7 | Row | int | Current row |
| 8 | Col | int | Current column |
| 9 | RowHeight(i) | int | Row height in twips |
| 10 | ColWidth(i) | int | Column width in twips |
| 11 | FrozenRows | int | Frozen (non-scrollable) data rows |
| 12 | FrozenCols | int | Frozen data columns |
| 14 | TopRow | int | First visible scrollable row |
| 15 | LeftCol | int | First visible scrollable column |
| 18 | Redraw | int | Enable/disable redraw (0=off, 1=on) |
| 22 | RowSel | int | Selection end row |
| 23 | ColSel | int | Selection end column |

**Appearance**

| DISPID | Name | Type | Description |
|--------|------|------|-------------|
| 16 | FocusRect | int | Focus rectangle style (0=none, 1=light, 2=heavy, 3=inset) |
| 17 | HighLight | int | Highlight mode (0=never, 1=withFocus, 2=always) |
| 24 | FillStyle | int | Fill behavior (0=single, 1=repeat) |
| 25 | WordWrap | int | Enable word wrapping |
| 27 | SelectionMode | int | Selection mode (0=free, 1=byRow, 2=byCol, 3=listBox) |
| 31 | Ellipsis | int | Text ellipsis style |
| 32 | ExtendLastCol | int | Extend last column to fill width |
| 48 | GridLines | int | Data area gridline style |
| 49 | GridLinesFixed | int | Fixed area gridline style |

**Colors** (ARGB format, e.g. `&HFFE0E0FF`)

| DISPID | Name | Description |
|--------|------|-------------|
| 40 | BackColor | Background |
| 41 | ForeColor | Text |
| 42 | GridColor | Gridline |
| 43 | BackColorFixed | Fixed area background |
| 44 | ForeColorFixed | Fixed area text |
| 45 | BackColorSel | Selection background |
| 46 | ForeColorSel | Selection text |
| 47 | BackColorAlternate | Alternate row background |
| 50 | TreeColor | Outline tree line color |

**Merge and outline**

| DISPID | Name | Type | Description |
|--------|------|------|-------------|
| 51 | MergeCells | int | Merge mode (0=none, 1=free, 2=restrict, ...) |
| 52 | MergeRow(i) | bool | Allow merge for row i |
| 53 | MergeCol(i) | bool | Allow merge for column i |
| 54 | OutlineBar | int | Outline bar style |
| 55 | OutlineCol | int | Outline grouping column |
| 56 | IsSubtotal(i) | bool | Row i is a subtotal row |
| 57 | IsCollapsed(i) | bool | Row i is collapsed |
| 33 | SubtotalPosition | int | Subtotal placement (0=above, 1=below) |

**Indexed properties**

| DISPID | Name | Type | Description |
|--------|------|------|-------------|
| 60 | ColAlignment(i) | int | Data cell alignment for column i |
| 61 | FixedAlignment(i) | int | Fixed cell alignment for column i |
| 62 | RowHidden(i) | bool | Hide row i |
| 63 | ColHidden(i) | bool | Hide column i |
| 64 | CellChecked(r,c) | int | Checkbox state |
| 65 | CellFlood(r,c) | int | Cell fill level (0-100) |

**Methods**

| DISPID | Name | Signature | Description |
|--------|------|-----------|-------------|
| 70 | Sort | Sort order, col | Sort by column |
| 71 | Subtotal | agg, groupCol, sumCol, caption, bgColor, fgColor, addCaption | Insert subtotal rows |
| 72 | AutoSize | col | Auto-size column width |
| 73 | AddItem | text [, index] | Add tab-delimited row |
| 74 | RemoveItem | index | Remove row |
| 75 | Clear | | Clear all data |
| 76 | Select | r1, c1, r2, c2 | Set selection range |
| 77 | Refresh | | Force redraw |

### IViewObject (rendering)

The host calls `Draw()` whenever the control needs to paint, passing in any device context. Internally that turns into a call to the CPU renderer (`volvox_grid_render_bgra()`), followed by a `SetDIBitsToDevice` blit of the BGRA buffer onto the target DC.

There is no GPU rendering path in ActiveX mode. The GPU backend exists in the engine but is intentionally off here because COM hosts hand us an HDC, not a window.

## Units: twips

FlexGrid measures `RowHeight` and `ColWidth` in twips, and so does this OCX. The conversion math, since you'll need it when you're debugging a layout mismatch: 1 inch = 1440 twips, and at 96 DPI that means 1 pixel = 15 twips.

The OCX converts at the boundary:

- **Put:** `pixels = (twips + 7) / 15` (rounded)
- **Get:** `twips = pixels * 15`
- The special value `-1` (auto-size) passes through unchanged.

The engine itself uses pixels internally; twips only exist at the COM surface for compatibility.

## Windows version compatibility

The OCX is a single `.ocx` with no external DLL dependencies beyond standard Windows system DLLs. Here's the story on which versions of Windows it actually runs on, because Rust's standard library imports a lot of modern APIs and we go to some trouble to neutralize them.

### Minimum: Windows XP SP2

`xp_compat.c` provides static fallback implementations for 17 APIs that Rust's stdlib imports but which don't exist on XP:

| API | Introduced | Fallback |
|-----|-----------|----------|
| `ProcessPrng` | Win10 | `advapi32!SystemFunction036` (RtlGenRandom) |
| `WaitOnAddress`, `WakeByAddress*` | Win8 | Spin-wait with `Sleep()` |
| `GetSystemTimePreciseAsFileTime` | Win8 | `GetSystemTimeAsFileTime` |
| `CompareStringOrdinal` | Vista | Manual ordinal comparison |
| `InitOnceBeginInitialize/Complete` | Vista | `InterlockedCompareExchange` spin-lock |
| `CreateWaitableTimerExW` | Vista | `CreateWaitableTimerW` |
| `CreateSymbolicLinkW` | Vista | Returns `ERROR_NOT_SUPPORTED` |
| `GetFinalPathNameByHandleW` | Vista | Returns `ERROR_NOT_SUPPORTED` |
| `Get/SetFileInformationByHandle` | Vista | Returns `ERROR_NOT_SUPPORTED` |
| `GetUserPreferredUILanguages` | Vista | Returns `"en-US"` |
| `ProcThreadAttributeList` functions | Vista | Returns `ERROR_NOT_SUPPORTED` |

How the stubbing works: `xp_compat.o` is linked before the Rust static library, and two mechanisms make the imports disappear.

1. **KERNEL32 stdcall functions.** Our C implementations (e.g. `_InitOnceBeginInitialize@16`) satisfy the symbol references before the MinGW import library is consulted, so these functions are never imported from KERNEL32.dll.

2. **raw-dylib functions** (`ProcessPrng`, `WaitOnAddress`). Rust uses `__imp_FuncName` indirect call pointers for these. We define those pointers via inline assembly so they point at our `__stdcall` implementations. The DLL imports for `bcryptprimitives.dll` and `api-ms-win-core-synch-l1-2-0.dll` disappear entirely from the PE import table.

### Remaining KERNEL32 imports (all XP-compatible)

After stubbing, the OCX only imports from ADVAPI32, GDI32, KERNEL32, msvcrt, ntdll, OLEAUT32, USER32, USERENV, and WS2_32 — all present on Windows XP. The few XP-era KERNEL32 functions used (`AddVectoredExceptionHandler`, `GetProcessId`, `SetThreadStackGuarantee`) are available on XP SP1/SP2.

### Not supported: Windows 2000 and earlier

Windows 2000 is missing roughly 21 additional KERNEL32 functions including `AddVectoredExceptionHandler` (XP+), and ntdll's `RtlCaptureContext` (XP+). Windows 95/98/ME are not possible at all — Rust's stdlib fundamentally requires NT-based Windows (Unicode W functions, `ntdll.dll`), and no amount of shimming gets you back to those kernels.

## Wine compatibility

The OCX works under Wine (tested with Wine 6.x), but older Wine versions ship without the Win8+ system DLLs that some imports resolve to, so two additional stub DLLs are built alongside the OCX:

- `bcryptprimitives.dll` — provides `ProcessPrng` via `RtlGenRandom`
- `api-ms-win-core-synch-l1-2-0.dll` — provides `WaitOnAddress`/`WakeByAddress*`

These stubs are only needed for Wine, not for real Windows, because the `xp_compat.c` stubs are already embedded in the OCX. The separate DLLs exist because older Wine loads and resolves all DLL imports before our internal stubs take effect.

To install them in a Wine prefix:

```bash
cp target/ocx/bcryptprimitives.dll ~/.wine/drive_c/windows/system32/
cp target/ocx/api-ms-win-core-synch-l1-2-0.dll ~/.wine/drive_c/windows/system32/
```

### Wine text antialiasing

Wine does not apply font smoothing to text rendered on memory DCs (`CreateCompatibleDC` + `CreateCompatibleBitmap`). Because the OCX is windowless and renders text to an offscreen buffer via GDI callbacks, text appears non-antialiased under Wine. This does not affect real Windows, where GDI correctly antialiases text on memory DCs.

The original FlexGrid control is a windowed control that renders text directly to its window DC during `WM_PAINT`, which Wine does antialias. The result is a visible text-quality difference in the comparison tests that does not exist on real Windows — keep that in mind when reading diff images.

### Wine XP mode

If you want to verify the XP compatibility story end-to-end, Wine can emulate Windows XP:

```bash
wine reg add "HKCU\Software\Wine" /v Version /t REG_SZ /d winxp /f
```

Reset to default:

```bash
wine reg add "HKCU\Software\Wine" /v Version /t REG_SZ /d win7 /f
```

## Testing

There are two test harnesses, one quick and one thorough.

### Quick capture test

The capture test is the fastest smoke check: it renders a single VolvoxGrid to a BMP and exits. If this works, the OCX is registered and the FFI is alive.

```bash
cd adapters/vsflexgrid/mingw
wine regsvr32 ../../../target/ocx/VolvoxGrid_i686.ocx
wine ../../../target/ocx/grid_capture_test_i686.exe
# Output: grid_output.bmp
```

### Visual comparison test

The comparison harness is what you want when you're tracking compatibility against FlexGrid. It runs 36 scripted scenarios in both controls and emits a side-by-side HTML report.

```bash
cd adapters/vsflexgrid/mingw
./run_compare_ui.sh               # Full UI comparison with HTML report
./run_compare_ui.sh --only-vv     # VolvoxGrid only (no reference OCX needed)
./run_compare_ui.sh --no-diff     # Skip pixel diff generation
./run_compare_ux.sh               # UX interaction comparison with HTML report
```

Output lands in `target/ocx/compare/`:

| File | Description |
|------|-------------|
| `test_NN_name_vv.png` | VolvoxGrid render |
| `test_NN_name_lg.png` | FlexGrid render |
| `test_NN_name_diff.png` | Pixel diff (red = different) |
| `report.html` | Side-by-side HTML report |

The HTML report displays a 2x2 grid per test:

```
┌──────────────┬───────────────┐
│  VBScript    │  Pixel Diff   │
├──────────────┼───────────────┤
│  FlexGrid   │  VolvoxGrid   │
└──────────────┴───────────────┘
```

### Test scenarios (36 tests)

Each scenario isolates one FlexGrid feature so a diff points unambiguously at the responsible code path. Names match the `.vbs` files in `mingw/tests/`.

| # | Name | What it tests |
|---|------|---------------|
| 01 | default | Empty grid with default settings |
| 02 | colors | BackColor, ForeColor, GridColor, selection colors |
| 03 | alternate_rows | BackColorAlternate striping |
| 04 | gridlines | GridLines / GridLinesFixed styles |
| 05 | selection_row | SelectionMode = byRow |
| 06 | selection_col | SelectionMode = byCol |
| 07 | focus_rect | FocusRect styles (none/light/heavy) |
| 08 | col_alignment | Left/center/right column alignment |
| 09 | col_widths | Custom column widths (twips) |
| 10 | row_heights | Custom row heights (twips) |
| 11 | merge_cells | MergeCells with MergeCol/MergeRow |
| 12 | word_wrap | WordWrap with multiline text |
| 13 | frozen | FrozenRows / FrozenCols |
| 14 | sort | Column sort |
| 15 | subtotals | Subtotal aggregation rows |
| 16 | checkboxes | CellChecked checkbox cells |
| 17 | cell_flood | CellFlood fill-level indicators |
| 18 | hidden | RowHidden / ColHidden |
| 19 | fixed_alignment | FixedAlignment for header cells |
| 20 | ellipsis | Text ellipsis truncation |
| 21 | extend_last_col | ExtendLastCol to fill width |
| 22 | additem | AddItem method (tab-delimited rows) |
| 23 | range_selection | Select method (range selection) |
| 24 | gridlines_inset | Inset gridline style |
| 25 | gridlines_horz | Horizontal-only gridlines |
| 26 | gridlines_vert | Vertical-only gridlines |
| 27 | outline_styles | OutlineBar tree styles |
| 28 | subtotal_above | SubtotalPosition = above |
| 29 | selection_listbox | ListBox selection mode |
| 30 | fill_style | FillStyle repeat mode |
| 31 | large_grid | Stress test (100 rows x 10 cols) |
| 32 | scrolled | Scrolled viewport (TopRow/LeftCol) |
| 33 | no_gridlines | GridLines = 0 (no lines) |
| 34 | focus_rect_inset | Inset focus rectangle |
| 35 | multi_fixed | Multiple fixed rows and columns |
| 36 | unicode | CJK, Cyrillic, Greek, symbols, mixed scripts |

Each test has a matching `.vbs` file in `mingw/tests/` that documents the VBScript equivalent of the setup — the HTML report renders that script alongside the images so you can read what produced the difference.

## Usage from VB6/VBA

If you've made it this far and you want to see the API in your own host, the code looks like classic FlexGrid because that's the whole point.

```vb
' Create instance
Dim fg As Object
Set fg = CreateObject("VolvoxGrid.VolvoxGridCtrl")

' Configure grid
fg.Rows = 10
fg.Cols = 5
fg.FixedRows = 1
fg.FixedCols = 1

' Set column widths (in twips: 1 inch = 1440 twips)
fg.ColWidth(0) = 1200    ' ~80 pixels at 96 DPI
fg.ColWidth(1) = 2400    ' ~160 pixels

' Populate cells
fg.TextMatrix(0, 1) = "Name"
fg.TextMatrix(0, 2) = "Value"
fg.TextMatrix(1, 1) = "Alpha"
fg.TextMatrix(1, 2) = "100"

' Style
fg.BackColorAlternate = &HFFF0F0F0   ' Light gray alternating rows
fg.GridLines = 1                       ' Flat gridlines
fg.FocusRect = 2                       ' Heavy focus rectangle

' Sort by column 1
fg.Sort 1, 1

' Add subtotals
fg.Subtotal 5, 1, 2, "Total", &HFFC0C0FF, &HFF000000, True
```

## GUIDs

If you're hand-rolling a registration script or referencing the type library, here are the canonical identifiers:

| Name | GUID |
|------|------|
| CLSID_VolvoxGrid | `{A7E3B4D1-5C2F-4E8A-B9D6-1F3C7E2A4B5D}` |
| IID_IVolvoxGrid | `{B8F4C5E2-6D3A-4F9B-A0E7-2A4D8F3B5C6E}` |
| LIBID_VolvoxGridLib | `{C9A5D6F3-7E4B-4A0C-B1F8-3B5E9A4C6D7F}` |
| ProgID | `VolvoxGrid.VolvoxGridCtrl` |

## Limitations

A few things are intentionally not in scope for the ActiveX adapter. Some are because COM hosting doesn't make sense for them, and some are open work.

- **No type information.** `GetTypeInfoCount()` returns 0. Design-time IntelliSense is not provided by the OCX, so VB6 IDE auto-complete on a late-bound `Object` reference won't have type hints.
- **No event sourcing.** The OCX does not fire events (e.g. `Click`, `RowColChange`). Properties and methods are read/written only — there is no outgoing dispinterface yet.
- **CPU rendering only.** `IViewObject::Draw()` uses the software renderer. The GPU renderer (`feature = "gpu"`) is not available in ActiveX mode, because the host hands us a DC, not a swap chain.
- **No embedded window.** The OCX does not create its own HWND. It renders on demand via `IViewObject::Draw()` to any DC the host provides. That keeps the integration model simple but means you can't capture native input directly from the control.
- **Wine text antialiasing.** Text appears non-antialiased under Wine because Wine does not apply font smoothing to memory DCs. On real Windows, text is properly antialiased. See [Wine text antialiasing](#wine-text-antialiasing) above.
- **Wine thread cleanup crash.** A benign page fault may occur during Wine process exit (thread cleanup). It happens after work is done and does not affect functionality, but if you're driving the harness from CI you'll want to ignore non-zero exit codes from that specific path.

## What's next

For the bigger picture — how this adapter fits alongside the Flutter, Web, .NET, Java, and Go bindings — head back to the repo root [README](../../README.md). For the engine internals, the renderer model, and how the FFI surface is generated, read [ARCHITECTURE.md](../../ARCHITECTURE.md).
