use std::collections::HashSet;
use volvoxgrid_engine::{
    event::GridEventData, grid::VolvoxGrid, input, outline, proto::volvoxgrid::v1 as pb, save,
    sort, tree,
};

fn grid() -> VolvoxGrid {
    let mut grid = VolvoxGrid::new_with_row_ids(17, 640, 480, 3, 1, 1, 0, true);
    grid.edit_trigger_mode = 2;
    grid.cells.set_text(0, 0, "Name".into());
    grid.cells.set_text(1, 0, "A".into());
    grid.cells.set_text(2, 0, "B".into());
    grid
}

fn ids(grid: &VolvoxGrid) -> Vec<i64> {
    (0..grid.rows)
        .map(|row| grid.get_row_id(row).unwrap())
        .collect()
}

fn assert_index(grid: &VolvoxGrid) {
    let ids = ids(grid);
    assert_eq!(ids.iter().collect::<HashSet<_>>().len(), grid.rows as usize);
    for (row, id) in ids.iter().enumerate() {
        assert!(*id > 0);
        assert_eq!(grid.find_row_by_id(*id), Some(row as i32));
    }
    assert_eq!(grid.get_row_id(-1), None);
    assert_eq!(grid.get_row_id(grid.rows), None);
}

fn text(value: &str) -> pb::CellValue {
    pb::CellValue {
        value: Some(pb::cell_value::Value::Text(value.into())),
    }
}

#[test]
fn automatic_ids_cover_fixed_rows_and_do_not_reuse_replaced_ids() {
    let mut grid = grid();
    let original = ids(&grid);
    assert_index(&grid);
    grid.load_table(3, 1, &[text("Name"), text("C"), text("D")], true);
    for id in &original {
        assert_eq!(grid.find_row_by_id(*id), None);
    }
    assert_index(&grid);
    assert!(ids(&grid).iter().all(|id| !original.contains(id)));
}

#[test]
fn application_ids_assign_atomically_and_are_independent_of_row_data() {
    let mut grid = grid();
    grid.set_row_data(1, Some(b"unrelated binary payload".to_vec()));
    grid.set_row_ids(&[(1, 101), (2, 102)]).unwrap();
    grid.set_row_ids(&[(1, 102), (2, 101)]).unwrap();
    assert_eq!(grid.get_row_id(1), Some(102));
    assert_eq!(
        grid.get_row_data(1),
        Some(b"unrelated binary payload".to_vec())
    );
    let before = ids(&grid);
    for invalid in [
        vec![(1, 101)],
        vec![(1, 0)],
        vec![(1, 1000), (2, 1000)],
        vec![(1, 1000), (1, 1001)],
        vec![(1, 1000), (3, 1001)],
    ] {
        assert!(grid.set_row_ids(&invalid).is_err());
        assert_eq!(ids(&grid), before);
        assert_index(&grid);
    }
    grid.define_rows(&[pb::RowDef {
        index: 1,
        row_id: Some(202),
        ..Default::default()
    }]);
    assert_eq!(grid.get_row_id(1), Some(202));
}

#[test]
fn sort_move_and_edit_events_keep_the_same_source_identity() {
    let mut grid = grid();
    grid.set_row_ids(&[(1, 101), (2, 102)]).unwrap();
    // No row metadata is present: IDs still have to follow the sort permutation.
    sort::sort_grid_all(&mut grid, sort::SORT_DESCENDING_STRING, 0);
    assert_eq!(grid.get_row_id(1), Some(102));
    grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
    assert_eq!(grid.edit.edit_row_id, 102);
    grid.edit.update_text("edited-B".into());
    assert!(grid.commit_edit());
    // Events remain queued across another move; the payload must retain B.
    assert!(input::apply_move_row_after_before(&mut grid, 1, 2));
    assert_eq!(grid.cells.get_text(2, 0), "edited-B");
    assert_eq!(grid.get_row_id(2), Some(102));
    let events = grid.events.drain();
    let edit_ids: Vec<_> = events
        .iter()
        .filter_map(|event| match &event.data {
            GridEventData::BeforeEdit { row_id, .. }
            | GridEventData::StartEdit { row_id, .. }
            | GridEventData::CellEditValidate { row_id, .. }
            | GridEventData::AfterEdit { row_id, .. } => Some(*row_id),
            _ => None,
        })
        .collect();
    assert_eq!(edit_ids, [102, 102, 102, 102]);
    assert_index(&grid);
}

