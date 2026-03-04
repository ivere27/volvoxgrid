use crate::proto::volvoxgrid::v1 as pb;
use crate::style::HighlightStyle;

/// Selection state
#[derive(Clone, Debug)]
pub struct SelectionState {
    pub row: i32,                  // current cursor row
    pub col: i32,                  // current cursor col
    pub row_end: i32,              // selection extent row
    pub col_end: i32,              // selection extent col
    pub mode: i32,                 // SelectionMode enum (0=free, 1=by_row, 2=by_col, 3=listbox)
    pub focus_border: i32,         // FocusBorderStyle enum
    pub selection_visibility: i32, // SelectionVisibility enum
    pub allow_selection: bool,
    pub header_click_select: bool,
    pub selection_style: HighlightStyle,
    pub hover_mode: u32,
    pub hover_row_style: HighlightStyle,
    pub hover_column_style: HighlightStyle,
    pub hover_cell_style: HighlightStyle,
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
            hover_mode: pb::HoverMode::HoverNone as u32,
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
    }

    /// Select a range
    pub fn select(&mut self, row1: i32, col1: i32, row2: i32, col2: i32, rows: i32, cols: i32) {
        let max_r = (rows - 1).max(0);
        let max_c = (cols - 1).max(0);
        self.row = row1.clamp(0, max_r);
        self.col = col1.clamp(0, max_c);
        self.row_end = if row2 < 0 {
            self.row
        } else {
            row2.clamp(0, max_r)
        };
        self.col_end = if col2 < 0 {
            self.col
        } else {
            col2.clamp(0, max_c)
        };
    }

    /// Get normalized selection range (row1 <= row2, col1 <= col2)
    pub fn get_range(&self) -> (i32, i32, i32, i32) {
        let r1 = self.row.min(self.row_end);
        let r2 = self.row.max(self.row_end);
        let c1 = self.col.min(self.col_end);
        let c2 = self.col.max(self.col_end);
        // Apply mode constraints
        match self.mode {
            m if m == pb::SelectionMode::SelectionByRow as i32 => (r1, 0, r2, i32::MAX),
            m if m == pb::SelectionMode::SelectionByColumn as i32 => (0, c1, i32::MAX, c2),
            _ => (r1, c1, r2, c2),
        }
    }

    /// Check if a cell is within the current selection
    pub fn is_selected(&self, row: i32, col: i32, total_cols: i32) -> bool {
        if self.mode == pb::SelectionMode::SelectionListbox as i32 {
            // Listbox mode: toggled rows + current cursor row
            return self.selected_rows.contains(&row) || row == self.row;
        }
        let (r1, c1, r2, c2) = self.get_range();
        let c2 = if c2 == i32::MAX { total_cols - 1 } else { c2 };
        let r2 = if r2 == i32::MAX { i32::MAX } else { r2 };
        row >= r1 && row <= r2 && col >= c1 && col <= c2
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
            let (r1, _, r2, _) = self.get_range();
            (r2 - r1 + 1).max(0)
        }
    }
}
