use crate::event::GridEventData;
use crate::grid::VolvoxGrid;
use crate::proto::volvoxgrid::v1 as pb;
#[cfg(not(target_arch = "wasm32"))]
use std::time::Instant;
#[cfg(target_arch = "wasm32")]
use web_time::Instant;

/// Result of hit-testing a pixel coordinate
#[derive(Clone, Debug)]
pub struct HitTestResult {
    pub row: i32,
    pub col: i32,
    pub area: HitArea,
    pub x_in_cell: f32,
    pub y_in_cell: f32,
}

#[derive(Clone, Debug, PartialEq)]
pub enum HitArea {
    Cell,           // regular cell content
    FixedRow,       // fixed row header
    FixedCol,       // fixed col header
    FixedCorner,    // top-left fixed corner
    ColBorder,      // between column headers (resize)
    RowBorder,      // between row headers (resize)
    OutlineButton,  // outline +/- button
    CheckBox,       // checkbox in cell
    DropdownButton, // dropdown button
    DropdownList,   // dropdown list
    HScrollBar,     // horizontal scrollbar area (track, thumb, arrows)
    VScrollBar,     // vertical scrollbar area (track, thumb, arrows)
    FastScroll,     // fast scroll touch zone (right edge)
    Background,     // empty area beyond grid
}

/// Optional behavior switches used by host integrations that need to intercept
/// cancelable events before applying grid mutations.
#[derive(Clone, Copy, Debug)]
pub struct InputBehavior {
    pub allow_begin_edit: bool,
    pub allow_header_sort: bool,
}

impl Default for InputBehavior {
    fn default() -> Self {
        Self {
            allow_begin_edit: true,
            allow_header_sort: true,
        }
    }
}

const HEADER_REORDER_LONG_PRESS_MS: u128 = 350;

fn header_resize_hit_half_width(grid: &VolvoxGrid) -> i32 {
    let w = grid.style.header_resize_handle.hit_width_px.max(1);
    // Symmetric tolerance around the border center line.
    (w + 1) / 2
}

fn type_ahead_delay_ms(grid: &VolvoxGrid) -> u128 {
    let raw = grid.type_ahead_delay;
    if raw <= 0 {
        return 2000;
    }
    // The original API used seconds. Our RPC currently carries integers, so accept
    // both seconds-like and milliseconds-like values.
    if raw <= 10 {
        (raw as u128) * 1000
    } else {
        raw as u128
    }
}

fn clear_type_ahead_buffer(grid: &mut VolvoxGrid, emit_end_event: bool) {
    let had_buffer = !grid.type_ahead_buffer.is_empty();
    if had_buffer && emit_end_event {
        grid.events.push(GridEventData::TypeAheadEnded);
    }
    crate::search::type_ahead_clear_buffer(grid);
    grid.type_ahead_last_input = None;
}

fn visible_top_left_for_scroll(grid: &mut VolvoxGrid, scroll_x: f32, scroll_y: f32) -> (i32, i32) {
    grid.ensure_layout();

    let first_scrollable_row = grid.first_scrollable_row().clamp(0, grid.rows);
    let top_row = if first_scrollable_row >= grid.rows {
        first_scrollable_row.saturating_sub(1).max(0)
    } else {
        let (first, _) =
            grid.layout
                .visible_rows(scroll_y, grid.viewport_height, first_scrollable_row);
        first.clamp(first_scrollable_row, grid.rows - 1)
    };

    let first_scrollable_col = grid.first_scrollable_col().clamp(0, grid.cols);
    let left_col = if first_scrollable_col >= grid.cols {
        first_scrollable_col.saturating_sub(1).max(0)
    } else {
        let (first, _) =
            grid.layout
                .visible_cols(scroll_x, grid.viewport_width, first_scrollable_col);
        first.clamp(first_scrollable_col, grid.cols - 1)
    };

    (top_row, left_col)
}

fn scroll_by_with_events(grid: &mut VolvoxGrid, dx: f32, dy: f32) -> bool {
    let old = visible_top_left_for_scroll(grid, grid.scroll.scroll_x, grid.scroll.scroll_y);

    let mut next_scroll = grid.scroll.clone();
    next_scroll.scroll_by(dx, dy);
    let predicted = visible_top_left_for_scroll(grid, next_scroll.scroll_x, next_scroll.scroll_y);
    if old != predicted {
        grid.events.push(GridEventData::BeforeScroll {
            old_top_row: old.0,
            old_left_col: old.1,
            new_top_row: predicted.0,
            new_left_col: predicted.1,
        });
    }

    grid.scroll.scroll_by(dx, dy);

    let actual = visible_top_left_for_scroll(grid, grid.scroll.scroll_x, grid.scroll.scroll_y);
    if old != actual {
        grid.events.push(GridEventData::AfterScroll {
            old_top_row: old.0,
            old_left_col: old.1,
            new_top_row: actual.0,
            new_left_col: actual.1,
        });
        true
    } else {
        false
    }
}

fn scroll_to_with_events(grid: &mut VolvoxGrid, x: f32, y: f32) -> bool {
    let old = visible_top_left_for_scroll(grid, grid.scroll.scroll_x, grid.scroll.scroll_y);

    let mut next_scroll = grid.scroll.clone();
    next_scroll.scroll_to(x, y);
    let predicted = visible_top_left_for_scroll(grid, next_scroll.scroll_x, next_scroll.scroll_y);
    if old != predicted {
        grid.events.push(GridEventData::BeforeScroll {
            old_top_row: old.0,
            old_left_col: old.1,
            new_top_row: predicted.0,
            new_left_col: predicted.1,
        });
    }

    grid.scroll.scroll_to(x, y);

    let actual = visible_top_left_for_scroll(grid, grid.scroll.scroll_x, grid.scroll.scroll_y);
    if old != actual {
        grid.events.push(GridEventData::AfterScroll {
            old_top_row: old.0,
            old_left_col: old.1,
            new_top_row: actual.0,
            new_left_col: actual.1,
        });
        true
    } else {
        false
    }
}

fn begin_edit_from_input(grid: &mut VolvoxGrid, row: i32, col: i32) {
    if !grid.can_begin_edit(row, col, false) {
        return;
    }

    let dropdown_list = grid.active_dropdown_list(row, col);
    grid.events.push(GridEventData::BeforeEdit { row, col });

    if dropdown_list.trim() == "..." {
        grid.events
            .push(GridEventData::CellButtonClick { row, col });
        return;
    }

    let stored_text = grid.cells.get_text(row, col).to_string();
    let display_text = grid.get_display_text(row, col);

    grid.edit.start_edit(row, col, &display_text);
    grid.edit.parse_dropdown_items(&dropdown_list);
    // Initialize dropdown index from stored translated value (preferred), or display text.
    if !dropdown_list.is_empty() {
        for i in 0..grid.edit.dropdown_count() {
            if (!stored_text.is_empty() && grid.edit.get_dropdown_data(i) == stored_text)
                || grid.edit.get_dropdown_item(i) == display_text
            {
                grid.edit.set_dropdown_index(i);
                break;
            }
        }
    }
    if !dropdown_list.is_empty() {
        grid.events.push(GridEventData::DropdownOpened);
    }
    grid.events.push(GridEventData::StartEdit { row, col });
}

/// Map a touch Y coordinate to a target row for fast scroll and apply it.
fn update_fast_scroll_target(grid: &mut VolvoxGrid, y: f32) {
    grid.ensure_layout();
    let s = grid.scale.max(0.01);
    let vert_inset = 12.0 * s;
    let vp_h = grid.viewport_height as f32;
    let track_top = vert_inset;
    let track_bottom = (vp_h - vert_inset).max(track_top + 1.0);
    let track_height = track_bottom - track_top;

    let ratio = ((y - track_top) / track_height).clamp(0.0, 1.0);
    let fixed = grid.fixed_rows;
    let data_rows = grid.rows - fixed;
    if data_rows <= 1 {
        return;
    }
    let target = fixed + (ratio * (data_rows - 1) as f32).round() as i32;
    let target = target.clamp(fixed, grid.rows - 1);
    if target == grid.fast_scroll_target_row {
        return;
    }
    grid.fast_scroll_target_row = target;
    grid.set_top_row(target);
    grid.mark_dirty();
}

/// Resolve the current display position for a logical column key.
fn col_display_pos(grid: &VolvoxGrid, logical_col: i32) -> i32 {
    grid.col_positions
        .iter()
        .position(|&c| c == logical_col)
        .map(|p| p as i32)
        .unwrap_or(logical_col)
}

/// Update active column-drag hover target and insertion gap.
///
/// `col_drag_insert_pos` stores an insertion gap index in display order:
/// 0..=cols, where `cols` means append at end.
fn update_col_drag_target(grid: &mut VolvoxGrid, x: f32, y: f32) {
    let hit = hit_test(grid, x, y);
    let mut next_target = -1;
    let mut next_insert = -1;

    if hit.col >= 0 && hit.col < grid.cols {
        next_target = hit.col;
        let target_pos = col_display_pos(grid, hit.col);
        let col_width = grid.get_col_width(hit.col).max(1) as f32;
        let right_half = hit.x_in_cell >= col_width * 0.5;
        next_insert = if right_half {
            target_pos + 1
        } else {
            target_pos
        }
        .clamp(0, grid.cols);
    } else if grid.cols > 0 {
        // Keep insertion targeting intuitive when dragging outside cell bands:
        // clamp to start/end based on horizontal pointer position.
        if x <= 0.0 {
            next_insert = 0;
            next_target = grid.col_at_position(0);
        } else if x >= grid.viewport_width as f32 {
            next_insert = grid.cols;
            next_target = grid.col_at_position(grid.cols - 1);
        }
    }

    if next_target != grid.col_drag_target || next_insert != grid.col_drag_insert_pos {
        grid.col_drag_moved = true;
    }
    grid.col_drag_target = next_target;
    grid.col_drag_insert_pos = next_insert;
}

fn clear_col_drag_active(grid: &mut VolvoxGrid) {
    grid.col_drag_active = false;
    grid.col_drag_source = -1;
    grid.col_drag_target = -1;
    grid.col_drag_insert_pos = -1;
    grid.col_drag_moved = false;
}

fn clear_col_drag_pending(grid: &mut VolvoxGrid) {
    grid.col_drag_pending = false;
    grid.col_drag_pending_source = -1;
    grid.col_drag_pending_can_sort = false;
    grid.col_drag_pending_since = None;
}

fn clear_col_drag_state(grid: &mut VolvoxGrid) {
    clear_col_drag_active(grid);
    clear_col_drag_pending(grid);
}

fn col_drag_pending_elapsed_ms(grid: &VolvoxGrid) -> u128 {
    grid.col_drag_pending_since
        .map(|since| Instant::now().duration_since(since).as_millis())
        .unwrap_or(0)
}

fn maybe_activate_pending_col_drag(grid: &mut VolvoxGrid, x: f32, y: f32) -> bool {
    if !grid.col_drag_pending || col_drag_pending_elapsed_ms(grid) < HEADER_REORDER_LONG_PRESS_MS {
        return false;
    }
    let source = grid.col_drag_pending_source;
    clear_col_drag_pending(grid);
    if source < 0 || source >= grid.cols {
        return false;
    }

    let source_pos = col_display_pos(grid, source);
    grid.col_drag_active = true;
    grid.col_drag_source = source;
    grid.col_drag_target = source;
    grid.col_drag_insert_pos = source_pos.clamp(0, grid.cols);
    grid.col_drag_moved = false;
    update_col_drag_target(grid, x, y);
    true
}

fn show_dropdown_button_for_cell(grid: &VolvoxGrid, row: i32, col: i32) -> bool {
    if grid.edit_trigger_mode <= 0 {
        return false;
    }
    let list = grid.active_dropdown_list(row, col);
    if list.is_empty() {
        return false;
    }
    match grid.dropdown_trigger {
        b if b == pb::DropdownTrigger::DropdownAlways as i32 => true,
        b if b == pb::DropdownTrigger::DropdownOnEdit as i32 => {
            grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col
        }
        /* ActiveX compatibility: show on current cell when dropdown lists exist. */
        3 => grid.selection.row == row && grid.selection.col == col,
        _ => false,
    }
}

