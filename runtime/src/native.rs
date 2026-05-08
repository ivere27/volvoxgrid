use std::collections::{HashMap, HashSet, VecDeque};
use std::panic::{self, AssertUnwindSafe};
use std::sync::{
    atomic::{AtomicI64, Ordering},
    mpsc, Arc, Mutex,
};
use std::time::{Duration, Instant};

use crate::shared;
use volvoxgrid_engine::proto::volvoxgrid::v1 as pb;
use volvoxgrid_engine::proto::volvoxgrid::v1::*;
use volvoxgrid_engine::GridManager;

#[path = "volvoxgrid_ffi_runtime.rs"]
mod ffi_impl;
use ffi_impl::*;
#[path = "volvoxtree_ffi_runtime.rs"]
mod ffi_tree_impl;
#[path = "terminal_tui.rs"]
mod terminal_tui;

#[cfg(all(target_os = "windows", target_env = "gnu"))]
unsafe extern "C" {
    fn volvoxgrid_windows_mingw_compat_force_link();
}

// Shared state is keyed by grid id rather than by VolvoxGridRuntime instance.
// Generated service values are cheap handles: a render session, EventStream,
// and action RPC may be driven through different runtime objects but still need
// to rendezvous on the same compare channel and session count.
lazy_static::lazy_static! {
    static ref SHARED_GRID_MANAGER: GridManager = GridManager::new();
    static ref COMPARE_CHANNELS: Mutex<HashMap<i64, Arc<CompareChannel>>> =
        Mutex::new(HashMap::new());
    static ref ACTIVE_RENDER_SESSIONS: Mutex<HashMap<i64, usize>> =
        Mutex::new(HashMap::new());
}

const ERROR_DECISION_TIMEOUT: i32 = 1001;
const ERROR_COMPARE_TIMEOUT: i32 = 1002;

type RuntimeResult<T> = Result<T, FfiError>;
type TreeRuntimeResult<T> = Result<T, ffi_tree_impl::FfiError>;

const ERROR_INVALID_ARGUMENT: i32 = 1;
const ERROR_NOT_FOUND: i32 = 2;
const ERROR_INVALID_STATE: i32 = 3;
const ERROR_TYPE_VIOLATION: i32 = 4;
const ERROR_NOT_IMPLEMENTED: i32 = 7;
const ERROR_INTERNAL: i32 = 8;

const GRPC_INVALID_ARGUMENT: i32 = 3;
const GRPC_NOT_FOUND: i32 = 5;
const GRPC_FAILED_PRECONDITION: i32 = 9;
const GRPC_UNIMPLEMENTED: i32 = 12;
const GRPC_INTERNAL: i32 = 13;

fn ffi_error(message: impl Into<String>, code: i32, grpc_code: i32) -> FfiError {
    FfiError::new(message.into(), code, grpc_code)
}

fn invalid_argument(message: impl Into<String>) -> FfiError {
    ffi_error(message, ERROR_INVALID_ARGUMENT, GRPC_INVALID_ARGUMENT)
}

fn not_found(message: impl Into<String>) -> FfiError {
    ffi_error(message, ERROR_NOT_FOUND, GRPC_NOT_FOUND)
}

fn invalid_state(message: impl Into<String>) -> FfiError {
    ffi_error(message, ERROR_INVALID_STATE, GRPC_FAILED_PRECONDITION)
}

fn type_violation(message: impl Into<String>) -> FfiError {
    ffi_error(message, ERROR_TYPE_VIOLATION, GRPC_INVALID_ARGUMENT)
}

fn not_implemented(message: impl Into<String>) -> FfiError {
    ffi_error(message, ERROR_NOT_IMPLEMENTED, GRPC_UNIMPLEMENTED)
}

fn internal_error(message: impl Into<String>) -> FfiError {
    ffi_error(message, ERROR_INTERNAL, GRPC_INTERNAL)
}

fn map_runtime_error(message: impl Into<String>) -> FfiError {
    let message = message.into();
    let lower = message.to_ascii_lowercase();

    if lower.contains("not found") {
        return not_found(message);
    }
    if lower.contains("type violation")
        || lower.contains("type mismatch")
        || lower.contains("invalid type")
    {
        return type_violation(message);
    }
    if lower.contains("invalid argument")
        || lower.contains("invalid utf-8")
        || lower.contains("decode")
        || lower.contains("encode")
        || lower.contains("empty")
        || lower.contains("unknown demo")
        || lower.contains("duplicate tree node id")
        || lower.contains("references missing parent")
        || lower.contains("tree cycle")
        || lower.contains("recursive remove is required")
        || lower.contains("cannot be moved")
        || lower.contains("parent_id")
    {
        return invalid_argument(message);
    }
    if lower.contains("not enabled") || lower.contains("not implemented") {
        return not_implemented(message);
    }
    if lower.contains("closed") || lower.contains("active edit") {
        return invalid_state(message);
    }
    internal_error(message)
}

fn tree_ffi_error_from(error: FfiError) -> ffi_tree_impl::FfiError {
    ffi_tree_impl::FfiError::new(error.message, error.code, error.grpc_code)
}

fn tree_map_runtime_error(message: impl Into<String>) -> ffi_tree_impl::FfiError {
    tree_ffi_error_from(map_runtime_error(message))
}

fn current_frame_metrics(grid: &volvoxgrid_engine::grid::VolvoxGrid) -> Option<FrameMetrics> {
    if !grid.layer_profiling && !grid.debug_overlay {
        return None;
    }
    Some(FrameMetrics {
        frame_time_ms: grid.debug_frame_time_ms,
        fps: grid.debug_fps,
        layer_times_us: grid.layer_times_us.to_vec(),
        zone_cell_counts: grid.zone_cell_counts.to_vec(),
        instance_count: grid.debug_instance_count,
    })
}

fn with_tui_pointer_geometry<R>(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    f: impl FnOnce(&mut volvoxgrid_engine::grid::VolvoxGrid) -> R,
) -> R {
    if !grid.is_tui_mode() {
        return f(grid);
    }

    let saved_row_start = grid.indicator_bands.row_start.clone();
    let saved_col_top = grid.indicator_bands.col_top.clone();

    if grid.indicator_bands.row_start.visible {
        grid.indicator_bands.row_start.width_px =
            volvoxgrid_engine::canvas_tui::tui_row_indicator_width(grid).max(1);
        grid.indicator_bands.row_start.auto_size = false;
        grid.indicator_bands.row_start.fit_slots_to_width();
    }
    grid.indicator_bands.col_top.visible = true;
    grid.indicator_bands.col_top.default_row_height_px = 1;
    grid.indicator_bands.col_top.band_rows = 1;
    grid.indicator_bands.col_top.row_defs.clear();

    let result = f(grid);

    grid.indicator_bands.row_start = saved_row_start;
    grid.indicator_bands.col_top = saved_col_top;

    result
}

struct TuiScrollbarTrackHit {
    geometry: volvoxgrid_engine::canvas_tui::TuiScrollbarGeometry,
    relative_scroll_row: i32,
}

fn tui_scrollbar_track_hit(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    x: i32,
    y: i32,
) -> Option<TuiScrollbarTrackHit> {
    let geometry = volvoxgrid_engine::canvas_tui::compute_tui_scrollbar_geometry(
        grid,
        grid.viewport_width,
        grid.viewport_height,
    );
    if !geometry.visible || x != geometry.scrollbar_col {
        return None;
    }

    let track_row = y - geometry.track_start_row;
    if track_row < 0 || track_row >= geometry.track_rows {
        return None;
    }

    Some(TuiScrollbarTrackHit {
        geometry,
        relative_scroll_row: track_row - geometry.fixed_data_rows,
    })
}

fn tui_target_top_row_for_thumb(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    geometry: volvoxgrid_engine::canvas_tui::TuiScrollbarGeometry,
    thumb_start: i32,
) -> i32 {
    let first_scrollable_row = grid.first_scrollable_row().clamp(0, grid.rows);
    let total_rows = (grid.rows - first_scrollable_row).max(0);
    let effective_scroll_rows = geometry.scroll_rows.max(1);
    let scrollable_extent = (total_rows - effective_scroll_rows).max(1);
    if geometry.thumb_range <= 0 {
        return grid.top_row();
    }

    first_scrollable_row
        + ((thumb_start.clamp(0, geometry.thumb_range) * scrollable_extent
            + geometry.thumb_range / 2)
            / geometry.thumb_range)
}

fn handle_tui_terminal_pointer_event(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    pe: &PointerEvent,
    terminal_session: &mut terminal_tui::TerminalTuiSession,
) -> bool {
    if !grid.is_tui_mode() || !terminal_session.is_active() {
        return false;
    }

    let pointer_x = pe.x as i32;
    let pointer_y = pe.y as i32;
    match pe.r#type {
        t if t == pb::pointer_event::Type::Down as i32 => {
            terminal_session.stop_tui_scrollbar_drag();

            if pe.button != 0 {
                return false;
            }

            let Some(hit) = tui_scrollbar_track_hit(grid, pointer_x, pointer_y) else {
                return false;
            };

            grid.cancel_pull_to_refresh_contact(false);

            if hit.relative_scroll_row >= 0
                && hit.relative_scroll_row >= hit.geometry.thumb_start
                && hit.relative_scroll_row < hit.geometry.thumb_start + hit.geometry.thumb_size
            {
                terminal_session.start_tui_scrollbar_drag(
                    pointer_y,
                    grid.top_row(),
                    hit.geometry.thumb_start,
                );
                return true;
            }

            if hit.relative_scroll_row >= 0 && hit.relative_scroll_row < hit.geometry.thumb_start {
                volvoxgrid_engine::input::handle_scroll(
                    grid,
                    0.0,
                    -(hit.geometry.scroll_rows.max(1) as f32),
                );
                return true;
            }

            if hit.relative_scroll_row >= hit.geometry.thumb_start + hit.geometry.thumb_size
                && hit.relative_scroll_row < hit.geometry.scroll_rows
            {
                volvoxgrid_engine::input::handle_scroll(
                    grid,
                    0.0,
                    hit.geometry.scroll_rows.max(1) as f32,
                );
                return true;
            }

            false
        }
        t if t == pb::pointer_event::Type::Up as i32 => {
            if terminal_session.is_tui_scrollbar_dragging() {
                terminal_session.stop_tui_scrollbar_drag();
                return true;
            }
            false
        }
        t if t == pb::pointer_event::Type::Move as i32 => {
            let Some((start_y, start_top_row, start_thumb)) =
                terminal_session.tui_scrollbar_drag_origin()
            else {
                return false;
            };

            let geometry = volvoxgrid_engine::canvas_tui::compute_tui_scrollbar_geometry(
                grid,
                grid.viewport_width,
                grid.viewport_height,
            );
            if !geometry.visible {
                terminal_session.stop_tui_scrollbar_drag();
                return false;
            }

            let delta_rows = pointer_y - start_y;
            let target_thumb = (start_thumb + delta_rows).clamp(0, geometry.thumb_range);
            let target_top_row = if geometry.thumb_range <= 0 {
                start_top_row
            } else {
                tui_target_top_row_for_thumb(grid, geometry, target_thumb)
            };
            if target_top_row == grid.top_row() {
                return true;
            }

            grid.set_top_row(target_top_row);
            return true;
        }
        _ => false,
    }
}

fn should_request_pointer_header_sort(
    grid: &volvoxgrid_engine::grid::VolvoxGrid,
    hit: &volvoxgrid_engine::input::HitTestResult,
    is_combo_cell: bool,
) -> bool {
    if hit.col < 0 || is_combo_cell || grid.header_features & 1 == 0 {
        return false;
    }

    if hit.area == volvoxgrid_engine::input::HitArea::FixedRow {
        return hit.row >= 0 && hit.row < grid.fixed_rows;
    }

    grid.is_tui_mode() && hit.area == volvoxgrid_engine::input::HitArea::IndicatorColTop
}

fn handle_pointer_render_input(
    runtime: &VolvoxGridRuntime,
    stream: &dyn RuntimeStreamBidi<RenderInput, RenderOutput>,
    sent_edit_requests: &mut HashMap<i64, SentEditRequest>,
    grid_id: i64,
    pe: PointerEvent,
    terminal_session: Option<&mut terminal_tui::TerminalTuiSession>,
    emit_aux_outputs: bool,
) {
    let sel_and_editor = runtime.with_grid(grid_id, |grid| {
        if !grid.layout.valid {
            ensure_layout(grid);
        }

        with_tui_pointer_geometry(grid, |grid| {
            let mut terminal_session = terminal_session;
            if let Some(session) = terminal_session.as_deref_mut() {
                if handle_tui_terminal_pointer_event(grid, &pe, session) {
                    return (
                        false,
                        grid.selection.row,
                        grid.selection.col,
                        shared::selection_ranges_proto(grid),
                        None,
                    );
                }
            }

            let tui_mouse_x = if grid.is_tui_mode() {
                Some(
                    volvoxgrid_engine::canvas_tui::translate_tui_mouse_x_for_hit(
                        grid,
                        grid.viewport_width,
                        grid.viewport_height,
                        pe.x as i32,
                    ),
                )
            } else {
                None
            };
            let pointer_x = tui_mouse_x.map_or(pe.x, |translation| translation.hit_test_x as f32);
            let pointer_y = pe.y;

            let decision_enabled = runtime.decision_channel_enabled(grid_id);
            let manual_edit_policy = decision_enabled || grid.is_tui_mode();
            let was_editing = grid.edit.is_active();
            let prev_edit_row = grid.edit.edit_row;
            let prev_edit_col = grid.edit.edit_col;
            let prev_edit_selection = (
                grid.edit.sel_start,
                grid.edit.sel_length,
                grid.edit.sel_caret,
            );
            let prev_sel = (
                grid.selection.row,
                grid.selection.col,
                shared::selection_range_tuples(grid),
            );
            if pe.r#type == pb::pointer_event::Type::Down as i32
                && pe.button == 0
                && grid.is_tui_mode()
                && volvoxgrid_engine::canvas_tui::tui_dropdown_hit_index(
                    grid,
                    grid.viewport_width,
                    grid.viewport_height,
                    pe.x as i32,
                    pe.y as i32,
                )
                .map(|idx| volvoxgrid_engine::input::commit_dropdown_item_click(grid, idx))
                .unwrap_or(false)
            {
                return (
                    false,
                    grid.selection.row,
                    grid.selection.col,
                    shared::selection_ranges_proto(grid),
                    None,
                );
            }
            let hit = if pe.r#type == pb::pointer_event::Type::Down as i32 {
                Some(volvoxgrid_engine::input::hit_test(
                    grid, pointer_x, pointer_y,
                ))
            } else {
                None
            };
            let prefer_combo = hit
                .as_ref()
                .map(|h| h.area == volvoxgrid_engine::input::HitArea::DropdownButton)
                .unwrap_or(false);
            let tui_hit_caret = hit.as_ref().and_then(|hit| {
                tui_mouse_x
                    .filter(|translation| translation.col == hit.col)
                    .map(|translation| {
                        volvoxgrid_engine::canvas_tui::tui_caret_index_from_display_click(
                            grid,
                            hit.row,
                            hit.col,
                            translation.x_in_cell,
                            translation.cell_width,
                        )
                    })
            });
            let active_tui_edit_click_caret = if pe.r#type == pb::pointer_event::Type::Down as i32
                && !pe.dbl_click
                && pe.button == 0
            {
                hit.as_ref().and_then(|hit| {
                    let hit_active_edit_cell = was_editing
                        && hit.row == prev_edit_row
                        && hit.col == prev_edit_col
                        && matches!(
                            hit.area,
                            volvoxgrid_engine::input::HitArea::Cell
                                | volvoxgrid_engine::input::HitArea::CellText
                                | volvoxgrid_engine::input::HitArea::FixedRow
                                | volvoxgrid_engine::input::HitArea::FixedCol
                        );
                    if hit_active_edit_cell {
                        tui_hit_caret
                    } else {
                        None
                    }
                })
            } else {
                None
            };

            match pe.r#type {
                t if t == pb::pointer_event::Type::Down as i32 => {
                    let allow_pull_contact = pe.button == 0
                        && !matches!(
                            hit.as_ref().map(|h| h.area.clone()),
                            Some(volvoxgrid_engine::input::HitArea::FastScroll)
                                | Some(volvoxgrid_engine::input::HitArea::HScrollBar)
                                | Some(volvoxgrid_engine::input::HitArea::VScrollBar)
                        );
                    if allow_pull_contact {
                        grid.begin_pull_to_refresh_contact();
                    } else {
                        grid.cancel_pull_to_refresh_contact(false);
                    }
                    if manual_edit_policy {
                        let queued_before_mouse_down = decision_enabled
                            && hit.as_ref().map_or(false, |hit| {
                                (!pe.dbl_click
                                    || hit.area == volvoxgrid_engine::input::HitArea::CheckBox)
                                    && hit.row >= 0
                                    && hit.col >= 0
                                    && hit.area != volvoxgrid_engine::input::HitArea::DropdownList
                            });
                        if queued_before_mouse_down {
                            if let Some(hit) = hit.as_ref() {
                                runtime.request_before_mouse_down(
                                    grid_id,
                                    grid,
                                    hit.row,
                                    hit.col,
                                    pointer_x,
                                    pointer_y,
                                    pe.button,
                                    pe.modifier,
                                    pe.dbl_click,
                                );
                            }
                        } else {
                            volvoxgrid_engine::input::handle_pointer_down_with_behavior(
                                grid,
                                pointer_x,
                                pointer_y,
                                pe.button,
                                pe.modifier,
                                pe.dbl_click,
                                volvoxgrid_engine::input::InputBehavior {
                                    allow_begin_edit: false,
                                    allow_header_sort: false,
                                    allow_node_toggle: false,
                                    allow_user_resize: false,
                                    allow_before_mouse_down: false,
                                    ..volvoxgrid_engine::input::InputBehavior::default()
                                },
                            );
                            if let Some(caret) = active_tui_edit_click_caret {
                                if grid.edit.is_active()
                                    && grid.edit.edit_row == prev_edit_row
                                    && grid.edit.edit_col == prev_edit_col
                                {
                                    grid.edit.set_selection_anchor_and_caret(caret, caret);
                                    grid.edit_pointer_select_active = true;
                                    grid.edit_pointer_select_anchor = caret;
                                    grid.mark_dirty();
                                }
                            }

                            if let Some(hit) = hit.as_ref() {
                                let mut is_combo_cell = false;
                                if hit.area == volvoxgrid_engine::input::HitArea::ColBorder
                                    && hit.col >= 0
                                    && !pe.dbl_click
                                {
                                    runtime.request_before_user_resize(
                                        grid_id, grid, -1, hit.col, pointer_x,
                                    );
                                } else if hit.area == volvoxgrid_engine::input::HitArea::RowBorder
                                    && hit.row >= 0
                                    && !pe.dbl_click
                                {
                                    runtime.request_before_user_resize(
                                        grid_id, grid, hit.row, -1, pointer_y,
                                    );
                                }

                                if hit.row >= 0
                                    && !pe.dbl_click
                                    && hit.area == volvoxgrid_engine::input::HitArea::OutlineButton
                                {
                                    let collapsing = !grid
                                        .row_props
                                        .get(&hit.row)
                                        .map_or(false, |rp| rp.is_collapsed);
                                    runtime.request_before_node_toggle(
                                        grid_id, grid, hit.row, collapsing,
                                    );
                                }

                                if hit.row >= 0 && hit.col >= 0 {
                                    if hit.area == volvoxgrid_engine::input::HitArea::CheckBox {
                                        runtime.request_before_checkbox_toggle(
                                            grid_id, grid, hit.row, hit.col,
                                        );
                                    }

                                    let is_cell_like = hit.area
                                        == volvoxgrid_engine::input::HitArea::Cell
                                        || hit.area == volvoxgrid_engine::input::HitArea::FixedRow
                                        || hit.area == volvoxgrid_engine::input::HitArea::FixedCol;
                                    let combo_list = if is_cell_like {
                                        grid.active_dropdown_list(hit.row, hit.col)
                                    } else {
                                        String::new()
                                    };
                                    is_combo_cell = !combo_list.is_empty();

                                    if hit.area == volvoxgrid_engine::input::HitArea::DropdownButton
                                    {
                                        if !(grid.edit.is_active()
                                            && grid.edit.edit_row == hit.row
                                            && grid.edit.edit_col == hit.col)
                                        {
                                            let _ = runtime.request_before_edit(
                                                grid_id, grid, hit.row, hit.col, false, true, None,
                                                None, None,
                                            );
                                        }
                                    } else if is_cell_like
                                        && ((pe.dbl_click && grid.edit_trigger_mode >= 2)
                                            || is_combo_cell)
                                    {
                                        let click_caret = if pe.dbl_click {
                                            tui_hit_caret.or_else(|| {
                                                Some(grid.caret_index_from_display_click(
                                                    hit.row,
                                                    hit.col,
                                                    hit.x_in_cell,
                                                ))
                                            })
                                        } else {
                                            None
                                        };
                                        let _ = runtime.request_before_edit(
                                            grid_id,
                                            grid,
                                            hit.row,
                                            hit.col,
                                            false,
                                            is_combo_cell,
                                            None,
                                            click_caret,
                                            if pe.dbl_click { Some(true) } else { None },
                                        );
                                    }
                                }

                                if should_request_pointer_header_sort(grid, hit, is_combo_cell) {
                                    runtime.request_before_sort(grid_id, grid, hit.col);
                                }
                            }
                        }
                    } else {
                        volvoxgrid_engine::input::handle_pointer_down(
                            grid,
                            pointer_x,
                            pointer_y,
                            pe.button,
                            pe.modifier,
                            pe.dbl_click,
                        );
                    }
                }
                t if t == pb::pointer_event::Type::Up as i32 => {
                    grid.end_pull_to_refresh_contact();
                    if decision_enabled {
                        if let Some((col, new_position)) =
                            volvoxgrid_engine::input::take_column_drag_move(grid)
                        {
                            runtime.request_before_move_column(grid_id, grid, col, new_position);
                        } else {
                            volvoxgrid_engine::input::handle_pointer_up_with_behavior(
                                grid,
                                pointer_x,
                                pointer_y,
                                pe.button,
                                pe.modifier,
                                volvoxgrid_engine::input::InputBehavior {
                                    allow_header_sort: false,
                                    ..volvoxgrid_engine::input::InputBehavior::default()
                                },
                            );
                        }
                    } else {
                        volvoxgrid_engine::input::handle_pointer_up(
                            grid,
                            pointer_x,
                            pointer_y,
                            pe.button,
                            pe.modifier,
                        );
                    }
                }
                t if t == pb::pointer_event::Type::Move as i32 => {
                    volvoxgrid_engine::input::handle_pointer_move(
                        grid,
                        pointer_x,
                        pointer_y,
                        pe.button,
                        pe.modifier,
                    );
                }
                _ => {}
            }

            let mut editor_output = None;
            if grid.edit.is_active() {
                let started_or_changed = !was_editing
                    || grid.edit.edit_row != prev_edit_row
                    || grid.edit.edit_col != prev_edit_col;
                let edit_selection_changed = was_editing
                    && grid.edit.edit_row == prev_edit_row
                    && grid.edit.edit_col == prev_edit_col
                    && (
                        grid.edit.sel_start,
                        grid.edit.sel_length,
                        grid.edit.sel_caret,
                    ) != prev_edit_selection;
                if started_or_changed || prefer_combo || edit_selection_changed {
                    editor_output = maybe_render_editor_output(grid, prefer_combo);
                }
            }

            let next_sel = (
                grid.selection.row,
                grid.selection.col,
                shared::selection_range_tuples(grid),
            );
            let selection_changed = next_sel != prev_sel;

            (
                selection_changed,
                grid.selection.row,
                grid.selection.col,
                shared::selection_ranges_proto(grid),
                editor_output,
            )
        })
    });
    if !emit_aux_outputs {
        return;
    }
    if let Ok((selection_changed, row, col, ranges, editor_output)) = sel_and_editor {
        if pe.r#type != pb::pointer_event::Type::Move as i32 || selection_changed {
            stream.send(RenderOutput {
                rendered: false,
                event: Some(render_output::Event::Selection(SelectionUpdate {
                    active_row: row,
                    active_col: col,
                    ranges,
                })),
            });
        }
        if let Some(output) = editor_output {
            send_render_output_tracked(runtime, stream, sent_edit_requests, grid_id, output);
        }
    }
}

