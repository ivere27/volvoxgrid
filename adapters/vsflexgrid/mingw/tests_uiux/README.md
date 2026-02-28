UI+UX test scripts for `run_compare_ux.sh`.

- Keep UI-only baseline scripts in `adapters/vsflexgrid/mingw/tests/`.
- Put UI+UX-specific VBScript/UX scripts in this folder.
- Naming stays the same: `NN_name.vbs` and optional `NN_name.ux`.

`run_compare_ux.sh` uses this folder by default.

New coverage additions:
- `65_event_edit_hooks.vbs` + `65_event_edit_hooks.ux` for edit/row-col event flows.
- data-oriented tests (`66`, `67`) are mirrored here for full-table compatibility.
