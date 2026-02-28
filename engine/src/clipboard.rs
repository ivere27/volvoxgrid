use crate::grid::VolvoxGrid;

/// Copy selected cells to clipboard format (tab-delimited text).
///
/// Returns `(text, rich_data)` where `text` is the tab/newline-delimited
/// string of cell contents and `rich_data` is reserved for future use.
pub fn copy(grid: &VolvoxGrid) -> (String, Vec<u8>) {
    let (r1, c1, r2, c2) = grid.selection.get_range();
    let r2 = r2.min(grid.rows - 1);
    let c2 = c2.min(grid.cols - 1);

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
            text.push_str(grid.cells.get_text(r, c));
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
    let (r1, c1, r2, c2) = grid.selection.get_range();
    let r2 = r2.min(grid.rows - 1);
    let c2 = c2.min(grid.cols - 1);
    grid.cells.clear_range(r1, c1, r2, c2);
    grid.mark_dirty();
}
