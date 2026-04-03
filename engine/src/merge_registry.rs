/// Registry of explicit user-initiated merge ranges.
///
/// Unlike content-based spanning (see `SpanState`), these are manually
/// specified ranges where multiple cells are presented as a single merged cell.
/// Explicit merges take priority over content-based spans in `get_merged_range`.
#[derive(Debug, Clone, Default)]
pub struct MergeRegistry {
    /// Each entry is (r1, c1, r2, c2) with r1 <= r2 and c1 <= c2.
    ranges: Vec<(i32, i32, i32, i32)>,
}

impl MergeRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    /// Add an explicit merge range. Removes any existing merges that overlap.
    pub fn add_merge(&mut self, r1: i32, c1: i32, r2: i32, c2: i32) {
        let (r1, r2) = (r1.min(r2), r1.max(r2));
        let (c1, c2) = (c1.min(c2), c1.max(c2));
        // A single cell is not a merge.
        if r1 == r2 && c1 == c2 {
            return;
        }
        self.remove_overlapping(r1, c1, r2, c2);
        self.ranges.push((r1, c1, r2, c2));
    }

    /// Remove all explicit merges that overlap the given range.
    pub fn remove_overlapping(&mut self, r1: i32, c1: i32, r2: i32, c2: i32) {
        let (r1, r2) = (r1.min(r2), r1.max(r2));
        let (c1, c2) = (c1.min(c2), c1.max(c2));
        self.ranges.retain(|&(mr1, mc1, mr2, mc2)| {
            // Retain ranges that do NOT overlap.
            mr2 < r1 || mr1 > r2 || mc2 < c1 || mc1 > c2
        });
    }

    /// Find the explicit merge range containing the given cell.
    pub fn find_merge(&self, row: i32, col: i32) -> Option<(i32, i32, i32, i32)> {
        self.ranges
            .iter()
            .find(|&&(r1, c1, r2, c2)| row >= r1 && row <= r2 && col >= c1 && col <= c2)
            .copied()
    }

    /// Return all explicit merge ranges.
    pub fn all_ranges(&self) -> &[(i32, i32, i32, i32)] {
        &self.ranges
    }

    /// Shift merge row indices after inserting a row at `at`.
    pub fn shift_rows_down(&mut self, at: i32) {
        for (r1, _, r2, _) in &mut self.ranges {
            if at <= *r1 {
                *r1 += 1;
                *r2 += 1;
            } else if at <= *r2 {
                *r2 += 1;
            }
        }
    }

    /// Shift merge row indices after removing row `at`.
    pub fn shift_rows_up(&mut self, at: i32) {
        let old_ranges = std::mem::take(&mut self.ranges);
        for (mut r1, c1, mut r2, c2) in old_ranges {
            if at < r1 {
                r1 -= 1;
                r2 -= 1;
            } else if at <= r2 {
                if r1 == r2 {
                    continue;
                }
                r2 -= 1;
            }
            self.ranges.push((r1, c1, r2, c2));
        }
    }

    /// Approximate heap usage in bytes.
    pub fn heap_size_bytes(&self) -> usize {
        self.ranges.capacity() * std::mem::size_of::<(i32, i32, i32, i32)>()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_and_find_merge() {
        let mut reg = MergeRegistry::new();
        reg.add_merge(1, 1, 3, 3);
        assert_eq!(reg.find_merge(2, 2), Some((1, 1, 3, 3)));
        assert_eq!(reg.find_merge(0, 0), None);
        assert_eq!(reg.find_merge(4, 4), None);
    }

    #[test]
    fn add_merge_normalizes_order() {
        let mut reg = MergeRegistry::new();
        reg.add_merge(3, 3, 1, 1);
        assert_eq!(reg.find_merge(2, 2), Some((1, 1, 3, 3)));
    }

    #[test]
    fn single_cell_merge_is_noop() {
        let mut reg = MergeRegistry::new();
        reg.add_merge(5, 5, 5, 5);
        assert_eq!(reg.find_merge(5, 5), None);
        assert!(reg.all_ranges().is_empty());
    }

    #[test]
    fn shift_rows_down_moves_single_row_merge() {
        let mut reg = MergeRegistry::new();
        reg.add_merge(3, 0, 3, 1);

        reg.shift_rows_down(3);

        assert_eq!(reg.find_merge(4, 0), Some((4, 0, 4, 1)));
        assert_eq!(reg.find_merge(3, 0), None);
    }

    #[test]
    fn shift_rows_down_expands_merge_when_inserting_inside_range() {
        let mut reg = MergeRegistry::new();
        reg.add_merge(3, 0, 5, 1);

        reg.shift_rows_down(4);

        assert_eq!(reg.find_merge(3, 0), Some((3, 0, 6, 1)));
        assert_eq!(reg.find_merge(6, 0), Some((3, 0, 6, 1)));
    }

    #[test]
    fn shift_rows_up_removes_single_row_merge_on_deleted_row() {
        let mut reg = MergeRegistry::new();
        reg.add_merge(3, 0, 3, 1);

        reg.shift_rows_up(3);

        assert!(reg.all_ranges().is_empty());
    }

    #[test]
    fn shift_rows_up_shrinks_merge_when_deleting_inside_range() {
        let mut reg = MergeRegistry::new();
        reg.add_merge(3, 0, 5, 1);

        reg.shift_rows_up(4);

        assert_eq!(reg.find_merge(3, 0), Some((3, 0, 4, 1)));
        assert_eq!(reg.find_merge(5, 0), None);
    }

    #[test]
    fn add_merge_removes_overlapping() {
        let mut reg = MergeRegistry::new();
        reg.add_merge(1, 1, 3, 3);
        reg.add_merge(2, 2, 5, 5);
        // Old merge is removed, only new one exists.
        assert_eq!(reg.all_ranges().len(), 1);
        assert_eq!(reg.find_merge(1, 1), None);
        assert_eq!(reg.find_merge(3, 3), Some((2, 2, 5, 5)));
    }

    #[test]
    fn remove_overlapping_retains_non_overlapping() {
        let mut reg = MergeRegistry::new();
        reg.add_merge(0, 0, 2, 2);
        reg.add_merge(5, 5, 7, 7);
        reg.remove_overlapping(1, 1, 3, 3);
        // First merge overlaps and is removed, second is retained.
        assert_eq!(reg.all_ranges().len(), 1);
        assert_eq!(reg.find_merge(6, 6), Some((5, 5, 7, 7)));
    }
}