fn handle_key_render_input(
    runtime: &VolvoxGridRuntime,
    stream: &dyn RuntimeStreamBidi<RenderInput, RenderOutput>,
    sent_edit_requests: &mut HashMap<i64, SentEditRequest>,
    grid_id: i64,
    ke: KeyEvent,
    emit_aux_outputs: bool,
    mut terminal_session: Option<&mut terminal_tui::TerminalTuiSession>,
) {
    let sel_and_editor = runtime.with_grid(grid_id, |grid| {
        if !grid.layout.valid {
            ensure_layout(grid);
        }
        let decision_enabled = runtime.decision_channel_enabled(grid_id);
        if let Some(session) = terminal_session.as_deref_mut() {
            let compose_default = if grid.engine_compose_configured {
                grid.engine_compose
            } else {
                true
            };
            session.ensure_compose_default(compose_default);
            grid.engine_compose = session.compose_enabled();
            grid.engine_compose_configured = true;
        }
        let was_editing = grid.edit.is_active();
        let prev_edit_row = grid.edit.edit_row;
        let prev_edit_col = grid.edit.edit_col;
        if was_editing {
            grid.edit.configure_compose(
                grid.effective_engine_compose_enabled(),
                grid.effective_compose_method(),
            );
        }
        let terminal_policy = terminal_session
            .as_deref_mut()
            .map(|session| session.apply_navigation_edit_policy(&ke, was_editing))
            .unwrap_or(terminal_tui::TerminalKeyPolicyDecision::Forward);

        match terminal_policy {
            terminal_tui::TerminalKeyPolicyDecision::Consume => {}
            terminal_tui::TerminalKeyPolicyDecision::StartEdit { caret_end: _ } => {
                // TUI: always start in Edit mode with select-all so the user
                // can type to replace or press arrows to deselect and edit.
                if !was_editing && !grid.host_key_dispatch && grid.edit_trigger_mode >= 1 {
                    let caret_end = Some(true);
                    let (edit_row, edit_col) =
                        volvoxgrid_engine::input::selected_outline_label_edit_target(grid)
                            .unwrap_or((grid.selection.row, grid.selection.col));
                    if !volvoxgrid_engine::input::is_boolean_checkbox_cell(
                        grid, edit_row, edit_col,
                    ) && decision_enabled
                    {
                        let _ = runtime.request_before_edit(
                            grid_id,
                            grid,
                            edit_row,
                            edit_col,
                            false,
                            false,
                            None,
                            None,
                            caret_end,
                        );
                        if grid.is_editing() {
                            grid.edit.select_all();
                            grid.mark_dirty();
                        }
                    } else if !volvoxgrid_engine::input::is_boolean_checkbox_cell(
                        grid, edit_row, edit_col,
                    ) {
                        shared::begin_edit_session_core_opts(
                            grid,
                            edit_row,
                            edit_col,
                            false,
                            true,
                            true,
                            None,
                            caret_end,
                            None,
                            None,
                        );
                        if grid.is_editing() {
                            grid.edit.select_all();
                        }
                    }
                }
            }
            terminal_tui::TerminalKeyPolicyDecision::ToggleCompose { enabled } => {
                grid.engine_compose = enabled;
                grid.engine_compose_configured = true;
                if grid.edit.is_active() {
                    grid.edit
                        .configure_compose(enabled, grid.effective_compose_method());
                    grid.mark_dirty();
                }
            }
            terminal_tui::TerminalKeyPolicyDecision::RemapKeyDown { key_code, modifier } => {
                volvoxgrid_engine::input::handle_key_down_with_behavior(
                    grid,
                    key_code,
                    modifier,
                    volvoxgrid_engine::input::InputBehavior {
                        allow_begin_edit: false,
                        allow_header_sort: true,
                        ..volvoxgrid_engine::input::InputBehavior::default()
                    },
                );
            }
            terminal_tui::TerminalKeyPolicyDecision::Forward => match ke.r#type {
                t if t == pb::key_event::Type::KeyDown as i32 => {
                    if decision_enabled {
                        let uses_outline_expander = (ke.key_code == 13 || ke.key_code == 32)
                            && !was_editing
                            && !grid.host_key_dispatch
                            && volvoxgrid_engine::input::selected_outline_label_keyboard_target(
                                grid,
                            )
                            .is_some();
                        if uses_outline_expander {
                            if let Some((row, collapse)) =
                                volvoxgrid_engine::input::selected_outline_node_toggle_target(grid)
                            {
                                runtime.request_before_node_toggle(grid_id, grid, row, collapse);
                            }
                        } else {
                            volvoxgrid_engine::input::handle_key_down_with_behavior(
                                grid,
                                ke.key_code,
                                ke.modifier,
                                volvoxgrid_engine::input::InputBehavior {
                                    allow_begin_edit: false,
                                    allow_header_sort: true,
                                    ..volvoxgrid_engine::input::InputBehavior::default()
                                },
                            );
                        }
                        let sel_row = grid.selection.row;
                        let sel_col = grid.selection.col;
                        let queued_checkbox_toggle = !uses_outline_expander
                            && (ke.key_code == 13 || ke.key_code == 32)
                            && !grid.host_key_dispatch
                            && !was_editing
                            && !grid.is_editing()
                            && runtime.request_before_checkbox_toggle(
                                grid_id, grid, sel_row, sel_col,
                            );
                        if !uses_outline_expander
                            && !queued_checkbox_toggle
                            && (ke.key_code == 13 || ke.key_code == 113)
                            && !grid.host_key_dispatch
                            && grid.edit_trigger_mode >= 1
                            && !was_editing
                        {
                            let (edit_row, edit_col) =
                                if ke.key_code == 113 {
                                    volvoxgrid_engine::input::selected_outline_label_edit_target(
                                        grid,
                                    )
                                    .unwrap_or((grid.selection.row, grid.selection.col))
                                } else {
                                    (grid.selection.row, grid.selection.col)
                                };
                            if !volvoxgrid_engine::input::is_boolean_checkbox_cell(
                                grid, edit_row, edit_col,
                            ) {
                                let _ = runtime.request_before_edit(
                                    grid_id,
                                    grid,
                                    edit_row,
                                    edit_col,
                                    false,
                                    false,
                                    None,
                                    None,
                                    if ke.key_code == 113 { Some(true) } else { None },
                                );
                            }
                        }
                    } else {
                        volvoxgrid_engine::input::handle_key_down(grid, ke.key_code, ke.modifier);
                    }
                }
                t if t == pb::key_event::Type::KeyUp as i32 => {
                    grid.events
                        .push(volvoxgrid_engine::event::GridEventData::KeyUp {
                            key_code: ke.key_code,
                            modifier: ke.modifier,
                        });
                }
                t if t == pb::key_event::Type::KeyPress as i32 => {
                    if decision_enabled {
                        let outline_space = ke.character == " "
                            && volvoxgrid_engine::input::selected_outline_label_keyboard_target(
                                grid,
                            )
                            .is_some();
                        if !outline_space {
                            volvoxgrid_engine::input::handle_key_press_with_behavior(
                                grid,
                                ke.character.chars().next().map(|c| c as u32).unwrap_or(0),
                                volvoxgrid_engine::input::InputBehavior {
                                    allow_begin_edit: false,
                                    allow_header_sort: true,
                                    ..volvoxgrid_engine::input::InputBehavior::default()
                                },
                            );
                        }
                        if !outline_space
                            && !was_editing
                            && !grid.host_key_dispatch
                            && grid.edit_trigger_mode >= 1
                            && grid.type_ahead_mode == 0
                        {
                            let seed = ke.character.chars().next().map(|c| c.to_string());
                            if let Some(seed) = seed {
                                if !seed.is_empty() {
                                    let (edit_row, edit_col) =
                                        volvoxgrid_engine::input::selected_outline_label_edit_target(
                                            grid,
                                        )
                                        .unwrap_or((grid.selection.row, grid.selection.col));
                                    if !volvoxgrid_engine::input::is_boolean_checkbox_cell(
                                        grid, edit_row, edit_col,
                                    ) {
                                        let _ = runtime.request_before_edit(
                                            grid_id,
                                            grid,
                                            edit_row,
                                            edit_col,
                                            false,
                                            false,
                                            Some(seed),
                                            None,
                                            None,
                                        );
                                    }
                                }
                            }
                        }
                    } else {
                        volvoxgrid_engine::input::handle_key_press(
                            grid,
                            ke.character.chars().next().map(|c| c as u32).unwrap_or(0),
                        );
                    }
                }
                _ => {}
            },
        }

        let mut editor_output = None;
        if grid.edit.is_active() {
            let started_or_changed = !was_editing
                || grid.edit.edit_row != prev_edit_row
                || grid.edit.edit_col != prev_edit_col;
            if started_or_changed {
                let prefer_combo = grid.edit.dropdown_count() > 0;
                editor_output = maybe_render_editor_output(grid, prefer_combo);
            }
        }

        (
            grid.selection.row,
            grid.selection.col,
            shared::selection_ranges_proto(grid),
            editor_output,
        )
    });
    if !emit_aux_outputs {
        return;
    }
    if let Ok((row, col, ranges, editor_output)) = sel_and_editor {
        stream.send(RenderOutput {
            rendered: false,
            event: Some(render_output::Event::Selection(SelectionUpdate {
                active_row: row,
                active_col: col,
                ranges,
            })),
        });
        if let Some(output) = editor_output {
            send_render_output_tracked(runtime, stream, sent_edit_requests, grid_id, output);
        }
    }
}

fn handle_scroll_render_input(
    runtime: &VolvoxGridRuntime,
    stream: &dyn RuntimeStreamBidi<RenderInput, RenderOutput>,
    grid_id: i64,
    se: ScrollEvent,
    emit_aux_outputs: bool,
) {
    let tooltip = runtime.with_grid(grid_id, |grid| {
        if !grid.layout.valid {
            ensure_layout(grid);
        }
        if runtime.decision_channel_enabled(grid_id) {
            let _ = runtime.request_before_scroll(grid_id, grid, se.delta_x, se.delta_y);
        } else {
            volvoxgrid_engine::input::handle_scroll(grid, se.delta_x, se.delta_y);
        }
        if grid.pull_to_refresh_is_visible() {
            return None;
        }
        if !grid.scroll_tips {
            return None;
        }
        let fixed_h = grid.layout.row_pos(grid.fixed_rows);
        let y = (grid.scroll.scroll_y as i32 + fixed_h).max(0);
        let row = grid.layout.row_at_y(y).clamp(0, (grid.rows - 1).max(0));
        let text = if grid.scroll_tooltip_text.is_empty() {
            format!(" Row {} ", row)
        } else {
            grid.scroll_tooltip_text.clone()
        };
        Some(TooltipRequest {
            x: 0.0,
            y: 0.0,
            text,
        })
    });
    if !emit_aux_outputs {
        return;
    }
    stream.send(RenderOutput {
        rendered: false,
        event: tooltip
            .ok()
            .flatten()
            .map(render_output::Event::TooltipRequest),
    });
}

struct VolvoxGridRuntime {
    next_event_id: AtomicI64,
    decision_enabled: Mutex<HashSet<i64>>,
    pending_actions: Mutex<HashMap<(i64, i64), PendingActionEntry>>,
    zoom_levels: Mutex<HashMap<i64, f64>>,
    loaded_font_data: Mutex<Vec<Vec<u8>>>,
}

struct PendingCompare {
    request_id: i64,
    row1: i32,
    row2: i32,
    col: i32,
}

struct CompareChannel {
    next_request_id: AtomicI64,
    pending: Mutex<VecDeque<PendingCompare>>,
    responses: Mutex<HashMap<i64, mpsc::Sender<i32>>>,
    waker: Mutex<Option<Arc<volvoxgrid_engine::Waker>>>,
}

struct HeaderSortSnapshot {
    col: i32,
    order: i32,
    emit_after_sort: bool,
    compare: Box<volvoxgrid_engine::grid::CustomCompareFn>,
    old_sort_state: volvoxgrid_engine::sort::SortState,
    old_row_positions: Vec<i32>,
    groups: Vec<Vec<i32>>,
}

#[derive(Debug)]
enum CompareAbort {
    Timeout,
    Cancelled,
}

impl CompareChannel {
    fn new() -> Arc<Self> {
        Arc::new(Self {
            next_request_id: AtomicI64::new(1),
            pending: Mutex::new(VecDeque::new()),
            responses: Mutex::new(HashMap::new()),
            waker: Mutex::new(None),
        })
    }

    fn attach_waker(&self, waker: Arc<volvoxgrid_engine::Waker>) {
        *self.waker.lock().unwrap_or_else(|e| e.into_inner()) = Some(waker);
    }

    fn notify_waker(&self) {
        if let Some(w) = self
            .waker
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .as_ref()
        {
            w.wake();
        }
    }

    fn compare(&self, row1: i32, row2: i32, col: i32, timeout: Option<Duration>) -> Option<i32> {
        let request_id = self.next_request_id.fetch_add(1, Ordering::Relaxed);
        let (response_tx, response_rx) = mpsc::channel();
        self.responses
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(request_id, response_tx);

        self.pending
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .push_back(PendingCompare {
                request_id,
                row1,
                row2,
                col,
            });
        self.notify_waker();

        let received = match timeout {
            Some(timeout) => response_rx.recv_timeout(timeout),
            None => response_rx
                .recv()
                .map_err(|_| mpsc::RecvTimeoutError::Disconnected),
        };

        match received {
            Ok(result) => Some(result.signum()),
            Err(mpsc::RecvTimeoutError::Timeout) => {
                self.responses
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .remove(&request_id);
                panic::panic_any(CompareAbort::Timeout);
            }
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                self.responses
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .remove(&request_id);
                panic::panic_any(CompareAbort::Cancelled);
            }
        }
    }

    fn cancel(&self) {
        self.responses
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clear();
        self.pending
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clear();
        self.notify_waker();
    }

    fn drain_pending(&self) -> Vec<PendingCompare> {
        let mut q = self.pending.lock().unwrap_or_else(|e| e.into_inner());
        q.drain(..).collect()
    }

    fn deliver_response(&self, request_id: i64, result: i32) -> bool {
        let response_tx = self
            .responses
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(&request_id);
        response_tx
            .map(|tx| tx.send(result.signum()).is_ok())
            .unwrap_or(false)
    }
}

#[derive(Clone, Debug)]
enum PendingAction {
    BeginEdit {
        row: i32,
        col: i32,
        force: bool,
        prefer_combo: bool,
        seed_text: Option<String>,
        click_caret: Option<i32>,
        caret_end: Option<bool>,
    },
    BeforeDropdownOpen {
        row: i32,
        col: i32,
        force: bool,
        prefer_combo: bool,
        seed_text: Option<String>,
        click_caret: Option<i32>,
        caret_end: Option<bool>,
    },
    ValidateEdit {
        row: i32,
        col: i32,
        old_text: String,
        committed_text: String,
    },
    ToggleCheckbox {
        row: i32,
        col: i32,
    },
    BeforeSort {
        col: i32,
    },
    BeforeNodeToggle {
        row: i32,
        collapse: bool,
    },
    BeforeUserResize {
        row: i32,
        col: i32,
        start_pos: f32,
    },
    BeforeMoveColumn {
        col: i32,
        new_position: i32,
    },
    BeforeMoveRow {
        row: i32,
        new_position: i32,
    },
    BeforeMouseDown {
        x: f32,
        y: f32,
        button: i32,
        modifier: i32,
        dbl_click: bool,
    },
    BeforeScroll {
        delta_x: f32,
        delta_y: f32,
    },
}

#[derive(Clone, Debug)]
struct PendingActionEntry {
    created_at: Instant,
    action: PendingAction,
}

#[derive(Clone, Debug)]
struct ZoomGestureState {
    cumulative_scale: f64,
    base_zoom_scale: f64,
    applied_scale: f64,
    defer_updates: bool,
    allow_preview_updates: bool,
    last_apply_at: Instant,
    base_default_row_height: i32,
    base_default_col_width: i32,
    base_row_heights: Vec<(i32, i32)>,
    base_col_widths: Vec<(i32, i32)>,
    base_col_top_default_row_height: i32,
    base_col_top_row_defs: Vec<(i32, i32)>,
    base_col_bottom_default_row_height: i32,
    base_col_bottom_row_defs: Vec<(i32, i32)>,
    base_cell_padding: volvoxgrid_engine::style::Padding,
    base_fixed_cell_padding: volvoxgrid_engine::style::Padding,
    base_column_paddings: Vec<(
        i32,
        Option<volvoxgrid_engine::style::Padding>,
        Option<volvoxgrid_engine::style::Padding>,
    )>,
    base_cell_style_metrics: Vec<(
        (i32, i32),
        Option<f32>,
        Option<volvoxgrid_engine::style::Padding>,
    )>,
    base_font_size: Option<f32>,
}

impl VolvoxGridRuntime {
    fn new() -> Self {
        Self {
            next_event_id: AtomicI64::new(1),
            decision_enabled: Mutex::new(HashSet::new()),
            pending_actions: Mutex::new(HashMap::new()),
            zoom_levels: Mutex::new(HashMap::new()),
            loaded_font_data: Mutex::new(Vec::new()),
        }
    }

    fn manager(&self) -> &'static GridManager {
        &SHARED_GRID_MANAGER
    }

    fn with_grid<T>(
        &self,
        id: i64,
        f: impl FnOnce(&mut volvoxgrid_engine::grid::VolvoxGrid) -> T,
    ) -> RuntimeResult<T> {
        self.manager().with_grid(id, f).map_err(map_runtime_error)
    }

    fn with_grid_result<T>(
        &self,
        id: i64,
        f: impl FnOnce(&mut volvoxgrid_engine::grid::VolvoxGrid) -> Result<T, String>,
    ) -> RuntimeResult<T> {
        self.manager()
            .with_grid(id, f)
            .map_err(map_runtime_error)?
            .map_err(map_runtime_error)
    }

    fn with_grid_tree<T>(
        &self,
        id: i64,
        f: impl FnOnce(&mut volvoxgrid_engine::grid::VolvoxGrid) -> T,
    ) -> TreeRuntimeResult<T> {
        self.manager()
            .with_grid(id, f)
            .map_err(tree_map_runtime_error)
    }

    fn with_grid_tree_result<T, E: ToString>(
        &self,
        id: i64,
        f: impl FnOnce(&mut volvoxgrid_engine::grid::VolvoxGrid) -> Result<T, E>,
    ) -> TreeRuntimeResult<T> {
        self.manager()
            .with_grid(id, f)
            .map_err(tree_map_runtime_error)?
            .map_err(|err| tree_map_runtime_error(err.to_string()))
    }

    fn sync_fonts_into_renderer(
        &self,
        renderer: &mut volvoxgrid_engine::render::Renderer,
        applied_count: &mut usize,
    ) {
        let fonts = self
            .loaded_font_data
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        if *applied_count > fonts.len() {
            *applied_count = 0;
        }
        for data in &fonts[*applied_count..] {
            renderer.load_font_data(data.clone());
        }
        *applied_count = fonts.len();
    }

    #[cfg(feature = "gpu")]
    fn sync_fonts_into_gpu_renderer(
        &self,
        renderer: &mut volvoxgrid_engine::gpu_render::GpuRenderer,
        applied_count: &mut usize,
    ) {
        let fonts = self
            .loaded_font_data
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        if *applied_count > fonts.len() {
            *applied_count = 0;
        }
        for data in &fonts[*applied_count..] {
            renderer.load_font_data(data.clone());
        }
        *applied_count = fonts.len();
    }
}

/// Ensure layout is valid, rebuilding if necessary.
fn ensure_layout(grid: &mut volvoxgrid_engine::grid::VolvoxGrid) {
    grid.ensure_layout();
}

/// Block on an async future using pollster (for GPU renderer initialization).
#[cfg(feature = "gpu")]
fn pollster_block<F: std::future::Future>(f: F) -> F::Output {
    pollster::block_on(f)
}

// ---------------------------------------------------------------------------
// Zoom helpers
// ---------------------------------------------------------------------------

fn clamp_row_height_for_zoom(grid: &volvoxgrid_engine::grid::VolvoxGrid, height: i32) -> i32 {
    let mut h = height.max(1);
    if grid.row_height_min > 0 && h < grid.row_height_min {
        h = grid.row_height_min;
    }
    if grid.row_height_max > 0 && h > grid.row_height_max {
        h = grid.row_height_max;
    }
    h
}

const LARGE_GRID_ZOOM_DEFER_ROWS: i32 = 200_000;
const ULTRA_LARGE_GRID_NO_PREVIEW_ROWS: i32 = 800_000;
const LARGE_GRID_ZOOM_APPLY_INTERVAL: Duration = Duration::from_millis(80);
const LARGE_GRID_ZOOM_MIN_DELTA: f64 = 0.03;
const LARGE_GRID_ZOOM_FORCE_DELTA: f64 = 0.08;
const ZOOM_STEP_NOISE_EPSILON: f64 = 0.002;
const ZOOM_FONT_SIZE_STEP: f32 = 0.25;
const ZOOM_MIN_SCALE: f64 = 0.25;
const ZOOM_MAX_SCALE: f64 = 4.0;
const ZOOM_STEP_MIN_SCALE: f64 = 1.0 / 32.0;
const ZOOM_STEP_MAX_SCALE: f64 = 32.0;
const ZOOM_RESTORE_EPSILON: f64 = 0.03;
const ZOOM_GESTURE_MIN_SCALE: f64 = 1.0e-6;
const ZOOM_GESTURE_MAX_SCALE: f64 = 1.0e6;

fn has_uniform_zoom_layout(grid: &volvoxgrid_engine::grid::VolvoxGrid) -> bool {
    grid.row_heights.is_empty()
        && grid.col_widths.is_empty()
        && grid.rows_hidden.is_empty()
        && grid.cols_hidden.is_empty()
        && grid.col_width_min.is_empty()
        && grid.col_width_max.is_empty()
}

fn should_defer_zoom_updates(grid: &volvoxgrid_engine::grid::VolvoxGrid, rows: i32) -> bool {
    rows >= LARGE_GRID_ZOOM_DEFER_ROWS && !has_uniform_zoom_layout(grid)
}

fn allow_zoom_preview_updates(grid: &volvoxgrid_engine::grid::VolvoxGrid, rows: i32) -> bool {
    if rows < ULTRA_LARGE_GRID_NO_PREVIEW_ROWS {
        return true;
    }
    has_uniform_zoom_layout(grid)
}

fn zoom_relative_delta(current_scale: f64, applied_scale: f64) -> f64 {
    if !current_scale.is_finite()
        || !applied_scale.is_finite()
        || current_scale <= 0.0
        || applied_scale <= 0.0
    {
        return f64::INFINITY;
    }
    ((current_scale / applied_scale) - 1.0).abs()
}

fn clamp_zoom_scale(scale: f64) -> f64 {
    if !scale.is_finite() || scale <= 0.0 {
        1.0
    } else {
        scale.clamp(ZOOM_MIN_SCALE, ZOOM_MAX_SCALE)
    }
}

fn clamp_zoom_gesture_scale(scale: f64) -> f64 {
    if !scale.is_finite() || scale <= 0.0 {
        1.0
    } else {
        scale.clamp(ZOOM_GESTURE_MIN_SCALE, ZOOM_GESTURE_MAX_SCALE)
    }
}

fn snap_zoom_restore_scale(scale: f64) -> f64 {
    if (scale - 1.0).abs() <= ZOOM_RESTORE_EPSILON {
        1.0
    } else {
        clamp_zoom_scale(scale)
    }
}

fn quantize_zoom_font_size(size: f32) -> f32 {
    let step = ZOOM_FONT_SIZE_STEP.max(0.001);
    (size / step).round() * step
}

fn scale_indicator_extent_for_zoom(extent: i32, scale: f32) -> i32 {
    ((extent as f32) * scale).round() as i32
}

fn indicator_row_defs_equal(
    current: &[volvoxgrid_engine::indicator::ColIndicatorRowDefState],
    next: &[volvoxgrid_engine::indicator::ColIndicatorRowDefState],
) -> bool {
    current.len() == next.len()
        && current
            .iter()
            .zip(next.iter())
            .all(|(a, b)| a.index == b.index && a.height_px == b.height_px)
}

fn scale_padding_for_zoom(
    padding: volvoxgrid_engine::style::Padding,
    scale: f32,
) -> volvoxgrid_engine::style::Padding {
    volvoxgrid_engine::style::Padding {
        left: ((padding.left as f32) * scale).round() as i32,
        top: ((padding.top as f32) * scale).round() as i32,
        right: ((padding.right as f32) * scale).round() as i32,
        bottom: ((padding.bottom as f32) * scale).round() as i32,
    }
    .clamped_non_negative()
}

fn capture_zoom_state(
    grid: &volvoxgrid_engine::grid::VolvoxGrid,
    defer_updates: bool,
    allow_preview_updates: bool,
    base_zoom_scale: f64,
) -> ZoomGestureState {
    let base_zoom_scale = snap_zoom_restore_scale(clamp_zoom_scale(base_zoom_scale));
    ZoomGestureState {
        cumulative_scale: 1.0,
        base_zoom_scale,
        applied_scale: base_zoom_scale,
        defer_updates,
        allow_preview_updates,
        last_apply_at: Instant::now(),
        base_default_row_height: grid.default_row_height,
        base_default_col_width: grid.default_col_width,
        base_row_heights: grid.row_heights.iter().map(|(r, h)| (*r, *h)).collect(),
        base_col_widths: grid.col_widths.iter().map(|(c, w)| (*c, *w)).collect(),
        base_col_top_default_row_height: grid.indicator_bands.col_top.default_row_height_px,
        base_col_top_row_defs: grid
            .indicator_bands
            .col_top
            .row_defs
            .iter()
            .map(|row| (row.index, row.height_px))
            .collect(),
        base_col_bottom_default_row_height: grid.indicator_bands.col_bottom.default_row_height_px,
        base_col_bottom_row_defs: grid
            .indicator_bands
            .col_bottom
            .row_defs
            .iter()
            .map(|row| (row.index, row.height_px))
            .collect(),
        base_cell_padding: grid.style.cell_padding,
        base_fixed_cell_padding: grid.style.fixed_cell_padding,
        base_column_paddings: grid
            .columns
            .iter()
            .enumerate()
            .filter_map(|(index, column)| {
                if column.cell_padding.is_none() && column.fixed_cell_padding.is_none() {
                    None
                } else {
                    Some((index as i32, column.cell_padding, column.fixed_cell_padding))
                }
            })
            .collect(),
        base_cell_style_metrics: grid
            .cell_styles
            .iter()
            .filter_map(|(&(row, col), style)| {
                if style.font_size.is_none() && style.padding.is_none() {
                    None
                } else {
                    Some(((row, col), style.font_size, style.padding))
                }
            })
            .collect(),
        base_font_size: if grid.style.font_size > 0.0 {
            Some(grid.style.font_size)
        } else {
            None
        },
    }
}

fn apply_zoom_scale(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    state: &ZoomGestureState,
    cumulative_scale: f64,
) -> bool {
    if !cumulative_scale.is_finite() || cumulative_scale <= 0.0 {
        return false;
    }
    let scale = cumulative_scale.clamp(ZOOM_MIN_SCALE, ZOOM_MAX_SCALE) as f32;
    let mut changed = false;

    let scaled_default_row = ((state.base_default_row_height as f32) * scale).round() as i32;
    let next_default_row = clamp_row_height_for_zoom(grid, scaled_default_row);
    if grid.default_row_height != next_default_row {
        grid.default_row_height = next_default_row;
        changed = true;
    }

    let scaled_default_col = ((state.base_default_col_width as f32) * scale).round() as i32;
    let next_default_col = scaled_default_col.max(1);
    if grid.default_col_width != next_default_col {
        grid.default_col_width = next_default_col;
        changed = true;
    }

    let next_col_top_default_row =
        scale_indicator_extent_for_zoom(state.base_col_top_default_row_height, scale).max(1);
    if grid.indicator_bands.col_top.default_row_height_px != next_col_top_default_row {
        grid.indicator_bands.col_top.default_row_height_px = next_col_top_default_row;
        changed = true;
    }
    let next_col_top_row_defs = state
        .base_col_top_row_defs
        .iter()
        .map(
            |(index, height_px)| volvoxgrid_engine::indicator::ColIndicatorRowDefState {
                index: *index,
                height_px: scale_indicator_extent_for_zoom(*height_px, scale).max(1),
            },
        )
        .collect::<Vec<_>>();
    if !indicator_row_defs_equal(
        &grid.indicator_bands.col_top.row_defs,
        &next_col_top_row_defs,
    ) {
        grid.indicator_bands.col_top.row_defs = next_col_top_row_defs;
        changed = true;
    }

    let next_col_bottom_default_row =
        scale_indicator_extent_for_zoom(state.base_col_bottom_default_row_height, scale).max(1);
    if grid.indicator_bands.col_bottom.default_row_height_px != next_col_bottom_default_row {
        grid.indicator_bands.col_bottom.default_row_height_px = next_col_bottom_default_row;
        changed = true;
    }
    let next_col_bottom_row_defs = state
        .base_col_bottom_row_defs
        .iter()
        .map(
            |(index, height_px)| volvoxgrid_engine::indicator::ColIndicatorRowDefState {
                index: *index,
                height_px: scale_indicator_extent_for_zoom(*height_px, scale).max(1),
            },
        )
        .collect::<Vec<_>>();
    if !indicator_row_defs_equal(
        &grid.indicator_bands.col_bottom.row_defs,
        &next_col_bottom_row_defs,
    ) {
        grid.indicator_bands.col_bottom.row_defs = next_col_bottom_row_defs;
        changed = true;
    }

    let next_cell_padding = scale_padding_for_zoom(state.base_cell_padding, scale);
    if grid.style.cell_padding != next_cell_padding {
        grid.style.cell_padding = next_cell_padding;
        changed = true;
    }

    let next_fixed_padding = scale_padding_for_zoom(state.base_fixed_cell_padding, scale);
    if grid.style.fixed_cell_padding != next_fixed_padding {
        grid.style.fixed_cell_padding = next_fixed_padding;
        changed = true;
    }

    let mut row_map_changed = grid.row_heights.len() != state.base_row_heights.len();
    if !row_map_changed {
        for (row, base_h) in &state.base_row_heights {
            let scaled_h = ((*base_h as f32) * scale).round() as i32;
            let next_h = clamp_row_height_for_zoom(grid, scaled_h);
            if grid.row_heights.get(row).copied().unwrap_or(i32::MIN) != next_h {
                row_map_changed = true;
                break;
            }
        }
    }
    if row_map_changed {
        grid.row_heights.clear();
        for (row, h) in &state.base_row_heights {
            let scaled_h = ((*h as f32) * scale).round() as i32;
            grid.row_heights
                .insert(*row, clamp_row_height_for_zoom(grid, scaled_h));
        }
        changed = true;
    }

    let mut col_map_changed = grid.col_widths.len() != state.base_col_widths.len();
    if !col_map_changed {
        for (col, base_w) in &state.base_col_widths {
            let scaled_w = ((*base_w as f32) * scale).round() as i32;
            let next_w = grid.clamp_col_width(*col, scaled_w.max(1));
            if grid.col_widths.get(col).copied().unwrap_or(i32::MIN) != next_w {
                col_map_changed = true;
                break;
            }
        }
    }
    if col_map_changed {
        grid.col_widths.clear();
        for (col, w) in &state.base_col_widths {
            let scaled_w = ((*w as f32) * scale).round() as i32;
            grid.col_widths
                .insert(*col, grid.clamp_col_width(*col, scaled_w.max(1)));
        }
        changed = true;
    }

    for (col, base_padding, base_fixed_padding) in &state.base_column_paddings {
        let Some(column) = grid.columns.get_mut(*col as usize) else {
            continue;
        };
        let next_padding = base_padding.map(|padding| scale_padding_for_zoom(padding, scale));
        if column.cell_padding != next_padding {
            column.cell_padding = next_padding;
            changed = true;
        }
        let next_fixed_padding =
            base_fixed_padding.map(|padding| scale_padding_for_zoom(padding, scale));
        if column.fixed_cell_padding != next_fixed_padding {
            column.fixed_cell_padding = next_fixed_padding;
            changed = true;
        }
    }

    for ((row, col), base_font_size, base_padding) in &state.base_cell_style_metrics {
        let Some(style) = grid.cell_styles.get_mut(&(*row, *col)) else {
            continue;
        };
        if let Some(base_font_size) = base_font_size {
            let next_font_size = if (scale - 1.0).abs() <= ZOOM_RESTORE_EPSILON as f32 {
                base_font_size.clamp(4.0, 128.0)
            } else {
                quantize_zoom_font_size((base_font_size * scale).clamp(4.0, 128.0))
            };
            if style
                .font_size
                .map(|value| (value - next_font_size).abs() > 0.001)
                .unwrap_or(true)
            {
                style.font_size = Some(next_font_size);
                changed = true;
            }
        }
        if let Some(base_padding) = base_padding {
            let next_padding = scale_padding_for_zoom(*base_padding, scale);
            if style.padding != Some(next_padding) {
                style.padding = Some(next_padding);
                changed = true;
            }
        }
    }

    if let Some(base_font_size) = state.base_font_size {
        let next_font_size = if (scale - 1.0).abs() <= ZOOM_RESTORE_EPSILON as f32 {
            base_font_size.clamp(4.0, 128.0)
        } else {
            quantize_zoom_font_size((base_font_size * scale).clamp(4.0, 128.0))
        };
        if (grid.style.font_size - next_font_size).abs() > 0.001 {
            grid.style.font_size = next_font_size;
            changed = true;
        }
    }

    if changed {
        grid.scroll.stop_fling();
        grid.layout.invalidate();
        grid.mark_dirty();
    }
    changed
}

