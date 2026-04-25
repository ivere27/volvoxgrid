use crate::grid::VolvoxGrid;
use crate::proto::volvoxgrid::v1 as pb;
use std::cell::RefCell;
use std::collections::HashMap;

pub struct SpanState {
    pub mode: i32,                                       // CellSpanMode enum
    pub mode_fixed: i32,                                 // CellSpanMode for fixed cells
    pub span_compare: i32,                               // SpanCompareMode enum
    pub group_span_compare: i32,                         // SpanCompareMode for group keys
    pub span_rows: std::collections::HashMap<i32, bool>, // per-row span enable
    pub span_cols: std::collections::HashMap<i32, bool>, // per-col span enable
    cache: RefCell<HashMap<(i32, i32), (i32, i32, i32, i32)>>,
}

impl Clone for SpanState {
    fn clone(&self) -> Self {
        Self {
            mode: self.mode,
            mode_fixed: self.mode_fixed,
            span_compare: self.span_compare,
            group_span_compare: self.group_span_compare,
            span_rows: self.span_rows.clone(),
            span_cols: self.span_cols.clone(),
            cache: RefCell::new(HashMap::new()),
        }
    }
}

impl std::fmt::Debug for SpanState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("SpanState")
            .field("mode", &self.mode)
            .field("mode_fixed", &self.mode_fixed)
            .field("span_compare", &self.span_compare)
            .field("group_span_compare", &self.group_span_compare)
            .field("span_rows", &self.span_rows)
            .field("span_cols", &self.span_cols)
            .finish()
    }
}

impl Default for SpanState {
    fn default() -> Self {
        Self {
            mode: pb::CellSpanMode::CellSpanNone as i32,
            mode_fixed: pb::CellSpanMode::CellSpanNone as i32,
            span_compare: pb::SpanCompareMode::SpanCompareExact as i32,
            group_span_compare: pb::SpanCompareMode::SpanCompareExact as i32,
            span_rows: std::collections::HashMap::new(),
            span_cols: std::collections::HashMap::new(),
            cache: RefCell::new(HashMap::new()),
        }
    }
}

impl SpanState {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn heap_size_bytes(&self) -> usize {
        let mut bytes = 0usize;
        bytes += self.span_rows.capacity()
            * (std::mem::size_of::<i32>() + std::mem::size_of::<bool>() + 8);
        bytes += self.span_cols.capacity()
            * (std::mem::size_of::<i32>() + std::mem::size_of::<bool>() + 8);

        let cache = self.cache.borrow();
        bytes += cache.capacity()
            * (std::mem::size_of::<(i32, i32)>() + std::mem::size_of::<(i32, i32, i32, i32)>() + 8);

        bytes
    }

    /// Clear the per-frame span cache. Call once at the start of each render.
    pub fn clear_span_cache(&self) {
        self.cache.borrow_mut().clear();
    }

