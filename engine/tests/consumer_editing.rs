use volvoxgrid_engine::{clipboard, grid::VolvoxGrid, proto::volvoxgrid::v1 as pb, sort};

fn read_only_editor() -> pb::EditorSpec {
    pb::EditorSpec {
        kind: pb::EditorKind::EditorText as i32,
        custom_props: Some(pb::StructValue {
            fields: vec![pb::StructField {
                key: "volvoxgrid.readOnly".into(),
                value: Some(pb::ScalarValue {
                    value: Some(pb::scalar_value::Value::BoolValue(true)),
                }),
            }],
        }),
        ..Default::default()
    }
}

#[test]
fn exact_numeric_sort_preserves_large_integer_and_decimal_order() {
    for order in [sort::SORT_ASCENDING_AUTO, sort::SORT_ASCENDING_NUMERIC] {
        let values = [
            "9007199254740993",
            "9007199254740992",
            "100.000000000000000002",
            "100.000000000000000001",
            "-9007199254740992",
            "-9007199254740993",
        ];
        let mut grid = VolvoxGrid::new(1, 640, 480, 7, 1, 1, 0);
        for (index, value) in values.iter().enumerate() {
            grid.cells.set_text(index as i32 + 1, 0, (*value).into());
        }
        sort::sort_grid_all(&mut grid, order, 0);
        let actual: Vec<_> = (1..7).map(|row| grid.cells.get_text(row, 0)).collect();
        assert_eq!(
            actual,
            [
                "-9007199254740993",
                "-9007199254740992",
                "100.000000000000000001",
                "100.000000000000000002",
                "9007199254740992",
                "9007199254740993",
            ]
        );
    }
}

#[test]
fn read_only_permission_follows_column_move_and_blocks_edit_and_clipboard() {
    let mut grid = VolvoxGrid::new(1, 640, 480, 2, 2, 1, 0);
    grid.edit_trigger_mode = 2;
    grid.columns[0].key = "sku".into();
    grid.columns[0].editor = Some(read_only_editor());
    grid.columns[1].key = "quantity".into();
    grid.cells.set_text(1, 0, "SKU-A".into());
    grid.cells.set_text(1, 1, "1".into());
    assert!(grid.move_col_by_positions(0, 1));
    assert_eq!(grid.columns[1].key, "sku");
    assert!(!grid.can_begin_edit(1, 1, false));
    assert!(!grid.can_begin_edit(1, 1, true));
    assert!(grid.can_begin_edit(1, 0, false));

    grid.selection
        .select_ranges(1, 0, &[(1, 0, 1, 1)], grid.rows, grid.cols);
    clipboard::paste(&mut grid, "2\tWRONG");
    assert_eq!(grid.cells.get_text(1, 0), "2");
    assert_eq!(grid.cells.get_text(1, 1), "SKU-A");
    clipboard::cut(&mut grid);
    assert_eq!(grid.cells.get_text(1, 0), "");
    assert_eq!(grid.cells.get_text(1, 1), "SKU-A");
}

#[test]
fn sparse_delete_preserves_permissions_and_identity_after_reordering() {
    let mut grid = VolvoxGrid::new_with_row_ids(1, 640, 480, 4, 100, 1, 0, true);
    grid.columns[0].editor = Some(read_only_editor());
    for (row, name) in [(1, "A"), (2, "B"), (3, "C")] {
        for col in 0..4 {
            grid.cells.set_text(row, col, format!("{name}{col}"));
        }
    }
    let a_id = grid.get_row_id(1);
    let b_id = grid.get_row_id(2);
    let c_id = grid.get_row_id(3);
    grid.cells.get_mut(2, 2).extra_mut().editor = Some(read_only_editor());
    // Even a blank cell can carry a read-only editor that deletion must keep.
    grid.cells.get_mut(3, 4).extra_mut().editor = Some(read_only_editor());
    grid.cells.set_text(8, 0, "outside rows".into());
    grid.cells.set_text(1, 110, "outside columns".into());
    sort::sort_grid_all(&mut grid, sort::SORT_DESCENDING_STRING, 0);
    assert!(grid.move_col_by_positions(0, 3));
    grid.selection
        .select_ranges(1, 0, &[(1, 0, 2, 99), (2, 0, 3, 1)], grid.rows, grid.cols);

    clipboard::delete_selection(&mut grid);

    assert_eq!(grid.cells.get_text(1, 0), "");
    assert_eq!(grid.cells.get_text(2, 0), "");
    assert_eq!(grid.cells.get_text(2, 1), "B2");
    assert_eq!(grid.cells.get_text(3, 1), "");
    assert_eq!(grid.cells.get_text(3, 2), "A3");
    assert!(grid.is_cell_read_only(1, 4));
    assert_eq!(grid.cells.get_text(8, 3), "outside rows");
    assert_eq!(grid.cells.get_text(3, 110), "outside columns");
    for (row, name, id) in [(1, "C0", c_id), (2, "B0", b_id), (3, "A0", a_id)] {
        assert_eq!(grid.cells.get_text(row, 3), name);
        assert_eq!(grid.get_row_id(row), id);
    }

    // A second sort catches accidental materialization of the cell maps.
    sort::sort_grid_all(&mut grid, sort::SORT_ASCENDING_STRING, 3);
    for (row, name, id) in [(1, "A0", a_id), (2, "B0", b_id), (3, "C0", c_id)] {
        assert_eq!(grid.cells.get_text(row, 3), name);
        assert_eq!(grid.get_row_id(row), id);
    }
    assert_eq!(grid.cells.get_text(1, 2), "A3");
    assert_eq!(grid.cells.get_text(2, 1), "B2");
    assert!(grid.is_cell_read_only(3, 4));
}

