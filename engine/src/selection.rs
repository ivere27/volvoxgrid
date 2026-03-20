use crate::proto::volvoxgrid::v1 as pb;
use crate::style::HighlightStyle;

pub const HOVER_NONE: u32 = 0;
pub const HOVER_ROW: u32 = 1;
pub const HOVER_COLUMN: u32 = 2;
pub const HOVER_CELL: u32 = 4;

#[inline]
pub fn hover_mode_has(mode: u32, flag: u32) -> bool {
    mode & flag != 0
}

/// Selection state
#[derive(Clone, Debug)]
pub struct SelectionState {
    pub row: i32,                                // current cursor row
    pub col: i32,                                // current cursor col
    pub row_end: i32,                            // selection extent row
    pub col_end: i32,                            // selection extent col
    pub extra_ranges: Vec<(i32, i32, i32, i32)>, // additional normalized ranges beyond the active one
    pub mode: i32,         // SelectionMode enum (0=free, 1=by_row, 2=by_col, 3=listbox)
    pub focus_border: i32, // FocusBorderStyle enum
    pub selection_visibility: i32, // SelectionVisibility enum
    pub allow_selection: bool,
    pub header_click_select: bool,
    pub selection_style: HighlightStyle,
    pub active_cell_style: HighlightStyle,
    pub hover_mode: u32,
    pub hover_row_style: HighlightStyle,
    pub hover_column_style: HighlightStyle,
    pub hover_cell_style: HighlightStyle,
    /// Optional indicator-specific selection highlight.
    /// When set, row/col indicators use these instead of `selection_style`.
    pub indicator_row_style: Option<HighlightStyle>,
    pub indicator_col_style: Option<HighlightStyle>,
    // For listbox mode - track individually selected rows
    pub selected_rows: std::collections::HashSet<i32>,
}

impl Default for SelectionState {
    fn default() -> Self {
        Self {
            row: 0,
            col: 0,
            row_end: 0,
            col_end: 0,
            extra_ranges: Vec::new(),
            mode: pb::SelectionMode::SelectionFree as i32,
            focus_border: pb::FocusBorderStyle::FocusBorderThin as i32,
            selection_visibility: pb::SelectionVisibility::SelectionVisAlways as i32,
            allow_selection: true,
            header_click_select: true,
            selection_style: HighlightStyle {
                back_color: Some(0xFF000080),
                fore_color: Some(0xFFFFFFFF),
                fill_handle: Some(pb::FillHandlePosition::FillHandleNone as i32),
                fill_handle_color: Some(0xFF217346),
                ..HighlightStyle::default()
            },
            active_cell_style: HighlightStyle::default(),
            hover_mode: HOVER_NONE,
            // ROW/COLUMN are intentionally subtle to provide axis context.
            hover_row_style: HighlightStyle {
                back_color: Some(0x10000000),
                ..HighlightStyle::default()
            },
            hover_column_style: HighlightStyle {
                back_color: Some(0x10000000),
                ..HighlightStyle::default()
            },
            // CELL is stronger so ROW+COL+CELL still clearly points to one target.
            hover_cell_style: HighlightStyle {
                back_color: Some(0x22000000),
                border: Some(pb::BorderStyle::BorderThin as i32),
                border_color: Some(0xFF1A73E8),
                ..HighlightStyle::default()
            },
            indicator_row_style: None,
            indicator_col_style: None,
            selected_rows: std::collections::HashSet::new(),
        }
    }
}

impl SelectionState {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn heap_size_bytes(&self) -> usize {
        self.selected_rows.capacity() * (std::mem::size_of::<i32>() + 8)
            + self.extra_ranges.capacity() * std::mem::size_of::<(i32, i32, i32, i32)>()
    }

    /// Create with initial cursor position clamped to fixed area
    pub fn with_initial(fixed_rows: i32, fixed_cols: i32) -> Self {
        Self {
            row: fixed_rows,
            col: fixed_cols,
            row_end: fixed_rows,
            col_end: fixed_cols,
            ..Self::default()
        }
    }

