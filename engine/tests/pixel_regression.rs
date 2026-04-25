#![cfg(feature = "demo")]

use std::env;
use std::fs;
use std::path::PathBuf;

use volvoxgrid_engine::cell::CellValueData;
use volvoxgrid_engine::grid::VolvoxGrid;
use volvoxgrid_engine::indicator::DEFAULT_ROW_INDICATOR_WIDTH;
use volvoxgrid_engine::load::load_data;
use volvoxgrid_engine::outline::{subtotal, subtotal_ex};
use volvoxgrid_engine::proto::volvoxgrid::v1 as pb;
use volvoxgrid_engine::render::Renderer;
use volvoxgrid_engine::scrollbar::{
    ScrollBarColors, DEFAULT_SCROLLBAR_FADE_DELAY_MS, DEFAULT_SCROLLBAR_FADE_DURATION_MS,
    DEFAULT_SCROLLBAR_MARGIN, DEFAULT_SCROLLBAR_MIN_THUMB,
};
use volvoxgrid_engine::selection::{HOVER_CELL, HOVER_COLUMN, HOVER_ROW};
use volvoxgrid_engine::sort::{sort_grid_all, SORT_ASCENDING_AUTO, SORT_DESCENDING_AUTO};
use volvoxgrid_engine::style::HighlightStyle;
use volvoxgrid_engine::text::TextRenderer;

const VIEWPORT_WIDTH: i32 = 960;
const VIEWPORT_HEIGHT: i32 = 540;
const REGENERATE_ENV: &str = "VOLVOXGRID_REGENERATE_GOLDENS";

const SALES_KEYS: [&str; 10] = [
    "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin", "Flag", "Status", "Notes",
];
const SALES_HEADERS: [&str; 10] = [
    "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin%", "Flag", "Status", "Notes",
];
const SALES_COL_WIDTHS: [i32; 10] = [40, 80, 100, 120, 90, 90, 70, 56, 80, 140];

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("engine crate should live under the repo root")
        .to_path_buf()
}

fn sales_json_path() -> PathBuf {
    repo_root().join("testdata").join("sales.json")
}

fn golden_path(name: &str) -> PathBuf {
    repo_root().join("testdata").join("golden").join(name)
}

fn sp(grid: &VolvoxGrid, px: i32) -> i32 {
    if grid.scale <= 1.001 {
        px
    } else {
        (px as f32 * grid.scale).round() as i32
    }
}

fn scale_px(scale: f32, px: i32) -> i32 {
    if scale <= 1.001 {
        px
    } else {
        (px as f32 * scale).round() as i32
    }
}

fn normalize_scrollbar_appearance(appearance: i32) -> i32 {
    match appearance {
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32 => a,
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceFlat as i32 => a,
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceModern as i32 => a,
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32 => a,
        _ => pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32,
    }
}

fn default_scrollbar_size(appearance: i32) -> i32 {
    match normalize_scrollbar_appearance(appearance) {
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceModern as i32 => 8,
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32 => 6,
        _ => 16,
    }
}

fn default_scrollbar_corner_radius(appearance: i32) -> i32 {
    match normalize_scrollbar_appearance(appearance) {
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceModern as i32 => 4,
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32 => 4,
        _ => 0,
    }
}

fn default_scrollbar_colors(appearance: i32) -> ScrollBarColors {
    match normalize_scrollbar_appearance(appearance) {
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceFlat as i32 => ScrollBarColors {
            thumb: 0xFFB8B8B8,
            thumb_hover: 0xFFC7C7C7,
            thumb_active: 0xFF999999,
            track: 0xFFE3E3E3,
            arrow: 0xFF202020,
            border: 0xFF6C6C6C,
        },
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceModern as i32 => ScrollBarColors {
            thumb: 0xFF7A7A7A,
            thumb_hover: 0xFF666666,
            thumb_active: 0xFF505050,
            track: 0xFFE5E5E5,
            arrow: 0x00000000,
            border: 0xFFB8B8B8,
        },
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32 => ScrollBarColors {
            thumb: 0xAA4E4E4E,
            thumb_hover: 0xCC404040,
            thumb_active: 0xEE303030,
            track: 0x22000000,
            arrow: 0x00000000,
            border: 0x44000000,
        },
        _ => ScrollBarColors {
            thumb: 0xFFC0C0C0,
            thumb_hover: 0xFFD0D0D0,
            thumb_active: 0xFFA8A8A8,
            track: 0xFFD8D8D8,
            arrow: 0xFF000000,
            border: 0xFF606060,
        },
    }
}