fn dropdown_button_rect(cx: i32, cy: i32, cw: i32, ch: i32) -> Option<(i32, i32, i32, i32)> {
    if cw <= 2 || ch <= 2 {
        return None;
    }
    let mut bw = (ch - 2).clamp(12, 18);
    bw = bw.min((cw - 2).max(0));
    let bh = (ch - 2).max(0);
    if bw <= 0 || bh <= 0 {
        return None;
    }
    let bx = cx + cw - bw - 1;
    let by = cy + 1;
    Some((bx, by, bw, bh))
}

/// Scrollbar size in pixels (matches render.rs SB_SIZE).
const SB_SIZE: i32 = 16;

/// Computed scrollbar layout geometry, replicating the logic from `render_scroll_bars`.
struct ScrollBarGeometry {
    show_h: bool,
    show_v: bool,
    // Horizontal bar
    h_bar_y: i32,
    h_left_arrow_x: i32,
    h_right_arrow_x: i32,
    h_track_x: i32,
    h_track_w: i32,
    h_thumb_x: i32,
    h_thumb_w: i32,
    h_thumb_range: i32,
    h_max_scroll: f32,
    // Vertical bar
    v_bar_x: i32,
    v_top_arrow_y: i32,
    v_bot_arrow_y: i32,
    v_track_y: i32,
    v_track_h: i32,
    v_thumb_y: i32,
    v_thumb_h: i32,
    v_thumb_range: i32,
    v_max_scroll: f32,
}

/// Compute scrollbar geometry matching the renderer's `render_scroll_bars` layout.
fn compute_scrollbar_geometry(grid: &VolvoxGrid) -> ScrollBarGeometry {
    let buf_w = grid.viewport_width;
    let buf_h = grid.viewport_height;

    let allow_h = grid.scroll_bars == pb::ScrollBarsMode::ScrollbarHorizontal as i32
        || grid.scroll_bars == pb::ScrollBarsMode::ScrollbarBoth as i32;
    let allow_v = grid.scroll_bars == pb::ScrollBarsMode::ScrollbarVertical as i32
        || grid.scroll_bars == pb::ScrollBarsMode::ScrollbarBoth as i32;

    let fixed_height = grid.layout.row_pos(grid.fixed_rows);
    let fixed_width = grid.layout.col_pos(grid.fixed_cols);
    let pinned_height = grid.pinned_top_height() + grid.pinned_bottom_height();
    let pinned_width = grid.pinned_left_width() + grid.pinned_right_width();

    let compute_max_scroll = |view_w: i32, view_h: i32| -> (f32, f32) {
        let mx = (grid.layout.total_width - view_w + fixed_width + pinned_width).max(0) as f32;
        let my = (grid.layout.total_height - view_h + fixed_height + pinned_height).max(0) as f32;
        (mx, my)
    };

    // Resolve bar visibility iteratively (same as renderer)
    let mut show_h = false;
    let mut show_v = false;
    if buf_w > SB_SIZE && buf_h > SB_SIZE {
        for _ in 0..3 {
            let view_w = (buf_w - if show_v { SB_SIZE } else { 0 }).max(1);
            let view_h = (buf_h - if show_h { SB_SIZE } else { 0 }).max(1);
            let (mx, my) = compute_max_scroll(view_w, view_h);
            let next_h = allow_h && mx > 0.0;
            let next_v = allow_v && my > 0.0;
            if next_h == show_h && next_v == show_v {
                break;
            }
            show_h = next_h;
            show_v = next_v;
        }
    }

    let view_w = (buf_w - if show_v { SB_SIZE } else { 0 }).max(1);
    let view_h = (buf_h - if show_h { SB_SIZE } else { 0 }).max(1);
    let (max_x, max_y) = compute_max_scroll(view_w, view_h);
    let scroll_x = grid.scroll.scroll_x.clamp(0.0, max_x);
    let scroll_y = grid.scroll.scroll_y.clamp(0.0, max_y);

    // Horizontal bar geometry
    let h_bar_y;
    let h_left_arrow_x;
    let h_right_arrow_x;
    let h_track_x;
    let h_track_w;
    let h_thumb_x;
    let h_thumb_w;
    let h_thumb_range;
    if show_h {
        let x = 0;
        let w = (buf_w - if show_v { SB_SIZE } else { 0 }).max(SB_SIZE);
        h_bar_y = buf_h - SB_SIZE;
        h_left_arrow_x = x;
        h_right_arrow_x = x + w - SB_SIZE;
        h_track_x = x + SB_SIZE;
        h_track_w = (w - SB_SIZE * 2).max(0);
        if h_track_w > 0 {
            let mut tw = if max_x > 0.0 {
                ((view_w as f32 / (view_w as f32 + max_x)) * h_track_w as f32).round() as i32
            } else {
                h_track_w
            };
            tw = tw.clamp(12, h_track_w.max(12)).min(h_track_w);
            h_thumb_w = tw;
            h_thumb_range = (h_track_w - tw).max(0);
            let thumb_off = if max_x > 0.0 && h_thumb_range > 0 {
                ((scroll_x / max_x) * h_thumb_range as f32).round() as i32
            } else {
                0
            };
            h_thumb_x = h_track_x + thumb_off;
        } else {
            h_thumb_w = 0;
            h_thumb_range = 0;
            h_thumb_x = h_track_x;
        }
    } else {
        h_bar_y = 0;
        h_left_arrow_x = 0;
        h_right_arrow_x = 0;
        h_track_x = 0;
        h_track_w = 0;
        h_thumb_x = 0;
        h_thumb_w = 0;
        h_thumb_range = 0;
    }

    // Vertical bar geometry
    let v_bar_x;
    let v_top_arrow_y;
    let v_bot_arrow_y;
    let v_track_y;
    let v_track_h;
    let v_thumb_y;
    let v_thumb_h;
    let v_thumb_range;
    if show_v {
        let y = 0;
        let h = (buf_h - if show_h { SB_SIZE } else { 0 }).max(SB_SIZE);
        v_bar_x = buf_w - SB_SIZE;
        v_top_arrow_y = y;
        v_bot_arrow_y = y + h - SB_SIZE;
        v_track_y = y + SB_SIZE;
        v_track_h = (h - SB_SIZE * 2).max(0);
        if v_track_h > 0 {
            let mut th = if max_y > 0.0 {
                ((view_h as f32 / (view_h as f32 + max_y)) * v_track_h as f32).round() as i32
            } else {
                v_track_h
            };
            th = th.clamp(12, v_track_h.max(12)).min(v_track_h);
            v_thumb_h = th;
            v_thumb_range = (v_track_h - th).max(0);
            let thumb_off = if max_y > 0.0 && v_thumb_range > 0 {
                ((scroll_y / max_y) * v_thumb_range as f32).round() as i32
            } else {
                0
            };
            v_thumb_y = v_track_y + thumb_off;
        } else {
            v_thumb_h = 0;
            v_thumb_range = 0;
            v_thumb_y = v_track_y;
        }
    } else {
        v_bar_x = 0;
        v_top_arrow_y = 0;
        v_bot_arrow_y = 0;
        v_track_y = 0;
        v_track_h = 0;
        v_thumb_y = 0;
        v_thumb_h = 0;
        v_thumb_range = 0;
    }

    ScrollBarGeometry {
        show_h,
        show_v,
        h_bar_y,
        h_left_arrow_x,
        h_right_arrow_x,
        h_track_x,
        h_track_w,
        h_thumb_x,
        h_thumb_w,
        h_thumb_range,
        h_max_scroll: max_x,
        v_bar_x,
        v_top_arrow_y,
        v_bot_arrow_y,
        v_track_y,
        v_track_h,
        v_thumb_y,
        v_thumb_h,
        v_thumb_range,
        v_max_scroll: max_y,
    }
}