#[test]
fn structural_changes_cancel_active_edits_instead_of_committing_to_a_new_target() {
    let mut grid = grid();
    grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
    grid.edit.update_text("wrong row".into());
    sort::sort_grid_all(&mut grid, sort::SORT_DESCENDING_STRING, 0);
    assert!(!grid.edit.is_active());
    assert!(!grid.commit_edit());
    assert_eq!(grid.cells.get_text(1, 0), "B");
    assert_eq!(grid.cells.get_text(2, 0), "A");
    grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
    grid.set_row_ids(&[(1, 201)]).unwrap();
    assert!(!grid.edit.is_active());
}

#[test]
fn sorted_insert_remove_resize_preserve_remaining_ids_and_values() {
    let mut grid = grid();
    let a = grid.get_row_id(1).unwrap();
    let b = grid.get_row_id(2).unwrap();
    sort::sort_grid_all(&mut grid, sort::SORT_DESCENDING_STRING, 0);
    grid.add_item("C", 2);
    let c = grid.get_row_id(2).unwrap();
    assert_ne!(a, c);
    grid.remove_item(1);
    assert_eq!(grid.find_row_by_id(b), None);
    assert_eq!(grid.get_row_id(1), Some(c));
    assert_eq!(grid.get_row_id(2), Some(a));
    sort::sort_grid_all(&mut grid, sort::SORT_DESCENDING_STRING, 0);
    grid.set_rows(2);
    assert_eq!(grid.cells.get_text(1, 0), "C");
    assert_eq!(grid.get_row_id(1), Some(c));
    assert_eq!(grid.find_row_by_id(a), None);
    grid.set_rows(4);
    assert_eq!(grid.get_row_id(1), Some(c));
    assert_index(&grid);
}

#[test]
fn full_load_with_ids_rejects_bad_ids_before_mutating_and_supports_same_keys() {
    let mut grid = grid();
    let original = ids(&grid);
    for invalid in [vec![1], vec![1, 101, 101]] {
        assert!(grid
            .load_table_with_row_ids(3, 2, &[text("WRONG")], true, &invalid)
            .is_err());
        assert_eq!(ids(&grid), original);
        assert_eq!(grid.cols, 1);
        assert_eq!(grid.cells.get_text(0, 0), "Name");
    }
    let supplied = vec![1, 102, 101];
    grid.load_table_with_row_ids(3, 1, &[text("Name"), text("B"), text("A")], true, &supplied)
        .unwrap();
    assert_eq!(ids(&grid), supplied);
    grid.load_table_with_row_ids(
        3,
        1,
        &[text("Name"), text("updated B"), text("updated A")],
        true,
        &supplied,
    )
    .unwrap();
    assert_eq!(ids(&grid), supplied);
    assert_index(&grid);
}

#[test]
fn subtotal_rows_receive_fresh_ids_and_do_not_replace_source_row_ids() {
    let mut grid = grid();
    grid.cells.set_text(1, 0, "1".into());
    grid.cells.set_text(2, 0, "2".into());
    let originals = ids(&grid);
    outline::subtotal(&mut grid, 2, -1, 0, "Total", 0, 0, true);
    assert!(grid.rows > 3);
    for id in &originals {
        assert!(grid.find_row_by_id(*id).is_some());
    }
    assert_index(&grid);
    outline::subtotal(&mut grid, 1, -1, 0, "", 0, 0, true);
    assert_eq!(ids(&grid), originals);
    assert_index(&grid);
}