#[cfg(test)]
mod tests {
    use super::{
        apply_zoom_scale, capture_zoom_state, cell_screen_rect, ensure_layout,
        should_request_pointer_header_sort, with_tui_pointer_geometry, RuntimeStream,
        RuntimeStreamBidi, RuntimeStreamReceiver, RuntimeStreamSender, VolvoxGridRuntime,
        VolvoxGridServiceRuntime,
    };
    use std::collections::{HashMap, HashSet};
    use std::sync::{
        atomic::{AtomicBool, Ordering},
        mpsc, Arc, Mutex,
    };
    use std::time::{Duration, Instant};
    use volvoxgrid_engine::event::GridEventData;
    use volvoxgrid_engine::grid::VolvoxGrid;
    use volvoxgrid_engine::input::{HitArea, HitTestResult};
    use volvoxgrid_engine::proto::volvoxgrid::v1 as pb;
    use volvoxgrid_engine::style::{CellStylePatch, Padding};

    struct AutoCompareEventStream {
        runtime: Arc<VolvoxGridRuntime>,
        grid_id: i64,
        compare: Arc<dyn Fn(&pb::CompareEvent) -> i32 + Send + Sync>,
        events: Mutex<Vec<pb::GridEvent>>,
        cancelled: AtomicBool,
        cancel_callbacks: Mutex<Vec<Box<dyn FnOnce() + Send + 'static>>>,
    }

    impl AutoCompareEventStream {
        fn new(
            runtime: Arc<VolvoxGridRuntime>,
            grid_id: i64,
            compare: Arc<dyn Fn(&pb::CompareEvent) -> i32 + Send + Sync>,
        ) -> Self {
            Self {
                runtime,
                grid_id,
                compare,
                events: Mutex::new(Vec::new()),
                cancelled: AtomicBool::new(false),
                cancel_callbacks: Mutex::new(Vec::new()),
            }
        }

        fn cancel(&self) {
            let callbacks: Vec<Box<dyn FnOnce() + Send + 'static>> = {
                let mut guard = self
                    .cancel_callbacks
                    .lock()
                    .unwrap_or_else(|e| e.into_inner());
                self.cancelled.store(true, Ordering::SeqCst);
                std::mem::take(&mut *guard)
            };
            for cb in callbacks {
                cb();
            }
        }
    }

    #[derive(Default)]
    struct TestRenderStream {
        outputs: Mutex<Vec<pb::RenderOutput>>,
    }

    impl RuntimeStream for TestRenderStream {
        fn is_cancelled(&self) -> bool {
            false
        }
    }

    impl RuntimeStreamSender<pb::RenderOutput> for TestRenderStream {
        fn send(&self, msg: pb::RenderOutput) -> bool {
            self.outputs
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .push(msg);
            true
        }
    }

    impl RuntimeStreamReceiver<pb::RenderInput> for TestRenderStream {
        fn recv(&self) -> Option<pb::RenderInput> {
            None
        }
    }

    impl RuntimeStreamBidi<pb::RenderInput, pb::RenderOutput> for TestRenderStream {}

    impl RuntimeStream for AutoCompareEventStream {
        fn is_cancelled(&self) -> bool {
            self.cancelled.load(Ordering::SeqCst)
        }

        fn on_cancel(&self, cb: Box<dyn FnOnce() + Send + 'static>) {
            let mut guard = self
                .cancel_callbacks
                .lock()
                .unwrap_or_else(|e| e.into_inner());
            if self.cancelled.load(Ordering::SeqCst) {
                drop(guard);
                cb();
            } else {
                guard.push(cb);
            }
        }
    }

    impl RuntimeStreamSender<pb::GridEvent> for AutoCompareEventStream {
        fn send(&self, msg: pb::GridEvent) -> bool {
            if self.is_cancelled() {
                return false;
            }
            if let Some(pb::grid_event::Event::Compare(compare)) = msg.event.as_ref() {
                let result = (self.compare)(compare);
                self.runtime
                    .deliver_compare_response(self.grid_id, compare.request_id, result);
            }
            self.events
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .push(msg);
            true
        }
    }

    fn runtime_with_decision_grid(rows: i32, cols: i32) -> (VolvoxGridRuntime, i64) {
        let runtime = VolvoxGridRuntime::new();
        let grid_id = runtime
            .manager()
            .create_grid(320, 160, rows, cols, 1, 0, 1.0);
        runtime.mark_decision_channel_enabled(grid_id);
        (runtime, grid_id)
    }

    fn take_pending_event_id<F>(grid: &mut VolvoxGrid, pred: F) -> i64
    where
        F: Fn(&GridEventData) -> bool,
    {
        let events = grid.events.drain();
        let event_id = events
            .iter()
            .find_map(|event| pred(&event.data).then_some(event.event_id))
            .expect("expected pending event");
        assert!(event_id > 0, "cancelable event must have event_id");
        event_id
    }

    fn request_pending_event_id<F, R>(
        runtime: &VolvoxGridRuntime,
        grid_id: i64,
        request: R,
        pred: F,
    ) -> i64
    where
        F: Fn(&GridEventData) -> bool,
        R: FnOnce(&VolvoxGridRuntime, i64, &mut VolvoxGrid),
    {
        runtime
            .with_grid(grid_id, |grid| {
                request(runtime, grid_id, grid);
                take_pending_event_id(grid, pred)
            })
            .expect("grid exists")
    }

    fn configure_checkbox_cell(grid: &mut VolvoxGrid, row: i32, col: i32, checked: bool) {
        grid.edit_trigger_mode = 1;
        grid.columns[col as usize].data_type = pb::ColumnDataType::ColumnDataBoolean as i32;
        grid.cells
            .set_text(row, col, if checked { "Yes" } else { "No" }.to_string());
        let cell = grid.cells.get_mut(row, col);
        let extra = cell.extra_mut();
        extra.value = volvoxgrid_engine::cell::CellValueData::Bool(checked);
        extra.checked = if checked {
            pb::CheckedState::CheckedChecked as i32
        } else {
            pb::CheckedState::CheckedUnchecked as i32
        };
    }

    fn destroy_test_grid(runtime: &VolvoxGridRuntime, grid_id: i64) {
        runtime.clear_grid_state(grid_id);
        runtime.manager().destroy_grid(grid_id);
    }

    fn wait_for_grid<F>(runtime: &VolvoxGridRuntime, grid_id: i64, mut pred: F)
    where
        F: FnMut(&mut VolvoxGrid) -> bool,
    {
        let start = Instant::now();
        loop {
            if runtime
                .with_grid(grid_id, |grid| pred(grid))
                .expect("grid exists")
            {
                return;
            }
            assert!(
                start.elapsed() < Duration::from_secs(2),
                "timed out waiting for grid condition"
            );
            std::thread::sleep(Duration::from_millis(10));
        }
    }

    #[test]
    fn compare_event_stream_emits_while_grid_lock_is_held() {
        let runtime = Arc::new(VolvoxGridRuntime::new());
        let grid_id = runtime.manager().create_grid(320, 160, 3, 1, 1, 0, 1.0);
        let mut session_grid_ids = HashSet::new();
        runtime.register_render_session_grid(grid_id, &mut session_grid_ids);
        let compare = VolvoxGridRuntime::install_compare_channel(grid_id, None)
            .expect("compare channel should install with an active render session");
        let grid_arc = runtime.manager().get_grid(grid_id).expect("grid exists");
        let grid_guard = grid_arc.lock().unwrap_or_else(|e| e.into_inner());
        let stream = AutoCompareEventStream::new(Arc::clone(&runtime), grid_id, Arc::new(|_| -1));

        std::thread::scope(|scope| {
            let runtime_for_stream = Arc::clone(&runtime);
            let stream_ref = &stream;
            let handle = scope.spawn(move || {
                runtime_for_stream
                    .event_stream(pb::EventStreamRequest { grid_id }, stream_ref)
                    .expect("event stream should exit cleanly");
            });

            std::thread::sleep(Duration::from_millis(30));
            let result = compare(2, 1, 0);
            stream.cancel();
            drop(grid_guard);
            handle.join().expect("event stream thread should not panic");

            assert_eq!(result, Some(-1));
        });

        let events = stream.events.lock().unwrap_or_else(|e| e.into_inner());
        assert!(events.iter().any(|event| matches!(
            event.event.as_ref(),
            Some(pb::grid_event::Event::Compare(_))
        )));
        drop(events);
        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn sort_custom_uses_compare_event_stream_responses() {
        let runtime = Arc::new(VolvoxGridRuntime::new());
        let grid_id = runtime.manager().create_grid(320, 160, 6, 1, 1, 0, 1.0);
        let values = ["dddd", "a", "ccc", "bb", "eeeee"];
        let mut lengths = HashMap::new();
        runtime
            .with_grid(grid_id, |grid| {
                for (i, value) in values.iter().enumerate() {
                    let row = (i as i32) + 1;
                    grid.cells.set_text(row, 0, (*value).to_string());
                    lengths.insert(row, value.len());
                }
            })
            .unwrap();

        let mut session_grid_ids = HashSet::new();
        runtime.register_render_session_grid(grid_id, &mut session_grid_ids);
        let compare_lengths = Arc::new(lengths);
        let stream = AutoCompareEventStream::new(
            Arc::clone(&runtime),
            grid_id,
            Arc::new(move |event| {
                let a = compare_lengths
                    .get(&event.row1)
                    .copied()
                    .unwrap_or_default();
                let b = compare_lengths
                    .get(&event.row2)
                    .copied()
                    .unwrap_or_default();
                match a.cmp(&b) {
                    std::cmp::Ordering::Less => -1,
                    std::cmp::Ordering::Equal => 0,
                    std::cmp::Ordering::Greater => 1,
                }
            }),
        );

        std::thread::scope(|scope| {
            let runtime_for_stream = Arc::clone(&runtime);
            let stream_ref = &stream;
            let handle = scope.spawn(move || {
                runtime_for_stream
                    .event_stream(pb::EventStreamRequest { grid_id }, stream_ref)
                    .expect("event stream should exit cleanly");
            });

            runtime
                .sort(pb::SortRequest {
                    grid_id,
                    sort_columns: vec![pb::SortColumn {
                        col: 0,
                        order: Some(pb::SortOrder::SortAscending as i32),
                        r#type: Some(pb::SortType::Custom as i32),
                    }],
                })
                .expect("custom sort should complete");
            stream.cancel();
            handle.join().expect("event stream thread should not panic");
        });

        runtime
            .with_grid(grid_id, |grid| {
                let got: Vec<String> = (1..=5)
                    .map(|row| grid.cells.get_text(row, 0).to_string())
                    .collect();
                assert_eq!(got, vec!["a", "bb", "ccc", "dddd", "eeeee"]);
            })
            .unwrap();

        let compare_count = stream
            .events
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .iter()
            .filter(|event| {
                matches!(
                    event.event.as_ref(),
                    Some(pb::grid_event::Event::Compare(_))
                )
            })
            .count();
        assert!(
            compare_count > 0,
            "custom sort must ask the host to compare"
        );
        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn header_click_custom_uses_compare_event_stream_responses() {
        let runtime = Arc::new(VolvoxGridRuntime::new());
        let grid_id = runtime.manager().create_grid(320, 160, 6, 1, 1, 0, 1.0);
        let values = ["dddd", "a", "ccc", "bb", "eeeee"];
        let mut lengths = HashMap::new();
        runtime
            .with_grid(grid_id, |grid| {
                grid.header_features = 1;
                grid.columns[0].sort_order = volvoxgrid_engine::sort::SORT_ASCENDING_CUSTOM;
                grid.columns[0].sort_defined = true;
                for (i, value) in values.iter().enumerate() {
                    let row = (i as i32) + 1;
                    grid.cells.set_text(row, 0, (*value).to_string());
                    lengths.insert(row, value.len());
                }
            })
            .unwrap();

        let mut session_grid_ids = HashSet::new();
        runtime.register_render_session_grid(grid_id, &mut session_grid_ids);
        let compare_lengths = Arc::new(lengths);
        let stream = AutoCompareEventStream::new(
            Arc::clone(&runtime),
            grid_id,
            Arc::new(move |event| {
                let a = compare_lengths
                    .get(&event.row1)
                    .copied()
                    .unwrap_or_default();
                let b = compare_lengths
                    .get(&event.row2)
                    .copied()
                    .unwrap_or_default();
                match a.cmp(&b) {
                    std::cmp::Ordering::Less => -1,
                    std::cmp::Ordering::Equal => 0,
                    std::cmp::Ordering::Greater => 1,
                }
            }),
        );

        std::thread::scope(|scope| {
            let runtime_for_stream = Arc::clone(&runtime);
            let stream_ref = &stream;
            let handle = scope.spawn(move || {
                runtime_for_stream
                    .event_stream(pb::EventStreamRequest { grid_id }, stream_ref)
                    .expect("event stream should exit cleanly");
            });

            runtime
                .with_grid(grid_id, |grid| {
                    runtime.request_before_sort(grid_id, grid, 0)
                })
                .expect("header custom sort should complete");
            wait_for_grid(&runtime, grid_id, |grid| {
                (1..=5)
                    .map(|row| grid.cells.get_text(row, 0).to_string())
                    .collect::<Vec<_>>()
                    == vec!["a", "bb", "ccc", "dddd", "eeeee"]
            });
            stream.cancel();
            handle.join().expect("event stream thread should not panic");
        });

        runtime
            .with_grid(grid_id, |grid| {
                let got: Vec<String> = (1..=5)
                    .map(|row| grid.cells.get_text(row, 0).to_string())
                    .collect();
                assert_eq!(got, vec!["a", "bb", "ccc", "dddd", "eeeee"]);
                assert_eq!(
                    grid.sort_state.sort_keys,
                    vec![(0, volvoxgrid_engine::sort::SORT_ASCENDING_CUSTOM)]
                );
            })
            .unwrap();

        let compare_count = stream
            .events
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .iter()
            .filter(|event| {
                matches!(
                    event.event.as_ref(),
                    Some(pb::grid_event::Event::Compare(_))
                )
            })
            .count();
        assert!(
            compare_count > 0,
            "header custom sort must ask the host to compare"
        );
        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn header_sort_snapshot_matches_engine_for_clean_custom_grid() {
        let runtime = VolvoxGridRuntime::new();
        let grid_id = runtime.manager().create_grid(320, 160, 6, 1, 1, 0, 1.0);
        let values = ["dddd", "a", "ccc", "bb", "eeeee"];
        let mut lengths = HashMap::new();
        runtime
            .with_grid(grid_id, |grid| {
                grid.header_features = 1;
                grid.columns[0].sort_order = volvoxgrid_engine::sort::SORT_NONE;
                grid.columns[0].sort_type = pb::SortType::Custom as i32;
                grid.columns[0].sort_defined = true;
                for (i, value) in values.iter().enumerate() {
                    let row = (i as i32) + 1;
                    grid.cells.set_text(row, 0, (*value).to_string());
                    lengths.insert(row, value.len());
                }
            })
            .unwrap();

        let lengths = Arc::new(lengths);
        let (order, old_sort_state, old_row_positions) = runtime
            .with_grid(grid_id, |grid| {
                (
                    volvoxgrid_engine::sort::header_click_next_sort_order(grid, 0),
                    grid.sort_state.clone(),
                    grid.row_positions.clone(),
                )
            })
            .unwrap();
        let snapshot_lengths = Arc::clone(&lengths);
        let snapshot = super::HeaderSortSnapshot {
            col: 0,
            order,
            emit_after_sort: true,
            compare: Box::new(move |row1, row2, _col| {
                let a = snapshot_lengths.get(&row1).copied().unwrap_or_default();
                let b = snapshot_lengths.get(&row2).copied().unwrap_or_default();
                Some(match a.cmp(&b) {
                    std::cmp::Ordering::Less => -1,
                    std::cmp::Ordering::Equal => 0,
                    std::cmp::Ordering::Greater => 1,
                })
            }),
            old_sort_state,
            old_row_positions,
            groups: vec![(1..=5).collect::<Vec<i32>>()],
        };

        VolvoxGridRuntime::run_header_sort_snapshot(grid_id, snapshot);
        let (snapshot_order, snapshot_keys) = runtime
            .with_grid(grid_id, |grid| {
                (
                    (1..=5)
                        .map(|row| grid.cells.get_text(row, 0).to_string())
                        .collect::<Vec<_>>(),
                    grid.sort_state.sort_keys.clone(),
                )
            })
            .unwrap();

        let mut engine_grid = VolvoxGrid::new(999, 320, 160, 6, 1, 1, 0);
        engine_grid.header_features = 1;
        engine_grid.columns[0].sort_order = volvoxgrid_engine::sort::SORT_NONE;
        engine_grid.columns[0].sort_type = pb::SortType::Custom as i32;
        engine_grid.columns[0].sort_defined = true;
        for (i, value) in values.iter().enumerate() {
            engine_grid
                .cells
                .set_text((i as i32) + 1, 0, (*value).to_string());
        }
        let engine_lengths = Arc::clone(&lengths);
        engine_grid.custom_compare = Some(Box::new(move |row1, row2, _col| {
            let a = engine_lengths.get(&row1).copied().unwrap_or_default();
            let b = engine_lengths.get(&row2).copied().unwrap_or_default();
            Some(match a.cmp(&b) {
                std::cmp::Ordering::Less => -1,
                std::cmp::Ordering::Equal => 0,
                std::cmp::Ordering::Greater => 1,
            })
        }));
        volvoxgrid_engine::sort::handle_header_click(&mut engine_grid, 0);
        let engine_order = (1..=5)
            .map(|row| engine_grid.cells.get_text(row, 0).to_string())
            .collect::<Vec<_>>();

        assert_eq!(snapshot_order, engine_order);
        assert_eq!(snapshot_keys, engine_grid.sort_state.sort_keys);
        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn header_click_custom_compare_does_not_hold_grid_lock_while_waiting() {
        let runtime = Arc::new(VolvoxGridRuntime::new());
        let grid_id = runtime.manager().create_grid(320, 160, 4, 1, 1, 0, 1.0);
        runtime
            .with_grid(grid_id, |grid| {
                grid.header_features = 1;
                grid.columns[0].sort_order = volvoxgrid_engine::sort::SORT_ASCENDING_CUSTOM;
                grid.columns[0].sort_defined = true;
                grid.cells.set_text(1, 0, "B".to_string());
                grid.cells.set_text(2, 0, "A".to_string());
            })
            .unwrap();

        let mut session_grid_ids = HashSet::new();
        runtime.register_render_session_grid(grid_id, &mut session_grid_ids);
        let (compare_seen_tx, compare_seen_rx) = mpsc::channel();
        let (release_compare_tx, release_compare_rx) = mpsc::channel();
        let release_compare_rx = Arc::new(Mutex::new(release_compare_rx));
        let stream = AutoCompareEventStream::new(
            Arc::clone(&runtime),
            grid_id,
            Arc::new(move |_| {
                let _ = compare_seen_tx.send(());
                let _ = release_compare_rx
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .recv();
                0
            }),
        );

        std::thread::scope(|scope| {
            let runtime_for_stream = Arc::clone(&runtime);
            let stream_ref = &stream;
            let handle = scope.spawn(move || {
                runtime_for_stream
                    .event_stream(pb::EventStreamRequest { grid_id }, stream_ref)
                    .expect("event stream should exit cleanly");
            });

            runtime
                .with_grid(grid_id, |grid| {
                    runtime.request_before_sort(grid_id, grid, 0)
                })
                .expect("header custom sort should schedule");
            compare_seen_rx
                .recv_timeout(Duration::from_secs(1))
                .expect("sort should request host comparison");

            let runtime_for_lock = Arc::clone(&runtime);
            let (lock_tx, lock_rx) = mpsc::channel();
            scope.spawn(move || {
                let _ = runtime_for_lock.with_grid(grid_id, |grid| grid.rows);
                let _ = lock_tx.send(());
            });
            lock_rx
                .recv_timeout(Duration::from_millis(200))
                .expect("grid lock should be available while compare is pending");

            let _ = release_compare_tx.send(());
            wait_for_grid(&runtime, grid_id, |grid| {
                grid.sort_state.sort_keys
                    == vec![(0, volvoxgrid_engine::sort::SORT_ASCENDING_CUSTOM)]
            });
            stream.cancel();
            handle.join().expect("event stream thread should not panic");
        });

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn apply_zoom_scale_scales_padding_and_cell_style_metrics() {
        let mut grid = volvoxgrid_engine::grid::VolvoxGrid::new(1, 320, 200, 2, 2, 0, 0);
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.indicator_bands.col_top.row_defs =
            vec![volvoxgrid_engine::indicator::ColIndicatorRowDefState {
                index: 0,
                height_px: 30,
            }];
        grid.style.cell_padding = Padding {
            left: 6,
            top: 2,
            right: 6,
            bottom: 2,
        };
        grid.style.fixed_cell_padding = Padding {
            left: 8,
            top: 4,
            right: 8,
            bottom: 4,
        };
        grid.columns[0].cell_padding = Some(Padding {
            left: 4,
            top: 2,
            right: 4,
            bottom: 2,
        });
        grid.columns[0].fixed_cell_padding = Some(Padding {
            left: 10,
            top: 4,
            right: 10,
            bottom: 4,
        });
        grid.cell_styles.insert(
            (0, 0),
            CellStylePatch {
                font_size: Some(20.0),
                padding: Some(Padding {
                    left: 3,
                    top: 1,
                    right: 3,
                    bottom: 1,
                }),
                ..Default::default()
            },
        );

        let state = capture_zoom_state(&grid, false, true, 1.0);
        assert!(apply_zoom_scale(&mut grid, &state, 0.5));

        assert_eq!(
            grid.style.cell_padding,
            Padding {
                left: 3,
                top: 1,
                right: 3,
                bottom: 1,
            }
        );
        assert_eq!(
            grid.style.fixed_cell_padding,
            Padding {
                left: 4,
                top: 2,
                right: 4,
                bottom: 2,
            }
        );
        assert_eq!(
            grid.columns[0].cell_padding,
            Some(Padding {
                left: 2,
                top: 1,
                right: 2,
                bottom: 1,
            })
        );
        assert_eq!(
            grid.columns[0].fixed_cell_padding,
            Some(Padding {
                left: 5,
                top: 2,
                right: 5,
                bottom: 2,
            })
        );
        assert_eq!(grid.indicator_bands.col_top.default_row_height_px, 12);
        assert_eq!(grid.indicator_bands.col_top.row_defs[0].height_px, 15);
        let style = grid.cell_styles.get(&(0, 0)).unwrap();
        assert_eq!(style.font_size, Some(10.0));
        assert_eq!(
            style.padding,
            Some(Padding {
                left: 2,
                top: 1,
                right: 2,
                bottom: 1,
            })
        );
    }

    #[test]
    fn tui_top_indicator_header_hit_can_request_sort() {
        let mut grid = volvoxgrid_engine::grid::VolvoxGrid::new(1, 80, 24, 3, 2, 1, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.header_features = 1;

        let hit = HitTestResult {
            row: -1,
            col: 1,
            area: HitArea::IndicatorColTop,
            x_in_cell: 2.0,
            y_in_cell: 0.0,
        };
        assert!(should_request_pointer_header_sort(&grid, &hit, false));

        let border_hit = HitTestResult {
            area: HitArea::ColBorder,
            ..hit.clone()
        };
        assert!(!should_request_pointer_header_sort(
            &grid,
            &border_hit,
            false
        ));

        grid.header_features = 0;
        assert!(!should_request_pointer_header_sort(&grid, &hit, false));
    }

    #[test]
    fn tui_pointer_geometry_aligns_cell_hit_x_with_rendered_row_indicator() {
        let mut grid = VolvoxGrid::new(1, 80, 12, 3, 2, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.set_col_width(0, 28);
        grid.cols_hidden.insert(0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.auto_size = false;
        grid.indicator_bands.row_start.width_px = 44;
        grid.indicator_bands.row_start.slots =
            vec![volvoxgrid_engine::indicator::RowIndicatorSlotState::new(
                pb::RowIndicatorSlotKind::RowIndicatorSlotExpander,
                44,
            )];
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 1;
        grid.outline.tree_indicator = pb::TreeIndicatorStyle::TreeIndicatorConnectorsLeaf as i32;
        grid.outline.label_column = 0;
        grid.outline.max_levels = 3;
        grid.layout.invalidate();
        grid.ensure_layout();

        let rendered_width = volvoxgrid_engine::canvas_tui::tui_row_indicator_width(&grid);
        assert_eq!(rendered_width, 43);
        assert_eq!(grid.indicator_bands.row_start.resolved_width_px(), 44);

        with_tui_pointer_geometry(&mut grid, |grid| {
            assert_eq!(
                grid.indicator_bands.row_start.resolved_width_px(),
                rendered_width
            );
            let translation = volvoxgrid_engine::canvas_tui::translate_tui_mouse_x_for_hit(
                grid,
                80,
                12,
                rendered_width,
            );
            let hit = volvoxgrid_engine::input::hit_test(grid, translation.hit_test_x as f32, 1.0);

            assert_eq!(translation.col, 1);
            assert_eq!(hit.row, 0);
            assert_eq!(hit.col, 1);
            assert_eq!(hit.area, HitArea::Cell);
        });

        assert_eq!(grid.indicator_bands.row_start.resolved_width_px(), 44);
    }

    #[test]
    fn tui_visible_outline_cell_enter_requests_edit_not_node_toggle() {
        let (runtime, grid_id) = runtime_with_decision_grid(3, 2);
        runtime
            .with_grid(grid_id, |grid| {
                grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
                grid.edit_trigger_mode = 1;
                grid.indicator_bands.row_start.visible = true;
                grid.indicator_bands.row_start.auto_size = false;
                grid.indicator_bands.row_start.width_px = 24;
                grid.indicator_bands.row_start.slots =
                    vec![volvoxgrid_engine::indicator::RowIndicatorSlotState::new(
                        pb::RowIndicatorSlotKind::RowIndicatorSlotExpander,
                        24,
                    )];
                grid.outline.tree_indicator =
                    pb::TreeIndicatorStyle::TreeIndicatorConnectorsLeaf as i32;
                grid.outline.label_column = 0;
                grid.cols_hidden.insert(0);
                grid.cells.set_text(1, 0, "Reports".to_string());
                grid.cells.set_text(1, 1, "Folder".to_string());
                grid.row_props.entry(1).or_default().outline_level = 0;
                grid.row_props.entry(2).or_default().outline_level = 1;
                grid.selection.set_cursor(
                    1,
                    1,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
            })
            .unwrap();

        let stream = TestRenderStream::default();
        let mut sent_edit_requests = HashMap::new();
        super::handle_key_render_input(
            &runtime,
            &stream,
            &mut sent_edit_requests,
            grid_id,
            pb::KeyEvent {
                r#type: pb::key_event::Type::KeyDown as i32,
                key_code: 13,
                modifier: 0,
                character: String::new(),
            },
            false,
            None,
        );

        let edit_event_id = runtime
            .with_grid(grid_id, |grid| {
                let events = grid.events.drain();
                assert!(!events
                    .iter()
                    .any(|event| { matches!(event.data, GridEventData::BeforeNodeToggle { .. }) }));
                events
                    .iter()
                    .find_map(|event| {
                        matches!(event.data, GridEventData::BeforeEdit { row: 1, col: 1 })
                            .then_some(event.event_id)
                    })
                    .expect("visible cell Enter should request BeforeEdit")
            })
            .unwrap();

        let _ = runtime.resolve_event_decision(grid_id, edit_event_id, false);
        runtime
            .with_grid(grid_id, |grid| {
                assert!(grid.edit.is_active());
                assert_eq!(grid.edit.edit_row, 1);
                assert_eq!(grid.edit.edit_col, 1);
                assert!(!grid
                    .row_props
                    .get(&1)
                    .is_some_and(|props| props.is_collapsed));
            })
            .unwrap();

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_cancel_and_allow_before_edit() {
        let (runtime, grid_id) = runtime_with_decision_grid(3, 2);

        let cancel_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                let _ =
                    runtime.request_before_edit(grid_id, grid, 1, 0, true, false, None, None, None);
            },
            |event| matches!(event, GridEventData::BeforeEdit { row: 1, col: 0 }),
        );
        let _ = runtime.resolve_event_decision(grid_id, cancel_id, true);
        runtime
            .with_grid(grid_id, |grid| assert!(!grid.edit.is_active()))
            .unwrap();

        let allow_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                let _ =
                    runtime.request_before_edit(grid_id, grid, 1, 0, true, false, None, None, None);
            },
            |event| matches!(event, GridEventData::BeforeEdit { row: 1, col: 0 }),
        );
        let _ = runtime.resolve_event_decision(grid_id, allow_id, false);
        runtime
            .with_grid(grid_id, |grid| {
                assert!(grid.edit.is_active());
                assert_eq!(grid.edit.edit_row, 1);
                assert_eq!(grid.edit.edit_col, 0);
            })
            .unwrap();

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_cancel_and_allow_checkbox_toggle() {
        let (runtime, grid_id) = runtime_with_decision_grid(3, 2);

        runtime
            .with_grid(grid_id, |grid| configure_checkbox_cell(grid, 1, 0, false))
            .unwrap();
        let cancel_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                runtime.request_before_checkbox_toggle(grid_id, grid, 1, 0);
            },
            |event| matches!(event, GridEventData::BeforeEdit { row: 1, col: 0 }),
        );
        let _ = runtime.resolve_event_decision(grid_id, cancel_id, true);
        runtime
            .with_grid(grid_id, |grid| {
                assert_eq!(grid.cells.get_text(1, 0), "No");
                assert_eq!(
                    grid.cells.get(1, 0).map(|cell| cell.checked()),
                    Some(pb::CheckedState::CheckedUnchecked as i32)
                );
                let events = grid.events.drain();
                assert!(!events.iter().any(|event| matches!(
                    event.data,
                    GridEventData::AfterEdit { .. } | GridEventData::CellChanged { .. }
                )));
            })
            .unwrap();

        let allow_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                runtime.request_before_checkbox_toggle(grid_id, grid, 1, 0);
            },
            |event| matches!(event, GridEventData::BeforeEdit { row: 1, col: 0 }),
        );
        let _ = runtime.resolve_event_decision(grid_id, allow_id, false);
        runtime
            .with_grid(grid_id, |grid| {
                assert!(!grid.is_editing());
                assert_eq!(grid.cells.get_text(1, 0), "Yes");
                assert_eq!(
                    grid.cells.get(1, 0).map(|cell| cell.checked()),
                    Some(pb::CheckedState::CheckedChecked as i32)
                );
                let events = grid.events.drain();
                assert!(events.iter().any(|event| matches!(
                    &event.data,
                    GridEventData::AfterEdit {
                        row: 1,
                        col: 0,
                        old_text,
                        new_text,
                    } if old_text.as_str() == "No" && new_text.as_str() == "Yes"
                )));
                assert!(events.iter().any(|event| matches!(
                    &event.data,
                    GridEventData::CellChanged {
                        row: 1,
                        col: 0,
                        old_text,
                        new_text,
                    } if old_text.as_str() == "No" && new_text.as_str() == "Yes"
                )));
                assert!(!events
                    .iter()
                    .any(|event| matches!(event.data, GridEventData::StartEdit { .. })));
            })
            .unwrap();

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_pointer_double_click_on_checkbox_queues_toggle() {
        let (runtime, grid_id) = runtime_with_decision_grid(3, 2);

        let event_id = runtime
            .with_grid(grid_id, |grid| {
                configure_checkbox_cell(grid, 1, 0, false);
                grid.columns[0].alignment = pb::Align::CenterCenter as i32;
                ensure_layout(grid);
                let (x, y, w, h) = cell_screen_rect(grid, 1, 0).expect("cell rect");
                let click_x = x as f32 + w as f32 * 0.5;
                let click_y = y as f32 + h as f32 * 0.5;
                assert_eq!(
                    volvoxgrid_engine::input::hit_test(grid, click_x, click_y).area,
                    volvoxgrid_engine::input::HitArea::CheckBox
                );

                runtime.handle_pointer_down_after_before_mouse(
                    grid_id, grid, click_x, click_y, 0, 0, true,
                );
                take_pending_event_id(grid, |event| {
                    matches!(event, GridEventData::BeforeEdit { row: 1, col: 0 })
                })
            })
            .expect("grid exists");

        let _ = runtime.resolve_event_decision(grid_id, event_id, false);
        runtime
            .with_grid(grid_id, |grid| {
                assert!(!grid.is_editing());
                assert_eq!(grid.cells.get_text(1, 0), "Yes");
                assert_eq!(
                    grid.cells.get(1, 0).map(|cell| cell.checked()),
                    Some(pb::CheckedState::CheckedChecked as i32)
                );
            })
            .unwrap();

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_default_does_not_expire() {
        let (runtime, grid_id) = runtime_with_decision_grid(3, 2);

        let event_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                let _ =
                    runtime.request_before_edit(grid_id, grid, 1, 0, true, false, None, None, None);
            },
            |event| matches!(event, GridEventData::BeforeEdit { row: 1, col: 0 }),
        );
        {
            let mut pending = runtime
                .pending_actions
                .lock()
                .unwrap_or_else(|e| e.into_inner());
            pending
                .get_mut(&(grid_id, event_id))
                .expect("pending action exists")
                .created_at = Instant::now() - Duration::from_secs(60);
        }

        assert!(runtime.resolve_expired_actions(grid_id).is_empty());
        runtime
            .with_grid(grid_id, |grid| assert!(!grid.edit.is_active()))
            .unwrap();
        assert!(runtime
            .pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .contains_key(&(grid_id, event_id)));

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_finite_timeout_emits_error_and_allows() {
        let (runtime, grid_id) = runtime_with_decision_grid(3, 2);
        runtime
            .with_grid(grid_id, |grid| {
                grid.decision_timeout_ms = 100;
            })
            .unwrap();

        let event_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                let _ =
                    runtime.request_before_edit(grid_id, grid, 1, 0, true, false, None, None, None);
            },
            |event| matches!(event, GridEventData::BeforeEdit { row: 1, col: 0 }),
        );
        {
            let mut pending = runtime
                .pending_actions
                .lock()
                .unwrap_or_else(|e| e.into_inner());
            pending
                .get_mut(&(grid_id, event_id))
                .expect("pending action exists")
                .created_at = Instant::now() - Duration::from_millis(250);
        }

        assert!(runtime.resolve_expired_actions(grid_id).is_empty());
        runtime
            .with_grid(grid_id, |grid| {
                assert!(grid.edit.is_active());
                assert_eq!(grid.edit.edit_row, 1);
                assert_eq!(grid.edit.edit_col, 0);
                assert!(grid.events.drain().into_iter().any(|event| {
                    matches!(
                        event.data,
                        GridEventData::Error { code, .. }
                            if code == super::ERROR_DECISION_TIMEOUT
                    )
                }));
            })
            .unwrap();
        assert!(!runtime
            .pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .contains_key(&(grid_id, event_id)));

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_cancel_and_allow_before_sort() {
        let (runtime, grid_id) = runtime_with_decision_grid(3, 1);
        runtime
            .with_grid(grid_id, |grid| {
                grid.header_features = 1;
                grid.cells.set_text(1, 0, "B".to_string());
                grid.cells.set_text(2, 0, "A".to_string());
            })
            .unwrap();

        let cancel_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| runtime.request_before_sort(grid_id, grid, 0),
            |event| matches!(event, GridEventData::BeforeSort { col: 0 }),
        );
        let _ = runtime.resolve_event_decision(grid_id, cancel_id, true);
        runtime
            .with_grid(grid_id, |grid| assert_eq!(grid.cells.get_text(1, 0), "B"))
            .unwrap();

        let allow_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| runtime.request_before_sort(grid_id, grid, 0),
            |event| matches!(event, GridEventData::BeforeSort { col: 0 }),
        );
        let _ = runtime.resolve_event_decision(grid_id, allow_id, false);
        wait_for_grid(&runtime, grid_id, |grid| grid.cells.get_text(1, 0) == "A");

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_cancel_and_allow_before_node_toggle() {
        let (runtime, grid_id) = runtime_with_decision_grid(4, 1);
        runtime
            .with_grid(grid_id, |grid| {
                grid.row_props.entry(1).or_default().outline_level = 0;
                grid.row_props.entry(2).or_default().outline_level = 1;
            })
            .unwrap();

        let cancel_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| runtime.request_before_node_toggle(grid_id, grid, 1, true),
            |event| {
                matches!(
                    event,
                    GridEventData::BeforeNodeToggle {
                        row: 1,
                        collapse: true
                    }
                )
            },
        );
        let _ = runtime.resolve_event_decision(grid_id, cancel_id, true);
        runtime
            .with_grid(grid_id, |grid| {
                assert!(!grid.row_props.get(&1).unwrap().is_collapsed);
                assert!(!grid.rows_hidden.contains(&2));
            })
            .unwrap();

        let allow_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| runtime.request_before_node_toggle(grid_id, grid, 1, true),
            |event| matches!(event, GridEventData::BeforeNodeToggle { row: 1, .. }),
        );
        let _ = runtime.resolve_event_decision(grid_id, allow_id, false);
        runtime
            .with_grid(grid_id, |grid| {
                assert!(grid.row_props.get(&1).unwrap().is_collapsed);
                assert!(grid.rows_hidden.contains(&2));
            })
            .unwrap();

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_cancel_and_allow_before_scroll() {
        let (runtime, grid_id) = runtime_with_decision_grid(40, 2);

        let cancel_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                assert!(runtime.request_before_scroll(grid_id, grid, 0.0, 5.0));
            },
            |event| matches!(event, GridEventData::BeforeScroll { .. }),
        );
        let _ = runtime.resolve_event_decision(grid_id, cancel_id, true);
        runtime
            .with_grid(grid_id, |grid| assert_eq!(grid.scroll.scroll_y, 0.0))
            .unwrap();

        let allow_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                assert!(runtime.request_before_scroll(grid_id, grid, 0.0, 5.0));
            },
            |event| matches!(event, GridEventData::BeforeScroll { .. }),
        );
        let _ = runtime.resolve_event_decision(grid_id, allow_id, false);
        runtime
            .with_grid(grid_id, |grid| assert!(grid.scroll.scroll_y > 0.0))
            .unwrap();

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_cancel_and_allow_before_user_resize() {
        let (runtime, grid_id) = runtime_with_decision_grid(3, 2);
        runtime
            .with_grid(grid_id, |grid| grid.allow_user_resizing = 1)
            .unwrap();

        let cancel_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                runtime.request_before_user_resize(grid_id, grid, -1, 0, 100.0)
            },
            |event| matches!(event, GridEventData::BeforeUserResize { row: -1, col: 0 }),
        );
        let _ = runtime.resolve_event_decision(grid_id, cancel_id, true);
        runtime
            .with_grid(grid_id, |grid| assert!(!grid.resize_active))
            .unwrap();

        let allow_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                runtime.request_before_user_resize(grid_id, grid, -1, 0, 100.0)
            },
            |event| matches!(event, GridEventData::BeforeUserResize { row: -1, col: 0 }),
        );
        let _ = runtime.resolve_event_decision(grid_id, allow_id, false);
        runtime
            .with_grid(grid_id, |grid| {
                assert!(grid.resize_active);
                assert!(grid.resize_is_col);
                assert_eq!(grid.resize_index, 0);
            })
            .unwrap();

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_cancel_and_allow_before_move_column() {
        let (runtime, grid_id) = runtime_with_decision_grid(3, 3);
        runtime
            .with_grid(grid_id, |grid| {
                grid.cells.set_text(1, 0, "A".to_string());
                grid.cells.set_text(1, 1, "B".to_string());
                grid.cells.set_text(1, 2, "C".to_string());
            })
            .unwrap();

        let cancel_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| runtime.request_before_move_column(grid_id, grid, 0, 2),
            |event| {
                matches!(
                    event,
                    GridEventData::BeforeMoveColumn {
                        col: 0,
                        new_position: 2
                    }
                )
            },
        );
        let _ = runtime.resolve_event_decision(grid_id, cancel_id, true);
        runtime
            .with_grid(grid_id, |grid| assert_eq!(grid.cells.get_text(1, 0), "A"))
            .unwrap();

        let allow_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| runtime.request_before_move_column(grid_id, grid, 0, 2),
            |event| matches!(event, GridEventData::BeforeMoveColumn { col: 0, .. }),
        );
        let _ = runtime.resolve_event_decision(grid_id, allow_id, false);
        runtime
            .with_grid(grid_id, |grid| assert_eq!(grid.cells.get_text(1, 2), "A"))
            .unwrap();

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_cancel_and_allow_before_move_row() {
        let (runtime, grid_id) = runtime_with_decision_grid(5, 1);

        let cancel_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| runtime.request_before_move_row(grid_id, grid, 1, 3),
            |event| {
                matches!(
                    event,
                    GridEventData::BeforeMoveRow {
                        row: 1,
                        new_position: 3
                    }
                )
            },
        );
        let _ = runtime.resolve_event_decision(grid_id, cancel_id, true);
        runtime
            .with_grid(grid_id, |grid| assert_eq!(grid.row_display_position(1), 1))
            .unwrap();

        let allow_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| runtime.request_before_move_row(grid_id, grid, 1, 3),
            |event| matches!(event, GridEventData::BeforeMoveRow { row: 1, .. }),
        );
        let _ = runtime.resolve_event_decision(grid_id, allow_id, false);
        runtime
            .with_grid(grid_id, |grid| assert_eq!(grid.row_display_position(1), 3))
            .unwrap();

        destroy_test_grid(&runtime, grid_id);
    }

    #[test]
    fn event_decision_cancel_and_allow_before_mouse_down() {
        let (runtime, grid_id) = runtime_with_decision_grid(4, 2);

        let cancel_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                runtime.request_before_mouse_down(grid_id, grid, 1, 0, 10.0, 25.0, 0, 0, false)
            },
            |event| matches!(event, GridEventData::BeforeMouseDown { row: 1, col: 0, .. }),
        );
        let _ = runtime.resolve_event_decision(grid_id, cancel_id, true);
        runtime
            .with_grid(grid_id, |grid| {
                assert_eq!(grid.mouse_row, -1);
                assert_eq!(grid.mouse_col, -1);
            })
            .unwrap();

        let allow_id = request_pending_event_id(
            &runtime,
            grid_id,
            |runtime, grid_id, grid| {
                runtime.request_before_mouse_down(grid_id, grid, 1, 0, 10.0, 25.0, 0, 0, false)
            },
            |event| matches!(event, GridEventData::BeforeMouseDown { row: 1, col: 0, .. }),
        );
        let _ = runtime.resolve_event_decision(grid_id, allow_id, false);
        runtime
            .with_grid(grid_id, |grid| {
                assert_eq!(grid.mouse_row, 1);
                assert_eq!(grid.mouse_col, 0);
            })
            .unwrap();

        destroy_test_grid(&runtime, grid_id);
    }
}