    /// Clamp cursor and selection to the valid range after resize
    pub fn clamp(&mut self, rows: i32, cols: i32, fixed_rows: i32, fixed_cols: i32) {
        if rows <= 0 || cols <= 0 {
            return;
        }
        self.row = self.row.clamp(fixed_rows.min(rows - 1), rows - 1);
        self.col = self.col.clamp(fixed_cols.min(cols - 1), cols - 1);
        self.row_end = self.row_end.clamp(fixed_rows.min(rows - 1), rows - 1);
        self.col_end = self.col_end.clamp(fixed_cols.min(cols - 1), cols - 1);
        for range in &mut self.extra_ranges {
            *range = Self::normalize_range(range.0, range.1, range.2, range.3, rows, cols);
        }
    }

    /// Keep a collapsed default cursor attached to the first scrollable cell
    /// when the fixed bands change.
    pub fn remap_collapsed_cursor_after_fixed_change(
        &mut self,
        rows: i32,
        cols: i32,
        old_fixed_rows: i32,
        old_fixed_cols: i32,
        new_fixed_rows: i32,
        new_fixed_cols: i32,
    ) {
        if rows <= 0 || cols <= 0 {
            return;
        }

        let old_first_row = old_fixed_rows.min(rows - 1);
        let old_first_col = old_fixed_cols.min(cols - 1);
        let new_first_row = new_fixed_rows.min(rows - 1);
        let new_first_col = new_fixed_cols.min(cols - 1);

        if self.row == self.row_end && self.row == old_first_row {
            self.row = new_first_row;
            self.row_end = new_first_row;
        }
        if self.col == self.col_end && self.col == old_first_col {
            self.col = new_first_col;
            self.col_end = new_first_col;
        }

        self.clamp(rows, cols, new_fixed_rows, new_fixed_cols);
    }

    /// Set cursor position, clamping to valid range.
    /// Always collapses selection to a single cell (setting Row/Col
    /// programmatically resets RowSel/ColSel).
    pub fn set_cursor(
        &mut self,
        row: i32,
        col: i32,
        rows: i32,
        cols: i32,
        fixed_rows: i32,
        fixed_cols: i32,
    ) {
        let max_r = (rows - 1).max(fixed_rows);
        let max_c = (cols - 1).max(fixed_cols);
        self.row = row.clamp(fixed_rows, max_r);
        self.col = col.clamp(fixed_cols, max_c);
        self.row_end = self.row;
        self.col_end = self.col;
        self.extra_ranges.clear();
        if self.mode != pb::SelectionMode::SelectionListbox as i32 {
            self.selected_rows.clear();
        }
    }

    /// Select a range
    pub fn select(&mut self, row1: i32, col1: i32, row2: i32, col2: i32, rows: i32, cols: i32) {
        let (row1, col1, row2, col2) = Self::normalize_range(row1, col1, row2, col2, rows, cols);
        self.row = row1;
        self.col = col1;
        self.row_end = row2;
        self.col_end = col2;
        self.extra_ranges.clear();
        self.selected_rows.clear();
    }

    /// Replace the active selection with the supplied set of ranges.
    pub fn select_ranges(
        &mut self,
        active_row: i32,
        active_col: i32,
        ranges: &[(i32, i32, i32, i32)],
        rows: i32,
        cols: i32,
    ) {
        if rows <= 0 || cols <= 0 {
            return;
        }
        if ranges.is_empty() {
            self.select(active_row, active_col, active_row, active_col, rows, cols);
            return;
        }

        let normalized: Vec<(i32, i32, i32, i32)> = ranges
            .iter()
            .map(|&(row1, col1, row2, col2)| {
                Self::normalize_range(row1, col1, row2, col2, rows, cols)
            })
            .collect();

        let mut active_index = 0usize;
        let clamped_active_row = active_row.clamp(0, rows - 1);
        let clamped_active_col = active_col.clamp(0, cols - 1);
        if let Some(index) = normalized.iter().position(|&(row1, col1, row2, col2)| {
            (row1 == clamped_active_row && col1 == clamped_active_col)
                || (row2 == clamped_active_row && col2 == clamped_active_col)
        }) {
            active_index = index;
        }

        let active = normalized[active_index];
        if active.0 == clamped_active_row && active.1 == clamped_active_col {
            self.row = active.0;
            self.col = active.1;
            self.row_end = active.2;
            self.col_end = active.3;
        } else if active.2 == clamped_active_row && active.3 == clamped_active_col {
            self.row = active.2;
            self.col = active.3;
            self.row_end = active.0;
            self.col_end = active.1;
        } else {
            self.row = active.0;
            self.col = active.1;
            self.row_end = active.2;
            self.col_end = active.3;
        }

        self.extra_ranges = normalized
            .into_iter()
            .enumerate()
            .filter_map(|(index, range)| {
                if index == active_index {
                    None
                } else {
                    Some(range)
                }
            })
            .collect();
        self.selected_rows.clear();
    }

