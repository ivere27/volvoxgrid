/// Drag/drop state tracking.
///
/// `drag_mode` controls whether rows/columns can be dragged:
/// - 0 = none
/// - 1 = rows only
/// - 2 = columns only
/// - 3 = both
///
/// `drop_mode` controls what happens on drop:
/// - 0 = none (drag disabled at drop level)
/// - 1 = move
/// - 2 = copy
#[derive(Clone, Debug)]
pub struct DragState {
    pub drag_mode: i32,
    pub drop_mode: i32,
    pub dragging: bool,
    pub drag_row: i32,
    pub drag_col: i32,
    pub drop_row: i32,
}

impl Default for DragState {
    fn default() -> Self {
        Self {
            drag_mode: 0,
            drop_mode: 0,
            dragging: false,
            drag_row: -1,
            drag_col: -1,
            drop_row: -1,
        }
    }
}

/// Move a data row from its current display position to a new position.
///
/// Both `row` and `position` must be within the scrollable area
/// (>= `fixed_rows` and < `rows`). If `row == position` or either is
/// out of range, the call is a no-op.
///
/// The move is performed by removing the entry from `row_positions` and
/// re-inserting it at the target index, then invalidating the layout.
pub fn drag_row(grid: &mut crate::grid::VolvoxGrid, row: i32, position: i32) {
    if row < grid.fixed_rows || row >= grid.rows {
        return;
    }
    if position < grid.fixed_rows || position >= grid.rows {
        return;
    }
    if row == position {
        return;
    }

    // Reorder row_positions
    let moving = grid.row_positions.remove(row as usize);
    let insert_at = if position > row {
        position - 1
    } else {
        position
    };
    grid.row_positions.insert(insert_at as usize, moving);

    grid.layout.invalidate();
    grid.mark_dirty();
}
