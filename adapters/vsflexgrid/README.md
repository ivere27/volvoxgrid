# VolvoxGrid ActiveX (OCX)

VolvoxGrid ActiveX is for feasibility testing against battle-tested, mature
FlexGrid OCX controls. It packages the VolvoxGrid Rust engine as a standard
COM/OLE control (`.ocx`) for VB6, VBA, VBScript, C++, or any COM-aware host,
so teams can identify current VolvoxGrid gaps and prioritize improvements.

## Architecture

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

**Key design:** A thin C shim (`volvoxgrid_ocx.c`) implements the COM interfaces
and dispatches property/method calls through a C FFI layer into the Rust engine,
which is linked as a static library (`.a`). The result is a single self-contained
`.ocx` file with no Rust runtime dependency.

## Directory Structure

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

**Linux cross-compilation (recommended):**

- Rust toolchain with cross-compilation targets:
  ```
  rustup target add i686-pc-windows-gnu
  rustup target add x86_64-pc-windows-gnu
  ```
- MinGW-w64 cross-compilers:
  ```
  sudo apt install gcc-mingw-w64-i686 gcc-mingw-w64-x86-64
  ```
- Wine (for testing):
  ```
  sudo apt install wine
  ```
- ImageMagick (optional, for BMP-to-PNG conversion):
  ```
  sudo apt install imagemagick
  ```

## Building

```bash
cd adapters/vsflexgrid/mingw
./build_ocx.sh           # Debug build (both i686 and x86_64)
./build_ocx.sh release   # Release build (stripped)

# Or from the repo root, build and launch the classic demo shell under Wine
make activex-run-release
```

The ActiveX demo runner defaults to `ACTIVEX_ARCH=x86_64`. Use `ACTIVEX_ARCH=i686` only when you need the 32-bit Wine/OCX host.

**Output** (in `target/ocx/`):

| File | Description |
|------|-------------|
| `VolvoxGrid_i686.ocx` | 32-bit OCX (for 32-bit VB6, Office) |
| `VolvoxGrid_x86_64.ocx` | 64-bit OCX (for 64-bit Office) |
| `grid_capture_test_i686.exe` | Single-control render test |
| `grid_compare_test_i686.exe` | Side-by-side comparison test |
| `bcryptprimitives.dll` | Wine stub DLL (not needed on real Windows) |
| `api-ms-win-core-synch-l1-2-0.dll` | Wine stub DLL (not needed on real Windows) |

### Build Flow

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

**Critical:** `xp_compat.o` must be linked before the Rust static library. It
defines symbols (`__imp_ProcessPrng`, `_InitOnceBeginInitialize@16`, etc.) that
override Rust's DLL import stubs, eliminating dependencies on Vista+/Win8+/Win10+ APIs.

## Registration

On the target Windows machine (or in Wine):

```
regsvr32 VolvoxGrid_i686.ocx       # Register
regsvr32 /u VolvoxGrid_i686.ocx    # Unregister
```

This creates the following registry entries:

| Key | Value |
|-----|-------|
| `HKCR\CLSID\{A7E3B4D1-5C2F-4E8A-B9D6-1F3C7E2A4B5D}` | VolvoxGrid Control |
| `HKCR\CLSID\{...}\InprocServer32` | Path to OCX |
| `HKCR\CLSID\{...}\ProgID` | VolvoxGrid.VolvoxGridCtrl |
| `HKCR\VolvoxGrid.VolvoxGridCtrl\CLSID` | `{A7E3B4D1-...}` |

**ProgID:** `VolvoxGrid.VolvoxGridCtrl`

## Comparison Harness

The UI/data comparison runners under `adapters/vsflexgrid/mingw/` now default to a Wine prefix that uses Microsoft MDAC 2.8 SP1 ADO components instead of Wine's builtin `msado15`. This is required for VBScript `CreateObject("ADODB.Recordset")` and legacy `VSFlexGrid8.VSFlexGridADO` binding behavior to match the real OCX path closely enough for comparison.

Default compare environment:

- `WINEPREFIX=$HOME/.wine`
- `WINEDLLOVERRIDES=msado15,mtxdm,odbc32,odbccp32,oledb32=n,b`

Use `$HOME/...`, not a quoted literal `~`, when setting the prefix path.

Examples:

```bash
cd adapters/vsflexgrid/mingw
./run_compare_ui.sh
./run_compare_ui.sh --data
```

Before the first compare run, prepare the prefix once:

```bash
cd adapters/vsflexgrid/mingw
MDAC28SDK_DIR=/path/to/mdac28sdk ./setup_mdac28.sh /path/to/MDAC_TYP.EXE
```

