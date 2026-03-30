//! Shared demo scenarios for VolvoxGrid host examples.
//!
//! This module is feature-gated behind `demo` and not included in
//! production builds. Direct engine targets and host/plugin adapters can
//! reuse these functions instead of duplicating setup/data logic.
//!
//! Three demos are provided:
//!
//! 1. **Sales Showcase** (`setup_sales_demo`) — ~1000 rows, 10 columns,
//!    subtotals, merged cells, dropdowns, currency/percentage formats,
//!    data bars, alternating row colors, explorer bar, outline bar.
//!
//! 2. **Hierarchy Showcase** (`setup_hierarchy_demo`) — ~200 rows, 6 columns,
//!    simulated directory tree with outline levels, expand/collapse, indented
//!    text, styled folder rows.
//!
//! 3. **Stress Test** (`setup_stress_demo`) — 1M rows, 12 columns, eagerly
//!    materialized for full-dataset sort/scroll benchmarking.  A separate
//!    lazy variant is available via `create_stress_grid`.

use crate::grid::VolvoxGrid;
use crate::indicator::DEFAULT_ROW_INDICATOR_WIDTH;
use crate::outline::{subtotal, subtotal_ex};
use crate::proto::volvoxgrid::v1 as pb;
use crate::scrollbar::{
    default_scrollbar_colors, default_scrollbar_corner_radius, default_scrollbar_size,
    reset_scrollbar_fade_state, DEFAULT_SCROLLBAR_FADE_DELAY_MS,
    DEFAULT_SCROLLBAR_FADE_DURATION_MS, DEFAULT_SCROLLBAR_MARGIN, DEFAULT_SCROLLBAR_MIN_THUMB,
};
use crate::selection::{HOVER_CELL, HOVER_COLUMN, HOVER_ROW};
use crate::style::{CellStylePatch, HighlightStyle};

// ── Shared helpers ──────────────────────────────────────────────────

#[derive(Clone, Copy, Debug)]
struct DemoTheme {
    body_bg: u32,
    body_fg: u32,
    canvas_bg: u32,
    alt_row_bg: u32,
    fixed_bg: u32,
    fixed_fg: u32,
    grid_color: u32,
    fixed_grid_color: u32,
    header_bg: u32,
    header_fg: u32,
    indicator_bg: u32,
    indicator_fg: u32,
    selection_bg: u32,
    selection_fg: u32,
    accent: u32,
    tree_color: u32,
}

const SALES_THEME: DemoTheme = DemoTheme {
    body_bg: 0xFFFFFFFF,
    body_fg: 0xFF111827,
    canvas_bg: 0xFFFAFAFB,
    alt_row_bg: 0xFFF9FAFB,
    fixed_bg: 0xFFF3F4F6,
    fixed_fg: 0xFF374151,
    grid_color: 0xFFE5E7EB,
    fixed_grid_color: 0xFFD1D5DB,
    header_bg: 0xFFF9FAFB,
    header_fg: 0xFF111827,
    indicator_bg: 0xFFF9FAFB,
    indicator_fg: 0xFF6B7280,
    selection_bg: 0xFF6366F1,
    selection_fg: 0xFFFFFFFF,
    accent: 0xFF818CF8,
    tree_color: 0xFF9CA3AF,
};

const HIERARCHY_THEME: DemoTheme = DemoTheme {
    body_bg: 0xFFFFFFFF,
    body_fg: 0xFF1C1917,
    canvas_bg: 0xFFFAFAF9,
    alt_row_bg: 0xFFF5F5F4,
    fixed_bg: 0xFFF5F5F4,
    fixed_fg: 0xFF44403C,
    grid_color: 0xFFE7E5E4,
    fixed_grid_color: 0xFFD6D3D1,
    header_bg: 0xFFFAFAF9,
    header_fg: 0xFF1C1917,
    indicator_bg: 0xFFFAFAF9,
    indicator_fg: 0xFF78716C,
    selection_bg: 0xFFD97706,
    selection_fg: 0xFFFFFFFF,
    accent: 0xFFF59E0B,
    tree_color: 0xFFA8A29E,
};

const STRESS_THEME: DemoTheme = DemoTheme {
    body_bg: 0xFFFFFFFF,
    body_fg: 0xFF1A1A1A,
    canvas_bg: 0xFFF3F3F3,
    alt_row_bg: 0xFFFAFAFA,
    fixed_bg: 0xFFEBEBEB,
    fixed_fg: 0xFF323232,
    grid_color: 0xFFE0E0E0,
    fixed_grid_color: 0xFFCCCCCC,
    header_bg: 0xFFF5F5F5,
    header_fg: 0xFF1A1A1A,
    indicator_bg: 0xFFF5F5F5,
    indicator_fg: 0xFF616161,
    selection_bg: 0xFF005FB8,
    selection_fg: 0xFFFFFFFF,
    accent: 0xFF0078D4,
    tree_color: 0xFF9E9E9E,
};

/// Scale a logical-pixel value by the grid's DPI scale factor.
fn sp(grid: &VolvoxGrid, px: i32) -> i32 {
    if grid.scale <= 1.001 {
        px
    } else {
        (px as f32 * grid.scale).round() as i32
    }
}

fn logical_px(grid: &VolvoxGrid, px: i32) -> i32 {
    if grid.scale <= 1.001 {
        px
    } else {
        ((px as f32) / grid.scale).ceil() as i32
    }
}

fn apply_demo_scrollbar_style(grid: &mut VolvoxGrid, appearance: i32) {
    grid.scrollbar_show_h = pb::ScrollBarMode::ScrollbarModeAuto as i32;
    grid.scrollbar_show_v = pb::ScrollBarMode::ScrollbarModeAuto as i32;
    grid.scrollbar_appearance = appearance;
    grid.scrollbar_size = default_scrollbar_size(appearance);
    grid.scrollbar_min_thumb = DEFAULT_SCROLLBAR_MIN_THUMB;
    grid.scrollbar_corner_radius = default_scrollbar_corner_radius(appearance);
    grid.scrollbar_colors = default_scrollbar_colors(appearance);
    grid.scrollbar_fade_delay_ms = DEFAULT_SCROLLBAR_FADE_DELAY_MS;
    grid.scrollbar_fade_duration_ms = DEFAULT_SCROLLBAR_FADE_DURATION_MS;
    grid.scrollbar_margin = DEFAULT_SCROLLBAR_MARGIN;
    reset_scrollbar_fade_state(grid);
}

fn apply_demo_theme(grid: &mut VolvoxGrid, theme: &DemoTheme) {
    grid.style.back_color = theme.body_bg;
    grid.style.fore_color = theme.body_fg;
    grid.style.back_color_fixed = theme.fixed_bg;
    grid.style.fore_color_fixed = theme.fixed_fg;
    grid.style.back_color_frozen = theme.body_bg;
    grid.style.fore_color_frozen = theme.body_fg;
    grid.style.back_color_bkg = theme.canvas_bg;
    grid.style.back_color_alternate = theme.alt_row_bg;
    grid.style.grid_lines = pb::GridLineStyle::GridlineSolid as i32;
    grid.style.grid_lines_fixed = pb::GridLineStyle::GridlineSolid as i32;
    grid.style.grid_color = theme.grid_color;
    grid.style.grid_color_fixed = theme.fixed_grid_color;
    grid.style.sheet_border = theme.fixed_grid_color;
    grid.style.progress_color = theme.accent;
    grid.style.tree_color = theme.tree_color;
    grid.style.header_separator.enabled = true;
    grid.style.header_separator.color = theme.fixed_grid_color;
    grid.style.header_separator.width_px = 1;
    grid.style.header_resize_handle.enabled = true;
    grid.style.header_resize_handle.color = theme.fixed_grid_color;
    grid.style.header_resize_handle.width_px = 1;
    grid.style.header_resize_handle.hit_width_px = 6;
    grid.selection.selection_style = HighlightStyle {
        back_color: Some(theme.selection_bg),
        fore_color: Some(theme.selection_fg),
        fill_handle: Some(pb::FillHandlePosition::FillHandleNone as i32),
        fill_handle_color: Some(theme.accent),
        ..HighlightStyle::default()
    };
    grid.selection.active_cell_style = HighlightStyle {
        back_color: Some(0x22000000),
        fore_color: Some(theme.selection_fg),
        border: Some(pb::BorderStyle::BorderThick as i32),
        border_color: Some(theme.accent),
        ..HighlightStyle::default()
    };
}

