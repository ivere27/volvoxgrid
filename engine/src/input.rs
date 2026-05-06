use crate::canvas::VisibleRange;
use crate::compose::ComposeResult;
use crate::control::CellControl;
use crate::event::{EventTarget, GridEventData};
use crate::grid::{ActiveIndicatorTarget, HoverTarget, VolvoxGrid};
use crate::proto::volvoxgrid::v1 as pb;
use crate::scrollbar::{
    bump_scrollbar_fade, compute_scrollbar_geometry, normalize_scrollbar_mode,
    scrollbar_overlays_content,
};
use crate::selection::{hover_mode_has, HOVER_CELL, HOVER_COLUMN, HOVER_NONE, HOVER_ROW};
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

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HitArea {
    Cell,                    // regular cell background / padding
    CellText,                // text content inside the cell
    CellPicture,             // picture content inside the cell
    CellButtonPicture,       // button_picture content inside the cell
    FixedRow,                // fixed row header
    FixedCol,                // fixed col header
    FixedCorner,             // top-left fixed corner
    IndicatorColTop,         // top column indicator band
    IndicatorRowStart,       // start row indicator band
    IndicatorRowStartResize, // right edge of start row indicator band
    IndicatorCornerTopStart, // top-start indicator corner
    ColBorder,               // between column headers (resize)
    RowBorder,               // between row headers (resize)
    OutlineButton,           // outline +/- button
    CheckBox,                // checkbox in cell
    DropdownButton,          // dropdown button
    DropdownList,            // dropdown list
    HScrollBar,              // horizontal scrollbar area (track, thumb, arrows)
    VScrollBar,              // vertical scrollbar area (track, thumb, arrows)
    FastScroll,              // fast scroll touch zone (right edge)
    Background,              // empty area beyond grid
}

#[derive(Clone, Copy, Debug)]
struct LocalRowHit {
    row: i32,
    effective_y: i32,
    in_fixed_row_area: bool,
}

#[derive(Clone, Copy, Debug)]
struct LocalColHit {
    col: i32,
    effective_x: i32,
    in_fixed_col_area: bool,
    // True for columns drawn in an overlay position (pinned or sticky), where
    // normal layout-space resize-edge math would target the scrolled column.
    hit_pinned_col: bool,
}

/// Optional behavior switches used by host integrations that need to intercept
/// cancelable events before applying grid mutations.
#[derive(Clone, Copy, Debug)]
pub struct InputBehavior {
    pub allow_begin_edit: bool,
    pub allow_header_sort: bool,
    pub allow_column_drag: bool,
    pub allow_node_toggle: bool,
    pub allow_user_resize: bool,
    pub allow_before_mouse_down: bool,
    pub allow_before_scroll: bool,
}

impl Default for InputBehavior {
    fn default() -> Self {
        Self {
            allow_begin_edit: true,
            allow_header_sort: true,
            allow_column_drag: true,
            allow_node_toggle: true,
            allow_user_resize: true,
            allow_before_mouse_down: true,
            allow_before_scroll: true,
        }
    }
}

const HEADER_REORDER_LONG_PRESS_MS: u128 = 350;

fn header_resize_hit_half_width(grid: &VolvoxGrid) -> i32 {
    if grid.is_tui_mode() {
        return 1;
    }
    let w = grid.style.header_resize_handle.hit_width_px.max(1);
    // Symmetric tolerance around the border center line.
    (w + 1) / 2
}

fn col_resize_enabled(grid: &VolvoxGrid) -> bool {
    matches!(grid.allow_user_resizing, 1 | 3 | 4 | 6)
}

fn row_resize_enabled(grid: &VolvoxGrid) -> bool {
    matches!(grid.allow_user_resizing, 2 | 3 | 5 | 6)
}

fn row_start_indicator_width_resize_hit(grid: &VolvoxGrid, px: i32, data_x: i32) -> bool {
    if !grid.indicator_bands.row_start.visible || !grid.indicator_bands.row_start.allow_resize {
        return false;
    }
    let hit_half = header_resize_hit_half_width(grid).max(1);
    px >= (data_x - hit_half).max(0) && px < data_x
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
                .visible_rows(scroll_y, grid.data_viewport_height(), first_scrollable_row);
        first.clamp(first_scrollable_row, grid.rows - 1)
    };

    let first_scrollable_col = grid.first_scrollable_col().clamp(0, grid.cols);
    let left_col = if first_scrollable_col >= grid.cols {
        first_scrollable_col.saturating_sub(1).max(0)
    } else {
        let (first, _) =
            grid.layout
                .visible_cols(scroll_x, grid.data_viewport_width(), first_scrollable_col);
        first.clamp(first_scrollable_col, grid.cols - 1)
    };

    (top_row, left_col)
}

fn scroll_by_with_options(grid: &mut VolvoxGrid, dx: f32, dy: f32, emit_before: bool) -> bool {
    if dx != 0.0 || dy != 0.0 {
        let _ = bump_scrollbar_fade(grid);
    }
    let old = visible_top_left_for_scroll(grid, grid.scroll.scroll_x, grid.scroll.scroll_y);

    let mut next_scroll = grid.scroll.clone();
    next_scroll.scroll_by(dx, dy);
    if grid.is_tui_mode() {
        next_scroll.quantize_to_cells();
    }
    let predicted = visible_top_left_for_scroll(grid, next_scroll.scroll_x, next_scroll.scroll_y);
    if emit_before && old != predicted {
        grid.events.push(GridEventData::BeforeScroll {
            old_top_row: old.0,
            old_left_col: old.1,
            new_top_row: predicted.0,
            new_left_col: predicted.1,
        });
    }

    grid.scroll.scroll_by(dx, dy);
    grid.normalize_scroll_for_mode();

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

fn scroll_by_with_events(grid: &mut VolvoxGrid, dx: f32, dy: f32) -> bool {
    scroll_by_with_options(grid, dx, dy, true)
}

fn scroll_to_with_options(grid: &mut VolvoxGrid, x: f32, y: f32, emit_before: bool) -> bool {
    let _ = bump_scrollbar_fade(grid);
    let old = visible_top_left_for_scroll(grid, grid.scroll.scroll_x, grid.scroll.scroll_y);

    let mut next_scroll = grid.scroll.clone();
    next_scroll.scroll_to(x, y);
    if grid.is_tui_mode() {
        next_scroll.quantize_to_cells();
    }
    let predicted = visible_top_left_for_scroll(grid, next_scroll.scroll_x, next_scroll.scroll_y);
    if emit_before && old != predicted {
        grid.events.push(GridEventData::BeforeScroll {
            old_top_row: old.0,
            old_left_col: old.1,
            new_top_row: predicted.0,
            new_left_col: predicted.1,
        });
    }

    grid.scroll.scroll_to(x, y);
    grid.normalize_scroll_for_mode();

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
    scroll_to_with_options(grid, x, y, true)
}

pub fn apply_node_toggle_after_before(grid: &mut VolvoxGrid, row: i32, collapse: bool) {
    if row < grid.fixed_rows || row >= grid.rows {
        return;
    }
    if let Some(node_id) = grid.tree.node_id_at_row(grid.fixed_rows, row) {
        let node_id = node_id.to_string();
        if !collapse
            && grid.tree.row_children_state(grid.fixed_rows, row)
                == Some(pb::NodeChildrenState::NodeChildrenUnloaded as i32)
        {
            let request_id = grid.next_tree_request_id();
            grid.events.push(GridEventData::TreeChildrenRequested {
                node_id,
                row,
                request_id,
            });
            return;
        }
        let grid_id = grid.id;
        let result = if collapse {
            let request = pb::CollapseNodesRequest {
                grid_id,
                node_ids: vec![node_id.clone()],
                recursive: false,
            };
            crate::tree::collapse_nodes(grid, request).map(|_| ())
        } else {
            let request = pb::ExpandNodesRequest {
                grid_id,
                node_ids: vec![node_id.clone()],
                recursive: false,
            };
            crate::tree::expand_nodes(grid, request).map(|_| ())
        };
        match result {
            Ok(()) => {
                grid.events.push(GridEventData::AfterTreeNodeToggle {
                    node_id,
                    row,
                    collapse,
                });
                if collapse {
                    normalize_selection_to_visible_row(grid, row);
                }
                grid.mark_dirty();
            }
            Err(err) => {
                normalize_selection_to_visible_row(grid, row);
                grid.mark_dirty();
                grid.events.push(GridEventData::Error {
                    code: crate::tree::error_code(&err),
                    message: err.to_string(),
                });
            }
        }
        return;
    }
    crate::outline::toggle_collapse(grid, row);
    if collapse {
        normalize_selection_to_visible_row(grid, row);
    }
    grid.events
        .push(GridEventData::AfterNodeToggle { row, collapse });
    grid.mark_dirty();
}

pub fn begin_user_resize_after_before(grid: &mut VolvoxGrid, row: i32, col: i32, start_pos: f32) {
    if col >= 0 && col < grid.cols && col_resize_enabled(grid) {
        grid.resize_active = true;
        grid.resize_is_col = true;
        grid.resize_index = col;
        grid.resize_start_pos = start_pos;
        grid.resize_start_size = grid.get_col_width(col);
    } else if row >= 0 && row < grid.rows && row_resize_enabled(grid) {
        grid.resize_active = true;
        grid.resize_is_col = false;
        grid.resize_index = row;
        grid.resize_start_pos = start_pos;
        grid.resize_start_size = grid.get_row_height(row);
    }
}

pub fn begin_row_start_indicator_width_resize(grid: &mut VolvoxGrid, start_pos: f32) {
    if !grid.indicator_bands.row_start.visible || !grid.indicator_bands.row_start.allow_resize {
        return;
    }
    grid.resize_active = true;
    grid.resize_is_col = true;
    grid.resize_index = -1;
    grid.resize_start_pos = start_pos;
    grid.resize_start_size = grid.indicator_bands.row_start.resolved_width_px();
}

fn set_row_start_indicator_width(grid: &mut VolvoxGrid, width_px: i32) {
    let width_px = width_px.max(1);
    grid.indicator_bands.row_start.width_px = width_px;
    grid.indicator_bands.row_start.auto_size = false;
    grid.indicator_bands.row_start.fit_slots_to_width();
}

pub fn apply_move_column_after_before(grid: &mut VolvoxGrid, col: i32, new_position: i32) -> bool {
    let Some(old_position) = grid.col_positions.iter().position(|&c| c == col) else {
        return false;
    };
    let new_position = new_position.clamp(0, grid.cols.saturating_sub(1)) as usize;
    if new_position == old_position {
        return false;
    }
    if grid.move_col_by_positions(old_position as i32, new_position as i32) {
        grid.events.push(GridEventData::AfterMoveColumn {
            col,
            old_position: old_position as i32,
        });
        grid.mark_dirty();
        true
    } else {
        false
    }
}

pub fn apply_move_row_after_before(grid: &mut VolvoxGrid, row: i32, new_position: i32) -> bool {
    if row < grid.fixed_rows || row >= grid.rows {
        return false;
    }
    if new_position < grid.fixed_rows || new_position >= grid.rows {
        return false;
    }
    if row == new_position {
        return false;
    }
    if grid.row_positions.is_empty() {
        grid.row_positions = (0..grid.rows).collect();
    }

    let moving = grid.row_positions.remove(row as usize);
    grid.row_positions.insert(new_position as usize, moving);
    grid.cells.set_row_map(grid.row_positions.clone());
    grid.layout.invalidate();
    grid.events.push(GridEventData::AfterMoveRow {
        row,
        old_position: row,
    });
    grid.mark_dirty();
    true
}

pub fn preview_wheel_scroll_event(
    grid: &mut VolvoxGrid,
    delta_x: f32,
    delta_y: f32,
) -> Option<(i32, i32, i32, i32)> {
    if grid.col_drag_active || grid.col_drag_pending {
        return None;
    }

    let line_height = if grid.is_tui_mode() {
        1.0
    } else {
        grid.default_row_height as f32
    };
    let dx = delta_x * line_height;
    let dy = delta_y * line_height;
    if dx == 0.0 && dy == 0.0 {
        return None;
    }

    let old = visible_top_left_for_scroll(grid, grid.scroll.scroll_x, grid.scroll.scroll_y);
    let mut next_scroll = grid.scroll.clone();
    next_scroll.scroll_by(dx, dy);
    if grid.is_tui_mode() {
        next_scroll.quantize_to_cells();
    }
    let predicted = visible_top_left_for_scroll(grid, next_scroll.scroll_x, next_scroll.scroll_y);
    (old != predicted).then_some((old.0, old.1, predicted.0, predicted.1))
}

pub fn scroll_to(grid: &mut VolvoxGrid, x: f32, y: f32) -> bool {
    scroll_to_with_events(grid, x, y)
}

fn begin_edit_from_input_with_options(grid: &mut VolvoxGrid, row: i32, col: i32, caret_end: bool) {
    if !grid.can_begin_edit(row, col, false) {
        return;
    }
    if is_boolean_checkbox_cell(grid, row, col) {
        return;
    }

    let dropdown = grid.active_dropdown(row, col);
    let has_dropdown = dropdown.is_some();
    grid.events.push(GridEventData::BeforeEdit { row, col });

    let stored_text = grid.cells.get_text(row, col).to_string();
    let display_text = grid.get_display_text(row, col);

    if caret_end || grid.is_tui_mode() {
        // Edit mode: caret positioned for in-place editing.
        // TUI: always use Edit mode with select-all so the user can type to
        // replace or press arrows to deselect and edit in place.
        grid.edit
            .start_edit_with_options(row, col, &display_text, None, Some(true), None, None);
        if !caret_end && grid.is_tui_mode() {
            grid.edit.select_all();
        }
    } else {
        grid.edit.start_edit(row, col, &display_text);
    }
    grid.edit.configure_compose(
        grid.effective_engine_compose_enabled(),
        grid.effective_compose_method(),
    );
    if let Some(dropdown) = dropdown.as_ref() {
        grid.edit.parse_dropdown(dropdown);
    } else {
        let dropdown_list = grid.active_dropdown_list(row, col);
        grid.edit.parse_dropdown_items(&dropdown_list);
    }
    // Initialize dropdown index from stored translated value (preferred), or display text.
    if has_dropdown {
        for i in 0..grid.edit.dropdown_count() {
            if (!stored_text.is_empty() && grid.edit.get_dropdown_data(i) == stored_text)
                || grid.edit.get_dropdown_item(i) == display_text
            {
                grid.edit.set_dropdown_index(i);
                break;
            }
        }
    }
    if has_dropdown {
        if let Some(event) = grid.before_dropdown_open_event(row, col) {
            grid.events.push(event);
        }
        grid.events.push(GridEventData::DropdownOpened);
    }
    grid.events.push(GridEventData::StartEdit { row, col });
    grid.mark_dirty();
}

fn begin_edit_from_input(grid: &mut VolvoxGrid, row: i32, col: i32) {
    begin_edit_from_input_with_options(grid, row, col, false);
}

fn active_edit_caret_from_pointer_x_in_cell(
    grid: &mut VolvoxGrid,
    row: i32,
    col: i32,
    x_in_cell: f32,
) -> Option<i32> {
    if grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col {
        Some(grid.caret_index_from_display_click(row, col, x_in_cell))
    } else {
        None
    }
}

fn place_active_edit_caret_from_pointer_click(
    grid: &mut VolvoxGrid,
    row: i32,
    col: i32,
    x_in_cell: f32,
) -> Option<i32> {
    let caret = active_edit_caret_from_pointer_x_in_cell(grid, row, col, x_in_cell)?;
    grid.edit.set_selection_anchor_and_caret(caret, caret);
    grid.mark_dirty();
    Some(caret)
}

fn update_active_edit_pointer_selection(grid: &mut VolvoxGrid, x: f32) -> bool {
    if !grid.edit_pointer_select_active || !grid.edit.is_active() {
        return false;
    }

    let row = grid.edit.edit_row;
    let col = grid.edit.edit_col;
    let Some((cx, _, _, _)) = grid.cell_screen_rect(row, col) else {
        grid.edit_pointer_select_active = false;
        return false;
    };
    let x_in_cell = x - cx as f32;
    let Some(caret) = active_edit_caret_from_pointer_x_in_cell(grid, row, col, x_in_cell) else {
        grid.edit_pointer_select_active = false;
        return false;
    };

    grid.edit
        .set_selection_anchor_and_caret(grid.edit_pointer_select_anchor, caret);
    grid.mark_dirty();
    true
}

fn begin_edit_from_pointer_double_click(grid: &mut VolvoxGrid, row: i32, col: i32, x_in_cell: f32) {
    begin_edit_from_input_with_options(grid, row, col, true);
    if let Some(anchor) = place_active_edit_caret_from_pointer_click(grid, row, col, x_in_cell) {
        grid.edit_pointer_select_active = true;
        grid.edit_pointer_select_anchor = anchor;
    }
}

fn commit_active_edit(grid: &mut VolvoxGrid) -> bool {
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
        grid.mark_dirty();
        true
    } else {
        false
    }
}

fn apply_compose_result(grid: &mut VolvoxGrid, result: ComposeResult) -> bool {
    let before_text = grid.edit.edit_text.clone();
    match result {
        ComposeResult::Pending { preedit, cursor } => {
            if preedit.is_empty() {
                grid.edit.cancel_preedit();
            } else {
                grid.edit.set_preedit(&preedit, cursor);
            }
        }
        ComposeResult::Commit { text } => {
            if !text.is_empty() {
                grid.edit.commit_preedit(&text);
            } else {
                grid.edit.cancel_preedit();
            }
        }
        ComposeResult::CommitPending {
            commit,
            preedit,
            cursor,
        } => {
            if !commit.is_empty() {
                grid.edit.commit_preedit(&commit);
            }
            if preedit.is_empty() {
                grid.edit.cancel_preedit();
            } else {
                grid.edit.set_preedit(&preedit, cursor);
            }
        }
        ComposeResult::Pass => return false,
    }

    if grid.edit.edit_text != before_text {
        grid.events.push(GridEventData::CellEditChange {
            text: grid.edit.edit_text.clone(),
        });
    }
    grid.mark_dirty();
    true
}

fn flush_engine_compose(grid: &mut VolvoxGrid) -> bool {
    if !grid.edit.is_engine_composing() {
        return false;
    }

    let before_text = grid.edit.edit_text.clone();
    grid.edit.flush_preedit();
    if grid.edit.edit_text != before_text {
        grid.events.push(GridEventData::CellEditChange {
            text: grid.edit.edit_text.clone(),
        });
    }
    grid.mark_dirty();
    true
}

fn should_flush_engine_compose_on_key_down(key_code: i32, ctrl: bool) -> bool {
    matches!(key_code, 9 | 13 | 27 | 35 | 36 | 37 | 38 | 39 | 40 | 46) || (ctrl && key_code == 65)
}

pub fn commit_dropdown_item_click(grid: &mut VolvoxGrid, idx: i32) -> bool {
    if idx < 0 || idx >= grid.edit.dropdown_count() {
        return false;
    }

    grid.edit.set_dropdown_index(idx);
    grid.edit.clear_dropdown_search();
    let text = grid.edit.get_dropdown_item(idx).to_string();
    grid.edit.update_text(text.clone());
    grid.events.push(GridEventData::CellEditChange { text });

    grid.dropdown_click_active = true;
    grid.commit_edit();
    grid.mark_dirty();
    true
}

fn move_selection_after_edit_commit(grid: &mut VolvoxGrid, row: i32, col: i32) {
    let old_row = grid.selection.row;
    let old_col = grid.selection.col;
    let old_row_end = grid.selection.row_end;
    let old_col_end = grid.selection.col_end;
    grid.selection.set_cursor(
        row,
        col,
        grid.rows,
        grid.cols,
        grid.fixed_rows,
        grid.fixed_cols,
    );

    let cursor_changed = grid.selection.row != old_row || grid.selection.col != old_col;
    let extent_changed =
        grid.selection.row_end != old_row_end || grid.selection.col_end != old_col_end;

    if cursor_changed {
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
            grid.data_viewport_width(),
            grid.data_viewport_height(),
            grid.fixed_rows,
            grid.fixed_cols,
            grid.pinned_top_height() + grid.pinned_bottom_height(),
            grid.pinned_left_width() + grid.pinned_right_width(),
        );
        grid.mark_dirty();
    } else if extent_changed {
        grid.scroll.show_cell(
            grid.selection.row_end,
            grid.selection.col_end,
            &grid.layout,
            grid.data_viewport_width(),
            grid.data_viewport_height(),
            grid.fixed_rows,
            grid.fixed_cols,
            grid.pinned_top_height() + grid.pinned_bottom_height(),
            grid.pinned_left_width() + grid.pinned_right_width(),
        );
        grid.mark_dirty();
    }
}

fn row_can_receive_focus(grid: &VolvoxGrid, row: i32) -> bool {
    row >= grid.fixed_rows && row < grid.rows && !grid.is_row_hidden(row)
}

fn visible_focus_row_at_or_after(grid: &VolvoxGrid, row: i32) -> Option<i32> {
    if grid.rows <= 0 {
        return None;
    }
    let start = row.clamp(grid.fixed_rows, grid.rows - 1);
    (start..grid.rows).find(|&candidate| row_can_receive_focus(grid, candidate))
}

fn visible_focus_row_at_or_before(grid: &VolvoxGrid, row: i32) -> Option<i32> {
    if grid.rows <= 0 {
        return None;
    }
    let start = row.clamp(grid.fixed_rows, grid.rows - 1);
    (grid.fixed_rows..=start)
        .rev()
        .find(|&candidate| row_can_receive_focus(grid, candidate))
}

fn nearest_visible_focus_row(grid: &VolvoxGrid, row: i32, prefer_after: bool) -> Option<i32> {
    if prefer_after {
        visible_focus_row_at_or_after(grid, row)
            .or_else(|| visible_focus_row_at_or_before(grid, row))
    } else {
        visible_focus_row_at_or_before(grid, row)
            .or_else(|| visible_focus_row_at_or_after(grid, row))
    }
}

fn visible_focus_row_with_delta(grid: &VolvoxGrid, row: i32, delta: i32) -> i32 {
    if delta == 0 {
        return nearest_visible_focus_row(grid, row, true).unwrap_or(row);
    }

    let prefer_after = delta > 0;
    let starts_on_visible_row = row_can_receive_focus(grid, row);
    let Some(mut current) = nearest_visible_focus_row(grid, row, prefer_after) else {
        return row;
    };

    let steps = if starts_on_visible_row {
        delta.unsigned_abs()
    } else {
        delta.unsigned_abs().saturating_sub(1)
    };
    for _ in 0..steps {
        let next = if delta > 0 {
            current
                .checked_add(1)
                .and_then(|next_row| visible_focus_row_at_or_after(grid, next_row))
        } else {
            current
                .checked_sub(1)
                .and_then(|next_row| visible_focus_row_at_or_before(grid, next_row))
        };
        let Some(next) = next else {
            break;
        };
        current = next;
    }

    current
}

fn normalize_selection_to_visible_row(grid: &mut VolvoxGrid, fallback_row: i32) {
    if grid.rows <= 0 || grid.cols <= 0 {
        return;
    }
    if row_can_receive_focus(grid, grid.selection.row) {
        return;
    }
    let row = nearest_visible_focus_row(grid, fallback_row, false)
        .unwrap_or_else(|| grid.fixed_rows.min(grid.rows - 1));
    let col = grid.selection.col;
    grid.selection.set_cursor(
        row,
        col,
        grid.rows,
        grid.cols,
        grid.fixed_rows,
        grid.fixed_cols,
    );
}

