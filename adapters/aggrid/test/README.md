# AG Grid compare reports

This harness runs the shared scenario set against both AG Grid and VolvoxGrid, then writes a side-by-side HTML report with pixel diffs. Reach for it when you're validating that a VolvoxGrid change still matches AG Grid behavior for a known scenario.

## Run it

From the repo root:

```bash
cd adapters/aggrid && npm install && ./run_compare_ui.sh
```

The first run installs the adapter's npm deps and builds the WASM bundle, so it's slower than subsequent runs.

## Where the output lands

Everything goes under `target/aggrid/compare/`:

- `report.html` — open this for the side-by-side view
- `compare_output.log` — raw run log
- `test_*_ref.png`, `test_*_vv.png`, `test_*_diff.png` — per-scenario AG Grid render, VolvoxGrid render, and pixel diff

## Useful options

- `--tests 1-6` or `--test 3` — narrow to a range or a single scenario
- `--only-vv` — skip the AG Grid reference run (faster, useful when you're iterating on VolvoxGrid only)
- `--no-html` — skip report generation when you only need the images