// ---------------------------------------------------------------------------
// Helper: convert engine GridEventData to proto GridEvent
// ---------------------------------------------------------------------------
fn engine_event_to_proto(
    grid_id: i64,
    event_id: i64,
    evt: volvoxgrid_engine::event::GridEventData,
) -> GridEvent {
    fn normalize_range(row1: i32, col1: i32, row2: i32, col2: i32) -> CellRange {
        CellRange {
            row1: row1.min(row2),
            col1: col1.min(col2),
            row2: row1.max(row2),
            col2: col1.max(col2),
        }
    }

    use volvoxgrid_engine::event::GridEventData as E;
    let event = match evt {
        E::CellFocusChanging {
            old_row,
            old_col,
            new_row,
            new_col,
        } => Some(grid_event::Event::CellFocusChanging(
            CellFocusChangingEvent {
                old_row,
                old_col,
                new_row,
                new_col,
            },
        )),
        E::CellFocusChanged {
            old_row,
            old_col,
            new_row,
            new_col,
        } => Some(grid_event::Event::CellFocusChanged(CellFocusChangedEvent {
            old_row,
            old_col,
            new_row,
            new_col,
        })),
        E::SelectionChanging {
            old_ranges,
            new_ranges,
            active_row,
            active_col,
        } => Some(grid_event::Event::SelectionChanging(
            SelectionChangingEvent {
                old_ranges: old_ranges
                    .into_iter()
                    .map(|(row1, col1, row2, col2)| normalize_range(row1, col1, row2, col2))
                    .collect(),
                new_ranges: new_ranges
                    .into_iter()
                    .map(|(row1, col1, row2, col2)| normalize_range(row1, col1, row2, col2))
                    .collect(),
                active_row,
                active_col,
            },
        )),
        E::SelectionChanged {
            old_ranges,
            new_ranges,
            active_row,
            active_col,
        } => Some(grid_event::Event::SelectionChanged(SelectionChangedEvent {
            old_ranges: old_ranges
                .into_iter()
                .map(|(row1, col1, row2, col2)| normalize_range(row1, col1, row2, col2))
                .collect(),
            new_ranges: new_ranges
                .into_iter()
                .map(|(row1, col1, row2, col2)| normalize_range(row1, col1, row2, col2))
                .collect(),
            active_row,
            active_col,
        })),
        E::EnterCell { row, col, target } => Some(grid_event::Event::EnterCell(EnterCellEvent {
            row,
            col,
            target: Some(target.to_proto()),
        })),
        E::LeaveCell { row, col, target } => Some(grid_event::Event::LeaveCell(LeaveCellEvent {
            row,
            col,
            target: Some(target.to_proto()),
        })),
        E::BeforeEdit { row, col } => {
            Some(grid_event::Event::BeforeEdit(BeforeEditEvent { row, col }))
        }
        E::StartEdit { row, col } => {
            Some(grid_event::Event::StartEdit(StartEditEvent { row, col }))
        }
        E::AfterEdit {
            row,
            col,
            old_text,
            new_text,
        } => Some(grid_event::Event::AfterEdit(AfterEditEvent {
            row,
            col,
            old_text,
            new_text,
        })),
        E::CellEditValidate {
            row,
            col,
            edit_text,
        } => Some(grid_event::Event::CellEditValidate(CellEditValidateEvent {
            row,
            col,
            edit_text,
        })),
        E::CellEditChange { text } => {
            Some(grid_event::Event::CellEditChange(CellEditChangeEvent {
                text,
            }))
        }
        E::KeyDownEdit { key_code, modifier } => {
            Some(grid_event::Event::KeyDownEdit(KeyDownEditEvent {
                key_code,
                modifier,
            }))
        }
        E::KeyPressEdit { key_ascii } => Some(grid_event::Event::KeyPressEdit(KeyPressEditEvent {
            key_ascii,
        })),
        E::KeyUpEdit { key_code, modifier } => Some(grid_event::Event::KeyUpEdit(KeyUpEditEvent {
            key_code,
            modifier,
        })),
        E::CellEditConfigureStyle { row, col } => Some(grid_event::Event::CellEditConfigureStyle(
            CellEditConfigureStyleEvent { row, col },
        )),
        E::CellEditConfigureWindow { row, col } => Some(
            grid_event::Event::CellEditConfigureWindow(CellEditConfigureWindowEvent { row, col }),
        ),
        E::BeforeDropdownOpen {
            row,
            col,
            x,
            y,
            width,
            height,
            dropdown,
            current_value,
            selected_index,
        } => Some(grid_event::Event::BeforeDropdownOpen(
            BeforeDropdownOpenEvent {
                row,
                col,
                x,
                y,
                width,
                height,
                dropdown: Some(dropdown),
                current_value,
                selected_index,
            },
        )),
        E::DropdownClosed => Some(grid_event::Event::DropdownClosed(DropdownClosedEvent {})),
        E::DropdownOpened => Some(grid_event::Event::DropdownOpened(DropdownOpenedEvent {})),
        E::CellChanged {
            row,
            col,
            old_text,
            new_text,
        } => Some(grid_event::Event::CellChanged(CellChangedEvent {
            row,
            col,
            old_text,
            new_text,
        })),
        E::RowStatusChange { row, status } => {
            Some(grid_event::Event::RowStatusChange(RowStatusChangeEvent {
                row,
                status: Some(status.to_proto()),
            }))
        }
        E::BeforeSort { col } => Some(grid_event::Event::BeforeSort(BeforeSortEvent { col })),
        E::AfterSort { col } => Some(grid_event::Event::AfterSort(AfterSortEvent { col })),
        E::Compare {
            request_id,
            row1,
            row2,
            col,
        } => Some(grid_event::Event::Compare(CompareEvent {
            request_id,
            row1,
            row2,
            col,
        })),
        E::BeforeNodeToggle { row, collapse } => {
            Some(grid_event::Event::BeforeNodeToggle(BeforeNodeToggleEvent {
                row,
                collapse,
            }))
        }
        E::AfterNodeToggle { row, collapse } => {
            Some(grid_event::Event::AfterNodeToggle(AfterNodeToggleEvent {
                row,
                collapse,
            }))
        }
        E::TreeChildrenRequested {
            node_id,
            row,
            request_id,
        } => Some(grid_event::Event::TreeChildrenRequested(
            TreeChildrenRequestedEvent {
                node_id,
                row,
                request_id,
            },
        )),
        E::BeforeTreeNodeToggle {
            node_id,
            row,
            collapse,
        } => Some(grid_event::Event::BeforeTreeNodeToggle(
            BeforeTreeNodeToggleEvent {
                node_id,
                row,
                collapse,
            },
        )),
        E::AfterTreeNodeToggle {
            node_id,
            row,
            collapse,
        } => Some(grid_event::Event::AfterTreeNodeToggle(
            AfterTreeNodeToggleEvent {
                node_id,
                row,
                collapse,
            },
        )),
        E::TreeNodeActivate { node_id, row } => {
            Some(grid_event::Event::TreeNodeActivate(TreeNodeActivateEvent {
                node_id,
                row,
            }))
        }
        E::TreeNodeContextMenu { node_id, row, x, y } => Some(
            grid_event::Event::TreeNodeContextMenu(TreeNodeContextMenuEvent { node_id, row, x, y }),
        ),
        E::BeforeScroll {
            old_top_row,
            old_left_col,
            new_top_row,
            new_left_col,
        } => Some(grid_event::Event::BeforeScroll(BeforeScrollEvent {
            old_top_row,
            old_left_col,
            new_top_row,
            new_left_col,
        })),
        E::AfterScroll {
            old_top_row,
            old_left_col,
            new_top_row,
            new_left_col,
        } => Some(grid_event::Event::AfterScroll(AfterScrollEvent {
            old_top_row,
            old_left_col,
            new_top_row,
            new_left_col,
        })),
        E::ScrollTooltip { text } => Some(grid_event::Event::ScrollTooltip(ScrollTooltipEvent {
            text,
        })),
        E::BeforeUserResize { row, col } => {
            Some(grid_event::Event::BeforeUserResize(BeforeUserResizeEvent {
                row,
                col,
            }))
        }
        E::AfterUserResize { row, col } => {
            Some(grid_event::Event::AfterUserResize(AfterUserResizeEvent {
                row,
                col,
            }))
        }
        E::AfterUserFreeze {
            frozen_rows,
            frozen_cols,
        } => Some(grid_event::Event::AfterUserFreeze(AfterUserFreezeEvent {
            frozen_rows,
            frozen_cols,
        })),
        E::BeforeMoveColumn { col, new_position } => {
            Some(grid_event::Event::BeforeMoveColumn(BeforeMoveColumnEvent {
                col,
                new_position,
            }))
        }
        E::AfterMoveColumn { col, old_position } => {
            Some(grid_event::Event::AfterMoveColumn(AfterMoveColumnEvent {
                col,
                old_position,
            }))
        }
        E::BeforeMoveRow { row, new_position } => {
            Some(grid_event::Event::BeforeMoveRow(BeforeMoveRowEvent {
                row,
                new_position,
            }))
        }
        E::AfterMoveRow { row, old_position } => {
            Some(grid_event::Event::AfterMoveRow(AfterMoveRowEvent {
                row,
                old_position,
            }))
        }
        E::BeforeMouseDown { row, col, target } => {
            Some(grid_event::Event::BeforeMouseDown(BeforeMouseDownEvent {
                row,
                col,
                target: Some(target.to_proto()),
            }))
        }
        E::MouseDown {
            button,
            modifier,
            x,
            y,
        } => Some(grid_event::Event::MouseDown(MouseDownEvent {
            button,
            modifier,
            x,
            y,
        })),
        E::MouseUp {
            button,
            modifier,
            x,
            y,
        } => Some(grid_event::Event::MouseUp(MouseUpEvent {
            button,
            modifier,
            x,
            y,
        })),
        E::MouseMove {
            button,
            modifier,
            x,
            y,
            target,
        } => Some(grid_event::Event::MouseMove(MouseMoveEvent {
            button,
            modifier,
            x,
            y,
            target: Some(target.to_proto()),
        })),
        E::Click {
            row,
            col,
            hit_area,
            interaction,
            target,
        } => Some(grid_event::Event::Click(ClickEvent {
            row,
            col,
            hit_area,
            interaction,
            target: Some(target.to_proto()),
        })),
        E::DblClick { row, col, target } => Some(grid_event::Event::DblClick(DblClickEvent {
            row,
            col,
            target: Some(target.to_proto()),
        })),
        E::KeyDown { key_code, modifier } => Some(grid_event::Event::KeyDown(KeyDownEvent {
            key_code,
            modifier,
        })),
        E::KeyPress { key_ascii } => Some(grid_event::Event::KeyPress(KeyPressEvent { key_ascii })),
        E::KeyUp { key_code, modifier } => {
            Some(grid_event::Event::KeyUp(KeyUpEvent { key_code, modifier }))
        }
        E::CustomRenderCell {
            row,
            col,
            x,
            y,
            width,
            height,
            text,
        } => Some(grid_event::Event::CustomRenderCell(CustomRenderCellEvent {
            row,
            col,
            x,
            y,
            width,
            height,
            text,
            style: None,
            done: false,
        })),
        E::DragStart { row, col } => {
            Some(grid_event::Event::DragStart(DragStartEvent { row, col }))
        }
        E::DragOver { row, col, x, y } => Some(grid_event::Event::DragOver(DragOverEvent {
            row,
            col,
            x,
            y,
        })),
        E::DragDrop { row, col } => Some(grid_event::Event::DragDrop(DragDropEvent { row, col })),
        E::DragComplete { success } => Some(grid_event::Event::DragComplete(DragCompleteEvent {
            success,
        })),
        E::TypeAheadStarted { col, text } => {
            Some(grid_event::Event::TypeAheadStarted(TypeAheadStartedEvent {
                col,
                text,
            }))
        }
        E::TypeAheadEnded => Some(grid_event::Event::TypeAheadEnded(TypeAheadEndedEvent {})),
        E::PullToRefreshTriggered => Some(grid_event::Event::PullToRefreshTriggered(
            PullToRefreshTriggeredEvent {},
        )),
        E::PullToRefreshCanceled => Some(grid_event::Event::PullToRefreshCanceled(
            PullToRefreshCanceledEvent {},
        )),
        E::DataRefreshing => Some(grid_event::Event::DataRefreshing(DataRefreshingEvent {})),
        E::DataRefreshed => Some(grid_event::Event::DataRefreshed(DataRefreshedEvent {})),
        E::FilterData { row, col, text } => Some(grid_event::Event::FilterData(FilterDataEvent {
            row,
            col,
            text,
        })),
        E::Error { code, message } => Some(grid_event::Event::Error(ErrorEvent { code, message })),
        E::BeforePageBreak { row } => {
            Some(grid_event::Event::BeforePageBreak(BeforePageBreakEvent {
                row,
            }))
        }
        E::StartPage { page } => Some(grid_event::Event::StartPage(StartPageEvent { page })),
        E::GetHeaderRow { page } => {
            Some(grid_event::Event::GetHeaderRow(GetHeaderRowEvent { page }))
        }
        E::Copy | E::Cut | E::Paste => None,
    };

    GridEvent {
        grid_id,
        event_id,
        event,
    }
}

