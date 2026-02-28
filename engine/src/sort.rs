use std::collections::{HashMap, HashSet};
#[cfg(not(target_arch = "wasm32"))]
use std::time::Instant;
#[cfg(target_arch = "wasm32")]
use web_time::Instant;

#[cfg(feature = "rayon")]
use rayon::prelude::*;

macro_rules! sort_indices {
    ($indices:expr, $cmp:expr) => {
        #[cfg(feature = "rayon")]
        $indices.par_sort_unstable_by($cmp);
        #[cfg(not(feature = "rayon"))]
        $indices.sort_unstable_by($cmp);
    };
}

use crate::grid::VolvoxGrid;
use crate::proto::volvoxgrid::v1 as pb;

#[derive(Clone, Debug)]
pub struct SortState {
    /// Active sort keys: `(col, order)` pairs in priority order.
    /// Single-column sort is `sort_keys.len() == 1`.
    pub sort_keys: Vec<(i32, i32)>,
    /// Last measured end-to-end sort duration in milliseconds.
    pub last_sort_elapsed_ms: f64,
    pub sort_ascending_picture: Option<Vec<u8>>,
    pub sort_descending_picture: Option<Vec<u8>>,
}

impl SortState {
    /// Primary sort column, or -1 if no sort is active.
    pub fn last_sort_col(&self) -> i32 {
        self.sort_keys.first().map_or(-1, |k| k.0)
    }

    /// Primary sort order, or SortNone if no sort is active.
    pub fn last_sort_order(&self) -> i32 {
        self.sort_keys
            .first()
            .map_or(pb::SortOrder::SortNone as i32, |k| k.1)
    }

    /// Remove all sort keys.
    pub fn clear(&mut self) {
        self.sort_keys.clear();
        self.last_sort_elapsed_ms = 0.0;
    }

    pub fn heap_size_bytes(&self) -> usize {
        self.sort_keys.capacity() * std::mem::size_of::<(i32, i32)>()
            + self
                .sort_ascending_picture
                .as_ref()
                .map_or(0, Vec::capacity)
            + self
                .sort_descending_picture
                .as_ref()
                .map_or(0, Vec::capacity)
    }
}

impl Default for SortState {
    fn default() -> Self {
        Self {
            sort_keys: Vec::new(),
            last_sort_elapsed_ms: 0.0,
            sort_ascending_picture: None,
            sort_descending_picture: None,
        }
    }
}

/// Perform sort on the grid using the current selection to determine the row range.
/// sort_order: SortOrder enum value
/// col: column to sort by (-1 = use current selection)
pub fn sort_grid(grid: &mut VolvoxGrid, sort_order: i32, col: i32) {
    if grid.rows <= grid.fixed_rows + 1 || grid.cols <= 0 {
        return;
    }

    let (row_lo, row_hi) = sort_row_range(grid);
    if row_lo < 0 || row_hi <= row_lo {
        return;
    }

    let key_cols = sort_key_columns(grid, col);
    if key_cols.is_empty() {
        return;
    }

    sort_range_impl(grid, sort_order, &key_cols, row_lo, row_hi, None);
}

/// Sort all data rows regardless of the current selection.
/// Used by header clicks which should always sort the entire grid.
pub fn sort_grid_all(grid: &mut VolvoxGrid, sort_order: i32, col: i32) {
    if grid.rows <= grid.fixed_rows + 1 || grid.cols <= 0 {
        return;
    }

    let row_lo = grid.fixed_rows;
    let row_hi = grid.rows - 1;

    let key_cols = sort_key_columns(grid, col);
    if key_cols.is_empty() {
        return;
    }

    sort_range_impl(grid, sort_order, &key_cols, row_lo, row_hi, None);
}

/// Sort all data rows using the multi-column sort keys stored in `grid.sort_state.sort_keys`.
/// Called by the plugin/adapter when the caller has set sort_keys directly via API.
pub fn sort_grid_all_multi(grid: &mut VolvoxGrid) {
    if grid.rows <= grid.fixed_rows + 1 || grid.cols <= 0 {
        return;
    }
    let sort_keys = grid.sort_state.sort_keys.clone();
    if sort_keys.is_empty() {
        return;
    }

    let row_lo = grid.fixed_rows;
    let row_hi = grid.rows - 1;

    let key_cols: Vec<i32> = sort_keys.iter().map(|&(col, _)| col).collect();
    // Use the first key's order as the nominal sort_order (for single-key fast path compat).
    let sort_order = sort_keys[0].1;
    sort_range_impl(grid, sort_order, &key_cols, row_lo, row_hi, Some(&sort_keys));
}