    /// Update only the active selection extent, collapsing any additional ranges.
    pub fn set_extent(&mut self, row_end: i32, col_end: i32, rows: i32, cols: i32) {
        let max_r = (rows - 1).max(0);
        let max_c = (cols - 1).max(0);
        self.row_end = row_end.clamp(0, max_r);
        self.col_end = col_end.clamp(0, max_c);
        self.extra_ranges.clear();
    }

    /// Get normalized selection range (row1 <= row2, col1 <= col2)
    pub fn get_range(&self) -> (i32, i32, i32, i32) {
        let (r1, c1, r2, c2) = self.active_range();
        // Apply mode constraints
        match self.mode {
            m if m == pb::SelectionMode::SelectionByRow as i32 => (r1, 0, r2, i32::MAX),
            m if m == pb::SelectionMode::SelectionByColumn as i32 => (0, c1, i32::MAX, c2),
            _ => (r1, c1, r2, c2),
        }
    }

    pub fn all_ranges(&self, rows: i32, cols: i32) -> Vec<(i32, i32, i32, i32)> {
        if rows <= 0 || cols <= 0 {
            return Vec::new();
        }
        if self.mode == pb::SelectionMode::SelectionListbox as i32 {
            let mut ranges = vec![(self.row, self.col, self.row, self.col)];
            let mut selected_rows: Vec<i32> = self.selected_rows.iter().copied().collect();
            selected_rows.sort_unstable();
            for row in selected_rows {
                if row != self.row {
                    ranges.push((row, 0, row, cols - 1));
                }
            }
            return ranges;
        }

        let mut ranges = Vec::with_capacity(1 + self.extra_ranges.len());
        ranges.push(self.apply_mode_bounds(self.active_range(), rows, cols));
        for &range in &self.extra_ranges {
            ranges.push(self.apply_mode_bounds(range, rows, cols));
        }
        ranges
    }

    /// Check if a cell is within the current selection
    pub fn is_selected(&self, row: i32, col: i32, total_cols: i32) -> bool {
        if self.mode == pb::SelectionMode::SelectionListbox as i32 {
            // Listbox mode: toggled rows + current cursor row
            return self.selected_rows.contains(&row) || row == self.row;
        }
        self.iter_selection_ranges(total_cols)
            .any(|(r1, c1, r2, c2)| row >= r1 && row <= r2 && col >= c1 && col <= c2)
    }

    /// Toggle row selection in listbox mode
    pub fn toggle_row(&mut self, row: i32) {
        if self.selected_rows.contains(&row) {
            self.selected_rows.remove(&row);
        } else {
            self.selected_rows.insert(row);
        }
    }

    /// Get count of selected rows
    pub fn selected_row_count(&self) -> i32 {
        if self.mode == pb::SelectionMode::SelectionListbox as i32 {
            self.selected_rows.len() as i32
        } else {
            self.iter_selection_ranges(i32::MAX)
                .map(|(r1, _, r2, _)| (r2 - r1 + 1).max(0))
                .sum()
        }
    }

    fn active_range(&self) -> (i32, i32, i32, i32) {
        (
            self.row.min(self.row_end),
            self.col.min(self.col_end),
            self.row.max(self.row_end),
            self.col.max(self.col_end),
        )
    }

