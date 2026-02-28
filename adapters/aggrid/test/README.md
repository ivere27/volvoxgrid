# AG Grid Compare Reports

Run:

```bash
cd adapters/aggrid && npm install && ./run_compare_ui.sh
```

Outputs are written to:

- `target/aggrid/capture_compare/report.html`
- `target/aggrid/capture_compare/compare_output.log`
- `target/aggrid/capture_compare/test_*_{ref,vv,diff}.png`

Options:

- `--tests 1-6`, `--test 3`
- `--only-vv`
- `--no-html`
