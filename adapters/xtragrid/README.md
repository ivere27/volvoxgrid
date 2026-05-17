# XtraGrid compare adapter

This adapter lets you run one shared C# scenario set against both `VolvoxGrid.DotNet` and the real `DevExpress.XtraGrid`, then writes a side-by-side HTML report with pixel diffs. Reach for it when you're checking that a VolvoxGrid change still matches XtraGrid behavior, or when you're sizing up VolvoxGrid as a XtraGrid replacement.

The adapter exists because XtraGrid is a long-standing, behavior-rich commercial control. Comparing screen-for-screen against a reference like that is the fastest way to find behavior gaps in VolvoxGrid and prioritize them — much faster than guessing from spec.

## Quick start

From the repo root, with the DevExpress assemblies available under `legacy/devexpress/*/net462/`:

```bash
adapters/xtragrid/run_compare_ui.sh
```

A UX-flavored variant — focused on interaction sequences rather than static renders — lives next to it:

```bash
adapters/xtragrid/run_compare_ux.sh
```

If you only want to render VolvoxGrid (no DevExpress reference), pass `--only-vv`. See [Common commands](#common-commands) below.

## How a comparison case works

Each `.csx` file in `test/cases/` is a shared C# script body that compiles to:

```csharp
public static void Run(GridControl grid, GridView view) { ... }
```

These aren't real DevExpress types at compile time. The runner provides a small compatibility shim that maps the shared API onto whichever engine you're targeting:

- the real `DevExpress.XtraGrid` when `--engine ref`
- `VolvoxGrid.DotNet` when `--engine vv`

The goal is one set of `.csx` files driving both engines. The shim handles the small translations — for example, mapping `OptionsView.ShowIndicator` onto VolvoxGrid's `row_indicator_start` band — so row-indicator scenarios compare directly instead of being normalized away.

## Inputs

When you're wiring up a new case or debugging an existing run, here's where the pieces live:

- **Cases:** `adapters/xtragrid/test/cases/*.csx`
- **Runner:** `adapters/xtragrid/test/runner/`
- **VolvoxGrid build:** produced by `dotnet/build_dotnet.sh`
- **DevExpress reference DLL:** either explicit (`--ref-grid-assembly /path/to/DevExpress.XtraGrid.vXX.Y.dll`) or auto-detected from `legacy/devexpress/*/net462/DevExpress.XtraGrid*.dll`

The DevExpress directory must contain the neighboring `DevExpress*.dll` dependencies beside `DevExpress.XtraGrid.v*.dll` — that's how XtraGrid expects its dependencies to load.

## Execution model

`run_compare_ui.sh` builds `VolvoxGrid.DotNet` with `DOTNET_TFM=net40` and builds the script runner as `net462`. The two-framework split keeps each side targeting what it was designed for.

Each case is executed in its own runner process. That isolation matters: Wine and `.NET` together don't cleanly share lifetime across cases, and running everything in one process tends to crash partway through a run. One process per case sidesteps it.

The script reuses a prepared Wine prefix and prefers one with a native Microsoft `.NET Framework 4.6.2` install when it can find one. The default native-prefix candidates, checked in order, are:

- `target/xtragrid/wineprefix`
- `target/xtragrid/wineprefix_dotnet462`
- `target/xtragrid/wineprefix_dotnet462_wine11`

## Runtime requirement

For public DevExpress `net462` packages running under Linux/Wine, a Wine Mono prefix isn't enough. You need:

- Wine with a native Microsoft `.NET Framework 4.6.2` installed in the prefix
- DevExpress assemblies from `legacy/devexpress/.../net462/`

The compare script automatically skips its Wine Mono bootstrap when it detects that native framework install, so once your prefix is set up correctly the run flows through without extra flags.

## Output

Everything lands under `target/xtragrid/compare/`. After a run you'll find:

- `test_*_vv.png` — VolvoxGrid render
- `test_*_ref.png` — XtraGrid render
- `test_*_diff.png` — pixel diff
- `results_vv.tsv`, `results_ref.tsv` — tabular results per case
- `compare_output.log` — raw log
- `report.html` — open this for the side-by-side view

The HTML report pairs each render with its diff so you can scan a long run quickly.

## Common commands

VolvoxGrid only (skip the DevExpress reference, useful when iterating on VolvoxGrid):

```bash
adapters/xtragrid/run_compare_ui.sh --only-vv
```

A single case by number:

```bash
adapters/xtragrid/run_compare_ui.sh --test 1
```

A specific DevExpress DLL:

```bash
adapters/xtragrid/run_compare_ui.sh \
  --ref-grid-assembly legacy/devexpress/25.2.5/net462/DevExpress.XtraGrid.v25.2.dll
```

## What's next

- [../../dotnet/README.md](../../dotnet/README.md) — the VolvoxGrid `.NET` package this adapter is built on
- [../../ARCHITECTURE.md](../../ARCHITECTURE.md) — how the engine, runtime, and wrappers fit together
- [./test/cases/README.md](./test/cases/README.md) — case-file conventions and the shared API surface