fn set_fast_scroll_target_row(grid: &mut VolvoxGrid, target: i32, force: bool) {
    if grid.rows <= 0 {
        return;
    }
    let fixed = grid.fixed_rows.clamp(0, grid.rows.saturating_sub(1).max(0));
    let target = target.clamp(fixed, grid.rows - 1);
    if !force && target == grid.fast_scroll_target_row {
        return;
    }
    grid.fast_scroll_target_row = target;
    grid.set_top_row(target);
    grid.mark_dirty_visual();
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
    let fixed = grid.fixed_rows;
    let data_rows = grid.rows - fixed;
    if data_rows <= 1 {
        return;
    }

    if y <= track_top {
        set_fast_scroll_target_row(grid, fixed, true);
        return;
    }
    if y >= track_bottom {
        set_fast_scroll_target_row(grid, grid.rows - 1, true);
        return;
    }

    let ratio = ((y - track_top) / track_height).clamp(0.0, 1.0);
    let target = fixed + (ratio * (data_rows - 1) as f32).round() as i32;
    set_fast_scroll_target_row(grid, target, false);
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
    if hit.area != HitArea::DropdownButton && clear_dropdown_button_pressed(grid) {
        grid.mark_dirty();
    }
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

pub fn take_column_drag_move(grid: &mut VolvoxGrid) -> Option<(i32, i32)> {
    if !grid.col_drag_active {
        return None;
    }

    let source = grid.col_drag_source;
    let insert_before = grid.col_drag_insert_pos;
    clear_col_drag_active(grid);

    if source < 0 || insert_before < 0 {
        return None;
    }

    let src_pos = grid.col_positions.iter().position(|&c| c == source)?;
    let desired_gap = insert_before.clamp(0, grid.cols) as usize;
    let mut insert_pos = desired_gap;
    if insert_pos > src_pos {
        insert_pos -= 1;
    }
    insert_pos = insert_pos.min(grid.col_positions.len());

    (insert_pos != src_pos).then_some((source, insert_pos as i32))
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
    if grid.resolved_cell_control(row, col) == CellControl::None {
        return false;
    }
    match grid.dropdown_trigger {
        b if b == pb::DropdownTrigger::DropdownAlways as i32 => true,
        b if b == pb::DropdownTrigger::DropdownOnEdit as i32 => {
            grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col
        }
        /* ActiveX compatibility: show on current cell when button-like controls exist. */
        3 => grid.selection.row == row && grid.selection.col == col,
        _ => false,
    }
}

fn dropdown_button_rect(cx: i32, cy: i32, cw: i32, ch: i32) -> Option<(i32, i32, i32, i32)> {
    crate::canvas::dropdown_button_rect(cx, cy, cw, ch)
}

fn is_boolean_checkbox_cell(grid: &VolvoxGrid, row: i32, col: i32) -> bool {
    row >= grid.fixed_rows
        && row < grid.rows
        && col >= 0
        && col < grid.cols
        && !grid.row_props.get(&row).map_or(false, |rp| rp.is_subtotal)
        && grid.get_col_props(col).map_or(false, |cp| {
            cp.data_type == pb::ColumnDataType::ColumnDataBoolean as i32
        })
}

fn checkbox_rect(grid: &VolvoxGrid, row: i32, col: i32) -> Option<(i32, i32, i32, i32)> {
    if !is_boolean_checkbox_cell(grid, row, col) {
        return None;
    }

    let (cx, cy, cw, ch) = grid.cell_screen_rect(row, col)?;
    let box_size = crate::canvas::checkbox_box_size(ch);
    let style_override = grid.get_cell_style(row, col);
    let alignment = crate::canvas::resolve_alignment(grid, row, col, &style_override, "");
    let (halign, valign) = crate::canvas::alignment_components(alignment);

    let max_bx = cx + cw - box_size;
    let max_by = cy + ch - box_size;
    if max_bx < cx || max_by < cy {
        return None;
    }

    let bx = match halign {
        0 => cx + 3,
        1 => cx + (cw - box_size) / 2,
        _ => cx + cw - box_size - 3,
    }
    .clamp(cx, max_bx);

    let by = match valign {
        0 => cy + 1,
        1 => cy + (ch - box_size) / 2,
        _ => cy + ch - box_size - 1,
    }
    .clamp(cy, max_by);

    Some((bx, by, box_size, box_size))
}

fn point_in_rect(px: i32, py: i32, rect: (i32, i32, i32, i32)) -> bool {
    let (rx, ry, rw, rh) = rect;
    px >= rx && px < rx + rw && py >= ry && py < ry + rh
}

fn first_subtotal_level(grid: &VolvoxGrid) -> i32 {
    grid.row_props
        .values()
        .filter(|rp| rp.is_subtotal)
        .map(|rp| rp.outline_level)
        .filter(|level| *level > 0)
        .min()
        .unwrap_or(0)
}

fn subtotal_visual_level(level: i32, is_subtotal: bool, subtotal_level_floor: i32) -> i32 {
    if is_subtotal {
        if level < 0 {
            0
        } else {
            (level - subtotal_level_floor + 1).max(1)
        }
    } else {
        (2 - subtotal_level_floor).max(1)
    }
}

fn outline_visual_depth(grid: &VolvoxGrid, row: i32) -> Option<i32> {
    if let Some(level) = grid.tree.row_level(grid.fixed_rows, row) {
        return Some(level.max(0));
    }
    let rp = grid.get_row_props(row)?;
    let has_subtotal_nodes = grid.row_props.values().any(|props| props.is_subtotal);
    if has_subtotal_nodes {
        Some(
            (subtotal_visual_level(rp.outline_level, rp.is_subtotal, first_subtotal_level(grid))
                - 1)
            .max(0),
        )
    } else {
        Some(crate::outline::outline_visual_depth_for_level(
            grid,
            rp.outline_level,
        ))
    }
}

fn outline_row_has_children(grid: &VolvoxGrid, row: i32) -> bool {
    if grid.tree.node_id_at_row(grid.fixed_rows, row).is_some() {
        return grid.tree.row_has_children(grid.fixed_rows, row);
    }
    let Some(rp) = grid.get_row_props(row) else {
        return false;
    };
    rp.is_subtotal || crate::outline::get_node(grid, row).3 > 0
}

fn row_start_has_expander_slot(grid: &VolvoxGrid) -> bool {
    grid.indicator_bands.row_start.visible
        && grid.indicator_bands.row_start.slots.iter().any(|slot| {
            slot.visible && slot.kind == pb::RowIndicatorSlotKind::RowIndicatorSlotExpander as i32
        })
        && grid.outline.tree_indicator != pb::TreeIndicatorStyle::TreeIndicatorNone as i32
}

pub fn selected_row_uses_outline_expander(grid: &VolvoxGrid) -> bool {
    let row = grid.selection.row;
    row >= grid.fixed_rows && row < grid.rows && row_start_has_expander_slot(grid)
}

pub fn selected_outline_label_keyboard_target(grid: &VolvoxGrid) -> Option<(i32, i32)> {
    let row = grid.selection.row;
    if !grid.is_tui_mode() || !selected_row_uses_outline_expander(grid) {
        return None;
    }
    let col = grid.outline.label_column;
    if col < 0 || col >= grid.cols || !grid.is_col_hidden(col) {
        return None;
    }
    if grid.selection.col != col {
        return None;
    }
    Some((row, col))
}

pub fn selected_outline_node_toggle_target(grid: &VolvoxGrid) -> Option<(i32, bool)> {
    let (row, _) = selected_outline_label_keyboard_target(grid)?;
    if !outline_row_has_children(grid, row) {
        return None;
    }
    let collapse = !grid.row_props.get(&row).map_or(false, |rp| rp.is_collapsed);
    Some((row, collapse))
}

pub fn selected_outline_label_edit_target(grid: &VolvoxGrid) -> Option<(i32, i32)> {
    let (row, col) = selected_outline_label_keyboard_target(grid)?;
    if !grid.can_begin_edit(row, col, false) {
        return None;
    }
    Some((row, col))
}

pub fn toggle_selected_outline_node(grid: &mut VolvoxGrid) -> bool {
    let Some((row, collapse)) = selected_outline_node_toggle_target(grid) else {
        return false;
    };
    if let Some(node_id) = grid.tree.node_id_at_row(grid.fixed_rows, row) {
        grid.events.push(GridEventData::BeforeTreeNodeToggle {
            node_id: node_id.to_string(),
            row,
            collapse,
        });
    } else {
        grid.events
            .push(GridEventData::BeforeNodeToggle { row, collapse });
    }
    apply_node_toggle_after_before(grid, row, collapse);
    true
}

fn tree_style_draws_connectors(grid: &VolvoxGrid) -> bool {
    grid.outline.tree_indicator == pb::TreeIndicatorStyle::TreeIndicatorConnectors as i32
        || grid.outline.tree_indicator == pb::TreeIndicatorStyle::TreeIndicatorConnectorsLeaf as i32
}

fn row_indicator_expander_toggle_hit(
    grid: &VolvoxGrid,
    vp: &VisibleRange,
    row: i32,
    px: i32,
) -> bool {
    if !outline_row_has_children(grid, row) {
        return false;
    }
    let band = &grid.indicator_bands.row_start;
    let visible_slot_count = band.slots.iter().filter(|slot| slot.visible).count();
    let mut slot_x = 0;
    for slot in band.slots.iter().filter(|slot| slot.visible) {
        let remaining = (vp.data_x - slot_x).max(0);
        if remaining <= 0 {
            break;
        }
        let slot_w = if visible_slot_count == 1 {
            remaining
        } else {
            slot.width_px.max(1).min(remaining)
        };
        if slot.kind == pb::RowIndicatorSlotKind::RowIndicatorSlotExpander as i32 {
            let depth = outline_visual_depth(grid, row).unwrap_or(0);
            if grid.is_tui_mode() && tree_style_draws_connectors(grid) {
                let branch_x = if depth > 0 { (depth - 1) * 4 } else { 0 };
                let hit_start = (slot_x + branch_x).clamp(slot_x, slot_x + slot_w);
                let hit_end = (hit_start + if depth > 0 { 4 } else { 2 }).min(slot_x + slot_w);
                return px >= hit_start && px < hit_end.max(hit_start + 1);
            }

            let tg = crate::outline::TreeGeometry::from_grid(grid);
            let indent_x = (slot_x + depth * tg.indent_step).min(slot_x + slot_w - 1);
            let toggle_size = tg.btn_size.max(1);
            let bx = (indent_x + tg.line_offset - toggle_size / 2)
                .clamp(slot_x, (slot_x + slot_w - toggle_size).max(slot_x));
            return px >= bx && px < bx + toggle_size;
        }
        slot_x += slot_w;
    }
    false
}

fn corner_outline_level_hit(grid: &VolvoxGrid, px: i32, width: i32) -> Option<i32> {
    let corner = &grid.indicator_bands.corner_top_start;
    if !grid.outline.show_level_buttons || !corner.visible || corner.slots.is_empty() {
        return None;
    }
    let visible_slot_count = corner.slots.iter().filter(|slot| slot.visible).count();
    let mut slot_x = 0;
    for slot in corner.slots.iter().filter(|slot| slot.visible) {
        let remaining = (width - slot_x).max(0);
        if remaining <= 0 {
            break;
        }
        let slot_w = if visible_slot_count == 1 {
            remaining
        } else if slot.width_px > 0 {
            slot.width_px.min(remaining)
        } else if slot.kind == pb::CornerIndicatorSlotKind::CornerSlotOutlineLevels as i32 {
            let button_count = crate::outline::outline_level_button_count(grid);
            crate::outline::outline_level_button_step(grid, remaining)
                .saturating_mul(button_count)
                .min(remaining)
        } else {
            remaining
        };
        if slot.kind == pb::CornerIndicatorSlotKind::CornerSlotOutlineLevels as i32 {
            let min_level = crate::outline::outline_level_button_min(grid);
            let max_level = crate::outline::outline_level_button_max(grid);
            if max_level < min_level || px < slot_x || px >= slot_x + slot_w {
                return None;
            }
            let step = crate::outline::outline_level_button_step(grid, slot_w).max(1);
            let button_idx = (px - slot_x) / step;
            let level = min_level + button_idx;
            return (level >= min_level && level <= max_level).then_some(level);
        }
        slot_x += slot_w;
    }
    None
}

fn corner_outline_level_hit_from_result(
    grid: &VolvoxGrid,
    hit: &HitTestResult,
    px: f32,
) -> Option<i32> {
    if hit.area != HitArea::IndicatorCornerTopStart {
        return None;
    }
    if !grid.indicator_bands.corner_top_start.visible {
        return None;
    }
    corner_outline_level_hit(grid, px as i32, grid.indicator_bands.start_width())
}

fn parse_png_dimensions(data: &[u8]) -> Option<(i32, i32)> {
    if data.len() < 24 || &data[0..8] != b"\x89PNG\r\n\x1a\n" || &data[12..16] != b"IHDR" {
        return None;
    }

    let width = u32::from_be_bytes([data[16], data[17], data[18], data[19]]) as i32;
    let height = u32::from_be_bytes([data[20], data[21], data[22], data[23]]) as i32;
    if width <= 0 || height <= 0 {
        None
    } else {
        Some((width, height))
    }
}

fn image_rect_from_alignment(
    cx: i32,
    cy: i32,
    cw: i32,
    ch: i32,
    img_w: i32,
    img_h: i32,
    align: i32,
) -> Option<(i32, i32, i32, i32)> {
    if cw <= 0 || ch <= 0 || img_w <= 0 || img_h <= 0 {
        return None;
    }

    let rect = match align {
        a if a == pb::ImageAlignment::ImgAlignLeftTop as i32 => (cx, cy, img_w, img_h),
        a if a == pb::ImageAlignment::ImgAlignLeftCenter as i32 => {
            (cx, cy + (ch - img_h) / 2, img_w, img_h)
        }
        a if a == pb::ImageAlignment::ImgAlignLeftBottom as i32 => {
            (cx, cy + ch - img_h, img_w, img_h)
        }
        a if a == pb::ImageAlignment::ImgAlignCenterTop as i32 => {
            (cx + (cw - img_w) / 2, cy, img_w, img_h)
        }
        a if a == pb::ImageAlignment::ImgAlignCenterCenter as i32 => {
            (cx + (cw - img_w) / 2, cy + (ch - img_h) / 2, img_w, img_h)
        }
        a if a == pb::ImageAlignment::ImgAlignCenterBottom as i32 => {
            (cx + (cw - img_w) / 2, cy + ch - img_h, img_w, img_h)
        }
        a if a == pb::ImageAlignment::ImgAlignRightTop as i32 => {
            (cx + cw - img_w, cy, img_w, img_h)
        }
        a if a == pb::ImageAlignment::ImgAlignRightCenter as i32 => {
            (cx + cw - img_w, cy + (ch - img_h) / 2, img_w, img_h)
        }
        a if a == pb::ImageAlignment::ImgAlignRightBottom as i32 => {
            (cx + cw - img_w, cy + ch - img_h, img_w, img_h)
        }
        a if a == pb::ImageAlignment::ImgAlignStretch as i32 => (cx, cy, cw, ch),
        _ => (cx, cy, img_w, img_h),
    };

    Some(rect)
}

fn button_picture_rect(
    grid: &VolvoxGrid,
    row: i32,
    col: i32,
    cx: i32,
    cy: i32,
    cw: i32,
    ch: i32,
) -> Option<(i32, i32, i32, i32)> {
    let cell = grid.cells.get(row, col)?;
    let data = cell.button_picture()?;
    let (img_w, img_h) = parse_png_dimensions(data)?;
    let (bx, by, bw, bh) = dropdown_button_rect(cx, cy, cw, ch)?;
    let draw_w = img_w.min(bw).max(1);
    let draw_h = img_h.min(bh).max(1);
    Some((
        bx + (bw - draw_w) / 2,
        by + (bh - draw_h) / 2,
        draw_w,
        draw_h,
    ))
}

fn text_content_rect(
    grid: &mut VolvoxGrid,
    row: i32,
    col: i32,
    cx: i32,
    cy: i32,
    cw: i32,
    ch: i32,
) -> Option<(i32, i32, i32, i32)> {
    if cw <= 0 || ch <= 0 {
        return None;
    }

    let meta = grid.build_text_cell_static_meta(row, col);
    if meta.suppress_text || meta.display_text.is_empty() {
        return None;
    }

    let font_name = meta
        .style_override
        .font_name
        .clone()
        .unwrap_or_else(|| grid.style.font_name.clone());
    let font_size = meta
        .style_override
        .font_size
        .unwrap_or(grid.style.font_size);
    let font_bold = meta
        .style_override
        .font_bold
        .unwrap_or(grid.style.font_bold);
    let font_italic = meta
        .style_override
        .font_italic
        .unwrap_or(grid.style.font_italic);

    let word_wrap = grid.word_wrap;
    let button_reserve = if show_dropdown_button_for_cell(grid, row, col) {
        dropdown_button_rect(cx, cy, cw, ch).map_or(0, |(_, _, bw, _)| bw + 2)
    } else {
        0
    };
    let usable_w = (cw - button_reserve).max(1);
    let inner_left = cx + meta.padding.left;
    let inner_right = cx + usable_w - meta.padding.right;
    let inner_w = (inner_right - inner_left).max(1);
    let inner_top = cy + meta.padding.top;
    let inner_bottom = cy + ch - meta.padding.bottom;
    let inner_h = (inner_bottom - inner_top).max(1);
    let wrap_width = if word_wrap {
        Some(inner_w as f32)
    } else {
        None
    };

    let te = grid.ensure_text_engine();
    let measure =
        |sample: &str, size: f32, max_width: Option<f32>, te: &mut crate::text::TextEngine| {
            if te.has_fonts() {
                te.measure_text(sample, &font_name, size, font_bold, font_italic, max_width)
            } else {
                let char_w = size * 0.6;
                let natural_w = sample.chars().count() as f32 * char_w;
                let line_h = size * 1.2;
                if let Some(max_w) = max_width {
                    let safe_max = max_w.max(1.0);
                    let lines = (natural_w / safe_max).ceil().max(1.0);
                    (natural_w.min(safe_max), line_h * lines)
                } else {
                    (natural_w, line_h)
                }
            }
        };

    let (mut tw, mut th) = measure(meta.display_text.as_ref(), font_size, wrap_width, te);
    if meta.shrink_to_fit && !word_wrap && tw > inner_w as f32 && inner_w > 0 {
        let scale = inner_w as f32 / tw;
        let shrunk = (font_size * scale).floor().max(6.0);
        (tw, th) = measure(meta.display_text.as_ref(), shrunk, None, te);
    }

    let text_w = tw.ceil().max(1.0) as i32;
    let text_h = th.ceil().max(1.0) as i32;
    let (halign, valign) = crate::canvas::alignment_components(meta.alignment);
    let text_x = match halign {
        0 => inner_left,
        1 => inner_left + (inner_w - text_w).max(0) / 2,
        _ => inner_right - text_w,
    };
    let text_y = match valign {
        0 => inner_top,
        1 => inner_top + (inner_h - text_h).max(0) / 2,
        _ => inner_bottom - text_h,
    };

    Some((text_x, text_y, text_w, text_h))
}

fn hit_area_to_proto(area: &HitArea) -> i32 {
    match area {
        HitArea::CellText => pb::CellHitArea::HitText as i32,
        HitArea::CellPicture => pb::CellHitArea::HitPicture as i32,
        HitArea::CellButtonPicture | HitArea::OutlineButton => pb::CellHitArea::HitButton as i32,
        HitArea::CheckBox => pb::CellHitArea::HitCheckbox as i32,
        HitArea::DropdownButton => pb::CellHitArea::HitDropdown as i32,
        _ => pb::CellHitArea::HitCell as i32,
    }
}

fn resolved_click_interaction(grid: &VolvoxGrid, row: i32, col: i32) -> i32 {
    if row < 0 || col < 0 {
        pb::CellInteraction::None as i32
    } else {
        grid.resolved_cell_interaction(row, col)
    }
}

fn is_background_target(target: &EventTarget) -> bool {
    target.kind == pb::GridTargetKind::GridTargetBackground as i32
}

fn row_indicator_slot_at(grid: &VolvoxGrid, local_x: i32, width: i32) -> (i32, i32, String) {
    let band = &grid.indicator_bands.row_start;
    let visible_slot_count = band.slots.iter().filter(|slot| slot.visible).count();
    let mut slot_x = 0;
    for (slot_index, slot) in band
        .slots
        .iter()
        .enumerate()
        .filter(|(_, slot)| slot.visible)
    {
        let remaining = (width - slot_x).max(0);
        if remaining <= 0 {
            break;
        }
        let slot_w = if visible_slot_count == 1 {
            remaining
        } else {
            slot.width_px.max(1).min(remaining)
        };
        if local_x >= slot_x && local_x < slot_x + slot_w {
            return (slot_index as i32, slot.kind, slot.custom_key.clone());
        }
        slot_x += slot_w;
    }
    (-1, 0, String::new())
}

fn corner_indicator_slot_at(grid: &VolvoxGrid, local_x: i32, width: i32) -> (i32, i32, String) {
    let corner = &grid.indicator_bands.corner_top_start;
    if corner.slots.is_empty() {
        let slot_kind = if grid.selection.allow_selection {
            pb::CornerIndicatorSlotKind::CornerSlotSelectAll as i32
        } else {
            0
        };
        return (-1, slot_kind, corner.custom_key.clone());
    }

    let visible_slot_count = corner.slots.iter().filter(|slot| slot.visible).count();
    let mut slot_x = 0;
    for (slot_index, slot) in corner
        .slots
        .iter()
        .enumerate()
        .filter(|(_, slot)| slot.visible)
    {
        let remaining = (width - slot_x).max(0);
        if remaining <= 0 {
            break;
        }
        let slot_w = if visible_slot_count == 1 {
            remaining
        } else if slot.width_px > 0 {
            slot.width_px.min(remaining)
        } else if slot.kind == pb::CornerIndicatorSlotKind::CornerSlotOutlineLevels as i32 {
            let button_count = crate::outline::outline_level_button_count(grid);
            crate::outline::outline_level_button_step(grid, remaining)
                .saturating_mul(button_count)
                .min(remaining)
        } else {
            remaining
        };
        if local_x >= slot_x && local_x < slot_x + slot_w {
            return (slot_index as i32, slot.kind, slot.custom_key.clone());
        }
        slot_x += slot_w;
    }
    (-1, 0, String::new())
}

fn col_indicator_row_for_y(
    band: &crate::indicator::ColIndicatorState,
    local_y: i32,
) -> Option<i32> {
    let row_count = band.row_count().max(1);
    let mut y = 0;
    for row in 0..row_count {
        let h = band.row_height_px(row).max(1);
        if local_y >= y && local_y < y + h {
            return Some(row);
        }
        y += h;
    }
    None
}

fn col_indicator_cell_height(
    band: &crate::indicator::ColIndicatorState,
    row1: i32,
    row2: i32,
) -> i32 {
    let row1 = row1.max(0);
    let row2 = row2.max(row1);
    (row1..=row2)
        .map(|row| band.row_height_px(row).max(1))
        .sum()
}

fn col_indicator_sort_arrow_box_size(cell_h: i32, scale: f32) -> i32 {
    let scale = if scale.is_finite() && scale > 0.0 {
        scale
    } else {
        1.0
    };
    let logical_h = if scale > 1.001 {
        ((cell_h as f32) / scale).round() as i32
    } else {
        cell_h
    };
    let logical_box = logical_h.saturating_sub(6).clamp(8, 16);
    let device_box = if scale > 1.001 {
        ((logical_box as f32) * scale).round() as i32
    } else {
        logical_box
    };
    device_box.min(cell_h.saturating_sub(2).max(0))
}

fn col_indicator_sub_mode_bits(
    grid: &VolvoxGrid,
    col: i32,
    mode_bits: u32,
    cell_height: i32,
    x_in_col: f32,
) -> u32 {
    if col < 0 || col >= grid.cols {
        return 0;
    }
    let sort_mode = pb::ColIndicatorCellMode::ColIndicatorCellSortGlyph as u32;
    if mode_bits & sort_mode != 0 && grid.header_features & 1 != 0 {
        let (_, _, col_w, _) = grid.layout.cell_rect(0, col);
        let glyph_box =
            col_indicator_sort_arrow_box_size(cell_height, grid.scale).min((col_w - 4).max(0));
        if glyph_box >= 6 {
            let glyph_x = (col_w - glyph_box - 4).max(2);
            let x = x_in_col as i32;
            if x >= glyph_x && x < glyph_x + glyph_box {
                return sort_mode;
            }
        }
    }
    0
}

fn col_indicator_target_for_hit(grid: &VolvoxGrid, hit: &HitTestResult) -> EventTarget {
    let band = &grid.indicator_bands.col_top;
    let local_y = hit.y_in_cell as i32;
    let indicator_row = col_indicator_row_for_y(band, local_y).unwrap_or(0);
    for (slot_index, cell) in band.cells.iter().enumerate() {
        if hit.col < cell.col1
            || hit.col > cell.col2.max(cell.col1)
            || indicator_row < cell.row1
            || indicator_row > cell.row2.max(cell.row1)
        {
            continue;
        }
        let mode_bits = if cell.mode_bits != 0 {
            cell.mode_bits
        } else {
            band.mode_bits
        };
        let cell_height = col_indicator_cell_height(band, cell.row1, cell.row2);
        let sub_mode_bits =
            col_indicator_sub_mode_bits(grid, hit.col, mode_bits, cell_height, hit.x_in_cell);
        let slot_kind = if sub_mode_bits != 0 {
            sub_mode_bits as i32
        } else if mode_bits & (pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32) != 0 {
            pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as i32
        } else {
            mode_bits as i32
        };
        let cell_data = cell.data.clone();
        return EventTarget {
            kind: pb::GridTargetKind::GridTargetColIndicator as i32,
            band: pb::IndicatorBand::ColTop as i32,
            slot_index: slot_index as i32,
            slot_kind,
            sub_mode_bits,
            custom_key: cell.custom_key.clone(),
            data: cell_data,
            ..EventTarget::default()
        };
    }

    let slot_kind = if band.has_mode(pb::ColIndicatorCellMode::ColIndicatorCellHeaderText) {
        pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as i32
    } else {
        band.mode_bits as i32
    };
    EventTarget {
        kind: pb::GridTargetKind::GridTargetColIndicator as i32,
        band: pb::IndicatorBand::ColTop as i32,
        slot_index: -1,
        slot_kind,
        sub_mode_bits: 0,
        custom_key: String::new(),
        ..EventTarget::default()
    }
}

fn row_in_any_selection(grid: &VolvoxGrid, row: i32) -> bool {
    if row == grid.selection.row {
        return true;
    }
    grid.selection
        .all_ranges(grid.rows, grid.cols)
        .iter()
        .any(|&(r1, _, r2, _)| row >= r1 && row <= r2)
}

fn enrich_row_indicator_target(grid: &VolvoxGrid, row: i32, target: &mut EventTarget) {
    use pb::GridEventTargetFlag as Flag;
    use pb::RowIndicatorSlotKind as Kind;

    if target.slot_index >= 0 {
        if let Some(slot) = grid
            .indicator_bands
            .row_start
            .slots
            .get(target.slot_index as usize)
        {
            if !slot.data.is_empty() {
                target.data = slot.data.clone();
            }
        }
    }

    if row < 0 {
        return;
    }

    let kind = target.slot_kind;
    if kind == Kind::RowIndicatorSlotNumbers as i32 {
        let n = (row - grid.fixed_rows + 1).max(1);
        target.text = n.to_string();
        target.int_value = n as i64;
        if row == grid.selection.row {
            target.status_flags |= Flag::GridTargetFlagSelected as u32;
        }
    } else if kind == Kind::RowIndicatorSlotCurrent as i32 {
        if row == grid.selection.row {
            target.status_flags |= Flag::GridTargetFlagSelected as u32;
        }
    } else if kind == Kind::RowIndicatorSlotSelection as i32 {
        if row_in_any_selection(grid, row) {
            target.status_flags |= Flag::GridTargetFlagSelected as u32;
        }
    } else if kind == Kind::RowIndicatorSlotCheckbox as i32 {
        if row_in_any_selection(grid, row) {
            target.status_flags |= Flag::GridTargetFlagChecked as u32;
        }
    } else if kind == Kind::RowIndicatorSlotEditing as i32 {
        if grid.edit.is_active() && grid.edit.edit_row == row {
            target.status_flags |= Flag::GridTargetFlagEditing as u32;
        }
    } else if kind == Kind::RowIndicatorSlotExpander as i32 {
        if let Some(rp) = grid.row_props.get(&row) {
            target.int_value = rp.outline_level as i64;
            if rp.is_collapsed {
                target.status_flags |= Flag::GridTargetFlagCollapsed as u32;
            } else {
                target.status_flags |= Flag::GridTargetFlagExpanded as u32;
            }
            if rp.is_subtotal {
                target.status_flags |= Flag::GridTargetFlagSubtotal as u32;
            }
        } else {
            target.status_flags |= Flag::GridTargetFlagExpanded as u32;
        }
        if grid.outline.label_column >= 0 && grid.outline.label_column < grid.cols {
            target.text = grid.get_display_text(row, grid.outline.label_column);
        }
    } else if kind == Kind::RowIndicatorSlotStatusIcon as i32 {
        if let Some(status) = grid.get_row_status(row) {
            target.text = status.domain.clone();
            target.int_value = status.code as i64;
        }
    }

    if let Some(rp) = grid.row_props.get(&row) {
        if rp.pin != 0 {
            target.status_flags |= Flag::GridTargetFlagPinned as u32;
        }
    }
}

fn enrich_col_indicator_target(grid: &VolvoxGrid, col: i32, target: &mut EventTarget) {
    use crate::sort;
    use pb::ColIndicatorCellMode as Mode;
    use pb::GridEventTargetFlag as Flag;

    if col < 0 || col >= grid.cols {
        return;
    }

    let kind = target.slot_kind;
    let is_sort_glyph = kind == Mode::ColIndicatorCellSortGlyph as i32
        || (target.sub_mode_bits & Mode::ColIndicatorCellSortGlyph as u32 != 0);

    if kind == Mode::ColIndicatorCellHeaderText as i32 && grid.fixed_rows > 0 {
        target.text = grid.get_display_text(0, col);
    }

    if is_sort_glyph {
        for (idx, &(sort_col, order)) in grid.sort_state.sort_keys.iter().enumerate() {
            if sort_col == col {
                target.int_value = (idx + 1) as i64;
                let asc = matches!(
                    order,
                    sort::SORT_ASCENDING_AUTO
                        | sort::SORT_ASCENDING_NUMERIC
                        | sort::SORT_ASCENDING_STRING_NO_CASE
                        | sort::SORT_ASCENDING_STRING
                        | sort::SORT_ASCENDING_CUSTOM
                );
                target.status_flags |= if asc {
                    Flag::GridTargetFlagSortAsc as u32
                } else {
                    Flag::GridTargetFlagSortDesc as u32
                };
                break;
            }
        }
    }
}

fn enrich_corner_indicator_target(
    grid: &VolvoxGrid,
    hit: &HitTestResult,
    target: &mut EventTarget,
) {
    use pb::CornerIndicatorSlotKind as Kind;
    use pb::GridEventTargetFlag as Flag;

    if target.slot_index >= 0 {
        if let Some(slot) = grid
            .indicator_bands
            .corner_top_start
            .slots
            .get(target.slot_index as usize)
        {
            if !slot.data.is_empty() {
                target.data = slot.data.clone();
            }
            if target.text.is_empty() && !slot.label_text.is_empty() {
                target.text = slot.label_text.clone();
            }
        }
    }

    if target.slot_kind == Kind::CornerSlotSelectAll as i32 {
        let rows = grid.rows;
        let cols = grid.cols;
        if rows > 0 && cols > 0 {
            let all_selected = grid
                .selection
                .all_ranges(rows, cols)
                .iter()
                .any(|&(r1, c1, r2, c2)| r1 <= 0 && c1 <= 0 && r2 >= rows - 1 && c2 >= cols - 1);
            if all_selected {
                target.status_flags |= Flag::GridTargetFlagSelected as u32;
            }
        }
    } else if target.slot_kind == Kind::CornerSlotOutlineLevels as i32 {
        if let Some(level) = corner_outline_level_hit(
            grid,
            hit.x_in_cell as i32,
            grid.indicator_bands.start_width(),
        ) {
            target.text = level.to_string();
            target.int_value = level as i64;
        } else {
            target.int_value = -1;
        }
    }
}

fn enrich_data_cell_target(grid: &VolvoxGrid, row: i32, col: i32, target: &mut EventTarget) {
    use pb::GridEventTargetFlag as Flag;

    if row < 0 || col < 0 {
        return;
    }

    if grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col {
        target.status_flags |= Flag::GridTargetFlagEditing as u32;
    }
    if grid.selection.is_selected(row, col, grid.cols) {
        target.status_flags |= Flag::GridTargetFlagSelected as u32;
    }
    if let Some(rp) = grid.row_props.get(&row) {
        if rp.pin != 0 {
            target.status_flags |= Flag::GridTargetFlagPinned as u32;
        }
    }
}

fn enrich_target_value(grid: &VolvoxGrid, hit: &HitTestResult, target: &mut EventTarget) {
    use pb::GridTargetKind as TK;
    if target.kind == TK::GridTargetRowIndicator as i32 {
        enrich_row_indicator_target(grid, hit.row, target);
    } else if target.kind == TK::GridTargetColIndicator as i32 {
        enrich_col_indicator_target(grid, hit.col, target);
    } else if target.kind == TK::GridTargetCornerIndicator as i32 {
        enrich_corner_indicator_target(grid, hit, target);
    } else if target.kind == TK::GridTargetDataCell as i32 {
        enrich_data_cell_target(grid, hit.row, hit.col, target);
    }
}

fn indicator_control_hover_target(grid: &VolvoxGrid, target: &EventTarget) -> bool {
    if grid.selection.hover_mode == HOVER_NONE {
        return false;
    }
    if target.kind == pb::GridTargetKind::GridTargetRowIndicator as i32
        && target.band == pb::IndicatorBand::RowStart as i32
        && target.slot_kind == pb::RowIndicatorSlotKind::RowIndicatorSlotExpander as i32
    {
        return true;
    }
    target.kind == pb::GridTargetKind::GridTargetCornerIndicator as i32
        && target.band == pb::IndicatorBand::CornerTopStart as i32
        && target.slot_kind == pb::CornerIndicatorSlotKind::CornerSlotOutlineLevels as i32
        && target.int_value >= 0
}

fn target_from_hit(grid: &VolvoxGrid, hit: &HitTestResult) -> EventTarget {
    let mut target = target_identity_from_hit(grid, hit);
    enrich_target_value(grid, hit, &mut target);
    target
}

fn target_identity_from_hit(grid: &VolvoxGrid, hit: &HitTestResult) -> EventTarget {
    let vp = VisibleRange::compute(grid, grid.viewport_width, grid.viewport_height);
    match hit.area {
        HitArea::IndicatorRowStart => {
            let (slot_index, slot_kind, custom_key) =
                row_indicator_slot_at(grid, hit.x_in_cell as i32, vp.data_x);
            EventTarget {
                kind: pb::GridTargetKind::GridTargetRowIndicator as i32,
                band: pb::IndicatorBand::RowStart as i32,
                slot_index,
                slot_kind,
                custom_key,
                ..EventTarget::default()
            }
        }
        HitArea::IndicatorRowStartResize => EventTarget {
            kind: pb::GridTargetKind::GridTargetRowIndicator as i32,
            band: pb::IndicatorBand::RowStart as i32,
            slot_kind: pb::RowIndicatorSlotKind::RowIndicatorSlotResize as i32,
            ..EventTarget::default()
        },
        HitArea::OutlineButton if hit.col < 0 => {
            let (slot_index, slot_kind, custom_key) =
                row_indicator_slot_at(grid, hit.x_in_cell as i32, vp.data_x);
            EventTarget {
                kind: pb::GridTargetKind::GridTargetRowIndicator as i32,
                band: pb::IndicatorBand::RowStart as i32,
                slot_index,
                slot_kind,
                custom_key,
                ..EventTarget::default()
            }
        }
        HitArea::RowBorder if hit.col < 0 => EventTarget {
            kind: pb::GridTargetKind::GridTargetRowIndicator as i32,
            band: pb::IndicatorBand::RowStart as i32,
            slot_kind: pb::RowIndicatorSlotKind::RowIndicatorSlotResize as i32,
            ..EventTarget::default()
        },
        HitArea::IndicatorColTop => col_indicator_target_for_hit(grid, hit),
        HitArea::ColBorder if hit.row < 0 => EventTarget {
            kind: pb::GridTargetKind::GridTargetColIndicator as i32,
            band: pb::IndicatorBand::ColTop as i32,
            slot_kind: pb::ColIndicatorCellMode::ColIndicatorCellResizeHandle as i32,
            sub_mode_bits: pb::ColIndicatorCellMode::ColIndicatorCellResizeHandle as u32,
            ..EventTarget::default()
        },
        HitArea::IndicatorCornerTopStart => {
            let (slot_index, slot_kind, custom_key) =
                corner_indicator_slot_at(grid, hit.x_in_cell as i32, vp.data_x);
            EventTarget {
                kind: pb::GridTargetKind::GridTargetCornerIndicator as i32,
                band: pb::IndicatorBand::CornerTopStart as i32,
                slot_index,
                slot_kind,
                custom_key,
                ..EventTarget::default()
            }
        }
        HitArea::Cell
        | HitArea::CellText
        | HitArea::CellPicture
        | HitArea::CellButtonPicture
        | HitArea::FixedRow
        | HitArea::FixedCol
        | HitArea::FixedCorner
        | HitArea::CheckBox
        | HitArea::DropdownButton
        | HitArea::OutlineButton
        | HitArea::ColBorder
        | HitArea::RowBorder
            if hit.row >= 0 && hit.col >= 0 =>
        {
            EventTarget::data_cell()
        }
        _ => EventTarget::background(),
    }
}

fn emit_pointer_move_and_hover(
    grid: &mut VolvoxGrid,
    hit: &HitTestResult,
    button: i32,
    modifier: i32,
    x: f32,
    y: f32,
) {
    let target = target_from_hit(grid, hit);
    let next = HoverTarget {
        row: hit.row,
        col: hit.col,
        target,
    };
    if grid.last_hover_target.as_ref() == Some(&next) {
        return;
    }
    let repaint_indicator_hover = grid
        .last_hover_target
        .as_ref()
        .is_some_and(|prev| indicator_control_hover_target(grid, &prev.target))
        || indicator_control_hover_target(grid, &next.target);
    if let Some(prev) = grid.last_hover_target.replace(next.clone()) {
        if !is_background_target(&prev.target) {
            grid.events.push(GridEventData::LeaveCell {
                row: prev.row,
                col: prev.col,
                target: prev.target,
            });
        }
    }
    grid.events.push(GridEventData::MouseMove {
        button,
        modifier,
        x,
        y,
        target: next.target.clone(),
    });
    if !is_background_target(&next.target) {
        grid.events.push(GridEventData::EnterCell {
            row: next.row,
            col: next.col,
            target: next.target,
        });
    }
    if repaint_indicator_hover {
        grid.mark_dirty();
    }
}

fn first_visible_row_indicator_slot(grid: &VolvoxGrid) -> i32 {
    grid.indicator_bands
        .row_start
        .slots
        .iter()
        .position(|slot| slot.visible)
        .map(|index| index as i32)
        .unwrap_or(-1)
}

fn first_visible_corner_indicator_slot(grid: &VolvoxGrid) -> i32 {
    grid.indicator_bands
        .corner_top_start
        .slots
        .iter()
        .position(|slot| slot.visible)
        .map(|index| index as i32)
        .unwrap_or(-1)
}

fn next_visible_row_indicator_slot(grid: &VolvoxGrid, current: i32, delta: i32) -> i32 {
    let slots: Vec<i32> = grid
        .indicator_bands
        .row_start
        .slots
        .iter()
        .enumerate()
        .filter_map(|(index, slot)| slot.visible.then_some(index as i32))
        .collect();
    next_visible_slot_index(&slots, current, delta)
}

fn next_visible_corner_indicator_slot(grid: &VolvoxGrid, current: i32, delta: i32) -> i32 {
    let slots: Vec<i32> = grid
        .indicator_bands
        .corner_top_start
        .slots
        .iter()
        .enumerate()
        .filter_map(|(index, slot)| slot.visible.then_some(index as i32))
        .collect();
    next_visible_slot_index(&slots, current, delta)
}

fn next_visible_slot_index(slots: &[i32], current: i32, delta: i32) -> i32 {
    if slots.is_empty() {
        return -1;
    }
    let current_pos = slots
        .iter()
        .position(|slot| *slot == current)
        .unwrap_or(if delta < 0 { slots.len() - 1 } else { 0 });
    let next_pos = if delta < 0 {
        current_pos.saturating_sub(1)
    } else {
        (current_pos + 1).min(slots.len() - 1)
    };
    slots[next_pos]
}

fn col_indicator_slot_for_col(grid: &VolvoxGrid, col: i32) -> i32 {
    grid.indicator_bands
        .col_top
        .cells
        .iter()
        .position(|cell| {
            col >= cell.col1
                && col <= cell.col2.max(cell.col1)
                && cell.row1 <= 0
                && cell.row2.max(cell.row1) >= 0
        })
        .map(|index| index as i32)
        .unwrap_or(-1)
}

fn indicator_focus_order(grid: &VolvoxGrid) -> Vec<i32> {
    let mut order = Vec::new();
    if grid.indicator_bands.row_start.visible {
        order.push(pb::IndicatorBand::RowStart as i32);
    }
    if grid.indicator_bands.col_top.visible {
        order.push(pb::IndicatorBand::ColTop as i32);
    }
    if grid.indicator_bands.corner_top_start.visible {
        order.push(pb::IndicatorBand::CornerTopStart as i32);
    }
    order
}

fn active_indicator_for_band(grid: &VolvoxGrid, band: i32) -> ActiveIndicatorTarget {
    if band == pb::IndicatorBand::RowStart as i32 {
        let row = grid.selection.row.clamp(0, grid.rows - 1);
        ActiveIndicatorTarget {
            band,
            row,
            col: -1,
            slot_index: first_visible_row_indicator_slot(grid),
        }
    } else if band == pb::IndicatorBand::ColTop as i32 {
        let col = grid.selection.col.clamp(0, grid.cols - 1);
        ActiveIndicatorTarget {
            band,
            row: -1,
            col,
            slot_index: col_indicator_slot_for_col(grid, col),
        }
    } else {
        ActiveIndicatorTarget {
            band,
            row: -1,
            col: -1,
            slot_index: first_visible_corner_indicator_slot(grid),
        }
    }
}

fn cycle_indicator_focus(grid: &mut VolvoxGrid) {
    let order = indicator_focus_order(grid);
    if order.is_empty() {
        grid.active_indicator = None;
        return;
    }
    let Some(active) = &grid.active_indicator else {
        grid.active_indicator = Some(active_indicator_for_band(grid, order[0]));
        return;
    };
    let Some(current_pos) = order.iter().position(|band| *band == active.band) else {
        grid.active_indicator = Some(active_indicator_for_band(grid, order[0]));
        return;
    };
    if current_pos + 1 >= order.len() {
        grid.active_indicator = None;
    } else {
        grid.active_indicator = Some(active_indicator_for_band(grid, order[current_pos + 1]));
    }
}

fn target_from_active_indicator(grid: &VolvoxGrid, active: &ActiveIndicatorTarget) -> EventTarget {
    if active.band == pb::IndicatorBand::RowStart as i32 {
        let mut target = EventTarget {
            kind: pb::GridTargetKind::GridTargetRowIndicator as i32,
            band: active.band,
            slot_index: active.slot_index,
            ..EventTarget::default()
        };
        if active.slot_index >= 0 {
            if let Some(slot) = grid
                .indicator_bands
                .row_start
                .slots
                .get(active.slot_index as usize)
            {
                target.slot_kind = slot.kind;
                target.custom_key = slot.custom_key.clone();
            }
        }
        return target;
    }
    if active.band == pb::IndicatorBand::ColTop as i32 {
        let band = &grid.indicator_bands.col_top;
        if active.slot_index >= 0 {
            if let Some(cell) = band.cells.get(active.slot_index as usize) {
                let mode_bits = if cell.mode_bits != 0 {
                    cell.mode_bits
                } else {
                    band.mode_bits
                };
                return EventTarget {
                    kind: pb::GridTargetKind::GridTargetColIndicator as i32,
                    band: active.band,
                    slot_index: active.slot_index,
                    slot_kind: if mode_bits
                        & (pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32)
                        != 0
                    {
                        pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as i32
                    } else {
                        mode_bits as i32
                    },
                    custom_key: cell.custom_key.clone(),
                    ..EventTarget::default()
                };
            }
        }
        return EventTarget {
            kind: pb::GridTargetKind::GridTargetColIndicator as i32,
            band: active.band,
            slot_index: -1,
            slot_kind: if band.has_mode(pb::ColIndicatorCellMode::ColIndicatorCellHeaderText) {
                pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as i32
            } else {
                band.mode_bits as i32
            },
            ..EventTarget::default()
        };
    }
    if active.band == pb::IndicatorBand::CornerTopStart as i32 {
        let mut target = EventTarget {
            kind: pb::GridTargetKind::GridTargetCornerIndicator as i32,
            band: active.band,
            slot_index: active.slot_index,
            ..EventTarget::default()
        };
        if active.slot_index >= 0 {
            if let Some(slot) = grid
                .indicator_bands
                .corner_top_start
                .slots
                .get(active.slot_index as usize)
            {
                target.slot_kind = slot.kind;
                target.custom_key = slot.custom_key.clone();
            }
        } else if grid.selection.allow_selection {
            target.slot_kind = pb::CornerIndicatorSlotKind::CornerSlotSelectAll as i32;
        }
        return target;
    }
    EventTarget::background()
}

fn move_active_indicator(grid: &mut VolvoxGrid, key_code: i32) {
    let Some(mut active) = grid.active_indicator.clone() else {
        return;
    };
    if active.band == pb::IndicatorBand::RowStart as i32 {
        match key_code {
            37 => {
                active.slot_index = next_visible_row_indicator_slot(grid, active.slot_index, -1);
            }
            38 => active.row = (active.row - 1).max(0),
            39 => {
                active.slot_index = next_visible_row_indicator_slot(grid, active.slot_index, 1);
            }
            40 => active.row = (active.row + 1).min(grid.rows - 1),
            _ => {}
        }
    } else if active.band == pb::IndicatorBand::ColTop as i32 {
        match key_code {
            37 => active.col = (active.col - 1).max(0),
            39 => active.col = (active.col + 1).min(grid.cols - 1),
            _ => {}
        }
        active.slot_index = col_indicator_slot_for_col(grid, active.col);
    } else if active.band == pb::IndicatorBand::CornerTopStart as i32 {
        match key_code {
            37 => {
                active.slot_index = next_visible_corner_indicator_slot(grid, active.slot_index, -1);
            }
            39 => {
                active.slot_index = next_visible_corner_indicator_slot(grid, active.slot_index, 1);
            }
            _ => {}
        }
    }
    grid.active_indicator = Some(active);
}

fn activate_indicator_target(grid: &mut VolvoxGrid, behavior: InputBehavior) {
    let Some(active) = grid.active_indicator.clone() else {
        return;
    };
    let target = target_from_active_indicator(grid, &active);
    if behavior.allow_before_mouse_down {
        grid.events.push(GridEventData::BeforeMouseDown {
            row: active.row,
            col: active.col,
            target: target.clone(),
        });
    }
    grid.events.push(GridEventData::Click {
        row: active.row,
        col: active.col,
        hit_area: pb::CellHitArea::HitCell as i32,
        interaction: pb::CellInteraction::None as i32,
        target,
    });
}

fn handle_indicator_keyboard_focus(
    grid: &mut VolvoxGrid,
    key_code: i32,
    behavior: InputBehavior,
) -> bool {
    if !grid.indicator_focus_enabled {
        grid.active_indicator = None;
        return false;
    }

    if key_code == grid.indicator_focus_enter_key_code {
        cycle_indicator_focus(grid);
        grid.mark_dirty();
        return true;
    }

    if grid.active_indicator.is_none() {
        return false;
    }

    if key_code == grid.indicator_focus_exit_key_code {
        grid.active_indicator = None;
        grid.mark_dirty();
        return true;
    }

    match key_code {
        37 | 38 | 39 | 40 => {
            move_active_indicator(grid, key_code);
            grid.mark_dirty();
        }
        13 | 32 => {
            activate_indicator_target(grid, behavior);
        }
        _ => {}
    }
    true
}

fn cell_hit_uses_pointer_cursor(grid: &VolvoxGrid, hit: &HitTestResult) -> bool {
    match resolved_click_interaction(grid, hit.row, hit.col) {
        x if x == pb::CellInteraction::TextLink as i32 => hit.area == HitArea::CellText,
        x if x == pb::CellInteraction::Button as i32 => matches!(
            hit.area,
            HitArea::Cell
                | HitArea::CellText
                | HitArea::CellPicture
                | HitArea::CellButtonPicture
                | HitArea::FixedRow
                | HitArea::FixedCol
        ),
        _ => false,
    }
}

fn clear_dropdown_button_pressed(grid: &mut VolvoxGrid) -> bool {
    let changed = grid.dropdown_button_pressed;
    grid.dropdown_button_pressed = false;
    grid.dropdown_button_pressed_row = -1;
    grid.dropdown_button_pressed_col = -1;
    changed
}

fn set_dropdown_button_pressed(grid: &mut VolvoxGrid, row: i32, col: i32) -> bool {
    let changed = !grid.dropdown_button_pressed
        || grid.dropdown_button_pressed_row != row
        || grid.dropdown_button_pressed_col != col;
    grid.dropdown_button_pressed = true;
    grid.dropdown_button_pressed_row = row;
    grid.dropdown_button_pressed_col = col;
    changed
}

fn clear_outline_level_button_pressed(grid: &mut VolvoxGrid) -> bool {
    let changed = grid.outline_level_button_pressed;
    grid.outline_level_button_pressed = false;
    grid.outline_level_button_pressed_level = -1;
    grid.outline_level_button_pressed_inside = false;
    changed
}

fn set_outline_level_button_pressed(grid: &mut VolvoxGrid, level: i32) -> bool {
    let changed = !grid.outline_level_button_pressed
        || grid.outline_level_button_pressed_level != level
        || !grid.outline_level_button_pressed_inside;
    grid.outline_level_button_pressed = true;
    grid.outline_level_button_pressed_level = level;
    grid.outline_level_button_pressed_inside = true;
    changed
}

fn update_outline_level_button_pressed_inside(
    grid: &mut VolvoxGrid,
    hit: &HitTestResult,
    x: f32,
) -> bool {
    if !grid.outline_level_button_pressed {
        return false;
    }
    let inside = corner_outline_level_hit_from_result(grid, hit, x)
        == Some(grid.outline_level_button_pressed_level);
    if grid.outline_level_button_pressed_inside == inside {
        return false;
    }
    grid.outline_level_button_pressed_inside = inside;
    true
}

fn parse_checkbox_text(raw: &str) -> Option<bool> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "true" | "1" | "yes" | "y" | "on" => Some(true),
        "false" | "0" | "no" | "n" | "off" => Some(false),
        _ => None,
    }
}

