use crate::grid::VolvoxGrid;
use crate::proto::volvoxgrid::v1 as pb;

/// Scaled tree geometry constants for outline rendering, hit-testing, and text indent.
/// All values are derived from `default_row_height` to look proportional on any DPI.
#[derive(Clone, Copy, Debug)]
pub struct TreeGeometry {
    pub btn_size: i32,
    pub indent_step: i32,
    pub line_offset: i32,
    pub connector_end: i32,
    pub sign_margin: i32,
}

impl TreeGeometry {
    /// Compute tree geometry scaled from the grid's default row height.
    /// Reference height is 20px (matches the default `DEFAULT_ROW_HEIGHT`).
    pub fn from_grid(grid: &VolvoxGrid) -> Self {
        let ref_h = grid.default_row_height.max(1) as f32;
        let scale = ref_h / 20.0;
        Self {
            btn_size: (11.0 * scale).round().max(6.0) as i32,
            indent_step: (16.0 * scale).round() as i32,
            line_offset: (6.0 * scale).round().max(1.0) as i32,
            connector_end: (12.0 * scale).round().max(6.0) as i32,
            sign_margin: (2.0 * scale).round().max(1.0) as i32,
        }
    }

    /// Pixel indent for a given outline level.
    #[inline]
    pub fn indent(&self, level: i32) -> i32 {
        (level - 1) * self.indent_step
    }

    /// X position of the vertical tree line relative to cell start.
    #[inline]
    pub fn line_x(&self, level: i32) -> i32 {
        self.indent(level) + self.line_offset
    }
}

#[derive(Clone, Debug)]
pub struct OutlineState {
    pub tree_indicator: i32,       // TreeIndicatorStyle enum
    pub tree_column: i32,          // column for outline tree display
    pub group_total_position: i32, // GroupTotalPosition enum (0=above, 1=below)
    pub multi_totals: bool,
    pub node_open_picture: Option<Vec<u8>>,
    pub node_closed_picture: Option<Vec<u8>>,
}

impl Default for OutlineState {
    fn default() -> Self {
        Self {
            tree_indicator: pb::TreeIndicatorStyle::TreeIndicatorNone as i32,
            tree_column: 0,
            group_total_position: pb::GroupTotalPosition::GroupTotalAbove as i32,
            multi_totals: false,
            node_open_picture: None,
            node_closed_picture: None,
        }
    }
}

impl OutlineState {
    pub fn heap_size_bytes(&self) -> usize {
        self.node_open_picture.as_ref().map_or(0, Vec::capacity)
            + self.node_closed_picture.as_ref().map_or(0, Vec::capacity)
    }
}

/// Insert subtotal rows into the grid.
///
/// `aggregate`: AggregateType enum (0=none, 1=clear, 2+=function)
/// `group_on_col`: column to group by (-1 = grand total only)
/// `aggregate_col`: column to aggregate
/// `caption`: label prefix for subtotal rows
/// `back_color` / `fore_color`: styling for subtotal rows
/// `add_outline`: whether to add outline tree levels
pub fn subtotal(
    grid: &mut VolvoxGrid,
    aggregate: i32,
    group_on_col: i32,
    aggregate_col: i32,
    caption: &str,
    back_color: u32,
    fore_color: u32,
    add_outline: bool,
) {
    subtotal_ex(
        grid,
        aggregate,
        group_on_col,
        aggregate_col,
        caption,
        back_color,
        fore_color,
        add_outline,
        "",    // format
        false, // font_bold
        -1,    // match_from (-1 = from fixed_cols)
        false, // total_only
    );
}

