use crate::event::GridEventData;
use crate::grid::VolvoxGrid;

/// Copy selected cells to clipboard format (tab-delimited text).
///
/// Returns `(text, rich_data)` where `text` is the tab/newline-delimited
/// string of cell contents and `rich_data` is reserved for future use.
pub fn copy(grid: &VolvoxGrid) -> (String, Vec<u8>) {
    if grid.edit.is_active() {
        return (grid.edit.get_sel_text().to_string(), Vec::new());
    }

    let ranges: Vec<(i32, i32, i32, i32)> = grid
        .selection
        .all_ranges(grid.rows, grid.cols)
        .into_iter()
        .map(|(r1, c1, r2, c2)| {
            (
                r1.max(0).min(grid.rows - 1),
                c1.max(0).min(grid.cols - 1),
                r2.max(0).min(grid.rows - 1),
                c2.max(0).min(grid.cols - 1),
            )
        })
        .collect();
    if ranges.is_empty() {
        return (String::new(), Vec::new());
    }

    let mut r1 = grid.rows - 1;
    let mut c1 = grid.cols - 1;
    let mut r2 = 0;
    let mut c2 = 0;
    for &(range_r1, range_c1, range_r2, range_c2) in &ranges {
        r1 = r1.min(range_r1);
        c1 = c1.min(range_c1);
        r2 = r2.max(range_r2);
        c2 = c2.max(range_c2);
    }

    let col_sep = if grid.clip_col_separator.is_empty() {
        "\t"
    } else {
        &grid.clip_col_separator
    };
    let row_sep = if grid.clip_row_separator.is_empty() {
        "\n"
    } else {
        &grid.clip_row_separator
    };

    let mut text = String::new();
    for r in r1..=r2 {
        if r > r1 {
            text.push_str(row_sep);
        }
        for c in c1..=c2 {
            if c > c1 {
                text.push_str(col_sep);
            }
            if ranges
                .iter()
                .any(|&(sr1, sc1, sr2, sc2)| r >= sr1 && r <= sr2 && c >= sc1 && c <= sc2)
            {
                text.push_str(grid.cells.get_text(r, c));
            }
        }
    }

    (text, Vec::new()) // rich_data not implemented yet
}

/// Cut = copy the selection, then delete the selected cells.
///
/// Returns the same `(text, rich_data)` tuple as `copy`.
pub fn cut(grid: &mut VolvoxGrid) -> (String, Vec<u8>) {
    if grid.edit.is_active() {
        if active_readonly_dropdown_edit(grid) {
            return (String::new(), Vec::new());
        }
        let text = grid.edit.get_sel_text().to_string();
        if grid.edit.delete_selection() {
            grid.events.push(GridEventData::CellEditChange {
                text: grid.edit.edit_text.clone(),
            });
            grid.mark_dirty();
        }
        return (text, Vec::new());
    }

    let result = copy(grid);
    delete_selection(grid);
    result
}

/// Paste clipboard text into the grid starting at the current cursor position.
///
/// The text is split by the grid's row and column separators, and each
/// resulting cell value is written into the grid. Pasting stops at the
/// grid boundary (does not auto-extend rows/cols).
pub fn paste(grid: &mut VolvoxGrid, text: &str) {
    if grid.edit.is_active() {
        if active_readonly_dropdown_edit(grid) {
            paste_into_readonly_dropdown(grid, text);
            return;
        }
        paste_into_edit(grid, text);
        return;
    }

    let col_sep = if grid.clip_col_separator.is_empty() {
        "\t".to_string()
    } else {
        grid.clip_col_separator.clone()
    };
    let row_sep = if grid.clip_row_separator.is_empty() {
        "\n".to_string()
    } else {
        grid.clip_row_separator.clone()
    };

    if row_sep == "\n" {
        let normalized = text.replace("\r\n", "\n").replace('\r', "\n");
        paste_rows(grid, normalized.split('\n'), &col_sep);
    } else {
        paste_rows(grid, text.split(&row_sep), &col_sep);
    }
    grid.mark_dirty();
}

fn active_readonly_dropdown_edit(grid: &VolvoxGrid) -> bool {
    grid.edit.is_active() && !grid.edit.dropdown_items.is_empty() && !grid.edit.dropdown_editable
}

fn paste_into_readonly_dropdown(grid: &mut VolvoxGrid, text: &str) {
    let Some(candidate) = single_clipboard_value(text) else {
        return;
    };
    if candidate.is_empty() {
        return;
    }

    for idx in 0..grid.edit.dropdown_count() {
        let item = grid.edit.get_dropdown_item(idx);
        let data = grid.edit.get_dropdown_data(idx);
        if item == candidate || (!data.is_empty() && data == candidate) {
            let selected = item.to_string();
            grid.edit.set_dropdown_index(idx);
            grid.edit.clear_dropdown_search();
            grid.events
                .push(GridEventData::CellEditChange { text: selected });
            grid.mark_dirty();
            return;
        }
    }
}