/// Core sort implementation operating on an explicit row range.
///
/// When subtotal rows exist within the range, data rows are sorted
/// independently within each group bounded by subtotal rows.
/// This preserves the outline/subtotal structure.
///
/// When `sort_value_generator` is set on the grid, unmaterialized rows
/// are compared using the generator function (virtual sort for lazy grids).
fn sort_range_impl(
    grid: &mut VolvoxGrid,
    sort_order: i32,
    key_cols: &[i32],
    row_lo: i32,
    row_hi: i32,
    per_col_orders: Option<&[(i32, i32)]>,
) {
    let started_at = Instant::now();
    let has_generator = grid.sort_value_generator.is_some();

    // When a value generator is available (lazy-materialized grid), pre-generate
    // the sort key column(s) for ALL rows so the comparator can work.
    if let Some(gen) = grid.sort_value_generator {
        for r in row_lo..=row_hi {
            let source = grid.row_positions.get(r as usize).copied().unwrap_or(r);
            for &col in key_cols {
                if grid.cells.get_text(r, col).is_empty() {
                    grid.cells.set_text(r, col, gen(source, col));
                }
            }
        }
    }

    // Collect rows that have cell data in the sort range.
    // When a generator is set, ALL rows participate.  Otherwise only
    // populated rows participate — empty rows must NOT sort to one end
    // and push real data out of view.
    //
    // Fast path: check first key column per row (O(rows) lookups)
    // instead of iterating every cell in the store (O(cells)).
    let include_all = has_generator;
    let first_key = key_cols[0];

    // Build groups of data rows bounded by subtotal rows.
    // Each group is sorted independently so that subtotal boundaries
    // and outline structure are preserved.

    let mut groups: Vec<Vec<i32>> = Vec::new();
    let mut current_group: Vec<i32> = Vec::new();

    for r in row_lo..=row_hi {
        // Pinned rows are excluded from sort (always stay in place)
        if grid.is_row_pinned(r) != 0 {
            continue;
        }
        let is_sub = grid.get_row_props(r).map_or(false, |rp| rp.is_subtotal);
        if is_sub {
            if !current_group.is_empty() {
                groups.push(std::mem::take(&mut current_group));
            }
            // subtotal row itself is skipped (stays anchored)
        } else if include_all || !grid.cells.get_text(r, first_key).is_empty() {
            current_group.push(r);
        }
    }
    if !current_group.is_empty() {
        groups.push(current_group);
    }

    // Pre-extract per-column sort metadata so the comparator doesn't
    // need a reference to the grid (required for rayon parallel sort).
    let col_infos: Vec<(i32, i32)> = if let Some(pco) = per_col_orders {
        pco.iter()
            .map(|&(col, order)| {
                let data_type = grid.get_col_props(col).map_or(0, |cp| cp.data_type);
                (order, data_type)
            })
            .collect()
    } else {
        key_cols
            .iter()
            .map(|&col| {
                let order = effective_order_for_col(grid, sort_order, col);
                let data_type = grid.get_col_props(col).map_or(0, |cp| cp.data_type);
                (order, data_type)
            })
            .collect()
    };

    // Sort each group independently and build the combined remap.
    // Also update row_positions to track the source row for each
    // display position (needed for lazy re-materialisation).
    let old_positions = grid.row_positions.clone();
    let mut row_remap = if has_row_metadata_in_range(grid, row_lo, row_hi) {
        Some(HashMap::new())
    } else {
        None
    };
    for group in &groups {
        if group.len() < 2 {
            continue;
        }

        // Sort an index array in parallel, then map back to row indices.
        let mut indices: Vec<usize> = (0..group.len()).collect();
        if key_cols.len() == 1 {
            sort_single_key_indices(
                grid,
                group,
                &mut indices,
                key_cols[0],
                col_infos[0].0,
                col_infos[0].1,
            );
        } else {
            // Pre-extract sort keys for all rows in this group so the
            // parallel comparator only touches plain &str slices.
            let sort_keys: Vec<Vec<&str>> = group
                .iter()
                .map(|&row| {
                    key_cols
                        .iter()
                        .map(|&col| grid.cells.get_text(row, col))
                        .collect()
                })
                .collect();

            sort_indices!(indices, |&ia, &ib| {
                compare_extracted(&sort_keys[ia], &sort_keys[ib], &col_infos)
            });
        }

        for (dest_idx, &src_idx) in indices.iter().enumerate() {
            let dest_row = group[dest_idx];
            let src_row = group[src_idx];
            if let Some(remap) = row_remap.as_mut() {
                if src_row != dest_row {
                    remap.insert(src_row, dest_row);
                }
            }
            grid.row_positions[dest_row as usize] = old_positions[src_row as usize];
        }
    }

    if let Some(remap) = row_remap.as_ref() {
        apply_row_remap(grid, remap);
    }

    // Install the row indirection so CellStore translates display rows
    // to logical (storage) rows on every access.  This avoids physically
    // moving 12M+ cells — only the Vec is cloned (O(rows)).
    grid.cells.set_row_map(grid.row_positions.clone());

    if let Some(pco) = per_col_orders {
        grid.sort_state.sort_keys = pco.to_vec();
    } else {
        grid.sort_state.sort_keys = vec![(key_cols[0], sort_order)];
    }
    grid.sort_state.last_sort_elapsed_ms = started_at.elapsed().as_secs_f64() * 1000.0;
    grid.layout.invalidate();
    grid.mark_dirty();
}