// ---------------------------------------------------------------------------
// Edit session helpers
// ---------------------------------------------------------------------------

fn cell_screen_rect(
    grid: &volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
) -> Option<(i32, i32, i32, i32)> {
    grid.cell_screen_rect(row, col)
}

fn effective_edit_mask(grid: &volvoxgrid_engine::grid::VolvoxGrid, col: i32) -> String {
    if col >= 0 && (col as usize) < grid.columns.len() {
        let mask = &grid.columns[col as usize].edit_mask;
        if !mask.is_empty() {
            return mask.clone();
        }
    }
    grid.edit_mask.clone()
}

fn build_edit_request(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
) -> Option<EditRequest> {
    let (x, y, w, h) = grid.cell_screen_rect(row, col)?;
    let (current_value, sel_start, sel_length, ui_mode) =
        if grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col {
            (
                grid.edit.edit_text.clone(),
                grid.edit.sel_start,
                grid.edit.sel_length,
                match grid.edit.ui_mode {
                    volvoxgrid_engine::edit::EditUiMode::EnterMode => EditUiMode::Enter as i32,
                    volvoxgrid_engine::edit::EditUiMode::EditMode => EditUiMode::Edit as i32,
                },
            )
        } else {
            let current_value = grid.get_display_text(row, col);
            let current_len = current_value.chars().count() as i32;
            (current_value, 0, current_len, EditUiMode::Enter as i32)
        };
    Some(EditRequest {
        row,
        col,
        x: x as f32,
        y: y as f32,
        width: w as f32,
        height: h as f32,
        current_value,
        edit_mask: effective_edit_mask(grid, col),
        max_length: grid.edit_max_length,
        sel_start,
        sel_length,
        ui_mode,
    })
}

fn build_combo_request(
    grid: &volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
) -> Option<DropdownRequest> {
    let (x, y, w, h) = cell_screen_rect(grid, row, col)?;
    let mut items = Vec::new();
    let count = grid.edit.dropdown_count();
    for i in 0..count {
        items.push(grid.edit.get_dropdown_item(i).to_string());
    }
    Some(DropdownRequest {
        row,
        col,
        x: x as f32,
        y: y as f32,
        width: w as f32,
        height: h as f32,
        items,
        selected: grid.edit.dropdown_index.max(-1),
        editable: grid.edit.dropdown_editable,
    })
}

fn maybe_render_editor_output(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    prefer_combo: bool,
) -> Option<RenderOutput> {
    if !grid.edit.is_active() {
        return None;
    }
    let row = grid.edit.edit_row;
    let col = grid.edit.edit_col;
    if row < 0 || col < 0 {
        return None;
    }
    let wants_combo_request =
        grid.edit.dropdown_count() > 0 && (prefer_combo || !grid.edit.dropdown_editable);
    if wants_combo_request {
        if let Some(req) = build_combo_request(grid, row, col) {
            return Some(RenderOutput {
                rendered: false,
                event: Some(render_output::Event::DropdownRequest(req)),
            });
        }
    }
    build_edit_request(grid, row, col).map(|req| RenderOutput {
        rendered: false,
        event: Some(render_output::Event::EditRequest(req)),
    })
}

fn same_edit_request_geometry(lhs: &EditRequest, rhs: &EditRequest) -> bool {
    lhs.row == rhs.row
        && lhs.col == rhs.col
        && lhs.ui_mode == rhs.ui_mode
        && lhs.x.to_bits() == rhs.x.to_bits()
        && lhs.y.to_bits() == rhs.y.to_bits()
        && lhs.width.to_bits() == rhs.width.to_bits()
        && lhs.height.to_bits() == rhs.height.to_bits()
}

#[derive(Clone)]
struct SentEditRequest {
    request: EditRequest,
    session_serial: u64,
}

fn current_edit_session_serial(
    runtime: &VolvoxGridRuntime,
    grid_id: i64,
    req: &EditRequest,
) -> Option<u64> {
    runtime
        .with_grid(grid_id, |grid| {
            if grid.edit.is_active()
                && grid.edit.edit_row == req.row
                && grid.edit.edit_col == req.col
            {
                Some(grid.edit.session_serial)
            } else {
                None
            }
        })
        .ok()
        .flatten()
}

fn track_sent_edit_request(
    runtime: &VolvoxGridRuntime,
    sent_edit_requests: &mut HashMap<i64, SentEditRequest>,
    grid_id: i64,
    output: &RenderOutput,
) {
    if let Some(render_output::Event::EditRequest(req)) = output.event.as_ref() {
        let session_serial = current_edit_session_serial(runtime, grid_id, req).unwrap_or(0);
        sent_edit_requests.insert(
            grid_id,
            SentEditRequest {
                request: req.clone(),
                session_serial,
            },
        );
    }
}

fn send_render_output_tracked(
    runtime: &VolvoxGridRuntime,
    stream: &dyn RuntimeStreamBidi<RenderInput, RenderOutput>,
    sent_edit_requests: &mut HashMap<i64, SentEditRequest>,
    grid_id: i64,
    output: RenderOutput,
) {
    track_sent_edit_request(runtime, sent_edit_requests, grid_id, &output);
    stream.send(output);
}

fn maybe_send_refreshed_edit_request(
    runtime: &VolvoxGridRuntime,
    stream: &dyn RuntimeStreamBidi<RenderInput, RenderOutput>,
    sent_edit_requests: &mut HashMap<i64, SentEditRequest>,
    grid_id: i64,
) {
    let output = runtime
        .with_grid(grid_id, |grid| {
            if !grid.layout.valid {
                ensure_layout(grid);
            }
            maybe_render_editor_output(grid, false)
        })
        .ok()
        .flatten();

    let Some(output) = output else {
        sent_edit_requests.remove(&grid_id);
        return;
    };
    let Some(render_output::Event::EditRequest(req)) = output.event.as_ref() else {
        return;
    };

    let current_session_serial = current_edit_session_serial(runtime, grid_id, req).unwrap_or(0);
    let should_send = sent_edit_requests.get(&grid_id).map_or(true, |prev| {
        prev.session_serial != current_session_serial
            || !same_edit_request_geometry(&prev.request, req)
    });
    if should_send {
        sent_edit_requests.insert(
            grid_id,
            SentEditRequest {
                request: req.clone(),
                session_serial: current_session_serial,
            },
        );
        stream.send(output);
    }
}

// ---------------------------------------------------------------------------
// VolvoxGridRuntime pending action / decision helpers
// ---------------------------------------------------------------------------
impl VolvoxGridRuntime {
    fn next_event_id(&self) -> i64 {
        self.next_event_id.fetch_add(1, Ordering::Relaxed)
    }

    fn decision_channel_enabled(&self, grid_id: i64) -> bool {
        self.decision_enabled
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .contains(&grid_id)
    }

    fn mark_decision_channel_enabled(&self, grid_id: i64) {
        self.decision_enabled
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(grid_id);
    }

    fn timeout_duration(ms: u32) -> Option<Duration> {
        if ms == 0 {
            None
        } else {
            Some(Duration::from_millis(u64::from(ms)))
        }
    }

    fn decision_timeout(&self, grid_id: i64) -> Option<Duration> {
        self.manager()
            .with_grid(grid_id, |grid| {
                Self::timeout_duration(grid.decision_timeout_ms)
            })
            .ok()
            .flatten()
    }

    fn compare_timeout_from_grid(grid: &volvoxgrid_engine::grid::VolvoxGrid) -> Option<Duration> {
        Self::timeout_duration(grid.compare_response_timeout_ms)
    }

    fn register_render_session_grid(&self, grid_id: i64, session_grid_ids: &mut HashSet<i64>) {
        if grid_id <= 0 || !session_grid_ids.insert(grid_id) {
            return;
        }
        let mut sessions = ACTIVE_RENDER_SESSIONS
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        *sessions.entry(grid_id).or_insert(0) += 1;
    }

    fn unregister_render_session_grids(&self, session_grid_ids: &HashSet<i64>) {
        if session_grid_ids.is_empty() {
            return;
        }
        let mut sessions = ACTIVE_RENDER_SESSIONS
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        for grid_id in session_grid_ids {
            let remove = if let Some(count) = sessions.get_mut(grid_id) {
                if *count > 1 {
                    *count -= 1;
                    false
                } else {
                    true
                }
            } else {
                false
            };
            if remove {
                sessions.remove(grid_id);
            }
        }
    }

    fn compare_session_active(grid_id: i64) -> bool {
        ACTIVE_RENDER_SESSIONS
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .get(&grid_id)
            .copied()
            .unwrap_or(0)
            > 0
    }

    fn install_compare_channel(
        grid_id: i64,
        timeout: Option<Duration>,
    ) -> Option<Box<volvoxgrid_engine::grid::CustomCompareFn>> {
        if !Self::compare_session_active(grid_id) {
            return None;
        }

        let channel = CompareChannel::new();
        if let Ok(waker) = SHARED_GRID_MANAGER.get_grid_waker(grid_id) {
            channel.attach_waker(waker);
        }
        COMPARE_CHANNELS
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(grid_id, Arc::clone(&channel));

        Some(Box::new(move |row1, row2, col| {
            channel.compare(row1, row2, col, timeout)
        }))
    }

    fn clear_compare_channel(grid_id: i64) {
        if let Some(channel) = COMPARE_CHANNELS
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(&grid_id)
        {
            channel.cancel();
        }
    }

    fn compare_abort_from_panic(
        panic_payload: &(dyn std::any::Any + Send),
    ) -> Option<&CompareAbort> {
        panic_payload.downcast_ref::<CompareAbort>()
    }

    fn restore_sort_snapshot(
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        sort_state: volvoxgrid_engine::sort::SortState,
        row_positions: Vec<i32>,
    ) {
        grid.sort_state = sort_state;
        grid.row_positions = row_positions;
        grid.cells.set_row_map(grid.row_positions.clone());
        grid.layout.invalidate();
        grid.mark_dirty();
    }

