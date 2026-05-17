# SfDataGrid compare reports

This harness runs the shared scenario set against both Syncfusion SfDataGrid and VolvoxGrid (rendered through Flutter), then writes a side-by-side HTML report with pixel diffs. Reach for it when you're validating that a VolvoxGrid change still matches SfDataGrid behavior for a known scenario.

## Run it

From the repo root:

```bash
./adapters/sfdatagrid/run_compare_ui.sh
```

The first run fetches Flutter packages, builds the native library, and warms the Flutter test harness, so it's slower than subsequent runs.

## Where the output lands

Everything goes under `target/sfdatagrid/compare/`:

- `report.html` — open this for the side-by-side view
- `compare_output.log` — raw run log
- `test_*_ref.png`, `test_*_vv.png`, `test_*_diff.png` — per-scenario SfDataGrid render, VolvoxGrid render, and pixel diff

## Useful options

- `--tests 1-6` or `--test 3` — narrow to a range or a single scenario
- `--only-vv` — skip the SfDataGrid reference run (faster while iterating on VolvoxGrid)
- `--no-html` — skip report generation when you only need the images
- `--no-diff` — skip pixel diff generation
- `--skip-build` — reuse the existing native library build
- `--skip-pub-get` — reuse the existing Flutter package fetch