fn checkbox_text_for_value(existing_text: &str, value: bool) -> String {
    match existing_text.trim().to_ascii_lowercase().as_str() {
        "1" | "0" => if value { "1" } else { "0" }.to_string(),
        "yes" | "no" => if value { "Yes" } else { "No" }.to_string(),
        "y" | "n" => if value { "Y" } else { "N" }.to_string(),
        "on" | "off" => if value { "ON" } else { "OFF" }.to_string(),
        _ => if value { "TRUE" } else { "FALSE" }.to_string(),
    }
}

fn checkbox_bool_value(grid: &VolvoxGrid, row: i32, col: i32) -> bool {
    let checked = grid
        .cells
        .get(row, col)
        .map_or(pb::CheckedState::CheckedUnchecked as i32, |cell| {
            cell.checked()
        });
    if checked == pb::CheckedState::CheckedChecked as i32 {
        return true;
    }
    if checked == pb::CheckedState::CheckedGrayed as i32 {
        return false;
    }

    match grid.cells.get_value(row, col) {
        crate::cell::CellValueData::Bool(value) => *value,
        _ => parse_checkbox_text(grid.cells.get_text(row, col)).unwrap_or(false),
    }
}

fn toggle_checkbox_cell(grid: &mut VolvoxGrid, row: i32, col: i32) -> bool {
    if !is_boolean_checkbox_cell(grid, row, col) {
        return false;
    }
    if !grid.can_begin_edit(row, col, false) {
        return false;
    }

    let checked = grid
        .cells
        .get(row, col)
        .map_or(pb::CheckedState::CheckedUnchecked as i32, |cell| {
            cell.checked()
        });
    if checked == pb::CheckedState::CheckedGrayed as i32 {
        return false;
    }

    let old_text = grid.cells.get_text(row, col).to_string();
    let next_value = !checkbox_bool_value(grid, row, col);
    let next_text = checkbox_text_for_value(&old_text, next_value);

    let cell = grid.cells.get_mut(row, col);
    cell.text = next_text.clone();
    let extra = cell.extra_mut();
    extra.value = crate::cell::CellValueData::Bool(next_value);
    extra.checked = if next_value {
        pb::CheckedState::CheckedChecked as i32
    } else {
        pb::CheckedState::CheckedUnchecked as i32
    };

    if old_text != next_text {
        grid.events.push(GridEventData::CellChanged {
            row,
            col,
            old_text,
            new_text: next_text,
        });
    }
    grid.mark_dirty();
    true
}

fn resolve_row_hit(
    grid: &VolvoxGrid,
    layout: &crate::layout::LayoutCache,
    local_y: i32,
    viewport_h: i32,
) -> LocalRowHit {
    let scroll_y = grid.scroll.scroll_y;
    let fixed_row_height = layout.row_pos(grid.fixed_rows);
    let frozen_bottom = layout.row_pos(grid.fixed_rows + grid.frozen_rows);
    let pinned_top_h = grid.pinned_top_height();
    let pinned_bottom_h = grid.pinned_bottom_height();
    let in_fixed_row_area = local_y < fixed_row_height;
    let pin_top_start = frozen_bottom;
    let pin_top_end = frozen_bottom + pinned_top_h;
    let pin_bot_start = viewport_h - pinned_bottom_h;

    let mut row;
    let mut effective_y;
    let mut hit_pinned = false;

    if in_fixed_row_area {
        effective_y = local_y;
        row = layout.row_at_y(effective_y);
    } else if pinned_top_h > 0 && local_y >= pin_top_start && local_y < pin_top_end {
        let mut y = pin_top_start;
        row = -1;
        for &r in &grid.pinned_rows_top {
            let rh = grid.row_height(r);
            if local_y >= y && local_y < y + rh {
                row = r;
                break;
            }
            y += rh;
        }
        effective_y = local_y;
        hit_pinned = true;
    } else if pinned_bottom_h > 0 && local_y >= pin_bot_start && local_y < viewport_h {
        let mut y = pin_bot_start;
        row = -1;
        for &r in &grid.pinned_rows_bottom {
            let rh = grid.row_height(r);
            if local_y >= y && local_y < y + rh {
                row = r;
                break;
            }
            y += rh;
        }
        effective_y = local_y;
        hit_pinned = true;
    } else {
        effective_y = local_y + scroll_y as i32 - pinned_top_h;
        row = layout.row_at_y(effective_y);
        if grid.is_row_pinned(row) != 0 {
            row = -1;
        }
    }

    if !hit_pinned && !in_fixed_row_area {
        let fixed_row_end = grid.fixed_rows + grid.frozen_rows;
        let scrollable_top = frozen_bottom + pinned_top_h;
        let scrollable_bottom = viewport_h - pinned_bottom_h;

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
                if local_y >= sticky_y && local_y < sticky_y + rh {
                    row = sr;
                    effective_y = local_y;
                    break;
                }
                sticky_y += rh;
                threshold_top += rh;
            }
        }

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
                if local_y >= sticky_y && local_y < sticky_y + rh {
                    row = sr;
                    effective_y = local_y;
                    break;
                }
                threshold_bottom -= rh;
            }
        }
    }

    LocalRowHit {
        row,
        effective_y,
        in_fixed_row_area,
    }
}

fn resolve_col_hit(
    grid: &VolvoxGrid,
    layout: &crate::layout::LayoutCache,
    local_x: i32,
    vp: &VisibleRange,
) -> LocalColHit {
    let scroll_x = grid.scroll.scroll_x;
    let fixed_col_end = grid.fixed_cols + grid.frozen_cols;
    let fixed_col_right = layout.col_pos(fixed_col_end);
    let fixed_col_width = layout.col_pos(grid.fixed_cols);
    let pinned_left_w = grid.pinned_left_width();
    let pinned_right_w = grid.pinned_right_width();
    let in_fixed_col_area = local_x < fixed_col_width;
    let pin_left_start = fixed_col_right;
    let pin_left_end = fixed_col_right + pinned_left_w;
    let pin_right_start = vp.data_w - pinned_right_w;

    let mut hit_pinned_col = false;
    let mut effective_x = if in_fixed_col_area {
        local_x
    } else {
        local_x + scroll_x as i32
    };
    let mut col = -1;

    if in_fixed_col_area {
        col = layout.col_at_x(effective_x);
    } else if !vp.sticky_left_cols.is_empty()
        && local_x >= fixed_col_right
        && local_x < fixed_col_right + vp.sticky_left_width
    {
        hit_pinned_col = true;
        effective_x = local_x;
        let mut x = fixed_col_right;
        for &sc in &vp.sticky_left_cols {
            let cw = grid.col_width(sc);
            if cw <= 0 {
                continue;
            }
            if local_x >= x && local_x < x + cw {
                col = sc;
                break;
            }
            x += cw;
        }
    } else if !vp.sticky_right_cols.is_empty()
        && local_x >= vp.data_w - vp.sticky_right_width
        && local_x < vp.data_w
    {
        hit_pinned_col = true;
        effective_x = local_x;
        let mut x = vp.data_w - vp.sticky_right_width;
        for &sc in &vp.sticky_right_cols {
            let cw = grid.col_width(sc);
            if cw <= 0 {
                continue;
            }
            if local_x >= x && local_x < x + cw {
                col = sc;
                break;
            }
            x += cw;
        }
    } else if pinned_left_w > 0 && local_x >= pin_left_start && local_x < pin_left_end {
        hit_pinned_col = true;
        effective_x = local_x;
        let mut x = pin_left_start;
        for &pc in &grid.pinned_cols_left {
            let cw = grid.col_width(pc);
            if cw <= 0 {
                continue;
            }
            if local_x >= x && local_x < x + cw {
                col = pc;
                break;
            }
            x += cw;
        }
    } else if pinned_right_w > 0 && local_x >= pin_right_start && local_x < vp.data_w {
        hit_pinned_col = true;
        effective_x = local_x;
        let mut x = pin_right_start;
        for &pc in &grid.pinned_cols_right {
            let cw = grid.col_width(pc);
            if cw <= 0 {
                continue;
            }
            if local_x >= x && local_x < x + cw {
                col = pc;
                break;
            }
            x += cw;
        }
    } else {
        effective_x = local_x + scroll_x as i32 - pinned_left_w;
        if !grid.extend_last_col && (effective_x < 0 || effective_x >= layout.total_width) {
            col = -1;
        } else {
            col = layout.col_at_x(effective_x);
            if grid.is_col_pinned(col) != 0 {
                col = -1;
            }
        }
    }

    if col >= 0 && grid.is_col_hidden(col) {
        col = grid.visible_col_at_or_before(col).unwrap_or(-1);
    }

    LocalColHit {
        col,
        effective_x,
        in_fixed_col_area,
        hit_pinned_col,
    }
}