#[test]
fn tree_projection_retains_node_row_ids_while_collapsed_nodes_have_no_display_row() {
    let mut grid = grid();
    let header_id = grid.get_row_id(0).unwrap();
    tree::load_tree(
        &mut grid,
        pb::LoadTreeRequest {
            replace: true,
            nodes: vec![pb::TreeNode {
                node_id: "parent".into(),
                children: vec![pb::TreeNode {
                    node_id: "child".into(),
                    ..Default::default()
                }],
                ..Default::default()
            }],
            ..Default::default()
        },
    )
    .unwrap();
    let parent_id = grid.get_row_id(1).unwrap();
    let child_id = grid.get_row_id(2).unwrap();
    tree::collapse_nodes(
        &mut grid,
        pb::CollapseNodesRequest {
            node_ids: vec!["parent".into()],
            ..Default::default()
        },
    )
    .unwrap();
    assert_eq!(grid.find_row_by_id(child_id), None);
    assert_eq!(grid.get_row_id(1), Some(parent_id));
    assert!(grid.set_row_ids(&[(1, child_id)]).is_err());
    tree::expand_nodes(
        &mut grid,
        pb::ExpandNodesRequest {
            node_ids: vec!["parent".into()],
            ..Default::default()
        },
    )
    .unwrap();
    assert_eq!(grid.get_row_id(2), Some(child_id));
    assert_eq!(grid.get_row_id(0), Some(header_id));
    assert_index(&grid);
}

#[test]
fn clearing_cell_content_keeps_ids_but_importing_replacement_data_refreshes_them() {
    let mut grid = grid();
    let original = ids(&grid);
    grid.clear_region(pb::ClearScope::ClearData as i32, 0);
    assert_eq!(ids(&grid), original);
    save::load_grid(
        &mut grid,
        b"Name\nC\nD",
        pb::ExportFormat::ExportTsv as i32,
        pb::ExportScope::ExportDataOnly as i32,
    );
    assert!(ids(&grid).iter().all(|id| !original.contains(id)));
    assert_index(&grid);
}

#[test]
fn ten_thousand_rows_sort_with_bijective_constant_time_lookup() {
    let mut grid = VolvoxGrid::new_with_row_ids(23, 640, 480, 10_001, 1, 1, 0, true);
    let supplied: Vec<_> = (0..grid.rows).map(|row| i64::from(row) + 1).collect();
    grid.replace_row_ids(&supplied).unwrap();
    for row in 1..grid.rows {
        grid.cells.set_text(row, 0, row.to_string());
    }
    sort::sort_grid_all(&mut grid, sort::SORT_DESCENDING_NUMERIC, 0);
    for row in 1..grid.rows {
        assert_eq!(grid.get_row_id(row), Some(i64::from(grid.rows - row) + 1));
    }
    assert_index(&grid);
}

#[test]
fn hard_rejected_table_load_preserves_data_and_identities() {
    let mut grid = grid();
    let before = ids(&grid);
    grid.define_columns(&[pb::ColumnDef {
        index: 0,
        data_type: Some(pb::ColumnDataType::ColumnDataNumber as i32),
        coercion_mode: Some(pb::CoercionMode::CoercionStrict as i32),
        error_mode: Some(pb::WriteErrorMode::WriteErrorReject as i32),
        ..Default::default()
    }]);
    let result = grid
        .load_table_with_row_ids(2, 1, &[text("bad number")], true, &[200, 201])
        .unwrap();
    assert!(result.rejected_count > 0);
    assert_eq!(grid.rows, 3);
    assert_eq!(ids(&grid), before);
    assert_eq!(grid.cells.get_text(1, 0), "A");
}

