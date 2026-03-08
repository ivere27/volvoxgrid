use crate::grid::VolvoxGrid;

/// Copy selected cells to clipboard format (tab-delimited text).
///
/// Returns `(text, rich_data)` where `text` is the tab/newline-delimited
/// string of cell contents and `rich_data` is reserved for future use.
pub fn copy(grid: &VolvoxGrid) -> (String, Vec<u8>) {
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
    let start_row = grid.selection.row;
    let start_col = grid.selection.col;

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

    for (ri, line) in text.split(row_sep).enumerate() {
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
    grid.mark_dirty();
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
    grid.mark_dirty();
}

#[cfg(test)]
mod tests {
    use super::{copy, delete_selection};
    use crate::grid::VolvoxGrid;

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
}