fn scrollbar_geometry(grid: &VolvoxGrid) -> crate::scrollbar::ScrollBarGeometry {
    compute_scrollbar_geometry(grid, grid.viewport_width, grid.viewport_height)
}

fn overlay_scrollbar_hidden(grid: &VolvoxGrid, horizontal: bool) -> bool {
    if !scrollbar_overlays_content(grid.scrollbar_appearance)
        || grid.scrollbar_drag_active
        || grid.scrollbar_repeat_active
        || grid.scrollbar_hover
    {
        return false;
    }
    let mode = if horizontal {
        grid.scrollbar_show_h
    } else {
        grid.scrollbar_show_v
    };
    normalize_scrollbar_mode(mode) != pb::ScrollBarMode::ScrollbarModeAlways as i32
        && grid.scrollbar_fade_opacity <= 0.0
}

fn update_scrollbar_hover(grid: &mut VolvoxGrid, x: f32, y: f32) -> bool {
    let geom = scrollbar_geometry(grid);
    let hovered = geom.contains_h(x as i32, y as i32) || geom.contains_v(x as i32, y as i32);
    let mut changed = grid.scrollbar_hover != hovered;
    grid.scrollbar_hover = hovered;
    if hovered && bump_scrollbar_fade(grid) {
        changed = true;
    }
    changed
}