fn single_clipboard_value(text: &str) -> Option<String> {
    let normalized = text.replace("\r\n", "\n").replace('\r', "\n");
    let value = normalized.strip_suffix('\n').unwrap_or(&normalized);
    if value.contains('\n') || value.contains('\t') {
        return None;
    }
    Some(value.to_string())
}

fn paste_into_edit(grid: &mut VolvoxGrid, text: &str) {
    let normalized = text.replace("\r\n", "\n").replace('\r', "\n");
    let total = grid.edit.edit_text.chars().count() as i32;
    let sel_start = grid.edit.sel_start.clamp(0, total);
    let sel_end = (grid.edit.sel_start + grid.edit.sel_length.max(0)).clamp(sel_start, total);
    let selected_len = sel_end - sel_start;
    let available = if grid.edit_max_length > 0 {
        (grid.edit_max_length - (total - selected_len)).max(0) as usize
    } else {
        usize::MAX
    };
    let insert_text = if available == usize::MAX {
        normalized
    } else {
        normalized.chars().take(available).collect()
    };

    if insert_text.is_empty() && selected_len <= 0 {
        return;
    }

    let before_text = grid.edit.edit_text.clone();
    let before_start = grid.edit.sel_start;
    let before_length = grid.edit.sel_length;
    grid.edit.insert_text(&insert_text);
    if grid.edit.edit_text != before_text
        || grid.edit.sel_start != before_start
        || grid.edit.sel_length != before_length
    {
        grid.events.push(GridEventData::CellEditChange {
            text: grid.edit.edit_text.clone(),
        });
        grid.mark_dirty();
    }
}

fn paste_rows<'a, I>(grid: &mut VolvoxGrid, rows: I, col_sep: &str)
where
    I: IntoIterator<Item = &'a str>,
{
    let start_row = grid.selection.row;
    let start_col = grid.selection.col;

    for (ri, line) in rows.into_iter().enumerate() {
        let row = start_row + ri as i32;
        if row >= grid.rows {
            break;
        }
        for (ci, cell) in line.split(col_sep).enumerate() {
            let col = start_col + ci as i32;
            if col >= grid.cols {
                break;
            }
            grid.cells.set_text(row, col, cell.to_string());
        }
    }
}

/// Delete (clear) all cells within the current selection.
pub fn delete_selection(grid: &mut VolvoxGrid) {
    let ranges = grid.selection.all_ranges(grid.rows, grid.cols);
    for (r1, c1, r2, c2) in ranges {
        let r1 = r1.max(0).min(grid.rows - 1);
        let c1 = c1.max(0).min(grid.cols - 1);
        let r2 = r2.max(0).min(grid.rows - 1);
        let c2 = c2.max(0).min(grid.cols - 1);
        grid.cells.clear_range(r1, c1, r2, c2);
    }
    grid.recompute_barcode_presence();
    grid.mark_dirty();
}

#[cfg(test)]
mod tests {
    use super::{copy, cut, delete_selection, paste};
    use crate::event::GridEventData;
    use crate::grid::VolvoxGrid;
    use crate::proto::volvoxgrid::v1 as pb;