fn reset_scrollbar_fade_state(grid: &mut VolvoxGrid) {
    grid.scrollbar_hover = false;
    grid.scrollbar_fade_opacity = 1.0;
    grid.scrollbar_fade_timer = if normalize_scrollbar_appearance(grid.scrollbar_appearance)
        == pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32
    {
        (grid.scrollbar_fade_delay_ms.max(0) as f32) / 1000.0
    } else {
        0.0
    };
    grid.scrollbar_fade_last_tick = None;
}

fn sales_demo_column_defs(scale: f32) -> Vec<pb::ColumnDef> {
    let mut defs = Vec::with_capacity(SALES_HEADERS.len());
    for (index, (&key, &caption)) in SALES_KEYS.iter().zip(SALES_HEADERS.iter()).enumerate() {
        let mut def = pb::ColumnDef {
            index: index as i32,
            width: Some(scale_px(scale, SALES_COL_WIDTHS[index])),
            caption: Some(caption.to_string()),
            key: Some(key.to_string()),
            span: Some(matches!(index, 0 | 1)),
            ..Default::default()
        };
        match index {
            0 => def.align = Some(pb::Align::CenterCenter as i32),
            4 | 5 => {
                def.align = Some(pb::Align::RightCenter as i32);
                def.data_type = Some(pb::ColumnDataType::ColumnDataCurrency as i32);
                def.format = Some("$#,##0".to_string());
            }
            6 => {
                def.align = Some(pb::Align::CenterCenter as i32);
                def.data_type = Some(pb::ColumnDataType::ColumnDataNumber as i32);
            }
            7 => {
                def.align = Some(pb::Align::CenterCenter as i32);
                def.data_type = Some(pb::ColumnDataType::ColumnDataBoolean as i32);
            }
            8 => {
                def.dropdown_items = Some("Active|Pending|Shipped|Returned|Cancelled".to_string());
            }
            _ => {}
        }
        defs.push(def);
    }
    defs
}