fn apply_demo_column_headers(
    grid: &mut VolvoxGrid,
    headers: &[&str],
    band_row_height_px: i32,
    theme: &DemoTheme,
) {
    for (col, &header) in headers.iter().enumerate() {
        if let Some(cp) = grid.columns.get_mut(col) {
            cp.caption = header.to_string();
        }
    }

    grid.indicator_bands.col_top.visible = true;
    grid.indicator_bands.col_top.band_rows = 1;
    grid.indicator_bands.col_top.default_row_height_px = sp(grid, band_row_height_px);
    grid.indicator_bands.col_top.mode_bits = (pb::ColIndicatorCellMode::ColIndicatorCellHeaderText
        as u32)
        | (pb::ColIndicatorCellMode::ColIndicatorCellSortGlyph as u32);
    grid.indicator_bands.col_top.back_color = Some(theme.header_bg);
    grid.indicator_bands.col_top.fore_color = Some(theme.header_fg);
    grid.indicator_bands.col_top.grid_color = Some(theme.fixed_grid_color);
    grid.indicator_bands.col_top.allow_resize = true;
    grid.indicator_bands.corner_top_start.visible = false;
    grid.indicator_bands.corner_top_start.mode_bits = 0;
    grid.indicator_bands.corner_top_start.custom_key.clear();
    grid.indicator_bands.corner_top_start.data.clear();
}

fn apply_demo_row_indicator(grid: &mut VolvoxGrid, width_px: i32, theme: &DemoTheme) {
    grid.indicator_bands.row_start.visible = true;
    grid.indicator_bands.row_start.width_px = sp(grid, width_px.max(DEFAULT_ROW_INDICATOR_WIDTH));
    grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;
    grid.indicator_bands.row_start.back_color = Some(theme.indicator_bg);
    grid.indicator_bands.row_start.fore_color = Some(theme.indicator_fg);
    grid.indicator_bands.row_start.grid_color = Some(theme.fixed_grid_color);
    grid.indicator_bands.row_start.allow_resize = true;
}

fn stress_row_indicator_width_px(grid: &mut VolvoxGrid, data_rows: i32) -> i32 {
    let label = data_rows.max(1).to_string();
    let font_name = grid.style.font_name.clone();
    let font_size = if grid.style.font_size > 0.0 {
        grid.style.font_size
    } else {
        13.0
    };
    let text_w = {
        let te = grid.ensure_text_engine();
        if te.has_fonts() {
            te.measure_text(&label, &font_name, font_size, false, false, None)
                .0
                .ceil() as i32
        } else {
            (label.chars().count() as f32 * font_size * 0.6).ceil() as i32
        }
    };

    (logical_px(grid, text_w) + 8).max(DEFAULT_ROW_INDICATOR_WIDTH)
}

fn stress_text_col_width_px(grid: &mut VolvoxGrid) -> i32 {
    let font_name = grid.style.font_name.clone();
    let font_size = if grid.style.font_size > 0.0 {
        grid.style.font_size
    } else {
        13.0
    };
    let samples: Vec<&str> = STRESS_TEXT_POOL
        .iter()
        .copied()
        .chain(std::iter::once(STRESS_HEADERS[0]))
        .collect();
    let text_w = {
        let te = grid.ensure_text_engine();
        if te.has_fonts() {
            samples
                .iter()
                .map(|text| {
                    te.measure_text(text, &font_name, font_size, false, false, None)
                        .0
                        .ceil() as i32
                })
                .max()
                .unwrap_or(0)
        } else {
            samples
                .iter()
                .map(|text| (text.chars().count() as f32 * font_size * 0.6).ceil() as i32)
                .max()
                .unwrap_or(0)
        }
    };

    (text_w + sp(grid, STRESS_TEXT_COL_PADDING_PX)).max(sp(grid, STRESS_COL_WIDTHS[0]))
}

fn apply_sales_subtotal_merges(grid: &mut VolvoxGrid) {
    if grid.cols < 2 {
        return;
    }

    for row in grid.fixed_rows..grid.rows {
        let Some(props) = grid.row_props.get(&row) else {
            continue;
        };
        if props.is_subtotal && props.outline_level <= 0 {
            grid.merge_cells(row, 0, row, 1);
        }
    }
}

fn reset_grid(grid: &mut VolvoxGrid) {
    // Clear all data
    grid.cells.clear_all();
    grid.rows = 0;
    grid.cols = 0;
    grid.row_positions.clear();
    grid.col_positions.clear();
    grid.row_heights.clear();
    grid.col_widths.clear();
    grid.row_props.clear();
    grid.columns.clear();
    grid.cell_styles.clear();

    // Reset state
    grid.edit.cancel(); // Ensures active edit is closed
    grid.selection.select(0, 0, 0, 0, 0, 0);
    grid.scroll.scroll_x = 0.0;
    grid.scroll.scroll_y = 0.0;
    grid.span = Default::default();
    grid.outline = Default::default();
    grid.sort_state = Default::default();
    grid.sort_value_generator = None;
    grid.indicator_bands = Default::default();

    // Reset properties to defaults
    grid.fixed_rows = 0;
    grid.fixed_cols = 0;
    grid.frozen_rows = 0;
    grid.frozen_cols = 0;
    grid.style.back_color_alternate = 0;
}

/// splitmix64 hash — deterministic pseudo-random from a seed.
pub fn splitmix64(mut x: u64) -> u64 {
    x = x.wrapping_add(0x9E3779B97F4A7C15);
    let mut z = x;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
    z ^ (z >> 31)
}

/// Pick an index in `0..len` deterministically from (row, salt).
pub fn rand_idx(row: i32, salt: u64, len: usize) -> usize {
    if len == 0 {
        return 0;
    }
    (splitmix64((row as u64) ^ salt) as usize) % len
}

// =====================================================================
// Demo 1: Sales Showcase (~1000 rows)
// =====================================================================

const SALES_PRODUCTS: [&str; 20] = [
    "Widget A",
    "Widget B",
    "Widget C",
    "Widget D",
    "Gadget X",
    "Gadget Y",
    "Gadget Z",
    "Gadget W",
    "Tool Alpha",
    "Tool Beta",
    "Tool Gamma",
    "Tool Delta",
    "Sensor M1",
    "Sensor M2",
    "Module P1",
    "Module P2",
    "Board Q1",
    "Board Q2",
    "Cable R1",
    "Chip S1",
];

const SALES_CATEGORIES: [&str; 5] = ["Electronics", "Hardware", "Tools", "Sensors", "Components"];

/// Map each product index to a category index.
const SALES_PRODUCT_CATEGORY: [usize; 20] = [
    0, 0, 0, 0, // Electronics
    1, 1, 1, 1, // Hardware
    2, 2, 2, 2, // Tools
    3, 3, 3, 3, // Sensors
    4, 4, 4, 4, // Components
];

const SALES_REGIONS: [&str; 4] = ["North", "South", "East", "West"];
const SALES_QUARTERS: [&str; 4] = ["Q1", "Q2", "Q3", "Q4"];
const SALES_STATUSES: [&str; 5] = ["Active", "Pending", "Shipped", "Returned", "Cancelled"];

const SALES_HEADERS: [&str; 10] = [
    "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin%", "Flag", "Status", "Notes",
];
const SALES_COL_WIDTHS: [i32; 10] = [40, 80, 100, 120, 90, 90, 70, 56, 80, 140];
const SALES_DATA_ROWS: i32 = 1000;

