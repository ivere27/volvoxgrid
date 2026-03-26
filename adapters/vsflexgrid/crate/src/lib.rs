// VolvoxGrid ActiveX Staticlib Crate
//
// This crate compiles as a static library (.a) that exports all extern "C"
// symbols defined in the generated volvoxgrid_ffi_native.rs. It is designed
// to be linked into the VolvoxGrid.ocx ActiveX control.

use std::time::{Duration, Instant};
use volvoxgrid_engine::cell::CellValueData;
use volvoxgrid_engine::proto::volvoxgrid::v1::*;
use volvoxgrid_engine::GridManager;

// Generated native C API — extern "C" functions + plugin trait.
#[path = "volvoxgrid_ffi_native.rs"]
mod ffi_native;
use ffi_native::*;

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------

lazy_static::lazy_static! {
    static ref GRID_MANAGER: GridManager = GridManager::new();
}

// Match classic LegacyGrid's baseline footprint more closely in ActiveX mode.
const ACTIVEX_DEFAULT_ROW_HEIGHT: i32 = 19;
const ACTIVEX_DEFAULT_COL_WIDTH: i32 = 76;

// ---------------------------------------------------------------------------
// Helpers (ported from plugin/src/lib.rs, without streaming/zoom/events)
// ---------------------------------------------------------------------------

fn proto_value_to_engine(cv: &Option<CellValue>) -> CellValueData {
    match cv {
        Some(cv) => match &cv.value {
            Some(cell_value::Value::Text(t)) => CellValueData::Text(t.clone()),
            Some(cell_value::Value::Number(n)) => CellValueData::Number(*n),
            Some(cell_value::Value::Flag(b)) => CellValueData::Bool(*b),
            Some(cell_value::Value::Raw(d)) => CellValueData::Bytes(d.clone()),
            Some(cell_value::Value::Timestamp(ts)) => CellValueData::Timestamp(*ts),
            None => CellValueData::Empty,
        },
        None => CellValueData::Empty,
    }
}

fn engine_value_to_proto(v: &CellValueData) -> CellValue {
    match v {
        CellValueData::Text(t) => CellValue {
            value: Some(cell_value::Value::Text(t.clone())),
        },
        CellValueData::Number(n) => CellValue {
            value: Some(cell_value::Value::Number(*n)),
        },
        CellValueData::Bool(b) => CellValue {
            value: Some(cell_value::Value::Flag(*b)),
        },
        CellValueData::Bytes(d) => CellValue {
            value: Some(cell_value::Value::Raw(d.clone())),
        },
        CellValueData::Timestamp(ts) => CellValue {
            value: Some(cell_value::Value::Timestamp(*ts)),
        },
        CellValueData::Empty => CellValue { value: None },
    }
}

fn ensure_layout(grid: &mut volvoxgrid_engine::grid::VolvoxGrid) {
    grid.ensure_layout();
}

fn apply_default_indicator_bands(grid: &mut volvoxgrid_engine::grid::VolvoxGrid) {
    grid.indicator_bands.row_start.visible = false;
    grid.indicator_bands.row_start.width_px =
        volvoxgrid_engine::indicator::DEFAULT_ROW_INDICATOR_WIDTH;
    grid.indicator_bands.row_start.mode_bits = (RowIndicatorMode::RowIndicatorCurrent as u32)
        | (RowIndicatorMode::RowIndicatorSelection as u32);

    grid.indicator_bands.col_top.visible = true;
    if grid.indicator_bands.col_top.band_rows <= 0 {
        grid.indicator_bands.col_top.band_rows = 1;
    }
    if grid.indicator_bands.col_top.default_row_height_px <= 0 {
        grid.indicator_bands.col_top.default_row_height_px =
            volvoxgrid_engine::indicator::DEFAULT_COL_INDICATOR_ROW_HEIGHT;
    }
    grid.indicator_bands.col_top.mode_bits = (ColIndicatorCellMode::ColIndicatorCellHeaderText
        as u32)
        | (ColIndicatorCellMode::ColIndicatorCellSortGlyph as u32);
    grid.layout.invalidate();
    grid.mark_dirty();
}

fn apply_array_data_to_grid(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    rows: i32,
    cols: i32,
    values: &[String],
) {
    let rows = rows.max(1);
    let cols = cols.max(1);
    grid.set_rows(rows);
    grid.set_cols(cols);
    grid.cells.clear_all();
    let max = (rows as usize).saturating_mul(cols as usize);
    for (idx, value) in values.iter().take(max).enumerate() {
        let idx = idx as i32;
        let row = idx / cols;
        let col = idx % cols;
        grid.cells.set_text(row, col, value.clone());
    }
    grid.mark_dirty();
}

fn apply_picture_type_to_rgba(buf: &mut [u8], picture_type: i32) {
    if picture_type != 1 {
        return;
    }
    for px in buf.chunks_exact_mut(4) {
        let r = px[0] as u16;
        let g = px[1] as u16;
        let b = px[2] as u16;
        let y = ((r * 77 + g * 150 + b * 29) >> 8) as u8;
        let bw = if y >= 128 { 255 } else { 0 };
        px[0] = bw;
        px[1] = bw;
        px[2] = bw;
    }
}

fn expand_sort_request_columns(
    grid: &volvoxgrid_engine::grid::VolvoxGrid,
    sort_columns: &[SortColumn],
) -> Vec<(i32, i32)> {
    let mut sort_keys = Vec::new();

    for sc in sort_columns {
        let merged = volvoxgrid_engine::sort::merge_sort_spec(
            volvoxgrid_engine::sort::SORT_NONE,
            sc.order,
            sc.r#type,
        );
        if merged == volvoxgrid_engine::sort::SORT_NONE {
            continue;
        }
        if sc.col >= 0 && sc.col < grid.cols {
            sort_keys.push((sc.col, merged));
            continue;
        }

        let lo = grid.selection.col.min(grid.selection.col_end).max(0);
        let hi = grid
            .selection
            .col
            .max(grid.selection.col_end)
            .min(grid.cols - 1);
        if lo > hi {
            continue;
        }

        for col in lo..=hi {
            sort_keys.push((col, merged));
        }
    }

    sort_keys
}

fn capture_grid_picture(grid: &mut volvoxgrid_engine::grid::VolvoxGrid) -> ImageData {
    ensure_layout(grid);
    let width = grid.viewport_width.max(1);
    let height = grid.viewport_height.max(1);
    let stride = width * 4;
    let mut buffer = vec![0u8; (stride * height) as usize];
    let mut renderer = volvoxgrid_engine::render::Renderer::new();
    renderer.render(grid, &mut buffer, width, height, stride);
    apply_picture_type_to_rgba(&mut buffer, grid.picture_type);
    let data = volvoxgrid_engine::print::encode_rgba_png(&buffer, width as u32, height as u32);
    ImageData {
        data,
        format: "png".to_string(),
    }
}

fn selection_range_tuples(grid: &volvoxgrid_engine::grid::VolvoxGrid) -> Vec<(i32, i32, i32, i32)> {
    grid.selection.all_ranges(grid.rows, grid.cols)
}

fn selection_ranges_proto(grid: &volvoxgrid_engine::grid::VolvoxGrid) -> Vec<CellRange> {
    selection_range_tuples(grid)
        .into_iter()
        .map(|(row1, col1, row2, col2)| CellRange {
            row1,
            col1,
            row2,
            col2,
        })
        .collect()
}

#[cfg(any())]
fn proto_style_to_engine(s: &GridStyle) -> volvoxgrid_engine::style::GridStyleState {
    volvoxgrid_engine::style::GridStyleState {
        appearance: s.appearance,
        back_color: s.back_color,
        fore_color: s.fore_color,
        back_color_fixed: s.back_color_fixed,
        fore_color_fixed: s.fore_color_fixed,
        back_color_frozen: s.back_color_frozen,
        fore_color_frozen: s.fore_color_frozen,
        back_color_sel: s.back_color_sel,
        fore_color_sel: s.fore_color_sel,
        back_color_bkg: s.back_color_bkg,
        back_color_alternate: s.back_color_alternate,
        grid_lines: s.grid_lines,
        grid_lines_fixed: s.grid_lines_fixed,
        grid_color: s.grid_color,
        grid_color_fixed: s.grid_color_fixed,
        grid_line_width: s.grid_line_width,
        text_style: s.text_effect,
        text_style_fixed: s.text_style_fixed,
        font_name: s.font_name.clone(),
        font_size: s.font_size,
        font_bold: s.font_bold,
        font_italic: s.font_italic,
        font_underline: s.font_underline,
        font_strikethrough: s.font_strikethrough,
        font_width: s.font_width,
        sheet_border: s.sheet_border,
        flood_color: s.progress_color,
        pictures_over: s.pictures_over,
        wallpaper: s.wallpaper.clone(),
        wallpaper_alignment: s.wallpaper_alignment,
        text_render_mode: s.text_render_mode,
        text_hinting_mode: s.text_hinting_mode,
        text_pixel_snap: s.text_pixel_snap,
        tree_color: 0xFF808080,
    }
}

#[cfg(any())]
fn engine_style_to_proto(s: &volvoxgrid_engine::style::GridStyleState) -> GridStyle {
    GridStyle {
        appearance: s.appearance,
        back_color: s.back_color,
        fore_color: s.fore_color,
        back_color_fixed: s.back_color_fixed,
        fore_color_fixed: s.fore_color_fixed,
        back_color_frozen: s.back_color_frozen,
        fore_color_frozen: s.fore_color_frozen,
        back_color_sel: s.back_color_sel,
        fore_color_sel: s.fore_color_sel,
        back_color_bkg: s.back_color_bkg,
        back_color_alternate: s.back_color_alternate,
        grid_lines: s.grid_lines,
        grid_lines_fixed: s.grid_lines_fixed,
        grid_color: s.grid_color,
        grid_color_fixed: s.grid_color_fixed,
        grid_line_width: s.grid_line_width,
        text_style: s.text_effect,
        text_style_fixed: s.text_style_fixed,
        font_name: s.font_name.clone(),
        font_size: s.font_size,
        font_bold: s.font_bold,
        font_italic: s.font_italic,
        font_underline: s.font_underline,
        font_strikethrough: s.font_strikethrough,
        font_width: s.font_width,
        sheet_border: s.sheet_border,
        flood_color: s.progress_color,
        pictures_over: s.pictures_over,
        wallpaper: s.wallpaper.clone(),
        wallpaper_alignment: s.wallpaper_alignment,
        text_render_mode: s.text_render_mode,
        text_hinting_mode: s.text_hinting_mode,
        text_pixel_snap: s.text_pixel_snap,
    }
}

#[cfg(any())]
fn proto_cell_style_to_override(cs: &CellStyle) -> CellStylePatch {
    CellStylePatch {
        back_color: if cs.back_color != 0 {
            Some(cs.back_color)
        } else {
            None
        },
        fore_color: if cs.fore_color != 0 {
            Some(cs.fore_color)
        } else {
            None
        },
        alignment: Some(cs.alignment),
        text_style: Some(cs.text_effect),
        font_name: if cs.font_name.is_empty() {
            None
        } else {
            Some(cs.font_name.clone())
        },
        font_size: if cs.font_size > 0.0 {
            Some(cs.font_size)
        } else {
            None
        },
        font_bold: Some(cs.font_bold),
        font_italic: Some(cs.font_italic),
        font_underline: Some(cs.font_underline),
        font_strikethrough: Some(cs.font_strikethrough),
        font_width: if cs.font_width > 0.0 {
            Some(cs.font_width)
        } else {
            None
        },
        border: Some(cs.border),
        border_color: None,
    }
}

#[cfg(any())]
fn engine_override_to_proto(so: &CellStylePatch) -> CellStyle {
    CellStyle {
        back_color: so.back_color.unwrap_or(0),
        fore_color: so.fore_color.unwrap_or(0),
        alignment: so.alignment.unwrap_or(0),
        text_style: so.text_effect.unwrap_or(0),
        font_name: so.font_name.clone().unwrap_or_default(),
        font_size: so.font_size.unwrap_or(0.0),
        font_bold: so.font_bold.unwrap_or(false),
        font_italic: so.font_italic.unwrap_or(false),
        font_underline: so.font_underline.unwrap_or(false),
        font_strikethrough: so.font_strikethrough.unwrap_or(false),
        font_width: so.font_width.unwrap_or(0.0),
        flood_color: 0,
        flood_percent: 0.0,
        border: so.border.unwrap_or(0),
    }
}

fn set_cell_property(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row1: i32,
    col1: i32,
    row2: i32,
    col2: i32,
    prop: i32,
    value: &Option<CellValue>,
) {
    let r_lo = row1.min(row2).max(0);
    let r_hi = row1.max(row2).min(grid.rows - 1);
    let c_lo = col1.min(col2).max(0);
    let c_hi = col1.max(col2).min(grid.cols - 1);
    for r in r_lo..=r_hi {
        for c in c_lo..=c_hi {
            match prop {
                0 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Text(t)) = &cv.value {
                            grid.cells.set_text(r, c, t.clone());
                        }
                    }
                }
                1 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Number(n)) = &cv.value {
                            grid.cell_styles.entry((r, c)).or_default().text_effect =
                                Some(*n as i32);
                        }
                    }
                }
                2 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Number(n)) = &cv.value {
                            grid.cell_styles.entry((r, c)).or_default().alignment = Some(*n as i32);
                        }
                    }
                }
                3 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Raw(d)) = &cv.value {
                            grid.cells.get_mut(r, c).extra_mut().picture = Some(d.clone());
                        }
                    }
                }
                4 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Number(n)) = &cv.value {
                            grid.cells.get_mut(r, c).extra_mut().picture_alignment = *n as i32;
                        }
                    }
                }
                5 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Number(n)) = &cv.value {
                            grid.cells.get_mut(r, c).extra_mut().checked = *n as i32;
                        }
                    }
                }
                6 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Number(n)) = &cv.value {
                            grid.cell_styles.entry((r, c)).or_default().back_color =
                                Some(*n as u32);
                        }
                    }
                }
                7 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Number(n)) = &cv.value {
                            grid.cell_styles.entry((r, c)).or_default().fore_color =
                                Some(*n as u32);
                        }
                    }
                }
                8 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Number(n)) = &cv.value {
                            grid.cells.get_mut(r, c).extra_mut().progress_color = *n as u32;
                        }
                    }
                }
                9 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Number(n)) = &cv.value {
                            grid.cells.get_mut(r, c).extra_mut().progress_percent = *n as f32;
                        }
                    }
                }
                10 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Text(t)) = &cv.value {
                            grid.cell_styles.entry((r, c)).or_default().font_name = Some(t.clone());
                        }
                    }
                }
                11 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Number(n)) = &cv.value {
                            grid.cell_styles.entry((r, c)).or_default().font_size = Some(*n as f32);
                        }
                    }
                }
                12 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Flag(b)) = &cv.value {
                            grid.cell_styles.entry((r, c)).or_default().font_bold = Some(*b);
                        }
                    }
                }
                13 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Flag(b)) = &cv.value {
                            grid.cell_styles.entry((r, c)).or_default().font_italic = Some(*b);
                        }
                    }
                }
                14 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Flag(b)) = &cv.value {
                            grid.cell_styles.entry((r, c)).or_default().font_underline = Some(*b);
                        }
                    }
                }
                15 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Flag(b)) = &cv.value {
                            grid.cell_styles
                                .entry((r, c))
                                .or_default()
                                .font_strikethrough = Some(*b);
                        }
                    }
                }
                16 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Number(n)) = &cv.value {
                            grid.cell_styles.entry((r, c)).or_default().font_width =
                                Some(*n as f32);
                        }
                    }
                }
                17 => {
                    let ev = proto_value_to_engine(value);
                    grid.cells.set_value(r, c, ev);
                }
                18 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Raw(d)) = &cv.value {
                            grid.cells.get_mut(r, c).extra_mut().user_data = Some(d.clone());
                        }
                    }
                }
                19 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Text(t)) = &cv.value {
                            grid.cells.get_mut(r, c).extra_mut().custom_format = t.clone();
                        }
                    }
                }
                24 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Raw(d)) = &cv.value {
                            grid.cells.get_mut(r, c).extra_mut().button_picture = Some(d.clone());
                        }
                    }
                }
                25 => {
                    if let Some(cv) = value {
                        if let Some(cell_value::Value::Text(t)) = &cv.value {
                            grid.cells.get_mut(r, c).extra_mut().dropdown_items = t.clone();
                        }
                    }
                }
                _ => {}
            }
        }
    }
    grid.mark_dirty();
}