Start the MSSQL test server before running UI comparison tests that include SQL cases `84-103`. `./run_compare_ui.sh` includes them by default:

```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=sapassword12#$%" -e "MSSQL_PID=Express" -p 1433:1433 -d mcr.microsoft.com/mssql/server:2017-latest
```

`run_compare_ui.sh` verifies the MDAC/MSSQL client setup when SQL compare tests are selected, but it does not install anything for you. Prepare the prefix once with `setup_mdac28.sh` before running the live SQL cases.

Override the SQL target with `VFG_SQL_SERVER`, `VFG_SQL_DATABASE`, `VFG_SQL_USER`, and `VFG_SQL_PASSWORD` when needed. The defaults match the Docker command above: `127.0.0.1,1433`, `tempdb`, `sa`, and `sapassword12#$%`.

If the typelibs in `~/.wine` still point to `/tmp/mdac28sdk`, rerun `setup_mdac28.sh` with `MDAC28SDK_DIR` to rehome them into `C:\windows\system32\mdac28` inside the prefix.

Override the defaults when needed:

```bash
WINEPREFIX=/path/to/prefix \
WINEDLLOVERRIDES=msado15,mtxdm,odbc32,odbccp32,oledb32=n,b \
./run_compare_ui.sh --data
```

If the default native MDAC prefix does not exist, `run_compare_ui.sh` exits with an error and asks you to provide a valid `WINEPREFIX` or `DEFAULT_NATIVE_WINEPREFIX`.

## COM Interfaces

The OCX exposes two COM interfaces:

### IDispatch (Property/Method Access)

All grid properties and methods are accessed through `IDispatch::Invoke()`.
The control maps property/method names to DISPIDs via `GetIDsOfNames()`.

**Grid Structure:**

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

**Appearance:**

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

**Colors** (ARGB format, e.g. `&HFFE0E0FF`):

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

**Merge & Outline:**

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

**Indexed Properties:**

| DISPID | Name | Type | Description |
|--------|------|------|-------------|
| 60 | ColAlignment(i) | int | Data cell alignment for column i |
| 61 | FixedAlignment(i) | int | Fixed cell alignment for column i |
| 62 | RowHidden(i) | bool | Hide row i |
| 63 | ColHidden(i) | bool | Hide column i |
| 64 | CellChecked(r,c) | int | Checkbox state |
| 65 | CellFlood(r,c) | int | Cell fill level (0-100) |

**Methods:**

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

### IViewObject (Rendering)

The `Draw()` method renders the grid to any device context (HDC). Internally
it calls the CPU renderer (`volvox_grid_render_bgra()`) and blits the BGRA
pixel buffer to the target DC via `SetDIBitsToDevice`.

No GPU rendering in ActiveX mode.

## Units: Twips

Following the classic FlexGrid API convention, `RowHeight` and `ColWidth` use
**twips** (1 inch = 1440 twips). At 96 DPI: **1 pixel = 15 twips**.

The OCX converts at the boundary:
- **Put:** `pixels = (twips + 7) / 15` (rounded)
- **Get:** `twips = pixels * 15`
- Special value `-1` (auto-size) passes through unchanged.

The engine internally uses pixels.

## Windows Version Compatibility

The OCX is a single `.ocx` file with **no external DLL dependencies** beyond
standard Windows system DLLs.

### Minimum: Windows XP (SP2)

`xp_compat.c` provides static fallback implementations for 17 APIs that Rust's
standard library imports but which don't exist on XP:

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

**How it works:** The `xp_compat.o` object file is linked before the Rust
static library. Two mechanisms:

1. **KERNEL32 stdcall functions** — Our C implementations (e.g.
   `_InitOnceBeginInitialize@16`) satisfy the symbol references before the
   MinGW import library is consulted, so these functions are never imported
   from KERNEL32.dll.

2. **raw-dylib functions** (ProcessPrng, WaitOnAddress) — Rust uses
   `__imp_FuncName` indirect call pointers. We define these via inline
   assembly pointing to our `__stdcall` implementations. The DLL imports
   for `bcryptprimitives.dll` and `api-ms-win-core-synch-l1-2-0.dll`
   disappear entirely from the PE import table.

### Remaining KERNEL32 imports (all XP-compatible)

After stubbing, the OCX only imports from: ADVAPI32, GDI32, KERNEL32,
msvcrt, ntdll, OLEAUT32, USER32, USERENV, WS2_32 — all present on Windows XP.

The few XP-era KERNEL32 functions used (`AddVectoredExceptionHandler`,
`GetProcessId`, `SetThreadStackGuarantee`) are available on XP SP1/SP2.