/// Extended subtotal with additional parameters.
///
/// `format`: format string applied to the aggregate value (e.g. "$#,##0.00").
///           Empty string uses default formatting.
/// `font_bold`: if true, subtotal rows are rendered in bold.
/// `match_from`: first column used for break matching (-1 = fixed_cols).
/// `total_only`: if true, insert only a grand total row (hide detail rows).
#[allow(clippy::too_many_arguments)]
pub fn subtotal_ex(
    grid: &mut VolvoxGrid,
    aggregate: i32,
    group_on_col: i32,
    aggregate_col: i32,
    caption: &str,
    back_color: u32,
    fore_color: u32,
    add_outline: bool,
    format: &str,
    font_bold: bool,
    match_from: i32,
    total_only: bool,
) {
    if aggregate == pb::AggregateType::AggNone as i32 {
        return;
    }
    if aggregate == pb::AggregateType::AggClear as i32 {
        clear_subtotals(grid);
        return;
    }

    let first_data_row = grid.fixed_rows;
    if grid.rows <= first_data_row || grid.cols <= 0 {
        return;
    }

    // Collect groups (group_value, start_row, end_row).
    let mut groups: Vec<(String, i32, i32)> = Vec::new(); // (group_value, start_row, end_row)

    if group_on_col >= 0 && group_on_col < grid.cols && !total_only {
        // Compare adjacent rows across [MatchFrom..GroupOn].
        let mut cmp_from = if match_from >= 0 {
            match_from
        } else {
            grid.fixed_cols
        };
        cmp_from = cmp_from.clamp(0, grid.cols - 1);
        let cmp_lo = cmp_from.min(group_on_col);
        let cmp_hi = cmp_from.max(group_on_col);

        let mut current_key: Option<String> = None;
        let mut current_group_name = String::new();
        let mut group_start = -1;
        let mut group_end = -1;

        for row in first_data_row..grid.rows {
            if is_subtotal_row(grid, row) {
                continue;
            }
            let key = build_group_key(grid, row, cmp_lo, cmp_hi);
            let group_name = grid.cells.get_text(row, group_on_col).to_string();
            if current_key.is_none() {
                current_key = Some(key);
                current_group_name = group_name;
                group_start = row;
                group_end = row;
                continue;
            }
            if current_key.as_deref() != Some(key.as_str()) {
                groups.push((current_group_name.clone(), group_start, group_end));
                current_key = Some(key);
                current_group_name = group_name;
                group_start = row;
                group_end = row;
            } else {
                group_end = row;
            }
        }
        if current_key.is_some() {
            groups.push((current_group_name, group_start, group_end));
        }
    } else {
        // Grand total only.
        //
        // Behavior when subtotals already exist:
        // - aggregate over detail rows only (subtotal rows ignored)
        // - insert grand total at the full data boundary
        //   (top when GroupTotalPosition=Above, bottom when Below),
        //   not at the first/last detail row.
        let mut has_detail = false;
        for row in first_data_row..grid.rows {
            if is_subtotal_row(grid, row) {
                continue;
            }
            has_detail = true;
            break;
        }
        if has_detail {
            groups.push((String::new(), first_data_row, grid.rows - 1));
        }
    }

    if groups.is_empty() {
        return;
    }

    // Insert subtotal rows (from bottom to top to preserve indices)
    for (group_name, start, end) in groups.iter().rev() {
        let agg_value = compute_aggregate(grid, aggregate, *start, *end, aggregate_col);
        let insert_row = if grid.outline.group_total_position
            == pb::GroupTotalPosition::GroupTotalAbove as i32
        {
            *start // above
        } else {
            *end + 1 // below
        };

        // Insert row
        grid.cells.insert_row(insert_row);
        shift_row_metadata_down(grid, insert_row);
        grid.rows += 1;

        // Set subtotal text
        let label = subtotal_caption(aggregate, caption, group_on_col, group_name);

        let label_col = if group_on_col >= 0 && group_on_col < grid.cols {
            group_on_col
        } else {
            0
        };
        if label_col >= 0 && label_col < grid.cols {
            grid.cells.set_text(insert_row, label_col, label);
        }

        // Subtotal rows copy key columns left of GroupOn
        // from a neighboring detail row so parent keys remain visible.
        if label_col > 0 {
            let data_start = if grid.outline.group_total_position
                == pb::GroupTotalPosition::GroupTotalAbove as i32
            {
                *start + 1
            } else {
                *start
            };
            let data_end = if grid.outline.group_total_position
                == pb::GroupTotalPosition::GroupTotalAbove as i32
            {
                *end + 1
            } else {
                *end
            };

            let source_row = if grid.outline.group_total_position
                == pb::GroupTotalPosition::GroupTotalAbove as i32
            {
                (data_start..=data_end).find(|&r| !is_subtotal_row(grid, r))
            } else {
                (data_start..=data_end)
                    .rev()
                    .find(|&r| !is_subtotal_row(grid, r))
            };

            if let Some(src_row) = source_row {
                for c in 0..label_col {
                    let key_text = grid.cells.get_text(src_row, c).to_string();
                    if !key_text.is_empty() {
                        grid.cells.set_text(insert_row, c, key_text);
                    }
                }
            }
        }

        // Format the aggregate value
        let formatted_value = if !format.is_empty() {
            let raw = format_aggregate(agg_value);
            crate::grid::apply_col_format_public(&raw, format).unwrap_or_else(|| raw)
        } else {
            format_aggregate(agg_value)
        };
        grid.cells
            .set_text(insert_row, aggregate_col, formatted_value);

        // Mark as subtotal row
        grid.row_props.entry(insert_row).or_default().is_subtotal = true;

        // Set outline level
        if add_outline {
            let data_start = if grid.outline.group_total_position
                == pb::GroupTotalPosition::GroupTotalAbove as i32
            {
                *start + 1
            } else {
                *start
            };
            let data_end = if grid.outline.group_total_position
                == pb::GroupTotalPosition::GroupTotalAbove as i32
            {
                *end + 1
            } else {
                *end
            };

            // Outline depth for subtotal rows tracks the
            // GroupOn column depth (0-based), not insertion order.
            // Grand totals (GroupOn=-1) are subtotal rows but not
            // tree nodes; they use outline level -1 (no +/- button).
            let new_subtotal_level = if group_on_col < 0 {
                -1
            } else {
                group_on_col.max(0)
            };
            grid.row_props.entry(insert_row).or_default().outline_level = new_subtotal_level;

            // Data rows stay at level 0 for subtotal visuals.
            for r in data_start..=data_end {
                if is_subtotal_row(grid, r) {
                    continue;
                }
                grid.row_props.entry(r).or_default().outline_level = 0;
            }
        }

        // Set subtotal style.
        // Row colors apply across the subtotal row, but bold
        // applies to generated subtotal cells (caption and aggregate value),
        // not copied key cells to the left of GroupOn.
        let subtotal_bold = font_bold || aggregate != pb::AggregateType::AggNone as i32;
        if back_color != 0 || fore_color != 0 || subtotal_bold {
            for c in 0..grid.cols {
                let bold_cell = subtotal_bold && c >= label_col;
                // Hierarchical subtotals: row coloring starts
                // at the generated subtotal caption cell and continues to the right.
                // Cells to the left (copied key columns) remain unfilled.
                let apply_back_color = back_color != 0 && c >= label_col;
                let style = crate::style::CellStyleOverride {
                    back_color: if apply_back_color {
                        Some(back_color)
                    } else {
                        None
                    },
                    fore_color: if fore_color != 0 {
                        Some(fore_color)
                    } else {
                        None
                    },
                    font_bold: if bold_cell { Some(true) } else { None },
                    ..Default::default()
                };
                if !style.is_empty() {
                    grid.cell_styles.insert((insert_row, c), style);
                }
            }
        }
    }

    // If total_only, hide detail rows
    if total_only {
        for row in first_data_row..grid.rows {
            let is_sub = grid.row_props.get(&row).map_or(false, |rp| rp.is_subtotal);
            if !is_sub {
                grid.rows_hidden.insert(row);
            }
        }
    }

    // Keep mapping consistent after row insertions.
    grid.row_positions = (0..grid.rows).collect();
    grid.layout.invalidate();
    grid.mark_dirty();
}