#[test]
fn sparse_full_selection_honors_default_read_only() {
    let mut grid = VolvoxGrid::new(1, 640, 480, 1_000_000, 100, 0, 0);
    grid.default_editor = Some(read_only_editor());
    for index in 0..100 {
        grid.cells.set_text(index * 1000, index, format!("{index}"));
    }
    grid.selection.select_ranges(
        0,
        0,
        &[(0, 0, grid.rows - 1, grid.cols - 1)],
        grid.rows,
        grid.cols,
    );
    clipboard::delete_selection(&mut grid);
    assert_eq!(grid.cells.len(), 100);
    grid.default_editor = None;
    clipboard::delete_selection(&mut grid);
    assert_eq!(grid.cells.len(), 0);
    // Repeating the operation on the now-empty grid also skips empty coordinates.
    clipboard::delete_selection(&mut grid);
    assert_eq!(grid.cells.len(), 0);
}

#[test]
fn sort_keeps_hidden_row_identity_with_data_and_row_metadata() {
    let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
    grid.edit_trigger_mode = 2;
    grid.columns[1].hidden = true;
    for (row, name) in [(1, "A"), (2, "B")] {
        grid.cells.set_text(row, 0, name.into());
        grid.cells.set_text(row, 1, format!("id-{name}"));
        grid.set_row_data(row, Some(name.as_bytes().to_vec()));
    }
    sort::sort_grid_all(&mut grid, sort::SORT_DESCENDING_STRING, 0);
    assert_eq!(grid.cells.get_text(1, 0), "B");
    assert_eq!(grid.cells.get_text(1, 1), "id-B");
    assert_eq!(grid.get_row_data(1), Some(b"B".to_vec()));
    grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
    grid.edit.update_text("edited-B".into());
    assert!(grid.commit_edit());
    assert_eq!(grid.cells.get_text(1, 1), "id-B");
    assert_eq!(grid.cells.get_text(2, 0), "A");

    // Structural operations materialize the sort map; identities must stay
    // attached to values before the following sort and subsequent edits.
    grid.add_item("C\tid-C", 1);
    grid.remove_item(2); // Remove edited B from the display.
    sort::sort_grid_all(&mut grid, sort::SORT_ASCENDING_STRING, 0);
    assert_eq!(grid.cells.get_text(1, 0), "A");
    assert_eq!(grid.cells.get_text(1, 1), "id-A");
    assert_eq!(grid.cells.get_text(2, 0), "C");
    assert_eq!(grid.cells.get_text(2, 1), "id-C");
    assert!(grid.move_col_by_positions(1, 0));
    assert!(grid.columns[0].hidden);
    assert_eq!(grid.cells.get_text(2, 0), "id-C");
    assert_eq!(grid.cells.get_text(2, 1), "C");
}