fn sort_row_range(grid: &VolvoxGrid) -> (i32, i32) {
    // If Row == RowEnd, sort all non-fixed rows.
    if grid.selection.row == grid.selection.row_end {
        (grid.fixed_rows, grid.rows - 1)
    } else {
        let lo = grid
            .selection
            .row
            .min(grid.selection.row_end)
            .max(grid.fixed_rows);
        let hi = grid
            .selection
            .row
            .max(grid.selection.row_end)
            .min(grid.rows - 1);
        (lo, hi)
    }
}

fn sort_key_columns(grid: &VolvoxGrid, col_override: i32) -> Vec<i32> {
    if col_override >= 0 && col_override < grid.cols {
        return vec![col_override];
    }
    let lo = grid.selection.col.min(grid.selection.col_end).max(0);
    let hi = grid
        .selection
        .col
        .max(grid.selection.col_end)
        .min(grid.cols - 1);
    if lo > hi {
        return Vec::new();
    }
    (lo..=hi).collect()
}

fn effective_order_for_col(grid: &VolvoxGrid, global_order: i32, col: i32) -> i32 {
    if global_order == pb::SortOrder::SortUseColSort as i32 {
        if col >= 0 && (col as usize) < grid.columns.len() {
            grid.columns[col as usize].sort_order
        } else {
            pb::SortOrder::SortNone as i32
        }
    } else {
        global_order
    }
}

#[inline]
fn apply_sort_direction(cmp: std::cmp::Ordering, order: i32) -> std::cmp::Ordering {
    if order % 2 == 0 {
        cmp.reverse()
    } else {
        cmp
    }
}

#[inline]
fn compare_f64(a: f64, b: f64) -> std::cmp::Ordering {
    a.partial_cmp(&b).unwrap_or(std::cmp::Ordering::Equal)
}