/// Configure and populate a grid as the Sales Showcase demo.
///
/// Creates ~1000 data rows with multi-level subtotals:
/// - Product subtotals within each category
/// - Category subtotals
/// - Grand total
///
/// Subtotals are placed above each group for proper outline tree collapse.
/// Outline levels: 0=grand, 1=category, 2=product, 3=data.
pub fn setup_sales_demo(grid: &mut VolvoxGrid) {
    reset_grid(grid);
    apply_demo_theme(grid, &SALES_THEME);
    apply_demo_scrollbar_style(
        grid,
        pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32,
    );

    // ── Generate data in memory ──────────────────────────────────────
    struct Entry {
        product: &'static str,
        category: &'static str,
        region: &'static str,
        quarter: &'static str,
        sales: i32,
        cost: i32,
        margin_pct: f32,
        flagged: bool,
        status: &'static str,
        note: String,
    }

    let note_tags = [
        "review",
        "priority",
        "follow-up",
        "audit",
        "bulk",
        "check",
        "normal",
        "expedite",
    ];
    let mut entries = Vec::with_capacity(SALES_DATA_ROWS as usize);
    for r in 1..=SALES_DATA_ROWS {
        let pi = rand_idx(r, 0xA1, SALES_PRODUCTS.len());
        let ci = SALES_PRODUCT_CATEGORY[pi];
        let ri = rand_idx(r, 0xC3, SALES_REGIONS.len());
        let qi = rand_idx(r, 0xD4, SALES_QUARTERS.len());
        let si = rand_idx(r, 0xE5, SALES_STATUSES.len());
        let ni = rand_idx(r, 0xF6, note_tags.len());
        let flagged = (splitmix64((r as u64) ^ 0x7788) % 4) == 0;
        let sales = 500 + (splitmix64((r as u64) ^ 0x51F0_0DAD) % 49_501) as i32;
        let cost_pct = 40 + (splitmix64((r as u64) ^ 0x22AA_BB) % 46) as i32;
        let cost = sales * cost_pct / 100;
        let margin = if sales > 0 {
            (sales - cost) as f32 / sales as f32 * 100.0
        } else {
            0.0
        };
        let nc = 1000 + (splitmix64((r as u64) ^ 0x4455) % 9000) as i32;
        entries.push(Entry {
            product: SALES_PRODUCTS[pi],
            category: SALES_CATEGORIES[ci],
            region: SALES_REGIONS[ri],
            quarter: SALES_QUARTERS[qi],
            sales,
            cost,
            margin_pct: margin,
            flagged,
            status: SALES_STATUSES[si],
            note: format!("{} note {}", note_tags[ni], nc),
        });
    }

    // ── Sort by Q, then Region ─────────────────────────────────────
    entries.sort_by(|a, b| a.quarter.cmp(b.quarter).then(a.region.cmp(b.region)));

    // ── Configure grid ───────────────────────────────────────────────
    grid.set_rows(entries.len() as i32);
    grid.set_cols(10);

    for (c, &w) in SALES_COL_WIDTHS.iter().enumerate() {
        grid.set_col_width(c as i32, sp(grid, w));
    }
    grid.default_row_height = sp(grid, crate::grid::DEFAULT_ROW_HEIGHT);
    apply_demo_column_headers(grid, &SALES_HEADERS, 28, &SALES_THEME);
    apply_demo_row_indicator(grid, 40, &SALES_THEME);

    grid.columns[0].alignment = pb::Align::CenterCenter as i32;
    grid.columns[4].alignment = pb::Align::RightCenter as i32;
    grid.columns[5].alignment = pb::Align::RightCenter as i32;
    grid.columns[6].alignment = pb::Align::CenterCenter as i32;
    grid.columns[7].data_type = pb::ColumnDataType::ColumnDataBoolean as i32;
    grid.columns[7].alignment = pb::Align::CenterCenter as i32;
    grid.columns[4].format = "$#,##0".to_string();
    grid.columns[5].format = "$#,##0".to_string();
    // Select-only dropdown: no leading `|`.
    grid.columns[8].dropdown_items = "Active|Pending|Shipped|Returned|Cancelled".to_string();
    grid.columns[6].progress_color = SALES_THEME.accent;

    grid.allow_user_resizing = 3;
    grid.tab_behavior = 1;
    grid.edit_trigger_mode = 0; // read-only by default; host demos may enable edit
    grid.dropdown_trigger = 1;
    grid.dropdown_search = false;
    grid.fling_enabled = true;
    grid.fling_impulse_gain = 220.0;
    grid.fling_friction = 0.9;
    grid.header_features = 3;
    grid.auto_size_mouse = true;
    grid.allow_user_freezing = 3;
    grid.selection.hover_mode = HOVER_ROW | HOVER_COLUMN | HOVER_CELL;
    grid.selection.hover_row_style = HighlightStyle {
        back_color: Some(0x106366F1),
        ..HighlightStyle::default()
    };
    grid.selection.hover_column_style = HighlightStyle {
        back_color: Some(0x106366F1),
        ..HighlightStyle::default()
    };
    grid.selection.hover_cell_style = HighlightStyle {
        back_color: Some(0x1E818CF8),
        border: Some(pb::BorderStyle::BorderThin as i32),
        border_color: Some(SALES_THEME.accent),
        ..HighlightStyle::default()
    };

    // ── Write flat data rows ─────────────────────────────────────────
    for (idx, e) in entries.iter().enumerate() {
        let r = idx as i32;
        grid.cells.set_text(r, 0, e.quarter.to_string());
        grid.cells.set_text(r, 1, e.region.to_string());
        grid.cells.set_text(r, 2, e.category.to_string());
        grid.cells.set_text(r, 3, e.product.to_string());
        grid.cells.set_text(r, 4, format!("{}", e.sales));
        grid.cells.set_text(r, 5, format!("{}", e.cost));
        grid.cells.set_text(r, 6, format!("{:.0}", e.margin_pct));
        grid.cells
            .set_text(r, 7, if e.flagged { "Yes" } else { "No" }.to_string());
        {
            let cell = grid.cells.get_mut(r, 7);
            let extra = cell.extra_mut();
            extra.value = crate::cell::CellValueData::Bool(e.flagged);
            extra.checked = if e.flagged {
                pb::CheckedState::CheckedChecked as i32
            } else {
                pb::CheckedState::CheckedUnchecked as i32
            };
        }
        grid.cells.set_text(r, 8, e.status.to_string());
        grid.cells.set_text(r, 9, e.note.clone());
        if e.margin_pct < 0.0 {
            grid.cell_styles.insert(
                (r, 6),
                CellStylePatch {
                    fore_color: Some(0xFFDC2626),
                    font_bold: Some(true),
                    ..Default::default()
                },
            );
        }
    }

    // ── Subtotals: Q → Region → Grand Total (below) ────────────────
    grid.outline.group_total_position = 1; // below
    grid.outline.multi_totals = true;
    subtotal(grid, 1, 0, 0, "", 0, 0, false); // clear existing

    // Sales (col 4)
    subtotal(
        grid,
        2,
        -1,
        4,
        "Grand Total",
        0xFFEEF2FF,
        SALES_THEME.body_fg,
        true,
    );
    subtotal_ex(
        grid,
        2,
        0,
        4,
        "",
        0xFFF5F3FF,
        SALES_THEME.body_fg,
        true,
        "",
        false,
        1,
        false,
    );
    subtotal_ex(
        grid,
        2,
        1,
        4,
        "",
        0xFFF8F7FF,
        SALES_THEME.body_fg,
        true,
        "",
        false,
        1,
        false,
    );

    // Cost (col 5) — multi_totals reuses existing subtotal rows
    subtotal(
        grid,
        2,
        -1,
        5,
        "Grand Total",
        0xFFEEF2FF,
        SALES_THEME.body_fg,
        true,
    );
    subtotal_ex(
        grid,
        2,
        0,
        5,
        "",
        0xFFF5F3FF,
        SALES_THEME.body_fg,
        true,
        "",
        false,
        1,
        false,
    );
    subtotal_ex(
        grid,
        2,
        1,
        5,
        "",
        0xFFF8F7FF,
        SALES_THEME.body_fg,
        true,
        "",
        false,
        1,
        false,
    );

    // Derive margin% and gray-out checkboxes on subtotal rows.
    let margin_f = |s: i64, c: i64| -> f64 {
        if s > 0 {
            (s - c) as f64 / s as f64 * 100.0
        } else {
            0.0
        }
    };
    let parse_i64 = |s: &str| -> i64 { s.parse::<i64>().unwrap_or(0) };
    let row_count = grid.rows;
    for row in grid.fixed_rows..row_count {
        let Some(props) = grid.row_props.get(&row) else {
            continue;
        };
        if !props.is_subtotal {
            continue;
        }
        {
            let cell = grid.cells.get_mut(row, 7);
            let extra = cell.extra_mut();
            extra.value = crate::cell::CellValueData::Bool(false);
            extra.checked = pb::CheckedState::CheckedGrayed as i32;
        }
        let sales_sum = parse_i64(grid.cells.get_text(row, 4));
        let cost_sum = parse_i64(grid.cells.get_text(row, 5));
        grid.cells
            .set_text(row, 6, format!("{:.1}", margin_f(sales_sum, cost_sum)));
    }

    // Span on Q and Region columns
    grid.span.mode = 4;
    grid.span.mode_fixed = 0;
    grid.span.span_cols.clear();
    grid.span.span_cols.insert(0, true);
    grid.span.span_cols.insert(1, true);
    grid.span.span_compare = 1;
    apply_sales_subtotal_merges(grid);

    // Outline bar
    grid.outline.tree_indicator = 0;
    grid.outline.group_total_position = 1; // below

    grid.layout.invalidate();
    grid.mark_dirty();
}