#[test]
fn read_only_cell_cannot_relax_column_permission_or_commit_pending_edit() {
    let mut grid = VolvoxGrid::new(1, 640, 480, 2, 1, 1, 0);
    grid.edit_trigger_mode = 2;
    grid.cells.set_text(1, 0, "original".into());
    grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
    grid.edit.update_text("changed".into());
    grid.columns[0].editor = Some(read_only_editor());
    grid.cells.get_mut(1, 0).extra_mut().editor = Some(pb::EditorSpec::default());
    assert!(!grid.commit_edit());
    assert!(!grid.is_editing());
    assert_eq!(grid.cells.get_text(1, 0), "original");
    // Application refreshes and failed-save rollbacks remain possible.
    grid.cells.set_text(1, 0, "server".into());
    assert_eq!(grid.cells.get_text(1, 0), "server");
}

#[test]
fn exact_numeric_sort_accepts_exponents_and_preserves_legacy_decoration() {
    let expected = [
        "($1,000.00)",
        "-2",
        "-0.01",
        "-0",
        "0",
        ".001",
        "+1.00e-2",
        "1e-1",
        "1.",
        "10%",
        "$1,000",
        "1.000000000000000000001e3",
        "1e1000",
    ];
    for descending in [false, true] {
        let mut grid = VolvoxGrid::new(1, 640, 480, expected.len() as i32, 1, 0, 0);
        for (row, value) in expected.iter().rev().enumerate() {
            grid.cells.set_text(row as i32, 0, (*value).into());
        }
        sort::sort_grid_all(
            &mut grid,
            if descending {
                sort::SORT_DESCENDING_NUMERIC
            } else {
                sort::SORT_ASCENDING_NUMERIC
            },
            0,
        );
        let actual: Vec<_> = (0..grid.rows)
            .map(|row| grid.cells.get_text(row, 0))
            .filter(|value| *value != "-0")
            .collect();
        let mut wanted: Vec<_> = expected
            .into_iter()
            .filter(|value| *value != "-0")
            .collect();
        if descending {
            wanted.reverse();
        }
        assert_eq!(actual, wanted);
    }
}

#[test]
fn load_table_replacement_resets_sort_and_column_maps() {
    let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
    for (row, name) in [(1, "A"), (2, "B")] {
        grid.cells.set_text(row, 0, name.into());
        grid.cells.set_text(row, 1, format!("id-{name}"));
    }
    sort::sort_grid_all(&mut grid, sort::SORT_DESCENDING_STRING, 0);
    grid.move_col_by_positions(0, 1);
    let values: Vec<_> = ["Name", "ID", "D", "id-D", "C", "id-C"]
        .into_iter()
        .map(|text| pb::CellValue {
            value: Some(pb::cell_value::Value::Text(text.into())),
        })
        .collect();
    assert_eq!(grid.load_table(3, 2, &values, true).rejected_count, 0);
    assert_eq!(grid.cells.get_text(1, 0), "D");
    assert_eq!(grid.cells.get_text(1, 1), "id-D");
    assert!(grid.sort_state.sort_keys.is_empty());
    sort::sort_grid_all(&mut grid, sort::SORT_ASCENDING_STRING, 0);
    assert_eq!(grid.cells.get_text(1, 0), "C");
    assert_eq!(grid.cells.get_text(1, 1), "id-C");
    assert_eq!(grid.cells.get_text(2, 0), "D");
    assert_eq!(grid.cells.get_text(2, 1), "id-D");
}

#[test]
fn editing_updates_typed_readback_without_rounding_text_columns() {
    use volvoxgrid_engine::cell::CellValueData;
    let mut grid = VolvoxGrid::new(1, 640, 480, 1, 2, 0, 0);
    grid.edit_trigger_mode = 2;
    grid.columns[0].data_type = pb::ColumnDataType::ColumnDataNumber as i32;
    let values = [
        pb::CellValue {
            value: Some(pb::cell_value::Value::Number(2.5)),
        },
        pb::CellValue {
            value: Some(pb::cell_value::Value::Text("9007199254740992".into())),
        },
    ];
    assert_eq!(grid.load_table(1, 2, &values, true).rejected_count, 0);
    grid.begin_edit(0, 0, pb::EditStartReason::EditStartProgrammatic);
    grid.edit.update_text("3.5".into());
    assert!(grid.commit_edit());
    assert!(matches!(grid.cells.get_value(0, 0), CellValueData::Number(value) if *value == 3.5));
    grid.begin_edit(0, 1, pb::EditStartReason::EditStartProgrammatic);
    grid.edit.update_text("9007199254740993".into());
    assert!(grid.commit_edit());
    assert!(
        matches!(grid.cells.get_value(0, 1), CellValueData::Text(value) if value == "9007199254740993")
    );
}