fn sort_single_key_indices(
    grid: &VolvoxGrid,
    group: &[i32],
    indices: &mut Vec<usize>,
    col: i32,
    order: i32,
    data_type: i32,
) {
    match order {
        // Numeric
        o if o == pb::SortOrder::SortNumericAscending as i32
            || o == pb::SortOrder::SortNumericDescending as i32 =>
        {
            let keys: Vec<f64> = group
                .iter()
                .map(|&row| parse_number(grid.cells.get_text(row, col)).unwrap_or(0.0))
                .collect();

            sort_indices!(indices, |&ia, &ib| {
                apply_sort_direction(compare_f64(keys[ia], keys[ib]), order)
            });
        }
        // String no-case
        o if o == pb::SortOrder::SortStringNoCaseAsc as i32
            || o == pb::SortOrder::SortStringNoCaseDesc as i32 =>
        {
            let keys: Vec<Box<str>> = group
                .iter()
                .map(|&row| {
                    grid.cells
                        .get_text(row, col)
                        .to_lowercase()
                        .into_boxed_str()
                })
                .collect();

            sort_indices!(indices, |&ia, &ib| {
                apply_sort_direction(keys[ia].cmp(&keys[ib]), order)
            });
        }
        // String (case-sensitive)
        o if o == pb::SortOrder::SortStringAsc as i32
            || o == pb::SortOrder::SortStringDesc as i32 =>
        {
            let keys: Vec<&str> = group
                .iter()
                .map(|&row| grid.cells.get_text(row, col))
                .collect();

            sort_indices!(indices, |&ia, &ib| {
                apply_sort_direction(keys[ia].cmp(keys[ib]), order)
            });
        }
        // Generic / date-generic
        o if o == pb::SortOrder::SortGenericAscending as i32
            || o == pb::SortOrder::SortGenericDescending as i32
            || o == pb::SortOrder::SortCustom as i32 =>
        {
            let texts: Vec<&str> = group
                .iter()
                .map(|&row| grid.cells.get_text(row, col))
                .collect();

            if data_type == pb::ColumnDataType::ColumnDataDate as i32 {
                // Date path: if both values parse as dates compare by parsed key,
                // otherwise fall back to case-insensitive string compare.
                let parsed: Vec<Option<i64>> = texts.iter().map(|s| parse_date_key(s)).collect();
                let all_dates = parsed.iter().all(|v| v.is_some());

                if all_dates {
                    let keys: Vec<i64> = parsed.into_iter().map(|v| v.unwrap_or(0)).collect();
                    sort_indices!(indices, |&ia, &ib| {
                        apply_sort_direction(keys[ia].cmp(&keys[ib]), order)
                    });
                } else {
                    let lower: Vec<Box<str>> = texts
                        .iter()
                        .map(|s| s.to_lowercase().into_boxed_str())
                        .collect();
                    sort_indices!(indices, |&ia, &ib| {
                        let cmp = match (parsed[ia], parsed[ib]) {
                            (Some(a), Some(b)) => a.cmp(&b),
                            _ => lower[ia].cmp(&lower[ib]),
                        };
                        apply_sort_direction(cmp, order)
                    });
                }
            } else {
                // Generic path: if both values parse as numbers compare numerically,
                // otherwise compare case-insensitive text.
                let parsed: Vec<Option<f64>> = texts.iter().map(|s| parse_number(s)).collect();
                let all_numeric = parsed.iter().all(|v| v.is_some());

                if all_numeric {
                    let keys: Vec<f64> = parsed.into_iter().map(|v| v.unwrap_or(0.0)).collect();
                    sort_indices!(indices, |&ia, &ib| {
                        apply_sort_direction(compare_f64(keys[ia], keys[ib]), order)
                    });
                } else {
                    let lower: Vec<Box<str>> = texts
                        .iter()
                        .map(|s| s.to_lowercase().into_boxed_str())
                        .collect();
                    sort_indices!(indices, |&ia, &ib| {
                        let cmp = match (parsed[ia], parsed[ib]) {
                            (Some(a), Some(b)) => compare_f64(a, b),
                            _ => lower[ia].cmp(&lower[ib]),
                        };
                        apply_sort_direction(cmp, order)
                    });
                }
            }
        }
        _ => {}
    }
}

/// Compare two rows using pre-extracted sort keys and column info.
/// `keys_a` and `keys_b` are slices of cell texts for each key column.
/// `col_infos` is `(order, data_type)` per key column.
fn compare_extracted(
    keys_a: &[&str],
    keys_b: &[&str],
    col_infos: &[(i32, i32)],
) -> std::cmp::Ordering {
    for (i, &(order, data_type)) in col_infos.iter().enumerate() {
        if order == pb::SortOrder::SortNone as i32 {
            continue;
        }
        let text_a = keys_a[i];
        let text_b = keys_b[i];
        let cmp = match order {
            o if o == pb::SortOrder::SortGenericAscending as i32
                || o == pb::SortOrder::SortGenericDescending as i32 =>
            {
                if data_type == pb::ColumnDataType::ColumnDataDate as i32 {
                    date_compare(text_a, text_b)
                } else {
                    generic_compare(text_a, text_b)
                }
            }
            o if o == pb::SortOrder::SortNumericAscending as i32
                || o == pb::SortOrder::SortNumericDescending as i32 =>
            {
                numeric_compare(text_a, text_b)
            }
            o if o == pb::SortOrder::SortStringNoCaseAsc as i32
                || o == pb::SortOrder::SortStringNoCaseDesc as i32 =>
            {
                string_nocase_compare(text_a, text_b)
            }
            o if o == pb::SortOrder::SortStringAsc as i32
                || o == pb::SortOrder::SortStringDesc as i32 =>
            {
                string_compare(text_a, text_b)
            }
            o if o == pb::SortOrder::SortCustom as i32 => generic_compare(text_a, text_b),
            _ => std::cmp::Ordering::Equal,
        };
        let cmp = if order % 2 == 0 { cmp.reverse() } else { cmp };
        if cmp != std::cmp::Ordering::Equal {
            return cmp;
        }
    }
    std::cmp::Ordering::Equal
}