// =====================================================================
// Demo 2: Hierarchy Showcase (~200 rows)
// =====================================================================

const HIERARCHY_HEADERS: [&str; 6] = ["Name", "Type", "Size", "Modified", "Permissions", "Action"];
const HIERARCHY_COL_WIDTHS: [i32; 6] = [260, 80, 80, 120, 100, 92];

struct DirEntry {
    name: &'static str,
    kind: &'static str, // "Folder", "File"
    size_kb: i32,       // 0 for folders
    modified: &'static str,
    perms: &'static str,
    level: i32,
}

/// Configure and populate a grid as the Hierarchy Showcase demo.
///
/// Creates ~200 rows showing a directory tree with outline levels,
/// expand/collapse, indented names, and styled folder rows.
pub fn setup_hierarchy_demo(grid: &mut VolvoxGrid) {
    reset_grid(grid);
    apply_demo_theme(grid, &HIERARCHY_THEME);
    apply_demo_scrollbar_style(
        grid,
        pb::ScrollBarAppearance::ScrollbarAppearanceModern as i32,
    );
    let entries = build_hierarchy_entries();
    let data_rows = entries.len() as i32;

    grid.set_rows(data_rows);
    grid.set_cols(HIERARCHY_HEADERS.len() as i32);

    // Column widths
    for (c, &w) in HIERARCHY_COL_WIDTHS.iter().enumerate() {
        grid.set_col_width(c as i32, sp(grid, w));
    }

    grid.default_row_height = sp(grid, crate::grid::DEFAULT_ROW_HEIGHT);
    apply_demo_column_headers(grid, &HIERARCHY_HEADERS, 28, &HIERARCHY_THEME);

    // Column alignments
    grid.columns[2].alignment = pb::Align::RightCenter as i32;
    grid.columns[4].alignment = pb::Align::CenterCenter as i32;
    grid.columns[5].alignment = pb::Align::CenterCenter as i32;
    grid.columns[5].interaction = pb::CellInteraction::TextLink as i32;

    // Alternating row color
    // Interaction defaults
    grid.allow_user_resizing = 3;
    grid.tab_behavior = 1;
    grid.edit_trigger_mode = 0; // read-only for hierarchy
    grid.fling_enabled = true;
    grid.fling_impulse_gain = 220.0;
    grid.fling_friction = 0.9;
    grid.header_features = 0; // disabled — flat sort is incompatible with tree hierarchy
    grid.auto_size_mouse = true;
    grid.selection.hover_mode = HOVER_CELL;
    grid.selection.hover_row_style = HighlightStyle::default();
    grid.selection.hover_column_style = HighlightStyle::default();
    grid.selection.hover_cell_style = HighlightStyle {
        back_color: Some(0x1AD97706),
        border: Some(pb::BorderStyle::BorderThin as i32),
        border_color: Some(HIERARCHY_THEME.accent),
        ..HighlightStyle::default()
    };

    // Populate data rows
    for (i, entry) in entries.iter().enumerate() {
        let r = i as i32;

        // Plain name — visual indent is handled by the outline tree renderer
        grid.cells.set_text(r, 0, entry.name.to_string());
        grid.cells.set_text(r, 1, entry.kind.to_string());
        if entry.size_kb > 0 {
            grid.cells.set_text(r, 2, format_size(entry.size_kb));
        }
        grid.cells.set_text(r, 3, entry.modified.to_string());
        grid.cells.set_text(r, 4, entry.perms.to_string());
        grid.cells.set_text(
            r,
            5,
            if entry.kind == "Folder" {
                "Browse"
            } else {
                "Open"
            }
            .to_string(),
        );

        // Set outline level (shift +1 so root-level folders at level 0
        // become level 1 and get +/- buttons from the renderer)
        let props = grid.row_props.entry(r).or_default();
        props.outline_level = entry.level + 1;
        if entry.kind == "Folder" {
            props.is_subtotal = true;
        }

        grid.cell_styles.insert(
            (r, 5),
            CellStylePatch {
                fore_color: Some(0xFF2563EB),
                font_bold: Some(false),
                ..Default::default()
            },
        );

        // Style folders bold
        if entry.kind == "Folder" {
            grid.cell_styles.insert(
                (r, 0),
                CellStylePatch {
                    font_bold: Some(true),
                    fore_color: Some(0xFF92400E),
                    ..Default::default()
                },
            );
        }
    }

    // Outline bar in complete mode
    grid.outline.tree_indicator = 2;
    grid.outline.tree_column = 0;

    grid.layout.invalidate();
    grid.mark_dirty();
}

fn format_size(kb: i32) -> String {
    if kb >= 1024 * 1024 {
        format!("{:.1} GB", kb as f64 / (1024.0 * 1024.0))
    } else if kb >= 1024 {
        format!("{:.1} MB", kb as f64 / 1024.0)
    } else {
        format!("{} KB", kb)
    }
}