/// Remove all subtotal rows
fn clear_subtotals(grid: &mut VolvoxGrid) {
    let mut subtotal_rows: Vec<i32> = grid
        .row_props
        .iter()
        .filter(|(_, p)| p.is_subtotal)
        .map(|(&r, _)| r)
        .collect();
    subtotal_rows.sort_unstable();

    for row in subtotal_rows.into_iter().rev() {
        grid.cells.remove_row(row);
        shift_row_metadata_up(grid, row);
        grid.rows -= 1;
    }

    // Reset row positions
    grid.row_positions = (0..grid.rows).collect();
    grid.layout.invalidate();
    grid.mark_dirty();
}

/// Compute aggregate value over a range
fn compute_aggregate(grid: &VolvoxGrid, agg_type: i32, row1: i32, row2: i32, col: i32) -> f64 {
    if row1 > row2 {
        return 0.0;
    }
    let mut values: Vec<f64> = Vec::new();
    for r in row1..=row2 {
        if is_subtotal_row(grid, r) {
            continue;
        }
        let text = grid.cells.get_text(r, col);
        if let Ok(v) = text.replace([',', '$', ' '], "").parse::<f64>() {
            values.push(v);
        }
    }

    if values.is_empty() {
        return 0.0;
    }

    match agg_type {
        a if a == pb::AggregateType::AggSum as i32 => values.iter().sum(),
        a if a == pb::AggregateType::AggPercent as i32 => {
            let total: f64 = values.iter().sum();
            if total != 0.0 {
                values.iter().sum::<f64>() / total * 100.0
            } else {
                0.0
            }
        }
        a if a == pb::AggregateType::AggCount as i32 => values.len() as f64,
        a if a == pb::AggregateType::AggAverage as i32 => {
            values.iter().sum::<f64>() / values.len() as f64
        }
        a if a == pb::AggregateType::AggMax as i32 => {
            values.iter().cloned().fold(f64::NEG_INFINITY, f64::max)
        }
        a if a == pb::AggregateType::AggMin as i32 => {
            values.iter().cloned().fold(f64::INFINITY, f64::min)
        }
        a if a == pb::AggregateType::AggStdDev as i32 => {
            // sample, N-1
            if values.len() < 2 {
                return 0.0;
            }
            let mean = values.iter().sum::<f64>() / values.len() as f64;
            let variance =
                values.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / (values.len() - 1) as f64;
            variance.sqrt()
        }
        a if a == pb::AggregateType::AggVar as i32 => {
            // sample, N-1
            if values.len() < 2 {
                return 0.0;
            }
            let mean = values.iter().sum::<f64>() / values.len() as f64;
            values.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / (values.len() - 1) as f64
        }
        10 => {
            // AGG_STD_DEV_POP (population, N) — not in proto
            let mean = values.iter().sum::<f64>() / values.len() as f64;
            let variance =
                values.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / values.len() as f64;
            variance.sqrt()
        }
        11 => {
            // AGG_VAR_POP (population, N) — not in proto
            let mean = values.iter().sum::<f64>() / values.len() as f64;
            values.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / values.len() as f64
        }
        _ => 0.0,
    }
}