fn get_cell_property(
    grid: &volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    prop: i32,
) -> CellValue {
    match prop {
        0 => CellValue {
            value: Some(cell_value::Value::Text(
                grid.cells.get_text(row, col).to_string(),
            )),
        },
        1 => {
            let so = grid.get_cell_style(row, col);
            CellValue {
                value: Some(cell_value::Value::Number(so.text_effect.unwrap_or(0) as f64)),
            }
        }
        2 => {
            let so = grid.get_cell_style(row, col);
            CellValue {
                value: Some(cell_value::Value::Number(so.alignment.unwrap_or(9) as f64)),
            }
        }
        3 => {
            let data = grid
                .cells
                .get(row, col)
                .and_then(|c| c.picture().map(|d| d.to_vec()))
                .unwrap_or_default();
            CellValue {
                value: Some(cell_value::Value::Raw(data)),
            }
        }
        4 => {
            let pa = grid
                .cells
                .get(row, col)
                .map_or(0, |c| c.picture_alignment());
            CellValue {
                value: Some(cell_value::Value::Number(pa as f64)),
            }
        }
        5 => {
            let checked = grid.cells.get(row, col).map_or(0, |c| c.checked());
            CellValue {
                value: Some(cell_value::Value::Number(checked as f64)),
            }
        }
        6 => {
            let so = grid.get_cell_style(row, col);
            CellValue {
                value: Some(cell_value::Value::Number(so.back_color.unwrap_or(0) as f64)),
            }
        }
        7 => {
            let so = grid.get_cell_style(row, col);
            CellValue {
                value: Some(cell_value::Value::Number(so.fore_color.unwrap_or(0) as f64)),
            }
        }
        8 => {
            let fc = grid.cells.get(row, col).map_or(0, |c| c.progress_color());
            CellValue {
                value: Some(cell_value::Value::Number(fc as f64)),
            }
        }
        9 => {
            let fp = grid
                .cells
                .get(row, col)
                .map_or(0.0, |c| c.progress_percent());
            CellValue {
                value: Some(cell_value::Value::Number(fp as f64)),
            }
        }
        10 => {
            let so = grid.get_cell_style(row, col);
            CellValue {
                value: Some(cell_value::Value::Text(so.font_name.unwrap_or_default())),
            }
        }
        11 => {
            let so = grid.get_cell_style(row, col);
            CellValue {
                value: Some(cell_value::Value::Number(so.font_size.unwrap_or(0.0) as f64)),
            }
        }
        12 => {
            let so = grid.get_cell_style(row, col);
            CellValue {
                value: Some(cell_value::Value::Flag(so.font_bold.unwrap_or(false))),
            }
        }
        13 => {
            let so = grid.get_cell_style(row, col);
            CellValue {
                value: Some(cell_value::Value::Flag(so.font_italic.unwrap_or(false))),
            }
        }
        14 => {
            let so = grid.get_cell_style(row, col);
            CellValue {
                value: Some(cell_value::Value::Flag(so.font_underline.unwrap_or(false))),
            }
        }
        15 => {
            let so = grid.get_cell_style(row, col);
            CellValue {
                value: Some(cell_value::Value::Flag(
                    so.font_strikethrough.unwrap_or(false),
                )),
            }
        }
        16 => {
            let so = grid.get_cell_style(row, col);
            CellValue {
                value: Some(cell_value::Value::Number(
                    so.font_width.unwrap_or(0.0) as f64
                )),
            }
        }
        17 => engine_value_to_proto(grid.cells.get_value(row, col)),
        18 => {
            let data = grid
                .cells
                .get(row, col)
                .and_then(|c| c.extra.as_ref().and_then(|e| e.user_data.clone()))
                .unwrap_or_default();
            CellValue {
                value: Some(cell_value::Value::Raw(data)),
            }
        }
        19 => {
            let cf = grid
                .cells
                .get(row, col)
                .map_or(String::new(), |c| c.custom_format().to_string());
            CellValue {
                value: Some(cell_value::Value::Text(cf)),
            }
        }
        20 => CellValue {
            value: Some(cell_value::Value::Number(grid.col_pos(col) as f64)),
        },
        21 => CellValue {
            value: Some(cell_value::Value::Number(grid.row_pos(row) as f64)),
        },
        22 => CellValue {
            value: Some(cell_value::Value::Number(grid.get_col_width(col) as f64)),
        },
        23 => CellValue {
            value: Some(cell_value::Value::Number(grid.get_row_height(row) as f64)),
        },
        24 => {
            let data = grid
                .cells
                .get(row, col)
                .and_then(|c| c.extra.as_ref().and_then(|e| e.button_picture.clone()))
                .unwrap_or_default();
            CellValue {
                value: Some(cell_value::Value::Raw(data)),
            }
        }
        25 => {
            let cl = grid
                .cells
                .get(row, col)
                .map_or(String::new(), |c| c.dropdown_items().to_string());
            CellValue {
                value: Some(cell_value::Value::Text(cl)),
            }
        }
        _ => CellValue { value: None },
    }
}

fn truncate_to_char_count(s: &str, max_chars: i32) -> String {
    if max_chars <= 0 {
        return s.to_string();
    }
    let max = max_chars as usize;
    s.chars().take(max).collect()
}

fn begin_edit_session(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    force: bool,
) {
    if !grid.can_begin_edit(row, col, force) {
        return;
    }
    let combo_list = grid.active_dropdown_list(row, col);
    grid.events
        .push(volvoxgrid_engine::event::GridEventData::BeforeEdit { row, col });
    if combo_list.trim() == "..." {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::CellButtonClick { row, col });
        grid.mark_dirty();
        return;
    }
    let stored_text = grid.cells.get_text(row, col).to_string();
    let display_text = grid.get_display_text(row, col);
    grid.edit.start_edit(row, col, &display_text);
    grid.edit.parse_dropdown_items(&combo_list);
    if !combo_list.is_empty() {
        for i in 0..grid.edit.dropdown_count() {
            if (!stored_text.is_empty() && grid.edit.get_dropdown_data(i) == stored_text)
                || grid.edit.get_dropdown_item(i) == display_text
            {
                grid.edit.set_dropdown_index(i);
                break;
            }
        }
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::DropdownOpened);
    }
    grid.events
        .push(volvoxgrid_engine::event::GridEventData::StartEdit { row, col });
    grid.mark_dirty();
}

fn normalize_committed_edit_text(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    new_text: &str,
) -> String {
    let mut committed = truncate_to_char_count(new_text, grid.edit_max_length);
    let cell_combo = grid
        .cells
        .get(row, col)
        .map(|c| c.dropdown_items().to_string())
        .unwrap_or_default();
    if cell_combo.is_empty() && col >= 0 && (col as usize) < grid.columns.len() {
        let col_list = &grid.columns[col as usize].dropdown_items;
        if !col_list.is_empty() {
            if let Some(mapped) =
                volvoxgrid_engine::edit::translate_dropdown_display_to_value(col_list, &committed)
            {
                committed = mapped;
            }
        }
    }
    committed
}

fn apply_committed_edit_text(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    old_text: String,
    committed: String,
) {
    grid.cells.set_text(row, col, committed.clone());
    grid.events
        .push(volvoxgrid_engine::event::GridEventData::AfterEdit {
            row,
            col,
            old_text,
            new_text: committed,
        });
}

// ---------------------------------------------------------------------------
// Plugin implementation
// ---------------------------------------------------------------------------

struct ActiveXPlugin;