fn generic_compare(a: &str, b: &str) -> std::cmp::Ordering {
    // Try numeric first, fall back to string
    match (parse_number(a), parse_number(b)) {
        (Some(na), Some(nb)) => na.partial_cmp(&nb).unwrap_or(std::cmp::Ordering::Equal),
        _ => a.to_lowercase().cmp(&b.to_lowercase()),
    }
}

fn parse_number(s: &str) -> Option<f64> {
    let t = s.trim();
    if t.is_empty() {
        return None;
    }
    let mut negative = false;
    let mut inner = t;
    if t.starts_with('(') && t.ends_with(')') && t.len() > 2 {
        negative = true;
        inner = &t[1..t.len() - 1];
    }

    let needs_clean = inner.chars().any(|ch| matches!(ch, ',' | '$' | ' ' | '%'));
    let parsed = if needs_clean {
        let mut cleaned = String::with_capacity(inner.len());
        for ch in inner.chars() {
            if !matches!(ch, ',' | '$' | ' ' | '%') {
                cleaned.push(ch);
            }
        }
        cleaned.parse::<f64>().ok()?
    } else {
        inner.parse::<f64>().ok()?
    };

    Some(if negative { -parsed } else { parsed })
}

fn numeric_compare(a: &str, b: &str) -> std::cmp::Ordering {
    let na = parse_number(a).unwrap_or(0.0);
    let nb = parse_number(b).unwrap_or(0.0);
    na.partial_cmp(&nb).unwrap_or(std::cmp::Ordering::Equal)
}

fn parse_date_key(s: &str) -> Option<i64> {
    // Accept a subset of common date forms:
    // YYYY-MM-DD, YYYY/MM/DD, YYYY.MM.DD, MM/DD/YYYY, MM-DD-YYYY
    let s = s.trim();
    if s.is_empty() {
        return None;
    }

    if let Some(num) = parse_number(s) {
        // OLE-style numeric dates still compare correctly as numbers.
        return Some((num * 1_000_000.0) as i64);
    }

    let parts: Vec<&str> = s
        .split(|ch: char| !ch.is_ascii_digit())
        .filter(|p| !p.is_empty())
        .collect();
    if parts.len() < 3 {
        return None;
    }

    let p0 = parts[0].parse::<i32>().ok()?;
    let p1 = parts[1].parse::<i32>().ok()?;
    let p2 = parts[2].parse::<i32>().ok()?;

    let (y, m, d) = if parts[0].len() == 4 {
        (p0, p1, p2) // YYYY-MM-DD
    } else if parts[2].len() == 4 {
        (p2, p0, p1) // MM/DD/YYYY (US default)
    } else {
        return None;
    };

    if !(1..=12).contains(&m) || !(1..=31).contains(&d) {
        return None;
    }
    Some((y as i64) * 10_000 + (m as i64) * 100 + (d as i64))
}

fn date_compare(a: &str, b: &str) -> std::cmp::Ordering {
    match (parse_date_key(a), parse_date_key(b)) {
        (Some(na), Some(nb)) => na.cmp(&nb),
        _ => string_nocase_compare(a, b),
    }
}

fn string_nocase_compare(a: &str, b: &str) -> std::cmp::Ordering {
    a.to_lowercase().cmp(&b.to_lowercase())
}

fn string_compare(a: &str, b: &str) -> std::cmp::Ordering {
    a.cmp(b)
}

fn remap_row_index(row: i32, row_remap: &HashMap<i32, i32>) -> i32 {
    row_remap.get(&row).copied().unwrap_or(row)
}

fn has_row_metadata_in_range(grid: &VolvoxGrid, row_lo: i32, row_hi: i32) -> bool {
    let in_range = |row: i32| row >= row_lo && row <= row_hi;

    grid.row_heights.keys().any(|&row| in_range(row))
        || grid.rows_hidden.iter().any(|&row| in_range(row))
        || grid.row_props.keys().any(|&row| in_range(row))
        || grid
            .span
            .span_rows
            .keys()
            .any(|&row| row != -1 && in_range(row))
        || grid.sticky_rows.keys().any(|&row| in_range(row))
        || grid.pinned_rows_top.iter().any(|&row| in_range(row))
        || grid.pinned_rows_bottom.iter().any(|&row| in_range(row))
}