    fn push_compare_timeout_error(grid: &mut volvoxgrid_engine::grid::VolvoxGrid, col: i32) {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::Error {
                code: ERROR_COMPARE_TIMEOUT,
                message: format!("no CompareResponse for custom sort on col={col}"),
            });
    }

    fn has_row_sort_metadata(
        grid: &volvoxgrid_engine::grid::VolvoxGrid,
        row_lo: i32,
        row_hi: i32,
    ) -> bool {
        let in_range = |row: i32| row >= row_lo && row <= row_hi;
        grid.sort_value_generator.is_some()
            || grid.row_heights.keys().any(|&row| in_range(row))
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

    fn prepare_custom_sort_snapshot(
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        col: i32,
        order: i32,
        emit_after_sort: bool,
    ) -> Option<HeaderSortSnapshot> {
        // Fast path only for the engine's current clean-grid single-key custom
        // sort shape. The snapshot deliberately bypasses sort_range_impl while
        // host comparisons are pending, so any row-affecting metadata must fall
        // back to the locked engine path where row remaps, pinned/subtotal rows,
        // generators, and spans are handled centrally.
        if grid.rows <= grid.fixed_rows + 1
            || grid.cols <= 0
            || !volvoxgrid_engine::sort::sort_order_is_custom(order)
        {
            return None;
        }
        let row_lo = grid.fixed_rows;
        let row_hi = grid.rows - 1;
        if Self::has_row_sort_metadata(grid, row_lo, row_hi) {
            return None;
        }

        let rows: Vec<i32> = (row_lo..=row_hi)
            .filter(|&row| !grid.cells.get_text(row, col).is_empty())
            .collect();
        if rows.len() < 2 {
            return None;
        }
        let timeout = Self::compare_timeout_from_grid(grid);
        let compare = Self::install_compare_channel(grid_id, timeout)?;
        Some(HeaderSortSnapshot {
            col,
            order,
            emit_after_sort,
            compare,
            old_sort_state: grid.sort_state.clone(),
            old_row_positions: grid.row_positions.clone(),
            groups: vec![rows],
        })
    }

    fn prepare_header_sort_snapshot(
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        col: i32,
    ) -> Option<HeaderSortSnapshot> {
        if grid.header_features & 1 == 0 {
            return None;
        }
        let order = volvoxgrid_engine::sort::header_click_next_sort_order(grid, col);
        Self::prepare_custom_sort_snapshot(grid_id, grid, col, order, true)
    }

    fn prepare_sort_keys_snapshot(
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        sort_keys: &[(i32, i32)],
    ) -> Option<HeaderSortSnapshot> {
        if sort_keys.len() != 1 {
            return None;
        }
        let (col, order) = sort_keys[0];
        Self::prepare_custom_sort_snapshot(grid_id, grid, col, order, false)
    }

    fn compare_ordering(result: Option<i32>, ascending: bool) -> std::cmp::Ordering {
        let ordering = match result.unwrap_or(0).signum() {
            value if value < 0 => std::cmp::Ordering::Less,
            value if value > 0 => std::cmp::Ordering::Greater,
            _ => std::cmp::Ordering::Equal,
        };
        if ascending {
            ordering
        } else {
            ordering.reverse()
        }
    }

    fn run_header_sort_snapshot(grid_id: i64, snapshot: HeaderSortSnapshot) {
        let started_at = Instant::now();
        let sort_result = panic::catch_unwind(AssertUnwindSafe(|| {
            let mut row_positions = snapshot.old_row_positions.clone();
            let ascending = volvoxgrid_engine::sort::sort_order_is_ascending(snapshot.order);
            for group in &snapshot.groups {
                let mut indices: Vec<usize> = (0..group.len()).collect();
                indices.sort_unstable_by(|&ia, &ib| {
                    let result = (snapshot.compare)(group[ia], group[ib], snapshot.col);
                    Self::compare_ordering(result, ascending)
                });
                for (dest_idx, &src_idx) in indices.iter().enumerate() {
                    let dest_row = group[dest_idx] as usize;
                    let src_row = group[src_idx] as usize;
                    if dest_row < row_positions.len() && src_row < snapshot.old_row_positions.len()
                    {
                        row_positions[dest_row] = snapshot.old_row_positions[src_row];
                    }
                }
            }
            row_positions
        }));
        Self::clear_compare_channel(grid_id);

        match sort_result {
            Ok(row_positions) => {
                let elapsed_ms = started_at.elapsed().as_secs_f64() * 1000.0;
                let _ = SHARED_GRID_MANAGER.with_grid(grid_id, |grid| {
                    // Last mutation wins. We only commit if the row order and
                    // active sort keys still match the snapshot. Cell edits and
                    // column metadata changes during the sort are not rejected;
                    // their rows can be ordered by the pre-edit compare values.
                    if grid.row_positions != snapshot.old_row_positions
                        || grid.sort_state.sort_keys != snapshot.old_sort_state.sort_keys
                    {
                        return;
                    }
                    let old_sort_keys = grid.sort_state.sort_keys.clone();
                    grid.row_positions = row_positions;
                    grid.cells.set_row_map(grid.row_positions.clone());
                    grid.sort_state = snapshot.old_sort_state;
                    grid.sort_state.sort_keys = vec![(snapshot.col, snapshot.order)];
                    grid.sort_state.last_sort_elapsed_ms = elapsed_ms;
                    grid.layout.invalidate();
                    grid.mark_dirty();
                    if snapshot.emit_after_sort && grid.sort_state.sort_keys != old_sort_keys {
                        grid.events
                            .push(volvoxgrid_engine::event::GridEventData::AfterSort {
                                col: snapshot.col,
                            });
                    }
                });
            }
            Err(err) => match Self::compare_abort_from_panic(err.as_ref()) {
                Some(CompareAbort::Timeout) => {
                    let _ = SHARED_GRID_MANAGER.with_grid(grid_id, |grid| {
                        Self::push_compare_timeout_error(grid, snapshot.col);
                    });
                }
                Some(CompareAbort::Cancelled) => {}
                None => panic::resume_unwind(err),
            },
        }
    }

    fn run_header_sort_locked(
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        col: i32,
    ) {
        let old_sort_state = grid.sort_state.clone();
        let old_row_positions = grid.row_positions.clone();
        let old_sort_keys = old_sort_state.sort_keys.clone();
        let next_order = volvoxgrid_engine::sort::header_click_next_sort_order(grid, col);
        Self::clear_compare_channel(grid_id);
        if volvoxgrid_engine::sort::sort_order_is_custom(next_order) {
            let timeout = Self::compare_timeout_from_grid(grid);
            grid.custom_compare = Self::install_compare_channel(grid_id, timeout);
        }

        // Timeout/cancellation is carried as a private panic from the compare
        // callback. Today an abort can leave sort_state/row_positions, layout,
        // or dirty state in an intermediate state; those are restored below. If
        // engine sorting starts mutating more abort-visible state, add it to
        // restore_sort_snapshot or force this case through the snapshot path.
        let sort_result = panic::catch_unwind(AssertUnwindSafe(|| {
            volvoxgrid_engine::sort::handle_header_click(grid, col);
        }));
        grid.custom_compare = None;
        Self::clear_compare_channel(grid_id);

        if let Err(err) = sort_result {
            Self::restore_sort_snapshot(grid, old_sort_state, old_row_positions);
            match Self::compare_abort_from_panic(err.as_ref()) {
                Some(CompareAbort::Timeout) => Self::push_compare_timeout_error(grid, col),
                Some(CompareAbort::Cancelled) => {}
                None => panic::resume_unwind(err),
            }
            return;
        }

        if grid.sort_state.sort_keys != old_sort_keys {
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::AfterSort { col });
        }
    }

    fn spawn_header_sort_job(grid_id: i64, col: i32) {
        let spawn_result = std::thread::Builder::new()
            .name(format!("volvoxgrid-sort-{grid_id}"))
            .spawn(move || {
                let snapshot = SHARED_GRID_MANAGER
                    .with_grid(grid_id, |grid| {
                        Self::prepare_header_sort_snapshot(grid_id, grid, col)
                    })
                    .ok()
                    .flatten();
                if let Some(snapshot) = snapshot {
                    Self::run_header_sort_snapshot(grid_id, snapshot);
                } else {
                    let _ = SHARED_GRID_MANAGER.with_grid(grid_id, |grid| {
                        Self::run_header_sort_locked(grid_id, grid, col);
                    });
                }
            });
        if let Err(err) = spawn_result {
            let _ = SHARED_GRID_MANAGER.with_grid(grid_id, |grid| {
                grid.events
                    .push(volvoxgrid_engine::event::GridEventData::Error {
                        code: ERROR_INTERNAL,
                        message: format!("failed to spawn header sort worker for col={col}: {err}"),
                    });
            });
        }
    }

    fn run_sort_keys_locked(
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        sort_keys: Vec<(i32, i32)>,
    ) {
        let old_sort_state = grid.sort_state.clone();
        let old_row_positions = grid.row_positions.clone();
        let timeout_col = sort_keys.first().map_or(-1, |(col, _)| *col);
        let has_custom = sort_keys
            .iter()
            .any(|&(_, order)| volvoxgrid_engine::sort::sort_order_is_custom(order));
        if has_custom {
            let timeout = Self::compare_timeout_from_grid(grid);
            grid.custom_compare = Self::install_compare_channel(grid_id, timeout);
        }
        grid.sort_state.sort_keys = sort_keys;
        let sort_result = panic::catch_unwind(AssertUnwindSafe(|| {
            volvoxgrid_engine::sort::sort_grid_all_multi(grid);
        }));
        grid.custom_compare = None;

        if let Err(err) = sort_result {
            Self::restore_sort_snapshot(grid, old_sort_state, old_row_positions);
            match Self::compare_abort_from_panic(err.as_ref()) {
                Some(CompareAbort::Timeout) => {
                    Self::push_compare_timeout_error(grid, timeout_col);
                }
                Some(CompareAbort::Cancelled) => {}
                None => panic::resume_unwind(err),
            }
        }
    }

    fn lookup_compare_channel(&self, grid_id: i64) -> Option<Arc<CompareChannel>> {
        COMPARE_CHANNELS
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .get(&grid_id)
            .cloned()
    }

    fn deliver_compare_response(&self, grid_id: i64, request_id: i64, result: i32) -> bool {
        let channel = COMPARE_CHANNELS
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .get(&grid_id)
            .cloned();
        channel
            .map(|channel| channel.deliver_response(request_id, result))
            .unwrap_or(false)
    }

    fn clear_grid_state(&self, grid_id: i64) {
        self.decision_enabled
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(&grid_id);
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .retain(|(pending_grid, _), _| *pending_grid != grid_id);
        Self::clear_compare_channel(grid_id);
        ACTIVE_RENDER_SESSIONS
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(&grid_id);
        self.zoom_levels
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(&grid_id);
        clear_registered_text_renderer(grid_id);
    }

    fn current_zoom_scale(&self, grid_id: i64) -> f64 {
        let mut levels = self.zoom_levels.lock().unwrap_or_else(|e| e.into_inner());
        *levels.entry(grid_id).or_insert(1.0)
    }

    fn set_current_zoom_scale(&self, grid_id: i64, scale: f64) {
        self.zoom_levels
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(grid_id, snap_zoom_restore_scale(clamp_zoom_scale(scale)));
    }

    fn request_before_edit(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        row: i32,
        col: i32,
        force: bool,
        prefer_combo: bool,
        seed_text: Option<String>,
        click_caret: Option<i32>,
        caret_end: Option<bool>,
    ) -> Option<RenderOutput> {
        if !grid.can_begin_edit(row, col, force) {
            return None;
        }

        if !self.decision_channel_enabled(grid_id) {
            shared::begin_edit_session_core_opts(
                grid,
                row,
                col,
                force,
                true,
                true,
                None,
                caret_end,
                seed_text.clone(),
                None,
            );
            if let Some(seed) = seed_text {
                if grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col {
                    grid.events
                        .push(volvoxgrid_engine::event::GridEventData::CellEditChange {
                            text: seed,
                        });
                }
            }
            if let Some(caret) = click_caret {
                if grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col {
                    grid.edit.sel_start = caret;
                    grid.edit.sel_length = 0;
                }
            }
            return maybe_render_editor_output(grid, prefer_combo);
        }

        let event_id = self.next_event_id();
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                (grid_id, event_id),
                PendingActionEntry {
                    created_at: Instant::now(),
                    action: PendingAction::BeginEdit {
                        row,
                        col,
                        force,
                        prefer_combo,
                        seed_text,
                        click_caret,
                        caret_end,
                    },
                },
            );
        grid.events.push_with_id(
            event_id,
            volvoxgrid_engine::event::GridEventData::BeforeEdit { row, col },
        );
        None
    }

    fn request_before_checkbox_toggle(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        row: i32,
        col: i32,
    ) -> bool {
        if !volvoxgrid_engine::input::can_toggle_checkbox_cell(grid, row, col) {
            return false;
        }

        if !self.decision_channel_enabled(grid_id) {
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::BeforeEdit { row, col });
            volvoxgrid_engine::input::apply_checkbox_toggle_after_before_edit(grid, row, col);
            return true;
        }

        let event_id = self.next_event_id();
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                (grid_id, event_id),
                PendingActionEntry {
                    created_at: Instant::now(),
                    action: PendingAction::ToggleCheckbox { row, col },
                },
            );
        grid.events.push_with_id(
            event_id,
            volvoxgrid_engine::event::GridEventData::BeforeEdit { row, col },
        );
        true
    }

    fn request_before_dropdown_open(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        row: i32,
        col: i32,
        force: bool,
        prefer_combo: bool,
        seed_text: Option<String>,
        click_caret: Option<i32>,
        caret_end: Option<bool>,
    ) -> bool {
        let Some(event) = grid.before_dropdown_open_event(row, col) else {
            return false;
        };
        let event_id = self.next_event_id();
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                (grid_id, event_id),
                PendingActionEntry {
                    created_at: Instant::now(),
                    action: PendingAction::BeforeDropdownOpen {
                        row,
                        col,
                        force,
                        prefer_combo,
                        seed_text,
                        click_caret,
                        caret_end,
                    },
                },
            );
        grid.events.push_with_id(event_id, event);
        true
    }

    fn request_validate_edit(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        row: i32,
        col: i32,
        old_text: String,
        new_text: String,
    ) {
        let committed_text = shared::normalize_committed_edit_text(grid, row, col, &new_text);

        if !self.decision_channel_enabled(grid_id) {
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::CellEditValidate {
                    row,
                    col,
                    edit_text: committed_text.clone(),
                });
            shared::apply_committed_edit_text(grid, row, col, old_text, committed_text);
            return;
        }

        let event_id = self.next_event_id();
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                (grid_id, event_id),
                PendingActionEntry {
                    created_at: Instant::now(),
                    action: PendingAction::ValidateEdit {
                        row,
                        col,
                        old_text,
                        committed_text: committed_text.clone(),
                    },
                },
            );
        grid.events.push_with_id(
            event_id,
            volvoxgrid_engine::event::GridEventData::CellEditValidate {
                row,
                col,
                edit_text: committed_text,
            },
        );
    }

    fn request_before_sort(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        col: i32,
    ) {
        if !self.decision_channel_enabled(grid_id) {
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::BeforeSort { col });
            Self::spawn_header_sort_job(grid_id, col);
            return;
        }

        let event_id = self.next_event_id();
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                (grid_id, event_id),
                PendingActionEntry {
                    created_at: Instant::now(),
                    action: PendingAction::BeforeSort { col },
                },
            );
        grid.events.push_with_id(
            event_id,
            volvoxgrid_engine::event::GridEventData::BeforeSort { col },
        );
    }

    fn request_before_node_toggle(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        row: i32,
        collapse: bool,
    ) {
        let event = if let Some(node_id) = grid.tree.node_id_at_row(grid.fixed_rows, row) {
            volvoxgrid_engine::event::GridEventData::BeforeTreeNodeToggle {
                node_id: node_id.to_string(),
                row,
                collapse,
            }
        } else {
            volvoxgrid_engine::event::GridEventData::BeforeNodeToggle { row, collapse }
        };
        if !self.decision_channel_enabled(grid_id) {
            grid.events.push(event);
            volvoxgrid_engine::input::apply_node_toggle_after_before(grid, row, collapse);
            return;
        }

        let event_id = self.next_event_id();
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                (grid_id, event_id),
                PendingActionEntry {
                    created_at: Instant::now(),
                    action: PendingAction::BeforeNodeToggle { row, collapse },
                },
            );
        grid.events.push_with_id(event_id, event);
    }

    fn request_before_user_resize(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        row: i32,
        col: i32,
        start_pos: f32,
    ) {
        if !self.decision_channel_enabled(grid_id) {
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::BeforeUserResize { row, col });
            volvoxgrid_engine::input::begin_user_resize_after_before(grid, row, col, start_pos);
            return;
        }

        let event_id = self.next_event_id();
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                (grid_id, event_id),
                PendingActionEntry {
                    created_at: Instant::now(),
                    action: PendingAction::BeforeUserResize {
                        row,
                        col,
                        start_pos,
                    },
                },
            );
        grid.events.push_with_id(
            event_id,
            volvoxgrid_engine::event::GridEventData::BeforeUserResize { row, col },
        );
    }

    fn request_before_move_column(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        col: i32,
        new_position: i32,
    ) {
        if !self.decision_channel_enabled(grid_id) {
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::BeforeMoveColumn {
                    col,
                    new_position,
                });
            volvoxgrid_engine::input::apply_move_column_after_before(grid, col, new_position);
            return;
        }

        let event_id = self.next_event_id();
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                (grid_id, event_id),
                PendingActionEntry {
                    created_at: Instant::now(),
                    action: PendingAction::BeforeMoveColumn { col, new_position },
                },
            );
        grid.events.push_with_id(
            event_id,
            volvoxgrid_engine::event::GridEventData::BeforeMoveColumn { col, new_position },
        );
    }

    fn request_before_move_row(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        row: i32,
        new_position: i32,
    ) {
        if !self.decision_channel_enabled(grid_id) {
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::BeforeMoveRow { row, new_position });
            volvoxgrid_engine::input::apply_move_row_after_before(grid, row, new_position);
            return;
        }

        let event_id = self.next_event_id();
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                (grid_id, event_id),
                PendingActionEntry {
                    created_at: Instant::now(),
                    action: PendingAction::BeforeMoveRow { row, new_position },
                },
            );
        grid.events.push_with_id(
            event_id,
            volvoxgrid_engine::event::GridEventData::BeforeMoveRow { row, new_position },
        );
    }

    fn request_before_mouse_down(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        row: i32,
        col: i32,
        x: f32,
        y: f32,
        button: i32,
        modifier: i32,
        dbl_click: bool,
    ) {
        if !self.decision_channel_enabled(grid_id) {
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::BeforeMouseDown {
                    row,
                    col,
                    target: volvoxgrid_engine::event::EventTarget::data_cell(),
                });
            self.handle_pointer_down_after_before_mouse(
                grid_id, grid, x, y, button, modifier, dbl_click,
            );
            return;
        }

        let event_id = self.next_event_id();
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                (grid_id, event_id),
                PendingActionEntry {
                    created_at: Instant::now(),
                    action: PendingAction::BeforeMouseDown {
                        x,
                        y,
                        button,
                        modifier,
                        dbl_click,
                    },
                },
            );
        grid.events.push_with_id(
            event_id,
            volvoxgrid_engine::event::GridEventData::BeforeMouseDown {
                row,
                col,
                target: volvoxgrid_engine::event::EventTarget::data_cell(),
            },
        );
    }

    fn handle_pointer_down_after_before_mouse(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        x: f32,
        y: f32,
        button: i32,
        modifier: i32,
        dbl_click: bool,
    ) {
        ensure_layout(grid);
        let hit = volvoxgrid_engine::input::hit_test(grid, x, y);
        volvoxgrid_engine::input::handle_pointer_down_with_behavior(
            grid,
            x,
            y,
            button,
            modifier,
            dbl_click,
            volvoxgrid_engine::input::InputBehavior {
                allow_begin_edit: false,
                allow_header_sort: false,
                allow_node_toggle: false,
                allow_user_resize: false,
                allow_before_mouse_down: false,
                ..volvoxgrid_engine::input::InputBehavior::default()
            },
        );

        let mut is_combo_cell = false;
        if hit.area == volvoxgrid_engine::input::HitArea::ColBorder && hit.col >= 0 && !dbl_click {
            self.request_before_user_resize(grid_id, grid, -1, hit.col, x);
        } else if hit.area == volvoxgrid_engine::input::HitArea::RowBorder
            && hit.row >= 0
            && !dbl_click
        {
            self.request_before_user_resize(grid_id, grid, hit.row, -1, y);
        }

        if hit.row >= 0
            && !dbl_click
            && hit.area == volvoxgrid_engine::input::HitArea::OutlineButton
        {
            let collapsing = !grid
                .row_props
                .get(&hit.row)
                .map_or(false, |rp| rp.is_collapsed);
            self.request_before_node_toggle(grid_id, grid, hit.row, collapsing);
        }

        if hit.row >= 0 && hit.col >= 0 {
            if hit.area == volvoxgrid_engine::input::HitArea::CheckBox {
                self.request_before_checkbox_toggle(grid_id, grid, hit.row, hit.col);
            }

            let is_cell_like = hit.area == volvoxgrid_engine::input::HitArea::Cell
                || hit.area == volvoxgrid_engine::input::HitArea::FixedRow
                || hit.area == volvoxgrid_engine::input::HitArea::FixedCol;
            let combo_list = if is_cell_like {
                grid.active_dropdown_list(hit.row, hit.col)
            } else {
                String::new()
            };
            is_combo_cell = !combo_list.is_empty();

            if hit.area == volvoxgrid_engine::input::HitArea::DropdownButton {
                if !(grid.edit.is_active()
                    && grid.edit.edit_row == hit.row
                    && grid.edit.edit_col == hit.col)
                {
                    let _ = self.request_before_edit(
                        grid_id, grid, hit.row, hit.col, false, true, None, None, None,
                    );
                }
            } else if is_cell_like && ((dbl_click && grid.edit_trigger_mode >= 2) || is_combo_cell)
            {
                let click_caret = if dbl_click {
                    Some(grid.caret_index_from_display_click(hit.row, hit.col, hit.x_in_cell))
                } else {
                    None
                };
                let _ = self.request_before_edit(
                    grid_id,
                    grid,
                    hit.row,
                    hit.col,
                    false,
                    is_combo_cell,
                    None,
                    click_caret,
                    if dbl_click { Some(true) } else { None },
                );
            }
        }

        if should_request_pointer_header_sort(grid, &hit, is_combo_cell) {
            self.request_before_sort(grid_id, grid, hit.col);
        }
    }

    fn request_before_scroll(
        &self,
        grid_id: i64,
        grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
        delta_x: f32,
        delta_y: f32,
    ) -> bool {
        let Some((old_top_row, old_left_col, new_top_row, new_left_col)) =
            volvoxgrid_engine::input::preview_wheel_scroll_event(grid, delta_x, delta_y)
        else {
            volvoxgrid_engine::input::handle_scroll_with_behavior(
                grid,
                delta_x,
                delta_y,
                volvoxgrid_engine::input::InputBehavior {
                    allow_before_scroll: false,
                    ..volvoxgrid_engine::input::InputBehavior::default()
                },
            );
            return false;
        };

        if !self.decision_channel_enabled(grid_id) {
            volvoxgrid_engine::input::handle_scroll(grid, delta_x, delta_y);
            return true;
        }

        let event_id = self.next_event_id();
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                (grid_id, event_id),
                PendingActionEntry {
                    created_at: Instant::now(),
                    action: PendingAction::BeforeScroll { delta_x, delta_y },
                },
            );
        grid.events.push_with_id(
            event_id,
            volvoxgrid_engine::event::GridEventData::BeforeScroll {
                old_top_row,
                old_left_col,
                new_top_row,
                new_left_col,
            },
        );
        true
    }

    fn apply_pending_action(
        &self,
        grid_id: i64,
        action: PendingAction,
        cancel: bool,
    ) -> Option<RenderOutput> {
        match action {
            PendingAction::BeginEdit {
                row,
                col,
                force,
                prefer_combo,
                seed_text,
                click_caret,
                caret_end,
            } => {
                if cancel {
                    return None;
                }
                self.manager()
                    .with_grid(grid_id, |grid| {
                        if grid.active_dropdown(row, col).is_some()
                            && self.request_before_dropdown_open(
                                grid_id,
                                grid,
                                row,
                                col,
                                force,
                                prefer_combo,
                                seed_text.clone(),
                                click_caret,
                                caret_end,
                            )
                        {
                            return None;
                        }
                        shared::begin_edit_session_core_opts(
                            grid,
                            row,
                            col,
                            force,
                            false,
                            true,
                            None,
                            caret_end,
                            seed_text.clone(),
                            None,
                        );
                        if let Some(seed) = seed_text {
                            if grid.edit.is_active()
                                && grid.edit.edit_row == row
                                && grid.edit.edit_col == col
                            {
                                grid.events.push(
                                    volvoxgrid_engine::event::GridEventData::CellEditChange {
                                        text: seed,
                                    },
                                );
                            }
                        }
                        if let Some(caret) = click_caret {
                            if grid.edit.is_active()
                                && grid.edit.edit_row == row
                                && grid.edit.edit_col == col
                            {
                                grid.edit.sel_start = caret;
                                grid.edit.sel_length = 0;
                            }
                        }
                        maybe_render_editor_output(grid, prefer_combo)
                    })
                    .ok()
                    .flatten()
            }
            PendingAction::BeforeDropdownOpen {
                row,
                col,
                force,
                prefer_combo,
                seed_text,
                click_caret,
                caret_end,
            } => {
                if cancel {
                    return None;
                }
                self.manager()
                    .with_grid(grid_id, |grid| {
                        shared::begin_edit_session_core_opts(
                            grid,
                            row,
                            col,
                            force,
                            false,
                            false,
                            None,
                            caret_end,
                            seed_text.clone(),
                            None,
                        );
                        if let Some(seed) = seed_text {
                            if grid.edit.is_active()
                                && grid.edit.edit_row == row
                                && grid.edit.edit_col == col
                            {
                                grid.events.push(
                                    volvoxgrid_engine::event::GridEventData::CellEditChange {
                                        text: seed,
                                    },
                                );
                            }
                        }
                        if let Some(caret) = click_caret {
                            if grid.edit.is_active()
                                && grid.edit.edit_row == row
                                && grid.edit.edit_col == col
                            {
                                grid.edit.sel_start = caret;
                                grid.edit.sel_length = 0;
                            }
                        }
                        maybe_render_editor_output(grid, prefer_combo)
                    })
                    .ok()
                    .flatten()
            }
            PendingAction::ValidateEdit {
                row,
                col,
                old_text,
                committed_text,
            } => self
                .manager()
                .with_grid(grid_id, |grid| {
                    let edit_matches = grid.edit.is_active()
                        && grid.edit.edit_row == row
                        && grid.edit.edit_col == col;

                    if cancel {
                        if edit_matches {
                            let prefer_combo = grid.edit.dropdown_count() > 0;
                            return maybe_render_editor_output(grid, prefer_combo);
                        }
                        return None;
                    }

                    if edit_matches {
                        grid.edit.cancel();
                    }
                    shared::apply_committed_edit_text(grid, row, col, old_text, committed_text);
                    None
                })
                .ok()
                .flatten(),
            PendingAction::ToggleCheckbox { row, col } => {
                if cancel {
                    return None;
                }
                let _ = self.manager().with_grid(grid_id, |grid| {
                    volvoxgrid_engine::input::apply_checkbox_toggle_after_before_edit(
                        grid, row, col,
                    );
                });
                None
            }
            PendingAction::BeforeSort { col } => {
                if cancel {
                    return None;
                }
                Self::spawn_header_sort_job(grid_id, col);
                None
            }
            PendingAction::BeforeNodeToggle { row, collapse } => {
                if cancel {
                    return None;
                }
                let _ = self.manager().with_grid(grid_id, |grid| {
                    volvoxgrid_engine::input::apply_node_toggle_after_before(grid, row, collapse);
                });
                None
            }
            PendingAction::BeforeUserResize {
                row,
                col,
                start_pos,
            } => {
                if cancel {
                    let _ = self.manager().with_grid(grid_id, |grid| {
                        grid.cancel_pull_to_refresh_contact(false);
                    });
                    return None;
                }
                let _ = self.manager().with_grid(grid_id, |grid| {
                    volvoxgrid_engine::input::begin_user_resize_after_before(
                        grid, row, col, start_pos,
                    );
                });
                None
            }
            PendingAction::BeforeMoveColumn { col, new_position } => {
                if cancel {
                    return None;
                }
                let _ = self.manager().with_grid(grid_id, |grid| {
                    volvoxgrid_engine::input::apply_move_column_after_before(
                        grid,
                        col,
                        new_position,
                    );
                });
                None
            }
            PendingAction::BeforeMoveRow { row, new_position } => {
                if cancel {
                    return None;
                }
                let _ = self.manager().with_grid(grid_id, |grid| {
                    volvoxgrid_engine::input::apply_move_row_after_before(grid, row, new_position);
                });
                None
            }
            PendingAction::BeforeMouseDown {
                x,
                y,
                button,
                modifier,
                dbl_click,
            } => {
                if cancel {
                    return None;
                }
                let _ = self.manager().with_grid(grid_id, |grid| {
                    self.handle_pointer_down_after_before_mouse(
                        grid_id, grid, x, y, button, modifier, dbl_click,
                    );
                });
                None
            }
            PendingAction::BeforeScroll { delta_x, delta_y } => {
                if cancel {
                    return None;
                }
                let _ = self.manager().with_grid(grid_id, |grid| {
                    volvoxgrid_engine::input::handle_scroll_with_behavior(
                        grid,
                        delta_x,
                        delta_y,
                        volvoxgrid_engine::input::InputBehavior {
                            allow_before_scroll: false,
                            ..volvoxgrid_engine::input::InputBehavior::default()
                        },
                    );
                });
                None
            }
        }
    }

    fn resolve_event_decision(
        &self,
        grid_id: i64,
        event_id: i64,
        cancel: bool,
    ) -> Option<RenderOutput> {
        self.mark_decision_channel_enabled(grid_id);

        if event_id <= 0 {
            return None;
        }

        let pending = self
            .pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(&(grid_id, event_id));
        pending.and_then(|entry| self.apply_pending_action(grid_id, entry.action, cancel))
    }

    fn resolve_expired_actions(&self, grid_id: i64) -> Vec<RenderOutput> {
        let Some(timeout) = self.decision_timeout(grid_id) else {
            return Vec::new();
        };
        let now = Instant::now();
        let mut expired_actions = Vec::new();
        {
            let mut pending = self
                .pending_actions
                .lock()
                .unwrap_or_else(|e| e.into_inner());
            let expired_keys: Vec<(i64, i64)> = pending
                .iter()
                .filter_map(|(key, entry)| {
                    if key.0 == grid_id && now.duration_since(entry.created_at) >= timeout {
                        Some(*key)
                    } else {
                        None
                    }
                })
                .collect();
            for key in expired_keys {
                if let Some(entry) = pending.remove(&key) {
                    expired_actions.push((key.1, entry.action));
                }
            }
        }

        let mut outputs = Vec::new();
        for (event_id, action) in expired_actions {
            let _ = self.manager().with_grid(grid_id, |grid| {
                grid.events
                    .push(volvoxgrid_engine::event::GridEventData::Error {
                        code: ERROR_DECISION_TIMEOUT,
                        message: format!(
                            "no EventDecision for event_id={event_id} after {}ms",
                            timeout.as_millis()
                        ),
                    });
            });
            if let Some(output) = self.apply_pending_action(grid_id, action, false) {
                outputs.push(output);
            }
        }
        outputs
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// v2 Trait Implementation
// ═══════════════════════════════════════════════════════════════════════════

impl ffi_tree_impl::VolvoxTreeServiceRuntime for VolvoxGridRuntime {
    fn load_tree(&self, request: LoadTreeRequest) -> TreeRuntimeResult<LoadTreeResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::load_tree(grid, request)
        })
    }

    fn append_tree(&self, mut request: LoadTreeRequest) -> TreeRuntimeResult<LoadTreeResponse> {
        request.replace = false;
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::load_tree(grid, request)
        })
    }

    fn insert_nodes(&self, request: InsertNodesRequest) -> TreeRuntimeResult<InsertNodesResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::insert_nodes(grid, request)
        })
    }

    fn remove_nodes(&self, request: RemoveNodesRequest) -> TreeRuntimeResult<RemoveNodesResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::remove_nodes(grid, request)
        })
    }

    fn move_nodes(&self, request: MoveNodesRequest) -> TreeRuntimeResult<MoveNodesResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::move_nodes(grid, request)
        })
    }

    fn rename_node(&self, request: RenameNodeRequest) -> TreeRuntimeResult<RenameNodeResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::rename_node(grid, request)
        })
    }

    fn update_tree(&self, request: UpdateTreeRequest) -> TreeRuntimeResult<UpdateTreeResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::update_tree(grid, request)
        })
    }

    fn update_node_cells(&self, request: UpdateNodeCellsRequest) -> TreeRuntimeResult<WriteResult> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::update_node_cells(grid, request)
        })
    }

    fn expand_nodes(&self, request: ExpandNodesRequest) -> TreeRuntimeResult<ExpandNodesResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::expand_nodes(grid, request)
        })
    }

    fn collapse_nodes(
        &self,
        request: CollapseNodesRequest,
    ) -> TreeRuntimeResult<CollapseNodesResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::collapse_nodes(grid, request)
        })
    }

    fn expand_to_node(
        &self,
        request: ExpandToNodeRequest,
    ) -> TreeRuntimeResult<ExpandToNodeResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::expand_to_node(grid, request)
        })
    }

    fn get_expansion(&self, request: GetExpansionRequest) -> TreeRuntimeResult<ExpansionState> {
        self.with_grid_tree(request.grid_id, |grid| {
            volvoxgrid_engine::tree::get_expansion(grid)
        })
    }

    fn set_expansion(
        &self,
        request: SetExpansionRequest,
    ) -> TreeRuntimeResult<SetExpansionResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::set_expansion(grid, request)
        })
    }

    fn get_tree_node(&self, request: GetTreeNodeRequest) -> TreeRuntimeResult<TreeNodeInfo> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::get_tree_node(grid, request)
        })
    }

    fn get_children(&self, request: GetChildrenRequest) -> TreeRuntimeResult<TreeNodeList> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::get_children(grid, request)
        })
    }

    fn get_visible_nodes(
        &self,
        request: GetVisibleNodesRequest,
    ) -> TreeRuntimeResult<TreeNodeList> {
        let grid_id = request.grid_id;
        self.with_grid_tree(grid_id, |grid| {
            volvoxgrid_engine::tree::get_visible_nodes(grid, request)
        })
    }

    fn get_node_path(&self, request: GetNodePathRequest) -> TreeRuntimeResult<NodePathResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::get_node_path(grid, request)
        })
    }

    fn get_node_by_path(&self, request: GetNodeByPathRequest) -> TreeRuntimeResult<TreeNodeInfo> {
        let grid_id = request.grid_id;
        self.with_grid_tree(grid_id, |grid| {
            volvoxgrid_engine::tree::get_node_by_path(grid, request)
        })
    }

    fn select_nodes(&self, request: SelectNodesRequest) -> TreeRuntimeResult<NodeSelectionState> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::select_nodes(grid, request)
        })
    }

    fn get_node_selection(
        &self,
        request: GetNodeSelectionRequest,
    ) -> TreeRuntimeResult<NodeSelectionState> {
        self.with_grid_tree(request.grid_id, |grid| {
            volvoxgrid_engine::tree::get_node_selection(grid)
        })
    }

    fn set_checked_nodes(
        &self,
        request: SetCheckedNodesRequest,
    ) -> TreeRuntimeResult<CheckedNodes> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::set_checked_nodes(grid, request)
        })
    }

    fn get_checked_nodes(
        &self,
        request: GetCheckedNodesRequest,
    ) -> TreeRuntimeResult<CheckedNodes> {
        self.with_grid_tree(request.grid_id, |grid| {
            volvoxgrid_engine::tree::get_checked_nodes(grid)
        })
    }

    fn sort_tree(&self, request: SortTreeRequest) -> TreeRuntimeResult<SortTreeResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree(grid_id, |grid| {
            volvoxgrid_engine::tree::sort_tree(grid, request)
        })
    }

    fn filter_tree(&self, request: FilterTreeRequest) -> TreeRuntimeResult<FilterTreeResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::filter_tree(grid, request)
        })
    }

    fn clear_tree_filter(
        &self,
        request: ClearTreeFilterRequest,
    ) -> TreeRuntimeResult<ClearTreeFilterResponse> {
        self.with_grid_tree(request.grid_id, |grid| {
            volvoxgrid_engine::tree::clear_tree_filter(grid)
        })
    }

    fn find_tree(&self, request: FindTreeRequest) -> TreeRuntimeResult<FindTreeResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::find_tree(grid, request)
        })
    }

    fn resolve_children(
        &self,
        request: ResolveChildrenRequest,
    ) -> TreeRuntimeResult<ResolveChildrenResponse> {
        let grid_id = request.grid_id;
        self.with_grid_tree_result(grid_id, |grid| {
            volvoxgrid_engine::tree::resolve_children(grid, request)
        })
    }
}

impl VolvoxGridServiceRuntime for VolvoxGridRuntime {
    // ── Lifecycle ──

    fn create(&self, request: CreateRequest) -> RuntimeResult<CreateResponse> {
        let spec = shared::create_grid_spec(&request);
        let id = self.manager().create_grid(
            request.viewport_width,
            request.viewport_height,
            spec.rows,
            spec.cols,
            spec.fixed_rows,
            spec.fixed_cols,
            spec.scale,
        );
        self.set_current_zoom_scale(id, 1.0);

        if let Some(config) = request.config.as_ref() {
            let _ = self.with_grid(id, |grid| {
                grid.apply_config(config);
            });
        }

        Ok(CreateResponse {
            grid_id: id,
            warnings: Vec::new(),
        })
    }

    fn destroy(&self, request: DestroyRequest) -> RuntimeResult<DestroyResponse> {
        self.clear_grid_state(request.grid_id);
        self.manager().destroy_grid(request.grid_id);
        Ok(DestroyResponse {})
    }

    // ── Configuration ──

    fn configure(&self, request: ConfigureRequest) -> RuntimeResult<ConfigureResponse> {
        self.with_grid(request.grid_id, |grid| shared::configure(grid, &request))
    }

    fn get_config(&self, request: GetConfigRequest) -> RuntimeResult<GridConfig> {
        self.with_grid(request.grid_id, |grid| grid.get_config())
    }

    fn load_font_data(&self, request: LoadFontDataRequest) -> RuntimeResult<LoadFontDataResponse> {
        if request.data.is_empty() {
            return Err(invalid_argument("font data is empty"));
        }

        let _primary_font_name = request.font_name.trim();
        let _font_name_fallbacks: Vec<&str> = request
            .font_names
            .iter()
            .map(|v| v.trim())
            .filter(|v| !v.is_empty())
            .collect();

        let mut loaded = self
            .loaded_font_data
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        if loaded
            .iter()
            .any(|existing| existing.as_slice() == request.data.as_slice())
        {
            return Ok(LoadFontDataResponse {});
        }
        loaded.push(request.data);
        Ok(LoadFontDataResponse {})
    }

    // ── Structure ──

    fn define_columns(
        &self,
        request: DefineColumnsRequest,
    ) -> RuntimeResult<DefineColumnsResponse> {
        self.with_grid(request.grid_id, |grid| {
            shared::define_columns(grid, &request)
        })
    }

    fn get_schema(&self, request: GetSchemaRequest) -> RuntimeResult<SchemaResponse> {
        self.with_grid(request.grid_id, |grid| grid.get_schema())
    }

    fn define_rows(&self, request: DefineRowsRequest) -> RuntimeResult<DefineRowsResponse> {
        self.with_grid(request.grid_id, |grid| shared::define_rows(grid, &request))
    }

    fn insert_rows(&self, request: InsertRowsRequest) -> RuntimeResult<InsertRowsResponse> {
        self.with_grid(request.grid_id, |grid| shared::insert_rows(grid, &request))
    }

    fn remove_rows(&self, request: RemoveRowsRequest) -> RuntimeResult<RemoveRowsResponse> {
        self.with_grid(request.grid_id, |grid| shared::remove_rows(grid, &request))
    }

    fn move_column(&self, request: MoveColumnRequest) -> RuntimeResult<MoveColumnResponse> {
        self.with_grid(request.grid_id, |grid| shared::move_column(grid, &request))
    }

    fn move_row(&self, request: MoveRowRequest) -> RuntimeResult<MoveRowResponse> {
        self.with_grid(request.grid_id, |grid| {
            self.request_before_move_row(request.grid_id, grid, request.row, request.position);
        })?;
        Ok(MoveRowResponse {})
    }

    // ── Data ──

    fn update_cells(&self, request: UpdateCellsRequest) -> RuntimeResult<WriteResult> {
        self.with_grid(request.grid_id, |grid| shared::update_cells(grid, &request))
    }

    fn get_cells(&self, request: GetCellsRequest) -> RuntimeResult<CellsResponse> {
        self.with_grid(request.grid_id, |grid| shared::get_cells(grid, &request))
    }