/// Shift all row-keyed metadata down by 1 for rows >= `at`.
fn shift_row_metadata_down(grid: &mut VolvoxGrid, at: i32) {
    let old_props = std::mem::take(&mut grid.row_props);
    for (r, props) in old_props {
        if r >= at {
            grid.row_props.insert(r + 1, props);
        } else {
            grid.row_props.insert(r, props);
        }
    }

    let old_heights = std::mem::take(&mut grid.row_heights);
    for (r, h) in old_heights {
        if r >= at {
            grid.row_heights.insert(r + 1, h);
        } else {
            grid.row_heights.insert(r, h);
        }
    }

    let old_hidden = std::mem::take(&mut grid.rows_hidden);
    for r in old_hidden {
        if r >= at {
            grid.rows_hidden.insert(r + 1);
        } else {
            grid.rows_hidden.insert(r);
        }
    }

    let old_styles = std::mem::take(&mut grid.cell_styles);
    for ((r, c), style) in old_styles {
        if r >= at {
            grid.cell_styles.insert((r + 1, c), style);
        } else {
            grid.cell_styles.insert((r, c), style);
        }
    }
}

/// Shift all row-keyed metadata up by 1 for rows > `at` (after removing row `at`).
fn shift_row_metadata_up(grid: &mut VolvoxGrid, at: i32) {
    let old_props = std::mem::take(&mut grid.row_props);
    for (r, props) in old_props {
        if r == at {
            continue;
        }
        if r > at {
            grid.row_props.insert(r - 1, props);
        } else {
            grid.row_props.insert(r, props);
        }
    }

    let old_heights = std::mem::take(&mut grid.row_heights);
    for (r, h) in old_heights {
        if r == at {
            continue;
        }
        if r > at {
            grid.row_heights.insert(r - 1, h);
        } else {
            grid.row_heights.insert(r, h);
        }
    }

    let old_hidden = std::mem::take(&mut grid.rows_hidden);
    for r in old_hidden {
        if r == at {
            continue;
        }
        if r > at {
            grid.rows_hidden.insert(r - 1);
        } else {
            grid.rows_hidden.insert(r);
        }
    }

    let old_styles = std::mem::take(&mut grid.cell_styles);
    for ((r, c), style) in old_styles {
        if r == at {
            continue;
        }
        if r > at {
            grid.cell_styles.insert((r - 1, c), style);
        } else {
            grid.cell_styles.insert((r, c), style);
        }
    }
}

fn is_subtotal_row(grid: &VolvoxGrid, row: i32) -> bool {
    grid.row_props.get(&row).map_or(false, |rp| rp.is_subtotal)
}

fn normalize_group_cell_text<'a>(text: &'a str, compare_mode: i32) -> std::borrow::Cow<'a, str> {
    match compare_mode {
        // Case-insensitive
        1 => std::borrow::Cow::Owned(text.to_lowercase()),
        // Trim + case-insensitive
        2 => std::borrow::Cow::Owned(text.trim().to_lowercase()),
        // Default/exact
        _ => std::borrow::Cow::Borrowed(text),
    }
}