#[test]
fn append_data_preserves_existing_ids_and_load_data_replaces_them() {
    use volvoxgrid_engine::load;
    let mut grid = grid();
    let original = ids(&grid);
    let options = pb::LoadDataOptions {
        header_policy: Some(pb::HeaderPolicy::HeaderNone as i32),
        ..Default::default()
    };
    let result = load::append_data(&mut grid, b"C\nD", Some(&options));
    assert_eq!(result.rejected, 0);
    assert_eq!(grid.rows, 5);
    assert_eq!(&ids(&grid)[..3], &original);
    assert_eq!(grid.cells.get_text(3, 0), "C");
    assert_index(&grid);
    load::load_data(&mut grid, b"E\nF", Some(&options));
    assert!(ids(&grid).iter().all(|id| !original.contains(id)));
    assert_index(&grid);
}

#[test]
fn auto_ids_skip_current_application_ids_without_reserving_numeric_values() {
    let mut grid = grid();
    let next_id = (1i64 << 31) | 4;
    grid.set_row_ids(&[(1, next_id)]).unwrap();
    grid.add_item("C", -1);
    assert_eq!(grid.get_row_id(1), Some(next_id));
    assert_ne!(grid.get_row_id(3), Some(next_id));
    assert_index(&grid);
}

#[test]
fn positive_int64_boundaries_are_exact_and_zero_or_negative_ids_reject_atomically() {
    let mut grid = grid();
    let high = (1i64 << 53) + 1;
    grid.set_row_ids(&[(1, high), (2, i64::MAX)]).unwrap();
    assert_eq!(grid.get_row_id(1), Some(high));
    assert_eq!(grid.get_row_id(2), Some(i64::MAX));
    assert_eq!(grid.find_row_by_id(high), Some(1));
    assert_eq!(grid.find_row_by_id(i64::MAX), Some(2));
    let before = ids(&grid);
    for invalid in [0, -1, i64::MIN] {
        assert!(grid.set_row_ids(&[(1, invalid)]).is_err());
        assert!(grid
            .load_table_with_row_ids(1, 1, &[text("wrong")], true, &[invalid])
            .is_err());
        assert_eq!(ids(&grid), before);
    }
}

#[test]
fn deleted_slots_and_full_replacement_never_revive_automatic_tokens() {
    let mut grid = grid();
    let old = grid.get_row_id(1).unwrap();
    let token = grid.row_identity_token(1).unwrap();
    grid.remove_item(1);
    grid.add_item("replacement", 1);
    assert_ne!(grid.get_row_id(1), Some(old));
    assert_eq!(grid.find_row_by_identity_token(token), None);
    assert_eq!(grid.find_row_by_id(old), None);
    let current = ids(&grid);
    grid.load_table(3, 1, &[], true);
    for id in current {
        assert_eq!(grid.find_row_by_id(id), None);
        assert_eq!(grid.find_row_by_identity_token(id), None);
    }
    assert_index(&grid);
}

#[test]
fn caller_alias_reuse_does_not_revive_old_incarnation_or_edit_session() {
    let mut grid = grid();
    grid.set_row_ids(&[(1, 101), (2, 102)]).unwrap();
    let token = grid.row_identity_token(1).unwrap();
    grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
    let old_session = grid.edit.clone();
    grid.load_table_with_row_ids(
        3,
        1,
        &[text("Name"), text("fresh A"), text("fresh B")],
        true,
        &[1, 101, 102],
    )
    .unwrap();
    assert!(!grid.edit.is_active());
    assert_eq!(grid.find_row_by_id(101), Some(1));
    assert_eq!(grid.find_row_by_identity_token(token), None);
    // A stale captured session cannot commit even if a host incorrectly restores it.
    grid.edit = old_session;
    grid.edit.update_text("stale write".into());
    assert!(!grid.commit_edit());
    assert_eq!(grid.cells.get_text(1, 0), "fresh A");
}

#[test]
fn aliases_can_swap_with_automatic_ids_without_ambiguous_reverse_lookup() {
    let mut grid = grid();
    let a = grid.get_row_id(1).unwrap();
    let b = grid.get_row_id(2).unwrap();
    grid.set_row_ids(&[(1, b), (2, a)]).unwrap();
    assert_eq!(grid.find_row_by_id(a), Some(2));
    assert_eq!(grid.find_row_by_id(b), Some(1));
    grid.set_row_ids(&[(1, a), (2, b)]).unwrap();
    assert_eq!(grid.find_row_by_id(a), Some(1));
    assert_eq!(grid.find_row_by_id(b), Some(2));
    assert_index(&grid);
}