    fn load_table(&self, request: LoadTableRequest) -> RuntimeResult<WriteResult> {
        self.with_grid(request.grid_id, |grid| shared::load_table(grid, &request))
    }

    fn load_data(&self, request: LoadDataRequest) -> RuntimeResult<LoadDataResult> {
        self.with_grid(request.grid_id, |grid| shared::load_data(grid, &request))
    }

    fn append_data(&self, request: AppendDataRequest) -> RuntimeResult<LoadDataResult> {
        self.with_grid(request.grid_id, |grid| shared::append_data(grid, &request))
    }

    fn clear(&self, request: ClearRequest) -> RuntimeResult<ClearResponse> {
        self.with_grid(request.grid_id, |grid| shared::clear(grid, &request))
    }

    // ── Selection ──

    fn select(&self, request: SelectRequest) -> RuntimeResult<SelectResponse> {
        self.with_grid(request.grid_id, |grid| shared::select(grid, &request))
    }

    fn get_selection(&self, request: GetSelectionRequest) -> RuntimeResult<SelectionState> {
        self.with_grid(request.grid_id, shared::selection_state_proto)
    }

    fn show_cell(&self, request: ShowCellRequest) -> RuntimeResult<ShowCellResponse> {
        self.with_grid(request.grid_id, |grid| shared::show_cell(grid, &request))
    }

    fn set_top_row(&self, request: SetRowRequest) -> RuntimeResult<SetTopRowResponse> {
        self.with_grid(request.grid_id, |grid| shared::set_top_row(grid, &request))
    }

    fn set_left_col(&self, request: SetColRequest) -> RuntimeResult<SetLeftColResponse> {
        self.with_grid(request.grid_id, |grid| shared::set_left_col(grid, &request))
    }

    // ── Editing ──

    fn edit(&self, request: EditCommand) -> RuntimeResult<EditState> {
        let grid_id = request.grid_id;
        let state = self.with_grid(grid_id, |grid| {
            match request.command {
                Some(edit_command::Command::Start(start)) => {
                    shared::begin_edit_session_core_opts(
                        grid,
                        start.row,
                        start.col,
                        false,
                        true,
                        true,
                        start.select_all,
                        start.caret_end,
                        start.seed_text,
                        start.formula_mode,
                    );
                }
                Some(edit_command::Command::Commit(commit)) => {
                    if grid.edit.is_active() {
                        grid.edit.flush_preedit();
                        let row = grid.edit.edit_row;
                        let col = grid.edit.edit_col;
                        let old_text = grid.cells.get_text(row, col).to_string();
                        let new_text = commit.text.unwrap_or_else(|| grid.edit.edit_text.clone());
                        if self.decision_channel_enabled(grid_id) {
                            let pending_text =
                                shared::truncate_to_char_count(&new_text, grid.edit_max_length);
                            grid.edit.update_text(pending_text.clone());
                            grid.edit.sel_start = pending_text.chars().count() as i32;
                            grid.edit.sel_length = 0;
                            self.request_validate_edit(
                                grid_id,
                                grid,
                                row,
                                col,
                                old_text,
                                pending_text,
                            );
                        } else {
                            let committed =
                                shared::normalize_committed_edit_text(grid, row, col, &new_text);
                            grid.edit.cancel();
                            grid.events.push(
                                volvoxgrid_engine::event::GridEventData::CellEditValidate {
                                    row,
                                    col,
                                    edit_text: committed.clone(),
                                },
                            );
                            shared::apply_committed_edit_text(grid, row, col, old_text, committed);
                        }
                    }
                }
                Some(edit_command::Command::Cancel(_)) => {
                    if grid.edit.is_active() {
                        let active_combo =
                            grid.active_dropdown_list(grid.edit.edit_row, grid.edit.edit_col);
                        grid.edit.cancel();
                        if !active_combo.is_empty() {
                            grid.events
                                .push(volvoxgrid_engine::event::GridEventData::DropdownClosed);
                        }
                        grid.mark_dirty();
                    }
                }
                Some(edit_command::Command::SetText(set_text)) => {
                    if grid.edit.is_active() {
                        let t =
                            shared::truncate_to_char_count(&set_text.text, grid.edit_max_length);
                        grid.edit.update_text(t.clone());
                        grid.edit.sel_start = t.chars().count() as i32;
                        grid.edit.sel_length = 0;
                        grid.events
                            .push(volvoxgrid_engine::event::GridEventData::CellEditChange {
                                text: t,
                            });
                        grid.mark_dirty();
                    }
                }
                Some(edit_command::Command::SetSelection(sel)) => {
                    if grid.edit.is_active() {
                        grid.edit.set_sel_start(sel.start);
                        grid.edit.set_sel_length(sel.length);
                        grid.mark_dirty();
                    }
                }
                Some(edit_command::Command::SetHighlights(set_highlights)) => {
                    let highlights = set_highlights
                        .regions
                        .iter()
                        .filter_map(|region| {
                            let range = region.range.as_ref()?;
                            Some(volvoxgrid_engine::edit::EditHighlightRegion {
                                row1: range.row1,
                                col1: range.col1,
                                row2: range.row2,
                                col2: range.col2,
                                style: volvoxgrid_engine::style::HighlightStyle::from_proto(
                                    region.style.as_ref(),
                                ),
                                ref_id: region.ref_id,
                                text_start: region.text_start,
                                text_length: region.text_length,
                            })
                        })
                        .collect::<Vec<_>>();
                    grid.edit.set_highlights(highlights);
                    grid.mark_dirty();
                }
                Some(edit_command::Command::SetPreedit(preedit)) => {
                    if grid.edit.is_active() {
                        if preedit.commit {
                            // IME committed text: insert into edit_text at cursor.
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
                        if self.decision_channel_enabled(grid_id) {
                            self.request_validate_edit(grid_id, grid, row, col, old_text, new_text);
                        } else {
                            let committed =
                                shared::normalize_committed_edit_text(grid, row, col, &new_text);
                            grid.edit.cancel();
                            grid.events.push(
                                volvoxgrid_engine::event::GridEventData::CellEditValidate {
                                    row,
                                    col,
                                    edit_text: committed.clone(),
                                },
                            );
                            shared::apply_committed_edit_text(grid, row, col, old_text, committed);
                        }
                    }
                }
                None => {}
            }

            shared::edit_state_proto(grid)
        })?;
        Ok(state)
    }

    // ── Actions ──

    fn sort(&self, request: SortRequest) -> RuntimeResult<SortResponse> {
        // Programmatic Sort supersedes any in-flight header-click custom sort
        // for this grid. clear_compare_channel cancels pending host compares so
        // the abandoned worker can unwind instead of committing stale order.
        Self::clear_compare_channel(request.grid_id);
        let snapshot = self.with_grid(request.grid_id, |grid| {
            if request.sort_columns.is_empty() {
                // No columns — clear sort state
                grid.sort_state.clear();
                grid.layout.invalidate();
                grid.mark_dirty();
                None
            } else {
                let sort_keys = shared::expand_sort_request_columns(grid, &request.sort_columns);
                if sort_keys.is_empty() {
                    return None;
                }
                if let Some(snapshot) =
                    Self::prepare_sort_keys_snapshot(request.grid_id, grid, &sort_keys)
                {
                    Some(snapshot)
                } else {
                    Self::run_sort_keys_locked(request.grid_id, grid, sort_keys);
                    None
                }
            }
        })?;
        if let Some(snapshot) = snapshot {
            Self::run_header_sort_snapshot(request.grid_id, snapshot);
        }
        Self::clear_compare_channel(request.grid_id);
        Ok(SortResponse {})
    }

    fn subtotal(&self, request: SubtotalRequest) -> RuntimeResult<SubtotalResult> {
        self.with_grid(request.grid_id, |grid| shared::subtotal(grid, &request))
    }

    fn auto_size(&self, request: AutoSizeRequest) -> RuntimeResult<AutoSizeResponse> {
        self.with_grid(request.grid_id, |grid| shared::auto_size(grid, &request))
    }

    fn outline(&self, request: OutlineRequest) -> RuntimeResult<OutlineResponse> {
        self.with_grid(request.grid_id, |grid| shared::outline(grid, &request))
    }

    fn get_node(&self, request: GetNodeRequest) -> RuntimeResult<NodeInfo> {
        self.with_grid(request.grid_id, |grid| shared::get_node(grid, &request))
    }

    fn find(&self, request: FindRequest) -> RuntimeResult<FindResponse> {
        self.with_grid(request.grid_id, |grid| shared::find(grid, &request))
    }

    fn aggregate(&self, request: AggregateRequest) -> RuntimeResult<AggregateResponse> {
        self.with_grid(request.grid_id, |grid| shared::aggregate(grid, &request))
    }

    fn get_merged_range(&self, request: GetMergedRangeRequest) -> RuntimeResult<CellRange> {
        self.with_grid(request.grid_id, |grid| {
            shared::get_merged_range(grid, &request)
        })
    }

    fn merge_cells(&self, request: MergeCellsRequest) -> RuntimeResult<MergeCellsResponse> {
        self.with_grid(request.grid_id, |grid| shared::merge_cells(grid, &request))
    }

    fn unmerge_cells(&self, request: UnmergeCellsRequest) -> RuntimeResult<UnmergeCellsResponse> {
        self.with_grid(request.grid_id, |grid| {
            shared::unmerge_cells(grid, &request)
        })
    }

    fn get_merged_regions(
        &self,
        request: GetMergedRegionsRequest,
    ) -> RuntimeResult<MergedRegionsResponse> {
        self.with_grid(request.grid_id, shared::get_merged_regions)
    }

    fn get_memory_usage(
        &self,
        request: GetMemoryUsageRequest,
    ) -> RuntimeResult<MemoryUsageResponse> {
        self.with_grid(request.grid_id, shared::get_memory_usage)
    }

    // ── Clipboard ──

    fn clipboard(&self, request: ClipboardCommand) -> RuntimeResult<ClipboardResponse> {
        let grid_id = request.grid_id;
        self.with_grid(grid_id, |grid| shared::clipboard(grid, &request))
    }

    // ── Export / Print / Archive ──

    fn export(&self, request: ExportRequest) -> RuntimeResult<ExportResponse> {
        self.with_grid(request.grid_id, |grid| shared::export(grid, &request))
    }

    fn print(&self, request: PrintRequest) -> RuntimeResult<PrintResponse> {
        self.with_grid(request.grid_id, |grid| shared::print(grid, &request))
    }

    fn archive(&self, request: ArchiveRequest) -> RuntimeResult<ArchiveResponse> {
        self.with_grid(request.grid_id, |grid| shared::archive(grid, &request))
    }

    // ── Render Control ──

    fn resize_viewport(
        &self,
        request: ResizeViewportRequest,
    ) -> RuntimeResult<ResizeViewportResponse> {
        self.with_grid(request.grid_id, |grid| {
            shared::resize_viewport(grid, &request)
        })
    }

    fn set_redraw(&self, request: SetRedrawRequest) -> RuntimeResult<SetRedrawResponse> {
        self.with_grid(request.grid_id, |grid| shared::set_redraw(grid, &request))
    }

    fn refresh(&self, request: RefreshRequest) -> RuntimeResult<RefreshResponse> {
        self.with_grid(request.grid_id, |grid| {
            let _ = request;
            shared::refresh(grid)
        })
    }

    fn load_demo(&self, request: LoadDemoRequest) -> RuntimeResult<LoadDemoResponse> {
        #[cfg(feature = "demo")]
        {
            self.with_grid_result(request.grid_id, |grid| {
                volvoxgrid_engine::demo::setup_named_demo(grid, &request.demo)
            })?;
            Ok(LoadDemoResponse {})
        }
        #[cfg(not(feature = "demo"))]
        {
            let _ = request;
            Err(not_implemented("demo feature is not enabled"))
        }
    }

    fn get_demo_data(&self, request: GetDemoDataRequest) -> RuntimeResult<GetDemoDataResponse> {
        #[cfg(feature = "demo")]
        {
            volvoxgrid_engine::demo::get_demo_data_response(&request.demo).map_err(Into::into)
        }
        #[cfg(not(feature = "demo"))]
        {
            let _ = request;
            Err(not_implemented("demo feature is not enabled"))
        }
    }

    // ── Streaming: Render Session ──

    fn render_session(
        &self,
        stream: &dyn RuntimeStreamBidi<RenderInput, RenderOutput>,
    ) -> RuntimeResult<()> {
        let mut renderer: Option<volvoxgrid_engine::render::Renderer> = None;
        let mut tui_renderer = volvoxgrid_engine::canvas_tui::TuiRenderer::new();
        tui_renderer
            .set_background_mode(volvoxgrid_engine::canvas_tui::TuiBackgroundMode::Transparent);
        let mut terminal_session = terminal_tui::TerminalTuiSession::new();
        let mut renderer_text_registration: Option<TextRendererRegistration> = None;
        let mut cpu_font_count_applied: usize = 0;
        #[cfg(feature = "gpu")]
        let mut gpu_renderer: Option<volvoxgrid_engine::gpu_render::GpuRenderer> = None;
        #[cfg(feature = "gpu")]
        let mut gpu_font_count_applied: usize = 0;
        #[cfg(feature = "gpu")]
        let mut last_surface_handle: i64 = 0;
        #[cfg(feature = "gpu")]
        let mut last_present_mode: i32 = -1;
        let mut last_fling_tick: Option<std::time::Instant> = None;
        let mut last_mem_calc: HashMap<i64, Instant> = HashMap::new();
        let mut sent_edit_requests: HashMap<i64, SentEditRequest> = HashMap::new();
        let mut zoom_sessions: HashMap<i64, ZoomGestureState> = HashMap::new();
        let mut session_grid_ids: HashSet<i64> = HashSet::new();

        loop {
            let input = match stream.recv() {
                Some(input) => input,
                None => break,
            };
            let grid_id = input.grid_id;
            self.register_render_session_grid(grid_id, &mut session_grid_ids);
            let is_compare_response = matches!(
                input.input.as_ref(),
                Some(render_input::Input::CompareResponse(_))
            );
            if !is_compare_response {
                for output in self.resolve_expired_actions(grid_id) {
                    if !terminal_session.suppress_aux_outputs() {
                        send_render_output_tracked(
                            self,
                            stream,
                            &mut sent_edit_requests,
                            grid_id,
                            output,
                        );
                    }
                }
            }

            match input.input {
                Some(render_input::Input::Viewport(vs)) => {
                    let _ = self.with_grid(grid_id, |grid| {
                        grid.resize_viewport(vs.width, vs.height);
                    });
                    stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    });
                }

                Some(render_input::Input::Buffer(buf_ready)) => {
                    let now = std::time::Instant::now();
                    let dt_seconds = if let Some(prev) = last_fling_tick {
                        now.duration_since(prev)
                            .as_secs_f32()
                            .clamp(1.0 / 240.0, 1.0 / 20.0)
                    } else {
                        1.0 / 60.0
                    };
                    last_fling_tick = Some(now);

                    let result = self.with_grid(grid_id, |grid| {
                        let terminal_active = terminal_session.is_active() && grid.is_tui_mode();
                        let needs_fling_tick =
                            grid.fling_enabled && !grid.is_tui_mode() && grid.scroll.fling_active;
                        let needs_pull_tick = grid.pull_to_refresh_needs_frame();
                        if !terminal_active && !grid.dirty && !needs_fling_tick && !needs_pull_tick
                        {
                            return (false, 0, 0, 0, 0, None);
                        }

                        // Tick per-frame layout/animation state even when the
                        // cached layout is already valid so animation can settle
                        // and clear `dirty` instead of self-pumping forever.
                        ensure_layout(grid);
                        let pinned_h = grid.pinned_top_height() + grid.pinned_bottom_height();
                        let pinned_w = grid.pinned_left_width() + grid.pinned_right_width();
                        grid.scroll.update_bounds(
                            &grid.layout,
                            grid.data_viewport_width(),
                            grid.data_viewport_height(),
                            grid.fixed_rows,
                            grid.fixed_cols,
                            pinned_h,
                            pinned_w,
                        );

                        if needs_fling_tick {
                            if grid.scroll.tick_fling(dt_seconds, grid.fling_friction) {
                                grid.mark_dirty_visual();
                            }
                        }
                        if needs_pull_tick && grid.tick_pull_to_refresh(dt_seconds) {
                            grid.mark_dirty_visual();
                        }

                        if !terminal_active && !grid.dirty {
                            return (false, 0, 0, 0, 0, None);
                        }

                        let handle = buf_ready.handle;
                        let stride = buf_ready.stride;
                        let width = buf_ready.width;
                        let height = buf_ready.height;

                        if handle == 0 {
                            return (false, 0, 0, 0, 0, None);
                        }
                        if !terminal_active && (width <= 0 || height <= 0 || stride <= 0) {
                            return (false, 0, 0, 0, 0, None);
                        }

                        grid.debug_zoom_level = self.current_zoom_scale(grid_id);

                        if grid.debug_overlay
                            && last_mem_calc
                                .get(&grid_id)
                                .map_or(true, |t| now.duration_since(*t) >= Duration::from_secs(10))
                        {
                            grid.debug_total_mem_bytes = grid.heap_size_bytes() as i64;
                            last_mem_calc.insert(grid_id, now);
                        }

                        let frame_start = std::time::Instant::now();

                        if terminal_active {
                            let prepared =
                                terminal_session.prepare_frame(grid, &mut tui_renderer, &buf_ready);
                            let elapsed = frame_start.elapsed().as_secs_f32() * 1000.0;
                            grid.debug_renderer_actual = RendererMode::RendererCpu as i32;
                            grid.debug_instance_count = 0;
                            grid.debug_text_cache_len = 0;
                            grid.debug_frame_time_ms = elapsed;
                            grid.debug_fps =
                                grid.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
                            return (prepared.rendered, 0, 0, 0, 0, Some(prepared));
                        }

                        if grid.is_tui_mode() {
                            let cell_size =
                                std::mem::size_of::<volvoxgrid_engine::canvas_tui::TuiCell>();
                            let stride_bytes = stride as usize;
                            if stride_bytes < cell_size
                                || stride_bytes % cell_size != 0
                                || stride_bytes / cell_size < width as usize
                            {
                                return (false, 0, 0, 0, 0, None);
                            }
                            let stride_cells = stride_bytes / cell_size;
                            let cell_count = stride_cells.saturating_mul(height as usize);
                            let buffer = unsafe {
                                std::slice::from_raw_parts_mut(
                                    handle as *mut volvoxgrid_engine::canvas_tui::TuiCell,
                                    cell_count,
                                )
                            };
                            grid.debug_renderer_actual = RendererMode::RendererCpu as i32;
                            let ((dx, dy, dw, dh), layer_times, zone_counts) =
                                tui_renderer.render(grid, buffer, width, height, stride_cells);
                            if grid.layer_profiling {
                                grid.layer_times_us = layer_times;
                                grid.zone_cell_counts = zone_counts;
                            }
                            grid.debug_instance_count = 0;
                            grid.debug_text_cache_len = 0;
                            let elapsed = frame_start.elapsed().as_secs_f32() * 1000.0;
                            grid.debug_frame_time_ms = elapsed;
                            grid.debug_fps =
                                grid.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
                            grid.clear_dirty();
                            return (true, dx, dy, dw, dh, None);
                        }

                        let buf_size = (stride * height) as usize;
                        let buffer =
                            unsafe { std::slice::from_raw_parts_mut(handle as *mut u8, buf_size) };

                        #[cfg(feature = "gpu")]
                        if grid.renderer_mode >= 2 {
                            let preferred_backends = match grid.renderer_mode {
                                3 => Some(wgpu::Backends::VULKAN),
                                4 => Some(wgpu::Backends::GL),
                                _ => None,
                            };

                            // Detect backend mismatch and force recreation
                            if let Some(gr) = gpu_renderer.as_ref() {
                                let current_type = gr.backend_type();
                                let mismatch = match grid.renderer_mode {
                                    3 => current_type != wgpu::Backend::Vulkan,
                                    4 => current_type != wgpu::Backend::Gl,
                                    _ => false,
                                };
                                if mismatch {
                                    gpu_renderer = None;
                                    gpu_font_count_applied = 0;
                                }
                            }

                            if gpu_renderer.is_none() {
                                match pollster_block(
                                    volvoxgrid_engine::gpu_render::GpuRenderer::new(
                                        preferred_backends,
                                    ),
                                ) {
                                    Ok(gr) => {
                                        gpu_renderer = Some(gr);
                                    }
                                    Err(_e) => {
                                        grid.set_renderer_mode(RendererMode::RendererCpu as i32);
                                    }
                                }
                            }
                            if let Some(gr) = gpu_renderer.as_mut() {
                                self.sync_fonts_into_gpu_renderer(gr, &mut gpu_font_count_applied);
                                grid.debug_renderer_actual = RendererMode::RendererGpu as i32;
                                grid.debug_gpu_backend = gr.backend_name();
                                grid.debug_gpu_present_mode = gr.present_mode_name();
                                grid.debug_text_cache_len = gr.text_cache_len() as i32;
                                let ((dx, dy, dw, dh), layer_times, zone_counts) =
                                    gr.render_to_buffer(grid, buffer, width, height, stride);
                                if grid.layer_profiling {
                                    grid.layer_times_us = layer_times;
                                    grid.zone_cell_counts = zone_counts;
                                }
                                grid.debug_instance_count = gr.instance_count() as i32;
                                let elapsed = frame_start.elapsed().as_secs_f32() * 1000.0;
                                grid.debug_frame_time_ms = elapsed;
                                grid.debug_fps =
                                    grid.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
                                grid.clear_dirty();
                                return (true, dx, dy, dw, dh, None);
                            }
                        }

                        grid.debug_renderer_actual = RendererMode::RendererCpu as i32;
                        grid.debug_text_cache_len = grid
                            .text_engine
                            .as_ref()
                            .map_or(0, |te| te.layout_cache_len() as i32);
                        let r =
                            renderer.get_or_insert_with(volvoxgrid_engine::render::Renderer::new);
                        let desired_text_registration = get_registered_text_renderer(grid_id);
                        if !same_text_renderer_registration(
                            renderer_text_registration,
                            desired_text_registration,
                        ) {
                            match desired_text_registration {
                                Some(registration) => {
                                    r.set_custom_text_renderer(Some(Box::new(
                                        ffi_text_renderer_from_registration(registration),
                                    )));
                                }
                                None => {
                                    r.set_custom_text_renderer(None);
                                }
                            }
                            renderer_text_registration = desired_text_registration;
                        }
                        self.sync_fonts_into_renderer(r, &mut cpu_font_count_applied);
                        let ((dx, dy, dw, dh), layer_times, zone_counts) =
                            r.render(grid, buffer, width, height, stride);
                        if grid.layer_profiling {
                            grid.layer_times_us = layer_times;
                            grid.zone_cell_counts = zone_counts;
                        }
                        grid.debug_text_cache_len = r.text_cache_len() as i32;
                        let elapsed = frame_start.elapsed().as_secs_f32() * 1000.0;
                        grid.debug_frame_time_ms = elapsed;
                        grid.debug_fps = grid.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
                        grid.clear_dirty();
                        (true, dx, dy, dw, dh, None)
                    });

                    match result {
                        Ok((rendered, dx, dy, dw, dh, prepared_terminal)) => {
                            let mut rendered = rendered;
                            let mut bytes_written = 0i32;
                            let mut required_capacity = 0i32;
                            let mut frame_kind = pb::FrameKind::Frame as i32;
                            if let Some(prepared) = prepared_terminal {
                                required_capacity = prepared.required_capacity as i32;
                                frame_kind = prepared.frame_kind;
                                if prepared.required_capacity > 0 {
                                    let capacity = buf_ready.capacity.max(0) as usize;
                                    if prepared.required_capacity > capacity {
                                        rendered = false;
                                    } else {
                                        unsafe {
                                            std::ptr::copy_nonoverlapping(
                                                prepared.bytes.as_ptr(),
                                                buf_ready.handle as *mut u8,
                                                prepared.bytes.len(),
                                            );
                                        }
                                        bytes_written = prepared.bytes.len() as i32;
                                        if rendered {
                                            let _ = self.with_grid(grid_id, |grid| {
                                                grid.clear_dirty();
                                            });
                                        }
                                        prepared.commit(&mut terminal_session);
                                    }
                                } else {
                                    prepared.commit(&mut terminal_session);
                                }
                            }
                            let metrics = if rendered {
                                self.with_grid(grid_id, |grid| current_frame_metrics(grid))
                                    .ok()
                                    .flatten()
                            } else {
                                None
                            };
                            stream.send(RenderOutput {
                                rendered,
                                event: Some(render_output::Event::FrameDone(FrameDone {
                                    handle: buf_ready.handle,
                                    dirty_x: dx,
                                    dirty_y: dy,
                                    dirty_w: dw,
                                    dirty_h: dh,
                                    metrics,
                                    bytes_written,
                                    required_capacity,
                                    frame_kind,
                                })),
                            });
                            if rendered && !terminal_session.suppress_aux_outputs() {
                                maybe_send_refreshed_edit_request(
                                    self,
                                    stream,
                                    &mut sent_edit_requests,
                                    grid_id,
                                );
                            }
                        }
                        Err(_) => {
                            stream.send(RenderOutput {
                                rendered: false,
                                event: Some(render_output::Event::FrameDone(FrameDone {
                                    handle: buf_ready.handle,
                                    dirty_x: 0,
                                    dirty_y: 0,
                                    dirty_w: 0,
                                    dirty_h: 0,
                                    metrics: None,
                                    bytes_written: 0,
                                    required_capacity: 0,
                                    frame_kind: pb::FrameKind::Frame as i32,
                                })),
                            });
                        }
                    }
                }

                #[cfg(not(feature = "gpu"))]
                Some(render_input::Input::GpuSurface(_)) => {
                    stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    });
                }