fn build_group_key(grid: &VolvoxGrid, row: i32, col_lo: i32, col_hi: i32) -> String {
    let compare_mode = grid.span.span_compare;
    let mut key = String::new();
    for c in col_lo..=col_hi {
        if c > col_lo {
            key.push('\x1f');
        }
        let normalized = normalize_group_cell_text(grid.cells.get_text(row, c), compare_mode);
        key.push_str(normalized.as_ref());
    }
    key
}

fn subtotal_caption(aggregate: i32, caption: &str, group_on_col: i32, group_name: &str) -> String {
    let default_template = match aggregate {
        a if a == pb::AggregateType::AggSum as i32 => "Total %s",
        a if a == pb::AggregateType::AggPercent as i32 => "Percent %s",
        a if a == pb::AggregateType::AggCount as i32 => "Count %s",
        a if a == pb::AggregateType::AggAverage as i32 => "Average %s",
        a if a == pb::AggregateType::AggMax as i32 => "Max %s",
        a if a == pb::AggregateType::AggMin as i32 => "Min %s",
        a if a == pb::AggregateType::AggStdDev as i32 => "StdDev %s",
        a if a == pb::AggregateType::AggVar as i32 => "Variance %s",
        _ => "Total %s",
    };

    let mut effective_caption = caption.to_string();

    // Caption "Total" is aggregate-aware and behaves as
    // a marker template instead of a literal.
    if caption.eq_ignore_ascii_case("Total") {
        effective_caption = default_template.to_string();
    }

    let default_label = default_template.replace("%s", "").trim().to_string();
    let grand_default = if default_label.is_empty() {
        "Grand Total".to_string()
    } else {
        format!("Grand {}", default_label)
    };

    if effective_caption.is_empty() {
        if group_on_col < 0 {
            grand_default
        } else if group_name.is_empty() {
            default_template.replace("%s", "")
        } else {
            default_template.replace("%s", group_name)
        }
    } else {
        let marker_value = if group_on_col < 0 {
            grand_default.as_str()
        } else {
            group_name
        };
        effective_caption.replace("%s", marker_value)
    }
}

#[cfg(test)]
mod tests {
    use super::{subtotal, subtotal_ex};
    use crate::grid::VolvoxGrid;
    use crate::style::CellStyleOverride;

    fn sample_grid() -> VolvoxGrid {
        let mut grid = VolvoxGrid::new(1, 800, 600, 5, 4, 1, 0);
        grid.cells.set_text(0, 0, "Product".to_string());
        grid.cells.set_text(0, 1, "Region".to_string());
        grid.cells.set_text(0, 2, "Sales".to_string());
        grid.cells.set_text(0, 3, "Note".to_string());

        grid.cells.set_text(1, 0, "A".to_string());
        grid.cells.set_text(1, 1, "East".to_string());
        grid.cells.set_text(1, 2, "10".to_string());

        grid.cells.set_text(2, 0, "A".to_string());
        grid.cells.set_text(2, 1, "West".to_string());
        grid.cells.set_text(2, 2, "20".to_string());

        grid.cells.set_text(3, 0, "B".to_string());
        grid.cells.set_text(3, 1, "East".to_string());
        grid.cells.set_text(3, 2, "30".to_string());

        grid.cells.set_text(4, 0, "B".to_string());
        grid.cells.set_text(4, 1, "West".to_string());
        grid.cells.set_text(4, 2, "40".to_string());
        grid
    }

    #[test]
    fn subtotal_multicall_builds_outline_hierarchy() {
        let mut grid = sample_grid();

        subtotal(&mut grid, 2, -1, 2, "", 0, 0, true);
        subtotal(&mut grid, 2, 0, 2, "", 0, 0, true);
        subtotal(&mut grid, 2, 1, 2, "", 0, 0, true);

        for row in grid.fixed_rows..grid.rows {
            let is_subtotal = grid.row_props.get(&row).map_or(false, |p| p.is_subtotal);
            let level = grid.row_props.get(&row).map_or(0, |p| p.outline_level);
            let c0 = grid.cells.get_text(row, 0);
            let c1 = grid.cells.get_text(row, 1);

            if c0 == "Grand Total" {
                assert!(is_subtotal);
                assert_eq!(level, -1);
                assert_eq!(grid.cells.get_text(row, 2), "100");
            } else if c1.starts_with("Total ") {
                assert!(is_subtotal);
                assert_eq!(level, 1);
            } else if c0.starts_with("Total ") {
                assert!(is_subtotal);
                assert_eq!(level, 0);
            } else {
                assert!(!is_subtotal);
                assert_eq!(level, 0);
            }
        }
    }