fn apply_row_remap(grid: &mut VolvoxGrid, row_remap: &HashMap<i32, i32>) {
    if row_remap.is_empty() {
        return;
    }

    // Cell rows are NOT remapped here — CellStore uses a row_map
    // indirection installed by sort_range_impl, so cells stay in place.

    // Remap row heights.
    let old_row_heights = std::mem::take(&mut grid.row_heights);
    let mut new_row_heights = HashMap::new();
    for (r, h) in old_row_heights {
        new_row_heights.insert(remap_row_index(r, row_remap), h);
    }
    grid.row_heights = new_row_heights;

    // Remap hidden rows.
    let old_hidden = std::mem::take(&mut grid.rows_hidden);
    let mut new_hidden = HashSet::new();
    for r in old_hidden {
        new_hidden.insert(remap_row_index(r, row_remap));
    }
    grid.rows_hidden = new_hidden;

    // Remap row properties.
    let old_row_props = std::mem::take(&mut grid.row_props);
    let mut new_row_props = HashMap::new();
    for (r, props) in old_row_props {
        new_row_props.insert(remap_row_index(r, row_remap), props);
    }
    grid.row_props = new_row_props;

    // Remap span row flags (-1 = all, keep as-is).
    let old_span_rows = std::mem::take(&mut grid.span.span_rows);
    let mut new_span_rows = HashMap::new();
    for (r, span) in old_span_rows {
        if r == -1 {
            new_span_rows.insert(r, span);
        } else {
            new_span_rows.insert(remap_row_index(r, row_remap), span);
        }
    }
    grid.span.span_rows = new_span_rows;

    // Remap sticky row state.
    let old_sticky = std::mem::take(&mut grid.sticky_rows);
    let mut new_sticky = HashMap::new();
    for (r, edge) in old_sticky {
        new_sticky.insert(remap_row_index(r, row_remap), edge);
    }
    grid.sticky_rows = new_sticky;

    // Remap pinned row vecs.
    for r in grid.pinned_rows_top.iter_mut() {
        *r = remap_row_index(*r, row_remap);
    }
    grid.pinned_rows_top.sort_unstable();
    for r in grid.pinned_rows_bottom.iter_mut() {
        *r = remap_row_index(*r, row_remap);
    }
    grid.pinned_rows_bottom.sort_unstable();

    // NOTE: row_positions is updated by sort_range_impl (the caller)
    // to track the logical source row for each display position.
    // Do NOT reset to identity here.
}

