# XtraGrid Adapter

## Purpose

`adapters/xtragrid` runs the shared C# case set in `test/cases/` against:

- `VolvoxGrid.DotNet` from `dotnet/`
- `DevExpress.XtraGrid` from `legacy/devexpress/...`

The adapter produces screenshots, optional diffs, and an HTML compare report.

## Entry Points

```bash
adapters/xtragrid/run_compare_ui.sh
adapters/xtragrid/run_compare_ux.sh
```

## Inputs

- Cases: `adapters/xtragrid/test/cases/*.csx`
- Runner: `adapters/xtragrid/test/runner/`
- Volvox build: `dotnet/build_dotnet.sh`
- DevExpress reference DLL:
  - explicit: `--ref-grid-assembly /path/to/DevExpress.XtraGrid.vXX.Y.dll`
  - autodetect: `legacy/devexpress/*/net462/DevExpress.XtraGrid*.dll`

The DevExpress directory must contain neighboring `DevExpress*.dll` dependencies beside `DevExpress.XtraGrid.v*.dll`.

## Execution Model

- `run_compare_ui.sh` builds `VolvoxGrid.DotNet` with `DOTNET_TFM=net40`
- the script runner is built as `net462`
- each `.csx` case is compiled into `public static void Run(GridControl grid, GridView view)`
- the runner maps that shared API onto either the DevExpress control or the Volvox control at runtime
- the compat layer maps `OptionsView.ShowIndicator` onto VolvoxGrid's `row_indicator_start` band so row-indicator scenarios can be compared directly instead of normalized away
- each case is executed in its own runner process to avoid Wine/.NET cross-case lifetime crashes
- the script reuses a prepared Wine prefix and prefers a prefix with a native `.NET Framework 4.6.2` install when one is present
- the default native-prefix candidates are:
  - `target/xtragrid/wineprefix`
  - `target/xtragrid/wineprefix_dotnet462`
  - `target/xtragrid/wineprefix_dotnet462_wine11`

## Output

All artifacts are written under `target/xtragrid/compare/`:

- `test_*_vv.png`
- `test_*_ref.png`
- `test_*_diff.png`
- `results_vv.tsv`
- `results_ref.tsv`
- `compare_output.log`
- `report.html`

## Common Commands

Volvox only:

```bash
adapters/xtragrid/run_compare_ui.sh --only-vv
```

Single case:

```bash
adapters/xtragrid/run_compare_ui.sh --test 1
```

Specific DevExpress DLL:

```bash
adapters/xtragrid/run_compare_ui.sh \
  --ref-grid-assembly legacy/devexpress/25.2.5/net462/DevExpress.XtraGrid.v25.2.dll
```

## Runtime Requirement

For public DevExpress `net462` packages under Linux/Wine, a Wine Mono prefix is not sufficient. The working setup is:

- Wine with a native Microsoft `.NET Framework 4.6.2` install in the prefix
- DevExpress assemblies from `legacy/devexpress/.../net462/`

The compare script automatically skips Wine Mono bootstrap when it detects that native framework install.