    #[test]
    fn subtotal_grand_total_inserted_at_top_after_existing_subtotals_when_above() {
        let mut grid = sample_grid();
        // Build some grouped subtotals first, then add grand total last.
        subtotal(&mut grid, 2, 0, 2, "", 0, 0, true);
        subtotal(&mut grid, 2, 1, 2, "", 0, 0, true);
        subtotal(&mut grid, 2, -1, 2, "", 0, 0, true);

        // With SubtotalAbove default, grand total should be the first data row.
        let first_data = grid.fixed_rows;
        assert_eq!(grid.cells.get_text(first_data, 0), "Grand Total");
        assert_eq!(grid.cells.get_text(first_data, 2), "100");
    }

    #[test]
    fn subtotal_match_from_is_column_index_range_start() {
        let mut grid = VolvoxGrid::new(1, 800, 600, 4, 3, 1, 0);
        grid.cells.set_text(0, 0, "A".to_string());
        grid.cells.set_text(0, 1, "B".to_string());
        grid.cells.set_text(0, 2, "Sales".to_string());

        grid.cells.set_text(1, 0, "left-1".to_string());
        grid.cells.set_text(1, 1, "X".to_string());
        grid.cells.set_text(1, 2, "10".to_string());
        grid.cells.set_text(2, 0, "left-2".to_string());
        grid.cells.set_text(2, 1, "X".to_string());
        grid.cells.set_text(2, 2, "20".to_string());
        grid.cells.set_text(3, 0, "left-3".to_string());
        grid.cells.set_text(3, 1, "Y".to_string());
        grid.cells.set_text(3, 2, "30".to_string());

        // Compare only column 1; first two rows remain in one group.
        subtotal_ex(&mut grid, 2, 1, 2, "", 0, 0, false, "", false, 1, false);
        assert_eq!(grid.rows, 6); // header + 3 data + 2 subtotal rows
    }

    #[test]
    fn subtotal_caption_matches_default_and_marker() {
        let mut grid = sample_grid();
        subtotal(&mut grid, 2, 0, 2, "", 0, 0, false);
        let total_a =
            (grid.fixed_rows..grid.rows).find(|&r| grid.cells.get_text(r, 0) == "Total A");
        assert!(total_a.is_some());

        subtotal(&mut grid, 1, 0, 0, "", 0, 0, false); // clear
        subtotal(&mut grid, 2, -1, 2, "", 0, 0, false);
        let grand =
            (grid.fixed_rows..grid.rows).find(|&r| grid.cells.get_text(r, 0) == "Grand Total");
        assert!(grand.is_some());

        subtotal(&mut grid, 1, 0, 0, "", 0, 0, false); // clear
        subtotal(&mut grid, 5, -1, 2, "", 0, 0, false);
        let grand_avg =
            (grid.fixed_rows..grid.rows).find(|&r| grid.cells.get_text(r, 0) == "Grand Average");
        assert!(grand_avg.is_some());

        subtotal(&mut grid, 1, 0, 0, "", 0, 0, false); // clear
        subtotal(&mut grid, 2, 0, 2, "The %s Count", 0, 0, false);
        let marker =
            (grid.fixed_rows..grid.rows).find(|&r| grid.cells.get_text(r, 0) == "The A Count");
        assert!(marker.is_some());

        subtotal(&mut grid, 1, 0, 0, "", 0, 0, false); // clear
        subtotal(&mut grid, 2, 0, 2, "Literal Caption", 0, 0, false);
        let literal =
            (grid.fixed_rows..grid.rows).find(|&r| grid.cells.get_text(r, 0) == "Literal Caption");
        assert!(literal.is_some());
    }

    #[test]
    fn subtotal_clear_restores_row_keyed_metadata_alignment() {
        let mut grid = sample_grid();
        grid.row_heights.insert(3, 42);
        grid.rows_hidden.insert(3);
        grid.row_props.entry(3).or_default().status = 2;
        grid.cell_styles.insert(
            (3, 1),
            CellStyleOverride {
                fore_color: Some(0xFF00AA00),
                ..Default::default()
            },
        );

        subtotal(&mut grid, 2, 0, 2, "", 0, 0, true);
        subtotal(&mut grid, 1, 0, 0, "", 0, 0, false); // clear subtotals

        assert_eq!(grid.rows, 5);
        assert_eq!(grid.row_heights.get(&3), Some(&42));
        assert!(grid.rows_hidden.contains(&3));
        assert!(grid.cell_styles.contains_key(&(3, 1)));
        assert_eq!(grid.row_props.get(&3).map(|p| p.status), Some(2));
    }