    fn apply_mode_bounds(
        &self,
        range: (i32, i32, i32, i32),
        rows: i32,
        cols: i32,
    ) -> (i32, i32, i32, i32) {
        match self.mode {
            m if m == pb::SelectionMode::SelectionByRow as i32 => (range.0, 0, range.2, cols - 1),
            m if m == pb::SelectionMode::SelectionByColumn as i32 => {
                (0, range.1, rows - 1, range.3)
            }
            _ => range,
        }
    }

    fn iter_selection_ranges(
        &self,
        total_cols: i32,
    ) -> impl Iterator<Item = (i32, i32, i32, i32)> + '_ {
        let active = std::iter::once(self.get_range());
        let extras = self
            .extra_ranges
            .iter()
            .copied()
            .map(move |range| match self.mode {
                m if m == pb::SelectionMode::SelectionByRow as i32 => {
                    (range.0, 0, range.2, total_cols - 1)
                }
                m if m == pb::SelectionMode::SelectionByColumn as i32 => {
                    (0, range.1, i32::MAX, range.3)
                }
                _ => range,
            });
        active.chain(extras)
    }

    fn normalize_range(
        row1: i32,
        col1: i32,
        row2: i32,
        col2: i32,
        rows: i32,
        cols: i32,
    ) -> (i32, i32, i32, i32) {
        let max_r = (rows - 1).max(0);
        let max_c = (cols - 1).max(0);
        let r1 = row1.clamp(0, max_r);
        let c1 = col1.clamp(0, max_c);
        let r2 = if row2 < 0 { r1 } else { row2.clamp(0, max_r) };
        let c2 = if col2 < 0 { c1 } else { col2.clamp(0, max_c) };
        (r1.min(r2), c1.min(c2), r1.max(r2), c1.max(c2))
    }
}

#[cfg(test)]
mod tests {
    use super::SelectionState;
    use crate::proto::volvoxgrid::v1 as pb;

    #[test]
    fn select_ranges_preserves_active_and_extra_ranges() {
        let mut selection = SelectionState::default();
        selection.select_ranges(5, 6, &[(5, 6, 7, 8), (1, 1, 2, 2)], 10, 10);

        assert_eq!(selection.row, 5);
        assert_eq!(selection.col, 6);
        assert_eq!(selection.row_end, 7);
        assert_eq!(selection.col_end, 8);
        assert_eq!(selection.extra_ranges, vec![(1, 1, 2, 2)]);
        assert_eq!(
            selection.all_ranges(10, 10),
            vec![(5, 6, 7, 8), (1, 1, 2, 2)]
        );
    }

    #[test]
    fn listbox_cursor_moves_preserve_toggled_rows() {
        let mut selection = SelectionState::default();
        selection.mode = pb::SelectionMode::SelectionListbox as i32;
        selection.selected_rows.insert(1);
        selection.selected_rows.insert(4);

        selection.set_cursor(4, 2, 10, 10, 0, 0);

        assert!(selection.selected_rows.contains(&1));
        assert!(selection.selected_rows.contains(&4));
        assert_eq!(
            selection.all_ranges(10, 10),
            vec![(4, 2, 4, 2), (1, 0, 1, 9)]
        );
    }

    #[test]
    fn collapsed_cursor_tracks_first_scrollable_cell_after_fixed_change() {
        let mut selection = SelectionState::with_initial(1, 1);

        selection.remap_collapsed_cursor_after_fixed_change(21, 5, 1, 1, 1, 0);

        assert_eq!(selection.row, 1);
        assert_eq!(selection.col, 0);
        assert_eq!(selection.row_end, 1);
        assert_eq!(selection.col_end, 0);
    }

    #[test]
    fn expanded_selection_keeps_logical_bounds_after_fixed_change() {
        let mut selection = SelectionState::default();
        selection.select(1, 1, 4, 3, 21, 5);

        selection.remap_collapsed_cursor_after_fixed_change(21, 5, 1, 1, 1, 0);

        assert_eq!(selection.row, 1);
        assert_eq!(selection.col, 1);
        assert_eq!(selection.row_end, 4);
        assert_eq!(selection.col_end, 3);
    }
}