pub fn hit_test(grid: &mut VolvoxGrid, px: f32, py: f32) -> HitTestResult {
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
        let sbg = scrollbar_geometry(grid);
        let ix = px as i32;
        let iy = py as i32;
        if sbg.show_v && !overlay_scrollbar_hidden(grid, false) && sbg.contains_v(ix, iy) {
            let v_bottom = if sbg.show_h && !sbg.overlays_content {
                sbg.corner_y
            } else {
                sbg.v_bar_y + sbg.v_bar_h
            };
            if iy >= sbg.v_bar_y && iy < v_bottom {
                return HitTestResult {
                    row: -1,
                    col: -1,
                    area: HitArea::VScrollBar,
                    x_in_cell: px,
                    y_in_cell: py,
                };
            }
        }
        if sbg.show_h && !overlay_scrollbar_hidden(grid, true) && sbg.contains_h(ix, iy) {
            let h_right = if sbg.show_v && !sbg.overlays_content {
                sbg.corner_x
            } else {
                sbg.h_bar_x + sbg.h_bar_w
            };
            if ix >= sbg.h_bar_x && ix < h_right {
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

    let vp = VisibleRange::compute(grid, grid.viewport_width, grid.viewport_height);
    let px_i = px as i32;
    let py_i = py as i32;

    if grid.indicator_bands.row_start.visible
        && grid.indicator_bands.col_top.visible
        && px_i >= 0
        && px_i < vp.data_x
        && py_i >= 0
        && py_i < vp.data_y
    {
        if row_start_indicator_width_resize_hit(grid, px_i, vp.data_x) {
            return HitTestResult {
                row: -1,
                col: -1,
                area: HitArea::IndicatorRowStartResize,
                x_in_cell: px,
                y_in_cell: py,
            };
        }
        return HitTestResult {
            row: -1,
            col: -1,
            area: HitArea::IndicatorCornerTopStart,
            x_in_cell: px,
            y_in_cell: py,
        };
    }

    if grid.indicator_bands.col_top.visible
        && py_i >= 0
        && py_i < vp.data_y
        && px_i >= vp.data_x
        && px_i < vp.data_x + vp.data_w
    {
        let local_x = px_i - vp.data_x;
        let col_hit = resolve_col_hit(grid, layout, local_x, &vp);
        if col_hit.col >= 0 && col_hit.col < grid.cols {
            let mut area = HitArea::IndicatorColTop;
            let mut hit_col = col_hit.col;
            if !col_hit.hit_pinned_col {
                let (cx, _, cw, _) = layout.cell_rect(0, hit_col);
                let col_left = cx;
                let col_right = cx + cw;
                let hit_half = header_resize_hit_half_width(grid);
                if (col_hit.effective_x - col_right).abs() <= hit_half {
                    area = HitArea::ColBorder;
                } else if hit_col > 0 && (col_hit.effective_x - col_left).abs() <= hit_half {
                    hit_col -= 1;
                    area = HitArea::ColBorder;
                }
            }
            return HitTestResult {
                row: -1,
                col: hit_col,
                area,
                x_in_cell: {
                    let (cx, _, _, _) = layout.cell_rect(0, hit_col.max(0));
                    local_x as f32 - cx as f32
                },
                y_in_cell: py,
            };
        }
    }

    if grid.indicator_bands.row_start.visible
        && px_i >= 0
        && px_i < vp.data_x
        && py_i >= vp.data_y
        && py_i < vp.data_y + vp.data_h
    {
        let local_y = py_i - vp.data_y;
        let row_hit = resolve_row_hit(grid, layout, local_y, vp.data_h);
        if row_hit.row >= 0 && row_hit.row < grid.rows {
            let mut area = HitArea::IndicatorRowStart;
            let mut hit_row = row_hit.row;
            let (_, row_top, _, row_h) = layout.cell_rect(hit_row, 0);
            if row_start_indicator_width_resize_hit(grid, px_i, vp.data_x) {
                area = HitArea::IndicatorRowStartResize;
                hit_row = -1;
            } else if row_resize_enabled(grid)
                && (row_hit.effective_y - (row_top + row_h)).abs() <= 3
            {
                area = HitArea::RowBorder;
            } else if row_resize_enabled(grid)
                && hit_row > 0
                && (row_hit.effective_y - row_top).abs() <= 3
            {
                hit_row -= 1;
                area = HitArea::RowBorder;
            } else if row_indicator_expander_toggle_hit(grid, &vp, hit_row, px_i) {
                area = HitArea::OutlineButton;
            }
            return HitTestResult {
                row: hit_row,
                col: -1,
                area,
                x_in_cell: px,
                y_in_cell: local_y as f32,
            };
        }
    }

    if px_i < vp.data_x
        || py_i < vp.data_y
        || px_i >= vp.data_x + vp.data_w
        || py_i >= vp.data_y + vp.data_h
    {
        return HitTestResult {
            row: -1,
            col: -1,
            area: HitArea::Background,
            x_in_cell: 0.0,
            y_in_cell: 0.0,
        };
    }

    let local_x = px_i - vp.data_x;
    let local_y = py_i - vp.data_y;
    let row_hit = resolve_row_hit(grid, layout, local_y, vp.data_h);
    let col_hit = resolve_col_hit(grid, layout, local_x, &vp);
    let mut row = row_hit.row;
    let mut col = col_hit.col;
    let effective_x = col_hit.effective_x;
    let effective_y = row_hit.effective_y;

    if row < 0 || col < 0 || row >= grid.rows || col >= grid.cols {
        return HitTestResult {
            row: -1,
            col: -1,
            area: HitArea::Background,
            x_in_cell: 0.0,
            y_in_cell: 0.0,
        };
    }

    let mut area = if row_hit.in_fixed_row_area && col_hit.in_fixed_col_area {
        HitArea::FixedCorner
    } else if row_hit.in_fixed_row_area {
        if col_hit.hit_pinned_col {
            HitArea::FixedRow
        } else {
            let (cx, _, cw, _) = layout.cell_rect(row, col);
            let col_left = cx;
            let col_right = cx + cw;
            let hit_half = header_resize_hit_half_width(grid);
            if (effective_x - col_right).abs() <= hit_half {
                HitArea::ColBorder
            } else if col > 0 && (effective_x - col_left).abs() <= hit_half {
                col -= 1;
                HitArea::ColBorder
            } else {
                HitArea::FixedRow
            }
        }
    } else if col_hit.in_fixed_col_area {
        let (_, cy, _, ch) = crate::canvas::cell_rect(grid, row, col, &vp)
            .unwrap_or_else(|| layout.cell_rect(row, col));
        let row_top = cy;
        let row_bottom = cy + ch;
        if row_resize_enabled(grid) && (effective_y - row_bottom).abs() <= 3 {
            HitArea::RowBorder
        } else if row_resize_enabled(grid) && row > 0 && (effective_y - row_top).abs() <= 3 {
            row -= 1;
            HitArea::RowBorder
        } else {
            HitArea::FixedCol
        }
    } else {
        HitArea::Cell
    };

    let (cx, cy, cw, ch) =
        crate::canvas::cell_rect(grid, row, col, &vp).unwrap_or_else(|| layout.cell_rect(row, col));

    if matches!(area, HitArea::Cell | HitArea::FixedRow | HitArea::FixedCol) {
        if let Some(rect) = button_picture_rect(grid, row, col, cx, cy, cw, ch) {
            if point_in_rect(px_i, py_i, rect) {
                area = HitArea::CellButtonPicture;
            }
        }
    }

    if matches!(area, HitArea::Cell | HitArea::FixedRow | HitArea::FixedCol) {
        if let Some(cell) = grid.cells.get(row, col) {
            if let Some(data) = cell.picture() {
                if let Some((img_w, img_h)) = parse_png_dimensions(data) {
                    if let Some(rect) = image_rect_from_alignment(
                        cx,
                        cy,
                        cw,
                        ch,
                        img_w,
                        img_h,
                        cell.picture_alignment(),
                    ) {
                        if point_in_rect(px_i, py_i, rect) {
                            area = HitArea::CellPicture;
                        }
                    }
                }
            }
        }
    }

    if matches!(area, HitArea::Cell | HitArea::FixedRow | HitArea::FixedCol) {
        if let Some(rect) = text_content_rect(grid, row, col, cx, cy, cw, ch) {
            if point_in_rect(px_i, py_i, rect) {
                area = HitArea::CellText;
            }
        }
    }

    if (area == HitArea::Cell || area == HitArea::FixedRow || area == HitArea::FixedCol)
        && show_dropdown_button_for_cell(grid, row, col)
    {
        if let Some(rect) = dropdown_button_rect(cx, cy, cw, ch) {
            if point_in_rect(px_i, py_i, rect) {
                area = HitArea::DropdownButton;
            }
        }
    }

    if (area == HitArea::Cell || area == HitArea::FixedCol)
        && checkbox_rect(grid, row, col).map_or(false, |(bx, by, bw, bh)| {
            px_i >= bx && px_i < bx + bw && py_i >= by && py_i < by + bh
        })
    {
        area = HitArea::CheckBox;
    }

    HitTestResult {
        row,
        col,
        area,
        x_in_cell: px_i as f32 - cx as f32,
        y_in_cell: py_i as f32 - cy as f32,
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
    grid.edit_pointer_select_active = false;
    if grid.type_ahead_mode != pb::TypeAheadMode::TypeAheadNone as i32 {
        clear_type_ahead_buffer(grid, true);
    }
    let hit = hit_test(grid, x, y);
    if hit.area != HitArea::DropdownButton && clear_dropdown_button_pressed(grid) {
        grid.mark_dirty();
    }
    let outline_level_hit = corner_outline_level_hit_from_result(grid, &hit, x);
    if outline_level_hit.is_none() && clear_outline_level_button_pressed(grid) {
        grid.mark_dirty();
    }

    let hit_active_edit_cell = grid.is_editing()
        && hit.row == grid.edit.edit_row
        && hit.col == grid.edit.edit_col
        && matches!(
            hit.area,
            HitArea::Cell | HitArea::CellText | HitArea::FixedRow | HitArea::FixedCol
        );

    // Click-away behavior: if editing, and click is not on the active dropdown or
    // active dropdown button, close the editor.
    // Plain text edits commit on click-away, but dropdown-backed edits cancel so
    // keyboard-previewed choices do not overwrite the stored value unless the
    // user explicitly confirms them.
    // Skipped when host_pointer_dispatch — the host adapter handles commit-on-click-away.
    if !grid.host_pointer_dispatch
        && grid.is_editing()
        && !grid.edit.formula_mode
        && hit.area != HitArea::DropdownList
    {
        let is_active_btn = hit.area == HitArea::DropdownButton
            && hit.row == grid.edit.edit_row
            && hit.col == grid.edit.edit_col;

        if !is_active_btn && !hit_active_edit_cell {
            if grid.edit.dropdown_items.is_empty() {
                grid.commit_edit();
            } else {
                grid.cancel_edit();
            }
        }
    }

    grid.mouse_row = hit.row;
    grid.mouse_col = hit.col;
    let shift = modifier & 1 != 0;
    let ctrl = modifier & 2 != 0;

    if !dbl_click && !grid.host_pointer_dispatch && hit_active_edit_cell {
        if let Some(anchor) =
            place_active_edit_caret_from_pointer_click(grid, hit.row, hit.col, hit.x_in_cell)
        {
            grid.edit_pointer_select_active = true;
            grid.edit_pointer_select_anchor = anchor;
        }
        return;
    }

    let event_target = target_from_hit(grid, &hit);
    if event_target.kind == pb::GridTargetKind::GridTargetDataCell as i32
        && grid.active_indicator.take().is_some()
    {
        grid.mark_dirty();
    }
    if dbl_click && !is_background_target(&event_target) && hit.area != HitArea::DropdownList {
        grid.events.push(GridEventData::DblClick {
            row: hit.row,
            col: hit.col,
            target: event_target.clone(),
        });
    }
    if !dbl_click && !is_background_target(&event_target) && hit.area != HitArea::DropdownList {
        if behavior.allow_before_mouse_down {
            grid.events.push(GridEventData::BeforeMouseDown {
                row: hit.row,
                col: hit.col,
                target: event_target,
            });
        }
    }
    if !dbl_click && hit.row >= 0 && hit.col >= 0 && hit.area != HitArea::DropdownList {
        grid.events.push(GridEventData::MouseDown {
            button: _button,
            modifier,
            x,
            y,
        });
    }

    match hit.area {
        HitArea::DropdownList => {
            if let Some(idx) = grid.dropdown_hit_index(x, y) {
                commit_dropdown_item_click(grid, idx);
            }
        }
        HitArea::DropdownButton => {
            if hit.row >= 0 && hit.col >= 0 {
                if set_dropdown_button_pressed(grid, hit.row, hit.col) {
                    grid.mark_dirty();
                }
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
                    grid.selection.set_extent(
                        grid.selection.row,
                        grid.selection.col,
                        grid.rows,
                        grid.cols,
                    );
                }
                grid.events.push(GridEventData::CellFocusChanged {
                    old_row,
                    old_col,
                    new_row: hit.row,
                    new_col: hit.col,
                });
                let legacy_button =
                    grid.resolved_cell_control(hit.row, hit.col) == CellControl::EllipsisButton;
                if !legacy_button {
                    if grid.is_editing()
                        && grid.edit.edit_row == hit.row
                        && grid.edit.edit_col == hit.col
                    {
                        if let Some(event) = grid.before_dropdown_open_event(hit.row, hit.col) {
                            grid.events.push(event);
                        }
                        grid.events.push(GridEventData::DropdownOpened);
                    } else if behavior.allow_begin_edit {
                        begin_edit_from_input(grid, hit.row, hit.col);
                    }
                }
                grid.mark_dirty();
            }
        }
        HitArea::CheckBox => {
            if hit.row >= 0 && hit.col >= 0 {
                if grid.host_pointer_dispatch {
                    return;
                }

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
                    grid.selection.set_extent(
                        grid.selection.row,
                        grid.selection.col,
                        grid.rows,
                        grid.cols,
                    );
                }
                grid.events.push(GridEventData::CellFocusChanged {
                    old_row,
                    old_col,
                    new_row: hit.row,
                    new_col: hit.col,
                });

                if dbl_click || !toggle_checkbox_cell(grid, hit.row, hit.col) {
                    grid.mark_dirty();
                }
            }
        }
        HitArea::OutlineButton => {
            if hit.row >= grid.fixed_rows {
                grid.outline_click_active = true;
                let collapsing = !grid
                    .row_props
                    .get(&hit.row)
                    .map_or(false, |rp| rp.is_collapsed);
                if behavior.allow_node_toggle {
                    if let Some(node_id) = grid.tree.node_id_at_row(grid.fixed_rows, hit.row) {
                        grid.events.push(GridEventData::BeforeTreeNodeToggle {
                            node_id: node_id.to_string(),
                            row: hit.row,
                            collapse: collapsing,
                        });
                    } else {
                        grid.events.push(GridEventData::BeforeNodeToggle {
                            row: hit.row,
                            collapse: collapsing,
                        });
                    }
                    apply_node_toggle_after_before(grid, hit.row, collapsing);
                }
            }
        }
        HitArea::IndicatorColTop => {
            if hit.col >= 0 && hit.col < grid.cols {
                if grid.host_pointer_dispatch {
                    return;
                }

                if grid.header_click_select && grid.header_features == 0 {
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

                if grid.header_features > 0
                    && (behavior.allow_header_sort || behavior.allow_column_drag)
                {
                    let can_move = behavior.allow_column_drag && grid.header_features & 2 != 0;
                    let can_sort = grid.header_features & 1 != 0;
                    if can_move && !dbl_click {
                        grid.col_drag_pending = true;
                        grid.col_drag_pending_source = hit.col;
                        grid.col_drag_pending_can_sort = can_sort;
                        grid.col_drag_pending_since = Some(Instant::now());
                    } else if can_sort && behavior.allow_header_sort {
                        grid.events.push(GridEventData::BeforeSort { col: hit.col });
                        let old_sort_keys = grid.sort_state.sort_keys.clone();
                        crate::sort::handle_header_click(grid, hit.col);
                        if grid.sort_state.sort_keys != old_sort_keys {
                            grid.events.push(GridEventData::AfterSort { col: hit.col });
                        }
                    }
                    grid.mark_dirty();
                }
            }
        }
        HitArea::IndicatorRowStart => {
            if hit.row >= 0 && hit.row < grid.rows {
                if grid.host_pointer_dispatch {
                    return;
                }

                if grid.header_click_select {
                    let anchor_col = grid.selection.col.clamp(grid.fixed_cols, grid.cols - 1);
                    grid.selection.select(
                        hit.row,
                        anchor_col,
                        hit.row,
                        grid.cols - 1,
                        grid.rows,
                        grid.cols,
                    );
                } else {
                    let target_col = grid.selection.col.clamp(grid.fixed_cols, grid.cols - 1);
                    grid.selection.set_cursor(
                        hit.row,
                        target_col,
                        grid.rows,
                        grid.cols,
                        grid.fixed_rows,
                        grid.fixed_cols,
                    );
                    grid.selection
                        .set_extent(hit.row, target_col, grid.rows, grid.cols);
                }
                grid.mark_dirty();
            }
        }
        HitArea::IndicatorRowStartResize => {
            if grid.host_pointer_dispatch {
                return;
            }
            if grid.indicator_bands.row_start.allow_resize && behavior.allow_user_resize {
                grid.events
                    .push(GridEventData::BeforeUserResize { row: -1, col: -1 });
                begin_row_start_indicator_width_resize(grid, x);
            }
        }
        HitArea::Cell
        | HitArea::CellText
        | HitArea::CellPicture
        | HitArea::CellButtonPicture
        | HitArea::FixedRow
        | HitArea::FixedCol => {
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
                    grid.selection.set_extent(
                        grid.selection.row,
                        grid.selection.col,
                        grid.rows,
                        grid.cols,
                    );
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
                let old_selection = grid.selection.clone();
                let old_row = old_selection.row;
                let old_col = old_selection.col;
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
                    grid.selection.set_extent(
                        grid.selection.row,
                        grid.selection.col,
                        grid.rows,
                        grid.cols,
                    );
                }

                // Fire CellFocusChanged
                grid.events.push(GridEventData::CellFocusChanged {
                    old_row,
                    old_col,
                    new_row: hit.row,
                    new_col: hit.col,
                });

                // Handle double click for editing, or single click for dropdown
                // cells so touch-style hosts can open combo editors without an
                // extra activation gesture.
                let is_dropdown = !grid.active_dropdown_list(hit.row, hit.col).is_empty();

                if behavior.allow_begin_edit && grid.edit_trigger_mode >= 2 {
                    if dbl_click {
                        begin_edit_from_pointer_double_click(grid, hit.row, hit.col, hit.x_in_cell);
                    } else if is_dropdown {
                        begin_edit_from_input(grid, hit.row, hit.col);
                    }
                }

                // Handle header features on fixed row click.
                // Clicking a header for sort/drag does NOT
                // move the selection — restore it after the action.
                if hit.area == HitArea::FixedRow
                    && hit.row < grid.fixed_rows
                    && !is_dropdown
                    && grid.header_features > 0
                    && (behavior.allow_header_sort || behavior.allow_column_drag)
                {
                    let can_move = behavior.allow_column_drag && grid.header_features & 2 != 0;
                    let can_sort = grid.header_features & 1 != 0;

                    if can_move && !dbl_click {
                        // In move mode, require long-press to start reorder so
                        // short click can still map cleanly to sort.
                        grid.col_drag_pending = true;
                        grid.col_drag_pending_source = hit.col;
                        grid.col_drag_pending_can_sort = can_sort;
                        grid.col_drag_pending_since = Some(Instant::now());
                    } else if can_sort && behavior.allow_header_sort {
                        grid.events.push(GridEventData::BeforeSort { col: hit.col });
                        let old_sort_keys = grid.sort_state.sort_keys.clone();
                        crate::sort::handle_header_click(grid, hit.col);
                        if grid.sort_state.sort_keys != old_sort_keys {
                            grid.events.push(GridEventData::AfterSort { col: hit.col });
                        }
                    }

                    // Restore selection — header clicks should not move the cursor.
                    grid.selection = old_selection;
                }

                grid.mark_dirty();
            }
        }
        HitArea::IndicatorCornerTopStart => {
            if !grid.indicator_bands.corner_top_start.visible {
                return;
            }
            if let Some(level) = outline_level_hit {
                grid.outline_click_active = true;
                if set_outline_level_button_pressed(grid, level) {
                    grid.mark_dirty();
                }
                return;
            }
            if grid.selection.allow_selection && grid.rows > 0 && grid.cols > 0 {
                let anchor_row = grid.fixed_rows.min(grid.rows - 1);
                let anchor_col = grid.fixed_cols.min(grid.cols - 1);
                grid.selection.select(
                    anchor_row,
                    anchor_col,
                    grid.rows - 1,
                    grid.cols - 1,
                    grid.rows,
                    grid.cols,
                );
                grid.mark_dirty();
            } else if grid.allow_user_freezing > 0 {
                grid.freeze_drag_active = true;
                grid.freeze_drag_is_row = grid.allow_user_freezing != 1;
            }
        }
        HitArea::ColBorder => {
            if hit.col >= 0 && hit.col < grid.cols {
                if col_resize_enabled(grid) {
                    if dbl_click && grid.auto_size_mouse {
                        grid.auto_resize_col(hit.col);
                    } else if behavior.allow_user_resize {
                        grid.events.push(GridEventData::BeforeUserResize {
                            row: -1,
                            col: hit.col,
                        });
                        begin_user_resize_after_before(grid, -1, hit.col, x);
                    }
                }
            }
        }
        HitArea::RowBorder => {
            if hit.row >= 0 && hit.row < grid.rows {
                if row_resize_enabled(grid) && behavior.allow_user_resize {
                    grid.events.push(GridEventData::BeforeUserResize {
                        row: hit.row,
                        col: -1,
                    });
                    begin_user_resize_after_before(grid, hit.row, -1, y);
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
            let sbg = scrollbar_geometry(grid);
            let sb_size = sbg.bar_size as f32;
            let ix = x as i32;
            let iy = y as i32;
            let is_h = hit.area == HitArea::HScrollBar;
            grid.scrollbar_hover = true;
            let _ = bump_scrollbar_fade(grid);

            if is_h && sbg.show_h {
                if sbg.uses_arrows
                    && ix >= sbg.h_left_arrow_x
                    && ix < sbg.h_left_arrow_x + sbg.bar_size
                {
                    let step = sb_size * 3.0;
                    scroll_by_with_events(grid, -step, 0.0);
                    grid.mark_dirty_visual();
                    grid.scrollbar_repeat_active = true;
                    grid.scrollbar_repeat_horizontal = true;
                    grid.scrollbar_repeat_delta = -step;
                    grid.scrollbar_repeat_delay = 0.4;
                    grid.scrollbar_repeat_is_track = false;
                    grid.scrollbar_repeat_mouse_pos = 0.0;
                } else if sbg.uses_arrows
                    && ix >= sbg.h_right_arrow_x
                    && ix < sbg.h_right_arrow_x + sbg.bar_size
                {
                    let step = sb_size * 3.0;
                    scroll_by_with_events(grid, step, 0.0);
                    grid.mark_dirty_visual();
                    grid.scrollbar_repeat_active = true;
                    grid.scrollbar_repeat_horizontal = true;
                    grid.scrollbar_repeat_delta = step;
                    grid.scrollbar_repeat_delay = 0.4;
                    grid.scrollbar_repeat_is_track = false;
                    grid.scrollbar_repeat_mouse_pos = 0.0;
                } else if ix >= sbg.h_track_x && ix < sbg.h_track_x + sbg.h_track_w {
                    if ix >= sbg.h_thumb_x && ix < sbg.h_thumb_x + sbg.h_thumb_w {
                        grid.scrollbar_drag_active = true;
                        grid.scrollbar_drag_horizontal = true;
                        grid.scrollbar_drag_start_pos = x;
                        grid.scrollbar_drag_start_scroll = grid.scroll.scroll_x;
                    } else if ix < sbg.h_thumb_x {
                        let page = sbg.view_w as f32;
                        scroll_by_with_events(grid, -page, 0.0);
                        grid.mark_dirty_visual();
                        grid.scrollbar_repeat_active = true;
                        grid.scrollbar_repeat_horizontal = true;
                        grid.scrollbar_repeat_delta = -page;
                        grid.scrollbar_repeat_delay = 0.4;
                        grid.scrollbar_repeat_is_track = true;
                        grid.scrollbar_repeat_mouse_pos = ix as f32;
                    } else {
                        let page = sbg.view_w as f32;
                        scroll_by_with_events(grid, page, 0.0);
                        grid.mark_dirty_visual();
                        grid.scrollbar_repeat_active = true;
                        grid.scrollbar_repeat_horizontal = true;
                        grid.scrollbar_repeat_delta = page;
                        grid.scrollbar_repeat_delay = 0.4;
                        grid.scrollbar_repeat_is_track = true;
                        grid.scrollbar_repeat_mouse_pos = ix as f32;
                    }
                }
            } else if !is_h && sbg.show_v {
                if sbg.uses_arrows
                    && iy >= sbg.v_top_arrow_y
                    && iy < sbg.v_top_arrow_y + sbg.bar_size
                {
                    let step = sb_size * 3.0;
                    scroll_by_with_events(grid, 0.0, -step);
                    grid.mark_dirty_visual();
                    grid.scrollbar_repeat_active = true;
                    grid.scrollbar_repeat_horizontal = false;
                    grid.scrollbar_repeat_delta = -step;
                    grid.scrollbar_repeat_delay = 0.4;
                    grid.scrollbar_repeat_is_track = false;
                    grid.scrollbar_repeat_mouse_pos = 0.0;
                } else if sbg.uses_arrows
                    && iy >= sbg.v_bot_arrow_y
                    && iy < sbg.v_bot_arrow_y + sbg.bar_size
                {
                    let step = sb_size * 3.0;
                    scroll_by_with_events(grid, 0.0, step);
                    grid.mark_dirty_visual();
                    grid.scrollbar_repeat_active = true;
                    grid.scrollbar_repeat_horizontal = false;
                    grid.scrollbar_repeat_delta = step;
                    grid.scrollbar_repeat_delay = 0.4;
                    grid.scrollbar_repeat_is_track = false;
                    grid.scrollbar_repeat_mouse_pos = 0.0;
                } else if iy >= sbg.v_track_y && iy < sbg.v_track_y + sbg.v_track_h {
                    if iy >= sbg.v_thumb_y && iy < sbg.v_thumb_y + sbg.v_thumb_h {
                        grid.scrollbar_drag_active = true;
                        grid.scrollbar_drag_horizontal = false;
                        grid.scrollbar_drag_start_pos = y;
                        grid.scrollbar_drag_start_scroll = grid.scroll.scroll_y;
                    } else if iy < sbg.v_thumb_y {
                        let page = sbg.view_h as f32;
                        scroll_by_with_events(grid, 0.0, -page);
                        grid.mark_dirty_visual();
                        grid.scrollbar_repeat_active = true;
                        grid.scrollbar_repeat_horizontal = false;
                        grid.scrollbar_repeat_delta = -page;
                        grid.scrollbar_repeat_delay = 0.4;
                        grid.scrollbar_repeat_is_track = true;
                        grid.scrollbar_repeat_mouse_pos = iy as f32;
                    } else {
                        let page = sbg.view_h as f32;
                        scroll_by_with_events(grid, 0.0, page);
                        grid.mark_dirty_visual();
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
    }
}

/// Handle pointer move event
pub fn handle_pointer_move(grid: &mut VolvoxGrid, x: f32, y: f32, button: i32, modifier: i32) {
    if grid.edit_pointer_select_active && button & 1 == 0 {
        grid.edit_pointer_select_active = false;
    }

    let event_hit = hit_test(grid, x, y);
    emit_pointer_move_and_hover(grid, &event_hit, button, modifier, x, y);

    if grid.edit_pointer_select_active {
        if update_active_edit_pointer_selection(grid, x) {
            return;
        }
    }

    // Handle active fast scroll gesture
    if grid.fast_scroll_active {
        update_fast_scroll_target(grid, y);
        return;
    }

    // Handle active scrollbar thumb drag
    if grid.scrollbar_drag_active {
        let sbg = scrollbar_geometry(grid);
        let _ = bump_scrollbar_fade(grid);
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
        grid.mark_dirty_visual();
        return;
    }

    // Handle active resize drag
    if grid.resize_active {
        grid.cursor_style = if grid.resize_is_col { 1 } else { 2 };
        if grid.resize_is_col {
            let delta = (x - grid.resize_start_pos) as i32;
            let new_width = (grid.resize_start_size + delta).max(0);
            if grid.resize_index < 0 {
                set_row_start_indicator_width(grid, new_width);
            } else if matches!(grid.allow_user_resizing, 4 | 6) {
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

    if grid.outline_level_button_pressed {
        if update_outline_level_button_pressed_inside(grid, &event_hit, x) {
            grid.mark_dirty();
        }
        return;
    }

    // Suppress selection extension after outline or dropdown popup clicks.
    if grid.outline_click_active {
        return;
    }
    if grid.dropdown_click_active {
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

    if update_scrollbar_hover(grid, x, y) {
        grid.mark_dirty_visual();
    }

    let prev_mouse_row = grid.mouse_row;
    let prev_mouse_col = grid.mouse_col;
    let hit = hit_test(grid, x, y);
    grid.mouse_row = hit.row;
    grid.mouse_col = hit.col;
    let hover_mode = grid.selection.hover_mode;
    if hover_mode != HOVER_NONE {
        let row_changed = grid.mouse_row != prev_mouse_row;
        let col_changed = grid.mouse_col != prev_mouse_col;
        // Invalidate only for axes actually used by hover mode.
        // ROW should ignore pure column motion, COLUMN should ignore pure row motion.
        let row_relevant =
            hover_mode_has(hover_mode, HOVER_ROW) || hover_mode_has(hover_mode, HOVER_CELL);
        let col_relevant =
            hover_mode_has(hover_mode, HOVER_COLUMN) || hover_mode_has(hover_mode, HOVER_CELL);
        if (row_relevant && row_changed) || (col_relevant && col_changed) {
            grid.mark_dirty();
        }
    }

    // Update cursor style based on hit area
    grid.cursor_style = match hit.area {
        HitArea::ColBorder => {
            if col_resize_enabled(grid) {
                1 // col-resize
            } else {
                0
            }
        }
        HitArea::RowBorder => {
            if row_resize_enabled(grid) {
                2 // row-resize
            } else {
                0
            }
        }
        HitArea::IndicatorRowStartResize => 1,
        HitArea::OutlineButton => 4,
        HitArea::DropdownButton | HitArea::CheckBox => 5,
        HitArea::Cell
        | HitArea::CellText
        | HitArea::CellPicture
        | HitArea::CellButtonPicture
        | HitArea::FixedRow
        | HitArea::FixedCol => {
            if cell_hit_uses_pointer_cursor(grid, &hit) {
                5
            } else {
                0
            }
        }
        HitArea::HScrollBar | HitArea::VScrollBar | HitArea::FastScroll => 0,
        _ => 0,
    };

    // Extend selection only during left-button drag (button bit 0 = primary).
    // Right-button (bit 1) and modifier-only moves must not alter selection.
    // Skipped entirely when host_pointer_dispatch — host adapter owns selection.
    if !grid.host_pointer_dispatch && button & 1 != 0 && hit.row >= 0 && hit.col >= 0 {
        grid.selection.set_extent(
            hit.row.clamp(grid.fixed_rows, grid.rows - 1),
            hit.col.clamp(grid.fixed_cols, grid.cols - 1),
            grid.rows,
            grid.cols,
        );
        grid.mark_dirty();
    }
}

/// Handle pointer up event
pub fn handle_pointer_up(grid: &mut VolvoxGrid, x: f32, y: f32, _button: i32, _modifier: i32) {
    handle_pointer_up_with_behavior(grid, x, y, _button, _modifier, InputBehavior::default());
}

pub fn handle_pointer_up_with_behavior(
    grid: &mut VolvoxGrid,
    x: f32,
    y: f32,
    _button: i32,
    _modifier: i32,
    behavior: InputBehavior,
) {
    // Clear scrollbar auto-repeat on any pointer up
    grid.scrollbar_repeat_active = false;

    // Complete fast scroll gesture
    if grid.fast_scroll_active {
        grid.fast_scroll_active = false;
        grid.fast_scroll_target_row = -1;
        grid.mark_dirty_visual();
        return;
    }

    // Complete scrollbar thumb drag
    if grid.scrollbar_drag_active {
        grid.scrollbar_drag_active = false;
        let hover_changed = update_scrollbar_hover(grid, x, y);
        if hover_changed {
            grid.mark_dirty_visual();
        }
        grid.mark_dirty_visual();
        return;
    }

    if clear_dropdown_button_pressed(grid) {
        grid.mark_dirty();
    }

    if grid.outline_level_button_pressed {
        let hit = hit_test(grid, x, y);
        let level = grid.outline_level_button_pressed_level;
        let commit = corner_outline_level_hit_from_result(grid, &hit, x) == Some(level);
        clear_outline_level_button_pressed(grid);
        grid.outline_click_active = false;
        if commit {
            crate::outline::toggle_level_button(grid, level);
        }
        grid.mark_dirty();
        return;
    }

    // Clear outline button click guard
    if grid.outline_click_active {
        grid.outline_click_active = false;
        return;
    }

    // Consume the mouse-up that completes a dropdown popup click.
    if grid.dropdown_click_active {
        grid.dropdown_click_active = false;
        return;
    }

    if grid.edit_pointer_select_active {
        grid.edit_pointer_select_active = false;
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
        let col_ev = if grid.resize_is_col && grid.resize_index >= 0 {
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

        if source >= 0
            && can_sort
            && behavior.allow_header_sort
            && elapsed < HEADER_REORDER_LONG_PRESS_MS
        {
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
        if let Some((source, new_position)) = take_column_drag_move(grid) {
            if behavior.allow_column_drag {
                grid.events.push(GridEventData::BeforeMoveColumn {
                    col: source,
                    new_position,
                });
                apply_move_column_after_before(grid, source, new_position);
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
    let target = target_from_hit(grid, &hit);
    if !is_background_target(&target) {
        grid.events.push(GridEventData::Click {
            row: hit.row,
            col: hit.col,
            hit_area: hit_area_to_proto(&hit.area),
            interaction: resolved_click_interaction(grid, hit.row, hit.col),
            target,
        });
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

    // During IME composition, suppress all grid key handling.
    // The IME owns the keyboard until composition ends.
    if grid.edit.composing && !grid.edit.is_engine_composing() {
        grid.events
            .push(GridEventData::KeyDown { key_code, modifier });
        return;
    }

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
        if key_code == 8 && grid.edit.is_engine_composing() {
            let result = grid.edit.compose_backspace();
            if apply_compose_result(grid, result) {
                grid.events
                    .push(GridEventData::KeyDownEdit { key_code, modifier });
                return;
            }
        }
        if should_flush_engine_compose_on_key_down(key_code, ctrl) {
            flush_engine_compose(grid);
        }

        match key_code {
            27 if !grid.host_key_dispatch => {
                // Escape: cancel edit (skipped when host drives dispatch)
                let row = grid.edit.edit_row;
                let col = grid.edit.edit_col;
                let original_text = grid.edit.original_text.clone();
                if grid.cancel_edit() {
                    grid.events.push(GridEventData::AfterEdit {
                        row,
                        col,
                        old_text: original_text.clone(),
                        new_text: original_text,
                    });
                }
            }
            13 if !grid.host_key_dispatch => {
                // Enter: commit edit (skipped when host drives dispatch)
                commit_active_edit(grid);
            }
            // Ctrl+A: select all text in editor
            65 if ctrl => {
                grid.edit.select_all();
                grid.mark_dirty();
            }
            8 => {
                if !grid.edit.dropdown_items.is_empty() && !grid.edit.dropdown_editable {
                    grid.edit.clear_dropdown_search();
                } else {
                    // Backspace
                    grid.edit.delete_back();
                    grid.events.push(GridEventData::CellEditChange {
                        text: grid.edit.edit_text.clone(),
                    });
                    grid.mark_dirty();
                }
            }
            46 => {
                if !grid.edit.dropdown_items.is_empty() && !grid.edit.dropdown_editable {
                    grid.edit.clear_dropdown_search();
                } else {
                    // Delete
                    grid.edit.delete_forward();
                    grid.events.push(GridEventData::CellEditChange {
                        text: grid.edit.edit_text.clone(),
                    });
                    grid.mark_dirty();
                }
            }
            37 => {
                // Left arrow
                if ctrl && shift {
                    grid.edit.select_word_left();
                } else if ctrl {
                    grid.edit.move_word_left();
                } else if shift {
                    grid.edit.select_left();
                } else {
                    grid.edit.move_left();
                }
                grid.mark_dirty();
            }
            39 => {
                // Right arrow
                if ctrl && shift {
                    grid.edit.select_word_right();
                } else if ctrl {
                    grid.edit.move_word_right();
                } else if shift {
                    grid.edit.select_right();
                } else {
                    grid.edit.move_right();
                }
                grid.mark_dirty();
            }
            36 => {
                // Home
                if shift {
                    grid.edit.select_home();
                } else {
                    grid.edit.move_home();
                }
                grid.mark_dirty();
            }
            35 => {
                // End
                if shift {
                    grid.edit.select_end();
                } else {
                    grid.edit.move_end();
                }
                grid.mark_dirty();
            }
            38 => {
                if !grid.edit.dropdown_items.is_empty() {
                    // Up arrow in dropdown: move selection up
                    let new_idx = (grid.edit.dropdown_index - 1).max(0);
                    grid.edit.set_dropdown_index(new_idx);
                    grid.edit.clear_dropdown_search();
                    grid.mark_dirty();
                } else if grid.edit.ui_mode == crate::edit::EditUiMode::EditMode {
                    // F2 edit mode: Up moves caret to the start.
                    if shift {
                        grid.edit.select_home();
                    } else {
                        grid.edit.move_home();
                    }
                    grid.mark_dirty();
                } else if !grid.host_key_dispatch {
                    // Enter mode: commit and move to the cell above.
                    let target_row = visible_focus_row_with_delta(grid, grid.selection.row, -1);
                    let target_col = grid.selection.col;
                    if commit_active_edit(grid) {
                        move_selection_after_edit_commit(grid, target_row, target_col);
                    }
                }
            }
            40 => {
                if !grid.edit.dropdown_items.is_empty() {
                    // Down arrow in dropdown: move selection down
                    let max_idx = grid.edit.dropdown_count() - 1;
                    let new_idx = (grid.edit.dropdown_index + 1).min(max_idx);
                    grid.edit.set_dropdown_index(new_idx);
                    grid.edit.clear_dropdown_search();
                    grid.mark_dirty();
                } else if grid.edit.ui_mode == crate::edit::EditUiMode::EditMode {
                    // F2 edit mode: Down moves caret to the end.
                    if shift {
                        grid.edit.select_end();
                    } else {
                        grid.edit.move_end();
                    }
                    grid.mark_dirty();
                } else if !grid.host_key_dispatch {
                    // Enter mode: commit and move to the cell below.
                    let target_row = visible_focus_row_with_delta(grid, grid.selection.row, 1);
                    let target_col = grid.selection.col;
                    if commit_active_edit(grid) {
                        move_selection_after_edit_commit(grid, target_row, target_col);
                    }
                }
            }
            _ => {}
        }
        grid.events
            .push(GridEventData::KeyDownEdit { key_code, modifier });
        return;
    }

    if handle_indicator_keyboard_focus(grid, key_code, behavior) {
        grid.events
            .push(GridEventData::KeyDown { key_code, modifier });
        return;
    }

    let old_row = grid.selection.row;
    let old_col = grid.selection.col;
    let old_row_end = grid.selection.row_end;
    let old_col_end = grid.selection.col_end;

    match key_code {
        // Arrow keys
        37 => {
            // Left
            if shift {
                let new_col = (grid.selection.col_end - 1).max(grid.fixed_cols);
                grid.selection
                    .set_extent(grid.selection.row_end, new_col, grid.rows, grid.cols);
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
                let new_row = visible_focus_row_with_delta(grid, grid.selection.row_end, -1);
                grid.selection
                    .set_extent(new_row, grid.selection.col_end, grid.rows, grid.cols);
            } else {
                let new_row = visible_focus_row_with_delta(grid, grid.selection.row, -1);
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
                grid.selection
                    .set_extent(grid.selection.row_end, new_col, grid.rows, grid.cols);
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
                let new_row = visible_focus_row_with_delta(grid, grid.selection.row_end, 1);
                grid.selection
                    .set_extent(new_row, grid.selection.col_end, grid.rows, grid.cols);
            } else {
                let new_row = visible_focus_row_with_delta(grid, grid.selection.row, 1);
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
            let new_row = visible_focus_row_with_delta(grid, grid.selection.row, -page);
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
            let new_row = visible_focus_row_with_delta(grid, grid.selection.row, page);
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
                let target_row =
                    visible_focus_row_at_or_after(grid, grid.fixed_rows).unwrap_or(grid.fixed_rows);
                grid.selection.set_cursor(
                    target_row,
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
                let target_row =
                    visible_focus_row_at_or_before(grid, grid.rows - 1).unwrap_or(grid.rows - 1);
                grid.selection.set_cursor(
                    target_row,
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
        // Space - toggle a selected checkbox without entering text edit.
        32 => {
            if !grid.host_key_dispatch && !grid.is_editing() {
                if behavior.allow_node_toggle && toggle_selected_outline_node(grid) {
                    grid.mark_dirty();
                } else if selected_outline_label_keyboard_target(grid).is_some() {
                    // Tree rows reserve Space for the row-indicator tree.
                } else if toggle_checkbox_cell(grid, grid.selection.row, grid.selection.col) {
                    grid.mark_dirty();
                }
            }
        }
        // Enter - toggle a selected checkbox, otherwise start editing if editable
        // (skipped when host drives dispatch).
        13 => {
            if !grid.host_key_dispatch && !grid.is_editing() {
                if behavior.allow_node_toggle && toggle_selected_outline_node(grid) {
                    grid.mark_dirty();
                } else if selected_outline_label_keyboard_target(grid).is_some() {
                    // Tree rows reserve Enter for the row-indicator tree.
                } else if toggle_checkbox_cell(grid, grid.selection.row, grid.selection.col) {
                    grid.mark_dirty();
                } else if behavior.allow_begin_edit && grid.edit_trigger_mode >= 1 {
                    begin_edit_from_input(grid, grid.selection.row, grid.selection.col);
                }
            }
        }
        // F2 - start editing with the caret at the end (skipped when host drives dispatch).
        // Checkbox cells are toggle-only and never enter text edit.
        113 => {
            if !grid.host_key_dispatch
                && behavior.allow_begin_edit
                && grid.edit_trigger_mode >= 1
                && !grid.is_editing()
            {
                let (row, col) = selected_outline_label_edit_target(grid)
                    .unwrap_or((grid.selection.row, grid.selection.col));
                if !is_boolean_checkbox_cell(grid, row, col) {
                    begin_edit_from_input_with_options(grid, row, col, true);
                }
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

    let cursor_changed = grid.selection.row != old_row || grid.selection.col != old_col;
    let extent_changed =
        grid.selection.row_end != old_row_end || grid.selection.col_end != old_col_end;

    if cursor_changed {
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
            grid.data_viewport_width(),
            grid.data_viewport_height(),
            grid.fixed_rows,
            grid.fixed_cols,
            grid.pinned_top_height() + grid.pinned_bottom_height(),
            grid.pinned_left_width() + grid.pinned_right_width(),
        );
        grid.mark_dirty();
    } else if extent_changed {
        grid.scroll.show_cell(
            grid.selection.row_end,
            grid.selection.col_end,
            &grid.layout,
            grid.data_viewport_width(),
            grid.data_viewport_height(),
            grid.fixed_rows,
            grid.fixed_cols,
            grid.pinned_top_height() + grid.pinned_bottom_height(),
            grid.pinned_left_width() + grid.pinned_right_width(),
        );
        grid.mark_dirty();
    }

    grid.events
        .push(GridEventData::KeyDown { key_code, modifier });
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
        if grid.edit.composing && !grid.edit.is_engine_composing() {
            return;
        }
        if !grid.edit.dropdown_items.is_empty() && !grid.edit.dropdown_editable {
            if grid.effective_dropdown_search(grid.edit.edit_row, grid.edit.edit_col)
                && grid
                    .edit
                    .select_readonly_dropdown_char(ch, type_ahead_delay_ms(grid))
            {
                grid.events.push(GridEventData::CellEditChange {
                    text: grid.edit.edit_text.clone(),
                });
                grid.mark_dirty();
            }
            return;
        }

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

        if grid.edit.engine_compose_enabled() {
            if grid.edit.is_engine_composing() && !grid.edit.compose_should_handle(ch) {
                flush_engine_compose(grid);
            }
            if grid.edit.compose_should_handle(ch) {
                let result = grid.edit.compose_feed(ch);
                if apply_compose_result(grid, result) {
                    return;
                }
            }
        }

        // Insert character into active editor
        grid.edit.insert_char(ch);

        // DropdownSearch: type-ahead dropdown list
        if grid.effective_dropdown_search(grid.edit.edit_row, grid.edit.edit_col)
            && !grid.edit.dropdown_items.is_empty()
        {
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
        if ch == ' ' && selected_outline_label_keyboard_target(grid).is_some() {
            return;
        }
        if ch == ' '
            && !grid.host_key_dispatch
            && behavior.allow_begin_edit
            && grid.edit_trigger_mode >= 1
        {
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
                grid.selection.set_extent(
                    grid.selection.row,
                    grid.selection.col,
                    grid.rows,
                    grid.cols,
                );
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
                    grid.data_viewport_width(),
                    grid.data_viewport_height(),
                    grid.fixed_rows,
                    grid.fixed_cols,
                    grid.pinned_top_height() + grid.pinned_bottom_height(),
                    grid.pinned_left_width() + grid.pinned_right_width(),
                );
                grid.mark_dirty();
            }
        }
    } else if ch == ' ' && selected_outline_label_keyboard_target(grid).is_some() {
        return;
    } else if !grid.host_key_dispatch && behavior.allow_begin_edit && grid.edit_trigger_mode >= 1 {
        // Auto-start editing on keypress (keyboard-edit mode), except for
        // select-only dropdown lists which must not accept freeform text.
        let row = grid.selection.row;
        let col = grid.selection.col;
        let dropdown_list = grid.active_dropdown_list(row, col);
        let readonly_dropdown = !dropdown_list.is_empty() && !dropdown_list.starts_with('|');

        if readonly_dropdown {
            if grid.effective_dropdown_search(row, col) {
                begin_edit_from_input(grid, row, col);
                if grid.is_editing()
                    && grid
                        .edit
                        .select_readonly_dropdown_char(ch, type_ahead_delay_ms(grid))
                {
                    grid.events.push(GridEventData::CellEditChange {
                        text: grid.edit.edit_text.clone(),
                    });
                    grid.mark_dirty();
                } else if grid.is_editing() {
                    grid.cancel_edit();
                }
            }
        } else {
            begin_edit_from_input(grid, row, col);

            if grid.is_editing() {
                // Clear old text and type the new character (VSVolvoxGrid8 behavior)
                grid.edit.update_text(String::new());
                grid.edit.sel_start = 0;
                grid.edit.sel_length = 0;
                if grid.edit.engine_compose_enabled() && grid.edit.compose_should_handle(ch) {
                    let result = grid.edit.compose_feed(ch);
                    if apply_compose_result(grid, result) {
                        // compose result already pushed state updates
                    } else {
                        grid.edit.insert_char(ch);
                        grid.events.push(GridEventData::CellEditChange {
                            text: grid.edit.edit_text.clone(),
                        });
                        grid.mark_dirty();
                    }
                } else {
                    grid.edit.insert_char(ch);
                    grid.events.push(GridEventData::CellEditChange {
                        text: grid.edit.edit_text.clone(),
                    });
                    grid.mark_dirty();
                }
            }
        }
    }

    grid.events.push(GridEventData::KeyPress {
        key_ascii: char_code as i32,
    });
}

/// Handle scroll event
pub fn handle_scroll(grid: &mut VolvoxGrid, delta_x: f32, delta_y: f32) {
    handle_scroll_with_behavior(grid, delta_x, delta_y, InputBehavior::default());
}

pub fn handle_scroll_with_behavior(
    grid: &mut VolvoxGrid,
    delta_x: f32,
    delta_y: f32,
    behavior: InputBehavior,
) {
    // During header drag-reorder, touch hosts may still emit coalesced scroll
    // deltas; ignore them so reorder remains stable.
    if grid.col_drag_active || grid.col_drag_pending {
        return;
    }
    if delta_x != 0.0 || delta_y != 0.0 {
        let _ = bump_scrollbar_fade(grid);
    }

    let line_height = if grid.is_tui_mode() {
        1.0
    } else {
        grid.default_row_height as f32
    };
    let dx = delta_x * line_height;
    let dy = delta_y * line_height;
    if grid.handle_pull_to_refresh_scroll(dx, dy) {
        grid.scroll.stop_fling();
        return;
    }
    let old_top_left =
        visible_top_left_for_scroll(grid, grid.scroll.scroll_x, grid.scroll.scroll_y);

    let mut next_scroll = grid.scroll.clone();
    next_scroll.scroll_by(dx, dy);
    if grid.is_tui_mode() {
        next_scroll.quantize_to_cells();
    }
    let predicted_top_left =
        visible_top_left_for_scroll(grid, next_scroll.scroll_x, next_scroll.scroll_y);
    if behavior.allow_before_scroll && old_top_left != predicted_top_left {
        grid.events.push(GridEventData::BeforeScroll {
            old_top_row: old_top_left.0,
            old_left_col: old_top_left.1,
            new_top_row: predicted_top_left.0,
            new_left_col: predicted_top_left.1,
        });
    }

    grid.scroll.scroll_by(dx, dy);
    grid.normalize_scroll_for_mode();
    let new_top_left =
        visible_top_left_for_scroll(grid, grid.scroll.scroll_x, grid.scroll.scroll_y);
    let scrolled = old_top_left != new_top_left;
    if grid.fling_enabled && !grid.is_tui_mode() {
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
        if grid.selection.hover_mode != HOVER_NONE && (grid.mouse_row != -1 || grid.mouse_col != -1)
        {
            // Hover hit target is pointer-position based. After scroll, clear stale
            // hover until the next pointer move updates hit-test coordinates.
            grid.mouse_row = -1;
            grid.mouse_col = -1;
        }
        grid.events.push(GridEventData::AfterScroll {
            old_top_row: old_top_left.0,
            old_left_col: old_top_left.1,
            new_top_row: new_top_left.0,
            new_left_col: new_top_left.1,
        });
    }

    grid.mark_dirty_visual();
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
    if grid.scrollbar_repeat_is_track {
        let sbg = scrollbar_geometry(grid);
        let mp = grid.scrollbar_repeat_mouse_pos as i32;
        let thumb_covers_mouse = if grid.scrollbar_repeat_horizontal {
            mp >= sbg.h_thumb_x && mp < sbg.h_thumb_x + sbg.h_thumb_w
        } else {
            mp >= sbg.v_thumb_y && mp < sbg.v_thumb_y + sbg.v_thumb_h
        };
        if thumb_covers_mouse {
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
    let scrolled = if grid.scrollbar_repeat_horizontal {
        scroll_by_with_events(grid, grid.scrollbar_repeat_delta, 0.0)
    } else {
        scroll_by_with_events(grid, 0.0, grid.scrollbar_repeat_delta)
    };
    if scrolled {
        grid.mark_dirty_visual();
    }
    grid.scrollbar_repeat_delay = 0.05;
    scrolled
}

pub fn tick_scrollbar_fade(grid: &mut VolvoxGrid, dt_seconds: f32) -> bool {
    if !scrollbar_overlays_content(grid.scrollbar_appearance)
        || !dt_seconds.is_finite()
        || dt_seconds <= 0.0
    {
        return false;
    }
    if grid.scrollbar_hover || grid.scrollbar_drag_active || grid.scrollbar_repeat_active {
        let changed = bump_scrollbar_fade(grid);
        if changed {
            grid.mark_dirty_visual();
        }
        return changed;
    }

    let old_opacity = grid.scrollbar_fade_opacity;
    let old_timer = grid.scrollbar_fade_timer;
    if grid.scrollbar_fade_timer > 0.0 {
        grid.scrollbar_fade_timer = (grid.scrollbar_fade_timer - dt_seconds).max(0.0);
    } else {
        let duration = (grid.scrollbar_fade_duration_ms.max(1) as f32) / 1000.0;
        grid.scrollbar_fade_opacity =
            (grid.scrollbar_fade_opacity - dt_seconds / duration).clamp(0.0, 1.0);
    }

    let changed = (grid.scrollbar_fade_opacity - old_opacity).abs() > f32::EPSILON
        || (old_timer > 0.0 && grid.scrollbar_fade_timer == 0.0);
    if changed {
        grid.mark_dirty_visual();
    }
    changed
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::event::GridEventData;
    use crate::grid::VolvoxGrid;
    use crate::indicator::{
        ColIndicatorCellState, CornerIndicatorSlotState, RowIndicatorSlotState,
    };
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

    fn typed_dropdown(labels: &[&str], searchable: Option<bool>) -> pb::Dropdown {
        pb::Dropdown {
            items: labels
                .iter()
                .map(|label| pb::DropdownItem {
                    label: Some((*label).to_string()),
                    ..Default::default()
                })
                .collect(),
            searchable,
            ..Default::default()
        }
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
    fn hit_test_maps_extended_area_to_last_visible_column_when_trailing_column_is_hidden() {
        let mut grid = VolvoxGrid::new(1, 300, 120, 3, 4, 1, 0);
        grid.extend_last_col = true;
        for col in 0..grid.cols {
            grid.set_col_width(col, 40);
        }
        grid.cols_hidden.insert(3);
        prime_layout(&mut grid);

        let hit = hit_test(&mut grid, 250.0, 5.0);

        assert_eq!(hit.area, HitArea::FixedRow);
        assert_eq!(hit.col, 2);
    }

    #[test]
    fn hit_test_maps_right_empty_area_to_background_when_last_column_is_not_extended() {
        let mut grid = VolvoxGrid::new(1, 300, 120, 3, 4, 0, 0);
        for col in 0..grid.cols {
            grid.set_col_width(col, 40);
        }
        grid.cols_hidden.insert(3);
        prime_layout(&mut grid);

        let hit = hit_test(&mut grid, 250.0, 5.0);

        assert_eq!(hit.area, HitArea::Background);
        assert_eq!(hit.row, -1);
        assert_eq!(hit.col, -1);
    }

    #[test]
    fn hit_test_sticky_left_col_returns_overlay_col_not_scrolled_col_underneath() {
        let mut grid = VolvoxGrid::new(1, 160, 120, 3, 6, 0, 0);
        for col in 0..grid.cols {
            grid.set_col_width(col, 40);
        }
        grid.set_col_sticky(3, pb::StickyEdge::StickyLeft as i32);
        grid.scroll.scroll_x = 210.0;
        prime_layout(&mut grid);

        let hit = hit_test(&mut grid, 10.0, 10.0);

        assert_eq!(hit.area, HitArea::Cell);
        assert_eq!(hit.col, 3);
    }

    #[test]
    fn hit_test_sticky_right_col_returns_overlay_col_not_scrolled_col_underneath() {
        let mut grid = VolvoxGrid::new(1, 160, 120, 3, 6, 0, 0);
        for col in 0..grid.cols {
            grid.set_col_width(col, 40);
        }
        grid.set_col_sticky(5, pb::StickyEdge::StickyRight as i32);
        grid.scroll.scroll_x = 40.0;
        prime_layout(&mut grid);

        let hit = hit_test(&mut grid, 130.0, 10.0);

        assert_eq!(hit.area, HitArea::Cell);
        assert_eq!(hit.col, 5);
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
    fn row_indicator_click_near_row_border_selects_when_row_resize_disabled() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 3, 0, 0);
        grid.allow_user_resizing = 1; // cols only
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 80;
        grid.indicator_bands.row_start.slots = vec![RowIndicatorSlotState::new(
            pb::RowIndicatorSlotKind::RowIndicatorSlotNumbers,
            80,
        )];
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        prime_layout(&mut grid);

        let hit = hit_test(&mut grid, 20.0, 43.0);

        assert_eq!(hit.area, HitArea::IndicatorRowStart);
        assert_eq!(hit.row, 0);
    }

    #[test]
    fn row_indicator_allow_resize_resizes_indicator_width() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 3, 0, 0);
        grid.allow_user_resizing = 1; // column resizing can remain independent.
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.allow_resize = true;
        grid.indicator_bands.row_start.width_px = 80;
        grid.indicator_bands.row_start.slots = vec![RowIndicatorSlotState::new(
            pb::RowIndicatorSlotKind::RowIndicatorSlotNumbers,
            80,
        )];
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        prime_layout(&mut grid);

        let right_edge_inside = grid.indicator_bands.row_start.resolved_width_px() - 1;
        handle_pointer_down(&mut grid, right_edge_inside as f32, 30.0, 0, 0, false);
        assert!(grid.resize_active);
        assert!(grid.resize_is_col);
        assert_eq!(grid.resize_index, -1);

        handle_pointer_move(&mut grid, (right_edge_inside + 20) as f32, 30.0, 1, 0);
        assert_eq!(grid.indicator_bands.row_start.resolved_width_px(), 100);

        handle_pointer_up(&mut grid, (right_edge_inside + 20) as f32, 30.0, 0, 0);
        assert!(!grid.resize_active);
        let events = grid.events.drain();
        assert!(events
            .iter()
            .any(|e| { matches!(e.data, GridEventData::AfterUserResize { row: -1, col: -1 }) }));
    }

    #[test]
    fn hit_test_detects_header_col_border_with_row_indicator_offset() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 3, 0, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 40;
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        prime_layout(&mut grid);

        let header_border_x = grid.indicator_bands.row_start.resolved_width_px() + grid.col_pos(1);
        let hit = hit_test(&mut grid, header_border_x as f32, 5.0);

        assert_eq!(hit.area, HitArea::ColBorder);
        assert_eq!(hit.col, 0);
    }

    #[test]
    fn row_indicator_click_reports_target_slot() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 6, 3, 0, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 60;
        grid.indicator_bands.row_start.slots = vec![
            RowIndicatorSlotState::new(pb::RowIndicatorSlotKind::RowIndicatorSlotNumbers, 20),
            RowIndicatorSlotState::new(pb::RowIndicatorSlotKind::RowIndicatorSlotCheckbox, 20),
            RowIndicatorSlotState::new(pb::RowIndicatorSlotKind::RowIndicatorSlotHandle, 20),
        ];
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        prime_layout(&mut grid);

        let click_x = 30.0;
        let click_y = 24.0 + grid.row_pos(3) as f32 + 10.0;
        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, false);
        handle_pointer_up(&mut grid, click_x, click_y, 0, 0);

        let events = grid.events.drain();
        assert!(events.iter().any(|e| matches!(
            &e.data,
            GridEventData::Click {
                row: 3,
                col: -1,
                target,
                ..
            } if target.kind == pb::GridTargetKind::GridTargetRowIndicator as i32
                && target.band == pb::IndicatorBand::RowStart as i32
                && target.slot_index == 1
                && target.slot_kind == pb::RowIndicatorSlotKind::RowIndicatorSlotCheckbox as i32
        )));
    }

    #[test]
    fn col_indicator_click_reports_target_cell() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 3, 0, 0);
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.col_top.cells = vec![ColIndicatorCellState {
            row1: 0,
            row2: 0,
            col1: 1,
            col2: 1,
            mode_bits: pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32,
            custom_key: "header-1".to_string(),
            ..Default::default()
        }];
        prime_layout(&mut grid);

        let click_x = grid.col_pos(1) as f32 + 10.0;
        let click_y = 10.0;
        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, false);
        handle_pointer_up(&mut grid, click_x, click_y, 0, 0);

        let events = grid.events.drain();
        assert!(events.iter().any(|e| matches!(
            &e.data,
            GridEventData::Click {
                row: -1,
                col: 1,
                target,
                ..
            } if target.kind == pb::GridTargetKind::GridTargetColIndicator as i32
                && target.band == pb::IndicatorBand::ColTop as i32
                && target.slot_index == 0
                && target.slot_kind == pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as i32
                && target.custom_key.as_str() == "header-1"
        )));
    }

    #[test]
    fn corner_indicator_click_reports_target_slot() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 3, 0, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 40;
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.corner_top_start.visible = true;
        grid.indicator_bands.corner_top_start.slots = vec![CornerIndicatorSlotState::new(
            pb::CornerIndicatorSlotKind::CornerSlotSelectAll,
            40,
        )];
        prime_layout(&mut grid);

        handle_pointer_down(&mut grid, 10.0, 10.0, 0, 0, false);
        handle_pointer_up(&mut grid, 10.0, 10.0, 0, 0);

        let events = grid.events.drain();
        assert!(events.iter().any(|e| matches!(
            &e.data,
            GridEventData::Click {
                row: -1,
                col: -1,
                target,
                ..
            } if target.kind == pb::GridTargetKind::GridTargetCornerIndicator as i32
                && target.band == pb::IndicatorBand::CornerTopStart as i32
                && target.slot_index == 0
                && target.slot_kind == pb::CornerIndicatorSlotKind::CornerSlotSelectAll as i32
        )));
    }

    #[test]
    fn pointer_move_emits_enter_leave_for_indicator_targets() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 6, 3, 0, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 60;
        grid.indicator_bands.row_start.slots = vec![
            RowIndicatorSlotState::new(pb::RowIndicatorSlotKind::RowIndicatorSlotNumbers, 20),
            RowIndicatorSlotState::new(pb::RowIndicatorSlotKind::RowIndicatorSlotCheckbox, 20),
            RowIndicatorSlotState::new(pb::RowIndicatorSlotKind::RowIndicatorSlotHandle, 20),
        ];
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        prime_layout(&mut grid);

        let y = 24.0 + grid.row_pos(2) as f32 + 10.0;
        handle_pointer_move(&mut grid, 30.0, y, 0, 0);
        handle_pointer_move(&mut grid, 50.0, y, 0, 0);

        let events = grid.events.drain();
        assert!(events.iter().any(|e| matches!(
            &e.data,
            GridEventData::LeaveCell { target, .. }
                if target.kind == pb::GridTargetKind::GridTargetRowIndicator as i32
                    && target.slot_index == 1
        )));
        assert!(events.iter().any(|e| matches!(
            &e.data,
            GridEventData::EnterCell { target, .. }
                if target.kind == pb::GridTargetKind::GridTargetRowIndicator as i32
                    && target.slot_index == 2
        )));
    }

    #[test]
    fn pointer_move_does_not_emit_enter_leave_for_background() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 3, 0, 0);
        prime_layout(&mut grid);

        handle_pointer_move(&mut grid, 10.0, 10.0, 0, 0);
        let events = grid.events.drain();
        assert!(events.iter().any(|e| matches!(
            &e.data,
            GridEventData::EnterCell { row: 0, col: 0, target }
                if target.kind == pb::GridTargetKind::GridTargetDataCell as i32
        )));

        handle_pointer_move(&mut grid, 700.0, 10.0, 0, 0);
        let events = grid.events.drain();
        assert!(events.iter().any(|e| matches!(
            &e.data,
            GridEventData::LeaveCell { row: 0, col: 0, target }
                if target.kind == pb::GridTargetKind::GridTargetDataCell as i32
        )));
        assert!(events.iter().any(|e| matches!(
            &e.data,
            GridEventData::MouseMove { target, .. }
                if target.kind == pb::GridTargetKind::GridTargetBackground as i32
        )));
        assert!(!events.iter().any(|e| matches!(
            &e.data,
            GridEventData::EnterCell { target, .. }
                if target.kind == pb::GridTargetKind::GridTargetBackground as i32
        )));

        handle_pointer_move(&mut grid, 10.0, 10.0, 0, 0);
        let events = grid.events.drain();
        assert!(!events.iter().any(|e| matches!(
            &e.data,
            GridEventData::LeaveCell { target, .. }
                if target.kind == pb::GridTargetKind::GridTargetBackground as i32
        )));
        assert!(events.iter().any(|e| matches!(
            &e.data,
            GridEventData::EnterCell { row: 0, col: 0, target }
                if target.kind == pb::GridTargetKind::GridTargetDataCell as i32
        )));
    }

    #[test]
    fn pointer_move_coalesces_transient_enter_leave_before_drain() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 3, 0, 0);
        prime_layout(&mut grid);

        handle_pointer_move(&mut grid, 10.0, 10.0, 0, 0);
        handle_pointer_move(&mut grid, 700.0, 10.0, 0, 0);

        let events = grid.events.drain();
        assert_eq!(events.len(), 1);
        assert!(events.iter().any(|e| matches!(
            &e.data,
            GridEventData::MouseMove { target, .. }
                if target.kind == pb::GridTargetKind::GridTargetBackground as i32
        )));
        assert!(!events.iter().any(|e| matches!(
            &e.data,
            GridEventData::EnterCell { target, .. }
            | GridEventData::LeaveCell { target, .. }
                if target.kind == pb::GridTargetKind::GridTargetDataCell as i32
        )));
    }

    #[test]
    fn keyboard_indicator_focus_activates_without_moving_selection() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 6, 3, 1, 1);
        grid.indicator_focus_enabled = true;
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 40;
        grid.indicator_bands.row_start.slots = vec![
            RowIndicatorSlotState::new(pb::RowIndicatorSlotKind::RowIndicatorSlotNumbers, 20),
            RowIndicatorSlotState::new(pb::RowIndicatorSlotKind::RowIndicatorSlotCheckbox, 20),
        ];
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.corner_top_start.visible = true;
        grid.indicator_bands.corner_top_start.slots = vec![CornerIndicatorSlotState::new(
            pb::CornerIndicatorSlotKind::CornerSlotSelectAll,
            40,
        )];
        grid.selection
            .set_cursor(2, 1, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);
        prime_layout(&mut grid);

        handle_key_down(&mut grid, 117, 0);
        assert!(matches!(
            grid.active_indicator,
            Some(ActiveIndicatorTarget {
                band,
                row: 2,
                slot_index: 0,
                ..
            }) if band == pb::IndicatorBand::RowStart as i32
        ));
        handle_key_down(&mut grid, 39, 0);
        assert_eq!(grid.active_indicator.as_ref().unwrap().slot_index, 1);
        handle_key_down(&mut grid, 13, 0);

        let events = grid.events.drain();
        assert!(events.iter().any(|e| matches!(
            &e.data,
            GridEventData::Click {
                row: 2,
                col: -1,
                target,
                ..
            } if target.kind == pb::GridTargetKind::GridTargetRowIndicator as i32
                && target.slot_index == 1
                && target.slot_kind == pb::RowIndicatorSlotKind::RowIndicatorSlotCheckbox as i32
        )));

        handle_key_down(&mut grid, 27, 0);
        assert!(grid.active_indicator.is_none());
        assert_eq!(grid.selection.row, 2);
        assert_eq!(grid.selection.col, 1);
    }

    #[test]
    fn active_indicator_preserves_selection_clamping() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 6, 3, 1, 1);
        grid.indicator_focus_enabled = true;
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.slots = vec![RowIndicatorSlotState::new(
            pb::RowIndicatorSlotKind::RowIndicatorSlotNumbers,
            40,
        )];
        grid.selection
            .set_cursor(1, 1, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);
        grid.active_indicator = Some(ActiveIndicatorTarget {
            band: pb::IndicatorBand::RowStart as i32,
            row: 0,
            col: -1,
            slot_index: 0,
        });

        handle_key_down(&mut grid, 38, 0);
        handle_key_down(&mut grid, 37, 0);

        assert!(grid.selection.row >= grid.fixed_rows);
        assert!(grid.selection.col >= grid.fixed_cols);
        assert_eq!(grid.selection.row, 1);
        assert_eq!(grid.selection.col, 1);
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
    fn tab_moves_selection_horizontally_by_default() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 4, 1, 0);
        grid.selection
            .set_cursor(2, 1, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);
        prime_layout(&mut grid);

        assert_eq!(grid.tab_behavior, pb::TabBehavior::TabCells as i32);

        handle_key_down(&mut grid, 9, 0);
        assert_eq!(grid.selection.row, 2);
        assert_eq!(grid.selection.col, 2);

        handle_key_down(&mut grid, 9, 1);
        assert_eq!(grid.selection.row, 2);
        assert_eq!(grid.selection.col, 1);
    }

    #[test]
    fn dropdown_keyboard_commit_does_not_shrink_row_height() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.columns[0].dropdown_items = "Very long display item|x".to_string();
        grid.set_row_height(1, 52);
        grid.selection.row = 1;
        grid.selection.col = 0;
        prime_layout(&mut grid);

        begin_edit_from_input(&mut grid, 1, 0);
        assert!(grid.is_editing());
        assert_eq!(grid.get_row_height(1), 52);

        handle_key_down(&mut grid, 40, 0);
        assert_eq!(grid.edit.dropdown_index, 0);
        assert_eq!(grid.edit.edit_text, "Very long display item");

        handle_key_down(&mut grid, 13, 0);
        assert!(!grid.is_editing());
        assert_eq!(grid.cells.get_text(1, 0), "Very long display item");
        assert_eq!(grid.get_row_height(1), 52);
    }

    #[test]
    fn f2_starts_edit_with_caret_at_end_without_selection() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.selection.row = 1;
        grid.selection.col = 0;
        grid.cells.set_text(1, 0, "hello".to_string());
        prime_layout(&mut grid);

        handle_key_down(&mut grid, 113, 0);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.ui_mode, crate::edit::EditUiMode::EditMode);
        assert_eq!(grid.edit.edit_text, "hello");
        assert_eq!(grid.edit.sel_start, 5);
        assert_eq!(grid.edit.sel_length, 0);
    }

    #[test]
    fn double_click_starts_edit_mode_at_clicked_caret_position() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 2;
        grid.selection.row = 1;
        grid.selection.col = 0;
        grid.cells.set_text(1, 0, "abcd".to_string());
        prime_layout(&mut grid);

        let style_override = grid.get_cell_style(1, 0);
        let padding = grid.resolve_cell_padding(1, 0, &style_override);
        let font_name = style_override
            .font_name
            .clone()
            .unwrap_or_else(|| grid.style.font_name.clone());
        let font_size = style_override.font_size.unwrap_or(grid.style.font_size);
        let font_bold = style_override.font_bold.unwrap_or(grid.style.font_bold);
        let font_italic = style_override.font_italic.unwrap_or(grid.style.font_italic);
        let te = grid.ensure_text_engine();
        let mut measure = |sample: &str| -> f32 {
            if te.has_fonts() {
                te.measure_text(sample, &font_name, font_size, font_bold, font_italic, None)
                    .0
            } else {
                sample.chars().count() as f32 * font_size * 0.6
            }
        };
        let ab_w = measure("ab");
        let (cx, cy, _, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let click_x = cx as f32 + padding.left as f32 + ab_w;
        let click_y = cy as f32 + (ch as f32 * 0.5);

        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, true);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.ui_mode, crate::edit::EditUiMode::EditMode);
        assert_eq!(grid.edit.sel_start, 2);
        assert_eq!(grid.edit.sel_length, 0);
    }

    #[test]
    fn single_click_in_active_edit_cell_moves_caret_without_ending_edit() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.selection.row = 1;
        grid.selection.col = 0;
        grid.cells.set_text(1, 0, "abcd".to_string());
        prime_layout(&mut grid);

        handle_key_down(&mut grid, 113, 0);
        assert!(grid.is_editing());
        assert_eq!(grid.edit.sel_start, 4);
        assert_eq!(grid.edit.sel_length, 0);

        let style_override = grid.get_cell_style(1, 0);
        let padding = grid.resolve_cell_padding(1, 0, &style_override);
        let font_name = style_override
            .font_name
            .clone()
            .unwrap_or_else(|| grid.style.font_name.clone());
        let font_size = style_override.font_size.unwrap_or(grid.style.font_size);
        let font_bold = style_override.font_bold.unwrap_or(grid.style.font_bold);
        let font_italic = style_override.font_italic.unwrap_or(grid.style.font_italic);
        let te = grid.ensure_text_engine();
        let mut measure = |sample: &str| -> f32 {
            if te.has_fonts() {
                te.measure_text(sample, &font_name, font_size, font_bold, font_italic, None)
                    .0
            } else {
                sample.chars().count() as f32 * font_size * 0.6
            }
        };
        let ab_w = measure("ab");
        let (cx, cy, _, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let click_x = cx as f32 + padding.left as f32 + ab_w;
        let click_y = cy as f32 + (ch as f32 * 0.5);

        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, false);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.edit_row, 1);
        assert_eq!(grid.edit.edit_col, 0);
        assert_eq!(grid.edit.sel_start, 2);
        assert_eq!(grid.edit.sel_length, 0);
        assert_eq!(grid.cells.get_text(1, 0), "abcd");
    }

    #[test]
    fn drag_in_active_edit_cell_selects_text_without_grid_selection() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.selection.row = 1;
        grid.selection.col = 0;
        grid.cells.set_text(1, 0, "abcd".to_string());
        prime_layout(&mut grid);

        handle_key_down(&mut grid, 113, 0);
        assert!(grid.is_editing());

        let style_override = grid.get_cell_style(1, 0);
        let padding = grid.resolve_cell_padding(1, 0, &style_override);
        let font_name = style_override
            .font_name
            .clone()
            .unwrap_or_else(|| grid.style.font_name.clone());
        let font_size = style_override.font_size.unwrap_or(grid.style.font_size);
        let font_bold = style_override.font_bold.unwrap_or(grid.style.font_bold);
        let font_italic = style_override.font_italic.unwrap_or(grid.style.font_italic);
        let te = grid.ensure_text_engine();
        let mut measure = |sample: &str| -> f32 {
            if te.has_fonts() {
                te.measure_text(sample, &font_name, font_size, font_bold, font_italic, None)
                    .0
            } else {
                sample.chars().count() as f32 * font_size * 0.6
            }
        };
        let a_w = measure("a");
        let abc_w = measure("abc");
        let (cx, cy, _, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let down_x = cx as f32 + padding.left as f32 + a_w;
        let move_x = cx as f32 + padding.left as f32 + abc_w;
        let pointer_y = cy as f32 + (ch as f32 * 0.5);

        handle_pointer_down(&mut grid, down_x, pointer_y, 0, 0, false);
        handle_pointer_move(&mut grid, move_x, pointer_y, 1, 0);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.sel_start, 1);
        assert_eq!(grid.edit.sel_length, 2);
        assert_eq!(grid.selection.row, 1);
        assert_eq!(grid.selection.col, 0);
        assert_eq!(grid.selection.row_end, 1);
        assert_eq!(grid.selection.col_end, 0);
    }

    #[test]
    fn drag_from_active_edit_cell_past_cell_bounds_clamps_text_selection() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.selection.row = 1;
        grid.selection.col = 0;
        grid.cells.set_text(1, 0, "abcd".to_string());
        prime_layout(&mut grid);

        handle_key_down(&mut grid, 113, 0);
        assert!(grid.is_editing());

        let style_override = grid.get_cell_style(1, 0);
        let padding = grid.resolve_cell_padding(1, 0, &style_override);
        let font_name = style_override
            .font_name
            .clone()
            .unwrap_or_else(|| grid.style.font_name.clone());
        let font_size = style_override.font_size.unwrap_or(grid.style.font_size);
        let font_bold = style_override.font_bold.unwrap_or(grid.style.font_bold);
        let font_italic = style_override.font_italic.unwrap_or(grid.style.font_italic);
        let te = grid.ensure_text_engine();
        let mut measure = |sample: &str| -> f32 {
            if te.has_fonts() {
                te.measure_text(sample, &font_name, font_size, font_bold, font_italic, None)
                    .0
            } else {
                sample.chars().count() as f32 * font_size * 0.6
            }
        };
        let a_w = measure("a");
        let (cx, cy, _, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let down_x = cx as f32 + padding.left as f32 + a_w;
        let pointer_y = cy as f32 + (ch as f32 * 0.5);
        let (other_x, _, _, _) = grid.cell_screen_rect(1, 1).expect("other cell rect");

        handle_pointer_down(&mut grid, down_x, pointer_y, 0, 0, false);
        handle_pointer_move(&mut grid, (other_x + 12) as f32, pointer_y, 1, 0);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.sel_start, 1);
        assert_eq!(grid.edit.sel_length, 3);
        assert_eq!(grid.selection.row, 1);
        assert_eq!(grid.selection.col, 0);
        assert_eq!(grid.selection.row_end, 1);
        assert_eq!(grid.selection.col_end, 0);
    }

    #[test]
    fn double_click_drag_enters_edit_and_selects_text() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 2;
        grid.selection.row = 1;
        grid.selection.col = 0;
        grid.cells.set_text(1, 0, "abcd".to_string());
        prime_layout(&mut grid);

        let style_override = grid.get_cell_style(1, 0);
        let padding = grid.resolve_cell_padding(1, 0, &style_override);
        let font_name = style_override
            .font_name
            .clone()
            .unwrap_or_else(|| grid.style.font_name.clone());
        let font_size = style_override.font_size.unwrap_or(grid.style.font_size);
        let font_bold = style_override.font_bold.unwrap_or(grid.style.font_bold);
        let font_italic = style_override.font_italic.unwrap_or(grid.style.font_italic);
        let te = grid.ensure_text_engine();
        let mut measure = |sample: &str| -> f32 {
            if te.has_fonts() {
                te.measure_text(sample, &font_name, font_size, font_bold, font_italic, None)
                    .0
            } else {
                sample.chars().count() as f32 * font_size * 0.6
            }
        };
        let a_w = measure("a");
        let abc_w = measure("abc");
        let (cx, cy, _, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let down_x = cx as f32 + padding.left as f32 + a_w;
        let move_x = cx as f32 + padding.left as f32 + abc_w;
        let pointer_y = cy as f32 + (ch as f32 * 0.5);

        handle_pointer_down(&mut grid, down_x, pointer_y, 0, 0, true);
        handle_pointer_move(&mut grid, move_x, pointer_y, 1, 0);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.ui_mode, crate::edit::EditUiMode::EditMode);
        assert_eq!(grid.edit.sel_start, 1);
        assert_eq!(grid.edit.sel_length, 2);
        assert_eq!(grid.selection.row, 1);
        assert_eq!(grid.selection.col, 0);
        assert_eq!(grid.selection.row_end, 1);
        assert_eq!(grid.selection.col_end, 0);
    }

    #[test]
    fn click_event_reports_row_col_text_hit_area_and_interaction() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.columns[0].interaction = pb::CellInteraction::TextLink as i32;
        grid.cells.set_text(1, 0, "hello".to_string());
        prime_layout(&mut grid);

        let style_override = grid.get_cell_style(1, 0);
        let padding = grid.resolve_cell_padding(1, 0, &style_override);
        let (cx, cy, _, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let click_x = cx as f32 + padding.left as f32 + 1.0;
        let click_y = cy as f32 + ch as f32 * 0.5;

        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, false);
        handle_pointer_up(&mut grid, click_x, click_y, 0, 0);

        let events = grid.events.drain();
        assert!(events.iter().any(|e| matches!(
            e.data,
            GridEventData::Click {
                row: 1,
                col: 0,
                hit_area,
                interaction,
                ..
            } if hit_area == pb::CellHitArea::HitText as i32
                && interaction == pb::CellInteraction::TextLink as i32
        )));
    }

    #[test]
    fn text_link_uses_pointer_cursor_on_hover() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.columns[0].interaction = pb::CellInteraction::TextLink as i32;
        grid.cells.set_text(1, 0, "open".to_string());
        prime_layout(&mut grid);

        let style_override = grid.get_cell_style(1, 0);
        let padding = grid.resolve_cell_padding(1, 0, &style_override);
        let (cx, cy, _, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let hover_x = cx as f32 + padding.left as f32 + 1.0;
        let hover_y = cy as f32 + ch as f32 * 0.5;

        handle_pointer_move(&mut grid, hover_x, hover_y, 0, 0);

        assert_eq!(grid.cursor_style, 5);
    }

    #[test]
    fn center_aligned_text_link_uses_pointer_cursor_on_hover() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.columns[0].interaction = pb::CellInteraction::TextLink as i32;
        grid.columns[0].alignment = pb::Align::CenterCenter as i32;
        grid.cells.set_text(1, 0, "Browse".to_string());
        prime_layout(&mut grid);

        let (cx, cy, cw, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let (tx, ty, tw, th) =
            text_content_rect(&mut grid, 1, 0, cx, cy, cw, ch).expect("text rect");
        let hover_x = tx as f32 + tw as f32 * 0.5;
        let hover_y = ty as f32 + th as f32 * 0.5;

        handle_pointer_move(&mut grid, hover_x, hover_y, 0, 0);

        assert_eq!(grid.cursor_style, 5);
    }

    #[test]
    fn center_aligned_text_link_click_reports_text_hit() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.columns[0].interaction = pb::CellInteraction::TextLink as i32;
        grid.columns[0].alignment = pb::Align::CenterCenter as i32;
        grid.cells.set_text(1, 0, "Open".to_string());
        prime_layout(&mut grid);

        let (cx, cy, cw, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let (tx, ty, tw, th) =
            text_content_rect(&mut grid, 1, 0, cx, cy, cw, ch).expect("text rect");
        let click_x = tx as f32 + tw as f32 * 0.5;
        let click_y = ty as f32 + th as f32 * 0.5;

        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, false);
        handle_pointer_up(&mut grid, click_x, click_y, 0, 0);

        let events = grid.events.drain();
        assert!(events.iter().any(|e| matches!(
            e.data,
            GridEventData::Click {
                row: 1,
                col: 0,
                hit_area,
                interaction,
                ..
            } if hit_area == pb::CellHitArea::HitText as i32
                && interaction == pb::CellInteraction::TextLink as i32
        )));
    }

    #[test]
    fn center_aligned_text_link_hit_test_respects_top_indicator_offset() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.columns[0].interaction = pb::CellInteraction::TextLink as i32;
        grid.columns[0].alignment = pb::Align::CenterCenter as i32;
        grid.cells.set_text(1, 0, "Browse".to_string());
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 28;
        prime_layout(&mut grid);

        let (cx, cy, cw, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let (tx, ty, tw, th) =
            text_content_rect(&mut grid, 1, 0, cx, cy, cw, ch).expect("text rect");
        let hover_x = tx as f32 + tw as f32 * 0.5;
        let hover_y = ty as f32 + th as f32 * 0.5;

        assert_eq!(
            hit_test(&mut grid, hover_x, hover_y).area,
            HitArea::CellText
        );

        handle_pointer_move(&mut grid, hover_x, hover_y, 0, 0);
        assert_eq!(grid.cursor_style, 5);
    }

    #[test]
    fn legacy_button_uses_dropdown_button_without_starting_edit() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.columns[0].control = CellControl::EllipsisButton;
        grid.columns[0].interaction = pb::CellInteraction::Button as i32;
        grid.edit_trigger_mode = 1;
        grid.dropdown_trigger = 3;
        grid.selection
            .set_cursor(1, 0, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);
        grid.selection.set_extent(1, 0, grid.rows, grid.cols);
        prime_layout(&mut grid);

        let (cx, cy, cw, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let (bx, by, bw, bh) =
            crate::canvas::dropdown_button_rect(cx, cy, cw, ch).expect("button rect");
        let click_x = bx as f32 + bw as f32 * 0.5;
        let click_y = by as f32 + bh as f32 * 0.5;

        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, false);
        assert!(!grid.is_editing());

        handle_pointer_up(&mut grid, click_x, click_y, 0, 0);

        let events = grid.events.drain();
        assert!(events.iter().any(|e| matches!(
            e.data,
            GridEventData::Click {
                row: 1,
                col: 0,
                hit_area,
                interaction,
                ..
            } if hit_area == pb::CellHitArea::HitDropdown as i32
                && interaction == pb::CellInteraction::Button as i32
        )));
    }

    #[test]
    fn double_click_emits_row_and_col() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.cells.set_text(1, 0, "hello".to_string());
        prime_layout(&mut grid);

        let (cx, cy, cw, ch) = grid.cell_screen_rect(1, 0).expect("cell rect");
        let click_x = cx as f32 + cw as f32 * 0.5;
        let click_y = cy as f32 + ch as f32 * 0.5;

        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, true);

        let events = grid.events.drain();
        assert!(events
            .iter()
            .any(|e| matches!(e.data, GridEventData::DblClick { row: 1, col: 0, .. })));
    }

    #[test]
    fn double_click_on_checkbox_does_not_enter_text_edit() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.edit_trigger_mode = 2;
        grid.columns[0].data_type = pb::ColumnDataType::ColumnDataBoolean as i32;
        grid.columns[0].alignment = pb::Align::CenterCenter as i32;
        grid.cells.set_text(1, 0, "No".to_string());
        {
            let cell = grid.cells.get_mut(1, 0);
            let extra = cell.extra_mut();
            extra.value = crate::cell::CellValueData::Bool(false);
            extra.checked = pb::CheckedState::CheckedUnchecked as i32;
        }
        prime_layout(&mut grid);

        let (bx, by, bw, bh) = checkbox_rect(&grid, 1, 0).expect("checkbox rect");
        let click_x = bx as f32 + bw as f32 * 0.5;
        let click_y = by as f32 + bh as f32 * 0.5;

        assert_eq!(
            hit_test(&mut grid, click_x, click_y).area,
            HitArea::CheckBox
        );

        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, false);
        assert!(!grid.is_editing());
        assert_eq!(
            grid.cells.get(1, 0).map(|cell| cell.checked()),
            Some(pb::CheckedState::CheckedChecked as i32)
        );
        assert_eq!(grid.cells.get_text(1, 0), "Yes");

        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, true);
        assert!(!grid.is_editing());
        assert_eq!(
            grid.cells.get(1, 0).map(|cell| cell.checked()),
            Some(pb::CheckedState::CheckedChecked as i32)
        );

        let events = grid.events.drain();
        assert!(!events.iter().any(|e| matches!(
            e.data,
            GridEventData::BeforeEdit { .. } | GridEventData::StartEdit { .. }
        )));
    }

    #[test]
    fn space_toggles_checkbox_without_entering_text_edit() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.columns[0].data_type = pb::ColumnDataType::ColumnDataBoolean as i32;
        grid.columns[0].alignment = pb::Align::CenterCenter as i32;
        grid.cells.set_text(1, 0, "No".to_string());
        {
            let cell = grid.cells.get_mut(1, 0);
            let extra = cell.extra_mut();
            extra.value = crate::cell::CellValueData::Bool(false);
            extra.checked = pb::CheckedState::CheckedUnchecked as i32;
        }
        prime_layout(&mut grid);
        grid.selection.row = 1;
        grid.selection.col = 0;

        handle_key_down(&mut grid, 32, 0);
        handle_key_press(&mut grid, ' ' as u32);

        assert!(!grid.is_editing());
        assert_eq!(grid.cells.get_text(1, 0), "Yes");
        assert_eq!(
            grid.cells.get(1, 0).map(|cell| cell.checked()),
            Some(pb::CheckedState::CheckedChecked as i32)
        );
    }

    #[test]
    fn enter_toggles_checkbox_without_entering_text_edit() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.columns[0].data_type = pb::ColumnDataType::ColumnDataBoolean as i32;
        grid.columns[0].alignment = pb::Align::CenterCenter as i32;
        grid.cells.set_text(1, 0, "No".to_string());
        {
            let cell = grid.cells.get_mut(1, 0);
            let extra = cell.extra_mut();
            extra.value = crate::cell::CellValueData::Bool(false);
            extra.checked = pb::CheckedState::CheckedUnchecked as i32;
        }
        prime_layout(&mut grid);
        grid.selection.row = 1;
        grid.selection.col = 0;

        handle_key_down(&mut grid, 13, 0);

        assert!(!grid.is_editing());
        assert_eq!(grid.cells.get_text(1, 0), "Yes");
        assert_eq!(
            grid.cells.get(1, 0).map(|cell| cell.checked()),
            Some(pb::CheckedState::CheckedChecked as i32)
        );
    }

    #[test]
    fn click_on_readonly_checkbox_does_not_toggle() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.edit_trigger_mode = 0;
        grid.columns[0].data_type = pb::ColumnDataType::ColumnDataBoolean as i32;
        grid.columns[0].alignment = pb::Align::CenterCenter as i32;
        grid.cells.set_text(1, 0, "No".to_string());
        {
            let cell = grid.cells.get_mut(1, 0);
            let extra = cell.extra_mut();
            extra.value = crate::cell::CellValueData::Bool(false);
            extra.checked = pb::CheckedState::CheckedUnchecked as i32;
        }
        prime_layout(&mut grid);

        let (bx, by, bw, bh) = checkbox_rect(&grid, 1, 0).expect("checkbox rect");
        let click_x = bx as f32 + bw as f32 * 0.5;
        let click_y = by as f32 + bh as f32 * 0.5;

        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, false);

        assert!(!grid.is_editing());
        assert_eq!(grid.cells.get_text(1, 0), "No");
        assert_eq!(
            grid.cells.get(1, 0).map(|cell| cell.checked()),
            Some(pb::CheckedState::CheckedUnchecked as i32)
        );
    }

    #[test]
    fn space_on_readonly_checkbox_does_not_toggle() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.edit_trigger_mode = 0;
        grid.columns[0].data_type = pb::ColumnDataType::ColumnDataBoolean as i32;
        grid.columns[0].alignment = pb::Align::CenterCenter as i32;
        grid.cells.set_text(1, 0, "No".to_string());
        {
            let cell = grid.cells.get_mut(1, 0);
            let extra = cell.extra_mut();
            extra.value = crate::cell::CellValueData::Bool(false);
            extra.checked = pb::CheckedState::CheckedUnchecked as i32;
        }
        prime_layout(&mut grid);
        grid.selection.row = 1;
        grid.selection.col = 0;

        handle_key_down(&mut grid, 32, 0);
        handle_key_press(&mut grid, 32);

        assert!(!grid.is_editing());
        assert_eq!(grid.cells.get_text(1, 0), "No");
        assert_eq!(
            grid.cells.get(1, 0).map(|cell| cell.checked()),
            Some(pb::CheckedState::CheckedUnchecked as i32)
        );
    }

    #[test]
    fn enter_on_readonly_checkbox_does_not_toggle() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.edit_trigger_mode = 0;
        grid.columns[0].data_type = pb::ColumnDataType::ColumnDataBoolean as i32;
        grid.columns[0].alignment = pb::Align::CenterCenter as i32;
        grid.cells.set_text(1, 0, "No".to_string());
        {
            let cell = grid.cells.get_mut(1, 0);
            let extra = cell.extra_mut();
            extra.value = crate::cell::CellValueData::Bool(false);
            extra.checked = pb::CheckedState::CheckedUnchecked as i32;
        }
        prime_layout(&mut grid);
        grid.selection.row = 1;
        grid.selection.col = 0;

        handle_key_down(&mut grid, 13, 0);

        assert!(!grid.is_editing());
        assert_eq!(grid.cells.get_text(1, 0), "No");
        assert_eq!(
            grid.cells.get(1, 0).map(|cell| cell.checked()),
            Some(pb::CheckedState::CheckedUnchecked as i32)
        );
    }

    #[test]
    fn f2_does_not_enter_text_edit_for_checkbox() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.columns[0].data_type = pb::ColumnDataType::ColumnDataBoolean as i32;
        grid.columns[0].alignment = pb::Align::CenterCenter as i32;
        grid.cells.set_text(1, 0, "No".to_string());
        {
            let cell = grid.cells.get_mut(1, 0);
            let extra = cell.extra_mut();
            extra.value = crate::cell::CellValueData::Bool(false);
            extra.checked = pb::CheckedState::CheckedUnchecked as i32;
        }
        prime_layout(&mut grid);
        grid.selection.row = 1;
        grid.selection.col = 0;

        handle_key_down(&mut grid, 113, 0);

        assert!(!grid.is_editing());
        assert_eq!(grid.cells.get_text(1, 0), "No");
        assert_eq!(
            grid.cells.get(1, 0).map(|cell| cell.checked()),
            Some(pb::CheckedState::CheckedUnchecked as i32)
        );
    }

    #[test]
    fn type_to_replace_arrow_down_commits_and_moves_selection() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.selection.row = 1;
        grid.selection.col = 0;
        grid.cells.set_text(1, 0, "hello".to_string());
        prime_layout(&mut grid);

        handle_key_press(&mut grid, 'A' as u32);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.ui_mode, crate::edit::EditUiMode::EnterMode);
        assert_eq!(grid.edit.edit_text, "A");
        assert_eq!(grid.edit.sel_start, 1);
        assert_eq!(grid.selection.row, 1);

        handle_key_down(&mut grid, 40, 0);

        assert!(!grid.is_editing());
        assert_eq!(grid.cells.get_text(1, 0), "A");
        assert_eq!(grid.selection.row, 2);
        assert_eq!(grid.selection.col, 0);
    }

    #[test]
    fn f2_edit_mode_arrow_keys_move_caret_without_committing() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.selection.row = 1;
        grid.selection.col = 0;
        grid.cells.set_text(1, 0, "hello".to_string());
        prime_layout(&mut grid);

        handle_key_down(&mut grid, 113, 0);
        assert!(grid.is_editing());
        assert_eq!(grid.edit.sel_start, 5);

        handle_key_down(&mut grid, 38, 0);
        assert!(grid.is_editing());
        assert_eq!(grid.edit.sel_start, 0);
        assert_eq!(grid.edit.sel_length, 0);
        assert_eq!(grid.cells.get_text(1, 0), "hello");
        assert_eq!(grid.selection.row, 1);

        handle_key_down(&mut grid, 40, 0);
        assert!(grid.is_editing());
        assert_eq!(grid.edit.sel_start, 5);
        assert_eq!(grid.edit.sel_length, 0);
        assert_eq!(grid.cells.get_text(1, 0), "hello");
        assert_eq!(grid.selection.row, 1);
    }

    #[test]
    fn enter_on_dropdown_cell_starts_edit_and_marks_dirty() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.columns[0].dropdown_items = "A|B|C".to_string();
        grid.selection.row = 1;
        grid.selection.col = 0;
        prime_layout(&mut grid);
        grid.dirty = false;
        grid.events.drain();

        handle_key_down(&mut grid, 13, 0);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.dropdown_count(), 3);
        assert!(grid.dirty);
        let events = grid.events.drain();
        assert!(events
            .iter()
            .any(|evt| matches!(evt.data, GridEventData::DropdownOpened)));
        assert!(events
            .iter()
            .any(|evt| matches!(evt.data, GridEventData::StartEdit { row: 1, col: 0 })));
    }

    #[test]
    fn readonly_dropdown_ignores_freeform_text_edits_when_search_disabled() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.dropdown_search = false;
        grid.columns[0].dropdown_items = "Active|Pending|Shipped".to_string();
        grid.cells.set_text(1, 0, "Pending".to_string());
        prime_layout(&mut grid);

        begin_edit_from_input(&mut grid, 1, 0);
        assert!(grid.is_editing());
        assert_eq!(grid.edit.edit_text, "Pending");

        handle_key_press(&mut grid, 'X' as u32);
        handle_key_down(&mut grid, 8, 0);
        handle_key_down(&mut grid, 46, 0);

        assert_eq!(grid.edit.edit_text, "Pending");
        handle_key_down(&mut grid, 13, 0);
        assert_eq!(grid.cells.get_text(1, 0), "Pending");
    }

    #[test]
    fn readonly_dropdown_search_selects_matching_item_without_freeform_text() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.dropdown_search = true;
        grid.columns[0].dropdown_items = "Active|Pending|Shipped".to_string();
        grid.cells.set_text(1, 0, "Pending".to_string());
        prime_layout(&mut grid);

        begin_edit_from_input(&mut grid, 1, 0);
        assert!(grid.is_editing());

        handle_key_press(&mut grid, 'S' as u32);
        handle_key_press(&mut grid, 'h' as u32);
        assert_eq!(grid.edit.dropdown_index, 2);
        assert_eq!(grid.edit.edit_text, "Shipped");

        handle_key_press(&mut grid, 'x' as u32);
        assert_eq!(grid.edit.edit_text, "Shipped");

        handle_key_down(&mut grid, 13, 0);
        assert_eq!(grid.cells.get_text(1, 0), "Shipped");
    }

    #[test]
    fn typed_dropdown_searchable_true_overrides_global_disabled() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.dropdown_search = false;
        grid.columns[0].dropdown = Some(typed_dropdown(
            &["Active", "Pending", "Shipped"],
            Some(true),
        ));
        grid.cells.set_text(1, 0, "Pending".to_string());
        prime_layout(&mut grid);

        begin_edit_from_input(&mut grid, 1, 0);
        assert!(grid.is_editing());

        handle_key_press(&mut grid, 'S' as u32);
        assert_eq!(grid.edit.dropdown_index, 2);
        assert_eq!(grid.edit.edit_text, "Shipped");
    }

    #[test]
    fn typed_dropdown_searchable_false_overrides_global_enabled() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.dropdown_search = true;
        grid.columns[0].dropdown = Some(typed_dropdown(
            &["Active", "Pending", "Shipped"],
            Some(false),
        ));
        grid.cells.set_text(1, 0, "Pending".to_string());
        prime_layout(&mut grid);

        begin_edit_from_input(&mut grid, 1, 0);
        assert!(grid.is_editing());

        handle_key_press(&mut grid, 'S' as u32);
        assert_eq!(grid.edit.dropdown_index, 1);
        assert_eq!(grid.edit.edit_text, "Pending");
    }

    #[test]
    fn readonly_dropdown_keypress_does_not_begin_freeform_edit_when_search_disabled() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.dropdown_search = false;
        grid.columns[0].dropdown_items = "Active|Pending|Shipped".to_string();
        grid.cells.set_text(1, 0, "Pending".to_string());
        prime_layout(&mut grid);
        grid.selection
            .set_cursor(1, 0, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);
        grid.selection
            .set_extent(grid.selection.row, grid.selection.col, grid.rows, grid.cols);

        handle_key_press(&mut grid, 'X' as u32);

        assert!(!grid.is_editing());
        assert_eq!(grid.cells.get_text(1, 0), "Pending");
        assert_eq!(grid.edit.edit_text, "");
    }

    #[test]
    fn readonly_dropdown_keypress_uses_type_ahead_without_freeform_text() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.dropdown_search = true;
        grid.columns[0].dropdown_items = "Active|Pending|Shipped".to_string();
        grid.cells.set_text(1, 0, "Pending".to_string());
        prime_layout(&mut grid);
        grid.selection
            .set_cursor(1, 0, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);
        grid.selection
            .set_extent(grid.selection.row, grid.selection.col, grid.rows, grid.cols);

        handle_key_press(&mut grid, 'S' as u32);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.dropdown_index, 2);
        assert_eq!(grid.edit.edit_text, "Shipped");
        assert_eq!(grid.cells.get_text(1, 0), "Pending");
    }

    #[test]
    fn dropdown_keyboard_preview_is_canceled_on_click_away() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.columns[0].dropdown_items = "A|B|C".to_string();
        grid.cells.set_text(1, 0, "A".to_string());
        prime_layout(&mut grid);

        begin_edit_from_input(&mut grid, 1, 0);
        assert!(grid.is_editing());
        assert_eq!(grid.edit.edit_text, "A");

        handle_key_down(&mut grid, 40, 0);
        assert_eq!(grid.edit.dropdown_index, 1);
        assert_eq!(grid.edit.edit_text, "B");

        let click_x = (grid.col_pos(1) + 4) as f32;
        let click_y = (grid.row_pos(1) + 4) as f32;
        handle_pointer_down(&mut grid, click_x, click_y, 0, 0, false);

        assert!(!grid.is_editing());
        assert_eq!(grid.cells.get_text(1, 0), "A");
        assert_eq!(grid.selection.row, 1);
        assert_eq!(grid.selection.col, 1);
    }

    #[test]
    fn dropdown_keyboard_preview_is_canceled_on_escape() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.columns[0].dropdown_items = "A|B|C".to_string();
        grid.cells.set_text(1, 0, "A".to_string());
        prime_layout(&mut grid);

        begin_edit_from_input(&mut grid, 1, 0);
        assert!(grid.is_editing());
        assert_eq!(grid.edit.edit_text, "A");

        handle_key_down(&mut grid, 40, 0);
        assert_eq!(grid.edit.dropdown_index, 1);
        assert_eq!(grid.edit.edit_text, "B");

        grid.events.drain();
        handle_key_down(&mut grid, 27, 0);

        assert!(!grid.is_editing());
        assert_eq!(grid.cells.get_text(1, 0), "A");

        let queued = grid.events.drain();
        assert!(queued
            .iter()
            .any(|evt| matches!(evt.data, GridEventData::DropdownClosed)));
        assert!(queued.iter().any(|evt| matches!(
            evt.data,
            GridEventData::AfterEdit {
                ref old_text,
                ref new_text,
                ..
            } if old_text == "A" && new_text == "A"
        )));
    }

    #[test]
    fn dropdown_item_click_does_not_start_selection_drag_on_followup_move() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.columns[0].dropdown_items = "A|B|C".to_string();
        grid.cells.set_text(1, 0, "A".to_string());
        prime_layout(&mut grid);

        begin_edit_from_input(&mut grid, 1, 0);
        assert!(grid.is_editing());

        let cell_rect = grid.cell_screen_rect(1, 0).expect("cell rect");
        let popup = crate::canvas::active_dropdown_popup_geometry(
            &grid,
            cell_rect,
            grid.viewport_width,
            grid.viewport_height,
        )
        .expect("dropdown popup");

        // Click the second dropdown item to commit "B".
        let popup_x = (popup.x + 8) as f32;
        let popup_y = (popup.y + popup.item_h + popup.item_h / 2) as f32;
        handle_pointer_down(&mut grid, popup_x, popup_y, 0, 0, false);

        assert_eq!(grid.cells.get_text(1, 0), "B");
        assert!(grid.dropdown_click_active);
        assert_eq!(grid.selection.row, 1);
        assert_eq!(grid.selection.col, 0);
        assert_eq!(grid.selection.row_end, 1);
        assert_eq!(grid.selection.col_end, 0);

        // A follow-up move in the same held click must not start extending the
        // underlying cell selection after the popup closes.
        let (other_x, other_y, _, _) = grid.cell_screen_rect(1, 1).expect("other cell rect");
        handle_pointer_move(&mut grid, (other_x + 8) as f32, (other_y + 8) as f32, 1, 0);
        assert_eq!(grid.selection.row, 1);
        assert_eq!(grid.selection.col, 0);
        assert_eq!(grid.selection.row_end, 1);
        assert_eq!(grid.selection.col_end, 0);

        handle_pointer_up(&mut grid, (other_x + 8) as f32, (other_y + 8) as f32, 0, 0);
        assert!(!grid.dropdown_click_active);
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
        assert_eq!(
            grid.cells.get_text(grid.selection.row, grid.selection.col),
            ""
        );

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
    fn editing_shift_arrow_selects_and_shrinks_text() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        prime_layout(&mut grid);

        handle_key_down(&mut grid, 13, 0);
        assert!(grid.is_editing());
        grid.edit.edit_text = "abcd".to_string();
        grid.edit.move_end();

        handle_key_down(&mut grid, 37, 1);
        assert_eq!(grid.edit.sel_start, 3);
        assert_eq!(grid.edit.sel_length, 1);

        handle_key_down(&mut grid, 37, 1);
        assert_eq!(grid.edit.sel_start, 2);
        assert_eq!(grid.edit.sel_length, 2);

        handle_key_down(&mut grid, 39, 1);
        assert_eq!(grid.edit.sel_start, 3);
        assert_eq!(grid.edit.sel_length, 1);

        handle_key_down(&mut grid, 39, 1);
        assert_eq!(grid.edit.sel_start, 4);
        assert_eq!(grid.edit.sel_length, 0);
    }

    #[test]
    fn editing_shift_down_selects_to_end_in_f2_mode() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        prime_layout(&mut grid);

        handle_key_down(&mut grid, 113, 0);
        assert!(grid.is_editing());
        grid.edit.edit_text = "abcdef".to_string();
        grid.edit.sel_start = 2;
        grid.edit.sel_length = 0;
        grid.edit.sel_caret = 2;

        handle_key_down(&mut grid, 40, 1);
        assert_eq!(grid.edit.sel_start, 2);
        assert_eq!(grid.edit.sel_length, 4);
    }

    #[test]
    fn editing_ctrl_arrow_jumps_by_word() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        prime_layout(&mut grid);

        handle_key_down(&mut grid, 13, 0);
        assert!(grid.is_editing());
        grid.edit.edit_text = "abc def ghi".to_string();
        grid.edit.move_home();

        handle_key_down(&mut grid, 39, 2);
        assert_eq!(grid.edit.sel_start, 4);
        assert_eq!(grid.edit.sel_length, 0);

        handle_key_down(&mut grid, 39, 2);
        assert_eq!(grid.edit.sel_start, 8);
        assert_eq!(grid.edit.sel_length, 0);

        handle_key_down(&mut grid, 37, 2);
        assert_eq!(grid.edit.sel_start, 4);
        assert_eq!(grid.edit.sel_length, 0);
    }

    #[test]
    fn editing_ctrl_shift_arrow_selects_by_word() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        prime_layout(&mut grid);

        handle_key_down(&mut grid, 13, 0);
        assert!(grid.is_editing());
        grid.edit.edit_text = "abc def ghi".to_string();
        grid.edit.move_end();

        handle_key_down(&mut grid, 37, 3);
        assert_eq!(grid.edit.sel_start, 8);
        assert_eq!(grid.edit.sel_length, 3);

        handle_key_down(&mut grid, 37, 3);
        assert_eq!(grid.edit.sel_start, 4);
        assert_eq!(grid.edit.sel_length, 7);

        handle_key_down(&mut grid, 39, 3);
        assert_eq!(grid.edit.sel_start, 8);
        assert_eq!(grid.edit.sel_length, 3);
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
    fn keypress_auto_start_uses_engine_compose_for_first_character() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.engine_compose = true;
        grid.engine_compose_configured = true;
        grid.compose_method = pb::ComposeMethod::Hangul as i32;
        grid.compose_method_configured = true;
        prime_layout(&mut grid);

        handle_key_press(&mut grid, 'r' as u32);
        assert!(grid.is_editing());
        assert_eq!(grid.edit.edit_text, "");
        assert_eq!(grid.edit.preedit_text, "ㄱ");
        assert!(grid.edit.composing);

        handle_key_press(&mut grid, 'k' as u32);
        assert_eq!(grid.edit.preedit_text, "가");
    }

    #[test]
    fn engine_compose_backspace_unwinds_preedit_before_edit_text() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.engine_compose = true;
        grid.engine_compose_configured = true;
        grid.compose_method = pb::ComposeMethod::Hangul as i32;
        grid.compose_method_configured = true;
        prime_layout(&mut grid);

        handle_key_press(&mut grid, 'r' as u32);
        handle_key_press(&mut grid, 'k' as u32);
        handle_key_press(&mut grid, 's' as u32);
        assert_eq!(grid.edit.preedit_text, "간");

        handle_key_down(&mut grid, 8, 0);
        assert_eq!(grid.edit.preedit_text, "가");
        assert_eq!(grid.edit.edit_text, "");
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
                ..InputBehavior::default()
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
                ..InputBehavior::default()
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

    #[test]
    fn fast_scroll_locks_to_top_when_dragging_above_track() {
        let mut grid = VolvoxGrid::new(1, 320, 180, 200, 4, 1, 0);
        grid.fast_scroll_enabled = true;
        prime_layout(&mut grid);

        update_fast_scroll_target(&mut grid, 90.0);
        assert!(grid.top_row() > grid.fixed_rows);

        let track_top = 12.0 * grid.scale.max(0.01);
        update_fast_scroll_target(&mut grid, track_top - 60.0);
        let locked_scroll_y = grid.scroll.scroll_y;

        assert_eq!(grid.fast_scroll_target_row, grid.fixed_rows);
        assert_eq!(grid.top_row(), grid.fixed_rows);
        assert_eq!(locked_scroll_y, 0.0);

        update_fast_scroll_target(&mut grid, track_top - 160.0);
        assert_eq!(grid.fast_scroll_target_row, grid.fixed_rows);
        assert_eq!(grid.top_row(), grid.fixed_rows);
        assert_eq!(grid.scroll.scroll_y, locked_scroll_y);
    }

    #[test]
    fn fast_scroll_locks_to_bottom_when_dragging_below_track() {
        let mut grid = VolvoxGrid::new(1, 320, 180, 200, 4, 1, 0);
        grid.fast_scroll_enabled = true;
        prime_layout(&mut grid);

        update_fast_scroll_target(&mut grid, 90.0);
        let track_bottom = (grid.viewport_height as f32 - 12.0 * grid.scale.max(0.01)).max(13.0);
        update_fast_scroll_target(&mut grid, track_bottom + 60.0);
        let locked_top_row = grid.top_row();
        let locked_scroll_y = grid.scroll.scroll_y;

        assert_eq!(grid.fast_scroll_target_row, grid.rows - 1);
        assert_eq!(grid.bottom_row(), grid.rows - 1);
        assert_eq!(grid.scroll.scroll_y, grid.scroll.max_scroll_y);

        update_fast_scroll_target(&mut grid, track_bottom + 160.0);
        assert_eq!(grid.fast_scroll_target_row, grid.rows - 1);
        assert_eq!(grid.bottom_row(), grid.rows - 1);
        assert_eq!(grid.top_row(), locked_top_row);
        assert_eq!(grid.scroll.scroll_y, locked_scroll_y);
    }

    #[test]
    fn overlay_scrollbar_geometry_does_not_shrink_viewport() {
        let mut grid = VolvoxGrid::new(1, 200, 120, 50, 12, 1, 1);
        prime_layout(&mut grid);
        grid.scrollbar_show_h =
            crate::proto::volvoxgrid::v1::ScrollBarMode::ScrollbarModeAlways as i32;
        grid.scrollbar_show_v =
            crate::proto::volvoxgrid::v1::ScrollBarMode::ScrollbarModeAlways as i32;
        grid.scrollbar_appearance =
            crate::proto::volvoxgrid::v1::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32;
        grid.scrollbar_size = 6;
        grid.scrollbar_margin = 2;

        let geom = scrollbar_geometry(&grid);

        assert!(geom.show_h);
        assert!(geom.show_v);
        assert_eq!(geom.view_w, grid.viewport_width);
        assert_eq!(geom.view_h, grid.viewport_height);
        assert_eq!(
            geom.h_bar_y,
            grid.viewport_height - grid.scrollbar_size - grid.scrollbar_margin
        );
    }

    #[test]
    fn overlay_scrollbar_hover_resets_fade() {
        let mut grid = VolvoxGrid::new(1, 200, 120, 50, 12, 1, 1);
        prime_layout(&mut grid);
        grid.scrollbar_show_h =
            crate::proto::volvoxgrid::v1::ScrollBarMode::ScrollbarModeAlways as i32;
        grid.scrollbar_show_v =
            crate::proto::volvoxgrid::v1::ScrollBarMode::ScrollbarModeAlways as i32;
        grid.scrollbar_appearance =
            crate::proto::volvoxgrid::v1::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32;
        grid.scrollbar_size = 6;
        grid.scrollbar_margin = 2;
        grid.scrollbar_fade_opacity = 0.0;
        grid.scrollbar_fade_timer = 0.0;

        let geom = scrollbar_geometry(&grid);
        handle_pointer_move(
            &mut grid,
            (geom.h_bar_x + 1) as f32,
            (geom.h_bar_y + 1) as f32,
            0,
            0,
        );

        assert!(grid.scrollbar_hover);
        assert_eq!(grid.scrollbar_fade_opacity, 1.0);
        assert!(grid.scrollbar_fade_timer > 0.0);
    }

    #[test]
    fn overlay_vertical_always_stays_hittable_when_horizontal_fades() {
        let mut grid = VolvoxGrid::new(1, 200, 120, 50, 12, 1, 1);
        prime_layout(&mut grid);
        grid.scrollbar_show_h =
            crate::proto::volvoxgrid::v1::ScrollBarMode::ScrollbarModeAuto as i32;
        grid.scrollbar_show_v =
            crate::proto::volvoxgrid::v1::ScrollBarMode::ScrollbarModeAlways as i32;
        grid.scrollbar_appearance =
            crate::proto::volvoxgrid::v1::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32;
        grid.scrollbar_size = 6;
        grid.scrollbar_margin = 2;
        grid.scrollbar_fade_opacity = 0.0;
        grid.scrollbar_fade_timer = 0.0;

        let geom = scrollbar_geometry(&grid);
        let vertical = hit_test(
            &mut grid,
            (geom.v_bar_x + 1) as f32,
            (geom.v_bar_y + 1) as f32,
        );
        let horizontal = hit_test(
            &mut grid,
            (geom.h_bar_x + 1) as f32,
            (geom.h_bar_y + 1) as f32,
        );

        assert!(matches!(vertical.area, HitArea::VScrollBar));
        assert!(!matches!(horizontal.area, HitArea::HScrollBar));
    }

    #[test]
    fn hover_row_mode_ignores_column_only_pointer_motion() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 100, 8, 1, 0);
        prime_layout(&mut grid);
        grid.selection.hover_mode = HOVER_ROW;

        let y = (grid.row_pos(1) + 2) as f32;
        let x1 = (grid.col_pos(1) + 2) as f32;
        let x2 = (grid.col_pos(4) + 2) as f32;

        handle_pointer_move(&mut grid, x1, y, 0, 0);
        assert!(grid.dirty);
        grid.clear_dirty();

        handle_pointer_move(&mut grid, x2, y, 0, 0);
        assert!(!grid.dirty);
    }

    #[test]
    fn hover_column_mode_ignores_row_only_pointer_motion() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 100, 8, 1, 0);
        prime_layout(&mut grid);
        grid.selection.hover_mode = HOVER_COLUMN;

        let x = (grid.col_pos(2) + 2) as f32;
        let y1 = (grid.row_pos(1) + 2) as f32;
        let y2 = (grid.row_pos(7) + 2) as f32;

        handle_pointer_move(&mut grid, x, y1, 0, 0);
        assert!(grid.dirty);
        grid.clear_dirty();

        handle_pointer_move(&mut grid, x, y2, 0, 0);
        assert!(!grid.dirty);
    }

    #[test]
    fn column_header_hover_does_not_assign_first_data_row() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 100, 8, 1, 0);
        prime_layout(&mut grid);
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.selection.hover_mode = HOVER_ROW | HOVER_COLUMN | HOVER_CELL;

        let x = (grid.col_pos(2) + grid.col_width(2) / 2) as f32;
        let y = 10.0;
        handle_pointer_move(&mut grid, x, y, 0, 0);

        assert_eq!(grid.mouse_row, -1);
        assert_eq!(grid.mouse_col, 2);
    }

    #[test]
    fn dropdown_list_hit_test_respects_top_indicator_offset() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 2, 1, 0);
        grid.edit_trigger_mode = 2;
        grid.columns[1].dropdown_items = "A|B|C".to_string();
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        prime_layout(&mut grid);

        grid.begin_edit(1, 1);
        assert!(grid.is_editing());

        let (cx, cy, _cw, ch) = grid.cell_screen_rect(1, 1).unwrap();
        let item_h = ch.max(18);
        let click_x = cx + 4;
        let click_y = cy + ch - 1 + item_h + item_h / 2;

        handle_pointer_down(&mut grid, click_x as f32, click_y as f32, 0, 0, false);

        assert_eq!(grid.cells.get_text(1, 1), "B");
        assert!(!grid.is_editing());
    }

    #[test]
    fn hover_none_pointer_move_does_not_dirty_grid() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 100, 8, 1, 0);
        prime_layout(&mut grid);
        grid.selection.hover_mode = HOVER_NONE;

        let x = (grid.col_pos(2) + 2) as f32;
        let y = (grid.row_pos(3) + 2) as f32;

        grid.clear_dirty();
        handle_pointer_move(&mut grid, x, y, 0, 0);
        assert!(!grid.dirty);
    }

    fn outline_indicator_test_grid() -> VolvoxGrid {
        let mut grid = VolvoxGrid::new(1, 240, 180, 4, 2, 1, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.auto_size = false;
        grid.indicator_bands.row_start.width_px = 80;
        grid.indicator_bands.row_start.slots = vec![RowIndicatorSlotState::new(
            pb::RowIndicatorSlotKind::RowIndicatorSlotExpander,
            80,
        )];
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.corner_top_start.visible = true;
        grid.indicator_bands.corner_top_start.slots = vec![CornerIndicatorSlotState::new(
            pb::CornerIndicatorSlotKind::CornerSlotOutlineLevels,
            80,
        )];
        grid.outline.tree_indicator = pb::TreeIndicatorStyle::TreeIndicatorArrowsLeaf as i32;
        grid.outline.max_levels = 3;
        grid.outline.show_level_buttons = true;
        grid.row_props.entry(1).or_default().outline_level = 1;
        grid.row_props.entry(2).or_default().outline_level = 2;
        grid.row_props.entry(3).or_default().outline_level = 3;
        prime_layout(&mut grid);
        grid
    }

    fn zero_based_outline_indicator_test_grid() -> VolvoxGrid {
        let mut grid = outline_indicator_test_grid();
        grid.set_rows(5);
        grid.outline.max_levels = 3;
        grid.row_props.entry(1).or_default().outline_level = 0;
        grid.row_props.entry(2).or_default().outline_level = 1;
        grid.row_props.entry(3).or_default().outline_level = 2;
        grid.row_props.entry(4).or_default().outline_level = 3;
        prime_layout(&mut grid);
        grid
    }

    fn visible_outline_levels(grid: &VolvoxGrid) -> Vec<i32> {
        (grid.fixed_rows..grid.rows)
            .filter(|row| !grid.is_row_hidden(*row))
            .filter_map(|row| grid.row_props.get(&row).map(|props| props.outline_level))
            .collect()
    }

    fn click_outline_level_button(grid: &mut VolvoxGrid, x: f32) {
        handle_pointer_down(grid, x, 5.0, 0, 0, false);
        handle_pointer_up(grid, x, 5.0, 0, 0);
    }

    #[test]
    fn row_indicator_expander_hit_toggles_outline_node() {
        let mut grid = outline_indicator_test_grid();
        let (_cx, row_y, _cw, row_h) = grid.cell_screen_rect(1, 0).unwrap();
        let hit = hit_test(&mut grid, 6.0, (row_y + row_h / 2) as f32);
        assert_eq!(hit.area, HitArea::OutlineButton);

        handle_pointer_down(&mut grid, 6.0, (row_y + row_h / 2) as f32, 0, 0, false);

        assert!(grid
            .row_props
            .get(&1)
            .is_some_and(|props| props.is_collapsed));
        assert!(grid.is_row_hidden(2));
        assert!(grid.is_row_hidden(3));
    }

    #[test]
    fn row_indicator_expander_double_click_toggles_outline_node() {
        let mut grid = outline_indicator_test_grid();
        let (_cx, row_y, _cw, row_h) = grid.cell_screen_rect(1, 0).unwrap();
        let y = (row_y + row_h / 2) as f32;

        handle_pointer_down(&mut grid, 6.0, y, 0, 0, true);

        assert!(grid
            .row_props
            .get(&1)
            .is_some_and(|props| props.is_collapsed));
        assert!(grid.is_row_hidden(2));
        assert!(grid.is_row_hidden(3));
    }

    #[test]
    fn selected_outline_row_enter_and_space_toggle_before_edit() {
        let mut grid = outline_indicator_test_grid();
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.edit_trigger_mode = 1;
        grid.outline.label_column = 0;
        grid.cols_hidden.insert(0);
        grid.selection
            .set_cursor(1, 0, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);

        handle_key_down(&mut grid, 13, 0);

        assert!(!grid.is_editing());
        assert!(grid
            .row_props
            .get(&1)
            .is_some_and(|props| props.is_collapsed));
        assert!(grid.is_row_hidden(2));

        handle_key_down(&mut grid, 32, 0);

        assert!(!grid.is_editing());
        assert!(grid
            .row_props
            .get(&1)
            .is_some_and(|props| !props.is_collapsed));
        assert!(!grid.is_row_hidden(2));

        grid.selection
            .set_cursor(3, 0, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);
        handle_key_down(&mut grid, 13, 0);

        assert!(!grid.is_editing());
    }

    #[test]
    fn f2_on_tui_outline_row_edits_hidden_label_column() {
        let mut grid = VolvoxGrid::new(1, 240, 180, 3, 2, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.edit_trigger_mode = 1;
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.auto_size = false;
        grid.indicator_bands.row_start.width_px = 24;
        grid.indicator_bands.row_start.slots = vec![RowIndicatorSlotState::new(
            pb::RowIndicatorSlotKind::RowIndicatorSlotExpander,
            24,
        )];
        grid.outline.tree_indicator = pb::TreeIndicatorStyle::TreeIndicatorConnectorsLeaf as i32;
        grid.outline.label_column = 0;
        grid.cols_hidden.insert(0);
        grid.cells.set_text(1, 0, "Reports".to_string());
        grid.cells.set_text(1, 1, "Folder".to_string());
        grid.row_props.entry(1).or_default().outline_level = 0;
        prime_layout(&mut grid);
        grid.selection
            .set_cursor(1, 0, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);

        handle_key_down(&mut grid, 113, 0);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.edit_row, 1);
        assert_eq!(grid.edit.edit_col, 0);
        assert_eq!(grid.edit.edit_text, "Reports");
    }

    #[test]
    fn f2_on_tui_outline_visible_cell_edits_selected_cell() {
        let mut grid = VolvoxGrid::new(1, 240, 180, 3, 2, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.edit_trigger_mode = 1;
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.auto_size = false;
        grid.indicator_bands.row_start.width_px = 24;
        grid.indicator_bands.row_start.slots = vec![RowIndicatorSlotState::new(
            pb::RowIndicatorSlotKind::RowIndicatorSlotExpander,
            24,
        )];
        grid.outline.tree_indicator = pb::TreeIndicatorStyle::TreeIndicatorConnectorsLeaf as i32;
        grid.outline.label_column = 0;
        grid.cols_hidden.insert(0);
        grid.cells.set_text(1, 0, "Reports".to_string());
        grid.cells.set_text(1, 1, "Folder".to_string());
        grid.row_props.entry(1).or_default().outline_level = 0;
        prime_layout(&mut grid);
        grid.selection
            .set_cursor(1, 1, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);

        handle_key_down(&mut grid, 113, 0);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.edit_row, 1);
        assert_eq!(grid.edit.edit_col, 1);
        assert_eq!(grid.edit.edit_text, "Folder");
    }

    #[test]
    fn enter_on_tui_outline_visible_cell_edits_selected_cell() {
        let mut grid = VolvoxGrid::new(1, 240, 180, 3, 2, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.edit_trigger_mode = 1;
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.auto_size = false;
        grid.indicator_bands.row_start.width_px = 24;
        grid.indicator_bands.row_start.slots = vec![RowIndicatorSlotState::new(
            pb::RowIndicatorSlotKind::RowIndicatorSlotExpander,
            24,
        )];
        grid.outline.tree_indicator = pb::TreeIndicatorStyle::TreeIndicatorConnectorsLeaf as i32;
        grid.outline.label_column = 0;
        grid.cols_hidden.insert(0);
        grid.cells.set_text(1, 0, "Reports".to_string());
        grid.cells.set_text(1, 1, "Folder".to_string());
        grid.row_props.entry(1).or_default().outline_level = 0;
        grid.row_props.entry(2).or_default().outline_level = 1;
        prime_layout(&mut grid);
        grid.selection
            .set_cursor(1, 1, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);

        handle_key_down(&mut grid, 13, 0);

        assert!(grid.is_editing());
        assert_eq!(grid.edit.edit_row, 1);
        assert_eq!(grid.edit.edit_col, 1);
        assert_eq!(grid.edit.edit_text, "Folder");
        assert!(!grid
            .row_props
            .get(&1)
            .is_some_and(|props| props.is_collapsed));
    }

    #[test]
    fn keyboard_navigation_skips_collapsed_outline_rows() {
        let mut grid = VolvoxGrid::new(1, 240, 180, 6, 2, 1, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.auto_size = false;
        grid.indicator_bands.row_start.width_px = 80;
        grid.indicator_bands.row_start.slots = vec![RowIndicatorSlotState::new(
            pb::RowIndicatorSlotKind::RowIndicatorSlotExpander,
            80,
        )];
        grid.outline.tree_indicator = pb::TreeIndicatorStyle::TreeIndicatorArrowsLeaf as i32;
        grid.outline.label_column = 0;
        grid.cols_hidden.insert(0);
        grid.row_props.entry(1).or_default().outline_level = 0;
        grid.row_props.entry(2).or_default().outline_level = 1;
        grid.row_props.entry(3).or_default().outline_level = 2;
        grid.row_props.entry(4).or_default().outline_level = 0;
        grid.row_props.entry(5).or_default().outline_level = 1;
        prime_layout(&mut grid);
        grid.selection
            .set_cursor(1, 0, grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);

        handle_key_down(&mut grid, 13, 0);

        assert!(grid.is_row_hidden(2));
        assert!(grid.is_row_hidden(3));

        handle_key_down(&mut grid, 40, 0);

        assert_eq!(grid.selection.row, 4);

        handle_key_down(&mut grid, 38, 0);

        assert_eq!(grid.selection.row, 1);
    }

    #[test]
    fn tui_connector_expander_hit_uses_rendered_tree_prefix() {
        let mut grid = VolvoxGrid::new(1, 240, 180, 6, 2, 1, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.auto_size = false;
        grid.indicator_bands.row_start.width_px = 80;
        grid.indicator_bands.row_start.slots = vec![RowIndicatorSlotState::new(
            pb::RowIndicatorSlotKind::RowIndicatorSlotExpander,
            80,
        )];
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.outline.tree_indicator = pb::TreeIndicatorStyle::TreeIndicatorConnectorsLeaf as i32;
        grid.row_props.entry(1).or_default().outline_level = 0;
        grid.row_props.entry(2).or_default().outline_level = 1;
        grid.row_props.entry(3).or_default().outline_level = 2;
        grid.row_props.entry(4).or_default().outline_level = 3;
        grid.row_props.entry(5).or_default().outline_level = 4;
        prime_layout(&mut grid);

        let (_cx, row_y, _cw, row_h) = grid.cell_screen_rect(4, 0).unwrap();
        let hit = hit_test(&mut grid, 10.0, (row_y + row_h / 2) as f32);

        assert_eq!(hit.area, HitArea::OutlineButton);
        assert_eq!(hit.row, 4);
    }

    #[test]
    fn row_indicator_expander_hover_targets_slot_and_repaints() {
        let mut grid = outline_indicator_test_grid();
        grid.selection.hover_mode = HOVER_ROW;
        let (_cx, row_y, _cw, row_h) = grid.cell_screen_rect(1, 0).unwrap();
        grid.clear_dirty();

        handle_pointer_move(&mut grid, 6.0, (row_y + row_h / 2) as f32, 0, 0);

        assert!(grid.dirty);
        let hover = grid.last_hover_target.as_ref().unwrap();
        assert_eq!(hover.row, 1);
        assert_eq!(
            hover.target.kind,
            pb::GridTargetKind::GridTargetRowIndicator as i32
        );
        assert_eq!(
            hover.target.slot_kind,
            pb::RowIndicatorSlotKind::RowIndicatorSlotExpander as i32
        );
    }

    #[test]
    fn row_indicator_expander_hover_disabled_does_not_repaint() {
        let mut grid = outline_indicator_test_grid();
        let (_cx, row_y, _cw, row_h) = grid.cell_screen_rect(1, 0).unwrap();
        grid.clear_dirty();

        handle_pointer_move(&mut grid, 6.0, (row_y + row_h / 2) as f32, 0, 0);

        assert!(!grid.dirty);
        assert_eq!(
            grid.last_hover_target.as_ref().unwrap().target.slot_kind,
            pb::RowIndicatorSlotKind::RowIndicatorSlotExpander as i32
        );
    }

    #[test]
    fn corner_outline_level_buttons_cycle_level_and_child() {
        let mut grid = zero_based_outline_indicator_test_grid();
        let step = crate::outline::TreeGeometry::from_grid(&grid).indent_step;
        let level_0_x = step / 2;
        let level_1_x = step + step / 2;
        let level_3_x = step * 3 + step / 2;

        handle_pointer_down(&mut grid, level_0_x as f32, 5.0, 0, 0, false);
        assert_eq!(visible_outline_levels(&grid), vec![0, 1, 2, 3]);
        assert!(grid.outline_level_button_pressed);
        assert_eq!(grid.outline_level_button_pressed_level, 0);
        assert!(grid.outline_level_button_pressed_inside);
        handle_pointer_up(&mut grid, level_0_x as f32, 5.0, 0, 0);
        assert_eq!(visible_outline_levels(&grid), vec![0]);
        assert!(!grid.outline_level_button_pressed);

        click_outline_level_button(&mut grid, level_0_x as f32);
        assert_eq!(visible_outline_levels(&grid), vec![0, 1]);

        click_outline_level_button(&mut grid, level_3_x as f32);
        assert_eq!(visible_outline_levels(&grid), vec![0, 1, 2, 3]);

        click_outline_level_button(&mut grid, level_1_x as f32);
        assert_eq!(visible_outline_levels(&grid), vec![0, 1]);

        click_outline_level_button(&mut grid, level_1_x as f32);
        assert_eq!(visible_outline_levels(&grid), vec![0, 1, 2]);
    }

    #[test]
    fn corner_outline_level_click_reveals_hidden_deeper_level() {
        let mut grid = zero_based_outline_indicator_test_grid();

        let step = crate::outline::TreeGeometry::from_grid(&grid).indent_step;
        let level_0_x = step / 2;
        let level_1_x = step + step / 2;

        click_outline_level_button(&mut grid, level_0_x as f32);
        assert_eq!(visible_outline_levels(&grid), vec![0]);

        click_outline_level_button(&mut grid, level_1_x as f32);
        assert_eq!(visible_outline_levels(&grid), vec![0, 1, 2]);
    }

    #[test]
    fn corner_outline_level_buttons_use_wide_touch_targets_when_space_allows() {
        let mut grid = zero_based_outline_indicator_test_grid();
        grid.indicator_bands.row_start.width_px = 240;
        grid.indicator_bands.row_start.slots[0].width_px = 240;
        grid.indicator_bands.corner_top_start.slots[0].width_px = 240;
        prime_layout(&mut grid);

        let step =
            crate::outline::outline_level_button_step(&grid, grid.indicator_bands.start_width());
        assert_eq!(step, crate::outline::MIN_TOUCH_OUTLINE_LEVEL_BUTTON_WIDTH);

        click_outline_level_button(&mut grid, (step - 5) as f32);
        assert_eq!(visible_outline_levels(&grid), vec![0]);
    }

    #[test]
    fn corner_outline_level_button_cancel_when_pointer_up_outside() {
        let mut grid = zero_based_outline_indicator_test_grid();

        let step = crate::outline::TreeGeometry::from_grid(&grid).indent_step;
        let level_0_x = step / 2;
        let level_1_x = step + step / 2;
        handle_pointer_down(&mut grid, level_0_x as f32, 5.0, 0, 0, false);
        handle_pointer_up(&mut grid, level_1_x as f32, 5.0, 0, 0);

        assert_eq!(visible_outline_levels(&grid), vec![0, 1, 2, 3]);
        assert!(!grid.outline_level_button_pressed);

        handle_pointer_down(&mut grid, level_0_x as f32, 5.0, 0, 0, false);
        assert!(grid.outline_level_button_pressed);

        handle_pointer_up(&mut grid, level_0_x as f32, 40.0, 0, 0);

        assert_eq!(visible_outline_levels(&grid), vec![0, 1, 2, 3]);
        assert!(!grid.outline_level_button_pressed);
        assert!(!grid.outline_click_active);
    }

    #[test]
    fn corner_outline_level_button_pressed_style_tracks_pointer_inside() {
        let mut grid = zero_based_outline_indicator_test_grid();

        let step = crate::outline::TreeGeometry::from_grid(&grid).indent_step;
        let level_0_x = step / 2;
        handle_pointer_down(&mut grid, level_0_x as f32, 5.0, 0, 0, false);
        assert!(grid.outline_level_button_pressed_inside);

        handle_pointer_move(&mut grid, level_0_x as f32, 40.0, 1, 0);
        assert!(grid.outline_level_button_pressed);
        assert!(!grid.outline_level_button_pressed_inside);

        handle_pointer_move(&mut grid, level_0_x as f32, 5.0, 1, 0);
        assert!(grid.outline_level_button_pressed_inside);

        handle_pointer_up(&mut grid, level_0_x as f32, 5.0, 0, 0);
        assert_eq!(visible_outline_levels(&grid), vec![0]);
    }

    #[test]
    fn corner_outline_level_hover_targets_each_level_and_repaints() {
        let mut grid = zero_based_outline_indicator_test_grid();
        grid.selection.hover_mode = HOVER_ROW;

        let step = crate::outline::TreeGeometry::from_grid(&grid).indent_step;
        let level_0_x = step / 2;
        let level_1_x = step + step / 2;
        grid.clear_dirty();

        handle_pointer_move(&mut grid, level_0_x as f32, 5.0, 0, 0);

        assert!(grid.dirty);
        let hover = grid.last_hover_target.as_ref().unwrap();
        assert_eq!(
            hover.target.kind,
            pb::GridTargetKind::GridTargetCornerIndicator as i32
        );
        assert_eq!(
            hover.target.slot_kind,
            pb::CornerIndicatorSlotKind::CornerSlotOutlineLevels as i32
        );
        assert_eq!(hover.target.int_value, 0);

        grid.clear_dirty();
        handle_pointer_move(&mut grid, level_1_x as f32, 5.0, 0, 0);

        assert!(grid.dirty);
        assert_eq!(grid.last_hover_target.as_ref().unwrap().target.int_value, 1);
    }

    #[test]
    fn corner_outline_level_hover_disabled_does_not_repaint() {
        let mut grid = zero_based_outline_indicator_test_grid();

        let step = crate::outline::TreeGeometry::from_grid(&grid).indent_step;
        let level_0_x = step / 2;
        grid.clear_dirty();

        handle_pointer_move(&mut grid, level_0_x as f32, 5.0, 0, 0);

        assert!(!grid.dirty);
        assert_eq!(grid.last_hover_target.as_ref().unwrap().target.int_value, 0);
    }
}