    #[test]
    fn subtotal_outline_column_skips_row_back_color_when_outline_enabled() {
        let mut grid = sample_grid();
        let blue = 0x00D0E0F0;
        let green = 0x00D8FFD8;

        subtotal(&mut grid, 5, 0, 2, "Total", blue, 0, true);
        subtotal(&mut grid, 5, 1, 2, "Total", green, 0, true);

        // GroupOn=0 subtotal (caption in col 0): col0 should be filled.
        let row_group0 = (grid.fixed_rows..grid.rows)
            .find(|&r| grid.cells.get_text(r, 0).starts_with("Average "))
            .expect("group_on=0 subtotal row not found");
        let c0_group0 = grid
            .cell_styles
            .get(&(row_group0, 0))
            .cloned()
            .unwrap_or_default();
        assert!(
            c0_group0.back_color.is_some(),
            "group_on=0 subtotal should color col0"
        );

        // GroupOn=1 subtotal (caption in col 1): col0 should remain unfilled, col1 filled.
        let row_group1 = (grid.fixed_rows..grid.rows)
            .find(|&r| grid.cells.get_text(r, 1).starts_with("Average "))
            .expect("group_on=1 subtotal row not found");
        let c0_group1 = grid
            .cell_styles
            .get(&(row_group1, 0))
            .cloned()
            .unwrap_or_default();
        let c1_group1 = grid
            .cell_styles
            .get(&(row_group1, 1))
            .cloned()
            .unwrap_or_default();
        assert!(
            c0_group1.back_color.is_none(),
            "group_on=1 subtotal should keep left key column unfilled"
        );
        assert!(
            c1_group1.back_color.is_some(),
            "group_on=1 subtotal should color caption column"
        );
    }
}

fn format_aggregate(value: f64) -> String {
    if value == value.floor() {
        format!("{}", value as i64)
    } else {
        format!("{:.2}", value)
    }
}

/// Expand/collapse to a given outline level
pub fn outline(grid: &mut VolvoxGrid, level: i32) {
    for row in grid.fixed_rows..grid.rows {
        if let Some(props) = grid.row_props.get_mut(&row) {
            if props.outline_level > level {
                props.is_collapsed = true;
            } else {
                props.is_collapsed = false;
            }
        }
    }
    update_visibility(grid);
}

/// Toggle collapse/expand for a single row
pub fn toggle_collapse(grid: &mut VolvoxGrid, row: i32) {
    if let Some(props) = grid.row_props.get_mut(&row) {
        props.is_collapsed = !props.is_collapsed;
    }
    update_visibility(grid);
}

/// Recompute hidden rows from current outline collapse flags.
pub fn refresh_visibility(grid: &mut VolvoxGrid) {
    update_visibility(grid);
}