    fn normalize_for_compare<'a>(&self, s: &'a str) -> &'a str {
        if self.span_compare == pb::SpanCompareMode::SpanCompareTrimNoCase as i32 {
            s.trim()
        } else {
            s
        }
    }

    fn is_empty_for_compare(&self, s: &str) -> bool {
        self.normalize_for_compare(s).is_empty()
    }

    fn text_matches(&self, a: &str, b: &str) -> bool {
        if self.span_compare == pb::SpanCompareMode::SpanCompareIncludeNulls as i32
            && self.is_empty_for_compare(a)
            && self.is_empty_for_compare(b)
        {
            return true;
        }

        // Other modes do not span empty cells.
        if self.is_empty_for_compare(a) || self.is_empty_for_compare(b) {
            return false;
        }

        let na = self.normalize_for_compare(a);
        let nb = self.normalize_for_compare(b);
        match self.span_compare {
            m if m == pb::SpanCompareMode::SpanCompareNoCase as i32
                || m == pb::SpanCompareMode::SpanCompareTrimNoCase as i32 =>
            {
                na.eq_ignore_ascii_case(nb)
            }
            _ => na == nb,
        }
    }

    #[inline]
    fn requires_left_dependency(mode: i32) -> bool {
        mode == pb::CellSpanMode::CellSpanByRow as i32
    }

    #[inline]
    fn requires_above_dependency(_mode: i32) -> bool {
        false
    }

    #[inline]
    fn row_zone(grid: &VolvoxGrid, row: i32) -> i32 {
        if row < grid.fixed_rows {
            0
        } else if row < grid.fixed_rows + grid.frozen_rows {
            1
        } else {
            2
        }
    }

    #[inline]
    fn col_zone(grid: &VolvoxGrid, col: i32) -> i32 {
        if col < grid.fixed_cols {
            0
        } else if col < grid.fixed_cols + grid.frozen_cols {
            1
        } else {
            2
        }
    }

    /// For restricted span modes, vertical pair spans may require the
    /// corresponding left cells to be span-compatible.
    fn vertical_dependency_ok(
        &self,
        grid: &VolvoxGrid,
        row_a: i32,
        row_b: i32,
        col: i32,
        mode: i32,
    ) -> bool {
        if !Self::requires_left_dependency(mode) || col <= 0 {
            return true;
        }
        let left_col = col - 1;
        // When the span column is immediately to the right of the fixed area,
        // RestrictRows does not require dependency on fixed cols.
        if left_col < grid.fixed_cols {
            return true;
        }
        let a_is_fixed = row_a < grid.fixed_rows || left_col < grid.fixed_cols;
        let b_is_fixed = row_b < grid.fixed_rows || left_col < grid.fixed_cols;
        // Restricted modes require the dependency pair itself to be span-enabled.
        if !self.is_span_enabled(row_a, left_col, a_is_fixed)
            || !self.is_span_enabled(row_b, left_col, b_is_fixed)
        {
            return false;
        }
        let a_left = grid.cells.get_text(row_a, left_col);
        let b_left = grid.cells.get_text(row_b, left_col);
        self.text_matches(a_left, b_left)
    }

    /// For restricted span modes, horizontal pair spans may require the
    /// corresponding cells above to be span-compatible.
    fn horizontal_dependency_ok(
        &self,
        grid: &VolvoxGrid,
        row: i32,
        col_a: i32,
        col_b: i32,
        mode: i32,
    ) -> bool {
        if !Self::requires_above_dependency(mode) || row <= 0 {
            return true;
        }
        let above_row = row - 1;
        let a_is_fixed = above_row < grid.fixed_rows || col_a < grid.fixed_cols;
        let b_is_fixed = above_row < grid.fixed_rows || col_b < grid.fixed_cols;
        // Restricted modes require the dependency pair itself to be span-enabled.
        if !self.is_span_enabled(above_row, col_a, a_is_fixed)
            || !self.is_span_enabled(above_row, col_b, b_is_fixed)
        {
            return false;
        }
        let above_a = grid.cells.get_text(above_row, col_a);
        let above_b = grid.cells.get_text(above_row, col_b);
        self.text_matches(above_a, above_b)
    }

    /// Check if spanning is enabled for a cell
    pub fn is_span_enabled(&self, row: i32, col: i32, is_fixed: bool) -> bool {
        let mode = if is_fixed { self.mode_fixed } else { self.mode };
        if mode == pb::CellSpanMode::CellSpanNone as i32 {
            return false;
        }
        if mode == pb::CellSpanMode::CellSpanHeaderOnly as i32 {
            return is_fixed;
        }

        // Check per-row/col flags
        let row_ok = self.span_rows.get(&row).copied().unwrap_or(false)
            || self.span_rows.get(&-1).copied().unwrap_or(false); // -1 = all
        let col_ok = self.span_cols.get(&col).copied().unwrap_or(false)
            || self.span_cols.get(&-1).copied().unwrap_or(false);

        match mode {
            m if m == pb::CellSpanMode::CellSpanFree as i32 => true,
            // RestrictRows = vertical spanning: SpanCol flags control which columns participate
            m if m == pb::CellSpanMode::CellSpanByRow as i32 => col_ok,
            // RestrictCols = horizontal spanning: SpanRow flags control which rows participate
            m if m == pb::CellSpanMode::CellSpanByColumn as i32 => row_ok,
            m if m == pb::CellSpanMode::CellSpanAdjacent as i32 => row_ok || col_ok,
            m if m == pb::CellSpanMode::CellSpanSpill as i32 => true,
            m if m == pb::CellSpanMode::CellSpanGroup as i32 => true,
            _ => false,
        }
    }

    /// Get the merged range for a cell. Returns (r1, c1, r2, c2).
    /// If not merged, returns the cell itself.
    /// Results are cached per-frame; call `clear_span_cache` before each render.
    pub fn get_merged_range(&self, grid: &VolvoxGrid, row: i32, col: i32) -> (i32, i32, i32, i32) {
        if row < 0 || row >= grid.rows || col < 0 || col >= grid.cols {
            return (row, col, row, col);
        }

        let key = (row, col);
        if let Some(&cached) = self.cache.borrow().get(&key) {
            return cached;
        }

        let result = self.compute_span_range(grid, row, col);
        self.cache.borrow_mut().insert(key, result);
        result
    }

    fn compute_span_range(&self, grid: &VolvoxGrid, row: i32, col: i32) -> (i32, i32, i32, i32) {
        let is_fixed = row < grid.fixed_rows || col < grid.fixed_cols;
        if !self.is_span_enabled(row, col, is_fixed) {
            return (row, col, row, col);
        }

        let mode = if is_fixed { self.mode_fixed } else { self.mode };
        let text = grid.cells.get_text(row, col);

        // SPAN_SPILL / SPAN_GROUP: text spills right into adjacent empty cells.
        if mode == pb::CellSpanMode::CellSpanSpill as i32
            || mode == pb::CellSpanMode::CellSpanGroup as i32
        {
            if mode == pb::CellSpanMode::CellSpanGroup as i32 {
                let is_subtotal = grid.get_row_props(row).map_or(false, |rp| rp.is_subtotal);
                if !is_subtotal {
                    return (row, col, row, col);
                }
            }

            if self.is_empty_for_compare(text) {
                return (row, col, row, col);
            }

            let mut c2 = col;
            while c2 < grid.cols - 1 {
                let next_col = c2 + 1;
                let next_is_fixed = row < grid.fixed_rows || next_col < grid.fixed_cols;
                if !self.is_span_enabled(row, next_col, next_is_fixed) {
                    break;
                }
                let next_text = grid.cells.get_text(row, next_col);
                if self.is_empty_for_compare(next_text) {
                    c2 += 1;
                } else {
                    break;
                }
            }

            return (row, col, row, c2);
        }

        // Non-spill span modes do not span blank cells unless IncludeNulls is set.
        if self.is_empty_for_compare(text)
            && self.span_compare != pb::SpanCompareMode::SpanCompareIncludeNulls as i32
        {
            return (row, col, row, col);
        }

        let mut r1 = row;
        let mut r2 = row;
        let mut c1 = col;
        let mut c2 = col;

        // Expand vertically (span rows with same content)
        let can_span_rows = mode != pb::CellSpanMode::CellSpanByColumn as i32;
        if can_span_rows {
            // Expand up
            while r1 > 0 {
                if Self::row_zone(grid, r1 - 1) != Self::row_zone(grid, r1) {
                    break;
                }
                // Never span across pinned/non-pinned boundary.
                if grid.is_row_pinned(r1 - 1) != grid.is_row_pinned(r1) {
                    break;
                }
                // Never span subtotal rows with anything.
                if grid.get_row_props(r1).map_or(false, |rp| rp.is_subtotal)
                    || grid
                        .get_row_props(r1 - 1)
                        .map_or(false, |rp| rp.is_subtotal)
                {
                    break;
                }
                let prev_text = grid.cells.get_text(r1 - 1, col);
                if self.text_matches(prev_text, text)
                    && self.vertical_dependency_ok(grid, r1 - 1, r1, col, mode)
                    && self.is_span_enabled(
                        r1 - 1,
                        col,
                        r1 - 1 < grid.fixed_rows || col < grid.fixed_cols,
                    )
                {
                    r1 -= 1;
                } else {
                    break;
                }
            }
            // Expand down
            while r2 < grid.rows - 1 {
                if Self::row_zone(grid, r2) != Self::row_zone(grid, r2 + 1) {
                    break;
                }
                // Never span across pinned/non-pinned boundary.
                if grid.is_row_pinned(r2) != grid.is_row_pinned(r2 + 1) {
                    break;
                }
                // Never span subtotal rows with anything.
                if grid.get_row_props(r2).map_or(false, |rp| rp.is_subtotal)
                    || grid
                        .get_row_props(r2 + 1)
                        .map_or(false, |rp| rp.is_subtotal)
                {
                    break;
                }
                let next_text = grid.cells.get_text(r2 + 1, col);
                if self.text_matches(next_text, text)
                    && self.vertical_dependency_ok(grid, r2, r2 + 1, col, mode)
                    && self.is_span_enabled(
                        r2 + 1,
                        col,
                        r2 + 1 < grid.fixed_rows || col < grid.fixed_cols,
                    )
                {
                    r2 += 1;
                } else {
                    break;
                }
            }
        }

        // Expand horizontally (span cols with same content)
        let can_span_cols = mode != pb::CellSpanMode::CellSpanByRow as i32;
        if can_span_cols {
            // Expand left
            while c1 > 0 {
                if Self::col_zone(grid, c1 - 1) != Self::col_zone(grid, c1) {
                    break;
                }
                // Never span across pinned/non-pinned column boundary.
                if grid.is_col_pinned(c1 - 1) != grid.is_col_pinned(c1) {
                    break;
                }
                let prev_text = grid.cells.get_text(row, c1 - 1);
                if self.text_matches(prev_text, text)
                    && self.horizontal_dependency_ok(grid, row, c1 - 1, c1, mode)
                    && self.is_span_enabled(
                        row,
                        c1 - 1,
                        row < grid.fixed_rows || c1 - 1 < grid.fixed_cols,
                    )
                {
                    c1 -= 1;
                } else {
                    break;
                }
            }
            // Expand right
            while c2 < grid.cols - 1 {
                if Self::col_zone(grid, c2) != Self::col_zone(grid, c2 + 1) {
                    break;
                }
                // Never span across pinned/non-pinned column boundary.
                if grid.is_col_pinned(c2) != grid.is_col_pinned(c2 + 1) {
                    break;
                }
                let next_text = grid.cells.get_text(row, c2 + 1);
                if self.text_matches(next_text, text)
                    && self.horizontal_dependency_ok(grid, row, c2, c2 + 1, mode)
                    && self.is_span_enabled(
                        row,
                        c2 + 1,
                        row < grid.fixed_rows || c2 + 1 < grid.fixed_cols,
                    )
                {
                    c2 += 1;
                } else {
                    break;
                }
            }
        }

        (r1, c1, r2, c2)
    }

    /// Check if this cell is the top-left origin of its span range
    pub fn is_span_origin(&self, grid: &VolvoxGrid, row: i32, col: i32) -> bool {
        let (r1, c1, _, _) = self.get_merged_range(grid, row, col);
        r1 == row && c1 == col
    }
}

