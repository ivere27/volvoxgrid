/// Cached layout computation - accumulated pixel positions for rows and columns
#[derive(Clone, Debug)]
pub struct LayoutCache {
    pub row_positions: Vec<i32>, // accumulated Y positions (row_positions[i] = pixel Y of row i top edge)
    pub col_positions: Vec<i32>, // accumulated X positions (col_positions[i] = pixel X of col i left edge)
    pub total_width: i32,
    pub total_height: i32,
    pub valid: bool,
    /// Monotonically increasing counter, bumped on every `invalidate()`.
    /// Used as a cache key for render context reuse.
    pub generation: u64,
    pub rows: i32,
    pub cols: i32,
    pub uniform_rows: bool,
    pub uniform_cols: bool,
    pub uniform_row_height: i32,
    pub uniform_col_width: i32,
}

impl LayoutCache {
    pub fn new() -> Self {
        Self {
            row_positions: Vec::new(),
            col_positions: Vec::new(),
            total_width: 0,
            total_height: 0,
            valid: false,
            generation: 0,
            rows: 0,
            cols: 0,
            uniform_rows: false,
            uniform_cols: false,
            uniform_row_height: 0,
            uniform_col_width: 0,
        }
    }

    pub fn heap_size_bytes(&self) -> usize {
        self.row_positions.capacity() * std::mem::size_of::<i32>()
            + self.col_positions.capacity() * std::mem::size_of::<i32>()
    }

    pub fn invalidate(&mut self) {
        self.valid = false;
        self.generation = self.generation.wrapping_add(1);
    }

    fn row_count(&self) -> i32 {
        if self.rows > 0 {
            self.rows
        } else if self.row_positions.len() > 1 {
            (self.row_positions.len() - 1) as i32
        } else {
            0
        }
    }

    fn col_count(&self) -> i32 {
        if self.cols > 0 {
            self.cols
        } else if self.col_positions.len() > 1 {
            (self.col_positions.len() - 1) as i32
        } else {
            0
        }
    }

    /// Rebuild accumulated positions from grid dimensions.
    ///
    /// `row_positions` has length `rows + 1`:
    ///   row_positions[0] = 0
    ///   row_positions[i+1] = row_positions[i] + height_of_row(i)  (0 if hidden)
    ///
    /// Same logic for `col_positions` with length `cols + 1`.
    pub fn rebuild(&mut self, grid: &crate::grid::VolvoxGrid) {
        let rows = grid.rows;
        let cols = grid.cols;
        self.rows = rows;
        self.cols = cols;

        self.uniform_rows = grid.row_heights.is_empty() && grid.rows_hidden.is_empty();
        self.uniform_cols = grid.col_widths.is_empty()
            && grid.cols_hidden.is_empty()
            && grid.col_width_min.is_empty()
            && grid.col_width_max.is_empty();

        if self.uniform_rows {
            self.uniform_row_height = if rows > 0 { grid.row_height(0) } else { 0 }.max(0);
            self.row_positions.clear();
            self.total_height = self.uniform_row_height.saturating_mul(rows.max(0));
        } else {
            self.uniform_row_height = 0;
            self.row_positions.clear();
            self.row_positions.reserve((rows + 1) as usize);
            self.row_positions.push(0);
            for r in 0..rows {
                let prev = *self.row_positions.last().unwrap();
                let h = grid.row_height(r);
                self.row_positions.push(prev + h);
            }
            self.total_height = *self.row_positions.last().unwrap_or(&0);
        }

        if self.uniform_cols {
            self.uniform_col_width = if cols > 0 { grid.col_width(0) } else { 0 }.max(0);
            self.col_positions.clear();
            self.total_width = self.uniform_col_width.saturating_mul(cols.max(0));
        } else {
            self.uniform_col_width = 0;
            self.col_positions.clear();
            self.col_positions.reserve((cols + 1) as usize);
            self.col_positions.push(0);
            for c in 0..cols {
                let prev = *self.col_positions.last().unwrap();
                let w = grid.col_width(c);
                self.col_positions.push(prev + w);
            }
            self.total_width = *self.col_positions.last().unwrap_or(&0);
        }

        self.valid = true;
    }

    /// Binary search to find the row at pixel Y.
    /// Returns the index of the row whose vertical extent contains `y`,
    /// or the last row index if `y` is beyond the total height.
    pub fn row_at_y(&self, y: i32) -> i32 {
        let rows = self.row_count();
        if rows <= 0 {
            return 0;
        }
        if self.uniform_rows {
            let step = self.uniform_row_height.max(0);
            if step <= 0 {
                return 0;
            }
            if y <= 0 {
                return 0;
            }
            if y >= self.total_height {
                return rows - 1;
            }
            return (y / step).clamp(0, rows - 1);
        }
        if self.row_positions.len() < 2 {
            return 0;
        }
        // partition_point returns the first index where row_positions[idx] > y
        let idx = self.row_positions.partition_point(|&pos| pos <= y) as i32;
        // The row containing y is idx - 1, clamped to valid range
        (idx - 1).clamp(0, rows - 1)
    }