#[cfg(any())]
impl VolvoxGridServicePlugin for ActiveXPlugin {
    fn create_grid(&self, r: CreateGridRequest) -> Result<GridHandle, String> {
        let id = GRID_MANAGER.create_grid(
            r.viewport_width,
            r.viewport_height,
            r.rows,
            r.cols,
            r.fixed_rows,
            r.fixed_cols,
            r.scale,
        );
        // Set Windows-specific defaults for the ActiveX control
        GRID_MANAGER
            .with_grid(id, |g| {
                g.style.font_name = "MS Sans Serif".to_string();
                g.style.font_size = 10.0 * 96.0 / 72.0; // 10pt at 96 DPI ≈ 13.3px
                g.style.back_color_bkg = 0xFF808080; // gray (AppWorkspace)
                g.style.back_color_fixed = 0xFFD4D0C8; // ButtonFace RGB(212,208,200)
                g.default_row_height = ACTIVEX_DEFAULT_ROW_HEIGHT;
                g.default_col_width = ACTIVEX_DEFAULT_COL_WIDTH;
                g.indicator_bands.col_top.default_row_height_px = ACTIVEX_DEFAULT_ROW_HEIGHT;
                g.selection.selection_visibility = 1; // HighlightAlways — default
                g.has_focus = true; // OCX control always considered focused for rendering
            })
            .ok();
        Ok(GridHandle { id })
    }
    fn destroy_grid(&self, r: GridHandle) -> Result<Empty, String> {
        RENDERERS.with(|rc| {
            rc.borrow_mut().remove(&r.id);
        });
        GRID_MANAGER.destroy_grid(r.id);
        Ok(Empty {})
    }
    fn set_rows(&self, r: SetRowsRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.set_rows(r.rows);
        })?;
        Ok(Empty {})
    }
    fn set_cols(&self, r: SetColsRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.set_cols(r.cols);
        })?;
        Ok(Empty {})
    }
    fn get_rows(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.rows)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_cols(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.cols)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_fixed_rows(&self, r: SetFixedRowsRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let old_fixed_rows = g.fixed_rows;
            let new_fixed_rows = r.fixed_rows.max(0).min(g.rows);
            g.fixed_rows = new_fixed_rows;
            if new_fixed_rows == 0 && !g.indicator_bands.col_top.visible {
                apply_default_indicator_bands(g);
            }
            g.selection.remap_collapsed_cursor_after_fixed_change(
                g.rows,
                g.cols,
                old_fixed_rows,
                g.fixed_cols,
                new_fixed_rows,
                g.fixed_cols,
            );
            g.layout.invalidate();
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_fixed_cols(&self, r: SetFixedColsRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let old_fixed_cols = g.fixed_cols;
            let new_fixed_cols = r.fixed_cols.max(0).min(g.cols);
            g.fixed_cols = new_fixed_cols;
            g.selection.remap_collapsed_cursor_after_fixed_change(
                g.rows,
                g.cols,
                g.fixed_rows,
                old_fixed_cols,
                g.fixed_rows,
                new_fixed_cols,
            );
            g.layout.invalidate();
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_frozen_rows(&self, r: SetFrozenRowsRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.frozen_rows = r.frozen_rows.max(0).min(g.rows - g.fixed_rows);
            g.layout.invalidate();
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_frozen_cols(&self, r: SetFrozenColsRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.frozen_cols = r.frozen_cols.max(0).min(g.cols - g.fixed_cols);
            g.layout.invalidate();
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_row_height(&self, r: SetRowHeightRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.set_row_height(r.row, r.height);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_col_width(&self, r: SetColWidthRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.set_col_width(r.col, r.width);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_row_height(&self, r: RowColIndex) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| g.get_row_height(r.index))?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn get_col_width(&self, r: RowColIndex) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| g.get_col_width(r.index))?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_row_height_min(&self, r: SetInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.row_height_min = r.value)?;
        Ok(Empty {})
    }
    fn set_row_height_max(&self, r: SetInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.row_height_max = r.value)?;
        Ok(Empty {})
    }
    fn set_col_width_min(&self, r: SetColInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.col_width_min.insert(r.col, r.value);
            }
        })?;
        Ok(Empty {})
    }
    fn set_col_width_max(&self, r: SetColInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.col_width_max.insert(r.col, r.value);
            }
        })?;
        Ok(Empty {})
    }
    fn set_row_hidden(&self, r: SetRowHiddenRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.hidden {
                g.rows_hidden.insert(r.row);
            } else {
                g.rows_hidden.remove(&r.row);
            }
            g.layout.invalidate();
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_col_hidden(&self, r: SetColHiddenRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.hidden {
                g.cols_hidden.insert(r.col);
            } else {
                g.cols_hidden.remove(&r.col);
            }
            g.layout.invalidate();
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_row_is_visible(&self, r: RowColIndex) -> Result<BoolValue, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| g.is_row_visible(r.index))?;
        Ok(BoolValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn get_col_is_visible(&self, r: RowColIndex) -> Result<BoolValue, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| g.is_col_visible(r.index))?;
        Ok(BoolValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_col_position(&self, r: MoveColRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let col = r.col;
            let pos = r.position;
            if col >= 0 && col < g.cols && pos >= 0 && pos < g.cols && col != pos {
                let insert_at = if pos > col { pos - 1 } else { pos };
                g.move_col_by_positions(col, insert_at);
            }
        })?;
        Ok(Empty {})
    }
    fn set_row_position(&self, r: MoveRowRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let row = r.row;
            let pos = r.position;
            if row >= 0 && row < g.rows && pos >= 0 && pos < g.rows && row != pos {
                let moving = g.row_positions.remove(row as usize);
                let insert_at = if pos > row { pos - 1 } else { pos };
                g.row_positions.insert(insert_at as usize, moving);
                g.layout.invalidate();
                g.mark_dirty();
            }
        })?;
        Ok(Empty {})
    }
    fn auto_size(&self, r: AutoSizeRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.ensure_text_engine();
            let mode = g.auto_size_mode;
            if mode == 0 || mode == 1 {
                let c_from = r.col_from.max(0);
                let c_to = r.col_to.min(g.cols - 1);
                if c_from <= c_to {
                    let font_name = g.style.font_name.clone();
                    let font_size = g.style.font_size;
                    let font_bold = g.style.font_bold;
                    let font_italic = g.style.font_italic;
                    let rows = g.rows;
                    let mut max_widths: Vec<i32> = vec![0; (c_to - c_from + 1) as usize];
                    for c in c_from..=c_to {
                        for row in 0..rows {
                            let text = g.cells.get_text(row, c);
                            if !text.is_empty() {
                                let te = g.text_engine.as_mut().unwrap();
                                let (tw, _) = te.measure_text(
                                    text,
                                    &font_name,
                                    font_size,
                                    font_bold,
                                    font_italic,
                                    None,
                                );
                                let needed = ((tw.ceil() as i32) + ACTIVEX_AUTOSIZE_TEXT_PAD_PX)
                                    .max(ACTIVEX_AUTOSIZE_MIN_COL_WIDTH_PX);
                                let idx = (c - c_from) as usize;
                                if needed > max_widths[idx] {
                                    max_widths[idx] = needed;
                                }
                            }
                        }
                    }
                    if r.equal {
                        let uniform = *max_widths.iter().max().unwrap_or(&0);
                        for c in c_from..=c_to {
                            let w = if r.max_width > 0 {
                                uniform.min(r.max_width)
                            } else {
                                uniform
                            };
                            g.set_col_width(c, w);
                        }
                    } else {
                        for c in c_from..=c_to {
                            let w = max_widths[(c - c_from) as usize];
                            let w = if r.max_width > 0 {
                                w.min(r.max_width)
                            } else {
                                w
                            };
                            g.set_col_width(c, w);
                        }
                    }
                }
            }
            if mode == 0 || mode == 2 {
                for row in 0..g.rows {
                    g.auto_resize_row(row);
                }
            }
        })?;
        Ok(Empty {})
    }
    fn set_auto_size_mode(&self, r: SetAutoSizeModeRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.auto_size_mode = r.mode)?;
        Ok(Empty {})
    }
    fn set_format_string(&self, r: SetFormatStringRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.format_string = r.format_string.clone();
            g.apply_format_string();
        })?;
        Ok(Empty {})
    }
    fn set_right_to_left(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.right_to_left = r.value;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_extend_last_col(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.extend_last_col = r.value;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_scroll_bars(&self, r: SetScrollBarsRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            match r.mode {
                1 => {
                    g.scrollbar_show_h = ScrollBarMode::ScrollbarModeAuto as i32;
                    g.scrollbar_show_v = ScrollBarMode::ScrollbarModeNever as i32;
                }
                2 => {
                    g.scrollbar_show_h = ScrollBarMode::ScrollbarModeNever as i32;
                    g.scrollbar_show_v = ScrollBarMode::ScrollbarModeAuto as i32;
                }
                3 => {
                    g.scrollbar_show_h = ScrollBarMode::ScrollbarModeAuto as i32;
                    g.scrollbar_show_v = ScrollBarMode::ScrollbarModeAuto as i32;
                }
                _ => {
                    g.scrollbar_show_h = ScrollBarMode::ScrollbarModeNever as i32;
                    g.scrollbar_show_v = ScrollBarMode::ScrollbarModeNever as i32;
                }
            }
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_scroll_track(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.scroll_track = r.value)?;
        Ok(Empty {})
    }
    fn set_fling_enabled(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.fling_enabled = r.value;
            if !r.value {
                g.scroll.stop_fling();
            }
        })?;
        Ok(Empty {})
    }
    fn set_fling_impulse_gain(&self, r: SetFloatProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.value.is_finite() {
                g.fling_impulse_gain = r.value.max(0.0);
            }
        })?;
        Ok(Empty {})
    }
    fn set_fling_friction(&self, r: SetFloatProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.value.is_finite() {
                g.fling_friction = r.value.clamp(0.1, 20.0);
            }
        })?;
        Ok(Empty {})
    }
    fn resize_viewport(&self, r: ResizeViewportRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.resize_viewport(r.width, r.height);
        })?;
        Ok(Empty {})
    }
    fn set_top_row(&self, r: SetRowRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.set_top_row(r.row);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_top_row(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.top_row())?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_left_col(&self, r: SetColRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.set_left_col(r.col);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_left_col(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.left_col())?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_bottom_row(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| {
            ensure_layout(g);
            g.bottom_row()
        })?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_right_col(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| {
            ensure_layout(g);
            g.right_col()
        })?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_row_pos(&self, r: RowColIndex) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            ensure_layout(g);
            g.row_pos(r.index)
        })?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn get_col_pos(&self, r: RowColIndex) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            ensure_layout(g);
            g.col_pos(r.index)
        })?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_row(&self, r: SetRowRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.selection.set_cursor(
                r.row,
                g.selection.col,
                g.rows,
                g.cols,
                g.fixed_rows,
                g.fixed_cols,
            );
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_col(&self, r: SetColRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.selection.set_cursor(
                g.selection.row,
                r.col,
                g.rows,
                g.cols,
                g.fixed_rows,
                g.fixed_cols,
            );
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_row(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.selection.row)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_col(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.selection.col)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_row_sel(&self, r: SetRowSelRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.selection.row_end = r.row_sel.clamp(g.fixed_rows, g.rows - 1);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_col_sel(&self, r: SetColSelRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.selection.col_end = r.col_sel.clamp(g.fixed_cols, g.cols - 1);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn select(&self, r: SelectRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.selection
                .select(r.row1, r.col1, r.row2, r.col2, g.rows, g.cols);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_selection(&self, r: GridHandle) -> Result<SelectionRange, String> {
        GRID_MANAGER.with_grid(r.id, |g| SelectionRange {
            grid_id: r.id,
            row1: g.selection.row,
            col1: g.selection.col,
            row2: g.selection.row_end,
            col2: g.selection.col_end,
        })
    }
    fn show_cell(&self, r: ShowCellRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let ph = g.pinned_top_height() + g.pinned_bottom_height();
            let pw = g.pinned_left_width() + g.pinned_right_width();
            g.scroll.show_cell(
                r.row,
                r.col,
                &g.layout,
                g.viewport_width,
                g.viewport_height,
                g.fixed_rows,
                g.fixed_cols,
                ph,
                pw,
            );
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_allow_selection(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.allow_selection = r.value;
            g.selection.allow_selection = r.value;
        })?;
        Ok(Empty {})
    }
    fn set_allow_big_selection(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.header_click_select = r.value;
            g.selection.header_click_select = r.value;
        })?;
        Ok(Empty {})
    }
    fn set_selection_mode(&self, r: SetSelectionModeRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.selection.mode = r.mode;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_focus_rect(&self, r: SetFocusRectRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.selection.focus_border = r.style;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_high_light(&self, r: SetHighLightRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.selection.selection_visibility = r.style;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_is_selected(&self, r: RowColIndex) -> Result<BoolValue, String> {
        let v =
            GRID_MANAGER.with_grid(r.grid_id, |g| g.is_cell_selected(r.index, g.selection.col))?;
        Ok(BoolValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn get_selected_row(&self, r: RowColIndex) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            if g.selection.is_selected(r.index, g.fixed_cols, g.cols) {
                1
            } else {
                0
            }
        })?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn get_selected_rows(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.selection.selected_row_count())?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_mouse_row(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.mouse_row)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_mouse_col(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.mouse_col)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_text(&self, r: SetTextRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let row = g.selection.row;
            let col = g.selection.col;
            g.cells.set_text(row, col, r.text.clone());
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_text(&self, r: GetTextRequest) -> Result<StringValue, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            let row = g.selection.row;
            let col = g.selection.col;
            g.cells.get_text(row, col).to_string()
        })?;
        Ok(StringValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_text_matrix(&self, r: SetTextMatrixRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.cells.set_text(r.row, r.col, r.text.clone());
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_text_matrix(&self, r: GetTextMatrixRequest) -> Result<StringValue, String> {
        let v =
            GRID_MANAGER.with_grid(r.grid_id, |g| g.cells.get_text(r.row, r.col).to_string())?;
        Ok(StringValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_text_array(&self, r: SetTextArrayRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.set_text_array(r.index, r.text.clone());
        })?;
        Ok(Empty {})
    }
    fn get_text_array(&self, r: GetTextArrayRequest) -> Result<StringValue, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| g.get_text_array(r.index))?;
        Ok(StringValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn load_array(&self, r: ArrayDataRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            apply_array_data_to_grid(g, r.rows, r.cols, &r.values)
        })?;
        Ok(Empty {})
    }
    fn bind_to_array(&self, r: ArrayDataRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            apply_array_data_to_grid(g, r.rows, r.cols, &r.values)
        })?;
        Ok(Empty {})
    }
    fn set_value(&self, r: SetValueRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let row = g.selection.row;
            let col = g.selection.col;
            let ev = proto_value_to_engine(&r.value);
            match &ev {
                CellValueData::Text(t) => g.cells.set_text(row, col, t.clone()),
                CellValueData::Number(n) => g.cells.set_text(row, col, n.to_string()),
                CellValueData::Bool(b) => g.cells.set_text(row, col, b.to_string()),
                _ => {}
            }
            g.cells.set_value(row, col, ev);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_value(&self, r: GetValueRequest) -> Result<CellValue, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let row = g.selection.row;
            let col = g.selection.col;
            engine_value_to_proto(g.cells.get_value(row, col))
        })
    }
    fn set_value_matrix(&self, r: SetValueMatrixRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let ev = proto_value_to_engine(&r.value);
            g.cells.set_value(r.row, r.col, ev);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_value_matrix(&self, r: GetValueMatrixRequest) -> Result<CellValue, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            engine_value_to_proto(g.cells.get_value(r.row, r.col))
        })
    }
    fn set_cells(&self, r: SetCellsRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            for entry in &r.cells {
                let ev = proto_value_to_engine(&entry.value);
                match &ev {
                    CellValueData::Text(t) => g.cells.set_text(entry.row, entry.col, t.clone()),
                    CellValueData::Number(n) => {
                        g.cells.set_text(entry.row, entry.col, n.to_string())
                    }
                    CellValueData::Bool(b) => g.cells.set_text(entry.row, entry.col, b.to_string()),
                    _ => {}
                }
                g.cells.set_value(entry.row, entry.col, ev);
            }
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_cells(&self, r: GetCellsRequest) -> Result<CellsData, String> {
        let cells = GRID_MANAGER.with_grid(r.grid_id, |g| {
            let mut entries = Vec::new();
            let r_lo = r.row1.min(r.row2).max(0);
            let r_hi = r.row1.max(r.row2).min(g.rows - 1);
            let c_lo = r.col1.min(r.col2).max(0);
            let c_hi = r.col1.max(r.col2).min(g.cols - 1);
            for row in r_lo..=r_hi {
                for col in c_lo..=c_hi {
                    let v = engine_value_to_proto(g.cells.get_value(row, col));
                    entries.push(CellEntry {
                        row,
                        col,
                        value: Some(v),
                    });
                }
            }
            entries
        })?;
        Ok(CellsData { cells })
    }
    fn set_cell(&self, r: SetCellRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            set_cell_property(g, r.row1, r.col1, r.row2, r.col2, r.prop, &r.value);
        })?;
        Ok(Empty {})
    }
    fn get_cell(&self, r: GetCellRequest) -> Result<CellValue, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| get_cell_property(g, r.row, r.col, r.prop))
    }
    fn set_clip(&self, r: SetClipRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::clipboard::paste(g, &r.clip);
        })?;
        Ok(Empty {})
    }
    fn get_clip(&self, r: GetClipRequest) -> Result<StringValue, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            let (text, _) = volvoxgrid_engine::clipboard::copy(g);
            text
        })?;
        Ok(StringValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_clip_separators(&self, r: SetClipSeparatorsRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.clip_col_separator = r.col_separator.clone();
            g.clip_row_separator = r.row_separator.clone();
        })?;
        Ok(Empty {})
    }
    fn set_fill_style(&self, r: SetFillStyleRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.apply_scope = r.style)?;
        Ok(Empty {})
    }
    fn add_item(&self, r: AddItemRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let insert_at = if r.index < 0 || r.index >= g.rows {
                g.rows
            } else {
                r.index
            };
            let h = g.get_row_height(insert_at.min(g.rows.saturating_sub(1)).max(0));
            g.animation.notify_rows_inserted(insert_at, 1, h);
            g.cells.insert_row(insert_at);
            g.rows += 1;
            g.row_positions.insert(insert_at as usize, insert_at);
            for (c, val) in r.item.split('\t').enumerate() {
                if (c as i32) < g.cols {
                    g.cells.set_text(insert_at, c as i32, val.to_string());
                }
            }
            g.layout.invalidate();
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn remove_item(&self, r: RemoveItemRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.index >= g.fixed_rows && r.index < g.rows {
                let h = g.get_row_height(r.index);
                g.animation.notify_rows_removed(r.index, 1, h);
                g.cells.remove_row(r.index);
                g.rows -= 1;
                g.row_positions = (0..g.rows).collect();
                g.selection
                    .clamp(g.rows, g.cols, g.fixed_rows, g.fixed_cols);
                g.layout.invalidate();
                g.mark_dirty();
            }
        })?;
        Ok(Empty {})
    }
    fn clear(&self, r: ClearRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let (r1, c1, r2, c2) = match r.region {
                0 => (g.fixed_rows, g.fixed_cols, g.rows - 1, g.cols - 1),
                1 => (0, 0, g.fixed_rows - 1, g.cols - 1),
                2 => (0, 0, g.rows - 1, g.fixed_cols - 1),
                3 => (0, 0, g.fixed_rows - 1, g.fixed_cols - 1),
                4 | 5 | 6 => (0, 0, g.rows - 1, g.cols - 1),
                _ => (g.fixed_rows, g.fixed_cols, g.rows - 1, g.cols - 1),
            };
            match r.scope {
                0 => {
                    g.cells.clear_range(r1, c1, r2, c2);
                    for row in r1..=r2 {
                        for col in c1..=c2 {
                            g.cell_styles.remove(&(row, col));
                        }
                    }
                }
                1 => {
                    for row in r1..=r2 {
                        for col in c1..=c2 {
                            g.cell_styles.remove(&(row, col));
                        }
                    }
                }
                2 => {
                    g.cells.clear_range(r1, c1, r2, c2);
                }
                3 => {
                    g.selection.row_end = g.selection.row;
                    g.selection.col_end = g.selection.col;
                    g.selection.selected_rows.clear();
                }
                _ => {}
            }
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn find_row(&self, r: FindRowRequest) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::search::find_row(
                g,
                &r.text,
                r.start_row,
                r.col,
                r.case_sense,
                r.full_match,
            )
        })?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn find_row_regex(&self, r: FindRowRegexRequest) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::search::find_row_regex(g, &r.pattern, r.start_row, r.col)
        })?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn aggregate(&self, r: AggregateRequest) -> Result<DoubleValue, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::search::aggregate(g, r.aggregate, r.row1, r.col1, r.row2, r.col2)
        })?;
        Ok(DoubleValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_editable(&self, r: SetEditableRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.edit_trigger_mode = r.mode)?;
        Ok(Empty {})
    }
    fn edit_cell(&self, r: EditCellRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            begin_edit_session(g, r.row, r.col, true);
        })?;
        Ok(Empty {})
    }
    fn finish_editing(&self, r: GridHandle) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.id, |g| {
            if let Some((row, col, old_text, new_text)) = g.edit.commit() {
                let committed = normalize_committed_edit_text(g, row, col, &new_text);
                apply_committed_edit_text(g, row, col, old_text, committed);
            }
        })?;
        Ok(Empty {})
    }
    fn set_edit_mask(&self, r: SetEditMaskRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.edit_mask = r.mask.clone())?;
        Ok(Empty {})
    }
    fn set_col_edit_mask(&self, r: SetColEditMaskRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col == -1 {
                for col in &mut g.columns {
                    col.edit_mask = r.mask.clone();
                }
            } else if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize].edit_mask = r.mask.clone();
            }
        })?;
        Ok(Empty {})
    }
    fn set_col_combo_list(&self, r: SetColComboListRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col == -1 {
                for col in &mut g.columns {
                    col.dropdown_items = r.list.clone();
                }
            } else if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize].dropdown_items = r.list.clone();
            }
        })?;
        Ok(Empty {})
    }
    fn set_combo_list(&self, r: SetComboListRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let row = g.selection.row;
            let col = g.selection.col;
            let cell = g.cells.get_mut(row, col);
            cell.extra_mut().dropdown_items = r.list.clone();
        })?;
        Ok(Empty {})
    }
    fn set_combo_search(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.dropdown_search = r.value)?;
        Ok(Empty {})
    }
    fn set_show_combo_button(&self, r: SetShowComboButtonRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.dropdown_trigger = r.mode)?;
        Ok(Empty {})
    }
    fn build_combo_list(&self, r: BuildComboListRequest) -> Result<StringValue, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            let col = g.selection.col;
            let mut items = std::collections::BTreeSet::new();
            for row in g.fixed_rows..g.rows {
                let t = g.cells.get_text(row, col);
                if !t.is_empty() {
                    if r.query.is_empty() || t.to_lowercase().contains(&r.query.to_lowercase()) {
                        items.insert(t.to_string());
                    }
                }
            }
            items.into_iter().collect::<Vec<_>>().join("|")
        })?;
        Ok(StringValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_tab_behavior(&self, r: SetTabBehaviorRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.tab_behavior = r.behavior)?;
        Ok(Empty {})
    }
    fn commit_edit(&self, r: CommitEditRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.cancel {
                if let Some((_row, _col)) = g.edit.cancel() {
                    g.mark_dirty();
                }
            } else {
                g.edit.update_text(r.text.clone());
                if let Some((row, col, old_text, new_text)) = g.edit.commit() {
                    let committed = normalize_committed_edit_text(g, row, col, &new_text);
                    apply_committed_edit_text(g, row, col, old_text, committed);
                }
            }
        })?;
        Ok(Empty {})
    }
    fn cancel_edit(&self, r: GridHandle) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.id, |g| {
            g.edit.cancel();
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_edit_text(&self, r: SetStringProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if !g.edit.is_active() {
                return;
            }
            let next = truncate_to_char_count(&r.value, g.edit_max_length);
            if next == g.edit.edit_text {
                return;
            }
            g.edit.edit_text = next.clone();
            g.edit.sel_start = next.chars().count() as i32;
            g.edit.sel_length = 0;
            g.events
                .push(volvoxgrid_engine::event::GridEventData::CellEditChange { text: next });
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_edit_text(&self, r: GridHandle) -> Result<StringValue, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| {
            if g.edit.is_active() {
                g.edit.edit_text.clone()
            } else {
                String::new()
            }
        })?;
        Ok(StringValue {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_edit_max_length(&self, r: SetInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.edit_max_length = r.value)?;
        Ok(Empty {})
    }
    fn get_edit_max_length(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.edit_max_length)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_grid_style(&self, r: SetGridStyleRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if let Some(style) = &r.style {
                g.style = proto_style_to_engine(style);
            }
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_grid_style(&self, r: GridHandle) -> Result<GridStyle, String> {
        GRID_MANAGER.with_grid(r.id, |g| engine_style_to_proto(&g.style))
    }
    fn set_cell_style(&self, r: SetCellStyleRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if let Some(style) = &r.style {
                let row = g.selection.row;
                let col = g.selection.col;
                g.cell_styles
                    .insert((row, col), proto_cell_style_to_override(style));
                g.mark_dirty();
            }
        })?;
        Ok(Empty {})
    }
    fn get_cell_style(&self, r: GetCellStyleRequest) -> Result<CellStyle, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let so = g.get_cell_style(r.row, r.col);
            engine_override_to_proto(&so)
        })
    }
    fn set_cell_style_range(&self, r: SetCellStyleRangeRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if let Some(style) = &r.style {
                let so = proto_cell_style_to_override(style);
                let r_lo = r.row1.min(r.row2).max(0);
                let r_hi = r.row1.max(r.row2).min(g.rows - 1);
                let c_lo = r.col1.min(r.col2).max(0);
                let c_hi = r.col1.max(r.col2).min(g.cols - 1);
                for row in r_lo..=r_hi {
                    for col in c_lo..=c_hi {
                        g.cell_styles.insert((row, col), so.clone());
                    }
                }
                g.mark_dirty();
            }
        })?;
        Ok(Empty {})
    }
    fn set_col_alignment(&self, r: SetColAlignmentRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize].alignment = r.alignment;
                g.mark_dirty();
            }
        })?;
        Ok(Empty {})
    }
    fn set_col_format(&self, r: SetColFormatRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize].format = r.format.clone();
            }
        })?;
        Ok(Empty {})
    }
    fn set_col_data_type(&self, r: SetColDataTypeRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize].data_type = r.data_type;
            }
        })?;
        Ok(Empty {})
    }
    fn set_col_indent(&self, r: SetColIndentRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize].indent = r.indent;
                g.mark_dirty();
            }
        })?;
        Ok(Empty {})
    }
    fn set_col_key(&self, r: SetColKeyRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize].key = r.key.clone();
            }
        })?;
        Ok(Empty {})
    }
    fn set_col_sort(&self, r: SetColSortRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize].sort_order = r.order;
            }
        })?;
        Ok(Empty {})
    }
    fn set_fixed_alignment(&self, r: SetColAlignmentRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize].fixed_alignment = r.alignment;
                g.mark_dirty();
            }
        })?;
        Ok(Empty {})
    }
    fn get_col_index(&self, r: GetColIndexRequest) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.columns
                .iter()
                .position(|cp| cp.key == r.key)
                .map(|i| i as i32)
                .unwrap_or(-1)
        })?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_cell_picture(&self, r: SetCellPictureRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let cell = g.cells.get_mut(r.row, r.col);
            if let Some(img) = &r.image {
                cell.extra_mut().picture = if img.data.is_empty() {
                    None
                } else {
                    Some(img.data.clone())
                };
            } else {
                cell.extra_mut().picture = None;
            }
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_cell_picture(&self, r: GetCellPictureRequest) -> Result<ImageData, String> {
        let data = GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.cells
                .get(r.row, r.col)
                .and_then(|c| c.picture().map(|d| d.to_vec()))
                .unwrap_or_default()
        })?;
        Ok(ImageData {
            data,
            format: "png".to_string(),
        })
    }
    fn set_cell_picture_alignment(
        &self,
        r: SetCellPictureAlignmentRequest,
    ) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.cells.get_mut(r.row, r.col).extra_mut().picture_alignment = r.alignment;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_col_image_list(&self, r: SetColImageListRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize].image_list =
                    r.images.iter().map(|img| img.data.clone()).collect();
                g.mark_dirty();
            }
        })?;
        Ok(Empty {})
    }
    fn set_cell_flood(&self, r: SetCellFloodRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let cell = g.cells.get_mut(r.row, r.col);
            let extra = cell.extra_mut();
            extra.progress_color = r.color;
            extra.progress_percent = r.percent;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_cell_checked(&self, r: SetCellCheckedRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.cells.get_mut(r.row, r.col).extra_mut().checked = r.state;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_cell_checked(&self, r: GetCellCheckedRequest) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.cells.get(r.row, r.col).map_or(0, |c| c.checked())
        })?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_owner_draw(&self, r: SetOwnerDrawRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.custom_render = r.mode;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn cell_border(&self, r: CellBorderRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let row = g.selection.row;
            let col = g.selection.col;
            let so = g.cell_styles.entry((row, col)).or_default();
            so.border = Some(r.style);
            so.border_color = Some(r.color);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn cell_border_range(&self, r: CellBorderRangeRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let r_lo = r.row1.min(r.row2).max(0);
            let r_hi = r.row1.max(r.row2).min(g.rows - 1);
            let c_lo = r.col1.min(r.col2).max(0);
            let c_hi = r.col1.max(r.col2).min(g.cols - 1);
            for row in r_lo..=r_hi {
                for col in c_lo..=c_hi {
                    let so = g.cell_styles.entry((row, col)).or_default();
                    so.border = Some(r.style);
                    so.border_color = Some(r.color);
                }
            }
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_word_wrap(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.word_wrap = r.value;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_ellipsis(&self, r: SetInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.ellipsis_mode = r.value.clamp(0, 2);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn sort(&self, r: SortRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.sort_columns.is_empty() {
                g.sort_state.clear();
                g.layout.invalidate();
                g.mark_dirty();
            } else {
                let sort_keys = expand_sort_request_columns(g, &r.sort_columns);
                if sort_keys.is_empty() {
                    return;
                }
                g.sort_state.sort_keys = sort_keys;
                volvoxgrid_engine::sort::sort_grid_all_multi(g);
            }
        })?;
        Ok(Empty {})
    }
    fn set_explorer_bar(&self, r: SetExplorerBarRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.header_features = r.mode;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_group_compare(&self, r: SetMergeCompareRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.span.span_compare = r.value;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_group_compare(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.span.span_compare)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_sort_ascending_picture(&self, r: SetImageProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.sort_state.sort_ascending_picture = if r.image_data.is_empty() {
                None
            } else {
                Some(r.image_data.clone())
            };
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_sort_ascending_picture(&self, r: GridHandle) -> Result<ImageData, String> {
        let data = GRID_MANAGER.with_grid(r.id, |g| {
            g.sort_state
                .sort_ascending_picture
                .clone()
                .unwrap_or_default()
        })?;
        Ok(ImageData {
            format: if data.is_empty() {
                String::new()
            } else {
                "png".to_string()
            },
            data,
        })
    }
    fn set_sort_descending_picture(&self, r: SetImageProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.sort_state.sort_descending_picture = if r.image_data.is_empty() {
                None
            } else {
                Some(r.image_data.clone())
            };
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_sort_descending_picture(&self, r: GridHandle) -> Result<ImageData, String> {
        let data = GRID_MANAGER.with_grid(r.id, |g| {
            g.sort_state
                .sort_descending_picture
                .clone()
                .unwrap_or_default()
        })?;
        Ok(ImageData {
            format: if data.is_empty() {
                String::new()
            } else {
                "png".to_string()
            },
            data,
        })
    }
    fn set_merge_cells(&self, r: SetMergeCellsRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.span.mode = r.mode;
            g.span.mode_fixed = r.mode;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_merge_cells_fixed(&self, r: SetMergeCellsRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.span.mode_fixed = r.mode;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_merge_row(&self, r: SetMergeRowRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.row == -1 {
                g.span.span_rows.insert(-1, r.merge);
                for row in 0..g.rows {
                    g.row_props.entry(row).or_default().span = r.merge;
                }
            } else if r.row >= 0 && r.row < g.rows {
                g.span.span_rows.insert(r.row, r.merge);
                g.row_props.entry(r.row).or_default().span = r.merge;
            }
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_merge_col(&self, r: SetMergeColRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col == -1 {
                g.span.span_cols.insert(-1, r.merge);
                for col in &mut g.columns {
                    col.span = r.merge;
                }
            } else if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.span.span_cols.insert(r.col, r.merge);
                g.columns[r.col as usize].span = r.merge;
            }
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_merge_compare(&self, r: SetMergeCompareRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.span.span_compare = r.value;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_merged_range(&self, r: GetMergedRangeRequest) -> Result<SelectionRange, String> {
        let (r1, c1, r2, c2) = GRID_MANAGER.with_grid(r.grid_id, |g| {
            if let Some(range) = g.get_merged_range(r.row, r.col) {
                range
            } else {
                (r.row, r.col, r.row, r.col)
            }
        })?;
        Ok(SelectionRange {
            grid_id: r.grid_id,
            row1: r1,
            col1: c1,
            row2: r2,
            col2: c2,
        })
    }
    fn set_outline_bar(&self, r: SetOutlineBarRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.outline.tree_indicator = r.style;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_outline_col(&self, r: SetOutlineColRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.outline.tree_column = r.col;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_tree_color(&self, r: SetColorProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.style.tree_color = r.color;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_is_subtotal(&self, r: SetIsSubtotalRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.row_props.entry(r.row).or_default().is_subtotal = r.is_subtotal;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_is_subtotal(&self, r: RowColIndex) -> Result<BoolValue, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.row_props.get(&r.index).map_or(false, |p| p.is_subtotal)
        })?;
        Ok(BoolValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_row_outline_level(&self, r: SetRowOutlineLevelRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.row_props.entry(r.row).or_default().outline_level = r.level;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_row_outline_level(&self, r: RowColIndex) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.row_props.get(&r.index).map_or(0, |p| p.outline_level)
        })?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_is_collapsed(&self, r: SetIsCollapsedRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.row_props.entry(r.row).or_default().is_collapsed = r.collapsed;
            volvoxgrid_engine::outline::refresh_visibility(g);
        })?;
        Ok(Empty {})
    }
    fn get_is_collapsed(&self, r: RowColIndex) -> Result<BoolValue, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.row_props.get(&r.index).map_or(false, |p| p.is_collapsed)
        })?;
        Ok(BoolValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn subtotal(&self, r: SubtotalRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::outline::subtotal(
                g,
                r.aggregate,
                r.group_on_col,
                r.aggregate_col,
                &r.caption,
                r.background,
                r.foreground,
                r.add_outline,
            );
        })?;
        Ok(Empty {})
    }
    fn set_subtotal_position(&self, r: SetSubtotalPositionRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.outline.group_total_position = r.position)?;
        Ok(Empty {})
    }
    fn set_multi_totals(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.outline.multi_totals = r.value)?;
        Ok(Empty {})
    }
    fn outline(&self, r: OutlineRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::outline::outline(g, r.level)
        })?;
        Ok(Empty {})
    }
    fn get_node_row(&self, r: GetNodeRowRequest) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::outline::get_node_row(g, r.row, r.relation)
        })?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn get_node(&self, r: GetNodeRequest) -> Result<NodeInfo, String> {
        let (row, level, is_expanded, child_count, parent_row, first_child, last_child) =
            GRID_MANAGER.with_grid(r.grid_id, |g| {
                volvoxgrid_engine::outline::get_node(g, r.row)
            })?;
        Ok(NodeInfo {
            row,
            level,
            is_expanded,
            child_count,
            parent_row,
            first_child,
            last_child,
        })
    }
    fn set_node_open_picture(&self, r: SetImageProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.outline.node_open_picture = if r.image_data.is_empty() {
                None
            } else {
                Some(r.image_data.clone())
            }
        })?;
        Ok(Empty {})
    }
    fn set_node_closed_picture(&self, r: SetImageProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.outline.node_closed_picture = if r.image_data.is_empty() {
                None
            } else {
                Some(r.image_data.clone())
            }
        })?;
        Ok(Empty {})
    }
    fn save_grid(&self, r: SaveGridRequest) -> Result<GridData, String> {
        let data = GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::save::save_grid(g, r.format, r.scope)
        })?;
        Ok(GridData {
            data,
            format: r.format,
        })
    }
    fn load_grid(&self, r: LoadGridRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::save::load_grid(g, &r.data, r.format, r.scope)
        })?;
        Ok(Empty {})
    }
    fn print_grid(&self, r: PrintGridRequest) -> Result<PrintOutput, String> {
        let pages = GRID_MANAGER.with_grid(r.grid_id, |g| {
            if !g.layout.valid {
                ensure_layout(g);
            }
            volvoxgrid_engine::print::print_grid(
                g,
                r.orientation,
                r.margin_left,
                r.margin_top,
                r.margin_right,
                r.margin_bottom,
                &r.header,
                &r.footer,
                r.show_page_numbers,
            )
        })?;
        Ok(PrintOutput {
            pages: pages
                .into_iter()
                .map(|p| PrintPage {
                    page_number: p.page_number,
                    image_data: p.image_data,
                    width: p.width,
                    height: p.height,
                })
                .collect(),
        })
    }
    fn archive(&self, r: ArchiveRequest) -> Result<ArchiveResponse, String> {
        let (data, names) = GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::save::archive(g, &r.name, r.action, &r.data)
        })?;
        Ok(ArchiveResponse { data, names })
    }
    fn get_archive_info(&self, r: GetArchiveInfoRequest) -> Result<ArchiveInfo, String> {
        let (names, sizes) = GRID_MANAGER.with_grid(r.grid_id, |_g| {
            volvoxgrid_engine::save::archive_info(&r.data)
        })?;
        Ok(ArchiveInfo { names, sizes })
    }
    fn copy(&self, r: GridHandle) -> Result<ClipboardData, String> {
        let (text, rich_data) =
            GRID_MANAGER.with_grid(r.id, |g| volvoxgrid_engine::clipboard::copy(g))?;
        Ok(ClipboardData { text, rich_data })
    }
    fn cut(&self, r: GridHandle) -> Result<ClipboardData, String> {
        let (text, rich_data) =
            GRID_MANAGER.with_grid(r.id, |g| volvoxgrid_engine::clipboard::cut(g))?;
        Ok(ClipboardData { text, rich_data })
    }
    fn paste(&self, r: PasteRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if let Some(data) = &r.data {
                volvoxgrid_engine::clipboard::paste(g, &data.text);
            }
        })?;
        Ok(Empty {})
    }
    fn delete(&self, r: GridHandle) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.id, |g| volvoxgrid_engine::clipboard::delete_selection(g))?;
        Ok(Empty {})
    }
    fn set_drag_mode(&self, r: SetDragModeRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.drag.drag_mode = r.mode)?;
        Ok(Empty {})
    }
    fn set_drop_mode(&self, r: SetDropModeRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.drag.drop_mode = r.mode)?;
        Ok(Empty {})
    }
    fn drag_row(&self, r: DragRowRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::drag::drag_row(g, r.row, r.position)
        })?;
        Ok(Empty {})
    }
    fn set_resize_policy(&self, r: SetResizePolicyRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.allow_user_resizing = r.mode)?;
        Ok(Empty {})
    }
    fn set_freeze_policy(&self, r: SetFreezePolicyRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.allow_user_freezing = r.mode)?;
        Ok(Empty {})
    }
    fn set_auto_search(&self, r: SetAutoSearchRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.type_ahead_mode = r.mode)?;
        Ok(Empty {})
    }
    fn set_auto_search_delay(&self, r: SetInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let value = if r.value <= 10 && r.value > 0 {
                r.value * 1000
            } else {
                r.value
            };
            g.type_ahead_delay = value;
        })?;
        Ok(Empty {})
    }
    fn set_auto_size_mouse(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.auto_size_mouse = r.value)?;
        Ok(Empty {})
    }
    fn set_scroll_tips(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.scroll_tips = r.value)?;
        Ok(Empty {})
    }
    fn set_interaction_config(&self, r: SetInteractionConfigRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if let Some(config) = r.config {
                g.fling_enabled = config.fling_enabled;
                if !g.fling_enabled {
                    g.scroll.stop_fling();
                }
                if config.fling_impulse_gain.is_finite() {
                    g.fling_impulse_gain = config.fling_impulse_gain.max(0.0);
                }
                if config.fling_friction.is_finite() {
                    g.fling_friction = config.fling_friction.clamp(0.1, 20.0);
                }
                g.pinch_zoom_enabled = config.pinch_zoom_enabled;
                g.scroll_track = config.scroll_track;
                g.scroll_tips = config.scroll_tips;
                g.auto_size_mouse = config.auto_size_mouse;
            }
        })?;
        Ok(Empty {})
    }
    fn get_interaction_config(&self, r: GridHandle) -> Result<InteractionConfig, String> {
        GRID_MANAGER.with_grid(r.id, |g| InteractionConfig {
            fling_enabled: g.fling_enabled,
            fling_impulse_gain: g.fling_impulse_gain,
            fling_friction: g.fling_friction,
            pinch_zoom_enabled: g.pinch_zoom_enabled,
            scroll_track: g.scroll_track,
            scroll_tips: g.scroll_tips,
            auto_size_mouse: g.auto_size_mouse,
        })
    }
    fn set_renderer_mode(&self, r: SetRendererModeRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.renderer_mode = r.mode;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_renderer_mode(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.renderer_mode)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_debug_overlay(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.debug_overlay = r.value;
            g.layer_profiling = r.value;
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_debug_overlay(&self, r: GridHandle) -> Result<BoolValue, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.debug_overlay)?;
        Ok(BoolValue {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_animation_enabled(&self, r: SetAnimationEnabledRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.animation.enabled = r.enabled;
            if r.duration_ms > 0 {
                g.animation.set_duration_ms(r.duration_ms);
            }
            if !r.enabled {
                g.animation.clear();
                if g.tick_scrollbar_fade(0.0) {
                    g.mark_dirty_visual();
                }
            }
        })?;
        Ok(Empty {})
    }
    fn get_animation_enabled(&self, r: GridHandle) -> Result<BoolValue, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.animation.enabled)?;
        Ok(BoolValue {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_redraw(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let was_off = !g.redraw;
            g.redraw = r.value;
            if r.value {
                if was_off {
                    g.animation.suppress_next = true;
                    g.animation.clear();
                }
                g.mark_dirty();
            }
        })?;
        Ok(Empty {})
    }
    fn refresh(&self, r: GridHandle) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.id, |g| {
            g.layout.invalidate();
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn set_auto_resize(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.auto_resize = r.value)?;
        Ok(Empty {})
    }
    fn get_auto_resize(&self, r: GridHandle) -> Result<BoolValue, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.auto_resize)?;
        Ok(BoolValue {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_scroll_tip_text(&self, r: SetStringProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.scroll_tooltip_text = r.value.clone())?;
        Ok(Empty {})
    }
    fn get_scroll_tip_text(&self, r: GridHandle) -> Result<StringValue, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.scroll_tooltip_text.clone())?;
        Ok(StringValue {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_flags(&self, r: SetInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.flags = r.value as u32)?;
        Ok(Empty {})
    }
    fn get_flags(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.flags as i32)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_version(&self, _r: GridHandle) -> Result<StringValue, String> {
        Ok(StringValue {
            grid_id: 0,
            value: "1.0.0".to_string(),
        })
    }
    fn get_client_width(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.viewport_width)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_client_height(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.viewport_height)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_is_searching(&self, r: GridHandle) -> Result<BoolValue, String> {
        Ok(BoolValue {
            grid_id: r.id,
            value: false,
        })
    }
    fn get_picture(&self, r: GridHandle) -> Result<ImageData, String> {
        GRID_MANAGER.with_grid(r.id, |g| capture_grid_picture(g))
    }
    fn set_picture_type(&self, r: SetInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            g.picture_type = r.value.clamp(0, 2);
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_picture_type(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.picture_type)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_data_mode(&self, r: SetInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.data_source_mode = r.value.max(0))?;
        Ok(Empty {})
    }
    fn get_data_mode(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.data_source_mode)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_virtual_data(&self, r: SetBoolProp) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.virtual_mode = r.value)?;
        Ok(Empty {})
    }
    fn get_virtual_data(&self, r: GridHandle) -> Result<BoolValue, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.virtual_mode)?;
        Ok(BoolValue {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_col_data(&self, r: SetColDataRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize].user_data = if r.data.is_empty() {
                    None
                } else {
                    Some(r.data.clone())
                };
            }
        })?;
        Ok(Empty {})
    }
    fn get_col_data(&self, r: GetColDataRequest) -> Result<ColDataValue, String> {
        let data = GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.col >= 0 && (r.col as usize) < g.columns.len() {
                g.columns[r.col as usize]
                    .user_data
                    .clone()
                    .unwrap_or_default()
            } else {
                Vec::new()
            }
        })?;
        Ok(ColDataValue {
            grid_id: r.grid_id,
            data,
        })
    }
    fn set_row_data(&self, r: SetColDataRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let row = r.col;
            if row >= 0 && row < g.rows {
                if r.data.is_empty() {
                    g.set_row_data(row, None);
                } else {
                    g.set_row_data(row, Some(r.data.clone()));
                }
            }
        })?;
        Ok(Empty {})
    }
    fn get_row_data(&self, r: GetColDataRequest) -> Result<ColDataValue, String> {
        let data = GRID_MANAGER.with_grid(r.grid_id, |g| {
            let row = r.col;
            if row >= 0 && row < g.rows {
                g.get_row_data(row).unwrap_or_default()
            } else {
                Vec::new()
            }
        })?;
        Ok(ColDataValue {
            grid_id: r.grid_id,
            data,
        })
    }
    fn set_row_status(&self, r: SetColInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let row = r.col;
            if row >= 0 && row < g.rows {
                g.set_row_status(row, r.value);
            }
        })?;
        Ok(Empty {})
    }
    fn get_row_status(&self, r: RowColIndex) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            if r.index >= 0 && r.index < g.rows {
                g.get_row_status(r.index)
            } else {
                0
            }
        })?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn set_cell_button_picture(&self, r: SetCellButtonPictureRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| {
            let cell = g.cells.get_mut(r.row, r.col);
            if let Some(img) = &r.image {
                let extra = cell.extra_mut();
                extra.button_picture = if img.data.is_empty() {
                    None
                } else {
                    Some(img.data.clone())
                };
                extra.button_picture_format = img.format.clone();
            } else {
                let extra = cell.extra_mut();
                extra.button_picture = None;
                extra.button_picture_format.clear();
            }
            g.mark_dirty();
        })?;
        Ok(Empty {})
    }
    fn get_cell_button_picture(&self, r: GetCellButtonPictureRequest) -> Result<ImageData, String> {
        let (data, format) =
            GRID_MANAGER.with_grid(r.grid_id, |g| match g.cells.get(r.row, r.col) {
                Some(cell) => (
                    cell.extra
                        .as_ref()
                        .and_then(|e| e.button_picture.clone())
                        .unwrap_or_default(),
                    cell.extra
                        .as_ref()
                        .map(|e| e.button_picture_format.clone())
                        .unwrap_or_default(),
                ),
                None => (Vec::new(), String::new()),
            })?;
        Ok(ImageData { data, format })
    }
    fn get_edit_sel_start(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.edit.sel_start)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_edit_sel_start(&self, r: EditSelRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.edit.set_sel_start(r.value))?;
        Ok(Empty {})
    }
    fn get_edit_sel_length(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.edit.sel_length)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_edit_sel_length(&self, r: EditSelRequest) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.edit.set_sel_length(r.value))?;
        Ok(Empty {})
    }
    fn get_edit_sel_text(&self, r: GridHandle) -> Result<StringValue, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.edit.get_sel_text().to_string())?;
        Ok(StringValue {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_combo_count(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.edit.dropdown_count())?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn get_combo_index(&self, r: GridHandle) -> Result<Int32Value, String> {
        let v = GRID_MANAGER.with_grid(r.id, |g| g.edit.dropdown_index)?;
        Ok(Int32Value {
            grid_id: r.id,
            value: v,
        })
    }
    fn set_combo_index(&self, r: SetInt32Prop) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.edit.set_dropdown_index(r.value))?;
        Ok(Empty {})
    }
    fn get_combo_item(&self, r: ComboInfoRequest) -> Result<StringValue, String> {
        let v =
            GRID_MANAGER.with_grid(r.grid_id, |g| g.edit.get_dropdown_item(r.index).to_string())?;
        Ok(StringValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn get_combo_data(&self, r: ComboInfoRequest) -> Result<StringValue, String> {
        let v =
            GRID_MANAGER.with_grid(r.grid_id, |g| g.edit.get_dropdown_data(r.index).to_string())?;
        Ok(StringValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn data_refresh(&self, r: GridHandle) -> Result<Empty, String> {
        GRID_MANAGER.with_grid(r.id, |g| g.data_refresh())?;
        Ok(Empty {})
    }
    fn load_grid_url(&self, r: LoadGridUrlRequest) -> Result<BoolValue, String> {
        let v = GRID_MANAGER.with_grid(r.grid_id, |g| {
            volvoxgrid_engine::save::load_grid_url(g, &r.url, &r.data, r.format, r.scope)
        })?;
        Ok(BoolValue {
            grid_id: r.grid_id,
            value: v,
        })
    }
    fn auto_search(&self, r: SetAutoSearchRequest) -> Result<Int32Value, String> {
        GRID_MANAGER.with_grid(r.grid_id, |g| g.type_ahead_mode = r.mode)?;
        Ok(Int32Value {
            grid_id: r.grid_id,
            value: 0,
        })
    }
    fn load_demo(&self, r: LoadDemoRequest) -> Result<Empty, String> {
        #[cfg(feature = "demo")]
        {
            GRID_MANAGER.with_grid(r.grid_id, |g| {
                let scale = g.scale;
                g.default_row_height = DEFAULT_ROW_HEIGHT;
                g.default_col_width = DEFAULT_COL_WIDTH;
                g.row_heights.clear();
                g.col_widths.clear();
                match r.demo.as_str() {
                    "sales" => volvoxgrid_engine::demo::setup_sales_demo(g),
                    "hierarchy" => volvoxgrid_engine::demo::setup_hierarchy_demo(g),
                    "stress" => volvoxgrid_engine::demo::setup_stress_demo(g),
                    _ => {}
                }
                if (scale - 1.0).abs() > 0.01 {
                    let custom_row_heights: Vec<(i32, i32)> =
                        g.row_heights.iter().map(|(r, h)| (*r, *h)).collect();
                    let custom_col_widths: Vec<(i32, i32)> =
                        g.col_widths.iter().map(|(c, w)| (*c, *w)).collect();
                    g.default_row_height = (g.default_row_height as f32 * scale).round() as i32;
                    for (r, h) in custom_row_heights {
                        g.set_row_height(r, (h as f32 * scale).round() as i32);
                    }
                    g.default_col_width = (g.default_col_width as f32 * scale).round() as i32;
                    for (c, w) in custom_col_widths {
                        g.set_col_width(c, (w as f32 * scale).round() as i32);
                    }
                }
            })?;
            return Ok(Empty {});
        }
        #[cfg(not(feature = "demo"))]
        Err("demo feature not enabled".to_string())
    }
}

impl ActiveXPlugin {
    fn manager(&self) -> &'static GridManager {
        &GRID_MANAGER
    }
}

impl VolvoxGridServicePlugin for ActiveXPlugin {
    fn create(&self, request: CreateRequest) -> Result<CreateResponse, String> {
        let config = request.config.as_ref();
        let layout = config.and_then(|c| c.layout.as_ref());
        let rows = layout.and_then(|l| l.rows).unwrap_or(10);
        let cols = layout.and_then(|l| l.cols).unwrap_or(5);
        let fixed_rows = layout.and_then(|l| l.fixed_rows).unwrap_or(1);
        let fixed_cols = layout.and_then(|l| l.fixed_cols).unwrap_or(0);
        let scale = if request.scale > 0.01 {
            request.scale
        } else {
            1.0
        };

        let id = self.manager().create_grid(
            request.viewport_width,
            request.viewport_height,
            rows,
            cols,
            fixed_rows,
            fixed_cols,
            scale,
        );

        // Preserve ActiveX-friendly defaults.
        let _ = self.manager().with_grid(id, |g| {
            g.style.font_name = "MS Sans Serif".to_string();
            g.style.font_size = 10.0 * 96.0 / 72.0; // 10pt @ 96 DPI
            g.style.back_color_bkg = 0xFF808080;
            g.style.back_color_fixed = 0xFFD4D0C8;
            g.style.grid_color = g.style.back_color_fixed;
            g.style.grid_color_fixed = g.style.back_color_fixed;
            g.default_row_height = ACTIVEX_DEFAULT_ROW_HEIGHT;
            g.default_col_width = ACTIVEX_DEFAULT_COL_WIDTH;
            g.indicator_bands.col_top.default_row_height_px = ACTIVEX_DEFAULT_ROW_HEIGHT;
            g.selection.selection_visibility = 1;
            g.has_focus = true;
            if fixed_rows == 0 {
                apply_default_indicator_bands(g);
            }
        });

        if let Some(config) = config {
            let _ = self.manager().with_grid(id, |grid| {
                grid.apply_config(config);
            });
        }

        Ok(CreateResponse {
            handle: Some(GridHandle { id }),
            warnings: Vec::new(),
        })
    }

    fn destroy(&self, request: GridHandle) -> Result<Empty, String> {
        RENDERERS.with(|rc| {
            rc.borrow_mut().remove(&request.id);
        });
        self.manager().destroy_grid(request.id);
        Ok(Empty {})
    }

    fn configure(&self, request: ConfigureRequest) -> Result<Empty, String> {
        if let Some(config) = &request.config {
            self.manager().with_grid(request.grid_id, |grid| {
                grid.apply_config(config);
            })?;
        }
        Ok(Empty {})
    }

    fn get_config(&self, request: GridHandle) -> Result<GridConfig, String> {
        self.manager()
            .with_grid(request.id, |grid| grid.get_config())
    }

    fn load_font_data(&self, _request: LoadFontDataRequest) -> Result<Empty, String> {
        // Font loading is handled externally for the ActiveX adapter.
        Ok(Empty {})
    }

    fn define_columns(&self, request: DefineColumnsRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            grid.define_columns(&request.columns);
        })?;
        Ok(Empty {})
    }

    fn get_schema(&self, request: GridHandle) -> Result<DefineColumnsRequest, String> {
        self.manager()
            .with_grid(request.id, |grid| grid.get_schema(request.id))
    }

    fn define_rows(&self, request: DefineRowsRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            grid.define_rows(&request.rows);
        })?;
        Ok(Empty {})
    }

    fn insert_rows(&self, request: InsertRowsRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            let count = request.count.max(1);
            let index = if request.index < 0 { -1 } else { request.index };
            for i in 0..count {
                let text = request
                    .text
                    .get(i as usize)
                    .map(|s| s.as_str())
                    .unwrap_or("");
                let at_row = if index < 0 { -1 } else { index + i };
                grid.add_item(text, at_row);
            }
        })?;
        Ok(Empty {})
    }

    fn remove_rows(&self, request: RemoveRowsRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            let count = request.count.max(1);
            for _ in 0..count {
                let row = request.index.min(grid.rows - 1);
                if row < grid.fixed_rows {
                    break;
                }
                grid.remove_item(row);
            }
        })?;
        Ok(Empty {})
    }

    fn move_column(&self, request: MoveColumnRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            if request.col >= 0
                && request.col < grid.cols
                && request.position >= 0
                && request.position < grid.cols
            {
                grid.move_col_by_positions(request.col, request.position);
            }
        })?;
        Ok(Empty {})
    }

    fn move_row(&self, request: MoveRowRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            if request.row >= grid.fixed_rows
                && request.row < grid.rows
                && request.position >= grid.fixed_rows
                && request.position < grid.rows
            {
                let src = request.row;
                let dst = request.position;
                if src != dst && !grid.row_positions.is_empty() {
                    let val = grid.row_positions.remove(src as usize);
                    grid.row_positions.insert(dst as usize, val);
                    grid.layout.invalidate();
                    grid.mark_dirty();
                }
            }
        })?;
        Ok(Empty {})
    }

    fn update_cells(&self, request: UpdateCellsRequest) -> Result<WriteResult, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            grid.write_cells(&request.cells, request.atomic)
        })
    }

    fn get_cells(&self, request: GetCellsRequest) -> Result<CellsResponse, String> {
        let cells = self.manager().with_grid(request.grid_id, |grid| {
            grid.get_cells(
                request.row1,
                request.col1,
                request.row2,
                request.col2,
                request.include_style,
                request.include_checked,
                request.include_typed,
            )
        })?;
        Ok(CellsResponse { cells })
    }

    fn load_table(&self, request: LoadTableRequest) -> Result<WriteResult, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            grid.load_table(request.rows, request.cols, &request.values, request.atomic)
        })
    }

    fn clear(&self, request: ClearRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            let (r1, c1, r2, c2) = match request.region {
                0 => (
                    grid.fixed_rows,
                    grid.fixed_cols,
                    grid.rows - 1,
                    grid.cols - 1,
                ),
                1 => (0, 0, grid.fixed_rows - 1, grid.cols - 1),
                2 => (0, 0, grid.rows - 1, grid.fixed_cols - 1),
                3 => (0, 0, grid.fixed_rows - 1, grid.fixed_cols - 1),
                4 => (0, 0, grid.rows - 1, grid.cols - 1),
                5 => (0, 0, grid.rows - 1, grid.cols - 1),
                6 => (0, 0, grid.rows - 1, grid.cols - 1),
                _ => (
                    grid.fixed_rows,
                    grid.fixed_cols,
                    grid.rows - 1,
                    grid.cols - 1,
                ),
            };
            match request.scope {
                0 => {
                    grid.cells.clear_range(r1, c1, r2, c2);
                    for r in r1..=r2 {
                        for c in c1..=c2 {
                            grid.cell_styles.remove(&(r, c));
                        }
                    }
                }
                1 => {
                    for r in r1..=r2 {
                        for c in c1..=c2 {
                            grid.cell_styles.remove(&(r, c));
                        }
                    }
                }
                2 => {
                    grid.cells.clear_range(r1, c1, r2, c2);
                }
                3 => {
                    let sr1 = grid.selection.row.min(grid.selection.row_end);
                    let sr2 = grid.selection.row.max(grid.selection.row_end);
                    let sc1 = grid.selection.col.min(grid.selection.col_end);
                    let sc2 = grid.selection.col.max(grid.selection.col_end);
                    grid.cells.clear_range(sr1, sc1, sr2, sc2);
                    for r in sr1..=sr2 {
                        for c in sc1..=sc2 {
                            grid.cell_styles.remove(&(r, c));
                        }
                    }
                }
                _ => {}
            }
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn select(&self, request: SelectRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            let active_row = request.active_row;
            let active_col = request.active_col;
            let ranges: Vec<(i32, i32, i32, i32)> = request
                .ranges
                .iter()
                .map(|r| (r.row1, r.col1, r.row2, r.col2))
                .collect();
            grid.selection
                .select_ranges(active_row, active_col, &ranges, grid.rows, grid.cols);
            if request.show.unwrap_or(false) {
                ensure_layout(grid);
                grid.scroll.show_cell(
                    active_row,
                    active_col,
                    &grid.layout,
                    grid.viewport_width,
                    grid.viewport_height,
                    grid.fixed_rows,
                    grid.fixed_cols,
                    grid.pinned_top_height() + grid.pinned_bottom_height(),
                    grid.pinned_left_width() + grid.pinned_right_width(),
                );
            }
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn get_selection(&self, request: GridHandle) -> Result<SelectionState, String> {
        self.manager().with_grid(request.id, |grid| {
            ensure_layout(grid);
            SelectionState {
                active_row: grid.selection.row,
                active_col: grid.selection.col,
                ranges: selection_ranges_proto(grid),
                top_row: grid.top_row(),
                left_col: grid.left_col(),
                bottom_row: grid.bottom_row(),
                right_col: grid.right_col(),
                mouse_row: grid.mouse_row,
                mouse_col: grid.mouse_col,
            }
        })
    }

    fn show_cell(&self, request: ShowCellRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            ensure_layout(grid);
            grid.scroll.show_cell(
                request.row,
                request.col,
                &grid.layout,
                grid.viewport_width,
                grid.viewport_height,
                grid.fixed_rows,
                grid.fixed_cols,
                grid.pinned_top_height() + grid.pinned_bottom_height(),
                grid.pinned_left_width() + grid.pinned_right_width(),
            );
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn set_top_row(&self, request: SetRowRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            grid.set_top_row(request.row);
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn set_left_col(&self, request: SetColRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            grid.set_left_col(request.col);
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn edit(&self, request: EditCommand) -> Result<EditState, String> {
        let grid_id = request.grid_id;
        let state = self.manager().with_grid(grid_id, |grid| {
            match request.command {
                Some(edit_command::Command::Start(start)) => {
                    begin_edit_session(grid, start.row, start.col, true);
                }
                Some(edit_command::Command::Commit(commit)) => {
                    if grid.edit.is_active() {
                        grid.edit.flush_preedit();
                        let row = grid.edit.edit_row;
                        let col = grid.edit.edit_col;
                        let old_text = grid.cells.get_text(row, col).to_string();
                        let new_text = commit.text.unwrap_or_else(|| grid.edit.edit_text.clone());
                        let committed = normalize_committed_edit_text(grid, row, col, &new_text);
                        grid.edit.cancel();
                        grid.events.push(
                            volvoxgrid_engine::event::GridEventData::CellEditValidate {
                                row,
                                col,
                                edit_text: committed.clone(),
                            },
                        );
                        apply_committed_edit_text(grid, row, col, old_text, committed);
                    }
                }
                Some(edit_command::Command::Cancel(_)) => {
                    if grid.edit.is_active() {
                        let active_combo =
                            grid.active_dropdown_list(grid.edit.edit_row, grid.edit.edit_col);
                        grid.edit.cancel();
                        if !active_combo.is_empty() && active_combo.trim() != "..." {
                            grid.events
                                .push(volvoxgrid_engine::event::GridEventData::DropdownClosed);
                        }
                        grid.mark_dirty();
                    }
                }
                Some(edit_command::Command::SetText(set_text)) => {
                    if grid.edit.is_active() {
                        let t = truncate_to_char_count(&set_text.text, grid.edit_max_length);
                        grid.edit.edit_text = t.clone();
                        grid.edit.sel_start = t.chars().count() as i32;
                        grid.edit.sel_length = 0;
                        grid.events
                            .push(volvoxgrid_engine::event::GridEventData::CellEditChange {
                                text: t,
                            });
                    }
                }
                Some(edit_command::Command::SetSelection(sel)) => {
                    if grid.edit.is_active() {
                        grid.edit.set_sel_start(sel.start);
                        grid.edit.set_sel_length(sel.length);
                    }
                }
                Some(edit_command::Command::SetHighlights(_)) => {}
                Some(edit_command::Command::SetPreedit(preedit)) => {
                    if grid.edit.is_active() {
                        if preedit.commit {
                            grid.edit.commit_preedit(&preedit.text);
                        } else if preedit.text.is_empty() {
                            grid.edit.cancel_preedit();
                        } else {
                            grid.edit.set_preedit(&preedit.text, preedit.cursor);
                        }
                        grid.mark_dirty();
                    }
                }
                Some(edit_command::Command::Finish(_)) => {
                    if grid.edit.is_active() {
                        grid.edit.flush_preedit();
                        let row = grid.edit.edit_row;
                        let col = grid.edit.edit_col;
                        let old_text = grid.cells.get_text(row, col).to_string();
                        let new_text = grid.edit.edit_text.clone();
                        let committed = normalize_committed_edit_text(grid, row, col, &new_text);
                        grid.edit.cancel();
                        grid.events.push(
                            volvoxgrid_engine::event::GridEventData::CellEditValidate {
                                row,
                                col,
                                edit_text: committed.clone(),
                            },
                        );
                        apply_committed_edit_text(grid, row, col, old_text, committed);
                    }
                }
                None => {}
            }

            EditState {
                active: grid.edit.is_active(),
                row: grid.edit.edit_row,
                col: grid.edit.edit_col,
                text: grid.edit.edit_text.clone(),
                sel_start: grid.edit.sel_start,
                sel_length: grid.edit.sel_length,
                composing: grid.edit.composing,
                preedit_text: grid.edit.preedit_text.clone(),
                ui_mode: match grid.edit.ui_mode {
                    volvoxgrid_engine::edit::EditUiMode::EnterMode => EditUiMode::Enter as i32,
                    volvoxgrid_engine::edit::EditUiMode::EditMode => EditUiMode::Edit as i32,
                },
            }
        })?;
        Ok(state)
    }

    fn sort(&self, request: SortRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            if request.sort_columns.is_empty() {
                grid.sort_state.clear();
                grid.layout.invalidate();
                grid.mark_dirty();
            } else {
                let sort_keys = expand_sort_request_columns(grid, &request.sort_columns);
                if sort_keys.is_empty() {
                    return;
                }
                grid.sort_state.sort_keys = sort_keys;
                volvoxgrid_engine::sort::sort_grid_all_multi(grid);
            }
        })?;
        Ok(Empty {})
    }

    fn subtotal(&self, request: SubtotalRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            volvoxgrid_engine::outline::subtotal(
                grid,
                request.aggregate,
                request.group_on_col,
                request.aggregate_col,
                &request.caption,
                request.background,
                request.foreground,
                request.add_outline,
            );
        })?;
        Ok(Empty {})
    }

    fn auto_size(&self, request: AutoSizeRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            ensure_layout(grid);
            let c1 = request.col_from.max(0).min(grid.cols - 1);
            let c2 = request.col_to.max(c1).min(grid.cols - 1);
            for c in c1..=c2 {
                grid.auto_resize_col(c);
            }
            if request.equal {
                let max_w = (c1..=c2).map(|c| grid.col_width(c)).max().unwrap_or(0);
                let max_w = if request.max_width > 0 {
                    max_w.min(request.max_width)
                } else {
                    max_w
                };
                for c in c1..=c2 {
                    grid.set_col_width(c, max_w);
                }
            } else if request.max_width > 0 {
                for c in c1..=c2 {
                    let w = grid.col_width(c);
                    if w > request.max_width {
                        grid.set_col_width(c, request.max_width);
                    }
                }
            }
        })?;
        Ok(Empty {})
    }

    fn outline(&self, request: OutlineRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            volvoxgrid_engine::outline::outline(grid, request.level);
        })?;
        Ok(Empty {})
    }

    fn get_node(&self, request: GetNodeRequest) -> Result<NodeInfo, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            let row = if let Some(relation) = request.relation {
                volvoxgrid_engine::outline::get_node_row(grid, request.row, relation)
            } else {
                request.row
            };
            let (
                level,
                outline_level,
                is_expanded,
                child_count,
                parent_row,
                first_child,
                last_child,
            ) = volvoxgrid_engine::outline::get_node(grid, row);
            let _ = level;
            NodeInfo {
                row,
                level: outline_level,
                is_expanded,
                child_count,
                parent_row,
                first_child,
                last_child,
            }
        })
    }

    fn find(&self, request: FindRequest) -> Result<FindResponse, String> {
        let row = self
            .manager()
            .with_grid(request.grid_id, |grid| match request.query {
                Some(find_request::Query::TextQuery(tq)) => volvoxgrid_engine::search::find_row(
                    grid,
                    &tq.text,
                    request.start_row,
                    request.col,
                    tq.case_sensitive,
                    tq.full_match,
                ),
                Some(find_request::Query::RegexQuery(rq)) => {
                    volvoxgrid_engine::search::find_row_regex(
                        grid,
                        &rq.pattern,
                        request.start_row,
                        request.col,
                    )
                }
                None => -1,
            })?;
        Ok(FindResponse { row })
    }

    fn aggregate(&self, request: AggregateRequest) -> Result<AggregateResponse, String> {
        let value = self.manager().with_grid(request.grid_id, |grid| {
            volvoxgrid_engine::search::aggregate(
                grid,
                request.aggregate,
                request.row1,
                request.col1,
                request.row2,
                request.col2,
            )
        })?;
        Ok(AggregateResponse { value })
    }

    fn get_merged_range(&self, request: GetMergedRangeRequest) -> Result<CellRange, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            if let Some((r1, c1, r2, c2)) = grid.get_merged_range(request.row, request.col) {
                CellRange {
                    row1: r1,
                    col1: c1,
                    row2: r2,
                    col2: c2,
                }
            } else {
                CellRange {
                    row1: request.row,
                    col1: request.col,
                    row2: request.row,
                    col2: request.col,
                }
            }
        })
    }

    fn merge_cells(&self, request: MergeCellsRequest) -> Result<Empty, String> {
        let range = request.range.unwrap_or_default();
        self.manager().with_grid(request.grid_id, |grid| {
            grid.merged_regions
                .add_merge(range.row1, range.col1, range.row2, range.col2);
            grid.layout.invalidate();
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn unmerge_cells(&self, request: UnmergeCellsRequest) -> Result<Empty, String> {
        let range = request.range.unwrap_or_default();
        self.manager().with_grid(request.grid_id, |grid| {
            grid.merged_regions
                .remove_overlapping(range.row1, range.col1, range.row2, range.col2);
            grid.layout.invalidate();
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn get_merged_regions(&self, request: GridHandle) -> Result<MergedRegionsResponse, String> {
        self.manager()
            .with_grid(request.id, |grid| MergedRegionsResponse {
                ranges: grid
                    .merged_regions
                    .all_ranges()
                    .iter()
                    .map(|&(r1, c1, r2, c2)| CellRange {
                        row1: r1,
                        col1: c1,
                        row2: r2,
                        col2: c2,
                    })
                    .collect(),
            })
    }

    fn get_memory_usage(&self, request: GridHandle) -> Result<MemoryUsageResponse, String> {
        self.manager()
            .with_grid(request.id, |grid| grid.memory_usage())
    }

    fn clipboard(&self, request: ClipboardCommand) -> Result<ClipboardResponse, String> {
        self.manager()
            .with_grid(request.grid_id, |grid| match request.command {
                Some(clipboard_command::Command::Copy(_)) => {
                    let (text, rich_data) = volvoxgrid_engine::clipboard::copy(grid);
                    ClipboardResponse { text, rich_data }
                }
                Some(clipboard_command::Command::Cut(_)) => {
                    let (text, rich_data) = volvoxgrid_engine::clipboard::cut(grid);
                    ClipboardResponse { text, rich_data }
                }
                Some(clipboard_command::Command::Paste(paste)) => {
                    if !paste.text.is_empty() {
                        volvoxgrid_engine::clipboard::paste(grid, &paste.text);
                    }
                    ClipboardResponse {
                        text: String::new(),
                        rich_data: Vec::new(),
                    }
                }
                Some(clipboard_command::Command::Delete(_)) => {
                    volvoxgrid_engine::clipboard::delete_selection(grid);
                    ClipboardResponse {
                        text: String::new(),
                        rich_data: Vec::new(),
                    }
                }
                None => ClipboardResponse {
                    text: String::new(),
                    rich_data: Vec::new(),
                },
            })
    }

    fn export(&self, request: ExportRequest) -> Result<ExportResponse, String> {
        let data = self.manager().with_grid(request.grid_id, |grid| {
            volvoxgrid_engine::save::save_grid(grid, request.format, request.scope)
        })?;
        Ok(ExportResponse {
            data,
            format: request.format,
        })
    }

    fn import(&self, request: ImportRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            if let Some(url) = &request.url {
                if !url.is_empty() {
                    volvoxgrid_engine::save::load_grid_url(
                        grid,
                        url,
                        &request.data,
                        request.format,
                        request.scope,
                    );
                    return;
                }
            }
            volvoxgrid_engine::save::load_grid(grid, &request.data, request.format, request.scope);
        })?;
        Ok(Empty {})
    }

    fn print(&self, request: PrintRequest) -> Result<PrintResponse, String> {
        let pages = self.manager().with_grid(request.grid_id, |grid| {
            ensure_layout(grid);
            let orientation = request.orientation.unwrap_or(0);
            let margin_left = request.margin_left.unwrap_or(50);
            let margin_top = request.margin_top.unwrap_or(50);
            let margin_right = request.margin_right.unwrap_or(50);
            let margin_bottom = request.margin_bottom.unwrap_or(50);
            let header = request.header.as_deref().unwrap_or("");
            let footer = request.footer.as_deref().unwrap_or("");
            let show_page_numbers = request.show_page_numbers.unwrap_or(false);

            volvoxgrid_engine::print::print_grid(
                grid,
                orientation,
                margin_left,
                margin_top,
                margin_right,
                margin_bottom,
                header,
                footer,
                show_page_numbers,
            )
            .into_iter()
            .map(|p| PrintPage {
                page_number: p.page_number,
                image_data: p.image_data,
                width: p.width,
                height: p.height,
            })
            .collect::<Vec<_>>()
        })?;
        Ok(PrintResponse { pages })
    }

    fn archive(&self, request: ArchiveRequest) -> Result<ArchiveResponse, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            let (data, names) = volvoxgrid_engine::save::archive(
                grid,
                &request.name,
                request.action,
                &request.data,
            );
            ArchiveResponse { data, names }
        })
    }

    fn resize_viewport(&self, request: ResizeViewportRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            grid.resize_viewport(request.width, request.height);
        })?;
        Ok(Empty {})
    }

    fn set_redraw(&self, request: SetRedrawRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            let was_off = !grid.redraw;
            grid.redraw = request.enabled;
            if request.enabled {
                if was_off {
                    grid.animation.suppress_next = true;
                    grid.animation.clear();
                }
                grid.mark_dirty();
            }
        })?;
        Ok(Empty {})
    }

    fn refresh(&self, request: GridHandle) -> Result<Empty, String> {
        self.manager().with_grid(request.id, |grid| {
            grid.layout.invalidate();
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn load_demo(&self, request: LoadDemoRequest) -> Result<Empty, String> {
        #[cfg(feature = "demo")]
        {
            self.manager().with_grid(request.grid_id, |grid| {
                match request.demo.as_str() {
                    "sales" => volvoxgrid_engine::demo::setup_sales_demo(grid),
                    "hierarchy" => volvoxgrid_engine::demo::setup_hierarchy_demo(grid),
                    "stress" => volvoxgrid_engine::demo::setup_stress_demo(grid),
                    other => return Err(format!("unknown demo: {other}")),
                }
                Ok(())
            })??;
            return Ok(Empty {});
        }
        #[cfg(not(feature = "demo"))]
        {
            let _ = request;
            Err("demo feature not enabled".to_string())
        }
    }
}

// ---------------------------------------------------------------------------
// C symbol compatibility layer
//
// Keep original symbol names for OCX C callsites, but route behavior through
// the v1-backed engine/runtime in this crate.
// ---------------------------------------------------------------------------

fn compat_set_out_len(out_len: *mut i32, len: usize) {
    if !out_len.is_null() {
        unsafe {
            *out_len = len as i32;
        }
    }
}

fn compat_push_varint(mut value: u64, out: &mut Vec<u8>) {
    while value >= 0x80 {
        out.push((value as u8) | 0x80);
        value >>= 7;
    }
    out.push(value as u8);
}

fn compat_alloc_empty_response(out_len: *mut i32) -> *mut u8 {
    compat_set_out_len(out_len, 0);
    alloc_payload_with_header(Vec::new())
}

fn compat_alloc_i32_response(value: i32, out_len: *mut i32) -> *mut u8 {
    // Compatibility wrappers decode field #2 varint from the payload.
    let mut payload = Vec::with_capacity(11);
    payload.push(0x10); // field 2, wire type 0
    compat_push_varint(value as i64 as u64, &mut payload);
    compat_set_out_len(out_len, payload.len());
    alloc_payload_with_header(payload)
}

fn compat_alloc_bytes_response(payload: Vec<u8>, out_len: *mut i32) -> *mut u8 {
    compat_set_out_len(out_len, payload.len());
    alloc_payload_with_header(payload)
}

fn compat_status(result: Result<(), String>, out_len: *mut i32) -> *mut u8 {
    match result {
        Ok(()) => compat_alloc_empty_response(out_len),
        Err(_) => {
            compat_set_out_len(out_len, 0);
            std::ptr::null_mut()
        }
    }
}

fn compat_i32(result: Result<i32, String>, out_len: *mut i32) -> *mut u8 {
    match result {
        Ok(value) => compat_alloc_i32_response(value, out_len),
        Err(_) => {
            compat_set_out_len(out_len, 0);
            std::ptr::null_mut()
        }
    }
}

fn compat_utf8(ptr: *const u8, len: i32) -> String {
    if ptr.is_null() || len <= 0 {
        return String::new();
    }
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len as usize) };
    String::from_utf8_lossy(bytes).into_owned()
}