    fn sample_grid() -> VolvoxGrid {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 4, 0, 0);
        grid.cells.set_text(0, 0, "A".to_string());
        grid.cells.set_text(0, 1, "B".to_string());
        grid.cells.set_text(0, 2, "C".to_string());
        grid.cells.set_text(1, 0, "D".to_string());
        grid.cells.set_text(1, 1, "E".to_string());
        grid.cells.set_text(1, 2, "F".to_string());
        grid
    }

    #[test]
    fn copy_uses_bounding_box_for_multi_ranges() {
        let mut grid = sample_grid();
        grid.selection
            .select_ranges(0, 0, &[(0, 0, 1, 0), (0, 2, 1, 2)], grid.rows, grid.cols);

        let (text, _) = copy(&grid);

        assert_eq!(text, "A\t\tC\nD\t\tF");
    }

    #[test]
    fn delete_selection_clears_all_selected_ranges() {
        let mut grid = sample_grid();
        grid.selection
            .select_ranges(0, 0, &[(0, 0, 0, 0), (1, 2, 1, 2)], grid.rows, grid.cols);

        delete_selection(&mut grid);

        assert_eq!(grid.cells.get_text(0, 0), "");
        assert_eq!(grid.cells.get_text(1, 2), "");
        assert_eq!(grid.cells.get_text(0, 1), "B");
    }

    #[test]
    fn paste_default_row_separator_accepts_crlf_without_cell_cr() {
        let mut grid = sample_grid();

        paste(&mut grid, "A1\tB1\tC1\r\nD1\tE1\tF1");

        assert_eq!(grid.cells.get_text(0, 2), "C1");
        assert_eq!(grid.cells.get_text(1, 2), "F1");
    }

    #[test]
    fn copy_applies_row_map_once() {
        let mut grid = sample_grid();
        grid.row_positions = vec![1, 0, 2];
        grid.cells.set_row_map(grid.row_positions.clone());
        grid.selection
            .select_ranges(0, 0, &[(0, 0, 0, 0)], grid.rows, grid.cols);

        let (text, _) = copy(&grid);

        assert_eq!(text, "D");
    }

    #[test]
    fn paste_applies_row_map_once() {
        let mut grid = sample_grid();
        grid.row_positions = vec![1, 0, 2];
        grid.cells.set_row_map(grid.row_positions.clone());

        paste(&mut grid, "X");

        assert_eq!(grid.cells.get_text(0, 0), "X");
        assert_eq!(grid.cells.get_text(1, 0), "A");
    }

    #[test]
    fn copy_cut_paste_operate_on_active_edit_selection() {
        let mut grid = sample_grid();
        grid.edit
            .start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "abcdef");
        grid.edit.set_selection_anchor_and_caret(2, 5);

        let (copied, _) = copy(&grid);
        assert_eq!(copied, "cde");

        let (cut_text, _) = cut(&mut grid);
        assert_eq!(cut_text, "cde");
        assert_eq!(grid.edit.edit_text, "abf");
        assert_eq!(grid.edit.sel_start, 2);
        assert_eq!(grid.edit.sel_length, 0);

        paste(&mut grid, "XY\r\nZ");
        assert_eq!(grid.edit.edit_text, "abXY\nZf");
        assert_eq!(grid.edit.sel_start, 6);
    }

    #[test]
    fn paste_selects_matching_readonly_dropdown_item() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 2;
        grid.columns[0].dropdown_items = "Active|Pending|Shipped".to_string();
        grid.cells.set_text(1, 0, "Pending".to_string());

        grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
        assert!(grid.edit.is_active());

        paste(&mut grid, "Shipped\r\n");

        assert_eq!(grid.edit.edit_text, "Shipped");
        assert_eq!(grid.edit.dropdown_index, 2);
        assert!(grid
            .events
            .drain()
            .iter()
            .any(|event| matches!(event.data, GridEventData::CellEditChange { ref text } if text == "Shipped")));
    }

    #[test]
    fn cut_ignores_readonly_dropdown_edit() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 2;
        grid.columns[0].dropdown_items = "Active|Pending|Shipped".to_string();
        grid.cells.set_text(1, 0, "Pending".to_string());

        grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
        assert!(grid.edit.is_active());
        grid.edit.select_all();
        grid.events.drain();

        let (cut_text, _) = cut(&mut grid);

        assert_eq!(cut_text, "");
        assert_eq!(grid.edit.edit_text, "Pending");
        assert_eq!(grid.edit.dropdown_index, 1);
        assert!(!grid
            .events
            .drain()
            .iter()
            .any(|event| matches!(event.data, GridEventData::CellEditChange { .. })));
    }

    #[test]
    fn paste_rejects_invalid_readonly_dropdown_item() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 2;
        grid.columns[0].dropdown_items = "Active|Pending|Shipped".to_string();
        grid.cells.set_text(1, 0, "Pending".to_string());

        grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
        assert!(grid.edit.is_active());
        grid.events.drain();

        paste(&mut grid, "Injected");

        assert_eq!(grid.edit.edit_text, "Pending");
        assert_eq!(grid.edit.dropdown_index, 1);
        assert!(!grid
            .events
            .drain()
            .iter()
            .any(|event| matches!(event.data, GridEventData::CellEditChange { .. })));
    }

    #[test]
    fn paste_rejects_multi_cell_text_for_readonly_dropdown() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 2;
        grid.columns[0].dropdown_items = "Active|Pending|Shipped".to_string();
        grid.cells.set_text(1, 0, "Pending".to_string());

        grid.begin_edit(1, 0, pb::EditStartReason::EditStartProgrammatic);
        assert!(grid.edit.is_active());

        paste(&mut grid, "Shipped\tExtra");

        assert_eq!(grid.edit.edit_text, "Pending");
        assert_eq!(grid.edit.dropdown_index, 1);
    }

    #[test]
    fn edit_paste_respects_max_length_after_replacing_selection() {
        let mut grid = sample_grid();
        grid.edit_max_length = 5;
        grid.edit
            .start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "abcde");
        grid.edit.set_selection_anchor_and_caret(2, 4);

        paste(&mut grid, "WXYZ");

        assert_eq!(grid.edit.edit_text, "abWXe");
        assert_eq!(grid.edit.sel_start, 4);
    }
}
