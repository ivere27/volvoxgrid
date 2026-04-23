//! Shared demo support for VolvoxGrid host examples.
//!
//! This module is feature-gated behind `demo` and not included in
//! production builds. It keeps shared demo helpers, stress-demo setup,
//! and embedded fixture access for `GetDemoData`.

use crate::grid::VolvoxGrid;
use crate::indicator::DEFAULT_ROW_INDICATOR_WIDTH;
use crate::proto::volvoxgrid::v1 as pb;
use crate::scrollbar::{
    default_scrollbar_colors, default_scrollbar_corner_radius, default_scrollbar_size,
    reset_scrollbar_fade_state, DEFAULT_SCROLLBAR_FADE_DELAY_MS,
    DEFAULT_SCROLLBAR_FADE_DURATION_MS, DEFAULT_SCROLLBAR_MARGIN, DEFAULT_SCROLLBAR_MIN_THUMB,
};
use crate::selection::HOVER_ROW;
use crate::style::HighlightStyle;
use flate2::read::GzDecoder;
use std::io::Read;
use std::sync::OnceLock;

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

const EMBEDDED_SALES_JSON_GZ: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/sales.json.gz"));
const EMBEDDED_HIERARCHY_JSON_GZ: &[u8] =
    include_bytes!(concat!(env!("OUT_DIR"), "/hierarchy.json.gz"));
const EMBEDDED_BARCODES_JSON_GZ: &[u8] =
    include_bytes!(concat!(env!("OUT_DIR"), "/barcodes.json.gz"));

static EMBEDDED_SALES_JSON_BYTES: OnceLock<Vec<u8>> = OnceLock::new();
static EMBEDDED_HIERARCHY_JSON_BYTES: OnceLock<Vec<u8>> = OnceLock::new();
static EMBEDDED_BARCODES_JSON_BYTES: OnceLock<Vec<u8>> = OnceLock::new();

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

fn reset_grid(grid: &mut VolvoxGrid) {
    // Clear all data
    grid.cells.clear_all();
    grid.clear_barcode_presence_tracking();
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

fn inflate_embedded_demo_bytes(compressed: &[u8]) -> Vec<u8> {
    let mut decoder = GzDecoder::new(compressed);
    let mut bytes = Vec::new();
    decoder
        .read_to_end(&mut bytes)
        .expect("embedded demo fixture should decompress");
    bytes
}

pub fn embedded_demo_data_bytes(demo: &str) -> Result<&'static [u8], String> {
    match demo {
        "sales" => Ok(EMBEDDED_SALES_JSON_BYTES
            .get_or_init(|| inflate_embedded_demo_bytes(EMBEDDED_SALES_JSON_GZ))
            .as_slice()),
        "hierarchy" => Ok(EMBEDDED_HIERARCHY_JSON_BYTES
            .get_or_init(|| inflate_embedded_demo_bytes(EMBEDDED_HIERARCHY_JSON_GZ))
            .as_slice()),
        "barcodes" => Ok(EMBEDDED_BARCODES_JSON_BYTES
            .get_or_init(|| inflate_embedded_demo_bytes(EMBEDDED_BARCODES_JSON_GZ))
            .as_slice()),
        "stress" => Err("embedded demo data is not available for procedural demo: stress".into()),
        other => Err(format!("unknown demo: {other}")),
    }
}

pub fn get_demo_data_response(demo: &str) -> Result<pb::GetDemoDataResponse, String> {
    let data = embedded_demo_data_bytes(demo)?;
    Ok(pb::GetDemoDataResponse {
        demo: demo.to_string(),
        format: pb::DemoDataFormat::Json as i32,
        data: data.to_vec(),
    })
}

pub fn setup_named_demo(grid: &mut VolvoxGrid, demo: &str) -> Result<(), String> {
    match demo {
        "stress" => {
            setup_stress_demo(grid);
            Ok(())
        }
        other => Err(format!("unknown demo: {other}")),
    }
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

/// Alias: materialize a stress test row.
pub fn materialize_row(grid: &mut VolvoxGrid, row: i32) {
    stress_materialize_row(grid, row);
}

/// Alias: materialize visible rows for stress test.
pub fn materialize_visible_rows(grid: &mut VolvoxGrid, padding: i32) {
    stress_materialize_visible_rows(grid, padding);
}

#[cfg(test)]
fn demo_fixture_path(name: &str) -> std::path::PathBuf {
    std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("engine crate should live under the repo root")
        .join("testdata")
        .join(name)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

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
    fn stress_demo_applies_theme_palette_and_scrollbar_style() {
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

    #[test]
    fn embedded_demo_data_matches_json_fixtures() {
        let sales_path = super::demo_fixture_path("sales.json");
        let hierarchy_path = super::demo_fixture_path("hierarchy.json");
        let barcodes_path = super::demo_fixture_path("barcodes.json");
        let sales_expected = fs::read(&sales_path).expect("sales fixture should exist");
        let hierarchy_expected = fs::read(&hierarchy_path).expect("hierarchy fixture should exist");
        let barcodes_expected = fs::read(&barcodes_path).expect("barcodes fixture should exist");

        assert_eq!(
            embedded_demo_data_bytes("sales").expect("sales embedded data should exist"),
            sales_expected.as_slice()
        );
        assert_eq!(
            embedded_demo_data_bytes("hierarchy").expect("hierarchy embedded data should exist"),
            hierarchy_expected.as_slice()
        );
        assert_eq!(
            embedded_demo_data_bytes("barcodes").expect("barcodes embedded data should exist"),
            barcodes_expected.as_slice()
        );
    }
}