fn build_hierarchy_entries() -> Vec<DirEntry> {
    let mut entries = Vec::with_capacity(200);

    // Helper macro for folder/file entries
    macro_rules! folder {
        ($name:expr, $level:expr, $date:expr) => {
            entries.push(DirEntry {
                name: $name,
                kind: "Folder",
                size_kb: 0,
                modified: $date,
                perms: "rwxr-xr-x",
                level: $level,
            });
        };
    }
    macro_rules! file {
        ($name:expr, $level:expr, $size:expr, $date:expr, $perms:expr) => {
            entries.push(DirEntry {
                name: $name,
                kind: "File",
                size_kb: $size,
                modified: $date,
                perms: $perms,
                level: $level,
            });
        };
    }

    // Root-level directories
    // Documents/
    folder!("Documents", 0, "2025-12-01");
    folder!("Reports", 1, "2025-11-15");
    file!("Q1_Report.xlsx", 2, 245, "2025-03-31", "rw-r--r--");
    file!("Q2_Report.xlsx", 2, 312, "2025-06-30", "rw-r--r--");
    file!("Q3_Report.pdf", 2, 1840, "2025-09-30", "rw-r--r--");
    file!("Q4_Report.docx", 2, 178, "2025-12-15", "rw-r--r--");
    file!("Annual_Summary.pdf", 2, 4200, "2025-12-20", "rw-r--r--");
    folder!("Invoices", 1, "2025-12-10");
    file!("INV-001.pdf", 2, 89, "2025-01-15", "rw-r--r--");
    file!("INV-002.pdf", 2, 92, "2025-02-18", "rw-r--r--");
    file!("INV-003.pdf", 2, 76, "2025-03-22", "rw-r--r--");
    file!("INV-004.pdf", 2, 134, "2025-04-10", "rw-r--r--");
    file!("INV-005.pdf", 2, 98, "2025-05-05", "rw-r--r--");
    file!("INV-006.pdf", 2, 112, "2025-06-08", "rw-r--r--");
    file!("INV-007.pdf", 2, 87, "2025-07-14", "rw-r--r--");
    file!("INV-008.pdf", 2, 145, "2025-08-19", "rw-r--r--");
    file!("INV-009.pdf", 2, 93, "2025-09-23", "rw-r--r--");
    file!("INV-010.pdf", 2, 101, "2025-10-30", "rw-r--r--");
    file!("INV-011.pdf", 2, 88, "2025-11-12", "rw-r--r--");
    file!("INV-012.pdf", 2, 156, "2025-12-05", "rw-r--r--");
    folder!("Contracts", 1, "2025-10-01");
    file!("Contract_Alpha.pdf", 2, 2100, "2025-01-20", "rw-------");
    file!("Contract_Beta.pdf", 2, 1850, "2025-04-15", "rw-------");
    file!("Contract_Gamma.docx", 2, 980, "2025-07-01", "rw-------");
    file!("NDA_Template.docx", 2, 45, "2025-02-10", "rw-r--r--");
    folder!("Presentations", 1, "2025-11-20");
    file!("Roadmap_2025.pptx", 2, 8500, "2025-01-10", "rw-r--r--");
    file!("Team_Kickoff.pptx", 2, 5200, "2025-03-01", "rw-r--r--");
    file!("Client_Demo.pptx", 2, 12400, "2025-06-15", "rw-r--r--");
    file!("Year_Review.pptx", 2, 9800, "2025-12-18", "rw-r--r--");

    // Photos/
    folder!("Photos", 0, "2025-11-30");
    folder!("Vacation", 1, "2025-08-20");
    file!("IMG_001.jpg", 2, 3200, "2025-08-01", "rw-r--r--");
    file!("IMG_002.jpg", 2, 2800, "2025-08-01", "rw-r--r--");
    file!("IMG_003.jpg", 2, 4100, "2025-08-02", "rw-r--r--");
    file!("IMG_004.jpg", 2, 3600, "2025-08-03", "rw-r--r--");
    file!("IMG_005.jpg", 2, 2950, "2025-08-04", "rw-r--r--");
    file!("IMG_006.jpg", 2, 5100, "2025-08-05", "rw-r--r--");
    file!("IMG_007.jpg", 2, 3800, "2025-08-06", "rw-r--r--");
    file!("IMG_008.jpg", 2, 4200, "2025-08-07", "rw-r--r--");
    folder!("Panoramas", 2, "2025-08-10");
    file!("PANO_001.jpg", 3, 12500, "2025-08-02", "rw-r--r--");
    file!("PANO_002.jpg", 3, 15200, "2025-08-04", "rw-r--r--");
    file!("PANO_003.jpg", 3, 11800, "2025-08-06", "rw-r--r--");
    folder!("Events", 1, "2025-11-10");
    file!("Conference_01.jpg", 2, 2400, "2025-05-15", "rw-r--r--");
    file!("Conference_02.jpg", 2, 3100, "2025-05-15", "rw-r--r--");
    file!("Conference_03.jpg", 2, 2700, "2025-05-16", "rw-r--r--");
    file!("TeamDinner.jpg", 2, 4500, "2025-09-20", "rw-r--r--");
    file!("Award_Ceremony.jpg", 2, 3800, "2025-11-05", "rw-r--r--");
    folder!("Screenshots", 1, "2025-12-15");
    file!("Screen_001.png", 2, 890, "2025-10-01", "rw-r--r--");
    file!("Screen_002.png", 2, 1200, "2025-10-15", "rw-r--r--");
    file!("Screen_003.png", 2, 780, "2025-11-01", "rw-r--r--");
    file!("Screen_004.png", 2, 950, "2025-11-20", "rw-r--r--");
    file!("Screen_005.png", 2, 1100, "2025-12-10", "rw-r--r--");

    // Projects/
    folder!("Projects", 0, "2025-12-18");
    folder!("VolvoxGrid", 1, "2025-12-18");
    folder!("src", 2, "2025-12-18");
    file!("main.rs", 3, 12, "2025-12-18", "rw-r--r--");
    file!("lib.rs", 3, 45, "2025-12-17", "rw-r--r--");
    file!("grid.rs", 3, 128, "2025-12-16", "rw-r--r--");
    file!("render.rs", 3, 89, "2025-12-15", "rw-r--r--");
    file!("cell.rs", 3, 34, "2025-12-14", "rw-r--r--");
    file!("style.rs", 3, 22, "2025-12-13", "rw-r--r--");
    folder!("tests", 2, "2025-12-10");
    file!("test_grid.rs", 3, 56, "2025-12-10", "rw-r--r--");
    file!("test_render.rs", 3, 78, "2025-12-09", "rw-r--r--");
    file!("test_edit.rs", 3, 34, "2025-12-08", "rw-r--r--");
    file!("Cargo.toml", 2, 2, "2025-12-15", "rw-r--r--");
    file!("README.md", 2, 8, "2025-12-01", "rw-r--r--");
    folder!("WebApp", 1, "2025-11-25");
    folder!("src", 2, "2025-11-25");
    file!("index.ts", 3, 15, "2025-11-25", "rw-r--r--");
    file!("app.ts", 3, 42, "2025-11-24", "rw-r--r--");
    file!("style.css", 3, 18, "2025-11-23", "rw-r--r--");
    folder!("public", 2, "2025-11-20");
    file!("index.html", 3, 3, "2025-11-20", "rw-r--r--");
    file!("favicon.ico", 3, 4, "2025-11-01", "rw-r--r--");
    file!("package.json", 2, 2, "2025-11-15", "rw-r--r--");
    file!("tsconfig.json", 2, 1, "2025-11-10", "rw-r--r--");
    folder!("MobileApp", 1, "2025-10-30");
    folder!("android", 2, "2025-10-30");
    file!("MainActivity.kt", 3, 28, "2025-10-30", "rw-r--r--");
    file!("build.gradle.kts", 3, 5, "2025-10-25", "rw-r--r--");
    folder!("ios", 2, "2025-10-28");
    file!("AppDelegate.swift", 3, 15, "2025-10-28", "rw-r--r--");
    file!("ContentView.swift", 3, 22, "2025-10-27", "rw-r--r--");

    // Music/
    folder!("Music", 0, "2025-09-15");
    folder!("Classical", 1, "2025-06-01");
    file!("Bach_BWV1007.flac", 2, 45000, "2025-01-10", "rw-r--r--");
    file!("Mozart_K545.flac", 2, 38000, "2025-02-15", "rw-r--r--");
    file!("Beethoven_Op27.flac", 2, 52000, "2025-03-20", "rw-r--r--");
    folder!("Jazz", 1, "2025-09-15");
    file!("Blue_Train.flac", 2, 61000, "2025-05-01", "rw-r--r--");
    file!("Kind_of_Blue.flac", 2, 58000, "2025-06-10", "rw-r--r--");
    file!("Mingus_Ah_Um.flac", 2, 49000, "2025-07-05", "rw-r--r--");
    folder!("Playlists", 1, "2025-09-01");
    file!("WorkFocus.m3u", 2, 2, "2025-08-01", "rw-r--r--");
    file!("Relaxation.m3u", 2, 3, "2025-08-15", "rw-r--r--");
    file!("Running.m3u", 2, 2, "2025-09-01", "rw-r--r--");

    // Downloads/
    folder!("Downloads", 0, "2025-12-20");
    file!("setup_v3.2.exe", 1, 85000, "2025-12-01", "rw-r--r--");
    file!("manual.pdf", 1, 12400, "2025-11-15", "rw-r--r--");
    file!("data_export.csv", 1, 34000, "2025-12-10", "rw-r--r--");
    file!("wallpaper.jpg", 1, 8900, "2025-10-20", "rw-r--r--");
    file!("archive_2024.tar.gz", 1, 256000, "2025-01-05", "rw-r--r--");
    file!("notes.txt", 1, 12, "2025-12-20", "rw-r--r--");
    file!(
        "presentation_draft.pptx",
        1,
        15600,
        "2025-12-18",
        "rw-r--r--"
    );
    file!("database_backup.sql", 1, 128000, "2025-12-15", "rw-------");

    // Recycle Bin/
    folder!("Recycle Bin", 0, "2025-12-19");
    file!("old_report.docx", 1, 340, "2025-06-01", "rw-------");
    file!("temp_data.xlsx", 1, 890, "2025-08-10", "rw-------");
    file!("draft_v1.txt", 1, 15, "2025-09-22", "rw-------");

    entries
}

// =====================================================================
// Demo 3: Stress Test (~1M rows)
// =====================================================================