fn compat_bytes(ptr: *const u8, len: i32) -> Vec<u8> {
    if ptr.is_null() || len <= 0 {
        return Vec::new();
    }
    unsafe { std::slice::from_raw_parts(ptr, len as usize).to_vec() }
}

fn apply_activex_defaults(grid: &mut volvoxgrid_engine::grid::VolvoxGrid) {
    grid.style.font_name = "MS Sans Serif".to_string();
    grid.style.font_size = 10.0 * 96.0 / 72.0; // 10pt @ 96 DPI
    grid.style.back_color_bkg = 0xFF808080;
    grid.style.back_color_fixed = 0xFFD4D0C8;
    grid.default_row_height = ACTIVEX_DEFAULT_ROW_HEIGHT;
    grid.default_col_width = ACTIVEX_DEFAULT_COL_WIDTH;
    grid.indicator_bands.col_top.default_row_height_px = ACTIVEX_DEFAULT_ROW_HEIGHT;
    grid.selection.selection_visibility = 1;
    grid.has_focus = true;
}

#[no_mangle]
pub extern "C" fn volvox_grid_create_grid(
    viewport_width: i32,
    viewport_height: i32,
    rows: i32,
    cols: i32,
    fixed_rows: i32,
    fixed_cols: i32,
    scale: f32,
) -> i64 {
    let scale = if scale > 0.01 { scale } else { 1.0 };
    let id = GRID_MANAGER.create_grid(
        viewport_width,
        viewport_height,
        rows.max(1),
        cols.max(1),
        fixed_rows.max(0),
        fixed_cols.max(0),
        scale,
    );
    let _ = GRID_MANAGER.with_grid(id, apply_activex_defaults);
    id
}