#[test]
fn one_million_automatic_rows_use_twelve_bytes_per_row_before_container_overhead() {
    let store = volvoxgrid_engine::row::RowIdentityStore::new(17, 1_000_000);
    assert_eq!(store.heap_size_bytes(), 12_000_000);
    let last = store.get(999_999).unwrap();
    assert_eq!(store.find(last), Some(999_999));
}

#[test]
fn changing_tree_fixed_row_boundary_never_duplicates_a_node_identity_in_headers() {
    let mut grid = grid();
    let request = pb::LoadTreeRequest {
        replace: true,
        nodes: vec![pb::TreeNode {
            node_id: "parent".into(),
            children: vec![pb::TreeNode {
                node_id: "child".into(),
                ..Default::default()
            }],
            ..Default::default()
        }],
        ..Default::default()
    };
    tree::load_tree(&mut grid, request.clone()).unwrap();
    let header = grid.get_row_id(0).unwrap();
    let parent = grid.get_row_id(1).unwrap();
    let child = grid.get_row_id(2).unwrap();
    grid.fixed_rows = 2;
    tree::project_tree(&mut grid);
    assert_index(&grid);
    assert_eq!(grid.get_row_id(0), Some(header));
    assert_ne!(grid.get_row_id(1), Some(parent));
    assert_eq!(grid.get_row_id(2), Some(parent));
    assert_eq!(grid.get_row_id(3), Some(child));
    grid.fixed_rows = 1;
    tree::project_tree(&mut grid);
    assert_eq!(grid.get_row_id(1), Some(parent));
    assert_eq!(grid.get_row_id(2), Some(child));
    assert_index(&grid);
    grid.fixed_rows = 2;
    tree::load_tree(&mut grid, request.clone()).unwrap();
    assert_eq!(grid.get_row_id(0), Some(header));
    assert_eq!(grid.find_row_by_id(parent), None);
    assert_eq!(grid.find_row_by_id(child), None);
    assert_index(&grid);
    // Replacing with multiple former tree rows in the fixed prefix can reuse
    // another prefix slot while allocating its first new header identity.
    grid.fixed_rows = 1;
    tree::project_tree(&mut grid);
    grid.fixed_rows = 3;
    tree::load_tree(&mut grid, request).unwrap();
    assert_eq!(grid.get_row_id(0), Some(header));
    assert_index(&grid);
}

fn grid_without_ids() -> VolvoxGrid {
    let mut grid = VolvoxGrid::new(31, 640, 480, 3, 1, 1, 0);
    grid.auto_resize = false;
    grid.edit_trigger_mode = 2;
    grid.cells.set_text(0, 0, "Name".into());
    grid.cells.set_text(1, 0, "A".into());
    grid.cells.set_text(2, 0, "B".into());
    grid
}

fn assert_ids_disabled(grid: &VolvoxGrid) {
    assert!(!grid.row_ids_enabled());
    assert_eq!(grid.row_ids.heap_size_bytes(), 0);
    assert_eq!(grid.get_row_id(0), None);
    assert_eq!(grid.get_row_id(grid.rows - 1), None);
    assert_eq!(grid.find_row_by_id((1i64 << 31) | 1), None);
    assert_eq!(grid.row_identity_token(0), None);
}