### Not supported: Windows 2000 and earlier

Windows 2000 is missing ~21 additional KERNEL32 functions including
`AddVectoredExceptionHandler` (XP+), and ntdll's `RtlCaptureContext` (XP+).
Windows 95/98/ME are not possible — Rust's stdlib fundamentally requires
NT-based Windows (Unicode W functions, ntdll.dll).

## Wine Compatibility

The OCX works under Wine (tested with Wine 6.x). Two additional stub DLLs
are built for older Wine versions that lack Win8+ system DLLs:

- `bcryptprimitives.dll` — Provides `ProcessPrng` via `RtlGenRandom`
- `api-ms-win-core-synch-l1-2-0.dll` — Provides `WaitOnAddress`/`WakeByAddress*`

**These stubs are only needed for Wine** (not for real Windows) because the
`xp_compat.c` stubs are already embedded in the OCX. The separate DLLs exist
because older Wine loads and resolves all DLL imports before our internal stubs
take effect.

To install for Wine:
```bash
cp target/ocx/bcryptprimitives.dll ~/.wine/drive_c/windows/system32/
cp target/ocx/api-ms-win-core-synch-l1-2-0.dll ~/.wine/drive_c/windows/system32/
```

### Wine Text Antialiasing

Wine does not apply font smoothing (antialiasing) to text rendered on memory
DCs (`CreateCompatibleDC` + `CreateCompatibleBitmap`). Since the OCX is
windowless and renders text to an offscreen buffer via GDI callbacks, text
appears non-antialiased under Wine. This does not affect real Windows, where
GDI correctly antialiases text on memory DCs.

The original FlexGrid control is a windowed control that renders text directly
to its window DC during `WM_PAINT`, which Wine does antialias. This causes a
visible text quality difference in the comparison tests that does not exist on
real Windows.

### Wine XP Mode

Wine can emulate Windows XP for testing:
```bash
wine reg add "HKCU\Software\Wine" /v Version /t REG_SZ /d winxp /f
```

Reset to default:
```bash
wine reg add "HKCU\Software\Wine" /v Version /t REG_SZ /d win7 /f
```

## Testing

### Quick Capture Test

Renders VolvoxGrid to a BMP:

```bash
cd adapters/vsflexgrid/mingw
wine regsvr32 ../../../target/ocx/VolvoxGrid_i686.ocx
wine ../../../target/ocx/grid_capture_test_i686.exe
# Output: grid_output.bmp
```

### Visual Comparison Test

Side-by-side comparison against FlexGrid OCX (36 test scenarios):

```bash
cd adapters/vsflexgrid/mingw
./run_compare_ui.sh               # Full UI comparison with HTML report
./run_compare_ui.sh --only-vv     # VolvoxGrid only (no reference OCX needed)
./run_compare_ui.sh --no-diff     # Skip pixel diff generation
./run_compare_ux.sh               # UX interaction comparison with HTML report
```

**Output** (in `target/ocx/compare/`):

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

### Test Scenarios (36 tests)

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

Each test has a corresponding `.vbs` file in `mingw/tests/` that documents the
VBScript equivalent of the test setup (used in the HTML report).

## Usage from VB6/VBA

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

| Name | GUID |
|------|------|
| CLSID_VolvoxGrid | `{A7E3B4D1-5C2F-4E8A-B9D6-1F3C7E2A4B5D}` |
| IID_IVolvoxGrid | `{B8F4C5E2-6D3A-4F9B-A0E7-2A4D8F3B5C6E}` |
| LIBID_VolvoxGridLib | `{C9A5D6F3-7E4B-4A0C-B1F8-3B5E9A4C6D7F}` |
| ProgID | `VolvoxGrid.VolvoxGridCtrl` |

## Limitations

- **No type library** — `GetTypeInfoCount()` returns 0. VB6 IntelliSense
  requires a separately registered `.tlb` file.
- **No event sourcing** — The OCX does not fire events (e.g. `Click`,
  `RowColChange`). Properties are read/written only.
- **CPU rendering only** — `IViewObject::Draw()` uses the software renderer.
  The GPU renderer (`feature = "gpu"`) is not available in ActiveX mode.
- **No embedded window** — The OCX does not create its own HWND. It renders
  on demand via `IViewObject::Draw()` to any DC provided by the host.
- **Wine text antialiasing** — Text appears non-antialiased under Wine because
  Wine does not apply font smoothing to memory DCs. On real Windows, text is
  properly antialiased. See [Wine Text Antialiasing](#wine-text-antialiasing).
- **Wine thread cleanup crash** — A benign page fault may occur during Wine
  process exit (thread cleanup). This does not affect functionality.