#[no_mangle]
pub extern "C" fn volvox_grid_destroy_grid(id: i64, out_len: *mut i32) -> *mut u8 {
    RENDERERS.with(|rc| {
        rc.borrow_mut().remove(&id);
    });
    GRID_MANAGER.destroy_grid(id);
    compat_alloc_empty_response(out_len)
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_rows(grid_id: i64, rows: i32, out_len: *mut i32) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.set_rows(rows);
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_cols(grid_id: i64, cols: i32, out_len: *mut i32) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.set_cols(cols);
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_rows(id: i64, out_len: *mut i32) -> *mut u8 {
    compat_i32(GRID_MANAGER.with_grid(id, |g| g.rows), out_len)
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_cols(id: i64, out_len: *mut i32) -> *mut u8 {
    compat_i32(GRID_MANAGER.with_grid(id, |g| g.cols), out_len)
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_fixed_rows(
    grid_id: i64,
    fixed_rows: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            let old_fixed_rows = g.fixed_rows;
            let new_fixed_rows = fixed_rows.max(0).min(g.rows);
            g.fixed_rows = new_fixed_rows;
            if new_fixed_rows == 0 && !g.indicator_bands.col_top.visible {
                apply_default_indicator_bands(g);
            }
            g.selection.remap_collapsed_cursor_after_fixed_change(
                g.rows,
                g.cols,
                old_fixed_rows,
                g.fixed_cols,
                new_fixed_rows,
                g.fixed_cols,
            );
            g.layout.invalidate();
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_fixed_cols(
    grid_id: i64,
    fixed_cols: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            let old_fixed_cols = g.fixed_cols;
            let new_fixed_cols = fixed_cols.max(0).min(g.cols);
            g.fixed_cols = new_fixed_cols;
            g.selection.remap_collapsed_cursor_after_fixed_change(
                g.rows,
                g.cols,
                g.fixed_rows,
                old_fixed_cols,
                g.fixed_rows,
                new_fixed_cols,
            );
            g.layout.invalidate();
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_frozen_rows(
    grid_id: i64,
    frozen_rows: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.frozen_rows = frozen_rows.max(0).min(g.rows - g.fixed_rows);
            g.layout.invalidate();
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_frozen_cols(
    grid_id: i64,
    frozen_cols: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.frozen_cols = frozen_cols.max(0).min(g.cols - g.fixed_cols);
            g.layout.invalidate();
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_row_height(
    grid_id: i64,
    row: i32,
    height: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.set_row_height(row, height);
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_col_width(
    grid_id: i64,
    col: i32,
    width: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.set_col_width(col, width);
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_row_height(
    grid_id: i64,
    index: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_i32(
        GRID_MANAGER.with_grid(grid_id, |g| g.get_row_height(index)),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_col_width(
    grid_id: i64,
    index: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_i32(
        GRID_MANAGER.with_grid(grid_id, |g| g.get_col_width(index)),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_row_hidden(
    grid_id: i64,
    row: i32,
    hidden: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            if hidden != 0 {
                g.rows_hidden.insert(row);
            } else {
                g.rows_hidden.remove(&row);
            }
            g.layout.invalidate();
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_col_hidden(
    grid_id: i64,
    col: i32,
    hidden: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            if hidden != 0 {
                g.cols_hidden.insert(col);
            } else {
                g.cols_hidden.remove(&col);
            }
            g.layout.invalidate();
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_row_is_visible(
    grid_id: i64,
    index: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_i32(
        GRID_MANAGER.with_grid(grid_id, |g| if g.is_row_visible(index) { 1 } else { 0 }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_col_is_visible(
    grid_id: i64,
    index: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_i32(
        GRID_MANAGER.with_grid(grid_id, |g| if g.is_col_visible(index) { 1 } else { 0 }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_scroll_bars(
    grid_id: i64,
    mode: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            match mode {
                1 => {
                    g.scrollbar_show_h = ScrollBarMode::ScrollbarModeAuto as i32;
                    g.scrollbar_show_v = ScrollBarMode::ScrollbarModeNever as i32;
                }
                2 => {
                    g.scrollbar_show_h = ScrollBarMode::ScrollbarModeNever as i32;
                    g.scrollbar_show_v = ScrollBarMode::ScrollbarModeAuto as i32;
                }
                3 => {
                    g.scrollbar_show_h = ScrollBarMode::ScrollbarModeAuto as i32;
                    g.scrollbar_show_v = ScrollBarMode::ScrollbarModeAuto as i32;
                }
                _ => {
                    g.scrollbar_show_h = ScrollBarMode::ScrollbarModeNever as i32;
                    g.scrollbar_show_v = ScrollBarMode::ScrollbarModeNever as i32;
                }
            }
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_top_row(id: i64, out_len: *mut i32) -> *mut u8 {
    compat_i32(GRID_MANAGER.with_grid(id, |g| g.top_row()), out_len)
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_left_col(id: i64, out_len: *mut i32) -> *mut u8 {
    compat_i32(GRID_MANAGER.with_grid(id, |g| g.left_col()), out_len)
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_row(grid_id: i64, row: i32, out_len: *mut i32) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.selection.set_cursor(
                row,
                g.selection.col,
                g.rows,
                g.cols,
                g.fixed_rows,
                g.fixed_cols,
            );
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_row(id: i64, out_len: *mut i32) -> *mut u8 {
    compat_i32(GRID_MANAGER.with_grid(id, |g| g.selection.row), out_len)
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_col(grid_id: i64, col: i32, out_len: *mut i32) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.selection.set_cursor(
                g.selection.row,
                col,
                g.rows,
                g.cols,
                g.fixed_rows,
                g.fixed_cols,
            );
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_col(id: i64, out_len: *mut i32) -> *mut u8 {
    compat_i32(GRID_MANAGER.with_grid(id, |g| g.selection.col), out_len)
}

#[no_mangle]
pub extern "C" fn volvox_grid_select(
    grid_id: i64,
    row1: i32,
    col1: i32,
    row2: i32,
    col2: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.selection.select(row1, col1, row2, col2, g.rows, g.cols);
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_allow_selection(
    grid_id: i64,
    value: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            let flag = value != 0;
            g.allow_selection = flag;
            g.selection.allow_selection = flag;
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_allow_big_selection(
    grid_id: i64,
    value: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            let flag = value != 0;
            g.header_click_select = flag;
            g.selection.header_click_select = flag;
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_selection_mode(
    grid_id: i64,
    mode: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.selection.mode = mode;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_focus_rect(
    grid_id: i64,
    style: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.selection.focus_border = style;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_high_light(
    grid_id: i64,
    style: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.selection.selection_visibility = style;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_text_matrix(
    grid_id: i64,
    row: i32,
    col: i32,
    text: *const u8,
    text_len: i32,
    out_len: *mut i32,
) -> *mut u8 {
    let text = compat_utf8(text, text_len);
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.cells.set_text(row, col, text.clone());
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_text_matrix(
    grid_id: i64,
    row: i32,
    col: i32,
    out_len: *mut i32,
) -> *mut u8 {
    match GRID_MANAGER.with_grid(grid_id, |g| g.cells.get_text(row, col).as_bytes().to_vec()) {
        Ok(bytes) => compat_alloc_bytes_response(bytes, out_len),
        Err(_) => {
            compat_set_out_len(out_len, 0);
            std::ptr::null_mut()
        }
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_fill_style(
    grid_id: i64,
    style: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| g.apply_scope = style),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_add_item(
    grid_id: i64,
    item: *const u8,
    item_len: i32,
    index: i32,
    out_len: *mut i32,
) -> *mut u8 {
    let item = compat_utf8(item, item_len);
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.add_item(&item, index);
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_remove_item(grid_id: i64, index: i32, out_len: *mut i32) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.remove_item(index);
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_find_row(
    grid_id: i64,
    text: *const u8,
    text_len: i32,
    start_row: i32,
    col: i32,
    case_sense: i32,
    full_match: i32,
    out_len: *mut i32,
) -> *mut u8 {
    let text = compat_utf8(text, text_len);
    compat_i32(
        GRID_MANAGER.with_grid(grid_id, |g| {
            volvoxgrid_engine::search::find_row(
                g,
                &text,
                start_row,
                col,
                case_sense != 0,
                full_match != 0,
            )
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_find_row_regex(
    grid_id: i64,
    pattern: *const u8,
    pattern_len: i32,
    start_row: i32,
    col: i32,
    out_len: *mut i32,
) -> *mut u8 {
    let pattern = compat_utf8(pattern, pattern_len);
    compat_i32(
        GRID_MANAGER.with_grid(grid_id, |g| {
            volvoxgrid_engine::search::find_row_regex(g, &pattern, start_row, col)
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_editable(grid_id: i64, mode: i32, out_len: *mut i32) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| g.edit_trigger_mode = mode),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_edit_cell(
    grid_id: i64,
    row: i32,
    col: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            begin_edit_session(g, row, col, true);
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_col_combo_list(
    grid_id: i64,
    col: i32,
    list: *const u8,
    list_len: i32,
    out_len: *mut i32,
) -> *mut u8 {
    let list = compat_utf8(list, list_len);
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            if col == -1 {
                for c in &mut g.columns {
                    c.dropdown_items = list.clone();
                }
            } else if col >= 0 && (col as usize) < g.columns.len() {
                g.columns[col as usize].dropdown_items = list.clone();
            }
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_show_combo_button(
    grid_id: i64,
    mode: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| g.dropdown_trigger = mode),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_col_data_type(
    grid_id: i64,
    col: i32,
    data_type: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            if col >= 0 && (col as usize) < g.columns.len() {
                g.columns[col as usize].data_type = data_type;
            }
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_col_alignment(
    grid_id: i64,
    col: i32,
    alignment: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            if col >= 0 && (col as usize) < g.columns.len() {
                g.columns[col as usize].alignment = alignment;
                g.mark_dirty();
            }
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_fixed_alignment(
    grid_id: i64,
    col: i32,
    alignment: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            if col >= 0 && (col as usize) < g.columns.len() {
                g.columns[col as usize].fixed_alignment = alignment;
                g.mark_dirty();
            }
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_cell_flood(
    grid_id: i64,
    row: i32,
    col: i32,
    color: u32,
    percent: f32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            let cell = g.cells.get_mut(row, col);
            let extra = cell.extra_mut();
            extra.progress_color = color;
            extra.progress_percent = percent;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_cell_checked(
    grid_id: i64,
    row: i32,
    col: i32,
    state: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.cells.get_mut(row, col).extra_mut().checked = state;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_cell_checked(
    grid_id: i64,
    row: i32,
    col: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_i32(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.cells.get(row, col).map_or(0, |c| c.checked())
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_word_wrap(
    grid_id: i64,
    value: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.word_wrap = value != 0;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_ellipsis(grid_id: i64, value: i32, out_len: *mut i32) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.ellipsis_mode = value.clamp(0, 2);
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_extend_last_col(
    grid_id: i64,
    value: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.extend_last_col = value != 0;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_merge_cells(
    grid_id: i64,
    mode: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.span.mode = mode;
            g.span.mode_fixed = mode;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_merge_row(
    grid_id: i64,
    row: i32,
    merge: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            let merge_enabled = merge != 0;
            if row == -1 {
                g.span.span_rows.insert(-1, merge_enabled);
                for r in 0..g.rows {
                    g.row_props.entry(r).or_default().span = merge_enabled;
                }
            } else if row >= 0 && row < g.rows {
                g.span.span_rows.insert(row, merge_enabled);
                g.row_props.entry(row).or_default().span = merge_enabled;
            }
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_merge_col(
    grid_id: i64,
    col: i32,
    merge: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            let merge_enabled = merge != 0;
            if col == -1 {
                g.span.span_cols.insert(-1, merge_enabled);
                for c in &mut g.columns {
                    c.span = merge_enabled;
                }
            } else if col >= 0 && (col as usize) < g.columns.len() {
                g.span.span_cols.insert(col, merge_enabled);
                g.columns[col as usize].span = merge_enabled;
            }
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_outline_bar(
    grid_id: i64,
    style: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.outline.tree_indicator = style;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_outline_col(
    grid_id: i64,
    col: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.outline.tree_column = col;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_is_subtotal(
    grid_id: i64,
    row: i32,
    is_subtotal: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.row_props.entry(row).or_default().is_subtotal = is_subtotal != 0;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_is_subtotal(
    grid_id: i64,
    index: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_i32(
        GRID_MANAGER.with_grid(grid_id, |g| {
            if g.row_props.get(&index).map_or(false, |p| p.is_subtotal) {
                1
            } else {
                0
            }
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_row_outline_level(
    grid_id: i64,
    row: i32,
    level: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.row_props.entry(row).or_default().outline_level = level;
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_row_outline_level(
    grid_id: i64,
    index: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_i32(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.row_props.get(&index).map_or(0, |p| p.outline_level)
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_is_collapsed(
    grid_id: i64,
    row: i32,
    collapsed: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.row_props.entry(row).or_default().is_collapsed = collapsed != 0;
            volvoxgrid_engine::outline::refresh_visibility(g);
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_is_collapsed(
    grid_id: i64,
    index: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_i32(
        GRID_MANAGER.with_grid(grid_id, |g| {
            if g.row_props.get(&index).map_or(false, |p| p.is_collapsed) {
                1
            } else {
                0
            }
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_subtotal_position(
    grid_id: i64,
    position: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.outline.group_total_position = position;
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_resize_policy(
    grid_id: i64,
    mode: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.allow_user_resizing = mode;
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_row_data(
    grid_id: i64,
    row: i32,
    data: *const u8,
    data_len: i32,
    out_len: *mut i32,
) -> *mut u8 {
    let data = compat_bytes(data, data_len);
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            if row >= 0 && row < g.rows {
                if data.is_empty() {
                    g.set_row_data(row, None);
                } else {
                    g.set_row_data(row, Some(data.clone()));
                }
            }
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_row_data(grid_id: i64, row: i32, out_len: *mut i32) -> *mut u8 {
    match GRID_MANAGER.with_grid(grid_id, |g| {
        if row >= 0 && row < g.rows {
            g.get_row_data(row).unwrap_or_default()
        } else {
            Vec::new()
        }
    }) {
        Ok(data) => compat_alloc_bytes_response(data, out_len),
        Err(_) => {
            compat_set_out_len(out_len, 0);
            std::ptr::null_mut()
        }
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_row_sel(
    grid_id: i64,
    row_end: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.selection.row_end = row_end.clamp(g.fixed_rows, g.rows - 1);
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_col_sel(
    grid_id: i64,
    col_end: i32,
    out_len: *mut i32,
) -> *mut u8 {
    compat_status(
        GRID_MANAGER.with_grid(grid_id, |g| {
            g.selection.col_end = col_end.clamp(g.fixed_cols, g.cols - 1);
            g.mark_dirty();
        }),
        out_len,
    )
}

#[no_mangle]
pub extern "C" fn volvox_grid_resize_viewport_native(id: i64, w: i32, h: i32) -> i32 {
    if w <= 0 || h <= 0 {
        return -1;
    }
    match GRID_MANAGER.with_grid(id, |g| {
        g.resize_viewport(w, h);
        ensure_layout(g);
        g.mark_dirty();
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_pointer_down_native(
    id: i64,
    x: f32,
    y: f32,
    button: i32,
    modifier: i32,
    dbl_click: i32,
) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        volvoxgrid_engine::input::handle_pointer_down(g, x, y, button, modifier, dbl_click != 0);
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_pointer_move_native(
    id: i64,
    x: f32,
    y: f32,
    button: i32,
    modifier: i32,
) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        volvoxgrid_engine::input::handle_pointer_move(g, x, y, button, modifier);
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_pointer_up_native(
    id: i64,
    x: f32,
    y: f32,
    button: i32,
    modifier: i32,
) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        volvoxgrid_engine::input::handle_pointer_up(g, x, y, button, modifier);
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_scroll_native(id: i64, delta_x: f32, delta_y: f32) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        volvoxgrid_engine::input::handle_scroll(g, delta_x, delta_y);
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_key_down_native(id: i64, key_code: i32, modifier: i32) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        volvoxgrid_engine::input::handle_key_down(g, key_code, modifier);
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_key_press_native(id: i64, char_code: u32) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        volvoxgrid_engine::input::handle_key_press(g, char_code);
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_hover_mode_native(id: i64, mode: u32) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        g.selection.hover_mode = mode;
        if mode == volvoxgrid_engine::selection::HOVER_NONE {
            g.mouse_row = -1;
            g.mouse_col = -1;
        }
        g.mark_dirty_visual();
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_debug_overlay_native(id: i64, enabled: i32) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        g.debug_overlay = enabled != 0;
        g.layer_profiling = enabled != 0;
        g.mark_dirty();
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_scroll_blit_native(id: i64, enabled: i32) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        g.scroll_blit_enabled = enabled != 0;
        g.mark_dirty_visual();
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn volvox_grid_init() {
    register_volvox_grid_service_plugin(ActiveXPlugin);
}

#[no_mangle]
pub extern "C" fn volvox_grid_shutdown() {}

/// Render grid to a raw BGRA pixel buffer suitable for Windows DIB.
/// The caller provides the buffer; returns 0 on success, -1 on error.
/// Buffer must be at least w * h * 4 bytes, laid out top-to-bottom in BGRA order.
#[no_mangle]
pub extern "C" fn volvox_grid_render_bgra(id: i64, buf: *mut u8, w: i32, h: i32) -> i32 {
    if buf.is_null() || w <= 0 || h <= 0 {
        return -1;
    }
    let now = Instant::now();
    let result = GRID_MANAGER.with_grid(id, |g| {
        // Resize viewport to match
        g.resize_viewport(w, h);
        ensure_layout(g);
        g.debug_renderer_actual = RendererMode::RendererCpu as i32;
        g.debug_gpu_backend.clear();
        g.debug_gpu_present_mode.clear();
        g.debug_instance_count = 0;
        if g.debug_overlay {
            LAST_MEM_CALC.with(|last_mem_calc| {
                let mut last_mem_calc = last_mem_calc.borrow_mut();
                if last_mem_calc
                    .get(&id)
                    .map_or(true, |t| now.duration_since(*t) >= Duration::from_secs(10))
                {
                    g.debug_total_mem_bytes = g.heap_size_bytes() as i64;
                    last_mem_calc.insert(id, now);
                }
            });
        }
        let stride = w * 4;
        let len = (stride * h) as usize;
        let slice = unsafe { std::slice::from_raw_parts_mut(buf, len) };
        let frame_start = Instant::now();
        // Use per-grid renderer (no lock — thread-local).
        let (layer_times, zone_counts, text_cache_len) = RENDERERS.with(|r| {
            let mut map = r.borrow_mut();
            let renderer = map
                .entry(id)
                .or_insert_with(volvoxgrid_engine::render::Renderer::new);
            let (_dirty_rect, layer_times, zone_counts) = renderer.render(g, slice, w, h, stride);
            (layer_times, zone_counts, renderer.text_cache_len() as i32)
        });
        if g.layer_profiling {
            g.layer_times_us = layer_times;
            g.zone_cell_counts = zone_counts;
        }
        g.debug_text_cache_len = text_cache_len;
        let elapsed = frame_start.elapsed().as_secs_f32() * 1000.0;
        g.debug_frame_time_ms = elapsed;
        g.debug_fps = g.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
        g.clear_dirty();
        // Convert RGBA → BGRA in-place (swap R and B)
        for y in 0..h as usize {
            for x in 0..w as usize {
                let off = y * stride as usize + x * 4;
                slice.swap(off, off + 2); // R ↔ B
            }
        }
    });
    match result {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

// ---------------------------------------------------------------------------
// Convenience wrappers for grid-level color/style properties.
// These provide simple scalar C access to fields that otherwise require
// protobuf GridStyle messages.
// ---------------------------------------------------------------------------

macro_rules! style_color_accessors {
    ($set_name:ident, $get_name:ident, $field:ident) => {
        #[no_mangle]
        pub extern "C" fn $set_name(id: i64, color: u32) -> i32 {
            match GRID_MANAGER.with_grid(id, |g| {
                g.style.$field = color;
                g.mark_dirty();
            }) {
                Ok(()) => 0,
                Err(_) => -1,
            }
        }
        #[no_mangle]
        pub extern "C" fn $get_name(id: i64) -> u32 {
            GRID_MANAGER.with_grid(id, |g| g.style.$field).unwrap_or(0)
        }
    };
}

style_color_accessors!(
    volvox_grid_set_back_color,
    volvox_grid_get_back_color,
    back_color
);
style_color_accessors!(
    volvox_grid_set_fore_color,
    volvox_grid_get_fore_color,
    fore_color
);
style_color_accessors!(
    volvox_grid_set_grid_color,
    volvox_grid_get_grid_color,
    grid_color
);
style_color_accessors!(
    volvox_grid_set_grid_color_fixed,
    volvox_grid_get_grid_color_fixed,
    grid_color_fixed
);
style_color_accessors!(
    volvox_grid_set_back_color_fixed,
    volvox_grid_get_back_color_fixed,
    back_color_fixed
);
style_color_accessors!(
    volvox_grid_set_fore_color_fixed,
    volvox_grid_get_fore_color_fixed,
    fore_color_fixed
);
style_color_accessors!(
    volvox_grid_set_back_color_alternate,
    volvox_grid_get_back_color_alternate,
    back_color_alternate
);
style_color_accessors!(
    volvox_grid_set_tree_color_native,
    volvox_grid_get_tree_color,
    tree_color
);

#[no_mangle]
pub extern "C" fn volvox_grid_set_back_color_sel(id: i64, color: u32) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        g.selection.selection_style.back_color = Some(color);
        g.mark_dirty();
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_back_color_sel(id: i64) -> u32 {
    GRID_MANAGER
        .with_grid(id, |g| g.selection.selection_style.back_color.unwrap_or(0))
        .unwrap_or(0)
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_fore_color_sel(id: i64, color: u32) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        g.selection.selection_style.fore_color = Some(color);
        g.mark_dirty();
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_fore_color_sel(id: i64) -> u32 {
    GRID_MANAGER
        .with_grid(id, |g| g.selection.selection_style.fore_color.unwrap_or(0))
        .unwrap_or(0)
}

macro_rules! style_i32_accessors {
    ($set_name:ident, $get_name:ident, $field:ident) => {
        #[no_mangle]
        pub extern "C" fn $set_name(id: i64, value: i32) -> i32 {
            match GRID_MANAGER.with_grid(id, |g| {
                g.style.$field = value;
                g.mark_dirty();
            }) {
                Ok(()) => 0,
                Err(_) => -1,
            }
        }
        #[no_mangle]
        pub extern "C" fn $get_name(id: i64) -> i32 {
            GRID_MANAGER.with_grid(id, |g| g.style.$field).unwrap_or(0)
        }
    };
}

style_i32_accessors!(
    volvox_grid_set_grid_lines_native,
    volvox_grid_get_grid_lines,
    grid_lines
);
style_i32_accessors!(
    volvox_grid_set_grid_lines_fixed_native,
    volvox_grid_get_grid_lines_fixed,
    grid_lines_fixed
);

#[no_mangle]
pub extern "C" fn volvox_grid_set_font_size(id: i64, size: f32) -> i32 {
    match GRID_MANAGER.with_grid(id, |g| {
        g.style.font_size = size;
        g.mark_dirty();
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}
#[no_mangle]
pub extern "C" fn volvox_grid_get_font_size(id: i64) -> f32 {
    GRID_MANAGER
        .with_grid(id, |g| g.style.font_size)
        .unwrap_or(0.0)
}

#[no_mangle]
pub extern "C" fn volvox_grid_set_font_name(id: i64, ptr: *const u8, len: i32) -> i32 {
    if ptr.is_null() || len < 0 {
        return -1;
    }
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len as usize) };
    let name = match std::str::from_utf8(bytes) {
        Ok(v) => v,
        Err(_) => return -1,
    };
    match GRID_MANAGER.with_grid(id, |g| {
        g.style.font_name = name.to_string();
        g.mark_dirty();
    }) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn volvox_grid_get_font_name(id: i64, out_len: *mut i32) -> *mut u8 {
    let name = GRID_MANAGER
        .with_grid(id, |g| g.style.font_name.clone())
        .unwrap_or_default();
    let bytes = name.into_bytes();
    if !out_len.is_null() {
        unsafe {
            *out_len = bytes.len() as i32;
        }
    }
    alloc_payload_with_header(bytes)
}

// ---------------------------------------------------------------------------
// Custom text renderer (FFI callback-based)
// ---------------------------------------------------------------------------

/// C callback type for measuring text.
/// Returns measured width via `*out_width` and height via `*out_height`.
///
/// Parameters:
///   text_ptr/text_len       — UTF-8 text bytes (NOT null-terminated)
///   font_name_ptr/font_name_len — UTF-8 font family name
///   font_size               — font size in pixels
///   bold, italic            — style flags (0 or 1)
///   max_width               — wrapping constraint, -1.0 means no constraint
///   out_width, out_height   — output pointers
///   user_data               — opaque pointer passed through from registration
type VvMeasureTextFn = unsafe extern "C" fn(
    text_ptr: *const u8,
    text_len: i32,
    font_name_ptr: *const u8,
    font_name_len: i32,
    font_size: f32,
    bold: i32,
    italic: i32,
    max_width: f32,
    out_width: *mut f32,
    out_height: *mut f32,
    user_data: *mut std::ffi::c_void,
);

/// C callback type for rendering text into an RGBA pixel buffer.
/// Returns rendered text width.
///
/// Parameters:
///   buffer/buf_width/buf_height/stride — target RGBA pixel buffer
///   x, y                    — draw position
///   clip_w, clip_h          — clip rectangle size
///   text_ptr/text_len       — UTF-8 text bytes
///   font_name_ptr/font_name_len — UTF-8 font family name
///   font_size               — font size in pixels
///   bold, italic            — style flags (0 or 1)
///   color                   — 0xAARRGGBB
///   max_width               — wrapping constraint, -1.0 means no constraint
///   user_data               — opaque pointer
type VvRenderTextFn = unsafe extern "C" fn(
    buffer: *mut u8,
    buf_width: i32,
    buf_height: i32,
    stride: i32,
    x: i32,
    y: i32,
    clip_w: i32,
    clip_h: i32,
    text_ptr: *const u8,
    text_len: i32,
    font_name_ptr: *const u8,
    font_name_len: i32,
    font_size: f32,
    bold: i32,
    italic: i32,
    color: u32,
    max_width: f32,
    user_data: *mut std::ffi::c_void,
) -> f32;

/// Wraps C function-pointer callbacks as a `TextRenderer`.
struct FfiTextRenderer {
    measure_fn: VvMeasureTextFn,
    render_fn: VvRenderTextFn,
    user_data: *mut std::ffi::c_void,
}

// The C side is responsible for thread safety of user_data.
unsafe impl Send for FfiTextRenderer {}

impl volvoxgrid_engine::text::TextRenderer for FfiTextRenderer {
    fn measure_text(
        &mut self,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> (f32, f32) {
        let mut out_w: f32 = 0.0;
        let mut out_h: f32 = 0.0;
        let mw = max_width.unwrap_or(-1.0);
        unsafe {
            (self.measure_fn)(
                text.as_ptr(),
                text.len() as i32,
                font_name.as_ptr(),
                font_name.len() as i32,
                font_size,
                bold as i32,
                italic as i32,
                mw,
                &mut out_w,
                &mut out_h,
                self.user_data,
            );
        }
        (out_w, out_h)
    }

    fn render_text(
        &mut self,
        buffer_pixels: &mut [u8],
        buf_width: i32,
        buf_height: i32,
        stride: i32,
        x: i32,
        y: i32,
        _clip_x: i32,
        _clip_y: i32,
        clip_w: i32,
        clip_h: i32,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        color: u32,
        max_width: Option<f32>,
    ) -> f32 {
        let mw = max_width.unwrap_or(-1.0);
        unsafe {
            (self.render_fn)(
                buffer_pixels.as_mut_ptr(),
                buf_width,
                buf_height,
                stride,
                x,
                y,
                clip_w,
                clip_h,
                text.as_ptr(),
                text.len() as i32,
                font_name.as_ptr(),
                font_name.len() as i32,
                font_size,
                bold as i32,
                italic as i32,
                color,
                mw,
                self.user_data,
            )
        }
    }
}

use std::cell::RefCell;
use std::collections::HashMap;

thread_local! {
    /// Per-grid `Renderer` instances.  Stored in thread-local storage because
    /// ActiveX runs in a COM Single-Threaded Apartment — no locking required.
    static RENDERERS: RefCell<HashMap<i64, volvoxgrid_engine::render::Renderer>> =
        RefCell::new(HashMap::new());
    static LAST_MEM_CALC: RefCell<HashMap<i64, Instant>> = RefCell::new(HashMap::new());
}

/// Register a custom text renderer for a grid, or clear it.
///
/// When `measure_fn` and `render_fn` are both non-null, a custom FFI text
/// renderer is created and associated with the grid. All subsequent
/// `volvox_grid_render_bgra` calls for that grid will use the custom
/// callbacks for text measurement and rendering.
///
/// Pass null for both function pointers to clear the custom renderer and
/// revert to the default cosmic-text engine.
#[no_mangle]
pub extern "C" fn volvox_grid_set_text_renderer(
    grid_id: i64,
    measure_fn: Option<VvMeasureTextFn>,
    render_fn: Option<VvRenderTextFn>,
    user_data: *mut std::ffi::c_void,
) -> i32 {
    RENDERERS.with(|r| {
        let mut map = r.borrow_mut();
        let renderer = map
            .entry(grid_id)
            .or_insert_with(volvoxgrid_engine::render::Renderer::new);
        match (measure_fn, render_fn) {
            (Some(mf), Some(rf)) => {
                let ffi = FfiTextRenderer {
                    measure_fn: mf,
                    render_fn: rf,
                    user_data,
                };
                renderer.set_custom_text_renderer(Some(Box::new(ffi)));

                // Also update the grid's text engine for measurement (auto-size)
                let ffi_for_grid = FfiTextRenderer {
                    measure_fn: mf,
                    render_fn: rf,
                    user_data,
                };
                let _ = GRID_MANAGER.with_grid(grid_id, |grid| {
                    grid.ensure_text_engine()
                        .set_external_renderer(Some(Box::new(ffi_for_grid)));
                });
            }
            _ => {
                renderer.set_custom_text_renderer(None);
                let _ = GRID_MANAGER.with_grid(grid_id, |grid| {
                    if let Some(te) = &mut grid.text_engine {
                        te.set_external_renderer(None);
                    }
                });
            }
        }
    });
    0
}