/// Handle header click on a fixed row column header (single-column sort toggle).
pub fn handle_header_click(grid: &mut VolvoxGrid, col: i32) {
    if grid.header_features == 0 {
        return;
    }

    let can_sort = grid.header_features & 1 != 0; // HEADER_SORT
    let _can_move = grid.header_features & 2 != 0; // HEADER_MOVE

    if can_sort {
        // Toggle sort direction (single-column — clears any multi-sort)
        let current_order = grid
            .sort_state
            .sort_keys
            .iter()
            .find(|&&(c, _)| c == col)
            .map(|&(_, o)| o)
            .unwrap_or(pb::SortOrder::SortNone as i32);

        let new_order = match current_order {
            o if o == pb::SortOrder::SortGenericAscending as i32 => {
                pb::SortOrder::SortGenericDescending as i32
            }
            o if o == pb::SortOrder::SortGenericDescending as i32 => {
                pb::SortOrder::SortNone as i32
            }
            _ => pb::SortOrder::SortGenericAscending as i32,
        };

        // Header click always resets to single-column sort.
        grid.sort_state.sort_keys.clear();
        if new_order == pb::SortOrder::SortNone as i32 {
            grid.sort_state.last_sort_elapsed_ms = 0.0;
            grid.layout.invalidate();
            grid.mark_dirty();
        } else {
            sort_grid_all(grid, new_order, col);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        date_compare, generic_compare, handle_header_click, sort_grid, sort_grid_all,
        sort_grid_all_multi,
    };
    use crate::grid::VolvoxGrid;

    #[test]
    fn sort_uses_selected_key_columns_left_to_right() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 5, 3, 1, 0);
        // Fixed header row at 0; data rows 1..4.
        let data = vec![(1, "A", "2"), (2, "A", "1"), (3, "B", "2"), (4, "B", "1")];
        for (r, c0, c1) in data {
            grid.cells.set_text(r, 0, c0.to_string());
            grid.cells.set_text(r, 1, c1.to_string());
            grid.cells.set_text(r, 2, format!("row{}", r));
        }

        // Sort rows 1..4 by columns 0..1.
        grid.selection.row = 1;
        grid.selection.row_end = 4;
        grid.selection.col = 0;
        grid.selection.col_end = 1;
        sort_grid(&mut grid, 1, -1); // generic ascending

        let got: Vec<String> = (1..=4)
            .map(|r| format!("{}{}", grid.cells.get_text(r, 0), grid.cells.get_text(r, 1)))
            .collect();
        assert_eq!(got, vec!["A1", "A2", "B1", "B2"]);
    }

    #[test]
    fn sort_use_col_sort_honors_per_column_order() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 5, 2, 1, 0);
        grid.cells.set_text(1, 0, "A".to_string());
        grid.cells.set_text(1, 1, "1".to_string());
        grid.cells.set_text(2, 0, "A".to_string());
        grid.cells.set_text(2, 1, "2".to_string());
        grid.cells.set_text(3, 0, "B".to_string());
        grid.cells.set_text(3, 1, "1".to_string());
        grid.cells.set_text(4, 0, "B".to_string());
        grid.cells.set_text(4, 1, "2".to_string());

        grid.columns[0].sort_order = 1; // asc
        grid.columns[1].sort_order = 2; // desc

        grid.selection.row = 1;
        grid.selection.row_end = 4;
        grid.selection.col = 0;
        grid.selection.col_end = 1;
        sort_grid(&mut grid, 10, -1); // use ColSort

        let got: Vec<String> = (1..=4)
            .map(|r| format!("{}{}", grid.cells.get_text(r, 0), grid.cells.get_text(r, 1)))
            .collect();
        assert_eq!(got, vec!["A2", "A1", "B2", "B1"]);
    }

    #[test]
    fn sort_generic_mixed_numeric_and_text_matches_comparator() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 6, 1, 1, 0);
        let values = vec!["2", "A", "10", "b", "-1"];
        for (i, value) in values.iter().enumerate() {
            grid.cells.set_text((i as i32) + 1, 0, (*value).to_string());
        }

        sort_grid_all(&mut grid, 1, 0);

        let got: Vec<String> = (1..=5)
            .map(|r| grid.cells.get_text(r, 0).to_string())
            .collect();

        let mut expected: Vec<String> = values.iter().map(|s| (*s).to_string()).collect();
        expected.sort_by(|a, b| generic_compare(a, b));

        assert_eq!(got, expected);
    }

    #[test]
    fn sort_date_mixed_valid_and_invalid_matches_comparator() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 6, 1, 1, 0);
        grid.columns[0].data_type = 2; // date
        let values = vec![
            "2025-01-02",
            "not-a-date",
            "2024-12-31",
            "2025/02/01",
            "alpha",
        ];
        for (i, value) in values.iter().enumerate() {
            grid.cells.set_text((i as i32) + 1, 0, (*value).to_string());
        }

        sort_grid_all(&mut grid, 1, 0);

        let got: Vec<String> = (1..=5)
            .map(|r| grid.cells.get_text(r, 0).to_string())
            .collect();

        let mut expected: Vec<String> = values.iter().map(|s| (*s).to_string()).collect();
        expected.sort_by(|a, b| date_compare(a, b));

        assert_eq!(got, expected);
    }

    #[test]
    fn sort_group_aware_with_subtotals() {
        // 1 fixed header row, 7 data rows = 8 total
        // Layout: row 1-3 = group A, row 4 = subtotal, row 5-6 = group B, row 7 = subtotal
        let mut grid = VolvoxGrid::new(1, 640, 480, 8, 2, 1, 0);

        // Group A: rows 1, 2, 3
        grid.cells.set_text(1, 0, "C".to_string());
        grid.cells.set_text(1, 1, "g1-C".to_string());
        grid.cells.set_text(2, 0, "A".to_string());
        grid.cells.set_text(2, 1, "g1-A".to_string());
        grid.cells.set_text(3, 0, "B".to_string());
        grid.cells.set_text(3, 1, "g1-B".to_string());

        // Subtotal at row 4
        grid.row_props.entry(4).or_default().is_subtotal = true;
        grid.cells.set_text(4, 0, "Sub1".to_string());

        // Group B: rows 5, 6
        grid.cells.set_text(5, 0, "Z".to_string());
        grid.cells.set_text(5, 1, "g2-Z".to_string());
        grid.cells.set_text(6, 0, "X".to_string());
        grid.cells.set_text(6, 1, "g2-X".to_string());

        // Subtotal at row 7
        grid.row_props.entry(7).or_default().is_subtotal = true;
        grid.cells.set_text(7, 0, "Sub2".to_string());

        // Sort all by column 0 ascending
        sort_grid_all(&mut grid, 1, 0);

        // Group A should be sorted within itself: A, B, C
        assert_eq!(grid.cells.get_text(1, 1), "g1-A");
        assert_eq!(grid.cells.get_text(2, 1), "g1-B");
        assert_eq!(grid.cells.get_text(3, 1), "g1-C");

        // Subtotal row 4 unchanged
        assert_eq!(grid.cells.get_text(4, 0), "Sub1");

        // Group B should be sorted within itself: X, Z
        assert_eq!(grid.cells.get_text(5, 1), "g2-X");
        assert_eq!(grid.cells.get_text(6, 1), "g2-Z");

        // Subtotal row 7 unchanged
        assert_eq!(grid.cells.get_text(7, 0), "Sub2");

        // Crucially, group B data should NOT mix with group A
        // (X < A in ASCII but X should stay in group B)
        assert_eq!(grid.cells.get_text(5, 0), "X");
        assert_eq!(grid.cells.get_text(1, 0), "A");
    }

    #[test]
    #[cfg(feature = "demo")]
    fn sort_hierarchy_demo_header_features_disabled() {
        // Hierarchy demo disables header_features since flat sort is
        // incompatible with tree structure.
        let mut grid = VolvoxGrid::new(1, 800, 600, 2, 5, 1, 0);
        crate::demo::setup_hierarchy_demo(&mut grid);
        grid.ensure_layout();

        assert_eq!(
            grid.header_features, 0,
            "header_features should be disabled for hierarchy"
        );

        // Clicking header should NOT trigger a sort
        crate::input::handle_pointer_down(&mut grid, 10.0, 5.0, 0, 0, false);
        crate::input::handle_pointer_up(&mut grid, 10.0, 5.0, 0, 0);

        let events = grid.events.drain();
        assert!(
            !events.iter().any(|e| matches!(
                e.data,
                crate::event::GridEventData::BeforeSort { .. }
                    | crate::event::GridEventData::AfterSort { .. }
            )),
            "no sort events should fire on hierarchy demo"
        );
    }

    #[test]
    fn multi_sort_api_two_columns() {
        use crate::proto::volvoxgrid::v1 as pb;

        let mut grid = VolvoxGrid::new(1, 640, 480, 5, 3, 1, 0);
        // Data: (col0=department, col1=name)
        // Row 1: Sales, Charlie
        // Row 2: Sales, Alice
        // Row 3: Engineering, Bob
        // Row 4: Engineering, Alice
        grid.cells.set_text(1, 0, "Sales".to_string());
        grid.cells.set_text(1, 1, "Charlie".to_string());
        grid.cells.set_text(2, 0, "Sales".to_string());
        grid.cells.set_text(2, 1, "Alice".to_string());
        grid.cells.set_text(3, 0, "Engineering".to_string());
        grid.cells.set_text(3, 1, "Bob".to_string());
        grid.cells.set_text(4, 0, "Engineering".to_string());
        grid.cells.set_text(4, 1, "Alice".to_string());

        // Sort by col0 asc, then col1 asc
        let asc = pb::SortOrder::SortGenericAscending as i32;
        grid.sort_state.sort_keys = vec![(0, asc), (1, asc)];
        sort_grid_all_multi(&mut grid);

        let got: Vec<String> = (1..=4)
            .map(|r| format!("{}-{}", grid.cells.get_text(r, 0), grid.cells.get_text(r, 1)))
            .collect();
        assert_eq!(
            got,
            vec![
                "Engineering-Alice",
                "Engineering-Bob",
                "Sales-Alice",
                "Sales-Charlie"
            ]
        );
        assert_eq!(grid.sort_state.sort_keys.len(), 2);
    }

    #[test]
    fn multi_sort_state_after_header_click_resets_to_single() {
        use crate::proto::volvoxgrid::v1 as pb;

        let mut grid = VolvoxGrid::new(1, 640, 480, 5, 3, 1, 0);
        grid.header_features = 1; // HEADER_SORT
        for r in 1..=4 {
            grid.cells.set_text(r, 0, format!("a{}", r));
            grid.cells.set_text(r, 1, format!("b{}", r));
        }

        // Set multi-sort via API
        let asc = pb::SortOrder::SortGenericAscending as i32;
        grid.sort_state.sort_keys = vec![(0, asc), (1, asc)];
        sort_grid_all_multi(&mut grid);
        assert_eq!(grid.sort_state.sort_keys.len(), 2);

        // Header click should reset to single-column sort
        handle_header_click(&mut grid, 1);
        assert_eq!(grid.sort_state.sort_keys.len(), 1);
        assert_eq!(grid.sort_state.sort_keys[0].0, 1); // col 1
    }
}
