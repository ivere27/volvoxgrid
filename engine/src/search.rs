use crate::grid::VolvoxGrid;

/// Find the first row (starting at `start_row`) where the cell in `col`
/// matches `text`.
///
/// - `case_sense`: if false, comparison is case-insensitive.
/// - `full_match`: if true, the cell text must equal the search text exactly;
///   otherwise a substring match is sufficient.
///
/// Returns the matching row index, or -1 if not found.
pub fn find_row(
    grid: &VolvoxGrid,
    text: &str,
    start_row: i32,
    col: i32,
    case_sense: bool,
    full_match: bool,
) -> i32 {
    let start = if start_row < grid.fixed_rows {
        grid.fixed_rows
    } else {
        start_row
    };
    let search = if case_sense {
        text.to_string()
    } else {
        text.to_lowercase()
    };

    for row in start..grid.rows {
        if col < 0 {
            // Search across all columns in this row
            let mut found_in_row = false;
            for c in 0..grid.cols {
                let cell_text = grid.cells.get_text(row, c);
                let compare = if case_sense {
                    cell_text.to_string()
                } else {
                    cell_text.to_lowercase()
                };
                let found = if full_match {
                    compare == search
                } else {
                    compare.contains(&search)
                };
                if found {
                    found_in_row = true;
                    break;
                }
            }
            // Also check row user_data if available
            if !found_in_row {
                if let Some(rp) = grid.row_props.get(&row) {
                    if let Some(ref user_data) = rp.user_data {
                        let ud_text = String::from_utf8_lossy(user_data);
                        let compare = if case_sense {
                            ud_text.to_string()
                        } else {
                            ud_text.to_lowercase()
                        };
                        let found = if full_match {
                            compare == search
                        } else {
                            compare.contains(&search)
                        };
                        if found {
                            found_in_row = true;
                        }
                    }
                }
            }
            if found_in_row {
                return row;
            }
        } else {
            let cell_text = grid.cells.get_text(row, col);
            let compare = if case_sense {
                cell_text.to_string()
            } else {
                cell_text.to_lowercase()
            };

            let found = if full_match {
                compare == search
            } else {
                compare.contains(&search)
            };

            if found {
                return row;
            }
        }
    }
    -1 // not found
}

/// Find the first row (starting at `start_row`) where the cell in `col`
/// matches the given regex `pattern`.
///
/// Returns the matching row index, or -1 if not found or if the pattern
/// is invalid.
#[cfg(feature = "regex")]
pub fn find_row_regex(grid: &VolvoxGrid, pattern: &str, start_row: i32, col: i32) -> i32 {
    let re = match regex::Regex::new(pattern) {
        Ok(r) => r,
        Err(_) => return -1,
    };

    let start = if start_row < grid.fixed_rows {
        grid.fixed_rows
    } else {
        start_row
    };

    for row in start..grid.rows {
        let cell_text = grid.cells.get_text(row, col);
        if re.is_match(cell_text) {
            return row;
        }
    }
    -1
}

#[cfg(not(feature = "regex"))]
pub fn find_row_regex(_grid: &VolvoxGrid, _pattern: &str, _start_row: i32, _col: i32) -> i32 {
    -1
}

/// Perform a type-ahead: sets `is_type_ahead_active` state, fires events, and
/// finds the row matching `text` in `col`.
///
/// Type-ahead is triggered by typing in a non-editable grid. Sets `grid.is_type_ahead_active = true` during search and
/// fires `TypeAheadStarted` / `TypeAheadEnded` events.
///
/// Returns the matching row index, or -1 if not found.
pub fn type_ahead(grid: &mut VolvoxGrid, text: &str, col: i32, from_top: bool) -> i32 {
    grid.is_type_ahead_active = true;
    grid.events
        .push(crate::event::GridEventData::TypeAheadStarted {
            col,
            text: text.to_string(),
        });

    let start_row = if from_top {
        grid.fixed_rows
    } else {
        grid.selection.row
    };
    let result = find_row(grid, text, start_row, col, false, false);

    grid.is_type_ahead_active = false;
    grid.events
        .push(crate::event::GridEventData::TypeAheadEnded);

    result
}