#[test]
fn creation_option_keeps_one_million_disabled_rows_free_of_identity_allocations() {
    let mut disabled = VolvoxGrid::new(31, 640, 480, 1_000_000, 1, 0, 0);
    assert_ids_disabled(&disabled);
    let target = disabled.capture_row_target(999_999).unwrap();
    assert_eq!(target.row_id, 0);
    assert_eq!(target.identity_token, 0);
    assert_eq!(disabled.resolve_row_target(&target), Some(999_999));
    assert_eq!(disabled.capture_row_target(1_000_000), None);
    disabled.set_rows(1_000_001);
    assert_eq!(disabled.resolve_row_target(&target), None);
    disabled.set_rows(1_000_000);
    assert_ids_disabled(&disabled);

    let enabled = VolvoxGrid::new_with_row_ids(32, 640, 480, 1_000_000, 1, 0, 0, true);
    assert!(enabled.row_ids_enabled());
    assert_eq!(enabled.row_ids.heap_size_bytes(), 12_000_000);
    assert!(enabled.get_row_id(999_999).is_some());
}

#[test]
fn manager_creation_option_is_explicit_and_disabled_by_default() {
    let manager = volvoxgrid_engine::GridManager::new();
    let disabled = manager.create_grid(640, 480, 3, 1, 1, 0, 1.0);
    let enabled = manager.create_grid_with_row_ids(640, 480, 3, 1, 1, 0, 1.0, true);
    manager
        .with_grid(disabled, |grid| assert_ids_disabled(grid))
        .unwrap();
    manager
        .with_grid(enabled, |grid| assert_index(grid))
        .unwrap();
}

#[test]
fn disabled_identity_assignments_reject_before_any_data_or_row_property_changes() {
    let mut grid = grid_without_ids();
    let target = grid.capture_row_target(1).unwrap();
    for error in [
        grid.set_row_ids(&[(1, 101)]).unwrap_err(),
        grid.replace_row_ids(&[1, 101, 102]).unwrap_err(),
        grid.load_table_with_row_ids(2, 2, &[text("WRONG")], true, &[101, 102])
            .unwrap_err(),
    ] {
        assert!(error.contains("row_ids_enabled=true"));
    }
    grid.define_rows(&[
        pb::RowDef {
            index: 1,
            height: Some(88),
            ..Default::default()
        },
        pb::RowDef {
            index: 2,
            row_id: Some(102),
            ..Default::default()
        },
    ]);
    assert_eq!(grid.rows, 3);
    assert_eq!(grid.cols, 1);
    assert_eq!(grid.cells.get_text(1, 0), "A");
    assert_eq!(grid.row_heights.get(&1), None);
    assert_eq!(grid.resolve_row_target(&target), Some(1));
    assert!(grid.set_row_ids(&[]).is_ok());
    assert_ids_disabled(&grid);
}

#[test]
fn disabled_pending_targets_reject_sort_move_delete_and_resize_aba() {
    let mut grid = grid_without_ids();
    let original = grid.capture_row_target(1).unwrap();
    grid.cells.set_text(1, 0, "AA".into());
    assert_eq!(grid.resolve_row_target(&original), Some(1));
    sort::sort_grid_all(&mut grid, sort::SORT_DESCENDING_STRING, 0);
    sort::sort_grid_all(&mut grid, sort::SORT_ASCENDING_STRING, 0);
    assert_eq!(grid.cells.get_text(1, 0), "AA");
    assert_eq!(grid.resolve_row_target(&original), None);

    let before_move = grid.capture_row_target(1).unwrap();
    assert!(input::apply_move_row_after_before(&mut grid, 1, 2));
    assert!(input::apply_move_row_after_before(&mut grid, 2, 1));
    assert_eq!(grid.resolve_row_target(&before_move), None);

    let before_delete = grid.capture_row_target(1).unwrap();
    grid.remove_item(1);
    grid.add_item("AA", 1);
    assert_eq!(grid.resolve_row_target(&before_delete), None);

    let before_resize = grid.capture_row_target(1).unwrap();
    grid.set_rows(4);
    grid.set_rows(3);
    assert_eq!(grid.resolve_row_target(&before_resize), None);
    assert_ids_disabled(&grid);
}