    /// Binary search to find the column at pixel X.
    /// Returns the index of the column whose horizontal extent contains `x`,
    /// or the last column index if `x` is beyond the total width.
    pub fn col_at_x(&self, x: i32) -> i32 {
        let cols = self.col_count();
        if cols <= 0 {
            return 0;
        }
        if self.uniform_cols {
            let step = self.uniform_col_width.max(0);
            if step <= 0 {
                return 0;
            }
            if x <= 0 {
                return 0;
            }
            if x >= self.total_width {
                return cols - 1;
            }
            return (x / step).clamp(0, cols - 1);
        }
        if self.col_positions.len() < 2 {
            return 0;
        }
        let idx = self.col_positions.partition_point(|&pos| pos <= x) as i32;
        (idx - 1).clamp(0, cols - 1)
    }

    /// Get visible row range for a viewport.
    ///
    /// Returns `(first_visible_row, last_visible_row)` for the scrollable area.
    /// Fixed rows (0..fixed_rows) are always visible and not affected by scrolling.
    /// The returned range covers scrollable rows whose pixel extent intersects
    /// the viewport: `[scroll_y .. scroll_y + viewport_height)`.
    pub fn visible_rows(&self, scroll_y: f32, viewport_height: i32, fixed_rows: i32) -> (i32, i32) {
        let rows = self.row_count();
        if rows <= 0 {
            return (0, 0);
        }
        let scroll_start = scroll_y.max(0.0) as i32;
        let scroll_end = scroll_start.saturating_add(viewport_height.max(0));

        if self.uniform_rows {
            let step = self.uniform_row_height.max(0);
            if step <= 0 {
                let first = fixed_rows.clamp(0, rows);
                return (first, first - 1);
            }
            let mut first = (scroll_start / step).clamp(0, rows);
            first = first.max(fixed_rows);
            if first >= rows {
                return (rows, rows - 1);
            }
            let last = if scroll_end <= 0 {
                first
            } else {
                ((scroll_end - 1) / step).clamp(first, rows - 1)
            };
            return (first, last);
        }
        if self.row_positions.len() < 2 {
            return (0, 0);
        }

        // First visible scrollable row: the first row whose bottom edge > scroll_y
        // bottom edge of row r = row_positions[r+1]
        let first = {
            let mut lo = fixed_rows;
            let mut hi = rows;
            while lo < hi {
                let mid = lo + (hi - lo) / 2;
                if self.row_positions[(mid + 1) as usize] <= scroll_start {
                    lo = mid + 1;
                } else {
                    hi = mid;
                }
            }
            lo
        };

        // Last visible scrollable row: the last row whose top edge < scroll_y + viewport_height
        // top edge of row r = row_positions[r]
        let last = {
            let mut lo = first;
            let mut hi = rows;
            while lo < hi {
                let mid = lo + (hi - lo) / 2;
                if self.row_positions[mid as usize] < scroll_end {
                    lo = mid + 1;
                } else {
                    hi = mid;
                }
            }
            // lo is now the first row whose top edge >= scroll_end, so last visible is lo - 1
            (lo - 1).max(first)
        };

        (first, last.min(rows - 1))
    }

    /// Get visible column range for a viewport.
    ///
    /// Returns `(first_visible_col, last_visible_col)` for the scrollable area.
    /// Fixed columns (0..fixed_cols) are always visible and not affected by scrolling.
    pub fn visible_cols(&self, scroll_x: f32, viewport_width: i32, fixed_cols: i32) -> (i32, i32) {
        let cols = self.col_count();
        if cols <= 0 {
            return (0, 0);
        }
        let scroll_start = scroll_x.max(0.0) as i32;
        let scroll_end = scroll_start.saturating_add(viewport_width.max(0));

        if self.uniform_cols {
            let step = self.uniform_col_width.max(0);
            if step <= 0 {
                let first = fixed_cols.clamp(0, cols);
                return (first, first - 1);
            }
            let mut first = (scroll_start / step).clamp(0, cols);
            first = first.max(fixed_cols);
            if first >= cols {
                return (cols, cols - 1);
            }
            let last = if scroll_end <= 0 {
                first
            } else {
                ((scroll_end - 1) / step).clamp(first, cols - 1)
            };
            return (first, last);
        }
        if self.col_positions.len() < 2 {
            return (0, 0);
        }

        // First visible scrollable col: the first col whose right edge > scroll_x
        let first = {
            let mut lo = fixed_cols;
            let mut hi = cols;
            while lo < hi {
                let mid = lo + (hi - lo) / 2;
                if self.col_positions[(mid + 1) as usize] <= scroll_start {
                    lo = mid + 1;
                } else {
                    hi = mid;
                }
            }
            lo
        };

        // Last visible scrollable col: the last col whose left edge < scroll_x + viewport_width
        let last = {
            let mut lo = first;
            let mut hi = cols;
            while lo < hi {
                let mid = lo + (hi - lo) / 2;
                if self.col_positions[mid as usize] < scroll_end {
                    lo = mid + 1;
                } else {
                    hi = mid;
                }
            }
            (lo - 1).max(first)
        };

        (first, last.min(cols - 1))
    }