/// Type-ahead with keystroke buffering support.
///
/// Appends the given character to the internal search buffer and performs
/// a search using the accumulated text. The host is responsible for timing:
/// it should call `type_ahead_clear_buffer()` when `type_ahead_delay`
/// milliseconds have elapsed since the last keystroke.
///
/// `grid.type_ahead_buffer` accumulates keystrokes between clears.
///
/// Returns the matching row index, or -1 if not found.
pub fn type_ahead_buffered(grid: &mut VolvoxGrid, ch: char, col: i32, from_top: bool) -> i32 {
    grid.type_ahead_buffer.push(ch);
    let search_text = grid.type_ahead_buffer.clone();
    type_ahead(grid, &search_text, col, from_top)
}

/// Clear the type-ahead keystroke buffer.
///
/// The host should call this after `type_ahead_delay` ms of inactivity
/// to reset the buffered search text for the next search sequence.
pub fn type_ahead_clear_buffer(grid: &mut VolvoxGrid) {
    grid.type_ahead_buffer.clear();
}

/// Compute an aggregate value over the rectangular cell range
/// `[row1..=row2, col1..=col2]`.
///
/// Cells whose text can be parsed as `f64` (after stripping commas, dollar
/// signs, and spaces) are included; non-numeric cells are silently skipped.
///
/// `agg_type` selects the function:
///
/// | Code | Function                        |
/// |------|---------------------------------|
/// | 2    | Sum                             |
/// | 3    | Percent (100 if sum != 0, else 0) |
/// | 4    | Count of numeric cells          |
/// | 5    | Average (mean)                  |
/// | 6    | Maximum                         |
/// | 7    | Minimum                         |
/// | 8    | Standard deviation (sample)     |
/// | 9    | Variance (sample)               |
/// | 10   | Standard deviation (population) |
/// | 11   | Variance (population)           |
///
/// Returns 0.0 for unknown codes or when no numeric values exist.
pub fn aggregate(
    grid: &VolvoxGrid,
    agg_type: i32,
    row1: i32,
    col1: i32,
    row2: i32,
    col2: i32,
) -> f64 {
    let mut values: Vec<f64> = Vec::new();

    for r in row1..=row2.min(grid.rows - 1) {
        for c in col1..=col2.min(grid.cols - 1) {
            let text = grid.cells.get_text(r, c);
            if let Ok(v) = text.replace([',', '$', ' '], "").parse::<f64>() {
                values.push(v);
            }
        }
    }

    if values.is_empty() {
        return 0.0;
    }

    match agg_type {
        2 => values.iter().sum(),
        3 => {
            let total: f64 = values.iter().sum();
            if total != 0.0 {
                100.0
            } else {
                0.0
            }
        }
        4 => values.len() as f64,
        5 => values.iter().sum::<f64>() / values.len() as f64,
        6 => values.iter().cloned().fold(f64::NEG_INFINITY, f64::max),
        7 => values.iter().cloned().fold(f64::INFINITY, f64::min),
        8 => {
            // Sample standard deviation (N-1)
            if values.len() < 2 {
                return 0.0;
            }
            let mean = values.iter().sum::<f64>() / values.len() as f64;
            let var =
                values.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / (values.len() - 1) as f64;
            var.sqrt()
        }
        9 => {
            // Sample variance (N-1)
            if values.len() < 2 {
                return 0.0;
            }
            let mean = values.iter().sum::<f64>() / values.len() as f64;
            values.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / (values.len() - 1) as f64
        }
        10 => {
            // Population standard deviation (N)
            let mean = values.iter().sum::<f64>() / values.len() as f64;
            let var = values.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / values.len() as f64;
            var.sqrt()
        }
        11 => {
            // Population variance (N)
            let mean = values.iter().sum::<f64>() / values.len() as f64;
            values.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / values.len() as f64
        }
        _ => 0.0,
    }
}