/// Default data rows for the stress test (1 million).
pub const STRESS_DATA_ROWS: i32 = 1_000_000;
/// Default number of rows to preload at startup.
pub const STRESS_PRELOAD_ROWS: i32 = 2_000;
/// Padding rows to materialize around the visible window.
pub const STRESS_MATERIALIZE_PADDING: i32 = 48;

const STRESS_HEADERS: [&str; 11] = [
    "Text",
    "Number",
    "Currency",
    "Pct",
    "Date",
    "Bool",
    "Combo",
    "Long Text",
    "Formatted",
    "Rating",
    "Code",
];
const STRESS_COL_WIDTHS: [i32; 11] = [68, 80, 90, 60, 100, 50, 90, 160, 90, 60, 100];
const STRESS_TEXT_COL_PADDING_PX: i32 = 12;

const STRESS_TEXT_POOL: [&str; 10] = [
    "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet",
];

const STRESS_COMBO_OPTIONS: [&str; 5] =
    ["Option A", "Option B", "Option C", "Option D", "Option E"];

const STRESS_LONG_TEXT: [&str; 8] = [
    "Short note",
    "A medium-length description for testing",
    "This is a longer text entry that spans multiple words and exercises the text layout engine",
    "Review pending",
    "Approved by management team after thorough evaluation of all criteria",
    "TODO: follow up next quarter",
    "Flagged for audit - requires additional documentation and verification steps",
    "Completed",
];

fn stress_bool_value(source_row: i32) -> bool {
    let logical_row = source_row.max(0) + 1;
    (splitmix64((logical_row as u64) ^ 0xDEF0) % 2) != 0
}

fn stress_checkbox_state(source_row: i32) -> i32 {
    if stress_bool_value(source_row) {
        pb::CheckedState::CheckedChecked as i32
    } else {
        pb::CheckedState::CheckedUnchecked as i32
    }
}

fn stress_apply_bool_cell(grid: &mut VolvoxGrid, row: i32, source_row: i32) {
    let bool_value = stress_bool_value(source_row);
    let cell = grid.cells.get_mut(row, 5);
    let extra = cell.extra_mut();
    extra.value = crate::cell::CellValueData::Bool(bool_value);
    extra.checked = stress_checkbox_state(source_row);
}

/// Configure a grid as the Stress Test demo (1M rows, 12 columns).
///
/// Sets up column widths, headers, alignment, dropdown lists, formats,
/// progress colors, and interaction settings.  All 1M data rows are
/// materialized in memory at startup so sort and scroll work on the
/// complete dataset.
pub fn setup_stress_demo(grid: &mut VolvoxGrid) {
    setup_stress_grid(
        grid,
        STRESS_DATA_ROWS,
        stress_cell_capacity_for_rows(STRESS_DATA_ROWS),
    );

    // Generate all cell texts in parallel across CPU cores if rayon is enabled,
    // then insert into CellStore sequentially (HashMap insert is fast
    // with pre-allocated capacity).
    #[cfg(feature = "rayon")]
    let all_texts: Vec<(i32, Vec<String>)> = {
        use rayon::prelude::*;
        (0..STRESS_DATA_ROWS)
            .into_par_iter()
            .map(|r| {
                let texts: Vec<String> = (0..12).map(|c| stress_cell_text(r, c as i32)).collect();
                (r, texts)
            })
            .collect()
    };

    #[cfg(not(feature = "rayon"))]
    let all_texts: Vec<(i32, Vec<String>)> = (0..STRESS_DATA_ROWS)
        .map(|r| {
            let texts: Vec<String> = (0..12).map(|c| stress_cell_text(r, c as i32)).collect();
            (r, texts)
        })
        .collect();

    for (r, texts) in all_texts {
        for (c, text) in texts.into_iter().enumerate() {
            grid.cells.set_text(r, c as i32, text);
        }
        stress_apply_bool_cell(grid, r, r);
    }
}

/// Create a fully configured stress demo grid with lazy row materialization.
///
/// Only `preload_rows` are generated at startup; remaining
/// rows are materialized on demand by `stress_materialize_visible_rows`.
pub fn create_stress_grid(
    id: i64,
    width: i32,
    height: i32,
    data_rows: i32,
    preload_rows: i32,
) -> VolvoxGrid {
    let data_rows = data_rows.max(0);
    let preload_rows = preload_rows.clamp(0, data_rows);
    let reserve_rows = (preload_rows + STRESS_MATERIALIZE_PADDING * 4).clamp(0, data_rows);

    let mut grid = VolvoxGrid::new(id, width, height, data_rows, 12, 0, 1);
    setup_stress_grid(
        &mut grid,
        data_rows,
        stress_cell_capacity_for_rows(reserve_rows),
    );

    // Enable virtual sort for unmaterialized rows.
    if preload_rows < data_rows {
        grid.sort_value_generator = Some(stress_cell_text);
    }

    // Materialize only a small startup window.
    for r in 0..preload_rows {
        stress_materialize_row(&mut grid, r);
    }

    // If viewport is known, also fill the first visible window.
    if width > 0 && height > 0 {
        stress_materialize_visible_rows(&mut grid, STRESS_MATERIALIZE_PADDING);
    }
    grid
}

fn stress_cell_capacity_for_rows(data_rows: i32) -> usize {
    (data_rows.max(0) as usize).saturating_mul(12)
}

fn setup_stress_grid(grid: &mut VolvoxGrid, data_rows: i32, cell_capacity: usize) {
    reset_grid(grid);
    apply_demo_theme(grid, &STRESS_THEME);
    apply_demo_scrollbar_style(
        grid,
        pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32,
    );
    grid.scrollbar_show_h = pb::ScrollBarMode::ScrollbarModeAuto as i32;
    grid.scrollbar_show_v = pb::ScrollBarMode::ScrollbarModeAlways as i32;
    // Capacity is caller-defined: eager path uses full dataset; lazy path
    // keeps startup memory/time low and grows on demand.
    grid.cells = crate::cell::CellStore::with_capacity(cell_capacity.max(12));
    grid.set_rows(data_rows.max(0));
    grid.set_cols(11);

    // Column widths
    let text_col_width = stress_text_col_width_px(grid);
    grid.set_col_width(0, text_col_width);
    for (c, &w) in STRESS_COL_WIDTHS.iter().enumerate().skip(1) {
        grid.set_col_width(c as i32, sp(grid, w));
    }

    grid.default_row_height = sp(grid, crate::grid::DEFAULT_ROW_HEIGHT);
    apply_demo_column_headers(grid, &STRESS_HEADERS, 28, &STRESS_THEME);
    let row_indicator_width = stress_row_indicator_width_px(grid, data_rows);
    apply_demo_row_indicator(grid, row_indicator_width, &STRESS_THEME);

    // Column alignments
    grid.columns[1].alignment = pb::Align::RightCenter as i32;
    grid.columns[2].alignment = pb::Align::RightCenter as i32;
    grid.columns[3].alignment = pb::Align::CenterCenter as i32;
    grid.columns[5].data_type = pb::ColumnDataType::ColumnDataBoolean as i32;
    grid.columns[5].alignment = pb::Align::CenterCenter as i32;
    grid.columns[9].alignment = pb::Align::CenterCenter as i32;

    // Column display formats
    grid.columns[2].format = "$#,##0".to_string(); // Currency

    // Dropdown list
    // Select-only dropdown: no leading `|`.
    grid.columns[6].dropdown_items = "Option A|Option B|Option C|Option D|Option E".to_string();

    // Rating progress (data-bar)
    grid.columns[9].progress_color = 0xFF0078D4;

    // Interaction defaults
    grid.allow_user_resizing = 3;
    grid.tab_behavior = 1;
    grid.edit_trigger_mode = 0; // read-only by default; host demos may enable edit
    grid.dropdown_trigger = 1;
    grid.dropdown_search = false;
    grid.fling_enabled = true;
    grid.fling_impulse_gain = 220.0;
    grid.fling_friction = 0.9;
    grid.header_features = 3;
    grid.auto_size_mouse = true;
    grid.allow_user_freezing = 3;
    grid.selection.hover_mode = HOVER_ROW;
    grid.selection.hover_row_style = HighlightStyle {
        back_color: Some(0x120078D4),
        ..HighlightStyle::default()
    };
    grid.selection.hover_column_style = HighlightStyle::default();
    grid.selection.hover_cell_style = HighlightStyle::default();
}