    /// Pixel Y-offset of the top edge of a row.
    pub fn row_pos(&self, row: i32) -> i32 {
        let rows = self.row_count();
        if row < 0 {
            return self.total_height;
        }
        if row == 0 {
            return 0;
        }
        if self.uniform_rows {
            return row
                .clamp(0, rows)
                .saturating_mul(self.uniform_row_height.max(0));
        }
        if row as usize >= self.row_positions.len() {
            return self.total_height;
        }
        self.row_positions[row as usize]
    }

    /// Pixel X-offset of the left edge of a column.
    pub fn col_pos(&self, col: i32) -> i32 {
        let cols = self.col_count();
        if col < 0 {
            return self.total_width;
        }
        if col == 0 {
            return 0;
        }
        if self.uniform_cols {
            return col
                .clamp(0, cols)
                .saturating_mul(self.uniform_col_width.max(0));
        }
        if col as usize >= self.col_positions.len() {
            return self.total_width;
        }
        self.col_positions[col as usize]
    }

    /// Get pixel rect for a cell.
    /// Returns `(x, y, width, height)` in pixels.
    pub fn cell_rect(&self, row: i32, col: i32) -> (i32, i32, i32, i32) {
        let x = self.col_pos(col);
        let y = self.row_pos(row);
        let x2 = self.col_pos(col + 1);
        let y2 = self.row_pos(row + 1);
        (x, y, x2 - x, y2 - y)
    }

    /// Patch column positions after a single column width change.
    /// Much faster than a full rebuild when only one column changed (O(cols) vs O(rows+cols)).
    pub fn patch_col_width(&mut self, col: i32, new_width: i32) {
        if !self.valid {
            return;
        }
        let cols = self.col_count();
        if col < 0 || col >= cols {
            return;
        }
        if self.uniform_cols {
            let base_w = self.uniform_col_width.max(0);
            let new_w = new_width.max(0);
            if base_w == new_w {
                return;
            }
            self.col_positions.clear();
            self.col_positions.reserve((cols + 1) as usize);
            self.col_positions.push(0);
            for c in 0..cols {
                let prev = *self.col_positions.last().unwrap();
                let w = if c == col { new_w } else { base_w };
                self.col_positions.push(prev + w);
            }
            self.total_width = *self.col_positions.last().unwrap_or(&0);
            self.uniform_cols = false;
            self.uniform_col_width = 0;
            return;
        }
        let c = col as usize;
        if c + 1 >= self.col_positions.len() {
            return;
        }
        let old_width = self.col_positions[c + 1] - self.col_positions[c];
        let delta = new_width - old_width;
        if delta == 0 {
            return;
        }
        for i in (c + 1)..self.col_positions.len() {
            self.col_positions[i] += delta;
        }
        self.total_width += delta;
        self.generation = self.generation.wrapping_add(1);
    }

    /// Patch row positions after a single row height change.
    pub fn patch_row_height(&mut self, row: i32, new_height: i32) {
        if !self.valid {
            return;
        }
        let rows = self.row_count();
        if row < 0 || row >= rows {
            return;
        }
        if self.uniform_rows {
            let base_h = self.uniform_row_height.max(0);
            let new_h = new_height.max(0);
            if base_h == new_h {
                return;
            }
            self.row_positions.clear();
            self.row_positions.reserve((rows + 1) as usize);
            self.row_positions.push(0);
            for r in 0..rows {
                let prev = *self.row_positions.last().unwrap();
                let h = if r == row { new_h } else { base_h };
                self.row_positions.push(prev + h);
            }
            self.total_height = *self.row_positions.last().unwrap_or(&0);
            self.uniform_rows = false;
            self.uniform_row_height = 0;
            return;
        }
        let r = row as usize;
        if r + 1 >= self.row_positions.len() {
            return;
        }
        let old_height = self.row_positions[r + 1] - self.row_positions[r];
        let delta = new_height - old_height;
        if delta == 0 {
            return;
        }
        for i in (r + 1)..self.row_positions.len() {
            self.row_positions[i] += delta;
        }
        self.total_height += delta;
        self.generation = self.generation.wrapping_add(1);
    }
}

impl Default for LayoutCache {
    fn default() -> Self {
        Self::new()
    }
}