/// Update row visibility based on outline collapse state
fn update_visibility(grid: &mut VolvoxGrid) {
    let has_subtotal_nodes = grid.row_props.values().any(|p| p.is_subtotal);
    grid.rows_hidden.clear();

    if has_subtotal_nodes {
        // Subtotal trees use parent subtotal rows as branch markers.
        // Collapse hides rows in the subtotal's branch until the next subtotal at
        // the same or higher branch scope.
        if grid.outline.group_total_position == pb::GroupTotalPosition::GroupTotalBelow as i32 {
            // Subtotals below: children are above the subtotal node.
            for row in (grid.fixed_rows..grid.rows).rev() {
                let Some(props) = grid.row_props.get(&row) else {
                    continue;
                };
                if !props.is_subtotal || !props.is_collapsed {
                    continue;
                }
                let level = props.outline_level;
                let mut r = row - 1;
                while r >= grid.fixed_rows {
                    let rp = grid.row_props.get(&r);
                    let is_sub = rp.map_or(false, |p| p.is_subtotal);
                    let rl = rp.map_or(0, |p| p.outline_level);
                    if is_sub && rl <= level {
                        break;
                    }
                    grid.rows_hidden.insert(r);
                    r -= 1;
                }
            }
        } else {
            // Subtotals above: children are below the subtotal node.
            for row in grid.fixed_rows..grid.rows {
                let Some(props) = grid.row_props.get(&row) else {
                    continue;
                };
                if !props.is_subtotal || !props.is_collapsed {
                    continue;
                }
                let level = props.outline_level;
                let mut r = row + 1;
                while r < grid.rows {
                    let rp = grid.row_props.get(&r);
                    let is_sub = rp.map_or(false, |p| p.is_subtotal);
                    let rl = rp.map_or(0, |p| p.outline_level);
                    if is_sub && rl <= level {
                        break;
                    }
                    grid.rows_hidden.insert(r);
                    r += 1;
                }
            }
        }
    } else if grid.outline.group_total_position == pb::GroupTotalPosition::GroupTotalBelow as i32 {
        // Generic non-subtotal outline (level tree): children have
        // greater outline level than parent.
        let mut hide_above_level = i32::MAX;
        for row in (grid.fixed_rows..grid.rows).rev() {
            let level = grid.row_props.get(&row).map_or(0, |p| p.outline_level);
            let is_collapsed = grid.row_props.get(&row).map_or(false, |p| p.is_collapsed);
            if level <= hide_above_level {
                if is_collapsed {
                    hide_above_level = level;
                } else {
                    hide_above_level = i32::MAX;
                }
            } else {
                grid.rows_hidden.insert(row);
            }
        }
    } else {
        let mut hide_below_level = i32::MAX;
        for row in grid.fixed_rows..grid.rows {
            let level = grid.row_props.get(&row).map_or(0, |p| p.outline_level);
            let is_collapsed = grid.row_props.get(&row).map_or(false, |p| p.is_collapsed);
            if level <= hide_below_level {
                if is_collapsed {
                    hide_below_level = level;
                } else {
                    hide_below_level = i32::MAX;
                }
            } else {
                grid.rows_hidden.insert(row);
            }
        }
    }

    // Rebuild layout immediately so that hidden rows get 0 height and
    // remaining rows reflow into correct positions.  Without this, hosts
    // that render without calling ensure_layout() would see stale
    // positions and blank gaps where collapsed rows used to be.
    grid.layout.invalidate();
    grid.ensure_layout();
    grid.mark_dirty();
}

/// Get node info for outline tree navigation
pub fn get_node_row(grid: &VolvoxGrid, row: i32, relation: i32) -> i32 {
    let level = grid.row_props.get(&row).map_or(0, |p| p.outline_level);

    match relation {
        // NodeRelation enum numeric values are stable in proto/v1:
        // 0=Parent, 1=FirstChild, 2=LastChild, 3=NextSibling, 4=PrevSibling.
        0 => {
            for r in (grid.fixed_rows..row).rev() {
                let rl = grid.row_props.get(&r).map_or(0, |p| p.outline_level);
                if rl < level {
                    return r;
                }
            }
            -1
        }
        1 => {
            if row + 1 < grid.rows {
                let cl = grid
                    .row_props
                    .get(&(row + 1))
                    .map_or(0, |p| p.outline_level);
                if cl > level {
                    return row + 1;
                }
            }
            -1
        }
        2 => {
            let mut last = -1;
            for r in (row + 1)..grid.rows {
                let rl = grid.row_props.get(&r).map_or(0, |p| p.outline_level);
                if rl <= level {
                    break;
                }
                last = r;
            }
            last
        }
        3 => {
            for r in (row + 1)..grid.rows {
                let rl = grid.row_props.get(&r).map_or(0, |p| p.outline_level);
                if rl == level {
                    return r;
                }
                if rl < level {
                    break;
                }
            }
            -1
        }
        4 => {
            for r in (grid.fixed_rows..row).rev() {
                let rl = grid.row_props.get(&r).map_or(0, |p| p.outline_level);
                if rl == level {
                    return r;
                }
                if rl < level {
                    break;
                }
            }
            -1
        }
        _ => -1,
    }
}

/// Get complete node info
pub fn get_node(grid: &VolvoxGrid, row: i32) -> (i32, i32, bool, i32, i32, i32, i32) {
    // Returns (row, level, is_expanded, child_count, parent_row, first_child, last_child)
    let level = grid.row_props.get(&row).map_or(0, |p| p.outline_level);
    let is_collapsed = grid.row_props.get(&row).map_or(false, |p| p.is_collapsed);
    let parent = get_node_row(grid, row, 0);
    let first_child = get_node_row(grid, row, 1);
    let last_child = get_node_row(grid, row, 2);

    let mut child_count = 0;
    if first_child >= 0 {
        for r in first_child..=last_child.max(first_child) {
            let rl = grid.row_props.get(&r).map_or(0, |p| p.outline_level);
            if rl == level + 1 {
                child_count += 1;
            }
            if rl <= level {
                break;
            }
        }
    }

    (
        row,
        level,
        !is_collapsed,
        child_count,
        parent,
        first_child,
        last_child,
    )
}