/// Compute the cell text for a given source row and column (stress test).
///
/// This is a pure function — given the same (source_row, col) it always
/// returns the same string.  Used by `stress_materialize_row` and by the
/// sort system (via `sort_value_generator`) to compare unmaterialized rows.
pub fn stress_cell_text(source_row: i32, col: i32) -> String {
    let logical_row = source_row.max(0) + 1;
    match col {
        0 => STRESS_TEXT_POOL[rand_idx(logical_row, 0xA1, STRESS_TEXT_POOL.len())].to_string(),
        1 => {
            let number = (splitmix64((logical_row as u64) ^ 0x1234) % 100_000) as i32 - 50_000;
            format!("{}", number)
        }
        2 => {
            let currency = 100 + (splitmix64((logical_row as u64) ^ 0x5678) % 999_900) as i32;
            format!("{}", currency)
        }
        3 => {
            let pct = (splitmix64((logical_row as u64) ^ 0x9ABC) % 101) as f32;
            format!("{:.0}", pct)
        }
        4 => {
            let day_offset = (splitmix64((logical_row as u64) ^ 0xAABB) % 2190) as i32;
            let year = 2020 + day_offset / 365;
            let day_in_year = day_offset % 365;
            let month = (day_in_year / 30).min(11) + 1;
            let day = (day_in_year % 30) + 1;
            format!("{:04}-{:02}-{:02}", year, month, day)
        }
        5 => {
            let bool_val = (splitmix64((logical_row as u64) ^ 0xDEF0) % 2) != 0;
            if bool_val { "Yes" } else { "No" }.to_string()
        }
        6 => STRESS_COMBO_OPTIONS[rand_idx(logical_row, 0xB2, STRESS_COMBO_OPTIONS.len())]
            .to_string(),
        7 => STRESS_LONG_TEXT[rand_idx(logical_row, 0xC3, STRESS_LONG_TEXT.len())].to_string(),
        8 => {
            let formatted =
                (splitmix64((logical_row as u64) ^ 0xEEFF) % 10_000_000) as f64 / 1000.0;
            format!("{:.3}", formatted)
        }
        9 => {
            let rating = (splitmix64((logical_row as u64) ^ 0x3355) % 100) as f32;
            format!("{:.0}", rating)
        }
        10 => {
            let code_val = splitmix64((logical_row as u64) ^ 0xCCDD);
            format!("{:016X}", code_val)
        }
        _ => String::new(),
    }
}

/// Populate a single data row with deterministic random values (stress test).
///
/// Uses `row_positions[row]` as the source seed so that sorted order is
/// preserved across trim/re-materialize cycles.
/// Does nothing if `row` is out of range or already has data in col 0.
pub fn stress_materialize_row(grid: &mut VolvoxGrid, row: i32) {
    if row < 0 || row >= grid.rows {
        return;
    }
    if grid.cells.contains(row, 0) {
        return;
    }

    let source_row = grid.row_positions.get(row as usize).copied().unwrap_or(row);

    for col in 0..11 {
        grid.cells
            .set_text(row, col, stress_cell_text(source_row, col));
    }
    stress_apply_bool_cell(grid, row, source_row);
}

/// Ensure layout is up to date and materialize visible stress rows.
///
/// Materializes the current scroll window plus `padding` rows above/below.
/// Rows outside this range are kept as-is (no trimming).
pub fn stress_materialize_visible_rows(grid: &mut VolvoxGrid, padding: i32) {
    grid.ensure_layout();
    if grid.viewport_height <= 0 {
        return;
    }
    let fixed_row_end = (grid.fixed_rows + grid.frozen_rows).clamp(0, grid.rows);
    if fixed_row_end >= grid.rows {
        return;
    }

    let (first, last) =
        grid.layout
            .visible_rows(grid.scroll.scroll_y, grid.viewport_height, fixed_row_end);
    let start = (first - padding.max(0)).max(fixed_row_end);
    let end = (last + padding.max(0)).min(grid.rows - 1);

    if start > end {
        return;
    }
    for row in start..=end {
        stress_materialize_row(grid, row);
    }
}

// ── Compatibility aliases ───────────────────────────────────────────
// These allow existing code to continue working during migration.

/// Alias for `STRESS_DATA_ROWS`.
pub const DEFAULT_DATA_ROWS: i32 = STRESS_DATA_ROWS;
/// Alias for `STRESS_PRELOAD_ROWS`.
pub const DEFAULT_PRELOAD_ROWS: i32 = STRESS_PRELOAD_ROWS;
/// Alias for `STRESS_MATERIALIZE_PADDING`.
pub const DEFAULT_MATERIALIZE_PADDING: i32 = STRESS_MATERIALIZE_PADDING;

/// Alias: configure grid as stress test.
pub fn setup_sales_grid(grid: &mut VolvoxGrid) {
    setup_stress_grid(
        grid,
        STRESS_DATA_ROWS,
        stress_cell_capacity_for_rows(STRESS_DATA_ROWS),
    );
}

/// Alias: create a stress test grid.
pub fn create_sales_grid(
    id: i64,
    width: i32,
    height: i32,
    data_rows: i32,
    preload_rows: i32,
) -> VolvoxGrid {
    create_stress_grid(id, width, height, data_rows, preload_rows)
}

/// Alias: materialize a stress test row.
pub fn materialize_row(grid: &mut VolvoxGrid, row: i32) {
    stress_materialize_row(grid, row);
}