/// Perform hit testing: pixel coordinates -> grid cell + area
pub fn hit_test(grid: &VolvoxGrid, px: f32, py: f32) -> HitTestResult {
    let px = if grid.right_to_left {
        (grid.viewport_width as f32 - px).max(0.0)
    } else {
        px
    };
    let layout = &grid.layout;
    if !layout.valid {
        return HitTestResult {
            row: -1,
            col: -1,
            area: HitArea::Background,
            x_in_cell: 0.0,
            y_in_cell: 0.0,
        };
    }

    // Check active dropdown list first — it overlays everything (including scrollbars).
    if let Some(_idx) = grid.dropdown_hit_index(px, py) {
        let row = grid.edit.edit_row;
        let col = grid.edit.edit_col;
        return HitTestResult {
            row,
            col,
            area: HitArea::DropdownList,
            x_in_cell: 0.0, // Not relevant for dropdown hit
            y_in_cell: 0.0,
        };
    }

    // Check scrollbar areas first — they overlay the grid content.
    {
        let sbg = compute_scrollbar_geometry(grid);
        let ix = px as i32;
        let iy = py as i32;
        if sbg.show_v && ix >= sbg.v_bar_x && ix < sbg.v_bar_x + SB_SIZE {
            // Exclude the corner area when both bars are shown
            let v_bottom = if sbg.show_h {
                grid.viewport_height - SB_SIZE
            } else {
                grid.viewport_height
            };
            if iy >= 0 && iy < v_bottom {
                return HitTestResult {
                    row: -1,
                    col: -1,
                    area: HitArea::VScrollBar,
                    x_in_cell: px,
                    y_in_cell: py,
                };
            }
        }
        if sbg.show_h && iy >= sbg.h_bar_y && iy < sbg.h_bar_y + SB_SIZE {
            let h_right = if sbg.show_v {
                grid.viewport_width - SB_SIZE
            } else {
                grid.viewport_width
            };
            if ix >= 0 && ix < h_right {
                return HitTestResult {
                    row: -1,
                    col: -1,
                    area: HitArea::HScrollBar,
                    x_in_cell: px,
                    y_in_cell: py,
                };
            }
        }
    }

    // Check fast scroll touch zone (right edge, 44dp wide)
    if grid.fast_scroll_enabled && grid.rows > grid.fixed_rows + 1 {
        let s = grid.scale.max(0.01);
        let touch_w = (44.0 * s) as i32;
        let right_inset = (8.0 * s) as i32;
        let vert_inset = (12.0 * s) as i32;
        let zone_right = grid.viewport_width - right_inset + (8.0 * s) as i32;
        let zone_left = (zone_right - touch_w).max(0);
        let zone_top = (vert_inset as f32 * 0.5) as i32;
        let zone_bottom = grid.viewport_height - zone_top;
        let ix = px as i32;
        let iy = py as i32;
        if ix >= zone_left && ix < zone_right && iy >= zone_top && iy < zone_bottom {
            return HitTestResult {
                row: -1,
                col: -1,
                area: HitArea::FastScroll,
                x_in_cell: px,
                y_in_cell: py,
            };
        }
    }

    let scroll_x = grid.scroll.scroll_x;
    let scroll_y = grid.scroll.scroll_y;

    // Determine if click is in fixed area
    let fixed_row_height = layout.row_pos(grid.fixed_rows);
    let frozen_bottom = layout.row_pos(grid.fixed_rows + grid.frozen_rows);
    let fixed_col_end = grid.fixed_cols + grid.frozen_cols;
    let fixed_col_right = layout.col_pos(fixed_col_end);
    let fixed_col_width = layout.col_pos(grid.fixed_cols);
    let pinned_left_w = grid.pinned_left_width();
    let pinned_right_w = grid.pinned_right_width();
    let vp_w = grid.viewport_width;
    let pinned_top_h = grid.pinned_top_height();
    let pinned_bottom_h = grid.pinned_bottom_height();
    let vp_h = grid.viewport_height;

    let in_fixed_row_area = py < fixed_row_height as f32;
    let in_fixed_col_area = px < fixed_col_width as f32;

    let px_i = px as i32;
    let py_i = py as i32;

    // Viewport row zones (top to bottom):
    //   0..frozen_bottom            → fixed/frozen rows (no scroll)
    //   frozen_bottom..+pinned_top  → pinned-top rows
    //   ..vp_h - pinned_bottom      → scrollable area
    //   vp_h - pinned_bottom..vp_h  → pinned-bottom rows
    let pin_top_start = frozen_bottom;
    let pin_top_end = frozen_bottom + pinned_top_h;
    let pin_bot_start = vp_h - pinned_bottom_h;

    // Find row — check pinned areas first, then scrollable with offset
    let mut row;
    let mut effective_y;
    let mut hit_pinned = false;

    if in_fixed_row_area {
        effective_y = py_i;
        row = layout.row_at_y(effective_y);
    } else if pinned_top_h > 0 && py_i >= pin_top_start && py_i < pin_top_end {
        // Hit a top-pinned row
        let mut y = pin_top_start;
        row = -1;
        for &r in &grid.pinned_rows_top {
            let rh = grid.row_height(r);
            if py_i >= y && py_i < y + rh {
                row = r;
                break;
            }
            y += rh;
        }
        effective_y = py_i; // not used for layout lookups in pinned area
        hit_pinned = true;
    } else if pinned_bottom_h > 0 && py_i >= pin_bot_start && py_i < vp_h {
        // Hit a bottom-pinned row
        let mut y = pin_bot_start;
        row = -1;
        for &r in &grid.pinned_rows_bottom {
            let rh = grid.row_height(r);
            if py_i >= y && py_i < y + rh {
                row = r;
                break;
            }
            y += rh;
        }
        effective_y = py_i;
        hit_pinned = true;
    } else {
        // Scrollable area: renderer places cells at row_pos - scroll_y + pinned_top_h,
        // so the inverse is content_y = screen_y + scroll_y - pinned_top_h.
        effective_y = py_i + scroll_y as i32 - pinned_top_h;
        row = layout.row_at_y(effective_y);
        // Skip pinned rows — they've been removed from the scrollable layout
        // (0 height), so row_at_y won't land on them, but just in case:
        if grid.is_row_pinned(row) != 0 {
            row = -1;
        }
    }

    // Sticky row override: check if py falls within a sticky overlay row.
    // Uses cascading thresholds matching VisibleRange::compute logic.
    if !hit_pinned && !in_fixed_row_area {
        // pb already imported at file top as v1
        let fixed_row_end = grid.fixed_rows + grid.frozen_rows;
        let scrollable_top = frozen_bottom + pinned_top_h;
        let scrollable_bottom = vp_h - pinned_bottom_h;

        // Collect and sort sticky-top candidates (ascending)
        let mut top_cands: Vec<i32> = grid
            .sticky_rows
            .iter()
            .filter(|(&r, &e)| {
                let both = e == pb::StickyEdge::StickyBoth as i32;
                (both || e == pb::StickyEdge::StickyTop as i32)
                    && grid.is_row_pinned(r) == 0
                    && r >= fixed_row_end
            })
            .map(|(&r, _)| r)
            .collect();
        top_cands.sort_unstable();

        let mut sticky_y = pin_top_end;
        let mut threshold_top = scrollable_top;
        for sr in top_cands {
            let screen_y = layout.row_pos(sr) - scroll_y as i32 + pinned_top_h;
            let rh = grid.row_height(sr);
            if screen_y < threshold_top {
                // This row is stuck at the top
                if py_i >= sticky_y && py_i < sticky_y + rh {
                    row = sr;
                    effective_y = py_i;
                    break;
                }
                sticky_y += rh;
                threshold_top += rh;
            }
        }

        // Collect and sort sticky-bottom candidates (descending)
        let mut bot_cands: Vec<i32> = grid
            .sticky_rows
            .iter()
            .filter(|(&r, &e)| {
                let both = e == pb::StickyEdge::StickyBoth as i32;
                (both || e == pb::StickyEdge::StickyBottom as i32)
                    && grid.is_row_pinned(r) == 0
                    && r >= fixed_row_end
            })
            .map(|(&r, _)| r)
            .collect();
        bot_cands.sort_unstable_by(|a, b| b.cmp(a));

        let mut sticky_y = pin_bot_start;
        let mut threshold_bottom = scrollable_bottom;
        for sr in bot_cands {
            let screen_y = layout.row_pos(sr) - scroll_y as i32 + pinned_top_h;
            let rh = grid.row_height(sr);
            if screen_y + rh > threshold_bottom {
                sticky_y -= rh;
                if py_i >= sticky_y && py_i < sticky_y + rh {
                    row = sr;
                    effective_y = py_i;
                    break;
                }
                threshold_bottom -= rh;
            }
        }
    }

    // Find col — handle pinned zones first, then scrollable area.
    let pin_left_start = fixed_col_right;
    let pin_left_end = fixed_col_right + pinned_left_w;
    let pin_right_start = vp_w - pinned_right_w;
    let mut hit_pinned_col = false;
    let mut effective_x = if in_fixed_col_area {
        px_i
    } else {
        px_i + scroll_x as i32
    };
    let mut col = -1;

    if in_fixed_col_area {
        col = layout.col_at_x(effective_x);
    } else if pinned_left_w > 0 && px_i >= pin_left_start && px_i < pin_left_end {
        hit_pinned_col = true;
        effective_x = px_i;
        let mut x = pin_left_start;
        for &pc in &grid.pinned_cols_left {
            let cw = grid.col_width(pc);
            if cw <= 0 {
                continue;
            }
            if px_i >= x && px_i < x + cw {
                col = pc;
                break;
            }
            x += cw;
        }
    } else if pinned_right_w > 0 && px_i >= pin_right_start && px_i < vp_w {
        hit_pinned_col = true;
        effective_x = px_i;
        let mut x = pin_right_start;
        for &pc in &grid.pinned_cols_right {
            let cw = grid.col_width(pc);
            if cw <= 0 {
                continue;
            }
            if px_i >= x && px_i < x + cw {
                col = pc;
                break;
            }
            x += cw;
        }
    } else {
        // Scrollable columns are clipped after the pinned-left area.
        effective_x = px_i + scroll_x as i32 - pinned_left_w;
        col = layout.col_at_x(effective_x);
        if grid.is_col_pinned(col) != 0 {
            col = -1;
        }
    }

    if row < 0 || col < 0 || row >= grid.rows || col >= grid.cols {
        return HitTestResult {
            row: -1,
            col: -1,
            area: HitArea::Background,
            x_in_cell: 0.0,
            y_in_cell: 0.0,
        };
    }

    // Determine area
    let mut area = if in_fixed_row_area && in_fixed_col_area {
        HitArea::FixedCorner
    } else if in_fixed_row_area {
        if hit_pinned_col {
            HitArea::FixedRow
        } else {
            // Check if near column border for resize
            let (cx, _, cw, _) = layout.cell_rect(row, col);
            let col_left = cx;
            let col_right = cx + cw;
            let hit_half = header_resize_hit_half_width(grid);
            if (effective_x - col_right).abs() <= hit_half {
                HitArea::ColBorder
            } else if col > 0 && (effective_x - col_left).abs() <= hit_half {
                // Near left edge = right edge of previous column
                // Adjust hit col to the previous column for resize
                col = col - 1;
                HitArea::ColBorder
            } else {
                HitArea::FixedRow
            }
        }
    } else if in_fixed_col_area {
        let (_, cy, _, ch) = layout.cell_rect(row, col);
        let row_top = cy;
        let row_bottom = cy + ch;
        if (effective_y - row_bottom).abs() <= 3 {
            HitArea::RowBorder
        } else if row > 0 && (effective_y - row_top).abs() <= 3 {
            // Near top edge = bottom edge of previous row
            row = row - 1;
            HitArea::RowBorder
        } else {
            HitArea::FixedCol
        }
    } else {
        HitArea::Cell
    };

    if (area == HitArea::Cell || area == HitArea::FixedRow || area == HitArea::FixedCol)
        && show_dropdown_button_for_cell(grid, row, col)
    {
        let (cx, cy, cw, ch) = layout.cell_rect(row, col);
        if let Some((bx, by, bw, bh)) = dropdown_button_rect(cx, cy, cw, ch) {
            if effective_x >= bx
                && effective_x < bx + bw
                && effective_y >= by
                && effective_y < by + bh
            {
                area = HitArea::DropdownButton;
            }
        }
    }

    // Outline +/- button hit-testing (geometry matches render_outline via TreeGeometry)
    if area == HitArea::Cell
        && grid.outline.tree_indicator != 0
        && grid.outline.tree_column >= 0
        && col == grid.outline.tree_column
        && row >= grid.fixed_rows
    {
        if let Some(rp) = grid.get_row_props(row) {
            // Subtotal trees render one visual level deeper than stored
            // outline_level (root subtotal L=0 still has a clickable +/- box).
            let visual_level = if rp.is_subtotal {
                rp.outline_level + 1
            } else {
                rp.outline_level
            };
            if rp.is_subtotal && visual_level > 0 {
                let tg = crate::outline::TreeGeometry::from_grid(grid);
                let (cx, cy, _cw, ch) = layout.cell_rect(row, col);
                let line_x = cx + tg.line_x(visual_level);
                let mid_y = cy + ch / 2;
                let bx = line_x - tg.btn_size / 2;
                let by = mid_y - tg.btn_size / 2;
                if effective_x >= bx
                    && effective_x < bx + tg.btn_size
                    && effective_y >= by
                    && effective_y < by + tg.btn_size
                {
                    area = HitArea::OutlineButton;
                }
            }
        }
    }

    let (cx, cy, _, _) = layout.cell_rect(row, col);
    HitTestResult {
        row,
        col,
        area,
        x_in_cell: effective_x as f32 - cx as f32,
        y_in_cell: effective_y as f32 - cy as f32,
    }
}

/// Handle pointer down event
pub fn handle_pointer_down(
    grid: &mut VolvoxGrid,
    x: f32,
    y: f32,
    _button: i32,
    modifier: i32,
    dbl_click: bool,
) {
    handle_pointer_down_with_behavior(
        grid,
        x,
        y,
        _button,
        modifier,
        dbl_click,
        InputBehavior::default(),
    );
}