                #[cfg(feature = "gpu")]
                Some(render_input::Input::GpuSurface(surface_ready)) => {
                    let now = std::time::Instant::now();
                    let dt_seconds = if let Some(prev) = last_fling_tick {
                        now.duration_since(prev)
                            .as_secs_f32()
                            .clamp(1.0 / 240.0, 1.0 / 20.0)
                    } else {
                        1.0 / 60.0
                    };
                    last_fling_tick = Some(now);

                    let handle = surface_ready.surface_handle;
                    let width = surface_ready.width;
                    let height = surface_ready.height;

                    // Surface handle == 0 means the native window was destroyed.
                    if handle == 0 {
                        if let Some(gr) = gpu_renderer.as_mut() {
                            gr.drop_surface();
                        }
                        last_surface_handle = 0;
                        // Stop engine-side fling so it doesn't resume after suspend.
                        let _ = self.with_grid(grid_id, |grid| {
                            grid.scroll.stop_fling();
                        });
                        stream.send(RenderOutput {
                            rendered: false,
                            event: Some(render_output::Event::GpuFrameDone(GpuFrameDone {
                                dirty_x: 0,
                                dirty_y: 0,
                                dirty_w: 0,
                                dirty_h: 0,
                                metrics: None,
                            })),
                        });
                        continue;
                    }

                    let requested_mode = self
                        .manager()
                        .with_grid(grid_id, |grid| grid.renderer_mode)
                        .unwrap_or(0);
                    if requested_mode < RendererMode::RendererGpu as i32
                        || requested_mode == RendererMode::RendererTui as i32
                    {
                        stream.send(RenderOutput {
                            rendered: false,
                            event: Some(render_output::Event::GpuFrameDone(GpuFrameDone {
                                dirty_x: 0,
                                dirty_y: 0,
                                dirty_w: 0,
                                dirty_h: 0,
                                metrics: None,
                            })),
                        });
                        continue;
                    }

                    // Lazy-init GpuRenderer on first GpuSurfaceReady
                    if gpu_renderer.is_some() {
                        let requested_mode = self
                            .manager()
                            .with_grid(grid_id, |grid| grid.renderer_mode)
                            .unwrap_or(0);
                        let current_type = gpu_renderer.as_ref().unwrap().backend_type();
                        let mismatch = match requested_mode {
                            3 => current_type != wgpu::Backend::Vulkan,
                            4 => current_type != wgpu::Backend::Gl,
                            _ => false,
                        };
                        if mismatch {
                            gpu_renderer = None;
                            gpu_font_count_applied = 0;
                            last_surface_handle = 0;
                        }
                    }

                    if gpu_renderer.is_none() {
                        let preferred_backends = self
                            .manager()
                            .with_grid(grid_id, |grid| match grid.renderer_mode {
                                3 => Some(wgpu::Backends::VULKAN),
                                4 => Some(wgpu::Backends::GL),
                                _ => None,
                            })
                            .ok()
                            .flatten();

                        match pollster_block(volvoxgrid_engine::gpu_render::GpuRenderer::new(
                            preferred_backends,
                        )) {
                            Ok(gr) => {
                                gpu_renderer = Some(gr);
                            }
                            Err(_e) => {
                                let _ = self.with_grid(grid_id, |grid| {
                                    grid.set_renderer_mode(RendererMode::RendererCpu as i32);
                                });
                                stream.send(RenderOutput {
                                    rendered: false,
                                    event: Some(render_output::Event::GpuFrameDone(GpuFrameDone {
                                        dirty_x: 0,
                                        dirty_y: 0,
                                        dirty_w: 0,
                                        dirty_h: 0,
                                        metrics: None,
                                    })),
                                });
                                continue;
                            }
                        }
                    }

                    let gr = gpu_renderer.as_mut().unwrap();

                    // Configure surface if handle changed, present mode changed, or surface not yet set up
                    let requested_pm = self
                        .manager()
                        .with_grid(grid_id, |grid| grid.present_mode)
                        .unwrap_or(0);
                    if handle != last_surface_handle
                        || !gr.has_surface()
                        || requested_pm != last_present_mode
                    {
                        let configure_result = pollster_block(unsafe {
                            gr.configure_surface_from_raw_handle(
                                handle as *mut std::ffi::c_void,
                                width as u32,
                                height as u32,
                                requested_pm,
                            )
                        });
                        if let Err(_e) = configure_result {
                            let _ = self.with_grid(grid_id, |grid| {
                                grid.set_renderer_mode(RendererMode::RendererCpu as i32);
                            });
                            last_surface_handle = 0;
                            last_present_mode = -1;
                            stream.send(RenderOutput {
                                rendered: false,
                                event: Some(render_output::Event::GpuFrameDone(GpuFrameDone {
                                    dirty_x: 0,
                                    dirty_y: 0,
                                    dirty_w: 0,
                                    dirty_h: 0,
                                    metrics: None,
                                })),
                            });
                            continue;
                        }
                        last_surface_handle = handle;
                        last_present_mode = requested_pm;
                        // Surface reconfiguration can happen after Android HOME/resume
                        // with no data mutation. Force one redraw so the newly bound
                        // surface is populated instead of staying black.
                        let _ = self.with_grid(grid_id, |grid| {
                            grid.mark_dirty();
                        });
                    } else {
                        // Same handle and present mode, just resize if needed
                        gr.resize_surface(width as u32, height as u32);
                        if !gr.has_surface() {
                            // resize_surface detected an invalid surface and dropped it.
                            // Reset handle tracking so the next frame triggers reconfiguration.
                            last_surface_handle = 0;
                            last_present_mode = -1;
                            stream.send(RenderOutput {
                                rendered: false,
                                event: Some(render_output::Event::GpuFrameDone(GpuFrameDone {
                                    dirty_x: 0,
                                    dirty_y: 0,
                                    dirty_w: 0,
                                    dirty_h: 0,
                                    metrics: None,
                                })),
                            });
                            continue;
                        }
                    }

                    self.sync_fonts_into_gpu_renderer(gr, &mut gpu_font_count_applied);

                    let gr_backend_name = gr.backend_name();
                    let gr_present_mode_name = gr.present_mode_name();
                    let gr_text_cache_len = gr.text_cache_len() as i32;

                    let result = self.with_grid(grid_id, |grid| {
                        let needs_fling_tick =
                            grid.fling_enabled && !grid.is_tui_mode() && grid.scroll.fling_active;
                        let needs_pull_tick = grid.pull_to_refresh_needs_frame();
                        if !grid.dirty && !needs_fling_tick && !needs_pull_tick {
                            return Ok((false, 0, 0, 0, 0));
                        }

                        // Tick per-frame layout/animation state even when the
                        // cached layout is already valid so animation can settle
                        // and clear `dirty` instead of self-pumping forever.
                        ensure_layout(grid);
                        let pinned_h = grid.pinned_top_height() + grid.pinned_bottom_height();
                        let pinned_w = grid.pinned_left_width() + grid.pinned_right_width();
                        grid.scroll.update_bounds(
                            &grid.layout,
                            grid.data_viewport_width(),
                            grid.data_viewport_height(),
                            grid.fixed_rows,
                            grid.fixed_cols,
                            pinned_h,
                            pinned_w,
                        );

                        if needs_fling_tick {
                            if grid.scroll.tick_fling(dt_seconds, grid.fling_friction) {
                                grid.mark_dirty_visual();
                            }
                        }
                        if needs_pull_tick && grid.tick_pull_to_refresh(dt_seconds) {
                            grid.mark_dirty_visual();
                        }

                        if !grid.dirty {
                            return Ok((false, 0, 0, 0, 0));
                        }

                        grid.debug_zoom_level = self.current_zoom_scale(grid_id);

                        if grid.debug_overlay
                            && last_mem_calc
                                .get(&grid_id)
                                .map_or(true, |t| now.duration_since(*t) >= Duration::from_secs(10))
                        {
                            grid.debug_total_mem_bytes = grid.heap_size_bytes() as i64;
                            last_mem_calc.insert(grid_id, now);
                        }

                        grid.debug_text_cache_len = gr_text_cache_len;

                        let frame_start = std::time::Instant::now();

                        grid.debug_renderer_actual = RendererMode::RendererGpu as i32;
                        grid.debug_gpu_backend = gr_backend_name;
                        grid.debug_gpu_present_mode = gr_present_mode_name;

                        match gr.render_to_surface(grid, width, height) {
                            Ok(((dx, dy, dw, dh), layer_times, zone_counts)) => {
                                if grid.layer_profiling {
                                    grid.layer_times_us = layer_times;
                                    grid.zone_cell_counts = zone_counts;
                                }
                                grid.debug_instance_count = gr.instance_count() as i32;
                                let elapsed = frame_start.elapsed().as_secs_f32() * 1000.0;
                                grid.debug_frame_time_ms = elapsed;
                                grid.debug_fps =
                                    grid.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
                                grid.clear_dirty();
                                Ok((true, dx, dy, dw, dh))
                            }
                            Err(e) => Err(e),
                        }
                    });

                    match result {
                        Ok(Ok((rendered, dx, dy, dw, dh))) => {
                            let metrics = if rendered {
                                self.with_grid(grid_id, |grid| current_frame_metrics(grid))
                                    .ok()
                                    .flatten()
                            } else {
                                None
                            };
                            stream.send(RenderOutput {
                                rendered,
                                event: Some(render_output::Event::GpuFrameDone(GpuFrameDone {
                                    dirty_x: dx,
                                    dirty_y: dy,
                                    dirty_w: dw,
                                    dirty_h: dh,
                                    metrics,
                                })),
                            });
                            if rendered {
                                maybe_send_refreshed_edit_request(
                                    self,
                                    stream,
                                    &mut sent_edit_requests,
                                    grid_id,
                                );
                            }
                        }
                        Ok(Err(_)) => {
                            // Surface error (e.g. Lost, Outdated). Drop the surface immediately
                            // and force reconfiguration on next frame.
                            if let Some(gr) = gpu_renderer.as_mut() {
                                gr.drop_surface();
                            }
                            last_surface_handle = 0;
                            last_present_mode = -1;
                            stream.send(RenderOutput {
                                rendered: false,
                                event: Some(render_output::Event::GpuFrameDone(GpuFrameDone {
                                    dirty_x: 0,
                                    dirty_y: 0,
                                    dirty_w: 0,
                                    dirty_h: 0,
                                    metrics: None,
                                })),
                            });
                        }
                        Err(_) => {
                            stream.send(RenderOutput {
                                rendered: false,
                                event: Some(render_output::Event::GpuFrameDone(GpuFrameDone {
                                    dirty_x: 0,
                                    dirty_y: 0,
                                    dirty_w: 0,
                                    dirty_h: 0,
                                    metrics: None,
                                })),
                            });
                        }
                    }
                }

                Some(render_input::Input::TerminalCapabilities(caps)) => {
                    terminal_session.update_capabilities(&caps);
                    stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    });
                }

                Some(render_input::Input::TerminalViewport(viewport)) => {
                    let changed = terminal_session.update_viewport(&viewport);
                    let _ = self.with_grid(grid_id, |grid| {
                        grid.resize_viewport(viewport.width, viewport.height);
                        if changed {
                            grid.mark_dirty();
                        }
                    });
                    stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    });
                }

                Some(render_input::Input::TerminalCommand(command)) => {
                    if command.kind == pb::terminal_command::Kind::TerminalCommandExit as i32 {
                        terminal_session.queue_shutdown();
                    }
                    stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    });
                }

                Some(render_input::Input::TerminalInput(terminal_input)) => {
                    for event in terminal_session.drain_input(&terminal_input.data) {
                        match event {
                            terminal_tui::TerminalEvent::Key(key) => {
                                handle_key_render_input(
                                    self,
                                    stream,
                                    &mut sent_edit_requests,
                                    grid_id,
                                    key,
                                    false,
                                    Some(&mut terminal_session),
                                );
                            }
                            terminal_tui::TerminalEvent::Pointer(pointer) => {
                                handle_pointer_render_input(
                                    self,
                                    stream,
                                    &mut sent_edit_requests,
                                    grid_id,
                                    pointer,
                                    Some(&mut terminal_session),
                                    false,
                                );
                            }
                            terminal_tui::TerminalEvent::Scroll(scroll) => {
                                handle_scroll_render_input(self, stream, grid_id, scroll, false);
                            }
                        }
                    }
                }

                Some(render_input::Input::Pointer(pe)) => {
                    handle_pointer_render_input(
                        self,
                        stream,
                        &mut sent_edit_requests,
                        grid_id,
                        pe,
                        None,
                        !terminal_session.suppress_aux_outputs(),
                    );
                }

                Some(render_input::Input::Key(ke)) => {
                    handle_key_render_input(
                        self,
                        stream,
                        &mut sent_edit_requests,
                        grid_id,
                        ke,
                        !terminal_session.suppress_aux_outputs(),
                        None,
                    );
                }

                Some(render_input::Input::Scroll(se)) => {
                    handle_scroll_render_input(
                        self,
                        stream,
                        grid_id,
                        se,
                        !terminal_session.suppress_aux_outputs(),
                    );
                }

                Some(render_input::Input::Zoom(ze)) => {
                    let _ = self.with_grid(grid_id, |grid| {
                        grid.cancel_pull_to_refresh_contact(false);
                    });
                    let zoom_enabled = self
                        .manager()
                        .with_grid(grid_id, |grid| grid.pinch_zoom_enabled)
                        .unwrap_or(true);
                    if !zoom_enabled {
                        zoom_sessions.remove(&grid_id);
                        stream.send(RenderOutput {
                            rendered: false,
                            event: None,
                        });
                        continue;
                    }

                    match ze.phase {
                        p if p == pb::zoom_event::Phase::ZoomBegin as i32 => {
                            let base_zoom_scale = self.current_zoom_scale(grid_id);
                            if let Ok(state) = self.with_grid(grid_id, |grid| {
                                if !grid.layout.valid {
                                    ensure_layout(grid);
                                }
                                grid.scroll.stop_fling();
                                let rows = grid.rows.max(0);
                                let defer_updates = should_defer_zoom_updates(grid, rows);
                                let allow_preview_updates = allow_zoom_preview_updates(grid, rows);
                                capture_zoom_state(
                                    grid,
                                    defer_updates,
                                    allow_preview_updates,
                                    base_zoom_scale,
                                )
                            }) {
                                zoom_sessions.insert(grid_id, state);
                            }
                        }
                        p if p == pb::zoom_event::Phase::ZoomUpdate as i32 => {
                            let mut step_scale = if ze.scale.is_finite() && ze.scale > 0.0 {
                                (ze.scale as f64).clamp(ZOOM_STEP_MIN_SCALE, ZOOM_STEP_MAX_SCALE)
                            } else {
                                1.0
                            };
                            if (step_scale - 1.0).abs() < ZOOM_STEP_NOISE_EPSILON {
                                step_scale = 1.0;
                            }

                            if !zoom_sessions.contains_key(&grid_id) {
                                let base_zoom_scale = self.current_zoom_scale(grid_id);
                                if let Ok(state) = self.with_grid(grid_id, |grid| {
                                    if !grid.layout.valid {
                                        ensure_layout(grid);
                                    }
                                    let rows = grid.rows.max(0);
                                    let defer_updates = should_defer_zoom_updates(grid, rows);
                                    let allow_preview_updates =
                                        allow_zoom_preview_updates(grid, rows);
                                    capture_zoom_state(
                                        grid,
                                        defer_updates,
                                        allow_preview_updates,
                                        base_zoom_scale,
                                    )
                                }) {
                                    zoom_sessions.insert(grid_id, state);
                                }
                            }

                            let (target_scale, relative_scale, should_apply) = if let Some(state) =
                                zoom_sessions.get_mut(&grid_id)
                            {
                                state.cumulative_scale =
                                    clamp_zoom_gesture_scale(state.cumulative_scale * step_scale);
                                let target_scale = snap_zoom_restore_scale(clamp_zoom_scale(
                                    state.base_zoom_scale * state.cumulative_scale,
                                ));
                                let relative_scale = if state.base_zoom_scale > 0.0 {
                                    target_scale / state.base_zoom_scale
                                } else {
                                    1.0
                                };
                                let now = Instant::now();
                                let relative_delta =
                                    zoom_relative_delta(target_scale, state.applied_scale);

                                let should_apply = if state.defer_updates {
                                    if !state.allow_preview_updates {
                                        false
                                    } else {
                                        relative_delta >= LARGE_GRID_ZOOM_FORCE_DELTA
                                            || (relative_delta >= LARGE_GRID_ZOOM_MIN_DELTA
                                                && now.duration_since(state.last_apply_at)
                                                    >= LARGE_GRID_ZOOM_APPLY_INTERVAL)
                                    }
                                } else {
                                    true
                                };

                                (target_scale, relative_scale, should_apply)
                            } else {
                                (1.0_f64, 1.0_f64, false)
                            };

                            if should_apply {
                                let mut applied = false;
                                if let Some(state) = zoom_sessions.get(&grid_id) {
                                    applied = self
                                        .manager()
                                        .with_grid(grid_id, |grid| {
                                            if !grid.layout.valid {
                                                ensure_layout(grid);
                                            }
                                            apply_zoom_scale(grid, state, relative_scale)
                                        })
                                        .unwrap_or(false);
                                }
                                if applied {
                                    if let Some(state) = zoom_sessions.get_mut(&grid_id) {
                                        state.applied_scale = target_scale;
                                        state.last_apply_at = Instant::now();
                                    }
                                    self.set_current_zoom_scale(grid_id, target_scale);
                                }
                            }
                        }
                        p if p == pb::zoom_event::Phase::ZoomEnd as i32 => {
                            if let Some(state) = zoom_sessions.remove(&grid_id) {
                                let final_scale = snap_zoom_restore_scale(clamp_zoom_scale(
                                    state.base_zoom_scale * state.cumulative_scale,
                                ));
                                let final_relative_scale = if state.base_zoom_scale > 0.0 {
                                    final_scale / state.base_zoom_scale
                                } else {
                                    1.0
                                };
                                let needs_final_apply =
                                    zoom_relative_delta(final_scale, state.applied_scale) > 0.0001;
                                let _ = self.with_grid(grid_id, |grid| {
                                    if !grid.layout.valid {
                                        ensure_layout(grid);
                                    }
                                    if needs_final_apply {
                                        apply_zoom_scale(grid, &state, final_relative_scale);
                                    } else {
                                        grid.scroll.stop_fling();
                                    }
                                });
                                self.set_current_zoom_scale(grid_id, final_scale);
                            } else {
                                let _ = self.with_grid(grid_id, |grid| {
                                    if !grid.layout.valid {
                                        ensure_layout(grid);
                                    }
                                    grid.scroll.stop_fling();
                                });
                            }
                        }
                        _ => {}
                    }
                    stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    });
                }

                Some(render_input::Input::EventDecision(decision)) => {
                    let decision_grid_id = if decision.grid_id != 0 {
                        decision.grid_id
                    } else {
                        grid_id
                    };
                    if let Some(output) = self.resolve_event_decision(
                        decision_grid_id,
                        decision.event_id,
                        decision.cancel,
                    ) {
                        send_render_output_tracked(
                            self,
                            stream,
                            &mut sent_edit_requests,
                            decision_grid_id,
                            output,
                        );
                    }
                    stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    });
                }

                Some(render_input::Input::CompareResponse(response)) => {
                    self.deliver_compare_response(grid_id, response.request_id, response.result);
                    stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    });
                }

                None => {
                    stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    });
                }
            }
        }
        self.unregister_render_session_grids(&session_grid_ids);
        Ok(())
    }

    // ── Streaming: Event Stream ──

    fn event_stream(
        &self,
        request: EventStreamRequest,
        stream: &dyn RuntimeStreamSender<GridEvent>,
    ) -> RuntimeResult<()> {
        let grid_id = request.grid_id;
        let (grid_arc, _event_cv, destroyed) = self
            .manager()
            .get_grid_waiter(grid_id)
            .map_err(map_runtime_error)?;
        let waker = self
            .manager()
            .get_grid_waker(grid_id)
            .map_err(map_runtime_error)?;

        // Route stream cancellation through the waker so we never have to poll
        // `is_cancelled()`. If the stream is already closed, on_cancel fires
        // immediately — the seq advance will short-circuit the first wait.
        {
            let waker_for_cancel = Arc::clone(&waker);
            stream.on_cancel(Box::new(move || waker_for_cancel.wake()));
        }

        loop {
            // Snapshot the wake sequence before draining. Any publisher (engine
            // events, compare pending, destroy, stream cancel) advances it;
            // wait_for_change only blocks when the snapshot is still current.
            let baseline = waker.current_seq();

            if destroyed.load(Ordering::SeqCst) || stream.is_cancelled() {
                return Ok(());
            }

            // 1. Compare pending uses its own mutex, so it's safe to drain even
            //    while the engine holds the grid lock (sort is inside with_grid).
            for pending in self
                .lookup_compare_channel(grid_id)
                .map(|c| c.drain_pending())
                .unwrap_or_default()
            {
                let proto_evt = GridEvent {
                    grid_id,
                    event_id: 0,
                    event: Some(grid_event::Event::Compare(CompareEvent {
                        request_id: pending.request_id,
                        row1: pending.row1,
                        row2: pending.row2,
                        col: pending.col,
                    })),
                };
                if !stream.send(proto_evt) {
                    return Ok(());
                }
            }

            // 2. Grid event queue: try_lock to avoid blocking the sort path.
            //    On WouldBlock we skip; the current holder's with_grid
            //    completion will wake us again.
            let event_list = match grid_arc.try_lock() {
                Ok(mut grid) => grid.events.drain(),
                Err(std::sync::TryLockError::Poisoned(poisoned)) => {
                    let mut grid = poisoned.into_inner();
                    grid.events.drain()
                }
                Err(std::sync::TryLockError::WouldBlock) => Vec::new(),
            };

            for evt in event_list {
                let proto_evt = engine_event_to_proto(grid_id, evt.event_id, evt.data);
                if proto_evt.event.is_some() && !stream.send(proto_evt) {
                    return Ok(());
                }
            }

            if destroyed.load(Ordering::SeqCst) || stream.is_cancelled() {
                return Ok(());
            }

            // 3. Pure push wait: block until any source bumps the waker seq.
            //    No timeout, no sleep. Cancel is wired via on_cancel above.
            waker.wait_for_change(baseline);
        }
    }
}

// ---------------------------------------------------------------------------
// Runtime registration
// ---------------------------------------------------------------------------

/// Factory for lazy runtime initialization (called by generated FFI dispatcher).
pub(crate) fn create_runtime() -> Box<dyn VolvoxGridServiceRuntime + 'static> {
    Box::new(VolvoxGridRuntime::new())
}

/// Factory for the companion tree service dispatcher.
pub(crate) fn create_tree_runtime() -> Box<dyn ffi_tree_impl::VolvoxTreeServiceRuntime + 'static> {
    Box::new(VolvoxGridRuntime::new())
}

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn VolvoxGrid_Init() {
    #[cfg(all(target_os = "windows", target_env = "gnu"))]
    unsafe {
        volvoxgrid_windows_mingw_compat_force_link();
    }
    register_volvox_grid_service_runtime(VolvoxGridRuntime::new());
}

// ---------------------------------------------------------------------------
// Extra C ABI exports: external text renderer callbacks
// ---------------------------------------------------------------------------

/// C callback type for measuring text.
///
/// `text_ptr` / `font_name_ptr` are UTF-8 byte slices (not null-terminated).
/// `max_width == -1.0` means unconstrained.
/// Width/height must be written to `out_width` / `out_height`.
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
///
/// `max_width == -1.0` means unconstrained.
/// Returns rendered text width.
type VvRenderTextFn = unsafe extern "C" fn(
    buffer: *mut u8,
    buf_width: i32,
    buf_height: i32,
    stride: i32,
    x: i32,
    y: i32,
    clip_x: i32,
    clip_y: i32,
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

#[derive(Clone, Copy, Debug)]
struct TextRendererRegistration {
    measure_fn: VvMeasureTextFn,
    render_fn: VvRenderTextFn,
    user_data: usize,
}

impl TextRendererRegistration {
    fn identity_key(self) -> (usize, usize, usize) {
        (
            self.measure_fn as usize,
            self.render_fn as usize,
            self.user_data,
        )
    }
}

/// Wraps C function-pointer callbacks as a `TextRenderer`.
struct FfiTextRenderer {
    measure_fn: VvMeasureTextFn,
    render_fn: VvRenderTextFn,
    user_data: *mut std::ffi::c_void,
}

// The host side owns `user_data` synchronization guarantees.
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
        clip_x: i32,
        clip_y: i32,
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
                clip_x,
                clip_y,
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

lazy_static::lazy_static! {
    static ref CUSTOM_TEXT_RENDERERS: Mutex<HashMap<i64, TextRendererRegistration>> =
        Mutex::new(HashMap::new());
}

fn ffi_text_renderer_from_registration(registration: TextRendererRegistration) -> FfiTextRenderer {
    FfiTextRenderer {
        measure_fn: registration.measure_fn,
        render_fn: registration.render_fn,
        user_data: registration.user_data as *mut std::ffi::c_void,
    }
}

fn get_registered_text_renderer(grid_id: i64) -> Option<TextRendererRegistration> {
    CUSTOM_TEXT_RENDERERS
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .get(&grid_id)
        .copied()
}

fn same_text_renderer_registration(
    left: Option<TextRendererRegistration>,
    right: Option<TextRendererRegistration>,
) -> bool {
    match (left, right) {
        (Some(a), Some(b)) => a.identity_key() == b.identity_key(),
        (None, None) => true,
        _ => false,
    }
}

fn set_grid_external_text_renderer(grid_id: i64, registration: Option<TextRendererRegistration>) {
    let _ = SHARED_GRID_MANAGER.with_grid(grid_id, |grid| match registration {
        Some(reg) => {
            grid.ensure_text_engine()
                .set_external_renderer(Some(Box::new(ffi_text_renderer_from_registration(reg))));
        }
        None => {
            if let Some(text_engine) = &mut grid.text_engine {
                text_engine.set_external_renderer(None);
            }
        }
    });
}

fn clear_registered_text_renderer(grid_id: i64) {
    CUSTOM_TEXT_RENDERERS
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .remove(&grid_id);
    set_grid_external_text_renderer(grid_id, None);
}

/// Register or clear a custom text renderer for a grid.
///
/// Pass non-null `measure_fn` + `render_fn` to enable; pass null for both to clear.
/// Returns 0 on success, -1 for invalid callback combinations.
#[no_mangle]
pub extern "C" fn volvox_grid_set_text_renderer(
    grid_id: i64,
    measure_fn: Option<VvMeasureTextFn>,
    render_fn: Option<VvRenderTextFn>,
    user_data: *mut std::ffi::c_void,
) -> i32 {
    match (measure_fn, render_fn) {
        (Some(measure), Some(render)) => {
            let registration = TextRendererRegistration {
                measure_fn: measure,
                render_fn: render,
                user_data: user_data as usize,
            };
            CUSTOM_TEXT_RENDERERS
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .insert(grid_id, registration);
            set_grid_external_text_renderer(grid_id, Some(registration));
            0
        }
        (None, None) => {
            clear_registered_text_renderer(grid_id);
            0
        }
        _ => -1,
    }
}

/// Returns 1 when built with the built-in `cosmic-text` engine, 0 otherwise.
#[no_mangle]
pub extern "C" fn volvox_grid_has_builtin_text_engine() -> i32 {
    if cfg!(feature = "standard") {
        1
    } else {
        0
    }
}

// ---------------------------------------------------------------------------
// Demo C ABI exports (feature-gated, not included in production builds)
// ---------------------------------------------------------------------------

#[cfg(feature = "demo")]
mod demo_ffi {
    use super::SHARED_GRID_MANAGER;
    use std::ffi::c_int;

    #[no_mangle]
    pub extern "C" fn VolvoxGrid_Demo_CreateStressGrid(
        data_rows: c_int,
        preload_rows: c_int,
        width: c_int,
        height: c_int,
    ) -> i64 {
        let mgr = &*SHARED_GRID_MANAGER;
        let grid =
            volvoxgrid_engine::demo::create_stress_grid(0, width, height, data_rows, preload_rows);
        let rows = grid.rows;
        let cols = grid.cols;
        let fr = grid.fixed_rows;
        let fc = grid.fixed_cols;
        let id = mgr.create_grid(width, height, rows, cols, fr, fc, 1.0);
        let _ = mgr.with_grid(id, |dest| {
            *dest = grid;
            dest.id = id;
        });
        id
    }

    #[no_mangle]
    pub extern "C" fn VolvoxGrid_Demo_MaterializeVisibleRows(grid_id: i64, padding: c_int) {
        let pad = if padding <= 0 {
            volvoxgrid_engine::demo::STRESS_MATERIALIZE_PADDING
        } else {
            padding
        };
        let _ = SHARED_GRID_MANAGER.with_grid(grid_id, |grid| {
            volvoxgrid_engine::demo::stress_materialize_visible_rows(grid, pad);
        });
    }

    #[no_mangle]
    pub extern "C" fn VolvoxGrid_Demo_SetupStressGrid(grid_id: i64, _data_rows: c_int) {
        let _ = SHARED_GRID_MANAGER.with_grid(grid_id, |grid| {
            volvoxgrid_engine::demo::setup_stress_demo(grid);
        });
    }
}