/// Alias: materialize visible rows for stress test.
pub fn materialize_visible_rows(grid: &mut VolvoxGrid, padding: i32) {
    stress_materialize_visible_rows(grid, padding);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sales_demo_uses_indicator_headers() {
        let mut grid = VolvoxGrid::new(1, 960, 540, 1, 1, 0, 0);
        setup_sales_demo(&mut grid);

        assert_eq!(grid.fixed_rows, 0);
        assert_eq!(grid.fixed_cols, 0);
        assert_eq!(grid.columns[0].caption, "Q");
        assert_eq!(grid.columns[4].caption, "Sales");
        assert_eq!(grid.columns[7].caption, "Flag");
        assert_eq!(grid.columns[8].caption, "Status");
        assert_eq!(
            grid.columns[7].data_type,
            pb::ColumnDataType::ColumnDataBoolean as i32
        );
        assert!(matches!(
            grid.cells.get(0, 7).map(|cell| cell.checked()),
            Some(v)
                if v == pb::CheckedState::CheckedChecked as i32
                    || v == pb::CheckedState::CheckedUnchecked as i32
        ));
        assert!(grid.indicator_bands.col_top.visible);
        assert!(grid.indicator_bands.row_start.visible);
        assert_eq!(grid.indicator_bands.col_top.row_count(), 1);
        assert_eq!(
            grid.indicator_bands.row_start.mode_bits,
            pb::RowIndicatorMode::RowIndicatorNumbers as u32
        );
        assert_ne!(grid.cells.get_text(0, 0), "Q");
        assert_ne!(grid.cells.get_text(0, 4), "Sales");
    }

    #[test]
    fn sales_demo_merges_q_and_region_for_q_subtotals_and_grand_total() {
        let mut grid = VolvoxGrid::new(1, 960, 540, 1, 1, 0, 0);
        setup_sales_demo(&mut grid);

        let mut merged_subtotal_rows = 0;
        let mut region_subtotal_rows = 0;
        for row in grid.fixed_rows..grid.rows {
            let Some(props) = grid.row_props.get(&row) else {
                continue;
            };
            if !props.is_subtotal {
                continue;
            }

            assert_eq!(
                grid.cells.get(row, 7).map(|cell| cell.checked()),
                Some(pb::CheckedState::CheckedGrayed as i32)
            );

            if props.outline_level <= 0 {
                merged_subtotal_rows += 1;
                assert_eq!(grid.get_merged_range(row, 0), Some((row, 0, row, 1)));
                assert_eq!(grid.get_merged_range(row, 1), Some((row, 0, row, 1)));
            } else {
                region_subtotal_rows += 1;
                assert_eq!(grid.get_merged_range(row, 0), None);
                assert_eq!(grid.get_merged_range(row, 1), None);
            }
        }

        assert!(
            merged_subtotal_rows > 0,
            "expected Q subtotal and grand-total merges"
        );
        assert!(
            region_subtotal_rows > 0,
            "expected region subtotal rows to remain unmerged"
        );
    }

    #[test]
    fn hierarchy_demo_hides_row_indicator() {
        let mut grid = VolvoxGrid::new(1, 960, 540, 1, 1, 0, 0);
        setup_hierarchy_demo(&mut grid);

        assert_eq!(grid.fixed_rows, 0);
        assert_eq!(grid.columns[0].caption, "Name");
        assert_eq!(grid.columns[4].caption, "Permissions");
        assert_eq!(grid.columns[5].caption, "Action");
        assert_eq!(
            grid.columns[5].interaction,
            pb::CellInteraction::TextLink as i32
        );
        assert!(grid.indicator_bands.col_top.visible);
        assert!(!grid.indicator_bands.row_start.visible);
        assert_eq!(grid.indicator_bands.col_top.row_count(), 1);
        assert_eq!(grid.cells.get_text(0, 0), "Documents");
        assert_ne!(grid.cells.get_text(0, 0), "Name");
        assert_eq!(grid.cells.get_text(0, 5), "Browse");
        assert_eq!(grid.cells.get_text(2, 5), "Open");
        assert_eq!(grid.get_cell_style(0, 5).font_underline, None);
    }

    #[test]
    fn create_stress_grid_uses_zero_based_rows_with_indicator_headers() {
        let mut grid = create_stress_grid(1, 0, 0, 8, 3);

        assert_eq!(grid.fixed_rows, 0);
        assert_eq!(grid.fixed_cols, 0);
        assert_eq!(grid.columns[0].caption, "Text");
        assert_eq!(grid.columns[10].caption, "Code");
        assert_eq!(
            grid.columns[5].data_type,
            pb::ColumnDataType::ColumnDataBoolean as i32
        );
        assert!(grid.indicator_bands.col_top.visible);
        assert!(grid.indicator_bands.row_start.visible);
        assert_eq!(grid.cells.get_text(0, 0), stress_cell_text(0, 0));
        assert_eq!(grid.cells.get_text(2, 0), stress_cell_text(2, 0));
        assert_eq!(
            grid.cells.get(2, 5).map(|cell| cell.checked()),
            Some(stress_checkbox_state(2))
        );
        assert_eq!(grid.cells.get_text(3, 0), "");

        stress_materialize_row(&mut grid, 3);
        assert_eq!(grid.cells.get_text(3, 0), stress_cell_text(3, 0));
        assert_eq!(
            grid.cells.get(3, 5).map(|cell| cell.checked()),
            Some(stress_checkbox_state(3))
        );
    }

    #[test]
    fn create_stress_grid_expands_row_indicator_for_large_row_counts() {
        let grid = create_stress_grid(1, 0, 0, STRESS_DATA_ROWS, 0);

        assert_eq!(
            grid.indicator_bands.row_start.width_px,
            stress_row_indicator_width_px(
                &mut VolvoxGrid::new(1, 0, 0, 1, 1, 0, 0),
                STRESS_DATA_ROWS
            )
        );
        assert!(grid.indicator_bands.row_start.width_px > 40);
    }

    #[test]
    fn demos_apply_theme_palettes_and_scrollbar_styles() {
        let mut sales = VolvoxGrid::new(1, 960, 540, 1, 1, 0, 0);
        setup_sales_demo(&mut sales);
        assert_eq!(sales.style.back_color_fixed, SALES_THEME.fixed_bg);
        assert_eq!(
            sales.indicator_bands.col_top.back_color,
            Some(SALES_THEME.header_bg)
        );
        assert_eq!(
            sales.indicator_bands.row_start.back_color,
            Some(SALES_THEME.indicator_bg)
        );
        assert_eq!(
            sales.selection.active_cell_style.back_color,
            Some(0x22000000)
        );
        assert_eq!(
            sales.selection.active_cell_style.border_color,
            Some(SALES_THEME.accent)
        );
        assert_eq!(
            sales.scrollbar_appearance,
            pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32
        );

        let mut hierarchy = VolvoxGrid::new(2, 960, 540, 1, 1, 0, 0);
        setup_hierarchy_demo(&mut hierarchy);
        assert_eq!(hierarchy.style.back_color_fixed, HIERARCHY_THEME.fixed_bg);
        assert_eq!(
            hierarchy.indicator_bands.col_top.back_color,
            Some(HIERARCHY_THEME.header_bg)
        );
        assert_eq!(
            hierarchy.scrollbar_appearance,
            pb::ScrollBarAppearance::ScrollbarAppearanceModern as i32
        );

        let mut stress = VolvoxGrid::new(3, 960, 540, 1, 1, 0, 0);
        setup_stress_grid(&mut stress, 128, 2048);
        assert_eq!(stress.style.back_color_fixed, STRESS_THEME.fixed_bg);
        assert_eq!(
            stress.indicator_bands.col_top.back_color,
            Some(STRESS_THEME.header_bg)
        );
        assert_eq!(
            stress.indicator_bands.row_start.back_color,
            Some(STRESS_THEME.indicator_bg)
        );
        assert_eq!(
            stress.scrollbar_appearance,
            pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32
        );
        assert_eq!(
            stress.scrollbar_show_h,
            pb::ScrollBarMode::ScrollbarModeAuto as i32
        );
        assert_eq!(
            stress.scrollbar_show_v,
            pb::ScrollBarMode::ScrollbarModeAlways as i32
        );
    }

    #[test]
    fn stress_demo_row_indicator_avoids_double_scaling_on_high_dpi() {
        let mut grid = VolvoxGrid::new(1, 0, 0, 1, 1, 0, 0);
        let data_rows = STRESS_DATA_ROWS;
        grid.scale = 3.0;
        grid.style.font_size = 42.0;

        let label = data_rows.max(1).to_string();
        let font_name = grid.style.font_name.clone();
        let font_size = grid.style.font_size;
        let measured_text_px = {
            let te = grid.ensure_text_engine();
            if te.has_fonts() {
                te.measure_text(&label, &font_name, font_size, false, false, None)
                    .0
                    .ceil() as i32
            } else {
                (label.chars().count() as f32 * font_size * 0.6).ceil() as i32
            }
        };
        let expected_logical_width =
            (logical_px(&grid, measured_text_px) + 8).max(DEFAULT_ROW_INDICATOR_WIDTH);

        setup_stress_grid(&mut grid, data_rows, 12);

        assert_eq!(
            grid.indicator_bands.row_start.width_px,
            sp(&grid, expected_logical_width)
        );
    }

    #[test]
    fn stress_demo_text_column_fits_samples_without_legacy_overwidth() {
        let mut grid = VolvoxGrid::new(1, 0, 0, 1, 1, 0, 0);
        grid.scale = 3.0;
        grid.style.font_size = 42.0;

        let font_name = grid.style.font_name.clone();
        let font_size = grid.style.font_size;
        let samples: Vec<&str> = STRESS_TEXT_POOL
            .iter()
            .copied()
            .chain(std::iter::once(STRESS_HEADERS[0]))
            .collect();
        let measured_text_px = {
            let te = grid.ensure_text_engine();
            if te.has_fonts() {
                samples
                    .iter()
                    .map(|text| {
                        te.measure_text(text, &font_name, font_size, false, false, None)
                            .0
                            .ceil() as i32
                    })
                    .max()
                    .unwrap_or(0)
            } else {
                samples
                    .iter()
                    .map(|text| (text.chars().count() as f32 * font_size * 0.6).ceil() as i32)
                    .max()
                    .unwrap_or(0)
            }
        };
        let expected_width = (measured_text_px + sp(&grid, STRESS_TEXT_COL_PADDING_PX))
            .max(sp(&grid, STRESS_COL_WIDTHS[0]));

        setup_stress_grid(&mut grid, STRESS_DATA_ROWS, 12);

        assert_eq!(grid.col_width(0), expected_width);
        assert!(grid.col_width(0) < sp(&grid, 110));
    }
}