pub fn handle_pointer_down_with_behavior(
    grid: &mut VolvoxGrid,
    x: f32,
    y: f32,
    _button: i32,
    modifier: i32,
    dbl_click: bool,
    behavior: InputBehavior,
) {
    grid.scroll.stop_fling();
    clear_col_drag_pending(grid);
    if grid.type_ahead_mode != pb::TypeAheadMode::TypeAheadNone as i32 {
        clear_type_ahead_buffer(grid, true);
    }
    let hit = hit_test(grid, x, y);

    // Click-away behavior: if editing, and click is not on the active dropdown or active dropdown button, commit and close.
    // This allows the user to dismiss the dropdown/editor by tapping elsewhere.
    // Skipped when host_pointer_dispatch — the host adapter handles commit-on-click-away.
    if !grid.host_pointer_dispatch
        && grid.is_editing()
        && !grid.edit.formula_mode
        && hit.area != HitArea::DropdownList
    {
        let is_active_btn = hit.area == HitArea::DropdownButton
            && hit.row == grid.edit.edit_row
            && hit.col == grid.edit.edit_col;

        if !is_active_btn {
            grid.commit_edit();
        }
    }

    grid.mouse_row = hit.row;
    grid.mouse_col = hit.col;
    let shift = modifier & 1 != 0;
    let ctrl = modifier & 2 != 0;

    match hit.area {
        HitArea::DropdownList => {
            if let Some(idx) = grid.dropdown_hit_index(x, y) {
                grid.edit.set_dropdown_index(idx);
                // Update text to match selection
                let text = grid.edit.get_dropdown_item(idx).to_string();
                grid.edit.update_text(text.clone());
                grid.events.push(GridEventData::CellEditChange { text });

                // Commit immediately on selection
                grid.commit_edit();
                grid.mark_dirty();
            }
        }
        HitArea::DropdownButton => {
            if hit.row >= 0 && hit.col >= 0 {
                let old_row = grid.selection.row;
                let old_col = grid.selection.col;
                grid.events.push(GridEventData::CellFocusChanging {
                    old_row,
                    old_col,
                    new_row: hit.row,
                    new_col: hit.col,
                });
                grid.selection.set_cursor(
                    hit.row,
                    hit.col,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
                if !shift {
                    grid.selection.row_end = grid.selection.row;
                    grid.selection.col_end = grid.selection.col;
                }
                grid.events.push(GridEventData::CellFocusChanged {
                    old_row,
                    old_col,
                    new_row: hit.row,
                    new_col: hit.col,
                });

                if grid.is_editing()
                    && grid.edit.edit_row == hit.row
                    && grid.edit.edit_col == hit.col
                {
                    grid.events.push(GridEventData::DropdownOpened);
                } else if behavior.allow_begin_edit {
                    begin_edit_from_input(grid, hit.row, hit.col);
                }
                grid.mark_dirty();
            }
        }
        HitArea::OutlineButton => {
            if hit.row >= grid.fixed_rows {
                grid.outline_click_active = true;
                let collapsing = !grid
                    .row_props
                    .get(&hit.row)
                    .map_or(false, |rp| rp.is_collapsed);
                grid.events.push(GridEventData::BeforeNodeToggle {
                    row: hit.row,
                    collapse: collapsing,
                });
                crate::outline::toggle_collapse(grid, hit.row);
                grid.events.push(GridEventData::AfterNodeToggle {
                    row: hit.row,
                    collapse: collapsing,
                });
                grid.mark_dirty();
            }
        }
        HitArea::Cell | HitArea::FixedRow | HitArea::FixedCol => {
            if hit.row >= 0 && hit.col >= 0 {
                // Allow freeze/thaw by dragging the frozen pane separator line.
                if grid.allow_user_freezing > 0 {
                    let allow_cols = matches!(grid.allow_user_freezing, 1 | 3);
                    let allow_rows = matches!(grid.allow_user_freezing, 2 | 3);
                    let frozen_col_line = grid.col_pos(grid.fixed_cols + grid.frozen_cols);
                    let frozen_row_line = grid.row_pos(grid.fixed_rows + grid.frozen_rows);
                    if allow_cols && (x as i32 - frozen_col_line).abs() <= 3 {
                        grid.freeze_drag_active = true;
                        grid.freeze_drag_is_row = false;
                        return;
                    }
                    if allow_rows && (y as i32 - frozen_row_line).abs() <= 3 {
                        grid.freeze_drag_active = true;
                        grid.freeze_drag_is_row = true;
                        return;
                    }
                }

                // When host_pointer_dispatch is set, skip all selection changes
                // and edit triggers — the host adapter drives those.
                if grid.host_pointer_dispatch {
                    return;
                }

                // ListBox mode: row-based toggle selection.
                if grid.selection.mode == pb::SelectionMode::SelectionListbox as i32
                    && hit.row >= grid.fixed_rows
                {
                    if shift && !grid.selection.selected_rows.is_empty() {
                        let anchor = grid.selection.row.max(grid.fixed_rows);
                        let lo = anchor.min(hit.row);
                        let hi = anchor.max(hit.row);
                        for r in lo..=hi {
                            grid.selection.selected_rows.insert(r);
                        }
                    } else if ctrl {
                        grid.selection.toggle_row(hit.row);
                    } else {
                        grid.selection.selected_rows.clear();
                        grid.selection.selected_rows.insert(hit.row);
                    }
                    grid.selection.set_cursor(
                        hit.row,
                        hit.col,
                        grid.rows,
                        grid.cols,
                        grid.fixed_rows,
                        grid.fixed_cols,
                    );
                    grid.selection.row_end = grid.selection.row;
                    grid.selection.col_end = grid.selection.col;
                    grid.mark_dirty();
                    return;
                }

                // Header clicks may select full rows/columns when allowed.
                if grid.header_click_select && grid.header_features == 0 {
                    if hit.area == HitArea::FixedRow && hit.row < grid.fixed_rows {
                        let anchor_row = grid.fixed_rows.min(grid.rows - 1);
                        let target_col = hit.col.clamp(0, grid.cols - 1);
                        grid.selection.select(
                            anchor_row,
                            target_col,
                            grid.rows - 1,
                            target_col,
                            grid.rows,
                            grid.cols,
                        );
                        grid.mark_dirty();
                        return;
                    }
                    if hit.area == HitArea::FixedCol && hit.col < grid.fixed_cols {
                        let anchor_col = grid.fixed_cols.min(grid.cols - 1);
                        let target_row = hit.row.clamp(0, grid.rows - 1);
                        grid.selection.select(
                            target_row,
                            anchor_col,
                            target_row,
                            grid.cols - 1,
                            grid.rows,
                            grid.cols,
                        );
                        grid.mark_dirty();
                        return;
                    }
                }

                // Fire CellFocusChanging event
                let old_row = grid.selection.row;
                let old_col = grid.selection.col;
                grid.events.push(GridEventData::CellFocusChanging {
                    old_row,
                    old_col,
                    new_row: hit.row,
                    new_col: hit.col,
                });

                // Move cursor
                grid.selection.set_cursor(
                    hit.row,
                    hit.col,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );

                // Plain click resets selection to single cell;
                // shift-click keeps the extent for range selection.
                if !shift {
                    grid.selection.row_end = grid.selection.row;
                    grid.selection.col_end = grid.selection.col;
                }

                // Fire CellFocusChanged
                grid.events.push(GridEventData::CellFocusChanged {
                    old_row,
                    old_col,
                    new_row: hit.row,
                    new_col: hit.col,
                });

                // Handle double click for editing, OR single click if it's a dropdown cell (user preference).
                // This aligns Android behavior (where single-tap is expected for dropdowns) with GTK4
                // where the host manually triggers edit on click.
                let is_dropdown = !grid.active_dropdown_list(hit.row, hit.col).is_empty()
                    && grid.active_dropdown_list(hit.row, hit.col).trim() != "...";

                if behavior.allow_begin_edit
                    && (dbl_click || is_dropdown)
                    && grid.edit_trigger_mode >= 2
                {
                    begin_edit_from_input(grid, hit.row, hit.col);
                }

                // Handle header features on fixed row click.
                // Clicking a header for sort/drag does NOT
                // move the selection — restore it after the action.
                if hit.area == HitArea::FixedRow
                    && hit.row < grid.fixed_rows
                    && !is_dropdown
                    && grid.header_features > 0
                    && behavior.allow_header_sort
                {
                    let can_move = grid.header_features & 2 != 0;
                    let can_sort = grid.header_features & 1 != 0;

                    if can_move && !dbl_click {
                        // In move mode, require long-press to start reorder so
                        // short click can still map cleanly to sort.
                        grid.col_drag_pending = true;
                        grid.col_drag_pending_source = hit.col;
                        grid.col_drag_pending_can_sort = can_sort;
                        grid.col_drag_pending_since = Some(Instant::now());
                    } else if can_sort {
                        grid.events.push(GridEventData::BeforeSort { col: hit.col });
                        let old_sort_keys = grid.sort_state.sort_keys.clone();
                        crate::sort::handle_header_click(grid, hit.col);
                        if grid.sort_state.sort_keys != old_sort_keys {
                            grid.events.push(GridEventData::AfterSort { col: hit.col });
                        }
                    }

                    // Restore selection — header clicks should not move the cursor.
                    grid.selection.row = old_row;
                    grid.selection.col = old_col;
                    grid.selection.row_end = old_row;
                    grid.selection.col_end = old_col;
                }

                grid.mark_dirty();
            }
        }
        HitArea::ColBorder => {
            if hit.col >= 0 && hit.col < grid.cols {
                let can_resize_cols = matches!(grid.allow_user_resizing, 1 | 3 | 4 | 6);
                if can_resize_cols {
                    if dbl_click && grid.auto_size_mouse {
                        grid.auto_resize_col(hit.col);
                    } else {
                        grid.events.push(GridEventData::BeforeUserResize {
                            row: -1,
                            col: hit.col,
                        });
                        grid.resize_active = true;
                        grid.resize_is_col = true;
                        grid.resize_index = hit.col;
                        grid.resize_start_pos = x;
                        grid.resize_start_size = grid.get_col_width(hit.col);
                    }
                }
            }
        }
        HitArea::RowBorder => {
            if hit.row >= 0 && hit.row < grid.rows {
                let can_resize_rows = matches!(grid.allow_user_resizing, 2 | 3 | 5 | 6);
                if can_resize_rows {
                    grid.events.push(GridEventData::BeforeUserResize {
                        row: hit.row,
                        col: -1,
                    });
                    grid.resize_active = true;
                    grid.resize_is_col = false;
                    grid.resize_index = hit.row;
                    grid.resize_start_pos = y;
                    grid.resize_start_size = grid.get_row_height(hit.row);
                }
            }
        }
        HitArea::FixedCorner => {
            // Allow freeze dragging from the fixed corner
            if grid.allow_user_freezing > 0 {
                grid.freeze_drag_active = true;
                // Determine direction based on user freezing mode
                grid.freeze_drag_is_row = grid.allow_user_freezing != 1;
            }
        }
        HitArea::HScrollBar | HitArea::VScrollBar => {
            let sbg = compute_scrollbar_geometry(grid);
            let ix = x as i32;
            let iy = y as i32;
            let is_h = hit.area == HitArea::HScrollBar;

            if is_h && sbg.show_h {
                // Left arrow button
                if ix >= sbg.h_left_arrow_x && ix < sbg.h_left_arrow_x + SB_SIZE {
                    let step = (SB_SIZE * 3) as f32;
                    scroll_by_with_events(grid, -step, 0.0);
                    grid.mark_dirty();
                    grid.scrollbar_repeat_active = true;
                    grid.scrollbar_repeat_horizontal = true;
                    grid.scrollbar_repeat_delta = -step;
                    grid.scrollbar_repeat_delay = 0.4;
                    grid.scrollbar_repeat_is_track = false;
                    grid.scrollbar_repeat_mouse_pos = 0.0;
                }
                // Right arrow button
                else if ix >= sbg.h_right_arrow_x && ix < sbg.h_right_arrow_x + SB_SIZE {
                    let step = (SB_SIZE * 3) as f32;
                    scroll_by_with_events(grid, step, 0.0);
                    grid.mark_dirty();
                    grid.scrollbar_repeat_active = true;
                    grid.scrollbar_repeat_horizontal = true;
                    grid.scrollbar_repeat_delta = step;
                    grid.scrollbar_repeat_delay = 0.4;
                    grid.scrollbar_repeat_is_track = false;
                    grid.scrollbar_repeat_mouse_pos = 0.0;
                }
                // Track area (including thumb)
                else if ix >= sbg.h_track_x && ix < sbg.h_track_x + sbg.h_track_w {
                    if ix >= sbg.h_thumb_x && ix < sbg.h_thumb_x + sbg.h_thumb_w {
                        // Thumb: start drag
                        grid.scrollbar_drag_active = true;
                        grid.scrollbar_drag_horizontal = true;
                        grid.scrollbar_drag_start_pos = x;
                        grid.scrollbar_drag_start_scroll = grid.scroll.scroll_x;
                    } else if ix < sbg.h_thumb_x {
                        // Track left of thumb: page scroll left
                        let page =
                            (grid.viewport_width - if sbg.show_v { SB_SIZE } else { 0 }) as f32;
                        scroll_by_with_events(grid, -page, 0.0);
                        grid.mark_dirty();
                        grid.scrollbar_repeat_active = true;
                        grid.scrollbar_repeat_horizontal = true;
                        grid.scrollbar_repeat_delta = -page;
                        grid.scrollbar_repeat_delay = 0.4;
                        grid.scrollbar_repeat_is_track = true;
                        grid.scrollbar_repeat_mouse_pos = ix as f32;
                    } else {
                        // Track right of thumb: page scroll right
                        let page =
                            (grid.viewport_width - if sbg.show_v { SB_SIZE } else { 0 }) as f32;
                        scroll_by_with_events(grid, page, 0.0);
                        grid.mark_dirty();
                        grid.scrollbar_repeat_active = true;
                        grid.scrollbar_repeat_horizontal = true;
                        grid.scrollbar_repeat_delta = page;
                        grid.scrollbar_repeat_delay = 0.4;
                        grid.scrollbar_repeat_is_track = true;
                        grid.scrollbar_repeat_mouse_pos = ix as f32;
                    }
                }
            } else if !is_h && sbg.show_v {
                // Top arrow button
                if iy >= sbg.v_top_arrow_y && iy < sbg.v_top_arrow_y + SB_SIZE {
                    let step = (SB_SIZE * 3) as f32;
                    scroll_by_with_events(grid, 0.0, -step);
                    grid.mark_dirty();
                    grid.scrollbar_repeat_active = true;
                    grid.scrollbar_repeat_horizontal = false;
                    grid.scrollbar_repeat_delta = -step;
                    grid.scrollbar_repeat_delay = 0.4;
                    grid.scrollbar_repeat_is_track = false;
                    grid.scrollbar_repeat_mouse_pos = 0.0;
                }
                // Bottom arrow button
                else if iy >= sbg.v_bot_arrow_y && iy < sbg.v_bot_arrow_y + SB_SIZE {
                    let step = (SB_SIZE * 3) as f32;
                    scroll_by_with_events(grid, 0.0, step);
                    grid.mark_dirty();
                    grid.scrollbar_repeat_active = true;
                    grid.scrollbar_repeat_horizontal = false;
                    grid.scrollbar_repeat_delta = step;
                    grid.scrollbar_repeat_delay = 0.4;
                    grid.scrollbar_repeat_is_track = false;
                    grid.scrollbar_repeat_mouse_pos = 0.0;
                }
                // Track area (including thumb)
                else if iy >= sbg.v_track_y && iy < sbg.v_track_y + sbg.v_track_h {
                    if iy >= sbg.v_thumb_y && iy < sbg.v_thumb_y + sbg.v_thumb_h {
                        // Thumb: start drag
                        grid.scrollbar_drag_active = true;
                        grid.scrollbar_drag_horizontal = false;
                        grid.scrollbar_drag_start_pos = y;
                        grid.scrollbar_drag_start_scroll = grid.scroll.scroll_y;
                    } else if iy < sbg.v_thumb_y {
                        // Track above thumb: page scroll up
                        let page =
                            (grid.viewport_height - if sbg.show_h { SB_SIZE } else { 0 }) as f32;
                        scroll_by_with_events(grid, 0.0, -page);
                        grid.mark_dirty();
                        grid.scrollbar_repeat_active = true;
                        grid.scrollbar_repeat_horizontal = false;
                        grid.scrollbar_repeat_delta = -page;
                        grid.scrollbar_repeat_delay = 0.4;
                        grid.scrollbar_repeat_is_track = true;
                        grid.scrollbar_repeat_mouse_pos = iy as f32;
                    } else {
                        // Track below thumb: page scroll down
                        let page =
                            (grid.viewport_height - if sbg.show_h { SB_SIZE } else { 0 }) as f32;
                        scroll_by_with_events(grid, 0.0, page);
                        grid.mark_dirty();
                        grid.scrollbar_repeat_active = true;
                        grid.scrollbar_repeat_horizontal = false;
                        grid.scrollbar_repeat_delta = page;
                        grid.scrollbar_repeat_delay = 0.4;
                        grid.scrollbar_repeat_is_track = true;
                        grid.scrollbar_repeat_mouse_pos = iy as f32;
                    }
                }
            }
        }
        HitArea::FastScroll => {
            // Stop fling and any scrollbar interaction
            grid.scroll.stop_fling();
            grid.scrollbar_drag_active = false;
            grid.scrollbar_repeat_active = false;
            // Start fast scroll gesture
            grid.fast_scroll_active = true;
            grid.fast_scroll_target_row = -1;
            grid.fast_scroll_anchor_col = grid.selection.col.max(0);
            update_fast_scroll_target(grid, y);
        }
        HitArea::Background => {}
        _ => {}
    }
}

/// Handle pointer move event
pub fn handle_pointer_move(grid: &mut VolvoxGrid, x: f32, y: f32, button: i32, _modifier: i32) {
    // Handle active fast scroll gesture
    if grid.fast_scroll_active {
        update_fast_scroll_target(grid, y);
        return;
    }

    // Handle active scrollbar thumb drag
    if grid.scrollbar_drag_active {
        let sbg = compute_scrollbar_geometry(grid);
        if grid.scrollbar_drag_horizontal {
            let delta_px = x - grid.scrollbar_drag_start_pos;
            let new_scroll = if sbg.h_thumb_range > 0 && sbg.h_max_scroll > 0.0 {
                grid.scrollbar_drag_start_scroll
                    + delta_px * (sbg.h_max_scroll / sbg.h_thumb_range as f32)
            } else {
                grid.scrollbar_drag_start_scroll
            };
            scroll_to_with_events(grid, new_scroll, grid.scroll.scroll_y);
        } else {
            let delta_px = y - grid.scrollbar_drag_start_pos;
            let new_scroll = if sbg.v_thumb_range > 0 && sbg.v_max_scroll > 0.0 {
                grid.scrollbar_drag_start_scroll
                    + delta_px * (sbg.v_max_scroll / sbg.v_thumb_range as f32)
            } else {
                grid.scrollbar_drag_start_scroll
            };
            scroll_to_with_events(grid, grid.scroll.scroll_x, new_scroll);
        }
        grid.mark_dirty();
        return;
    }

    // Handle active resize drag
    if grid.resize_active {
        grid.cursor_style = if grid.resize_is_col { 1 } else { 2 };
        if grid.resize_is_col {
            let delta = (x - grid.resize_start_pos) as i32;
            let new_width = (grid.resize_start_size + delta).max(0);
            let is_uniform = matches!(grid.allow_user_resizing, 4 | 6);
            if is_uniform {
                // Uniform mode: must rebuild full layout
                grid.set_col_width(-1, new_width);
            } else {
                // Single column: use incremental layout patch (avoids O(rows) rebuild)
                let col = grid.resize_index;
                let w = grid.clamp_col_width(col, new_width);
                grid.col_widths.insert(col, w);
                grid.layout.patch_col_width(col, w);
            }
        } else {
            let delta = (y - grid.resize_start_pos) as i32;
            let new_height = (grid.resize_start_size + delta).max(0);
            let is_uniform = matches!(grid.allow_user_resizing, 5 | 6);
            if is_uniform {
                grid.set_row_height(-1, new_height);
            } else {
                // Single row: use incremental layout patch
                let row = grid.resize_index;
                let h = new_height.max(0);
                grid.row_heights.insert(row, h);
                grid.layout.patch_row_height(row, h);
            }
        }
        grid.mark_dirty();
        return;
    }

    // Header reorder requires long-press; while pending, suppress normal drag
    // behaviors to avoid conflicts with selection/sort click.
    if grid.col_drag_pending {
        if maybe_activate_pending_col_drag(grid, x, y) {
            grid.cursor_style = 3; // move/grab
            grid.mark_dirty();
        }
        return;
    }

    // Handle active column drag/reorder
    if grid.col_drag_active {
        grid.cursor_style = 3; // move/grab
        update_col_drag_target(grid, x, y);
        grid.mark_dirty();
        return;
    }

    // Suppress selection extension after outline button click
    if grid.outline_click_active {
        return;
    }

    // Handle active freeze drag
    if grid.freeze_drag_active {
        grid.cursor_style = if grid.freeze_drag_is_row { 2 } else { 1 };
        let hit = hit_test(grid, x, y);
        if grid.freeze_drag_is_row && hit.row >= grid.fixed_rows {
            let new_frozen = (hit.row - grid.fixed_rows).max(0);
            let max_frozen = (grid.rows - grid.fixed_rows - 1).max(0);
            grid.frozen_rows = new_frozen.min(max_frozen);
            grid.layout.invalidate();
            grid.mark_dirty();
        } else if !grid.freeze_drag_is_row && hit.col >= grid.fixed_cols {
            let new_frozen = (hit.col - grid.fixed_cols).max(0);
            let max_frozen = (grid.cols - grid.fixed_cols - 1).max(0);
            grid.frozen_cols = new_frozen.min(max_frozen);
            grid.layout.invalidate();
            grid.mark_dirty();
        }
        return;
    }

    let hit = hit_test(grid, x, y);
    grid.mouse_row = hit.row;
    grid.mouse_col = hit.col;

    // Update cursor style based on hit area
    grid.cursor_style = match hit.area {
        HitArea::ColBorder => {
            if matches!(grid.allow_user_resizing, 1 | 3 | 4 | 6) {
                1 // col-resize
            } else {
                0
            }
        }
        HitArea::RowBorder => {
            if matches!(grid.allow_user_resizing, 2 | 3 | 5 | 6) {
                2 // row-resize
            } else {
                0
            }
        }
        HitArea::OutlineButton => 4, // pointer/hand cursor
        HitArea::HScrollBar | HitArea::VScrollBar | HitArea::FastScroll => 0, // default arrow cursor
        _ => 0,                                                               // default
    };

    // Extend selection only during left-button drag (button bit 0 = primary).
    // Right-button (bit 1) and modifier-only moves must not alter selection.
    // Skipped entirely when host_pointer_dispatch — host adapter owns selection.
    if !grid.host_pointer_dispatch && button & 1 != 0 && hit.row >= 0 && hit.col >= 0 {
        grid.selection.row_end = hit.row.clamp(grid.fixed_rows, grid.rows - 1);
        grid.selection.col_end = hit.col.clamp(grid.fixed_cols, grid.cols - 1);
        grid.mark_dirty();
    }
}

/// Handle pointer up event
pub fn handle_pointer_up(grid: &mut VolvoxGrid, x: f32, y: f32, _button: i32, _modifier: i32) {
    // Clear scrollbar auto-repeat on any pointer up
    grid.scrollbar_repeat_active = false;

    // Complete fast scroll gesture
    if grid.fast_scroll_active {
        grid.fast_scroll_active = false;
        grid.fast_scroll_target_row = -1;
        grid.mark_dirty();
        return;
    }

    // Complete scrollbar thumb drag
    if grid.scrollbar_drag_active {
        grid.scrollbar_drag_active = false;
        grid.mark_dirty();
        return;
    }

    // Clear outline button click guard
    if grid.outline_click_active {
        grid.outline_click_active = false;
        return;
    }

    // Complete resize drag — also do a full layout invalidate since the
    // incremental patching during drag doesn't update scroll bounds.
    if grid.resize_active {
        grid.layout.invalidate();
        let row_ev = if grid.resize_is_col {
            -1
        } else {
            grid.resize_index
        };
        let col_ev = if grid.resize_is_col {
            grid.resize_index
        } else {
            -1
        };
        grid.events.push(GridEventData::AfterUserResize {
            row: row_ev,
            col: col_ev,
        });
        grid.resize_active = false;
        grid.resize_index = -1;
        grid.mark_dirty();
        return;
    }

    if grid.col_drag_pending {
        let source = grid.col_drag_pending_source;
        let can_sort = grid.col_drag_pending_can_sort;
        let elapsed = col_drag_pending_elapsed_ms(grid);
        clear_col_drag_pending(grid);

        if source >= 0 && can_sort && elapsed < HEADER_REORDER_LONG_PRESS_MS {
            grid.events.push(GridEventData::BeforeSort { col: source });
            let old_sort_keys = grid.sort_state.sort_keys.clone();
            crate::sort::handle_header_click(grid, source);
            if grid.sort_state.sort_keys != old_sort_keys {
                grid.events.push(GridEventData::AfterSort { col: source });
            }
        }

        grid.mark_dirty();
        return;
    }

    // Complete column drag/reorder
    if grid.col_drag_active {
        let source = grid.col_drag_source;
        let insert_before = grid.col_drag_insert_pos;
        clear_col_drag_active(grid);

        if source >= 0 && insert_before >= 0 {
            let src_pos = grid.col_positions.iter().position(|&c| c == source);
            if let Some(sp) = src_pos {
                let desired_gap = insert_before.clamp(0, grid.cols) as usize;
                let mut insert_pos = desired_gap;
                if insert_pos > sp {
                    insert_pos -= 1;
                }
                insert_pos = insert_pos.min(grid.col_positions.len());

                if insert_pos != sp {
                    // Actual reorder happened.
                    let new_position = insert_pos as i32;
                    grid.events.push(GridEventData::BeforeMoveColumn {
                        col: source,
                        new_position,
                    });
                    if grid.move_col_by_positions(sp as i32, insert_pos as i32) {
                        grid.events.push(GridEventData::AfterMoveColumn {
                            col: source,
                            old_position: sp as i32,
                        });
                    }
                }
            }
        }
        grid.mark_dirty();
        return;
    }

    // Complete freeze drag
    if grid.freeze_drag_active {
        grid.freeze_drag_active = false;
        grid.events.push(GridEventData::AfterUserFreeze {
            frozen_rows: grid.frozen_rows,
            frozen_cols: grid.frozen_cols,
        });
        grid.mark_dirty();
        return;
    }

    let hit = hit_test(grid, x, y);
    if hit.row >= 0 && hit.col >= 0 {
        grid.events.push(GridEventData::Click);
    }
}

/// Handle key down event
pub fn handle_key_down(grid: &mut VolvoxGrid, key_code: i32, modifier: i32) {
    handle_key_down_with_behavior(grid, key_code, modifier, InputBehavior::default());
}

pub fn handle_key_down_with_behavior(
    grid: &mut VolvoxGrid,
    key_code: i32,
    modifier: i32,
    behavior: InputBehavior,
) {
    grid.scroll.stop_fling();
    let shift = modifier & 1 != 0;
    let ctrl = modifier & 2 != 0;

    if !grid.is_editing() && grid.type_ahead_mode != pb::TypeAheadMode::TypeAheadNone as i32 {
        if matches!(key_code, 27 | 33 | 34 | 35 | 36 | 37 | 38 | 39 | 40) {
            clear_type_ahead_buffer(grid, true);
        }
    }

    // Escape cancels an in-progress/pending header drag without sort/reorder.
    if key_code == 27 && (grid.col_drag_active || grid.col_drag_pending) {
        clear_col_drag_state(grid);
        grid.mark_dirty();
        return;
    }

    // Handle keys during active editing
    if grid.is_editing() {
        match key_code {
            27 if !grid.host_key_dispatch => {
                // Escape: cancel edit (skipped when host drives dispatch)
                if let Some((row, col)) = grid.edit.cancel() {
                    grid.events.push(GridEventData::AfterEdit {
                        row,
                        col,
                        old_text: grid.edit.original_text.clone(),
                        new_text: grid.edit.original_text.clone(),
                    });
                    grid.mark_dirty();
                }
            }
            13 if !grid.host_key_dispatch => {
                // Enter: commit edit (skipped when host drives dispatch)
                if let Some((row, col, old_text, new_text)) = grid.edit.commit() {
                    let dropdown_list = grid.active_dropdown_list(row, col);
                    let store_text = if let Some(data_val) =
                        crate::edit::translate_dropdown_display_to_value(&dropdown_list, &new_text)
                    {
                        data_val
                    } else {
                        new_text.clone()
                    };
                    grid.events.push(GridEventData::CellEditValidate {
                        row,
                        col,
                        edit_text: new_text.clone(),
                    });
                    grid.cells.set_text(row, col, store_text);
                    grid.events.push(GridEventData::AfterEdit {
                        row,
                        col,
                        old_text,
                        new_text,
                    });
                    grid.auto_resize_cell(row, col);
                    grid.mark_dirty();
                }
            }
            // Ctrl+A: select all text in editor
            65 if ctrl => {
                grid.edit.select_all();
                grid.mark_dirty();
            }
            8 => {
                // Backspace
                grid.edit.delete_back();
                grid.events.push(GridEventData::CellEditChange {
                    text: grid.edit.edit_text.clone(),
                });
                grid.mark_dirty();
            }
            46 => {
                // Delete
                grid.edit.delete_forward();
                grid.events.push(GridEventData::CellEditChange {
                    text: grid.edit.edit_text.clone(),
                });
                grid.mark_dirty();
            }
            37 => {
                // Left arrow
                grid.edit.move_left();
                grid.mark_dirty();
            }
            39 => {
                // Right arrow
                grid.edit.move_right();
                grid.mark_dirty();
            }
            36 => {
                // Home
                grid.edit.move_home();
                grid.mark_dirty();
            }
            35 => {
                // End
                grid.edit.move_end();
                grid.mark_dirty();
            }
            38 => {
                // Up arrow in dropdown: move selection up
                if !grid.edit.dropdown_items.is_empty() {
                    let new_idx = (grid.edit.dropdown_index - 1).max(0);
                    grid.edit.set_dropdown_index(new_idx);
                    grid.mark_dirty();
                }
            }
            40 => {
                // Down arrow in dropdown: move selection down
                if !grid.edit.dropdown_items.is_empty() {
                    let max_idx = grid.edit.dropdown_count() - 1;
                    let new_idx = (grid.edit.dropdown_index + 1).min(max_idx);
                    grid.edit.set_dropdown_index(new_idx);
                    grid.mark_dirty();
                }
            }
            _ => {}
        }
        grid.events.push(GridEventData::KeyDownEdit {
            key_code,
            shift: modifier,
        });
        return;
    }

    let old_row = grid.selection.row;
    let old_col = grid.selection.col;

    match key_code {
        // Arrow keys
        37 => {
            // Left
            if shift {
                let new_col = (grid.selection.col_end - 1).max(grid.fixed_cols);
                grid.selection.col_end = new_col;
            } else {
                let new_col = (grid.selection.col - 1).max(grid.fixed_cols);
                grid.selection.set_cursor(
                    grid.selection.row,
                    new_col,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
            }
        }
        38 => {
            // Up
            if shift {
                let new_row = (grid.selection.row_end - 1).max(grid.fixed_rows);
                grid.selection.row_end = new_row;
            } else {
                let new_row = (grid.selection.row - 1).max(grid.fixed_rows);
                grid.selection.set_cursor(
                    new_row,
                    grid.selection.col,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
            }
        }
        39 => {
            // Right
            if shift {
                let new_col = (grid.selection.col_end + 1).min(grid.cols - 1);
                grid.selection.col_end = new_col;
            } else {
                let new_col = (grid.selection.col + 1).min(grid.cols - 1);
                grid.selection.set_cursor(
                    grid.selection.row,
                    new_col,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
            }
        }
        40 => {
            // Down
            if shift {
                let new_row = (grid.selection.row_end + 1).min(grid.rows - 1);
                grid.selection.row_end = new_row;
            } else {
                let new_row = (grid.selection.row + 1).min(grid.rows - 1);
                grid.selection.set_cursor(
                    new_row,
                    grid.selection.col,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
            }
        }
        // Page Up/Down
        33 => {
            // PageUp
            let page = (grid.viewport_height / grid.default_row_height).max(1);
            let new_row = (grid.selection.row - page).max(grid.fixed_rows);
            grid.selection.set_cursor(
                new_row,
                grid.selection.col,
                grid.rows,
                grid.cols,
                grid.fixed_rows,
                grid.fixed_cols,
            );
        }
        34 => {
            // PageDown
            let page = (grid.viewport_height / grid.default_row_height).max(1);
            let new_row = (grid.selection.row + page).min(grid.rows - 1);
            grid.selection.set_cursor(
                new_row,
                grid.selection.col,
                grid.rows,
                grid.cols,
                grid.fixed_rows,
                grid.fixed_cols,
            );
        }
        // Home/End
        36 => {
            // Home
            if ctrl {
                grid.selection.set_cursor(
                    grid.fixed_rows,
                    grid.fixed_cols,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
            } else {
                grid.selection.set_cursor(
                    grid.selection.row,
                    grid.fixed_cols,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
            }
        }
        35 => {
            // End
            if ctrl {
                grid.selection.set_cursor(
                    grid.rows - 1,
                    grid.cols - 1,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
            } else {
                grid.selection.set_cursor(
                    grid.selection.row,
                    grid.cols - 1,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
            }
        }
        // Tab
        9 => {
            if grid.tab_behavior == pb::TabBehavior::TabCells as i32 {
                // TAB_CELLS
                if shift {
                    let new_col = grid.selection.col - 1;
                    if new_col >= grid.fixed_cols {
                        grid.selection.set_cursor(
                            grid.selection.row,
                            new_col,
                            grid.rows,
                            grid.cols,
                            grid.fixed_rows,
                            grid.fixed_cols,
                        );
                    }
                } else {
                    let new_col = grid.selection.col + 1;
                    if new_col < grid.cols {
                        grid.selection.set_cursor(
                            grid.selection.row,
                            new_col,
                            grid.rows,
                            grid.cols,
                            grid.fixed_rows,
                            grid.fixed_cols,
                        );
                    }
                }
            }
        }
        // Enter - start editing if editable (skipped when host drives dispatch)
        13 => {
            if !grid.host_key_dispatch
                && behavior.allow_begin_edit
                && grid.edit_trigger_mode >= 1
                && !grid.is_editing()
            {
                begin_edit_from_input(grid, grid.selection.row, grid.selection.col);
            }
        }
        // F2 - also start editing (skipped when host drives dispatch)
        113 => {
            if !grid.host_key_dispatch
                && behavior.allow_begin_edit
                && grid.edit_trigger_mode >= 1
                && !grid.is_editing()
            {
                begin_edit_from_input(grid, grid.selection.row, grid.selection.col);
            }
        }
        // Delete
        46 => {
            if ctrl {
                // Ctrl+Delete: delete selection
            }
        }
        // Ctrl+C = Copy, Ctrl+X = Cut, Ctrl+V = Paste
        67 if ctrl => {
            grid.events.push(GridEventData::Copy);
        }
        88 if ctrl => {
            grid.events.push(GridEventData::Cut);
        }
        86 if ctrl => {
            grid.events.push(GridEventData::Paste);
        }
        // Ctrl+A = Select All
        65 if ctrl => {
            grid.selection.select(
                grid.fixed_rows,
                grid.fixed_cols,
                grid.rows - 1,
                grid.cols - 1,
                grid.rows,
                grid.cols,
            );
        }
        _ => {}
    }

    // Fire events if cursor moved
    if grid.selection.row != old_row || grid.selection.col != old_col {
        grid.events.push(GridEventData::CellFocusChanged {
            old_row,
            old_col,
            new_row: grid.selection.row,
            new_col: grid.selection.col,
        });
        // Auto-scroll to show cursor
        grid.scroll.show_cell(
            grid.selection.row,
            grid.selection.col,
            &grid.layout,
            grid.viewport_width,
            grid.viewport_height,
            grid.fixed_rows,
            grid.fixed_cols,
            grid.pinned_top_height() + grid.pinned_bottom_height(),
            grid.pinned_left_width() + grid.pinned_right_width(),
        );
        grid.mark_dirty();
    }

    grid.events.push(GridEventData::KeyDown {
        key_code,
        shift: modifier,
    });
}

/// Handle key press event (character input)
///
/// This handles printable character input. In keyboard-edit mode (edit_trigger_mode >= 1),
/// typing a printable character auto-starts editing and replaces the cell content.
/// During active editing, characters are inserted at the cursor position.
pub fn handle_key_press(grid: &mut VolvoxGrid, char_code: u32) {
    handle_key_press_with_behavior(grid, char_code, InputBehavior::default());
}

pub fn handle_key_press_with_behavior(
    grid: &mut VolvoxGrid,
    char_code: u32,
    behavior: InputBehavior,
) {
    let ch = match char::from_u32(char_code) {
        Some(c) if c >= ' ' => c, // printable characters
        _ => return,
    };

    if grid.is_editing() {
        // Check edit mask validation
        let mask = if !grid.edit_mask.is_empty() {
            grid.edit_mask.clone()
        } else {
            let col = grid.edit.edit_col;
            if col >= 0 && (col as usize) < grid.columns.len() {
                grid.columns[col as usize].edit_mask.clone()
            } else {
                String::new()
            }
        };
        if !mask.is_empty() {
            let cursor_pos = grid.edit.sel_start as usize;
            let input_pos = crate::edit::next_input_position(&mask, cursor_pos);
            if !crate::edit::is_char_valid_for_mask(ch, &mask, input_pos) {
                return; // Reject invalid character
            }
        }

        // Check max length
        if grid.edit_max_length > 0
            && grid.edit.sel_length == 0
            && grid.edit.edit_text.chars().count() as i32 >= grid.edit_max_length
        {
            return;
        }

        // Insert character into active editor
        grid.edit.insert_char(ch);

        // DropdownSearch: type-ahead dropdown list
        if grid.dropdown_search && !grid.edit.dropdown_items.is_empty() {
            let idx = grid.edit.search_dropdown(&grid.edit.edit_text.clone());
            if idx >= 0 {
                grid.edit.dropdown_index = idx;
            }
        }

        grid.events.push(GridEventData::CellEditChange {
            text: grid.edit.edit_text.clone(),
        });
        grid.mark_dirty();
    } else if grid.type_ahead_mode != pb::TypeAheadMode::TypeAheadNone as i32 {
        // Type-ahead takes precedence over typing edits. In editable mode,
        // SPACE starts editing while other printable keys search.
        if ch == ' ' && !grid.host_key_dispatch && behavior.allow_begin_edit && grid.edit_trigger_mode >= 1 {
            begin_edit_from_input(grid, grid.selection.row, grid.selection.col);
            if grid.is_editing() {
                grid.edit.update_text(String::new());
                grid.edit.sel_start = 0;
                grid.edit.sel_length = 0;
            }
        } else {
            let now = Instant::now();
            let delay = type_ahead_delay_ms(grid);
            if let Some(last) = grid.type_ahead_last_input {
                if now.duration_since(last).as_millis() > delay {
                    clear_type_ahead_buffer(grid, false);
                }
            }
            grid.type_ahead_last_input = Some(now);

            let from_top = grid.type_ahead_mode == pb::TypeAheadMode::TypeAheadFromStart as i32;
            let col = grid.selection.col;
            let found = crate::search::type_ahead_buffered(grid, ch, col, from_top);
            if found >= grid.fixed_rows {
                let old_row = grid.selection.row;
                let old_col = grid.selection.col;
                grid.events.push(GridEventData::CellFocusChanging {
                    old_row,
                    old_col,
                    new_row: found,
                    new_col: col,
                });
                grid.selection.set_cursor(
                    found,
                    col,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
                grid.selection.row_end = grid.selection.row;
                grid.selection.col_end = grid.selection.col;
                grid.events.push(GridEventData::CellFocusChanged {
                    old_row,
                    old_col,
                    new_row: grid.selection.row,
                    new_col: grid.selection.col,
                });
                grid.scroll.show_cell(
                    grid.selection.row,
                    grid.selection.col,
                    &grid.layout,
                    grid.viewport_width,
                    grid.viewport_height,
                    grid.fixed_rows,
                    grid.fixed_cols,
                    grid.pinned_top_height() + grid.pinned_bottom_height(),
                    grid.pinned_left_width() + grid.pinned_right_width(),
                );
                grid.mark_dirty();
            }
        }
    } else if !grid.host_key_dispatch && behavior.allow_begin_edit && grid.edit_trigger_mode >= 1 {
        // Auto-start editing on keypress (keyboard-edit mode)
        let row = grid.selection.row;
        let col = grid.selection.col;
        begin_edit_from_input(grid, row, col);

        if grid.is_editing() {
            // Clear old text and type the new character (VSVolvoxGrid8 behavior)
            grid.edit.update_text(String::from(ch));
            grid.edit.sel_start = 1;
            grid.edit.sel_length = 0;
            grid.events.push(GridEventData::CellEditChange {
                text: grid.edit.edit_text.clone(),
            });
            grid.mark_dirty();
        }
    }

    grid.events.push(GridEventData::KeyPress {
        key_ascii: char_code as i32,
    });
}

/// Handle scroll event
pub fn handle_scroll(grid: &mut VolvoxGrid, delta_x: f32, delta_y: f32) {
    // During header drag-reorder, touch hosts may still emit coalesced scroll
    // deltas; ignore them so reorder remains stable.
    if grid.col_drag_active || grid.col_drag_pending {
        return;
    }

    let line_height = grid.default_row_height as f32;
    let dx = delta_x * line_height;
    let dy = delta_y * line_height;
    let old_top_left =
        visible_top_left_for_scroll(grid, grid.scroll.scroll_x, grid.scroll.scroll_y);

    let mut next_scroll = grid.scroll.clone();
    next_scroll.scroll_by(dx, dy);
    let predicted_top_left =
        visible_top_left_for_scroll(grid, next_scroll.scroll_x, next_scroll.scroll_y);
    if old_top_left != predicted_top_left {
        grid.events.push(GridEventData::BeforeScroll {
            old_top_row: old_top_left.0,
            old_left_col: old_top_left.1,
            new_top_row: predicted_top_left.0,
            new_left_col: predicted_top_left.1,
        });
    }

    grid.scroll.scroll_by(dx, dy);
    let new_top_left =
        visible_top_left_for_scroll(grid, grid.scroll.scroll_x, grid.scroll.scroll_y);
    let scrolled = old_top_left != new_top_left;
    if grid.fling_enabled {
        // Convert wheel/touch delta into an inertial velocity impulse.
        let impulse_gain = grid.fling_impulse_gain.max(0.0);
        grid.scroll
            .add_fling_impulse(dx * impulse_gain, dy * impulse_gain);
    } else {
        grid.scroll.stop_fling();
    }
    if !grid.scroll_track {
        // Without scroll tracking, avoid inertial carry-over between interactions.
        grid.scroll.stop_fling();
    }

    if scrolled && grid.scroll_tips && grid.layout.valid {
        let fixed_h = grid.layout.row_pos(grid.fixed_rows);
        let y = (grid.scroll.scroll_y as i32 + fixed_h).max(0);
        let row = grid.layout.row_at_y(y).clamp(0, (grid.rows - 1).max(0));
        let text = if grid.scroll_tooltip_text.is_empty() {
            format!(" Row {} ", row)
        } else {
            grid.scroll_tooltip_text.clone()
        };
        grid.events.push(GridEventData::ScrollTooltip { text });
    }

    if scrolled {
        grid.events.push(GridEventData::AfterScroll {
            old_top_row: old_top_left.0,
            old_left_col: old_top_left.1,
            new_top_row: new_top_left.0,
            new_left_col: new_top_left.1,
        });
    }

    grid.mark_dirty();
}

/// Tick the scrollbar auto-repeat timer. Call this from the host's frame timer
/// (e.g. every 16ms). Returns `true` if a repeat scroll was applied (grid is
/// already marked dirty in that case).
pub fn tick_scrollbar_repeat(grid: &mut VolvoxGrid, dt_seconds: f32) -> bool {
    if !grid.scrollbar_repeat_active {
        return false;
    }
    grid.scrollbar_repeat_delay -= dt_seconds;
    if grid.scrollbar_repeat_delay > 0.0 {
        return false;
    }
    // For track clicks, stop repeating once the thumb has reached the click position.
    if grid.scrollbar_repeat_is_track {
        let sbg = compute_scrollbar_geometry(grid);
        let mp = grid.scrollbar_repeat_mouse_pos as i32;
        let thumb_covers_mouse = if grid.scrollbar_repeat_horizontal {
            mp >= sbg.h_thumb_x && mp < sbg.h_thumb_x + sbg.h_thumb_w
        } else {
            mp >= sbg.v_thumb_y && mp < sbg.v_thumb_y + sbg.v_thumb_h
        };
        if thumb_covers_mouse {
            // Transition into thumb drag so moving the mouse while still
            // holding the button drags the scrollbar thumb.
            grid.scrollbar_repeat_active = false;
            grid.scrollbar_drag_active = true;
            grid.scrollbar_drag_horizontal = grid.scrollbar_repeat_horizontal;
            grid.scrollbar_drag_start_pos = grid.scrollbar_repeat_mouse_pos;
            grid.scrollbar_drag_start_scroll = if grid.scrollbar_repeat_horizontal {
                grid.scroll.scroll_x
            } else {
                grid.scroll.scroll_y
            };
            return false;
        }
    }
    // Apply the scroll delta
    let scrolled = if grid.scrollbar_repeat_horizontal {
        scroll_by_with_events(grid, grid.scrollbar_repeat_delta, 0.0)
    } else {
        scroll_by_with_events(grid, 0.0, grid.scrollbar_repeat_delta)
    };
    if scrolled {
        grid.mark_dirty();
    }
    // Set short interval for subsequent repeats (~50ms)
    grid.scrollbar_repeat_delay = 0.05;
    scrolled
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::event::GridEventData;
    use crate::grid::VolvoxGrid;
    use std::time::Duration;

    fn prime_layout(grid: &mut VolvoxGrid) {
        grid.layout.row_positions.clear();
        grid.layout.row_positions.push(0);
        for r in 0..grid.rows {
            let y = *grid.layout.row_positions.last().unwrap() + grid.row_height(r);
            grid.layout.row_positions.push(y);
        }
        grid.layout.total_height = *grid.layout.row_positions.last().unwrap_or(&0);

        grid.layout.col_positions.clear();
        grid.layout.col_positions.push(0);
        for c in 0..grid.cols {
            let x = *grid.layout.col_positions.last().unwrap() + grid.col_width(c);
            grid.layout.col_positions.push(x);
        }
        grid.layout.total_width = *grid.layout.col_positions.last().unwrap_or(&0);
        grid.layout.valid = true;
    }

    fn force_pending_header_long_press(grid: &mut VolvoxGrid) {
        assert!(grid.col_drag_pending);
        grid.col_drag_pending_since = Some(
            Instant::now() - Duration::from_millis((HEADER_REORDER_LONG_PRESS_MS + 10) as u64),
        );
    }

    #[test]
    fn col_resize_drag() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 3, 1, 0);
        grid.allow_user_resizing = 1; // cols only
        prime_layout(&mut grid);

        // Click on column border (right edge of col 0, in fixed row area)
        // col 0 right edge = col_positions[1] = 70 (default width).
        // Hit test detects ColBorder when within 3px of column right edge.
        // cell_rect(0, 0) = (0, 0, 70, 20), col_right = 70.
        // effective_x = px (in fixed area, no scroll), so click at x=70.
        let col0_right = grid.layout.col_positions[1]; // 70
        let click_x = col0_right as f32; // exactly at border
        handle_pointer_down(&mut grid, click_x, 5.0, 0, 0, false);
        assert!(
            grid.resize_active,
            "resize should be active; col0_right={}",
            col0_right
        );
        assert!(grid.resize_is_col);
        assert_eq!(grid.resize_index, 0);

        // Drag right by 30px
        let start_width = grid.get_col_width(0);
        handle_pointer_move(&mut grid, click_x + 30.0, 5.0, 1, 0);
        assert_eq!(grid.get_col_width(0), start_width + 30);

        // Release
        handle_pointer_up(&mut grid, click_x + 30.0, 5.0, 0, 0);
        assert!(!grid.resize_active);
        let events = grid.events.drain();
        assert!(events
            .iter()
            .any(|e| matches!(e.data, GridEventData::AfterUserResize { row: -1, col: 0 })));
    }

    #[test]
    fn col_resize_rejected_when_not_allowed() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 3, 1, 0);
        grid.allow_user_resizing = 0; // none
        prime_layout(&mut grid);

        let col0_right = grid.col_pos(1);
        handle_pointer_down(&mut grid, col0_right as f32, 5.0, 0, 0, false);
        assert!(!grid.resize_active);
    }

    #[test]
    fn auto_start_editing_on_keypress() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1; // keyboard-edit
        prime_layout(&mut grid);

        // Type 'A' should auto-start editing
        handle_key_press(&mut grid, 'A' as u32);
        assert!(grid.is_editing());
        assert_eq!(grid.edit.edit_text, "A");
        assert_eq!(grid.edit.sel_start, 1);
    }

    #[test]
    fn editing_enter_commits() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        prime_layout(&mut grid);

        handle_key_press(&mut grid, 'X' as u32);
        assert!(grid.is_editing());

        // Press Enter to commit
        handle_key_down(&mut grid, 13, 0);
        assert!(!grid.is_editing());
        assert_eq!(
            grid.cells.get_text(grid.selection.row, grid.selection.col),
            "X"
        );
    }

    #[test]
    fn host_dispatch_disables_auto_start_edit_on_keypress() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.host_key_dispatch = true;
        prime_layout(&mut grid);

        handle_key_press(&mut grid, 'A' as u32);
        assert!(!grid.is_editing());
        assert_eq!(grid.edit.edit_text, "");
    }

    #[test]
    fn host_dispatch_keeps_edit_session_on_enter_and_escape() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.host_key_dispatch = true;
        prime_layout(&mut grid);

        let row = grid.selection.row;
        let col = grid.selection.col;
        begin_edit_from_input(&mut grid, row, col);
        assert!(grid.is_editing());
        grid.edit.edit_text = "changed".to_string();

        handle_key_down(&mut grid, 13, 0);
        assert!(grid.is_editing());
        assert_eq!(grid.cells.get_text(grid.selection.row, grid.selection.col), "");

        handle_key_down(&mut grid, 27, 0);
        assert!(grid.is_editing());
    }

    #[test]
    fn host_dispatch_ctrl_a_still_selects_all_in_editor() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.host_key_dispatch = true;
        prime_layout(&mut grid);

        let row = grid.selection.row;
        let col = grid.selection.col;
        begin_edit_from_input(&mut grid, row, col);
        assert!(grid.is_editing());
        grid.edit.edit_text = "abcdef".to_string();
        grid.edit.sel_start = 2;
        grid.edit.sel_length = 0;

        handle_key_down(&mut grid, 65, 2); // Ctrl+A
        assert_eq!(grid.edit.sel_start, 0);
        assert_eq!(grid.edit.sel_length, 6);
    }

    #[test]
    fn editing_escape_cancels() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.cells.set_text(1, 0, "original".to_string());
        prime_layout(&mut grid);

        // Start editing
        handle_key_down(&mut grid, 13, 0); // Enter to start
        assert!(grid.is_editing());

        // Type something
        grid.edit.edit_text = "changed".to_string();

        // Press Escape to cancel
        handle_key_down(&mut grid, 27, 0);
        assert!(!grid.is_editing());
        // Original text should be preserved
        assert_eq!(grid.cells.get_text(1, 0), "original");
    }

    #[test]
    fn editing_backspace_delete() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        prime_layout(&mut grid);

        handle_key_down(&mut grid, 13, 0); // Enter to start
        grid.edit.edit_text = "abc".to_string();
        grid.edit.sel_start = 2;
        grid.edit.sel_length = 0;

        // Backspace: delete 'b'
        handle_key_down(&mut grid, 8, 0);
        assert_eq!(grid.edit.edit_text, "ac");
        assert_eq!(grid.edit.sel_start, 1);

        // Delete: delete 'c'
        handle_key_down(&mut grid, 46, 0);
        assert_eq!(grid.edit.edit_text, "a");
    }

    #[test]
    fn behavior_can_disable_begin_edit_from_input() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 2, 1, 0);
        grid.edit_trigger_mode = 2;
        prime_layout(&mut grid);

        handle_pointer_down_with_behavior(
            &mut grid,
            10.0,
            25.0, // data row 1
            0,
            0,
            true, // dbl click would normally begin edit
            InputBehavior {
                allow_begin_edit: false,
                allow_header_sort: true,
            },
        );

        assert!(!grid.edit.is_active());
        let events = grid.events.drain();
        assert!(!events
            .iter()
            .any(|e| matches!(e.data, GridEventData::BeforeEdit { .. })));
        assert!(!events
            .iter()
            .any(|e| matches!(e.data, GridEventData::StartEdit { .. })));
    }

    #[test]
    fn behavior_can_disable_header_sort() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.header_features = 1; // HEADER_SORT
        grid.cells.set_text(1, 0, "B".to_string());
        grid.cells.set_text(2, 0, "A".to_string());
        prime_layout(&mut grid);

        // Header click with sorting disabled by behavior: no sort.
        handle_pointer_down_with_behavior(
            &mut grid,
            10.0,
            10.0, // fixed header row
            0,
            0,
            false,
            InputBehavior {
                allow_begin_edit: true,
                allow_header_sort: false,
            },
        );
        assert_eq!(grid.cells.get_text(1, 0), "B");
        let events = grid.events.drain();
        assert!(!events
            .iter()
            .any(|e| matches!(e.data, GridEventData::BeforeSort { .. })));
        assert!(!events
            .iter()
            .any(|e| matches!(e.data, GridEventData::AfterSort { .. })));

        // Same header click with default behavior: sort happens.
        handle_pointer_down(&mut grid, 10.0, 10.0, 0, 0, false);
        assert_eq!(grid.cells.get_text(1, 0), "A");
        let events = grid.events.drain();
        assert!(events
            .iter()
            .any(|e| matches!(e.data, GridEventData::BeforeSort { col: 0 })));
        assert!(events
            .iter()
            .any(|e| matches!(e.data, GridEventData::AfterSort { col: 0 })));
    }

    #[test]
    fn header_click_sorts_when_move_mode_enabled_without_drag() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.header_features = 3; // HEADER_SORT | HEADER_MOVE
        grid.cells.set_text(1, 0, "B".to_string());
        grid.cells.set_text(2, 0, "A".to_string());
        prime_layout(&mut grid);

        handle_pointer_down(&mut grid, 10.0, 10.0, 0, 0, false);
        handle_pointer_up(&mut grid, 10.0, 10.0, 0, 0);

        assert_eq!(grid.cells.get_text(1, 0), "A");
        let events = grid.events.drain();
        assert!(events
            .iter()
            .any(|e| matches!(e.data, GridEventData::AfterSort { col: 0 })));
    }

    #[test]
    fn column_drag_uses_between_column_gap_for_right_move() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 4, 1, 0);
        grid.header_features = 2; // HEADER_MOVE
        grid.cells.set_text(0, 0, "A".to_string());
        grid.cells.set_text(0, 1, "B".to_string());
        grid.cells.set_text(0, 2, "C".to_string());
        grid.cells.set_text(0, 3, "D".to_string());
        prime_layout(&mut grid);

        // Start dragging header col=1.
        handle_pointer_down(&mut grid, 105.0, 10.0, 0, 0, false);
        assert!(grid.col_drag_pending);
        assert_eq!(grid.col_drag_pending_source, 1);
        force_pending_header_long_press(&mut grid);

        // Hover right half of col=2 => insertion gap after col=2.
        let x = (grid.col_pos(2) + (grid.col_width(2) * 3) / 4) as f32;
        handle_pointer_move(&mut grid, x, 10.0, 1, 0);
        assert!(grid.col_drag_active);
        assert_eq!(grid.col_drag_insert_pos, 3);

        handle_pointer_up(&mut grid, x, 10.0, 0, 0);
        assert_eq!(grid.cells.get_text(0, 0), "A");
        assert_eq!(grid.cells.get_text(0, 1), "C");
        assert_eq!(grid.cells.get_text(0, 2), "B");
        assert_eq!(grid.cells.get_text(0, 3), "D");

        let events = grid.events.drain();
        assert!(events
            .iter()
            .any(|e| matches!(e.data, GridEventData::AfterMoveColumn { col: 1, .. })));
    }

    #[test]
    fn column_drag_still_targets_when_pointer_leaves_header_band() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 6, 4, 1, 0);
        grid.header_features = 3; // HEADER_SORT | HEADER_MOVE
        grid.cells.set_text(0, 0, "A".to_string());
        grid.cells.set_text(0, 1, "B".to_string());
        grid.cells.set_text(0, 2, "C".to_string());
        grid.cells.set_text(0, 3, "D".to_string());
        prime_layout(&mut grid);

        handle_pointer_down(&mut grid, 105.0, 10.0, 0, 0, false);
        force_pending_header_long_press(&mut grid);
        grid.events.drain();

        // Move into body rows: drag target should remain valid by X position.
        handle_pointer_move(&mut grid, 180.0, 45.0, 1, 0);
        assert!(grid.col_drag_insert_pos >= 0);
        handle_pointer_up(&mut grid, 180.0, 45.0, 0, 0);

        assert_eq!(grid.cells.get_text(0, 0), "A");
        assert_eq!(grid.cells.get_text(0, 1), "C");
        assert_eq!(grid.cells.get_text(0, 2), "B");
        assert_eq!(grid.cells.get_text(0, 3), "D");
        let events = grid.events.drain();
        assert!(events
            .iter()
            .any(|e| matches!(e.data, GridEventData::AfterMoveColumn { .. })));
    }

    #[test]
    fn escape_cancels_active_column_drag() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 6, 4, 1, 0);
        grid.header_features = 3; // HEADER_SORT | HEADER_MOVE
        prime_layout(&mut grid);

        let before = grid.col_positions.clone();
        handle_pointer_down(&mut grid, 105.0, 10.0, 0, 0, false);
        force_pending_header_long_press(&mut grid);
        let x = (grid.col_pos(2) + (grid.col_width(2) * 3) / 4) as f32;
        handle_pointer_move(&mut grid, x, 10.0, 1, 0);
        assert!(grid.col_drag_active);
        assert!(grid.col_drag_moved);

        handle_key_down(&mut grid, 27, 0);
        assert!(!grid.col_drag_active);
        assert_eq!(grid.col_positions, before);

        let events = grid.events.drain();
        assert!(!events
            .iter()
            .any(|e| matches!(e.data, GridEventData::AfterMoveColumn { .. })));
        assert!(!events
            .iter()
            .any(|e| matches!(e.data, GridEventData::AfterSort { .. })));
    }

    #[test]
    fn header_long_press_without_drag_does_not_sort() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.header_features = 3; // HEADER_SORT | HEADER_MOVE
        grid.cells.set_text(1, 0, "B".to_string());
        grid.cells.set_text(2, 0, "A".to_string());
        prime_layout(&mut grid);

        handle_pointer_down(&mut grid, 10.0, 10.0, 0, 0, false);
        force_pending_header_long_press(&mut grid);
        handle_pointer_up(&mut grid, 10.0, 10.0, 0, 0);

        assert_eq!(grid.cells.get_text(1, 0), "B");
        let events = grid.events.drain();
        assert!(!events
            .iter()
            .any(|e| matches!(e.data, GridEventData::AfterSort { .. })));
    }

    #[test]
    fn scroll_is_ignored_while_column_drag_is_active() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 50, 5, 1, 0);
        prime_layout(&mut grid);
        let before_x = grid.scroll.scroll_x;
        let before_y = grid.scroll.scroll_y;
        grid.col_drag_active = true;

        handle_scroll(&mut grid, 4.0, 6.0);

        assert_eq!(grid.scroll.scroll_x, before_x);
        assert_eq!(grid.scroll.scroll_y, before_y);
        assert!(grid.events.drain().is_empty());

        grid.col_drag_active = false;
        grid.col_drag_pending = true;
        grid.col_drag_pending_source = 0;
        grid.col_drag_pending_can_sort = true;
        grid.col_drag_pending_since = Some(Instant::now());
        handle_scroll(&mut grid, 4.0, 6.0);
        assert_eq!(grid.scroll.scroll_x, before_x);
        assert_eq!(grid.scroll.scroll_y, before_y);
        assert!(grid.events.drain().is_empty());
    }
}