fn apply_sales_demo_chrome(grid: &mut VolvoxGrid) {
    if grid.cols < SALES_HEADERS.len() as i32 {
        grid.set_cols(SALES_HEADERS.len() as i32);
    }

    grid.style.back_color = 0xFFFFFFFF;
    grid.style.fore_color = 0xFF111827;
    grid.style.back_color_fixed = 0xFFF3F4F6;
    grid.style.fore_color_fixed = 0xFF374151;
    grid.style.back_color_frozen = 0xFFFFFFFF;
    grid.style.fore_color_frozen = 0xFF111827;
    grid.style.back_color_bkg = 0xFFFAFAFB;
    grid.style.back_color_alternate = 0xFFF9FAFB;
    grid.style.grid_lines = pb::GridLineStyle::GridlineSolid as i32;
    grid.style.grid_lines_fixed = pb::GridLineStyle::GridlineSolid as i32;
    grid.style.grid_color = 0xFFE5E7EB;
    grid.style.grid_color_fixed = 0xFFD1D5DB;
    grid.style.sheet_border = 0xFFD1D5DB;
    grid.style.progress_color = 0xFF818CF8;
    grid.style.tree_color = 0xFF9CA3AF;
    grid.style.header_separator.enabled = true;
    grid.style.header_separator.color = 0xFFD1D5DB;
    grid.style.header_separator.width_px = 1;
    grid.style.header_resize_handle.enabled = true;
    grid.style.header_resize_handle.color = 0xFFD1D5DB;
    grid.style.header_resize_handle.width_px = 1;
    grid.style.header_resize_handle.hit_width_px = 6;

    grid.selection.selection_style = HighlightStyle {
        back_color: Some(0xFF6366F1),
        fore_color: Some(0xFFFFFFFF),
        fill_handle: Some(pb::FillHandlePosition::FillHandleNone as i32),
        fill_handle_color: Some(0xFF818CF8),
        ..HighlightStyle::default()
    };
    grid.selection.active_cell_style = HighlightStyle {
        back_color: Some(0x22000000),
        fore_color: Some(0xFFFFFFFF),
        border: Some(pb::BorderStyle::BorderThick as i32),
        border_color: Some(0xFF818CF8),
        ..HighlightStyle::default()
    };

    grid.scrollbar_show_h = pb::ScrollBarMode::ScrollbarModeAuto as i32;
    grid.scrollbar_show_v = pb::ScrollBarMode::ScrollbarModeAuto as i32;
    grid.scrollbar_appearance = pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32;
    grid.scrollbar_size = default_scrollbar_size(grid.scrollbar_appearance);
    grid.scrollbar_min_thumb = DEFAULT_SCROLLBAR_MIN_THUMB;
    grid.scrollbar_corner_radius = default_scrollbar_corner_radius(grid.scrollbar_appearance);
    grid.scrollbar_colors = default_scrollbar_colors(grid.scrollbar_appearance);
    grid.scrollbar_fade_delay_ms = DEFAULT_SCROLLBAR_FADE_DELAY_MS;
    grid.scrollbar_fade_duration_ms = DEFAULT_SCROLLBAR_FADE_DURATION_MS;
    grid.scrollbar_margin = DEFAULT_SCROLLBAR_MARGIN;
    reset_scrollbar_fade_state(grid);

    grid.default_row_height = sp(grid, volvoxgrid_engine::grid::DEFAULT_ROW_HEIGHT);

    for (col, &header) in SALES_HEADERS.iter().enumerate() {
        if let Some(cp) = grid.columns.get_mut(col) {
            cp.caption = header.to_string();
        }
    }
    grid.indicator_bands.col_top.visible = true;
    grid.indicator_bands.col_top.band_rows = 1;
    grid.indicator_bands.col_top.default_row_height_px = sp(grid, 28);
    grid.indicator_bands.col_top.mode_bits = (pb::ColIndicatorCellMode::ColIndicatorCellHeaderText
        as u32)
        | (pb::ColIndicatorCellMode::ColIndicatorCellSortGlyph as u32);
    grid.indicator_bands.col_top.back_color = Some(0xFFF9FAFB);
    grid.indicator_bands.col_top.fore_color = Some(0xFF111827);
    grid.indicator_bands.col_top.grid_color = Some(0xFFD1D5DB);
    grid.indicator_bands.col_top.allow_resize = true;
    grid.indicator_bands.corner_top_start.visible = false;
    grid.indicator_bands.corner_top_start.mode_bits = 0;
    grid.indicator_bands.corner_top_start.custom_key.clear();
    grid.indicator_bands.corner_top_start.data.clear();

    grid.indicator_bands.row_start.visible = true;
    grid.indicator_bands.row_start.width_px = sp(grid, 40.max(DEFAULT_ROW_INDICATOR_WIDTH));
    grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;
    grid.indicator_bands.row_start.back_color = Some(0xFFF9FAFB);
    grid.indicator_bands.row_start.fore_color = Some(0xFF6B7280);
    grid.indicator_bands.row_start.grid_color = Some(0xFFD1D5DB);
    grid.indicator_bands.row_start.allow_resize = true;

    for (index, width) in SALES_COL_WIDTHS.iter().copied().enumerate() {
        grid.set_col_width(index as i32, sp(grid, width));
    }
    for (index, key) in SALES_KEYS.iter().enumerate() {
        if let Some(column) = grid.columns.get_mut(index) {
            column.key = (*key).to_string();
        }
    }

    grid.columns[6].progress_color = 0xFF818CF8;
    grid.allow_user_resizing = 3;
    grid.tab_behavior = 1;
    grid.edit_trigger_mode = 0;
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
        border_color: Some(0xFF818CF8),
        ..HighlightStyle::default()
    };
}

fn parse_sales_bool_text(raw: &str) -> Option<bool> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "true" | "1" | "yes" | "y" | "on" => Some(true),
        "false" | "0" | "no" | "n" | "off" => Some(false),
        _ => None,
    }
}

fn set_sales_flag_cell(grid: &mut VolvoxGrid, row: i32, flagged: bool) {
    grid.cells
        .set_text(row, 7, if flagged { "Yes" } else { "No" }.to_string());
    let cell = grid.cells.get_mut(row, 7);
    let extra = cell.extra_mut();
    extra.value = CellValueData::Bool(flagged);
    extra.checked = if flagged {
        pb::CheckedState::CheckedChecked as i32
    } else {
        pb::CheckedState::CheckedUnchecked as i32
    };
}