#[test]
fn disabled_index_editing_commits_but_replaced_table_rejects_a_stale_session() {
    let mut grid = grid_without_ids();
    sort::sort_grid_all(&mut grid, sort::SORT_DESCENDING_STRING, 0);
    grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
    assert!(grid.is_edit_target_current());
    grid.edit.update_text("edited B".into());
    assert!(grid.commit_edit());
    assert_eq!(grid.cells.get_text(1, 0), "edited B");
    let events = grid.events.drain();
    let edit_ids: Vec<_> = events
        .iter()
        .filter_map(|event| match event.data {
            GridEventData::BeforeEdit { row_id, .. }
            | GridEventData::StartEdit { row_id, .. }
            | GridEventData::CellEditValidate { row_id, .. }
            | GridEventData::AfterEdit { row_id, .. } => Some(row_id),
            _ => None,
        })
        .collect();
    assert_eq!(edit_ids, [0, 0, 0, 0]);

    grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
    let stale_session = grid.edit.clone();
    let stale_target = grid.capture_row_target(1).unwrap();
    grid.load_table(
        3,
        1,
        &[text("Name"), text("fresh A"), text("fresh B")],
        true,
    );
    assert_eq!(grid.resolve_row_target(&stale_target), None);
    grid.edit = stale_session;
    grid.edit.update_text("WRONG".into());
    assert!(!grid.is_edit_target_current());
    assert!(!grid.commit_edit());
    assert_eq!(grid.cells.get_text(1, 0), "fresh A");
    assert_ids_disabled(&grid);
}

#[test]
fn enabled_pending_target_follows_sort_but_rejects_reused_application_id() {
    let mut grid = grid();
    grid.set_row_ids(&[(1, 101), (2, 102)]).unwrap();
    let target = grid.capture_row_target(1).unwrap();
    sort::sort_grid_all(&mut grid, sort::SORT_DESCENDING_STRING, 0);
    assert_eq!(grid.resolve_row_target(&target), Some(2));
    grid.remove_item(2);
    grid.add_item("replacement A", 2);
    grid.set_row_ids(&[(2, 101)]).unwrap();
    assert_eq!(grid.resolve_row_target(&target), None);
}

#[test]
fn disabled_import_subtotal_and_tree_operations_never_enable_identity_storage() {
    use volvoxgrid_engine::load;
    let mut grid = grid_without_ids();
    let options = pb::LoadDataOptions {
        header_policy: Some(pb::HeaderPolicy::HeaderNone as i32),
        ..Default::default()
    };
    load::append_data(&mut grid, b"C\nD", Some(&options));
    assert_ids_disabled(&grid);
    load::load_data(&mut grid, b"1\n2", Some(&options));
    assert_ids_disabled(&grid);
    save::load_grid(
        &mut grid,
        b"Name\n1\n2",
        pb::ExportFormat::ExportTsv as i32,
        pb::ExportScope::ExportDataOnly as i32,
    );
    assert_ids_disabled(&grid);
    outline::subtotal(&mut grid, 2, -1, 0, "Total", 0, 0, true);
    assert_ids_disabled(&grid);
    outline::subtotal(&mut grid, 1, -1, 0, "", 0, 0, true);
    assert_ids_disabled(&grid);
    tree::load_tree(
        &mut grid,
        pb::LoadTreeRequest {
            replace: true,
            nodes: vec![pb::TreeNode {
                node_id: "parent".into(),
                children: vec![pb::TreeNode {
                    node_id: "child".into(),
                    ..Default::default()
                }],
                ..Default::default()
            }],
            ..Default::default()
        },
    )
    .unwrap();
    assert_ids_disabled(&grid);
    let target = grid.capture_row_target(1).unwrap();
    tree::collapse_nodes(
        &mut grid,
        pb::CollapseNodesRequest {
            node_ids: vec!["parent".into()],
            ..Default::default()
        },
    )
    .unwrap();
    tree::expand_nodes(
        &mut grid,
        pb::ExpandNodesRequest {
            node_ids: vec!["parent".into()],
            ..Default::default()
        },
    )
    .unwrap();
    assert_eq!(grid.resolve_row_target(&target), None);
    assert_ids_disabled(&grid);
}
