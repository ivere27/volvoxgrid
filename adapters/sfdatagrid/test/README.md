# SfDataGrid Compare Reports

Run:

```bash
./adapters/sfdatagrid/run_compare_ui.sh
```

Outputs are written to:

- `target/sfdatagrid/compare/report.html`
- `target/sfdatagrid/compare/compare_output.log`
- `target/sfdatagrid/compare/test_*_{ref,vv,diff}.png`

Options:

- `--tests 1-6`, `--test 3`
- `--only-vv`
- `--no-html`
- `--no-diff`
- `--skip-build`
- `--skip-pub-get`