#[cfg(test)]
mod tests {
    use crate::grid::VolvoxGrid;
    use crate::proto::volvoxgrid::v1 as pb;

    #[test]
    fn span_compare_trim_no_case_merges_equivalent_text() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.cells.set_text(1, 0, " Foo ".to_string());
        grid.cells.set_text(2, 0, "foo".to_string());
        grid.span.mode = 1; // free
        grid.span.span_cols.insert(-1, true);
        grid.span.span_rows.insert(-1, true);
        grid.span.span_compare = pb::SpanCompareMode::SpanCompareTrimNoCase as i32;

        let (r1, _c1, r2, _c2) = grid.span.get_merged_range(&grid, 1, 0);
        assert_eq!((r1, r2), (1, 2));
    }

    #[test]
    fn span_spill_expands_right_into_empty_cells() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 2, 4, 1, 0);
        grid.cells.set_text(1, 0, "Northwind".to_string());
        grid.span.mode = 6; // spill

        let (_r1, c1, _r2, c2) = grid.span.get_merged_range(&grid, 1, 0);
        assert_eq!((c1, c2), (0, 3));
    }

    #[test]
    fn span_fixed_only_spans_header_cells() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 4, 2, 0);
        grid.span.mode_fixed = 5; // fixed only
        grid.cells.set_text(0, 0, "Sales".to_string());
        grid.cells.set_text(0, 1, "Sales".to_string());
        grid.cells.set_text(0, 2, "Region".to_string());

        let (_r1, c1, _r2, c2) = grid.span.get_merged_range(&grid, 0, 0);
        assert_eq!((c1, c2), (0, 1));
    }

    #[test]
    fn span_restrict_rows_requires_left_dependency_for_non_fixed_columns() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 5, 2, 1, 0);
        grid.span.mode = pb::CellSpanMode::CellSpanByRow as i32;
        grid.span.span_cols.insert(1, true);

        grid.cells.set_text(1, 0, "Widget A".to_string());
        grid.cells.set_text(2, 0, "Widget B".to_string());
        grid.cells.set_text(3, 0, "Widget C".to_string());
        grid.cells.set_text(4, 0, "Widget D".to_string());
        for r in 1..=4 {
            grid.cells.set_text(r, 1, "Electronics".to_string());
        }

        let (r1, _c1, r2, _c2) = grid.span.get_merged_range(&grid, 1, 1);
        assert_eq!((r1, r2), (1, 1));
    }

    #[test]
    fn span_restrict_rows_skips_left_dependency_at_fixed_boundary() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 5, 3, 1, 1);
        grid.fixed_cols = 1;
        grid.span.mode = pb::CellSpanMode::CellSpanByRow as i32;
        grid.span.span_cols.insert(1, true);

        // Left column is fixed and differs row-to-row.
        for r in 1..=4 {
            grid.cells.set_text(r, 0, r.to_string());
            grid.cells.set_text(r, 1, "Electronics".to_string());
        }

        let (r1, _c1, r2, _c2) = grid.span.get_merged_range(&grid, 1, 1);
        assert_eq!((r1, r2), (1, 4));
    }

    #[test]
    fn span_restrict_cols_spans_on_flagged_row_without_above_dependency() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 3, 1, 0);
        grid.span.mode = pb::CellSpanMode::CellSpanByColumn as i32;
        grid.span.span_rows.insert(-1, true);

        // Target row has equal adjacent cells.
        grid.cells.set_text(2, 1, "Q1".to_string());
        grid.cells.set_text(2, 2, "Q1".to_string());
        // Above row differs, but in restrict-cols mode this does not
        // block span on the flagged row.
        grid.cells.set_text(1, 1, "North".to_string());
        grid.cells.set_text(1, 2, "South".to_string());

        let (_r1, c1, _r2, c2) = grid.span.get_merged_range(&grid, 2, 1);
        assert_eq!((c1, c2), (1, 2));
    }

    #[test]
    fn span_does_not_cross_frozen_row_boundary() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 6, 2, 1, 0);
        grid.fixed_rows = 1;
        grid.frozen_rows = 1;
        grid.span.mode = pb::CellSpanMode::CellSpanByRow as i32;
        grid.span.span_cols.insert(0, true);
        grid.span.span_cols.insert(1, true);

        grid.cells.set_text(1, 1, "Engineering".to_string()); // frozen row
        grid.cells.set_text(2, 1, "Engineering".to_string()); // scrollable row
        grid.cells.set_text(3, 1, "Engineering".to_string()); // scrollable row
                                                              // Restrict-rows span mode requires left-column dependency.
        grid.cells.set_text(1, 0, "Dept".to_string());
        grid.cells.set_text(2, 0, "Dept".to_string());
        grid.cells.set_text(3, 0, "Dept".to_string());

        let (r1_frozen, _c1, r2_frozen, _c2) = grid.span.get_merged_range(&grid, 1, 1);
        let (r1_scroll, _c1b, r2_scroll, _c2b) = grid.span.get_merged_range(&grid, 2, 1);

        assert_eq!((r1_frozen, r2_frozen), (1, 1));
        assert_eq!((r1_scroll, r2_scroll), (2, 3));
    }

    #[test]
    fn span_does_not_cross_frozen_col_boundary() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 6, 1, 0);
        grid.fixed_cols = 1;
        grid.frozen_cols = 1;
        grid.span.mode = pb::CellSpanMode::CellSpanByColumn as i32;
        grid.span.span_rows.insert(1, true);

        grid.cells.set_text(1, 1, "Q1".to_string()); // frozen col
        grid.cells.set_text(1, 2, "Q1".to_string()); // scrollable col
        grid.cells.set_text(1, 3, "Q1".to_string()); // scrollable col

        let (_r1_frozen, c1_frozen, _r2_frozen, c2_frozen) =
            grid.span.get_merged_range(&grid, 1, 1);
        let (_r1_scroll, c1_scroll, _r2_scroll, c2_scroll) =
            grid.span.get_merged_range(&grid, 1, 2);

        assert_eq!((c1_frozen, c2_frozen), (1, 1));
        assert_eq!((c1_scroll, c2_scroll), (2, 3));
    }
}
