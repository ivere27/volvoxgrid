# XtraGrid Compare Cases

Each file in this folder is a shared C# script body executed as:

```csharp
public static void Run(GridControl grid, GridView view) { ... }
```

These are not real DevExpress types at compile time. The runner provides a small shared compatibility surface that maps onto:

- real `DevExpress.XtraGrid` when `--engine ref`
- `VolvoxGrid.DotNet` when `--engine vv`

The goal is to keep one set of `.csx` files for both engines.

File naming:

- `NN_name.csx`

Typical entrypoints:

```bash
adapters/xtragrid/run_compare_ui.sh --only-vv
adapters/xtragrid/run_compare_ui.sh --ref-grid-assembly "/path/to/DevExpress.XtraGrid.vXX.Y.dll"
```

Output:

- screenshots: `target/xtragrid/compare/test_*_{vv,ref}.png`
- diffs: `target/xtragrid/compare/test_*_diff.png`
- report: `target/xtragrid/compare/report.html`