fn sales_flag_value(grid: &VolvoxGrid, row: i32) -> bool {
    grid.cells
        .get(row, 7)
        .and_then(|cell| {
            cell.extra.as_ref().and_then(|extra| match &extra.value {
                CellValueData::Bool(value) => Some(*value),
                _ => None,
            })
        })
        .or_else(|| parse_sales_bool_text(grid.cells.get_text(row, 7)))
        .unwrap_or(false)
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

fn apply_sales_demo_subtotals(grid: &mut VolvoxGrid) {
    for row in grid.fixed_rows..grid.rows {
        let flagged = sales_flag_value(grid, row);
        set_sales_flag_cell(grid, row, flagged);
    }

    grid.outline.group_total_position = 1;
    grid.outline.multi_totals = true;
    subtotal(grid, 1, 0, 0, "", 0, 0, false);

    subtotal(grid, 2, -1, 4, "Grand Total", 0xFFEEF2FF, 0xFF111827, true);
    subtotal_ex(
        grid, 2, 0, 4, "", 0xFFF5F3FF, 0xFF111827, true, "", false, 1, false,
    );
    subtotal_ex(
        grid, 2, 1, 4, "", 0xFFF8F7FF, 0xFF111827, true, "", false, 1, false,
    );

    subtotal(grid, 2, -1, 5, "Grand Total", 0xFFEEF2FF, 0xFF111827, true);
    subtotal_ex(
        grid, 2, 0, 5, "", 0xFFF5F3FF, 0xFF111827, true, "", false, 1, false,
    );
    subtotal_ex(
        grid, 2, 1, 5, "", 0xFFF8F7FF, 0xFF111827, true, "", false, 1, false,
    );

    let parse_i64 = |text: &str| -> i64 { text.parse::<i64>().unwrap_or(0) };
    for row in grid.fixed_rows..grid.rows {
        let Some(props) = grid.row_props.get(&row) else {
            continue;
        };
        if !props.is_subtotal {
            continue;
        }

        let cell = grid.cells.get_mut(row, 7);
        let extra = cell.extra_mut();
        extra.value = CellValueData::Bool(false);
        extra.checked = pb::CheckedState::CheckedGrayed as i32;

        let sales_sum = parse_i64(grid.cells.get_text(row, 4));
        let cost_sum = parse_i64(grid.cells.get_text(row, 5));
        let margin = if sales_sum > 0 {
            ((sales_sum - cost_sum) as f64 / sales_sum as f64) * 100.0
        } else {
            0.0
        };
        grid.cells.set_text(row, 6, format!("{margin:.1}"));
    }

    grid.span.mode = pb::CellSpanMode::CellSpanByRow as i32;
    grid.span.mode_fixed = 0;
    grid.span.span_cols.clear();
    grid.span.span_cols.insert(0, true);
    grid.span.span_cols.insert(1, true);
    grid.span.span_compare = pb::SpanCompareMode::SpanCompareNoCase as i32;
    apply_sales_subtotal_merges(grid);

    grid.outline.tree_indicator = 0;
    grid.outline.group_total_position = 1;
    grid.layout.invalidate();
    grid.mark_dirty();
}

struct SolidTextRenderer;

impl TextRenderer for SolidTextRenderer {
    fn measure_text(
        &mut self,
        text: &str,
        _font_name: &str,
        _font_size: f32,
        _bold: bool,
        _italic: bool,
        _max_width: Option<f32>,
    ) -> (f32, f32) {
        ((text.len().max(1) as f32) * 6.0, 8.0)
    }

    fn render_text(
        &mut self,
        buffer_pixels: &mut [u8],
        buf_width: i32,
        buf_height: i32,
        stride: i32,
        x: i32,
        y: i32,
        clip_x: i32,
        clip_y: i32,
        clip_w: i32,
        clip_h: i32,
        text: &str,
        _font_name: &str,
        _font_size: f32,
        _bold: bool,
        _italic: bool,
        color: u32,
        _max_width: Option<f32>,
    ) -> f32 {
        let draw_w = (text.len().max(1) as i32) * 6;
        let draw_h = 8;
        let x0 = x.max(clip_x).max(0);
        let y0 = y.max(clip_y).max(0);
        let x1 = (x + draw_w).min(clip_x + clip_w).min(buf_width);
        let y1 = (y + draw_h).min(clip_y + clip_h).min(buf_height);
        if x1 <= x0 || y1 <= y0 {
            return draw_w as f32;
        }

        let r = ((color >> 16) & 0xFF) as u8;
        let g = ((color >> 8) & 0xFF) as u8;
        let b = (color & 0xFF) as u8;
        let a = ((color >> 24) & 0xFF) as u8;
        for py in y0..y1 {
            for px in x0..x1 {
                let off = (py * stride + px * 4) as usize;
                buffer_pixels[off] = r;
                buffer_pixels[off + 1] = g;
                buffer_pixels[off + 2] = b;
                buffer_pixels[off + 3] = a;
            }
        }
        draw_w as f32
    }
}

fn build_sales_grid() -> VolvoxGrid {
    let mut grid = VolvoxGrid::new(1, VIEWPORT_WIDTH, VIEWPORT_HEIGHT, 1, 1, 0, 0);
    let data = fs::read(sales_json_path()).expect("sales fixture should exist");
    let result = load_data(&mut grid, &data, None);
    assert_eq!(result.status, pb::LoadDataStatus::LoadOk as i32);
    assert_eq!(result.rows, 1000);
    assert_eq!(result.cols, 10);
    grid.define_columns(&sales_demo_column_defs(grid.scale));
    apply_sales_demo_chrome(&mut grid);
    grid
}

fn render_png(grid: &VolvoxGrid) -> Vec<u8> {
    let mut renderer = Renderer::with_custom_text_renderer(Box::new(SolidTextRenderer));
    let mut buffer = vec![0u8; (VIEWPORT_WIDTH * VIEWPORT_HEIGHT * 4) as usize];
    renderer.render(
        grid,
        &mut buffer,
        VIEWPORT_WIDTH,
        VIEWPORT_HEIGHT,
        VIEWPORT_WIDTH * 4,
    );
    volvoxgrid_engine::print::encode_rgba_png(
        &buffer,
        VIEWPORT_WIDTH as u32,
        VIEWPORT_HEIGHT as u32,
    )
}

fn assert_matches_golden(name: &str, png: &[u8]) {
    let path = golden_path(name);
    if env::var_os(REGENERATE_ENV).is_some() {
        fs::create_dir_all(
            path.parent()
                .expect("golden file should have a parent directory"),
        )
        .expect("should create golden directory");
        fs::write(&path, png).expect("should rewrite golden image");
    }

    let expected = fs::read(&path)
        .unwrap_or_else(|err| panic!("failed to read golden {}: {err}", path.display()));
    if expected != png {
        let actual_path = env::temp_dir().join(name.replace(".png", ".actual.png"));
        fs::write(&actual_path, png).expect("should write failed regression artifact");
        panic!(
            "pixel regression mismatch for {} (actual written to {})",
            path.display(),
            actual_path.display()
        );
    }
}

#[test]
fn sales_default_view_matches_golden() {
    let mut grid = build_sales_grid();
    apply_sales_demo_subtotals(&mut grid);
    let png = render_png(&grid);
    assert_matches_golden("sales_default.png", &png);
}

#[test]
fn sales_sort_q_ascending_matches_golden() {
    let mut grid = build_sales_grid();
    sort_grid_all(&mut grid, SORT_ASCENDING_AUTO, 0);
    let png = render_png(&grid);
    assert_matches_golden("sales_sort_q_asc.png", &png);
}

#[test]
fn sales_sort_sales_descending_matches_golden() {
    let mut grid = build_sales_grid();
    sort_grid_all(&mut grid, SORT_DESCENDING_AUTO, 4);
    let png = render_png(&grid);
    assert_matches_golden("sales_sort_sales_desc.png", &png);
}

#[test]
fn sales_scroll_row_500_matches_golden() {
    let mut grid = build_sales_grid();
    apply_sales_demo_subtotals(&mut grid);
    grid.set_top_row(500);
    let png = render_png(&grid);
    assert_matches_golden("sales_scroll_row_500.png", &png);
}
